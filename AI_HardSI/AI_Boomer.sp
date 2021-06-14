#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar g_hBoomerBhop;
ConVar g_hVomitRange;

bool g_bBoomerBhop;

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
	g_hBoomerBhop = CreateConVar("ai_boomer_bhop", "1", "Flag to enable bhop facsimile on AI boomers");

	g_hVomitRange = FindConVar("z_vomit_range");
	
	g_hBoomerBhop.AddChangeHook(ConVarChanged);
	g_hVomitRange.AddChangeHook(ConVarChanged);
	

	FindConVar("z_vomit_fatigue").SetInt(0);
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
	g_bBoomerBhop = g_hBoomerBhop.BoolValue;
	g_fVomitRange = g_hVomitRange.FloatValue;
}

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 2)
		return;

	char sAbility[16];
	event.GetString("ability", sAbility, sizeof(sAbility));
	if(strcmp(sAbility, "ability_vomit") == 0)
		Boomer_OnVomit(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 2 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(g_bBoomerBhop && GetEntityFlags(client) & FL_ONGROUND != 0 && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") || TargetSurvivor(client)))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") - 30.0)
		{
			if(0.50 * g_fVomitRange < NearestSurvivorDistance(client) < 1000.0)
			{
				static float vEyeAngles[3];
				GetClientEyeAngles(client, vEyeAngles);
				if(Bhop(client, buttons, vEyeAngles))
					return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}
/*
bool IsWatchingLadder(int client)
{
	static int entity;
	entity = GetClientAimTarget(client, false);
	if(entity == -1 || !HasEntProp(entity, Prop_Data, "m_climbableNormal"))
		return false;
		
	static float vPos[3], vLadder[3];
	GetClientAbsOrigin(client, vPos);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vLadder);
	return GetVectorDistance(vPos, vLadder) < 100.0;
}
*/
int TargetSurvivor(int client)
{
	static int iTarget;
	iTarget = GetClientAimTarget(client, true);
	return IsAliveSurvivor(iTarget) ? iTarget : 0;
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
	AddVectors(vStart, vVel, vEnd);

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

#define CROUCHING_HEIGHT 56.0
void Boomer_OnVomit(int client)
{
	static int iAimTarget;

	iAimTarget = GetClientAimTarget(client, true);
	if(!IsAliveSurvivor(iAimTarget))
	{
		static int iNewTarget;
		iNewTarget = GetClosestSurvivor(client, iAimTarget, g_fVomitRange + 260.0);
		if(iNewTarget != -1)
			iAimTarget = iNewTarget;
	}

	static float vAngles[3];
	static float vVectors[3];
	static float vVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVelocity);

	static float vLength;
	vLength = GetVectorLength(vVelocity);
	vLength = vLength < g_fVomitRange ? g_fVomitRange : vLength;

	if(IsAliveSurvivor(iAimTarget))
	{
		static float vOrigin[3];
		static float vTarget[3];

		GetClientAbsOrigin(iAimTarget, vTarget);
		GetClientAbsOrigin(client, vOrigin);

		vTarget[2] += CROUCHING_HEIGHT;

		MakeVectorFromPoints(vOrigin, vTarget, vVectors);

		GetVectorAngles(vVectors, vAngles);

		vLength += GetEntPropFloat(iAimTarget, Prop_Data, "m_flMaxspeed");
	}
	else
	{
		GetClientEyeAngles(client, vAngles);

		vVectors[0] = Cosine(DegToRad(vAngles[1])) * Cosine(DegToRad(vAngles[0]));
		vVectors[1] = Sine(DegToRad(vAngles[1])) * Cosine(DegToRad(vAngles[0]));
		vVectors[2] = Sine(DegToRad(vAngles[0]));

		vLength += NearestSurvivorDistance(client);
	}
	
	NormalizeVector(vVectors, vVectors);
	ScaleVector(vVectors, vLength);
	TeleportEntity(client, NULL_VECTOR, vAngles, vVectors);
}

bool IsAliveSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

int GetClosestSurvivor(int client, int iAimTarget = -1, float fDistance)
{
	static int i;
	static int iNum;
	static float fDist;
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
		if(iTarget && iTarget != iAimTarget && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget))
		{
			GetClientAbsOrigin(iTarget, vTarget);
			fDist = GetVectorDistance(vOrigin, vTarget);
			if(fDist < fDistance)
				aTargets.Set(aTargets.Push(fDist), iTarget, 1);
		}
	}

	if(aTargets.Length == 0)
	{
		iNum = 0;
		
		GetClientAbsOrigin(client, vOrigin);
		
		for(i = 1; i <= MaxClients; i++)
		{
			if(i != iAimTarget && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				GetClientAbsOrigin(i, vTarget);
				fDist = GetVectorDistance(vOrigin, vTarget);
				if(fDist < fDistance)
					aTargets.Set(aTargets.Push(fDist), i, 1);
			}
		}
		
		if(aTargets.Length == 0)
		{
			delete aTargets;
			return -1;
		}
	}

	aTargets.Sort(Sort_Ascending, Sort_Float);
	iAimTarget = aTargets.Get(0, 1);
	delete aTargets;
	return iAimTarget;
}
