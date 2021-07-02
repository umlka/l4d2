#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define GAMEDATA	"transitionzombiespawnfix"

DynamicDetour g_dDetour[2];

public Plugin myinfo = 
{
	name = "Transition Zombie Spawn Fix",
	author = "sorallll",
	description = "",
	version = "1.0.0",
	url = "https://steamcommunity.com/id/sorallll"
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
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
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
		SetFailState("Failed to load signature: ZombieManager::CanZombieSpawnHere");
		
	if(!g_dDetour[0].Enable(Hook_Pre, mreCanZombieSpawnHerePre))
		SetFailState("Failed to detour pre: ZombieManager::CanZombieSpawnHere");
		
	if(!g_dDetour[0].Enable(Hook_Post, mreCanZombieSpawnHerePost))
		SetFailState("Failed to detour post: ZombieManager::CanZombieSpawnHere");

	g_dDetour[1] = DynamicDetour.FromConf(hGameData, "CDirector::IsInTransition");
	if(g_dDetour[1] == null)
		SetFailState("Failed to load signature: CDirector::IsInTransition");

	if(!g_dDetour[1].Enable(Hook_Post, mreIsInTransitionPost))
		SetFailState("Failed to detour post: CDirector::IsInTransition");
}

void vDisableDetours()
{
	if(!g_dDetour[0].Enable(Hook_Pre, mreCanZombieSpawnHerePre) || !g_dDetour[0].Disable(Hook_Post, mreCanZombieSpawnHerePost))
		SetFailState("Failed to disable detour: ZombieManager::CanZombieSpawnHere");

	if(!g_dDetour[1].Disable(Hook_Post, mreIsInTransitionPost))
		SetFailState("Failed to disable detour: CDirector::IsInTransition");
}

bool g_bCanZombieSpawnHere;
public MRESReturn mreCanZombieSpawnHerePre()
{
	g_bCanZombieSpawnHere = true;
	return MRES_Ignored;
}

public MRESReturn mreCanZombieSpawnHerePost()
{
	g_bCanZombieSpawnHere = false;
	return MRES_Ignored;
}

public MRESReturn mreIsInTransitionPost(DHookReturn hReturn)
{
	if(g_bCanZombieSpawnHere)
	{
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}