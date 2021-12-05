#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define DEBUG						0
#define BENCHMARK					0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#define FIRST_MAP					1
#define MIDDLE_MAP					2
#define	FINAL_MAP					4
#define TERROR_NAV_MISSION_START	128
#define TERROR_NAV_CHECKPOINT		2048
#define TERROR_NAV_RESCUE_VEHICLE	32768
#define GAMEDATA					"safearea_teleport"
#define SOUND_COUNTDOWN 			"buttons/blip1.wav"

Handle
	g_hTimer,
	g_hSDKCleanupPlayerState,
	g_hSDKIsMissionFinalMap,
	g_hSDKGetMissionFirstMap,
	g_hSDKKeyValuesGetString,
	g_hSDKIsFirstMapInScenario,
	g_hSDKGetLastCheckpoint,
	g_hSDKGetInitialCheckpoint,
	g_hSDKCheckpointContainsArea,
	g_hSDKFindRescueAreaTrigger,
	g_hSDKIsTouching,
	g_hSDKIsCheckpointDoor,
	g_hSDKIsCheckpointExitDoor,
	g_hSDKGetLastKnownArea,
	g_hSDKFindRandomSpot;

Address
	g_pTheNavAreas,
	g_pNavMesh,
	g_pDirector;

ArrayList
	g_aLastDoor,
	//g_aStartDoor,
	g_aEndNavArea,
	g_aStartNavArea,
	g_aRescueVehicle,
	g_aTelePortTarget;

ConVar
	g_hSafeArea,
	g_hSafeAreaTime,
	g_hSafeAreaMinSurvivors;

int
	g_iTheCount,
	g_iCountdown,
	g_iCurrentMap,
	g_iRoundStart, 
	g_iPlayerSpawn,
	g_iChangelevel,
	g_iRescueVehicle,
	g_iTriggerFinale,
	g_iSpawnAttributesOffset,
	//g_iFlowDistanceOffset,
	g_iSafeArea,
	g_iSafeAreaTime,
	g_iSafeAreaMinSurvivors;

float
	g_vMins[3],
	g_vMaxs[3];

bool
	g_bLateLoad,
	g_bFirstRound,
	g_bIsTriggered,
	g_bIsSacrificeFinale;

static const char
	g_sMethod[][] =
	{
		"传送",
		"处死",
	};

methodmap CNavArea
{
	public bool IsNull()
	{
		return view_as<Address>(this) == Address_Null;
	}

	public void Mins(float result[3])
	{
		result[0] = view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(4), NumberType_Int32));
		result[1] = view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(8), NumberType_Int32));
		result[2] = view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(12), NumberType_Int32));
	}

	public void Maxs(float result[3])
	{
		result[0] = view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(16), NumberType_Int32));
		result[1] = view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(20), NumberType_Int32));
		result[2] = view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(24), NumberType_Int32));
	}

	public void Center(float result[3])
	{
		float vMins[3];
		float vMaxs[3];
		this.Mins(vMins);
		this.Maxs(vMaxs);

		AddVectors(vMins, vMaxs, result);
		ScaleVector(result, 0.5);
	}

	public void FindRandomSpot(float result[3])
	{
		SDKCall(g_hSDKFindRandomSpot, view_as<int>(this), result, sizeof(result));
		/*
		float vMins[3];
		float vMaxs[3];
		this.Mins(vMins);
		this.Maxs(vMaxs);

		result[0] = GetRandomFloat(vMins[0], vMaxs[0]);
		result[1] = GetRandomFloat(vMins[1], vMaxs[1]);
		result[2] = GetRandomFloat(vMins[2], vMaxs[2]);*/
	}

	property int SpawnAttributes
	{
		public get()
		{
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iSpawnAttributesOffset), NumberType_Int32);
		}
		/*
		public set(int value)
		{
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iSpawnAttributesOffset), value, NumberType_Int32);
		}*/
	}
	/*
	property float Flow
	{
		public get()
		{
			return view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iFlowDistanceOffset), NumberType_Int32));
		}
	}*/
};

//如果签名失效，请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo = 
{
	name = 			"SafeArea Teleport",
	author = 		"sorallll",
	description = 	"",
	version = 		"1.0.8",
	url = 			""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("ST_GetRandomEndSpot", aNative_ST_GetRandomEndSpot);
	CreateNative("ST_GetRandomStartSpot", aNative_ST_GetRandomStartSpot);

	g_bLateLoad = late;
	return APLRes_Success;
}

any aNative_ST_GetRandomEndSpot(Handle plugin, int numParams)
{
	int iLength = g_aEndNavArea.Length;
	if(iLength == 0)
		return false;
	
	float vPos[3];
	CNavArea area = g_aEndNavArea.Get(GetRandomInt(0, iLength - 1));
	area.FindRandomSpot(vPos);
	SetNativeArray(1, vPos, sizeof(vPos));
	return true;
}

any aNative_ST_GetRandomStartSpot(Handle plugin, int numParams)
{
	int iLength = g_aStartNavArea.Length;
	if(iLength == 0)
		return false;

	float vPos[3];
	CNavArea area = g_aStartNavArea.Get(GetRandomInt(0, iLength - 1));
	area.FindRandomSpot(vPos);
	SetNativeArray(1, vPos, sizeof(vPos));
	return true;
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hSafeArea = CreateConVar("st_type", "0", "如何处理未进入终点安全区域的玩家(0=传送,1=处死)", _, true, 0.0, true, 1.0);
	g_hSafeAreaTime = CreateConVar("st_time", "30", "开始倒计时多少秒后进行处理(0=关闭该功能)", _, true, 0.0);
	g_hSafeAreaMinSurvivors = CreateConVar("st_minsurvivors", "1", "当区域内的生还者达到多少时才开始倒计时", _, true, 0.0);
	
	g_hSafeArea.AddChangeHook(vConVarChanged);
	g_hSafeAreaTime.AddChangeHook(vConVarChanged);
	g_hSafeAreaMinSurvivors.AddChangeHook(vConVarChanged);

	AutoExecConfig(true, "safearea_teleport");
	//想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	
	RegAdminCmd("sm_warpstart", cmdWarpStart, ADMFLAG_RCON, "传送所有生还者到起点安全区域");
	RegAdminCmd("sm_warpend", cmdWarpEnd, ADMFLAG_RCON, "传送所有生还者到终点安全区域");
	RegAdminCmd("sm_finale", cmdFinale, ADMFLAG_RCON, "结局关卡强制过关");
	RegAdminCmd("sm_st", cmdSt, ADMFLAG_ROOT, "测试");
	
	g_aLastDoor = new ArrayList(2);
	//g_aStartDoor = new ArrayList(2);
	g_aEndNavArea = new ArrayList();
	g_aStartNavArea = new ArrayList();
	g_aRescueVehicle = new ArrayList();
	g_aTelePortTarget = new ArrayList(2);

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

	if(g_bLateLoad)
	{
		OnMapStart();
		vInitPlugin();
		g_iRoundStart = 1;
		g_iPlayerSpawn = 1;
	}
}

void OnFinaleStart(const char[] output, int caller, int activator, float delay)
{
	if(!bIsValidEntRef(g_iTriggerFinale)) //c5m5, c13m4
	{
		g_iTriggerFinale = EntIndexToEntRef(caller);
		g_bIsSacrificeFinale = !!GetEntProp(g_iTriggerFinale, Prop_Data, "m_bIsSacrificeFinale");

		if(g_bIsSacrificeFinale)
		{
			if(g_bFirstRound)
				PrintToChatAll("\x01当前救援地图是\x05牺牲结局\x01，已关闭自动\x05%s\x01功能", g_sMethod[g_iSafeArea]);

			int iEntRef;
			int iLength = g_aRescueVehicle.Length;
			for(int i; i < iLength; i++)
			{
				if(bIsValidEntRef((iEntRef = g_aRescueVehicle.Get(i))))
					UnhookSingleEntityOutput(iEntRef, "OnStartTouch", OnStartTouch);
			}
		}
	}
}

Action cmdWarpStart(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	int iLength = g_aStartNavArea.Length;
	if(iLength == 0)
	{
		ReplyToCommand(client, "未发现起点Nav区域");
		return Plugin_Handled;
	}

	float vPos[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			vTeleportFix(i);

			view_as<CNavArea>(g_aStartNavArea.Get(GetRandomInt(0, iLength - 1))).FindRandomSpot(vPos);
			TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
		}
	}

	return Plugin_Handled;
}

Action cmdWarpEnd(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if(g_aEndNavArea.Length == 0)
	{
		ReplyToCommand(client, "未发现终点Nav区域");
		return Plugin_Handled;
	}

	vTeleportOrSuicide(0);
	return Plugin_Handled;
}

Action cmdFinale(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if(bIsValidEntRef(g_iTriggerFinale))
		AcceptEntityInput(g_iTriggerFinale, "FinaleEscapeFinished");
	else
	{
		if(bIsValidEntRef(g_iRescueVehicle))
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

Action cmdSt(int client, int args)
{
	ReplyToCommand(client, "过图触发器->%d 救援触发器->%d 起始Nav区域数量->%d 终点Nav区域数量->%d", g_iChangelevel ? EntRefToEntIndex(g_iChangelevel) : -1, SDKCall(g_hSDKFindRescueAreaTrigger), g_aStartNavArea.Length, g_aEndNavArea.Length);
	return Plugin_Handled;
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
	g_iSafeArea = g_hSafeArea.IntValue;
	g_iSafeAreaTime = g_hSafeAreaTime.IntValue;
	g_iSafeAreaMinSurvivors = g_hSafeAreaMinSurvivors.IntValue;
}

public void OnMapStart()
{
	vLateLoadGameData();

	g_bFirstRound = true;

	PrecacheSound(SOUND_COUNTDOWN);

	if(bIsFinalMap())
		g_iCurrentMap |= FINAL_MAP;

	if(bIsFirstMap())
		g_iCurrentMap |= FIRST_MAP;

	if(g_iCurrentMap & FIRST_MAP == 0 && g_iCurrentMap & FINAL_MAP == 0)
		g_iCurrentMap = MIDDLE_MAP;
}

public void OnMapEnd()
{
	vResetPlugin();
	delete g_hTimer;
	g_iCurrentMap = 0;
}

void vResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bFirstRound = false;
	g_bIsTriggered = false;
	g_bIsSacrificeFinale = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(strcmp(name, "round_end") == 0)
		vResetPlugin();

	delete g_hTimer;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;

	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		vInitPlugin();
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		vInitPlugin();
	g_iPlayerSpawn = 1;
}

void vInitPlugin()
{
	if(g_iTheCount == 0)
		return;

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	vHookEndAreaEntity();
	vFindSafeRoomDoors();
	vFindTerrorNavAreas();

	#if BENCHMARK
	g_profiler.Stop();
	//PrintToServer("执行耗时: %f", g_profiler.Time);
	PrintToChatAll("执行耗时: %f", g_profiler.Time);
	#endif
}

void vFindTerrorNavAreas()
{
	g_aEndNavArea.Clear();
	g_aStartNavArea.Clear();

	CNavArea area;
	int iFlags;
	float vCenter[3];

	Address pLastCheckpoint = SDKCall(g_hSDKGetLastCheckpoint, g_pNavMesh);
	Address pInitialCheckpoint = SDKCall(g_hSDKGetInitialCheckpoint, g_pNavMesh);

	for(int i; i < g_iTheCount; i++)
	{
		if(view_as<CNavArea>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32)).IsNull() == true)
			continue;

		iFlags = area.SpawnAttributes;
		if(g_iCurrentMap == MIDDLE_MAP)
		{
			if(iFlags & TERROR_NAV_CHECKPOINT)
			{
				area.Center(vCenter);
				if(!bIsDotInEndArea(vCenter))
				{
					if(pInitialCheckpoint == Address_Null || SDKCall(g_hSDKCheckpointContainsArea, pInitialCheckpoint, area))
						g_aStartNavArea.Push(area);
				}
				else
				{
					if(pLastCheckpoint == Address_Null || SDKCall(g_hSDKCheckpointContainsArea, pLastCheckpoint, area))
						g_aEndNavArea.Push(area);
				}
			}
		}
		else
		{
			if(g_iCurrentMap & FIRST_MAP)
			{
				if(iFlags & TERROR_NAV_CHECKPOINT)
				{
					if(iFlags & TERROR_NAV_MISSION_START)
						g_aStartNavArea.Push(area);
					else
					{
						if(pLastCheckpoint == Address_Null || SDKCall(g_hSDKCheckpointContainsArea, pLastCheckpoint, area))
						{
							area.Center(vCenter);
							if(bIsDotInEndArea(vCenter))
								g_aEndNavArea.Push(area);
						}
					}
				}
			}

			if(g_iCurrentMap & FINAL_MAP)
			{
				if(iFlags & TERROR_NAV_CHECKPOINT)
				{
					if(pInitialCheckpoint == Address_Null || SDKCall(g_hSDKCheckpointContainsArea, pInitialCheckpoint, area))
						g_aStartNavArea.Push(area);
				}

				if(iFlags & TERROR_NAV_RESCUE_VEHICLE)
					g_aEndNavArea.Push(area);
			}
		}
	}
}

void vHookEndAreaEntity()
{
	g_iChangelevel = 0;
	g_iTriggerFinale = 0;
	g_iRescueVehicle = 0;

	g_aRescueVehicle.Clear();

	g_vMins = view_as<float>({0.0, 0.0, 0.0});
	g_vMaxs = view_as<float>({0.0, 0.0, 0.0});

	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		vCalculateBoundingBoxSize((g_iChangelevel = EntIndexToEntRef(entity)));
		HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch);
	}
	else
	{
		entity = FindEntityByClassname(MaxClients + 1, "trigger_finale");
		if(entity != INVALID_ENT_REFERENCE)
		{
			g_iTriggerFinale = EntIndexToEntRef(entity);
			g_bIsSacrificeFinale = !!GetEntProp(g_iTriggerFinale, Prop_Data, "m_bIsSacrificeFinale");
		}

		if(g_bIsSacrificeFinale)
		{
			if(g_bFirstRound)
				PrintToChatAll("\x01当前救援地图是\x05牺牲结局\x01，已关闭自动\x05%s\x01功能", g_sMethod[g_iSafeArea]);
		}
		else
		{
			entity = MaxClients + 1;
			while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE)
			{
				if(GetEntProp(entity, Prop_Data, "m_iEntireTeam") != 2)
					continue;

				g_aRescueVehicle.Push(EntIndexToEntRef(entity));
				HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch);
			}

			if(g_aRescueVehicle.Length == 1)
				vCalculateBoundingBoxSize((g_iRescueVehicle = g_aRescueVehicle.Get(0)));
		}
	}
}

//https://forums.alliedmods.net/showpost.php?p=2680639&postcount=3
void vCalculateBoundingBoxSize(int entity)
{
	float vOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", g_vMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", g_vMaxs);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);

	g_vMins[2] -= 20.0;
	g_vMaxs[2] -= 20.0;

	AddVectors(vOrigin, g_vMins, g_vMins);
	AddVectors(vOrigin, g_vMaxs, g_vMaxs);
}

void vFindSafeRoomDoors()
{
	g_aLastDoor.Clear();
	//g_aStartDoor.Clear();

	if(bIsValidEntRef(g_iChangelevel))
	{
		int iFlags;
		int entity = MaxClients + 1;
		while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
		{
			iFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
			if(iFlags & 8192 == 0 || iFlags & 32768 != 0)
				continue;
		
			if(!SDKCall(g_hSDKIsCheckpointDoor, entity))
				continue;

			if(!SDKCall(g_hSDKIsCheckpointExitDoor, entity))
				g_aLastDoor.Set(g_aLastDoor.Push(EntIndexToEntRef(entity)), GetEntPropFloat(entity, Prop_Data, "m_flSpeed"), 1);
			/*else
				g_aStartDoor.Set(g_aStartDoor.Push(EntIndexToEntRef(entity)), GetEntPropFloat(entity, Prop_Data, "m_flSpeed"), 1);*/
		}
	}
}

void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if(g_bIsTriggered || g_bIsSacrificeFinale || activator < 1 || activator > MaxClients || !IsClientInGame(activator) || GetClientTeam(activator) != 2 || !IsPlayerAlive(activator))
		return;
	
	if(!g_iChangelevel && !g_iRescueVehicle)
	{
		if(caller != SDKCall(g_hSDKFindRescueAreaTrigger))
			return;

		vCalculateBoundingBoxSize((g_iRescueVehicle = EntIndexToEntRef(caller)));

		int i;
		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(; i < iLength; i++)
		{
			if((iEntRef = g_aRescueVehicle.Get(i)) != g_iRescueVehicle && bIsValidEntRef(iEntRef))
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch", OnStartTouch);
		}

		i = 0;
		float vCenter[3];
		iLength = g_aEndNavArea.Length;
		while(i < iLength)
		{
			view_as<CNavArea>(g_aEndNavArea.Get(i)).Center(vCenter);
			if(!bIsDotInEndArea(vCenter))
			{
				g_aEndNavArea.Erase(i);
				iLength--;
			}
			else
				i++;
		}
	}

	if(iGetEndAreaSurvivors() < g_iSafeAreaMinSurvivors)
		return;

	if(g_iSafeAreaTime > 0)
	{
		g_bIsTriggered = true;
		g_iCountdown = g_iSafeAreaTime;

		delete g_hTimer;
		g_hTimer = CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT);
	}
}

int iGetEndAreaSurvivors()
{
	int iSurvivors;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && bIsPlayerInEndArea(i))
			iSurvivors++;
	}
	return iSurvivors;
}

Action Timer_Countdown(Handle timer)
{
	if(g_iCountdown > 0)
	{
		vPrintHintToSurvivor("%d 秒后%s所有未进入终点区域的玩家", g_iCountdown--, g_sMethod[g_iSafeArea]);
		vEmitSoundToSurvivor(SOUND_COUNTDOWN, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
	else if(g_iCountdown <= 0)
	{
		vTeleportOrSuicide(g_iSafeArea);
		g_hTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void vPrintHintToSurvivor(const char[] format, any ...)
{
	char sBuffer[254];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
		{
			SetGlobalTransTarget(i);
			VFormat(sBuffer, sizeof(sBuffer), format, 2);
			PrintHintText(i, "%s", sBuffer);
		}
	}
}

void vTeleportOrSuicide(int iType)
{
	switch(iType)
	{
		case 0:
		{
			vCloseAndLockLastSafeDoor();
			CreateTimer(0.1, Timer_TeleportToCheckpoint, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		case 1:
		{
			if(bNoPlayerInEndArea())
			{
				vPrintHintToSurvivor("终点区域无玩家存在, 已改为自动传送");
				vTeleportOrSuicide(0);
			}
			else
			{
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
						ForcePlayerSuicide(i);
				}
			}
		}
	}
}

void vCloseAndLockLastSafeDoor()
{
	int iEntRef;
	int iLength = g_aLastDoor.Length;
	for(int i; i < iLength; i++)
	{
		if(!bIsValidEntRef((iEntRef = g_aLastDoor.Get(i))))
			continue;
		
		SetEntPropFloat(iEntRef, Prop_Data, "m_flSpeed", 1000.0);
		SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 0);
		AcceptEntityInput(iEntRef, "Unlock");
		AcceptEntityInput(iEntRef, "Close");
		AcceptEntityInput(iEntRef, "forceclosed");
		AcceptEntityInput(iEntRef, "Lock");
		SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 1);
	}
}

Action Timer_TeleportToCheckpoint(Handle timer)
{
	g_aTelePortTarget.Clear();

	int iEntRef;
	int iLength = g_aLastDoor.Length;
	for(int i; i < iLength; i++)
	{
		if(!bIsValidEntRef((iEntRef = g_aLastDoor.Get(i))))
			continue;

		SetEntPropFloat(iEntRef, Prop_Data, "m_flSpeed", g_aLastDoor.Get(i, 1));
		SetVariantString("OnUser1 !self:Unlock::5.0:-1");
		AcceptEntityInput(iEntRef, "AddOutput");
		AcceptEntityInput(iEntRef, "FireUser1");
	}

	vTeleportToCheckpoint();
	return Plugin_Continue;
}

void vTeleportToCheckpoint()
{
	int iLength = g_aEndNavArea.Length;
	if(iLength > 0)
	{
		vRemoveInfecteds();

		int i = 1;
		for(; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
			{
				SDKCall(g_hSDKCleanupPlayerState, i);
				ForcePlayerSuicide(i);
			}
		}

		CNavArea area;
		float vPos[3];
		for(i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
			{
				vTeleportFix(i);

				area = g_aEndNavArea.Get(GetRandomInt(0, iLength - 1));
				area.FindRandomSpot(vPos);
				TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
				g_aTelePortTarget.Set(g_aTelePortTarget.Push(GetClientUserId(i)), area, 1);
			}
		}

		CreateTimer(0.2, Timer_DectcetTeleport, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_DectcetTeleport(Handle timer)
{
	int i = 1;
	int iIndex;
	for(; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
		{
			iIndex = g_aTelePortTarget.FindValue(GetClientUserId(i), 0);
			if(iIndex != -1)
			{
				iIndex = g_aEndNavArea.FindValue(g_aTelePortTarget.Get(iIndex, 1));
				if(iIndex != -1)
					g_aEndNavArea.Erase(iIndex);
			}
		}
	}

	int iLength = g_aEndNavArea.Length;
	if(iLength > 0)
	{
		float vPos[3];
		for(i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
			{
				vTeleportFix(i);

				view_as<CNavArea>(g_aEndNavArea.Get(GetRandomInt(0, iLength - 1))).FindRandomSpot(vPos);
				TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}

	return Plugin_Continue;
}

void vTeleportFix(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		vRunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", client);

	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);

	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

void vRunScript(const char[] sCode, any ...) 
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

void vRemoveInfecteds()
{
	char sClassName[9];
	float vOrigin[3];
	int iMaxEnts = GetMaxEntities();
	for(int i = MaxClients + 1; i <= iMaxEnts; i++)
	{
		if(!IsValidEntity(i))
			continue;

		GetEntityClassname(i, sClassName, sizeof(sClassName));
		if(strcmp(sClassName, "infected") == 0 || strcmp(sClassName, "witch") == 0)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", vOrigin);
			if(bIsDotInEndArea(vOrigin))
				RemoveEntity(i);
		}
	}
}

bool bNoPlayerInEndArea()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && bIsPlayerInEndArea(i))
			return false;
	}
	return true;
}

bool bIsDotInEndArea(const float vDot[3])
{
	return g_vMins[0] < vDot[0] < g_vMaxs[0] && g_vMins[1] < vDot[1] < g_vMaxs[1] && g_vMins[2] < vDot[2] < g_vMaxs[2];
}

bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}

void vEmitSoundToSurvivor(const char[] sample,
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

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pNavMesh = hGameData.GetAddress("TerrorNavMesh");
	if(g_pNavMesh == Address_Null)
		SetFailState("Failed to find address: TerrorNavMesh");

	g_pDirector = hGameData.GetAddress("CDirector");
	if(g_pDirector == Address_Null)
		SetFailState("Failed to find address: CDirector");

	g_iSpawnAttributesOffset = hGameData.GetOffset("TerrorNavArea::ScriptGetSpawnAttributes");
	if(g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: TerrorNavArea::ScriptGetSpawnAttributes");
	/*
	g_iFlowDistanceOffset = hGameData.GetOffset("CTerrorPlayer::GetFlowDistance::m_flow");
	if(g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::GetFlowDistance::m_flow");*/

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::CleanupPlayerState") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::CleanupPlayerState");
	g_hSDKCleanupPlayerState = EndPrepSDKCall();
	if(g_hSDKCleanupPlayerState == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::CleanupPlayerState");

	
	StartPrepSDKCall(SDKCall_GameRules);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::IsMissionFinalMap") == false)
		SetFailState("Failed to find signature: CTerrorGameRules::IsMissionFinalMap");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsMissionFinalMap = EndPrepSDKCall();
	if(g_hSDKIsMissionFinalMap == null)
		SetFailState("Failed to create SDKCall: CTerrorGameRules::IsMissionFinalMap");

	StartPrepSDKCall(SDKCall_Static);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionFirstMap") == false)
		SetFailState("Failed to find signature: CTerrorGameRules::GetMissionFirstMap");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain, VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMissionFirstMap = EndPrepSDKCall();
	if(g_hSDKGetMissionFirstMap == null)
		SetFailState("Failed to create SDKCall: CTerrorGameRules::GetMissionFirstMap");
		
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString") == false)
		SetFailState("Failed to find signature: KeyValues::GetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	g_hSDKKeyValuesGetString = EndPrepSDKCall();
	if(g_hSDKKeyValuesGetString == null)
		SetFailState("Failed to create SDKCall: KeyValues::GetString");
		
	StartPrepSDKCall(SDKCall_Raw);
	if (PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsFirstMapInScenario") == false)
		SetFailState("Failed to find signature: CDirector::IsFirstMapInScenario");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsFirstMapInScenario = EndPrepSDKCall();
	if(g_hSDKIsFirstMapInScenario == null)
		SetFailState("Failed to create SDKCall: CDirector::IsFirstMapInScenario");
		
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavMesh::GetLastCheckpoint") == false)
		SetFailState("Failed to find signature: TerrorNavMesh::GetLastCheckpoint");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetLastCheckpoint = EndPrepSDKCall();
	if(g_hSDKGetLastCheckpoint == null)
		SetFailState("Failed to create SDKCall: TerrorNavMesh::GetLastCheckpoint");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavMesh::GetInitialCheckpoint") == false)
		SetFailState("Failed to find signature: TerrorNavMesh::GetInitialCheckpoint");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetInitialCheckpoint = EndPrepSDKCall();
	if(g_hSDKGetInitialCheckpoint == null)
		SetFailState("Failed to create SDKCall: TerrorNavMesh::GetInitialCheckpoint");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Checkpoint::ContainsArea") == false)
		SetFailState("Failed to find signature: Checkpoint::ContainsArea");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKCheckpointContainsArea = EndPrepSDKCall();
	if(g_hSDKCheckpointContainsArea == null)
		SetFailState("Failed to create SDKCall: Checkpoint::ContainsArea");

	StartPrepSDKCall(SDKCall_GameRules);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirectorChallengeMode::FindRescueAreaTrigger") == false)
		SetFailState("Failed to find signature: CDirectorChallengeMode::FindRescueAreaTrigger");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKFindRescueAreaTrigger = EndPrepSDKCall();
	if(g_hSDKFindRescueAreaTrigger == null)
		SetFailState("Failed to create SDKCall: CDirectorChallengeMode::FindRescueAreaTrigger");

	StartPrepSDKCall(SDKCall_Entity);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CBaseTrigger::IsTouching") == false)
		SetFailState("Failed to find signature: CBaseTrigger::IsTouching");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsTouching = EndPrepSDKCall();
	if(g_hSDKIsTouching == null)
		SetFailState("Failed to create SDKCall: CBaseTrigger::IsTouching");

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

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorPlayer::GetLastKnownArea") == false)
		SetFailState("Failed to find offset: CTerrorPlayer::GetLastKnownArea");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetLastKnownArea = EndPrepSDKCall();
	if(g_hSDKGetLastKnownArea == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GetLastKnownArea");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavArea::FindRandomSpot") == false)
		SetFailState("Failed to find signature: TerrorNavArea::FindRandomSpot");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	g_hSDKFindRandomSpot = EndPrepSDKCall();
	if(g_hSDKFindRandomSpot == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::FindRandomSpot");

	delete hGameData;
}

void vLateLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	Address pTheCount = hGameData.GetAddress("TheCount");
	if(pTheCount == Address_Null)
		SetFailState("Failed to find address: TheCount");

	g_iTheCount = LoadFromAddress(pTheCount, NumberType_Int32);
	if(g_iTheCount == 0)
	{
		#if DEBUG
		//PrintToServer("当前Nav区域数量为0， 可能是某些测试地图");
		PrintToChatAll("当前Nav区域数量为0， 可能是某些测试地图");
		#endif
	}

	g_pTheNavAreas = view_as<Address>(LoadFromAddress(pTheCount + view_as<Address>(4), NumberType_Int32));
	if(g_pTheNavAreas == Address_Null)
		SetFailState("Failed to find address: TheNavAreas");

	delete hGameData;
}

bool bIsPlayerInEndArea(int client)
{
	if(SDKCall(g_hSDKGetLastKnownArea, client) == 0)
		return false;

	if(g_iCurrentMap & FINAL_MAP == 0)
		return bIsValidEntRef(g_iChangelevel) && SDKCall(g_hSDKIsTouching, g_iChangelevel, client);

	return bIsValidEntRef(g_iRescueVehicle) && SDKCall(g_hSDKIsTouching, g_iRescueVehicle, client);
}

bool bIsFinalMap()
{
	return SDKCall(g_hSDKIsMissionFinalMap);
}

bool bIsFirstMap()
{
	int iKeyvalue = SDKCall(g_hSDKGetMissionFirstMap, 0);
	if(iKeyvalue > 0)
	{
		char sMap[128], sCheck[128];
		GetCurrentMap(sMap, sizeof(sMap));
		SDKCall(g_hSDKKeyValuesGetString, iKeyvalue, sCheck, sizeof(sCheck), "map", "N/A");
		return strcmp(sMap, sCheck) == 0;
	}

	return SDKCall(g_hSDKIsFirstMapInScenario, g_pDirector);
}
