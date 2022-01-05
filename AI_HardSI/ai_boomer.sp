#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar
	g_hBoomerBhop,
	g_hVomitRange;

bool
	g_bBoomerBhop;

float
	g_fVomitRange;

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
	
	g_hBoomerBhop.AddChangeHook(vConVarChanged);
	g_hVomitRange.AddChangeHook(vConVarChanged);
	

	FindConVar("z_vomit_fatigue").SetInt(0);
	FindConVar("z_boomer_near_dist").SetInt(1);
	//FindConVar("boomer_vomit_delay").SetFloat(0.1);
	//FindConVar("boomer_exposed_time_tolerance").SetFloat(10000.0);

	HookEvent("ability_use", Event_AbilityUse);
}

public void OnPluginEnd()
{
	FindConVar("z_vomit_fatigue").RestoreDefault();
	FindConVar("z_boomer_near_dist").RestoreDefault();
	//FindConVar("boomer_vomit_delay").RestoreDefault();
	//FindConVar("boomer_exposed_time_tolerance").RestoreDefault();
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
	g_bBoomerBhop = g_hBoomerBhop.BoolValue;
	g_fVomitRange = g_hVomitRange.FloatValue;
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 2)
		return;

	char sAbility[16];
	event.GetString("ability", sAbility, sizeof(sAbility));
	if(strcmp(sAbility, "ability_vomit") == 0)
		vBoomer_OnVomit(client);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!g_bBoomerBhop)
		return Plugin_Continue;

	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 2 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") || bTargetSurvivor(client)))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") - 30.0)
		{
			if(0.50 * g_fVomitRange < fNearestSurvivorDistance(client) < 1000.0)
			{
				static float vAngles[3];
				GetClientEyeAngles(client, vAngles);
				if(bBhop(client, buttons, vAngles))
					return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}

bool bTargetSurvivor(int client)
{
	return bIsAliveSurvivor(GetClientAimTarget(client, true));
}
/*
bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	static float vVec[3];

	bJumped = false;

	if(buttons & IN_FORWARD)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, 180.0))
			bJumped = true;
	}
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, 90.0))
			bJumped = true;
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		//if(bClient_Push(client, buttons, vVec, 90.0))
			//bJumped = true;

		static float vRig[3];
		static float vVel[3];
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

		NormalizeVector(vRig, vRig);
		NormalizeVector(vVel, vVel);
		
		if(155.0 < RadToDeg(ArcCosine(GetVectorDotProduct(vRig, vVel))) <= 180.0)
			bJumped = false;
		else
		{
			if(bClient_Push(client, buttons, vAng, 90.0))
				bJumped = true;
		}
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		//if(bClient_Push(client, buttons, vVec, 90.0))
			//bJumped = true;

		static float vRig[3];
		static float vVel[3];
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

		NormalizeVector(vRig, vRig);
		NormalizeVector(vVel, vVel);
		
		if(155.0 < RadToDeg(ArcCosine(GetVectorDotProduct(vRig, vVel))) <= 180.0)
			bJumped = false;
		else
		{
			if(bClient_Push(client, buttons, vVec, 90.0))
				bJumped = true;
		}
	}
	
	return bJumped;
}
*/
bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	static float vVec[3];

	bJumped = false;

	if(buttons & IN_FORWARD || buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, buttons & IN_FORWARD ? 180.0 : -90.0))
			bJumped = true;
	}

	if(buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);

		static float vRig[3];
		static float vVel[3];
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);

		NormalizeVector(vRig, vRig);
		NormalizeVector(vVel, vVel);
		
		if(155.0 < RadToDeg(ArcCosine(GetVectorDotProduct(vRig, vVel))) <= 180.0)
			bJumped = false;
		else
		{
			if(bClient_Push(client, buttons, vVec, buttons & IN_MOVELEFT ? -90.0 : 90.0))
				bJumped = true;
		}
	}

	return bJumped;
}

bool bClient_Push(int client, int &buttons, float vVec[3], float fForce)
{
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

#define OBSTACLE_HEIGHT 18.0
bool bWontFall(int client, const float vVel[3])
{
	static float vPos[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vPos);
	AddVectors(vPos, vVel, vEnd);
	vPos[2] += OBSTACLE_HEIGHT;

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static bool bHit;
	static Handle hTrace;
	static float vEndPos[3];

	bHit = false;
	vEnd[2] += OBSTACLE_HEIGHT;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID, bTraceEntityFilter);
	vEnd[2] -= OBSTACLE_HEIGHT;

	if(TR_DidHit(hTrace))
	{
		bHit = true;
		TR_GetEndPosition(vEndPos, hTrace);
		if(GetVectorDistance(vPos, vEndPos) < 64.0)
		{
			delete hTrace;
			return false;
		}

		static float vVec[3];
		NormalizeVector(vVel, vVec);
	
		static float vPlane[3];
		TR_GetPlaneNormal(hTrace, vPlane);
		NegateVector(vPlane);
		NormalizeVector(vPlane, vPlane);
		if(RadToDeg(ArcCosine(GetVectorDotProduct(vVec, vPlane))) < 30.0)
		{
			delete hTrace;
			return false;
		}
	}
	delete hTrace;
	
	if(!bHit)
		vEndPos = vEnd;

	static float vDown[3];
	vDown[0] = vEndPos[0];
	vDown[1] = vEndPos[1];
	vDown[2] = vEndPos[2] - 100000.0;

	hTrace = TR_TraceHullFilterEx(vEndPos, vDown, vMins, vMaxs, MASK_PLAYERSOLID, bTraceEntityFilter);
	if(TR_DidHit(hTrace))
	{
		TR_GetEndPosition(vEnd, hTrace);
		if(vEndPos[2] - vEnd[2] > 120.0)
		{
			delete hTrace;
			return false;
		}

		static int entity;
		if((entity = TR_GetEntityIndex(hTrace)) > MaxClients)
		{
			static char classname[13];
			GetEdictClassname(entity, classname, sizeof(classname));
			if(strcmp(classname, "trigger_hurt") == 0)
			{
				delete hTrace;
				return false;
			}
		}
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

bool bTraceEntityFilter(int entity, int contentsMask)
{
	if(entity <= MaxClients)
		return false;
	else
	{
		static char classname[9];
		GetEntityClassname(entity, classname, sizeof classname);
		if(classname[0] == 'i' || classname[0] == 'w')
		{
			if(strcmp(classname, "infected") == 0 || strcmp(classname, "witch") == 0)
				return false;
		}
	}
	return true;
}

float fNearestSurvivorDistance(int client)
{
	static int i;
	static int iCount;
	static float vPos[3];
	static float vTarget[3];
	static float fDistance[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientAbsOrigin(client, vPos);

	for(i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, vTarget);
			fDistance[iCount++] = GetVectorDistance(vPos, vTarget);
		}
	}

	if(iCount == 0)
		return -1.0;

	SortFloats(fDistance, iCount, Sort_Ascending);
	return fDistance[0];
}

#define CROUCHING_EYE 44.0
void vBoomer_OnVomit(int client)
{
	static int iAimTarget;
	iAimTarget = GetClientAimTarget(client, true);
	if(!bIsAliveSurvivor(iAimTarget))
	{
		static int iNewTarget;
		iNewTarget = iGetClosestSurvivor(client, iAimTarget, g_fVomitRange + 260.0);
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

	if(bIsAliveSurvivor(iAimTarget))
	{
		static float vPos[3];
		static float vTarget[3];
		GetClientAbsOrigin(client, vPos);
		GetClientAbsOrigin(iAimTarget, vTarget);

		vTarget[2] += CROUCHING_EYE;

		MakeVectorFromPoints(vPos, vTarget, vVectors);
		GetVectorAngles(vVectors, vAngles);

		//vLength += GetEntPropFloat(iAimTarget, Prop_Data, "m_flMaxspeed");
	}
	else
	{
		GetClientEyeAngles(client, vAngles);

		vVectors[0] = Cosine(DegToRad(vAngles[1])) * Cosine(DegToRad(vAngles[0]));
		vVectors[1] = Sine(DegToRad(vAngles[1])) * Cosine(DegToRad(vAngles[0]));
		vVectors[2] = Sine(DegToRad(vAngles[0]));

		vLength += fNearestSurvivorDistance(client);
	}
	
	NormalizeVector(vVectors, vVectors);
	ScaleVector(vVectors, vLength);
	TeleportEntity(client, NULL_VECTOR, vAngles, vVectors);
}

bool bIsAliveSurvivor(int client)
{
	return bIsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool bIsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

int iGetClosestSurvivor(int client, int iAimTarget = -1, float fDistance)
{
	static int i;
	static int iCount;
	static float fDist;
	static float vPos[3];
	static float vTarget[3];
	static int iTargets[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientEyePosition(client, vPos);
	iCount = GetClientsInRange(vPos, RangeType_Visibility, iTargets, MAXPLAYERS);
	
	if(iCount == 0)
		return -1;
			
	static int iTarget;
	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	
	for(i = 0; i < iCount; i++)
	{
		iTarget = iTargets[i];
		if(iTarget && iTarget != iAimTarget && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget))
		{
			GetClientAbsOrigin(iTarget, vTarget);
			fDist = GetVectorDistance(vPos, vTarget);
			if(fDist < fDistance)
				aTargets.Set(aTargets.Push(fDist), iTarget, 1);
		}
	}

	if(aTargets.Length == 0)
	{
		iCount = 0;
		GetClientAbsOrigin(client, vPos);
		
		for(i = 1; i <= MaxClients; i++)
		{
			if(i != iAimTarget && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				GetClientAbsOrigin(i, vTarget);
				fDist = GetVectorDistance(vPos, vTarget);
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
