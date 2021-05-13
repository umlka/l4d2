#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define BOOMER_BOOST 100.0

ConVar g_hVomitRange;

float g_fVomitRange;

public Plugin myinfo = 
{
	name = "AI BOOMER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() 
{
	g_hVomitRange = FindConVar("z_vomit_range");
	g_hVomitRange.AddChangeHook(ConVarChanged);

	FindConVar("z_vomit_fatigue").SetInt(1500);
	FindConVar("z_boomer_near_dist").SetInt(1);
	FindConVar("boomer_vomit_delay").SetFloat(0.01);
	FindConVar("boomer_exposed_time_tolerance").SetFloat(10000.0);

	HookEvent("ability_use", Event_AbilityUse);
}

public void OnPluginEnd() 
{
	FindConVar("z_vomit_fatigue").RestoreDefault();
	FindConVar("z_boomer_near_dist").RestoreDefault();
	FindConVar("boomer_vomit_delay").RestoreDefault();
	FindConVar("boomer_exposed_time_tolerance").RestoreDefault();
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
	g_fVomitRange = g_hVomitRange.FloatValue;
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsBotBoomer(client))
		Boomer_OnVomit(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 2 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	static float vVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	static float fDist;
	static float fCurrentSpeed;
	fDist = NearestSurvivorDistance(client);
	fCurrentSpeed = SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0));
	if(0.50 * g_fVomitRange < fDist < 1000.0 && fCurrentSpeed > 160.0) 
	{
		if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1 && GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
				
			static float vEyeAngles[3];
			GetClientEyeAngles(client, vEyeAngles);
			Client_PushForce(client, buttons, vEyeAngles, vVelocity, BOOMER_BOOST);
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

void Boomer_OnVomit(int client) 
{
	static float NearestAngles[3];
	if(MakeNearestAngles(client, NearestAngles))
		TeleportEntity(client, NULL_VECTOR, NearestAngles, NULL_VECTOR);
}

stock float NearestSurvivorDistance(int client)
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
			GetClientAbsOrigin(i, vTarget);
			fDists[iNum++] = GetVectorDistance(vOrigin, vTarget);
		}
	}

	SortFloats(fDists, iNum, Sort_Ascending);
	return fDists[0];
}

stock bool IsBotBoomer(int client) 
{
	return IsValidClient(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 2;
}

stock bool IsSurvivor(int client) 
{
	return IsValidClient(client) && GetClientTeam(client) == 2;
}

stock bool IsValidClient(int client) 
{
	return client > 0 && client <= MaxClients && IsClientInGame(client); 
}

bool MakeNearestAngles(int client, float NearestAngles[3])
{
	static int iAimTarget;
	static float vTarget[3];
	static float vOrigin[3];

	iAimTarget = GetClientAimTarget(client, true);
	if(!IsSurvivor(iAimTarget)) 
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
			if(iTarget && iTarget != iAimTarget && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget))
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

	if(!IsSurvivor(iAimTarget))
		return false;

	GetClientAbsOrigin(client, vOrigin);
	GetClientAbsOrigin(iAimTarget, vTarget);
	MakeVectorFromPoints(vOrigin, vTarget, vOrigin);
	GetVectorAngles(vOrigin, NearestAngles);
	return true;
}
