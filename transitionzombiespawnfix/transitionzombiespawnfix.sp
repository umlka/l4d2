#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>
#include <dhooks>
#include <left4dhooks>

#define GAMEDATA "transitionzombiespawnfix"

ArrayStack
	g_aMemPatches;

Address
	g_pScriptedEventManager;

bool
	g_bLateLoad,
	g_bShouldFix,
	g_bIsFinaleMap;

// some code from [L4D2] Air Ability Patch (https://forums.alliedmods.net/showthread.php?p=2660278)
public Plugin myinfo = 
{
	name = "[L4D2]Transition Zombie Spawn Fix",
	author = "sorallll & Psyk0tik (Crasher_3637)",
	description = "To Fix z_spawn_old/ZombieManager::GetRandomPZSpawnPosition spawn SI failed during player transition(\"could not find a XX spawn position in 5 tries\")",
	version = "1.0.4",
	url = "https://forums.alliedmods.net/showthread.php?t=333351"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	static const char sPatchNames[][] =
	{
		"ZombieManager::CanZombieSpawnHere::IsInTransitionCheck",
		"CTerrorPlayer::OnPreThinkGhostState::IsInTransitionCheck",
		"CTerrorPlayer::OnPreThinkGhostState::SpawnDisabledCheck"
	};

	MemoryPatch mpPatch;
	g_aMemPatches = new ArrayStack();
	for(int i; i < sizeof sPatchNames; i++)
	{
		mpPatch = MemoryPatch.CreateFromConf(hGameData, sPatchNames[i]);
		if(!mpPatch)
			SetFailState("Failed to create MemoryPatch: \"%s\"", sPatchNames[i]);

		if(!mpPatch.Validate())
			SetFailState("Failed to validate MemoryPatch: \"%s\"", sPatchNames[i]);

		mpPatch.Enable();
		g_aMemPatches.Push(mpPatch);
	}

	vSetupDetours(hGameData);

	delete hGameData;

	if(g_bLateLoad)
		g_bIsFinaleMap = L4D_IsMissionFinalMap();
}

public void OnAllPluginsLoaded()
{
	g_pScriptedEventManager = L4D_GetPointer(POINTER_EVENTMANAGER);
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

public void OnMapStart()
{
	g_bIsFinaleMap = L4D_IsMissionFinalMap();
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::ZombieManager::GetRandomPZSpawnPosition");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: DD::ZombieManager::GetRandomPZSpawnPosition");
		
	if(!dDetour.Enable(Hook_Pre, DD_ZombieManager_GetRandomPZSpawnPosition_Pre))
		SetFailState("Failed to detour pre: DD::ZombieManager::GetRandomPZSpawnPosition");
		
	if(!dDetour.Enable(Hook_Post, DD_ZombieManager_GetRandomPZSpawnPosition_Post))
		SetFailState("Failed to detour post: DD::ZombieManager::GetRandomPZSpawnPosition");
}

int m_FinaleType;
MRESReturn DD_ZombieManager_GetRandomPZSpawnPosition_Pre(DHookReturn hReturn, DHookParam hParams)
{
	if(!g_bIsFinaleMap || bIsFinaleActive())
		return MRES_Ignored;

	m_FinaleType = LoadFromAddress(g_pScriptedEventManager, NumberType_Int32);
	if(m_FinaleType != 5)
		return MRES_Ignored;

	g_bShouldFix = true;
	StoreToAddress(g_pScriptedEventManager, 1, NumberType_Int32);
	return MRES_Ignored;
}

MRESReturn DD_ZombieManager_GetRandomPZSpawnPosition_Post(DHookReturn hReturn, DHookParam hParams)
{
	if(g_bShouldFix)
		StoreToAddress(g_pScriptedEventManager, m_FinaleType, NumberType_Int32);

	g_bShouldFix = false;
	return MRES_Ignored;
}

bool bIsFinaleActive()
{
	static int iPlayerResource = INVALID_ENT_REFERENCE;
	if(iPlayerResource == INVALID_ENT_REFERENCE || !IsValidEntity(iPlayerResource))
	{
		iPlayerResource = EntIndexToEntRef(GetPlayerResourceEntity());
		if(iPlayerResource == INVALID_ENT_REFERENCE || !IsValidEntity(iPlayerResource))
			return false;
	}

	return !!GetEntProp(iPlayerResource, Prop_Send, "m_isFinale", 1);
}