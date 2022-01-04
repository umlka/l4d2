#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar
	g_hChargerBhop,
	g_hChargeProximity,
	g_hChargeStartSpeed,
	g_hHealthThresholdCharger,
	g_hAimOffsetSensitivityCharger;

float
	g_fChargeProximity,
	g_fChargeStartSpeed;

int
	g_iHealthThresholdCharger,
	g_iAimOffsetSensitivityCharger;

bool
	g_bChargerBhop,
	g_bShouldCharge[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "AI CHARGER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart()
{
	g_hChargerBhop = CreateConVar("ai_charger_bhop", "1", "Flag to enable bhop facsimile on AI chargers");
	g_hChargeProximity = CreateConVar("ai_charge_proximity", "300.0", "How close a client will approach before charging");
	g_hHealthThresholdCharger = CreateConVar("ai_health_threshold_charger", "300", "Charger will charge if its health drops to this level");
	g_hAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger", "45", "If the charger has a target, it will not straight charge if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 180.0);
	g_hChargeStartSpeed = FindConVar("z_charge_start_speed");

	g_hChargerBhop.AddChangeHook(vConVarChanged);
	g_hChargeProximity.AddChangeHook(vConVarChanged);
	g_hChargeStartSpeed.AddChangeHook(vConVarChanged);
	g_hHealthThresholdCharger.AddChangeHook(vConVarChanged);
	g_hAimOffsetSensitivityCharger.AddChangeHook(vConVarChanged);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("charger_charge_start", Event_ChargerChargeStart);
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
	g_bChargerBhop = g_hChargerBhop.BoolValue;
	g_fChargeStartSpeed = g_hChargeStartSpeed.FloatValue;
	g_fChargeProximity = g_hChargeProximity.FloatValue;
	g_iHealthThresholdCharger = g_hHealthThresholdCharger.IntValue;
	g_iAimOffsetSensitivityCharger = g_hAimOffsetSensitivityCharger.IntValue;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_bShouldCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}

void Event_ChargerChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	int flags = GetEntProp(client, Prop_Send, "m_fFlags");
	SetEntProp(client, Prop_Send, "m_fFlags", flags & ~FL_FROZEN);
	vCharger_OnCharge(client);
	SetEntProp(client, Prop_Send, "m_fFlags", flags);
}

int g_iSpecialTarget[MAXPLAYERS + 1];
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	g_iSpecialTarget[specialInfected] = curTarget;
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 6 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	static float fSurvivorProximity;
	fSurvivorProximity = fNearestSurvivorDistance(client);
	if(fSurvivorProximity > g_fChargeProximity && GetEntProp(client, Prop_Send, "m_iHealth") > g_iHealthThresholdCharger)
	{
		if(!g_bShouldCharge[client])
			vBlockCharge(client);
	}
	else
		g_bShouldCharge[client] = true;
		
	if(g_bShouldCharge[client] && -1.0 < fSurvivorProximity < 150.0 && bChargerCanCharge(client))
	{
		static int iTarget;
		iTarget = g_iSpecialTarget[client]/*GetClientAimTarget(client, true)*/;
		if(bIsAliveSurvivor(iTarget) && !bIsIncapacitated(iTarget) && (buttons & IN_ATTACK2 || !bHitWall(client, iTarget)))
		{
			buttons |= IN_ATTACK;
			buttons |= IN_ATTACK2;
			return Plugin_Changed;
		}
	}

	if(g_bChargerBhop && 200.0 < fSurvivorProximity < 1000.0 && GetEntityFlags(client) & FL_ONGROUND && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") - 30.0)
		{
			static float vAngles[3];
			GetClientEyeAngles(client, vAngles);
			if(bBhop(client, buttons, vAngles))
				return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}
/*
bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	static float vVec[3];

	bJumped = false;

	if(buttons & IN_FORWARD)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, 180.0))
			bJumped = true;
	}
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, 90.0))
			bJumped = true;
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		//if(bClient_Push(client, buttons, vVec, 90.0))
			//bJumped = true;

		static float vRig[3];
		static float vVel[3];
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

		NormalizeVector(vRig, vRig);
		NormalizeVector(vVel, vVel);
		
		if(155.0 < RadToDeg(ArcCosine(GetVectorDotProduct(vRig, vVel))) <= 180.0)
			bJumped = false;
		else
		{
			if(bClient_Push(client, buttons, vAng, 90.0))
				bJumped = true;
		}
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		//if(bClient_Push(client, buttons, vVec, 90.0))
			//bJumped = true;

		static float vRig[3];
		static float vVel[3];
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

		NormalizeVector(vRig, vRig);
		NormalizeVector(vVel, vVel);
		
		if(155.0 < RadToDeg(ArcCosine(GetVectorDotProduct(vRig, vVel))) <= 180.0)
			bJumped = false;
		else
		{
			if(bClient_Push(client, buttons, vVec, 90.0))
				bJumped = true;
		}
	}
	
	return bJumped;
}
*/
bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	static float vVec[3];

	bJumped = false;

	if(buttons & IN_FORWARD || buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, buttons & IN_FORWARD ? 180.0 : -90.0))
			bJumped = true;
	}

	if(buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);

		static float vRig[3];
		static float vVel[3];
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

		NormalizeVector(vRig, vRig);
		NormalizeVector(vVel, vVel);
		
		if(155.0 < RadToDeg(ArcCosine(GetVectorDotProduct(vRig, vVel))) <= 180.0)
			bJumped = false;
		else
		{
			if(bClient_Push(client, buttons, vVec, buttons & IN_MOVELEFT ? -90.0 : 90.0))
				bJumped = true;
		}
	}

	return bJumped;
}

bool bClient_Push(int client, int &buttons, float vVec[3], float fForce)
{
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);

	if(bWontFall(client, vVel))
	{
		buttons |= IN_DUCK;
		buttons |= IN_JUMP;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
		return true;
	}

	return false;
}

#define JUMP_HEIGHT 18.0
bool bWontFall(int client, const float vVel[3])
{
	static float vPos[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vPos);
	AddVectors(vPos, vVel, vEnd);
	vPos[2] += 20.0;

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static bool bHit;
	static Handle hTrace;
	static float vEndPos[3];

	bHit = false;
	vEnd[2] += JUMP_HEIGHT;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID, bTraceEntityFilter);
	//vEnd[2] -= JUMP_HEIGHT;

	if(TR_DidHit(hTrace))
	{
		bHit = true;
		TR_GetEndPosition(vEndPos, hTrace);
		if(GetVectorDistance(vPos, vEndPos) < 64.0)
		{
			delete hTrace;
			return false;
		}

		static float vVec[3];
		NormalizeVector(vVel, vVec);
	
		static float vPlane[3];
		TR_GetPlaneNormal(hTrace, vPlane);
		NegateVector(vPlane);
		NormalizeVector(vPlane, vPlane);
		if(RadToDeg(ArcCosine(GetVectorDotProduct(vVec, vPlane))) < 30.0)
		{
			delete hTrace;
			return false;
		}
	}
	delete hTrace;
	
	if(!bHit)
		vEndPos = vEnd;

	static float vDown[3];
	vDown[0] = vEndPos[0];
	vDown[1] = vEndPos[1];
	vDown[2] = vEndPos[2] - 100000.0;

	hTrace = TR_TraceHullFilterEx(vEndPos, vDown, vMins, vMaxs, MASK_PLAYERSOLID, bTraceEntityFilter);
	if(TR_DidHit(hTrace))
	{
		TR_GetEndPosition(vEnd, hTrace);
		if(vEndPos[2] - vEnd[2] > 120.0)
		{
			delete hTrace;
			return false;
		}

		static int entity;
		if((entity = TR_GetEntityIndex(hTrace)) > MaxClients)
		{
			static char classname[13];
			GetEdictClassname(entity, classname, sizeof(classname));
			if(strcmp(classname, "trigger_hurt") == 0)
			{
				delete hTrace;
				return false;
			}
		}
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

bool bTraceEntityFilter(int entity, int contentsMask)
{
	if(entity <= MaxClients)
		return false;
	else
	{
		static char classname[9];
		GetEntityClassname(entity, classname, sizeof classname);
		if(classname[0] == 'i' || classname[0] == 'w')
		{
			if(strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0)
				return false;
		}
	}
	return true;
}

float fNearestSurvivorDistance(int client)
{
	static int i;
	static int iCount;
	static float vPos[3];
	static float vTarget[3];
	static float fDistance[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientAbsOrigin(client, vPos);

	for(i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, vTarget);
			fDistance[iCount++] = GetVectorDistance(vPos, vTarget);
		}
	}

	if(iCount == 0)
		return -1.0;

	SortFloats(fDistance, iCount, Sort_Ascending);
	return fDistance[0];
}

bool bHitWall(int client, int iTarget)
{
	static float vPos[3];
	static float vTarget[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsOrigin(iTarget, vTarget);
	vPos[2] += 10.0;
	vTarget[2] += 10.0;

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static float vEnd[3];
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vPos, vTarget, vMins, vMaxs, MASK_PLAYERSOLID, bTraceEntityFilter);
	if(TR_DidHit(hTrace))
	{
		TR_GetEndPosition(vEnd, hTrace);
		delete hTrace;

		if(GetVectorDistance(vEnd, vTarget) < 32.0)
			return false;
		return true;
	}

	delete hTrace;
	return false;
}

bool bChargerCanCharge(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0)
		return false;

	static int iAbility;
	iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility == -1 || !IsValidEntity(iAbility) || GetEntProp(iAbility, Prop_Send, "m_isCharging") || GetEntPropFloat(iAbility, Prop_Send, "m_timestamp") >= GetGameTime())
		return false;

	return true;
}

void vBlockCharge(int client)
{
	static int iAbility;
	iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
		SetEntPropFloat(iAbility, Prop_Send, "m_timestamp", GetGameTime() + 0.1);	
}

#define CROUCHING_HEIGHT 56.0
void vCharger_OnCharge(int client)
{
	static int iAimTarget;
	iAimTarget = g_iSpecialTarget[client]/*GetClientAimTarget(client, true)*/;
	if(!bIsAliveSurvivor(iAimTarget) || bIsIncapacitated(iAimTarget) || bIsPinned(iAimTarget) || bIsTargetWatchingAttacker(client, g_iAimOffsetSensitivityCharger))
	{
		static int iNewTarget;
		iNewTarget = iGetClosestSurvivor(client, iAimTarget, g_fChargeProximity);
		if(iNewTarget != -1)
			iAimTarget = iNewTarget;
	}

	static float vAngles[3];
	static float vVectors[3];
	static float vVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVelocity);

	static float vLength;
	vLength = GetVectorLength(vVelocity) + CROUCHING_HEIGHT;
	vLength = vLength < g_fChargeStartSpeed ? g_fChargeStartSpeed : vLength;

	if(bIsAliveSurvivor(iAimTarget))
	{
		static float vPos[3];
		static float vTarget[3];
		GetClientAbsOrigin(client, vPos);
		GetClientAbsOrigin(iAimTarget, vTarget);

		vTarget[2] += CROUCHING_HEIGHT;

		MakeVectorFromPoints(vPos, vTarget, vVectors);
		GetVectorAngles(vVectors, vAngles);

		if(GetEntityFlags(client) & FL_ONGROUND == 0)
			vLength += GetEntPropFloat(iAimTarget, Prop_Data, "m_flMaxspeed");
	}
	else
	{
		GetClientEyeAngles(client, vAngles);

		vVectors[0] = Cosine(DegToRad(vAngles[1])) * Cosine(DegToRad(vAngles[0]));
		vVectors[1] = Sine(DegToRad(vAngles[1])) * Cosine(DegToRad(vAngles[0]));
		vVectors[2] = Sine(DegToRad(vAngles[0]));

		if(GetEntityFlags(client) & FL_ONGROUND == 0)
			vLength += fNearestSurvivorDistance(client);
	}
	
	NormalizeVector(vVectors, vVectors);
	ScaleVector(vVectors, vLength);
	TeleportEntity(client, NULL_VECTOR, vAngles, vVectors);
}

bool bIsAliveSurvivor(int client)
{
	return bIsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool bIsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool bIsIncapacitated(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool bIsPinned(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	/*if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;*/
	return false;
}

bool bIsTargetWatchingAttacker(int iAttacker, int iOffsetThreshold)
{
	static int iTarget;
	static bool bIsWatching;

	bIsWatching = true;
	if(bIsAliveSurvivor((iTarget = g_iSpecialTarget[iAttacker]/*GetClientAimTarget(iAttacker)*/)) && RoundToNearest(fGetPlayerAimOffset(iTarget, iAttacker)) > iOffsetThreshold)
		bIsWatching = false;

	return bIsWatching;
}

float fGetPlayerAimOffset(int iAttacker, int iTarget)
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

int iGetClosestSurvivor(int client, int iAimTarget = -1, float fDistance)
{
	static int i;
	static int iCount;
	static float fDist;
	static float vPos[3];
	static float vTarget[3];
	static int iTargets[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientEyePosition(client, vPos);
	iCount = GetClientsInRange(vPos, RangeType_Visibility, iTargets, MAXPLAYERS);
	
	if(iCount == 0)
		return -1;
			
	static int iTarget;
	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	
	for(i = 0; i < iCount; i++)
	{
		iTarget = iTargets[i];
		if(iTarget && iTarget != iAimTarget && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget) && !bIsIncapacitated(iTarget) && !bIsPinned(iTarget) && !bHitWall(client, iTarget))
		{
			GetClientAbsOrigin(iTarget, vTarget);
			fDist = GetVectorDistance(vPos, vTarget);
			if(fDist < fDistance)
				aTargets.Set(aTargets.Push(fDist), iTarget, 1);
		}
	}

	if(aTargets.Length == 0)
	{
		iCount = 0;
		GetClientAbsOrigin(client, vPos);
		
		for(i = 1; i <= MaxClients; i++)
		{
			if(i != iAimTarget && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsIncapacitated(i) && !bIsPinned(i) && !bHitWall(client, i))
			{
				GetClientAbsOrigin(i, vTarget);
				fDist = GetVectorDistance(vPos, vTarget);
				if(fDist < fDistance)
					aTargets.Set(aTargets.Push(fDist), i, 1);
			}
		}
		
		if(aTargets.Length == 0)
		{
			delete aTargets;
			return -1;
		}
	}

	aTargets.Sort(Sort_Ascending, Sort_Float);
	iAimTarget = aTargets.Get(0, 1);
	delete aTargets;
	return iAimTarget;
}