#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define VERSION "3.1.0"

ArrayList
	g_aMeleeScripts;

ConVar
	g_hEnabled,
	g_hSpawnType,
	g_hRandomAmount,
	g_hMapBaseAmount,
	g_hMeleeItems[14];

int
	g_iRoundStart,
	g_iPlayerSpawn;

static const char 
	g_sMeleeModels[][] =
	{
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl"
	},
	g_sMeleeName[][] =
	{
		"fireaxe",			//斧头
		"frying_pan",		//平底锅
		"machete",			//砍刀
		"baseball_bat",		//棒球棒
		"crowbar",			//撬棍
		"cricket_bat",		//球拍
		"tonfa",			//警棍
		"katana",			//武士刀
		"electric_guitar",	//吉他
		"knife",			//小刀
		"golfclub",			//高尔夫球棍
		"shovel",			//铁铲
		"pitchfork",		//草叉
		"riotshield",		//盾牌
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
	g_aMeleeScripts = new ArrayList(64);

	CreateConVar("l4d2_mitsr_version", VERSION, "The version of Melee In The Saferoom"); 
	g_hEnabled = CreateConVar("l4d2_mitsr_enabled", "1", "Should the plugin be enabled", _, true, 0.0, true, 1.0);
	g_hSpawnType = CreateConVar("l4d2_mitsr_spawn_type", "1", "0 = Custom list, 1 = Random Weapon and 2 = Map based weapons.", _, true, 0.0, true, 2.0);
	g_hRandomAmount	= CreateConVar("l4d2_mitsr_random_amount", "4","Number of weapons to spawn if l4d2_mitsr_spawn_type is set to 1.", _, true, 0.0, true, 32.0);
	g_hMapBaseAmount = CreateConVar("l4d2_mitsr_mapbase_amount", "4", "Number multiple if l4d2_mitsr_spawn_type is set to 2.", _, true, 0.0, true, 32.0);
		
	g_hMeleeItems[0] = CreateConVar("l4d2_mitsr_fireaxe", "1", "Number of fireaxes to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[1] = CreateConVar("l4d2_mitsr_fryingpan", "1", "Number of frying pans to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[2] = CreateConVar("l4d2_mitsr_machete", "1", "Number of machetes to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[3] = CreateConVar("l4d2_mitsr_baseballbat", "1", "Number of baseball bats to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[4] = CreateConVar("l4d2_mitsr_crowbar", "1", "Number of crowbars to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[5] = CreateConVar("l4d2_mitsr_cricketbat", "1", "Number of cricket bats to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[6] = CreateConVar("l4d2_mitsr_tonfa", "1", "Number of tonfas to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[7] = CreateConVar("l4d2_mitsr_katana", "1", "Number of katanas to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[8] = CreateConVar("l4d2_mitsr_elecguitar", "1", "Number of electric guitars to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[9] = CreateConVar("l4d2_mitsr_knife", "1", "Number of knifes to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[10] = CreateConVar("l4d2_mitsr_golfclub", "1", "Number of golf clubs to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[11] = CreateConVar("l4d2_mitsr_shovel", "1", "Number of shovels to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[12] = CreateConVar("l4d2_mitsr_pitchfork", "1", "Number of pitchforks to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	g_hMeleeItems[13] = CreateConVar("l4d2_mitsr_riotshield", "1", "Number of tonfas to spawn (l4d2_mitsr_spawn_type must be 0)", _, true, 0.0, true, 10.0);
	
	//AutoExecConfig(true, "l4d2_melee_in_the_saferoom");
	
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_melee",	cmdMelee, ADMFLAG_KICK, "Lists all melee weapons spawnable in current campaign"); 
}

Action cmdMelee(int client, int args)
{	
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
		ReplyToCommand(client, "地图尚未开始");
	else
	{
		ReplyToCommand(client, "当前地图已解锁近战:");

		char sScriptName[64];
		int iLength = g_aMeleeScripts.Length;
		for(int i; i < iLength; i++)
		{
			g_aMeleeScripts.GetString(i, sScriptName, sizeof sScriptName);
			ReplyToCommand(client, "%d : %s", i, sScriptName);
		}
	}

	return Plugin_Handled;
}

public void OnMapStart()
{
	int i;
	int iLen;

	iLen = sizeof g_sMeleeModels;
	for(i = 0; i < iLen; i++)
	{
		if(!IsModelPrecached(g_sMeleeModels[i]))
			PrecacheModel(g_sMeleeModels[i], true);
	}

	iLen = sizeof g_sMeleeName;
	char sBuffer[64];
	for(i = 0; i < iLen; i++)
	{
		FormatEx(sBuffer, sizeof sBuffer, "scripts/melee/%s.txt", g_sMeleeName[i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}
	
	vGetMeleeWeaponsStringTable();
}

void vGetMeleeWeaponsStringTable()
{
	g_aMeleeScripts.Clear();

	int iTable = FindStringTable("meleeweapons");
	if(iTable != INVALID_STRING_TABLE)
	{
		int iNum = GetStringTableNumStrings(iTable);
		char sMeleeName[64];
		for(int i; i < iNum; i++)
		{
			ReadStringTable(iTable, i, sMeleeName, sizeof sMeleeName);
			g_aMeleeScripts.PushString(sMeleeName);
		}
	}
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		CreateTimer(1.0, tmrStartSpawnMelee, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		CreateTimer(1.0, tmrStartSpawnMelee, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

Action tmrStartSpawnMelee(Handle timer)
{
	vStartSpawnMelee();
	return Plugin_Continue;
}

void vStartSpawnMelee()
{
	if(!g_hEnabled.BoolValue) 
		return;

	int client = ivGetInGameClient();
	if(!client)
		return;

	int iLimit;
	float vOrigin[3]; 
	float vAngles[3];
	GetClientAbsOrigin(client, vOrigin);

	vOrigin[2] += 20.0;
	vAngles[0] = 90.0;

	int iLength = g_aMeleeScripts.Length;

	if(g_hSpawnType.IntValue == 1)
	{
		static ArrayList aRandomMelee;

		if(bIsGameInFirstHalf())
		{
			if(aRandomMelee != null)
				aRandomMelee.Clear();

			aRandomMelee = g_aMeleeScripts.Clone();
			aRandomMelee.Sort(Sort_Random, Sort_String);
		}

		char sScriptName[64];
		iLimit = g_hRandomAmount.IntValue;
		for(int i; i < iLimit; i++)
		{
			aRandomMelee.GetString(i < iLength ? i : GetRandomInt(0, iLength - 1), sScriptName, sizeof sScriptName);
			vSpawnMelee(sScriptName, vOrigin, vAngles);
		}
	}
	else if(g_hSpawnType.IntValue == 2)
	{
		char sScriptName[64];
		iLimit = g_hMapBaseAmount.IntValue;
		for(int i; i < iLimit; i++)
		{
			g_aMeleeScripts.GetString(i < iLength ? i : i - (RoundToFloor(float(i / iLength)) * iLength), sScriptName, sizeof sScriptName);
			vSpawnMelee(sScriptName, vOrigin, vAngles);
		}
	}
	else
		vSpawnCustomList(vOrigin, vAngles);
}

void vSpawnMelee(const char[] sClass, const float vPos[3], const float vAng[3])
{
	float vOrigin[3];
	float vAngles[3];
	vOrigin = vPos;
	vAngles = vAng;
	
	vOrigin[0] += (-10.0 + GetRandomFloat(0.0, 20.0));
	vOrigin[1] += (-10.0 + GetRandomFloat(0.0, 20.0));
	vOrigin[2] += GetRandomFloat(0.0, 10.0);
	vAngles[1] = GetRandomFloat(0.0, 360.0);

	int entity = CreateEntityByName("weapon_melee");
	DispatchKeyValue(entity, "solid", "6");
	DispatchKeyValue(entity, "melee_script_name", sClass);
	DispatchSpawn(entity);
	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);

	//SetEntityMoveType(entity, MOVETYPE_NONE);
}

void vSpawnCustomList(const float vPos[3], const float vAng[3])
{
	char sScriptName[64];
	int iLength = sizeof g_hMeleeItems;
	for(int x; x < iLength; x++)
	{
		for(int i; i < g_hMeleeItems[x].IntValue; i++)
		{
			if(g_aMeleeScripts.FindString(g_sMeleeName[x]) != -1)
				strcopy(sScriptName, sizeof sScriptName, g_sMeleeName[x]);
			else
				g_aMeleeScripts.GetString(GetRandomInt(0, g_aMeleeScripts.Length - 1), sScriptName, sizeof sScriptName);
	
			vSpawnMelee(sScriptName, vPos, vAng);
		}
	}
}

int ivGetInGameClient()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			return i;
	}
	return 0;
}

bool bIsGameInFirstHalf()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound") ? false : true;
}
