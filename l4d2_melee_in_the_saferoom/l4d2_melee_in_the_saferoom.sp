#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define VERSION "3.1.0"

ConVar g_hEnabled;
ConVar g_hSpawnType;
ConVar g_hRandomAmount;
ConVar g_hMapBaseAmount;
ConVar g_hMeleeItems[14];

int g_iRoundStart;
int g_iPlayerSpawn;
int g_iMeleeClassCount;
int g_iMeleeRandomSpawn[32];

char g_sMeleeClass[16][32];

static const char g_sMeleeModels[][] =
{
	"models/weapons/melee/v_bat.mdl",
	"models/weapons/melee/w_bat.mdl",
	"models/weapons/melee/v_cricket_bat.mdl",
	"models/weapons/melee/w_cricket_bat.mdl",
	"models/weapons/melee/v_crowbar.mdl",
	"models/weapons/melee/w_crowbar.mdl",
	"models/weapons/melee/v_electric_guitar.mdl",
	"models/weapons/melee/w_electric_guitar.mdl",
	"models/weapons/melee/v_fireaxe.mdl",
	"models/weapons/melee/w_fireaxe.mdl",
	"models/weapons/melee/v_frying_pan.mdl",
	"models/weapons/melee/w_frying_pan.mdl",
	"models/weapons/melee/v_golfclub.mdl",
	"models/weapons/melee/w_golfclub.mdl",
	"models/weapons/melee/v_katana.mdl",
	"models/weapons/melee/w_katana.mdl",
	"models/weapons/melee/v_machete.mdl",
	"models/weapons/melee/w_machete.mdl",
	"models/weapons/melee/v_tonfa.mdl",
	"models/weapons/melee/w_tonfa.mdl",
	"models/weapons/melee/v_riotshield.mdl",
	"models/weapons/melee/w_riotshield.mdl",
	"models/weapons/melee/v_pitchfork.mdl",
	"models/weapons/melee/w_pitchfork.mdl",
	"models/weapons/melee/v_shovel.mdl",
	"models/weapons/melee/w_shovel.mdl"
};

static const char g_sMeleeName[][] =
{
	"knife",			//小刀
	"cricket_bat",		//球拍
	"crowbar",			//撬棍
	"electric_guitar",	//吉他
	"fireaxe",			//斧头
	"frying_pan",		//平底锅
	"golfclub",			//高尔夫球棍
	"baseball_bat",		//棒球棒
	"katana",			//武士刀
	"machete",			//砍刀
	"tonfa",			//警棍
	"riot_shield",		//盾牌
	"pitchfork",		//草叉
	"shovel"			//铁铲
};

public Plugin myinfo =
{
	name = "Melee In The Saferoom",
	author = "$atanic $pirit, N3wton",
	description = "Spawns a selection of melee weapons in the saferoom, at the start of each round.",
	version = VERSION
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Melee in the Saferoom only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_mitsr_Version", VERSION, "The version of Melee In The Saferoom"); 
	g_hEnabled = CreateConVar("l4d2_MITSR_Enabled", "1", "Should the plugin be enabled", _, true, 0.0, true, 1.0);
	g_hSpawnType = CreateConVar("l4d2_MITSR_Spawn_Type", "1", "0 = Custom list, 1 = Random Weapon and 2 = Map based weapons.", _, true, 0.0, true, 2.0);
	g_hRandomAmount	= CreateConVar("l4d2_MITSR_Random_Amount", "4","Number of weapons to spawn if l4d2_MITSR_Spawn_Type is set to 1.", _, true, 0.0, true, 32.0);
	g_hMapBaseAmount = CreateConVar("l4d2_MITSR_MapBase_Amount", "4", "Number multiple if l4d2_MITSR_Spawn_Type is set to 2.", _, true, 0.0, true, 32.0);
		
	g_hMeleeItems[7] = CreateConVar("l4d2_MITSR_Knife", "1", "Number of knifes to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[1] = CreateConVar("l4d2_MITSR_CricketBat", "1", "Number of cricket bats to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[2] = CreateConVar("l4d2_MITSR_Crowbar", "1", "Number of crowbars to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[3] = CreateConVar("l4d2_MITSR_ElecGuitar", "1", "Number of electric guitars to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[4] = CreateConVar("l4d2_MITSR_FireAxe", "1", "Number of fireaxes to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[5] = CreateConVar("l4d2_MITSR_FryingPan", "1", "Number of frying pans to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[6] = CreateConVar("l4d2_MITSR_GolfClub", "1", "Number of golf clubs to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[0] = CreateConVar("l4d2_MITSR_BaseballBat", "1", "Number of baseball bats to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[8] = CreateConVar("l4d2_MITSR_Katana", "1", "Number of katanas to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[9] = CreateConVar("l4d2_MITSR_Machete", "1", "Number of machetes to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[10] = CreateConVar("l4d2_MITSR_Tonfa", "1", "Number of tonfas to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[11] = CreateConVar("l4d2_MITSR_RiotShield", "1", "Number of tonfas to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[12] = CreateConVar("l4d2_MITSR_PitchFork", "1", "Number of pitchforks to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[13] = CreateConVar("l4d2_MITSR_Shovel", "1", "Number of shovels to spawn (l4d2_MITSR_Spawn_Type must be 0)", _, true, 0.0, true, 10.0);
	
	//AutoExecConfig(true, "l4d2_melee_in_the_saferoom");
	
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_melee",	Command_SMMelee, ADMFLAG_KICK, "Lists all melee weapons spawnable in current campaign"); 
}

public Action Command_SMMelee(int client, int args)
{	
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
		ReplyToCommand(client, "地图尚未开始");
	else
	{
		ReplyToCommand(client, "当前地图已解锁近战:");
		for(int i; i < g_iMeleeClassCount; i++)
			ReplyToCommand(client, "%d : %s", i, g_sMeleeClass[i]);
	}

	return Plugin_Handled;
}

public void OnMapStart()
{
	int i;
	int iLen;

	iLen = sizeof(g_sMeleeModels);
	for(i = 0; i < iLen; i++)
	{
		if(!IsModelPrecached(g_sMeleeModels[i]))
			PrecacheModel(g_sMeleeModels[i], true);
	}

	iLen = sizeof(g_sMeleeName);
	char sBuffer[32];
	for(i = 0; i < iLen; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "scripts/melee/%s.txt", g_sMeleeName[i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}
	
	GetMeleeClasses();
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		CreateTimer(1.0, Timer_StratSpawnMelee, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		CreateTimer(1.0, Timer_StratSpawnMelee, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public Action Timer_StratSpawnMelee(Handle timer)
{
	StratSpawnMelee();
}

void StratSpawnMelee()
{
	if(!g_hEnabled.BoolValue) 
		return;

	int client = GetInGameClient();
	if(client == 0)
		return;

	int iLimit;
	float vOrigin[3]; 
	float vAngles[3];
	GetClientAbsOrigin(client, vOrigin);

	vOrigin[2] += 20.0;
	vAngles[0] = 90.0;

	if(g_hSpawnType.IntValue == 1)
	{
		if(IsGameInFirstHalf())
			SortIntegers(g_iMeleeRandomSpawn, g_iMeleeClassCount, Sort_Random);

		iLimit = g_hRandomAmount.IntValue;
		for(int i; i < iLimit; i++)
			SpawnMelee(g_sMeleeClass[i < g_iMeleeClassCount ? g_iMeleeRandomSpawn[i] : GetRandomInt(0, g_iMeleeClassCount - 1)], vOrigin, vAngles);
	}
	else if(g_hSpawnType.IntValue == 2)
	{
		iLimit = g_hMapBaseAmount.IntValue;
		for(int i; i < iLimit; i++)
			SpawnMelee(g_sMeleeClass[i < g_iMeleeClassCount ? i : i - (RoundToFloor(float(i / g_iMeleeClassCount)) * g_iMeleeClassCount)], vOrigin, vAngles);
	}
	else
		SpawnCustomList(vOrigin, vAngles);
}

stock void SpawnCustomList(const float vPos[3], const float vAng[3])
{
	char sScriptName[32];
	int iLen = sizeof(g_hMeleeItems);
	for(int x; x < iLen; x++)
	{
		for(int i; i < g_hMeleeItems[x].IntValue; i++)
		{
			GetScriptName(g_sMeleeName[x], sScriptName);
			SpawnMelee(sScriptName, vPos, vAng);
		}
	}
}

stock void SpawnMelee(const char[] sClass, const float vPos[3], const float vAng[3])
{
	float vOrigin[3];
	float vAngles[3];
	vOrigin = vPos;
	vAngles = vAng;
	
	vOrigin[0] += (-10.0 + GetRandomFloat(0.0, 20.0));
	vOrigin[1] += (-10.0 + GetRandomFloat(0.0, 20.0));
	vOrigin[2] += GetRandomFloat(0.0, 10.0);
	vAngles[1] = GetRandomFloat(0.0, 360.0);

	int iMeleeSpawn = CreateEntityByName("weapon_melee");
	DispatchKeyValue(iMeleeSpawn, "melee_script_name", sClass);
	DispatchSpawn(iMeleeSpawn);
	TeleportEntity(iMeleeSpawn, vOrigin, vAngles, NULL_VECTOR);
}

stock void GetMeleeClasses()
{
	g_iMeleeClassCount = 0;

	int i;
	for(i = 0; i < 16; i++)
		g_sMeleeClass[i][0] = 0;
	
	int iMeleeStringTable = FindStringTable("MeleeWeapons");
	int iCount = GetStringTableNumStrings(iMeleeStringTable);
	
	char sMeleeClass[16][32];
	for(i = 0; i < iCount; i++)
	{
		ReadStringTable(iMeleeStringTable, i, sMeleeClass[i], sizeof(sMeleeClass[]));
		if(IsVaidMelee(sMeleeClass[i]))
		{
			g_iMeleeRandomSpawn[g_iMeleeClassCount] = g_iMeleeClassCount;
			strcopy(g_sMeleeClass[g_iMeleeClassCount], sizeof(g_sMeleeClass[]), sMeleeClass[i]);
			g_iMeleeClassCount++;
		}
	}
}

stock bool IsVaidMelee(const char[] sWeapon)
{
	bool bIsVaid = false;
	int iEntity = CreateEntityByName("weapon_melee");
	DispatchKeyValue(iEntity, "melee_script_name", sWeapon);
	DispatchSpawn(iEntity);

	char sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	if(StrContains(sModelName, "hunter", false) == -1)
		bIsVaid  = true;

	RemoveEdict(iEntity);
	return bIsVaid;
}

stock void GetScriptName(const char[] sMeleeClass, char[] sScriptName)
{
	for(int i; i < g_iMeleeClassCount; i++)
	{
		if(StrContains(g_sMeleeClass[i], sMeleeClass, false) == 0)
		{
			FormatEx(sScriptName, 32, "%s", g_sMeleeClass[i]);
			return;
		}
	}
	FormatEx(sScriptName, 32, "%s", g_sMeleeClass[GetRandomInt(0, g_iMeleeClassCount - 1)]);	
}

stock int GetInGameClient()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			return i;
	}
	return 0;
}

stock bool IsGameInFirstHalf()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound") ? false : true;
}