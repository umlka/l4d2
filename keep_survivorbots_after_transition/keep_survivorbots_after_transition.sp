#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

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
	description = "",
	version = "1.0.2",
	url = "https://forums.alliedmods.net/showthread.php?t=336245"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vLoadGameData();

	if(g_bLateLoad)
		vMaxRestoreSurvivorBotsPatch(true);
}

public void OnPluginEnd()
{
	vMaxRestoreSurvivorBotsPatch(false);
}

public void OnMapEnd()
{
	vMaxRestoreSurvivorBotsPatch(true);
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

	g_bWindowsOS = hGameData.GetOffset("OS") == 0;

	g_pSavedSurvivorBotCount = hGameData.GetAddress("SavedSurvivorBotCount");
	if(!g_pSavedSurvivorBotCount)
		SetFailState("Failed to find address: SavedSurvivorBotCount");

	vRegisterMaxRestoreSurvivorBotsPatch(hGameData);

	delete hGameData;
}

void vRegisterMaxRestoreSurvivorBotsPatch(GameData hGameData = null)
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

void vMaxRestoreSurvivorBotsPatch(bool bPatch)
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
