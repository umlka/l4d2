#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define GAMEDATA "skip_tank_taunt"

bool
	g_bLateLoad;

public Plugin myinfo =
{
	name = "Skip Tank Taunt", 
	author = "sorallll", 
	description = "", 
	version = "1.0.0", 
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vLoadGameData();

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);

	if(g_bLateLoad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
				SDKHook(i, SDKHook_PostThinkPost, Hook_PostThinkPost);
		}
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			SDKUnhook(i, SDKHook_PostThinkPost, Hook_PostThinkPost);
	}
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsFakeClient(client))
		return;
	
	SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
	SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client)
		SDKUnhook(GetClientOfUserId(event.GetInt("userid")), SDKHook_PostThinkPost, Hook_PostThinkPost);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client)
		SDKUnhook(GetClientOfUserId(event.GetInt("userid")), SDKHook_PostThinkPost, Hook_PostThinkPost);
}

public void Hook_PostThinkPost(int client)
{
	switch(IsPlayerAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		case true:
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 15, 16, 17, 18, 19, 20, 21, 22, 23:
					SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 5.0);
			}
		}

		case false:
			SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
	}
}

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::SelectWeightedSequence");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::SelectWeightedSequence");

	if(!dDetour.Enable(Hook_Post, mreSelectWeightedSequencePost))
		SetFailState("Failed to detour post: CTerrorPlayer::SelectWeightedSequence");
}

public MRESReturn mreSelectWeightedSequencePost(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis) || GetClientTeam(pThis) != 3 || !IsPlayerAlive(pThis) || GetEntProp(pThis, Prop_Send, "m_zombieClass") != 8 || GetEntProp(pThis, Prop_Send, "m_isGhost") == 1)
		return MRES_Ignored;

	switch(hReturn.Value)
	{
		case 52, 53, 54, 55, 56, 57, 58 ,59, 60:
		{
			hReturn.Value = 0;
			SetEntPropFloat(pThis, Prop_Send, "m_flCycle", 1000.0);
			return MRES_ChangedOverride;
		}
	}

	return MRES_Ignored;
}