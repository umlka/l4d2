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
				if(fSurvivorProximity < g_fJockeyLeapRange && bWithinViewAngle(client, 15.0))
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

bool bWithinViewAngle(int client, float fOffsetThreshold)
{
	static int iTarget;
	iTarget = GetClientAimTarget(client);
	if(!bIsAliveSurvivor(iTarget))
		return true;
	
	static float vSrc[3];
	static float vTarg[3];
	static float vAng[3];
	GetClientEyePosition(iTarget, vSrc);
	GetClientEyePosition(client, vTarg);
	GetClientEyeAngles(iTarget, vAng);
	return PointWithinViewAngle(vSrc, vTarg, vAng, GetFOVDotProduct(fOffsetThreshold));
}

// https://github.com/nosoop/stocksoup

/**
 * Checks if a point is in the field of view of an object.  Supports up to 180 degree FOV.
 * I forgot how the dot product stuff works.
 * 
 * Direct port of the function of the same name from the Source SDK:
 * https://github.com/ValveSoftware/source-sdk-2013/blob/beaae8ac45a2f322a792404092d4482065bef7ef/sp/src/public/mathlib/vector.h#L461-L477
 * 
 * @param vecSrcPosition	Source position of the view.
 * @param vecTargetPosition	Point to check if within view angle.
 * @param vecLookDirection	The direction to look towards.  Note that this must be a forward
 * 							angle vector.
 * @param flCosHalfFOV		The width of the forward view cone as a dot product result. For
 * 							subclasses of CBaseCombatCharacter, you can use the
 * 							`m_flFieldOfView` data property.  To manually calculate for a
 * 							desired FOV, use `GetFOVDotProduct(angle)` from math.inc.
 * @return					True if the point is within view from the source position at the
 * 							specified FOV.
 */
stock bool PointWithinViewAngle(const float vecSrcPosition[3], const float vecTargetPosition[3],
		const float vecLookDirection[3], float flCosHalfFOV) {
	float vecDelta[3];
	
	SubtractVectors(vecTargetPosition, vecSrcPosition, vecDelta);
	
	float cosDiff = GetVectorDotProduct(vecLookDirection, vecDelta);
	
	if (cosDiff < 0.0) {
		return false;
	}
	
	float flLen2 = GetVectorLength(vecDelta, true);
	
	// a/sqrt(b) > c  == a^2 > b * c ^2
	return ( cosDiff * cosDiff >= flLen2 * flCosHalfFOV * flCosHalfFOV );
}

/**
 * Calculates the width of the forward view cone as a dot product result from the given angle.
 * This manually calculates the value of CBaseCombatCharacter's `m_flFieldOfView` data property.
 *
 * For reference: https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/server/hl2/npc_bullseye.cpp#L151
 *
 * @param angle     The FOV value in degree
 * @return          Width of the forward view cone as a dot product result
 */
stock float GetFOVDotProduct(float angle) {
	return Cosine(DegToRad(angle) / 2.0);
}
