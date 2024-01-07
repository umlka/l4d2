#pragma semicolon 1

#include <sourcemod>
//#include <sdktools>
#include <left4dhooks>

//#define DEBUG

#define PLUGIN_NAME           "[L4D2] Boss Spawn"
#define PLUGIN_AUTHOR         "xZk"
#define PLUGIN_DESCRIPTION    "Spawn bosses(Tank/Witch) depending on the progress of the map"
#define PLUGIN_VERSION        "1.3.0"
#define PLUGIN_URL            "https://forums.alliedmods.net/showthread.php?t=323402"

#define SPAWN_NO_PREFERENCE					   -1
#define SPAWN_ANYWHERE							0
#define SPAWN_BEHIND_SURVIVORS					1
#define SPAWN_NEAR_IT_VICTIM					2
#define SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS	3
#define SPAWN_SPECIALS_ANYWHERE					4
#define SPAWN_FAR_AWAY_FROM_SURVIVORS			5
#define SPAWN_ABOVE_SURVIVORS					6
#define SPAWN_IN_FRONT_OF_SURVIVORS				7
#define SPAWN_VERSUS_FINALE_DISTANCE			8
#define SPAWN_LARGE_VOLUME						9
#define SPAWN_NEAR_POSITION						10

Handle
	g_hTimerCheckFlow,
	g_hTimerCheckWitch;

ArrayList
	g_aWitches;

ConVar
	cvarPluginEnable,
	cvarTotalTanks,
	cvarTotalTanksRandom,
	cvarTanks,
	cvarTanksRandom,
	cvarTanksChance,
	cvarCheckTanks,
	cvarStartTanks,
	cvarFinaleTanks,
	cvarRangeMinTank,
	cvarRangeMaxTank,
	cvarTotalWitches,
	cvarTotalWitchesRandom,
	cvarWitches,
	cvarWitchesRandom,
	cvarWitchesChance,
	cvarCheckWitches,
	cvarStartWitches,
	cvarFinaleWitches,
	cvarRangeMinWitch,
	cvarRangeMaxWitch,
	cvarRangeRandom,
	cvarInterval;

bool
	g_bPluginEnable,
	g_bCheckTanks,
	g_bCheckWitches,
	g_bStartTanks,
	g_bStartWitches,
	g_bRangeRandom;

int
	g_iFinaleTanks,
	g_iFinaleWitches,
	g_iTanks,
	g_iTanksRandom,
	g_iTanksChance,
	g_iWitches,
	g_iWitchesRandom,
	g_iWitchesChance,
	g_iTotalTanks,
	g_iTotalTanksRandom,
	g_iTotalWitches,
	g_iTotalWitchesRandom;

float
	g_fFlowPercentMinTank,
	g_fFlowPercentMaxTank,
	g_fFlowPercentMinWitch,
	g_fFlowPercentMaxWitch,
	g_fInterval;

float
	g_fFurthestSurvivorFlow,
	g_fFlowRangeMinTank,
	g_fFlowRangeMinWitch,
	g_fFlowRangeMaxWitch,
	g_fFlowRangeMaxTank,
	g_fFlowRangeSpawnTank,
	g_fFlowRangeSpawnWitch,
	g_fFlowSpawnTank,
	g_fFlowSpawnWitch,
	g_fFlowCanSpawnTank,
	g_fFlowCanSpawnWitch;

int
	g_iTankCounter,
	g_iWitchCounter,
	g_iMaxTanks,
	g_iMaxWitches,
	g_iDirection;

bool
	g_bFinaleStarts,
	g_bAllowSpawnTanks,
	g_bAllowSpawnWitches,
	g_bChekingFlow,
	g_bInSpawnTime,
	g_bIsFinalMap,
	g_bIsFirstMap;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_aWitches = new ArrayList();

	cvarPluginEnable       = CreateConVar("boss_spawn", "1", "0:Disable, 1:Enable Plugin", FCVAR_NONE, true, 0.0, true, 1.0 );
	cvarInterval           = CreateConVar("boss_spawn_interval", "1.0", "Set interval time check to spawn", FCVAR_NONE, true, 0.1);
	cvarTanks              = CreateConVar("boss_spawn_tanks", "1", "Set Tanks to spawn simultaneously");
	cvarTanksRandom        = CreateConVar("boss_spawn_tanks_rng", "0", "Set max random Tanks to spawn simultaneously, 0:Disable Random value");
	cvarTanksChance        = CreateConVar("boss_spawn_tanks_chance", "100", "Setting chance (0-100)% to spawn Tanks", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarWitches            = CreateConVar("boss_spawn_witches", "1", "Set Witches to spawn simultaneously");
	cvarWitchesRandom      = CreateConVar("boss_spawn_witches_rng", "0", "Set max random Witches to spawn simultaneously, 0:Disable Random value");
	cvarWitchesChance      = CreateConVar("boss_spawn_witches_chance", "100", "Setting chance (0-100)% to spawn Witches", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarTotalTanks         = CreateConVar("boss_spawn_total_tanks", "1", "Set total Tanks to spawn on map");
	cvarTotalTanksRandom   = CreateConVar("boss_spawn_total_tanks_rng", "0", "Set max random value total Tanks on map, 0:Disable Random value");
	cvarTotalWitches       = CreateConVar("boss_spawn_total_witches", "3", "Set total Witches to spawn on map");
	cvarTotalWitchesRandom = CreateConVar("boss_spawn_total_witches_rng", "10", "Set max random value total Witches on map, 0:Disable Random value");
	cvarCheckTanks         = CreateConVar("boss_spawn_check_tanks", "0", "0:Checking any Tanks spawned on map, 1:Checking only boss spawn Tanks");
	cvarCheckWitches       = CreateConVar("boss_spawn_check_witches", "0", "0:Checking any Witches spawned on map, 1:Checking only boss spawn Witches");
	cvarStartTanks         = CreateConVar("boss_spawn_start_tanks", "1", "0:Disable Tanks in first map, 1:Allow Tanks in first map");
	cvarFinaleTanks        = CreateConVar("boss_spawn_finale_tanks", "0", "0:Disable tanks in finale map, 1:Allow before finale starts, 2:Allow after finale starts, 3:Allow all finale map");
	cvarStartWitches       = CreateConVar("boss_spawn_start_witches", "1", "0:Disable Witches in first map, 1:Allow Witches in first map");
	cvarFinaleWitches      = CreateConVar("boss_spawn_finale_witches", "1", "0:Disable witches in finale map, 1:Allow before finale starts, 2: Allow after finale starts, 3:Allow all finale map");
	cvarRangeMinTank       = CreateConVar("boss_spawn_range_min_tank", "15.0", "Set progress (0-100)% min of the distance map to can spawn Tank", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarRangeMaxTank       = CreateConVar("boss_spawn_range_max_tank", "80.0", "Set progress (0-100)% max of the distance map to can spawn Tank", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarRangeMinWitch      = CreateConVar("boss_spawn_range_min_witch", "5.0", "Set progress (0-100)% min of the distance map to can spawn Witch", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarRangeMaxWitch      = CreateConVar("boss_spawn_range_max_witch", "95.0", "Set progress (0-100)% max of the distance map to can spawn Witch", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarRangeRandom        = CreateConVar("boss_spawn_range_random", "1", "0:Set distribute spawning points evenly between each, 1:Set random range between spawning points", FCVAR_NONE, true, 0.0, true, 1.0);
	
	//AutoExecConfig(true, "l4d2_boss_spawn");
	
	cvarPluginEnable.AddChangeHook(CvarChanged_Enable);
	cvarInterval.AddChangeHook(CvarsChanged);    
	cvarTanks.AddChangeHook(CvarsChanged);        
	cvarTanksRandom.AddChangeHook(CvarsChanged);
	cvarTanksChance.AddChangeHook(CvarsChanged);
	cvarWitches.AddChangeHook(CvarsChanged);        
	cvarWitchesRandom.AddChangeHook(CvarsChanged);
	cvarWitchesChance.AddChangeHook(CvarsChanged);
	cvarTotalTanks.AddChangeHook(CvarsChanged);        
	cvarTotalTanksRandom.AddChangeHook(CvarsChanged);  
	cvarCheckTanks.AddChangeHook(CvarsChanged);   
	cvarTotalWitches.AddChangeHook(CvarsChanged);      
	cvarTotalWitchesRandom.AddChangeHook(CvarsChanged);
	cvarCheckWitches.AddChangeHook(CvarsChanged);
	cvarStartTanks.AddChangeHook(CvarsChanged);
	cvarFinaleTanks.AddChangeHook(CvarsChanged);
	cvarStartWitches.AddChangeHook(CvarsChanged);
	cvarFinaleWitches.AddChangeHook(CvarsChanged);
	cvarRangeMinTank.AddChangeHook(CvarsChanged);  
	cvarRangeMaxTank.AddChangeHook(CvarsChanged);  
	cvarRangeMinWitch.AddChangeHook(CvarsChanged); 
	cvarRangeMaxWitch.AddChangeHook(CvarsChanged);
	cvarRangeRandom.AddChangeHook(CvarsChanged);
	
	EnablePlugin();
}

public void OnPluginEnd() {
	FindConVar("director_no_bosses").RestoreDefault();
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	if (!g_bInSpawnTime)
		return Plugin_Continue;

	if (strcmp(key, "PreferredSpecialDirection", false) == 0) {
		retVal = g_iDirection;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnConfigsExecuted() {
	FindConVar("director_no_bosses").IntValue = 1;
}

void CvarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_bPluginEnable = convar.BoolValue;
	if (g_bPluginEnable && oldValue[0] == '0')
		EnablePlugin();
	else if (!g_bPluginEnable && oldValue[0] == '1')
		DisablePlugin();
}

void CvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvarsValues();
}

void EnablePlugin() {
	g_bPluginEnable = cvarPluginEnable.BoolValue;
	if (g_bPluginEnable){
		HookEvent("round_start", Event_RoundStart);
		HookEvent("round_end", Event_RoundEnd);
		HookEvent("map_transition", Event_RoundEnd);
		HookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint);
		HookEvent("player_left_start_area", Event_PlayerLeftCheckpoint);
		HookEvent("tank_spawn", Event_TankSpawn);
		HookEvent("witch_spawn", Event_WitchSpawn);
		HookEntityOutput("trigger_finale", "FinaleStart", EntityOutput_FinaleStart);
	}
	GetCvarsValues();
}

void DisablePlugin() {
	UnhookEvent("round_start", Event_RoundStart);
	UnhookEvent("round_end", Event_RoundEnd);
	UnhookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint);
	UnhookEvent("player_left_start_area", Event_PlayerLeftCheckpoint);
	UnhookEvent("tank_spawn", Event_TankSpawn);
	UnhookEvent("witch_spawn", Event_WitchSpawn);
	UnhookEntityOutput("trigger_finale", "FinaleStart", EntityOutput_FinaleStart);
	g_aWitches.Clear();
	delete g_hTimerCheckFlow;
	delete g_hTimerCheckWitch;
}

void GetCvarsValues() {
	g_bRangeRandom = cvarRangeRandom.BoolValue;
	g_bCheckTanks = cvarCheckTanks.BoolValue;
	g_bCheckWitches = cvarCheckWitches.BoolValue;
	g_bStartTanks = cvarStartTanks.BoolValue;
	g_bStartWitches = cvarStartWitches.BoolValue;
	g_iTanks = cvarTanks.IntValue;
	g_iTanksRandom = cvarTanksRandom.IntValue;
	g_iTanksChance = cvarTanksChance.IntValue;
	g_iWitches = cvarWitches.IntValue;
	g_iWitchesRandom = cvarWitchesRandom.IntValue;
	g_iWitchesChance = cvarWitchesChance.IntValue;
	g_iTotalTanks = cvarTotalTanks.IntValue;
	g_iTotalTanksRandom = cvarTotalTanksRandom.IntValue;
	g_iTotalWitches = cvarTotalWitches.IntValue;
	g_iTotalWitchesRandom = cvarTotalWitchesRandom.IntValue;
	g_iFinaleTanks = cvarFinaleTanks.IntValue;
	g_iFinaleWitches = cvarFinaleWitches.IntValue;
	g_fFlowPercentMinTank = cvarRangeMinTank.FloatValue;
	g_fFlowPercentMaxTank = cvarRangeMaxTank.FloatValue;
	g_fFlowPercentMinWitch = cvarRangeMinWitch.FloatValue;
	g_fFlowPercentMaxWitch = cvarRangeMaxWitch.FloatValue;
	g_fInterval = cvarInterval.FloatValue;
}

public void OnMapStart() {
	g_bIsFinalMap = L4D_IsMissionFinalMap();
	g_bIsFirstMap = L4D_IsFirstMapInScenario();
}

public void OnMapEnd() {
	g_aWitches.Clear();
	delete g_hTimerCheckFlow;
	delete g_hTimerCheckWitch;
	g_iTankCounter = 0;
	g_iWitchCounter = 0;
	g_fFlowSpawnTank = 0.0;
	g_fFlowSpawnWitch = 0.0;
	g_bFinaleStarts = false;
	g_bChekingFlow = false;
}

void EntityOutput_FinaleStart(const char[] output, int caller, int activator, float time) {
	g_bFinaleStarts = true;
	g_bAllowSpawnTanks = (g_iFinaleTanks == 3 || g_bFinaleStarts && g_iFinaleTanks == 2 );
	g_bAllowSpawnWitches = (g_iFinaleWitches == 3 || g_bFinaleStarts && g_iFinaleWitches == 2 ); 
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bCheckTanks)
		g_iTankCounter++;
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bCheckWitches)
		g_iWitchCounter++;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_PlayerLeftCheckpoint(Event event, const char[] name, bool dontBroadcast) {
	if (g_bChekingFlow)
		return;
	
	if ((g_bIsFirstMap && !g_bStartTanks && !g_bStartWitches) || (g_bIsFinalMap && !g_iFinaleTanks && !g_iFinaleWitches)){
		g_aWitches.Clear();
		delete g_hTimerCheckFlow;
		delete g_hTimerCheckWitch;
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	g_bAllowSpawnTanks = (g_bStartTanks && g_bIsFirstMap || !g_bIsFirstMap) && (g_iFinaleTanks == 3 || !g_bIsFinalMap || !g_bFinaleStarts && g_iFinaleTanks == 1);
	g_bAllowSpawnWitches = (g_bStartWitches && g_bIsFirstMap || !g_bIsFirstMap) && (g_iFinaleWitches == 3 || !g_bIsFinalMap || !g_bFinaleStarts && g_iFinaleWitches == 1); 
	CreateTimer(0.1, tmrStartCheckFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action tmrStartCheckFlow(Handle timer){
	if (g_bChekingFlow || !L4D_HasAnySurvivorLeftSafeArea())
		return Plugin_Stop;

	g_bChekingFlow = true;
	g_bFinaleStarts = false;
	g_iTankCounter = 0;
	g_iWitchCounter = 0;
	g_fFlowSpawnTank = 0.0;
	g_fFlowSpawnWitch = 0.0;
	g_iMaxTanks = !g_iTotalTanksRandom ? g_iTotalTanks : GetRandomInt(g_iTotalTanks, g_iTotalTanksRandom);
	g_iMaxWitches = !g_iTotalWitchesRandom ? g_iTotalWitches : GetRandomInt(g_iTotalWitches, g_iTotalWitchesRandom);

	float fMapMaxFlow = L4D2Direct_GetMapMaxFlowDistance();
	g_fFlowRangeMinTank = fMapMaxFlow * g_fFlowPercentMinTank / 100.0;
	g_fFlowRangeMaxTank = fMapMaxFlow * g_fFlowPercentMaxTank / 100.0;
	g_fFlowRangeSpawnTank = (g_fFlowRangeMaxTank-g_fFlowRangeMinTank)/float(g_iMaxTanks);
	g_fFlowCanSpawnTank = g_fFlowRangeMinTank;
	
	g_fFlowRangeMinWitch = fMapMaxFlow * g_fFlowPercentMinWitch / 100.0;
	g_fFlowRangeMaxWitch = fMapMaxFlow * g_fFlowPercentMaxWitch / 100.0;
	g_fFlowRangeSpawnWitch = (g_fFlowRangeMaxWitch-g_fFlowRangeMinWitch) / float(g_iMaxWitches);
	g_fFlowCanSpawnWitch = g_fFlowRangeMinWitch;
	
	delete g_hTimerCheckFlow;
	g_hTimerCheckFlow = CreateTimer(g_fInterval, tmrCheckFlow, _, TIMER_REPEAT);

	delete g_hTimerCheckWitch;
	g_hTimerCheckWitch = CreateTimer(10.0, tmrCheckWitch, _, TIMER_REPEAT);
	return Plugin_Continue;
}

Action tmrCheckWitch(Handle timer) {
	static int i;
	static int witch;
	static int entRef;
	static Address area;
	static float fDist;
	static float vPos[3];
	static float vWitch[3];

	static int client;
	static float flow;
	static float lastFlow;
	static ArrayList aList;

	aList = new ArrayList(2);
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			flow = L4D2Direct_GetFlowDistance(i);
			if (flow && flow != -9999.0)
			aList.Set(aList.Push(flow), i, 1);
		}
	}

	static int count;
	count = aList.Length;
	if (!count) {
		delete aList;
		return Plugin_Continue;
	}

	aList.Sort(Sort_Ascending, Sort_Float);
	client = aList.Get(0, 1);
	lastFlow = aList.Get(0, 0);
	delete aList;

	i = 0;
	witch = 0;
	count = g_aWitches.Length;
	while (i < count) {
		if (EntRefToEntIndex((entRef =g_aWitches.Get(i))) == INVALID_ENT_REFERENCE) {
			g_aWitches.Erase(i);
			count--;
			continue;
		}
		else {
			GetEntPropVector(entRef, Prop_Send, "m_vecOrigin", vWitch);
			area = L4D_GetNearestNavArea(vWitch);
			if (!area) {
				RemoveEntity(entRef);
				g_aWitches.Erase(i);
				count--;
				continue;
			}

			fDist = L4D2Direct_GetTerrorNavAreaFlow(area);
			if (fDist == -9999.0 || lastFlow - fDist > 1800.0) {
				RemoveEntity(entRef);
				g_aWitches.Erase(i);
				count--;
				continue;
			}

			GetClientAbsOrigin(client, vPos);
			fDist = L4D2_NavAreaTravelDistance(vPos, vWitch, false);
			if (fDist == -1.0 || fDist > 3600.0) {
				RemoveEntity(entRef);
				g_aWitches.Erase(i);
				count--;
				continue;
			}

			i++;
			witch++;
		}
	}

	return Plugin_Continue;
}

Action tmrCheckFlow(Handle timer) {
	if (g_iTankCounter >= g_iMaxTanks && g_iWitchCounter >= g_iMaxWitches) {
		g_hTimerCheckFlow = null;
		return Plugin_Stop;
	}

	static int i;
	static int count;
	static int highest;
	highest = L4D_GetHighestFlowSurvivor();
	g_fFurthestSurvivorFlow = highest != -1 ? L4D2Direct_GetFlowDistance(highest) : L4D2_GetFurthestSurvivorFlow();

	if (g_bAllowSpawnTanks && (g_iMaxTanks && g_iTankCounter < g_iMaxTanks) && (g_fFurthestSurvivorFlow >= g_fFlowRangeMinTank && g_fFurthestSurvivorFlow <= g_fFlowRangeMaxTank)) {
		if (!g_fFlowSpawnTank){
			if (g_bRangeRandom)
				g_fFlowSpawnTank = GetRandomFloat(g_fFlowCanSpawnTank, g_fFlowCanSpawnTank + g_fFlowRangeSpawnTank);
			else if (!g_iTankCounter)
				g_fFlowSpawnTank = g_fFlowCanSpawnTank;
			else
				g_fFlowSpawnTank = g_fFlowCanSpawnTank+g_fFlowRangeSpawnTank;
		}
		
		if (g_fFurthestSurvivorFlow >= g_fFlowSpawnTank){
			count = !g_iTanksRandom ? g_iTanks : GetRandomInt(g_iTanks, g_iTanksRandom);
			for(i = 0; i < count; i++){
				if (g_iTanksChance < GetRandomInt(1,100) || SpawnTank(highest) < 1)
					continue;

				g_fFlowCanSpawnTank = g_fFlowCanSpawnTank+g_fFlowRangeSpawnTank;
				g_fFlowSpawnTank = 0.0;
				if (g_bCheckTanks)
					g_iTankCounter++;
			}
		}
	}
	
	if (g_bAllowSpawnWitches && (g_iMaxWitches && g_iWitchCounter < g_iMaxWitches) && (g_fFurthestSurvivorFlow >= g_fFlowRangeMinWitch && g_fFurthestSurvivorFlow <= g_fFlowRangeMaxWitch)) {
		float flowrange = g_fFlowCanSpawnWitch + g_fFlowRangeSpawnWitch;
		if (!g_fFlowSpawnWitch)
			g_fFlowSpawnWitch = GetRandomFloat(g_fFlowCanSpawnWitch, flowrange);// get flowspawn once
		
		if (g_fFurthestSurvivorFlow >= g_fFlowSpawnWitch){
			count = !g_iWitchesRandom ? g_iWitches : GetRandomInt(g_iWitches, g_iWitchesRandom);

			static int witch;
			for(i = 0; i < count; i++) {
				if (g_iWitchesChance < GetRandomInt(1,100))
					continue;

				witch = SpawnWitch(highest);
				if (witch == -1)
					continue;
				
				g_aWitches.Push(EntIndexToEntRef(witch));
				g_fFlowCanSpawnWitch = flowrange;
				g_fFlowSpawnWitch = 0.0;
				if (g_bCheckWitches)
					g_iWitchCounter++;
			}
		}
	}
	
	return Plugin_Continue;
}

int SpawnTank(int client) {
	bool success;
	float vecPos[3];
	g_bInSpawnTime = true;
	g_iDirection = SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS;
	if (client != -1)
		success = L4D_GetRandomPZSpawnPosition(client, 7, 10, vecPos);//7: does not find spawn point in some places for witch

	if (!success)
		success = L4D_GetRandomPZSpawnPosition(client, 8, 10, vecPos);

	if (!success) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || GetClientTeam(i) != 2)
				continue;

			g_iDirection = SPAWN_SPECIALS_ANYWHERE;
			success = L4D_GetRandomPZSpawnPosition(i, 7, 10, vecPos);//7: does not find spawn point in some places for witch
			if (!success)
				success = L4D_GetRandomPZSpawnPosition(i, 8, 10, vecPos);

			if (success)
				break;
		}
	}

	g_bInSpawnTime = false;
	if (success)
		return L4D2_SpawnTank(vecPos, NULL_VECTOR);

	return 0;
}

int SpawnWitch(int client) {
	bool success;
	float vecPos[3];
	g_bInSpawnTime = true;
	g_iDirection = SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS;
	if (client != -1)
		success = L4D_GetRandomPZSpawnPosition(client, 8, 10, vecPos);//7: does not find spawn point in some places for witch

	if (!success) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || GetClientTeam(i) != 2)
				continue;

			g_iDirection = SPAWN_IN_FRONT_OF_SURVIVORS;
			success = L4D_GetRandomPZSpawnPosition(i, 7, 10, vecPos);//7: does not find spawn point in some places for witch
			if (!success)
				success = L4D_GetRandomPZSpawnPosition(i, 8, 10, vecPos);

			if (success)
				break;
		}
	}

	g_bInSpawnTime = false;
	if (success)
		return CreateWitch(vecPos);

	return -1;
}

int CreateWitch(const float vPos[3]) {
	int witch = CreateEntityByName("witch");
	if (witch != -1) {
		SetAbsOrigin(witch, vPos);

		static float vAng[3];
		vAng[1] = GetRandomFloat(-179.0, 179.0);
		SetAbsAngles(witch, vAng);
		DispatchSpawn(witch);
	}
	
	return witch;
}
