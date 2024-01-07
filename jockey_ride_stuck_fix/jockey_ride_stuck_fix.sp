#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_NAME				"Jockey Ride Stuck Fix"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"When the survivor bot controlled by jockey is kicked out of the game, jockey will get stuck in the air, this plugin fixes it"
#define PLUGIN_VERSION			"1.0.1"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?p=2756577"

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	CreateConVar("jockey ride stuck fix_version", PLUGIN_VERSION, "Jockey Ride Stuck Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if (jockey != -1) {
		int flags = GetCommandFlags("dismount");
		SetCommandFlags("dismount", flags & ~FCVAR_CHEAT);
		FakeClientCommand(jockey, "dismount");
		SetCommandFlags("dismount", flags);
	}
}
