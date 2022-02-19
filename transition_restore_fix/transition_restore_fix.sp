#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define GAMEDATA	"transition_restore_fix"

Address
	//g_pSavedPlayers,
	g_pSavedPlayerCount;

Handle
	g_hSDKKeyValuesGetInt;

MemoryPatch
	g_mpRestoreByUserId;

ConVar
	g_hRestartRestoreUid;

bool
	g_bRestartRestoreUid;

int
	g_iRoundEnd;

public Plugin myinfo = 
{
	name = "Transition Restore Fix",
	author = "sorallll",
	description = "Restoring transition data by player's UserId instead of character",
	version = "1.1.1",
	url = "https://forums.alliedmods.net/showthread.php?t=336287"
};

public void OnPluginStart()
{
	vInitGameData();

	g_hRestartRestoreUid = CreateConVar("restart_restore_by_userid", "0", "Restore data by player's UserId after mission lost?", FCVAR_NOTIFY);
	g_hRestartRestoreUid.AddChangeHook(vConVarChanged);

	AutoExecConfig(true, "transition_restore_fix");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
	g_mpRestoreByUserId.Disable();
}

public void OnConfigsExecuted()
{
	g_bRestartRestoreUid = g_hRestartRestoreUid.BoolValue;
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bRestartRestoreUid = g_hRestartRestoreUid.BoolValue;
}

public void OnMapEnd()
{
	g_iRoundEnd = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundEnd++;
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

	/**g_pSavedPlayers = hGameData.GetAddress("g_SavedPlayers");
	if(!g_pSavedPlayers)
		SetFailState("Failed to find address: g_SavedPlayers");*/

	g_pSavedPlayerCount = hGameData.GetAddress("SavedPlayerCount");
	if(!g_pSavedPlayerCount)
		SetFailState("Failed to find address: SavedPlayerCount");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetInt"))
		SetFailState("Failed to find signature: KeyValues::GetInt");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKKeyValuesGetInt = EndPrepSDKCall();
	if(!g_hSDKKeyValuesGetInt)
		SetFailState("Failed to create SDKCall: KeyValues::GetInt");

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
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "Detour_CTerrorPlayer::TransitionRestore");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: Detour_CTerrorPlayer::TransitionRestore");
		
	if(!dDetour.Enable(Hook_Pre, mreTransitionRestorePre))
		SetFailState("Failed to detour pre: Detour_CTerrorPlayer::TransitionRestore");

	if(!dDetour.Enable(Hook_Post, mreTransitionRestorePost))
		SetFailState("Failed to detour post: Detour_CTerrorPlayer::TransitionRestore");
}

MRESReturn mreTransitionRestorePre(int pThis)
{
	if(!g_bRestartRestoreUid && g_iRoundEnd)
		return MRES_Ignored;

	if(IsFakeClient(pThis) || !bPlayerSavedData(GetClientUserId(pThis)))
		return MRES_Ignored;

	g_mpRestoreByUserId.Enable();
	return MRES_Ignored;
}

MRESReturn mreTransitionRestorePost(int pThis)
{
	g_mpRestoreByUserId.Disable();
	return MRES_Ignored;
}

// 读取玩家过关时保存的userID
bool bPlayerSavedData(int userid)
{
	int iSavedPlayerCount = LoadFromAddress(g_pSavedPlayerCount, NumberType_Int32);
	if(!iSavedPlayerCount)
		return false;

	Address pSavedPlayers = view_as<Address>(LoadFromAddress(g_pSavedPlayerCount + view_as<Address>(4)/*g_pSavedPlayers*/, NumberType_Int32));
	if(!pSavedPlayers)
		return false;

	Address pThis;
	for(int i; i < iSavedPlayerCount; i++)
	{
		pThis = view_as<Address>(LoadFromAddress(pSavedPlayers + view_as<Address>(4 * i), NumberType_Int32));
		if(!pThis)
			continue;

		if(SDKCall(g_hSDKKeyValuesGetInt, pThis, "userID", 0) == userid)
			return true;
	}

	return false;
}
