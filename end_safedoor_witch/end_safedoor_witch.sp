#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"End Safedoor Witch"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.5"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?t=335777"

// witch向门外偏移的距离
#define WITCH_OFFSET	33.0

int
	g_iRoundStart,
	g_iPlayerSpawn;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	CreateConVar("end_safedoor_witch_version", PLUGIN_VERSION, "End Safedoor Witch plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",	Event_PlayerSpawn,	EventHookMode_PostNoCopy);
}

public void OnMapEnd() {
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		Init();
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		Init();
	g_iPlayerSpawn = 1;
}

void Init() {
	int entity = INVALID_ENT_REFERENCE;
	if ((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == -1)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if (entity == -1)
		return;

	int door = L4D_GetCheckpointLast();
	if (door == -1)
		return;

	float vOrigin[3];
	GetAbsOrigin(entity, vOrigin, true);
	vOrigin[2] = 0.0;

	float height;
	float vPos[3];
	float vAng[3];
	float vFwd[3];
	float vVec[2][3];
	float vEnd[2][3];

	GetEntPropVector(door, Prop_Data, "m_vecAbsOrigin", vPos);
	vVec[0] = vPos;
	vVec[0][2] = 0.0;
	MakeVectorFromPoints(vVec[0], vOrigin, vVec[0]);
	NormalizeVector(vVec[0], vVec[0]);

	GetEntPropVector(door, Prop_Data, "m_angRotationOpenBack", vAng);
	vAng[0] = vAng[2] = 0.0;
	GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vFwd, vFwd);
	ScaleVector(vFwd, 28.0);
	AddVectors(vPos, vFwd, vPos);

	if (GetEndPoint(vPos, vAng, 56.0, vEnd[0])) {
		vAng[1] += 180.0;
		if (GetEndPoint(vPos, vAng, 56.0, vEnd[1])) {
			NormalizeVector(vFwd, vFwd);
			ScaleVector(vFwd, GetVectorDistance(vEnd[0], vEnd[1]) * 0.5);
			AddVectors(vEnd[1], vFwd, vPos);
		}
	}

	vAng[1] += 90.0;
	GetAngleVectors(vAng, vVec[1], NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vVec[1], vVec[1]);
	vAng[1] += RadToDeg(ArcCosine(GetVectorDotProduct(vVec[0], vVec[1]))) >= 90.0 ? 15.0 : 195.0;

	GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vFwd, vFwd);
	ScaleVector(vFwd, WITCH_OFFSET);
	AddVectors(vPos, vFwd, vPos);

	vPos[2] -= 25.0;
	height = GetGroundHeight(vPos, 128.0);
	vPos[2] = height ? height : vPos[2] - 10.5;

	SpawnWitch(vPos, vAng);
}

float GetGroundHeight(const float vPos[3], float scale) {
	float vEnd[3];
	GetAngleVectors(view_as<float>({90.0, 0.0, 0.0}), vEnd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vEnd, vEnd);
	ScaleVector(vEnd, scale);
	AddVectors(vPos, vEnd, vEnd);

	Handle hTrace = TR_TraceHullFilterEx(vPos, vEnd, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 10.0}), MASK_PLAYERSOLID, TraceWorldFilter);
	if (TR_DidHit(hTrace)) {
		TR_GetEndPosition(vEnd, hTrace);
		delete hTrace;
		return vEnd[2];
	}

	delete hTrace;
	return 0.0;
}

bool GetEndPoint(const float vStart[3], const float vAng[3], float scale, float vBuffer[3]) {
	float vEnd[3];
	GetAngleVectors(vAng, vEnd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vEnd, vEnd);
	ScaleVector(vEnd, scale);
	AddVectors(vStart, vEnd, vEnd);

	Handle hTrace = TR_TraceHullFilterEx(vStart, vEnd, view_as<float>({-5.0, -5.0, 0.0}), view_as<float>({5.0, 5.0, 5.0}), MASK_PLAYERSOLID, TraceWorldFilter);
	if (TR_DidHit(hTrace)) {
		TR_GetEndPosition(vBuffer, hTrace);
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

bool TraceWorldFilter(int entity, int contentsMask) {
	return !entity;
}

// https://forums.alliedmods.net/showthread.php?p=1471101
void SpawnWitch(const float vPos[3], const float vAng[3]) {
	int witch = CreateEntityByName("witch");
	if (witch != -1) {
		TeleportEntity(witch, vPos, vAng, NULL_VECTOR);
		SetEntPropFloat(witch, Prop_Send, "m_rage", 0.5);
		SetEntProp(witch, Prop_Data, "m_nSequence", 4);
		DispatchSpawn(witch);
		SetEntProp(witch, Prop_Send, "m_CollisionGroup", 1);
		CreateTimer(0.3, tmrSolidCollision, EntIndexToEntRef(witch), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action tmrSolidCollision(Handle timer, int witch) {
	if (EntRefToEntIndex(witch) != INVALID_ENT_REFERENCE)
		SetEntProp(witch, Prop_Send, "m_CollisionGroup", 0);

	return Plugin_Continue;
}
