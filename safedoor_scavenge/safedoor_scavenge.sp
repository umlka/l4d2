#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <left4dhooks>

#define GAMEDATA				"safedoor_scavenge"
// https://developer.valvesoftware.com/wiki/List_of_L4D_Series_Nav_Mesh_Attributes:zh-cn
#define NAV_MESH_PLAYERCLIP		262144
#define NAV_MESH_FLOW_BLOCKED	134217728
#define NAV_MESH_OUTSIDE_WORLD	268435456
#define TERROR_NAV_CHECKPOINT	2048

Handle
	g_hPanicTimer,
	g_hSDKIsCheckpointDoor,
	g_hSDKIsCheckpointExitDoor,
	g_hSDKNextBotCreatePlayerBot,
	g_hSDKSurvivorBotIsReachable;

DynamicHook
	g_dDynamicHook;

Address
	g_pTheNavAreas;

ArrayList
	g_aLastDoor,
	g_aSpawnArea,
	g_aScavengeItem;

ConVar
	g_hGascanUseRange,
	g_hNumCansNeeded,
	g_hMinTravelDistance,
	g_hMaxTravelDistance,
	g_hCansNeededPerPlayer,
	g_hAllowMultipleFill,
	g_hScavengePanicTime;

int
	g_iTheCount,
	g_iRoundStart, 
	g_iPlayerSpawn,
	g_iSpawnAttributesOffset,
	g_iFlowDistanceOffset,
	g_iNumCansNeeded,
	g_iNumGascans,
	g_iTargetDoor,
	g_iGameDisplay,
	g_iFuncNavBlocker,
	g_iPourGasAmount,
	g_iPropUseTarget[MAXPLAYERS + 1];

float
	g_fGascanUseRange,
	g_fMinTravelDistance,
	g_fMaxTravelDistance,
	g_fCansNeededPerPlayer,
	g_fScavengePanicTime,
	g_fBlockGascanTime[MAXPLAYERS + 1];

bool
	g_bInTime,
	g_bFirstRound,
	g_bScavengeStarted,
	g_bBlockOpenDoor,
	g_bAllowMultipleFill;

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
		L4D_FindRandomSpot(view_as<int>(this), result);

		/*float vMins[3];
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

public Plugin myinfo = 
{
	name = 			"Safe Door Scavenge",
	author = 		"sorallll",
	description = 	"",
	version = 		"1.0.5",
	url = 			""
}

public void OnPluginStart()
{
	vLoadGameData();

	g_aLastDoor = new ArrayList();
	g_aSpawnArea = new ArrayList();
	g_aScavengeItem = new ArrayList();

	g_hGascanUseRange = FindConVar("gascan_use_range");

	g_hNumCansNeeded = CreateConVar("safedoor_scavenge_needed", "8", "How many barrels of oil need to be added to unlock the safe room door by default", _, true, 0.0);
	g_hMinTravelDistance = CreateConVar("safedoor_scavenge_min_dist", "250.0", "The minimum distance between the brushed oil drum and the land mark", _, true, 0.0);
	g_hMaxTravelDistance = CreateConVar("safedoor_scavenge_max_dist", "3500.0", "The maximum distance between the brushed oil drum and the land mark", _, true, 0.0);
	g_hCansNeededPerPlayer = CreateConVar("safedoor_scavenge_per_player", "1.5", "How many barrels of oil does each player need to unlock the safe room door (the value greater than 0 will override the value of safedoor_scavenge_needed. 0=use the default setting)", _, true, 0.0);
	g_hAllowMultipleFill = CreateConVar("safedoor_scavenge_multiple_fill", "0", "Allow multiple gascans to be filled at the same time?");
	g_hScavengePanicTime = CreateConVar("safedoor_scavenge_panic_time", "15.0", "How long is the panic event interval after the scavenge starts?(0.0=off)", _, true, 0.0);

	g_hGascanUseRange.AddChangeHook(vConVarChanged);
	g_hNumCansNeeded.AddChangeHook(vConVarChanged);
	g_hMinTravelDistance.AddChangeHook(vConVarChanged);
	g_hMaxTravelDistance.AddChangeHook(vConVarChanged);
	g_hCansNeededPerPlayer.AddChangeHook(vConVarChanged);
	g_hAllowMultipleFill.AddChangeHook(vConVarChanged);
	g_hScavengePanicTime.AddChangeHook(vConVarChanged);

	//AutoExecConfig(true, "safedoor_scavenge");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("weapon_drop", Event_WeaponDrop);
	HookEvent("entity_visible", Event_EntityVisible);

	RegAdminCmd("sm_sd", cmdSd, ADMFLAG_ROOT, "Test");
}

Action cmdSd(int client, int args)
{
	if(client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	float vPos[3];
	GetClientAbsOrigin(client, vPos);
	int area = L4D_GetNearestNavArea(vPos);
	if(area)
	{
		ReplyToCommand(client, "BaseAttributes->%d SpawnAttributes->%d SpawnArea Count->%d", view_as<CNavArea>(area).BaseAttributes, view_as<CNavArea>(area).SpawnAttributes, g_aSpawnArea.Length);
		ReplyToCommand(client, "DOOR->%d STOP_SCAN->%d TR_PointOutsideWorld->%d SpawnFlags->%d", view_as<CNavArea>(area).SpawnAttributes & 262144, view_as<CNavArea>(area).SpawnAttributes & 4, TR_PointOutsideWorld(vPos), LoadFromAddress(view_as<Address>(area) + view_as<Address>(127), NumberType_Int32));
		int iBot = iFindSurvivorBot();
		if(iBot != -1)
		{
			float vBot[3];
			GetClientAbsOrigin(iBot, vBot);

			int iBotArea = L4D_GetNearestNavArea(vBot);
			if(iBotArea)
				ReplyToCommand(client, "SurvivorBotIsReachable->%d NavAreaBuildPath->%d", SDKCall(g_hSDKSurvivorBotIsReachable, iBot, iBotArea, area), L4D2_VScriptWrapper_NavAreaBuildPath(vBot, vPos, 100000.0, false, true, 2, false));
		}
	}

	/*Event event = CreateEvent("gascan_pour_blocked", true);
	event.SetInt("userid", GetClientUserId(client));
	event.FireToClient(client);*/

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
	g_fGascanUseRange = g_hGascanUseRange.FloatValue + 128.0;
	g_iNumCansNeeded = g_hNumCansNeeded.IntValue;
	g_fMinTravelDistance = g_hMinTravelDistance.FloatValue;
	g_fMaxTravelDistance = g_hMaxTravelDistance.FloatValue;
	g_fCansNeededPerPlayer = g_hCansNeededPerPlayer.FloatValue;
	g_bAllowMultipleFill = g_hAllowMultipleFill.BoolValue;
	g_fScavengePanicTime = g_hScavengePanicTime.FloatValue;
}

public void OnMapStart()
{
	g_bFirstRound = true;

	vLateLoadGameData();

	PrecacheModel("models/props_junk/gascan001a.mdl", true);
}

public void OnMapEnd()
{
	vResetPlugin();
	g_aSpawnArea.Clear();
}

void vResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_iPourGasAmount = 0;

	g_bScavengeStarted = false;
	g_bBlockOpenDoor = false;

	g_aLastDoor.Clear();
	g_aScavengeItem.Clear();

	delete g_hPanicTimer;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(bIsValidEntRef(g_iPropUseTarget[i]))
			RemoveEntity(g_iPropUseTarget[i]);

		g_iPropUseTarget[i] = 0;
		g_fBlockGascanTime[i] = 0.0;
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bFirstRound = false;

	int iLength = g_aScavengeItem.Length;
	if(iLength > 0)
	{
		int iEntRef;
		for(int i; i < iLength; i++)
		{
			if(bIsValidEntRef((iEntRef = g_aScavengeItem.Get(i))))
				RemoveEntity(iEntRef);
		}
	}

	if(bIsValidEntRef(g_iGameDisplay))
		AcceptEntityInput(g_iGameDisplay, "TurnOff");

	vResetPlugin();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hPanicTimer;

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

void Event_WeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!bIsValidEntRef(g_iPropUseTarget[client]))
		return;

	int propid = event.GetInt("propid");
	if(propid <= MaxClients || !IsValidEntity(propid))
		return;
	
	char classname[14];
	GetEntityClassname(propid, classname, sizeof(classname));
	if(strcmp(classname[7], "gascan") == 0)
	{
		int entity = g_iPropUseTarget[client];
		g_iPropUseTarget[client] = 0;

		RemoveEntity(entity);
	}
}

void Event_EntityVisible(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bScavengeStarted)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

	int subject = EntIndexToEntRef(event.GetInt("subject"));
	if(g_aLastDoor.FindValue(subject) == -1)
		return;
	
	int iMaxSpawnArea = g_aSpawnArea.Length;
	if(!iMaxSpawnArea)
	{
		g_bBlockOpenDoor = false;
		vUnhookAllCheckpointDoor();

		if(bIsValidEntRef(g_iFuncNavBlocker))
			AcceptEntityInput(g_iFuncNavBlocker, "UnblockNav");
	
		return;
	}

	g_bScavengeStarted = true;

	g_iTargetDoor = subject;

	SetEntProp(subject, Prop_Send, "m_glowColorOverride", iGetColorInt(255, 0, 0));
	AcceptEntityInput(subject, "StartGlowing");

	g_iNumGascans = g_fCansNeededPerPlayer != 0.0 ? RoundToCeil(float(iCountSurvivorTeam()) * g_fCansNeededPerPlayer) : g_iNumCansNeeded;

	SetRandomSeed(GetTime());

	float vOrigin[3];
	for(int i; i < g_iNumGascans; i++)
	{
		view_as<CNavArea>(g_aSpawnArea.Get(GetRandomInt(0, iMaxSpawnArea - 1))).FindRandomSpot(vOrigin);
		vSpawnScavengeItem(vOrigin);
	}

	vSetNeededDisplay(g_iNumGascans);

	if(g_fScavengePanicTime)
	{
		vExecuteCheatCommand("director_force_panic_event");

		delete g_hPanicTimer;
		g_hPanicTimer = CreateTimer(g_fScavengePanicTime, tmrScavengePanic, _, TIMER_REPEAT);
	}
}

void vInitPlugin()
{
	vFindSafeRoomDoors();

	if(g_bFirstRound)
		RequestFrame(OnNextFrame_FindTerrorNavAreas);
}

void OnNextFrame_FindTerrorNavAreas()
{
	vFindTerrorNavAreas();
}

void vFindSafeRoomDoors()
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");
	
	if(entity != INVALID_ENT_REFERENCE)
	{
		int iChangeLevel = entity;
	
		int iFlags;
		entity = MaxClients + 1;
		while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
		{
			iFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
			if(iFlags & 8192 == 0 || iFlags & 32768 != 0)
				continue;

			if(!SDKCall(g_hSDKIsCheckpointDoor, entity))
				continue;
			
			if(!SDKCall(g_hSDKIsCheckpointExitDoor, entity))
			{
				g_aLastDoor.Push(EntIndexToEntRef(entity));

				AcceptEntityInput(entity, "Close");
				AcceptEntityInput(entity, "forceclosed");
				HookSingleEntityOutput(entity, "OnOpen", vOnOpen);
			}
		}

		if(g_aLastDoor.Length)
		{
			g_bBlockOpenDoor = true;

			float vOrigin[3], vMins[3], vMaxs[3];
			GetEntPropVector(iChangeLevel, Prop_Send, "m_vecOrigin", vOrigin);
			GetEntPropVector(iChangeLevel, Prop_Send, "m_vecMins", vMins);
			GetEntPropVector(iChangeLevel, Prop_Send, "m_vecMaxs", vMaxs);

			vMins[0] -= 33.0;
			vMins[1] -= 33.0;
			vMins[2] -= 33.0;
			vMaxs[0] += 33.0;
			vMaxs[1] += 33.0;
			vMaxs[2] += 33.0;

			DataPack dPack = new DataPack();
			dPack.WriteFloatArray(vOrigin, 3);
			dPack.WriteFloatArray(vMins, 3);
			dPack.WriteFloatArray(vMaxs, 3);
			CreateTimer(0.1, tmrBlockNav, dPack, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

// [L4D2] Saferoom Lock: Scavenge (https://forums.alliedmods.net/showthread.php?t=333086)
void vOnOpen(const char[] output, int caller, int activator, float delay)
{
	if(!g_bScavengeStarted)
	{
		int iMaxSpawnArea = g_aSpawnArea.Length;
		if(!iMaxSpawnArea)
		{
			g_bBlockOpenDoor = false;
			vUnhookAllCheckpointDoor();

			if(bIsValidEntRef(g_iFuncNavBlocker))
				AcceptEntityInput(g_iFuncNavBlocker, "UnblockNav");
	
			return;
		}

		g_bScavengeStarted = true;

		g_iTargetDoor = EntIndexToEntRef(caller);

		SetEntProp(caller, Prop_Send, "m_glowColorOverride", iGetColorInt(255, 0, 0));
		AcceptEntityInput(caller, "StartGlowing");

		g_iNumGascans = g_fCansNeededPerPlayer != 0.0 ? RoundToCeil(float(iCountSurvivorTeam()) * g_fCansNeededPerPlayer) : g_iNumCansNeeded;

		SetRandomSeed(GetTime());

		float vOrigin[3];
		for(int i; i < g_iNumGascans; i++)
		{
			view_as<CNavArea>(g_aSpawnArea.Get(GetRandomInt(0, iMaxSpawnArea - 1))).FindRandomSpot(vOrigin);
			vSpawnScavengeItem(vOrigin);
		}

		vSetNeededDisplay(g_iNumGascans);

		if(g_fScavengePanicTime)
		{
			vExecuteCheatCommand("director_force_panic_event");

			delete g_hPanicTimer;
			g_hPanicTimer = CreateTimer(g_fScavengePanicTime, tmrScavengePanic, _, TIMER_REPEAT);
		}
	}

	if(g_bBlockOpenDoor && !g_bInTime)
	{
		g_bInTime = true;
		RequestFrame(OnNextFrame_CloseDoor, EntIndexToEntRef(caller));
	}
}

Action tmrScavengePanic(Handle timer)
{
	vExecuteCheatCommand("director_force_panic_event");
	return Plugin_Continue;
}


void OnNextFrame_CloseDoor(int entity)
{
	if((entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE)
	{
		SetEntPropString(entity, Prop_Data, "m_SoundClose", "");
		SetEntPropString(entity, Prop_Data, "m_SoundOpen", "");
		AcceptEntityInput(entity, "Close");
		SetEntPropString(entity, Prop_Data, "m_SoundClose", "Doors.Checkpoint.FullClose1");
		SetEntPropString(entity, Prop_Data, "m_SoundOpen", "Doors.Checkpoint.FullOpen1");
	}
	g_bInTime = false;
}

Action tmrBlockNav(Handle timer, DataPack dPack)
{
	dPack.Reset();
	float vMins[3], vMaxs[3], vOrigin[3];
	dPack.ReadFloatArray(vOrigin, 3);
	dPack.ReadFloatArray(vMins, 3);
	dPack.ReadFloatArray(vMaxs, 3);
	delete dPack;

	int entity = CreateEntityByName("func_nav_blocker");
	DispatchKeyValue(entity, "teamToBlock", "2");
	DispatchKeyValue(entity, "affectsFlow", "0");
	DispatchKeyValue(entity, "solid", "2");

	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);

	SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);

	AcceptEntityInput(entity, "BlockNav");

	g_iFuncNavBlocker = EntIndexToEntRef(entity);

	return Plugin_Continue;
}

void vFindTerrorNavAreas()
{
	if(!g_aLastDoor.Length)
		return;

	int iLandArea;
	float fLandFlow;
	float fMapMaxFlow = L4D2Direct_GetMapMaxFlowDistance();

	float vOrigin[3];
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "info_landmark")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
		iLandArea = L4D_GetNearestNavArea(vOrigin);
		if(!iLandArea)
			continue;

		fLandFlow = view_as<CNavArea>(iLandArea).Flow;
		if(fLandFlow > fMapMaxFlow * 0.5)
			break;
	}

	bool bCreated;
	int iBot = iFindSurvivorBot();
	if(iBot == -1)
	{
		iBot = iCreateSurvivorBot();
		if(iBot == -1)
			return;

		bCreated = true;
	}

	float fMinFlow = g_fMinTravelDistance;
	if(fMinFlow > fMapMaxFlow)
		fMinFlow = fMapMaxFlow * 0.75;

	float fMaxFlow = g_fMaxTravelDistance;
	if(fMaxFlow > fMapMaxFlow)
		fMaxFlow = fMapMaxFlow;

	if(fMinFlow >= fMaxFlow)
		fMinFlow = fMaxFlow * 0.5;

	fLandFlow -= fMaxFlow;

	CNavArea area;

	int iBaseAttributes;
	float fFlow;
	float fDistance;
	float vCenter[3];
	for(int i; i < g_iTheCount; i++)
	{
		if((area = view_as<CNavArea>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32))).IsNull() == true)
			continue;

		if(area.SpawnAttributes & TERROR_NAV_CHECKPOINT)
			continue;

		iBaseAttributes = area.BaseAttributes;
		if(iBaseAttributes  & NAV_MESH_PLAYERCLIP || iBaseAttributes  & NAV_MESH_FLOW_BLOCKED || iBaseAttributes  & NAV_MESH_OUTSIDE_WORLD)
			continue;

		fFlow = area.Flow;
		if(fFlow == -9999.0 || area.Flow < fLandFlow)
			continue;

		if(!SDKCall(g_hSDKSurvivorBotIsReachable, iBot, iLandArea, area)) //有往返程之分, 这里只考虑返程. 往程area->iLandArea 返程iDoorArea->area 有些地图从安全门开始的返程不能回去，例如c2m1, c7m1, c13m1等
			continue;

		area.Center(vCenter);
		fDistance = L4D2_NavAreaTravelDistance(vOrigin, vCenter, true); //有往返程之分, 这里只考虑返程. 往程vCenter->vOrigin 返程vOrigin->vCenter
		if(fDistance < fMinFlow || fDistance > fMaxFlow)
			continue;

		area.FindRandomSpot(vCenter);
		if(bIsPlayerStuck(vCenter))
			continue;

		g_aSpawnArea.Push(area);
	}

	if(bCreated)
	{
		vRemovePlayerWeapons(iBot);
		KickClient(iBot);
	}
}

bool bIsPlayerStuck(const float vPos[3])
{
	static bool bHit;
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vPos, vPos, view_as<float>({-16.0, -16.0, 0.0}), view_as<float>({16.0, 16.0, 71.0}), MASK_PLAYERSOLID, bTraceEntityFilter);
	if(hTrace != null)
	{
		bHit = TR_DidHit(hTrace);
		delete hTrace;
	}
	return bHit;
}

bool bTraceEntityFilter(int entity, int contentsMask)
{
	return !entity || entity > MaxClients;
}

int iFindSurvivorBot()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			return i;
	}
	return -1;
}

void vRemovePlayerWeapons(int client)
{
	int iWeapon;
	for(int i; i < 5; i++)
	{
		iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			if(RemovePlayerItem(client, iWeapon))
				RemoveEdict(iWeapon);
		}
	}
}

void vUnhookAllCheckpointDoor()
{
	int iEntRef;
	int iLength = g_aLastDoor.Length;
	for(int i; i < iLength; i++)
	{
		if(bIsValidEntRef((iEntRef = g_aLastDoor.Get(i, 0))))
			UnhookSingleEntityOutput(iEntRef, "OnOpen", vOnOpen);
	}
}

int iGetColorInt(int red, int green, int blue)
{
	return red + (green << 8) + (blue << 16);
}

int iCountSurvivorTeam()
{
	int iSurvivors;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
			iSurvivors++;
	}
	return iSurvivors;
}

void vSpawnScavengeItem(const float vOrigin[3])
{
	int entity = CreateEntityByName("weapon_scavenge_item_spawn");
	DispatchKeyValue(entity, "solid", "6");
	DispatchKeyValue(entity, "glowstate", "3");
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "disableshadows", "1");

	char sSkin[2];
	IntToString(GetRandomInt(1, 3), sSkin, sizeof(sSkin));
	DispatchKeyValue(entity, "weaponskin", sSkin);
	
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);

	SetEntityMoveType(entity, MOVETYPE_NONE);

	AcceptEntityInput(entity, "SpawnItem");
	AcceptEntityInput(entity, "TurnGlowsOn");
	g_aScavengeItem.Push(EntIndexToEntRef(entity));
}

void vSetNeededDisplay(int iNumCans)
{
	int entity = CreateEntityByName("game_scavenge_progress_display");

	char sNumCans[8];
	IntToString(iNumCans, sNumCans, sizeof(sNumCans));
	DispatchKeyValue(entity, "Max", sNumCans);
	DispatchSpawn(entity);

	AcceptEntityInput(entity, "TurnOn");
	g_iGameDisplay = EntIndexToEntRef(entity);
}

bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}

void vExecuteCheatCommand(const char[] sCommand, const char[] sValue = "")
{
	int iCmdFlags = GetCommandFlags(sCommand);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	ServerCommand("%s %s", sCommand, sValue);
	ServerExecute();
	SetCommandFlags(sCommand, iCmdFlags);
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

	g_iSpawnAttributesOffset = hGameData.GetOffset("TerrorNavArea::ScriptGetSpawnAttributes");
	if(g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: TerrorNavArea::ScriptGetSpawnAttributes");

	g_iFlowDistanceOffset = hGameData.GetOffset("CTerrorPlayer::GetFlowDistance::m_flow");
	if(g_iSpawnAttributesOffset == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::GetFlowDistance::m_flow");

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

	StartPrepSDKCall(SDKCall_Static);
	Address pAddr = hGameData.GetAddress("NextBotCreatePlayerBot<SurvivorBot>");
	if(pAddr == Address_Null)
		SetFailState("Failed to find address: NextBotCreatePlayerBot<SurvivorBot> in CDirector::AddSurvivorBot");
	if(hGameData.GetOffset("OS") == 1) // 1 - windows, 2 - linux. it's hard to get uniq. sig in windows => will use XRef.
		pAddr += view_as<Address>(LoadFromAddress(pAddr + view_as<Address>(1), NumberType_Int32) + 5); // sizeof(instruction)
	if(PrepSDKCall_SetAddress(pAddr) == false)
		SetFailState("Failed to find address: NextBotCreatePlayerBot<SurvivorBot>");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDKNextBotCreatePlayerBot = EndPrepSDKCall();
	if(g_hSDKNextBotCreatePlayerBot == null)
		SetFailState("Failed to create SDKCall: NextBotCreatePlayerBot<SurvivorBot>");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::IsReachable") == false)
		SetFailState("Failed to find signature: SurvivorBot::IsReachable");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKSurvivorBotIsReachable = EndPrepSDKCall();
	if(g_hSDKSurvivorBotIsReachable == null)
		SetFailState("Failed to create SDKCall: SurvivorBot::IsReachable");

	vSetupDynamicHooks(hGameData);

	delete hGameData;
}

void vSetupDynamicHooks(GameData hGameData = null)
{
	g_dDynamicHook = DynamicHook.FromConf(hGameData, "CGasCan::GetTargetEntity");
	if(g_dDynamicHook == null)
		SetFailState("Failed to load offset: CGasCan::GetTargetEntity");
}

MRESReturn mreGasCanGetTargetEntityPre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(!g_bScavengeStarted)
		return MRES_Ignored;

	int client = hParams.Get(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return MRES_Ignored;

	static float vPos[3], vTarget[3];
	GetClientEyePosition(client, vPos);
	GetEntPropVector(g_iTargetDoor, Prop_Data, "m_vecAbsOrigin", vTarget);
	if(FloatAbs(vPos[2] - vTarget[2]) > g_fGascanUseRange)
		return MRES_Ignored;

	vTarget[2] = vPos[2] = 0.0;
	if(GetVectorDistance(vPos, vTarget) > g_fGascanUseRange)
		return MRES_Ignored;

	MakeVectorFromPoints(vPos, vTarget, vPos);
	NormalizeVector(vPos, vPos);

	static float vAng[3];
	GetClientEyeAngles(client, vAng);
	vAng[0] = vAng[2] = 0.0;
	GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vAng, vAng);

	static float fDegree;
	fDegree = RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vPos)));
	if(fDegree < -120.0 || fDegree > 120.0)
		return MRES_Ignored;

	if(!g_bAllowMultipleFill && bOtherPlayerPouringGas(client))
	{
		g_fBlockGascanTime[client] = GetGameTime() + 1.8;
	
		DataPack dPack = new DataPack();
		dPack.WriteCell(GetClientUserId(client));
		dPack.WriteCell(EntIndexToEntRef(pThis));
		RequestFrame(OnNextFrame_EquipGascan, dPack);

		return MRES_Ignored;
	}

	vStartPouring(client);

	return MRES_Ignored;
}

// [L4D2] Scavenge Pouring (https://forums.alliedmods.net/showthread.php?t=333064)
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!g_bAllowMultipleFill && g_fBlockGascanTime[client] > GetGameTime())
		buttons &= ~IN_ATTACK;

	return Plugin_Continue;
}

void OnNextFrame_EquipGascan(DataPack dPack)
{
	dPack.Reset();

	int client = GetClientOfUserId(dPack.ReadCell());
	if(client && IsClientInGame(client))
	{
		int weapon = EntRefToEntIndex(dPack.ReadCell());
		if(weapon != INVALID_ENT_REFERENCE)
		{
			EquipPlayerWeapon(client, weapon);

			// 伪造gascan_pour_blocked事件来调用客户端的特定本地化提示(等一会! 有其他人正在加油..)
			Event event = CreateEvent("gascan_pour_blocked", true);
			event.SetInt("userid", GetClientUserId(client));
			event.FireToClient(client);
		}
	}

	delete dPack;
}

bool bOtherPlayerPouringGas(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && g_iPropUseTarget[i] && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && L4D2_GetPlayerUseAction(i) == L4D2UseAction_PouringGas)
			return true;
	}
	return false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity <= MaxClients)
		return;

	if(classname[0] != 'w' && classname[1] != 'e')
		return;

	if(strcmp(classname, "weapon_gascan") == 0)
        g_dDynamicHook.HookEntity(Hook_Pre, entity, mreGasCanGetTargetEntityPre);
}

// [L4D2] Pour Gas (https://forums.alliedmods.net/showthread.php?p=1729019)
void vStartPouring(int client)
{
	vRemovePropUseTarget(client);

	float vPos[3], vAng[3], vDir[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsAngles(client, vAng);
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vPos[0] += vDir[0] * 5.0;
	vPos[1] += vDir[1] * 5.0;
	vPos[2] += vDir[2] * 5.0;

	int entity = CreateEntityByName("point_prop_use_target");
	DispatchKeyValue(entity, "nozzle", "gas_nozzle");
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	SetVariantString("OnUseCancelled !self:Kill::0.0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnUseFinished !self:Kill::0.0:-1");
	AcceptEntityInput(entity, "AddOutput");
	HookSingleEntityOutput(entity, "OnUseCancelled", vOnUseCancelled);
	HookSingleEntityOutput(entity, "OnUseFinished", vOnUseFinished, true);
	SetEntProp(entity, Prop_Data, "m_iHammerID", client);
	g_iPropUseTarget[client] = EntIndexToEntRef(entity);
}

void vRemovePropUseTarget(int client)
{
	int entity = g_iPropUseTarget[client];
	g_iPropUseTarget[client] = 0;

	if(bIsValidEntRef(entity))
		RemoveEntity(entity);
}

void vOnUseCancelled(const char[] output, int caller, int activator, float delay)
{
	g_iPropUseTarget[GetEntProp(caller, Prop_Data, "m_iHammerID")] = 0;

	RemoveEntity(caller);
}

void vOnUseFinished(const char[] output, int caller, int activator, float delay)
{
	g_iPourGasAmount++;
	if(g_iPourGasAmount == g_iNumGascans)
	{
		delete g_hPanicTimer;

		g_bBlockOpenDoor = false;

		vUnhookAllCheckpointDoor();

		if(bIsValidEntRef(g_iFuncNavBlocker))
			AcceptEntityInput(g_iFuncNavBlocker, "UnblockNav");

		if(bIsValidEntRef(g_iTargetDoor))
			SetEntProp(g_iTargetDoor, Prop_Send, "m_glowColorOverride", iGetColorInt(0, 255, 0));
	}

	g_iPropUseTarget[GetEntProp(caller, Prop_Data, "m_iHammerID")] = 0;

	RemoveEntity(caller);
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
	if(!g_iTheCount)
		PrintToServer("当前地图NavArea数量为0, 可能是某些测试地图");

	g_pTheNavAreas = view_as<Address>(LoadFromAddress(pTheCount + view_as<Address>(4), NumberType_Int32));
	if(g_pTheNavAreas == Address_Null)
		SetFailState("Failed to find address: TheNavAreas");

	delete hGameData;
}

// https://forums.alliedmods.net/showpost.php?p=2729883&postcount=16
int iCreateSurvivorBot()
{
	int iBot = SDKCall(g_hSDKNextBotCreatePlayerBot, NULL_STRING);
	if(IsValidEntity(iBot))
	{
		ChangeClientTeam(iBot, 2);
		
		if(!IsPlayerAlive(iBot))
			L4D_RespawnPlayer(iBot);

		return iBot;
	}
	return -1;
}