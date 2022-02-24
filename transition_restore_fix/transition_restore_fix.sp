#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define GAMEDATA	"transition_restore_fix"

Address
	g_pSavedPlayerCount;

Handle
	g_hSDKKVGetString,
	g_hSDKKVSetString;

MemoryPatch
	g_mpRestoreByUserId;

DynamicDetour
	g_dDetourRestart;

ConVar
	g_hKeepIdentity;

bool
	g_bRestart;

enum struct PlayerSaveData
{
	char character[4];
	char modelName[PLATFORM_MAX_PATH];
}

PlayerSaveData
	g_esSavedData;

public Plugin myinfo =
{
	name = "Transition Restore Fix",
	author = "sorallll",
	description = "Restoring transition data by player's UserId instead of character",
	version = "1.1.2",
	url = "https://forums.alliedmods.net/showthread.php?t=336287"
};

public void OnPluginStart()
{
	vInitGameData();

	g_hKeepIdentity = CreateConVar("restart_keep_identity", "1", "Whether to keep the current character and model after the mission lost and restarts? (0=restore to pre-transition identity, 1=game default)", FCVAR_NOTIFY);
	g_hKeepIdentity.AddChangeHook(vConVarChanged);

	AutoExecConfig(true, "transition_restore_fix");
}

public void OnPluginEnd()
{
	g_mpRestoreByUserId.Disable();
}

public void OnConfigsExecuted()
{
	vToggleDetours(g_hKeepIdentity.BoolValue);
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vToggleDetours(g_hKeepIdentity.BoolValue);
}

void vToggleDetours(bool bEnable)
{
	static bool bEnabled;
	if(!bEnabled && bEnable)
	{
		bEnabled = true;

		if(!g_dDetourRestart.Enable(Hook_Pre, mreRestartPre))
			SetFailState("Failed to detour pre: Detour_CDirector::Restart");
		
		if(!g_dDetourRestart.Enable(Hook_Post, mreRestartPost))
			SetFailState("Failed to detour post: Detour_CDirector::Restart");
	}
	else if(bEnabled && !bEnable)
	{
		bEnabled = false;

		if(!g_dDetourRestart.Disable(Hook_Pre, mreRestartPre))
			SetFailState("Failed to disable detour pre: Detour_CDirector::Restart");

		if(!g_dDetourRestart.Disable(Hook_Post, mreRestartPost))
			SetFailState("Failed to disable detour post: Detour_CDirector::Restart");
	}
}

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pSavedPlayerCount = hGameData.GetAddress("SavedPlayerCount");
	if(!g_pSavedPlayerCount)
		SetFailState("Failed to find address: SavedPlayerCount");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString"))
		SetFailState("Failed to find signature: KeyValues::GetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	g_hSDKKVGetString = EndPrepSDKCall();
	if(!g_hSDKKVGetString)
		SetFailState("Failed to create SDKCall: KeyValues::GetString");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString"))
		SetFailState("Failed to find signature: KeyValues::SetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDKKVSetString = EndPrepSDKCall();
	if(!g_hSDKKVSetString)
		SetFailState("Failed to create SDKCall: KeyValues::SetString");

	vInitPatchs(hGameData);
	vSetupDetours(hGameData);

	delete hGameData;
}

void vInitPatchs(GameData hGameData = null)
{
	g_mpRestoreByUserId = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::TransitionRestore::RestoreByUserId");
	if(!g_mpRestoreByUserId)
		SetFailState("Failed to create MemoryPatch: CTerrorPlayer::TransitionRestore::RestoreByUserId");

	if(!g_mpRestoreByUserId.Validate())
		SetFailState("Failed to validate MemoryPatch: CTerrorPlayer::TransitionRestore::RestoreByUserId");
}

void vSetupDetours(GameData hGameData = null)
{
	g_dDetourRestart = DynamicDetour.FromConf(hGameData, "Detour_CDirector::Restart");
	if(!g_dDetourRestart)
		SetFailState("Failed to create DynamicDetour: Detour_CDirector::Restart");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "Detour_CTerrorPlayer::TransitionRestore");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: Detour_CTerrorPlayer::TransitionRestore");
		
	if(!dDetour.Enable(Hook_Pre, mreTransitionRestorePre))
		SetFailState("Failed to detour pre: Detour_CTerrorPlayer::TransitionRestore");

	if(!dDetour.Enable(Hook_Post, mreTransitionRestorePost))
		SetFailState("Failed to detour post: Detour_CTerrorPlayer::TransitionRestore");
}

MRESReturn mreRestartPre(Address pThis)
{
	g_bRestart = true;
	return MRES_Ignored;
}

MRESReturn mreRestartPost(Address pThis)
{
	g_bRestart = false;
	return MRES_Ignored;
}

MRESReturn mreTransitionRestorePre(int pThis)
{
	if(IsFakeClient(pThis))
		return MRES_Ignored;

	Address pSavedData = pFindSavedDataByUserId(GetClientUserId(pThis));
	if(!pSavedData)
		return MRES_Ignored;

	if(g_bRestart && GetClientTeam(pThis) == 2)
	{
		char sCharacter[4];
		char sModelName[PLATFORM_MAX_PATH];
		SDKCall(g_hSDKKVGetString, pSavedData, sCharacter, sizeof sCharacter, "character", "");
		SDKCall(g_hSDKKVGetString, pSavedData, sModelName, sizeof sModelName, "modelName", "");
		if(sCharacter[0] != '\0' && sModelName[0] != '\0')
		{
			strcopy(g_esSavedData.character, sizeof PlayerSaveData::character, sCharacter);
			strcopy(g_esSavedData.modelName, sizeof PlayerSaveData::modelName, sModelName);

			IntToString(GetEntProp(pThis, Prop_Send, "m_survivorCharacter"), sCharacter, sizeof sCharacter);
			SDKCall(g_hSDKKVSetString, pSavedData, "character", sCharacter);

			GetEntPropString(pThis, Prop_Data, "m_ModelName", sModelName, sizeof sModelName);
			SDKCall(g_hSDKKVSetString, pSavedData, "modelName", sModelName);
		}
	}

	g_mpRestoreByUserId.Enable();
	return MRES_Ignored;
}

MRESReturn mreTransitionRestorePost(int pThis)
{
	if(g_esSavedData.character[0] != '\0' && g_esSavedData.modelName[0] != '\0')
	{
		Address pSavedData = pFindSavedDataByUserId(GetClientUserId(pThis));
		if(pSavedData)
		{
			SDKCall(g_hSDKKVSetString, pSavedData, "character", g_esSavedData.character);
			SDKCall(g_hSDKKVSetString, pSavedData, "modelName", g_esSavedData.modelName);
		}
	}

	g_esSavedData.character[0] = '\0';
	g_esSavedData.modelName[0] = '\0';
	g_mpRestoreByUserId.Disable();
	return MRES_Ignored;
}

// 读取玩家过关时保存的userID
Address pFindSavedDataByUserId(int userid)
{
	int iSavedPlayerCount = LoadFromAddress(g_pSavedPlayerCount, NumberType_Int32);
	if(!iSavedPlayerCount)
		return Address_Null;

	Address pSavedPlayers = view_as<Address>(LoadFromAddress(g_pSavedPlayerCount + view_as<Address>(4), NumberType_Int32));
	if(!pSavedPlayers)
		return Address_Null;

	Address pThis;
	char sUserId[16];
	for(int i; i < iSavedPlayerCount; i++)
	{
		pThis = view_as<Address>(LoadFromAddress(pSavedPlayers + view_as<Address>(4 * i), NumberType_Int32));
		if(!pThis)
			continue;

		SDKCall(g_hSDKKVGetString, pThis, sUserId, sizeof sUserId, "userID", "");
		if(sUserId[0] != '\0' && StringToInt(sUserId) == userid)
			return pThis;
	}

	return Address_Null;
}
