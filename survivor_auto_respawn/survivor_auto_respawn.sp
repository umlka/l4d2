#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
//#include <defib_fix>

/*****************************************************************************************************/
// ====================================================================================================
// colors.inc
// ====================================================================================================
#define SERVER_INDEX	0
#define NO_INDEX	   -1
#define NO_PLAYER	   -2
#define BLUE_INDEX		2
#define RED_INDEX		3
#define MAX_COLORS		6
#define MAX_MESSAGE_LENGTH 254
static const char CTag[][] = {"{default}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}"};
static const char CTagCode[][] = {"\x01", "\x04", "\x03", "\x03", "\x03", "\x05"};
static const bool CTagReqSayText2[] = {false, false, true, true, true, false};
static const int CProfile_TeamIndex[] = {NO_INDEX, NO_INDEX, SERVER_INDEX, RED_INDEX, BLUE_INDEX, NO_INDEX};

/**
 * @note Prints a message to a specific client in the chat area.
 * @note Supports color tags.
 *
 * @param client		Client index.
 * @param szMessage		Message (formatting rules).
 * @return				No return
 * 
 * On error/Errors:	If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] szMessage, any ...) {
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];

	SetGlobalTransTarget(client);
	FormatEx(szBuffer, sizeof szBuffer, "\x01%s", szMessage);
	VFormat(szCMessage, sizeof szCMessage, szBuffer, 3);
	
	int index = CFormat(szCMessage, sizeof szCMessage);
	if (index == NO_INDEX)
		PrintToChat(client, "%s", szCMessage);
	else
		CSayText2(client, index, szCMessage);
}

/**
 * @note Prints a message to all clients in the chat area.
 * @note Supports color tags.
 *
 * @param client		Client index.
 * @param szMessage		Message (formatting rules)
 * @return				No return
 */
stock void CPrintToChatAll(const char[] szMessage, any ...) {
	char szBuffer[MAX_MESSAGE_LENGTH];

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof szBuffer, szMessage, 2);
			CPrintToChat(i, "%s", szBuffer);
		}
	}
}

/**
 * @note Replaces color tags in a string with color codes
 *
 * @param szMessage		String.
 * @param maxlength		Maximum length of the string buffer.
 * @return				Client index that can be used for SayText2 author index
 * 
 * On error/Errors:	If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] szMessage, int maxlength) {	
	int iRandomPlayer = NO_INDEX;

	for (int i; i < MAX_COLORS; i++) {													//	Para otras etiquetas de color se requiere un bucle.
		if (StrContains(szMessage, CTag[i], false) == -1)								//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if (!CTagReqSayText2[i])
			ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);			//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else {																			//	La etiqueta necesita Saytext2.	
			if (iRandomPlayer == NO_INDEX) {											//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]);			//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if (iRandomPlayer == NO_PLAYER)
					ReplaceString(szMessage, maxlength, CTag[i], CTagCode[5], false);	//	Si no se encuentra un cliente valido, reemplasa la etiqueta con una etiqueta de color verde.
				else 
					ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);	// 	Si el cliente fue encontrado simplemente reemplasa.
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
stock int CFindRandomPlayerByTeam(int color_team) {
	if (color_team == SERVER_INDEX)
		return 0;
	else {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && GetClientTeam(i) == color_team)
				return i;
		}
	}

	return NO_PLAYER;
}

/**
 * @note Sends a SayText2 usermessage to a client
 *
 * @param szMessage		Client index
 * @param maxlength		Author index
 * @param szMessage		Message
 * @return				No return.
 */
stock void CSayText2(int client, int author, const char[] szMessage) {
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	bf.WriteByte(author);
	bf.WriteByte(true);
	bf.WriteString(szMessage);
	EndMessage();
}
/*****************************************************************************************************/
#define PLUGIN_NAME				"Survivor Auto Respawn"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"自动复活"
#define PLUGIN_VERSION			"1.4.1"
#define PLUGIN_URL				"https://steamcommunity.com/id/sorallll"

#define GAMEDATA				"survivor_auto_respawn"
#define CVAR_FLAGS				FCVAR_NOTIFY
#define MAX_SLOTS				5

Handle
	g_hSDK_CTerrorPlayer_RoundRespawn;

ArrayList
	g_aMeleeScripts;

Address
	g_pStatsCondition;

ConVar
	g_cvRespawnTime,
	g_cvRespawnLimit,
	g_cvRespawnBot,
	g_cvRespawnIdle,
	g_cvRespawnGoAFK,
	g_cvPunishType,
	g_cvPunishTime,
	g_cvPunishBot,
	g_cvBotSpawned,
	g_cvGiveType,
	g_cvSbAllBotGame,
	g_cvAllowAllBotSur;

bool
	g_bDisabled,
	g_bRespawnBot,
	g_bRespawnIdle,
	g_bRespawnGoAFK,
	g_bPunishType,
	g_bPunishBot,
	g_bBotSpawned,
	g_bGiveType,
	g_bRemoveDeathModel;

int
	g_iRespawnTime,
	g_iRespawnLimit,
	g_iPunishTime,
	g_iMaxRespawned;

float
	g_fCmdCooldown[MAXPLAYERS + 1];

enum struct Weapon {
	ConVar cvFlags;

	int count;
	int allowed[20];
}

Weapon
	g_Weapon[MAX_SLOTS];

enum struct Player {
	Handle timer;

	int respawned;
	int countdown;
}

Player
	g_Player[MAXPLAYERS + 1];

static const char
	g_sWeaponName[MAX_SLOTS][17][] = {
		{//slot 0(主武器)
			"weapon_smg",						//1 UZI微冲
			"weapon_smg_mp5",					//2 MP5
			"weapon_smg_silenced",				//4 MAC微冲
			"weapon_pumpshotgun",				//8 木喷
			"weapon_shotgun_chrome",			//16 铁喷
			"weapon_rifle",						//32 M16步枪
			"weapon_rifle_desert",				//64 三连步枪
			"weapon_rifle_ak47",				//128 AK47
			"weapon_rifle_sg552",				//256 SG552
			"weapon_autoshotgun",				//512 一代连喷
			"weapon_shotgun_spas",				//1024 二代连喷
			"weapon_hunting_rifle",				//2048 木狙
			"weapon_sniper_military",			//4096 军狙
			"weapon_sniper_scout",				//8192 鸟狙
			"weapon_sniper_awp",				//16384 AWP
			"weapon_rifle_m60",					//32768 M60
			"weapon_grenade_launcher"			//65536 榴弹发射器
		},
		{//slot 1(副武器)
			"weapon_pistol",					//1 小手枪
			"weapon_pistol_magnum",				//2 马格南
			"weapon_chainsaw",					//4 电锯
			"fireaxe",							//8 斧头
			"frying_pan",						//16 平底锅
			"machete",							//32 砍刀
			"baseball_bat",						//64 棒球棒
			"crowbar",							//128 撬棍
			"cricket_bat",						//256 球拍
			"tonfa",							//512 警棍
			"katana",							//1024 武士刀
			"electric_guitar",					//2048 电吉他
			"knife",							//4096 小刀
			"golfclub",							//8192 高尔夫球棍
			"shovel",							//16384 铁铲
			"pitchfork",						//32768 草叉
			"riotshield",						//65536 盾牌
		},
		{//slot 2(投掷物)
			"weapon_molotov",					//1 燃烧瓶
			"weapon_pipe_bomb",					//2 管制炸弹
			"weapon_vomitjar",					//4 胆汁瓶
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
			"weapon_first_aid_kit",				//1 医疗包
			"weapon_defibrillator",				//2 电击器
			"weapon_upgradepack_incendiary",	//4 燃烧弹药包
			"weapon_upgradepack_explosive",		//8 高爆弹药包
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
			"weapon_pain_pills",				//1 止痛药
			"weapon_adrenaline",				//2 肾上腺素
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
	g_sWeaponModels[][] = {
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

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

native bool L4D2_RemovePlayerDeathModel(int client);
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	MarkNativeAsOptional("L4D2_RemovePlayerDeathModel");
	return APLRes_Success;
}

public void OnPluginStart() {
	InitData();
	g_aMeleeScripts = new ArrayList(ByteCountToCells(64));
	CreateConVar("survivor_auto_respawn_version", PLUGIN_VERSION, "Survivor Auto Respawn plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvRespawnTime =		CreateConVar("sar_respawn_time",	"15",		"玩家自动复活时间(秒).", CVAR_FLAGS);
	g_cvRespawnLimit =		CreateConVar("sar_respawn_limit",	"5",		"玩家每回合自动复活次数.", CVAR_FLAGS);
	g_cvRespawnBot =		CreateConVar("sar_respawn_bot",		"1",		"是否允许Bot自动复活 \n0=否,1=是.", CVAR_FLAGS);
	g_cvRespawnIdle =		CreateConVar("sar_respawn_idle",	"1",		"是否允许闲置玩家自动复活 \n0=否,1=是.", CVAR_FLAGS);
	g_cvRespawnGoAFK =		CreateConVar("sar_respawn_goafk",	"1",		"玩家被复活后是否立即闲置 \n0=否,1=是.", CVAR_FLAGS);
	g_cvPunishType =		CreateConVar("sar_punish_type",		"1",		"玩家复活惩罚类型 \n0=每个人单独计算,1=按本回合内最高已复活次数计算.", CVAR_FLAGS);
	g_cvPunishTime =		CreateConVar("sar_punish_time",		"5",		"每次复活一次的惩罚时间 \n0=不惩罚.", CVAR_FLAGS);
	g_cvPunishBot =			CreateConVar("sar_punish_bot",		"0",		"是否对Bot进行复活惩罚 \n0=否,1=是.", CVAR_FLAGS);
	g_cvBotSpawned =		CreateConVar("sar_bot_spawned",		"0",		"是否将Bot的复活次数计入最高已复活次数 \n0=否,1=是.", CVAR_FLAGS);
	g_cvGiveType =			CreateConVar("sar_give_type",		"0",		"根据什么来给玩家装备. \n0=不给,1=根据每个槽位的设置,2=根据当前所有生还者的平均装备质量(仅主副武器).");
	g_Weapon[0].cvFlags =	CreateConVar("sar_respawn_slot0",	"131071",	"主武器给什么 \n0=不给,131071=所有,7=微冲,1560=霰弹,30720=狙击,31=Tier1,32736=Tier2,98304=Tier0.");
	g_Weapon[1].cvFlags =	CreateConVar("sar_respawn_slot1",	"5160",		"副武器给什么 \n0=不给,131071=所有.如果选中了近战且该近战在当前地图上未解锁,则会随机给一把.");
	g_Weapon[2].cvFlags =	CreateConVar("sar_respawn_slot2",	"7",		"投掷物给什么 \n0=不给,7=所有.", CVAR_FLAGS);
	g_Weapon[3].cvFlags =	CreateConVar("sar_respawn_slot3",	"1",		"槽位3给什么 \n0=不给,15=所有.", CVAR_FLAGS);
	g_Weapon[4].cvFlags =	CreateConVar("sar_respawn_slot4",	"3",		"槽位4给什么 \n0=不给,3=所有.", CVAR_FLAGS);

	g_cvSbAllBotGame = FindConVar("sb_all_bot_game");
	g_cvAllowAllBotSur = FindConVar("allow_all_bot_survivor_team");

	g_cvRespawnTime.AddChangeHook(CvarChanged);
	g_cvRespawnLimit.AddChangeHook(CvarChanged);
	g_cvRespawnBot.AddChangeHook(CvarChanged);
	g_cvRespawnIdle.AddChangeHook(CvarChanged);
	g_cvRespawnGoAFK.AddChangeHook(CvarChanged);
	g_cvPunishType.AddChangeHook(CvarChanged);
	g_cvPunishTime.AddChangeHook(CvarChanged);
	g_cvPunishBot.AddChangeHook(CvarChanged);
	g_cvBotSpawned.AddChangeHook(CvarChanged);

	for (int i; i < MAX_SLOTS; i++)
		g_Weapon[i].cvFlags.AddChangeHook(CvarChanged_Weapon);
		
	AutoExecConfig(true);

	RegConsoleCmd("sm_respawn", cmdRespawn, "复活");
}

public void OnPluginEnd() {
	StatsConditionPatch(false);
}

public void OnAllPluginsLoaded() {
	g_bRemoveDeathModel = GetFeatureStatus(FeatureType_Native, "L4D2_RemovePlayerDeathModel") == FeatureStatus_Available;
}

Action Listener_SpecNext(int client, char[] command, int argc) {
	if (g_bDisabled)
		return Plugin_Continue;

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (GetClientTeam(client) != 2 || IsPlayerAlive(client) || g_Player[client].timer)
		return Plugin_Continue;

	float time = GetEngineTime();
	if (g_fCmdCooldown[client] > time)
		return Plugin_Continue;

	g_fCmdCooldown[client] = time + 30.0;

	PrintHintText(client, "聊天栏输入 !respawn 进行复活");
	PrintToChat(client, "\x01聊天栏输入 \x05!respawn \x01进行复活.");
	return Plugin_Continue;
}

Action cmdRespawn(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (g_bDisabled) {
		PrintToChat(client, "请等待回合开始后再尝试.");
		return Plugin_Handled;
	}

	if (!g_iRespawnTime || !g_iRespawnLimit) {
		PrintToChat(client, "复活功能已禁用.");
		return Plugin_Handled;
	}

	if (g_Player[client].timer) {
		PrintToChat(client, "复活倒计时已在运行中");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != 2 || IsPlayerAlive(client)) {
		PrintToChat(client, "只有死亡的生还者才能使用该指令");
		return Plugin_Handled;
	}

	if (CalculateRespawnLimit(client)) {
		delete g_Player[client].timer;
		g_Player[client].timer = CreateTimer(1.0, tmrRespawnSurvivor, GetClientUserId(client), TIMER_REPEAT);
	}

	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	GetCvars();
	GetCvars_Weapon();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void CvarChanged_Weapon(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Weapon();
}

void GetCvars() {
	g_iRespawnTime = g_cvRespawnTime.IntValue;
	g_iRespawnLimit = g_cvRespawnLimit.IntValue;
	g_iPunishTime = g_cvPunishTime.IntValue;
	Toggle(g_iRespawnTime && g_iRespawnLimit);
	g_bRespawnBot = g_cvRespawnBot.BoolValue;
	g_bRespawnIdle = g_cvRespawnIdle.BoolValue;
	g_bRespawnGoAFK = g_cvRespawnGoAFK.BoolValue;
	g_bPunishType = g_cvPunishType.BoolValue;
	g_bPunishBot = g_cvPunishBot.BoolValue;
	g_bBotSpawned = g_cvBotSpawned.BoolValue;
}

void Toggle(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;

		HookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("map_transition",			Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("finale_vehicle_leaving",	Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("player_spawn",			Event_PlayerSpawn);
		HookEvent("player_death",			Event_PlayerDeath,	EventHookMode_Pre);
		HookEvent("player_bot_replace",		Event_PlayerBotReplace);
		HookEvent("bot_player_replace",		Event_BotPlayerReplace);

		AddCommandListener(Listener_SpecNext, "spec_next");

	}
	else if (enabled && !enable) {
		enabled = false;
		
		UnhookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("map_transition",			Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("finale_vehicle_leaving",	Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("round_start",				Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",				Event_PlayerSpawn);
		UnhookEvent("player_death",				Event_PlayerDeath,	EventHookMode_Pre);
		UnhookEvent("player_bot_replace",		Event_PlayerBotReplace);
		UnhookEvent("bot_player_replace",		Event_BotPlayerReplace);

		RemoveCommandListener(Listener_SpecNext, "spec_next");

		for (int i = 1; i <= MaxClients; i++) {
			g_Player[i].respawned = 0;
			delete g_Player[i].timer;
		}
	}
}

void GetCvars_Weapon() {
	int count;
	for (int i; i < MAX_SLOTS; i++) {
		g_Weapon[i].count = 0;
		if (!g_Weapon[i].cvFlags.BoolValue || !IsNullSlot(i))
			count++;
	}

	g_bGiveType = count < MAX_SLOTS ? g_cvGiveType.BoolValue : false;
}

bool IsNullSlot(int slot) {
	for (int i; i < sizeof g_sWeaponName[]; i++) {
		if (g_sWeaponName[slot][i][0] == '\0')
			break;

		if ((1 << i) & g_Weapon[slot].cvFlags.IntValue)
			g_Weapon[slot].allowed[g_Weapon[slot].count++] = i;
	}
	return g_Weapon[slot].count > 0;
}

public void OnClientDisconnect_Post(int client) {
	delete g_Player[client].timer;
	g_Player[client].respawned = 0;
	RemoveSurDeathModel(client);
}

public void OnMapEnd() {
	g_iMaxRespawned = 0;
	for (int i = 1; i <= MaxClients; i++) {
		delete g_Player[i].timer;
		g_Player[i].respawned = 0;
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_bDisabled = true;
	g_iMaxRespawned = 0;
	for (int i = 1; i <= MaxClients; i++) {
		delete g_Player[i].timer;
		g_Player[i].respawned = 0;
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bDisabled = false;
	for (int i = 1; i <= MaxClients; i++)
		delete g_Player[i].timer;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	if (IsPlayerAlive(client)) {
		RemoveSurDeathModel(client);
		return;
	}

	if (g_Player[client].timer || GetClientTeam(client) != 2)
		return;

	bool isBot = IsFakeClient(client);
	if ((!g_bRespawnBot && isBot))
		return;

	if (!g_bRespawnIdle && !isBot && GetBotOfIdlePlayer(client))
		return;

	if (CalculateRespawnLimit(client)) {
		delete g_Player[client].timer;
		g_Player[client].timer = CreateTimer(1.0, tmrRespawnSurvivor, event.GetInt("userid"), TIMER_REPEAT);
	}
}

int GetBotOfIdlePlayer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
	return client && IsClientInGame(client);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || g_Player[client].timer || !IsClientInGame(client) || (!g_bRespawnBot && IsFakeClient(client)) || GetClientTeam(client) != 2)
		return;

	if (CalculateRespawnLimit(client)) {
		delete g_Player[client].timer;
		g_Player[client].timer = CreateTimer(1.0, tmrRespawnSurvivor, event.GetInt("userid"), TIMER_REPEAT);
	}
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || g_Player[bot].timer || !IsClientInGame(bot) || (!g_bRespawnBot && IsFakeClient(bot)) || GetClientTeam(bot) != 2 || IsPlayerAlive(bot))
		return;

	if (CalculateRespawnLimit(bot)) {
		delete g_Player[bot].timer;
		g_Player[bot].timer = CreateTimer(1.0, tmrRespawnSurvivor, event.GetInt("bot"), TIMER_REPEAT);
	}
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bRespawnIdle)
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || g_Player[player].timer || !IsClientInGame(player) || GetClientTeam(player) != 2 || IsPlayerAlive(player))
		return;

	if (CalculateRespawnLimit(player)) {
		delete g_Player[player].timer;
		g_Player[player].timer = CreateTimer(1.0, tmrRespawnSurvivor, event.GetInt("player"), TIMER_REPEAT);
	}
}

bool CalculateRespawnLimit(int client) {
	if (g_bDisabled)
		return false;

	bool isBot = IsFakeClient(client);
	if (g_Player[client].respawned >= g_iRespawnLimit) {
		if (!isBot)
			PrintHintText(client, "复活次数已耗尽, 请等待队友救援");

		return false;
	}

	g_Player[client].countdown = g_iRespawnTime + ((!g_bPunishBot && isBot) ? 0 : g_iPunishTime * (g_bPunishType ? g_iMaxRespawned : g_Player[client].respawned));
	return true;
}

Action tmrRespawnSurvivor(Handle timer, int client) {
	if (!(client = GetClientOfUserId(client)))
		return Plugin_Stop;

	if (IsClientInGame(client) && GetClientTeam(client) == 2 && !IsPlayerAlive(client)) {
		if (g_Player[client].countdown > 0) {
			if (!IsFakeClient(client))
				PrintCenterText(client, "%d 秒后复活", g_Player[client].countdown);

			g_Player[client].countdown--;
		}
		else {
			RespawnSurvivor(client);
			g_Player[client].timer = null;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	g_Player[client].timer = null;
	return Plugin_Stop;	
}

void RespawnSurvivor(int client) {
	RoundRespawn(client);
	GiveWeapon(client);
	TeleportToSurvivor(client);
	g_Player[client].respawned++;

	bool isBot = IsFakeClient(client);
	if ((!isBot || g_bBotSpawned) && g_Player[client].respawned > g_iMaxRespawned)
		g_iMaxRespawned = g_Player[client].respawned;

	if (!isBot) {
		if (g_bRespawnGoAFK && CanIdle(client))
			GoAFKTimer(client, 0.1);

		CPrintToChat(client, "{olive}剩余复活次数 {default}-> {blue}%d", g_iRespawnLimit - g_Player[client].respawned);
	}
}

bool CanIdle(int client) {
	if (g_cvSbAllBotGame.BoolValue || g_cvAllowAllBotSur.BoolValue)
		return true;

	int player;
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			player++;
	}
	return player > 0;
}

void RemoveSurDeathModel(int client) {
	if (g_bRemoveDeathModel)
		L4D2_RemovePlayerDeathModel(client);
}

void GiveWeapon(int client) {
	if (!g_bGiveType)
		return;

	RemoveAllWeapons(client);

	for (int i = 4; i >= 2; i--) {
		if (!g_Weapon[i].count)
			continue;

		GivePlayerItem(client, g_sWeaponName[i][g_Weapon[i].allowed[GetRandomInt(0, g_Weapon[i].count - 1)]]);
	}

	GiveSecondary(client);

	switch(g_cvGiveType.IntValue) {
		case 1:
			GivePresetPrimary(client);
		
		case 2:
			GiveAveragePrimary(client);
	}
}

void RemoveAllWeapons(int client) {
	int weapon;
	for (int i; i < MAX_SLOTS; i++) {
		if ((weapon = GetPlayerWeaponSlot(client, i)) > MaxClients) {
			RemovePlayerItem(client, weapon);
			RemoveEntity(weapon);
		}
	}
}

void GiveSecondary(int client) {
	if (g_Weapon[1].count) {
		int iRandom = g_Weapon[1].allowed[GetRandomInt(0, g_Weapon[1].count - 1)];
		if (iRandom > 2)
			GiveMelee(client, g_sWeaponName[1][iRandom]);
		else
			GivePlayerItem(client, g_sWeaponName[1][iRandom]);
	}
}

void GivePresetPrimary(int client) {
	if (g_Weapon[0].count)
		GivePlayerItem(client, g_sWeaponName[0][g_Weapon[0].allowed[GetRandomInt(0, g_Weapon[0].count - 1)]]);
}

bool IsWeaponTier1(int weapon) {
	char cls[32];
	GetEntityClassname(weapon, cls, sizeof cls);
	for (int i; i < 5; i++) {
		if (strcmp(cls, g_sWeaponName[0][i], false) == 0)
			return true;
	}
	return false;
}

void GiveAveragePrimary(int client) {
	int i = 1, weapon, tier, total;
	for (; i <= MaxClients; i++) {
		if (i == client || !IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;

		total += 1;	
		weapon = GetPlayerWeaponSlot(i, 0);
		if (weapon <= MaxClients || !IsValidEntity(weapon))
			continue;

		tier += IsWeaponTier1(weapon) ? 1 : 2;
	}

	switch(total > 0 ? RoundToNearest(1.0 * tier / total) : 0) {
		case 1:
			GivePlayerItem(client, g_sWeaponName[0][GetRandomInt(0, 4)]); // 随机给一把tier1武器

		case 2:
			GivePlayerItem(client, g_sWeaponName[0][GetRandomInt(5, 14)]); // 随机给一把tier2武器	
	}
}

void TeleportToSurvivor(int client) {
	int target = 1;
	ArrayList aClients = new ArrayList(2);

	for (; target <= MaxClients; target++) {
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target))
			continue;
	
		aClients.Set(aClients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!aClients.Length)
		target = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		target = aClients.Length - 1;
		target = aClients.Get(GetRandomInt(aClients.FindValue(aClients.Get(target, 0)), target), 1);
	}

	delete aClients;

	if (target) {
		SetInvincibilityTime(client, 1.5);
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags")|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

//给玩家近战
//https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484
public void OnMapStart() {
	int i;
	for (; i < sizeof g_sWeaponModels; i++) {
		if (!IsModelPrecached(g_sWeaponModels[i]))
			PrecacheModel(g_sWeaponModels[i], true);
	}

	char buffer[64];
	for (i = 3; i < sizeof g_sWeaponName[]; i++) {
		FormatEx(buffer, sizeof buffer, "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		if (!IsGenericPrecached(buffer))
			PrecacheGeneric(buffer, true);
	}

	GetMeleeStringTable();
}

void GetMeleeStringTable() {
	g_aMeleeScripts.Clear();

	int table = FindStringTable("meleeweapons");
	if (table != INVALID_STRING_TABLE) {
		int num = GetStringTableNumStrings(table);
		char meleeName[64];
		for (int i; i < num; i++) {
			ReadStringTable(table, i, meleeName, sizeof meleeName);
			g_aMeleeScripts.PushString(meleeName);
		}
	}
}

void GiveMelee(int client, const char[] meleeName) {
	char sScriptName[64];
	if (g_aMeleeScripts.FindString(meleeName) != -1)
		strcopy(sScriptName, sizeof sScriptName, meleeName);
	else
		g_aMeleeScripts.GetString(GetRandomInt(0, g_aMeleeScripts.Length - 1), sScriptName, sizeof sScriptName);
	
	GivePlayerItem(client, sScriptName);
}

void InitData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::RoundRespawn\"");
	if (!(g_hSDK_CTerrorPlayer_RoundRespawn = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::RoundRespawn\"");

	InitPatchs(hGameData);

	delete hGameData;
}

void InitPatchs(GameData hGameData = null) {
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"RoundRespawn_Offset\"");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if (iByteMatch == -1)
		SetFailState("Failed to find byte: \"RoundRespawn_Byte\"");

	g_pStatsCondition = hGameData.GetMemSig("CTerrorPlayer::RoundRespawn");
	if (!g_pStatsCondition)
		SetFailState("Failed to find address: \"CTerrorPlayer::RoundRespawn\"");
	
	g_pStatsCondition += view_as<Address>(iOffset);
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if (iByteOrigin != iByteMatch)
		SetFailState("Failed to load \"CTerrorPlayer::RoundRespawn\", byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

// [L4D1 & L4D2] SM Respawn Improved (https://forums.alliedmods.net/showthread.php?t=323220)
void StatsConditionPatch(bool patch) {
	static bool patched;
	if (!patched && patch) {
		patched = true;
		StoreToAddress(g_pStatsCondition, 0xEB, NumberType_Int8);
	}
	else if (patched && !patch) {
		patched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

void RoundRespawn(int client) {
	StatsConditionPatch(true);
	SDKCall(g_hSDK_CTerrorPlayer_RoundRespawn, client);
	StatsConditionPatch(false);
}

void GoAFKTimer(int client, float flDuration) {
	static int m_GoAFKTimer = -1;
	if (m_GoAFKTimer == -1)
		m_GoAFKTimer = FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") - 12;

	SetEntDataFloat(client, m_GoAFKTimer + 4, flDuration);
	SetEntDataFloat(client, m_GoAFKTimer + 8, GetGameTime() + flDuration);
}

void SetInvincibilityTime(int client, float flDuration) {
	static int m_invulnerabilityTimer = -1;
	if (m_invulnerabilityTimer == -1)
		m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;

	SetEntDataFloat(client, m_invulnerabilityTimer + 4, flDuration);
	SetEntDataFloat(client, m_invulnerabilityTimer + 8, GetGameTime() + flDuration);
}
