#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define DEBUG						0

#define SAFE_ROOM					(1 << 0)
#define RESCUE_VEHICLE				(1 << 1)

// https://developer.valvesoftware.com/wiki/List_of_L4D_Series_Nav_Mesh_Attributes:zh-cn
#define NAV_MESH_PLAYERCLIP			262144
#define NAV_MESH_FLOW_BLOCKED		134217728
#define NAV_MESH_OUTSIDE_WORLD		268435456
#define TERROR_NAV_MISSION_START	128
#define TERROR_NAV_CHECKPOINT		2048
#define TERROR_NAV_RESCUE_VEHICLE	32768
#define TERROR_NAV_DOOR				262144
#define GAMEDATA					"safearea_teleport"
#define SOUND_COUNTDOWN 			"buttons/blip1.wav"

Handle
	g_hTimer,
	g_hSDKCleanupPlayerState,
	g_hSDKGetLastCheckpoint,
	g_hSDKCheckpointContainsArea,
	g_hSDKCheckpointGetLargestArea,
	g_hSDKFindRescueAreaTrigger,
	g_hSDKIsTouching,
	g_hSDKIsCheckpointDoor,
	g_hSDKIsCheckpointExitDoor;

Address
	g_pTheNavAreas;

ArrayList
	g_aLastDoor,
	g_aEndNavArea,
	g_aRescueVehicle;

ConVar
	g_hSafeAreaFlags,
	g_hSafeAreaType,
	g_hSafeAreaTime,
	g_hMinSurvivorPercent;

int
	g_iTheCount,
	g_iCountdown,
	g_iRoundStart, 
	g_iPlayerSpawn,
	g_iChangelevel,
	g_iRescueVehicle,
	g_iTriggerFinale,
	g_iSpawnAttributesOffset,
	g_iFlowDistanceOffset,
	g_iSafeAreaFlags,
	g_iSafeAreaType,
	g_iSafeAreaTime,
	g_iMinSurvivorPercent;

float
	g_vMins[3],
	g_vMaxs[3],
	g_vOrigin[3];

bool
	g_bFirstRound,
	g_bIsFinaleMap,
	g_bIsTriggered,
	g_bIsSacrificeFinale,
	g_bTranslation;

methodmap CNavArea
{
	public bool IsNull()
	{
		return view_as<Address>(this) == Address_Null;
	}

	/*public void Mins(float result[3])
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
	}*/

	public void FindRandomSpot(float result[3])
	{
		L4D_FindRandomSpot(view_as<int>(this), result);
		/*
		float vMins[3];
		float vMaxs[3];
		this.Mins(vMins);
		this.Maxs(vMaxs);

		result[0] = GetRandomFloat(vMins[0], vMaxs[0]);
		result[1] = GetRandomFloat(vMins[1], vMaxs[1]);
		result[2] = GetRandomFloat(vMins[2], vMaxs[2]);*/
	}
	
	property int BaseAttributes
	{
		public get()
		{
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(84), NumberType_Int32);
		}
		/*
		public set(int value)
		{
			StoreToAddress(view_as<Address>(this) + view_as<Address>(84), value, NumberType_Int32);
		}*/
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

	property float Flow
	{
		public get()
		{
			return view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iFlowDistanceOffset), NumberType_Int32));
		}
	}
};

// 如果签名失效，请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo = 
{
	name = 			"SafeArea Teleport",
	author = 		"sorallll",
	description = 	"",
	version = 		"1.1.5",
	url = 			"https://forums.alliedmods.net/showthread.php?p=2766514#post2766514"
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/safearea_teleport.phrases.txt");
	if(FileExists(sPath))
	{
		LoadTranslations("safearea_teleport.phrases");
		g_bTranslation = true;
	}

	vLoadGameData();

	g_aLastDoor = new ArrayList(2);
	g_aEndNavArea = new ArrayList();
	g_aRescueVehicle = new ArrayList();

	g_hSafeAreaFlags = CreateConVar("st_enable", "3", "Where is it enabled? (1=Safe Room, 2=Rescue Vehicle, 3=Both)", _, true, 0.0, true, 3.0);
	g_hSafeAreaType = CreateConVar("st_type", "1", "How to deal with players who have not entered the destination safe area (1=teleport, 2=slay)", _, true, 1.0, true, 2.0);
	g_hSafeAreaTime = CreateConVar("st_time", "30", "How many seconds to count down before processing (0=disable the function)", _, true, 0.0);
	g_hMinSurvivorPercent = CreateConVar("st_min_percent", "50", "What percentage of the survivors start the countdown when they reach the finish area", _, true, 0.0);
	
	g_hSafeAreaFlags.AddChangeHook(vAllowConVarChanged);
	g_hSafeAreaType.AddChangeHook(vConVarChanged);
	g_hSafeAreaTime.AddChangeHook(vConVarChanged);
	g_hMinSurvivorPercent.AddChangeHook(vConVarChanged);

	AutoExecConfig(true, "safearea_teleport");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	
	RegAdminCmd("sm_warpend", cmdWarpEnd, ADMFLAG_RCON, "Send all survivors to the destination safe area");
	RegAdminCmd("sm_st", cmdSt, ADMFLAG_ROOT, "Test");
	
	HookEntityOutput("trigger_finale", "FinaleStart", vOnFinaleStart);
}

void vOnFinaleStart(const char[] output, int caller, int activator, float delay)
{
	if(!g_bIsFinaleMap || g_iSafeAreaFlags & RESCUE_VEHICLE == 0)
		return;

	if(!bIsValidEntRef(g_iTriggerFinale)) //c5m5, c13m4
	{
		g_iTriggerFinale = EntIndexToEntRef(caller);
		g_bIsSacrificeFinale = !!GetEntProp(g_iTriggerFinale, Prop_Data, "m_bIsSacrificeFinale");

		if(g_bIsSacrificeFinale)
		{
			if(g_bFirstRound)
			{
				if(g_bTranslation)
					PrintToChatAll("\x05%t", "IsSacrificeFinale");
				else
					PrintToChatAll("\x05该地图是牺牲结局，已关闭当前功能");
			}

			int iEntRef;
			int iLength = g_aRescueVehicle.Length;
			for(int i; i < iLength; i++)
			{
				if(bIsValidEntRef((iEntRef = g_aRescueVehicle.Get(i))))
					UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  vOnStartTouch);
			}
		}
	}
}

Action cmdWarpEnd(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "Round has not yet started");
		return Plugin_Handled;
	}

	if(g_aEndNavArea.Length == 0)
	{
		ReplyToCommand(client, "No endpoint Nav area found");
		return Plugin_Handled;
	}

	vPerform(1);
	return Plugin_Handled;
}

Action cmdSt(int client, int args)
{
	ReplyToCommand(client, "ChangeLevel->%d RescueAreaTrigger->%d EndNavArea->%d", g_iChangelevel ? EntRefToEntIndex(g_iChangelevel) : -1, SDKCall(g_hSDKFindRescueAreaTrigger), g_aEndNavArea.Length);
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	vGetCvars();
	vIsAllowed();
}

void vAllowConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vIsAllowed()
{
	int iLast = g_iSafeAreaFlags;
	g_iSafeAreaFlags = g_hSafeAreaFlags.IntValue;

	if(iLast != g_iSafeAreaFlags)
	{
		if(bIsValidEntRef(g_iChangelevel))
			UnhookSingleEntityOutput(g_iChangelevel, "OnStartTouch",  vOnStartTouch);

		int i;
		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(; i < iLength; i++)
		{
			if((iEntRef = g_aRescueVehicle.Get(i)) != g_iRescueVehicle && bIsValidEntRef(iEntRef))
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  vOnStartTouch);
		}

		vInitPlugin();
	}
}

void vGetCvars()
{
	g_iSafeAreaType = g_hSafeAreaType.IntValue;
	g_iSafeAreaTime = g_hSafeAreaTime.IntValue;
	g_iMinSurvivorPercent = g_hMinSurvivorPercent.IntValue;
}

public void OnMapStart()
{
	vLateLoadGameData();
	PrecacheSound(SOUND_COUNTDOWN);

	g_bFirstRound = true;
	g_bIsFinaleMap = L4D_IsMissionFinalMap();
}

public void OnMapEnd()
{
	vResetPlugin();
	delete g_hTimer;
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

	vHookEndAreaEntity();
	vFindSafeRoomDoors();

	if(g_bFirstRound)
		vFindTerrorNavAreas();
}

void vFindTerrorNavAreas()
{
	if(g_bIsFinaleMap)
	{
		if(g_iSafeAreaFlags & RESCUE_VEHICLE == 0)
			return;
	}
	else
	{
		if(g_iSafeAreaFlags & SAFE_ROOM == 0)
			return;
	}

	g_aEndNavArea.Clear();

	CNavArea area;
	int iBase;
	int iSpawn;

	Address pLastCheckpoint;
	if(!g_bIsFinaleMap)
		pLastCheckpoint = SDKCall(g_hSDKGetLastCheckpoint, L4D_GetPointer(POINTER_NAVMESH));

	for(int i; i < g_iTheCount; i++)
	{
		if((area = view_as<CNavArea>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32))).IsNull() == true)
			continue;

		if(area.Flow == -9999.0)
			continue;
	
		iBase = area.BaseAttributes;
		if(iBase & NAV_MESH_PLAYERCLIP || iBase & NAV_MESH_FLOW_BLOCKED || iBase & NAV_MESH_OUTSIDE_WORLD)
			continue;

		iSpawn = area.SpawnAttributes;
		if(g_bIsFinaleMap)
		{
			if(iSpawn & TERROR_NAV_RESCUE_VEHICLE)
				g_aEndNavArea.Push(area);
		}
		else
		{
			if(iSpawn & TERROR_NAV_CHECKPOINT == 0 || iSpawn & TERROR_NAV_DOOR)
				continue;
			
			if(SDKCall(g_hSDKCheckpointContainsArea, pLastCheckpoint, area))
				g_aEndNavArea.Push(area);
		}
	}
}

void vHookEndAreaEntity()
{
	g_iChangelevel = 0;
	g_iTriggerFinale = 0;
	g_iRescueVehicle = 0;

	g_aRescueVehicle.Clear();

	g_vMins = NULL_VECTOR;
	g_vMaxs = NULL_VECTOR;
	g_vOrigin = NULL_VECTOR;

	if(!g_iSafeAreaFlags)
		return;

	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		if(g_iSafeAreaFlags & SAFE_ROOM)
		{
			vGetBrushEntityVector((g_iChangelevel = EntIndexToEntRef(entity)));
			HookSingleEntityOutput(entity, "OnStartTouch", vOnStartTouch);
		}
	}
	else if(g_iSafeAreaFlags & RESCUE_VEHICLE)
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
			{
				if(g_bTranslation)
					PrintToChatAll("\x05%t", "IsSacrificeFinale");
				else
					PrintToChatAll("\x05该地图是牺牲结局，已关闭当前功能");
			}
		}
		else
		{
			entity = MaxClients + 1;
			while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE)
			{
				if(GetEntProp(entity, Prop_Data, "m_iEntireTeam") != 2)
					continue;

				g_aRescueVehicle.Push(EntIndexToEntRef(entity));
				HookSingleEntityOutput(entity, "OnStartTouch",  vOnStartTouch);
			}

			if(g_aRescueVehicle.Length == 1)
				vGetBrushEntityVector((g_iRescueVehicle = g_aRescueVehicle.Get(0)));
		}
	}
}

void vGetBrushEntityVector(int entity)
{
	GetEntPropVector(entity, Prop_Send, "m_vecMins", g_vMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", g_vMaxs);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", g_vOrigin);
}

// https://forums.alliedmods.net/showpost.php?p=2680639&postcount=3
void vCalculateBoundingBoxSize(float vMins[3], float vMaxs[3], const float vOrigin[3])
{
	AddVectors(vOrigin, vMins, vMins);
	AddVectors(vOrigin, vMaxs, vMaxs);
}

void vFindSafeRoomDoors()
{
	g_aLastDoor.Clear();

	if(g_bIsFinaleMap || g_iSafeAreaFlags & SAFE_ROOM == 0)
		return;

	if(!bIsValidEntRef(g_iChangelevel))
		return;
	
	int iFlags;
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
	{
		iFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		if(iFlags & 8192 == 0 || iFlags & 32768 != 0)
			continue;
		
		if(!SDKCall(g_hSDKIsCheckpointDoor, entity))
			continue;

		if(SDKCall(g_hSDKIsCheckpointExitDoor, entity))
			continue;

		g_aLastDoor.Set(g_aLastDoor.Push(EntIndexToEntRef(entity)), GetEntPropFloat(entity, Prop_Data, "m_flSpeed"), 1);
	}
}

void  vOnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if(g_bIsTriggered || g_bIsSacrificeFinale || activator < 1 || activator > MaxClients || !IsClientInGame(activator) || GetClientTeam(activator) != 2 || !IsPlayerAlive(activator))
		return;
	
	static int iTemp;
	if(!g_iChangelevel && !g_iRescueVehicle)
	{
		if(caller != SDKCall(g_hSDKFindRescueAreaTrigger))
			return;

		vGetBrushEntityVector((g_iRescueVehicle = EntIndexToEntRef(caller)));

		iTemp = 0;
		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(; iTemp < iLength; iTemp++)
		{
			if((iEntRef = g_aRescueVehicle.Get(iTemp)) != g_iRescueVehicle && bIsValidEntRef(iEntRef))
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  vOnStartTouch);
		}

		float vMins[3];
		float vMaxs[3];
		float vOrigin[3];
		vMins = g_vMins;
		vMaxs = g_vMaxs;
		vOrigin = g_vOrigin;

		vMins[2] -= 20.0;
		vMaxs[2] -= 20.0;
		vCalculateBoundingBoxSize(vMins, vMaxs, vOrigin);

		iTemp = 0;
		iLength = g_aEndNavArea.Length;
		while(iTemp < iLength)
		{
			view_as<CNavArea>(g_aEndNavArea.Get(iTemp)).FindRandomSpot(vOrigin);
			if(!bIsPosInArea(vOrigin, vMins, vMaxs))
			{
				g_aEndNavArea.Erase(iTemp);
				iLength--;
			}
			else
				iTemp++;
		}
	}

	if(!g_aEndNavArea.Length)
	{
		g_bIsTriggered = true;
		return;
	}

	iTemp = iGetReachedSurvivorPercent();
	if(iTemp < g_iMinSurvivorPercent)
	{
		if(g_bTranslation)
			vPrintHintToSurvivor("%t", "SurvivorReached", iTemp, g_iMinSurvivorPercent);
		else
			vPrintHintToSurvivor("%d/100存活玩家已到达终点区域 %d/100开始倒计时", iTemp, g_iMinSurvivorPercent);

		return;
	}

	if(g_iSafeAreaTime > 0)
	{
		g_bIsTriggered = true;
		g_iCountdown = g_iSafeAreaTime;

		delete g_hTimer;
		g_hTimer = CreateTimer(1.0, tmrCountdown, _, TIMER_REPEAT);
	}
}

int iGetReachedSurvivorPercent()
{
	int iReached, iAliveSurvivors;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			iAliveSurvivors++;
			if(bIsPlayerInEndArea(i, false))
				iReached++;
		}	
	}
	return RoundToCeil(float(iReached) / float(iAliveSurvivors) * 100.0);
}

Action tmrCountdown(Handle timer)
{
	if(g_iCountdown > 0)
	{
		if(g_bTranslation)
		{
			switch(g_iSafeAreaType)
			{
				case 1:
					vPrintHintToSurvivor("%t", "Countdown_Send", g_iCountdown--);

				case 2:
					vPrintHintToSurvivor("%t", "Countdown_Slay", g_iCountdown--);
			}
		}
		else
			vPrintHintToSurvivor("%d 秒后%s所有未进入终点区域的玩家", g_iCountdown--, g_iSafeAreaType == 1 ? "传送" : "处死");

		vEmitSoundToSurvivor(SOUND_COUNTDOWN, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
	else if(g_iCountdown <= 0)
	{
		vPerform(g_iSafeAreaType);
		g_hTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

void vPrintHintToSurvivor(const char[] sMessage, any ...)
{
	static char sBuffer[254];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
		{
			SetGlobalTransTarget(i);
			VFormat(sBuffer, sizeof sBuffer, sMessage, 2);
			PrintHintText(i, "%s", sBuffer);
		}
	}
}

void vPerform(int iType)
{
	switch(iType)
	{
		case 1:
		{
			if(!g_bIsFinaleMap)
				vCloseAndLockLastSafeDoor();

			CreateTimer(0.5, tmrTeleportToCheckpoint, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		case 2:
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i, false))
					ForcePlayerSuicide(i);
			}
			/*if(bNoPlayerInEndArea())
			{
				if(g_bTranslation)
					vPrintHintToSurvivor("%t", "NoPlayerInEndArea");
				else
					vPrintHintToSurvivor("终点区域无玩家存在, 已改为自动传送");

				vPerform(1);
			}
			else
			{
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i, false))
						ForcePlayerSuicide(i);
				}
			}*/
		}
	}
}

void vCloseAndLockLastSafeDoor()
{
	int iLength = g_aLastDoor.Length;
	if(iLength > 0)
	{
		int i;
		int iEntRef;
		char sBuffer[64];
		while(i < iLength)
		{
			if(bIsValidEntRef((iEntRef = g_aLastDoor.Get(i))))
			{
				SetEntPropFloat(iEntRef, Prop_Data, "m_flSpeed", 1000.0);
				SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 0);
				AcceptEntityInput(iEntRef, "DisableCollision");
				AcceptEntityInput(iEntRef, "Unlock");
				AcceptEntityInput(iEntRef, "Close");
				AcceptEntityInput(iEntRef, "forceclosed");
				AcceptEntityInput(iEntRef, "Lock");
				SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 1);

				SetVariantString("OnUser1 !self:EnableCollision::1.0:-1");
				AcceptEntityInput(iEntRef, "AddOutput");
				SetVariantString("OnUser1 !self:Unlock::5.0:-1");
				AcceptEntityInput(iEntRef, "AddOutput");
				FloatToString(g_aLastDoor.Get(i, 1), sBuffer, sizeof sBuffer);
				Format(sBuffer, sizeof sBuffer, "OnUser1 !self:SetSpeed:%s:5.0:-1", sBuffer);
				SetVariantString(sBuffer);
				AcceptEntityInput(iEntRef, "AddOutput");
				AcceptEntityInput(iEntRef, "FireUser1");
			}
			i++;
		}
	}
}

Action tmrTeleportToCheckpoint(Handle timer)
{
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
		CNavArea CArea;
		float vPos[3];
		ArrayList aVerify = new ArrayList(2);

		if(!g_bIsFinaleMap)
			CArea = SDKCall(g_hSDKCheckpointGetLargestArea, SDKCall(g_hSDKGetLastCheckpoint, L4D_GetPointer(POINTER_NAVMESH)));
		
		for(i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
			{
				vTeleportFix(i);

				area = CArea ? CArea : g_aEndNavArea.Get(GetRandomInt(0, iLength - 1));
				area.FindRandomSpot(vPos);
				TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
				aVerify.Set(aVerify.Push(GetClientUserId(i)), area, 1);
			}
		}

		DataPack dPack = new DataPack();
		dPack.WriteCell(aVerify);
		CreateTimer(1.0, tmrTeleportVerify, dPack, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action tmrTeleportVerify(Handle timer, DataPack dPack)
{
	dPack.Reset();
	ArrayList aVerify = dPack.ReadCell();
	delete dPack;

	if(!g_bIsTriggered)
		return Plugin_Stop;

	ArrayList aSuccess = new ArrayList();

	int i = 1;
	int iTemp;
	float vPos[3];
	for(; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			iTemp = aVerify.FindValue(GetClientUserId(i), 0);
			if(iTemp != -1)
			{
				iTemp = g_aEndNavArea.FindValue(aVerify.Get(iTemp, 1));
				if(iTemp != -1)
				{
					if(bIsPlayerInEndArea(i))
						aSuccess.Push(g_aEndNavArea.Get(iTemp));
					else
						g_aEndNavArea.Erase(iTemp);
				}
			}
			else
			{
				GetClientAbsOrigin(i, vPos);
				iTemp = L4D_GetNearestNavArea(vPos);
				if(iTemp)
				{
					iTemp = g_aEndNavArea.FindValue(iTemp);
					if(iTemp != -1)
						g_aEndNavArea.Erase(iTemp);
				}
			}
		}
	}

	delete aVerify;

	int iLength = aSuccess.Length;
	if(iLength > 0)
	{
		for(i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
			{
				vTeleportFix(i);

				view_as<CNavArea>(aSuccess.Get(GetRandomInt(0, iLength - 1))).FindRandomSpot(vPos);
				TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	else
	{
		iLength = g_aEndNavArea.Length;
		if(iLength > 0)
		{
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
	}

	delete aSuccess;
	return Plugin_Continue;
}

void vTeleportFix(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		L4D_ReviveSurvivor(client);

	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);

	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

void vRemoveInfecteds()
{
	float vMins[3];
	float vMaxs[3];
	float vOrigin[3];
	vMins = g_vMins;
	vMaxs = g_vMaxs;
	vOrigin = g_vOrigin;

	vMins[0] -= 36.0;
	vMins[1] -= 36.0;
	vMins[2] -= 36.0;
	vMaxs[0] += 36.0;
	vMaxs[1] += 36.0;
	vMaxs[2] += 36.0;
	vCalculateBoundingBoxSize(vMins, vMaxs, vOrigin);

	char classname[9];
	int iMaxEnts = GetMaxEntities();
	for(int i = MaxClients + 1; i <= iMaxEnts; i++)
	{
		if(!IsValidEntity(i))
			continue;

		GetEntityClassname(i, classname, sizeof classname);
		if(strcmp(classname, "infected") != 0 && strcmp(classname, "witch") != 0)
			continue;
	
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", vOrigin);
		if(!bIsPosInArea(vOrigin, vMins, vMaxs))
			continue;

		RemoveEntity(i);
	}
}
/*
bool bNoPlayerInEndArea()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && bIsPlayerInEndArea(i, false))
			return false;
	}
	return true;
}
*/
bool bIsPosInArea(const float vPos[3], const float vMins[3], const float vMaxs[3])
{
	return vMins[0] < vPos[0] < vMaxs[0] && vMins[1] < vPos[1] < vMaxs[1] && vMins[2] < vPos[2] < vMaxs[2];
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
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iSpawnAttributesOffset = hGameData.GetOffset("TerrorNavArea::ScriptGetSpawnAttributes");
	if(g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: TerrorNavArea::ScriptGetSpawnAttributes");

	g_iFlowDistanceOffset = hGameData.GetOffset("CTerrorPlayer::GetFlowDistance::m_flow");
	if(g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::GetFlowDistance::m_flow");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::CleanupPlayerState") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::CleanupPlayerState");
	g_hSDKCleanupPlayerState = EndPrepSDKCall();
	if(g_hSDKCleanupPlayerState == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::CleanupPlayerState");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavMesh::GetLastCheckpoint") == false)
		SetFailState("Failed to find signature: TerrorNavMesh::GetLastCheckpoint");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetLastCheckpoint = EndPrepSDKCall();
	if(g_hSDKGetLastCheckpoint == null)
		SetFailState("Failed to create SDKCall: TerrorNavMesh::GetLastCheckpoint");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Checkpoint::ContainsArea") == false)
		SetFailState("Failed to find signature: Checkpoint::ContainsArea");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKCheckpointContainsArea = EndPrepSDKCall();
	if(g_hSDKCheckpointContainsArea == null)
		SetFailState("Failed to create SDKCall: Checkpoint::ContainsArea");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Checkpoint::GetLargestArea") == false)
		SetFailState("Failed to find signature: Checkpoint::GetLargestArea");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKCheckpointGetLargestArea = EndPrepSDKCall();
	if(g_hSDKCheckpointGetLargestArea == null)
		SetFailState("Failed to create SDKCall: Checkpoint::GetLargestArea");

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

	delete hGameData;
}

void vLateLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
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
		PrintToServer("The current number of Nav areas is 0, which may be some test maps");
		#endif
	}

	g_pTheNavAreas = view_as<Address>(LoadFromAddress(pTheCount + view_as<Address>(4), NumberType_Int32));
	if(g_pTheNavAreas == Address_Null)
		SetFailState("Failed to find address: TheNavAreas");

	delete hGameData;
}

bool bIsPlayerInEndArea(int client, bool bCheckArea = true)
{
	int area = L4D_GetLastKnownArea(client);
	if(!area)
		return false;

	if(bCheckArea && g_aEndNavArea.FindValue(area) == -1)
		return false;

	if(g_bIsFinaleMap)
		return bIsValidEntRef(g_iRescueVehicle) && SDKCall(g_hSDKIsTouching, g_iRescueVehicle, client);
	
	return bIsValidEntRef(g_iChangelevel) && SDKCall(g_hSDKIsTouching, g_iChangelevel, client);
}