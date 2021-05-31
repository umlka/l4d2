#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "AI SPITTER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 4 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND != 0 && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > 170.0)
		{
			if(150.0 < NearestSurvivorDistance(client) < 1000.0)
			{
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				static float vEyeAngles[3];
				GetClientEyeAngles(client, vEyeAngles);
				Bhop(client, buttons, vEyeAngles);
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

void Bhop(int client, int &buttons, const float vAng[3])
{
	static float vVec[3];
	if(buttons & IN_FORWARD)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		Client_Push(client, vVec, 120.0);
	}
		
	if(buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		Client_Push(client, vVec, -60.0);
	}
	
	if(buttons & IN_MOVELEFT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Push(client, vVec, -120.0);
	}

	if(buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		Client_Push(client, vVec, 120.0);
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
