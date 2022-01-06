#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar
	g_hJockeyLeapRange,
	g_hJockeyLeapAgain,
	g_hJockeyStumbleRadius,
	g_hHopActivationProximity;

float
	g_fJockeyLeapRange,
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
	g_hHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "800.0", "How close a client will approach before it starts hopping");
	g_hJockeyLeapRange = FindConVar("z_jockey_leap_range");
	g_hJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");

	g_hJockeyLeapRange.AddChangeHook(vConVarChanged);
	g_hJockeyLeapAgain.AddChangeHook(vConVarChanged);
	g_hJockeyStumbleRadius.AddChangeHook(vConVarChanged);
	g_hHopActivationProximity.AddChangeHook(vConVarChanged);

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_shoved", Event_PlayerShoved);
	HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_Pre);
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
	g_fJockeyLeapRange = g_hJockeyLeapRange.FloatValue;
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

	GetClientAbsOrigin(iPinnedSurvivor, vPos);
	for(i = 1; i <= MaxClients; i++)
	{
		if(i == iPinnedSurvivor || i == iPinner || !IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || bIsPinned(i))
			continue;
		
		GetClientAbsOrigin(i, vDir);
		MakeVectorFromPoints(vPos, vDir, vDir);
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

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 5 || GetEntProp(client, Prop_Send, "m_isGhost") == 1 || !GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
		return Plugin_Continue;

	static float fSurvivorProximity;
	fSurvivorProximity = fNearestSurvivorDistance(client);
	if(fSurvivorProximity > g_fHopActivationProximity)
		return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		static float vAng[3];

		if(g_bDoNormalJump[client])
		{
			if(buttons & IN_FORWARD)
			{
				vAng = angles;
				vAng[0] = GetRandomFloat(-10.0, 0.0);
				TeleportEntity(client, NULL_VECTOR, vAng, NULL_VECTOR);
			}
			buttons |= IN_JUMP;
			switch(GetRandomInt(0, 2))
			{
				case 0:
					buttons |= IN_DUCK;
	
				case 1:
					buttons |= IN_ATTACK2;
			}
			g_bDoNormalJump[client] = false;
		}
		else
		{
			static float fGameTime;
			if(g_fLeapAgainTime[client] < (fGameTime = GetGameTime()))
			{
				if(fSurvivorProximity < g_fJockeyLeapRange && bIsBeingWatched(client, 30.0))
				{
					vAng = angles;
					vAng[0] = GetRandomFloat(-50.0, -10.0);
					TeleportEntity(client, NULL_VECTOR, vAng, NULL_VECTOR);
				}
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

	return Plugin_Continue;
}

bool bIsBeingWatched(int client, float fOffsetThreshold)
{
	static int iTarget;
	if(bIsAliveSurvivor((iTarget = GetClientAimTarget(client))) && fGetPlayerAimOffset(client, iTarget) > fOffsetThreshold)
		return false;

	return true;
}

float fGetPlayerAimOffset(int client, int iTarget)
{
	static float vAng[3];
	static float vPos[3];
	static float vDir[3];

	GetClientEyeAngles(iTarget, vAng);
	vAng[0] = vAng[2] = 0.0;
	GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vAng, vAng);

	GetClientAbsOrigin(client, vPos);
	GetClientAbsOrigin(iTarget, vDir);
	vPos[2] = vDir[2] = 0.0;
	MakeVectorFromPoints(vDir, vPos, vDir);
	NormalizeVector(vDir, vDir);

	return RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vDir)));
}

bool bIsAliveSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

float fNearestSurvivorDistance(int client)
{
	static int i;
	static int iCount;
	static float vPos[3];
	static float vTarg[3];
	static float fDists[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientAbsOrigin(client, vPos);

	for(i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, vTarg);
			fDists[iCount++] = GetVectorDistance(vPos, vTarg);
		}
	}

	if(iCount == 0)
		return -1.0;

	SortFloats(fDists, iCount, Sort_Ascending);
	return fDists[0];
}
