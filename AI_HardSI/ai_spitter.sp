#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar
	g_hSpitterBhop;

bool
	g_bSpitterBhop;

public Plugin myinfo =
{
	name = "AI SPITTER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart()
{
	g_hSpitterBhop = CreateConVar("ai_spitter_bhop", "1", "Flag to enable bhop facsimile on AI spitters");

	g_hSpitterBhop.AddChangeHook(vConVarChanged);
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
	g_bSpitterBhop = g_hSpitterBhop.BoolValue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!g_bSpitterBhop)
		return Plugin_Continue;

	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 4 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		if(SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0)) > 150.0)
		{
			if(150.0 < fNearestSurvivorDistance(client) < 1000.0)
			{
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				static float vAng[3];
				GetClientEyeAngles(client, vAng);
				vBhop(client, buttons, vAng);
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

void vBhop(int client, int &buttons, float vAng[3])
{
	if(buttons & IN_FORWARD)
		vClient_Push(client, vAng, 120.0);
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		vClient_Push(client, vAng, 60.0);
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		vClient_Push(client, vAng, 60.0);
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		vClient_Push(client, vAng, 60.0);
	}
}

void vClient_Push(int client, const float vAng[3], float fForce)
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
