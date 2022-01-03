#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

// witch向门外偏移的距离
#define WITCH_OFFSET	20.0
#define GAMEDATA		"end_safedoor_witch"

Handle
	g_hSDKIsCheckpointDoor,
	g_hSDKIsCheckpointExitDoor;

int
	g_iRoundStart,
	g_iPlayerSpawn;

public Plugin myinfo = 
{
	name = 			"End Safedoor Witch",
	author = 		"sorallll",
	description = 	"",
	version = 		"1.0.1",
	url = 			""
}

public void OnPluginStart()
{
	vLoadGameData();

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		CreateTimer(1.0, tmrSpawnWitch, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		CreateTimer(1.0, tmrSpawnWitch, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

Action tmrSpawnWitch(Handle timer)
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		int i;
		float vPos[3];
		float vAng[3];
		float vFwd[3];
		float fHeight;
		char sModel[64];

		entity = MaxClients + 1;
		while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
		{
			i = GetEntProp(entity, Prop_Data, "m_spawnflags");
			if(i & 8192 == 0 || i & 32768 != 0)
				continue;
		
			if(!SDKCall(g_hSDKIsCheckpointDoor, entity))
				continue;

			if(SDKCall(g_hSDKIsCheckpointExitDoor, entity))
				continue;

			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

			GetEntPropVector(entity, Prop_Data, "m_angRotationOpenBack", vAng);
			GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(vFwd, vFwd);
			ScaleVector(vFwd, 24.0);
			AddVectors(vPos, vFwd, vPos);

			GetEntPropVector(entity, Prop_Data, "m_angRotationClosed", vAng);
			GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof sModel);
			if(strcmp(sModel, "models/props_doors/checkpoint_door_-02.mdl") != 0)
				vAng[1] += 180.0;

			GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(vFwd, vFwd);
			ScaleVector(vFwd, WITCH_OFFSET);
			AddVectors(vPos, vFwd, vPos);

			vPos[2] -= 25.0;
			fHeight = fGetGroundHeight(vPos, entity);

			if(fHeight)
				vPos[2] = fHeight + 5.0;

			vSpawnWitch(vPos, vAng);
		}
	}

	return Plugin_Continue;
}

float fGetGroundHeight(const float vPos[3], int entity)
{
	float vEnd[3];
	Handle hTrace = TR_TraceRayFilterEx(vPos, view_as<float>({90.0, 0.0, 0.0}), MASK_ALL, RayType_Infinite, bTraceEntityFilter, entity);
	if(TR_DidHit(hTrace))
		TR_GetEndPosition(vEnd, hTrace);

	delete hTrace;
	return vEnd[2];
}

bool bTraceEntityFilter(int entity, int contentsMask, any data)
{
	if(entity == data || entity <= MaxClients)
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

// https://forums.alliedmods.net/showthread.php?p=1471101
void vSpawnWitch(const float vPos[3], const float vAng[3])
{
	int entity = CreateEntityByName("witch");
	if(entity != -1)
	{
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		SetEntPropFloat(entity, Prop_Send, "m_rage", 0.5);
		SetEntProp(entity, Prop_Data, "m_nSequence", 4);
		DispatchSpawn(entity);
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
		CreateTimer(0.3, tmrSolidCollision, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action tmrSolidCollision(Handle timer, int entity)
{
	if(EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);

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

	StartPrepSDKCall(SDKCall_Entity);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointDoor") == false)
		SetFailState("Failed to find offset: CPropDoorRotatingCheckpoint::IsCheckpointDoor");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsCheckpointDoor = EndPrepSDKCall();
	if(g_hSDKIsCheckpointDoor == null)
		SetFailState("Failed to create SDKCall: CPropDoorRotatingCheckpoint::IsCheckpointDoor");

	StartPrepSDKCall(SDKCall_Entity);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointExitDoor") == false)
		SetFailState("Failed to find offset: CPropDoorRotatingCheckpoint::IsCheckpointExitDoor");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsCheckpointExitDoor = EndPrepSDKCall();
	if(g_hSDKIsCheckpointExitDoor == null)
		SetFailState("Failed to create SDKCall: CPropDoorRotatingCheckpoint::IsCheckpointExitDoor");

	delete hGameData;
}
