#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define GAMEDATA	"transition_restore_fix"

Address
	g_pSavedPlayerCount;

Handle
	g_hSDKKeyValuesGetString,
	g_hSDKKeyValuesSetString;

MemoryPatch
	g_mpRestoreByUserId;

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
}

public void OnPluginEnd()
{
	g_mpRestoreByUserId.Disable();
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
	g_hSDKKeyValuesGetString = EndPrepSDKCall();
	if(!g_hSDKKeyValuesGetString)
		SetFailState("Failed to create SDKCall: KeyValues::GetString");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString"))
		SetFailState("Failed to find signature: KeyValues::SetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDKKeyValuesSetString = EndPrepSDKCall();
	if(!g_hSDKKeyValuesSetString)
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
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "Detour_CDirector::Restart");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: Detour_CDirector::Restart");
		
	if(!dDetour.Enable(Hook_Pre, mreRestartPre))
		SetFailState("Failed to detour pre: Detour_CDirector::Restart");

	if(!dDetour.Enable(Hook_Post, mreRestartPost))
		SetFailState("Failed to detour post: Detour_CDirector::Restart");

	dDetour = DynamicDetour.FromConf(hGameData, "Detour_CTerrorPlayer::TransitionRestore");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: Detour_CTerrorPlayer::TransitionRestore");
		
	if(!dDetour.Enable(Hook_Pre, mreTransitionRestorePre))
		SetFailState("Failed to detour pre: Detour_CTerrorPlayer::TransitionRestore");

	if(!dDetour.Enable(Hook_Post, mreTransitionRestorePost))
		SetFailState("Failed to detour post: Detour_CTerrorPlayer::TransitionRestore");
}

bool g_bRestart;
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

char g_sSavedCharacter[16];
char g_sSavedModelName[PLATFORM_MAX_PATH];
MRESReturn mreTransitionRestorePre(int pThis)
{
	if(IsFakeClient(pThis))
		return MRES_Ignored;

	Address pSavedData = pFindSavedDataByUserId(GetClientUserId(pThis));
	if(!pSavedData)
		return MRES_Ignored;

	if(g_bRestart && GetClientTeam(pThis) == 2)
	{
		char sCharacter[16];
		char sModelName[PLATFORM_MAX_PATH];
		SDKCall(g_hSDKKeyValuesGetString, pSavedData, sCharacter, sizeof sCharacter, "character", "N/A");
		SDKCall(g_hSDKKeyValuesGetString, pSavedData, sModelName, sizeof sModelName, "modelName", "N/A");
		if(strcmp(sCharacter, "N/A") != 0 && strcmp(sModelName, "N/A") != 0)
		{
			strcopy(g_sSavedCharacter, sizeof g_sSavedCharacter, sCharacter);
			strcopy(g_sSavedModelName, sizeof g_sSavedModelName, sModelName);
	
			IntToString(GetEntProp(pThis, Prop_Send, "m_survivorCharacter"), sCharacter, sizeof sCharacter);
			SDKCall(g_hSDKKeyValuesSetString, pSavedData, "character", sCharacter);

			GetEntPropString(pThis, Prop_Data, "m_ModelName", sModelName, sizeof sModelName);
			SDKCall(g_hSDKKeyValuesSetString, pSavedData, "modelName", sModelName);
		}
	}

	g_mpRestoreByUserId.Enable();
	return MRES_Ignored;
}

MRESReturn mreTransitionRestorePost(int pThis)
{
	if(g_bRestart && g_sSavedCharacter[0] != '\0' && g_sSavedModelName[0] != '\0')
	{
		Address pSavedData = pFindSavedDataByUserId(GetClientUserId(pThis));
		if(!pSavedData)
		{
			SDKCall(g_hSDKKeyValuesSetString, pSavedData, "character", g_sSavedCharacter);
			SDKCall(g_hSDKKeyValuesSetString, pSavedData, "modelName", g_sSavedModelName);
		}
	}

	g_sSavedCharacter[0] = '\0';
	g_sSavedModelName[0] = '\0';
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

		SDKCall(g_hSDKKeyValuesGetString, pThis, sUserId, sizeof sUserId, "userID", "N/A");
		if(strcmp(sUserId, "N/A") != 0 && StringToInt(sUserId) == userid)
			return pThis;
	}

	return Address_Null;
}