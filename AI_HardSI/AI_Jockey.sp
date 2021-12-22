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
	g_fHopActivationProximity;
	
bool
	g_bCanLeap[MAXPLAYERS + 1],
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

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_Pre);
	
	g_hJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");
	//g_hJockeyLeapAgain.SetFloat(0.25);

	FindConVar("z_jockey_leap_range").SetFloat(1000.0);

	g_hJockeyLeapAgain.AddChangeHook(vConVarChanged);
	g_hJockeyStumbleRadius.AddChangeHook(vConVarChanged);
	g_hHopActivationProximity.AddChangeHook(vConVarChanged);
	FindConVar("mp_gamemode").AddChangeHook(vGameModeChanged);
}

public void OnPluginEnd()
{
	FindConVar("z_jockey_leap_range").RestoreDefault();
}

public void OnConfigsExecuted()
{
	vGetCvars();
	vGetCurrentMode();
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

void vGameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCurrentMode();
}

bool g_bMapStarted;
public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

int g_iCurrentMode;
void vGetCurrentMode()
{
	if(g_bMapStarted == false)
		return;

	g_iCurrentMode = 0;

	int entity = CreateEntityByName("info_gamemode");
	if(IsValidEntity(entity))
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if(IsValidEntity(entity)) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if(strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if(strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if(strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if(strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_bCanLeap[GetClientOfUserId(event.GetInt("userid"))] = true;
}

void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(bIsBotJockey(client))
		vJockey_OnShoved(client);
}

void vJockey_OnShoved(int client)
{
	g_bCanLeap[client] = false;
	CreateTimer(g_fJockeyLeapAgain, Timer_LeapCooldown, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

bool bIsBotJockey(int client)
{
	return client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 5;
}

Action Timer_LeapCooldown(Handle timer, int client)
{
	g_bCanLeap[GetClientOfUserId(client)] = true;
}

void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{	
	if(g_iCurrentMode != 1 || g_fJockeyStumbleRadius <= 0.0)
		return;

	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if(attacker > 0 && victim > 0)
		vStumbleByStanders(victim, attacker);
}

void vStumbleByStanders(int iPinnedSurvivor, int iPinner)
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
			if(i != iPinnedSurvivor && i != iPinner && !bIsPinned(i))
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