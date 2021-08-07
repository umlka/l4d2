#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define	MAX_DOORS					4
#define TERROR_NAV_FINALE			64
#define TERROR_NAV_MISSION_START	128
#define TERROR_NAV_CHECKPOINT		2048
#define TERROR_NAV_RESCUE_VEHICLE	32768 
#define SOUND_COUNTDOWN 			"buttons/blip1.wav"
#define GAMEDATA					"safearea_teleport"

GameData
	g_hGameData;

Handle
	g_hTimer,
	//g_hSDK_Call_GetSpawnAttributes,
	g_hSDK_Call_HasSpawnAttributes;

Address
	g_pTheCount,
	g_pTheNavAreas;

ArrayList
	g_aEndNavArea,
	g_aStartNavArea;

ConVar
	g_hSafeArea,
	g_hSafeAreaTime,
	g_hRemoveInfecteds;

int
	g_iTheCount,
	g_iCountdown,
	g_iCurrentMap,
	g_iRoundStart, 
	g_iPlayerSpawn,
	g_iChangelevel,
	g_iRescueVehicle,
	g_iTriggerFinale,
	g_iLastSafeDoor[MAX_DOORS],
	g_iSafeArea,
	g_iSafeAreaTime;

float
	g_vMins[3],
	g_vMaxs[3],
	g_vScaleMins[3],
	g_vScaleMaxs[3];

bool
	g_bHasTriggered,
	g_bRemoveInfecteds,
	g_bIsInEndSafeArea[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = 			"End Area Detcet",
    author = 		"sorallll",
    description = 	"",
    version = 		"1.0.0",
    url = 			""
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hSafeArea = CreateConVar("end_safearea_method", "0", "如何处理未进入终点安全区域的玩家?(0=传送,1=处死)", _, true, 0.0, true, 1.0);
	g_hSafeAreaTime = CreateConVar("end_safearea_time", "30", "倒计时多久(0=关闭该功能)", _, true, 0.0);
	g_hRemoveInfecteds = CreateConVar("end_safearea_remove", "1", "传送前是否移除终点安全区域内的感染者", _, true, 0.0, true, 1.0);
	
	g_hSafeArea.AddChangeHook(vConVarChanged);
	g_hSafeAreaTime.AddChangeHook(vConVarChanged);
	g_hRemoveInfecteds.AddChangeHook(vConVarChanged);

	//AutoExecConfig(true, "end_safezone_detcet");
	//想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	RegAdminCmd("sm_warpstart", cmdWarpStart, ADMFLAG_RCON, "传送所有生还者到起点安全区域");
	RegAdminCmd("sm_warpend", cmdWarpEnd, ADMFLAG_RCON, "传送所有生还者到终点安全区域");
	RegAdminCmd("sm_finale", cmdFinale, ADMFLAG_RCON, "结局关卡强制过关");
	RegAdminCmd("sm_esd", cmdEsd, ADMFLAG_ROOT, "测试");
	
	g_aEndNavArea = new ArrayList(1);
	g_aStartNavArea = new ArrayList(1);

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);
}

public void OnFinaleStart(const char[] output, int caller, int activator, float delay)
{
	if(!bIsValidEntRef(g_iTriggerFinale)) //c5m5, c13m4
		g_iTriggerFinale = EntIndexToEntRef(caller);
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
		if(bIsAliveSurvivor(i))
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

	g_bHasTriggered = true;
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

public Action cmdEsd(int client, int args)
{
	ReplyToCommand(client, "起始Nav区域数量->%d 终点Nav区域数量->%d", g_aStartNavArea.Length, g_aEndNavArea.Length);
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
	g_bRemoveInfecteds = g_hRemoveInfecteds.BoolValue;
}

public void OnMapStart()
{
	PrecacheSound(SOUND_COUNTDOWN);

	if(L4D_IsFirstMapInScenario())
		g_iCurrentMap = 1;
	else if(L4D_IsMissionFinalMap())
		g_iCurrentMap = 2;
	else
		g_iCurrentMap = 0;

	g_pTheCount = g_hGameData.GetAddress("TheCount");
	if(g_pTheCount == Address_Null)
		SetFailState("Failed to find address: TheCount");

	g_iTheCount = LoadFromAddress(g_pTheCount, NumberType_Int32);

	g_pTheNavAreas = g_hGameData.GetAddress("TheNavAreas");
	if(g_pTheNavAreas == Address_Null)
		SetFailState("Failed to find address: TheNavAreas");

	vFindTargetNavAreas();
}

void vFindTargetNavAreas()
{
	g_aEndNavArea.Clear();
	g_aStartNavArea.Clear();

	float fMapHalfFlow = L4D2Direct_GetMapMaxFlowDistance() * 0.5;

	int iArea;
	float fFlow;
	for(int i; i < g_iTheCount; i++)
	{
		if((iArea = LoadFromAddress(g_pTheNavAreas + view_as<Address>(4 * i), NumberType_Int32)) == 0)
			continue;

		fFlow = L4D2Direct_GetTerrorNavAreaFlow(view_as<Address>(iArea));
		if(fFlow == 0.0 || fFlow == -9999.0)
			continue;

		switch(g_iCurrentMap)
		{
			case 0:
			{
				if(SDKCall(g_hSDK_Call_HasSpawnAttributes, iArea, TERROR_NAV_CHECKPOINT))
				{
					if(fFlow < fMapHalfFlow)
						g_aStartNavArea.Push(iArea);
					else
						g_aEndNavArea.Push(iArea);
				}
			}

			case 1:
			{
				if(SDKCall(g_hSDK_Call_HasSpawnAttributes, iArea, TERROR_NAV_CHECKPOINT))
				{
					if(SDKCall(g_hSDK_Call_HasSpawnAttributes, iArea, TERROR_NAV_MISSION_START))
					{
						if(fFlow < fMapHalfFlow)
							g_aStartNavArea.Push(iArea);
					}
					else
					{
						if(fFlow > fMapHalfFlow)
							g_aEndNavArea.Push(iArea);
					}
				}
			}

			case 2:
			{
				if(SDKCall(g_hSDK_Call_HasSpawnAttributes, iArea, TERROR_NAV_CHECKPOINT))
				{
					if(fFlow < fMapHalfFlow)
						g_aStartNavArea.Push(iArea);
				}
				else
				{
					if(SDKCall(g_hSDK_Call_HasSpawnAttributes, iArea, TERROR_NAV_RESCUE_VEHICLE))
					{
						if(fFlow > fMapHalfFlow)
							g_aEndNavArea.Push(iArea);
					}
				}
			}
		}
	}
}
/*
void vGetAreaOrigin(Address pArea, float vOrigin)
{
	float vMins[3], vMaxs[3];
	vMins[0] = view_as<float>(LoadFromAddress(pArea + view_as<Address>(4), NumberType_Int32));
	vMins[1] = view_as<float>(LoadFromAddress(pArea + view_as<Address>(8), NumberType_Int32));
	vMins[2] = view_as<float>(LoadFromAddress(pArea + view_as<Address>(12), NumberType_Int32));
		
	vMaxs[0] = view_as<float>(LoadFromAddress(pArea + view_as<Address>(16), NumberType_Int32));
	vMaxs[1] = view_as<float>(LoadFromAddress(pArea + view_as<Address>(20), NumberType_Int32));
	vMaxs[2] = view_as<float>(LoadFromAddress(pArea + view_as<Address>(24), NumberType_Int32));

	AddVectors(vMins, vMaxs, vOrigin);
	ScaleVector(vOrigin, 0.5);
}
*/

public void OnMapEnd()
{
	vResetPlugin();
}

void vResetPlugin()
{
	delete g_hTimer;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasTriggered = false;

	if(bIsValidEntRef(g_iChangelevel))
	{
		SDKUnhook(g_iChangelevel, SDKHook_EndTouch, Hook_OnEndTouch);
		SDKUnhook(g_iChangelevel, SDKHook_StartTouch, Hook_OnStartTouch);
	}

	if(bIsValidEntRef(g_iRescueVehicle))
	{
		SDKUnhook(g_iRescueVehicle, SDKHook_EndTouch, Hook_OnEndTouch);
		SDKUnhook(g_iRescueVehicle, SDKHook_StartTouch, Hook_OnStartTouch);
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
		InitPlugin();
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		InitPlugin();
	g_iPlayerSpawn = 1;
	
	g_bIsInEndSafeArea[GetClientOfUserId(event.GetInt("userid"))] = false;
}

void InitPlugin()
{
	vHookEndAreaEntity();
	vFindSafeRoomDoors();
}

void vHookEndAreaEntity()
{
	g_iChangelevel = 0;
	g_iTriggerFinale = 0;
	g_iRescueVehicle = 0;

	g_vMins = view_as<float>({0.0, 0.0, 0.0});
	g_vMaxs = view_as<float>({0.0, 0.0, 0.0});
	g_vScaleMins = view_as<float>({0.0, 0.0, 0.0});
	g_vScaleMaxs = view_as<float>({0.0, 0.0, 0.0});

	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		vGetEntityVectors(entity);
		g_iChangelevel = EntIndexToEntRef(entity);
		SDKHook(entity, SDKHook_EndTouch, Hook_OnEndTouch);
		SDKHook(entity, SDKHook_StartTouch, Hook_OnStartTouch);
	}
	else
	{
		g_iTriggerFinale = FindEntityByClassname(MaxClients + 1, "trigger_finale");
		if(g_iTriggerFinale != INVALID_ENT_REFERENCE)
			g_iTriggerFinale = EntIndexToEntRef(g_iTriggerFinale);
		
		entity = iFindRescueAreaTrigger();
		if(entity != INVALID_ENT_REFERENCE)
		{
			vGetEntityVectors(entity);
			g_iRescueVehicle = EntIndexToEntRef(entity);
			SDKHook(entity, SDKHook_EndTouch, Hook_OnEndTouch);
			SDKHook(entity, SDKHook_StartTouch, Hook_OnStartTouch);
		}
	}
}

//https://forums.alliedmods.net/showpost.php?p=2680639&postcount=3
void vGetEntityVectors(int entity)
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
	
	g_vScaleMins[0] = vMins[0] - 100.0;
	g_vScaleMins[1] = vMins[1] - 100.0;
	g_vScaleMins[2] = vMins[2] - 100.0;
	
	g_vScaleMaxs[0] = vMaxs[0] + 100.0;
	g_vScaleMaxs[1] = vMaxs[1] + 100.0;
	g_vScaleMaxs[2] = vMaxs[2] + 100.0;
	
	AddVectors(vOrigin, g_vScaleMins, g_vScaleMins);
	AddVectors(vOrigin, g_vScaleMaxs, g_vScaleMaxs);
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
	for(int i; i < MAX_DOORS; i++)
		g_iLastSafeDoor[i] = 0;

	if(g_iChangelevel)
	{
		float vOrigin[3];
		int entity = MaxClients + 1;
		while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
		{
			if(!bIsValidDoorFlags(entity))
				continue;

			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
			if(GetEntProp(entity, Prop_Send, "m_bLocked") == 1 && !bIsDotInScaleEndArea(vOrigin))
				continue;

			for(int i; i < MAX_DOORS; i++)
			{
				if(g_iLastSafeDoor[i] == 0)
				{
					g_iLastSafeDoor[i] = EntIndexToEntRef(entity);
					break;
				}
			}
		}
	}
}

bool bIsValidDoorFlags(int entity)
{
    int flags = GetEntProp(entity, Prop_Data, "m_spawnflags");
    return flags & 8192 != 0 && flags & 32768 == 0;
}

public Action Hook_OnEndTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients)
		return;

	g_bIsInEndSafeArea[other] = false;
}

public Action Hook_OnStartTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients)
		return;

	g_bIsInEndSafeArea[other] = true;

	if(g_bHasTriggered || !IsClientInGame(other) || GetClientTeam(other) != 2 || !IsPlayerAlive(other))
		return;

	g_bHasTriggered = true;
	if(g_iSafeAreaTime == 0)
		return;

	g_iCountdown = g_iSafeAreaTime;
	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT);
}

public Action Timer_Countdown(Handle timer)
{
	static const char
		sMethod[][] =
		{
			"传送",
			"处死",
		};

	if(g_iCountdown > 0)
	{
		vPrintHintToSurvivor("%d 秒后%s所有未进入终点区域的玩家", g_iCountdown--, sMethod[g_iSafeArea]);
		vEmitSoundToTeam2(SOUND_COUNTDOWN, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
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
			CreateTimer(0.3, Timer_TeleportToCheckpoint, _, TIMER_FLAG_NO_MAPCHANGE);
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
					if(bIsAliveSurvivor(i) && !g_bIsInEndSafeArea[i])
						ForcePlayerSuicide(i);
				}
			}
		}
	}
}

void vCloseAndLockLastSafeDoor()
{
	for(int i; i < MAX_DOORS; i++)
	{
		if(!bIsValidEntRef(g_iLastSafeDoor[i]) || !bIsValidDoorFlags(g_iLastSafeDoor[i]))
			continue;

		SetEntProp(g_iLastSafeDoor[i], Prop_Data, "m_hasUnlockSequence", 0);
		AcceptEntityInput(g_iLastSafeDoor[i], "Unlock");
		SetVariantFloat(1000.0);
		AcceptEntityInput(g_iLastSafeDoor[i], "SetSpeed");
		AcceptEntityInput(g_iLastSafeDoor[i], "Close");
		AcceptEntityInput(g_iLastSafeDoor[i], "forceclosed");
		AcceptEntityInput(g_iLastSafeDoor[i], "Lock");
		SetEntProp(g_iLastSafeDoor[i], Prop_Data, "m_hasUnlockSequence", 1);
	}
}

public Action Timer_TeleportToCheckpoint(Handle timer)
{
	for(int i; i < MAX_DOORS; i++)
	{
		if(!bIsValidEntRef(g_iLastSafeDoor[i]) || !bIsValidDoorFlags(g_iLastSafeDoor[i]))
			continue;

		SetVariantFloat(200.0); //200 default l4d speed
		AcceptEntityInput(g_iLastSafeDoor[i], "SetSpeed");
		SetVariantString("OnUser1 !self:Unlock::5.0:-1");
		AcceptEntityInput(g_iLastSafeDoor[i], "AddOutput");
		AcceptEntityInput(g_iLastSafeDoor[i], "FireUser1");
	}

	vTeleportToCheckpoint();
}

void vTeleportToCheckpoint()
{
	if(g_bRemoveInfecteds)
		vRemoveInfecteds();

	int iAreaCount = g_aEndNavArea.Length;
	if(iAreaCount > 0)
	{
		float vRandom[3];
		for(int i = 1; i <= MaxClients; i++)
		{
			if(bIsAliveSurvivor(i))
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
	vForceCrouch(client);

	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);

	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		vReviveFromIncap(client);
	else
	{
		int attacker = iGetInfectedAttacker(client);
		if(attacker > 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker))
		{
			SetEntProp(attacker, Prop_Send, "m_fFlags", GetEntProp(attacker, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			ForcePlayerSuicide(attacker);
		}
	}
}

void vForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1); // force crouch pose to allow respawn in transport / duct ...
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

int iGetInfectedAttacker(int client)
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

void vRemoveInfecteds()
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
	
	char sClassName[9];
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
			if(bIsDotInScaleEndArea(vOrigin))
				RemoveEntity(i);
		}
	}
}

bool bIsAliveSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
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
		if(g_bIsInEndSafeArea[i] && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			return false;
	}
	return true;
}

bool bIsDotInScaleEndArea(const float vDot[3])
{
	return g_vScaleMins[0] < vDot[0] < g_vScaleMaxs[0] && g_vScaleMins[1] < vDot[1] < g_vScaleMaxs[1] && g_vScaleMins[2] < vDot[2] < g_vScaleMaxs[2];
}

bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}

void vEmitSoundToTeam2(const char[] sample,
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
	/*
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "TerrorNavArea::ScriptGetSpawnAttributes") == false)
		SetFailState("Failed to find signature: TerrorNavArea::ScriptGetSpawnAttributes");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_GetSpawnAttributes = EndPrepSDKCall();
	if(g_hSDK_Call_GetSpawnAttributes == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::ScriptGetSpawnAttributes");
	*/
	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(g_hGameData, SDKConf_Signature, "TerrorNavArea::ScriptHasSpawnAttributes") == false)
		SetFailState("Failed to find signature: TerrorNavArea::ScriptHasSpawnAttributes");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_HasSpawnAttributes = EndPrepSDKCall();
	if(g_hSDK_Call_HasSpawnAttributes == null)
		SetFailState("Failed to create SDKCall: TerrorNavArea::ScriptHasSpawnAttributes");
	//delete g_hGameData;
}