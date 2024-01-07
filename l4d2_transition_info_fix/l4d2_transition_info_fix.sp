/*====================================================
1.0
	- Initial release
======================================================*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_NAME				"Transition Info Fix"
#define PLUGIN_AUTHOR			"IA/NanaNana"
#define PLUGIN_DESCRIPTION		"Fix the transition info bug"
#define PLUGIN_VERSION			"1.0"
#define PLUGIN_URL				"http://steamcommunity.com/profiles/76561198291983872"

#define GAMEDATA				"l4d2_transition_info_fix"

Handle
	g_hSDK_CDirector_OnServerShutdown;

Address
	g_pDirector;

bool
	g_bIsVersus,
	g_bTransition;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::OnServerShutdown"))
		SetFailState("Failed to find signature: \"CDirector::OnServerShutdown\"");
	if (!(g_hSDK_CDirector_OnServerShutdown = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::OnServerShutdown\"");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::InfoChangelevel::ChangeLevelNow");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::InfoChangelevel::ChangeLevelNow\"");

	if (!dDetour.Enable(Hook_Post, DD_InfoChangelevel_ChangeLevelNow_Post))
		SetFailState("Failed to detour post: \"DD::InfoChangelevel::ChangeLevelNow\"");

	delete hGameData;

	HookEntityOutput("info_gamemode", "OnCoop", OnGamemode);
	HookEntityOutput("info_gamemode", "OnVersus", OnGamemode);
	HookEntityOutput("info_gamemode", "OnSurvival", OnGamemode);
	HookEntityOutput("info_gamemode", "OnScavenge", OnGamemode);
}

void OnGamemode(const char[] output, int caller, int activator, float delay) {
	g_bIsVersus = strcmp(output, "OnVersus") == 0;
}

MRESReturn DD_InfoChangelevel_ChangeLevelNow_Post(Address pThis) {
	g_bTransition = true;
	return MRES_Ignored;
}

public void OnMapEnd() {
	if (!g_bIsVersus && !g_bTransition)
		SDKCall(g_hSDK_CDirector_OnServerShutdown, g_pDirector);

	g_bTransition = false;
}