#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define GAMEDATA	"drop_secondary"

int
	g_iOffHiddenWeapon;

public Plugin myinfo =
{
	name = "L4D2 Drop Secondary",
	author = "Jahze, Visor, NoBody & HarryPotter, sorallll",
	version	= "2.0",
	description	= "Survivor players will drop their secondary weapon when they die",
	url = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iOffHiddenWeapon = hGameData.GetOffset("CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenWeapon");
	if(g_iOffHiddenWeapon == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenWeapon");
	
	delete hGameData;

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	int entity = GetEntDataEnt2(client, g_iOffHiddenWeapon);
	if(entity > MaxClients && IsValidEntity(entity))
	{
		float vTarget[3];
		GetClientAbsOrigin(client, vTarget);
		SDKHooks_DropWeapon(client, entity, vTarget, NULL_VECTOR, false);
	}
}