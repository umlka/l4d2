#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define DEBUG						0
#define FIRST_MAP					1
#define MIDDLE_MAP					2
#define	FINAL_MAP					4
#define TERROR_NAV_FINALE			64
#define TERROR_NAV_MISSION_START	128
#define TERROR_NAV_CHECKPOINT		2048
#define TERROR_NAV_RESCUE_VEHICLE	32768
#define GAMEDATA					"safearea_teleport"
#define SOUND_COUNTDOWN 			"buttons/blip1.wav"

GameData
	g_hGameData;

Handle
	g_hTimer,
	g_hSDK_Call_CleanupPlayerState,
	g_hSDK_Call_GetSpawnAttributes,
	//g_hSDK_Call_HasSpawnAttributes,
	g_hSDK_Call_IsAreaConnectedToNonCheckpointArea,
	//g_hSDK_Call_ScriptGetDoor,
	g_hSDK_Call_IsTouching,
	g_hSDK_Call_IsCheckpointDoor,
	g_hSDK_Call_IsCheckpointExitDoor;

Address
	g_pTheCount,
	g_pTheNavAreas;

ArrayList
	g_aLastDoor,
	g_aEndNavArea,
	g_aStartNavArea,
	g_aRescueVehicle;

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
	g_iSafeArea,
	g_iSafeAreaTime,
	g_iSafeAreaMinSurvivors;

float
	g_vMins[3],
	g_vMaxs[3];

bool
	g_bLateLoad,
	g_bFirstRound,
	g_bHasTriggered,
	g_bIsSacrificeFinale;

static const char
	g_sMethod[][] =
	{
		"传送",
		"处死",
	};

public Plugin myinfo = 
{
    name = 			"SafeArea Teleport",
    author = 		"sorallll",
    description = 	"",
    version = 		"1.0.4",
    url = 			""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hSafeArea = CreateConVar("est_type", "0", "如何处理未进入终点安全区域的玩家(0=传送,1=处死)", _, true, 0.0, true, 1.0);
	g_hSafeAreaTime = CreateConVar("est_time", "30", "开始倒计时多少秒后进行处理(0=关闭该功能)", _, true, 0.0);
	g_hSafeAreaMinSurvivors = CreateConVar("est_minsurvivors", "1", "当区域内的生还者达到多少时才开始倒计时", _, true, 0.0);
	
	g_hSafeArea.AddChangeHook(vConVarChanged);
	g_hSafeAreaTime.AddChangeHook(vConVarChanged);
	g_hSafeAreaMinSurvivors.AddChangeHook(vConVarChanged);

	//AutoExecConfig(true, "end_safezone_detcet");
	//想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	
	RegAdminCmd("sm_warpstart", cmdWarpStart, ADMFLAG_RCON, "传送所有生还者到起点安全区域");
	RegAdminCmd("sm_warpend", cmdWarpEnd, ADMFLAG_RCON, "传送所有生还者到终点安全区域");
	RegAdminCmd("sm_finale", cmdFinale, ADMFLAG_RCON, "结局关卡强制过关");
	RegAdminCmd("sm_est", cmdEst, ADMFLAG_ROOT, "测试");
	
	g_aLastDoor = new ArrayList();
	g_aEndNavArea = new ArrayList();
	g_aStartNavArea = new ArrayList();
	g_aRescueVehicle = new ArrayList();

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

	if(g_bLateLoad)
	{
		OnMapStart();
		vInitPlugin();
	}
}

public void OnFinaleStart(const char[] output, int caller, int activator, float delay)
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
			int iAreaCount = g_aRescueVehicle.Length;
			for(int i; i < iAreaCount; i++)
			{
				if(bIsValidEntRef((iEntRef = g_aRescueVehicle.Get(i))))
					UnhookSingleEntityOutput(iEntRef, "OnStartTouch", OnStartTouch);
			}
		}
	}
}

public Action cmdWarpStart(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	int iAreaCount = g_aStartNavArea.Length;
	if(iAreaCount == 0)
	{
		ReplyToCommand(client, "未发现起点Nav区域");
		return Plugin_Handled;
	}

	float vRandom[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			vTeleportFix(i);

			L4D_FindRandomSpot(g_aStartNavArea.Get(GetRandomInt(0, iAreaCount - 1)), vRandom);
			TeleportEntity(i, vRandom, NULL_VECTOR, NULL_VECTOR);
		}
	}

	return Plugin_Handled;
}

public Action cmdWarpEnd(int client, int args)
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

public Action cmdFinale(int client, int args)
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

public Action cmdEst(int client, int args)
{
	ReplyToCommand(client, "过图触发器->%d 救援触发器->%d 起始Nav区域数量->%d 终点Nav区域数量->%d", g_iChangelevel ? EntRefToEntIndex(g_iChangelevel) : INVALID_ENT_REFERENCE, iFindRescueAreaTrigger(), g_aStartNavArea.Length, g_aEndNavArea.Length);
	return Plugin_Handled;
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
	g_iSafeArea = g_hSafeArea.IntValue;
	g_iSafeAreaTime = g_hSafeAreaTime.IntValue;
	g_iSafeAreaMinSurvivors = g_hSafeAreaMinSurvivors.IntValue;
}

public void OnMapStart()
{
	g_bFirstRound = true;

	PrecacheSound(SOUND_COUNTDOWN);

	if(L4D_IsFirstMapInScenario())
		g_iCurrentMap |= FIRST_MAP;

	if(L4D_IsMissionFinalMap())
		g_iCurrentMap |= FINAL_MAP;

	if(g_iCurrentMap & FIRST_MAP == 0 && g_iCurrentMap & FINAL_MAP == 0)
		g_iCurrentMap = MIDDLE_MAP;

	g_pTheCount = g_hGameData.GetAddress("TheCount");
	if(g_pTheCount == Address_Null)
		SetFailState("Failed to find address: TheCount");

	g_iTheCount = LoadFromAddress(g_pTheCount, NumberType_Int32);

	g_pTheNavAreas = g_hGameData.GetAddress("TheNavAreas");
	if(g_pTheNavAreas == Address_Null)
		SetFailState("Failed to find address: TheNavAreas");
}

public void OnMapEnd()
{
	vResetPlugin();
}

void vResetPlugin()
{
	delete g_hTimer;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bFirstRound = false;
	g_bHasTriggered = false;
	g_bIsSacrificeFinale = false;

	if(bIsValidEntRef(g_iChangelevel))
		UnhookSingleEntityOutput(g_iChangelevel, "OnStartTouch", OnStartTouch);

	int iEntRef;
	int iAreaCount = g_aRescueVehicle.Length;
	for(int i; i < iAreaCount; i++)
	{
		if(bIsValidEntRef((iEntRef = g_aRescueVehicle.Get(i))))
			UnhookSingleEntityOutput(iEntRef, "OnStartTouch", OnStartTouch);
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	vResetPlugin();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;

	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		vInitPlugin();
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		vInitPlugin();
	g_iPlayerSpawn = 1;
}

void vInitPlugin()
{
	vHookEndAreaEntity();
	vFindSafeRoomDoors();
	vFindTerrorNavAreas();

	#if DEBUG
	if(g_iCurrentMap == MIDDLE_MAP)
		PrintToChatAll("\x01当前地图是\x05中间地图");
	else
	{
		if(g_iCurrentMap & FIRST_MAP)
			PrintToChatAll("\x01当前地图是\x05起始地图");

		if(g_iCurrentMap & FINAL_MAP)
			PrintToChatAll("\x01当前地图是\x05结局地图");
	}
	#endif
}

void vFindTerrorNavAreas()
{
	g_aEndNavArea.Clear();
	g_aStartNavArea.Clear();
	g_aRescueVehicle.Clear();

	int iArea;
	int iFlags;
	float vOrigin[3];
	for(int i; i < g_iTheCount; i++)
	{
		if((iArea = LoadFromAddress(g_pTheNavAreas + view_as<Address>(4 * i), NumberType_Int32)) == 0)
			continue;

		iFlags = SDKCall(g_hSDK_Call_GetSpawnAttributes, iArea);
		if(g_iCurrentMap == MIDDLE_MAP)
		{
			if(iFlags & TERROR_NAV_CHECKPOINT)
			{
				if(SDKCall(g_hSDK_Call_IsAreaConnectedToNonCheckpointArea, iArea)/* || SDKCall(g_hSDK_Call_ScriptGetDoor, iArea)*/)
					continue;

				vGetAreaOrigin(iArea, vOrigin);
				if(!bIsDotInEndArea(vOrigin))
					g_aStartNavArea.Push(iArea);
				else
					g_aEndNavArea.Push(iArea);
			}
		}
		else
		{
			if(g_iCurrentMap & FIRST_MAP)
			{
				if(iFlags & TERROR_NAV_CHECKPOINT)
				{
					if(SDKCall(g_hSDK_Call_IsAreaConnectedToNonCheckpointArea, iArea))
						continue;
	
					if(iFlags & TERROR_NAV_MISSION_START)
						g_aStartNavArea.Push(iArea);
					else
					{
						vGetAreaOrigin(iArea, vOrigin);
						if(bIsDotInEndArea(vOrigin))
							g_aEndNavArea.Push(iArea);
						/*if(!SDKCall(g_hSDK_Call_ScriptGetDoor, iArea))
						{
							vGetAreaOrigin(iArea, vOrigin);
							if(bIsDotInEndArea(vOrigin))
								g_aEndNavArea.Push(iArea);
						}*/
					}
				}
			}

			if(g_iCurrentMap & FINAL_MAP)
			{
				if(iFlags & TERROR_NAV_CHECKPOINT)
				{
					if(!SDKCall(g_hSDK_Call_IsAreaConnectedToNonCheckpointArea, iArea)/* && !SDKCall(g_hSDK_Call_ScriptGetDoor, iArea)*/)
						g_aStartNavArea.Push(iArea);
				}

				if(iFlags & TERROR_NAV_RESCUE_VEHICLE)
					g_aEndNavArea.Push(iArea);
			}
		}
	}
}

void vGetAreaOrigin(int iArea, float vOrigin[3])
{
	float vMins[3], vMaxs[3];
	vMins[0] = view_as<float>(LoadFromAddress(view_as<Address>(iArea + 4), NumberType_Int32));
	vMins[1] = view_as<float>(LoadFromAddress(view_as<Address>(iArea + 8), NumberType_Int32));
	vMins[2] = view_as<float>(LoadFromAddress(view_as<Address>(iArea + 12), NumberType_Int32));
		
	vMaxs[0] = view_as<float>(LoadFromAddress(view_as<Address>(iArea + 16), NumberType_Int32));
	vMaxs[1] = view_as<float>(LoadFromAddress(view_as<Address>(iArea + 20), NumberType_Int32));
	vMaxs[2] = view_as<float>(LoadFromAddress(view_as<Address>(iArea + 24), NumberType_Int32));

	AddVectors(vMins, vMaxs, vOrigin);
	ScaleVector(vOrigin, 0.5);
}

void vHookEndAreaEntity()
{
	g_iChangelevel = 0;
	g_iTriggerFinale = 0;
	g_iRescueVehicle = 0;

	g_vMins = view_as<float>({0.0, 0.0, 0.0});
	g_vMaxs = view_as<float>({0.0, 0.0, 0.0});

	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		vGetEntityVectors(entity);
		g_iChangelevel = EntIndexToEntRef(entity);
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
		}
	}
}

//https://forums.alliedmods.net/showpost.php?p=2680639&postcount=3
void vGetEntityVectors(int entity)
{
	float vOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", g_vMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", g_vMaxs);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);

	g_vMins[0] -= 50.0;
	g_vMins[1] -= 50.0;
	g_vMins[2] -= 50.0;
	
	g_vMaxs[0] += 50.0;
	g_vMaxs[1] += 50.0;
	g_vMaxs[2] += 50.0;

	AddVectors(vOrigin, g_vMins, g_vMins);
	AddVectors(vOrigin, g_vMaxs, g_vMaxs);
}

int iFindRescueAreaTrigger()
{
	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "FindRescueAreaTrigger()");
	if(L4D2_GetVScriptOutput(sBuffer, sBuffer, sizeof(sBuffer)))
	{
		//([72] trigger_multiple: stadium_exit_leftt_escape_trigger)
		//(null : 0x(nil))
		int iLen = strlen(sBuffer);
		if(iLen < 6)
			return INVALID_ENT_REFERENCE;

		if(sBuffer[0] != '(' || sBuffer[1] != '[' || sBuffer[iLen - 1] != ')')
			return INVALID_ENT_REFERENCE;

		if(SplitString(sBuffer, "] ", sBuffer, sizeof(sBuffer)) == -1)
			return INVALID_ENT_REFERENCE;

		return StringToInt(sBuffer[2]);
	}

	return INVALID_ENT_REFERENCE;
}

void vFindSafeRoomDoors()
{
	g_aLastDoor.Clear();

	if(bIsValidEntRef(g_iChangelevel))
	{
		int entity = MaxClients + 1;
		while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
		{
			if(!bIsLastSafeDoor(entity))
				continue;

			g_aLastDoor.Push(EntIndexToEntRef(entity));
		}
	}
}

public void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if(g_bHasTriggered || g_bIsSacrificeFinale || activator < 1 || activator > MaxClients || !IsClientInGame(activator) || GetClientTeam(activator) != 2 || !IsPlayerAlive(activator))
		return;
	
	if(!bIsValidEntRef(g_iChangelevel) && !bIsValidEntRef(g_iRescueVehicle))
	{
		if(caller != iFindRescueAreaTrigger())
			return;

		vGetEntityVectors(caller);
		g_iRescueVehicle = EntIndexToEntRef(caller);

		int i;
		int iEntRef;
		int iAreaCount = g_aRescueVehicle.Length;
		for(; i < iAreaCount; i++)
		{
			if((iEntRef = g_aRescueVehicle.Get(i)) != g_iRescueVehicle && bIsValidEntRef(iEntRef))
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch", OnStartTouch);
		}

		i = 0;
		float vOrigin[3];
		iAreaCount = g_aEndNavArea.Length;
		while(i < iAreaCount)
		{
			vGetAreaOrigin(g_aEndNavArea.Get(i), vOrigin);
			if(!bIsDotInEndArea(vOrigin))
			{
				g_aEndNavArea.Erase(i);
				iAreaCount--;
			}
			else
				i++;
		}
	}

	if(iGetAliveSurvivorCount() < g_iSafeAreaMinSurvivors)
		return;

	if(g_iSafeAreaTime > 0)
	{
		g_bHasTriggered = true;
		g_iCountdown = g_iSafeAreaTime;

		delete g_hTimer;
		g_hTimer = CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT);
	}
}

int iGetAliveSurvivorCount()
{
	int iSurvivors;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && bIsClientInEndArea(i))
			iSurvivors++;
	}
	return iSurvivors;
}

public Action Timer_Countdown(Handle timer)
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
					if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsClientInEndArea(i))
						ForcePlayerSuicide(i);
				}
			}
		}
	}
}

void vCloseAndLockLastSafeDoor()
{
	int iEntRef;
	int iDoorCount = g_aLastDoor.Length;
	for(int i; i < iDoorCount; i++)
	{
		if(!bIsValidEntRef((iEntRef = g_aLastDoor.Get(i))))
			continue;
		
		SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 0);
		AcceptEntityInput(iEntRef, "Unlock");
		SetVariantFloat(1000.0);
		AcceptEntityInput(iEntRef, "SetSpeed");
		AcceptEntityInput(iEntRef, "Close");
		AcceptEntityInput(iEntRef, "forceclosed");
		AcceptEntityInput(iEntRef, "Lock");
		SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 1);
	}
}

public Action Timer_TeleportToCheckpoint(Handle timer)
{
	int iEntRef;
	int iDoorCount = g_aLastDoor.Length;
	for(int i; i < iDoorCount; i++)
	{
		if(!bIsValidEntRef((iEntRef = g_aLastDoor.Get(i))))
			continue;
		
		SetVariantFloat(200.0); //200 default l4d speed
		AcceptEntityInput(iEntRef, "SetSpeed");
		SetVariantString("OnUser1 !self:Unlock::5.0:-1");
		AcceptEntityInput(iEntRef, "AddOutput");
		AcceptEntityInput(iEntRef, "FireUser1");
	}

	vTeleportToCheckpoint();
}

void vTeleportToCheckpoint()
{
	int iAreaCount = g_aEndNavArea.Length;
	if(iAreaCount > 0)
	{
		vRemoveInfecteds();

		int i = 1;
		for(; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
			{
				SDKCall(g_hSDK_Call_CleanupPlayerState, i);
				ForcePlayerSuicide(i);
			}
		}

		float vRandom[3];
		for(i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsClientInEndArea(i))
			{
				vTeleportFix(i);

				L4D_FindRandomSpot(g_aEndNavArea.Get(GetRandomInt(0, iAreaCount - 1)), vRandom);
				TeleportEntity(i, vRandom, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

void vTeleportFix(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		vReviveFromIncap(client);

	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);

	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
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

void vReviveFromIncap(int client) 
{
	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "GetPlayerFromUserID(%d).ReviveFromIncap()", client);
	L4D2_GetVScriptOutput(sBuffer, sBuffer, sizeof(sBuffer));
}

bool bNoPlayerInEndArea()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && bIsClientInEndArea(i))
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

	g_hGameData = new GameData(GAMEDATA);
	if(g_hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "CTerrorPlayer::CleanupPlayerState") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::CleanupPlayerState");
	g_hSDK_Call_CleanupPlayerState = EndPrepSDKCall();
	if(g_hSDK_Call_CleanupPlayerState == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::CleanupPlayerState");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "TerrorNavArea::ScriptGetSpawnAttributes") == false)
		SetFailState("Failed to find signature: TerrorNavArea::ScriptGetSpawnAttributes");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_GetSpawnAttributes = EndPrepSDKCall();
	if(g_hSDK_Call_GetSpawnAttributes == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::ScriptGetSpawnAttributes");

	/*
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "TerrorNavArea::ScriptHasSpawnAttributes") == false)
		SetFailState("Failed to find signature: TerrorNavArea::ScriptHasSpawnAttributes");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_HasSpawnAttributes = EndPrepSDKCall();
	if(g_hSDK_Call_HasSpawnAttributes == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::ScriptHasSpawnAttributes");*/

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "IsAreaConnectedToNonCheckpointArea") == false)
		SetFailState("Failed to find signature: IsAreaConnectedToNonCheckpointArea");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_IsAreaConnectedToNonCheckpointArea = EndPrepSDKCall();
	if(g_hSDK_Call_IsAreaConnectedToNonCheckpointArea == null)
		SetFailState("Failed to create SDKCall: IsAreaConnectedToNonCheckpointArea");
	/*
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "TerrorNavArea::ScriptGetDoor") == false)
		SetFailState("Failed to find signature: TerrorNavArea::ScriptGetDoor");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_ScriptGetDoor = EndPrepSDKCall();
	if(g_hSDK_Call_ScriptGetDoor == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::ScriptGetDoor");*/

	StartPrepSDKCall(SDKCall_Entity);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "CBaseTrigger::IsTouching") == false)
		SetFailState("Failed to find signature: CBaseTrigger::IsTouching");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_IsTouching = EndPrepSDKCall();
	if(g_hSDK_Call_IsTouching == null)
		SetFailState("Failed to create SDKCall: CBaseTrigger::IsTouching");

	StartPrepSDKCall(SDKCall_Entity);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointDoor") == false)
		SetFailState("Failed to find signature: CPropDoorRotatingCheckpoint::IsCheckpointDoor");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_IsCheckpointDoor = EndPrepSDKCall();
	if(g_hSDK_Call_IsCheckpointDoor == null)
		SetFailState("Failed to create SDKCall: CPropDoorRotatingCheckpoint::IsCheckpointDoor");

	StartPrepSDKCall(SDKCall_Entity);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointExitDoor") == false)
		SetFailState("Failed to find signature: CPropDoorRotatingCheckpoint::IsCheckpointExitDoor");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_IsCheckpointExitDoor = EndPrepSDKCall();
	if(g_hSDK_Call_IsCheckpointExitDoor == null)
		SetFailState("Failed to create SDKCall: CPropDoorRotatingCheckpoint::IsCheckpointExitDoor");
}

bool bIsClientInEndArea(int client)
{
	float fFlow = L4D2Direct_GetFlowDistance(client);
	if(fFlow == 0.0 || fFlow == -9999.0)
		return false;

	if(g_iCurrentMap & FINAL_MAP)
		return bIsValidEntRef(g_iRescueVehicle) && SDKCall(g_hSDK_Call_IsTouching, g_iRescueVehicle, client);

	return bIsValidEntRef(g_iChangelevel) && SDKCall(g_hSDK_Call_IsTouching, g_iChangelevel, client);
}

bool bIsLastSafeDoor(int entity)
{
	if(!bIsValidDoorFlags(entity))
		return false;

	return SDKCall(g_hSDK_Call_IsCheckpointDoor, entity) && !SDKCall(g_hSDK_Call_IsCheckpointExitDoor, entity);
}

bool bIsValidDoorFlags(int entity)
{
	int flags = GetEntProp(entity, Prop_Data, "m_spawnflags");
	return flags & 8192 != 0 && flags & 32768 == 0;
}