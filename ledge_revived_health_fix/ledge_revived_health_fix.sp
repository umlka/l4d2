#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_NAME				"Ledge Revived Health Fix"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

#define GAMEDATA				"ledge_revived_health_fix"

ConVar
	g_cvSurvivorIncapH,
	g_cvSurvivorLedgeG;

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

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::OnRevived");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::OnRevived\"");

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_OnRevived_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::OnRevived\"");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_OnRevived_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::OnRevived\"");

	delete hGameData;

	CreateConVar("ledge_revived_health_fix_version", PLUGIN_VERSION, "Ledge Revived Health Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvSurvivorIncapH = FindConVar("survivor_incap_health");
	g_cvSurvivorLedgeG = FindConVar("survivor_ledge_grab_health");
}

int g_iTempValue = -1;
MRESReturn DD_CTerrorPlayer_OnRevived_Pre(int pThis, DHookReturn hReturn) {
	if (pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis))
		return MRES_Ignored;

	if (GetClientTeam(pThis) != 2 || !IsPlayerAlive(pThis) || GetEntProp(pThis, Prop_Send, "m_isHangingFromLedge", 1) != 1)
		return MRES_Ignored;

	g_iTempValue = g_cvSurvivorIncapH.IntValue;
	g_cvSurvivorIncapH.IntValue = g_cvSurvivorLedgeG.IntValue;

	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_OnRevived_Post(int pThis, DHookReturn hReturn) {
	if (g_iTempValue != -1) {
		g_cvSurvivorIncapH.IntValue = g_iTempValue;
		g_iTempValue = -1;
	}

	return MRES_Ignored;
}