#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <navmesh>

#define SOUND_COUNTDOWN "buttons/blip1.wav"

enum
{
	NavMeshArea_ID = 0,
	NavMeshArea_Flags,
	NavMeshArea_PlaceID,
	NavMeshArea_X1,
	NavMeshArea_Y1,
	NavMeshArea_Z1,
	NavMeshArea_X2,
	NavMeshArea_Y2,
	NavMeshArea_Z2,
	NavMeshArea_CenterX,
	NavMeshArea_CenterY,
	NavMeshArea_CenterZ,
	NavMeshArea_InvDxCorners,
	NavMeshArea_InvDyCorners,
	NavMeshArea_NECornerZ,
	NavMeshArea_SWCornerZ,
	
	NavMeshArea_ConnectionsStartIndex,
	NavMeshArea_ConnectionsEndIndex,
	
	NavMeshArea_IncomingConnectionsStartIndex,
	NavMeshArea_IncomingConnectionsEndIndex,

	NavMeshArea_HidingSpotsStartIndex,
	NavMeshArea_HidingSpotsEndIndex,
	
	NavMeshArea_EncounterPathsStartIndex,
	NavMeshArea_EncounterPathsEndIndex,
	
	NavMeshArea_LadderConnectionsStartIndex,
	NavMeshArea_LadderConnectionsEndIndex,
	
	NavMeshArea_CornerLightIntensityNW,
	NavMeshArea_CornerLightIntensityNE,
	NavMeshArea_CornerLightIntensitySE,
	NavMeshArea_CornerLightIntensitySW,
	
	NavMeshArea_VisibleAreasStartIndex,
	NavMeshArea_VisibleAreasEndIndex,
	
	NavMeshArea_InheritVisibilityFrom,
	NavMeshArea_EarliestOccupyTimeFirstTeam,
	NavMeshArea_EarliestOccupyTimeSecondTeam,
	NavMeshArea_Blocked,
	
// 	A* pathfinding
	NavMeshArea_Parent,
	NavMeshArea_ParentHow,
	NavMeshArea_CostSoFar,
	NavMeshArea_TotalCost,
	NavMeshArea_Marker,
	NavMeshArea_OpenMarker,
	NavMeshArea_PrevOpenIndex,
	NavMeshArea_NextOpenIndex,
	NavMeshArea_PathLengthSoFar,
	
	NavMeshArea_NearSearchMarker,
	
	TFNavArea_AttributeFlags,

	CSNavArea_ApproachInfoStartIndex,
	CSNavArea_ApproachInfoEndIndex,

	TerrorNavArea_SpawnAttributes,

	NavMeshArea_MaxStats
};

ArrayList g_hNavMeshAreas;
ArrayList g_hEndNavMeshAreas;
ArrayList g_hStartNavMeshAreas;
ArrayList g_hBlockedNavMeshAreas;

Handle g_hTimer;

ConVar g_hEndSafeAreaMethod;
ConVar g_hEndSafeAreaTime;
ConVar g_hRemoveAllInfected;

int g_iCountdown;
int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iChangelevel;
int g_iRescueVehicle;
//int g_iStartSafeDoor;
int g_iLastSafeDoor;
int g_iEndSafeAreaMethod;
int g_iEndSafeAreaTime;

float g_vMins[3];
float g_vMaxs[3];

bool g_bHasTriggered;
bool g_bFinalVehicleReady;
bool g_bRemoveAllInfected;
bool g_bIsInEndSafeArea[MAXPLAYERS + 1];

static const char g_sMethod[][] =
{
	"传送",
	"处死",
};

public Plugin myinfo = 
{
    name = "End Area Detcet",
    author = "sorallll",
    description = "",
    version = "1.0",
    url = ""
}

public void OnPluginStart()
{
	g_hEndSafeAreaMethod = CreateConVar("end_safearea_method", "0", "如何处理未进入终点安全区域的玩家?(0=传送,1=处死)", _, true, 0.0, true, 1.0);
	g_hEndSafeAreaTime = CreateConVar("end_safearea_time", "15", "倒计时多久(0=关闭该功能)", _, true, 0.0);
	g_hRemoveAllInfected = CreateConVar("end_safearea_remove", "1", "传送前是否移除终点安全区域内的感染者", _, true, 0.0, true, 1.0);
	
	g_hEndSafeAreaMethod.AddChangeHook(ConVarChanged);
	g_hEndSafeAreaTime.AddChangeHook(ConVarChanged);
	g_hRemoveAllInfected.AddChangeHook(ConVarChanged);

	//AutoExecConfig(true, "end_safezone_detcet");
	//想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("finale_vehicle_ready", Event_FinaleVehicleReady, EventHookMode_Pre);
	HookEvent("nav_blocked", Event_NavBlocked, EventHookMode_Pre);
	
	RegAdminCmd("sm_warpstart", CmdWarpStart, ADMFLAG_RCON, "传送所有生还者到起点安全区域");
	RegAdminCmd("sm_warpend", CmdWarpEnd, ADMFLAG_RCON, "传送所有生还者到终点安全区域");
	RegAdminCmd("sm_finale", CmdFinale, ADMFLAG_RCON, "结局关卡强制过关");
	//RegAdminCmd("sm_esd", CmdEsd, ADMFLAG_ROOT, "测试");
	
	g_hEndNavMeshAreas = new ArrayList(1);
	g_hStartNavMeshAreas = new ArrayList(1);
	g_hBlockedNavMeshAreas = new ArrayList(1);
}

public Action CmdWarpStart(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	int iAreaCount = g_hStartNavMeshAreas.Length;
	if(iAreaCount == 0)
	{
		ReplyToCommand(client, "未发现起点Nav区域");
		return Plugin_Handled;
	}
	
	int iRandom;
	float vCenter[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsAliveSurvivor(i))
		{
			if(GetEntityMoveType(i) == MOVETYPE_NOCLIP)
				SetEntityMoveType(i, MOVETYPE_WALK);

			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			L4D2_ReviveFromIncap(i);
			iRandom = GetRandomInt(0, iAreaCount - 1);
			CNavArea iRandomArea = view_as<CNavArea>(g_hStartNavMeshAreas.Get(iRandom));
			iRandomArea.GetCenter(vCenter);
			TeleportEntity(i, vCenter, NULL_VECTOR, NULL_VECTOR);
		}
	}

	return Plugin_Handled;
}

public Action CmdWarpEnd(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if(g_hEndNavMeshAreas.Length == 0)
	{
		ReplyToCommand(client, "未发现终点Nav区域");
		return Plugin_Handled;
	}

	g_bHasTriggered = true;
	TeleportOrSuicide(0);
	return Plugin_Handled;
}

public Action CmdFinale(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	int iFinaleEntity;
	if((iFinaleEntity = FindEntityByClassname(MaxClients + 1, "trigger_finale")) == INVALID_ENT_REFERENCE)
	{
		ReplyToCommand(client, "未发现trigger_finale实体");
		return Plugin_Handled;
	}
	
	AcceptEntityInput(iFinaleEntity, "FinaleEscapeFinished");
	return Plugin_Handled;
}
/*
public Action CmdEsd(int client, int args)
{
	int iAreaCount = g_hBlockedNavMeshAreas.Length;
	for(int iAreaIndex; iAreaIndex < iAreaCount; iAreaIndex++)
	{
		int iSpawnAttributes = g_hNavMeshAreas.Get(g_hBlockedNavMeshAreas.Get(iAreaIndex), TerrorNavArea_SpawnAttributes);
		ReplyToCommand(client, "iAreaIndex->%d iSpawnAttributes->%x", g_hBlockedNavMeshAreas.Get(iAreaIndex), iSpawnAttributes);
	}
	return Plugin_Handled;
}
*/
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
	g_iEndSafeAreaMethod = g_hEndSafeAreaMethod.IntValue;
	g_iEndSafeAreaTime = g_hEndSafeAreaTime.IntValue;
	g_bRemoveAllInfected = g_hRemoveAllInfected.BoolValue;
}

public void OnMapStart()
{
	PrecacheSound(SOUND_COUNTDOWN);
}

public void OnMapEnd()
{
	delete g_hTimer;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasTriggered = false;
	g_bFinalVehicleReady = false;

	g_hEndNavMeshAreas.Clear();
	g_hStartNavMeshAreas.Clear();
	g_hBlockedNavMeshAreas.Clear();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		InitPlugin();
	g_iRoundStart = 1;
	
	delete g_hTimer;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		InitPlugin();
	g_iPlayerSpawn = 1;
	
	g_bIsInEndSafeArea[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public void Event_FinaleVehicleReady(Event event, const char[] name, bool dontBroadcast)
{
	g_bFinalVehicleReady = true;
}

public void Event_NavBlocked(Event event, const char[] name, bool dontBroadcast)
{
	int iAreaID = event.GetInt("area");
	int iAreaIndex = view_as<int>(NavMesh_FindAreaByID(iAreaID));
	if(iAreaIndex != -1)
	{
		//bool bBlocked = view_as<bool>(event.GetInt("blocked"));
		if(g_hBlockedNavMeshAreas.FindValue(iAreaIndex) == -1)
			g_hBlockedNavMeshAreas.Push(iAreaIndex);
			
		if(g_bFinalVehicleReady == true && g_bHasTriggered == false && g_iEndSafeAreaTime != 0 && g_hEndNavMeshAreas.Length == 0 && g_hBlockedNavMeshAreas.Length != 0)
		{
			int index;
			int entity = MaxClients + 1;
			float vMins[3], vMaxs[3], vOrigin[3];
			while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE)
			{
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
				GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
				GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
	
				vOrigin[0] = vOrigin[0] + (vMins[0] + vMaxs[0]) * 0.5;
				vOrigin[1] = vOrigin[1] + (vMins[1] + vMaxs[1]) * 0.5;
				vOrigin[2] = vOrigin[2] + (vMins[2] + vMaxs[2]) * 0.5;
			
				int area = view_as<int>(NavMesh_GetNearestArea(vOrigin));
				index = g_hBlockedNavMeshAreas.FindValue(area);
				if(index != -1 && view_as<bool>(g_hNavMeshAreas.Get(area, NavMeshArea_Blocked)) == false)
				{
					g_hEndNavMeshAreas.Push(g_hBlockedNavMeshAreas.Get(index));
					GetEndAreaEntityVectors(entity);
					g_iRescueVehicle = EntIndexToEntRef(entity);
					SDKHook(entity, SDKHook_EndTouch, OnEndTouch);
					SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
					break;
				}
			}
		}
	}	
}

void InitPlugin()
{
	g_hNavMeshAreas = view_as<ArrayList>(NavMesh_GetAreas());
	HookEndAreaEntity();
	InitSafeAreaArray();
	FindSafeAreaDoor();
}

void InitSafeAreaArray()
{
	int iAreaCount = g_hNavMeshAreas.Length;
	for(int iAreaIndex; iAreaIndex < iAreaCount; iAreaIndex++)
	{
		if(g_iChangelevel)
		{
			if(g_hNavMeshAreas.Get(iAreaIndex, TerrorNavArea_SpawnAttributes) & TERROR_NAV_PLAYER_START)
				g_hStartNavMeshAreas.Push(iAreaIndex);
			else if(g_hNavMeshAreas.Get(iAreaIndex, TerrorNavArea_SpawnAttributes) & TERROR_NAV_CHECKPOINT)
			{
				if(NavMeshAreaInEndSafeArea(iAreaIndex))
					g_hEndNavMeshAreas.Push(iAreaIndex);
				else
					g_hStartNavMeshAreas.Push(iAreaIndex);
			}
		}
		else
		{
			if(g_hNavMeshAreas.Get(iAreaIndex, TerrorNavArea_SpawnAttributes) & TERROR_NAV_CHECKPOINT)
				g_hStartNavMeshAreas.Push(iAreaIndex);
			else if(g_hNavMeshAreas.Get(iAreaIndex, TerrorNavArea_SpawnAttributes) & TERROR_NAV_RESCUE_VEHICLE)
				g_hEndNavMeshAreas.Push(iAreaIndex);
		}
	}
}

bool NavMeshAreaInEndSafeArea(int iAreaIndex)
{
	static float vBuffer[3];
	if(!NavMeshArea_GetCenter(iAreaIndex, vBuffer))
		return false;
	
	return PointInEndSafeArea(vBuffer);
}

void HookEndAreaEntity()
{
	g_iChangelevel = 0;
	g_iRescueVehicle = 0;
	//g_iStartSafeDoor = 0;
	g_iLastSafeDoor = 0;

	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		GetEndAreaEntityVectors(entity);
		g_iChangelevel = EntIndexToEntRef(entity);
		SDKHook(entity, SDKHook_EndTouch, OnEndTouch);
		SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
	}
	else
	{
		entity = MaxClients + 1;
		float vMins[3], vMaxs[3], vOrigin[3];
		while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
			GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
			GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
	
			vOrigin[0] = vOrigin[0] + (vMins[0] + vMaxs[0]) * 0.5;
			vOrigin[1] = vOrigin[1] + (vMins[1] + vMaxs[1]) * 0.5;
			vOrigin[2] = vOrigin[2] + (vMins[2] + vMaxs[2]) * 0.5;
			
			CNavArea area = NavMesh_GetNearestArea(vOrigin);
			if(area != INVALID_NAV_AREA && g_hNavMeshAreas.Get(view_as<int>(area), TerrorNavArea_SpawnAttributes) & TERROR_NAV_RESCUE_VEHICLE)
			{
				GetEndAreaEntityVectors(entity);
				g_iRescueVehicle = EntIndexToEntRef(entity);
				SDKHook(entity, SDKHook_EndTouch, OnEndTouch);
				SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
				break;
			}
		}
	}
}

void GetEndAreaEntityVectors(int entity)
{
	g_vMins = view_as<float>({0.0, 0.0, 0.0});
	g_vMaxs = view_as<float>({0.0, 0.0, 0.0});

	float vOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(entity, Prop_Send, "m_vecMins", g_vMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", g_vMaxs);

	g_vMins[0] -= 100.0;
	g_vMins[1] -= 100.0;
	g_vMins[2] -= 100.0;

	g_vMaxs[0] += 200.0;
	g_vMaxs[1] += 200.0;
	g_vMaxs[2] += 200.0;

	AddVectors(vOrigin, g_vMins, g_vMins);
	AddVectors(vOrigin, g_vMaxs, g_vMaxs);
}

void FindSafeAreaDoor()
{
	int index;
	float vOrigin[3];
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
	{
		if(GetEntProp(entity, Prop_Data, "m_spawnflags") == 32768)
			continue;
	
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
		int area = view_as<int>(NavMesh_GetNearestArea(vOrigin));
		index = g_hEndNavMeshAreas.FindValue(area);
		if(index != -1)
		{
			g_iLastSafeDoor = EntIndexToEntRef(entity);
			g_hEndNavMeshAreas.Erase(index);
		}
		else if(PointInEndSafeArea(vOrigin))
			g_iLastSafeDoor = EntIndexToEntRef(entity);
		else
		{
			index = g_hStartNavMeshAreas.FindValue(area);
			if(index != -1)
				g_hStartNavMeshAreas.Erase(index);

			//g_iStartSafeDoor = EntIndexToEntRef(entity);
		}
	}
}

public Action OnEndTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients || GetGameTime() < 30.0)
		return;

	g_bIsInEndSafeArea[other] = false;
}

public Action OnStartTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients || GetGameTime() < 30.0)
		return;

	g_bIsInEndSafeArea[other] = true;

	if(g_bHasTriggered || (g_iRescueVehicle && !g_bFinalVehicleReady) || !IsClientInGame(other) || GetClientTeam(other) != 2 || !IsPlayerAlive(other))
		return;
		
	g_bHasTriggered = true;
	if(g_iEndSafeAreaTime == 0)
		return;

	g_iCountdown = g_iEndSafeAreaTime;
	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, Timer_NotifySurvivor, _, TIMER_REPEAT);
}

public Action Timer_NotifySurvivor(Handle timer)
{
	if(g_iCountdown > 0)
	{
		PrintHintTextToTeam2("%d 秒后%s所有未进入终点区域的玩家", g_iCountdown--, g_sMethod[g_iEndSafeAreaMethod]);
		PlaySound(SOUND_COUNTDOWN);
	}
	else if(g_iCountdown <= 0)
	{
		TeleportOrSuicide(g_iEndSafeAreaMethod);
		g_hTimer = null;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

void PrintHintTextToTeam2(const char[] format, any ...)
{
	char buffer[254];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintHintText(i, "%s", buffer);
		}
	}
}

void TeleportOrSuicide(int iSelect)
{
	switch(iSelect)
	{
		case 0:
		{
			SuicideInfectedAttacker();
			CloseAndLockLastSafeDoor();
			CreateTimer(0.3, Timer_TeleportAllSurvivorsToCheckpoint, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		case 1:
		{
			if(NoPlayerInEndArea())
			{
				PrintHintTextToTeam2("终点区域无玩家存在, 已改为自动传送");
				TeleportOrSuicide(0);
			}
			else
			{
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsAliveSurvivor(i) && !g_bIsInEndSafeArea[i])
						ForcePlayerSuicide(i);
				}
			}
		}
	}
}

stock void SuicideInfectedAttacker()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!g_bIsInEndSafeArea[i] && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && L4D2_HasSurvivorVictim(i))
		{
			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			ForcePlayerSuicide(i);
		}
	}
}

stock void CloseAndLockLastSafeDoor()
{
	if(!IsValidEntRef(g_iLastSafeDoor))
			return;

	SetEntProp(g_iLastSafeDoor, Prop_Data, "m_hasUnlockSequence", 0);
	AcceptEntityInput(g_iLastSafeDoor, "Unlock");
	SetVariantFloat(1000.0);
	AcceptEntityInput(g_iLastSafeDoor, "SetSpeed");
	AcceptEntityInput(g_iLastSafeDoor, "Close");
	AcceptEntityInput(g_iLastSafeDoor, "forceclosed");
	AcceptEntityInput(g_iLastSafeDoor, "Lock");
	SetEntProp(g_iLastSafeDoor, Prop_Data, "m_hasUnlockSequence", 1);
}

public Action Timer_TeleportAllSurvivorsToCheckpoint(Handle timer)
{
	if(IsValidEntRef(g_iLastSafeDoor))
	{
		SetVariantFloat(200.0); //200 default l4d speed
		AcceptEntityInput(g_iLastSafeDoor, "SetSpeed");
		SetVariantString("OnUser1 !self:Unlock::5.0:-1");
		AcceptEntityInput(g_iLastSafeDoor, "AddOutput");
		AcceptEntityInput(g_iLastSafeDoor, "FireUser1");
	}

	TeleportAllSurvivorsToCheckpoint();
}

void TeleportAllSurvivorsToCheckpoint()
{
	if(g_bRemoveAllInfected)
		RemoveAllInfected();

	SuicideInfectedAttacker();

	int iAreaCount = g_hEndNavMeshAreas.Length;
	if(iAreaCount == 0)
		return;

	int iRandom;
	float vCenter[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsAliveSurvivor(i))
		{
			if(GetEntityMoveType(i) == MOVETYPE_NOCLIP)
				SetEntityMoveType(i, MOVETYPE_WALK);

			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			L4D2_ReviveFromIncap(i);
			iRandom = GetRandomInt(0, iAreaCount - 1);
			CNavArea iRandomArea = view_as<CNavArea>(g_hEndNavMeshAreas.Get(iRandom));
			iRandomArea.GetCenter(vCenter);
			TeleportEntity(i, vCenter, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

stock void RemoveAllInfected()
{
	int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(g_bIsInEndSafeArea[i] && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			ForcePlayerSuicide(i);
		}
	}
	
	char sClassName[32];
	float vOrigin[3];
	int iMaxEnts = GetMaxEntities();
	for(i = MaxClients + 1; i <= iMaxEnts; i++)
	{
		if(!IsValidEntity(i))
			continue;

		GetEntityClassname(i, sClassName, sizeof(sClassName));
		if(strcmp(sClassName, "infected") == 0 || strcmp(sClassName, "witch") == 0)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", vOrigin);
			if(PointInEndSafeArea(vOrigin))
				RemoveEntity(i);
		}
	}
}

stock bool L4D2_HasSurvivorVictim(int client)
{
	/* Charger */
	if(GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0)
		return true;

	/* Hunter */
	if(GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0)
		return true;

	/* Smoker */
	if(GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0)
		return true;

	/* Jockey */
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0)
		return true;

	return false;
}

stock bool IsAliveSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

stock void L4D2_ReviveFromIncap(int client) 
{
	if(IsHanging(client))
		L4D2_RunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));
}

//https://forums.alliedmods.net/showpost.php?p=2681159&postcount=10
stock bool IsHanging(int client)
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") > 0;
}

stock void L4D2_RunScript(const char[] sCode, any ...) 
{
	/**
	* Run a VScript (Credit to Timocop)
	*
	* @param sCode		Magic
	* @return void
	*/

	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
			SetFailState("Could not create 'logic_script'");

		DispatchSpawn(iScriptLogic);
	}

	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

bool NoPlayerInEndArea()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bIsInEndSafeArea[i] && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			return false;
	}

	return true;
}

//https://forums.alliedmods.net/showpost.php?p=2680639&postcount=3
stock bool PointInEndSafeArea(const float vLoca[3])
{
	return g_vMins[0] < vLoca[0] < g_vMaxs[0] && g_vMins[1] < vLoca[1] < g_vMaxs[1] && g_vMins[2] < vLoca[2] < g_vMaxs[2];
}

stock bool IsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

stock void PlaySound(const char[] sSound)
{
	EmitSoundToTeam2(sSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

stock void EmitSoundToTeam2(const char[] sample,
				 int entity = SOUND_FROM_PLAYER,
				 int channel = SNDCHAN_AUTO,
				 int level = SNDLEVEL_NORMAL,
				 int flags = SND_NOFLAGS,
				 float volume = SNDVOL_NORMAL,
				 int pitch = SNDPITCH_NORMAL,
				 int speakerentity = -1,
				 const float origin[3] = NULL_VECTOR,
				 const float dir[3] = NULL_VECTOR,
				 bool updatePos = true,
				 float soundtime = 0.0)
{
	int[] clients = new int[MaxClients];
	int total;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
			clients[total++] = i;
	}

	if(total)
	{
		EmitSound(clients, total, sample, entity, channel,
			level, flags, volume, pitch, speakerentity,
			origin, dir, updatePos, soundtime);
	}
}
