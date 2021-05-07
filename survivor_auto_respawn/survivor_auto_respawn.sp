#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>
/**************************************************************************/
//颜色
#define MAX_COLORS 	 6
#define SERVER_INDEX 0
#define NO_INDEX 	-1
#define NO_PLAYER 	-2
#define BLUE_INDEX 	 2
#define RED_INDEX 	 3
static const char CTag[][] = { "{default}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}" };
static const char CTagCode[][] = { "\x01", "\x04", "\x03", "\x03", "\x03", "\x05" };
static const bool CTagReqSayText2[] = { false, false, true, true, true, false };
static const int CProfile_TeamIndex[] = { NO_INDEX, NO_INDEX, SERVER_INDEX, RED_INDEX, BLUE_INDEX, NO_INDEX };

/**
 * @note Prints a message to a specific client in the chat area.
 * @note Supports color tags.
 *
 * @param client 		Client index.
 * @param sMessage 		Message (formatting rules).
 * @return 				No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] sMessage, any ...)
{
	if(client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if(!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	static char sBuffer[250];
	static char sCMessage[250];
	SetGlobalTransTarget(client);
	Format(sBuffer, sizeof(sBuffer), "\x01%s", sMessage);
	VFormat(sCMessage, sizeof(sCMessage), sBuffer, 3);
	
	int index = CFormat(sCMessage, sizeof(sCMessage));
	if(index == NO_INDEX)
		PrintToChat(client, sCMessage);
	else
		CSayText2(client, index, sCMessage);
}

/**
 * @note Prints a message to all clients in the chat area.
 * @note Supports color tags.
 *
 * @param client		Client index.
 * @param sMessage 		Message (formatting rules)
 * @return 				No return
 */
stock void CPrintToChatAll(const char[] sMessage, any ...)
{
	static char sBuffer[250];

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(sBuffer, sizeof(sBuffer), sMessage, 2);
			CPrintToChat(i, sBuffer);
		}
	}
}

/**
 * @note Replaces color tags in a string with color codes
 *
 * @param sMessage    String.
 * @param maxlength   Maximum length of the string buffer.
 * @return			  Client index that can be used for SayText2 author index
 * 
 * On error/Errors:   If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] sMessage, int maxlength)
{	
	int iRandomPlayer = NO_INDEX;
	
	for(int i; i < MAX_COLORS; i++)													//	Para otras etiquetas de color se requiere un bucle.
	{
		if(StrContains(sMessage, CTag[i]) == -1) 										//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if(!CTagReqSayText2[i])
			ReplaceString(sMessage, maxlength, CTag[i], CTagCode[i]); 					//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else																				//	La etiqueta necesita Saytext2.
		{	
			if(iRandomPlayer == NO_INDEX)												//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
			{
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]); 			//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if(iRandomPlayer == NO_PLAYER) 
					ReplaceString(sMessage, maxlength, CTag[i], CTagCode[5]); 			//	Si no se encuentra un cliente valido, reemplasa la etiqueta con una etiqueta de color verde.
				else 
					ReplaceString(sMessage, maxlength, CTag[i], CTagCode[i]); 			// 	Si el cliente fue encontrado simplemente reemplasa.
			}
			else 																			//	Si en caso de usar dos colores de equipo infectado y equipo de superviviente juntos se mandará un mensaje de error.
				ThrowError("Using two team colors in one message is not allowed"); 			//	Si se ha usadó una combinación de colores no validad se registrara en la carpeta logs.
		}
	}

	return iRandomPlayer;
}

/**
 * @note Founds a random player with specified team
 *
 * @param color_team  Client team.
 * @return			  Client index or NO_PLAYER if no player found
 */
stock int CFindRandomPlayerByTeam(int color_team)
{
	if(color_team == SERVER_INDEX)
		return 0;
	else
	{
		for(int i = 1; i <= MaxClients; i ++)
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
 * @param sMessage 		Client index
 * @param maxlength 	Author index
 * @param sMessage 		Message
 * @return 				No return.
 */
stock void CSayText2(int client, int author, const char[] sMessage)
{
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client));
	bf.WriteByte(author);
	bf.WriteByte(true);
	bf.WriteString(sMessage);
	EndMessage();
}
/**************************************************************************/

#define GAMEDATA 		"survivor_auto_respawn"
#define CVAR_FLAGS 		FCVAR_NOTIFY

Handle g_hSDK_Call_RoundRespawn;
//Handle g_hSDK_Call_GoAwayFromKeyboard;

Handle g_hRespawnTimer[MAXPLAYERS + 1];

Address g_pRespawn;
Address g_pResetStatCondition;

//DynamicDetour g_dDetour;

ConVar g_hRespawnTime;
ConVar g_hRespawnLimit;
ConVar g_hAllowSurvivorBot;
ConVar g_hAllowSurvivorIdle;
ConVar g_hGiveType;
ConVar g_hSlotFlags[5];
//ConVar g_hSbAllBotGame; 
//ConVar g_hAllowAllBotSurvivorTeam;

bool g_bAllowSurvivorBot;
bool g_bAllowSurvivorIdle;

int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iRespawnTime;
int g_iRespawnLimit;
int g_iSlotCount[5];
int g_iSlotWeapons[5][20];
int g_iMeleeClassCount;
int g_iDeathModel[MAXPLAYERS + 1];
int g_iPlayerRespawned[MAXPLAYERS + 1];
int g_iRespawnCountdown[MAXPLAYERS + 1];

char g_sMeleeClass[16][32];

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
	name = "Survivor Auto Respawn",
	author = "sorallll",
	description = "",
	version = "",
	url = "https://steamcommunity.com/id/sorallll"
}

public void OnPluginStart()
{
	LoadGameData();

	g_hRespawnTime = CreateConVar("sar_respawn_time", "15" , "玩家自动复活时间(秒)", CVAR_FLAGS, true, 0.0);
	g_hRespawnLimit = CreateConVar("sar_respawn_limit", "5" , "玩家每回合自动复活次数", CVAR_FLAGS, true, 0.0);
	g_hAllowSurvivorBot = CreateConVar("sar_respawn_bot", "1" , "是否允许Bot自动复活 \n0=否,1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hAllowSurvivorIdle = CreateConVar("sar_respawn_idle", "1" , "是否允许闲置玩家自动复活 \n0=否,1=是(某些多人插件闲置死亡后会接管BOT)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hGiveType = CreateConVar("sar_respawn_type", "0" , "根据什么来给玩家装备. \n0=不给,1=根据每个槽位的设置,2=根据当前所有生还者的平均装备质量(仅主副武器)", CVAR_FLAGS, true, 0.0, true, 2.0);

	g_hSlotFlags[0] = CreateConVar("sar_respawn_slot0", "131071" , "主武器给什么 \n0=不给,131071=所有,7=微冲,1560=霰弹,30720=狙击,31=Tier1,32736=Tier2,98304=Tier0", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[1] = CreateConVar("sar_respawn_slot1", "131068" , "副武器给什么 \n0=不给,131071=所有.如果选中了近战且该近战在当前地图上未解锁,则会随机给一把", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[2] = CreateConVar("sar_respawn_slot2", "7" , "投掷物给什么 \n0=不给,7=所有", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[3] = CreateConVar("sar_respawn_slot3", "15" , "槽位3给什么 \n0=不给,15=所有", CVAR_FLAGS, true, 0.0);
	g_hSlotFlags[4] = CreateConVar("sar_respawn_slot4", "3" , "槽位4给什么 \n0=不给,3=所有", CVAR_FLAGS, true, 0.0);
	
	//g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	//g_hAllowAllBotSurvivorTeam = FindConVar("allow_all_bot_survivor_team");

	g_hRespawnTime.AddChangeHook(ConVarChanged);
	g_hRespawnLimit.AddChangeHook(ConVarChanged);
	g_hAllowSurvivorBot.AddChangeHook(ConVarChanged);
	g_hAllowSurvivorIdle.AddChangeHook(ConVarChanged);

	for(int i; i < 5; i++)
		g_hSlotFlags[i].AddChangeHook(ConVarChanged_Slot);
		
	//AutoExecConfig(true, "survivor_auto_respawn");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	PatchAddress(false);
	/*if(!g_dDetour.Disable(Hook_Pre, DeathModelCreatePre) || !g_dDetour.Disable(Hook_Post, DeathModelCreatePost))
		SetFailState("Failed to disable detour: CSurvivorDeathModel::Create");*/
}

public void OnConfigsExecuted()
{
	GetCvars();
	GetSlotCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void ConVarChanged_Slot(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetSlotCvars();
}

void GetCvars()
{
	g_iRespawnTime = g_hRespawnTime.IntValue;
	g_iRespawnLimit = g_hRespawnLimit.IntValue;
	g_bAllowSurvivorBot = g_hAllowSurvivorBot.BoolValue;
	g_bAllowSurvivorIdle = g_hAllowSurvivorIdle.BoolValue;
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

public Action L4D2_OnSurvivorDeathModelCreated(int client, int iDeathModel)
{
	g_iDeathModel[client] = EntIndexToEntRef(iDeathModel);
}

public void OnClientPutInServer(int client)
{
	ResetClientData(client);
}

public void OnClientDisconnect(int client)
{
	delete g_hRespawnTimer[client];
}

public void OnMapEnd()
{
	ResetPlugin();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void ResetClientData(int client)
{
	g_iPlayerRespawned[client] = 0;
}

void InitPlugin()
{
	for(int i = 1; i <= MaxClients; i++)
		delete g_hRespawnTimer[i];
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		ResetClientData(i);
		delete g_hRespawnTimer[i];
	}
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
	if(client == 0 || !IsClientInGame(client))
		return;

	RemoveSurvivorDeathModel(client);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRespawnTime == 0 || g_iRespawnLimit == 0 || IsRoundStarted() == false)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if(IsFakeClient(client))
	{
		int iIdlePlayer = GetIdlePlayer(client);
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

	if(CalculateRespawnLimit(client))
	{
		delete g_hRespawnTimer[client];
		g_hRespawnTimer[client] = CreateTimer(1.0, Timer_Respawn, GetClientUserId(client), TIMER_REPEAT);
	}
}

int GetIdlePlayer(int client)
{
	if(HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
	{
		client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
		if(client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
			return client;
	}
	return 0;
}

bool CalculateRespawnLimit(int client)
{
	if(g_iPlayerRespawned[client] >= g_iRespawnLimit)
	{
		if(!IsFakeClient(client))
			PrintHintText(client, "复活次数已耗尽，请等待救援");

		return false;
	}

	g_iRespawnCountdown[client] = g_iRespawnTime;
	return true;
}

public Action Timer_Respawn(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) && IsClientInGame(client))
	{
		if(GetClientTeam(client) == 2 && !IsPlayerAlive(client))
		{
			if(g_iRespawnCountdown[client] > 0)
			{
				if(!IsFakeClient(client))
					PrintHintText(client, "%d 秒后复活", g_iRespawnCountdown[client]);

				g_iRespawnCountdown[client]--;
			}
			else
			{
				RespawnSurvivor(client);
				g_hRespawnTimer[client] = null;
				return Plugin_Stop;
			}

			return Plugin_Continue;
		}

		g_hRespawnTimer[client] = null;
		return Plugin_Stop;	
	}

	return Plugin_Stop;
}

void RespawnSurvivor(int client)
{
	Respawn(client);
	GiveWeapon(client);
	SetGodMode(client, 1.0);
	TeleportToSurvivor(client);
	Terror_SetAdrenalineTime(client, 15.0);
	g_iPlayerRespawned[client]++;

	if(!IsFakeClient(client))
		CPrintToChat(client, "{olive}剩余复活次数 {default}-> {blue}%d", g_iRespawnLimit - g_iPlayerRespawned[client]);
}
/*
bool CanIdle(int client)
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
*/

void RemoveSurvivorDeathModel(int client)
{
	int entity = g_iDeathModel[client];
	g_iDeathModel[client] = 0;

	if(IsValidEntRef(entity))
		RemoveEntity(entity);
}

stock bool IsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
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
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
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

//https://forums.alliedmods.net/showthread.php?t=327928
stock void Terror_SetAdrenalineTime(int client, float fDuration)
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

void GiveWeapon(int client)
{
	if(!IsPlayerAlive(client)) 
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
	for(int i = 4; i >= 0; i--)
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
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
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

	GiveSecondaryWeapon(client);
	DeletePlayerSlotX(client, 0);

	switch(iAverage)
	{
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
/*	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_GoAwayFromKeyboard = EndPrepSDKCall();
	if(g_hSDK_Call_GoAwayFromKeyboard == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::GoAwayFromKeyboard");

	SetupDetours(hGameData);*/
	
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
/*
bool GoAwayFromKeyboard(int client)
{
	return SDKCall(g_hSDK_Call_GoAwayFromKeyboard, client);
}

void SetupDetours(GameData hGameData = null)
{
	g_dDetour = DynamicDetour.FromConf(hGameData, "CSurvivorDeathModel::Create");
	if(g_dDetour == null)
		SetFailState("Failed to load signature: CSurvivorDeathModel::Create");
		
	if(!g_dDetour.Enable(Hook_Pre, DeathModelCreatePre))
		SetFailState("Failed to detour pre: CSurvivorDeathModel::Create");
		
	if(!g_dDetour.Enable(Hook_Post, DeathModelCreatePost))
		SetFailState("Failed to detour post: CSurvivorDeathModel::Create");
}

//https://github.com/LuxLuma/Left-4-fix/tree/master/left%204%20fix/Defib_Fix
int g_iTempClient;
public MRESReturn DeathModelCreatePre(int pThis)
{
	g_iTempClient = pThis;
}

public MRESReturn DeathModelCreatePost(int pThis, DHookReturn hReturn)
{
	int iDeathModel = hReturn.Value;
	if(iDeathModel == 0)
		return MRES_Ignored;

	g_iDeathModel[g_iTempClient] = EntIndexToEntRef(iDeathModel);
	return MRES_Ignored;
}*/
