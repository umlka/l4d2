#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public Plugin myinfo=
{
	name = "jockey ride stuck fix",
	author = "sorallll",
	description = "When the survivor bot controlled by jockey is kicked out of the game, jockey will get stuck in the air, this plugin fixes it",
	version = "1.0.0",
	url = ""
}

public void OnPluginStart()
{
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if(jockey != -1)
		vCheatCommand(jockey, "dismount");
}

void vCheatCommand(int client, const char[] sCommand)
{
	int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s", sCommand);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags);
}