#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar
	g_hJockeyLeapAgain,
	g_hJockeyStumbleRadius,
	g_hHopActivationProximity;

float
	g_fJockeyLeapAgain,
	g_fJockeyStumbleRadius,
	g_fHopActivationProximity,
	g_fLeapAgainTime[MAXPLAYERS + 1];
	
bool
	g_bDoNormalJump[MAXPLAYERS + 1];

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
	g_hJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50.0", "Stumble radius of a client landing a ride");
	g_hHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500.0", "How close a client will approach before it starts hopping");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_shoved", Event_PlayerShoved);
	HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_Pre);
	
	g_hJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");
	//g_hJockeyLeapAgain.SetFloat(0.25);

	FindConVar("z_jockey_leap_range").SetFloat(1000.0);

	g_hJockeyLeapAgain.AddChangeHook(vConVarChanged);
	g_hJockeyStumbleRadius.AddChangeHook(vConVarChanged);
	g_hHopActivationProximity.AddChangeHook(vConVarChanged);
}

public void OnPluginEnd()
{
	FindConVar("z_jockey_leap_range").RestoreDefault();
}

public void OnConfigsExecuted()
{
	vGetCvars();
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	g_fJockeyLeapAgain = g_hJockeyLeapAgain.FloatValue;
	g_fJockeyStumbleRadius = g_hJockeyStumbleRadius.FloatValue;
	g_fHopActivationProximity = g_hHopActivationProximity.FloatValue;
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++)
		g_fLeapAgainTime[i] = 0.0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		g_fLeapAgainTime[i] = 0.0;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_fLeapAgainTime[GetClientOfUserId(event.GetInt("userid"))] = 0.0;
}

void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(bIsBotJockey(client))
		g_fLeapAgainTime[client] = GetGameTime() + g_fJockeyLeapAgain;
}

bool bIsBotJockey(int client)
{
	return client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 5;
}

void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{	
	if(g_fJockeyStumbleRadius <= 0.0 || !L4D_IsCoopMode())
		return;

	int attacker = GetClientOfUserId(event.GetInt("userid"));
	if(attacker == 0 || !IsClientInGame(attacker))
		return;

	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(victim == 0 || !IsClientInGame(victim))
		return;
	
	vStumbleByStanders(victim, attacker);
}

void vStumbleByStanders(int iPinnedSurvivor, int iPinner)
{
	static int i;
	static float vPos[3];
	static float vDir[3];
	static float vOrigin[3];

	GetClientAbsOrigin(iPinnedSurvivor, vOrigin);
	for(i = 1; i <= MaxClients; i++)
	{
		if(i == iPinnedSurvivor || i == iPinner || !IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || bIsPinned(i))
			continue;
		
		GetClientAbsOrigin(i, vPos);
		MakeVectorFromPoints(vOrigin, vPos, vDir);
		if(GetVectorLength(vDir) <= g_fJockeyStumbleRadius)
		{
			NormalizeVector(vDir, vDir);
			L4D_StaggerPlayer(i, iPinnedSurvivor, vDir);
		}
	}
}

bool bIsPinned(int client)
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

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 5 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if((GetEntProp(client, Prop_Send, "m_hasVisibleThreats") || bTargetSurvivor(client)) && fNearestSurvivorDistance(client) < g_fHopActivationProximity)
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
				static float fGameTime;
				if(g_fLeapAgainTime[client] < (fGameTime = GetGameTime()))
				{
					buttons |= IN_ATTACK;
					g_bDoNormalJump[client] = true;
					g_fLeapAgainTime[client] = fGameTime + g_fJockeyLeapAgain;
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

int bTargetSurvivor(int client)
{
	static int iTarget;
	iTarget = GetClientAimTarget(client, true);
	return bIsAliveSurvivor(iTarget) ? iTarget : 0;
}

bool bIsAliveSurvivor(int client)
{
	return bIsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool bIsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

float fNearestSurvivorDistance(int client)
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