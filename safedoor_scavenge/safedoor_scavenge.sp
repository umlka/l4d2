#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define TERROR_NAV_CHECKPOINT	2048
#define GAMEDATA				"safedoor_scavenge"

Handle
	g_hSDKIsCheckpointDoor,
	g_hSDKIsCheckpointExitDoor,
	g_hSDKNextBotCreatePlayerBot,
	g_hSDKSurvivorBotIsReachable;

Address
	g_pTheNavAreas;

ArrayList
	g_aLastDoor,
	g_aSpawnArea,
	g_aScavengeItem;

ConVar
	g_hNumCansNeeded,
	g_hMinTravelDistance,
	g_hMaxTravelDistance,
	g_hCansNeededPerPlayer;

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
	g_iPropUseTarget,
	g_iFuncNavBlocker,
	g_iPourGasAmount;

float
	g_fMinTravelDistance,
	g_fMaxTravelDistance,
	g_fCansNeededPerPlayer;

bool
	g_bInTime,
	g_bFirstRound,
	g_bSpawnGascan,
	g_bBlockOpenDoor;

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
	version = 		"1.0.2",
	url = 			""
}

public void OnPluginStart()
{
	vLoadGameData();

	g_aLastDoor = new ArrayList();
	g_aSpawnArea = new ArrayList();
	g_aScavengeItem = new ArrayList();

	g_hNumCansNeeded = CreateConVar("safedoor_scavenge_needed", "8", "How many barrels of oil need to be added to unlock the safe room door by default", _, true, 0.0, true, 64.0);
	g_hMinTravelDistance = CreateConVar("safedoor_scavenge_min_dist", "250.0", "The minimum distance between the brushed oil drum and the land mark", _, true, 0.0);
	g_hMaxTravelDistance = CreateConVar("safedoor_scavenge_max_dist", "3500.0", "The maximum distance between the brushed oil drum and the land mark", _, true, 0.0);
	g_hCansNeededPerPlayer = CreateConVar("safedoor_scavenge_per_player", "1.0", "How many barrels of oil does each player need to unlock the safety door (the value greater than 0 will override the value of safedoor_scavenge_needed. 0=use the default setting)", _, true, 0.0, true, 64.0);

	g_hNumCansNeeded.AddChangeHook(vConVarChanged);
	g_hMinTravelDistance.AddChangeHook(vConVarChanged);
	g_hMaxTravelDistance.AddChangeHook(vConVarChanged);
	g_hCansNeededPerPlayer.AddChangeHook(vConVarChanged);

	//AutoExecConfig(true, "safedoor_scavenge");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_use", Event_PlayerUse, EventHookMode_Pre);
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
	g_iNumCansNeeded = g_hNumCansNeeded.IntValue;
	g_fMinTravelDistance = g_hMinTravelDistance.FloatValue;
	g_fMaxTravelDistance = g_hMaxTravelDistance.FloatValue;
	g_fCansNeededPerPlayer = g_hCansNeededPerPlayer.FloatValue;
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

	g_bSpawnGascan = false;
	g_bBlockOpenDoor = false;

	g_aLastDoor.Clear();
	g_aScavengeItem.Clear();
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

void Event_PlayerUse(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bSpawnGascan)
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

	int targetid = EntIndexToEntRef(event.GetInt("targetid"));
	if(g_aLastDoor.FindValue(targetid) == -1)
		return;

	g_iTargetDoor = targetid;

	SetEntProp(g_iTargetDoor, Prop_Send, "m_glowColorOverride", iGetColorInt(255, 0, 0));
	AcceptEntityInput(g_iTargetDoor, "StartGlowing");

	g_iNumGascans = g_fCansNeededPerPlayer != 0.0 ? RoundToCeil(float(iCountSurvivorTeam()) * g_fCansNeededPerPlayer) : g_iNumCansNeeded;

	SetRandomSeed(GetTime());

	float vOrigin[3];
	for(int i; i < g_iNumGascans; i++)
	{
		view_as<CNavArea>(g_aSpawnArea.Get(GetRandomInt(0, iMaxSpawnArea - 1))).FindRandomSpot(vOrigin);
		vSpawnScavengeItem(vOrigin);
	}

	vCreateGasNozzle(g_iTargetDoor);
	vSetNeededDisplay(g_iNumGascans);

	g_bSpawnGascan = true;
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

			float vMins[3], vMaxs[3], vOrigin[3];
			GetEntPropVector(iChangeLevel, Prop_Send, "m_vecMins", vMins);
			GetEntPropVector(iChangeLevel, Prop_Send, "m_vecMaxs", vMaxs);
			GetEntPropVector(iChangeLevel, Prop_Send, "m_vecOrigin", vOrigin);

			vMins[0] -= 33.0;
			vMins[1] -= 33.0;
			vMins[2] -= 33.0;
			vMaxs[0] += 33.0;
			vMaxs[1] += 33.0;
			vMaxs[2] += 33.0;

			entity = CreateEntityByName("func_nav_blocker");
			DispatchKeyValue(entity, "solid", "2");
			DispatchKeyValue(entity, "teamToBlock", "2");

			TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(entity);

			SetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
			SetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);

			AcceptEntityInput(entity, "BlockNav");

			g_iFuncNavBlocker = EntIndexToEntRef(entity);
		}
	}
}

// https://forums.alliedmods.net/showthread.php?t=333086
void vOnOpen(const char[] output, int caller, int activator, float delay)
{
	if(g_bBlockOpenDoor && !g_bInTime)
	{
		g_bInTime = true;
		RequestFrame(OnNextFrame_CloseDoor, EntIndexToEntRef(caller));
	}

	/*if(g_bSpawnGascan)
		return;

	int iMaxSpawnArea = g_aSpawnArea.Length;
	if(!iMaxSpawnArea)
	{
		g_bBlockOpenDoor = false;
		vUnhookAllCheckpointDoor();
		return;
	}

	g_iTargetDoor = EntIndexToEntRef(caller);

	SetEntProp(g_iTargetDoor, Prop_Send, "m_glowColorOverride", iGetColorInt(255, 0, 0));
	AcceptEntityInput(g_iTargetDoor, "StartGlowing");

	g_iNumGascans = g_fCansNeededPerPlayer != 0.0 ? RoundToCeil(float(iCountSurvivorTeam()) * g_fCansNeededPerPlayer) : g_iNumCansNeeded;

	SetRandomSeed(GetTime());

	float vOrigin[3];
	for(int i; i < g_iNumGascans; i++)
	{
		view_as<CNavArea>(g_aSpawnArea.Get(GetRandomInt(0, iMaxSpawnArea - 1))).FindRandomSpot(vOrigin);
		vSpawnScavengeItem(vOrigin);
	}

	vCreateGasNozzle(g_iTargetDoor);
	vSetNeededDisplay(g_iNumGascans);

	g_bSpawnGascan = true;*/
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

	float fFlow;
	float fDistance;
	float vCenter[3];
	for(int i; i < g_iTheCount; i++)
	{
		if((area = view_as<CNavArea>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32))).IsNull() == true || LoadFromAddress(view_as<Address>(area) + view_as<Address>(84), NumberType_Int32) != 0x20000000)
			continue;

		if(area.SpawnAttributes & TERROR_NAV_CHECKPOINT) //排除安全区域，避免直接刷进安全屋
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

		g_aSpawnArea.Push(area);
	}

	if(bCreated)
	{
		vRemovePlayerWeapons(iBot);
		KickClient(iBot);
	}
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

// https://forums.alliedmods.net/showthread.php?t=333086
void vCreateGasNozzle(int iTarget)
{
	int entity = CreateEntityByName("point_prop_use_target");
	DispatchKeyValue(entity, "nozzle", "safedoor_gas_nozzle");

	float vOrigin[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", vOrigin);
	vOrigin[2] -= 20.0;
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);

	SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({ -56.0, -56.0, -72.0 }));
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({ 56.0, 56.0, 72.0 }));


	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", iTarget);

	HookSingleEntityOutput(entity, "OnUseFinished", vOnUseFinished);
	g_iPropUseTarget = EntIndexToEntRef(entity);
}

void vOnUseFinished(const char[] output, int caller, int activator, float delay)
{
	g_iPourGasAmount++;
	if(g_iPourGasAmount == g_iNumGascans)
	{
		g_bBlockOpenDoor = false;

		if(bIsValidEntRef(g_iTargetDoor))
			SetEntProp(g_iTargetDoor, Prop_Send, "m_glowColorOverride", iGetColorInt(0, 255, 0));

		int iEntRef;
		int iLength = g_aLastDoor.Length;
		for(int i; i < iLength; i++)
		{
			if(bIsValidEntRef((iEntRef = g_aLastDoor.Get(i, 0))))
				UnhookSingleEntityOutput(iEntRef, "OnOpen", vOnOpen);
		}

		if(bIsValidEntRef(g_iPropUseTarget))
			RemoveEntity(g_iPropUseTarget);

		if(bIsValidEntRef(g_iFuncNavBlocker))
			AcceptEntityInput(g_iFuncNavBlocker, "UnblockNav");
	}
}

// Convert 3 values of 8-bit into a 32-bit
int iGetColorInt(int red, int green, int blue)
{
	return red + (green << 8) + (blue << 16);
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

bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
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
