#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define GAMEDATA	"transition_restore_fix"

MemoryPatch
	g_mpRestoreState,
	g_mpRestoreByUserId;

DynamicHook
	g_dBeginChangeLevel;

ArrayList
	g_aSavedPlayers;

ConVar
	g_hRestartRestoreUid;

int
	g_iRoundEnd;

bool
	g_bLateLoad,
	g_bTransitionStart,
	g_bRestartRestoreUid;

char
	g_sTargetMap[64];

public Plugin myinfo = 
{
	name = "Transition Restore Fix",
	author = "sorallll",
	description = "Restoring transition data by player's UserId instead of character",
	version = "1.0.9",
	url = "https://forums.alliedmods.net/showthread.php?t=336287"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vLoadGameData();
	g_mpRestoreState.Enable();

	g_aSavedPlayers = new ArrayList();

	g_hRestartRestoreUid = CreateConVar("restart_restore_by_userid", "0", "Restore data by player's UserId after mission lost?", FCVAR_NOTIFY);
	g_hRestartRestoreUid.AddChangeHook(vConVarChanged);

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	if(g_bLateLoad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

public void OnPluginEnd()
{
	g_mpRestoreState.Disable();
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

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
		g_dBeginChangeLevel.HookEntity(Hook_Post, client, mreOnBeginChangeLevelPost);
}

public void OnMapStart()
{
	char sMap[64];
	GetCurrentMap(sMap, sizeof sMap);
	if(strcmp(sMap, g_sTargetMap, false) != 0)
		g_aSavedPlayers.Clear();

	g_sTargetMap[0] = '\0';
	g_bTransitionStart = false;
}

public void OnMapEnd()
{
	g_iRoundEnd = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundEnd++;
}

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_mpRestoreState = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::OnEndChangeLevel::restoreState");
	if(!g_mpRestoreState)
		SetFailState("Failed to create MemoryPatch: CTerrorPlayer::OnEndChangeLevel::restoreState");

	if(!g_mpRestoreState.Validate())
		SetFailState("Failed to validate MemoryPatch: CTerrorPlayer::OnEndChangeLevel::restoreState");

	g_mpRestoreByUserId = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::TransitionRestore::RestoreByUserId");
	if(!g_mpRestoreByUserId)
		SetFailState("Failed to create MemoryPatch: CTerrorPlayer::TransitionRestore::RestoreByUserId");

	if(!g_mpRestoreByUserId.Validate())
		SetFailState("Failed to validate MemoryPatch: CTerrorPlayer::TransitionRestore::RestoreByUserId");

	vSetupHooks(hGameData);
	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupHooks(GameData hGameData = null)
{
	g_dBeginChangeLevel = DynamicHook.FromConf(hGameData, "Hooks_CTerrorPlayer::OnBeginChangeLevel");
	if(!g_dBeginChangeLevel)
		SetFailState("Failed to create DynamicHook: Hooks_CTerrorPlayer::OnBeginChangeLevel");
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

MRESReturn mreOnBeginChangeLevelPost(int pThis, DHookParam hParams)
{
	if(!g_bTransitionStart)
	{
		g_aSavedPlayers.Clear();
		g_bTransitionStart = true;
		hParams.GetString(1, g_sTargetMap, sizeof g_sTargetMap);
	}

	if(GetClientTeam(pThis) != 2)
		return MRES_Ignored;

	g_aSavedPlayers.Push(GetClientUserId(pThis));
	return MRES_Ignored;
}

MRESReturn mreTransitionRestorePre(int pThis)
{
	if(!g_bRestartRestoreUid && g_iRoundEnd)
		return MRES_Ignored;

	if(IsFakeClient(pThis) || g_aSavedPlayers.FindValue(GetClientUserId(pThis)) == -1)
		g_mpRestoreByUserId.Disable();
	else
		g_mpRestoreByUserId.Enable();

	return MRES_Ignored;
}

MRESReturn mreTransitionRestorePost(int pThis)
{
	g_mpRestoreByUserId.Disable();
	return MRES_Ignored;
}