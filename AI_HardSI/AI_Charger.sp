#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar g_hChargeProximity;
ConVar g_hAimOffsetSensitivityCharger;

float g_fChargeProximity;

int g_iAimOffsetSensitivityCharger;
int g_bShouldCharge[MAXPLAYERS + 1];

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
	g_hChargeProximity = CreateConVar("ai_charge_proximity", "300", "How close a client will approach before charging");	
	g_hAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger", "20", "If the client has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 179.0);
	
	g_hChargeProximity.AddChangeHook(ConVarChanged);
	g_hAimOffsetSensitivityCharger.AddChangeHook(ConVarChanged);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("charger_charge_start", Event_ChargerChargeStart);
	HookEvent("charger_charge_end",	Event_ChargerChargeEnd);
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
	g_iAimOffsetSensitivityCharger = g_hAimOffsetSensitivityCharger.IntValue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	g_bShouldCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}

bool IsAliveSurvivor(int client) 
{
	return IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsValidClient(int client) 
{
	return client > 0 && client <= MaxClients && IsClientInGame(client); 
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 6 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;
	
	static float fDist;
	static int iTarget;
	fDist = NearestSurvivorDistance(client);
	iTarget = GetClientAimTarget(client, true);
	if((buttons & IN_ATTACK2) && fDist < 100.0 && ReadyAbility(client))
	{
		if(IsAliveSurvivor(iTarget) && !IsIncapacitated(iTarget) && !IsPinned(iTarget) && IsVisibleTo(client, iTarget))
		{
			buttons |= IN_ATTACK;
			return Plugin_Changed;
		}
	}

	static float vOrigin[3];
	static int iSurvivorProximity;
	GetClientAbsOrigin(client, vOrigin);
	iSurvivorProximity = GetSurvivorProximity(vOrigin, iTarget);
	if(iSurvivorProximity > g_fChargeProximity)
	{	
		if(!g_bShouldCharge[client]) 
			BlockCharge(client);
	} 
	else
	{
		g_bShouldCharge[client] = true;
		if(buttons & IN_ATTACK)
			return Plugin_Continue;
	}

	if(0.50 * g_fChargeProximity < fDist < 1000.0 && GetEntityFlags(client) & FL_ONGROUND != 0 && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		static float fCurrentSpeed;
		fCurrentSpeed = SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0));
		if(fCurrentSpeed > 190.0)
		{
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;

			static float vEyeAngles[3];
			GetClientEyeAngles(client, vEyeAngles);
			Bhopx(client, buttons, vEyeAngles);
		}
	}

	return Plugin_Continue;
}

void Bhopx(int client, int &buttons, const float vAng[3])
{
	static float vVec[3];
	if(buttons & IN_FORWARD)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		Client_Pushx(client, vVec, 120.0);
	}
		
	if(buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		Client_Pushx(client, vVec, -60.0);
	}
	
	if(buttons & IN_MOVELEFT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Pushx(client, vVec, -60.0);
	}

	if(buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Pushx(client, vVec, 60.0);
	}
}

void Client_Pushx(int client, float vVec[3], float fForce)
{
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}
/*
void Bhop(int client, int &buttons, float vAng[3])
{
	if(buttons & IN_FORWARD)
		Client_Push(client, vAng, 120.0);
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		Client_Push(client, vAng, 60.0);
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		Client_Push(client, vAng, 60.0);
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		Client_Push(client, vAng, 60.0);
	}
}

void Client_Push(int client, const float vAng[3], float fForce)
{
	static float vVec[3];
	GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}
*/
bool IsVisibleTo(int client, int iTarget)
{
	static float vEyePos[3], vTarget[3];
	static float vAngles[3], vLookAt[3];
	
	GetClientEyePosition(client, vEyePos);
	GetClientEyePosition(iTarget, vTarget);

	MakeVectorFromPoints(vEyePos, vTarget, vLookAt);
	GetVectorAngles(vLookAt, vAngles);

	static Handle hTrace;
	hTrace = TR_TraceRayFilterEx(vEyePos, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter, client);

	static bool bIsVisible;
	bIsVisible = false;
	if(TR_DidHit(hTrace))
	{
		static float vStart[3];
		TR_GetEndPosition(vStart, hTrace);

		if((GetVectorDistance(vEyePos, vStart, false) + 25.0) >= GetVectorDistance(vEyePos, vTarget))
			bIsVisible = true;
	}
	delete hTrace;
	return bIsVisible;
}

bool TraceFilter(int entity, int contentMask, any data) 
{
	if(entity == data)
		return false;
	else
	{
		static char sClass[9];
		GetEntityClassname(entity, sClass, sizeof(sClass));
		if(strcmp(sClass, "infected") == 0)
			return false;
		else if(strcmp(sClass, "witch") == 0)
			return false;
		return true;
	}
}

int GetClosestSurvivor(const float vPos[3], int iExcludeSurvivor = -1) 
{
	static int i;
	static int iNum;
	int[] iTargets = new int[MaxClients];

	iNum = 0;

	for(i = 1; i <= MaxClients; i++)
	{
		if(i != iExcludeSurvivor && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			iTargets[iNum++] = i;
	}
	
	if(iNum == 0)
		return -1;

	static ArrayList aTargets;
	static int iTarget;
	static float vTarget[3];
	aTargets = new ArrayList(2);
	
	for(i = 0; i < iNum; i++)
	{
		iTarget = iTargets[i];
		GetClientAbsOrigin(iTarget, vTarget);
		aTargets.Set(aTargets.Push(GetVectorDistance(vPos, vTarget)), iTarget, 1);
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

int GetSurvivorProximity(const float vPos[3], int iTarget = -1) 
{
	if(!IsAliveSurvivor(iTarget)) 
		iTarget = GetClosestSurvivor(vPos);

	if(iTarget == -1)
		return -1;

	static float vTarget[3];
	GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vTarget);
	return RoundToNearest(GetVectorDistance(vPos, vTarget));
}

bool IsPinned(int client) 
{
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)	   // charger pound
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)		// charger carry
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)	   // hunter
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)	   //jockey
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)		  //smoker
		return true;
	return false;
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

bool ReadyAbility(int client)
{
	static int iAbility;
	iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1 && IsValidEdict(iAbility)) 
		return GetEntPropFloat(iAbility, Prop_Send, "m_timestamp") < GetGameTime();

	return false;
}

public void Event_ChargerChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	int flags = GetEntProp(client, Prop_Send, "m_fFlags");
	SetEntProp(client, Prop_Send, "m_fFlags", flags & ~FL_FROZEN);
	Charger_OnCharge(client);
	SetEntProp(client, Prop_Send, "m_fFlags", flags);
	
	int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(entity != -1)
		SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 999.9);
}

public void Event_ChargerChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client)
	{
		int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(entity != -1)
			SetEntPropFloat(entity, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.0);
	}
}

void BlockCharge(int client) 
{
	int iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
		SetEntPropFloat(iAbility, Prop_Send, "m_timestamp", GetGameTime() + 0.1);	
}

void Charger_OnCharge(int client) 
{
	static float NearestAngles[3];
	if(MakeNearestAngles(client, NearestAngles))
	{
		float vVec[3];
		GetAngleVectors(NearestAngles, NULL_VECTOR, vVec, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		TeleportEntity(client, NULL_VECTOR, NearestAngles, vVec);
	}
}

bool IsIncapacitated(int client) 
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool IsTargetWatchingAttacker(int iAttacker, int iOffsetThreshold) 
{
	static bool bIsWatching;
	bIsWatching = true;

	if(GetClientTeam(iAttacker) == 3 && IsPlayerAlive(iAttacker)) 
	{
		static int iTarget;
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
	}	
	return bIsWatching;
}

float GetPlayerAimOffset(int iAttacker, int iTarget) 
{
	if(!IsClientInGame(iAttacker) || !IsPlayerAlive(iAttacker))
		ThrowError("Client is not Alive."); 
	if(!IsClientInGame(iTarget) || !IsPlayerAlive(iTarget))
		ThrowError("Target is not Alive.");
		
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

bool MakeNearestAngles(int client, float NearestAngles[3])
{
	static int iAimTarget;
	static float vTarget[3];
	static float vOrigin[3];

	iAimTarget = GetClientAimTarget(client, true);
	if(!IsAliveSurvivor(iAimTarget) || IsIncapacitated(iAimTarget) || IsPinned(iAimTarget) || !IsTargetWatchingAttacker(client, g_iAimOffsetSensitivityCharger))
	{
		static int i;
		static int iNum;
		static int iTargets[MAXPLAYERS + 1];
	
		GetClientEyePosition(client, vOrigin);
		iNum = GetClientsInRange(vOrigin, RangeType_Visibility, iTargets, MAXPLAYERS);
	
		if(iNum == 0)
			return false;
			
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

		if(aTargets.Length != 0)
		{
			aTargets.Sort(Sort_Ascending, Sort_Float);
			iAimTarget = aTargets.Get(0, 1);
		}
		delete aTargets;
	}

	if(!IsAliveSurvivor(iAimTarget))
		return false;

	GetClientAbsOrigin(client, vOrigin);
	GetClientAbsOrigin(iAimTarget, vTarget);
	MakeVectorFromPoints(vOrigin, vTarget, vOrigin);
	GetVectorAngles(vOrigin, NearestAngles);
	return true;
}
