#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define TANK_BOOST 80.0
#define TANK_MELEE_SCAN_DELAY 0.25
#define TANK_ROCK_AIM_TIME    4.0
#define TANK_ROCK_AIM_DELAY   0.25

ConVar g_hTankAttackRange;

float g_fTankAttackRange;
float g_fDelay[MAXPLAYERS + 1][3];

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
		for(int j; j < 3; j++) 
			g_fDelay[i][j] = fTime;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;
		
	static float vVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	static float fDist;
	static float fCurrentSpeed;
	fDist = NearestSurvivorDistance(client, true);
	fCurrentSpeed = SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0));
	if(GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && g_fTankAttackRange + 45.0 < fDist < 1000.0 && fCurrentSpeed > 190.0) 
	{
		if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1 && GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			buttons &= ~IN_ATTACK2;
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
					
			static float vEyeAngles[3];
			GetClientEyeAngles(client, vEyeAngles);
			Client_PushForce(client, buttons, vEyeAngles, vVelocity, TANK_BOOST);

			if(DelayExpired(client, 0, TANK_MELEE_SCAN_DELAY)) 
			{
				DelayStart(client, 0);
				if(NearestSurvivorDistance(client, false) < g_fTankAttackRange * 0.95) 
				{
					buttons |= IN_ATTACK;
					return Plugin_Changed;
				}
			}
		}
	}

	if(buttons & IN_ATTACK2)
	{
		DelayStart(client, 1);
		DelayStart(client, 2);
	}

	if(DelayExpired(client, 1, TANK_ROCK_AIM_DELAY) && !DelayExpired(client, 2, TANK_ROCK_AIM_TIME))
	{
		static int iTarget;
		iTarget = GetClientAimTarget(client, true);
		if(iTarget == -1 || IsIncapacitated(iTarget) || IsPinned(iTarget) || !IsVisibleTo(client, iTarget)) 
		{
			iTarget = NearestVisibleNormalSurvivor(client);
			if(iTarget > 0) 
			{
				if(angles[2] == 0.0) 
				{
					static float vAimAngles[3];
					ComputeAimAngles(client, iTarget, vAimAngles, AimTarget_Chest);
					vAimAngles[2] = 0.0;
					TeleportEntity(client, NULL_VECTOR, vAimAngles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}

	return Plugin_Continue;
}

stock void Client_PushForce(int client, int &buttons, float vAng[3], float vVel[3], float fForce)
{
	static float vVec[3];
	if((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVERIGHT) || (buttons & IN_MOVELEFT))
	{
		if((buttons & IN_FORWARD) || (buttons & IN_BACK))
			GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		else
		{
			ScaleVector(vVel, 0.5);
			GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		}

		NormalizeVector(vVec, vVec);
	
		if((buttons & IN_FORWARD) || (buttons & IN_MOVERIGHT))
			ScaleVector(vVec, fForce);
		else
			ScaleVector(vVec, -1.0 * fForce);

		AddVectors(vVel, vVec, vVel);
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
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

stock void DelayStart(int client, int index)
{
	g_fDelay[client][index] = GetGameTime();
}

stock bool DelayExpired(int client, int index, float fDelay)
{
	return GetGameTime() - g_fDelay[client][index] > fDelay;
}

stock bool IsIncapacitated(int client) 
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0;
}

stock bool IsPinned(int client) 
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

stock bool IsVisibleTo(int client, int iTarget)
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

stock bool TraceFilter(int entity, int contentMask, any data) 
{
	return entity != data;
}

stock void ComputeAimAngles(int client, int iTarget, float vAngles[3], AimTarget iType = AimTarget_Eye)
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
			vTarget[2] += 45.0; // このくらい
		}
	}

	MakeVectorFromPoints(vEyePos, vTarget, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
}

stock float NearestSurvivorDistance(int client, bool bIncapacitated)
{
	static int i;
	static int iNum;
	static float vOrigin[3];
	static float vTarget[3];
	float[] fDists = new float[MaxClients];
	
	iNum = 0;

	GetClientAbsOrigin(client, vOrigin);

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if(!bIncapacitated && IsIncapacitated(i))
				continue;

			GetClientAbsOrigin(i, vTarget);
			fDists[iNum++] = GetVectorDistance(vOrigin, vTarget);
		}
	}

	SortFloats(fDists, iNum, Sort_Ascending);
	return fDists[0];
}

stock int NearestVisibleNormalSurvivor(int client)
{
	static int i;
	static int iNum;
	static int iTarget;
	static float vEyePos[3];
	static float vTarget[3];
	static ArrayList aTargets;
	static int iTargets[MAXPLAYERS + 1];

	GetClientEyePosition(client, vEyePos);
	iNum = GetClientsInRange(vEyePos, RangeType_Visibility, iTargets, MAXPLAYERS);

	if(iNum == 0)
		return -1;

	aTargets = new ArrayList(2);

	for(i = 0; i < iNum; i++)
	{
		iTarget = iTargets[i];
		if(iTarget && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget) && !IsIncapacitated(iTarget) && !IsPinned(iTarget))
		{
			GetClientAbsOrigin(iTarget, vTarget);
			aTargets.Set(aTargets.Push(GetVectorDistance(vEyePos, vTarget)), iTarget, 1);
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

stock bool IsSurvivor(int client) 
{
	return IsValidClient(client) && GetClientTeam(client) == 2;
}

stock bool IsValidClient(int client) 
{
	return client > 0 && client <= MaxClients && IsClientInGame(client); 
}
