#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define GAMEDATA "transitionzombiespawnfix"

DynamicDetour
	g_dDetour[3];

bool
	g_bCanZombieSpawnHere;

public Plugin myinfo = 
{
	name = "[L4D2]Transition Zombie Spawn Fix",
	author = "sorallll & Psyk0tik (Crasher_3637)",
	description = "To Fix z_spawn_old/ZombieManager::GetRandomPZSpawnPosition spawn SI failed during player transition(\"could not find a XX spawn position in 5 tries\")",
	version = "1.0.2",
	url = "https://forums.alliedmods.net/showthread.php?t=333351"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "This plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	vLoadGameData();
}

public void OnPluginEnd()
{
	vDisableDetours();
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

	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDetours(GameData hGameData = null)
{
	g_dDetour[0] = DynamicDetour.FromConf(hGameData, "ZombieManager::CanZombieSpawnHere");
	if(g_dDetour[0] == null)
		SetFailState("Failed to create DynamicDetour: ZombieManager::CanZombieSpawnHere");
		
	if(!g_dDetour[0].Enable(Hook_Pre, mreCanZombieSpawnHerePre))
		SetFailState("Failed to detour pre: ZombieManager::CanZombieSpawnHere");
		
	if(!g_dDetour[0].Enable(Hook_Post, mreCanZombieSpawnHerePost))
		SetFailState("Failed to detour post: ZombieManager::CanZombieSpawnHere");

	g_dDetour[1] = DynamicDetour.FromConf(hGameData, "CDirector::IsInTransition");
	if(g_dDetour[1] == null)
		SetFailState("Failed to create DynamicDetour: CDirector::IsInTransition");

	if(!g_dDetour[1].Enable(Hook_Post, mreIsInTransitionPost))
		SetFailState("Failed to detour post: CDirector::IsInTransition");

	g_dDetour[2] = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::OnPreThinkGhostState");
	if(g_dDetour[2] == null)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::OnPreThinkGhostState");
		
	if(!g_dDetour[2].Enable(Hook_Pre, mreOnPreThinkGhostStatePre))
		SetFailState("Failed to detour pre: CTerrorPlayer::OnPreThinkGhostState");
		
	if(!g_dDetour[2].Enable(Hook_Post, mreOnPreThinkGhostStatePost))
		SetFailState("Failed to detour post: CTerrorPlayer::OnPreThinkGhostState");
}

void vDisableDetours()
{
	if(!g_dDetour[0].Disable(Hook_Pre, mreCanZombieSpawnHerePre) || !g_dDetour[0].Disable(Hook_Post, mreCanZombieSpawnHerePost))
		SetFailState("Failed to disable detour: ZombieManager::CanZombieSpawnHere");

	if(!g_dDetour[1].Disable(Hook_Post, mreIsInTransitionPost))
		SetFailState("Failed to disable detour: CDirector::IsInTransition");

	if(!g_dDetour[2].Disable(Hook_Pre, mreOnPreThinkGhostStatePre) || !g_dDetour[2].Disable(Hook_Post, mreOnPreThinkGhostStatePost))
		SetFailState("Failed to disable detour: CTerrorPlayer::OnPreThinkGhostState");
}

MRESReturn mreCanZombieSpawnHerePre(DHookReturn hReturn, DHookParam hParams)
{
	g_bCanZombieSpawnHere = true;
	return MRES_Ignored;
}

MRESReturn mreCanZombieSpawnHerePost(DHookReturn hReturn, DHookParam hParams)
{
	g_bCanZombieSpawnHere = false;
	return MRES_Ignored;
}

MRESReturn mreIsInTransitionPost(Address pThis, DHookReturn hReturn)
{
	if(g_bCanZombieSpawnHere)
	{
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn mreOnPreThinkGhostStatePre(int pThis)
{
	g_bCanZombieSpawnHere = true;
	return MRES_Ignored;
}

MRESReturn mreOnPreThinkGhostStatePost(int pThis)
{
	g_bCanZombieSpawnHere = false;
	return MRES_Ignored;
}
