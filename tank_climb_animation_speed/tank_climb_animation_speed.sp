#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_NAME				"Tank Climb Animation Speed"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

ConVar
	g_cvAnimationPlaybackRate;

float
	g_fAnimationPlaybackRate;

bool
	g_bLateLoad;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("tank_climb_animation_speed_version", PLUGIN_VERSION, "Tank Climb Animation Speed plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvAnimationPlaybackRate = CreateConVar("tank_climb_animation_playbackrate", "5.0", "Tank Climb Obstacle animation playback rate", _, true, 0.0);
	g_cvAnimationPlaybackRate.AddChangeHook(CvarChanged);
	AutoExecConfig(true);

	HookEvent("round_end",		Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",		Event_TankSpawn);
	HookEvent("player_death",	Event_PlayerDeath);
	HookEvent("player_team",	Event_PlayerTeam);

	if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
				SDKHook(i, SDKHook_PreThink, OnPreThink);
		}
	}
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fAnimationPlaybackRate = g_cvAnimationPlaybackRate.FloatValue;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i))
			SDKUnhook(i, SDKHook_PreThink, OnPreThink);
	}
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && IsFakeClient(client)) {
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
		SDKHook(client, SDKHook_PreThink, OnPreThink);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client)
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	if (event.GetInt("oldteam") != 3)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client)
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
}

void OnPreThink(int client) {
	switch (GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		case true: {
			if (GetEntityMoveType(client) == MOVETYPE_CUSTOM) {
				switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
					case 16, 17, 18, 19, 20, 21, 22, 23:
						SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", g_fAnimationPlaybackRate);
				}
			}
			
		}

		case false:
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}