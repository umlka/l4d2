#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

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

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast) 
{
	char sAbility[16];
	event.GetString("ability", sAbility, sizeof(sAbility));
	if(strcmp(sAbility, "ability_vomit") == 0)
		Boomer_OnVomit(GetClientOfUserId(event.GetInt("userid")));
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 2 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND != 0 && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > 160.0)
		{
			if(0.50 * g_fVomitRange < NearestSurvivorDistance(client) < 1000.0)
			{
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				static float vEyeAngles[3];
				GetClientEyeAngles(client, vEyeAngles);
				Bhopx(client, buttons, vEyeAngles);
				return Plugin_Changed;
			}
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
		Client_Pushx(client, vVec, 180.0);
	}

	if(buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		Client_Pushx(client, vVec, -90.0);
	}
	
	if(buttons & IN_MOVELEFT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Pushx(client, vVec, -90.0);
	}

	if(buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Pushx(client, vVec, 90.0);
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
void Boomer_OnVomit(int client) 
{
	if(IsBotBoomer(client))
	{
		static float NearestVectors[3];
		if(MakeNearestVectors(client, NearestVectors))
		{
			static float vVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVelocity);
			NormalizeVector(NearestVectors, NearestVectors);
			ScaleVector(NearestVectors, GetVectorLength(vVelocity));

			static float NearestAngles[3];
			GetVectorAngles(NearestVectors, NearestAngles);
			TeleportEntity(client, NULL_VECTOR, NearestAngles, NearestVectors);
		}
	}
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

bool IsBotBoomer(int client) 
{
	return client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 2;
}

bool IsAliveSurvivor(int client) 
{
	return IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsValidClient(int client) 
{
	return client > 0 && client <= MaxClients && IsClientInGame(client); 
}

bool MakeNearestVectors(int client, float NearestVectors[3])
{
	static int iAimTarget;
	static float vTarget[3];
	static float vOrigin[3];

	iAimTarget = GetClientAimTarget(client, true);
	if(!IsAliveSurvivor(iAimTarget)) 
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

		if(aTargets.Length == 0)
		{
			delete aTargets;
			return false;
		}
		
		aTargets.Sort(Sort_Ascending, Sort_Float);
		iAimTarget = aTargets.Get(0, 1);
		delete aTargets;
	}

	if(!IsAliveSurvivor(iAimTarget))
		return false;

	GetClientAbsOrigin(client, vOrigin);
	GetClientEyePosition(iAimTarget, vTarget);
	MakeVectorFromPoints(vOrigin, vTarget, NearestVectors);
	return true;
}
