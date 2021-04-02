#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define SPITTER_BOOST 100.0
//#define SPITTER_SPIT_DELAY 2.0

//float g_fDelay[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "AI SPITTER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};
/*
public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	float fTime = GetGameTime();
	for(int i; i <= MaxClients; i++) 
		g_fDelay[i] = fTime;
}
*/
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 4 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;
/*	
	if(buttons & IN_ATTACK) 
	{
		if(GetGameTime() - g_fDelay[client] > SPITTER_SPIT_DELAY)
		{
			g_fDelay[client] = GetGameTime();
			buttons |= IN_JUMP;
		}
	}
*/
	static float vVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	static float fCurrentSpeed;
	fCurrentSpeed = SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0));
	if(150.0 < NearestSurvivorDistance(client) < 1000.0 && fCurrentSpeed > 190.0) 
	{
		if(!(GetEntityFlags(client) & FL_ONGROUND) && !(GetEntityMoveType(client) & MOVETYPE_LADDER) && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
		else
		{
			if(GetEntityFlags(client) & FL_ONGROUND) 
			{
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				static float vEyeAngles[3];
				GetClientEyeAngles(client, vEyeAngles);
				Client_PushForce(client, buttons, vEyeAngles, vVelocity, SPITTER_BOOST);
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