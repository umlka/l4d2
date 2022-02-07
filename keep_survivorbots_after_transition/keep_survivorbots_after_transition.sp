#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define GAMEDATA	"keep_survivorbots_after_transition"

Address
	g_pMaxRestoreSurvivorBots;

int
	g_iOffOrigin;

bool
	g_bLinuxOS,
	g_bLateLoad;

public Plugin myinfo = 
{
	name = "Keep SurvivorBots After Transition",
	author = "sorallll",
	description = "",
	version = "1.0.0",
	url = ""
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

public void OnMapStart()
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

	g_bLinuxOS = hGameData.GetOffset("OS") == 1;

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
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	Address pSavedSurvivorBotCount = hGameData.GetAddress("SavedSurvivorBotCount");
	if(pSavedSurvivorBotCount == Address_Null)
		SetFailState("Failed to find address: SavedSurvivorBotCount");

	switch(bPatch)
	{
		case true:
		{
			int iSavedSurvivorBotCount = LoadFromAddress(pSavedSurvivorBotCount, NumberType_Int32);
			StoreToAddress(g_pMaxRestoreSurvivorBots + view_as<Address>(2), iSavedSurvivorBotCount <= g_iOffOrigin ? g_iOffOrigin : (!g_bLinuxOS ? iSavedSurvivorBotCount + 1 : iSavedSurvivorBotCount), NumberType_Int8);
		}

		case false:
			StoreToAddress(g_pMaxRestoreSurvivorBots + view_as<Address>(2), g_iOffOrigin, NumberType_Int8);
	}

	delete hGameData;
}
