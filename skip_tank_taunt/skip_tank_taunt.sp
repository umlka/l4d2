#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define GAMEDATA "skip_tank_taunt"

DynamicHook
	g_dHooksSelectWeightedSequence;

bool
	g_bLateLoad;

public Plugin myinfo =
{
	name = "Skip Tank Taunt",
	author = "sorallll",
	description = "",
	version = "1.0.2",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vInitGameData();

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);

	if(g_bLateLoad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				OnClientPutInServer(i);
				if(IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
					SDKHook(i, SDKHook_PreThink, OnPreThink);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	g_dHooksSelectWeightedSequence.HookEntity(Hook_Pre, client, DH_CTerrorPlayer_SelectWeightedSequence_Pre);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			SDKUnhook(i, SDKHook_PreThink, OnPreThink);
	}
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	SDKHook(client, SDKHook_PreThink, OnPreThink);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && IsClientInGame(client) && GetClientTeam(client) == 3)
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("oldteam") != 3)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client)
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
}

/**
* From left4dhooks.l4d2.cfg
* ACT_TERROR_CLIMB_24_FROM_STAND	718
* ACT_TERROR_CLIMB_36_FROM_STAND	719
* ACT_TERROR_CLIMB_38_FROM_STAND	720
* ACT_TERROR_CLIMB_48_FROM_STAND	721
* ACT_TERROR_CLIMB_50_FROM_STAND	722
* ACT_TERROR_CLIMB_60_FROM_STAND	723
* ACT_TERROR_CLIMB_70_FROM_STAND	724
* ACT_TERROR_CLIMB_72_FROM_STAND	725
* ACT_TERROR_CLIMB_84_FROM_STAND	726
* ACT_TERROR_CLIMB_96_FROM_STAND	727
* ACT_TERROR_CLIMB_108_FROM_STAND	728
* ACT_TERROR_CLIMB_115_FROM_STAND	729
* ACT_TERROR_CLIMB_120_FROM_STAND	730
* ACT_TERROR_CLIMB_130_FROM_STAND	731
* ACT_TERROR_CLIMB_132_FROM_STAND	732
* ACT_TERROR_CLIMB_144_FROM_STAND	733
* ACT_TERROR_CLIMB_150_FROM_STAND	734
* ACT_TERROR_CLIMB_156_FROM_STAND	735
* ACT_TERROR_CLIMB_166_FROM_STAND	736
* ACT_TERROR_CLIMB_168_FROM_STAND	737
**/
void OnPreThink(int client)
{
	switch(IsPlayerAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		case true:
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 16, 17, 18, 19, 20, 21, 22, 23:
					SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 10.0);
			}
		}

		case false:
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}
void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	vSetupHooks(hGameData);

	delete hGameData;
}

void vSetupHooks(GameData hGameData = null)
{
	g_dHooksSelectWeightedSequence = DynamicHook.FromConf(hGameData, "DH_CTerrorPlayer::SelectWeightedSequence");
	if(!g_dHooksSelectWeightedSequence)
		SetFailState("Failed to create DynamicHook: DH_CTerrorPlayer::SelectWeightedSequence");
}

/**
* From left4dhooks.l4d2.cfg
* ACT_TERROR_HULK_VICTORY 		792
* ACT_TERROR_HULK_VICTORY_B 	793
* ACT_TERROR_RAGE_AT_ENEMY 		794
* ACT_TERROR_RAGE_AT_KNOCKDOWN	795
**/
MRESReturn DH_CTerrorPlayer_SelectWeightedSequence_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(GetClientTeam(pThis) != 3 || !IsPlayerAlive(pThis) || GetEntProp(pThis, Prop_Send, "m_zombieClass") != 8 || GetEntProp(pThis, Prop_Send, "m_isGhost") == 1)
		return MRES_Ignored;

	if(792 <= hParams.Get(1) <= 795)
	{
		hReturn.Value = 0;
		SetEntPropFloat(pThis, Prop_Send, "m_flCycle", 1000.0);
		return MRES_ChangedOverride;
	}

	return MRES_Ignored;
}
