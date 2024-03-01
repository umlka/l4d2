#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_NAME				"Fallen Survivor Item Control"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"Fallen survivor item control"
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				"https://steamcommunity.com/id/sorallll"

#define GAMEDATA				"fallen_survivor_item_control"
#define CVAR_FLAGS 				FCVAR_NOTIFY

ConVar
	g_cFallenSurvivorItem;

int
	g_iFallenSurvivorItem;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitData();

	CreateConVar("fallen_survivor_item_control_version", PLUGIN_VERSION, "Fallen Survivor Item Control plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cFallenSurvivorItem = CreateConVar("fallen_survivor_item", "15", "0=None, 1=Molotov, 2=PipeBomb, 4=PainPills, 8=FirstAidKit, 15=All. Add numbers together.", CVAR_FLAGS);
	g_cFallenSurvivorItem.AddChangeHook(CvarChanged);
	AutoExecConfig(true);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_iFallenSurvivorItem = g_cFallenSurvivorItem.IntValue;
}

void InitData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::Infected::Spawn");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::Infected::Spawn\"");

	if (!dDetour.Enable(Hook_Post, DD_Infected_Spawn_Post))
		SetFailState("Failed to detour post: \"DD::Infected::Spawn\"");

	delete hGameData;
}

MRESReturn DD_Infected_Spawn_Post(int pThis, DHookReturn hReturn) {
	if (GetEntProp(pThis, Prop_Send, "m_Gender") == 14)
		SetEntProp(pThis, Prop_Send, "m_nFallenFlags", g_iFallenSurvivorItem);

	return MRES_Ignored;
}
