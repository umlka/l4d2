#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define DEBUG						0
#define CVAR_FLAGS					FCVAR_NOTIFY

#define SAFE_ROOM					(1 << 0)
#define RESCUE_VEHICLE				(1 << 1)

// https://developer.valvesoftware.com/wiki/List_of_L4D_Series_Nav_Mesh_Attributes:zh-cn
#define NAV_MESH_OUTSIDE_WORLD		268435456
#define TERROR_NAV_CHECKPOINT		2048
#define TERROR_NAV_RESCUE_VEHICLE	32768
#define TERROR_NAV_DOOR				262144
#define GAMEDATA					"safearea_teleport"
#define SOUND_COUNTDOWN 			"buttons/blip1.wav"

Handle
	g_hTimer,
	g_hSDK_CTerrorPlayer_CleanupPlayerState,
	g_hSDK_TerrorNavMesh_GetLastCheckpoint,
	g_hSDK_Checkpoint_ContainsArea,
	g_hSDK_Checkpoint_GetLargestArea,
	g_hSDK_CDirectorChallengeMode_FindRescueAreaTrigger,
	g_hSDK_CBaseTrigger_IsTouching,
	g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointDoor,
	g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointExitDoor;

Address
	g_pTheCount;

ArrayList
	g_aLastDoor,
	g_aEndNavArea,
	g_aRescueVehicle;

ConVar
	g_hCvarAllow,
	g_hCvarModes,
	g_hCvarModesOff,
	g_hCvarModesTog,
	g_hCvarMPGameMode,
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
	g_iOff_m_iMissionWipes,
	g_iOff_m_flow,
	g_iOff_m_attributeFlags,
	g_iOff_m_spawnAttributes,
	g_iSafeAreaFlags,
	g_iSafeAreaType,
	g_iSafeAreaTime,
	g_iMinSurvivorPercent;

float
	g_vMins[3],
	g_vMaxs[3],
	g_vOrigin[3];

bool
	g_bLateLoad,
	g_bMapStarted,
	g_bCvarAllow,
	g_bTranslation,
	g_bIsFinaleMap,
	g_bIsTriggered,
	g_bIsSacrificeFinale;

methodmap TerrorNavArea
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

	property float m_flow
	{
		public get()
		{
			return view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_flow), NumberType_Int32));
		}
	}
	
	property int m_attributeFlags
	{
		public get()
		{
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_attributeFlags), NumberType_Int32);
		}
		/*
		public set(int value)
		{
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_attributeFlags), value, NumberType_Int32);
		}*/
	}

	property int m_spawnAttributes
	{
		public get()
		{
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_spawnAttributes), NumberType_Int32);
		}
		/*
		public set(int value)
		{
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_spawnAttributes), value, NumberType_Int32);
		}*/
	}
};

// 如果签名失效，请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo = 
{
	name = 			"SafeArea Teleport",
	author = 		"sorallll",
	description = 	"",
	version = 		"1.1.9",
	url = 			"https://forums.alliedmods.net/showthread.php?p=2766514#post2766514"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vInitData();

	g_aLastDoor = new ArrayList(2);
	g_aEndNavArea = new ArrayList();
	g_aRescueVehicle = new ArrayList();

	g_hCvarAllow =			CreateConVar("st_allow",		"1",	"0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hCvarModes =			CreateConVar("st_modes",		"",		"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hCvarModesOff =		CreateConVar("st_modes_off",	"",		"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS);
	g_hCvarModesTog =		CreateConVar("st_modes_tog",	"0",	"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS);

	g_hSafeAreaFlags =		CreateConVar("st_enable",		"3",	"Where is it enabled? (1=Safe Room, 2=Rescue Vehicle, 3=Both)", CVAR_FLAGS);
	g_hSafeAreaType =		CreateConVar("st_type",			"1",	"How to deal with players who have not entered the destination safe area (1=teleport, 2=slay)", CVAR_FLAGS);
	g_hSafeAreaTime =		CreateConVar("st_time",			"30",	"How many seconds to count down before processing", CVAR_FLAGS);
	g_hMinSurvivorPercent =	CreateConVar("st_min_percent",	"50",	"What percentage of the survivors start the countdown when they reach the finish area", CVAR_FLAGS);
	
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(vAllowConVarChanged);
	g_hCvarAllow.AddChangeHook(vAllowConVarChanged);
	g_hCvarModes.AddChangeHook(vAllowConVarChanged);
	g_hCvarModesOff.AddChangeHook(vAllowConVarChanged);
	g_hCvarModesTog.AddChangeHook(vAllowConVarChanged);

	g_hSafeAreaFlags.AddChangeHook(vGeneralConVarChanged);
	g_hSafeAreaType.AddChangeHook(vGeneralConVarChanged);
	g_hSafeAreaTime.AddChangeHook(vGeneralConVarChanged);
	g_hMinSurvivorPercent.AddChangeHook(vGeneralConVarChanged);

	AutoExecConfig(true, "safearea_teleport");

	RegAdminCmd("sm_warpend", cmdWarpEnd, ADMFLAG_RCON, "Send all survivors to the destination safe area");
	RegAdminCmd("sm_st", cmdSt, ADMFLAG_ROOT, "Test");
	
	HookEntityOutput("trigger_finale", "FinaleStart", vOnFinaleStart);

	if(g_bLateLoad)
		g_bIsFinaleMap = L4D_IsMissionFinalMap();
}

void vOnFinaleStart(const char[] output, int caller, int activator, float delay)
{
	if(!g_bIsFinaleMap || g_iSafeAreaFlags & RESCUE_VEHICLE == 0 || bIsValidEntRef(g_iTriggerFinale))
		return;

	g_iTriggerFinale = EntIndexToEntRef(caller);
	g_bIsSacrificeFinale = !!GetEntProp(g_iTriggerFinale, Prop_Data, "m_bIsSacrificeFinale");

	if(g_bIsSacrificeFinale)
	{
		if(!iGetMissionWipes())
		{
			if(g_bTranslation)
				PrintToChatAll("\x05%t", "IsSacrificeFinale");
			else
				PrintToChatAll("\x05该地图是牺牲结局, 已关闭当前功能");
		}

		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(int i; i < iLength; i++)
		{
			if(EntRefToEntIndex((iEntRef = g_aRescueVehicle.Get(i))) != INVALID_ENT_REFERENCE)
			{
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  OnStartTouch);
				UnhookSingleEntityOutput(iEntRef, "OnEndTouch", OnEndTouch);
			}
		}
	}
}

Action cmdWarpEnd(int client, int args)
{
	if(!g_aEndNavArea.Length)
	{
		ReplyToCommand(client, "No endpoint nav area found");
		return Plugin_Handled;
	}

	vPerform(1);
	return Plugin_Handled;
}

Action cmdSt(int client, int args)
{
	ReplyToCommand(client, "ChangeLevel->%d RescueAreaTrigger->%d EndNavArea->%d", g_iChangelevel ? EntRefToEntIndex(g_iChangelevel) : -1, SDKCall(g_hSDK_CDirectorChallengeMode_FindRescueAreaTrigger), g_aEndNavArea.Length);
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	vIsAllowed();
}

void vAllowConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vGeneralConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	int iLast = g_iSafeAreaFlags;
	g_iSafeAreaFlags = g_hSafeAreaFlags.IntValue;
	g_iSafeAreaType = g_hSafeAreaType.IntValue;
	g_iSafeAreaTime = g_hSafeAreaTime.IntValue;
	g_iMinSurvivorPercent = g_hMinSurvivorPercent.IntValue;

	if(iLast != g_iSafeAreaFlags)
	{
		if(bIsValidEntRef(g_iChangelevel))
		{
			UnhookSingleEntityOutput(g_iChangelevel, "OnStartTouch",  OnStartTouch);
			UnhookSingleEntityOutput(g_iChangelevel, "OnEndTouch", OnEndTouch);
		}

		int i;
		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(; i < iLength; i++)
		{
			if((iEntRef = g_aRescueVehicle.Get(i)) != g_iRescueVehicle && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE)
			{
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  OnStartTouch);
				UnhookSingleEntityOutput(iEntRef, "OnEndTouch", OnEndTouch);
			}
		}

		vInitPlugin();
	}
}

// redit to Silvers
void vIsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = bIsAllowedGameMode();
	vGetCvars();

	if(g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true)
	{
		g_bCvarAllow = true;

		vInitPlugin();

		HookEvent("round_end", 				Event_RoundEnd, 	EventHookMode_PostNoCopy);
		HookEvent("map_transition", 		Event_RoundEnd, 	EventHookMode_PostNoCopy);
		HookEvent("finale_vehicle_leaving", Event_RoundEnd, 	EventHookMode_PostNoCopy);
		HookEvent("round_start", 			Event_RoundStart, 	EventHookMode_PostNoCopy);
		HookEvent("player_spawn", 			Event_PlayerSpawn, 	EventHookMode_PostNoCopy);
	}
	else if(g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false))
	{
		g_bCvarAllow = false;

		UnhookEvent("round_end", 				Event_RoundEnd, 	EventHookMode_PostNoCopy);
		UnhookEvent("map_transition", 			Event_RoundEnd, 	EventHookMode_PostNoCopy);
		UnhookEvent("finale_vehicle_leaving",	Event_RoundEnd, 	EventHookMode_PostNoCopy);
		UnhookEvent("round_start", 				Event_RoundStart, 	EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", 			Event_PlayerSpawn, 	EventHookMode_PostNoCopy);

		vResetPlugin();
		delete g_hTimer;

		if(bIsValidEntRef(g_iChangelevel))
		{
			UnhookSingleEntityOutput(g_iChangelevel, "OnStartTouch",  OnStartTouch);
			UnhookSingleEntityOutput(g_iChangelevel, "OnEndTouch", OnEndTouch);
		}

		int i;
		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(; i < iLength; i++)
		{
			if((iEntRef = g_aRescueVehicle.Get(i)) != g_iRescueVehicle && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE)
			{
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  OnStartTouch);
				UnhookSingleEntityOutput(iEntRef, "OnEndTouch", OnEndTouch);
			}
		}
	}
}

int g_iCurrentMode;
public void L4D_OnGameModeChange(int gamemode)
{
	g_iCurrentMode = gamemode;
}

bool bIsAllowedGameMode()
{
	if(!g_hCvarMPGameMode)
		return false;

	if(!g_iCurrentMode)
		g_iCurrentMode = L4D_GetGameModeType();

	if(!g_bMapStarted)
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if(iCvarModesTog && !(iCvarModesTog & g_iCurrentMode))
		return false;

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof sGameMode);
	Format(sGameMode, sizeof sGameMode, ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof sGameModes);
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof sGameModes, ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof sGameModes);
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof sGameModes, ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

public void OnMapStart()
{
	g_bMapStarted = true;
	PrecacheSound(SOUND_COUNTDOWN);
	g_bIsFinaleMap = L4D_IsMissionFinalMap();
}

public void OnMapEnd()
{
	vResetPlugin();
	delete g_hTimer;
	g_iTheCount = 0;
	g_aEndNavArea.Clear();
	g_bMapStarted = false;
}

void vResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
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
	if(bGetNavAreaCount() && bFindEndNavAreas())
	{
		vHookEndAreaEntity();
		vFindSafeRoomDoors();
	}
}

bool bFindEndNavAreas()
{
	if(g_aEndNavArea.Length)
		return true;

	if(g_bIsFinaleMap)
	{
		if(g_iSafeAreaFlags & RESCUE_VEHICLE == 0)
			return false;
	}
	else
	{
		if(g_iSafeAreaFlags & SAFE_ROOM == 0)
			return false;
	}

	int iSpawnAttributes;
	TerrorNavArea navarea;

	Address pLastCheckpoint;
	if(!g_bIsFinaleMap)
		pLastCheckpoint = SDKCall(g_hSDK_TerrorNavMesh_GetLastCheckpoint, L4D_GetPointer(POINTER_NAVMESH));

	Address pTheNavAreas = view_as<Address>(LoadFromAddress(g_pTheCount + view_as<Address>(4), NumberType_Int32));
	if(!pTheNavAreas)
		SetFailState("Failed to find address: TheNavAreas");

	for(int i; i < g_iTheCount; i++)
	{
		if((navarea = view_as<TerrorNavArea>(LoadFromAddress(pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32))).IsNull())
			continue;

		if(navarea.m_flow == -9999.0)
			continue;
	
		if(navarea.m_attributeFlags & NAV_MESH_OUTSIDE_WORLD)
			continue;

		iSpawnAttributes = navarea.m_spawnAttributes;
		if(g_bIsFinaleMap)
		{
			if(iSpawnAttributes & TERROR_NAV_RESCUE_VEHICLE)
				g_aEndNavArea.Push(navarea);
		}
		else
		{
			if(iSpawnAttributes & TERROR_NAV_CHECKPOINT == 0 || iSpawnAttributes & TERROR_NAV_DOOR)
				continue;
			
			if(SDKCall(g_hSDK_Checkpoint_ContainsArea, pLastCheckpoint, navarea))
				g_aEndNavArea.Push(navarea);
		}
	}

	return g_aEndNavArea.Length > 0;
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
			HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch);
			HookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch);
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
			if(!iGetMissionWipes())
			{
				if(g_bTranslation)
					PrintToChatAll("\x05%t", "IsSacrificeFinale");
				else
					PrintToChatAll("\x05该地图是牺牲结局, 已关闭当前功能");
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
				HookSingleEntityOutput(entity, "OnStartTouch",  OnStartTouch);
				HookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch);
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
		
		if(!SDKCall(g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointDoor, entity))
			continue;

		if(SDKCall(g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointExitDoor, entity))
			continue;

		g_aLastDoor.Set(g_aLastDoor.Push(EntIndexToEntRef(entity)), GetEntPropFloat(entity, Prop_Data, "m_flSpeed"), 1);
	}
}

void  OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if(g_bIsTriggered || g_bIsSacrificeFinale || !g_iSafeAreaTime || activator < 1 || activator > MaxClients || !IsClientInGame(activator) || GetClientTeam(activator) != 2 || !IsPlayerAlive(activator))
		return;
	
	static int iParam;
	if(!g_iChangelevel && !g_iRescueVehicle)
	{
		if(caller != SDKCall(g_hSDK_CDirectorChallengeMode_FindRescueAreaTrigger))
			return;

		vGetBrushEntityVector((g_iRescueVehicle = EntIndexToEntRef(caller)));

		iParam = 0;
		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(; iParam < iLength; iParam++)
		{
			if((iEntRef = g_aRescueVehicle.Get(iParam)) != g_iRescueVehicle && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE)
			{
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  OnStartTouch);
				UnhookSingleEntityOutput(iEntRef, "OnEndTouch", OnEndTouch);
			}
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

		iParam = 0;
		iLength = g_aEndNavArea.Length;
		while(iParam < iLength)
		{
			view_as<TerrorNavArea>(g_aEndNavArea.Get(iParam)).Center(vOrigin);
			if(!bIsPosInArea(vOrigin, vMins, vMaxs))
			{
				g_aEndNavArea.Erase(iParam);
				iLength--;
			}
			else
				iParam++;
		}
	}

	if(!g_aEndNavArea.Length)
	{
		g_bIsTriggered = true;
		return;
	}

	iParam = 0;
	int iReached;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			iParam++;
			if(bIsPlayerInEndArea(i, false))
				iReached++;
		}	
	}

	iParam = RoundToCeil(g_iMinSurvivorPercent / 100.0 * iParam);
	if(iReached < iParam)
	{
		if(g_bTranslation)
			vPrintHintToSurvivor("%t", "SurvivorReached", iReached, iParam);
		else
			vPrintHintToSurvivor("%d名生还者已到达终点区域(需要%d名)", iReached, iParam);
		return;
	}

	g_bIsTriggered = true;
	g_iCountdown = g_iSafeAreaTime;

	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, tmrCountdown, _, TIMER_REPEAT);
}

void OnEndTouch(const char[] output, int caller, int activator, float delay)
{
	if(g_bIsTriggered || g_bIsSacrificeFinale || !g_iSafeAreaTime || activator < 1 || activator > MaxClients || !IsClientInGame(activator) || GetClientTeam(activator) != 2)
		return;
	
	static int iParam;
	if(!g_iChangelevel && !g_iRescueVehicle)
	{
		if(caller != SDKCall(g_hSDK_CDirectorChallengeMode_FindRescueAreaTrigger))
			return;

		vGetBrushEntityVector((g_iRescueVehicle = EntIndexToEntRef(caller)));

		iParam = 0;
		int iEntRef;
		int iLength = g_aRescueVehicle.Length;
		for(; iParam < iLength; iParam++)
		{
			if((iEntRef = g_aRescueVehicle.Get(iParam)) != g_iRescueVehicle && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE)
			{
				UnhookSingleEntityOutput(iEntRef, "OnStartTouch",  OnStartTouch);
				UnhookSingleEntityOutput(iEntRef, "OnEndTouch", OnEndTouch);
			}
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

		iParam = 0;
		iLength = g_aEndNavArea.Length;
		while(iParam < iLength)
		{
			view_as<TerrorNavArea>(g_aEndNavArea.Get(iParam)).Center(vOrigin);
			if(!bIsPosInArea(vOrigin, vMins, vMaxs))
			{
				g_aEndNavArea.Erase(iParam);
				iLength--;
			}
			else
				iParam++;
		}
	}

	if(!g_aEndNavArea.Length)
	{
		g_bIsTriggered = true;
		return;
	}

	iParam = 0;
	int iReached;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			iParam++;
			if(bIsPlayerInEndArea(i, false))
				iReached++;
		}	
	}

	iParam = RoundToCeil(g_iMinSurvivorPercent / 100.0 * iParam);
	if(iReached < iParam)
	{
		if(g_bTranslation)
			vPrintHintToSurvivor("%t", "SurvivorReached", iReached, iParam);
		else
			vPrintHintToSurvivor("%d名生还者已到达终点区域(需要%d名)", iReached, iParam);
		return;
	}

	g_bIsTriggered = true;
	g_iCountdown = g_iSafeAreaTime;

	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, tmrCountdown, _, TIMER_REPEAT);
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
			vPrintHintToSurvivor("%d 秒后%s未进入终点区域的生还者", g_iCountdown--, g_iSafeAreaType == 1 ? "传送" : "处死");

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
			if(EntRefToEntIndex((iEntRef = g_aLastDoor.Get(i))) != INVALID_ENT_REFERENCE)
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
				SDKCall(g_hSDK_CTerrorPlayer_CleanupPlayerState, i);
				ForcePlayerSuicide(i);
			}
		}

		float vPos[3];
		TerrorNavArea largest;

		if(!g_bIsFinaleMap)
			largest = SDKCall(g_hSDK_Checkpoint_GetLargestArea, SDKCall(g_hSDK_TerrorNavMesh_GetLastCheckpoint, L4D_GetPointer(POINTER_NAVMESH)));

		if(largest)
		{
			for(i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
				{
					vTeleportFix(i);

					largest.FindRandomSpot(vPos);
					TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
				}
			}
		}
		else
		{
			for(i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPlayerInEndArea(i))
				{
					vTeleportFix(i);

					view_as<TerrorNavArea>(g_aEndNavArea.Get(GetRandomInt(0, iLength - 1))).FindRandomSpot(vPos);
					TeleportEntity(i, vPos, NULL_VECTOR, NULL_VECTOR);
				}
			}
		}
	}
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

void vInitData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/safearea_teleport.phrases.txt");
	if(FileExists(sPath))
	{
		LoadTranslations("safearea_teleport.phrases");
		g_bTranslation = true;
	}

	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pTheCount = hGameData.GetAddress("TheCount");
	if(!g_pTheCount)
		SetFailState("Failed to find address: TheCount");

	g_iOff_m_iMissionWipes = hGameData.GetOffset("m_iMissionWipes");
	if(g_iOff_m_iMissionWipes== -1)
		SetFailState("Failed to find offset: m_iMissionWipes");

	g_iOff_m_flow = hGameData.GetOffset("CTerrorPlayer::GetFlowDistance::m_flow");
	if(g_iOff_m_flow == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::GetFlowDistance::m_flow");

	g_iOff_m_attributeFlags = hGameData.GetOffset("CNavArea::InheritAttributes::m_attributeFlags");
	if(g_iOff_m_attributeFlags == -1)
		SetFailState("Failed to find offset: CNavArea::InheritAttributes::m_attributeFlags");

	g_iOff_m_spawnAttributes = hGameData.GetOffset("TerrorNavArea::SetSpawnAttributes::m_spawnAttributes");
	if(g_iOff_m_spawnAttributes == -1)
		SetFailState("Failed to find offset: TerrorNavArea::SetSpawnAttributes::m_spawnAttributes");

	StartPrepSDKCall(SDKCall_Player);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::CleanupPlayerState"))
		SetFailState("Failed to find signature: CTerrorPlayer::CleanupPlayerState");
	g_hSDK_CTerrorPlayer_CleanupPlayerState = EndPrepSDKCall();
	if(!g_hSDK_CTerrorPlayer_CleanupPlayerState)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::CleanupPlayerState");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavMesh::GetLastCheckpoint"))
		SetFailState("Failed to find signature: TerrorNavMesh::GetLastCheckpoint");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_TerrorNavMesh_GetLastCheckpoint = EndPrepSDKCall();
	if(!g_hSDK_TerrorNavMesh_GetLastCheckpoint)
		SetFailState("Failed to create SDKCall: TerrorNavMesh::GetLastCheckpoint");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Checkpoint::ContainsArea"))
		SetFailState("Failed to find signature: Checkpoint::ContainsArea");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Checkpoint_ContainsArea = EndPrepSDKCall();
	if(!g_hSDK_Checkpoint_ContainsArea)
		SetFailState("Failed to create SDKCall: Checkpoint::ContainsArea");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Checkpoint::GetLargestArea"))
		SetFailState("Failed to find signature: Checkpoint::GetLargestArea");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Checkpoint_GetLargestArea = EndPrepSDKCall();
	if(!g_hSDK_Checkpoint_GetLargestArea)
		SetFailState("Failed to create SDKCall: Checkpoint::GetLargestArea");

	StartPrepSDKCall(SDKCall_GameRules);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirectorChallengeMode::FindRescueAreaTrigger"))
		SetFailState("Failed to find signature: CDirectorChallengeMode::FindRescueAreaTrigger");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_CDirectorChallengeMode_FindRescueAreaTrigger = EndPrepSDKCall();
	if(!g_hSDK_CDirectorChallengeMode_FindRescueAreaTrigger)
		SetFailState("Failed to create SDKCall: CDirectorChallengeMode::FindRescueAreaTrigger");

	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CBaseTrigger::IsTouching"))
		SetFailState("Failed to find signature: CBaseTrigger::IsTouching");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CBaseTrigger_IsTouching = EndPrepSDKCall();
	if(!g_hSDK_CBaseTrigger_IsTouching)
		SetFailState("Failed to create SDKCall: CBaseTrigger::IsTouching");

	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointDoor"))
		SetFailState("Failed to find offset: CPropDoorRotatingCheckpoint::IsCheckpointDoor");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointDoor = EndPrepSDKCall();
	if(!g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointDoor)
		SetFailState("Failed to create SDKCall: CPropDoorRotatingCheckpoint::IsCheckpointDoor");

	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CPropDoorRotatingCheckpoint::IsCheckpointExitDoor"))
		SetFailState("Failed to find offset: CPropDoorRotatingCheckpoint::IsCheckpointExitDoor");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointExitDoor = EndPrepSDKCall();
	if(!g_hSDK_CPropDoorRotatingCheckpoint_IsCheckpointExitDoor)
		SetFailState("Failed to create SDKCall: CPropDoorRotatingCheckpoint::IsCheckpointExitDoor");

	delete hGameData;
}

bool bGetNavAreaCount()
{
	if(g_iTheCount)
		return true;

	g_iTheCount = LoadFromAddress(g_pTheCount, NumberType_Int32);
	if(!g_iTheCount)
	{
		#if DEBUG
		PrintToServer("The current number of Nav areas is 0, which may be some test maps");
		#endif

		return false;
	}

	return true;
}

int iGetMissionWipes()
{
	return LoadFromAddress(L4D_GetPointer(POINTER_DIRECTOR) + view_as<Address>(g_iOff_m_iMissionWipes), NumberType_Int32);
}

bool bIsPlayerInEndArea(int client, bool bCheckArea = true)
{
	int navarea = L4D_GetLastKnownArea(client);
	if(!navarea)
		return false;

	if(bCheckArea && g_aEndNavArea.FindValue(navarea) == -1)
		return false;

	if(g_bIsFinaleMap)
		return bIsValidEntRef(g_iRescueVehicle) && SDKCall(g_hSDK_CBaseTrigger_IsTouching, g_iRescueVehicle, client);
	
	return bIsValidEntRef(g_iChangelevel) && SDKCall(g_hSDK_CBaseTrigger_IsTouching, g_iChangelevel, client);
}