#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define PLUGIN_NAME				"Incapacitated Revive"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

#define GAMEDATA				"incapacitated_revive"

ConVar
	g_cvSurvivorIncapD,
	g_cvIncapacitatedRevive;

float
	g_fIncapacitatedRevive;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitGameData();
	CreateConVar("incapacitated_revive_version", PLUGIN_VERSION, "Incapacitated Revive plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvIncapacitatedRevive = CreateConVar("incapacitated_revive_increase", "10.0", "根据当前倒地次数增加额外的倒地扣血速率", FCVAR_NOTIFY, true, 0.0);
	g_cvSurvivorIncapD = FindConVar("survivor_incap_decay_rate");
	g_cvSurvivorIncapD.Flags &= ~FCVAR_NOTIFY;
	g_cvIncapacitatedRevive.AddChangeHook(CvarChanged);

	HookEvent("witch_killed",	Event_WitchKilled);
	HookEvent("player_death",	Event_PlayerDeath);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fIncapacitatedRevive = g_cvIncapacitatedRevive.FloatValue;
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (!IsPlayerAlive(client) || !GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
		return;

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) || L4D2_GetInfectedAttacker(client) != -1)
		return;

	L4D_ReviveSurvivor(client);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	if (!IsPlayerAlive(attacker) || !GetEntProp(attacker, Prop_Send, "m_isIncapacitated", 1))
		return;

	if (GetEntProp(attacker, Prop_Send, "m_isHangingFromLedge", 1) || L4D2_GetInfectedAttacker(attacker) != -1)
		return;

	L4D_ReviveSurvivor(attacker);
}

void InitGameData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::UpdateIncapacitatedAndRevival");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::UpdateIncapacitatedAndRevival\"");

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_UpdateIncapacitatedAndRevival_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::UpdateIncapacitatedAndRevival\"");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_UpdateIncapacitatedAndRevival_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::UpdateIncapacitatedAndRevival\"");

	delete hGameData;
}

float g_fTempValue = -1.0;
MRESReturn DD_CTerrorPlayer_UpdateIncapacitatedAndRevival_Pre(int pThis, DHookReturn hReturn) {
	if (GetClientTeam(pThis) != 2 || !IsPlayerAlive(pThis))
		return MRES_Ignored;

	if (GetEntProp(pThis, Prop_Send, "m_isHangingFromLedge", 1) || GetEntPropEnt(pThis, Prop_Send, "m_tongueOwner") != -1)
		return MRES_Ignored;

	g_fTempValue = g_cvSurvivorIncapD.FloatValue;
	g_cvSurvivorIncapD.FloatValue = g_fTempValue + GetEntProp(pThis, Prop_Send, "m_currentReviveCount") * g_fIncapacitatedRevive;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_UpdateIncapacitatedAndRevival_Post(int pThis, DHookReturn hReturn) {
	if (g_fTempValue != -1.0) {
		g_cvSurvivorIncapD.FloatValue = g_fTempValue;
		g_fTempValue = -1.0;
	}

	return MRES_Ignored;
}