#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
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

ConVar cvarPluginEnable, cvarTotalTanks, cvarTotalTanksRandom, cvarTanks, cvarTanksRandom, cvarTanksChance, cvarCheckTanks, cvarStartTanks, cvarFinaleTanks, cvarRangeMinTank, cvarRangeMaxTank, cvarTotalWitches, cvarTotalWitchesRandom, cvarWitches, cvarWitchesRandom, cvarWitchesChance, cvarCheckWitches, cvarStartWitches, cvarFinaleWitches, cvarRangeMinWitch, cvarRangeMaxWitch, cvarRangeRandom, cvarInterval;
bool g_bPluginEnable; bool g_bCheckTanks; bool g_bCheckWitches; bool g_bStartTanks; bool g_bStartWitches; bool g_bRangeRandom; int g_iFinaleTanks; int g_iFinaleWitches; int g_iTanks; int g_iTanksRandom; int g_iTanksChance; int g_iWitches; int g_iWitchesRandom; int g_iWitchesChance; int g_iTotalTanks; int g_iTotalTanksRandom; int g_iTotalWitches; int g_iTotalWitchesRandom; float g_fFlowPercentMinTank;  float g_fFlowPercentMaxTank;  float g_fFlowPercentMinWitch; float g_fFlowPercentMaxWitch; float g_fInterval;

Handle g_hTimerCheckFlow;
float g_fFlowMaxMap;
float g_fFlowPlayers;
float g_fFlowRangeMinTank;
float g_fFlowRangeMinWitch;
float g_fFlowRangeMaxWitch;
float g_fFlowRangeMaxTank;
float g_fFlowRangeSpawnTank;
float g_fFlowRangeSpawnWitch;
float g_fFlowSpawnTank;
float g_fFlowSpawnWitch;
float g_fFlowCanSpawnTank;
float g_fFlowCanSpawnWitch;
int g_iTankCounter;
int g_iWitchCounter;
int g_iMaxTanks;
int g_iMaxWitches;
int g_iPlayerHighestFlow;
int g_iPreferredDirection;
bool g_bFinaleStarts;
bool g_bAllowSpawnTanks;
bool g_bAllowSpawnWitches;
bool g_bChekingFlow;
bool g_bInSpawnTime;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	cvarPluginEnable       = CreateConVar("boss_spawn", "1", "0:Disable, 1:Enable Plugin", FCVAR_NONE, true, 0.0, true, 1.0 );
	cvarInterval           = CreateConVar("boss_spawn_interval", "0.5", "Set interval time check to spawn", FCVAR_NONE, true, 0.1);
	cvarTanks              = CreateConVar("boss_spawn_tanks", "1", "Set Tanks to spawn simultaneously");
	cvarTanksRandom        = CreateConVar("boss_spawn_tanks_rng", "0", "Set max random Tanks to spawn simultaneously, 0:Disable Random value");
	cvarTanksChance        = CreateConVar("boss_spawn_tanks_chance", "100", "Setting chance (0-100)% to spawn Tanks", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarWitches            = CreateConVar("boss_spawn_witches", "1", "Set Witches to spawn simultaneously");
	cvarWitchesRandom      = CreateConVar("boss_spawn_witches_rng", "0", "Set max random Witches to spawn simultaneously, 0:Disable Random value");
	cvarWitchesChance      = CreateConVar("boss_spawn_witches_chance", "100", "Setting chance (0-100)% to spawn Witches", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarTotalTanks         = CreateConVar("boss_spawn_total_tanks", "1", "Set total Tanks to spawn on map");
	cvarTotalTanksRandom   = CreateConVar("boss_spawn_total_tanks_rng", "3", "Set max random value total Tanks on map, 0:Disable Random value");
	cvarTotalWitches       = CreateConVar("boss_spawn_total_witches", "1", "Set total Witches to spawn on map");
	cvarTotalWitchesRandom = CreateConVar("boss_spawn_total_witches_rng", "3", "Set max random value total Witches on map, 0:Disable Random value");
	cvarCheckTanks         = CreateConVar("boss_spawn_check_tanks", "0", "0:Checking any Tanks spawned on map, 1:Checking only boss spawn Tanks");
	cvarCheckWitches       = CreateConVar("boss_spawn_check_witches", "0", "0:Checking any Witches spawned on map, 1:Checking only boss spawn Witches");
	cvarStartTanks         = CreateConVar("boss_spawn_start_tanks", "1", "0:Disable Tanks in first map, 1:Allow Tanks in first map");
	cvarFinaleTanks        = CreateConVar("boss_spawn_finale_tanks", "0", "0:Disable tanks in finale map, 1:Allow before finale starts, 2:Allow after finale starts, 3:Allow all finale map");
	cvarStartWitches       = CreateConVar("boss_spawn_start_witches", "1", "0:Disable Witches in first map, 1:Allow Witches in first map");
	cvarFinaleWitches      = CreateConVar("boss_spawn_finale_witches", "0", "0:Disable witches in finale map, 1:Allow before finale starts, 2: Allow after finale starts, 3:Allow all finale map");
	cvarRangeMinTank       = CreateConVar("boss_spawn_range_min_tank", "0.0", "Set progress (0-100)% min of the distance map to can spawn Tank", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarRangeMaxTank       = CreateConVar("boss_spawn_range_max_tank", "100.0", "Set progress (0-100)% max of the distance map to can spawn Tank", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarRangeMinWitch      = CreateConVar("boss_spawn_range_min_witch", "0.0", "Set progress (0-100)% min of the distance map to can spawn Witch", FCVAR_NONE, true, 0.0, true, 100.0);
	cvarRangeMaxWitch      = CreateConVar("boss_spawn_range_max_witch", "100.0", "Set progress (0-100)% max of the distance map to can spawn Witch", FCVAR_NONE, true, 0.0, true, 100.0);
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

public void OnPluginEnd()
{
	FindConVar("director_no_bosses").RestoreDefault();
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if(!g_bInSpawnTime)
		return Plugin_Continue;

	static int iValue;

	iValue = retVal;
	if(strcmp(key, "PreferredSpecialDirection", false) == 0)
		iValue = g_iPreferredDirection;

	if(iValue != retVal)
	{
		retVal = iValue;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	FindConVar("director_no_bosses").IntValue = 1;
}

public void CvarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bPluginEnable = convar.BoolValue;
	if (g_bPluginEnable && oldValue[0] == '0')
		EnablePlugin();
	else if (!g_bPluginEnable && oldValue[0] == '1')
		DisablePlugin();
}

public void CvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue){
	GetCvarsValues();
}

void EnablePlugin(){
	g_bPluginEnable = cvarPluginEnable.BoolValue;
	if(g_bPluginEnable){
		HookEvent("round_start", Event_RoundStart);
		HookEvent("round_end", Event_RoundEnd);
		HookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint);
		HookEvent("player_left_start_area", Event_PlayerLeftCheckpoint);
		//HookEvent("finale_start", Event_FinaleStart);//doesn't work all finales
		HookEvent("tank_spawn", Event_TankSpawn);
		HookEvent("witch_spawn", Event_WitchSpawn);
		HookEntityOutput("trigger_finale", "FinaleStart", EntityOutput_FinaleStart);
	}
	GetCvarsValues();
}

void DisablePlugin(){
	UnhookEvent("round_start", Event_RoundStart);
	UnhookEvent("round_end", Event_RoundEnd);
	UnhookEvent("player_left_checkpoint", Event_PlayerLeftCheckpoint);
	UnhookEvent("player_left_start_area", Event_PlayerLeftCheckpoint);
	//UnhookEvent("finale_start", Event_FinaleStart);
	UnhookEvent("tank_spawn", Event_TankSpawn);
	UnhookEvent("witch_spawn", Event_WitchSpawn);
	UnhookEntityOutput("trigger_finale", "FinaleStart", EntityOutput_FinaleStart);
	delete g_hTimerCheckFlow;
}

void GetCvarsValues(){
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

public void OnMapEnd()
{
	delete g_hTimerCheckFlow;
	g_iTankCounter = 0;
	g_iWitchCounter = 0;
	g_fFlowSpawnTank = 0.0;
	g_fFlowSpawnWitch = 0.0;
	g_bFinaleStarts = false;
	g_bChekingFlow = false;
}

public void EntityOutput_FinaleStart(const char[] output, int caller, int activator, float time)
{
	g_bFinaleStarts = true;
	g_bAllowSpawnTanks = (g_iFinaleTanks == 3 || g_bFinaleStarts && g_iFinaleTanks == 2 );
	g_bAllowSpawnWitches = (g_iFinaleWitches == 3 || g_bFinaleStarts && g_iFinaleWitches == 2 ); 
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bCheckTanks)
		g_iTankCounter++;
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(!g_bCheckWitches)
		g_iWitchCounter++;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimerCheckFlow;
	g_iTankCounter = 0;
	g_iWitchCounter = 0;
	g_fFlowSpawnTank = 0.0;
	g_fFlowSpawnWitch = 0.0;
	g_bFinaleStarts = false;
	g_bChekingFlow = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimerCheckFlow;
	g_iTankCounter = 0;
	g_iWitchCounter = 0;
	g_fFlowSpawnTank = 0.0;
	g_fFlowSpawnWitch = 0.0;
	g_bFinaleStarts = false;
	g_bChekingFlow = false;
}

public void Event_PlayerLeftCheckpoint(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bChekingFlow){
		return;
	}
	
	if((L4D_IsFirstMapInScenario() && !g_bStartTanks && !g_bStartWitches) 
	|| (L4D_IsMissionFinalMap() && !g_iFinaleTanks && !g_iFinaleWitches) 
	){
		delete g_hTimerCheckFlow;
		return;
	}
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidSurvivor(client)){
		return;
	}
	g_bAllowSpawnTanks = (g_bStartTanks && L4D_IsFirstMapInScenario() || !L4D_IsFirstMapInScenario()) 
							&& (g_iFinaleTanks == 3 || !L4D_IsMissionFinalMap() || !g_bFinaleStarts && g_iFinaleTanks == 1 );

	g_bAllowSpawnWitches = (g_bStartWitches && L4D_IsFirstMapInScenario() || !L4D_IsFirstMapInScenario())
							&& (g_iFinaleWitches == 3 || !L4D_IsMissionFinalMap() || !g_bFinaleStarts && g_iFinaleWitches == 1  ); 
	CreateTimer(0.1, StartCheckFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action StartCheckFlow(Handle timer){
	
	if(g_bChekingFlow || !L4D_HasAnySurvivorLeftSafeArea()){
		return Plugin_Stop;
	}
	g_bChekingFlow = true;
	g_bFinaleStarts = false;
	g_iTankCounter = 0;
	g_iWitchCounter = 0;
	g_fFlowSpawnTank = 0.0;
	g_fFlowSpawnWitch = 0.0;
	g_fFlowMaxMap = L4D2Direct_GetMapMaxFlowDistance();
	g_iMaxTanks = !g_iTotalTanksRandom ? g_iTotalTanks : GetRandomInt(g_iTotalTanks, g_iTotalTanksRandom);
	g_iMaxWitches = !g_iTotalWitchesRandom ? g_iTotalWitches : GetRandomInt(g_iTotalWitches, g_iTotalWitchesRandom);
	
	g_fFlowRangeMinTank = g_fFlowMaxMap * g_fFlowPercentMinTank/100.0;
	g_fFlowRangeMaxTank = g_fFlowMaxMap * g_fFlowPercentMaxTank/100.0;
	g_fFlowRangeSpawnTank = (g_fFlowRangeMaxTank-g_fFlowRangeMinTank)/float(g_iMaxTanks);
	g_fFlowCanSpawnTank = g_fFlowRangeMinTank;
	
	g_fFlowRangeMinWitch = g_fFlowMaxMap * g_fFlowPercentMinWitch/100.0;
	g_fFlowRangeMaxWitch = g_fFlowMaxMap * g_fFlowPercentMaxWitch/100.0;
	g_fFlowRangeSpawnWitch = (g_fFlowRangeMaxWitch-g_fFlowRangeMinWitch)/float(g_iMaxWitches);
	g_fFlowCanSpawnWitch = g_fFlowRangeMinWitch;
	
	delete g_hTimerCheckFlow;
	g_hTimerCheckFlow = CreateTimer(g_fInterval, TimerCheckFlow, _, TIMER_REPEAT);
	return Plugin_Continue;
}

public Action TimerCheckFlow(Handle timer)
{
	if(g_iTankCounter >= g_iMaxTanks && g_iWitchCounter >= g_iMaxWitches) {
		g_hTimerCheckFlow = null;
		return Plugin_Stop;
	}
	g_iPlayerHighestFlow = L4D_GetHighestFlowSurvivor();
	if(IsValidSurvivor(g_iPlayerHighestFlow)){
		g_fFlowPlayers = L4D2Direct_GetFlowDistance(g_iPlayerHighestFlow);
	}else{
		g_fFlowPlayers = L4D2_GetFurthestSurvivorFlow();
	}
	//PrintToConsoleAll("playersflow: %f ", g_fFlowPlayers);
	if(g_bAllowSpawnTanks 
	&& (g_iMaxTanks && g_iTankCounter < g_iMaxTanks)
	&& (g_fFlowPlayers >= g_fFlowRangeMinTank && g_fFlowPlayers <= g_fFlowRangeMaxTank)
	){
		//float flowrange = g_fFlowCanSpawnTank+g_fFlowRangeSpawnTank;
		// if(!g_fFlowSpawnTank)
		//g_fFlowSpawnTank = GetRandomFloat(g_fFlowCanSpawnTank, flowrange);
		if(!g_fFlowSpawnTank){
			if(g_bRangeRandom){
				g_fFlowSpawnTank = GetRandomFloat(g_fFlowCanSpawnTank, g_fFlowCanSpawnTank+g_fFlowRangeSpawnTank);
			}
			else if(!g_iTankCounter){
				g_fFlowSpawnTank = g_fFlowCanSpawnTank;
			}else{
				g_fFlowSpawnTank = g_fFlowCanSpawnTank+g_fFlowRangeSpawnTank;
			}
		}
		
		if(g_fFlowPlayers >= g_fFlowSpawnTank){
			int tanks = !g_iTanksRandom ? g_iTanks : GetRandomInt(g_iTanks, g_iTanksRandom);
			for(int i; i < tanks; i++){
				if(g_iTanksChance >= GetRandomInt(1,100) && SpawnTank() > 0){
					g_fFlowCanSpawnTank = g_fFlowCanSpawnTank+g_fFlowRangeSpawnTank;
					g_fFlowSpawnTank = 0.0;
					if(g_bCheckTanks)
						g_iTankCounter++;
				}
				// else{
					// PrintToConsoleAll("no spawn tank?");
				// }
			}
		}
	}
	
	if(g_bAllowSpawnWitches 
	&& (g_iMaxWitches && g_iWitchCounter < g_iMaxWitches) 
	&& (g_fFlowPlayers >= g_fFlowRangeMinWitch && g_fFlowPlayers <= g_fFlowRangeMaxWitch)
	){
		float flowrange = g_fFlowCanSpawnWitch+g_fFlowRangeSpawnWitch;
		if(!g_fFlowSpawnWitch)
			g_fFlowSpawnWitch = GetRandomFloat(g_fFlowCanSpawnWitch, flowrange);// get flowspawn once
		if(g_fFlowPlayers >= g_fFlowSpawnWitch){
			int witches = !g_iWitchesRandom ? g_iWitches : GetRandomInt(g_iWitches, g_iWitchesRandom);
			for(int i; i < witches; i++){
				if(g_iWitchesChance >= GetRandomInt(1,100) && SpawnWitch() > 0){
					g_fFlowCanSpawnWitch = flowrange;
					g_fFlowSpawnWitch = 0.0;
					if(g_bCheckWitches)
						g_iWitchCounter++;
				}
				// else{
					// PrintToConsoleAll("no spawn witch?");
				// }
			}
		}
	}
	
	return Plugin_Continue;
}

int SpawnTank(){
	g_bInSpawnTime = true;
	g_iPreferredDirection = SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS;
	bool canspawn;
	float spawnpos[3];
	//int client = L4D_GetHighestFlowSurvivor();
	if(IsValidClient(g_iPlayerHighestFlow))
	{
		canspawn = L4D_GetRandomPZSpawnPosition(g_iPlayerHighestFlow, 8, 10, spawnpos);
	}
	if(canspawn)
	{
		//PrintToConsoleAll("[BS] spawn a tank!");
		//PrintToChatAll("[BS] spawn a tank !");
		g_bInSpawnTime = false;
		return L4D2_SpawnTank(spawnpos, NULL_VECTOR);
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidSurvivor(i))
			{
				canspawn = L4D_GetRandomPZSpawnPosition(i, 8, 10, spawnpos);
				if(canspawn)
				{
					break;
				}
			} 
		}
		if(canspawn)
		{
			//PrintToConsoleAll("[BS] spawn a tank!");
			//PrintToChatAll("[BS] spawn a tank !");
			g_bInSpawnTime = false;
			return L4D2_SpawnTank(spawnpos, NULL_VECTOR);
		}/*
		else
		{
			PrintToConsoleAll("[BS] no found spawn");
			PrintToChatAll("[BS] no found spawn tank");
		}*/
	}
	return 0; 
}

int SpawnWitch(){
	g_bInSpawnTime = true;
	g_iPreferredDirection = SPAWN_IN_FRONT_OF_SURVIVORS;
	bool canspawn;
	float spawnpos[3];
	if(IsValidClient(g_iPlayerHighestFlow))
	{
		canspawn = L4D_GetRandomPZSpawnPosition(g_iPlayerHighestFlow, 7, 10, spawnpos);//7: does not find spawn point in some places for witch
		if(!canspawn)
		{
			canspawn = L4D_GetRandomPZSpawnPosition(g_iPlayerHighestFlow, 8, 10, spawnpos);
		}
	}
	if(canspawn)
	{
		// PrintToConsoleAll("[BS] spawn a witch!");
		// PrintToChatAll("[BS] spawn a witch!");
		g_bInSpawnTime = false;
		return L4D2_SpawnWitch(spawnpos, NULL_VECTOR);
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidSurvivor(i))
			{
				canspawn = L4D_GetRandomPZSpawnPosition(i, 7, 10, spawnpos);//7: does not find spawn point in some places for witch
				if(!canspawn)
				{
					canspawn = L4D_GetRandomPZSpawnPosition(i, 8, 10, spawnpos);
				}
				if(canspawn)
				{
					break;
				}
			} 
		}
		if(canspawn)
		{
			// PrintToConsoleAll("[BS] spawn a witch!");
			// PrintToChatAll("[BS] spawn a witch!");
			g_bInSpawnTime = false;
			return L4D2_SpawnWitch(spawnpos, NULL_VECTOR);
		}/*
		else
		{
			// PrintToConsoleAll("[BS] no found spawn witch");
			// PrintToChatAll("[BS] no found spawn witch");
		}*/
	}
	return 0;  
}

stock bool IsValidSpect(int client){ 
	return (IsValidClient(client) && GetClientTeam(client) == 1 );
}

stock bool IsValidSurvivor(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 2 );
}

stock bool IsValidInfected(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 3 );
}

stock bool IsValidClient(int client){
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool IsValidEnt(int entity){
	return (entity > MaxClients && IsValidEntity(entity) && entity != INVALID_ENT_REFERENCE);
}
