#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar g_hChargeProximity;
ConVar g_hHealthThresholdCharger;
ConVar g_hAimOffsetSensitivityCharger;

float g_fChargeProximity;

int g_iHealthThresholdCharger;
int g_iAimOffsetSensitivityCharger;

bool g_bShouldCharge[MAXPLAYERS + 1];

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
	g_hChargeProximity = CreateConVar("ai_charge_proximity", "300.0", "How close a client will approach before charging");
	g_hHealthThresholdCharger = CreateConVar("ai_health_threshold_charger", "300", "Charger will charge if its health drops to this level");
	g_hAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger", "20", "If the client has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 179.0);
	
	g_hChargeProximity.AddChangeHook(ConVarChanged);
	g_hHealthThresholdCharger.AddChangeHook(ConVarChanged);
	g_hAimOffsetSensitivityCharger.AddChangeHook(ConVarChanged);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("charger_charge_start", Event_ChargerChargeStart);
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
	g_fChargeProximity = g_hChargeProximity.FloatValue;
	g_iHealthThresholdCharger = g_hHealthThresholdCharger.IntValue;
	g_iAimOffsetSensitivityCharger = g_hAimOffsetSensitivityCharger.IntValue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bShouldCharge[client] = false;
}

public void Event_ChargerChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsFakeClient(client))
		return;

	int flags = GetEntProp(client, Prop_Send, "m_fFlags");
	SetEntProp(client, Prop_Send, "m_fFlags", flags & ~FL_FROZEN);
	Charger_OnCharge(client);
	SetEntProp(client, Prop_Send, "m_fFlags", flags);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 6 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	static float fSurvivorProximity;
	fSurvivorProximity = NearestSurvivorDistance(client);
	if(fSurvivorProximity > g_fChargeProximity && GetEntProp(client, Prop_Send, "m_iHealth") > g_iHealthThresholdCharger)
	{
		if(!g_bShouldCharge[client])
			BlockCharge(client);
	}
	else
		g_bShouldCharge[client] = true;
		
	static int iTarget;
	iTarget = GetClientAimTarget(client, true);
	if(g_bShouldCharge[client] && -1.0 < fSurvivorProximity < 100.0 && ReadyAbility(client) && !IsChargeSurvivor(client) && IsAliveSurvivor(iTarget) && !IsIncapacitated(iTarget))
	{
		buttons |= IN_ATTACK;
		return Plugin_Changed;
	}

	if(200.0 < fSurvivorProximity < 1000.0 && GetEntityFlags(client) & FL_ONGROUND != 0 && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") - 30.0)
		{
			static float vEyeAngles[3];
			GetClientEyeAngles(client, vEyeAngles);
			if(Bhop(client, buttons, vEyeAngles))
				return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

bool Bhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	bJumped = false;

	if(buttons & IN_FORWARD)
	{
		if(Client_Push(client, buttons, vAng, 180.0))
			bJumped = true;
	}
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		if(Client_Push(client, buttons, vAng, 90.0))
			bJumped = true;
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		if(Client_Push(client, buttons, vAng, 90.0))
			bJumped = true;
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		if(Client_Push(client, buttons, vAng, 90.0))
			bJumped = true;
	}
	
	return bJumped;
}

bool Client_Push(int client, int &buttons, const float vAng[3], float fForce)
{
	static float vVec[3];
	GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);

	if(WontFall(client, vVel))
	{
		buttons |= IN_DUCK;
		buttons |= IN_JUMP;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
		return true;
	}

	return false;
}
/*
bool Bhop(int client, int &buttons, const float vAng[3])
{
	static bool bJumped;
	bJumped = false;

	static float vVec[3];

	if(buttons & IN_FORWARD || buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(Client_Push(client, buttons, vVec, buttons & IN_FORWARD ? 180.0 : -90.0))
			bJumped = true;
	}

	if(buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		if(Client_Push(client, buttons, vVec, buttons & IN_MOVELEFT ? -90.0 : 90.0))
			bJumped = true;
	}

	return bJumped;
}

bool Client_Push(int client, int &buttons, float vVec[3], float fForce)
{
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);

	if(WontFall(client, vVel))
	{
		buttons |= IN_DUCK;
		buttons |= IN_JUMP;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
		return true;
	}

	return false;
}
*/
#define JUMP_HEIGHT 56.0
bool WontFall(int client, const float vVel[3])
{
	static float vStart[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vStart);
	AddVectors(vVel, vStart, vEnd);

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	vStart[2] += 20.0;

	static float fHeight;
	fHeight = vVel[2] > 0.0 ? vVel[2] : JUMP_HEIGHT;

	vEnd[2] += fHeight;
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vStart, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceEntityFilter);
	vEnd[2] -= fHeight;

	static bool bDidHit;
	bDidHit = false;

	static float vEndNonCol[3];

	if(hTrace != null)
	{
		if(TR_DidHit(hTrace))
		{
			bDidHit = true;
			TR_GetEndPosition(vEndNonCol, hTrace);
			if(GetVectorDistance(vStart, vEndNonCol) < 64.0)
			{
				delete hTrace;
				return false;
			}
		}
		delete hTrace;
	}
	
	if(!bDidHit)
		vEndNonCol = vEnd;

	static float vDown[3];
	vDown[0] = vEndNonCol[0];
	vDown[1] = vEndNonCol[1];
	vDown[2] = vEndNonCol[2] - 100000.0;

	hTrace = TR_TraceHullFilterEx(vEndNonCol, vDown, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceEntityFilter);
	if(hTrace != null)
	{
		if(TR_DidHit(hTrace))
		{
			TR_GetEndPosition(vEnd, hTrace);
			if(vEndNonCol[2] - vEnd[2] > 124.0)
			{
				delete hTrace;
				return false;
			}
			delete hTrace;
			return true;
		}
		delete hTrace;
	}
	return false;
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

bool IsChargeSurvivor(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0;
}

bool ReadyAbility(int client)
{
	static int iAbility;
	iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	return iAbility != -1 && GetEntPropFloat(iAbility, Prop_Send, "m_timestamp") < GetGameTime();
}

void BlockCharge(int client)
{
	static int iAbility;
	iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
		SetEntPropFloat(iAbility, Prop_Send, "m_timestamp", GetGameTime() + 0.1);	
}

void Charger_OnCharge(int client)
{
	static float NearestVectors[3];
	if(MakeNearestVectors(client, NearestVectors))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVelocity);
		NormalizeVector(NearestVectors, NearestVectors);
		
		static float vLenght;
		vLenght = GetVectorLength(vVelocity);
		ScaleVector(NearestVectors, vLenght < 500.0 ? 500.0 : vLenght);

		static float NearestAngles[3];
		GetVectorAngles(NearestVectors, NearestAngles);
		TeleportEntity(client, NULL_VECTOR, NearestAngles, NearestVectors);
	}
}

#define CROUCHING_HEIGHT 56.0
bool MakeNearestVectors(int client, float NearestVectors[3])
{
	static int iAimTarget;
	static float vOrigin[3];
	static float vTarget[3];

	GetClientAbsOrigin(client, vOrigin);

	iAimTarget = GetClientAimTarget(client, true);
	if(!IsAliveSurvivor(iAimTarget) || IsIncapacitated(iAimTarget) || IsPinned(iAimTarget) || IsTargetWatchingAttacker(client, g_iAimOffsetSensitivityCharger))
	{
		static int iNewTarget;
		iNewTarget = GetClosestSurvivor(client, iAimTarget);
		if(iNewTarget != -1)
		{
			GetClientAbsOrigin(iNewTarget, vTarget);
			if(GetVectorDistance(vOrigin, vTarget) < g_fChargeProximity)
				iAimTarget = iNewTarget;
		}
	}

	if(!IsAliveSurvivor(iAimTarget))
		return false;

	GetClientAbsOrigin(iAimTarget, vTarget);

	vTarget[2] += CROUCHING_HEIGHT;
	MakeVectorFromPoints(vOrigin, vTarget, NearestVectors);
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

int GetClosestSurvivor(int client, int iAimTarget = -1)
{
	static int i;
	static int iNum;
	static float vOrigin[3];
	static float vTarget[3];
	static int iTargets[MAXPLAYERS + 1];
	
	GetClientEyePosition(client, vOrigin);
	iNum = GetClientsInRange(vOrigin, RangeType_Visibility, iTargets, MAXPLAYERS);
	
	if(iNum == 0)
		return -1;
			
	static int iTarget;
	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	
	for(i = 0; i < iNum; i++)
	{
		iTarget = iTargets[i];
		if(iTarget && iTarget != iAimTarget && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget) && !IsIncapacitated(iTarget) && !IsPinned(iTarget))
		{
			GetClientAbsOrigin(iTarget, vTarget);
			aTargets.Set(aTargets.Push(GetVectorDistance(vOrigin, vTarget)), iTarget, 1);
		}
	}

	if(aTargets.Length == 0)
	{
		delete aTargets;
		return -1;
	}
		
	aTargets.Sort(Sort_Ascending, Sort_Float);
	iAimTarget = aTargets.Get(0, 1);
	delete aTargets;
	return iAimTarget;
}

bool IsAliveSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool IsIncapacitated(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
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
