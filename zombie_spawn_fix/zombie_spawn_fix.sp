#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA "zombie_spawn_fix"

ArrayStack
	g_aMemPatches;

static const char g_sPatchNames[][] =
	{
		"ZombieManager::CanZombieSpawnHere::IsInTransitionCheck",
		"CTerrorPlayer::OnPreThinkGhostState::IsInTransitionCheck",
		"CTerrorPlayer::OnPreThinkGhostState::SpawnDisabledCheck",
		"ZombieManager::AccumulateSpawnAreaCollection::EnforceFinaleNavSpawnRulesCheck"
	};

// some code from [L4D2] Air Ability Patch (https://forums.alliedmods.net/showthread.php?p=2660278)
public Plugin myinfo = 
{
	name = "[L4D2]Zombie Spawn Fix",
	author = "sorallll & Psyk0tik (Crasher_3637)",
	description = "Fixed Special Inected and Player Zombie spawning failures in some cases",
	version = "1.0.5",
	url = "https://forums.alliedmods.net/showthread.php?t=333351"
};

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	MemoryPatch mpPatch;
	g_aMemPatches = new ArrayStack();
	for(int i; i < sizeof g_sPatchNames; i++)
	{
		mpPatch = MemoryPatch.CreateFromConf(hGameData, g_sPatchNames[i]);
		if(!mpPatch)
			SetFailState("Failed to create MemoryPatch: \"%s\"", g_sPatchNames[i]);

		if(!mpPatch.Validate())
			SetFailState("Failed to validate MemoryPatch: \"%s\"", g_sPatchNames[i]);

		mpPatch.Enable();
		g_aMemPatches.Push(mpPatch);
	}

	delete hGameData;
}

public void OnPluginEnd()
{
	MemoryPatch mpPatch;
	while(!g_aMemPatches.Empty)
	{
		mpPatch = g_aMemPatches.Pop();
		mpPatch.Disable();
	}
}