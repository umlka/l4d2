#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define BoostForward 80.0

ConVar
	g_hTankBhop;
ConVar
	g_hTankAttackRange;

bool
	g_bTankBhop;

float
	g_fTankAttackRange;

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
	g_hTankBhop = CreateConVar("ai_tank_bhop", "1", "Flag to enable bhop facsimile on AI tanks");

	g_hTankAttackRange = FindConVar("tank_attack_range");
	
	g_hTankBhop.AddChangeHook(vConVarChanged);
	g_hTankAttackRange.AddChangeHook(vConVarChanged);
}

public void OnConfigsExecuted()
{
	vGetCvars();
}

public void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	g_bTankBhop = g_hTankBhop.BoolValue;
	g_fTankAttackRange = g_hTankAttackRange.FloatValue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(g_bTankBhop && GetEntityFlags(client) & FL_ONGROUND != 0 && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") - 30.0)
		{
			if(g_fTankAttackRange + 45.0 < fNearestSurvivorDistance(client) < 1000.0)
			{
				static float vEyeAngles[3];
				GetClientEyeAngles(client, vEyeAngles);
				if(bBhop(client, buttons, vEyeAngles))
					return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	bJumped = false;

	if(buttons & IN_FORWARD)
	{
		if(bClient_Push(client, buttons, vAng, BoostForward))
			bJumped = true;
	}
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		if(bClient_Push(client, buttons, vAng, BoostForward))
			bJumped = true;
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		if(bClient_Push(client, buttons, vAng, BoostForward))
			bJumped = true;
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		if(bClient_Push(client, buttons, vAng, BoostForward))
			bJumped = true;
	}
	
	return bJumped;
}

bool bClient_Push(int client, int &buttons, const float vAng[3], float fForce)
{
	static float vVec[3];
	GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
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

#define JUMP_HEIGHT 56.0
bool bWontFall(int client, const float vVel[3])
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
	hTrace = TR_TraceHullFilterEx(vStart, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
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

	hTrace = TR_TraceHullFilterEx(vEndNonCol, vDown, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	if(hTrace != null)
	{
		if(TR_DidHit(hTrace))
		{
			TR_GetEndPosition(vEnd, hTrace);
			if(vEndNonCol[2] - vEnd[2] > 120.0)
			{
				delete hTrace;
				return false;
			}

			static int entity;
			static char sClassName[13];
			if((entity = TR_GetEntityIndex(hTrace)) > MaxClients)
			{
				GetEdictClassname(entity, sClassName, sizeof(sClassName));
				if(strcmp(sClassName, "trigger_hurt") == 0)
				{
					delete hTrace;
					return false;
				}
			}
			delete hTrace;
			return true;
		}
		delete hTrace;
	}
	return false;
}
 
public bool bTraceEntityFilter(int entity, int contentsMask)
{
	if(entity <= MaxClients)
		return false;

	static char sClassName[9];
	GetEntityClassname(entity, sClassName, sizeof(sClassName));
	return (sClassName[0] != 'i' || sClassName[0] != 'w' || strcmp(sClassName, "infected") != 0 || strcmp(sClassName, "witch") != 0);
}

float fNearestSurvivorDistance(int client)
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

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if(IsFakeClient(client) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}