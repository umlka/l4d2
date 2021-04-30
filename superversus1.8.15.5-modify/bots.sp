#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "1.8.15.5"
#define GAMEDATA 		"bots"
#define CVAR_FLAGS 		FCVAR_NOTIFY
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED   3
#define TEAM_PASSING    4

StringMap g_hSteamIDs;

Handle g_hSDK_Call_RoundRespawn;
Handle g_hSDK_Call_SetHumanSpec;
Handle g_hSDK_Call_TakeOverBot;
Handle g_hSDK_Call_GoAwayFromKeyboard;
Handle g_hSDK_Call_SetObserverTarget;

Handle g_hBotsUpdateTimer;

Address g_pRespawn;
Address g_pResetStatCondition;

ConVar g_hSurvivorLimit;
ConVar g_hL4DSurvivorLimit;
ConVar g_hAutoJoin; 
ConVar g_hRespawnJoin;
ConVar g_hSpecCmdLimit;
ConVar g_hGiveType;
ConVar g_hGiveRescued;
ConVar g_hSlotFlags[5];
ConVar g_hSpawnFlowLimit;
ConVar g_hSbAllBotGame; 
ConVar g_hAllowAllBotSurvivorTeam;

int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iSurvivorBot;
int g_iSlotCount[5];
int g_iSlotWeapons[5][20];
int g_iMeleeClassCount;
int g_iPlayerBot[MAXPLAYERS + 1];
int g_iBotPlayer[MAXPLAYERS + 1];

bool g_bShouldFixAFK;
bool g_bShouldIgnore;
bool g_bTeamChangeSpec[MAXPLAYERS + 1];

char g_sMeleeClass[16][32];
char g_sEntityModels[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

static const char g_sSurvivorNames[8][] =
{
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Francis",
	"Louis"
};

static const char g_sSurvivorModels[8][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

static const char g_sWeaponName[5][17][] =
{
	{//slot 0(主武器)
		"smg",						//1 UZI微冲
		"smg_mp5",					//2 MP5
		"smg_silenced",				//4 MAC微冲
		"pumpshotgun",				//8 木喷
		"shotgun_chrome",			//16 铁喷
		"rifle",					//32 M16步枪
		"rifle_desert",				//64 三连步枪
		"rifle_ak47",				//128 AK47
		"rifle_sg552",				//256 SG552
		"autoshotgun",				//512 一代连喷
		"shotgun_spas",				//1024 二代连喷
		"hunting_rifle",			//2048 木狙
		"sniper_military",			//4096 军狙
		"sniper_scout",				//8192 鸟狙
		"sniper_awp",				//16384 AWP
		"rifle_m60",				//32768 M60
		"grenade_launcher"			//65536 榴弹发射器
	},
	{//slot 1(副武器)
		"pistol",					//1 小手枪
		"pistol_magnum",			//2 马格南
		"chainsaw",					//4 电锯
		"fireaxe",					//8 斧头
		"frying_pan",				//16 平底锅
		"machete",					//32 砍刀
		"baseball_bat",				//64 棒球棒
		"crowbar",					//128 撬棍
		"cricket_bat",				//256 球拍
		"tonfa",					//512 警棍
		"katana",					//1024 武士刀
		"electric_guitar",			//2048 吉他
		"knife",					//4096 小刀
		"golfclub",					//8192 高尔夫球棍
		"shovel",					//16384 铁铲
		"pitchfork",				//32768 草叉
		"riotshield",				//65536 盾牌
	},
	{//slot 2(投掷物)
		"molotov",					//1 燃烧瓶
		"pipe_bomb",				//2 管制炸弹
		"vomitjar",					//4 胆汁瓶
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		""
	},
	{//slot 3
		"first_aid_kit",			//1 医疗包
		"defibrillator",			//2 电击器
		"upgradepack_incendiary",	//4 燃烧弹药包
		"upgradepack_explosive",	//8 高爆弹药包
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		""
	},
	{//slot 4
		"adrenaline",				//1 肾上腺素
		"pain_pills",				//2 止痛药
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		""
	}
};

static const char g_sWeaponModels[][] =
{
	"models/w_models/weapons/w_smg_uzi.mdl",
	"models/w_models/weapons/w_smg_mp5.mdl",
	"models/w_models/weapons/w_smg_a.mdl",
	"models/w_models/weapons/w_pumpshotgun_A.mdl",
	"models/w_models/weapons/w_shotgun.mdl",
	"models/w_models/weapons/w_rifle_m16a2.mdl",
	"models/w_models/weapons/w_desert_rifle.mdl",
	"models/w_models/weapons/w_rifle_ak47.mdl",
	"models/w_models/weapons/w_rifle_sg552.mdl",
	"models/w_models/weapons/w_autoshot_m4super.mdl",
	"models/w_models/weapons/w_shotgun_spas.mdl",
	"models/w_models/weapons/w_sniper_mini14.mdl",
	"models/w_models/weapons/w_sniper_military.mdl",
	"models/w_models/weapons/w_sniper_scout.mdl",
	"models/w_models/weapons/w_sniper_awp.mdl",
	"models/w_models/weapons/w_m60.mdl",
	"models/w_models/weapons/w_grenade_launcher.mdl",
	
	"models/w_models/weapons/w_pistol_a.mdl",
	"models/w_models/weapons/w_desert_eagle.mdl",
	"models/weapons/melee/w_chainsaw.mdl",
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
	"models/weapons/melee/w_riotshield.mdl",

	"models/w_models/weapons/w_eq_molotov.mdl",
	"models/w_models/weapons/w_eq_pipebomb.mdl",
	"models/w_models/weapons/w_eq_bile_flask.mdl",

	"models/w_models/weapons/w_eq_medkit.mdl",
	"models/w_models/weapons/w_eq_defibrillator.mdl",
	"models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
	"models/w_models/weapons/w_eq_explosive_ammopack.mdl",

	"models/w_models/weapons/w_eq_adrenaline.mdl",
	"models/w_models/weapons/w_eq_painpills.mdl"
};

public Plugin myinfo =
{
	name        = "bots(coop)",
	author      = "DDRKhat, Marcus101RR, Merudo, Lux, Shadowysn, sorallll",
	description = "coop",
	version     = PLUGIN_VERSION,
	url         = "https://forums.alliedmods.net/showthread.php?p=2405322#post2405322"
}

public void OnPluginStart()
{
	LoadGameData();

	g_hL4DSurvivorLimit = FindConVar("survivor_limit");
	g_hSurvivorLimit = CreateConVar("l4d_survivor_limit", "4", "开局Bot的数量", CVAR_FLAGS, true, 1.00, true, 24.00);

	g_hAutoJoin = CreateConVar("l4d_autojoin", "1" , "在玩家连接后,是否自动加入? \n(0=否,1=是)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRespawnJoin = CreateConVar("l4d_respawn_on_join", "1" , "超出开局Bot的数量后进服的玩家是否活着? \n(0=否,1=是.防止玩家死亡后切换队伍或者重进游戏刷复活)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hSpecCmdLimit = CreateConVar("l4d_spec_cmd_limit", "2" , "当完全旁观玩家达到多少个时禁止使用sm_spec命令", CVAR_FLAGS, true, 0.0);
	g_hGiveType = CreateConVar("l4d_extra_type", "2" , "根据什么来给超出开局Bot的数量后进服的玩家装备. \n(0=不给,1=根据每个槽位的设置,2=根据当前所有生还者的平均装备质量(仅主副武器))", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_hGiveRescued = CreateConVar("l4d_give_rescued", "1" , "玩家被从小黑屋救出来后是否给装备 \n(0=不给,1=按照l4d_extra_type的设置给)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hSlotFlags[0] = CreateConVar("l4d_extra_slot0", "131071" , "超出开局Bot的数量后进服的玩家主武器给什么 \n(0=不给,131071=所有,7=微冲,1560=霰弹,30720=狙击,31=Tier1,32736=Tier2,98304=Tier3)", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[1] = CreateConVar("l4d_extra_slot1", "131071" , "超出开局Bot的数量后进服的玩家副武器给什么 \n(0=不给,131071=所有.如果选中了近战且该近战在当前地图上未解锁,则会随机给一把)", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[2] = CreateConVar("l4d_extra_slot2", "7" , "超出开局Bot的数量后进服的玩家投掷物给什么 \n(0=不给,7=所有)", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[3] = CreateConVar("l4d_extra_slot3", "15" , "超出开局Bot的数量后进服的玩家槽位3给什么 \n(0=不给,15=所有)", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[4] = CreateConVar("l4d_extra_slot4", "3" , "超出开局Bot的数量后进服的玩家槽位4给什么 \n(0=不给,3=所有)", CVAR_FLAGS, true, 0.0);
	
	CreateConVar("bots_version", PLUGIN_VERSION, "bots(coop)(给物品Flags参考源码g_sWeaponName中的武器名处的数字,多个武器里面随机则数字取和)", CVAR_FLAGS | FCVAR_DONTRECORD);
	
	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hAllowAllBotSurvivorTeam = FindConVar("allow_all_bot_survivor_team");

	g_hL4DSurvivorLimit.SetBounds(ConVarBound_Upper, true, 24.0);

	//https://forums.alliedmods.net/showthread.php?t=120275
	g_hSpawnFlowLimit = FindConVar("z_spawn_flow_limit");
	g_hSpawnFlowLimit.SetInt(999999999);

	for(int i; i < 5; i++)
		g_hSlotFlags[i].AddChangeHook(ConVarChanged_Slot);

	//AutoExecConfig(true, "l4d_superversus");

	RegConsoleCmd("sm_spec", CmdJoinSpectator, "加入旁观者");
	RegConsoleCmd("sm_join", CmdJoinSurvivor, "加入生还者");
	RegAdminCmd("sm_afk", CmdGoAFK, ADMFLAG_RCON, "闲置(仅存活的生还者可用)");	
	RegConsoleCmd("sm_teams", CmdTeamMenu, "打开团队信息菜单");
	RegAdminCmd("sm_kb", CmdKickAllSurvivorBot, ADMFLAG_RCON, "踢出所有生还者Bot");
	RegAdminCmd("sm_botset", CmdBotSet, ADMFLAG_RCON, "设置开局Bot的数量");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("survivor_rescued", Event_SurvivorRescued);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);

	AddCommandListener(CommandListener_SpecNext, "spec_next");
	
	g_hSteamIDs = new StringMap();
}

public Action CmdJoinSpectator(int client, int args)
{
	if(IsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SPECTATOR)
		return Plugin_Handled;
	
	if(GetTeamSpectator() >= g_hSpecCmdLimit.IntValue)
		return Plugin_Handled;

	ChangeClientTeam(client, TEAM_SPECTATOR);
	return Plugin_Handled;
}

int GetTeamSpectator()
{
	int iSpectator;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SPECTATOR && !GetBotOfIdle(i))
			iSpectator++;
	}
	return iSpectator;
}

public Action CmdJoinSurvivor(int client, int args)
{
	if(IsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	int iBot;
	if((iBot = GetBotOfIdle(client)))
	{
		TakeOverBot(client);
		return Plugin_Handled;
	}
	else
	{
		iBot = GetClientOfUserId(g_iPlayerBot[client]);
		if(iBot == 0 || !IsValidAliveSurvivorBot(iBot))
			iBot = GetAnyValidAliveSurvivorBot();
	}

	int iTeam = GetClientTeam(client);
	if(iTeam != TEAM_SURVIVOR)
	{
		SetGhostStatus(client, 0);

		if(iTeam != TEAM_SPECTATOR)
			ChangeClientTeam(client, TEAM_SPECTATOR);

		if(iBot)
		{
			SetHumanIdle(iBot, client);
			TakeOverBot(client);
		}
		else
		{
			bool canRespawn = g_hRespawnJoin.BoolValue && IsFirstTime(client);
			ChangeClientTeam(client, TEAM_SURVIVOR);

			if(canRespawn && !IsPlayerAlive(client))
			{
				Respawn(client);
				GiveWeapon(client);
				SetGodMode(client, 1.0);
				TeleportToSurvivor(client);
			} 
			else if(g_hRespawnJoin.BoolValue)
				ReplyToCommand(client, "\x01重复加入默认为\x05死亡状态.");
		}
	}
	else if(!IsPlayerAlive(client))
	{
		if(iBot)
		{
			ChangeClientTeam(client, TEAM_SPECTATOR);
			SetHumanIdle(iBot, client);
			TakeOverBot(client);
		}
		else
			ReplyToCommand(client, "\x01你已经\x04死亡\x01. 没有\x05电脑Bot\x01可以接管.");
	}

	return Plugin_Handled;
}

public Action CmdGoAFK(int client, int args)
{
	if(IsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
		return Plugin_Handled;

	GoAwayFromKeyboard(client);
	return Plugin_Handled;
}

public Action CmdTeamMenu(int client, int args)
{
	if(IsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	DisplayTeamMenu(client);
	return Plugin_Handled;
}

public Action CmdKickAllSurvivorBot(int client, int args)
{
	if(IsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2)
			KickClient(i);
	}

	return Plugin_Handled;
}

public Action CmdBotSet(int client, int args)
{
	if(IsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(args == 1)
	{
		char sNumber[4];
		GetCmdArg(1, sNumber, sizeof(sNumber));
		int iNumber = StringToInt(sNumber);
		if(1 <= iNumber <= 24)
		{
			g_hSurvivorLimit.SetInt(iNumber);

			delete g_hBotsUpdateTimer;
			g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
	
			ReplyToCommand(client, "\x01开局Bot数量已设置为 \x05%d.", iNumber);
		}
		else
			ReplyToCommand(client, "请输入1 ~ 24范围内的整数参数.");
	}
	else
		ReplyToCommand(client, "!botset/sm_botset <数量>.");

	return Plugin_Handled;
}

public Action CommandListener_SpecNext(int client, char[] command, int argc)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SPECTATOR || GetBotOfIdle(client))
		return Plugin_Continue;

	if(g_bTeamChangeSpec[client])
	{
		PrintToChat(client, "\x01聊天栏输入 \x05!join \x01加入游戏");
		PrintHintText(client, "聊天栏输入 !join 加入游戏");
		g_bTeamChangeSpec[client] = false;
	}

	return Plugin_Continue;
}

public void OnPluginEnd()
{
	PatchAddress(false);
}

public void OnConfigsExecuted()
{
	GetSlotCvars();
	g_hL4DSurvivorLimit.IntValue = g_hSurvivorLimit.IntValue;
}

public void ConVarChanged_Slot(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetSlotCvars();
}

void GetSlotCvars()
{
	for(int i; i < 5; i++)
	{
		g_iSlotCount[i] = 0;
		if(g_hSlotFlags[i].IntValue > 0)
			GetSlotInfo(i);
	}
}

void GetSlotInfo(int iSlot)
{
	for(int i; i < 17; i++)
	{
		if(g_sWeaponName[iSlot][i][0] == 0)
			return;
		
		if((1 << i) & g_hSlotFlags[iSlot].IntValue)
			g_iSlotWeapons[iSlot][g_iSlotCount[iSlot]++] = i;
	}
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;

	if(IsRoundStarted() == true)
	{
		delete g_hBotsUpdateTimer;
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
	}
}

public Action Timer_BotsUpdate(Handle timer)
{
	g_hBotsUpdateTimer = null;

	if(AreAllInGame() == true)
		SpawnCheck();
	else
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
}

void SpawnCheck()
{
	if(IsRoundStarted() == false)
		return;

	int iSurvivor       = GetSurvivorTeam();
	int iHumanSurvivor  = GetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLim    = g_hSurvivorLimit.IntValue;
	int iSurvivorMax    = iHumanSurvivor > iSurvivorLim ? iHumanSurvivor : iSurvivorLim;

	if(iSurvivor > iSurvivorMax) 
		PrintToConsoleAll("Kicking %d bot(s)", iSurvivor - iSurvivorMax);

	if(iSurvivor < iSurvivorLim) 
		PrintToConsoleAll("Spawning %d bot(s)", iSurvivorLim - iSurvivor);

	for(; iSurvivorMax < iSurvivor; iSurvivorMax++)
		KickUnusedSurvivorBot();
	
	for(; iSurvivor < iSurvivorLim; iSurvivor++)
		SpawnFakeSurvivorClient();
		
	UpdateSurvivorLimitCvar();
}

void KickUnusedSurvivorBot()
{
	int iBot = GetAnyValidSurvivorBot(); //优先踢出没有对应真实玩家且后生成的Bot
	if(iBot)
	{
		DeletePlayerSlotAll(iBot);
		KickClient(iBot, "Kicking Useless Client.");
	}
}

void SpawnFakeSurvivorClient()
{
	int iBot = CreateFakeClient("SurvivorBot");
	if(iBot == 0)
		return;

	ChangeClientTeam(iBot, TEAM_SURVIVOR);

	if(DispatchKeyValue(iBot, "classname", "SurvivorBot") == false)
		return;

	if(DispatchSpawn(iBot) == false)
		return;

	if(!IsPlayerAlive(iBot))
		Respawn(iBot);

	TeleportToSurvivor(iBot);

	if(IsClientInGame(iBot) && IsFakeClient(iBot) && GetClientTeam(iBot) == TEAM_SURVIVOR && !GetIdlePlayer(iBot))
		KickClient(iBot, "Kicking Fake Client.");
}

void UpdateSurvivorLimitCvar()
{
	int iHumanSurvivor = GetTeamPlayers(TEAM_SURVIVOR, false);

	//防止真人生还者数量大于survivor_limit时,出现的一些问题(死亡转旁观以及手动设置survivor_limit参数时暴毙)
	g_hL4DSurvivorLimit.IntValue = iHumanSurvivor > g_hSurvivorLimit.IntValue ? iHumanSurvivor : g_hSurvivorLimit.IntValue; 
}

public void OnMapEnd()
{
	ResetPlugin();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();

	for(int i = 1; i <= MaxClients; i++)
		TakeOver(i);
}

void InitPlugin()
{
	Bots_Intensity(); //加强生还者BOT,需要的去掉注释
	delete g_hBotsUpdateTimer;
}

stock void Bots_Intensity()
{
	int flags = GetCommandFlags("sb_force_max_intensity");
	SetCommandFlags("sb_force_max_intensity", flags & ~FCVAR_CHEAT);
	ServerCommand("sb_force_max_intensity Nick");
	ServerExecute();
	ServerCommand("sb_force_max_intensity Coach");
	ServerExecute();
	ServerCommand("sb_force_max_intensity Ellis");
	ServerExecute();
	ServerCommand("sb_force_max_intensity Rochelle");
	ServerExecute();
	ServerCommand("sb_force_max_intensity Bill");
	ServerExecute();
	ServerCommand("sb_force_max_intensity Zoey");
	ServerExecute();
	ServerCommand("sb_force_max_intensity Louis");
	ServerExecute();
	ServerCommand("sb_force_max_intensity Francis");
	ServerExecute();
	SetCommandFlags("sb_force_max_intensity", flags);
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;

	g_hSteamIDs.Clear();
	
	delete g_hBotsUpdateTimer;
}

bool IsRoundStarted()
{
	return g_iRoundStart && g_iPlayerSpawn;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		InitPlugin();
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		InitPlugin();
	g_iPlayerSpawn = 1;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(GetClientTeam(client) == TEAM_SURVIVOR)
	{
		UpdateSurvivorLimitCvar();

		delete g_hBotsUpdateTimer;
		g_hBotsUpdateTimer = CreateTimer(2.0, Timer_BotsUpdate);
		
		if(!IsFakeClient(client) && IsFirstTime(client))
			RecordSteamID(client);

		SetGhostStatus(client, 0);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	TakeOver(GetClientOfUserId(event.GetInt("userid")));
}

void TakeOver(int bot)
{
	int iIdlePlayer;
	if(bot > 0 && IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == TEAM_SURVIVOR && (iIdlePlayer = GetIdlePlayer(bot)))
	{
		SetHumanIdle(bot, iIdlePlayer);
		TakeOverBot(iIdlePlayer);		
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(IsRoundStarted() == false)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;
		
	int team = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");

	if(team == 2)
		SetGhostStatus(client, 0);

	if(team == TEAM_SPECTATOR)
		g_bTeamChangeSpec[client] = true;
	else if(oldteam == TEAM_SPECTATOR)
		g_bTeamChangeSpec[client] = false;
		
	if(oldteam == 0 && team == 1)
		CreateTimer(0.1, Timer_AutoJoinSurvivorTeam, GetClientUserId(client));
}

public Action Timer_AutoJoinSurvivorTeam(Handle timer, int client)
{
	if(IsRoundStarted() == false || (client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) > TEAM_SPECTATOR || IsPlayerAlive(client) || GetBotOfIdle(client)) 
		return;
	
	if(g_hAutoJoin.BoolValue)
		CmdJoinSurvivor(client, 0);
}

public void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if(client == 0 || !IsClientInGame(client))
		return;

	if(g_hGiveRescued.BoolValue)
		GiveWeapon(client);

	if(!IsFakeClient(client) && CanIdle(client))
		CmdGoAFK(client, 0); //被从小黑屋救出来后闲置,避免有些玩家挂机
}

bool CanIdle(int client)
{
	if(g_hSbAllBotGame.BoolValue || g_hAllowAllBotSurvivorTeam.BoolValue)
		return true;

	int iSurvivor;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
			iSurvivor++;
	}

	return iSurvivor > 0;
}

public void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	int bot_userid = event.GetInt("bot");
	int player_userid = event.GetInt("player");
	int bot = GetClientOfUserId(bot_userid);
	int player = GetClientOfUserId(player_userid);

	if(g_sEntityModels[player][0] == '\0')
		return;

	if(player == 0 || !IsClientInGame(player) || IsFakeClient(player) || !IsSurvivor(player))
		return;

	g_iBotPlayer[bot] = player_userid;
	g_iPlayerBot[player] = bot_userid;

	SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
	SetEntityModel(bot, g_sEntityModels[player]);
	for(int i; i < 8; i++)
	{
		if(strcmp(g_sEntityModels[player], g_sSurvivorModels[i]) == 0)
			SetClientInfo(bot, "name", g_sSurvivorNames[i]);
	}
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if(player == 0 || !IsClientInGame(player) || IsFakeClient(player) || !IsSurvivor(player))
		return;

	static char sModel[PLATFORM_MAX_PATH];
	int bot = GetClientOfUserId(event.GetInt("bot"));
	GetClientModel(bot, sModel, sizeof(sModel));
	SetEntityModel(player, sModel);
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));
}

bool IsSurvivor(int client)
{
	if(GetClientTeam(client) != TEAM_SURVIVOR && GetClientTeam(client) != TEAM_PASSING)
		return false;
	return true;
}

public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	int entity = FindEntityByClassname(MaxClients + 1, "info_survivor_position");
	if(entity != INVALID_ENT_REFERENCE)
	{
		int iPlayer;
		float vOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
		for(int i = 1; i <= MaxClients; i++)
		{
			if(iPlayer++ < 4)
				continue;

			if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
			{
				entity = CreateEntityByName("info_survivor_position");
				DispatchSpawn(entity);
				TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

bool AreAllInGame()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i)) //加载中
			return false;
	}
	return true;
}

bool IsFirstTime(int client)
{
	if(!IsClientInGame(client) || IsFakeClient(client)) 
		return false;
	
	char sSteamID[64];
	if(!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID))) 
		return false;

	bool bAllowed;
	if(!g_hSteamIDs.GetValue(sSteamID, bAllowed))  // If can't find the entry in map
	{
		g_hSteamIDs.SetValue(sSteamID, true, true);
		bAllowed = true;
	}

	return bAllowed;
}

void RecordSteamID(int client)
{
	char sSteamID[64];
	if(GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID))) 
		g_hSteamIDs.SetValue(sSteamID, false, true);
}

int GetBotOfIdle(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && (GetIdlePlayer(i) == client)) 
			return i;
	}
	return 0;
}

int GetIdlePlayer(int client)
{
	if(IsPlayerAlive(client))
		return HasIdlePlayer(client);

	return 0;
}

int HasIdlePlayer(int client)
{
	if(HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
	{
		client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
		if(client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPECTATOR)
			return client;
	}
	return 0;
}

int GetSurvivorTeam()
{
	return GetTeamPlayers(TEAM_SURVIVOR, true);
}

int GetTeamPlayers(int team, bool bIncludeBots)
{
	int iPlayers;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == team)
		{
			if(!bIncludeBots && IsFakeClient(i) && !GetIdlePlayer(i))
				continue;

			iPlayers++;
		}
	}
	return iPlayers;
}

bool IsValidSurvivorBot(int client)
{
	return IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && !IsClientInKickQueue(client) && !HasIdlePlayer(client);
}

bool IsValidAliveSurvivorBot(int client)
{
	return IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsClientInKickQueue(client) && !HasIdlePlayer(client);
}

int GetAnyValidSurvivorBot()
{
	int iPlayer, iHasPlayer, iNotPlayer;
	int[] iHasPlayerBots = new int[MaxClients];
	int[] iNotPlayerBots = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidSurvivorBot(i))
		{
			if((iPlayer = GetClientOfUserId(g_iBotPlayer[i])) && IsClientInGame(iPlayer) && !IsFakeClient(iPlayer) && GetClientTeam(iPlayer) != 2)
				iHasPlayerBots[iHasPlayer++] = i;
			else
				iNotPlayerBots[iNotPlayer++] = i;
		}
	}

	if(iNotPlayer == 0)
	{
		if(iHasPlayer == 0)
			iPlayer = 0;
		else
		{
			SortIntegers(iHasPlayerBots, iHasPlayer, Sort_Descending);
			iPlayer = iHasPlayerBots[0];
		}
	}
	else
	{
		SortIntegers(iNotPlayerBots, iNotPlayer, Sort_Descending);
		iPlayer = iNotPlayerBots[0];
	}
	
	return iPlayer;
}

int GetAnyValidAliveSurvivorBot()
{
	int iPlayer, iHasPlayer, iNotPlayer;
	int[] iHasPlayerBots = new int[MaxClients];
	int[] iNotPlayerBots = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidAliveSurvivorBot(i)) 
		{
			if((iPlayer = GetClientOfUserId(g_iBotPlayer[i])) && IsClientInGame(iPlayer) && !IsFakeClient(iPlayer) && GetClientTeam(iPlayer) != 2)
				iHasPlayerBots[iHasPlayer++] = i;
			else
				iNotPlayerBots[iNotPlayer++] = i;
		}
	}
	return (iNotPlayer == 0) ? (iHasPlayer == 0 ? 0 : iHasPlayerBots[GetRandomInt(0, iHasPlayer - 1)]) : iNotPlayerBots[GetRandomInt(0, iNotPlayer - 1)];
}

int CountAvailableSurvivorBots()
{
	int iNum;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidSurvivorBot(i))
			iNum++;
	}
	return iNum;
}

static const char g_sZombieClass[][] =
{
	"None",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank"
};

void DisplayTeamMenu(int client)
{
	Panel TeamPanel = new Panel();
	TeamPanel.SetTitle("---------★团队信息★---------");

	char sInfo[PLATFORM_MAX_PATH];
	FormatEx(sInfo, sizeof(sInfo), "旁观者 (%d)", GetTeamPlayers(TEAM_SPECTATOR, false));
	TeamPanel.DrawItem(sInfo);

	int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SPECTATOR)
		{
			FormatEx(sInfo, sizeof(sInfo), "%N", i);
			ReplaceString(sInfo, sizeof(sInfo), "[", "");
			
			if(GetBotOfIdle(i))
				Format(sInfo, sizeof(sInfo), "闲置 - %s", sInfo);
			else
				Format(sInfo, sizeof(sInfo), "观众 - %s", sInfo);

			TeamPanel.DrawText(sInfo);
		}
	}

	FormatEx(sInfo, sizeof(sInfo), "生还者 (%d/%d) - %d Bot(s)", GetTeamPlayers(TEAM_SURVIVOR, false), g_hSurvivorLimit.IntValue, CountAvailableSurvivorBots());
	TeamPanel.DrawItem(sInfo);

	int iIncapacitatedCount = FindConVar("survivor_max_incapacitated_count").IntValue;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			FormatEx(sInfo, sizeof(sInfo), "%N", i);
			ReplaceString(sInfo, sizeof(sInfo), "[", "");
	
			if(IsPlayerAlive(i))
			{
				if(GetEntProp(i, Prop_Send, "m_isIncapacitated"))
					Format(sInfo, sizeof(sInfo), "倒地 - %d HP - %s", GetClientRealHealth(i), sInfo);
				else if(GetEntProp(i, Prop_Send, "m_currentReviveCount") == iIncapacitatedCount)
					Format(sInfo, sizeof(sInfo), "黑白 - %d HP - %s", GetClientRealHealth(i), sInfo);
				else
					Format(sInfo, sizeof(sInfo), "%dHP - %s", GetClientRealHealth(i), sInfo);
	
			}
			else
				Format(sInfo, sizeof(sInfo), "死亡 - %s", sInfo);

			TeamPanel.DrawText(sInfo);
		}
	}

	FormatEx(sInfo, sizeof(sInfo), "感染者 (%d)", GetTeamPlayers(TEAM_INFECTED, false));
	
	TeamPanel.DrawItem(sInfo);

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			int iZombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
			if(iZombieClass < 0 || iZombieClass > 8)
				iZombieClass = 0;

			if(IsFakeClient(i) && iZombieClass != 8) 
				continue ;

			FormatEx(sInfo, sizeof(sInfo), "%N", i);
			ReplaceString(sInfo, sizeof(sInfo), "[", "");

			if(IsPlayerAlive(i))
			{
				if(GetEntProp(i, Prop_Send, "m_isGhost"))
					Format(sInfo, sizeof(sInfo), "(%s)鬼魂 - %s", g_sZombieClass[iZombieClass], sInfo);
				else
					Format(sInfo, sizeof(sInfo), "(%s)%d HP - %s", g_sZombieClass[iZombieClass], GetEntProp(i, Prop_Data, "m_iHealth"), sInfo);
			}
			else
				Format(sInfo, sizeof(sInfo), "(%s)死亡 - %s", g_sZombieClass[iZombieClass], sInfo);

			TeamPanel.DrawText(sInfo);
		}
	}

	TeamPanel.DrawItem("刷新");

	TeamPanel.Send(client, TeamMenuHandler, 30);
	delete TeamPanel;
}

public int TeamMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
			if(param2 == 4)
				DisplayTeamMenu(client);

		case MenuAction_End:
			delete menu;
	}
}

int GetClientRealHealth(int client)
{
	return RoundToFloor(GetClientHealth(client) + GetTempHealth(client));
}

float GetTempHealth(int client)
{
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue;
	return fHealth < 0.0 ? 0.0 : fHealth;
}

void SetGodMode(int client, float fDuration)
{
	if(!IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 0);

	if(fDuration > 0.0) 
		CreateTimer(fDuration, Timer_Mortal, GetClientUserId(client));
}

public Action Timer_Mortal(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 2);
}

void GiveWeapon(int client)
{
	if(!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) 
		return;

	switch(g_hGiveType.IntValue)
	{
		case 1:
			GivePresetWeapon(client);
		
		case 2:
			GiveAverageWeapon(client);
	}
}

void GivePresetWeapon(int client)
{
	for(int i; i < 5; i++)
	{
		if(g_iSlotCount[i] == 0)
			continue;

		DeletePlayerSlotX(client, i);
		int iRandom = g_iSlotWeapons[i][GetRandomInt(0, g_iSlotCount[i] - 1)];
		if(i == 1 && iRandom > 2)
			GiveMeleeWeapon(client, g_sWeaponName[1][iRandom]);
		else
			CheatCmd_Give(client, g_sWeaponName[i][iRandom]);
	}
}

bool IsWeaponTier1(int iWeapon)
{
	char sWeapon[32];
	GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
	for(int i; i < 5; i++)
	{
		if(strcmp(sWeapon[7], g_sWeaponName[0][i]) == 0) 
			return true;
	}
	return false;
}

void GiveAverageWeapon(int client)
{
	int i, iWeapon, iTier, iTotal;
	for(i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			iTotal += 1;	
			iWeapon = GetPlayerWeaponSlot(i, 0);
			if(iWeapon <= MaxClients || !IsValidEntity(iWeapon)) 
				continue;

			if(IsWeaponTier1(iWeapon)) 
				iTier += 1;
			else 
				iTier += 2;
		}
	}

	int iAverage = iTotal > 0 ? RoundToNearest(1.0 * iTier / iTotal) : 0;

	DeletePlayerSlotX(client, 0);
	switch(iAverage)
	{
		case 0:
			GiveSecondaryWeapon(client);

		case 1:
			CheatCmd_Give(client, g_sWeaponName[0][GetRandomInt(0, 4)]); //随机给一把tier1武器

		case 2: 
			CheatCmd_Give(client, g_sWeaponName[0][GetRandomInt(5, 14)]); //随机给一把tier2武器
			
	}
	
	for(i = 3; i < 5; i++)
	{
		if(g_iSlotCount[i] == 0)
			continue;

		DeletePlayerSlotX(client, i);
		CheatCmd_Give(client, g_sWeaponName[i][g_iSlotWeapons[i][GetRandomInt(0, g_iSlotCount[i] - 1)]]);
	}
}

void GiveSecondaryWeapon(int client)
{
	if(g_iSlotCount[1] == 0)
		return;

	DeletePlayerSlotX(client, 1);
	int iRandom = g_iSlotWeapons[1][GetRandomInt(0, g_iSlotCount[1] - 1)];
	if(iRandom > 2)
		GiveMeleeWeapon(client, g_sWeaponName[1][iRandom]);
	else
		CheatCmd_Give(client, g_sWeaponName[1][iRandom]);
}

stock void CheatCmd_Give(int client, const char[] args = "")
{
	int bits = GetUserFlagBits(client);
	int flags = GetCommandFlags("give");
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);			   
	FakeClientCommand(client, "give %s", args);
	SetCommandFlags("give", flags);
	SetUserFlagBits(client, bits);
}

void TeleportToSurvivor(int client)
{
	int iTarget = GetTeleportTarget(client);
	if(iTarget != -1)
	{
		ForceCrouch(client);

		float vPos[3];
		GetClientAbsOrigin(iTarget, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

int GetTeleportTarget(int client)
{
	int iNormal, iIncap, iHanging;
	int[] iNormalSurvivors = new int[MaxClients];
	int[] iIncapSurvivors = new int[MaxClients];
	int[] iHangingSurvivors = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			if(GetEntProp(i, Prop_Send, "m_isIncapacitated") > 0)
			{
				if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") > 0)
					iHangingSurvivors[iHanging++] = i;
				else
					iIncapSurvivors[iIncap++] = i;
			}
			else
				iNormalSurvivors[iNormal++] = i;
		}
	}
	return (iNormal == 0) ? (iIncap == 0 ? (iHanging == 0 ? -1 : iHangingSurvivors[GetRandomInt(0, iHanging - 1)]) : iIncapSurvivors[GetRandomInt(0, iIncap - 1)]) :iNormalSurvivors[GetRandomInt(0, iNormal - 1)];
}

void ForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

void SetGhostStatus(int client, int iGhost)
{
	if(GetEntProp(client, Prop_Send, "m_isGhost") != iGhost)
		SetEntProp(client, Prop_Send, "m_isGhost", iGhost); 
}

stock void DeletePlayerSlot(int client, int iWeapon)
{		
	if(RemovePlayerItem(client, iWeapon))
		RemoveEntity(iWeapon);
}

stock void DeletePlayerSlotX(int client, int iSlot)
{
	iSlot = GetPlayerWeaponSlot(client, iSlot);
	if(iSlot > 0)
	{
		if(RemovePlayerItem(client, iSlot))
			RemoveEntity(iSlot);
	}
}

stock void DeletePlayerSlotAll(int client)
{
	int iSlot;
	for(int i; i < 5; i++)
	{
		iSlot = GetPlayerWeaponSlot(client, i);
		if(iSlot > 0)
			DeletePlayerSlot(client, iSlot);
	}
}

//给玩家近战
//https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484
public void OnMapStart()
{
	g_hSpawnFlowLimit.SetInt(999999999);

	int i;
	int iLen;

	iLen = sizeof(g_sWeaponModels);
	for(i = 0; i < iLen; i++)
	{
		if(!IsModelPrecached(g_sWeaponModels[i]))
			PrecacheModel(g_sWeaponModels[i], true);
	}

	char sBuffer[32];
	for(i = 3; i < 17; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}
	
	GetMeleeClasses();
}

stock void GetMeleeClasses()
{
	int iMeleeStringTable = FindStringTable("MeleeWeapons");
	g_iMeleeClassCount = GetStringTableNumStrings(iMeleeStringTable);

	for(int i; i < g_iMeleeClassCount; i++)
		ReadStringTable(iMeleeStringTable, i, g_sMeleeClass[i], sizeof(g_sMeleeClass[]));
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

stock void GiveMeleeWeapon(int client, const char[] sMeleeClass)
{
	char sScriptName[32];
	GetScriptName(sMeleeClass, sScriptName);
	CheatCmd_Give(client, sScriptName);
}

void LoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false) 
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "RoundRespawn") == false)
		SetFailState("Failed to find signature: RoundRespawn");
	g_hSDK_Call_RoundRespawn = EndPrepSDKCall();
	if(g_hSDK_Call_RoundRespawn == null)
		SetFailState("Failed to create SDKCall: RoundRespawn");

	RoundRespawnPatch(hGameData);

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SetHumanSpec") == false)
		SetFailState("Failed to find signature: SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_Call_SetHumanSpec = EndPrepSDKCall();
	if(g_hSDK_Call_SetHumanSpec == null)
		SetFailState("Failed to create SDKCall: SetHumanSpec");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TakeOverBot") == false)
		SetFailState("Failed to find signature: TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_TakeOverBot = EndPrepSDKCall();
	if(g_hSDK_Call_TakeOverBot == null)
		SetFailState("Failed to create SDKCall: TakeOverBot");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_GoAwayFromKeyboard = EndPrepSDKCall();
	if(g_hSDK_Call_GoAwayFromKeyboard == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GoAwayFromKeyboard");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorPlayer::SetObserverTarget") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::SetObserverTarget");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_Call_SetObserverTarget = EndPrepSDKCall();
	if(g_hSDK_Call_SetObserverTarget == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::SetObserverTarget");

	SetupDetours(hGameData);

	delete hGameData;
}

void RoundRespawnPatch(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if(iOffset == -1)
		SetFailState("Failed to find offset: RoundRespawn_Offset");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to find byte: RoundRespawn_Byte");

	g_pRespawn = hGameData.GetAddress("RoundRespawn");
	if(!g_pRespawn)
		SetFailState("Failed to find address: RoundRespawn");
	
	g_pResetStatCondition = g_pRespawn + view_as<Address>(iOffset);
	
	int iByteOrigin = LoadFromAddress(g_pResetStatCondition, NumberType_Int8);
	if(iByteOrigin != iByteMatch)
		SetFailState("Failed to load, byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void Respawn(int client)
{
	PatchAddress(true);
	SDKCall(g_hSDK_Call_RoundRespawn, client);
	PatchAddress(false);
}

//https://forums.alliedmods.net/showthread.php?t=323220
void PatchAddress(bool bPatch) // Prevents respawn command from reset the player's statistics
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		StoreToAddress(g_pResetStatCondition, 0x79, NumberType_Int8); // if (!bool) - 0x75 JNZ => 0x78 JNS (jump short if not sign) - always not jump
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		StoreToAddress(g_pResetStatCondition, 0x75, NumberType_Int8);
	}
}

void SetHumanIdle(int bot, int client)
{
	SDKCall(g_hSDK_Call_SetHumanSpec, bot, client);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
}

void TakeOverBot(int client)
{
	SDKCall(g_hSDK_Call_TakeOverBot, client, true);
}

//https://forums.alliedmods.net/showthread.php?p=2005618?p=2005618
bool GoAwayFromKeyboard(int client)
{
	return SDKCall(g_hSDK_Call_GoAwayFromKeyboard, client);
}

void SetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour;
	dDetour = DynamicDetour.FromConf(hGameData, "SetHumanSpec");
	if(dDetour == null)
		SetFailState("Failed to find signature: SetHumanSpec");
		
	if(!dDetour.Enable(Hook_Pre, SetHumanSpecPre))
		SetFailState("Failed to detour pre: SetHumanSpec");

	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GoAwayFromKeyboard");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");

	if(!dDetour.Enable(Hook_Pre, PlayerGoAwayFromKeyboardPre))
		SetFailState("Failed to detour pre: CTerrorPlayer::GoAwayFromKeyboard");

	if(!dDetour.Enable(Hook_Post, PlayerGoAwayFromKeyboardPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GoAwayFromKeyboard");
	
	dDetour = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	dDetour.SetFromConf(hGameData, SDKConf_Signature, "CBasePlayer::SetModel");
	dDetour.AddParam(HookParamType_CharPtr);
	dDetour.Enable(Hook_Pre, SetModelPre);
	dDetour.Enable(Hook_Post, SetModelPost);
}

//AFK Fix https://forums.alliedmods.net/showthread.php?p=2714236
public void OnEntityCreated(int entity, const char[] classname)
{
	if(!g_bShouldFixAFK)
		return;
	
	if(classname[0] != 's' || strcmp(classname, "survivor_bot", false) != 0)
		return;
	
	g_iSurvivorBot = entity;
}

public MRESReturn SetHumanSpecPre(int pThis, DHookParam hParams)
{
	if(g_bShouldIgnore)
		return MRES_Ignored;
	
	if(!g_bShouldFixAFK)
		return MRES_Ignored;
	
	if(g_iSurvivorBot < 1)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

public MRESReturn PlayerGoAwayFromKeyboardPre(int pThis, DHookReturn hReturn)
{
	g_bShouldFixAFK = true;
	return MRES_Ignored;
}

public MRESReturn PlayerGoAwayFromKeyboardPost(int pThis, DHookReturn hReturn)
{
	if(g_bShouldFixAFK && g_iSurvivorBot > 0 && IsFakeClient(g_iSurvivorBot))
	{
		g_bShouldIgnore = true;
		
		SDKCall(g_hSDK_Call_SetHumanSpec, g_iSurvivorBot, pThis);
		SDKCall(g_hSDK_Call_SetObserverTarget, pThis, g_iSurvivorBot);

		WriteTakeoverPanel(pThis, g_iSurvivorBot);
		
		g_bShouldIgnore = false;
	}
	
	g_iSurvivorBot = 0;
	g_bShouldFixAFK = false;
	return MRES_Ignored;
}

//Identity Fix https://forums.alliedmods.net/showpost.php?p=2718792&postcount=36
public MRESReturn SetModelPre(int pThis, DHookParam hParams)
{
	// We need this pre hook even though it's empty, or else the post hook will crash the game.
}

public MRESReturn SetModelPost(int pThis, DHookParam hParams)
{
	if(pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis))
		return MRES_Ignored;

	if(!IsSurvivor(pThis))
	{
		g_sEntityModels[pThis][0] = '\0';
		return MRES_Ignored;
	}
	
	static char sModel[PLATFORM_MAX_PATH];
	hParams.GetString(1, sModel, sizeof(sModel));
	if(StrContains(sModel, "models/infected", false) == -1)
		strcopy(g_sEntityModels[pThis], sizeof(g_sEntityModels), sModel);

	return MRES_Ignored;
}

void WriteTakeoverPanel(int client, int bot)
{
	char sBuffer[2];
	IntToString(GetEntProp(bot, Prop_Send, "m_survivorCharacter"), sBuffer, sizeof(sBuffer));
	BfWrite bf = view_as<BfWrite>(StartMessageOne("VGUIMenu", client));
	bf.WriteString("takeover_survivor_bar");
	bf.WriteByte(true);
	bf.WriteByte(1);
	bf.WriteString("character");
	bf.WriteString(sBuffer);
	EndMessage();
}
