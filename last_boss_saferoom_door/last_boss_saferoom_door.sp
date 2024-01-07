#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"Last Boss Saferoom Door"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.1"
#define PLUGIN_URL				""

#define PARTICLE_BLACK			"smoke_window" // Large black smoke
#define PARTICLE_CLOUD			"smoker_smokecloud" // Smoker cloud
#define PARTICLE_CLOUD1			"smoker_smokecloud_cheap"

enum {
	Boss_None,
	Boss_Witch,
	Boss_Tank
}

enum struct Boss {
	int idx;
	int type;
	int refe;
	int door;
	int attach;

	float pos[3];
	float ang[3];

	void Init() {
		this.idx = 0;
		this.type = Boss_None;
		this.refe = 0;
		this.door = 0;
		this.attach = 0;

		this.pos = NULL_VECTOR;
		this.ang = NULL_VECTOR;
	}
}

Boss
	g_Boss;

int
	g_iRoundStart,
	g_iPlayerSpawn;

static const char
	g_sModels[][] = {
		"models/infected/witch.mdl",
		"models/infected/witch_bride.mdl",
		"models/infected/hulk.mdl",
		"models/infected/hulk_dlc3.mdl",
		"models/infected/hulk_l4d1.mdl"
	};

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	CreateConVar("last_boss_saferoom_door_version", PLUGIN_VERSION, "Last Boss Saferoom Door plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",	Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	HookEvent("player_death",	Event_PlayerDeath,	EventHookMode_Pre);

	RegAdminCmd("sm_bosstest", cmdTest, ADMFLAG_ROOT, "Test");
}

Action cmdTest(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	TeleportEntity(client, g_Boss.pos, g_Boss.ang, NULL_VECTOR);
	return Plugin_Handled;
}

public void OnClientDisconnect(int client) {
	if (!g_Boss.refe)
		return;

	if (g_Boss.type != Boss_Tank)
		return;

	if (!IsValidEntRef(g_Boss.door))
		return;

	if (GetClientOfUserId(g_Boss.refe) == client) {
		ForceDoorClosed();
		g_Boss.refe = 0;
	}
}

public void OnMapStart() {
	PrecacheParticle(PARTICLE_BLACK);
	PrecacheParticle(PARTICLE_CLOUD);
	PrecacheParticle(PARTICLE_CLOUD1);

	for (int i; i < sizeof g_sModels; i++) {
		if (!IsModelPrecached(g_sModels[i]))
			PrecacheModel(g_sModels[i], true);
	}
}

public void OnMapEnd() {
	g_Boss.Init();

	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		CreateTimer(1.0, tmrInit, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		CreateTimer(1.0, tmrInit, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	if (!g_Boss.refe)
		return;

	if (g_Boss.type != Boss_Tank)
		return;

	if (!IsValidEntRef(g_Boss.door))
		return;

	if (GetClientOfUserId(g_Boss.refe) != GetClientOfUserId(event.GetInt("userid"))) {
		ForceDoorClosed();
		g_Boss.refe = 0;
	}
}

Action tmrInit(Handle timer) {
	Init();
	return Plugin_Continue;
}

void Init() {
	int entity = -1;
	if ((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == -1)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if (entity == -1)
		return;

	int door = L4D_GetCheckpointLast();
	if (door == -1)
		return;

	g_Boss.door = EntIndexToEntRef(door);

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
	ScaleVector(vFwd, 5.0);
	AddVectors(vPos, vFwd, vPos);

	vPos[2] -= 25.0;
	height = GetGroundHeight(vPos, 128.0);
	vPos[2] = height ? height : vPos[2] - 10.5;

	g_Boss.pos = vPos;
	g_Boss.ang = vAng;

	AcceptEntityInput(door, "DisableCollision");
	AcceptEntityInput(door, "Close");
	AcceptEntityInput(door, "forceclosed");
	SetVariantString("OnUser1 !self:EnableCollision::5.0:-1");
	AcceptEntityInput(door, "AddOutput");
	AcceptEntityInput(door, "FireUser1");

	HookSingleEntityOutput(door, "OnOpen", OnOpen);
}

void OnOpen(const char[] output, int caller, int activator, float delay) {
	UnhookSingleEntityOutput(caller, "OnOpen", OnOpen);

	float vPos[3];
	GetEntPropVector(caller, Prop_Data, "m_vecAbsOrigin", vPos);
	vPos[2] += 10000.0;
	SetAbsOrigin(caller, vPos);
	Stumble(g_Boss.pos, 250.0);

	AcceptEntityInput(caller, "DisableCollision");
	SetVariantString("OnUser1 !self:EnableCollision::5.0:-1");
	AcceptEntityInput(caller, "AddOutput");
	AcceptEntityInput(caller, "FireUser1");

	CreatePredictModel();
	SDKHook(caller, SDKHook_SetTransmit, Hook_SetTransmit);
}

void Stumble(const float vecPos[3], float flDistance) {
	float vecTarget[3];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;

		GetClientAbsOrigin(i, vecTarget);
		if (GetVectorDistance(vecPos, vecTarget) <= flDistance)
			L4D_StaggerPlayer(i, i, vecPos);
	}
}

Action Hook_SetTransmit(int entity, int client) {
	return Plugin_Handled;
}

int g_iHits;
void CreatePredictModel() {
	int entity = CreateEntityByName("prop_dynamic");
	if (entity == -1)
		return;

	g_Boss.attach = EntIndexToEntRef(entity);

	g_Boss.idx = Math_GetRandomInt(0, sizeof g_sModels - 1);
	g_Boss.type = g_Boss.idx < 2 ? Boss_Witch : Boss_Tank;
	DispatchKeyValue(entity, "solid", "6");
	DispatchKeyValue(entity, "model", g_sModels[g_Boss.idx]);
	DispatchKeyValue(entity, "DefaultAnim", g_Boss.type == Boss_Witch ? "ACT_TERROR_WITCH_WANDER_IDLE" : "ACT_TERROR_RAGE_AT_ENEMY");
	DispatchKeyValue(entity, "disableshadows", "1");
	SetAbsOrigin(entity, g_Boss.pos);
	SetAbsAngles(entity, g_Boss.ang);
	DispatchSpawn(entity);
	L4D2_SetEntityGlow(entity, L4D2Glow_Constant, 0, 0, {1, 1, 1}, false);

	g_iHits = 0;
	SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
}

#define MAX_HITS 25
Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
	g_iHits++;
	if (g_iHits < MAX_HITS) {
		static int color[3];
		color[0] = RoundToCeil(255.0 * g_iHits / MAX_HITS);
		L4D2_SetEntityGlow(victim, L4D2Glow_Constant, 0, 0, color, true);
		return Plugin_Continue;
	}

	ShowParticle(PARTICLE_BLACK, g_Boss.pos, NULL_VECTOR, 10.0);
	ShowParticle(PARTICLE_CLOUD, g_Boss.pos, NULL_VECTOR, 10.0);
	ShowParticle(PARTICLE_CLOUD1, g_Boss.pos, NULL_VECTOR, 10.0);
	SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage);
	PerformBlind();
	SpawnBoss(g_Boss.pos, g_Boss.ang);
	L4D2_SetEntityGlow(g_Boss.refe, L4D2Glow_Constant, 0, 0, {1, 1, 1}, false);
	RemoveEntity(victim);
	
	return Plugin_Continue;
}

public void OnEntityDestroyed(int entity) {
	if (entity <= 0)
		return;

	if (g_Boss.type != Boss_Witch)
		return;

	if (!IsValidEntRef(g_Boss.door))
		return;

	if (g_Boss.refe && EntRefToEntIndex(g_Boss.refe) == entity) {
		ForceDoorClosed();
		g_Boss.refe = 0;
	}
}

void ForceDoorClosed() {
	float m_flSpeed = GetEntPropFloat(g_Boss.door, Prop_Data, "m_flSpeed");
	SetEntPropFloat(g_Boss.door, Prop_Data, "m_flSpeed", 1000.0);
	SetEntProp(g_Boss.door, Prop_Data, "m_hasUnlockSequence", 0);
	AcceptEntityInput(g_Boss.door, "DisableCollision");
	AcceptEntityInput(g_Boss.door, "Unlock");
	AcceptEntityInput(g_Boss.door, "Close");
	AcceptEntityInput(g_Boss.door, "forceclosed");
	AcceptEntityInput(g_Boss.door, "Lock");
	SetEntProp(g_Boss.door, Prop_Data, "m_hasUnlockSequence", 1);

	SetVariantString("OnUser1 !self:EnableCollision::1.5:-1");
	AcceptEntityInput(g_Boss.door, "AddOutput");

	char buffer[64];
	FloatToString(m_flSpeed, buffer, sizeof buffer);
	Format(buffer, sizeof buffer, "OnUser1 !self:SetSpeed:%s:5.0:-1", buffer);
	SetVariantString(buffer);
	AcceptEntityInput(g_Boss.door, "AddOutput");
	AcceptEntityInput(g_Boss.door, "FireUser1");
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

void SpawnBoss(const float vPos[3], const float vAng[3]) {
	switch (g_Boss.type) {
		case Boss_Witch: {
			int entity = SpawnWitch(vPos, vAng);
			if (entity > 0) {
				SetEntityModel(entity, g_sModels[g_Boss.idx]);
				g_Boss.refe = EntIndexToEntRef(entity);
			}
		}

		case Boss_Tank: {
			int entity = L4D2_SpawnTank(vPos, vAng);
			if (entity > 0) {
				SetEntityModel(entity, g_sModels[g_Boss.idx]);
				g_Boss.refe = GetClientUserId(entity);
			}
		}
	}
}

// https://forums.alliedmods.net/showthread.php?p=1471101
int SpawnWitch(const float vPos[3], const float vAng[3]) {
	int entity = CreateEntityByName("witch");
	if (entity != -1) {
		SetAbsOrigin(entity, vPos);
		SetAbsAngles(entity, vAng);
		SetEntProp(entity, Prop_Data, "m_nSequence", 4);
		SetEntPropFloat(entity, Prop_Send, "m_rage", 0.9);
		DispatchSpawn(entity);
	}

	return entity;
}

bool IsValidEntRef(int entity) {
	return entity && EntRefToEntIndex(entity) != -1;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Integer number between min and max
 */
int Math_GetRandomInt(int min, int max) {
	int random = GetURandomInt();
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

int ShowParticle(const char[] particle, const float vPos[3], const float vAng[3], float time) {
	int entity = CreateEntityByName("info_particle_system");
	if (entity == -1)
		return 0;

	DispatchKeyValue(entity, "effect_name", particle);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	static char buffer[64];
	FormatEx(buffer, sizeof buffer, "OnUser1 !self:Kill::%f:-1", time);
	SetVariantString(buffer);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");

	return entity;
}

int PrecacheParticle(const char[] effect_name) {
	static int table = INVALID_STRING_TABLE;
	if (table == INVALID_STRING_TABLE)
		table = FindStringTable("ParticleEffectNames");

	int index = FindStringIndex(table, effect_name);
	if (index == INVALID_STRING_INDEX) {
		bool save = LockStringTables(false);
		AddToStringTable(table, effect_name);
		LockStringTables(save);
		index = FindStringIndex(table, effect_name);
	}

	return index;
}

#define FFADE_IN		0x0001
#define FFADE_OUT		0x0002
#define FFADE_STAYOUT	0x0008
#define FFADE_PURGE		0x0010

#define SCREENFADE_FRACBITS	(1 << 9) // 512

void PerformBlind() {
	float vPos[3];
	vPos = g_Boss.pos;
	vPos[2] += 45.0;
	int clients[MAXPLAYERS + 1];
	int num = GetClientsInRange(vPos, RangeType_Visibility, clients, MAXPLAYERS);

	for (int i; i < num; i++) {
		if (!IsClientInGame(clients[i]) || IsFakeClient(clients[i]))
			continue;

		ScreenFade(clients[i], 1, SCREENFADE_FRACBITS, FFADE_IN|FFADE_PURGE, 0, 0, 0, 255);
	}
}

void ScreenFade(int client, int delay, int duration, int type, int red, int green, int blue, int alpha) {
    BfWrite bf = UserMessageToBfWrite(StartMessageOne("Fade", client));
    bf.WriteShort(delay);
    bf.WriteShort(duration);
    bf.WriteShort(type);
    bf.WriteByte(red);
    bf.WriteByte(green);
    bf.WriteByte(blue);
    bf.WriteByte(alpha);
    EndMessage();
}
