#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar g_hLungeInterval;
ConVar g_hFastPounceProximity;
ConVar g_hPounceVerticalAngle;
ConVar g_hPounceAngleMean;
ConVar g_hPounceAngleStd;
ConVar g_hStraightPounceProximity;
ConVar g_hAimOffsetSensitivityHunter;
ConVar g_hWallDetectionDistance;

float g_fLungeInterval;
float g_fFastPounceProximity;
float g_fPounceVerticalAngle;
float g_fPounceAngleMean;
float g_fPounceAngleStd;
float g_fStraightPounceProximity;
int g_iAimOffsetSensitivityHunter;
float g_fWallDetectionDistance;

bool g_bCanLunge[MAXPLAYERS + 1];
bool g_bHasQueuedLunge[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "AI HUNTER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart()
{	
	FindConVar("hunter_committed_attack_range").SetFloat(10000.0);
	FindConVar("hunter_pounce_ready_range").SetFloat(500.0);
	FindConVar("hunter_leap_away_give_up_range").SetFloat(0.0);
	FindConVar("hunter_pounce_max_loft_angle").SetFloat(0.0);
	FindConVar("z_pounce_crouch_delay").SetFloat(0.1);
	FindConVar("z_pounce_damage_interrupt").SetInt(150);
	g_hLungeInterval = FindConVar("z_lunge_interval");

	g_hFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "1000.0", "At what distance to start pouncing fast");
	g_hPounceVerticalAngle = CreateConVar("ai_pounce_vertical_angle", "7.0", "Vertical angle to which AI hunter pounces will be restricted");
	g_hPounceAngleMean = CreateConVar("ai_pounce_angle_mean", "10.0", "Mean angle produced by Gaussian RNG");
	g_hPounceAngleStd = CreateConVar("ai_pounce_angle_std", "20.0", "One standard deviation from mean as produced by Gaussian RNG");
	g_hStraightPounceProximity = CreateConVar("ai_straight_pounce_proximity", "350.0", "Distance to nearest survivor at which hunter will consider pouncing straight");
	g_hAimOffsetSensitivityHunter = CreateConVar("ai_aim_offset_sensitivity_hunter", "179", "If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 179.0);
	g_hWallDetectionDistance = CreateConVar("ai_wall_detection_distance", "-1.0", "How far in front of himself infected bot will check for a wall. Use '-1' to disable feature");

	g_hLungeInterval.AddChangeHook(ConVarChanged);
	g_hFastPounceProximity.AddChangeHook(ConVarChanged);
	g_hPounceVerticalAngle.AddChangeHook(ConVarChanged);
	g_hPounceAngleMean.AddChangeHook(ConVarChanged);
	g_hPounceAngleStd.AddChangeHook(ConVarChanged);
	g_hStraightPounceProximity.AddChangeHook(ConVarChanged);
	g_hAimOffsetSensitivityHunter.AddChangeHook(ConVarChanged);
	g_hWallDetectionDistance.AddChangeHook(ConVarChanged);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("ability_use", Event_AbilityUse);
}

public void OnPluginEnd()
{
	FindConVar("hunter_committed_attack_range").RestoreDefault();
	FindConVar("hunter_pounce_ready_range").RestoreDefault();
	FindConVar("hunter_leap_away_give_up_range").RestoreDefault();
	FindConVar("hunter_pounce_max_loft_angle").RestoreDefault();
	FindConVar("z_pounce_crouch_delay").RestoreDefault();
	FindConVar("z_pounce_damage_interrupt").RestoreDefault();
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
	g_fLungeInterval = g_hLungeInterval.FloatValue;
	g_fFastPounceProximity = g_hFastPounceProximity.FloatValue;
	g_fPounceVerticalAngle = g_hPounceVerticalAngle.FloatValue;
	g_fPounceAngleMean = g_hPounceAngleMean.FloatValue;
	g_fPounceAngleStd = g_hPounceAngleStd.FloatValue;
	g_fStraightPounceProximity = g_hStraightPounceProximity.FloatValue;
	g_iAimOffsetSensitivityHunter = g_hAimOffsetSensitivityHunter.IntValue;
	g_fWallDetectionDistance = g_hWallDetectionDistance.FloatValue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bHasQueuedLunge[client] = false;
	g_bCanLunge[client] = true;
}

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	char sAbility[16];
	event.GetString("ability", sAbility, sizeof(sAbility));
	if(strcmp(sAbility, "ability_lunge") == 0)
		Hunter_OnPounce(GetClientOfUserId(event.GetInt("userid")));
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 3 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	buttons &= ~IN_ATTACK2;
	
	static int flags;
	flags = GetEntityFlags(client);
	if(flags & FL_DUCKING != 0 && flags & FL_ONGROUND != 0 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vPos[3];
		GetClientAbsOrigin(client, vPos);
		if(NearestSurvivorDistance(client, vPos) < g_fFastPounceProximity)
		{
			buttons &= ~IN_ATTACK;			
			if(!g_bHasQueuedLunge[client])
			{
				g_bCanLunge[client] = false;
				g_bHasQueuedLunge[client] = true;
				CreateTimer(g_fLungeInterval, Timer_LungeInterval, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
			else if(g_bCanLunge[client])
			{
				buttons |= IN_ATTACK;
				g_bHasQueuedLunge[client] = false;
			}
		}	
	}

	return Plugin_Changed;
}

float NearestSurvivorDistance(int client, const float vOrigin[3])
{
	static int i;
	static int iNum;
	static float vTarget[3];
	static float fDists[MAXPLAYERS + 1];

	iNum = 0;

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

public Action Timer_LungeInterval(Handle timer, int client)
{
	g_bCanLunge[GetClientOfUserId(client)] = true;
}

bool IsBotHunter(int client)
{
	return client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 3;
}

void Hunter_OnPounce(int client)
{	
	if(!IsBotHunter(client))
		return;

	static int iLunge;
	iLunge = GetEntPropEnt(client, Prop_Send, "m_customAbility");			

	static float vPos[3];
	
	GetClientAbsOrigin(client, vPos);
	if(g_fWallDetectionDistance > 0.0 && HitSolid(client, vPos))
	{
		if(GetRandomInt(0, 1))
			AngleLunge(iLunge, 45.0);
		else
			AngleLunge(iLunge, 315.0);
	}
	else
	{	
		if(IsTargetWatchingAttacker(client, g_iAimOffsetSensitivityHunter) && NearestSurvivorDistance(client, vPos) > g_fStraightPounceProximity)
		{			
			static float fPounceAngle;
			fPounceAngle = GaussianRNG(g_fPounceAngleMean, g_fPounceAngleStd);
			AngleLunge(iLunge, fPounceAngle);
			LimitLungeVerticality(iLunge);				
		}	
	}
}

bool HitSolid(int client, float vStart[3])
{
	static float vEyeDir[3];
	GetClientEyeAngles(client, vEyeDir);
	GetAngleVectors(vEyeDir, vEyeDir, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vEyeDir, vEyeDir);
	ScaleVector(vEyeDir, g_fWallDetectionDistance);
	AddVectors(vStart, vEyeDir, vEyeDir);

	static float vMin[3];
	static float vMax[3];
	GetClientMins(client, vMin);
	GetClientMaxs(client, vMax);

	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vStart, vEyeDir, vMin, vMax, MASK_PLAYERSOLID_BRUSHONLY, TraceEntityFilter);

	static bool bDidHit;
	bDidHit = false;

	if(hTrace != null)
	{
		bDidHit = TR_DidHit(hTrace);
		delete hTrace;
	}
	
	return bDidHit;
}

public bool TraceEntityFilter(int entity, int contentsMask)
{
	if(entity <= MaxClients)
		return false;
	else
	{
		static char sClassName[9];
		GetEntityClassname(entity, sClassName, sizeof(sClassName));
		if(sClassName[0] == 'i' || sClassName[0] == 'w')
		{
			if(strcmp(sClassName, "infected") == 0 || strcmp(sClassName, "witch") == 0)
				return false;
		}
	}

	return true;
}

bool IsTargetWatchingAttacker(int iAttacker, int iOffsetThreshold)
{
	static int iTarget;
	static bool bIsWatching;

	bIsWatching = true;
	iTarget = GetClientAimTarget(iAttacker);
	if(IsAliveSurvivor(iTarget))
	{
		static int iAimOffset;
		iAimOffset = RoundToNearest(GetPlayerAimOffset(iTarget, iAttacker));
		if(iAimOffset <= iOffsetThreshold)
			bIsWatching = true;
		else 
			bIsWatching = false;
	}
	return bIsWatching;
}

float GetPlayerAimOffset(int iAttacker, int iTarget)
{
	static float vAim[3];
	static float vTarget[3];
	static float vAttacker[3];

	GetClientEyeAngles(iAttacker, vAim);
	vAim[0] = vAim[2] = 0.0;
	GetAngleVectors(vAim, vAim, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vAim, vAim);
	
	GetClientAbsOrigin(iTarget, vTarget);
	GetClientAbsOrigin(iAttacker, vAttacker);
	vAttacker[2] = vTarget[2] = 0.0;
	MakeVectorFromPoints(vAttacker, vTarget, vAttacker);
	NormalizeVector(vAttacker, vAttacker);
	
	return RadToDeg(ArcCosine(GetVectorDotProduct(vAim, vAttacker)));
}

void AngleLunge(int iLunge, float fTurnAngle)
{	
	static float vLunge[3];
	GetEntPropVector(iLunge, Prop_Send, "m_queuedLunge", vLunge);

	fTurnAngle = DegToRad(fTurnAngle);

	static float vForcedLunge[3];
	vForcedLunge[0] = vLunge[0] * Cosine(fTurnAngle) - vLunge[1] * Sine(fTurnAngle);
	vForcedLunge[1] = vLunge[0] * Sine(fTurnAngle) + vLunge[1] * Cosine(fTurnAngle);
	vForcedLunge[2] = vLunge[2];
	
	SetEntPropVector(iLunge, Prop_Send, "m_queuedLunge", vForcedLunge);	
}

void LimitLungeVerticality(int iLunge)
{
	static float vLunge[3];
	GetEntPropVector(iLunge, Prop_Send, "m_queuedLunge", vLunge);

	static float fVertAngle;
	fVertAngle = DegToRad(g_fPounceVerticalAngle);	

	static float vFlatLunge[3];
	vFlatLunge[1] = vLunge[1] * Cosine(fVertAngle) - vLunge[2] * Sine(fVertAngle);
	vFlatLunge[2] = vLunge[1] * Sine(fVertAngle) + vLunge[2] * Cosine(fVertAngle);
	vFlatLunge[0] = vLunge[0] * Cosine(fVertAngle) + vLunge[2] * Sine(fVertAngle);
	vFlatLunge[2] = vLunge[0] * -Sine(fVertAngle) + vLunge[2] * Cosine(fVertAngle);
	
	SetEntPropVector(iLunge, Prop_Send, "m_queuedLunge", vFlatLunge);
}

/** 
 * Thanks to Newteee:
 * Random number generator fit to a bellcurve. Function to generate Gaussian Random Number fit to a bellcurve with a specified mean and std
 * Uses Polar Form of the Box-Muller transformation
*/
float GaussianRNG(float fMean, float fStd)
{
	static float fX1;
	static float fX2;
	static float fW;

	do
	{
		fX1 = 2.0 * GetRandomFloat(0.0, 1.0) - 1.0;
		fX2 = 2.0 * GetRandomFloat(0.0, 1.0) - 1.0;
		fW = Pow(fX1, 2.0) + Pow(fX2, 2.0);
	}while(fW >= 1.0);
	
	static float e = 2.71828;
	fW = SquareRoot(-2.0 * (Logarithm(fW, e) / fW));

	static float fY1;
	static float fY2;
	fY1 = fX1 * fW;
	fY2 = fX2 * fW;

	static float fZ1;
	static float fZ2;
	fZ1 = fY1 * fStd + fMean;
	fZ2 = fY2 * fStd - fMean;

	return GetRandomFloat(0.0, 1.0) < 0.5 ? fZ1 : fZ2;
}

bool IsAliveSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
