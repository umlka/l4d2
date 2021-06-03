#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define TANK_MELEE_SCAN_DELAY 0.25
#define TANK_ROCK_AIM_TIME    4.0
#define TANK_ROCK_AIM_DELAY   0.25

ConVar g_hTankAttackRange;

float g_fTankAttackRange;
float g_fDelay[MAXPLAYERS + 1][2];

enum AimTarget
{
	AimTarget_Eye,
	AimTarget_Body,
	AimTarget_Chest
};

public Plugin myinfo = 
{
	name = "AI TANK",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart()
{
	g_hTankAttackRange = FindConVar("tank_attack_range");
	g_hTankAttackRange.AddChangeHook(ConVarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
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
	g_fTankAttackRange = g_hTankAttackRange.FloatValue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	float fTime = GetGameTime();
	for(int i; i <= MaxClients; i++)
		for(int j; j < 2; j++)
			g_fDelay[i][j] = fTime;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;
		
	static int i;
	static float fDist;
	static int iNoIncapped;
	static int iNormalAlive;
	static float vOrigin[3];
	static float vTarget[3];
	static float fNoIncappeds[MAXPLAYERS + 1];
	static float fNormalAlives[MAXPLAYERS + 1];
	
	iNoIncapped = 0;
	iNormalAlive = 0;

	GetClientAbsOrigin(client, vOrigin);

	for(i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, vTarget);
			fDist = GetVectorDistance(vOrigin, vTarget);
			if(!IsIncapacitated(i))
				fNoIncappeds[iNoIncapped++] = fDist;

			fNormalAlives[iNormalAlive++] = fDist;
		}
	}

	if(iNormalAlive != 0)
	{
		SortFloats(fNormalAlives, iNormalAlive, Sort_Ascending);
		if(g_fTankAttackRange + 45.0 < fNormalAlives[0] < 1000.0 && GetEntityFlags(client) & FL_ONGROUND != 0 && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
		{
			static float vVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
			if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > 200.0 && !IsWatchingLadder(client))
			{
				//buttons &= ~IN_ATTACK2;
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
					
				static float vEyeAngles[3];
				GetClientEyeAngles(client, vEyeAngles);
				Bhop(client, buttons, vEyeAngles);
				return Plugin_Changed;
			}
		}
	}

	if(DelayExpired(client, 0, TANK_MELEE_SCAN_DELAY))
	{
		DelayStart(client, 0);
		if(iNoIncapped != 0)
		{
			SortFloats(fNoIncappeds, iNoIncapped, Sort_Ascending);
			if(-1.0 < fNoIncappeds[0] < g_fTankAttackRange * 0.95)
			{
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}

	if(buttons & IN_ATTACK2)
		DelayStart(client, 1);

	if(DelayExpired(client, 1, TANK_ROCK_AIM_DELAY) && !DelayExpired(client, 1, TANK_ROCK_AIM_TIME))
	{
		static int iAimTarget;
		iAimTarget = GetClientAimTarget(client, true);
		if(!IsAliveSurvivor(iAimTarget) || IsIncapacitated(iAimTarget) || IsPinned(iAimTarget) || !IsVisibleTo(client, iAimTarget))
		{
			iAimTarget = GetClosestSurvivor(client, iAimTarget);
			if(iAimTarget != -1)
			{
				if(angles[2] == 0.0)
				{
					static float vAimAngles[3];
					ComputeAimAngles(client, iAimTarget, vAimAngles, AimTarget_Chest);
					vAimAngles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, vAimAngles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

bool IsWatchingLadder(int client)
{
	static int entity;
	entity = GetClientAimTarget(client, false);
	if(entity == -1 || !IsValidEntity(entity))
		return false;

	return HasEntProp(entity, Prop_Data, "m_climbableNormal");
}
/*
void Bhop(int client, int &buttons, const float vAng[3])
{
	static float vVec[3];
	if(buttons & IN_FORWARD)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		Client_Push(client, vVec, 80.0);
	}

	if(buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		Client_Push(client, vVec, -80.0);
	}

	if(buttons & IN_MOVELEFT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Push(client, vVec, -80.0);
	}

	if(buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Push(client, vVec, 80.0);
	}
}

void Client_Push(int client, float vVec[3], float fForce)
{
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}
*/
void Bhop(int client, int &buttons, float vAng[3])
{
	if(buttons & IN_FORWARD)
		Client_Push(client, vAng, 80.0);
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		Client_Push(client, vAng, 80.0);
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		Client_Push(client, vAng, 80.0);
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		Client_Push(client, vAng, 80.0);
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

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if(IsFakeClient(client) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void DelayStart(int client, int index)
{
	g_fDelay[client][index] = GetGameTime();
}

bool DelayExpired(int client, int index, float fDelay)
{
	return GetGameTime() - g_fDelay[client][index] > fDelay;
}

bool IsIncapacitated(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool IsAliveSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
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

bool IsVisibleTo(int client, int iTarget)
{
	static float vAngles[3];
	static float vEyePos[3];

	GetClientEyePosition(client, vEyePos);
	ComputeAimAngles(client, iTarget, vAngles);
	
	static Handle hTrace;
	hTrace = TR_TraceRayFilterEx(vEyePos, vAngles, MASK_SOLID, RayType_Infinite, TraceFilter, client);
	if(hTrace != null)
	{
		if(TR_DidHit(hTrace))
		{
			delete hTrace;
			return TR_GetEntityIndex(hTrace) == iTarget;
		}
		delete hTrace;
	}
	return false;
}

bool TraceFilter(int entity, int contentMask, any data)
{
	return entity != data;
}

void ComputeAimAngles(int client, int iTarget, float vAngles[3], AimTarget iType = AimTarget_Eye)
{
	static float vEyePos[3];
	static float vTarget[3];
	static float vLookAt[3];

	GetClientEyePosition(client, vEyePos);

	switch(iType)
	{
		case AimTarget_Eye:
			GetClientEyePosition(iTarget, vTarget);

		case AimTarget_Body:
			GetClientAbsOrigin(iTarget, vTarget);

		case AimTarget_Chest:
		{
			GetClientAbsOrigin(iTarget, vTarget);
			vTarget[2] += 45.0;
		}
	}

	MakeVectorFromPoints(vEyePos, vTarget, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
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
