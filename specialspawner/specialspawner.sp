#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <binhooks>
#include <left4dhooks>

#define SPAWN_DEBUG 1

#define NUM_TYPES_INFECTED	6

#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5
#define UNINITIALISED	-1

Handle g_hSpawnTimer;

ConVar g_hSILimit;
ConVar g_hSpawnSize;
ConVar g_hSpawnLimits[NUM_TYPES_INFECTED];
ConVar g_hSpawnWeights[NUM_TYPES_INFECTED];
ConVar g_hScaleWeights;
ConVar g_hSpawnTimeMode;
ConVar g_hSpawnTimeMin;
ConVar g_hSpawnTimeMax;
ConVar g_hSIbase;
ConVar g_hSIextra;
ConVar g_hGroupbase;
ConVar g_hGroupextra;
ConVar g_hRusherDistance;
ConVar g_hTankSpawnAction;
ConVar g_hTankSpawnLimits;
ConVar g_hTankSpawnWeights;
ConVar g_hSpawnRange;
ConVar g_hDiscardRange;
ConVar g_hDirectorNoSpecials;

float g_fSpawnTimeMin;
float g_fSpawnTimeMax;
float g_fRusherDistance;
float g_fSpawnTimes[MAXPLAYERS + 1];

static char g_sZombieClass[NUM_TYPES_INFECTED][] =
{
	"smoker",
	"boomer",
	"hunter",
	"spitter",
	"jockey",
	"charger"
};

int g_iRoundStart;
int g_iPlayerSpawn;
int g_iSILimit;
int g_iSpawnSize;
int g_iSpawnLimits[NUM_TYPES_INFECTED];
int g_iSpawnWeights[NUM_TYPES_INFECTED];
int g_iSpawnTimeMode;
int g_iTankSpawnAction;
int g_iPreferredDirection = 4;

int g_iSILimitCache = UNINITIALISED;
int g_iSpawnLimitsCache[NUM_TYPES_INFECTED] =
{	
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED
};

int g_iSpawnWeightsCache[NUM_TYPES_INFECTED] =
{
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED
};

int g_iTankSpawnLimits[NUM_TYPES_INFECTED] =
{	
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED
};

int g_iTankSpawnWeights[NUM_TYPES_INFECTED] =
{	
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED,
	UNINITIALISED
};

int g_iSpawnSizeCache = UNINITIALISED;
int g_iSpawnCounts[NUM_TYPES_INFECTED];

int g_iSIbase;
int g_iSIextra;
int g_iGroupbase;
int g_iGroupextra;
int g_iCurrentClass = UNINITIALISED;

bool g_bScaleWeights;
bool g_bControlZombies;
bool g_bDirectorNoSpecials;
bool g_bHasAnySurvivorLeftSafeArea;

native bool CZ_IsSpawnablePZSupported();

public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "control_zombies") == 0)
		g_bControlZombies = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if(strcmp(name, "control_zombies") == 0)
		g_bControlZombies = false;
}

public Plugin myinfo =
{
	name = "Special Spawner",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "1.1",
	url = ""
};

void vLoadCacheSpawnLimits()
{
	if(g_iSILimitCache != UNINITIALISED)
	{
		g_hSILimit.IntValue = g_iSILimitCache;
		g_iSILimitCache = UNINITIALISED;
	}

	if(g_iSpawnSizeCache != UNINITIALISED)
	{
		g_hSpawnSize.IntValue = g_iSpawnSizeCache;
		g_iSpawnSizeCache = UNINITIALISED;
	}

	for(int i; i < NUM_TYPES_INFECTED; i++)
	{		
		if(g_iSpawnLimitsCache[i] != UNINITIALISED)
		{
			g_hSpawnLimits[i].IntValue = g_iSpawnLimitsCache[i];
			g_iSpawnLimitsCache[i] = UNINITIALISED;
		}
	}
}

void vLoadCacheSpawnWeights()
{
	for(int i; i < NUM_TYPES_INFECTED; i++)
	{		
		if(g_iSpawnWeightsCache[i] != UNINITIALISED)
		{
			g_hSpawnWeights[i].IntValue = g_iSpawnWeightsCache[i];
			g_iSpawnWeightsCache[i] = UNINITIALISED;
		}
	}
}

void vLoadCacheTankCustom()
{
	for(int i; i < NUM_TYPES_INFECTED; i++)
	{
		if(g_iTankSpawnLimits[i] != UNINITIALISED)
			g_hSpawnLimits[i].IntValue = g_iTankSpawnLimits[i];
			
		if(g_iTankSpawnWeights[i] != UNINITIALISED)
			g_hSpawnWeights[i].IntValue = g_iTankSpawnWeights[i];
	}
}

void vResetLimits()
{
	for(int i; i < NUM_TYPES_INFECTED; i++)
		g_hSpawnLimits[i].RestoreDefault();
}

void vResetWeights()
{
	for(int i; i < NUM_TYPES_INFECTED; i++)
		g_hSpawnWeights[i].RestoreDefault();
}

void vStartCustomSpawnTimer(float time)
{
	vEndSpawnTimer();
	g_hSpawnTimer = CreateTimer(time, Timer_SpawnInfectedAuto);
}

void vStartSpawnTimer()
{
	vEndSpawnTimer();
	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[iGetInfecteds()] : GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), Timer_SpawnInfectedAuto);
}

void vEndSpawnTimer()
{
	delete g_hSpawnTimer;
}

public Action Timer_SpawnInfectedAuto(Handle timer)
{ 
	g_hSpawnTimer = null;

	vGenerateAndExecuteSpawnQueue();

	vStartSpawnTimer();
}

static int iGetAnyValidClient()
{
	static int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i))
			return i;
	}
	return UNINITIALISED;
}

static void vGenerateAndExecuteSpawnQueue()
{
	static int iCurrentSI;
	iCurrentSI = iGetInfecteds();
	if(iCurrentSI < g_iSILimit)
	{
		static int iSize;
		static int iAllowedSI;

		iAllowedSI = g_iSILimit - iCurrentSI;
		iSize = g_iSpawnSize > iAllowedSI ? iAllowedSI : g_iSpawnSize;

		vSITypeCount();

		static int i;
		static int iIndex;
		static int iQueueLength;
		static ArrayList aSpawnQueue;

		aSpawnQueue = new ArrayList();
		for(i = 0; i < iSize; i++)
		{
			iIndex = iGenerateIndex();
			if(iIndex == UNINITIALISED)
				break;

			aSpawnQueue.Push(iIndex);
			g_iSpawnCounts[iIndex] += 1;
		}	

		iQueueLength = aSpawnQueue.Length;
		if(iQueueLength > 0)
		{
			static int client;
			client = iGetAnyValidClient();
			if(client > 0)
			{
				static float fFlow;
				static int iRusher;
				static bool bForward;
				static ArrayList aList;
	
				bForward = false;
				aList = new ArrayList(2);
				for(i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
					{
			
						fFlow = L4D2Direct_GetFlowDistance(i);
						if(fFlow && fFlow != -9999.0)
							aList.Set(aList.Push(fFlow), i, 1);
					}
				}

				aList.Sort(Sort_Descending, Sort_Float);
		
				static int iCount;
				iCount = aList.Length;
				iRusher = iCount > 0 ? aList.Get(0, 1) : 0;
	
				if(iCount >= 2)
				{
					fFlow = aList.Get(0, 0);

					static float fLastFlow;
					fLastFlow = aList.Get(iCount - 1, 0);

					if(fFlow - fLastFlow > g_fRusherDistance)
					{
						#if SPAWN_DEBUG
						PrintToServer("[SS] Rusher->%N", iRusher);
						#endif

						bForward = true;
					}
				}

				delete aList;

				g_iPreferredDirection = bForward ? 3 : 4;

				static bool bResetGhost[MAXPLAYERS + 1];
				static bool bResetLifeState[MAXPLAYERS + 1];

				if(!bIsSpawnablePZSupported())
				{
					for(i = 1; i <= MaxClients; i++)
					{
						if(!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3)
							continue;

						if(GetEntProp(i, Prop_Send, "m_isGhost") == 1)
						{
							bResetGhost[i] = true;
							SetEntProp(i, Prop_Send, "m_isGhost", 0);
						}
						else if(!IsPlayerAlive(i))
						{
							bResetLifeState[i] = true;
							SetEntProp(i, Prop_Send, "m_lifeState", 0);
						}
					}
				}

				static int iCmdFlags;
				static int iFlagBits;
				iFlagBits = GetUserFlagBits(client);
				iCmdFlags = GetCommandFlags("z_spawn_old");
				SetUserFlagBits(client, ADMFLAG_ROOT);
				SetCommandFlags("z_spawn_old", iCmdFlags & ~FCVAR_CHEAT);

				for(iIndex = 0; iIndex < iQueueLength; iIndex++)
					FakeClientCommand(client, "z_spawn_old %s auto", g_sZombieClass[aSpawnQueue.Get(iIndex)]);

				SetUserFlagBits(client, iFlagBits);
				SetCommandFlags("z_spawn_old", iCmdFlags | FCVAR_CHEAT);
				
				if(!bIsSpawnablePZSupported())
				{
					for(i = 1; i <= MaxClients; i++)
					{
						if(bResetGhost[i])
							SetEntProp(i, Prop_Send, "m_isGhost", 1);
						if(bResetLifeState[i])
							SetEntProp(i, Prop_Send, "m_lifeState", 1);
			
						bResetGhost[i] = false;
						bResetLifeState[i] = false;
					}
				}

				g_iPreferredDirection = 4;

				if(iRusher > 0)
					vVerifySIType(iRusher, aSpawnQueue, iCurrentSI + iSize);
				else
				{
					#if SPAWN_DEBUG
					PrintToServer("[SS] 无最高路程玩家");
					#endif
				}
			}
		}
		delete aSpawnQueue;
	}
}

static bool bIsSpawnablePZSupported()
{
	if(!g_bControlZombies)
		return false;

	return CZ_IsSpawnablePZSupported();
}

static void vVerifySIType(int iRusher, ArrayList aSpawnQueue, int iAllowedSI)
{
	static int i;
	static int iCount;
	static int iIndex;
	static int iZombieClass;

	iCount = 0;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			if((iZombieClass = GetEntProp(i, Prop_Send, "m_zombieClass")) != 8)
			{
				iCount++;
				if((iIndex = aSpawnQueue.FindValue(iZombieClass - 1)) != -1)
					aSpawnQueue.Erase(iIndex);
			}
		}
	}

	static int iQueueLength;
	iQueueLength = aSpawnQueue.Length;
	if(iCount < iAllowedSI && iQueueLength > 0)
	{
		iAllowedSI -= iCount;
		if(iAllowedSI > iQueueLength)
			iAllowedSI = iQueueLength;
		
		g_hSpawnRange.IntValue += 500;
		g_hDiscardRange.IntValue += 500;
		static float fSpawnPos[3];
		for(i = 0; i < iAllowedSI; i++)
		{
			iIndex = aSpawnQueue.Get(i);
			#if SPAWN_DEBUG
			PrintToServer("[SS] %s产生失败", g_sZombieClass[iIndex]);
			#endif
			if(L4D_GetRandomPZSpawnPosition(iRusher, iIndex + 1, 10, fSpawnPos))
			{
				L4D2_SpawnSpecial(iIndex + 1, fSpawnPos, NULL_VECTOR);
				#if SPAWN_DEBUG
				PrintToServer("[SS] 补充产生%s", g_sZombieClass[iIndex]);
				#endif
			}
			else
			{
				#if SPAWN_DEBUG
				PrintToServer("[SS] %s寻位失败", g_sZombieClass[iIndex]);
				#endif
			}
		}
		g_hSpawnRange.IntValue -= 500;
		g_hDiscardRange.IntValue -= 500;
	}
}

static int iGetInfecteds()
{
	static int i;
	static int iCount;

	iCount = 0;
	
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == 3)
		{
			if(IsPlayerAlive(i))
			{
				if(GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
					iCount++;
			}
			else if(IsFakeClient(i))
				KickClient(i);
		}
	}
	return iCount;
}

static void vSITypeCount()
{
	static int i;
	for(i = 0; i < NUM_TYPES_INFECTED; i++)
		g_iSpawnCounts[i] = 0;

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			switch(GetEntProp(i, Prop_Send, "m_zombieClass"))
			{
				case 1:
					g_iSpawnCounts[SI_SMOKER]++;

				case 2:
					g_iSpawnCounts[SI_BOOMER]++;

				case 3:
					g_iSpawnCounts[SI_HUNTER]++;

				case 4:
					g_iSpawnCounts[SI_SPITTER]++;

				case 5:
					g_iSpawnCounts[SI_JOCKEY]++;
		
				case 6:
					g_iSpawnCounts[SI_CHARGER]++;
			}
		}
	}
}

static int iGenerateIndex()
{	
	static int i;
	static int iTotalSpawnWeight;
	static int iStandardizedSpawnWeight;
	static int iTempSpawnWeights[NUM_TYPES_INFECTED];

	iTotalSpawnWeight = 0;
	iStandardizedSpawnWeight = 0;

	for(i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		iTempSpawnWeights[i] = g_iSpawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - g_iSpawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
		iTotalSpawnWeight += iTempSpawnWeights[i];
	}

	static float fUnit;
	static float fIntervalEnds[NUM_TYPES_INFECTED];
	fUnit = 1.0 / iTotalSpawnWeight;

	for(i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if(iTempSpawnWeights[i] >= 0)
		{
			iStandardizedSpawnWeight += iTempSpawnWeights[i];
			fIntervalEnds[i] = iStandardizedSpawnWeight * fUnit;
		}
	}

	static float fRandom;
	fRandom = GetRandomFloat(0.0, 1.0);
	for(i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if(iTempSpawnWeights[i] <= 0)
			continue;

		if(fIntervalEnds[i] < fRandom)
			continue;

		return i;
	}

	return UNINITIALISED;
}

public void OnPluginStart()
{
	g_hSILimit = CreateConVar("ss_si_limit", "12", "同时存在的最大特感数量", _, true, 1.0, true, 32.0);
	g_hSpawnSize = CreateConVar("ss_spawn_size", "4", "一次产生多少只特感", _, true, 1.0, true, 32.0);
	g_hSpawnLimits[SI_SMOKER] = CreateConVar("ss_smoker_limit",	"3", "同时存在的最大smoker数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_BOOMER] = CreateConVar("ss_boomer_limit",	"2", "同时存在的最大boomer数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_HUNTER] = CreateConVar("ss_hunter_limit",	"3", "同时存在的最大hunter数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SPITTER] = CreateConVar("ss_spitter_limit", "2", "同时存在的最大spitter数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_JOCKEY] = CreateConVar("ss_jockey_limit",	"3", "同时存在的最大jockey数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_CHARGER] = CreateConVar("ss_charger_limit", "3", "同时存在的最大charger数量", _, true, 0.0, true, 32.0);

	g_hSpawnWeights[SI_SMOKER] = CreateConVar("ss_smoker_weight", "80", "smoker产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_BOOMER] = CreateConVar("ss_boomer_weight", "125", "boomer产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_HUNTER] = CreateConVar("ss_hunter_weight", "100", "hunter产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_SPITTER] = CreateConVar("ss_spitter_weight", "125", "spitter产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_JOCKEY] = CreateConVar("ss_jockey_weight", "100", "jockey产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_CHARGER] = CreateConVar("ss_charger_weight", "100", "charger产生比重", _, true, 0.0);
	g_hScaleWeights = CreateConVar("ss_scale_weights", "1",	"[ 0 = 关闭 | 1 = 开启 ] 缩放相应特感的产生比重", _, true, 0.0, true, 1.0);
	g_hSpawnTimeMin = CreateConVar("ss_time_min", "10.0", "特感的最小产生时间", _, true, 0.0);
	g_hSpawnTimeMax = CreateConVar("ss_time_max", "15.0", "特感的最大产生时间", _, true, 1.0);
	g_hSpawnTimeMode = CreateConVar("ss_time_mode", "2", "特感的刷新时间模式[ 0 = 随机 | 1 = 递增 | 2 = 递减 ]", _, true, 0.0, true, 2.0);

	g_hSIbase = CreateConVar("ss_base_limit", "4", "生还者团队玩家不超过4人时有多少个特感", _, true, 0.0, true, 32.0);
	g_hSIextra = CreateConVar("ss_extra_limit", "1", "生还者团队玩家每增加一个可增加多少个特感", _, true, 0.0, true, 32.0);
	g_hGroupbase = CreateConVar("ss_groupbase_limit", "4", "生还者团队玩家不超过4人时一次产生多少只特感", _, true, 0.0, true, 32.0);
	g_hGroupextra = CreateConVar("ss_groupextra_limit", "2", "生还者团队玩家每增加多少玩家一次多产生一只", _, true, 1.0, true, 32.0);
	g_hRusherDistance = CreateConVar("ss_rusher_distance", "2000.0", "路程超过多少算跑图", _, true, 500.0);
	g_hTankSpawnAction = CreateConVar("ss_tankspawn_action", "1", "坦克产生后是否对当前刷特参数进行修改, 坦克死完后恢复?[ 0 = 忽略(保持原有的刷特状态) | 1 = 自定义 ]", _, true, 0.0, true, 1.0);
	g_hTankSpawnLimits = CreateConVar("ss_tankspawn_limits", "3;1;3;0;3;3", "坦克产生后每种特感数量的自定义参数");
	g_hTankSpawnWeights = CreateConVar("ss_tankspawn_weights", "80;300;100;0;100;100", "坦克产生后每种特感比重的自定义参数");

	g_hSpawnRange = FindConVar("z_spawn_range");
	g_hSpawnRange.Flags &= ~FCVAR_NOTIFY;
	g_hDiscardRange = FindConVar("z_discard_range");
	g_hDiscardRange.Flags &= ~FCVAR_NOTIFY;
	
	g_hDirectorNoSpecials = FindConVar("director_no_specials");
	g_hDirectorNoSpecials.AddChangeHook(vOthersConVarChanged);

	g_hSpawnSize.AddChangeHook(vLimitsConVarChanged);
	for(int i; i < NUM_TYPES_INFECTED; i++)
	{
		g_hSpawnLimits[i].AddChangeHook(vLimitsConVarChanged);
		g_hSpawnWeights[i].AddChangeHook(vOthersConVarChanged);
	}

	g_hSILimit.AddChangeHook(vTimesConVarChanged);
	g_hSpawnTimeMin.AddChangeHook(vTimesConVarChanged);
	g_hSpawnTimeMax.AddChangeHook(vTimesConVarChanged);
	g_hSpawnTimeMode.AddChangeHook(vTimesConVarChanged);

	g_hScaleWeights.AddChangeHook(vOthersConVarChanged);
	g_hSIbase.AddChangeHook(vOthersConVarChanged);
	g_hSIextra.AddChangeHook(vOthersConVarChanged);
	g_hGroupbase.AddChangeHook(vOthersConVarChanged);
	g_hGroupextra.AddChangeHook(vOthersConVarChanged);
	g_hRusherDistance.AddChangeHook(vOthersConVarChanged);

	g_hTankSpawnAction.AddChangeHook(vTankSpawnConVarChanged);
	g_hTankSpawnLimits.AddChangeHook(vTankCustomConVarChanged);
	g_hTankSpawnWeights.AddChangeHook(vTankCustomConVarChanged);

	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	RegAdminCmd("sm_weight", Cmd_SetWeight, ADMFLAG_RCON, "Set spawn weights for SI classes");
	RegAdminCmd("sm_limit", Cmd_SetLimit, ADMFLAG_RCON, "Set individual, total and simultaneous SI spawn limits");
	RegAdminCmd("sm_timer", Cmd_SetTimer, ADMFLAG_RCON, "Set a variable or constant spawn time (seconds)");

	RegAdminCmd("sm_resetspawns", Cmd_ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("sm_forcetimer", Cmd_StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
	RegAdminCmd("sm_type", Cmd_Type, ADMFLAG_ROOT, "随机轮换模式");
}

public void OnPluginEnd()
{
	g_hSpawnRange.RestoreDefault();
	g_hDiscardRange.RestoreDefault();
	g_hDirectorNoSpecials.RestoreDefault();

	FindConVar("z_spawn_flow_limit").RestoreDefault();
	FindConVar("z_attack_flow_range").RestoreDefault();

	FindConVar("director_no_bosses").RestoreDefault();
	FindConVar("director_spectate_specials").RestoreDefault();

	FindConVar("z_safe_spawn_range").RestoreDefault();
	FindConVar("z_spawn_safety_range").RestoreDefault();

	FindConVar("z_finale_spawn_safety_range").RestoreDefault();
	FindConVar("z_finale_spawn_tank_safety_range").RestoreDefault();
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	static int val;

	val = retVal;
	if(strcmp(key, "MaxSpecials", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSILimit;
	else if(strcmp(key, "DominatorLimit", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSILimit;
	else if(strcmp(key, "SmokerLimit", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSpawnLimits[0];
	else if(strcmp(key, "BoomerLimit", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSpawnLimits[1];
	else if(strcmp(key, "HunterLimit", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSpawnLimits[2];
	else if(strcmp(key, "SpitterLimit", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSpawnLimits[3];
	else if(strcmp(key, "JockeyLimit", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSpawnLimits[4];
	else if(strcmp(key, "ChargerLimit", false) == 0)
		val = g_bDirectorNoSpecials ? 32 : g_iSpawnLimits[5];
	else if(strcmp(key, "SpecialInfectedAssault", false) == 0)
		val = 1;
	else if(strcmp(key, "PreferredSpecialDirection", false) == 0)
		val = g_iPreferredDirection;

	if(val != retVal)
	{
		retVal = val;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnPlayerStuck(int client)
{
	if(client && IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && IsValidStuck(client))
	{
		#if SPAWN_DEBUG
		PrintToServer("[SS] %N卡住踢出", client);
		#endif
		KickClient(client, "感染者卡住踢出");
	}
}

bool IsValidStuck(int client)
{
	bool bIsValid = true;
	switch(GetEntProp(client, Prop_Send, "m_zombieClass"))
	{
		case 1:
		{
			if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
				bIsValid = false; 
		}
		
		case 3:
		{
			if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
				bIsValid = false;
		}
		
		case 5:
		{
			if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
				bIsValid = false;
		}
		
		case 6:
		{
			if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
				bIsValid = false;
	}
		
		case 8:
			bIsValid = false;
	}
	return bIsValid;
}

public void OnConfigsExecuted()
{
	vGetLimitsCvars();
	vGetTimesCvars();
	vGetOthersCvars();
	vGetTankSpawnCvars();
	vGetTankCustomCvars();
	vSetDirectorConvars();

	g_iPreferredDirection = 4;
}

public void vLimitsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetLimitsCvars();
}

void vGetLimitsCvars()
{
	g_iSpawnSize = g_hSpawnSize.IntValue;
	for(int i; i < NUM_TYPES_INFECTED; i++)
		g_iSpawnLimits[i] = g_hSpawnLimits[i].IntValue;
}

public void vTimesConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetTimesCvars();
}

void vGetTimesCvars()
{
	g_iSILimit = g_hSILimit.IntValue;
	g_fSpawnTimeMin = g_hSpawnTimeMin.FloatValue;
	g_fSpawnTimeMax = g_hSpawnTimeMax.FloatValue;
	g_iSpawnTimeMode = g_hSpawnTimeMode.IntValue;
	
	if(g_fSpawnTimeMin > g_fSpawnTimeMax)
		g_fSpawnTimeMin = g_fSpawnTimeMax;
		
	vCalculateSpawnTimes();
}

void vCalculateSpawnTimes()
{
	if(g_iSILimit > 1 && g_iSpawnTimeMode > 0)
	{
		float fUnit = (g_fSpawnTimeMax - g_fSpawnTimeMin) / (g_iSILimit - 1);
		switch(g_iSpawnTimeMode)
		{
			case 1: 
			{
				g_fSpawnTimes[0] = g_fSpawnTimeMin;
				for(int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] + fUnit) : g_fSpawnTimeMax;
			}

			case 2: 
			{	
				g_fSpawnTimes[0] = g_fSpawnTimeMax;
				for(int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] - fUnit) : g_fSpawnTimeMax;
			}
		}	
	} 
	else
		g_fSpawnTimes[0] = g_fSpawnTimeMax;
}

public void vOthersConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetOthersCvars();
}

void vGetOthersCvars()
{
	g_bScaleWeights = g_hScaleWeights.BoolValue;

	for(int i; i < NUM_TYPES_INFECTED; i++)
		g_iSpawnWeights[i] = g_hSpawnWeights[i].IntValue;

	g_iSIbase = g_hSIbase.IntValue;
	g_iSIextra = g_hSIextra.IntValue;
	g_iGroupbase = g_hGroupbase.IntValue;
	g_iGroupextra = g_hGroupextra.IntValue;
	g_fRusherDistance = g_hRusherDistance.FloatValue;
	g_bDirectorNoSpecials = g_hDirectorNoSpecials.BoolValue;
}

public void vTankSpawnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int iLast = g_iTankSpawnAction;

	vGetTankSpawnCvars();

	if(iLast != g_iTankSpawnAction)
		vTankSpawnDeathActoin(bFindTank(-1));
}

void vGetTankSpawnCvars()
{
	g_iTankSpawnAction = g_hTankSpawnAction.IntValue;
}

public void vTankCustomConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetTankCustomCvars();
}

void vGetTankCustomCvars()
{
	char sTemp[64];
	g_hTankSpawnLimits.GetString(sTemp, sizeof(sTemp));

	char sValues[NUM_TYPES_INFECTED][8];
	ExplodeString(sTemp, ";", sValues, sizeof(sValues), sizeof(sValues[]));
	
	int i;
	int iValue;
	for(; i < NUM_TYPES_INFECTED; i++)
	{
		if(sValues[i][0] == '\0')
		{
			g_iTankSpawnLimits[i] = UNINITIALISED;
			continue;
		}
		
		if((iValue = StringToInt(sValues[i])) < UNINITIALISED || iValue > g_iSILimit)
		{
			g_iTankSpawnLimits[i] = UNINITIALISED;
			sValues[i][0] = '\0';
			continue;
		}
	
		g_iTankSpawnLimits[i] = iValue;
		sValues[i][0] = '\0';
	}
	
	g_hTankSpawnWeights.GetString(sTemp, sizeof(sTemp));
	ExplodeString(sTemp, ";", sValues, sizeof(sValues), sizeof(sValues[]));
	
	for(i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if(sValues[i][0] == '\0' || (iValue = StringToInt(sValues[i])) < 0)
		{
			g_iTankSpawnWeights[i] = UNINITIALISED;
			continue;
		}

		g_iTankSpawnWeights[i] = iValue;
	}
}

void vSetDirectorConvars()
{
	g_hSpawnRange.IntValue = 1000;
	g_hDiscardRange.IntValue = 1250;
	g_hDirectorNoSpecials.IntValue = 1;

	FindConVar("z_spawn_flow_limit").IntValue = 50000;
	FindConVar("z_attack_flow_range").IntValue = 50000;

	FindConVar("director_no_bosses").IntValue = 1;
	FindConVar("director_spectate_specials").IntValue = 1;

	FindConVar("z_safe_spawn_range").IntValue = 1;
	FindConVar("z_spawn_safety_range").IntValue = 1;

	FindConVar("z_finale_spawn_safety_range").IntValue = 1;
	FindConVar("z_finale_spawn_tank_safety_range").IntValue = 1;
}

public void OnClientDisconnect(int client)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return;
		
	CreateTimer(0.1, Timer_TankDisconnectCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	vEndSpawnTimer();
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	vTankSpawnDeathActoin(false);
	g_bHasAnySurvivorLeftSafeArea = false;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	vEndSpawnTimer();
	g_iRoundStart = 1;
}

public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{ 
	if(g_bHasAnySurvivorLeftSafeArea == false && bIsRoundStarted() == true && bHasAnySurvivorLeftSafeArea())
		CreateTimer(0.1, Timer_PlayerLeftStartArea, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool bIsRoundStarted()
{
	return g_iRoundStart && g_iPlayerSpawn;
}

public Action Timer_PlayerLeftStartArea(Handle timer)
{
	if(g_bHasAnySurvivorLeftSafeArea == false && bHasAnySurvivorLeftSafeArea())
	{
		if(g_iCurrentClass >= 6)
			vSetRandomType();
		else if(g_iCurrentClass > UNINITIALISED)
			vSiTypeMode(g_iCurrentClass);

		vStartCustomSpawnTimer(0.1);

		g_bHasAnySurvivorLeftSafeArea = true;
	}
}

bool bHasAnySurvivorLeftSafeArea()
{
	int entity = FindEntityByClassname(-1, "terror_player_manager");
	if(entity == INVALID_ENT_REFERENCE)
		return false;

	return !!GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

Handle g_hUpdateTimer;
public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	static int client;
	client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client))
		return;

	if(event.GetInt("team") == 2 || event.GetInt("oldteam") == 2)
	{
		delete g_hUpdateTimer;
		g_hUpdateTimer = CreateTimer(2.0, Timer_SpecialsUpdate);
	}
}

public Action Timer_SpecialsUpdate(Handle timer)
{
	g_hUpdateTimer = null;

	vSetMaxSpecialsCount();
}

void vSetMaxSpecialsCount()
{
	int iPlayers;
	int iTempLimit;
	int iTempSize;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
			iPlayers++;
	}

	if(iPlayers < 5)
	{
		iTempLimit = g_iSIbase;
		iTempSize = g_iGroupbase;
	}
	else
	{
		iTempLimit = g_iSIextra * (iPlayers - 4) + g_iSIbase;
		iTempSize = g_iGroupbase + RoundFloat(1.0 * (iPlayers - 4) / g_iGroupextra);
	}

	if(iTempLimit == g_iSILimit && iTempSize == g_iSpawnSize)
		return;

	g_hSILimit.IntValue = iTempLimit;
	g_hSpawnSize.IntValue = iTempSize;
	PrintToChatAll("\x01[\x05%d特\x01/\x05次\x01] \x05%d特 \x01[\x03%.1f\x01~\x03%.1f\x01]\x04秒", iTempSize, iTempLimit, g_fSpawnTimeMin, g_fSpawnTimeMax);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_iPlayerSpawn = 1;

	static int userid;
	static int client;
	userid = event.GetInt("userid");
	client = GetClientOfUserId(userid);
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return;

	CreateTimer(0.1, Timer_TankSpawn, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int userid;
	static int client;
	userid = event.GetInt("userid");
	client = GetClientOfUserId(userid);
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;
	
	if(GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && !bFindTank(client))
		vTankSpawnDeathActoin(false);

	if(IsFakeClient(client))
		RequestFrame(OnNextFrame_KickBot, userid);
}

public Action Timer_TankSpawn(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || bFindTank(client))
		return;

	for(int i; i < NUM_TYPES_INFECTED; i++)
	{
		g_iSpawnLimitsCache[i] = g_iSpawnLimits[i];
		g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
	}

	vTankSpawnDeathActoin(true);
}

public void OnNextFrame_KickBot(int client)
{
	if((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
		KickClient(client);

}

bool bFindTank(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			return true;
	}
	return false;
}

public Action Timer_TankDisconnectCheck(Handle timer)
{
	if(bFindTank(-1))
		return;

	vTankSpawnDeathActoin(false);
}

void vTankSpawnDeathActoin(bool bIsTankAlive)
{
	static bool bLoad;
	if(bIsTankAlive)
	{
		if(!bLoad && g_iTankSpawnAction)
		{
			bLoad = true;
			vLoadCacheTankCustom();
		}
	}
	else
	{
		if(bLoad)
		{
			bLoad = false;
			vLoadCacheSpawnLimits();
			vLoadCacheSpawnWeights();
		}
	}
}

public Action Cmd_SetLimit(int client, int args)
{
	if(args == 1)
	{
		char sArg[16];
		GetCmdArg(1, sArg, sizeof(sArg));	
		if(strcmp(sArg, "reset", false) == 0)
		{
			vResetLimits();
			ReplyToCommand(client, "[SS] Spawn Limits reset to default values");
		}
	}
	else if(args == 2)
	{
		char sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));

		char sLimitValue[32];	 
		GetCmdArg(2, sLimitValue, sizeof(sLimitValue));
		int iLimitValue = StringToInt(sLimitValue);	
	
		if(iLimitValue < 0)
			ReplyToCommand(client, "[SS] Limit value must be >= 0");
		else 
		{
			if(strcmp(sTargetClass, "all", false) == 0)
			{
				for(int i; i < NUM_TYPES_INFECTED; i++)
					g_hSpawnLimits[i].IntValue = iLimitValue;

				PrintToChatAll("\x01[SS] All SI limits have been set to \x05%d", iLimitValue);
			} 
			else if(strcmp(sTargetClass, "max", false) == 0)
			{
				g_hSILimit.IntValue = iLimitValue;
				PrintToChatAll("\x01[SS] -> \x04Max \x01SI limit set to \x05%i", iLimitValue);				   
			} 
			else if(strcmp(sTargetClass, "group", false) == 0 || strcmp(sTargetClass, "wave", false) == 0)
			{
				g_hSpawnSize.IntValue = iLimitValue;
				PrintToChatAll("\x01[SS] -> SI will spawn in \x04groups\x01 of \x05%i", iLimitValue);
			} 
			else 
			{
				for(int i; i < NUM_TYPES_INFECTED; i++)
				{
					if(strcmp(g_sZombieClass[i], sTargetClass, false) == 0)
					{
						g_hSpawnLimits[i].IntValue = iLimitValue;
						PrintToChatAll("\x01[SS] \x04%s \x01limit set to \x05%i", sTargetClass, iLimitValue);
					}
				}
			}
		}	 
	} 
	else 
	{
		ReplyToCommand(client, "\x04!limit/sm_limit \x05<class> <limit>");
		ReplyToCommand(client, "\x05<class> \x01[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
		ReplyToCommand(client, "\x05<limit> \x01[ >= 0 ]");
	}

	return Plugin_Handled;
}

public Action Cmd_SetWeight(int client, int args)
{
	if(args == 1)
	{
		char sArg[16];
		GetCmdArg(1, sArg, sizeof(sArg));	
		if(strcmp(sArg, "reset", false) == 0)
		{
			vResetWeights();
			ReplyToCommand(client, "[SS] Spawn weights reset to default values");
		} 
	} 
	else if(args == 2)
	{
		char sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));

		char sWeightPercent[32];	 
		GetCmdArg(2, sWeightPercent, sizeof(sWeightPercent));
		int iWeightPercent = StringToInt(sWeightPercent);	  
		if(iWeightPercent < 0)
		{
			ReplyToCommand(client, "weight value >= 0");
			return Plugin_Handled;
		} 
		else 
		{
			if(strcmp(sTargetClass, "all", false) == 0)
			{
				for(int i; i < NUM_TYPES_INFECTED; i++)
					g_hSpawnWeights[i].IntValue = iWeightPercent;			
	
				ReplyToCommand(client, "\x01[SS] -> \x04All spawn weights \x01set to \x05%d", iWeightPercent);	
			} 
			else 
			{
				for(int i; i < NUM_TYPES_INFECTED; i++)
				{
					if(strcmp(sTargetClass, g_sZombieClass[i], false) == 0)
					{
						g_hSpawnWeights[i].IntValue =  iWeightPercent;
						ReplyToCommand(client, "\x01[SS] \x04%s \x01weight set to \x05%d", g_sZombieClass[i], iWeightPercent);				
					}
				}	
			}
			
		}
	} 
	else 
	{
		ReplyToCommand(client, "\x04!weight/sm_weight \x05<class> <value>");
		ReplyToCommand(client, "\x05<class> \x01[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ]");	
		ReplyToCommand(client, "\x05value \x01[ >= 0 ]");	
	}

	return Plugin_Handled;
}

public Action Cmd_SetTimer(int client, int args)
{
	if(args == 1)
	{
		float fTime;
		char sArg[8];
		GetCmdArg(1, sArg, sizeof(sArg));

		fTime = StringToFloat(sArg);
		if(fTime < 0.0)
			fTime = 1.0;

		g_hSpawnTimeMin.FloatValue = fTime;
		g_hSpawnTimeMax.FloatValue = fTime;
		ReplyToCommand(client, "\x01[SS] Spawn timer set to constant \x05%.1f \x01seconds", fTime);
	} 
	else if(args == 2)
	{
		float fMin, fMax;
		char sArg[8];
		GetCmdArg(1, sArg, sizeof(sArg));
		fMin = StringToFloat(sArg);
		GetCmdArg(2, sArg, sizeof(sArg));
		fMax = StringToFloat(sArg);
		if(fMin > 0.0 && fMax > 1.0 && fMax > fMin)
		{
			g_hSpawnTimeMin.FloatValue = fMin;
			g_hSpawnTimeMax.FloatValue = fMax;
			ReplyToCommand(client, "\x01[SS] Spawn timer will be between \x05%.1f \x01and \x05%.1f \x01seconds", fMin, fMax);
		} 
		else 
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.0) spawn time");
	} 
	else 
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");

	return Plugin_Handled;
}

public Action Cmd_ResetSpawns(int client, int args)
{	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			ForcePlayerSuicide(i);
	}

	vStartCustomSpawnTimer(g_fSpawnTimes[0]);
	ReplyToCommand(client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.1f seconds.", g_fSpawnTimeMin);
	return Plugin_Handled;
}

public Action Cmd_StartSpawnTimerManually(int client, int args)
{
	if(args < 1)
	{
		vStartSpawnTimer();
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
	} 
	else 
	{
		float fTime = 1.0;
		char sArg[8];
		GetCmdArg(1, sArg, sizeof(sArg));
		fTime = StringToFloat(sArg);
		
		if(fTime < 0.0)
			fTime = 1.0;
		
		vStartCustomSpawnTimer(fTime);
		ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.1f seconds.", fTime);
	}
	return Plugin_Handled;
}

public Action Cmd_Type(int client, int args)
{
	if(args == 1)
	{
		char sTargetClass[16];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		if(strcmp(sTargetClass, "off", false) == 0)
		{
			g_iCurrentClass = UNINITIALISED;
			ReplyToCommand(client, "已关闭单一特感模式");
			vResetLimits();
		}
		else if(strcmp(sTargetClass, "random", false) == 0)
		{
			vSetRandomType();
			g_iCurrentClass = 6;
		}
		else
		{
			int iClassIndex = iGetZombieClass(sTargetClass);
			if(iClassIndex == UNINITIALISED)
			{
				ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
				ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
			}
			else if(iClassIndex == g_iCurrentClass)
				ReplyToCommand(client, "目标特感类型与当前特感类型相同");
			else
			{
				vSiTypeMode(iClassIndex);
				g_iCurrentClass = iClassIndex;
			}
		}
	}
	else
	{
		ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
		ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
	}

	return Plugin_Handled;
}

int iGetZombieClass(const char[] sClass)
{
	for(int i; i < NUM_TYPES_INFECTED; i++)
	{
		if(strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return UNINITIALISED;
}

void vSetRandomType()
{
	static int iClassIndex;
	static int iZombieClass[NUM_TYPES_INFECTED] = {0, 1, 2, 3, 4, 5};
	if(iClassIndex == 0)
		SortIntegers(iZombieClass, NUM_TYPES_INFECTED, Sort_Random);

	PrintToChatAll("\x03当前轮换\x01: \n");
	vSiTypeMode(iZombieClass[iClassIndex]);
	if(++iClassIndex == NUM_TYPES_INFECTED)
		iClassIndex = 0;
}

void vSiTypeMode(int iClassIndex)
{
	for(int i; i < NUM_TYPES_INFECTED; i++)		
		g_hSpawnLimits[i].IntValue = i != iClassIndex ? 0 : g_iSILimit;

	PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[iClassIndex]);
}
