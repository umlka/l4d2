#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define SPEEDBOOST	90.0
#define GAMEDATA	"ai_tank"

ConVar
	g_hTankBhop,
	g_hTankAttackRange,
	g_hTankThrowForce,
	g_hAimOffsetSensitivityTank;

bool
	g_bTankBhop;

float
	g_fTankAttackRange,
	g_fTankThrowForce;

int
	g_iAimOffsetSensitivityTank;

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
	vLoadGameData();

	g_hTankBhop = CreateConVar("ai_tank_bhop", "1", "Flag to enable bhop facsimile on AI tanks");
	g_hAimOffsetSensitivityTank = CreateConVar("ai_aim_offset_sensitivity_hunter", "45", "If the tank has a target, it will not straight throw if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 180.0);
	g_hTankAttackRange = FindConVar("tank_attack_range");
	g_hTankThrowForce = FindConVar("z_tank_throw_force");

	g_hTankBhop.AddChangeHook(vConVarChanged);
	g_hTankAttackRange.AddChangeHook(vConVarChanged);
	g_hTankThrowForce.AddChangeHook(vConVarChanged);
	g_hAimOffsetSensitivityTank.AddChangeHook(vConVarChanged);
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
	g_bTankBhop = g_hTankBhop.BoolValue;
	g_fTankAttackRange = g_hTankAttackRange.FloatValue;
	g_fTankThrowForce = g_hTankThrowForce.FloatValue;
	g_iAimOffsetSensitivityTank = g_hAimOffsetSensitivityTank.IntValue;
}

int g_iSpecialTarget[MAXPLAYERS + 1];
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget)
{
	g_iSpecialTarget[specialInfected] = curTarget;
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!g_bTankBhop)
		return Plugin_Continue;

	if(!IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if(GetEntityFlags(client) & FL_ONGROUND && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
	{
		static float vVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
		if(SquareRoot(Pow(vVelocity[0], 2.0) + Pow(vVelocity[1], 2.0)) > GetEntPropFloat(client, Prop_Data, "m_flMaxspeed") - 30.0)
		{
			if(g_fTankAttackRange + 45.0 < fNearestSurvivorDistance(client) < 800.0)
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

bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	bJumped = false;

	if(buttons & IN_FORWARD)
	{
		if(bClient_Push(client, buttons, vAng, SPEEDBOOST))
			bJumped = true;
	}
		
	if(buttons & IN_BACK)
	{
		vAng[1] += 180.0;
		if(bClient_Push(client, buttons, vAng, SPEEDBOOST))
			bJumped = true;
	}
	
	if(buttons & IN_MOVELEFT)
	{
		vAng[1] += 90.0;
		if(bClient_Push(client, buttons, vAng, SPEEDBOOST))
			bJumped = true;
	}

	if(buttons & IN_MOVERIGHT)
	{
		vAng[1] -= 90.0;
		if(bClient_Push(client, buttons, vAng, SPEEDBOOST))
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
/*
bool bBhop(int client, int &buttons, float vAng[3])
{
	static bool bJumped;
	static float vVec[3];

	bJumped = false;

	if(buttons & IN_FORWARD || buttons & IN_BACK)
	{
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, buttons & IN_FORWARD ? SPEEDBOOST : -SPEEDBOOST))
			bJumped = true;
	}

	if(buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		if(bClient_Push(client, buttons, vVec, buttons & IN_MOVELEFT ? -SPEEDBOOST : SPEEDBOOST))
			bJumped = true;
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
*/
#define JUMP_HEIGHT 18.0
bool bWontFall(int client, const float vVel[3])
{
	static float vPos[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vPos);
	AddVectors(vPos, vVel, vEnd);
	vPos[2] += 20.0;

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static bool bHit;
	static Handle hTrace;
	static float vEndPos[3];

	bHit = false;
	vEnd[2] += JUMP_HEIGHT;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID, bTraceEntityFilter);
	//vEnd[2] -= JUMP_HEIGHT;

	if(TR_DidHit(hTrace))
	{
		bHit = true;
		TR_GetEndPosition(vEndPos, hTrace);
		if(GetVectorDistance(vPos, vEndPos) < 64.0)
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

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CTankRock::OnRelease");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTankRock::OnRelease");

	if(!dDetour.Enable(Hook_Pre, mreTankRockReleasePre))
		SetFailState("Failed to detour pre: CTankRock::OnRelease");

	/*if(!dDetour.Enable(Hook_Post, mreTankRockReleasePost))
		SetFailState("Failed to detour post: CTankRock::OnRelease");*/
}

MRESReturn mreTankRockReleasePre(int pThis, DHookParam hParams)
{
	if(pThis <= MaxClients || !IsValidEntity(pThis))
		return MRES_Ignored;

	int iThrower = GetEntPropEnt(pThis, Prop_Data, "m_hThrower");
	if(iThrower < 1 || iThrower > MaxClients || !IsClientInGame(iThrower) || !IsFakeClient(iThrower) || GetClientTeam(iThrower) != 3 || GetEntProp(iThrower, Prop_Send, "m_zombieClass") != 8)
		return MRES_Ignored;
	
	static int iAimTarget;
	iAimTarget = g_iSpecialTarget[iThrower]/*GetClientAimTarget(iThrower, true)*/;
	if(!bIsAliveSurvivor(iAimTarget) || bIsIncapacitated(iAimTarget) || bHitWall(pThis, iAimTarget) || bIsTargetWatchingAttacker(iAimTarget, g_iAimOffsetSensitivityTank))
	{
		static int iNewTarget;
		iNewTarget = iGetClosestSurvivor(iThrower, iAimTarget, pThis, g_fTankThrowForce);
		if(iNewTarget != -1)
			iAimTarget = iNewTarget;
	}

	if(!bIsAliveSurvivor(iAimTarget))
		return MRES_Ignored;

	static float vPos[3];
	static float vTarget[3];
	static float vVectors[3];
	GetClientEyePosition(iThrower, vPos);
	GetClientAbsOrigin(iAimTarget, vTarget);

	vTarget[2] += 45.0;

	MakeVectorFromPoints(vPos, vTarget, vVectors);
	GetVectorAngles(vVectors, vTarget);
	hParams.SetVector(2, vTarget);

	static float vLength;
	vLength = GetVectorLength(vVectors);
	vLength = vLength > g_fTankThrowForce ? vLength : g_fTankThrowForce;
	NormalizeVector(vVectors, vVectors);
	ScaleVector(vVectors, vLength + GetEntPropFloat(iAimTarget, Prop_Data, "m_flMaxspeed"));
	hParams.SetVector(3, vVectors);
	return MRES_ChangedHandled;
}
/*
MRESReturn mreTankRockReleasePost(int pThis, DHookParam hParams)
{
	return MRES_Ignored;
}
*/
bool bIsAliveSurvivor(int client)
{
	return bIsValidClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool bIsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool bIsIncapacitated(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool bIsTargetWatchingAttacker(int iAttacker, int iOffsetThreshold)
{
	static int iTarget;
	static bool bIsWatching;

	bIsWatching = true;
	if(bIsAliveSurvivor((iTarget = g_iSpecialTarget[iAttacker]/*GetClientAimTarget(iAttacker)*/)) && RoundToNearest(fGetPlayerAimOffset(iTarget, iAttacker)) > iOffsetThreshold)
		bIsWatching = false;

	return bIsWatching;
}

float fGetPlayerAimOffset(int iAttacker, int iTarget)
{
	static float vAim[3];
	static float vTarget[3];
	static float vAttacker[3];

	GetClientEyeAngles(iAttacker, vAim);
	vAim[0] = vAim[2] = 0.0;
	GetAngleVectors(vAim, vAim, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vAim, vAim);
	
	GetClientAbsOrigin(iTarget, vTarget);
	GetClientAbsOrigin(iAttacker, vAttacker);
	vAttacker[2] = vTarget[2] = 0.0;
	MakeVectorFromPoints(vAttacker, vTarget, vAttacker);
	NormalizeVector(vAttacker, vAttacker);
	
	return RadToDeg(ArcCosine(GetVectorDotProduct(vAim, vAttacker)));
}

bool bHitWall(int entity, int iTarget)
{
	static float vPos[3];
	static float vTarget[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
	GetClientAbsOrigin(iTarget, vTarget);
	vTarget[2] += 45.0;

	static float vMins[3];
	static float vMaxs[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);

	static bool bHit;
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vPos, vTarget, vMins, vMaxs, MASK_SOLID, bTraceEntityFilter);
	bHit = TR_DidHit(hTrace);
	delete hTrace;
	return bHit;
}

int iGetClosestSurvivor(int client, int iAimTarget = -1, int entity, float fDistance)
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
		if(iTarget && iTarget != iAimTarget && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget) && !bIsIncapacitated(iTarget) && !bHitWall(entity, iTarget))
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
			if(i != iAimTarget && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsIncapacitated(i) && !bHitWall(client, i))
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

