#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "1.9.1"
#define GAMEDATA 		"bots"
#define CVAR_FLAGS 		FCVAR_NOTIFY
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED   3

StringMap
	g_aSteamIDs;

Handle
	g_hBotsUpdateTimer,
	g_hSDKRoundRespawn,
	g_hSDKSetHumanSpectator,
	g_hSDKTakeOverBot,
	g_hSDKSetObserverTarget,
	g_hSDKGoAwayFromKeyboard;

Address
	g_pStatsCondition;

ConVar
	g_hSurvivorLimit,
	g_hBotsSurvivorLimit,
	g_hAutoJoin,
	g_hRespawnJoin,
	g_hSpecCmdLimit,
	g_hGiveWeaponType,
	g_hSlotFlags[5],
	g_hSbAllBotGame,
	g_hAllowAllBotSurvivorTeam;

int
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iSurvivorBot,
	g_iBotsSurvivorLimit,
	g_iSpecCmdLimit,
	g_iSlotCount[5],
	g_iSlotWeapons[5][20],
	g_iMeleeClassCount,
	g_iPlayerBot[MAXPLAYERS + 1],
	g_iBotPlayer[MAXPLAYERS + 1];

bool
	g_bShouldFixAFK,
	g_bShouldIgnore,
	g_bAutoJoin,
	g_bRespawnJoin,
	g_bGiveWeaponType,
	g_bSpecNotify[MAXPLAYERS + 1];

char
	g_sMeleeClass[16][32],
	g_sPlayerModel[MAXPLAYERS + 1][128];

static const char
	g_sSurvivorNames[8][] =
	{
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis"
	},
	g_sSurvivorModels[8][] =
	{
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	},
	g_sWeaponName[5][17][] =
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
			"pain_pills",				//1 止痛药
			"adrenaline",				//2 肾上腺素
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
	},
	g_sWeaponModels[][] =
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

//如果签名失效，请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo =
{
	name		= "bots(coop)",
	author		= "DDRKhat, Marcus101RR, Merudo, Lux, Shadowysn, sorallll",
	description	= "coop",
	version		= PLUGIN_VERSION,
	url			= "https://forums.alliedmods.net/showthread.php?p=2405322#post2405322"
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hSurvivorLimit = FindConVar("survivor_limit");
	g_hBotsSurvivorLimit = CreateConVar("bots_survivor_limit", "4", "开局Bot的数量", CVAR_FLAGS, true, 1.00, true, 31.0);

	g_hAutoJoin = CreateConVar("bots_auto_join_survivor", "1", "玩家连接后,是否自动加入生还者? \n0=否,1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hRespawnJoin = CreateConVar("bots_respawn_on_join", "1", "玩家第一次进服时如果没有存活的Bot可以接管是否复活? \n0=否,1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hSpecCmdLimit = CreateConVar("bots_spec_cmd_limit", "1", "当完全旁观玩家达到多少个时禁止使用sm_spec命令", CVAR_FLAGS, true, 0.0);
	g_hGiveWeaponType = CreateConVar("bots_give_type", "2", "根据什么来给玩家装备. \n0=不给,1=根据每个槽位的设置,2=根据当前所有生还者的平均装备质量(仅主副武器)", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_hSlotFlags[0] = CreateConVar("bots_give_slot0", "131071", "主武器给什么 \n0=不给,131071=所有,7=微冲,1560=霰弹,30720=狙击,31=Tier1,32736=Tier2,98304=Tier0", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[1] = CreateConVar("bots_give_slot1", "5160", "副武器给什么 \n0=不给,131071=所有.如果选中了近战且该近战在当前地图上未解锁,则会随机给一把", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[2] = CreateConVar("bots_give_slot2", "0", "投掷物给什么 \n0=不给,7=所有", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[3] = CreateConVar("bots_give_slot3", "3", "槽位3给什么 \n0=不给,15=所有", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[4] = CreateConVar("bots_give_slot4", "3", "槽位4给什么 \n0=不给,3=所有", CVAR_FLAGS, true, 0.0);

	CreateConVar("bots_version", PLUGIN_VERSION, "bots(coop)(给物品Flags参考源码g_sWeaponName中的武器名处的数字,多个武器里面随机则数字取和)", CVAR_FLAGS | FCVAR_DONTRECORD);
	
	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hAllowAllBotSurvivorTeam = FindConVar("allow_all_bot_survivor_team");

	g_hSurvivorLimit.Flags &= ~FCVAR_NOTIFY; //移除ConVar变动提示
	g_hSurvivorLimit.SetBounds(ConVarBound_Upper, true, 31.0);

	//https://forums.alliedmods.net/showthread.php?t=120275
	ConVar hConVar = FindConVar("z_spawn_flow_limit");
	hConVar.SetBounds(ConVarBound_Lower, true, 999999999.0);
	hConVar.SetBounds(ConVarBound_Upper, true, 999999999.0);
	hConVar.IntValue = 999999999;

	g_hAutoJoin.AddChangeHook(vOtherConVarChanged);
	g_hRespawnJoin.AddChangeHook(vOtherConVarChanged);
	g_hSpecCmdLimit.AddChangeHook(vOtherConVarChanged);

	for(int i; i < 5; i++)
		g_hSlotFlags[i].AddChangeHook(vSlotConVarChanged);
	g_hGiveWeaponType.AddChangeHook(vSlotConVarChanged);

	g_hBotsSurvivorLimit.AddChangeHook(vSurvivorLimitConVarChanged);

	//AutoExecConfig(true, "bots");

	RegConsoleCmd("sm_spec", cmdJoinSpectator, "加入旁观者");
	RegConsoleCmd("sm_join", cmdJoinSurvivor, "加入生还者");
	RegAdminCmd("sm_afk", cmdGoAFK, ADMFLAG_RCON, "闲置(仅存活的生还者可用)");
	RegConsoleCmd("sm_teams", cmdTeamMenu, "打开团队信息菜单");
	RegAdminCmd("sm_kb", cmdKickAllSurvivorBot, ADMFLAG_RCON, "踢出所有生还者Bot");
	RegAdminCmd("sm_botset", cmdBotSet, ADMFLAG_RCON, "设置开局Bot的数量");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("survivor_rescued", Event_SurvivorRescued);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);

	AddCommandListener(CommandListener_SpecNext, "spec_next");
	
	g_aSteamIDs = new StringMap();
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);
}

public Action cmdJoinSpectator(int client, int args)
{
	if(bIsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if(iGetTeamSpectator() >= g_iSpecCmdLimit)
		return Plugin_Handled;

	if(iGetBotOfIdle(client))
		SDKCall(g_hSDKTakeOverBot, client, true);

	ChangeClientTeam(client, TEAM_SPECTATOR);
	return Plugin_Handled;
}

int iGetTeamSpectator()
{
	int iSpectator;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SPECTATOR && !iGetBotOfIdle(i))
			iSpectator++;
	}
	return iSpectator;
}

public Action cmdJoinSurvivor(int client, int args)
{
	if(bIsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	int iTeam = GetClientTeam(client);
	if(iTeam != TEAM_SURVIVOR)
	{
		vSetGhostStatus(client, 0);

		if(iTeam != TEAM_SPECTATOR)
			ChangeClientTeam(client, TEAM_SPECTATOR);
		else if(iGetBotOfIdle(client))
		{
			SDKCall(g_hSDKTakeOverBot, client, true);
			return Plugin_Handled;
		}
		
		int iBot = GetClientOfUserId(g_iPlayerBot[client]);
		if(iBot == 0 || !bIsValidAliveSurvivorBot(iBot))
			iBot = iGetAnyValidAliveSurvivorBot();

		if(iBot)
		{
			SDKCall(g_hSDKSetHumanSpectator, iBot, client);
			SDKCall(g_hSDKSetObserverTarget, client, iBot);
			SDKCall(g_hSDKTakeOverBot, client, true);
		}
		else
		{
			bool bCanRespawn = g_bRespawnJoin && bIsFirstTime(client);

			ChangeClientTeam(client, TEAM_SURVIVOR);

			if(bCanRespawn && !IsPlayerAlive(client))
			{
				vRoundRespawn(client);
				vSetGodMode(client, 1.0);
				vTeleportToSurvivor(client);
			} 
			else if(g_bRespawnJoin)
				ReplyToCommand(client, "\x01重复加入默认为\x05死亡状态.");
		}
	}
	else if(!IsPlayerAlive(client))
	{
		int iBot = iGetAnyValidAliveSurvivorBot();
		if(iBot)
		{
			ChangeClientTeam(client, TEAM_SPECTATOR);
			SDKCall(g_hSDKSetHumanSpectator, iBot, client);
			SDKCall(g_hSDKSetObserverTarget, client, iBot);
			SDKCall(g_hSDKTakeOverBot, client, true);
		}
		else
			ReplyToCommand(client, "\x01你已经\x04死亡\x01. 没有\x05电脑Bot\x01可以接管.");
	}

	return Plugin_Handled;
}

public Action cmdGoAFK(int client, int args)
{
	if(bIsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
		return Plugin_Handled;

	SDKCall(g_hSDKGoAwayFromKeyboard, client);
	return Plugin_Handled;
}

public Action cmdTeamMenu(int client, int args)
{
	if(bIsRoundStarted() == false)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	vDisplayTeamMenu(client);
	return Plugin_Handled;
}

public Action cmdKickAllSurvivorBot(int client, int args)
{
	if(bIsRoundStarted() == false)
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

public Action cmdBotSet(int client, int args)
{
	if(bIsRoundStarted() == false)
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
			g_hBotsSurvivorLimit.IntValue = iNumber;

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
	if(client == 0 || !g_bSpecNotify[client] || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SPECTATOR || iGetBotOfIdle(client))
		return Plugin_Continue;

	g_bSpecNotify[client] = false;
	PrintHintText(client, "聊天栏输入 !join 加入游戏");
	PrintToChat(client, "\x01聊天栏输入 \x05!join \x01加入游戏");

	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	vGetSlotCvars();
	vGetOtherCvars();
	vGetSurvivorLimitCvars();
}

public void vOtherConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetOtherCvars();
}

void vGetOtherCvars()
{
	g_bAutoJoin = g_hAutoJoin.BoolValue;
	g_bRespawnJoin = g_hRespawnJoin.BoolValue;
	g_iSpecCmdLimit = g_hSpecCmdLimit.IntValue;
}

public void vSlotConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetSlotCvars();
}

void vGetSlotCvars()
{
	int iNullSlot;
	for(int i; i < 5; i++)
	{
		g_iSlotCount[i] = 0;
		if(g_hSlotFlags[i].IntValue > 0)
		{
			if(bGetSlotInfo(i) == false)
				iNullSlot++;
		}	
	}

	g_bGiveWeaponType = iNullSlot != 5 ? g_hGiveWeaponType.BoolValue : false;
}

bool bGetSlotInfo(int iSlot)
{
	for(int i; i < 17; i++)
	{
		if(g_sWeaponName[iSlot][i][0] == '\0')
			break;

		if((1 << i) & g_hSlotFlags[iSlot].IntValue)
			g_iSlotWeapons[iSlot][g_iSlotCount[iSlot]++] = i;
	}
	return g_iSlotCount[iSlot] != 0;
}

public void vSurvivorLimitConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetSurvivorLimitCvars();
}

void vGetSurvivorLimitCvars()
{
	g_hSurvivorLimit.IntValue = g_iBotsSurvivorLimit = g_hBotsSurvivorLimit.IntValue;
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;

	if(bIsRoundStarted() == true)
	{
		delete g_hBotsUpdateTimer;
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
	}
}

public Action Timer_BotsUpdate(Handle timer)
{
	g_hBotsUpdateTimer = null;

	if(bAreAllInGame() == true)
		vSpawnCheck();
	else
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
}

void vSpawnCheck()
{
	if(bIsRoundStarted() == false)
		return;

	int iSurvivor		= iGetTeamPlayers(TEAM_SURVIVOR, true);
	int iHumanSurvivor	= iGetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLimit	= g_iBotsSurvivorLimit;
	int iSurvivorMax	= iHumanSurvivor > iSurvivorLimit ? iHumanSurvivor : iSurvivorLimit;

	if(iSurvivor > iSurvivorMax)
		PrintToConsoleAll("Kicking %d bot(s)", iSurvivor - iSurvivorMax);

	if(iSurvivor < iSurvivorLimit)
		PrintToConsoleAll("Spawning %d bot(s)", iSurvivorLimit - iSurvivor);

	for(; iSurvivorMax < iSurvivor; iSurvivorMax++)
		vKickUnusedSurvivorBot();
	
	for(; iSurvivor < iSurvivorLimit; iSurvivor++)
		vSpawnFakeSurvivorClient();
}

void vKickUnusedSurvivorBot()
{
	int iBot = iGetAnyValidSurvivorBot(); //优先踢出没有对应真实玩家且后生成的Bot
	if(iBot)
	{
		vRemovePlayerWeapons(iBot);
		KickClient(iBot, "Kicking Useless Client.");
	}
}

void vSpawnFakeSurvivorClient()
{
	int iBot = CreateFakeClient("SurvivorBot");
	if(iBot == 0)
		return;

	ChangeClientTeam(iBot, TEAM_SURVIVOR);

	if(DispatchKeyValue(iBot, "classname", "SurvivorBot") == true)
	{
		if(DispatchSpawn(iBot) == true)
		{
			if(!IsPlayerAlive(iBot))
				vRoundRespawn(iBot);

			vSetGodMode(iBot, 1.0);
			vTeleportToSurvivor(iBot);
		}
	}

	KickClient(iBot, "Kicking Fake Client.");
}

public void OnMapEnd()
{
	vResetPlugin();
}

void vResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;

	g_aSteamIDs.Clear();

	delete g_hBotsUpdateTimer;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(strcmp(name, "round_end") == 0)
		vResetPlugin();

	for(int i = 1; i <= MaxClients; i++)
		vTakeOver(i);
}

bool bIsRoundStarted()
{
	return g_iRoundStart && g_iPlayerSpawn;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_iPlayerSpawn = 1;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(GetClientTeam(client) == TEAM_SURVIVOR)
	{
		delete g_hBotsUpdateTimer;
		g_hBotsUpdateTimer = CreateTimer(2.0, Timer_BotsUpdate);
		
		if(!IsFakeClient(client) && bIsFirstTime(client))
			vRecordSteamID(client);

		vSetGhostStatus(client, 0);
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	vTakeOver(GetClientOfUserId(event.GetInt("userid")));
}

void vTakeOver(int bot)
{
	int iIdlePlayer;
	if(bot && IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == TEAM_SURVIVOR && (iIdlePlayer = iHasIdlePlayer(bot)))
	{
		SDKCall(g_hSDKSetHumanSpectator, bot, iIdlePlayer);
		SDKCall(g_hSDKSetObserverTarget, iIdlePlayer, bot);
		SDKCall(g_hSDKTakeOverBot, iIdlePlayer, true);
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;
		
	int team = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");

	if(team == 2)
		vSetGhostStatus(client, 0);

	if(team == TEAM_SPECTATOR)
		g_bSpecNotify[client] = true;
	else if(oldteam == TEAM_SPECTATOR)
		g_bSpecNotify[client] = false;
		
	if(g_bAutoJoin && oldteam == 0 && team == 1)
		CreateTimer(0.1, Timer_AutoJoinSurvivorTeam, GetClientUserId(client));
}

public Action Timer_AutoJoinSurvivorTeam(Handle timer, any client)
{
	if(!g_bAutoJoin || bIsRoundStarted() == false || (client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) > TEAM_SPECTATOR || IsPlayerAlive(client) || iGetBotOfIdle(client)) 
		return;
	
	cmdJoinSurvivor(client, 0);
}

public void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || !bCanIdle(client))
		return;

	cmdGoAFK(client, 0); //被从小黑屋救出来后闲置,避免有些玩家挂机
}

bool bCanIdle(int client)
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
	int player_userid = event.GetInt("player");
	int player = GetClientOfUserId(player_userid);
	if(player == 0 || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int bot_userid = event.GetInt("bot");
	int bot = GetClientOfUserId(bot_userid);

	g_iBotPlayer[bot] = player_userid;
	g_iPlayerBot[player] = bot_userid;

	if(g_sPlayerModel[player][0] == '\0')
		return;

	SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
	SetEntityModel(bot, g_sPlayerModel[player]);
	for(int i; i < 8; i++)
	{
		if(strcmp(g_sPlayerModel[player], g_sSurvivorModels[i]) == 0)
			SetClientName(bot, g_sSurvivorNames[i]);
	}
}

public void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if(player == 0 || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));

	char sModel[128];
	GetClientModel(bot, sModel, sizeof(sModel));
	SetEntityModel(player, sModel);
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));
}

public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		vTakeOver(i);

	int entity = FindEntityByClassname(MaxClients + 1, "info_survivor_position");
	if(entity != INVALID_ENT_REFERENCE)
	{
		float vOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
		
		int iSurvivor;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
			{
				if(++iSurvivor < 4)
					continue;

				entity = CreateEntityByName("info_survivor_position");
				DispatchSpawn(entity);
				TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

bool bAreAllInGame()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i)) //加载中
			return false;
	}
	return true;
}

bool bIsFirstTime(int client)
{
	if(!IsClientInGame(client) || IsFakeClient(client)) 
		return false;
	
	static char sSteamID[32];

	sSteamID[0] = '\0';
	if(!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
		return false;

	static bool bAllowed;

	bAllowed = false;
	if(!g_aSteamIDs.GetValue(sSteamID, bAllowed))
	{
		g_aSteamIDs.SetValue(sSteamID, true, true);
		bAllowed = true;
	}
	return bAllowed;
}

void vRecordSteamID(int client)
{
	char sSteamID[32];
	if(GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)))
		g_aSteamIDs.SetValue(sSteamID, false, true);
}

int iGetBotOfIdle(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && (iHasIdlePlayer(i) == client))
			return i;
	}
	return 0;
}

static int iHasIdlePlayer(int client)
{
	char sNetClass[64];
	if(!GetEntityNetClass(client, sNetClass, sizeof(sNetClass)))
		return 0;

	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPECTATOR)
		return client;

	return 0;
}

static int iGetTeamPlayers(int team, bool bIncludeBots)
{
	static int i;
	static int iPlayers;

	iPlayers = 0;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == team)
		{
			if(!bIncludeBots && IsFakeClient(i) && !iHasIdlePlayer(i))
				continue;

			iPlayers++;
		}
	}
	return iPlayers;
}

bool bIsValidSurvivorBot(int client)
{
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && !iHasIdlePlayer(client);
}

bool bIsValidAliveSurvivorBot(int client)
{
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !iHasIdlePlayer(client);
}

int iGetAnyValidSurvivorBot()
{
	int iSurvivor, iHasPlayer, iNotPlayer;
	int[] iHasPlayerBots = new int[MaxClients];
	int[] iNotPlayerBots = new int[MaxClients];
	for(int i = MaxClients; i >= 1; i--)
	{
		if(bIsValidSurvivorBot(i))
		{
			if((iSurvivor = GetClientOfUserId(g_iBotPlayer[i])) && IsClientInGame(iSurvivor) && !IsFakeClient(iSurvivor) && GetClientTeam(iSurvivor) != 2)
				iHasPlayerBots[iHasPlayer++] = i;
			else
				iNotPlayerBots[iNotPlayer++] = i;
		}
	}
	return (iNotPlayer == 0) ? (iHasPlayer == 0 ? 0 : iHasPlayerBots[0]) : iNotPlayerBots[0];
}

int iGetAnyValidAliveSurvivorBot()
{
	int iSurvivor, iHasPlayer, iNotPlayer;
	int[] iHasPlayerBots = new int[MaxClients];
	int[] iNotPlayerBots = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(bIsValidAliveSurvivorBot(i))
		{
			if((iSurvivor = GetClientOfUserId(g_iBotPlayer[i])) && IsClientInGame(iSurvivor) && !IsFakeClient(iSurvivor) && GetClientTeam(iSurvivor) != 2)
				iHasPlayerBots[iHasPlayer++] = i;
			else
				iNotPlayerBots[iNotPlayer++] = i;
		}
	}
	return (iNotPlayer == 0) ? (iHasPlayer == 0 ? 0 : iHasPlayerBots[GetRandomInt(0, iHasPlayer - 1)]) : iNotPlayerBots[GetRandomInt(0, iNotPlayer - 1)];
}

void vSetGodMode(int client, float fDuration)
{
	if(!IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 0);

	if(fDuration > 0.0)
		CreateTimer(fDuration, Timer_Mortal, GetClientUserId(client));
}

public Action Timer_Mortal(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 2);
}

void vGiveDefaultItems(int client)
{
	vRemovePlayerWeapons(client);

	for(int i = 4; i >= 2; i--)
	{
		if(g_iSlotCount[i] == 0)
			continue;

		vCheatCommand(client, "give", g_sWeaponName[i][g_iSlotWeapons[i][GetRandomInt(0, g_iSlotCount[i] - 1)]]);
	}

	vGiveSecondary(client);

	switch(g_hGiveWeaponType.IntValue)
	{
		case 1:
			vGivePresetPrimary(client);
		
		case 2:
			vGiveAveragePrimary(client);
	}
}

void vGiveSecondary(int client)
{
	if(g_iSlotCount[1] != 0)
	{
		int iRandom = g_iSlotWeapons[1][GetRandomInt(0, g_iSlotCount[1] - 1)];
		if(iRandom > 2)
			vGiveMelee(client, g_sWeaponName[1][iRandom]);
		else
			vCheatCommand(client, "give", g_sWeaponName[1][iRandom]);
	}
}

void vGivePresetPrimary(int client)
{
	if(g_iSlotCount[0] != 0)
		vCheatCommand(client, "give", g_sWeaponName[0][g_iSlotWeapons[0][GetRandomInt(0, g_iSlotCount[0] - 1)]]);
}

bool bIsWeaponTier1(int iWeapon)
{
	char sWeapon[32];
	GetEntityClassname(iWeapon, sWeapon, sizeof(sWeapon));
	for(int i; i < 5; i++)
	{
		if(strcmp(sWeapon[7], g_sWeaponName[0][i]) == 0)
			return true;
	}
	return false;
}

void vGiveAveragePrimary(int client)
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

			if(bIsWeaponTier1(iWeapon))
				iTier += 1;
			else 
				iTier += 2;
		}
	}

	switch(iTotal > 0 ? RoundToNearest(1.0 * iTier / iTotal) : 0)
	{
		case 1:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(0, 4)]); //随机给一把tier1武器

		case 2:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(5, 14)]); //随机给一把tier2武器	
	}
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

void vCheatCommand(int client, const char[] sCommand, const char[] sArguments = "")
{
	static int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags);
}

void vTeleportToSurvivor(int client)
{
	int iTarget = iGetTeleportTarget(client);
	if(iTarget != -1)
	{
		vForceCrouch(client);

		float vPos[3];
		GetClientAbsOrigin(iTarget, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

int iGetTeleportTarget(int client)
{
	int iNormal, iIncap, iHanging;
	int[] iNormalSurvivors = new int[MaxClients];
	int[] iIncapSurvivors = new int[MaxClients];
	int[] iHangingSurvivors = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			if(GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			{
				if(GetEntProp(i, Prop_Send, "m_isHangingFromLedge"))
					iHangingSurvivors[iHanging++] = i;
				else
					iIncapSurvivors[iIncap++] = i;
			}
			else
				iNormalSurvivors[iNormal++] = i;
		}
	}
	return (iNormal == 0) ? (iIncap == 0 ? (iHanging == 0 ? -1 : iHangingSurvivors[GetRandomInt(0, iHanging - 1)]) : iIncapSurvivors[GetRandomInt(0, iIncap - 1)]) : iNormalSurvivors[GetRandomInt(0, iNormal - 1)];
}

void vForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

void vSetGhostStatus(int client, int iGhost)
{
	if(GetEntProp(client, Prop_Send, "m_isGhost") != iGhost)
		SetEntProp(client, Prop_Send, "m_isGhost", iGhost);
}

//给玩家近战
//https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484
public void OnMapStart()
{
	int i;
	int iLen;

	iLen = sizeof(g_sWeaponModels);
	for(i = 0; i < iLen; i++)
	{
		if(!IsModelPrecached(g_sWeaponModels[i]))
			PrecacheModel(g_sWeaponModels[i], true);
	}

	char sBuffer[64];
	for(i = 3; i < 17; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}

	vGetMeleeClasses();
}

void vGetMeleeClasses()
{
	int iMeleeStringTable = FindStringTable("MeleeWeapons");
	g_iMeleeClassCount = GetStringTableNumStrings(iMeleeStringTable);

	for(int i; i < g_iMeleeClassCount; i++)
		ReadStringTable(iMeleeStringTable, i, g_sMeleeClass[i], sizeof(g_sMeleeClass[]));
}

void vGetScriptName(const char[] sMeleeClass, char[] sScriptName, int maxlength)
{
	for(int i; i < g_iMeleeClassCount; i++)
	{
		if(StrContains(g_sMeleeClass[i], sMeleeClass, false) == 0)
		{
			strcopy(sScriptName, maxlength, g_sMeleeClass[i]);
			return;
		}
	}
	strcopy(sScriptName, maxlength, g_sMeleeClass[GetRandomInt(0, g_iMeleeClassCount - 1)]);
}

void vGiveMelee(int client, const char[] sMeleeClass)
{
	char sScriptName[32];
	vGetScriptName(sMeleeClass, sScriptName, sizeof(sScriptName));
	vCheatCommand(client, "give", sScriptName);
}

void vDisplayTeamMenu(int client)
{
	static const char sZombieClass[][] =
	{
		"None",
		"Smoker",
		"Boomer",
		"Hunter",
		"Spitter",
		"Jockey",
		"Charger",
		"Witch",
		"Tank",
		"Survivor"
	};

	Panel TeamPanel = new Panel();
	TeamPanel.SetTitle("---------★团队信息★---------");

	char sInfo[128];
	FormatEx(sInfo, sizeof(sInfo), "旁观者 (%d)", iGetTeamPlayers(TEAM_SPECTATOR, false));
	TeamPanel.DrawItem(sInfo);

	int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SPECTATOR)
		{
			FormatEx(sInfo, sizeof(sInfo), "%N", i);
			ReplaceString(sInfo, sizeof(sInfo), "[", "");
			
			if(iGetBotOfIdle(i))
				Format(sInfo, sizeof(sInfo), "闲置 - %s", sInfo);
			else
				Format(sInfo, sizeof(sInfo), "观众 - %s", sInfo);

			TeamPanel.DrawText(sInfo);
		}
	}

	FormatEx(sInfo, sizeof(sInfo), "生还者 (%d/%d) - %d Bot(s)", iGetTeamPlayers(TEAM_SURVIVOR, false), g_iBotsSurvivorLimit, iCountAvailableSurvivorBots());
	TeamPanel.DrawItem(sInfo);

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			FormatEx(sInfo, sizeof(sInfo), "%N", i);
			ReplaceString(sInfo, sizeof(sInfo), "[", "");
	
			if(IsPlayerAlive(i))
			{
				if(GetEntProp(i, Prop_Send, "m_isIncapacitated"))
					Format(sInfo, sizeof(sInfo), "倒地 - %d HP - %s", iGetClientRealHealth(i), sInfo);
				else if(GetEntProp(i, Prop_Send, "m_currentReviveCount") >= FindConVar("survivor_max_incapacitated_count").IntValue)
					Format(sInfo, sizeof(sInfo), "黑白 - %d HP - %s", iGetClientRealHealth(i), sInfo);
				else
					Format(sInfo, sizeof(sInfo), "%dHP - %s", iGetClientRealHealth(i), sInfo);
	
			}
			else
				Format(sInfo, sizeof(sInfo), "死亡 - %s", sInfo);

			TeamPanel.DrawText(sInfo);
		}
	}

	FormatEx(sInfo, sizeof(sInfo), "感染者 (%d)", iGetTeamPlayers(TEAM_INFECTED, false));
	TeamPanel.DrawItem(sInfo);

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			int iZombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
			if(IsFakeClient(i) && iZombieClass != 8)
				continue;

			FormatEx(sInfo, sizeof(sInfo), "%N", i);
			ReplaceString(sInfo, sizeof(sInfo), "[", "");

			if(IsPlayerAlive(i))
			{
				if(GetEntProp(i, Prop_Send, "m_isGhost"))
					Format(sInfo, sizeof(sInfo), "(%s)鬼魂 - %s", sZombieClass[iZombieClass], sInfo);
				else
					Format(sInfo, sizeof(sInfo), "(%s)%d HP - %s", sZombieClass[iZombieClass], GetEntProp(i, Prop_Data, "m_iHealth"), sInfo);
			}
			else
				Format(sInfo, sizeof(sInfo), "(%s)死亡 - %s", sZombieClass[iZombieClass], sInfo);

			TeamPanel.DrawText(sInfo);
		}
	}

	TeamPanel.DrawItem("刷新");

	TeamPanel.Send(client, iTeamMenuHandler, 30);
	delete TeamPanel;
}

public int iTeamMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
			if(param2 == 4)
				vDisplayTeamMenu(client);

		case MenuAction_End:
			delete menu;
	}
}

int iCountAvailableSurvivorBots()
{
	int iNum;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(bIsValidSurvivorBot(i))
			iNum++;
	}
	return iNum;
}

int iGetClientRealHealth(int client)
{
	return GetClientHealth(client) + RoundToFloor(fGetTempHealth(client));
}

float fGetTempHealth(int client)
{
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * FindConVar("pain_pills_decay_rate").FloatValue;
	return fHealth < 0.0 ? 0.0 : fHealth;
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

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::RoundRespawn");
	g_hSDKRoundRespawn = EndPrepSDKCall();
	if(g_hSDKRoundRespawn == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::RoundRespawn");

	vRegisterStatsConditionPatch(hGameData);

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator") == false)
		SetFailState("Failed to find signature: SurvivorBot::SetHumanSpectator");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDKSetHumanSpectator = EndPrepSDKCall();
	if(g_hSDKSetHumanSpectator == null)
		SetFailState("Failed to create SDKCall: SurvivorBot::SetHumanSpectator");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKTakeOverBot = EndPrepSDKCall();
	if(g_hSDKTakeOverBot == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::TakeOverBot");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorPlayer::SetObserverTarget") == false)
		SetFailState("Failed to find offset: CTerrorPlayer::SetObserverTarget");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKSetObserverTarget = EndPrepSDKCall();
	if(g_hSDKSetObserverTarget == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::SetObserverTarget");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKGoAwayFromKeyboard = EndPrepSDKCall();
	if(g_hSDKGoAwayFromKeyboard == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GoAwayFromKeyboard");

	vSetupDetours(hGameData);

	delete hGameData;
}

void vRegisterStatsConditionPatch(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if(iOffset == -1)
		SetFailState("Failed to find offset: RoundRespawn_Offset");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to find byte: RoundRespawn_Byte");

	g_pStatsCondition = hGameData.GetAddress("CTerrorPlayer::RoundRespawn");
	if(!g_pStatsCondition)
		SetFailState("Failed to find address: CTerrorPlayer::RoundRespawn");
	
	g_pStatsCondition += view_as<Address>(iOffset);
	
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if(iByteOrigin != iByteMatch)
		SetFailState("Failed to load 'CTerrorPlayer::RoundRespawn', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void vRoundRespawn(int client)
{
	vStatsConditionPatch(true);
	SDKCall(g_hSDKRoundRespawn, client);
	vStatsConditionPatch(false);
}

//https://forums.alliedmods.net/showthread.php?t=323220
void vStatsConditionPatch(bool bPatch)
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		StoreToAddress(g_pStatsCondition, 0x79, NumberType_Int8);
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "SurvivorBot::SetHumanSpectator");
	if(dDetour == null)
		SetFailState("Failed to find signature: SurvivorBot::SetHumanSpectator");
		
	if(!dDetour.Enable(Hook_Pre, mreSetHumanSpectatorPre))
		SetFailState("Failed to detour pre: SurvivorBot::SetHumanSpectator");

	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GoAwayFromKeyboard");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");

	if(!dDetour.Enable(Hook_Pre, mreGoAwayFromKeyboardPre))
		SetFailState("Failed to detour pre: CTerrorPlayer::GoAwayFromKeyboard");

	if(!dDetour.Enable(Hook_Post, mreGoAwayFromKeyboardPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GoAwayFromKeyboard");

	dDetour = DynamicDetour.FromConf(hGameData, "CBasePlayer::SetModel");
	if(dDetour == null)
		SetFailState("Failed to find signature: CBasePlayer::SetModel");
		
	if(!dDetour.Enable(Hook_Post, mrePlayerSetModelPost))
		SetFailState("Failed to detour pre: CBasePlayer::SetModel");

	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::TakeOverBot");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::TakeOverBot");
		
	if(!dDetour.Enable(Hook_Pre, mreTakeOverBotPre))
		SetFailState("Failed to detour pre: CTerrorPlayer::TakeOverBot");

	if(!dDetour.Enable(Hook_Post, mreTakeOverBotPost))
		SetFailState("Failed to detour post: CTerrorPlayer::TakeOverBot");

	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GiveDefaultItems");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::GiveDefaultItems");
		
	if(!dDetour.Enable(Hook_Post, mreGiveDefaultItemsPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GiveDefaultItems");
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

public MRESReturn mreSetHumanSpectatorPre(int pThis, DHookParam hParams)
{
	if(g_bShouldIgnore)
		return MRES_Ignored;
	
	if(!g_bShouldFixAFK)
		return MRES_Ignored;
	
	if(g_iSurvivorBot < 1)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

public MRESReturn mreGoAwayFromKeyboardPre(int pThis, DHookReturn hReturn)
{
	g_bShouldFixAFK = true;
	return MRES_Ignored;
}

public MRESReturn mreGoAwayFromKeyboardPost(int pThis, DHookReturn hReturn)
{
	if(g_bShouldFixAFK && g_iSurvivorBot > 0 && IsFakeClient(g_iSurvivorBot))
	{
		g_bShouldIgnore = true;

		SDKCall(g_hSDKSetHumanSpectator, g_iSurvivorBot, pThis);
		SDKCall(g_hSDKSetObserverTarget, pThis, g_iSurvivorBot);
		SetEntProp(pThis, Prop_Send, "m_iObserverMode", 5);

		vWriteTakeoverPanel(pThis, g_iSurvivorBot);
		
		g_bShouldIgnore = false;
	}
	
	g_iSurvivorBot = 0;
	g_bShouldFixAFK = false;
	return MRES_Ignored;
}

//Identity Fix https://forums.alliedmods.net/showpost.php?p=2718792&postcount=36
public MRESReturn mrePlayerSetModelPost(int pThis, DHookParam hParams)
{
	if(pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis))
		return MRES_Ignored;

	if(GetClientTeam(pThis) != TEAM_SURVIVOR)
	{
		g_sPlayerModel[pThis][0] = '\0';
		return MRES_Ignored;
	}
	
	char sModel[128];
	hParams.GetString(1, sModel, sizeof(sModel));
	if(StrContains(sModel, "survivors", false) >= 0)
		strcopy(g_sPlayerModel[pThis], sizeof(g_sPlayerModel), sModel);

	return MRES_Ignored;
}

void vWriteTakeoverPanel(int client, int bot)
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

bool g_bTakingOverBot[MAXPLAYERS + 1];
public MRESReturn mreTakeOverBotPre(int pThis, DHookParam hParams)
{
	g_bTakingOverBot[pThis] = true;
}

public MRESReturn mreTakeOverBotPost(int pThis, DHookParam hParams)
{
	g_bTakingOverBot[pThis] = false;
}

public MRESReturn mreGiveDefaultItemsPost(int pThis)
{
	if(!g_bGiveWeaponType || g_bShouldFixAFK || g_bTakingOverBot[pThis])
		return MRES_Ignored;

	if(!IsClientInGame(pThis) || GetClientTeam(pThis) != TEAM_SURVIVOR || !IsPlayerAlive(pThis))
		return MRES_Ignored;

	vGiveDefaultItems(pThis);
	return MRES_Ignored;
}
