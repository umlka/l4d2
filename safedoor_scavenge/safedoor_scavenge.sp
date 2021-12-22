#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define FIRST_MAP					1
#define MIDDLE_MAP					2
#define	FINAL_MAP					4
#define TERROR_NAV_MISSION_START	128
#define TERROR_NAV_CHECKPOINT		2048
#define TERROR_NAV_RESCUE_VEHICLE	32768
#define GAMEDATA					"safedoor_scavenge"

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
	g_iPourGasAmount;

float
	g_fMinTravelDistance,
	g_fMaxTravelDistance,
	g_fCansNeededPerPlayer;

bool
	//g_bLateLoad,
	g_bFirstRound,
	g_bSpawnGascan;

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
	version = 		"1.0.0",
	url = 			""
}

public void OnPluginStart()
{
	vLoadGameData();

	g_aLastDoor = new ArrayList(3);
	g_aSpawnArea = new ArrayList();
	g_aScavengeItem = new ArrayList();

	g_hNumCansNeeded = CreateConVar("safedoor_scavenge_needed", "8", "How many barrels of oil need to be added to unlock the safety door by default", _, true, 0.0, true, 64.0);
	g_hMinTravelDistance = CreateConVar("safedoor_scavenge_min_dist", "100.0", "The minimum distance between the brushed oil drum and the safety door", _, true, 0.0);
	g_hMaxTravelDistance = CreateConVar("safedoor_scavenge_max_dist", "3500.0", "The maximum distance between the brushed oil drum and the safety door", _, true, 0.0);
	g_hCansNeededPerPlayer = CreateConVar("safedoor_scavenge_per_player", "1.0", "How many barrels of oil does each player need to unlock the safety door (the value greater than 0 will override the value of safedoor_scavenge_needed. 0=use the default setting)", _, true, 0.0, true, 64.0);

	g_hNumCansNeeded.AddChangeHook(vConVarChanged);
	g_hMinTravelDistance.AddChangeHook(vConVarChanged);
	g_hMaxTravelDistance.AddChangeHook(vConVarChanged);
	g_hCansNeededPerPlayer.AddChangeHook(vConVarChanged);

	AutoExecConfig(true, "safedoor_scavenge");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_use", Event_PlayerUsePre, EventHookMode_Pre);

	/*if(g_bLateLoad)
	{
		OnMapStart();
		vInitPlugin();
		g_iRoundStart = 1;
		g_iPlayerSpawn = 1;
		g_bSpawnGascan = false;
	}*/
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
	g_iTargetDoor = 0;
	g_iGameDisplay = 0;
	g_iPourGasAmount = 0;

	g_bSpawnGascan = false;

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

void Event_PlayerUsePre(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bSpawnGascan)
		return;

	int iLength = g_aSpawnArea.Length;
	if(iLength == 0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

	int targetid = EntIndexToEntRef(event.GetInt("targetid"));
	if(g_aLastDoor.FindValue(targetid) == -1)
		return;

	int iMaxSpawnArea = iLength;

	int iEntRef;
	iLength = g_aLastDoor.Length;
	for(int i; i < iLength; i++)
	{
		if(bIsValidEntRef((iEntRef = g_aLastDoor.Get(i, 0))))
		{
			g_aLastDoor.Set(i, GetEntPropFloat(iEntRef, Prop_Data, "m_flSpeed"), 1);
			g_aLastDoor.Set(i, GetEntProp(iEntRef, Prop_Send, "m_spawnflags"), 2);
	
			if(GetEntProp(iEntRef, Prop_Data, "m_eDoorState") != 0)
			{
				SetEntPropFloat(iEntRef, Prop_Data, "m_flSpeed", 1000.0);
				SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 0);
				AcceptEntityInput(iEntRef, "Unlock");
				AcceptEntityInput(iEntRef, "Close");
				AcceptEntityInput(iEntRef, "forceclosed");
				AcceptEntityInput(iEntRef, "Lock");
				SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 1);
			}
	
			SetEntProp(iEntRef, Prop_Send, "m_spawnflags", 36864);
		}
	}

	g_iTargetDoor = targetid;

	SetEntProp(targetid, Prop_Send, "m_glowColorOverride", iGetColorInt(255, 0, 0));
	AcceptEntityInput(targetid, "StartGlowing");

	g_iNumGascans = g_fCansNeededPerPlayer != 0.0 ? RoundToCeil(float(iCountSurvivorTeam()) * g_fCansNeededPerPlayer) : g_iNumCansNeeded;

	float vOrigin[3];
	for(int i; i < g_iNumGascans; i++)
	{
		view_as<CNavArea>(g_aSpawnArea.Get(GetRandomInt(0, iMaxSpawnArea - 1))).FindRandomSpot(vOrigin);
		vSpawnScavengeItem(vOrigin);
	}

	vCreateGasNozzle(targetid);
	vSetNeededDisplay(g_iNumGascans);

	g_bSpawnGascan = true;
}

void vFindSafeRoomDoors()
{
	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");
	
	if(entity != INVALID_ENT_REFERENCE)
	{
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
				if(GetEntProp(entity, Prop_Data, "m_eDoorState") != 0)
				{
					AcceptEntityInput(entity, "Close");
					AcceptEntityInput(entity, "forceclosed");
					AcceptEntityInput(entity, "Lock");
					SetEntProp(entity, Prop_Data, "m_hasUnlockSequence", 1);
				}

				g_aLastDoor.Push(EntIndexToEntRef(entity));
			}
		}
	}
}

void vFindTerrorNavAreas()
{
	int iLength = g_aLastDoor.Length;
	if(iLength == 0)
		return;

	
	int iEntRef;
	int iDoorArea;
	int iIndex;

	float fFlow;
	float vOrigin[3];
	ArrayList aDoorFlow = new ArrayList(3);
	for(int i; i < iLength; i++)
	{
		if(bIsValidEntRef((iEntRef = g_aLastDoor.Get(i, 0))))
		{
			GetEntPropVector(iEntRef, Prop_Data, "m_vecAbsOrigin", vOrigin);
			iDoorArea = L4D_GetNearestNavArea(vOrigin);
			if(iDoorArea == 0)
				continue;

			fFlow = view_as<CNavArea>(iDoorArea).Flow;
			if(fFlow == 0.0 || fFlow == -9999.0)
				continue;

			iIndex = aDoorFlow.Push(fFlow);
			aDoorFlow.Set(iIndex, iDoorArea, 1);
			aDoorFlow.Set(iIndex, iEntRef, 2);
		}
	}

	if(aDoorFlow.Length == 0)
	{
		delete aDoorFlow;
		return;
	}

	aDoorFlow.Sort(Sort_Ascending, Sort_Float);
	fFlow = aDoorFlow.Get(0, 0);
	iDoorArea = aDoorFlow.Get(0, 1);
	GetEntPropVector(aDoorFlow.Get(0, 2), Prop_Data, "m_vecAbsOrigin", vOrigin);

	delete aDoorFlow;

	bool bCreated;
	int iBot = iFindSurvivorBot();
	if(iBot == -1)
	{
		iBot = iCreateSurvivorBot();
		if(iBot == -1)
			return;

		bCreated = true;
	}

	float fMapMaxFlow = L4D2Direct_GetMapMaxFlowDistance();

	float fMinFlow = g_fMinTravelDistance;
	if(fMinFlow > fMapMaxFlow)
		fMinFlow = fMapMaxFlow * 0.75;

	float fMaxFlow = g_fMaxTravelDistance;
	if(fMaxFlow > fMapMaxFlow)
		fMaxFlow = fMapMaxFlow;

	if(fMinFlow >= fMaxFlow)
		fMinFlow = fMaxFlow * 0.5;

	fFlow -= fMaxFlow;

	CNavArea area;
	int iFlags;
	float fDistance;
	float vCenter[3];
	for(int i; i < g_iTheCount; i++)
	{
		if((area = view_as<CNavArea>(LoadFromAddress(g_pTheNavAreas + view_as<Address>(i * 4), NumberType_Int32))).IsNull() == true)
			continue;

		iFlags = area.SpawnAttributes;
		if(iFlags & TERROR_NAV_CHECKPOINT || iFlags & TERROR_NAV_MISSION_START) //排除安全区域，避免直接刷进安全屋
			continue;

		if(area.Flow < fFlow)
			continue;

		if(!SDKCall(g_hSDKSurvivorBotIsReachable, iBot, iDoorArea, area)) //有往返程之分, 这里只考虑返程. 往程area->iDoorArea 返程iDoorArea->area 有些地图从安全门开始的返程不能回去，例如c2m1, c7m1, c13m1等
			continue;
		/*{
			area.Center(vCenter);
			if(!L4D2_IsReachable(iBot, vCenter)) //这个函数不会考虑往返程
				continue;
		}*/
					
		area.Center(vCenter);
		fDistance = L4D2_NavAreaTravelDistance(vOrigin, vCenter, false); //有往返程之分, 这里只考虑返程. 往程vCenter->vOrigin 返程vOrigin->vCenter
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

// https://forums.alliedmods.net/showthread.php?t=333086
void vCreateGasNozzle(int iTarget)
{
	int entity = CreateEntityByName("point_prop_use_target");
	DispatchKeyValue(entity, "nozzle", "safedoor_gas_nozzle");

	float vOrigin[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", vOrigin);
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", iTarget);

	HookSingleEntityOutput(entity, "OnUseFinished", vOnUseFinished);

}

void vOnUseFinished(const char[] output, int caller, int activator, float delay)
{
	g_iPourGasAmount++;
	if(g_iPourGasAmount == g_iNumGascans)
	{
		SetEntProp(g_iTargetDoor, Prop_Send, "m_glowColorOverride", iGetColorInt(0, 255, 0));

		int iEntRef;
		int iLength = g_aLastDoor.Length;
		for(int i; i < iLength; i++)
		{
			if(bIsValidEntRef((iEntRef = g_aLastDoor.Get(i, 0))))
			{
				SetEntProp(iEntRef, Prop_Data, "m_hasUnlockSequence", 0);
				AcceptEntityInput(iEntRef, "Unlock");
	
				SetEntPropFloat(iEntRef, Prop_Data, "m_flSpeed", g_aLastDoor.Get(i, 1));
				SetEntProp(iEntRef, Prop_Send, "m_spawnflags", g_aLastDoor.Get(i, 2));
			}
		}
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
	if(entity == -1) 
		return;

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
	if(entity == -1)
		return;

	DispatchKeyValueVector(entity, "origin", vOrigin);
	DispatchKeyValue(entity, "targetname", "scavenge_gascans_spawn");
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "solid", "6");
	DispatchKeyValue(entity, "skin", "0");
	DispatchKeyValue(entity, "model", "models/props_junk/gascan001a.mdl");
	DispatchKeyValue(entity, "glowstate", "3");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "body", "0");
	DispatchKeyValue(entity, "angles", "0 0 0");
	DispatchSpawn(entity);

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
	if(g_iTheCount == 0)
		PrintToServer("当前地图NavArea数量为0, 可能是某些测试地图");

	g_pTheNavAreas = view_as<Address>(LoadFromAddress(pTheCount + view_as<Address>(4), NumberType_Int32));
	if(g_pTheNavAreas == Address_Null)
		SetFailState("Failed to find address: TheNavAreas");

	delete hGameData;
}

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