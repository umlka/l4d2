#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

/*****************************************************************************************************/
// ====================================================================================================
// colors.inc
// ====================================================================================================
#define SERVER_INDEX 0
#define NO_INDEX 	-1
#define NO_PLAYER 	-2
#define BLUE_INDEX 	 2
#define RED_INDEX 	 3
#define MAX_COLORS 	 6
#define MAX_MESSAGE_LENGTH 250
static const char CTag[][] = { "{default}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}" };
static const char CTagCode[][] = { "\x01", "\x04", "\x03", "\x03", "\x03", "\x05" };
static const bool CTagReqSayText2[] = { false, false, true, true, true, false };
static const int CProfile_TeamIndex[] = { NO_INDEX, NO_INDEX, SERVER_INDEX, RED_INDEX, BLUE_INDEX, NO_INDEX };

/**
 * @note Prints a message to a specific client in the chat area.
 * @note Supports color tags.
 *
 * @param client	Client index.
 * @param sMessage	Message (formatting rules).
 * @return			No return
 * 
 * On error/Errors:	If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] sMessage, any ...)
{
	if(client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if(!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	static char sBuffer[MAX_MESSAGE_LENGTH];
	static char sCMessage[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	Format(sBuffer, sizeof(sBuffer), "\x01%s", sMessage);
	VFormat(sCMessage, sizeof(sCMessage), sBuffer, 3);
	
	int index = CFormat(sCMessage, sizeof(sCMessage));
	if(index == NO_INDEX)
		PrintToChat(client, "%s", sCMessage);
	else
		CSayText2(client, index, sCMessage);
}

/**
 * @note Prints a message to all clients in the chat area.
 * @note Supports color tags.
 *
 * @param client	Client index.
 * @param sMessage	Message (formatting rules)
 * @return			No return
 */
stock void CPrintToChatAll(const char[] sMessage, any ...)
{
	static char sBuffer[MAX_MESSAGE_LENGTH];

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(sBuffer, sizeof(sBuffer), sMessage, 2);
			CPrintToChat(i, "%s", sBuffer);
		}
	}
}

/**
 * @note Replaces color tags in a string with color codes
 *
 * @param sMessage	String.
 * @param maxlength	Maximum length of the string buffer.
 * @return			Client index that can be used for SayText2 author index
 * 
 * On error/Errors:	If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] sMessage, int maxlength)
{	
	int iRandomPlayer = NO_INDEX;
	
	for(int i; i < MAX_COLORS; i++)														//	Para otras etiquetas de color se requiere un bucle.
	{
		if(StrContains(sMessage, CTag[i]) == -1)										//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if(!CTagReqSayText2[i])
			ReplaceString(sMessage, maxlength, CTag[i], CTagCode[i], false);			//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else																			//	La etiqueta necesita Saytext2.
		{	
			if(iRandomPlayer == NO_INDEX)												//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
			{
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]);			//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if(iRandomPlayer == NO_PLAYER)
					ReplaceString(sMessage, maxlength, CTag[i], CTagCode[5], false);	//	Si no se encuentra un cliente valido, reemplasa la etiqueta con una etiqueta de color verde.
				else 
					ReplaceString(sMessage, maxlength, CTag[i], CTagCode[i], false);	// 	Si el cliente fue encontrado simplemente reemplasa.
			}
			else																		//	Si en caso de usar dos colores de equipo infectado y equipo de superviviente juntos se mandará un mensaje de error.
				ThrowError("Using two team colors in one message is not allowed");		//	Si se ha usadó una combinación de colores no validad se registrara en la carpeta logs.
		}
	}

	return iRandomPlayer;
}

/**
 * @note Founds a random player with specified team
 *
 * @param color_team	Client team.
 * @return				Client index or NO_PLAYER if no player found
 */
stock int CFindRandomPlayerByTeam(int color_team)
{
	if(color_team == SERVER_INDEX)
		return 0;
	else
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == color_team)
				return i;
		}
	}

	return NO_PLAYER;
}

/**
 * @note Sends a SayText2 usermessage to a client
 *
 * @param sMessage	Client index
 * @param maxlength	Author index
 * @param sMessage	Message
 * @return			No return.
 */
stock void CSayText2(int client, int author, const char[] sMessage)
{
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	bf.WriteByte(author);
	bf.WriteByte(true);
	bf.WriteString(sMessage);
	EndMessage();
}
/*****************************************************************************************************/

#define GAMEDATA	"survivor_auto_respawn"
#define CVAR_FLAGS	FCVAR_NOTIFY

Handle
	g_hSDKRoundRespawn,
	g_hSDKGoAwayFromKeyboard,
	g_hRespawnTimer[MAXPLAYERS + 1];

Address
	g_pStatsCondition;

ConVar
	g_hRespawnTime,
	g_hRespawnLimit,
	g_hAllowSurvivorBot,
	g_hAllowSurvivorIdle,
	g_hGiveWeaponType,
	g_hSlotFlags[5],
	g_hSbAllBotGame,
	g_hAllowAllBotSurvivorTeam;

bool
	g_bAllowSurvivorBot,
	g_bAllowSurvivorIdle;

int
	g_iRespawnTime,
	g_iRespawnLimit,
	g_iSlotCount[5],
	g_iSlotWeapons[5][20],
	g_iMeleeClassCount,
	g_iDeathModel[MAXPLAYERS + 1],
	g_iPlayerRespawned[MAXPLAYERS + 1],
	g_iRespawnCountdown[MAXPLAYERS + 1];

char
	g_sMeleeClass[16][32];

static const char
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

public Plugin myinfo = 
{
	name = "Survivor Auto Respawn",
	author = "sorallll",
	description = "",
	version = "1.3.2",
	url = "https://steamcommunity.com/id/sorallll"
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hRespawnTime = CreateConVar("sar_respawn_time", "15", "玩家自动复活时间(秒)", CVAR_FLAGS, true, 0.0);
	g_hRespawnLimit = CreateConVar("sar_respawn_limit", "5", "玩家每回合自动复活次数", CVAR_FLAGS, true, 0.0);
	g_hAllowSurvivorBot = CreateConVar("sar_respawn_bot", "1", "是否允许Bot自动复活 \n0=否,1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hAllowSurvivorIdle = CreateConVar("sar_respawn_idle", "1", "是否允许闲置玩家自动复活 \n0=否,1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hGiveWeaponType = CreateConVar("sar_give_type", "0", "根据什么来给玩家装备. \n0=不给,1=根据每个槽位的设置,2=根据当前所有生还者的平均装备质量(仅主副武器)", CVAR_FLAGS, true, 0.0, true, 2.0);

	g_hSlotFlags[0] = CreateConVar("sar_respawn_slot0", "131071", "主武器给什么 \n0=不给,131071=所有,7=微冲,1560=霰弹,30720=狙击,31=Tier1,32736=Tier2,98304=Tier0", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[1] = CreateConVar("sar_respawn_slot1", "5160", "副武器给什么 \n0=不给,131071=所有.如果选中了近战且该近战在当前地图上未解锁,则会随机给一把", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[2] = CreateConVar("sar_respawn_slot2", "7", "投掷物给什么 \n0=不给,7=所有", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[3] = CreateConVar("sar_respawn_slot3", "15", "槽位3给什么 \n0=不给,15=所有", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[4] = CreateConVar("sar_respawn_slot4", "3", "槽位4给什么 \n0=不给,3=所有", CVAR_FLAGS, true, 0.0);

	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hAllowAllBotSurvivorTeam = FindConVar("allow_all_bot_survivor_team");

	g_hRespawnTime.AddChangeHook(vConVarChanged);
	g_hRespawnLimit.AddChangeHook(vConVarChanged);
	g_hAllowSurvivorBot.AddChangeHook(vConVarChanged);
	g_hAllowSurvivorIdle.AddChangeHook(vConVarChanged);

	for(int i; i < 5; i++)
		g_hSlotFlags[i].AddChangeHook(vSlotConVarChanged);
		
	AutoExecConfig(true, "survivor_auto_respawn");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);
}

public void OnConfigsExecuted()
{
	vGetCvars();
	vGetSlotCvars();
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vSlotConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetSlotCvars();
}

void vGetCvars()
{
	g_iRespawnTime = g_hRespawnTime.IntValue;
	g_iRespawnLimit = g_hRespawnLimit.IntValue;
	g_bAllowSurvivorBot = g_hAllowSurvivorBot.BoolValue;
	g_bAllowSurvivorIdle = g_hAllowSurvivorIdle.BoolValue;
}

void vGetSlotCvars()
{
	for(int i; i < 5; i++)
	{
		g_iSlotCount[i] = 0;
		if(g_hSlotFlags[i].IntValue > 0)
			vGetSlotInfo(i);
	}
}

void vGetSlotInfo(int iSlot)
{
	for(int i; i < 17; i++)
	{
		if(g_sWeaponName[iSlot][i][0] == 0)
			return;
		
		if((1 << i) & g_hSlotFlags[iSlot].IntValue)
			g_iSlotWeapons[iSlot][g_iSlotCount[iSlot]++] = i;
	}
}

public void L4D2_OnSurvivorDeathModelCreated(int iClient, int iDeathModel)
{
	g_iDeathModel[iClient] = EntIndexToEntRef(iDeathModel);
}

public void OnClientPutInServer(int client)
{
	g_iPlayerRespawned[client] = 0;
}

public void OnClientDisconnect(int client)
{
	delete g_hRespawnTimer[client];
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iPlayerRespawned[i] = 0;
		delete g_hRespawnTimer[i];
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		delete g_hRespawnTimer[i];
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRespawnTime == 0 || g_iRespawnLimit == 0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client))
		return;

	if(IsPlayerAlive(client))
	{
		vRemoveSurvivorDeathModel(client);
		return;
	}

	if(g_hRespawnTimer[client] != null || GetClientTeam(client) != 2 || (!g_bAllowSurvivorBot && IsFakeClient(client)))
		return;

	if(bCalculateRespawnLimit(client))
	{
		delete g_hRespawnTimer[client];
		g_hRespawnTimer[client] = CreateTimer(1.0, Timer_RespawnSurvivor, GetClientUserId(client), TIMER_REPEAT);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRespawnTime == 0 || g_iRespawnLimit == 0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if(IsFakeClient(client))
	{
		int iIdlePlayer = iHasIdlePlayer(client);
		if(iIdlePlayer == 0)
		{
			if(!g_bAllowSurvivorBot)
				return;
		}
		else
		{
			if(!g_bAllowSurvivorIdle)
				return;
			else
				client = iIdlePlayer;
		}
	}

	if(bCalculateRespawnLimit(client))
	{
		delete g_hRespawnTimer[client];
		g_hRespawnTimer[client] = CreateTimer(1.0, Timer_RespawnSurvivor, GetClientUserId(client), TIMER_REPEAT);
	}
}

int iHasIdlePlayer(int client)
{
	char sNetClass[64];
	if(!GetEntityNetClass(client, sNetClass, sizeof(sNetClass)))
		return 0;

	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
		return client;

	return 0;
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	if(g_iRespawnTime == 0 || g_iRespawnLimit == 0 || !g_bAllowSurvivorBot)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(!IsFakeClient(bot) || IsPlayerAlive(bot))
		return;

	if(bCalculateRespawnLimit(bot))
	{
		delete g_hRespawnTimer[bot];
		g_hRespawnTimer[bot] = CreateTimer(1.0, Timer_RespawnSurvivor, GetClientUserId(bot), TIMER_REPEAT);
	}
}

bool bCalculateRespawnLimit(int client)
{
	if(g_iPlayerRespawned[client] >= g_iRespawnLimit)
	{
		if(!IsFakeClient(client))
			PrintHintText(client, "复活次数已耗尽，请等待队友救援");

		return false;
	}

	g_iRespawnCountdown[client] = g_iRespawnTime;
	return true;
}

Action Timer_RespawnSurvivor(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0)
		return Plugin_Stop;

	if(IsClientInGame(client) && GetClientTeam(client) == 2 && !IsPlayerAlive(client))
	{
		if(g_iRespawnCountdown[client] > 0)
		{
			if(!IsFakeClient(client))
				PrintCenterText(client, "%d 秒后复活", g_iRespawnCountdown[client]);

			g_iRespawnCountdown[client]--;
		}
		else
		{
			vRespawnSurvivor(client);
			g_hRespawnTimer[client] = null;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	g_hRespawnTimer[client] = null;
	return Plugin_Stop;	
}

void vRespawnSurvivor(int client)
{
	vRoundRespawn(client);
	if(g_hGiveWeaponType.BoolValue)
		vGiveWeapon(client);

	vSetGodMode(client, 1.0);
	vTeleportToSurvivor(client);
	g_iPlayerRespawned[client]++;

	if(!IsFakeClient(client))
	{
		if(bCanIdle(client))
			SDKCall(g_hSDKGoAwayFromKeyboard, client);

		CPrintToChat(client, "{olive}剩余复活次数 {default}-> {blue}%d", g_iRespawnLimit - g_iPlayerRespawned[client]);
	}	
}

bool bCanIdle(int client)
{
	if(g_hSbAllBotGame.BoolValue || g_hAllowAllBotSurvivorTeam.BoolValue)
		return true;

	int iSurvivor;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			iSurvivor++;
	}
	return iSurvivor > 0;
}

void vRemoveSurvivorDeathModel(int client)
{
	if(!bIsValidEntRef(g_iDeathModel[client]))
		return;

	RemoveEntity(g_iDeathModel[client]);
	g_iDeathModel[client] = 0;
}

bool bIsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}
/*
//https://forums.alliedmods.net/showthread.php?t=327928
void vTerror_SetAdrenalineTime(int client, float fDuration)
{
    // Get CountdownTimer address
    static int iTimerAddress = -1;
    if(iTimerAddress == -1)
        iTimerAddress = FindSendPropInfo("CTerrorPlayer", "m_bAdrenalineActive") - 12;
    
    //iTimerAddress + 4 = Duration
    //iTimerAddress + 8 = TimeStamp
    SetEntDataFloat(client, iTimerAddress + 4, fDuration);
    SetEntDataFloat(client, iTimerAddress + 8, GetGameTime() + fDuration);
    SetEntProp(client, Prop_Send, "m_bAdrenalineActive", 1);
} 
*/
void vGiveWeapon(int client)
{
	if(!IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

	for(int i = 4; i >= 2; i--)
	{
		if(g_iSlotCount[i] == 0)
			continue;

		vRemovePlayerSlot(client, i);
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
		vRemovePlayerSlot(client, 1);
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
	{
		vRemovePlayerSlot(client, 0);
		vCheatCommand(client, "give", g_sWeaponName[0][g_iSlotWeapons[0][GetRandomInt(0, g_iSlotCount[0] - 1)]]);
	}
}

bool bIsWeaponTier1(int iWeapon)
{
	static char sWeapon[32];
	GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
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
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
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

	vRemovePlayerSlot(client, 0);

	switch(iTotal > 0 ? RoundToNearest(1.0 * iTier / iTotal) : 0)
	{
		case 1:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(0, 4)]); //随机给一把tier1武器

		case 2:
			vCheatCommand(client, "give", g_sWeaponName[0][GetRandomInt(5, 14)]); //随机给一把tier2武器	
	}
}

void vCheatCommand(int client, const char[] sCommand, const char[] sArguments = "")
{
	int iFlagBits, iCmdFlags;
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
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
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

void vRemovePlayerSlot(int client, int iSlot)
{
	iSlot = GetPlayerWeaponSlot(client, iSlot);
	if(iSlot > MaxClients && IsValidEntity(iSlot))
	{
		if(RemovePlayerItem(client, iSlot))
			RemoveEdict(iSlot);
	}
}

void vSetGodMode(int client, float fDuration)
{
	if(!IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 0);

	if(fDuration > 0.0) 
		CreateTimer(fDuration, Timer_Mortal, GetClientUserId(client));
}

Action Timer_Mortal(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntProp(client, Prop_Data, "m_takedamage", 2);
	return Plugin_Continue;
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

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKGoAwayFromKeyboard = EndPrepSDKCall();
	if(g_hSDKGoAwayFromKeyboard == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GoAwayFromKeyboard");

	vRegisterStatsConditionPatch(hGameData);

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
