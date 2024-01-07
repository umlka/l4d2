#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

int
	m_hHiddenWeapon;

public Plugin myinfo = {
	name = "L4D2 Drop Secondary",
	author = "sorallll",
	version	= "1.0.1",
	url = "https://github.com/umlka/l4d2/tree/main/drop_secondary"
};

public void OnPluginStart() {
	m_hHiddenWeapon = FindSendPropInfo("CTerrorPlayer", "m_knockdownTimer") + 116;
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	int entity = GetEntDataEnt2(client, m_hHiddenWeapon);
	SetEntDataEnt2(client, m_hHiddenWeapon, -1, true);
	if (entity > MaxClients && IsValidEntity(entity) && GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == client) {
		float vecTarget[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecTarget);
		SDKHooks_DropWeapon(client, entity, vecTarget, NULL_VECTOR, false);
	}
}
