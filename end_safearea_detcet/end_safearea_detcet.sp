#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <navmesh>

#define SOUND_COUNTDOWN "buttons/blip1.wav"

ArrayList g_hEndNavMeshAreas;
ArrayList g_hStartNavMeshAreas;
ArrayList g_hRescueVehicleEntities;

Handle g_hTimer;

ConVar g_hEndSafeAreaMethod;
ConVar g_hEndSafeAreaTime;
ConVar g_hRemoveAllInfected;

int g_iCountdown;
int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iChangelevel;
int g_iRescueVehicle;
int g_iTriggerFinale;
int g_iLastSafeDoor;
//int g_iStartSafeDoor;
int g_iEndSafeAreaMethod;
int g_iEndSafeAreaTime;

float g_vMins[3];
float g_vMaxs[3];
float g_vScaleMins[3];
float g_vScaleMaxs[3];

bool g_bHasTriggered;
bool g_bIsSacrificeFinale;
bool g_bRemoveAllInfected;
bool g_bFinaleVehicleReady;
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
	g_hEndSafeAreaTime = CreateConVar("end_safearea_time", "60", "倒计时多久(0=关闭该功能)", _, true, 0.0);
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
	
	RegAdminCmd("sm_warpstart", CmdWarpStart, ADMFLAG_RCON, "传送所有生还者到起点安全区域");
	RegAdminCmd("sm_warpend", CmdWarpEnd, ADMFLAG_RCON, "传送所有生还者到终点安全区域");
	RegAdminCmd("sm_finale", CmdFinale, ADMFLAG_RCON, "结局关卡强制过关");
	RegAdminCmd("sm_esd", CmdEsd, ADMFLAG_ROOT, "测试");
	
	g_hEndNavMeshAreas = new ArrayList(1);
	g_hStartNavMeshAreas = new ArrayList(1);
	g_hRescueVehicleEntities = new ArrayList(1);

	HookEntityOutput("trigger_finale", "FinaleStart", EntityOutput_FinaleStart);
	HookEntityOutput("trigger_finale", "FinaleEscapeStarted", EntityOutput_FinaleEscapeStarted);
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

	float vRandom[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsAliveSurvivor(i))
		{
			if(GetEntityMoveType(i) == MOVETYPE_NOCLIP)
				SetEntityMoveType(i, MOVETYPE_WALK);

			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			if(IsHanging(i))
				L4D2_ReviveFromIncap(i);
			else
			{
				int attacker = L4D2_GetInfectedAttacker(i);
				if(attacker > 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker))
				{
					SetEntProp(attacker, Prop_Send, "m_fFlags", GetEntProp(attacker, Prop_Send, "m_fFlags") & ~FL_FROZEN);
					ForcePlayerSuicide(attacker);
				}
			}

			view_as<CNavArea>(g_hStartNavMeshAreas.Get(GetRandomInt(0, iAreaCount - 1))).GetRandomPoint(vRandom);
			TeleportEntity(i, vRandom, NULL_VECTOR, NULL_VECTOR);
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

	if(g_bIsSacrificeFinale)
	{
		ReplyToCommand(client, "牺牲类型的结局不支持传送");
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

	if(IsValidEntRef(g_iTriggerFinale))
		AcceptEntityInput(g_iTriggerFinale, "FinaleEscapeFinished");
	else
	{
		if(IsValidEntRef(g_iRescueVehicle))
		{
			FireEntityOutput(g_iRescueVehicle, "OnEntireTeamStartTouch", -1, 0.0);
			Event event = CreateEvent("finale_win", true);
			event.Fire(false);
		}
		else
			ReplyToCommand(client, "不是结局地图");
	}

	return Plugin_Handled;
}

public Action CmdEsd(int client, int args)
{
	ReplyToCommand(client, "g_hStartNavMeshAreas.Length->%d g_hEndNavMeshAreas.Length->%d", g_hStartNavMeshAreas.Length, g_hEndNavMeshAreas.Length);
	return Plugin_Handled;
}

public void EntityOutput_FinaleStart(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidEntRef(g_iTriggerFinale)) //c5m5, c13m4
	{
		g_iTriggerFinale = EntIndexToEntRef(caller);
		g_bIsSacrificeFinale = view_as<bool>(GetEntProp(caller, Prop_Data, "m_bIsSacrificeFinale")); //https://developer.valvesoftware.com/wiki/Trigger_finale 排除牺牲类型的结局
	}

	if(g_bIsSacrificeFinale)
	{
		int iEntRef;
		int iCount = g_hRescueVehicleEntities.Length;
		for(int iIndex; iIndex < iCount; iIndex++)
		{
			if(IsValidEntRef((iEntRef = g_hRescueVehicleEntities.Get(iIndex))))
			{
				SDKUnhook(iEntRef, SDKHook_EndTouch, RescueVehicle_OnEndTouch);
				SDKUnhook(iEntRef, SDKHook_StartTouch, RescueVehicle_OnStartTouch);
			}
		}
		
		if(g_hTimer != null)
			delete g_hTimer;

		g_hRescueVehicleEntities.Clear();
	}
}

public void EntityOutput_FinaleEscapeStarted(const char[] output, int caller, int activator, float delay)
{
	g_bFinaleVehicleReady = true;
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
	g_bIsSacrificeFinale = false;
	g_bFinaleVehicleReady = false;
	
	if(IsValidEntRef(g_iChangelevel))
	{
		SDKUnhook(g_iChangelevel, SDKHook_EndTouch, Changelevel_OnEndTouch);
		SDKUnhook(g_iChangelevel, SDKHook_StartTouch, Changelevel_OnStartTouch);
	}
	
	int iEntRef;
	int iCount = g_hRescueVehicleEntities.Length;
	for(int iIndex; iIndex < iCount; iIndex++)
	{
		if(IsValidEntRef((iEntRef = g_hRescueVehicleEntities.Get(iIndex))))
		{
			SDKUnhook(iEntRef, SDKHook_EndTouch, RescueVehicle_OnEndTouch);
			SDKUnhook(iEntRef, SDKHook_StartTouch, RescueVehicle_OnStartTouch);
		}
	}

	g_hEndNavMeshAreas.Clear();
	g_hStartNavMeshAreas.Clear();
	g_hRescueVehicleEntities.Clear();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		CreateTimer(0.1, Timer_Start, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
	
	delete g_hTimer;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		CreateTimer(0.1, Timer_Start, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
	
	g_bIsInEndSafeArea[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public void Event_FinaleVehicleReady(Event event, const char[] name, bool dontBroadcast)
{
	g_bFinaleVehicleReady = true;
}

public Action Timer_Start(Handle timer) //等待OnNavMeshLoaded
{
	HookEndAreaEntity();
	FindSafeRoomDoors();
}

void HookEndAreaEntity()
{
	g_iChangelevel = 0;
	g_iRescueVehicle = 0;
	g_iTriggerFinale = 0;

	g_vMins = view_as<float>({0.0, 0.0, 0.0});
	g_vMaxs = view_as<float>({0.0, 0.0, 0.0});
	g_vScaleMins = view_as<float>({0.0, 0.0, 0.0});
	g_vScaleMaxs = view_as<float>({0.0, 0.0, 0.0});

	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		GetEndAreaEntityVectors(entity);
		g_iChangelevel = EntIndexToEntRef(entity);
		SDKHook(entity, SDKHook_EndTouch, Changelevel_OnEndTouch);
		SDKHook(entity, SDKHook_StartTouch, Changelevel_OnStartTouch);
	}
	else
	{
		g_iTriggerFinale = FindEntityByClassname(MaxClients + 1, "trigger_finale");
		if(g_iTriggerFinale != INVALID_ENT_REFERENCE)
		{
			g_iTriggerFinale = EntIndexToEntRef(g_iTriggerFinale);
			g_bIsSacrificeFinale = view_as<bool>(GetEntProp(g_iTriggerFinale, Prop_Data, "m_bIsSacrificeFinale"));
		}
		
		if(g_bIsSacrificeFinale)
			return;

		entity = MaxClients + 1;
		float vMins[3], vMaxs[3], vOrigin[3];
		while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE)
		{
			if(GetEntProp(entity, Prop_Data, "m_iEntireTeam") != 2)
				continue;

			GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
			GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
	
			vOrigin[0] = vOrigin[0] + (vMins[0] + vMaxs[0]) * 0.5;
			vOrigin[1] = vOrigin[1] + (vMins[1] + vMaxs[1]) * 0.5;
			vOrigin[2] = vOrigin[2] + (vMins[2] + vMaxs[2]) * 0.5;

			CNavArea area = NavMesh_GetNearestArea(vOrigin);
			if(area != INVALID_NAV_AREA && view_as<TerrorNavArea>(area).SpawnAttributes & TERROR_NAV_RESCUE_VEHICLE)
			{
				GetEndAreaEntityVectors(entity);
				g_iRescueVehicle = EntIndexToEntRef(entity);
				g_hRescueVehicleEntities.Push(g_iRescueVehicle);
				SDKHook(entity, SDKHook_EndTouch, RescueVehicle_OnEndTouch);
				SDKHook(entity, SDKHook_StartTouch, RescueVehicle_OnStartTouch);
				break;
			}
		}
		
		if(g_iRescueVehicle == 0)
		{
			entity = MaxClients + 1;
			while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE)
			{
				if(GetEntProp(entity, Prop_Data, "m_iEntireTeam") != 2)
					continue;

				g_hRescueVehicleEntities.Push(EntIndexToEntRef(entity));
				SDKHook(entity, SDKHook_EndTouch, RescueVehicle_OnEndTouch);
				SDKHook(entity, SDKHook_StartTouch, RescueVehicle_OnStartTouch);
			}
		}
	}
}

//https://forums.alliedmods.net/showpost.php?p=2680639&postcount=3
void GetEndAreaEntityVectors(int entity)
{
	float vMins[3], vMaxs[3], vOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);

	g_vMins[0] = vMins[0];
	g_vMins[1] = vMins[1];
	g_vMins[2] = vMins[2] - 50.0;
	
	g_vMaxs[0] = vMaxs[0];
	g_vMaxs[1] = vMaxs[1];
	g_vMaxs[2] = vMaxs[2] - 5.0;

	AddVectors(vOrigin, g_vMins, g_vMins);
	AddVectors(vOrigin, g_vMaxs, g_vMaxs);
	
	g_vScaleMins[0] = vMins[0] - 200.0;
	g_vScaleMins[1] = vMins[1] - 200.0;
	g_vScaleMins[2] = vMins[2] - 200.0;
	
	g_vScaleMaxs[0] = vMaxs[0] + 200.0;
	g_vScaleMaxs[1] = vMaxs[1] + 200.0;
	g_vScaleMaxs[2] = vMaxs[2] + 200.0;
	
	AddVectors(vOrigin, g_vScaleMins, g_vScaleMins);
	AddVectors(vOrigin, g_vScaleMaxs, g_vScaleMaxs);
}

void FindSafeRoomDoors()
{
	g_iLastSafeDoor = 0;
	//g_iStartSafeDoor = 0;
	
	float vOrigin[3];
	int entity = MaxClients + 1;
	ArrayList hSafeDoorNavMeshAreas = new ArrayList(1);
	while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
	{
		if(!IsValidDoorFlags(entity))
			continue;

		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
		CNavArea area = NavMesh_GetNearestArea(vOrigin);
		if(area != INVALID_NAV_AREA)
			hSafeDoorNavMeshAreas.Push(view_as<int>(area));

		if(g_iChangelevel && IsDotInScaleEndArea(vOrigin))
			g_iLastSafeDoor = EntIndexToEntRef(entity);
		/*else
			g_iStartSafeDoor = EntIndexToEntRef(entity);*/
	}

	FindNavMeshAreas(hSafeDoorNavMeshAreas);
}

void FindNavMeshAreas(ArrayList hSafeDoorNavMeshAreas)
{
	ArrayList hNavMeshAreas = view_as<ArrayList>(NavMesh_GetAreas());

	int iSpawnFlags;
	float vBuffer[3];
	int iAreaCount = hNavMeshAreas.Length;
	for(int iAreaIndex = 0; iAreaIndex < iAreaCount; iAreaIndex++)
	{
		if(hSafeDoorNavMeshAreas.FindValue(iAreaIndex) != -1)
			continue;

		iSpawnFlags = hNavMeshAreas.Get(iAreaIndex, 49);
		if(iSpawnFlags & TERROR_NAV_PLAYER_START)
			g_hStartNavMeshAreas.Push(iAreaIndex);
		else if(iSpawnFlags & TERROR_NAV_RESCUE_VEHICLE)
			g_hEndNavMeshAreas.Push(iAreaIndex);
		else if(iSpawnFlags & TERROR_NAV_CHECKPOINT)
		{
			vBuffer[0] = view_as<float>(hNavMeshAreas.Get(iAreaIndex, 9));
			vBuffer[1] = view_as<float>(hNavMeshAreas.Get(iAreaIndex, 10));
			vBuffer[2] = NavMeshAreaGetZ(iAreaIndex, vBuffer);
	
			if(!IsDotInScaleEndArea(vBuffer))
				g_hStartNavMeshAreas.Push(iAreaIndex);
			else if(IsDotInNormalEndArea(vBuffer))
				g_hEndNavMeshAreas.Push(iAreaIndex);
		}
	}
}

stock float NavMeshAreaGetZ(int iAreaIndex, const float flPos[3])
{
	float flExtentLow[3], flExtentHigh[3];
	NavMeshArea_GetExtentLow(iAreaIndex, flExtentLow);
	NavMeshArea_GetExtentHigh(iAreaIndex, flExtentHigh);
	
	float dx = flExtentHigh[0] - flExtentLow[0];
	float dy = flExtentHigh[1] - flExtentLow[1];
	
	float flNEZ = NavMeshArea_GetNECornerZ(iAreaIndex);
	
	if(dx == 0.0 || dy == 0.0)
		return flNEZ;

	float u = (flPos[0] - flExtentLow[0]) / dx;
	float v = (flPos[1] - flExtentLow[1]) / dy;
	
	u = fsel(u, u, 0.0);
	u = fsel(u - 1.0, 1.0, u);
	
	v = fsel(v, v, 0.0);
	v = fsel(v - 1.0, 1.0, v);
	
	float flSWZ = NavMeshArea_GetSWCornerZ(iAreaIndex);
	
	float flNorthZ = flExtentLow[2] + u * (flNEZ - flExtentLow[2]);
	float flSouthZ = flSWZ + u * (flExtentHigh[2] - flSWZ);
	
	return flNorthZ + v * (flSouthZ - flNorthZ);
}

stock float fsel(float a, float b, float c)
{
	return a >= 0.0 ? b : c;
}

bool IsValidDoorFlags(int entity)
{
    int flags = GetEntProp(entity, Prop_Data, "m_spawnflags");
    return (flags & 8192 != 0) && (flags & 32768 == 0);
}

public Action Changelevel_OnEndTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients || GetGameTime() < 30.0)
		return;

	g_bIsInEndSafeArea[other] = false;
}

public Action Changelevel_OnStartTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients || GetGameTime() < 30.0)
		return;

	g_bIsInEndSafeArea[other] = true;

	if(g_bHasTriggered || !IsClientInGame(other) || GetClientTeam(other) != 2 || !IsPlayerAlive(other))
		return;

	g_bHasTriggered = true;
	if(g_iEndSafeAreaTime == 0)
		return;

	g_iCountdown = g_iEndSafeAreaTime;
	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, Timer_NotifySurvivor, _, TIMER_REPEAT);
}

public Action RescueVehicle_OnEndTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients)
		return;

	g_bIsInEndSafeArea[other] = false;
}

public Action RescueVehicle_OnStartTouch(int entity, int other)
{
	if(g_bIsSacrificeFinale || other < 1 || other > MaxClients)
		return;
	
	g_bIsInEndSafeArea[other] = true;

	if(!g_iRescueVehicle && !g_bFinaleVehicleReady)
	{
		SDKUnhook(entity, SDKHook_EndTouch, RescueVehicle_OnEndTouch);
		SDKUnhook(entity, SDKHook_StartTouch, RescueVehicle_OnStartTouch);
		int iIndex = g_hRescueVehicleEntities.FindValue(EntIndexToEntRef(entity));
		if(iIndex != -1)
			g_hRescueVehicleEntities.Erase(iIndex);
			
		return;
	}

	if(g_bHasTriggered || !IsClientInGame(other) || GetClientTeam(other) != 2 || !IsPlayerAlive(other))
		return;

	int iCount = g_hRescueVehicleEntities.Length;
	if(iCount > 1)
	{
		g_iRescueVehicle = EntIndexToEntRef(entity);

		int iIndex;
		int iEntRef;
		while(iIndex < iCount)
		{
			if((iEntRef = g_hRescueVehicleEntities.Get(iIndex)) != g_iRescueVehicle)
			{
				if(IsValidEntRef(iEntRef))
				{
					SDKUnhook(iEntRef, SDKHook_EndTouch, RescueVehicle_OnEndTouch);
					SDKUnhook(iEntRef, SDKHook_StartTouch, RescueVehicle_OnStartTouch);
				}
				g_hRescueVehicleEntities.Erase(iIndex);
				iCount--;
			}
			else
				iIndex++;
		}

		float vMins[3], vMaxs[3], vOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
	
		vOrigin[0] = vOrigin[0] + (vMins[0] + vMaxs[0]) * 0.5;
		vOrigin[1] = vOrigin[1] + (vMins[1] + vMaxs[1]) * 0.5;
		vOrigin[2] = vOrigin[2] + (vMins[2] + vMaxs[2]) * 0.5;
			
		CNavArea area = NavMesh_GetNearestArea(vOrigin);
		if(area != INVALID_NAV_AREA)
			g_hEndNavMeshAreas.Push(view_as<int>(area));
	}
	
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
	if(g_bIsSacrificeFinale)
		return;

	switch(iSelect)
	{
		case 0:
		{
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

stock void CloseAndLockLastSafeDoor()
{
	if(!IsValidEntRef(g_iLastSafeDoor) || !IsValidDoorFlags(g_iLastSafeDoor))
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
	if(IsValidEntRef(g_iLastSafeDoor) && IsValidDoorFlags(g_iLastSafeDoor))
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

	int iAreaCount = g_hEndNavMeshAreas.Length;
	
	if(iAreaCount == 0)
		return;

	float vRandom[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsAliveSurvivor(i))
		{
			if(GetEntityMoveType(i) == MOVETYPE_NOCLIP)
				SetEntityMoveType(i, MOVETYPE_WALK);

			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);

			if(IsHanging(i))
				L4D2_ReviveFromIncap(i);
			else
			{
				int attacker = L4D2_GetInfectedAttacker(i);
				if(attacker > 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker))
				{
					SetEntProp(attacker, Prop_Send, "m_fFlags", GetEntProp(attacker, Prop_Send, "m_fFlags") & ~FL_FROZEN);
					ForcePlayerSuicide(attacker);
				}
			}

			view_as<CNavArea>(g_hEndNavMeshAreas.Get(GetRandomInt(0, iAreaCount - 1))).GetRandomPoint(vRandom);
			TeleportEntity(i, vRandom, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

/**
 * Returns infected attacker of survivor victim.
 *
 * Note: Infected attacker means the infected player that is currently
 * pinning down the survivor. Such as hunter, smoker, charger and jockey.
 *
 * @param client        Survivor client index.
 * @return              Infected attacker index, -1 if not found.
 * @error               Invalid client index.
 */
stock int L4D2_GetInfectedAttacker(int client)
{
    int attacker;

    /* Charger */
    attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
    if(attacker > 0)
        return attacker;

    attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
    if(attacker > 0)
        return attacker;

    /* Hunter */
    attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
    if(attacker > 0)
        return attacker;

    /* Smoker */
    attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
    if(attacker > 0)
        return attacker;

    /* Jockey */
    attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
    if(attacker > 0)
        return attacker;

    return -1;
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
			if(IsDotInScaleEndArea(vOrigin))
				RemoveEntity(i);
		}
	}
}

stock bool IsAliveSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

//https://forums.alliedmods.net/showpost.php?p=2681159&postcount=10
stock bool IsHanging(int client)
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") > 0;
}

stock void L4D2_ReviveFromIncap(int client) 
{
	L4D2_RunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));
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
stock bool IsDotInNormalEndArea(const float vDot[3])
{
	return g_vMins[0] < vDot[0] < g_vMaxs[0] && g_vMins[1] < vDot[1] < g_vMaxs[1] && g_vMins[2] < vDot[2] < g_vMaxs[2];
}

stock bool IsDotInScaleEndArea(const float vDot[3])
{
	return g_vScaleMins[0] < vDot[0] < g_vScaleMaxs[0] && g_vScaleMins[1] < vDot[1] < g_vScaleMaxs[1] && g_vScaleMins[2] < vDot[2] < g_vScaleMaxs[2];
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
