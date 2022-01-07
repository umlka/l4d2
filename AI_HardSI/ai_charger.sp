#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

ConVar
	g_hChargerBhop,
	g_hChargeProximity,
	g_hChargeStartSpeed,
	g_hHealthThresholdCharger,
	g_hAimOffsetSensitivityCharger;

float
	g_fChargeProximity,
	g_fChargeStartSpeed,
	g_fAimOffsetSensitivityCharger;

int
	g_iHealthThresholdCharger;

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
	g_hAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger", "20.0", "If the charger has a target, it will not straight charge if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 180.0);
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
	g_fAimOffsetSensitivityCharger = g_hAimOffsetSensitivityCharger.FloatValue;
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

	int flags = GetEntityFlags(client);
	SetEntityFlags(client, flags & ~FL_FROZEN);
	int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(entity != -1)
		SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 2.5);
	vCharger_OnCharge(client);
	SetEntityFlags(client, flags);
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
	else if(!bHitWall(client))
		g_bShouldCharge[client] = true;
		
	if(g_bShouldCharge[client] && -1.0 < fSurvivorProximity < 150.0 && bChargerCanCharge(client))
	{
		static int iTarget;
		iTarget = GetClientAimTarget(client, true);
		if(bIsAliveSurvivor(iTarget) && !bIsIncapacitated(iTarget))
		{
			static float vPos[3];
			static float vTarg[3];
			GetClientAbsOrigin(client, vPos);
			GetClientAbsOrigin(iTarget, vTarg);
			if(GetVectorDistance(vPos, vTarg) < 150.0 && !bHitWall(client, iTarget))
			{
				g_bShouldCharge[client] = true;

				buttons |= IN_ATTACK;
				buttons |= IN_ATTACK2;
				return Plugin_Changed;
			}
		}
	}

	if(g_bChargerBhop && 150.0 < fSurvivorProximity < 1000.0 && GetEntityFlags(client) & FL_ONGROUND && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		if(SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0)) > 150.0)
		{
			static float vAng[3];
			GetClientEyeAngles(client,  vAng);
			if(bBhop(client, buttons,  vAng))
				return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	bJumped = false;

	if(buttons & IN_FORWARD || buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
		if(bClientPush(client, buttons, vAng, buttons & IN_FORWARD ? 180.0 : -90.0))
			bJumped = true;
	}

	if(buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		static float vPos[3];
		static float vVec[3];
		GetAngleVectors(vAng, NULL_VECTOR, vAng, NULL_VECTOR);

		vVec = vAng;
		vVec[0] = vVec[2] = 0.0;
		GetAngleVectors(vVec, vVec, NULL_VECTOR, NULL_VECTOR);
		GetClientAbsOrigin(client, vPos);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, 33.0);
		AddVectors(vPos, vVec, vVec);

		static float vMins[3];
		static float vMaxs[3];
		GetClientMins(client, vMins);
		GetClientMaxs(client, vMaxs);

		static Handle hTrace;
		hTrace = TR_TraceHullFilterEx(vPos, vVec, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
		if(!TR_DidHit(hTrace))
		{
			if(bClientPush(client, buttons, vAng, buttons & IN_MOVELEFT ? -90.0 : 90.0))
				bJumped = true;
		}

		delete hTrace;
	}

	return bJumped;
}

bool bClientPush(int client, int &buttons, float vVec[3], float fForce)
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

#define OBSTACLE_HEIGHT 18.0
bool bWontFall(int client, const float vVel[3])
{
	static float vPos[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vPos);
	AddVectors(vPos, vVel, vEnd);
	vPos[2] += OBSTACLE_HEIGHT;

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static bool bHit;
	static Handle hTrace;
	static float vEndPos[3];

	bHit = false;
	vEnd[2] += OBSTACLE_HEIGHT;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	vEnd[2] -= OBSTACLE_HEIGHT;

	if(TR_DidHit(hTrace))
	{
		bHit = true;
		TR_GetEndPosition(vEndPos, hTrace);
		if(GetVectorDistance(vPos, vEndPos) < 64.0)
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

	hTrace = TR_TraceHullFilterEx(vEndPos, vDown, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
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

bool bHitWall(int client, int iTarget = -1)
{
	static float vPos[3];
	static float vAng[3];
	GetClientAbsOrigin(client, vPos);
	vPos[2] += 20.0;

	if(iTarget != -1)
	{
		GetClientAbsOrigin(iTarget, vAng);
		vAng[2] += 20.0;
	}
	else
	{
		GetClientEyeAngles(client, vAng);
		GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vAng, vAng);
		ScaleVector(vAng, g_fChargeProximity); 
		AddVectors(vPos, vAng, vAng);
	}

	static bool bHit;
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vPos, vAng, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 36.0}), MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	bHit = TR_DidHit(hTrace);
	delete hTrace;
	return bHit;
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

#define CROUCHING_EYE 44.0
#define PLAYER_HEIGHT 72.0
void vCharger_OnCharge(int client)
{
	static int iTarget;
	iTarget = GetClientAimTarget(client, true);
	if(!bIsAliveSurvivor(iTarget) || bIsIncapacitated(iTarget) || bIsPinned(iTarget) || bHitWall(client, iTarget) || bIsBeingWatched(client, g_fAimOffsetSensitivityCharger))
		iTarget = iGetClosestSurvivor(client, iTarget, g_fChargeStartSpeed);

	if(iTarget == -1)
		return;

	static float vVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVelocity);

	static float vLength;
	vLength = GetVectorLength(vVelocity);
	vLength = vLength < g_fChargeStartSpeed ? g_fChargeStartSpeed : vLength;

	static float vPos[3];
	static float vTarg[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsOrigin(iTarget, vTarg);

	float fHeight = vTarg[2] - vPos[2];
	if(fHeight > PLAYER_HEIGHT)
		vLength += fHeight;
	
	if(GetEntityFlags(client) & FL_ONGROUND == 0)
	{
		vTarg[2] += CROUCHING_EYE;
		vLength += g_fChargeStartSpeed;
	}

	MakeVectorFromPoints(vPos, vTarg, vVelocity);

	static float vAngles[3];
	GetVectorAngles(vVelocity, vAngles);

	NormalizeVector(vVelocity, vVelocity);
	ScaleVector(vVelocity, vLength);
	TeleportEntity(client, NULL_VECTOR, vAngles, vVelocity);
}

bool bIsAliveSurvivor(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
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

int iGetClosestSurvivor(int client, int iExclude = -1, float fDistance)
{
	static int i;
	static int iCount;
	static float fDist;
	static float vPos[3];
	static float vTarg[3];
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
		if(iTarget && iTarget != iExclude && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget) && !bIsIncapacitated(iTarget) && !bIsPinned(iTarget) && !bHitWall(client, iTarget))
		{
			GetClientAbsOrigin(iTarget, vTarg);
			fDist = GetVectorDistance(vPos, vTarg);
			if(fDist < fDistance)
				aTargets.Set(aTargets.Push(fDist), iTarget, 1);
		}
	}

	if(aTargets.Length == 0)
	{
		delete aTargets;
		return -1;
	}

	aTargets.Sort(Sort_Ascending, Sort_Float);
	iTarget = aTargets.Get(0, 1);
	delete aTargets;
	return iTarget;
}