#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar g_hJockeyLeapAgain;
ConVar g_hJockeyStumbleRadius;
ConVar g_hHopActivationProximity;

float g_fJockeyLeapAgain;
float g_fJockeyStumbleRadius;
float g_fHopActivationProximity;
	
bool g_bCanLeap[MAXPLAYERS + 1];
bool g_bDoNormalJump[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "AI JOCKEY",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart()
{
	FindConVar("z_jockey_leap_range").SetFloat(1000.0);
	g_hJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");

	g_hJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50", "Stumble radius of a client landing a ride");
	g_hHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "How close a client will approach before it starts hopping");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_Pre);
	
	g_hJockeyLeapAgain.AddChangeHook(ConVarChanged);
	g_hJockeyStumbleRadius.AddChangeHook(ConVarChanged);
	g_hHopActivationProximity.AddChangeHook(ConVarChanged);
}

public void OnPluginEnd()
{
	FindConVar("z_jockey_leap_range").RestoreDefault();
}

public void OnConfigsExecuted()
{
	GetCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fJockeyLeapAgain = g_hJockeyLeapAgain.FloatValue;
	g_fJockeyStumbleRadius = g_hJockeyStumbleRadius.FloatValue;
	g_fHopActivationProximity = g_hHopActivationProximity.FloatValue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_bCanLeap[GetClientOfUserId(event.GetInt("userid"))] = true;
}

public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsBotJockey(client))
		Jockey_OnShoved(client);
}

void Jockey_OnShoved(int client)
{
	g_bCanLeap[client] = false;
	CreateTimer(g_fJockeyLeapAgain, Timer_LeapCooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

bool IsBotJockey(int client)
{
	return client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 5;
}

public Action Timer_LeapCooldown(Handle timer, int client)
{
	g_bCanLeap[GetClientOfUserId(client)] = true;
}

public void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{	
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(attacker > 0 && victim > 0)
		StumbleByStanders(victim, attacker);
}

void StumbleByStanders(int iPinnedSurvivor, int iPinner)
{
	static float vOrigin[3];
	static float vPos[3];
	static float vDir[3];
	static int i;
	GetClientAbsOrigin(iPinnedSurvivor, vOrigin);
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if(i != iPinnedSurvivor && i != iPinner && !IsPinned(i))
			{
				GetClientAbsOrigin(i, vPos);
				SubtractVectors(vPos, vOrigin, vDir);
				if(GetVectorLength(vDir) <= g_fJockeyStumbleRadius)
				{
					NormalizeVector(vDir, vDir);
					L4D_StaggerPlayer(i, iPinnedSurvivor, vDir);
				}
			}
		} 
	}
}

bool IsPinned(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	return false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 5 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && NearestSurvivorDistance(client) < g_fHopActivationProximity)
	{
		if(GetEntityFlags(client) & FL_ONGROUND)
		{
			if(g_bDoNormalJump[client])
			{
				buttons |= IN_JUMP;
				g_bDoNormalJump[client] = false;
			}
			else
			{
				if(g_bCanLeap[client])
				{
					buttons |= IN_ATTACK;
					g_bCanLeap[client] = false;
					CreateTimer(g_fJockeyLeapAgain, Timer_LeapCooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					g_bDoNormalJump[client] = true;
				} 			
			}
			
		}
		else
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_ATTACK;
		}	
		return Plugin_Changed;
	} 

	return Plugin_Continue;
}

float NearestSurvivorDistance(int client)
{
	static int i;
	static int iNum;
	static float vOrigin[3];
	static float vTarget[3];
	static float fDists[MAXPLAYERS + 1];
	
	iNum = 0;

	GetClientAbsOrigin(client, vOrigin);

	for(i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, vTarget);
			fDists[iNum++] = GetVectorDistance(vOrigin, vTarget);
		}
	}

	if(iNum == 0)
		return -1.0;

	SortFloats(fDists, iNum, Sort_Ascending);
	return fDists[0];
}
