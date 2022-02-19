#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define GAMEDATA	"keep_survivorbots_after_transition"

Address
	g_pSavedSurvivorBotCount,
	g_pMaxRestoreSurvivorBots;

int
	g_iOffOrigin;

bool
	g_bLateLoad,
	g_bWindowsOS;

public Plugin myinfo = 
{
	name = "Keep SurvivorBots After Transition",
	author = "sorallll",
	description = "4 + Survivor Bots will no longer disappear after the transition",
	version = "1.0.3",
	url = "https://forums.alliedmods.net/showthread.php?t=336245"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vInitGameData();

	if(g_bLateLoad)
		vPatch(true);
}

public void OnPluginEnd()
{
	vPatch(false);
}

public void OnMapStart()
{
	vPatch(true);
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

	g_bWindowsOS = hGameData.GetOffset("OS") == 0;

	g_pSavedSurvivorBotCount = hGameData.GetAddress("SavedSurvivorBotCount");
	if(!g_pSavedSurvivorBotCount)
		SetFailState("Failed to find address: SavedSurvivorBotCount");

	vInitPatch(hGameData);

	delete hGameData;
}

void vInitPatch(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("MaxRestoreSurvivorBots_Offset");
	if(iOffset == -1)
		SetFailState("Failed to find offset: MaxRestoreSurvivorBots_Offset");

	int iByteMatch = hGameData.GetOffset("MaxRestoreSurvivorBots_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to find byte: MaxRestoreSurvivorBots_Byte");

	g_pMaxRestoreSurvivorBots = hGameData.GetAddress("MaxRestoreSurvivorBots");
	if(!g_pMaxRestoreSurvivorBots)
		SetFailState("Failed to find address: MaxRestoreSurvivorBots");
	
	g_pMaxRestoreSurvivorBots += view_as<Address>(iOffset);
	
	int iByteOrigin = LoadFromAddress(g_pMaxRestoreSurvivorBots, NumberType_Int8);
	if(iByteOrigin != iByteMatch)
		SetFailState("Failed to load 'MaxRestoreSurvivorBots', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);

	g_iOffOrigin = hGameData.GetOffset("MaxRestoreSurvivorBots_Origin");
	if(g_iOffOrigin == -1)
		SetFailState("Failed to find offset: MaxRestoreSurvivorBots_Origin");
}

void vPatch(bool bPatch)
{
	switch(bPatch)
	{
		case true:
		{
			int iSavedSurvivorBotCount = LoadFromAddress(g_pSavedSurvivorBotCount, NumberType_Int32);
			StoreToAddress(g_pMaxRestoreSurvivorBots + view_as<Address>(2), iSavedSurvivorBotCount <= g_iOffOrigin ? g_iOffOrigin : (!g_bWindowsOS ? iSavedSurvivorBotCount : iSavedSurvivorBotCount + 1), NumberType_Int8);
		}

		case false:
			StoreToAddress(g_pMaxRestoreSurvivorBots + view_as<Address>(2), g_iOffOrigin, NumberType_Int8);
	}
}