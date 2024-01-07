#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public Plugin myinfo = {
	name = "LerpTracker",
	author = "ProdigySim",
	description = "Keep track of players' lerp settings",
	version = "0.8",
	url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
};

ConVar
	g_hAnnounceLerp,
	g_hMaxLerpValue,
	g_hMinUpdateRate,
	g_hMaxUpdateRate,
	g_hMinInterpRatio,
	g_hMaxInterpRatio;

bool
	g_bLateLoad;

int
	g_iAnnounceLerp;

float
	g_fMaxLerpValue,
	g_fMinUpdateRate,
	g_fMaxUpdateRate,
	g_fMinInterpRatio,
	g_fMaxInterpRatio,
	g_fCurrentLerps[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	g_hAnnounceLerp = CreateConVar("sm_announce_lerp", "2", "Announce changes to client lerp. (1=Announce initial lerp and changes, 2=Announce changes only)");
	g_hMaxLerpValue = CreateConVar("sm_max_interp", "0.5", "Kick players whose settings breach this Hard upper-limit for player lerps.");

	g_hMinUpdateRate = FindConVar("sv_minupdaterate");
	g_hMaxUpdateRate = FindConVar("sv_maxupdaterate");
	g_hMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	g_hMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");

	g_hAnnounceLerp.AddChangeHook(ConVarChanged);
	g_hMaxLerpValue.AddChangeHook(ConVarChanged);
	g_hMinUpdateRate.AddChangeHook(ConVarChanged);
	g_hMaxUpdateRate.AddChangeHook(ConVarChanged);
	g_hMinInterpRatio.AddChangeHook(ConVarChanged);
	g_hMaxInterpRatio.AddChangeHook(ConVarChanged);

	RegConsoleCmd("sm_lerps", cmdLerps, "List the Lerps of all players in game");

	if (g_bLateLoad)
		ScanAllPlayersLerp();
}

public void OnConfigsExecuted() {
	GetCvars();
}

void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_iAnnounceLerp = g_hAnnounceLerp.IntValue;
	g_fMaxLerpValue = g_hMaxLerpValue.FloatValue;
	g_fMinUpdateRate = g_hMinUpdateRate.FloatValue;
	g_fMaxUpdateRate = g_hMaxUpdateRate.FloatValue;
	g_fMinInterpRatio = g_hMinInterpRatio.FloatValue;
	g_fMaxInterpRatio = g_hMaxInterpRatio.FloatValue;
}

public void OnClientPutInServer(int client) {
	g_fCurrentLerps[client] = -1.0;
}

public void OnClientSettingsChanged(int client) {
	if (IsClientInGame(client) && !IsFakeClient(client))
		ProcessPlayerLerp(client);
}

Action cmdLerps(int client, int args) {
	int lerpcnt;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i))
			ReplyToCommand(client, "%02d. %N Lerp: %.01f", ++lerpcnt, i, g_fCurrentLerps[i] * 1000);
	}

	return Plugin_Handled;
}

void ScanAllPlayersLerp() {
	for (int client = 1; client <= MaxClients; client++) {
		g_fCurrentLerps[client] = -1.0;
		if (IsClientInGame(client) && !IsFakeClient(client))
			ProcessPlayerLerp(client);
	}
}

void ProcessPlayerLerp(int client) {
	float m_fLerpTime = fGetLerpTime(client);
	SetEntPropFloat(client, Prop_Data, "m_fLerpTime", m_fLerpTime);

	if (g_fCurrentLerps[client] < 0.0) {
		if (g_iAnnounceLerp == 1)
			PrintToChatAll("%N's LerpTime set to %.01f", client, m_fLerpTime * 1000);
	}
	else if (g_iAnnounceLerp == 2 && m_fLerpTime != g_fCurrentLerps[client])
		PrintToChatAll("%N's LerpTime Changed from %.01f to %.01f", client, g_fCurrentLerps[client] * 1000, m_fLerpTime * 1000);

	float max = g_fMaxLerpValue;
	if (m_fLerpTime > max) {
		KickClient(client, "Lerp %.01f exceeds server max of %.01f", m_fLerpTime * 1000, max * 1000);
		PrintToChatAll("%N kicked for lerp too high. %.01f > %.01f", client, m_fLerpTime * 1000, max * 1000);
	}
	else
		g_fCurrentLerps[client] = m_fLerpTime;
}

float fGetLerpTime(int client) {
	char value[64];
	if (!GetClientInfo(client, "cl_updaterate", value, sizeof value))
		value[0] = '\0';

	float flUpdateRate = StringToFloat(value);

	flUpdateRate = clamp(flUpdateRate, g_fMinUpdateRate, g_fMaxUpdateRate);

	if (!GetClientInfo(client, "cl_interp_ratio", value, sizeof value))
		value[0] = '\0';

	float flLerpRatio = StringToFloat(value);

	if (!GetClientInfo(client, "cl_interp", value, sizeof value))
		value[0] = '\0';

	float flLerpAmount = StringToFloat(value);

	if (g_hMinInterpRatio != null && g_hMaxInterpRatio != null && g_fMinInterpRatio != -1.0)
		flLerpRatio = clamp(flLerpRatio, g_fMinInterpRatio, g_fMaxInterpRatio);

	return maximum(flLerpAmount, flLerpRatio / flUpdateRate);
}

float maximum(float a, float b) {
	return (a > b) ? a : b;
}

float clamp(float inc, float low, float high) {
	return (inc > high) ? high : ((inc < low) ? low : inc);
}
