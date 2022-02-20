#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "1.10.0"
#define GAMEDATA 		"bots"
#define CVAR_FLAGS 		FCVAR_NOTIFY
#define MAX_SLOTS		5
#define TEAM_NOTEAM		0
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED   3
#define SOUND_SPECMENU	"ui/helpful_event_1.wav"

Handle
	g_hBotsUpdateTimer,
	g_hSDKNextBotCreateSurvivorBot,
	g_hSDKRoundRespawn,
	g_hSDKSetHumanSpectator,
	g_hSDKTakeOverBot,
	g_hSDKGoAwayFromKeyboard,
	g_hSDKIsInTransition;

StringMap
	g_aSteamIDs;

ArrayList
	g_aMeleeScripts;

Address
	g_pDirector,
	g_pStatsCondition;

ConVar
	g_hSurvivorLimit,
	g_hSurvivorLimitSet,
	g_hAutoJoin,
	g_hRespawnJoin,
	g_hSpecCmdLimit,
	g_hSpecNextNotify,
	g_hGiveWeaponType,
	g_hGiveWeaponTime;

int
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iSurvivorBot,
	g_iSurvivorLimitSet,
	g_iSpecCmdLimit,
	g_iSpecNextNotify,
	g_iOffHiddenWeapon;

bool
	g_bShouldFixAFK,
	g_bAutoJoin,
	g_bRespawnJoin,
	g_bGiveWeaponType,
	g_bGiveWeaponTime,
	g_bInSpawnTime,
	g_bHideNameChange;

enum struct esWeapon
{
	ConVar cFlags;

	int iCount;
	int iAllowed[20];
}

esWeapon
	g_esWeapon[MAX_SLOTS];

enum struct esPlayer
{
	int iPlayerBot;
	int iBotPlayer;

	bool bSpecNotify;

	char sModel[128];
	char sSteamID[32];
}

esPlayer
	g_esPlayer[MAXPLAYERS + 1];

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
	g_sWeaponName[MAX_SLOTS][17][] =
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
			"electric_guitar",			//2048 电吉他
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

// 如果签名失效，请到此处更新 (https://github.com/Psykotikism/L4D1-2_Signatures)
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
	vInitGameData();

	g_aSteamIDs = new StringMap();
	g_aMeleeScripts = new ArrayList(64);

	g_hSurvivorLimit = 		FindConVar("survivor_limit");
	g_hSurvivorLimitSet = 	CreateConVar("bots_survivor_limit", 	"4", 		"开局Bot的数量", CVAR_FLAGS, true, 1.0, true, 31.0);
	g_hAutoJoin = 			CreateConVar("bots_auto_join_survivor", "1", 		"玩家连接后, 是否自动加入生还者. \n0=否, 1=是.", CVAR_FLAGS);
	g_hRespawnJoin = 		CreateConVar("bots_respawn_on_join", 	"1", 		"玩家第一次进服时如果没有存活的Bot可以接管是否复活. \n0=否, 1=是.", CVAR_FLAGS);
	g_hSpecCmdLimit = 		CreateConVar("bots_spec_cmd_limit", 	"1", 		"当完全旁观玩家达到多少个时禁止使用sm_spec命令.", CVAR_FLAGS);
	g_hSpecNextNotify = 	CreateConVar("bots_spec_next_notify", 	"3", 		"完全旁观玩家点击鼠标左键时, 提示加入生还者的方式 \n0=不提示, 1=聊天栏, 2=屏幕中央, 3=弹出菜单.", CVAR_FLAGS);
	g_esWeapon[0].cFlags = 	CreateConVar("bots_give_slot0", 		"131071", 	"主武器给什么. \n0=不给, 131071=所有, 7=微冲, 1560=霰弹, 30720=狙击, 31=Tier1, 32736=Tier2, 98304=Tier0.", CVAR_FLAGS);
	g_esWeapon[1].cFlags = 	CreateConVar("bots_give_slot1", 		"1066", 	"副武器给什么. \n0=不给, 131071=所有.(如果选中了近战且该近战在当前地图上未解锁,则会随机给一把).", CVAR_FLAGS);
	g_esWeapon[2].cFlags = 	CreateConVar("bots_give_slot2", 		"0", 		"投掷物给什么. \n0=不给, 7=所有.", CVAR_FLAGS);
	g_esWeapon[3].cFlags =	CreateConVar("bots_give_slot3", 		"1", 		"医疗品给什么. \n0=不给, 15=所有.", CVAR_FLAGS);
	g_esWeapon[4].cFlags =	CreateConVar("bots_give_slot4", 		"3", 		"药品给什么. \n0=不给, 3=所有.", CVAR_FLAGS);
	g_hGiveWeaponType = 	CreateConVar("bots_give_type", 			"2", 		"根据什么来给玩家装备. \n0=不给, 1=每个槽位的设置, 2=当前存活生还者的平均装备质量(仅主副武器).", CVAR_FLAGS);
	g_hGiveWeaponTime = 	CreateConVar("bots_give_time", 			"0", 		"什么时候给玩家装备. \n0=每次出生时, 1=只在本插件创建Bot和复活玩家时.", CVAR_FLAGS);
	CreateConVar("bots_version", PLUGIN_VERSION, "bots(coop)(给物品flags参考源码g_sWeaponName中的武器名处的数字, 多个武器里面随机则取数字和)", CVAR_FLAGS|FCVAR_DONTRECORD);

	g_hSurvivorLimit.Flags &= ~FCVAR_NOTIFY; // 移除ConVar变动提示
	g_hSurvivorLimit.SetBounds(ConVarBound_Upper, true, 31.0);

	g_hSurvivorLimitSet.AddChangeHook(vLimitConVarChanged);

	g_hAutoJoin.AddChangeHook(vGeneralConVarChanged);
	g_hRespawnJoin.AddChangeHook(vGeneralConVarChanged);
	g_hSpecCmdLimit.AddChangeHook(vGeneralConVarChanged);
	g_hSpecNextNotify.AddChangeHook(vGeneralConVarChanged);

	for(int i; i < MAX_SLOTS; i++)
		g_esWeapon[i].cFlags.AddChangeHook(vWeaponConVarChanged);
	g_hGiveWeaponType.AddChangeHook(vWeaponConVarChanged);
	g_hGiveWeaponTime.AddChangeHook(vWeaponConVarChanged);
	
	AutoExecConfig(true, "bots");

	RegConsoleCmd("sm_spec", cmdJoinSpectator, "加入旁观者");
	RegConsoleCmd("sm_join", cmdJoinSurvivor, "加入生还者");
	RegConsoleCmd("sm_tkbot", cmdTakeOverBot, "接管指定BOT");
	RegConsoleCmd("sm_teams", cmdTeamPanel, "团队菜单");

	RegAdminCmd("sm_afk", cmdGoAFK, ADMFLAG_RCON, "闲置");
	RegAdminCmd("sm_kb", cmdKickBot, ADMFLAG_RCON, "踢出所有生还者Bot");
	RegAdminCmd("sm_botset", cmdBotSet, ADMFLAG_RCON, "设置开局Bot的数量");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_bot_replace", Event_PlayerBotReplace);
	HookEvent("bot_player_replace", Event_BotPlayerReplace);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);

	AddCommandListener(CommandListener_SpecNext, "spec_next");
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);
}

Action cmdJoinSpectator(int client, int args)
{
	if(!g_iRoundStart || !g_iPlayerSpawn)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	bool bIdle = !!iGetBotOfIdlePlayer(client);
	if(GetClientTeam(client) == TEAM_SPECTATOR && !bIdle)
	{
		ReplyToCommand(client, "你当前已在旁观者队伍.");
		return Plugin_Handled;
	}
	
	if(iGetTeamSpectator() >= g_iSpecCmdLimit)
	{
		ReplyToCommand(client, "\x05当前旁观者数量已达到限制\x01-> \x04%d\x01.", g_iSpecCmdLimit);
		return Plugin_Handled;
	}

	if(bIdle)
		SDKCall(g_hSDKTakeOverBot, client, true);

	ChangeClientTeam(client, TEAM_SPECTATOR);
	return Plugin_Handled;
}

int iGetTeamSpectator()
{
	int iSpectator;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SPECTATOR && !iGetBotOfIdlePlayer(i))
			iSpectator++;
	}
	return iSpectator;
}

Action cmdJoinSurvivor(int client, int args)
{
	if(!g_iRoundStart || !g_iPlayerSpawn)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	int iTeam = GetClientTeam(client);
	if(iTeam != TEAM_SURVIVOR)
	{
		if(iTeam != TEAM_SPECTATOR)
			ChangeClientTeam(client, TEAM_SPECTATOR);
		else if(iGetBotOfIdlePlayer(client))
		{
			SDKCall(g_hSDKTakeOverBot, client, true);
			return Plugin_Handled;
		}
		
		bool bCanRespawn = g_bRespawnJoin && bIsFirstTime(client);
		int iBot = GetClientOfUserId(g_esPlayer[client].iPlayerBot);
		if(!iBot || !bIsValidSurvivorBot(iBot, -1))
			iBot = iFindUselessSurvivorBot(true);

		if(!iBot)
		{
			iBot = iCreateSurvivorBot();
			if(!iBot)
			{
				ChangeClientTeam(client, TEAM_SURVIVOR);
				if(bCanRespawn)
				{
					if(!IsPlayerAlive(client))
					{
						vRoundRespawn(client);
						vSetGodMode(client, 3.0);
						vTeleportToSurvivor(client);
					}
				}
				else if(!IsPlayerAlive(client))
					ReplyToCommand(client, "\x05重复加入默认为\x01-> \x04死亡状态\x01.");

				return Plugin_Handled;
			}
			else if(IsPlayerAlive(iBot))
			{
				if(bCanRespawn)
				{
					vSetGodMode(iBot, 3.0);
					vTeleportToSurvivor(iBot);
				}
				else
				{
					vRemovePlayerWeapons(iBot);
					ForcePlayerSuicide(iBot);
				}
			}
		}

		if(bCanRespawn)
		{
			if(!IsPlayerAlive(iBot))
			{
				vRoundRespawn(iBot);
				vSetGodMode(iBot, 3.0);
				vTeleportToSurvivor(iBot);
			}

			vSetHumanSpectator(iBot, client);
		}
		else
		{
			if(IsPlayerAlive(iBot))
				vSetHumanSpectator(iBot, client);
			else
			{
				SDKCall(g_hSDKSetHumanSpectator, iBot, client);
				SDKCall(g_hSDKTakeOverBot, client, true);
				ReplyToCommand(client, "\x05重复加入默认为\x01-> \x04死亡状态\x01.");
			}		
		}
	}
	/*else if(!IsPlayerAlive(client))
	{
		int iBot = iFindUselessSurvivorBot(true);
		if(iBot && IsPlayerAlive(iBot))
		{
			ChangeClientTeam(client, TEAM_SPECTATOR);
			vTakeOverBot(client, iBot);
		}
		else
			ReplyToCommand(client, "\x01你已经 \x04死亡\x01. 没有 \x05空闲的电脑BOT \x01可以接管\x01.");
	}*/

	return Plugin_Handled;
}

Action cmdTakeOverBot(int client, int args)
{
	if(!g_iRoundStart || !g_iPlayerSpawn)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(!iClientTeamTakeOver(client))
	{
		ReplyToCommand(client, "不符合接管条件.");
		return Plugin_Handled;
	}

	if(!iFindUselessSurvivorBot(true))
	{
		ReplyToCommand(client, "\x01没有 \x05空闲的电脑BOT \x01可以接管\x01.");
		return Plugin_Handled;
	}

	vDisplayBotList(client);
	return Plugin_Handled;
}

int iClientTeamTakeOver(int client)
{
	int iTeam = GetClientTeam(client);
	switch(iTeam)
	{
		case TEAM_SPECTATOR:
			if(iGetBotOfIdlePlayer(client))
				iTeam = 0;

		case TEAM_SURVIVOR:
			if(IsPlayerAlive(client))
				iTeam = 0;
	}
	return iTeam;
}

void vDisplayBotList(int client)
{
	char sID[16];
	char sName[MAX_NAME_LENGTH];
	Menu menu = new Menu(iDisplayBotListMenuHandler);
	menu.SetTitle("- 请选择接管目标 - [!tkbot]");

	menu.AddItem("o", "当前旁观目标");

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!bIsValidSurvivorBot(i, -1))
			continue;

		FormatEx(sID, sizeof sID, "%d", GetClientUserId(i));
		FormatEx(sName, sizeof sName, "%s - %s", IsPlayerAlive(i) ? "存活" : "死亡",sGetModelName(i));
		menu.AddItem(sID, sName);
	}
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

// L4D2_Adrenaline_Recovery (https://github.com/LuxLuma/L4D2_Adrenaline_Recovery)
char[] sGetModelName(int client)
{
	int iIndex;
	char sModel[31];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof sModel);
	switch(sModel[29])
	{
		case 'b'://nick
			iIndex = 0;
		case 'd'://rochelle
			iIndex = 1;
		case 'c'://coach
			iIndex = 2;
		case 'h'://ellis
			iIndex = 3;
		case 'v'://bill
			iIndex = 4;
		case 'n'://zoey
			iIndex = 5;
		case 'e'://francis
			iIndex = 6;
		case 'a'://louis
			iIndex = 7;
		default:
			iIndex = 8;
	}

	strcopy(sModel, sizeof sModel, iIndex == 8 ? "未知" : g_sSurvivorNames[iIndex]);
	return sModel;
}

int iDisplayBotListMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			menu.GetItem(param2, sItem, sizeof sItem);

			int iBot;
			if(sItem[0] == 'o')
			{
				iBot = GetEntPropEnt(param1, Prop_Send, "m_hObserverTarget");
				if(iBot > 0 && bIsValidSurvivorBot(iBot, -1))
					vTakeOverBot(param1, iBot);
				else
					PrintToChat(param1, "当前旁观目标非可接管BOT.");
			}
			else
			{
				iBot = GetClientOfUserId(StringToInt(sItem));
				if(!iBot || !bIsValidSurvivorBot(iBot, -1))
					PrintToChat(param1, "选定的目标BOT已失效.");
				else
				{
					int iTeam = iClientTeamTakeOver(param1);
					if(!iTeam)
						PrintToChat(param1, "不符合接管条件.");
					else
					{
						if(iTeam != 1)
							ChangeClientTeam(param1, TEAM_SPECTATOR);

						vTakeOverBot(param1, iBot);
					}
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action cmdGoAFK(int client, int args)
{
	if(!g_iRoundStart || !g_iPlayerSpawn)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
		return Plugin_Handled;

	SDKCall(g_hSDKGoAwayFromKeyboard, client);
	return Plugin_Handled;
}

Action cmdTeamPanel(int client, int args)
{
	if(!g_iRoundStart || !g_iPlayerSpawn)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	vDisplayTeamPanel(client);
	return Plugin_Handled;
}

Action cmdKickBot(int client, int args)
{
	if(!g_iRoundStart || !g_iPlayerSpawn)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && !iGetIdlePlayerOfBot(i))
			KickClient(i);
	}

	return Plugin_Handled;
}

Action cmdBotSet(int client, int args)
{
	if(!g_iRoundStart || !g_iPlayerSpawn)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(args != 1)
	{
		ReplyToCommand(client, "\x01!botset/sm_botset <\x05数量\x01>.");
		return Plugin_Handled;
	}
	
	char sArgs[4];
	GetCmdArg(1, sArgs, sizeof sArgs);
	int iArgs = StringToInt(sArgs);
	if(iArgs < 1 || iArgs > 31)
	{
		ReplyToCommand(client, "\x01参数范围 \x051\x01~\x0531\x01.");
		return Plugin_Handled;
	}

	g_hSurvivorLimitSet.IntValue = iArgs;

	delete g_hBotsUpdateTimer;
	g_hBotsUpdateTimer = CreateTimer(1.0, tmrBotsUpdate);
	ReplyToCommand(client, "\x05开局BOT数量已设置为\x01-> \x04%d\x01.", iArgs);

	return Plugin_Handled;
}

Action CommandListener_SpecNext(int client, char[] command, int argc)
{
	if(!g_esPlayer[client].bSpecNotify || !client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_SPECTATOR || iGetBotOfIdlePlayer(client))
		return Plugin_Continue;

	g_esPlayer[client].bSpecNotify = false;

	switch(g_iSpecNextNotify)
	{
		case 1:
			PrintToChat(client, "\x01聊天栏输入 \x05!join \x01加入游戏.");

		case 2:
			PrintHintText(client, "聊天栏输入 !join 加入游戏");

		case 3:
			vJoinSurvivorMenu(client);
	}

	return Plugin_Continue;
}

void vJoinSurvivorMenu(int client)
{
	EmitSoundToClient(client, SOUND_SPECMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	Menu menu = new Menu(iJoinSurvivorMenuHandler);
	menu.SetTitle("加入生还者?");
	menu.AddItem("y", "是");
	menu.AddItem("n", "否");

	if(iFindUselessSurvivorBot(true))
		menu.AddItem("t", "接管指定BOT");

	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iJoinSurvivorMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
					cmdJoinSurvivor(param1, 0);

				case 2:
					if(iFindUselessSurvivorBot(true))
						vDisplayBotList(param1);
					else
						PrintToChat(param1, "\x01没有 \x05空闲的电脑BOT \x01可以接管\x01.");
			}
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!g_bHideNameChange)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char sMessage[254];
	msg.ReadString(sMessage, sizeof sMessage, true);
	if(strcmp(sMessage, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	vGetLimitCvars();
	vGetWeaponCvars();
	vGetGeneralCvars();
}

void vLimitConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetLimitCvars();
}

void vGetLimitCvars()
{
	g_hSurvivorLimit.IntValue = g_iSurvivorLimitSet = g_hSurvivorLimitSet.IntValue;
}

void vGeneralConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetGeneralCvars();
}

void vGetGeneralCvars()
{
	g_bAutoJoin = g_hAutoJoin.BoolValue;
	g_bRespawnJoin = g_hRespawnJoin.BoolValue;
	g_iSpecCmdLimit = g_hSpecCmdLimit.IntValue;
	g_iSpecNextNotify = g_hSpecNextNotify.IntValue;
}

void vWeaponConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetWeaponCvars();
}

void vGetWeaponCvars()
{
	int iNullSlot;
	for(int i; i < MAX_SLOTS; i++)
	{
		g_esWeapon[i].iCount = 0;
		if(!g_esWeapon[i].cFlags.BoolValue || !iGetSlotAllowed(i))
			iNullSlot++;
	}

	g_bGiveWeaponType = iNullSlot < MAX_SLOTS ? g_hGiveWeaponType.BoolValue : false;
	g_bGiveWeaponTime = g_hGiveWeaponTime.BoolValue;
}

int iGetSlotAllowed(int iSlot)
{
	for(int i; i < 17; i++)
	{
		if(g_sWeaponName[iSlot][i][0] == '\0')
			break;

		if((1 << i) & g_esWeapon[iSlot].cFlags.IntValue)
			g_esWeapon[iSlot].iAllowed[g_esWeapon[iSlot].iCount++] = i;
	}
	return g_esWeapon[iSlot].iCount;
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;

	g_esPlayer[client].sSteamID[0] = '\0';

	if(g_iRoundStart)
	{
		delete g_hBotsUpdateTimer;
		g_hBotsUpdateTimer = CreateTimer(1.0, tmrBotsUpdate);
	}
}

Action tmrBotsUpdate(Handle timer)
{
	g_hBotsUpdateTimer = null;

	if(!SDKCall(g_hSDKIsInTransition, g_pDirector))
		vSpawnCheck();
	else
		g_hBotsUpdateTimer = CreateTimer(1.0, tmrBotsUpdate);

	return Plugin_Continue;
}

void vSpawnCheck()
{
	if(!g_iRoundStart)
		return;

	int iSurvivor		= iGetTeamPlayers(TEAM_SURVIVOR, true);
	int iHumanSurvivor	= iGetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLimit	= g_iSurvivorLimitSet;
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
	int iBot = iFindUnusedSurvivorBot(); // 优先踢出没有对应真实玩家且后生成的Bot
	if(iBot)
	{
		vRemovePlayerWeapons(iBot);
		KickClient(iBot, "Kicking Useless Client.");
	}
}

void vSpawnFakeSurvivorClient()
{
	int iBot = iCreateSurvivorBot();
	if(iBot)
	{
		if(!IsPlayerAlive(iBot))
			vRoundRespawn(iBot);

		vSetGodMode(iBot, 3.0);
		vTeleportToSurvivor(iBot);
	}
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

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	vResetPlugin();

	for(int i = 1; i <= MaxClients; i++)
		vAutoTakeOverBot(i);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	g_iPlayerSpawn = 1;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return;

	delete g_hBotsUpdateTimer;
	g_hBotsUpdateTimer = CreateTimer(2.0, tmrBotsUpdate);
		
	if(!IsFakeClient(client) && bIsFirstTime(client))
		vRecordSteamID(client);

	vSetGhostStatus(client, 0);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client)
		vAutoTakeOverBot(client);
}

void vAutoTakeOverBot(int client)
{
	int iIdlePlayer;
	if(IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && bIsValidHumanSpectator((iIdlePlayer = iGetIdlePlayerOfBot(client))))
		vTakeOverBot(iIdlePlayer, client);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	switch(event.GetInt("team"))
	{
		case TEAM_SPECTATOR:
		{
			g_esPlayer[client].bSpecNotify = true;

			if(g_bAutoJoin && event.GetInt("oldteam") == TEAM_NOTEAM)
				CreateTimer(1.0, tmrAutoJoinSurvivorTeam, event.GetInt("userid"), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}

		case TEAM_SURVIVOR:
			vSetGhostStatus(client, 0);
	}
}

Action tmrAutoJoinSurvivorTeam(Handle timer, int client)
{
	if(!g_bAutoJoin || !(client = GetClientOfUserId(client)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) > TEAM_SPECTATOR || iGetBotOfIdlePlayer(client)) 
		return Plugin_Stop;

	if(!g_iRoundStart || GetClientTeam(client) == TEAM_NOTEAM || SDKCall(g_hSDKIsInTransition, g_pDirector))
		return Plugin_Continue;

	cmdJoinSurvivor(client, 0);
	return Plugin_Stop;
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	int playerUID = event.GetInt("player");
	int player = GetClientOfUserId(playerUID);
	if(!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int botUID = event.GetInt("bot");
	int bot = GetClientOfUserId(botUID);

	g_esPlayer[bot].iBotPlayer = playerUID;
	g_esPlayer[player].iPlayerBot = botUID;

	if(g_esPlayer[player].sModel[0] == '\0')
		return;

	SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
	SetEntityModel(bot, g_esPlayer[player].sModel);
	for(int i; i < 8; i++)
	{
		if(strcmp(g_esPlayer[player].sModel, g_sSurvivorModels[i], false) == 0)
		{
			g_bHideNameChange = true;
			SetClientName(bot, g_sSurvivorNames[i]);
			g_bHideNameChange = false;
			break;
		}
	}
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if(!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));

	char sModel[128];
	GetClientModel(bot, sModel, sizeof sModel);
	SetEntityModel(player, sModel);
}

void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	int entity = FindEntityByClassname(MaxClients + 1, "info_survivor_position");
	if(entity == INVALID_ENT_REFERENCE)
		return;

	float vOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);

	int iSurvivor;
	static const char sOrder[][] = {"1", "2", "3", "4"};
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;
			
		if(++iSurvivor < 4)
			continue;
			
		entity = CreateEntityByName("info_survivor_position");
		if(entity == INVALID_ENT_REFERENCE)
			continue;

		DispatchKeyValue(entity, "Order", sOrder[iSurvivor - RoundToFloor(iSurvivor / 4.0) * 4]);
		TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(entity);
	}
}

/**
bool bAreAllInGame()/
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i)) // 加载中
			return false;
	}
	return true;
}*/

bool bIsFirstTime(int client)
{
	if(!bCacheSteamID(client))
		return false;

	bool bAllowed = true;
	g_aSteamIDs.GetValue(g_esPlayer[client].sSteamID, bAllowed);
	return bAllowed;
}

void vRecordSteamID(int client)
{
	if(bCacheSteamID(client))
		g_aSteamIDs.SetValue(g_esPlayer[client].sSteamID, false, true);
}

bool bCacheSteamID(int client)
{
	if(g_esPlayer[client].sSteamID[0] == '\0')
		return GetClientAuthId(client, AuthId_Steam2, g_esPlayer[client].sSteamID, sizeof esPlayer::sSteamID);
	return true;
}

int iGetBotOfIdlePlayer(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && iGetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

static int iGetIdlePlayerOfBot(int client)
{
	static char sNetClass[64];
	GetEntityNetClass(client, sNetClass, sizeof sNetClass);
	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

bool bIsValidHumanSpectator(int client)
{
	return client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPECTATOR;
}

static int iGetTeamPlayers(int iTeam, bool bIncludeBots)
{
	static int i;
	static int iPlayers;

	iPlayers = 0;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == iTeam)
		{
			if(!bIncludeBots && IsFakeClient(i) && !iGetIdlePlayerOfBot(i))
				continue;

			iPlayers++;
		}
	}
	return iPlayers;
}

bool bIsValidSurvivorBot(int client, int alive = -1)
{
	if(!IsClientInGame(client) || IsClientInKickQueue(client) || !IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return false;

	return (alive == -1 || IsPlayerAlive(client) == view_as<bool>(alive)) && !iGetIdlePlayerOfBot(client);
}

int iFindUnusedSurvivorBot()
{
	int client;
	ArrayList aClients = new ArrayList(2);

	for(int i = MaxClients; i >= 1; i--)
	{
		if(!bIsValidSurvivorBot(i, -1))
			continue;

		aClients.Set(aClients.Push(!(client = GetClientOfUserId(g_esPlayer[i].iBotPlayer)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SURVIVOR ? 0 : 1), i, 1);
	}

	if(!aClients.Length)
		client = 0;
	else
	{
		aClients.Sort(Sort_Ascending, Sort_Integer);
		client = aClients.Get(0, 1);
	}

	delete aClients;
	return client;
}

/*int iFindUselessSurvivorBot()
{
	int client;
	ArrayList aClients = new ArrayList(2);

	for(int i = MaxClients; i >= 1; i--)
	{
		if(!bIsValidSurvivorBot(i, 1))
			continue;

		aClients.Set(aClients.Push(!(client = GetClientOfUserId(g_esPlayer[i].iBotPlayer)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SURVIVOR ? 0 : 1), i, 1);
	}

	if(!aClients.Length)
		client = 0;
	else
	{
		aClients.Sort(Sort_Descending, Sort_Integer);

		client = aClients.Length - 1;
		client = aClients.Get(GetRandomInt(aClients.FindValue(aClients.Get(client, 0)), client), 1);
	}

	delete aClients;
	return client;
}*/

int iFindUselessSurvivorBot(bool bAlive)
{
	int client;
	ArrayList aClients = new ArrayList(2);

	for(int i = MaxClients; i >= 1; i--)
	{
		if(!IsClientInGame(i) || IsClientInKickQueue(i) || !IsFakeClient(i) || GetClientTeam(i) != TEAM_SURVIVOR || iGetIdlePlayerOfBot(i))
			continue;

		aClients.Set(aClients.Push(IsPlayerAlive(i) == bAlive ? (!(client = GetClientOfUserId(g_esPlayer[i].iBotPlayer)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SURVIVOR ? 0 : 1) : (!(client = GetClientOfUserId(g_esPlayer[i].iBotPlayer)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SURVIVOR ? 2 : 3)), i, 1);
	}

	if(!aClients.Length)
		client = 0;
	else
	{
		aClients.Sort(Sort_Descending, Sort_Integer);

		client = aClients.Length - 1;
		client = aClients.Get(GetRandomInt(aClients.FindValue(aClients.Get(client, 0)), client), 1);
	}

	delete aClients;
	return client;
}

void vSetGodMode(int client, float fDuration)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 0);

	if(fDuration > 0.0)
		CreateTimer(fDuration, tmrMortal, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

Action tmrMortal(Handle timer, int client)
{
	if(!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetEntProp(client, Prop_Data, "m_takedamage") != 0)
		return Plugin_Stop;

	SetEntProp(client, Prop_Data, "m_takedamage", 2);
	return Plugin_Continue;
}

void vGiveDefaultItems(int client)
{
	vRemovePlayerWeapons(client);

	for(int i = 4; i >= 2; i--)
	{
		if(!g_esWeapon[i].iCount)
			continue;

		vCheatCommand(client, "give", g_sWeaponName[i][g_esWeapon[i].iAllowed[GetRandomInt(0, g_esWeapon[i].iCount - 1)]]);
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
	if(g_esWeapon[1].iCount)
	{
		int iRandom = g_esWeapon[1].iAllowed[GetRandomInt(0, g_esWeapon[1].iCount - 1)];
		if(iRandom > 2)
			vGiveMelee(client, g_sWeaponName[1][iRandom]);
		else
			vCheatCommand(client, "give", g_sWeaponName[1][iRandom]);
	}
}

void vGivePresetPrimary(int client)
{
	if(g_esWeapon[0].iCount)
		vCheatCommand(client, "give", g_sWeaponName[0][g_esWeapon[0].iAllowed[GetRandomInt(0, g_esWeapon[0].iCount - 1)]]);
}

bool bIsWeaponTier1(int iWeapon)
{
	char sWeapon[32];
	GetEntityClassname(iWeapon, sWeapon, sizeof sWeapon);
	for(int i; i < 5; i++)
	{
		if(strcmp(sWeapon[7], g_sWeaponName[0][i]) == 0)
			return true;
	}
	return false;
}

void vGiveAveragePrimary(int client)
{
	int i = 1, iWeapon, iTier, iTotal;
	for(; i <= MaxClients; i++)
	{
		if(i == client || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
			continue;

		iTotal += 1;	
		iWeapon = GetPlayerWeaponSlot(i, 0);
		if(iWeapon <= MaxClients || !IsValidEntity(iWeapon))
			continue;

		iTier += bIsWeaponTier1(iWeapon) ? 1 : 2;
	}

	switch(iTotal > 0 ? RoundToNearest(1.0 * iTier / iTotal) : 0)
	{
		case 1:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(0, 4)]); // 随机给一把tier1武器

		case 2:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(5, 14)]); // 随机给一把tier2武器	
	}
}

void vRemovePlayerWeapons(int client)
{
	int iWeapon;
	for(int i; i < MAX_SLOTS; i++)
	{
		if((iWeapon = GetPlayerWeaponSlot(client, i)) > MaxClients)
		{
			RemovePlayerItem(client, iWeapon);
			RemoveEdict(iWeapon);
		}
	}

	iWeapon = GetEntDataEnt2(client, g_iOffHiddenWeapon);
	if(iWeapon > MaxClients && IsValidEntity(iWeapon) && GetEntPropEnt(iWeapon, Prop_Data, "m_hOwnerEntity") == client)
	{
		RemovePlayerItem(client, iWeapon);
		RemoveEdict(iWeapon);
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

void vTeleportToSurvivor(int client, bool bRandom = true)
{
	int iSurvivor = 1;
	ArrayList aClients = new ArrayList(2);

	for(; iSurvivor <= MaxClients; iSurvivor++)
	{
		if(iSurvivor == client || !IsClientInGame(iSurvivor) || GetClientTeam(iSurvivor) != 2 || !IsPlayerAlive(iSurvivor))
			continue;
	
		aClients.Set(aClients.Push(!GetEntProp(iSurvivor, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(iSurvivor, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), iSurvivor, 1);
	}

	if(!aClients.Length)
		iSurvivor = 0;
	else
	{
		aClients.Sort(Sort_Descending, Sort_Integer);

		if(!bRandom)
			iSurvivor = aClients.Get(aClients.Length - 1, 1);
		else
		{
			iSurvivor = aClients.Length - 1;
			iSurvivor = aClients.Get(GetRandomInt(aClients.FindValue(aClients.Get(iSurvivor, 0)), iSurvivor), 1);
		}
	}

	delete aClients;

	if(iSurvivor)
	{
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags")|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(iSurvivor, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

void vSetGhostStatus(int client, int iGhost)
{
	SetEntProp(client, Prop_Send, "m_isGhost", iGhost);
}

// 给玩家近战
// L4D2- Melee In The Saferoom (https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484)
public void OnMapStart()
{
	int i;
	int iLength = sizeof g_sWeaponModels;
	for(; i < iLength; i++)
	{
		if(!IsModelPrecached(g_sWeaponModels[i]))
			PrecacheModel(g_sWeaponModels[i], true);
	}

	char sBuffer[64];
	for(i = 3; i < 17; i++)
	{
		FormatEx(sBuffer, sizeof sBuffer, "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}

	PrecacheSound(SOUND_SPECMENU);
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

void vGiveMelee(int client, const char[] sMeleeName)
{
	char sScriptName[64];
	if(g_aMeleeScripts.FindString(sMeleeName) != -1)
		strcopy(sScriptName, sizeof sScriptName, sMeleeName);
	else
		g_aMeleeScripts.GetString(GetRandomInt(0, g_aMeleeScripts.Length - 1), sScriptName, sizeof sScriptName);
	
	vCheatCommand(client, "give", sScriptName);
}

void vDisplayTeamPanel(int client)
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

	Panel hPanel = new Panel();
	hPanel.SetTitle("---团队信息---");

	char sBuffer[254];
	FormatEx(sBuffer, sizeof sBuffer, "旁观者 (%d)", iGetTeamPlayers(TEAM_SPECTATOR, false));
	hPanel.DrawItem(sBuffer);

	int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != TEAM_SPECTATOR)
			continue;

		FormatEx(sBuffer, sizeof sBuffer, "%N", i);
		ReplaceString(sBuffer, sizeof sBuffer, "[", "");
			
		if(iGetBotOfIdlePlayer(i))
			Format(sBuffer, sizeof sBuffer, "闲置 - %s", sBuffer);
		else
			Format(sBuffer, sizeof sBuffer, "观众 - %s", sBuffer);

		hPanel.DrawText(sBuffer);
	}

	FormatEx(sBuffer, sizeof sBuffer, "生还者 (%d/%d) - %d Bot(s)", iGetTeamPlayers(TEAM_SURVIVOR, false), g_iSurvivorLimitSet, iCountSurvivorBots());
	hPanel.DrawItem(sBuffer);

	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;
		
		FormatEx(sBuffer, sizeof sBuffer, "%N", i);
		ReplaceString(sBuffer, sizeof sBuffer, "[", "");
	
		if(IsPlayerAlive(i))
		{
			if(GetEntProp(i, Prop_Send, "m_isIncapacitated"))
				Format(sBuffer, sizeof sBuffer, "倒地 - %d HP - %s", GetClientHealth(i) + iGetTempHealth(i), sBuffer);
			else if(GetEntProp(i, Prop_Send, "m_currentReviveCount") >= FindConVar("survivor_max_incapacitated_count").IntValue)
				Format(sBuffer, sizeof sBuffer, "黑白 - %d HP - %s", GetClientHealth(i) + iGetTempHealth(i), sBuffer);
			else
				Format(sBuffer, sizeof sBuffer, "%dHP - %s", GetClientHealth(i) + iGetTempHealth(i), sBuffer);
	
		}
		else
			Format(sBuffer, sizeof sBuffer, "死亡 - %s", sBuffer);

		hPanel.DrawText(sBuffer);
	}

	FormatEx(sBuffer, sizeof sBuffer, "感染者 (%d)", iGetTeamPlayers(TEAM_INFECTED, false));
	hPanel.DrawItem(sBuffer);

	int iClass;
	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED)
			continue;

		if((iClass = GetEntProp(i, Prop_Send, "m_zombieClass")) != 8 && IsFakeClient(i))
			continue;

		FormatEx(sBuffer, sizeof sBuffer, "%N", i);
		ReplaceString(sBuffer, sizeof sBuffer, "[", "");

		if(IsPlayerAlive(i))
		{
			if(GetEntProp(i, Prop_Send, "m_isGhost"))
				Format(sBuffer, sizeof sBuffer, "(%s)鬼魂 - %s", sZombieClass[iClass], sBuffer);
			else
				Format(sBuffer, sizeof sBuffer, "(%s)%d HP - %s", sZombieClass[iClass], GetEntProp(i, Prop_Data, "m_iHealth"), sBuffer);
		}
		else
			Format(sBuffer, sizeof sBuffer, "(%s)死亡 - %s", sZombieClass[iClass], sBuffer);

		hPanel.DrawText(sBuffer);
	}

	hPanel.DrawItem("刷新");

	hPanel.Send(client, iTeamPanelHandler, 30);
	delete hPanel;
}

int iTeamPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
			if(param2 == 4)
				vDisplayTeamPanel(param1);

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iCountSurvivorBots()
{
	int iBot;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(bIsValidSurvivorBot(i, -1))
			iBot++;
	}
	return iBot;
}

int iGetTempHealth(int client)
{
	static ConVar hPainPillsDecay;
	if(hPainPillsDecay == null)
		hPainPillsDecay = FindConVar("pain_pills_decay_rate");

	int iTempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * hPainPillsDecay.FloatValue)) - 1;
	return iTempHealth < 0 ? 0 : iTempHealth;
}

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath)) 
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if(!g_pDirector)
		SetFailState("Failed to find address: CDirector");

	g_iOffHiddenWeapon = hGameData.GetOffset("CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenWeapon");
	if(g_iOffHiddenWeapon == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenWeapon");

	StartPrepSDKCall(SDKCall_Static);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "NextBotCreatePlayerBot<SurvivorBot>"))
		SetFailState("Failed to find signature: NextBotCreatePlayerBot<SurvivorBot>");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDKNextBotCreateSurvivorBot = EndPrepSDKCall();
	if(!g_hSDKNextBotCreateSurvivorBot)
		SetFailState("Failed to create SDKCall: NextBotCreatePlayerBot<SurvivorBot>");

	StartPrepSDKCall(SDKCall_Player);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn"))
		SetFailState("Failed to find signature: CTerrorPlayer::RoundRespawn");
	g_hSDKRoundRespawn = EndPrepSDKCall();
	if(!g_hSDKRoundRespawn)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::RoundRespawn");

	vRegisterStatsConditionPatch(hGameData);

	StartPrepSDKCall(SDKCall_Player);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator"))
		SetFailState("Failed to find signature: SurvivorBot::SetHumanSpectator");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDKSetHumanSpectator = EndPrepSDKCall();
	if(!g_hSDKSetHumanSpectator)
		SetFailState("Failed to create SDKCall: SurvivorBot::SetHumanSpectator");
	
	StartPrepSDKCall(SDKCall_Player);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot"))
		SetFailState("Failed to find signature: CTerrorPlayer::TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKTakeOverBot = EndPrepSDKCall();
	if(!g_hSDKTakeOverBot)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::TakeOverBot");

	StartPrepSDKCall(SDKCall_Player);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard"))
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKGoAwayFromKeyboard = EndPrepSDKCall();
	if(!g_hSDKGoAwayFromKeyboard)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GoAwayFromKeyboard");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: CDirector::IsInTransition");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsInTransition = EndPrepSDKCall();
	if(!g_hSDKIsInTransition)
		SetFailState("Failed to create SDKCall: CDirector::IsInTransition");

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

// [L4D1 & L4D2] SM Respawn Improved (https://forums.alliedmods.net/showthread.php?t=323220)
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

// Left 4 Dead 2 - CreateSurvivorBot (https://forums.alliedmods.net/showpost.php?p=2729883&postcount=16)
int iCreateSurvivorBot()
{
	g_bInSpawnTime = true;
	int iBot = SDKCall(g_hSDKNextBotCreateSurvivorBot, NULL_STRING);
	if(iBot)
		ChangeClientTeam(iBot, 2);

	g_bInSpawnTime = false;
	return iBot;
}

void vRoundRespawn(int client)
{			
	vStatsConditionPatch(true);
	g_bInSpawnTime = true;
	SDKCall(g_hSDKRoundRespawn, client);
	g_bInSpawnTime = false;
	vStatsConditionPatch(false);
}

/**
// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/clients.inc#:~:text=Spectator%20Movement%20modes-,enum%20Obs_Mode,-%7B
// Spectator Movement modes
enum Obs_Mode
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES
};
**/
void vSetHumanSpectator(int iBot, int client)
{
	SDKCall(g_hSDKSetHumanSpectator, iBot, client);
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iBot);
	if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 6)
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
}

void vTakeOverBot(int client, int iBot)
{
	SDKCall(g_hSDKSetHumanSpectator, iBot, client);
	SDKCall(g_hSDKTakeOverBot, client, true);
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GoAwayFromKeyboard");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::GoAwayFromKeyboard");

	if(!dDetour.Enable(Hook_Pre, mreGoAwayFromKeyboardPre))
		SetFailState("Failed to detour pre: CTerrorPlayer::GoAwayFromKeyboard");

	if(!dDetour.Enable(Hook_Post, mreGoAwayFromKeyboardPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GoAwayFromKeyboard");

	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GetPlayerByCharacter");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::GetPlayerByCharacter");
		
	if(!dDetour.Enable(Hook_Post, mreGetPlayerByCharacterPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GetPlayerByCharacter");

	dDetour = DynamicDetour.FromConf(hGameData, "CBasePlayer::SetModel");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: CBasePlayer::SetModel");
		
	if(!dDetour.Enable(Hook_Post, mrePlayerSetModelPost))
		SetFailState("Failed to detour pre: CBasePlayer::SetModel");

	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GiveDefaultItems");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::GiveDefaultItems");
		
	if(!dDetour.Enable(Hook_Post, mreGiveDefaultItemsPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GiveDefaultItems");
}

// [L4D1 & L4D2]Survivor_AFK_Fix[Left 4 Fix] (https://forums.alliedmods.net/showthread.php?p=2714236)
public void OnEntityCreated(int entity, const char[] classname)
{
	if(!g_bShouldFixAFK)
		return;
	
	if(classname[0] != 's' || strcmp(classname, "survivor_bot", false) != 0)
		return;
	
	g_iSurvivorBot = entity;
}

MRESReturn mreGoAwayFromKeyboardPre(int pThis, DHookReturn hReturn)
{
	g_bShouldFixAFK = true;
	return MRES_Ignored;
}

MRESReturn mreGoAwayFromKeyboardPost(int pThis, DHookReturn hReturn)
{
	g_iSurvivorBot = 0;
	g_bShouldFixAFK = false;
	return MRES_Ignored;
}

MRESReturn mreGetPlayerByCharacterPost(DHookReturn hReturn, DHookParam hParams)
{
	if(!g_bShouldFixAFK)
		return MRES_Ignored;
	
	if(!g_iSurvivorBot)
		return MRES_Ignored;

	if(!IsFakeClient(g_iSurvivorBot))
		return MRES_Ignored;

	hReturn.Value = g_iSurvivorBot;
	return MRES_Supercede;
}

// [L4D(2)] Survivor Identity Fix for 5+ Survivors (https://forums.alliedmods.net/showpost.php?p=2718792&postcount=36)
MRESReturn mrePlayerSetModelPost(int pThis, DHookParam hParams)
{
	if(pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis) || IsFakeClient(pThis))
		return MRES_Ignored;

	if(GetClientTeam(pThis) != TEAM_SURVIVOR)
	{
		g_esPlayer[pThis].sModel[0] = '\0';
		return MRES_Ignored;
	}
	
	static char sModel[128];
	hParams.GetString(1, sModel, sizeof sModel);
	if(StrContains(sModel, "survivors", false) >= 0)
		strcopy(g_esPlayer[pThis].sModel, sizeof esPlayer::sModel, sModel);

	return MRES_Ignored;
}

MRESReturn mreGiveDefaultItemsPost(int pThis)
{
	if(!g_bGiveWeaponType || g_bShouldFixAFK || g_bGiveWeaponTime && !g_bInSpawnTime)
		return MRES_Ignored;

	if(pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis) || GetClientTeam(pThis) != TEAM_SURVIVOR || !IsPlayerAlive(pThis) || bTakingOverBot(pThis))
		return MRES_Ignored;

	vGiveDefaultItems(pThis);
	return MRES_Ignored;
}

bool bTakingOverBot(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && iGetIdlePlayerOfBot(i) == client)
			return true;
	}
	return false;
}
