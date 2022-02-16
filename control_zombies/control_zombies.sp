#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

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
#define MAX_MESSAGE_LENGTH 254
static const char CTag[][] = {"{default}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}"};
static const char CTagCode[][] = {"\x01", "\x04", "\x03", "\x03", "\x03", "\x05"};
static const bool CTagReqSayText2[] = {false, false, true, true, true, false};
static const int CProfile_TeamIndex[] = {NO_INDEX, NO_INDEX, SERVER_INDEX, RED_INDEX, BLUE_INDEX, NO_INDEX};

/**
 * @note Prints a message to a specific client in the chat area.
 * @note Supports color tags.
 *
 * @param client	Client index.
 * @param szMessage	Message (formatting rules).
 * @return			No return
 * 
 * On error/Errors:	If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] szMessage, any ...)
{
	if(client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if(!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];

	SetGlobalTransTarget(client);
	FormatEx(szBuffer, sizeof szBuffer, "\x01%s", szMessage);
	VFormat(szCMessage, sizeof szCMessage, szBuffer, 3);
	
	int index = CFormat(szCMessage, sizeof szCMessage);
	if(index == NO_INDEX)
		PrintToChat(client, "%s", szCMessage);
	else
		CSayText2(client, index, szCMessage);
}

/**
 * @note Prints a message to all clients in the chat area.
 * @note Supports color tags.
 *
 * @param client	Client index.
 * @param szMessage	Message (formatting rules)
 * @return			No return
 */
stock void CPrintToChatAll(const char[] szMessage, any ...)
{
	char szBuffer[MAX_MESSAGE_LENGTH];

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof szBuffer, szMessage, 2);
			CPrintToChat(i, "%s", szBuffer);
		}
	}
}

/**
 * @note Replaces color tags in a string with color codes
 *
 * @param szMessage	String.
 * @param maxlength	Maximum length of the string buffer.
 * @return			Client index that can be used for SayText2 author index
 * 
 * On error/Errors:	If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] szMessage, int maxlength)
{	
	int iRandomPlayer = NO_INDEX;
	
	for(int i; i < MAX_COLORS; i++)														//	Para otras etiquetas de color se requiere un bucle.
	{
		if(StrContains(szMessage, CTag[i], false) == -1)								//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if(!CTagReqSayText2[i])
			ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);			//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else																			//	La etiqueta necesita Saytext2.
		{	
			if(iRandomPlayer == NO_INDEX)												//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
			{
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]);			//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if(iRandomPlayer == NO_PLAYER)
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
 * @param szMessage	Client index
 * @param maxlength	Author index
 * @param szMessage	Message
 * @return			No return.
 */
stock void CSayText2(int client, int author, const char[] szMessage)
{
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	bf.WriteByte(author);
	bf.WriteByte(true);
	bf.WriteString(szMessage);
	EndMessage();
}
/*****************************************************************************************************/

#define DEBUG				0
#define BENCHMARK			0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#define GAMEDATA 			"control_zombies"
#define CVAR_FLAGS 			FCVAR_NOTIFY
#define SOUND_CLASSMENU		"ui/helpful_event_1.wav"

#define COLOR_NORMAL		0
#define COLOR_INCAPA		1
#define COLOR_BLACKW		2
#define COLOR_VOMITED		3

#define SI_SMOKER			0
#define SI_BOOMER			1
#define SI_HUNTER			2
#define SI_SPITTER			3
#define SI_JOCKEY			4
#define SI_CHARGER			5

esData
	g_esData[MAXPLAYERS + 1];

Handle
	g_hTimer,
	g_hSDKOnRevived,
	g_hSDKIsInStasis,
	g_hSDKLeaveStasis,
	g_hSDKState_Transition,
	g_hSDKMaterializeFromGhost,
	g_hSDKSetClass,
	g_hSDKCreateForPlayer,
	g_hSDKCleanupPlayerState,
	g_hSDKTakeOverZombieBot,
	g_hSDKReplaceWithBot,
	g_hSDKSetPreSpawnClass,
	g_hSDKRoundRespawn,
	g_hSDKSetHumanSpectator,
	g_hSDKTakeOverBot,
	g_hSDKHasPlayerControlledZombies;

Address
	g_pStatsCondition;

DynamicDetour
	g_dOnEnterGhostState,
	g_dMaterializeFromGhost,
	g_dPlayerZombieAbortControl,
	g_dSpawnablePZScanProtect[3];

ConVar
	g_hGameMode,
	g_hMaxTankPlayer,
	g_hSurvuivorLimit,
	g_hSurvuivorChance,
	g_hSbAllBotGame,
	g_hAllowAllBotSur,
	g_hSurvivorMaxInc,
	g_hExchangeTeam,
	g_hPZSuicideTime,
	g_hPZRespawnTime,
	g_hPZPunishTime,
	g_hPZPunishHealth,
	g_hAutoDisplayMenu,
	g_hPZTeamLimit,
	g_hCmdCooldownTime,
	g_hCmdEnterCooling,
	g_hPZChangeTeamTo,
	g_hGlowColorEnable,
	g_hGlowColor[4],
	g_hUserFlagBits,
	g_hImmunityLevels,
	g_hSILimit,
	g_hSpawnLimits[6],
	g_hSpawnWeights[6],
	g_hScaleWeights;

static const char
	g_sZombieClass[6][] =
	{
		"smoker",
		"boomer",
		"hunter",
		"spitter",
		"jockey", 
		"charger"
	};

char
	g_sGameMode[32];

bool
	g_bLateLoad,
	g_bIsLinuxOS,
	g_bSbAllBotGame,
	g_bAllowAllBotSur,
	g_bExchangeTeam,
	g_bGlowColorEnable,
	g_bPZPunishHealth,
	g_bScaleWeights,
	g_bOnMaterializeFromGhost,
	g_bIsSpawnablePZSupported,
	g_bHasAnySurvivorLeftSafeArea;

int
	g_iControlled = -1,
	g_iSILimit,
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iSpawnablePZ,
	g_iOffMelee,
	g_iOffHangingPreTemp,
	g_iOffHangingPreReal,
	g_iOffHangingCurrent,
	g_iSurvivorMaxInc,
	g_iSurvuivorLimit,
	g_iMaxTankPlayer,
	g_iPZRespawnTime,
	g_iPZSuicideTime,
	g_iPZPunishTime,
	g_iPZTeamLimit,
	g_iPZChangeTeamTo,
	g_iAutoDisplayMenu,
	g_iCmdEnterCooling,
	g_iGlowColor[4],
	g_iSpawnLimits[6],
	g_iSpawnWeights[6],
	g_iUserFlagBits[6],
	g_iImmunityLevels[6];

float
	g_fSurvuivorChance,
	g_fMapStartTime,
	g_fCmdCooldownTime;

enum struct esPlayer
{
	char sSteamID[32];

	bool bIsPlayerPB;
	bool bClassCmdUsed;

	int iTankBot;
	int iPlayerBot;
	int iBotPlayer;
	int iLastTeamID;
	int iModelIndex;
	int iModelEntRef;
	int iMaterialized;
	int iEnteredGhost;
	int iCurrentPZRespawnTime;

	float fCmdLastUsedTime;
	float fBugExploitTime[2];
	float fRespawnStartTime;
	float fSuicideStartTime;
}

esPlayer
	g_esPlayer[MAXPLAYERS + 1];

// 如果签名失效，请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo = 
{
	name = "Control Zombies In Co-op",
	author = "sorallll",
	description = "",
	version = "3.3.4",
	url = "https://steamcommunity.com/id/sorallll"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CZ_RespawnPZ", aNative_RespawnPZ);
	CreateNative("CZ_SetSpawnablePZ", aNative_SetSpawnablePZ);
	CreateNative("CZ_ResetSpawnablePZ", aNative_ResetSpawnablePZ);
	CreateNative("CZ_IsSpawnablePZSupported", aNative_IsSpawnablePZSupported);

	RegPluginLibrary("control_zombies");

	g_bLateLoad = late;
	return APLRes_Success;
}

any aNative_RespawnPZ(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 3 || IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return false;

	int iZombieClass = GetNativeCell(2);
	if(iZombieClass < 1 || iZombieClass > 8 || iZombieClass == 7)
		return false;

	return bRespawnPZ(client, iZombieClass);
}

any aNative_SetSpawnablePZ(Handle plugin, int numParams)
{
	g_iSpawnablePZ = GetNativeCell(1);
	return 0;
}

any aNative_ResetSpawnablePZ(Handle plugin, int numParams)
{
	g_iSpawnablePZ = 0;
	return 0;
}

any aNative_IsSpawnablePZSupported(Handle plugin, int numParams)
{
	return g_bIsSpawnablePZSupported;
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hMaxTankPlayer = 				CreateConVar("cz_max_tank_player", 					"1", 					"坦克玩家达到多少后插件将不再控制玩家接管(0=不接管坦克)", CVAR_FLAGS, true, 0.0);
	g_hSurvuivorLimit = 			CreateConVar("cz_allow_survivor_limit", 			"1", 					"至少有多少名正常生还者(未被控,未倒地,未死亡)时,才允许玩家接管坦克", CVAR_FLAGS, true, 0.0);
	g_hSurvuivorChance = 			CreateConVar("cz_survivor_allow_chance", 			"0.0", 					"准备叛变的玩家数量为0时,自动抽取生还者和感染者玩家的几率(排除闲置旁观玩家)(0.0=不自动抽取)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hExchangeTeam = 				CreateConVar("cz_exchange_team", 					"0", 					"特感玩家杀死生还者玩家后是否互换队伍?(0=否,1=是)", CVAR_FLAGS);
	g_hPZSuicideTime = 				CreateConVar("cz_pz_suicide_time", 					"120", 					"特感玩家复活后自动处死的时间(0=不会处死复活后的特感玩家)", CVAR_FLAGS, true, 0.0);
	g_hPZRespawnTime = 				CreateConVar("cz_pz_respawn_time", 					"15", 					"特感玩家自动复活时间(0=插件不会接管特感玩家的复活)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishTime = 				CreateConVar("cz_pz_punish_time", 					"30", 					"特感玩家在ghost状态下切换特感类型后下次复活延长的时间(0=插件不会延长复活时间)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishHealth = 			CreateConVar("cz_pz_punish_health", 				"1", 					"特感玩家在ghost状态下切换特感类型后血量是否减半(0=插件不会减半血量)", CVAR_FLAGS);
	g_hAutoDisplayMenu = 			CreateConVar("cz_atuo_display_menu", 				"1", 					"在感染玩家进入灵魂状态后自动向其显示更改类型的菜单?(0=不显示,-1=每次都显示,大于0=每回合总计显示的最大次数)", CVAR_FLAGS, true, -1.0);
	g_hPZTeamLimit = 				CreateConVar("cz_pz_team_limit", 					"2", 					"感染玩家数量达到多少后将限制使用sm_team3命令(-1=感染玩家不能超过生还玩家,大于等于0=感染玩家不能超过该值)", CVAR_FLAGS, true, -1.0);
	g_hCmdCooldownTime = 			CreateConVar("cz_cmd_cooldown_time", 				"60.0", 				"sm_team2,sm_team3,sm_tt命令的冷却时间(0.0-无冷却)", CVAR_FLAGS, true, 0.0);
	g_hCmdEnterCooling = 			CreateConVar("cz_return_enter_cooling", 			"31", 					"什么情况下sm_team2,sm_team3,sm_tt命令会进入冷却(1=使用其中一个命令,2=坦克玩家掉控,4=坦克玩家死亡,8=坦克玩家未及时重生,16=特感玩家杀掉生还者玩家,31=所有)", CVAR_FLAGS);
	g_hPZChangeTeamTo = 			CreateConVar("cz_pz_change_team_to", 				"0", 					"换图,过关以及任务失败时是否自动将特感玩家切换到哪个队伍?(0=不切换,1=旁观者,2=生还者)", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_hGlowColorEnable = 			CreateConVar("cz_survivor_color_enable", 			"1", 					"是否给生还者创发光建模型?(0=否,1=是)", CVAR_FLAGS);
	g_hGlowColor[COLOR_NORMAL] = 	CreateConVar("cz_survivor_color_normal", 			"0 180 0", 				"特感玩家看到的正常状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_INCAPA] = 	CreateConVar("cz_survivor_color_incapacitated", 	"180 0 0", 				"特感玩家看到的倒地状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_BLACKW] = 	CreateConVar("cz_survivor_color_blackwhite", 		"255 255 255", 			"特感玩家看到的黑白状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_VOMITED] = 	CreateConVar("cz_survivor_color_nowit", 			"155 0 180", 			"特感玩家看到的被Boomer喷或炸中过的生还者发光颜色", CVAR_FLAGS);
	g_hUserFlagBits = 				CreateConVar("cz_user_flagbits", 					";z;;;;z", 				"哪些标志能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_class,鼠标中键重置冷却的使用限制(留空表示所有人都不会被限制)", CVAR_FLAGS);
	g_hImmunityLevels = 			CreateConVar("cz_immunity_levels", 					"99;99;99;99;99;99", 	"要达到什么免疫级别才能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_class,鼠标中键重置冷的使用限制", CVAR_FLAGS);

	// https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
	g_hSILimit = 					CreateConVar("cz_si_limit", 						"31", 					"同时存在的最大特感数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SMOKER] = 	CreateConVar("cz_smoker_limit",						"6", 					"同时存在的最大smoker数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_BOOMER] = 	CreateConVar("cz_boomer_limit",						"6", 					"同时存在的最大boomer数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_HUNTER] = 	CreateConVar("cz_hunter_limit",						"6", 					"同时存在的最大hunter数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SPITTER] = 	CreateConVar("cz_spitter_limit", 					"6", 					"同时存在的最大spitter数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_JOCKEY] = 	CreateConVar("cz_jockey_limit",						"6", 					"同时存在的最大jockey数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_CHARGER] = 	CreateConVar("cz_charger_limit", 					"6", 					"同时存在的最大charger数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnWeights[SI_SMOKER] = 	CreateConVar("cz_smoker_weight", 					"100", 					"smoker产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_BOOMER] = 	CreateConVar("cz_boomer_weight", 					"50", 					"boomer产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_HUNTER] = 	CreateConVar("cz_hunter_weight", 					"100", 					"hunter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_SPITTER] = 	CreateConVar("cz_spitter_weight", 					"50", 					"spitter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_JOCKEY] = 	CreateConVar("cz_jockey_weight", 					"100", 					"jockey产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_CHARGER] = 	CreateConVar("cz_charger_weight", 					"50", 					"charger产生比重", CVAR_FLAGS, true, 0.0);
	g_hScaleWeights = 				CreateConVar("cz_scale_weights", 					"1",					"[ 0 = 关闭 | 1 = 开启 ] 缩放相应特感的产生比重", _, true, 0.0, true, 1.0);

	AutoExecConfig(true, "controll_zombies");
	// 想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(vModeConVarChanged);
	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hSbAllBotGame.AddChangeHook(vGeneralConVarChanged);
	g_hAllowAllBotSur = FindConVar("allow_all_bot_survivor_team");
	g_hAllowAllBotSur.AddChangeHook(vGeneralConVarChanged);
	g_hSurvivorMaxInc = FindConVar("survivor_max_incapacitated_count");
	g_hSurvivorMaxInc.AddChangeHook(vColorConVarChanged);

	g_hMaxTankPlayer.AddChangeHook(vGeneralConVarChanged);
	g_hSurvuivorLimit.AddChangeHook(vGeneralConVarChanged);
	g_hSurvuivorChance.AddChangeHook(vGeneralConVarChanged);
	g_hExchangeTeam.AddChangeHook(vGeneralConVarChanged);
	g_hPZSuicideTime.AddChangeHook(vGeneralConVarChanged);
	g_hPZRespawnTime.AddChangeHook(vGeneralConVarChanged);
	g_hPZPunishTime.AddChangeHook(vGeneralConVarChanged);
	g_hPZPunishHealth.AddChangeHook(vGeneralConVarChanged);
	g_hAutoDisplayMenu.AddChangeHook(vGeneralConVarChanged);
	g_hPZTeamLimit.AddChangeHook(vGeneralConVarChanged);
	g_hCmdCooldownTime.AddChangeHook(vGeneralConVarChanged);
	g_hCmdEnterCooling.AddChangeHook(vGeneralConVarChanged);
	g_hPZChangeTeamTo.AddChangeHook(vGeneralConVarChanged);

	g_hGlowColorEnable.AddChangeHook(vColorConVarChanged);
	int i;
	for(; i < 4; i++)
		g_hGlowColor[i].AddChangeHook(vColorConVarChanged);

	g_hUserFlagBits.AddChangeHook(vAccessConVarChanged);
	g_hImmunityLevels.AddChangeHook(vAccessConVarChanged);

	g_hSILimit.AddChangeHook(vSpawnConVarChanged);
	for(i = 0; i < 6; i++)
	{
		g_hSpawnLimits[i].AddChangeHook(vSpawnConVarChanged);
		g_hSpawnWeights[i].AddChangeHook(vSpawnConVarChanged);
	}
	g_hScaleWeights.AddChangeHook(vSpawnConVarChanged);

	//RegAdminCmd("sm_cz", cmdCz, ADMFLAG_ROOT, "测试");
	RegConsoleCmd("sm_team2", cmdTeam2, "切换到Team 2.");
	RegConsoleCmd("sm_team3", cmdTeam3, "切换到Team 3.");
	//RegConsoleCmd("sm_bp", cmdPB, "叛变为坦克.");
	RegConsoleCmd("sm_pb", cmdPB, "提前叛变.");
	RegConsoleCmd("sm_tt", cmdTakeTank, "接管坦克.");
	RegConsoleCmd("sm_class", cmdChangeClass, "更改特感类型.");

	if(g_bLateLoad)
	{
		g_iRoundStart = 1;
		g_iPlayerSpawn = 1;
		g_bHasAnySurvivorLeftSafeArea = bHasAnySurvivorLeftSafeArea();
	}

	vPluginStateChanged();
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);

	for(int i = 1; i <= MaxClients; i++)
		vRemoveSurvivorModelGlow(i);
}

public void OnConfigsExecuted()
{
	vGetGeneralCvars();
	vGetColorCvars();
	vGetSpawnCvars();
	vGetAccessCvars();
	vPluginStateChanged();
}

void vModeConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vPluginStateChanged();
}

void vPluginStateChanged()
{
	g_hGameMode.GetString(g_sGameMode, sizeof g_sGameMode);

	int iLast = g_iControlled;
	g_iControlled = SDKCall(g_hSDKHasPlayerControlledZombies);
	if(g_iControlled == 1)
	{
		vToggle(false);
		if(iLast != g_iControlled)
		{
			delete g_hTimer;
			for(int i = 1; i <= MaxClients; i++)
			{
				vResetClientData(i);
				if(IsClientInGame(i) && GetClientTeam(i) == 2)
					vRemoveSurvivorModelGlow(i);
			}
		}
	}
	else
	{
		vToggle(true);
		if(iLast != g_iControlled)
		{
			if(bHasPlayerZombie())
			{
				float fTime = g_bHasAnySurvivorLeftSafeArea ? GetEngineTime() : 0.0;
				for(int i = 1; i <= MaxClients; i++)
				{
					if(!IsClientInGame(i))
						continue;

					switch(GetClientTeam(i))
					{
						case 2:
							vCreateSurvivorModelGlow(i);

						case 3:
						{
							if(!IsFakeClient(i) && !IsPlayerAlive(i))
							{
								vCalculatePZRespawnTime(i);
								g_esPlayer[i].fRespawnStartTime = fTime;
							}
						}
					}
				}

				delete g_hTimer;
				g_hTimer = CreateTimer(0.1, tmrPlayerStatus, _, TIMER_REPEAT);
			}
		}
	}
}

void vToggle(bool bEnable)
{
	static bool bEnabled;
	if(!bEnabled && bEnable)
	{
		bEnabled = true;
		vToggleDetours(true);

		HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
		HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea);
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("player_team", Event_PlayerTeam);
		HookEvent("player_spawn", Event_PlayerSpawn);
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		HookEvent("tank_frustrated", Event_TankFrustrated);
		HookEvent("player_bot_replace", Event_PlayerBotReplace);
		HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

		AddCommandListener(CommandListener_CallVote, "callvote");
	}
	else if(bEnabled && !bEnable)
	{
		bEnabled = false;
		vToggleDetours(false);

		UnhookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
		UnhookEvent("player_left_checkpoint", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_team", Event_PlayerTeam);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		UnhookEvent("tank_frustrated", Event_TankFrustrated);
		UnhookEvent("player_bot_replace", Event_PlayerBotReplace);
		UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

		RemoveCommandListener(CommandListener_CallVote, "callvote");
	}
}

void vGeneralConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetGeneralCvars();
}

void vGetGeneralCvars()
{
	g_iMaxTankPlayer = g_hMaxTankPlayer.IntValue;
	g_iSurvuivorLimit = g_hSurvuivorLimit.IntValue;
	g_fSurvuivorChance = g_hSurvuivorChance.FloatValue;
	g_bSbAllBotGame = g_hSbAllBotGame.BoolValue;
	g_bAllowAllBotSur = g_hAllowAllBotSur.BoolValue;
	g_bExchangeTeam = g_hExchangeTeam.BoolValue;
	g_iPZRespawnTime = g_hPZRespawnTime.IntValue;
	g_iPZSuicideTime = g_hPZSuicideTime.IntValue;
	g_iPZPunishTime = g_hPZPunishTime.IntValue;
	g_bPZPunishHealth = g_hPZPunishHealth.BoolValue;
	g_iAutoDisplayMenu = g_hAutoDisplayMenu.IntValue;
	g_iPZTeamLimit = g_hPZTeamLimit.IntValue;
	g_fCmdCooldownTime = g_hCmdCooldownTime.FloatValue;
	g_iCmdEnterCooling = g_hCmdEnterCooling.IntValue;
	g_iPZChangeTeamTo = g_hPZChangeTeamTo.IntValue;
}

void vColorConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetColorCvars();
}

void vGetColorCvars()
{
	bool bLast = g_bGlowColorEnable;
	g_bGlowColorEnable = g_hGlowColorEnable.BoolValue;
	g_iSurvivorMaxInc = g_hSurvivorMaxInc.IntValue;

	int i;
	for(; i < 4; i++)
		g_iGlowColor[i] = iGetColor(g_hGlowColor[i]);

	if(bLast != g_bGlowColorEnable)
	{
		if(g_bGlowColorEnable)
		{
			if(bHasPlayerZombie())
			{
				for(i = 1; i <= MaxClients; i++)
					vCreateSurvivorModelGlow(i);
			}
		}
		else
		{
			for(i = 1; i <= MaxClients; i++)
				vRemoveSurvivorModelGlow(i);
		}
	}
}

int iGetColor(ConVar hConVar)
{
	char sTemp[12];
	hConVar.GetString(sTemp, sizeof sTemp);

	if(sTemp[0] == '\0')
		return 1;

	char sColors[3][4];
	int iColor = ExplodeString(sTemp, " ", sColors, sizeof sColors, sizeof sColors[]);

	if(iColor != 3)
		return 1;
		
	iColor = StringToInt(sColors[0]);
	iColor += 256 * StringToInt(sColors[1]);
	iColor += 65536 * StringToInt(sColors[2]);

	return iColor > 0 ? iColor : 1;
}

void vAccessConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetAccessCvars();
}

void vGetAccessCvars()
{
	vGetUserFlagBits();
	vGetImmunityLevels();
}

void vGetUserFlagBits()
{
	char sTemp[256];
	g_hUserFlagBits.GetString(sTemp, sizeof sTemp);

	char sUserFlagBits[6][26];
	ExplodeString(sTemp, ";", sUserFlagBits, sizeof sUserFlagBits, sizeof sUserFlagBits[]);

	for(int i; i < 6; i++)
		g_iUserFlagBits[i] = ReadFlagString(sUserFlagBits[i]);
}

void vGetImmunityLevels()
{
	char sTemp[128];
	g_hImmunityLevels.GetString(sTemp, sizeof sTemp);

	char sImmunityLevels[6][8];
	ExplodeString(sTemp, ";", sImmunityLevels, sizeof sImmunityLevels, sizeof sImmunityLevels[]);

	for(int i; i < 6; i++)
		g_iImmunityLevels[i] = StringToInt(sImmunityLevels[i]);
}

static bool bCheckClientAccess(int client, int iIndex)
{
	if(g_iUserFlagBits[iIndex] == 0)
		return true;

	static int iFlagBits;
	if((iFlagBits = GetUserFlagBits(client)) & ADMFLAG_ROOT == 0 && iFlagBits & g_iUserFlagBits[iIndex] == 0)
		return false;

	if(!bCacheSteamID(client))
		return false;

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, g_esPlayer[client].sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return true;

	return admin.ImmunityLevel >= g_iImmunityLevels[iIndex];
}

bool bCacheSteamID(int client)
{
	if(g_esPlayer[client].sSteamID[0] == '\0')
		return GetClientAuthId(client, AuthId_Steam2, g_esPlayer[client].sSteamID, sizeof esPlayer::sSteamID);
	return true;
}

void vSpawnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetSpawnCvars();
}

void vGetSpawnCvars()
{
	g_iSILimit = g_hSILimit.IntValue;
	for(int i; i < 6; i++)
	{
		g_iSpawnLimits[i] = g_hSpawnLimits[i].IntValue;
		g_iSpawnWeights[i] = g_hSpawnWeights[i].IntValue;
	}
	g_bScaleWeights = g_hScaleWeights.BoolValue;
}
/**
Action cmdCz(int client, int args)
{
	if(!client || !IsClientInGame(client) || GetClientTeam(client) < 2)
		return Plugin_Handled;

	SDKCall(g_hSDKReplaceWithBot, client, false);
	SDKCall(g_hSDKSetPreSpawnClass, client, 3);
	SDKCall(g_hSDKState_Transition, client, 8);
	return Plugin_Handled;
}
*/
Action cmdTeam2(int client, int args)
{
	if(g_iControlled == 1)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(bCheckClientAccess(client, 0) == false)
	{
		// ReplyToCommand(client, "无权使用该指令");
		// return Plugin_Handled;
		float fTime = GetEngineTime();
		if(g_esPlayer[client].fCmdLastUsedTime > fTime)
		{
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_esPlayer[client].fCmdLastUsedTime - fTime);
			return Plugin_Handled;
		}
	}

	if(GetClientTeam(client) != 3)
	{
		PrintToChat(client, "只有感染者才能使用该指令");
		return Plugin_Handled;
	}

	if(g_iCmdEnterCooling & (1 << 0))
		g_esPlayer[client].fCmdLastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
	vChangeTeamToSurvivor(client);
	return Plugin_Handled;
}

Action cmdTeam3(int client, int args)
{
	if(g_iControlled == 1)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
		return Plugin_Handled;

	if(bCheckClientAccess(client, 1) == false)
	{
		// ReplyToCommand(client, "无权使用该指令");
		// return Plugin_Handled;
		float fTime = GetEngineTime();
		if(g_esPlayer[client].fCmdLastUsedTime > fTime)
		{
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_esPlayer[client].fCmdLastUsedTime - fTime);
			return Plugin_Handled;
		}

		int iTeam3 = iGetTeamPlayers(3);
		int iTeam2 = iGetTeamPlayers(2);
		if((g_iPZTeamLimit >= 0 && iTeam3 >= g_iPZTeamLimit) || (g_iPZTeamLimit == -1 && iTeam3 >= iTeam2))
		{
			PrintToChat(client, "已到达感染玩家数量限制");
			return Plugin_Handled;
		}
	}
		
	if(g_iCmdEnterCooling & (1 << 0))
		g_esPlayer[client].fCmdLastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

	g_esData[client].Clean();

	int iBot;
	if(GetClientTeam(client) != 1 || !(iBot = iGetBotOfIdlePlayer(client)))
		iBot = client;

	g_esData[client].Save(iBot, false);

	ChangeClientTeam(client, 3);
	return Plugin_Handled;
}

Action cmdPB(int client, int args)
{
	if(g_iControlled == 1)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(bCheckClientAccess(client, 2) == false)
	{
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if(g_esPlayer[client].bIsPlayerPB == false)
	{
		g_esPlayer[client].bIsPlayerPB = true;
		CPrintToChat(client, "已加入叛变列表");
		CPrintToChat(client, "再次输入该指令可退出叛变列表");
		CPrintToChat(client, "坦克出现后将会随机从叛变列表中抽取1人接管");
		CPrintToChat(client, "{olive}当前叛变玩家列表:");

		for(int i = 1; i <= MaxClients; i++)
		{
			if(g_esPlayer[i].bIsPlayerPB && IsClientInGame(i) && !IsFakeClient(i))
				CPrintToChat(client, "-> {red}%N", i);
		}
	}
	else
	{
		g_esPlayer[client].bIsPlayerPB = false;
		CPrintToChat(client, "已退出叛变列表");
	}

	return Plugin_Handled;
}

Action cmdTakeTank(int client, int args)
{
	if(g_iControlled == 1)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(!bIsRoundStarted())
	{
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	int iTeam = GetClientTeam(client);
	if(bCheckClientAccess(client, 3) == false)
	{
		// ReplyToCommand(client, "无权使用该指令");
		// return Plugin_Handled;
		float fTime = GetEngineTime();
		if(g_esPlayer[client].fCmdLastUsedTime > fTime)
		{
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_esPlayer[client].fCmdLastUsedTime - fTime);
			return Plugin_Handled;
		}
	}
		
	if(iGetTankPlayers() >= g_iMaxTankPlayer)
	{
		ReplyToCommand(client, "\x01存活的玩家坦克数量达到预设上限 ->\x05%d", g_iMaxTankPlayer);
		return Plugin_Handled;
	}

	switch(iTeam)
	{
		case 2:
		{
			if(!bAllowSurvivorTakeOver())
			{
				ReplyToCommand(client, "生还者接管坦克将会导致任务失败 请等待玩家足够后再尝试");
				return Plugin_Handled;
			}
		}
		
		case 3:
		{
			if(IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
			{
				ReplyToCommand(client, "你当前已经是坦克");
				return Plugin_Handled;
			}
		}
	}

	if(iGetStandingSurvivors() < g_iSurvuivorLimit)
	{
		ReplyToCommand(client, "\x01完全正常的生还者数量小于预设值 ->\x05%d", g_iSurvuivorLimit);
		return Plugin_Handled;
	}

	int iTank;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
		{
			iTank = i;
			break;
		}
	}

	if(!iTank)
	{
		ReplyToCommand(client, "无可供接管的坦克存在");
		return Plugin_Handled;
	}

	switch(iTeam)
	{
		case 2:
		{
				g_esData[client].Clean();
				g_esData[client].Save(client, false);
				ChangeClientTeam(client, 3);
		}
			
		case 3:
		{
			if(IsPlayerAlive(client))
			{
				SDKCall(g_hSDKCleanupPlayerState, client);
				ForcePlayerSuicide(client);
			}
		}

		default:
			ChangeClientTeam(client, 3);
	}

	if(GetClientTeam(client) == 3)
		g_esPlayer[client].iLastTeamID = iTeam != 3 ? 2 : 3;

	if(iTakeOverZombieBot(client, iTank) == 8 && IsPlayerAlive(client))
	{
		if(g_iCmdEnterCooling & (1 << 0))
			g_esPlayer[client].fCmdLastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

		CPrintToChatAll("{green}★ {default}[{olive}AI{default}] {red}%N {default}已被 {red}%N {olive}接管", iTank, client);
	}

	return Plugin_Handled;
}

Action cmdChangeClass(int client, int args)
{
	if(g_iControlled == 1)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if(bCheckClientAccess(client, 4) == false)
	{
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if(GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost") == 0)
	{
		PrintToChat(client, "灵魂状态下的特感才能使用该指令");
		return Plugin_Handled;
	}

	if(g_esPlayer[client].iMaterialized != 0)
	{
		PrintToChat(client, "第一次灵魂状态下才能使用该指令");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		char sTargetClass[16];
		GetCmdArg(1, sTargetClass, sizeof sTargetClass);
		int iZombieClass;
		int iClass = iGetZombieClass(sTargetClass);
		if(iClass == -1)
		{
			CPrintToChat(client, "{olive}!class{default}/{olive}sm_class {default}<{red}class{default}>.");
			CPrintToChat(client, "<{olive}class{default}> [ {red}smoker {default}| {red}boomer {default}| {red}hunter {default}| {red}spitter {default}| {red}jockey {default}| {red}charger {default}]");
		}
		else if(++iClass == (iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass")))
			CPrintToChat(client, "目标特感类型与当前特感类型相同");
		else if(iZombieClass == 8)
			CPrintToChat(client, "{red}Tank {default}无法更改特感类型");
		else
			vSetZombieClassAndPunish(client, iClass);
	}
	else
	{
		if(GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
			vSelectZombieClassMenu(client);
		else
			CPrintToChat(client, "{red}Tank {default}无法更改特感类型");
	}
	
	return Plugin_Handled;
}

void vDisplayClassMenu(int client)
{
	Menu menu = new Menu(iDisplayClassMenuHandler);
	menu.SetTitle("!class付出一定代价更改特感类型?");
	menu.AddItem("yes", "是");
	menu.AddItem("no", "否");
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, 15);
}

int iDisplayClassMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(param2 == 0 && GetClientTeam(param1) == 3 && !IsFakeClient(param1) && IsPlayerAlive(param1) && GetEntProp(param1, Prop_Send, "m_isGhost") == 1)
				vSelectZombieClassMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vSelectZombieClassMenu(int client)
{
	char sIndex[2];
	Menu menu = new Menu(iSelectZombieClassMenuHandler);
	menu.SetTitle("选择要切换的特感");
	int iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass") - 1;
	for(int i; i < 6; i++)
	{
		if(i != iZombieClass)
		{
			FormatEx(sIndex, sizeof sIndex, "%d", i);
			menu.AddItem(sIndex, g_sZombieClass[i]);
		}
	}
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, 30);
}

int iSelectZombieClassMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			int iZombieClass;
			if(GetClientTeam(param1) == 3 && !IsFakeClient(param1) && IsPlayerAlive(param1) && (iZombieClass = GetEntProp(param1, Prop_Send, "m_zombieClass")) != 8 && GetEntProp(param1, Prop_Send, "m_isGhost") == 1)
			{
				char sItem[2];
				menu.GetItem(param2, sItem, sizeof sItem);
				int iClass = StringToInt(sItem);
				if(++iClass != iZombieClass)
					vSetZombieClassAndPunish(param1, iClass);
			}
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vSetZombieClassAndPunish(int client, int iZombieClass)
{
	vSetZombieClass(client, iZombieClass);
	if(g_bPZPunishHealth)
		SetEntityHealth(client, RoundToCeil(GetClientHealth(client) / 2.0));
	g_esPlayer[client].bClassCmdUsed = true;
}

int iGetZombieClass(const char[] sClass)
{
	for(int i; i < 6; i++)
	{
		if(strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return -1;
}

Action CommandListener_CallVote(int client, const char[] command, int argc)
{
	if(!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
		
	if(GetClientTeam(client) == 3)
	{
		CPrintToChat(client, "{red}感染者无人权");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// https://gist.github.com/ProdigySim/04912e5e76f69027f8c4
// Spawn State - These look like flags, but get used like static values quite often.
// These names were pulled from reversing client.dll--specifically CHudGhostPanel::OnTick()'s uses of the "#L4D_Zombie_UI_*" strings
//
// SPAWN_OK             0
// SPAWN_DISABLED       1  "Spawning has been disabled..." (e.g. director_no_specials 1)
// WAIT_FOR_SAFE_AREA   2  "Waiting for the Survivors to leave the safe area..."
// WAIT_FOR_FINALE      4  "Waiting for the finale to begin..."
// WAIT_FOR_TANK        8  "Waiting for Tank battle conclusion..."
// SURVIVOR_ESCAPED    16  "The Survivors have escaped..."
// DIRECTOR_TIMEOUT    32  "The Director has called a time-out..." (lol wat)
// WAIT_FOR_STAMPEDE   64  "Waiting for the next stampede of Infected..."
// CAN_BE_SEEN        128  "Can't spawn here" "You can be seen by the Survivors"
// TOO_CLOSE          256  "Can't spawn here" "You are too close to the Survivors"
// RESTRICTED_AREA    512  "Can't spawn here" "This is a restricted area"
// INSIDE_ENTITY     1024  "Can't spawn here" "Something is blocking this spot"
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(g_iControlled == 1 || IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
		return Plugin_Continue;

	static int iFlags;
	iFlags = GetEntProp(client, Prop_Data, "m_afButtonPressed");
	if(GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(iFlags & IN_ZOOM)
		{
			if(g_esPlayer[client].iMaterialized == 0 && bCheckClientAccess(client, 4) == true)
				vSelectAscendingZombieClass(client);
		}
		else if(iFlags & IN_ATTACK)
		{
			if(GetEntProp(client, Prop_Send, "m_ghostSpawnState") == 1)
				SDKCall(g_hSDKMaterializeFromGhost, client);
		}
	}
	else
	{
		if(iFlags & IN_ZOOM && bCheckClientAccess(client, 5) == true)
			vResetInfectedAbility(client, 0.1); // 管理员鼠标中键重置技能冷却
	}

	return Plugin_Continue;
}

void vSelectAscendingZombieClass(int client)
{
	static int iZombieClass;
	iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(iZombieClass != 8)
		vSetZombieClassAndPunish(client, iZombieClass - RoundToFloor(iZombieClass / 6.0) * 6 + 1);
}

// https://forums.alliedmods.net/showthread.php?p=1542365
void vResetInfectedAbility(int client, float fTime)
{
	int iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
	{
		//SetEntPropFloat(iAbility, Prop_Send, "m_duration", fTime);
		SetEntPropFloat(iAbility, Prop_Send, "m_timestamp", GetGameTime() + fTime);
	}
}

public void OnMapStart()
{
	PrecacheSound(SOUND_CLASSMENU);
	g_fMapStartTime = GetGameTime();
	for(int i = 1; i <= MaxClients; i++)
		g_esPlayer[i].fBugExploitTime[0] = g_esPlayer[i].fBugExploitTime[1] = 0.0;
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasAnySurvivorLeftSafeArea = false;
	delete g_hTimer;
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;

	vResetClientData(client);
}

public void OnClientDisconnect(int client)
{
	vRemoveSurvivorModelGlow(client);

	if(IsFakeClient(client))
		return;

	g_esPlayer[client].sSteamID[0] = '\0';

	if(!IsClientInGame(client) || GetClientTeam(client) != 3)
		g_esPlayer[client].iLastTeamID = 0;
}

void vResetClientData(int client)
{
	g_esData[client].Clean();

	g_esPlayer[client].iEnteredGhost = 0;
	g_esPlayer[client].iMaterialized = 0;
	g_esPlayer[client].fRespawnStartTime = 0.0;
	g_esPlayer[client].fSuicideStartTime = 0.0;
	
	g_esPlayer[client].bIsPlayerPB = false;
	g_esPlayer[client].bClassCmdUsed = false;
}

// ------------------------------------------------------------------------------
// Event
void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{ 
	if(g_bHasAnySurvivorLeftSafeArea || !bIsRoundStarted())
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		CreateTimer(0.1, tmrPlayerLeftStartArea, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool bIsRoundStarted()
{
	return g_iRoundStart && g_iPlayerSpawn;
}

Action tmrPlayerLeftStartArea(Handle timer)
{
	if(!g_bHasAnySurvivorLeftSafeArea && bIsRoundStarted() && bHasAnySurvivorLeftSafeArea())
	{
		g_bHasAnySurvivorLeftSafeArea = true;

		if(g_iControlled == 0)
		{
			if(g_iPZRespawnTime > 0)
			{
				float fTime = GetEngineTime();
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3 && !IsPlayerAlive(i))
					{
						g_esPlayer[i].iCurrentPZRespawnTime = 0;
						g_esPlayer[i].fRespawnStartTime = fTime;
					}
				}
			}

			delete g_hTimer;
			g_hTimer = CreateTimer(0.1, tmrPlayerStatus, _, TIMER_REPEAT);
		}
	}

	return Plugin_Continue;
}

bool bHasAnySurvivorLeftSafeArea()
{
	int entity = GetPlayerResourceEntity();
	if(entity == INVALID_ENT_REFERENCE)
		return false;

	return !!GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

void vCalculatePZRespawnTime(int client)
{
	g_esPlayer[client].iCurrentPZRespawnTime = g_iPZRespawnTime;

	if(g_iPZPunishTime > 0 && g_esPlayer[client].bClassCmdUsed)
		g_esPlayer[client].iCurrentPZRespawnTime += g_iPZPunishTime;
		
	g_esPlayer[client].bClassCmdUsed = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		vRemoveInfectedClips();
	g_iRoundStart = 1;

	delete g_hTimer;
	for(int i = 1; i <= MaxClients; i++)
	{
		g_esPlayer[i].fRespawnStartTime = 0.0;
		g_esPlayer[i].fSuicideStartTime = 0.0;
	}
}

// 移除一些限制特感的透明墙体，增加活动空间. 并且能够修复C2M5上面坦克卡住的情况
void vRemoveInfectedClips()
{
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "func_playerinfected_clip")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
		
	entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "func_playerghostinfected_clip")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasAnySurvivorLeftSafeArea = false;

	delete g_hTimer;
	for(int i = 1; i <= MaxClients; i++)
	{
		vResetClientData(i);

		if(g_iPZChangeTeamTo || g_esPlayer[i].iLastTeamID == 2)
			vForceChangeTeamTo(i);
	}
}

void vForceChangeTeamTo(int client)
{
	if(IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3)
	{
		switch(g_iPZChangeTeamTo)
		{
			case 1:
				ChangeClientTeam(client, 1);
					
			case 2:
				vChangeTeamToSurvivor(client);
		}
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return;

	g_esPlayer[client].iMaterialized = 0;
	vRemoveSurvivorModelGlow(client);

	if(IsFakeClient(client))
		return;

	g_esPlayer[client].fRespawnStartTime = 0.0;
	g_esPlayer[client].fSuicideStartTime = 0.0;

	int team = event.GetInt("team");
	if(team == 3)
	{
		if(g_iPZRespawnTime > 0 && g_bHasAnySurvivorLeftSafeArea == true)
		{
			vCalculatePZRespawnTime(client);
			g_esPlayer[client].fRespawnStartTime = GetEngineTime();
		}

		CreateTimer(0.1, tmrLadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);
	}

	switch(event.GetInt("oldteam"))
	{
		case 0:
		{
			if(team == 3 && (g_iPZChangeTeamTo || g_esPlayer[client].iLastTeamID == 2))
				RequestFrame(OnNextFrame_ChangeTeamTo, userid);

			g_esPlayer[client].iLastTeamID = 0;
		}
		
		case 3:
		{
			g_esPlayer[client].iLastTeamID = 0;

			if(team == 2 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
				SetEntProp(client, Prop_Send, "m_isGhost", 0); // SDKCall(g_hSDKMaterializeFromGhost, client);
			
			CreateTimer(0.1, tmrLadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

Action tmrLadderAndGlow(Handle timer, int client)
{
	if(g_iControlled == 0 && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client))
	{
		if(GetClientTeam(client) == 3)
		{
			// g_hGameMode.ReplicateToClient(client, "versus");
			if(iGetTeamPlayers(3) == 1)
			{
				for(int i = 1; i <= MaxClients; i++)
					vCreateSurvivorModelGlow(i);

				delete g_hTimer;
				g_hTimer = CreateTimer(0.1, tmrPlayerStatus, _, TIMER_REPEAT);
			}
		}
		else
		{
			g_hGameMode.ReplicateToClient(client, g_sGameMode);

			int i = 1;
			for(; i <= MaxClients; i++)
				vRemoveSurvivorModelGlow(i);

			if(!bHasPlayerZombie())
				delete g_hTimer;
			else
			{
				for(i = 1; i <= MaxClients; i++)
					vCreateSurvivorModelGlow(i);
			}
		}
	}

	return Plugin_Continue;
}

void OnNextFrame_ChangeTeamTo(int client)
{
	if(g_iControlled == 0 && (client = GetClientOfUserId(client)))
		vForceChangeTeamTo(client);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		vRemoveInfectedClips();
	g_iPlayerSpawn = 1;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(!IsPlayerAlive(client))
		return;
	
	g_esPlayer[client].iTankBot = 0;
	g_esPlayer[client].fRespawnStartTime = 0.0;

	if(!g_bOnMaterializeFromGhost)
		RequestFrame(OnNextFrame_PlayerSpawn, userid); // player_bot_replace在player_spawn之后触发，延迟一帧进行接管判断
}

void OnNextFrame_PlayerSpawn(int client)
{
	if(g_iControlled == 1 || (client = GetClientOfUserId(client))== 0 || !IsClientInGame(client) || IsClientInKickQueue(client) || !IsPlayerAlive(client))
		return;

	switch(GetClientTeam(client))
	{
		case 2:
		{
			if(bHasPlayerZombie())
				vCreateSurvivorModelGlow(client);
		}
		
		case 3:
		{
			if(g_iRoundStart && IsFakeClient(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
			{
				int iPlayer;
				if(g_esPlayer[client].iTankBot != 2 && iGetTankPlayers() < g_iMaxTankPlayer)
				{
					if((iPlayer = iTakeOverTank(client)))
					{
						vSetInfectedGhost(iPlayer, true);
						if(g_esPlayer[iPlayer].iLastTeamID == 2)
							CreateTimer(1.0, tmrReturnToSurvivor, GetClientUserId(iPlayer), TIMER_REPEAT);

						CPrintToChatAll("{green}★ {default}[{olive}AI{default}] {red}%N {default}已被 {red}%N {olive}接管", client, iPlayer);
					}
				}

				if(iPlayer == 0 && (GetEntProp(client, Prop_Data, "m_bIsInStasis") == 1 || SDKCall(g_hSDKIsInStasis, client)))
					SDKCall(g_hSDKLeaveStasis, client); // 解除战役模式下特感方有玩家存在时坦克卡住的问题
			}
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return;

	g_esPlayer[client].iMaterialized = 0;
	g_esPlayer[client].fSuicideStartTime = 0.0;

	switch(GetClientTeam(client))
	{
		case 2:
		{
			vRemoveSurvivorModelGlow(client);
			if(g_bExchangeTeam && !IsFakeClient(client))
			{
				int attacker = GetClientOfUserId(event.GetInt("attacker"));
				if(0 < attacker <= MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
				{
					ChangeClientTeam(client, 3);
					CPrintToChat(client, "{green}★ {red}生还者玩家 {default}被 {red}特感玩家 {default}杀死后，{olive}二者互换队伍");

					if(g_iCmdEnterCooling & (1 << 4))
						g_esPlayer[client].fCmdLastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
					RequestFrame(OnNextFrame_ChangeTeamToSurvivor, GetClientUserId(attacker));
					CPrintToChat(attacker, "{green}★ {red}特感玩家 {default}杀死 {red}生还者玩家 {default}后，{olive}二者互换队伍");
				}
			}
		}
		
		case 3:
		{
			if(!IsFakeClient(client))
			{
				if(g_iPZRespawnTime > 0 && g_bHasAnySurvivorLeftSafeArea == true)
				{
					vCalculatePZRespawnTime(client);
					g_esPlayer[client].fRespawnStartTime = GetEngineTime();
				}

				if(g_esPlayer[client].iLastTeamID == 2 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
				{
					if(g_iCmdEnterCooling & (1 << 2))
						g_esPlayer[client].fCmdLastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
					RequestFrame(OnNextFrame_ChangeTeamToSurvivor, userid);
					CPrintToChat(client, "{green}★ {olive}玩家Tank {default}死亡后自动切换回 {blue}生还者队伍");
				}
			}
		}
	}
}

Action tmrPlayerStatus(Handle timer)
{
	if(g_iControlled == 1)
		return Plugin_Continue;

	static int i;
	static int iModelIndex;
	static char sModelName[128];
	static float fTime;
	static float fInterval;
	static float fLastQueryTime[MAXPLAYERS + 1];
	static float fLastCountDown[MAXPLAYERS + 1];
	static bool bTankFrustrated[MAXPLAYERS + 1];

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	fTime = GetEngineTime();

	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		switch(GetClientTeam(i))
		{
			case 2:
			{
				if(!g_bGlowColorEnable || !IsPlayerAlive(i) || !bIsValidEntRef(g_esPlayer[i].iModelEntRef))
					continue;

				if(g_esPlayer[i].iModelIndex != (iModelIndex = GetEntProp(i, Prop_Data, "m_nModelIndex")))
				{
					g_esPlayer[i].iModelIndex = iModelIndex;
					GetEntPropString(i, Prop_Data, "m_ModelName", sModelName, sizeof sModelName);
					SetEntityModel(g_esPlayer[i].iModelEntRef, sModelName);
				}

				vSetGlowColor(i);
			}

			case 3:
			{
				if(IsFakeClient(i))
					continue;

				if(fTime - fLastQueryTime[i] >= 1.0)
				{
					QueryClientConVar(i, "mp_gamemode", queryMpGamemode, GetClientSerial(i));
					fLastQueryTime[i] = fTime;
				}

				if(!g_bHasAnySurvivorLeftSafeArea)
					continue;

				if(!IsPlayerAlive(i))
				{
					if(g_esPlayer[i].fRespawnStartTime)
					{
						if((fInterval = fTime - g_esPlayer[i].fRespawnStartTime) >= g_esPlayer[i].iCurrentPZRespawnTime)
						{
							if(bAttemptRespawnPZ(i))
							{
								// PrintToConsole(i, "重生预设-> %d秒 实际耗时->%.5f秒", g_esPlayer[i].iCurrentPZRespawnTime, fInterval);
								g_esPlayer[i].fRespawnStartTime = 0.0;
							}
							else
							{
								g_esPlayer[i].fRespawnStartTime = fTime - g_esPlayer[i].iCurrentPZRespawnTime + 5.0;
								CPrintToChat(i, "{red}复活失败 {default}将在{red}5秒{default}后继续尝试");
							}
						}
						else
						{
							if(fTime - fLastCountDown[i] >= 1.0)
							{
								PrintCenterText(i, "%d 秒后重生", RoundToCeil(g_esPlayer[i].iCurrentPZRespawnTime - fInterval));
								fLastCountDown[i] = fTime;
							}
						}
					}
				}
				else
				{
					if(GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
					{
						if(g_esPlayer[i].fSuicideStartTime && fTime - g_esPlayer[i].fSuicideStartTime >= g_iPZSuicideTime)
						{
							ForcePlayerSuicide(i);
							CPrintToChat(i, "{olive}特感玩家复活处死时间{default}-> {red}%d秒", g_iPZSuicideTime);
							// CPrintToChat(i, "{olive}处死预设{default}-> {red}%d秒 {olive}实际耗时{default}-> {red}%.5f秒", g_iPZSuicideTime, fInterval = fTime - g_esPlayer[i].fSuicideStartTime);
							g_esPlayer[i].fSuicideStartTime = 0.0;
						}
					}
					else if(GetEntProp(i, Prop_Send, "m_isGhost") == 0)
					{
						if(bTankFrustrated[i] && GetEntProp(i, Prop_Send, "m_frustration") >= 100)
						{
							// CTerrorPlayer::UpdateZombieFrustration(CTerrorPlayer *__hidden this)函数里面的原生方法
							Event event = CreateEvent("tank_frustrated", true);
							event.SetInt("userid", GetClientUserId(i));
							event.Fire(false);

							SDKCall(g_hSDKReplaceWithBot, i, false);
							SDKCall(g_hSDKSetPreSpawnClass, i, 3);
							SDKCall(g_hSDKState_Transition, i, 8);
						}
						else
						{
							bTankFrustrated[i] = GetEntProp(i, Prop_Send, "m_frustration") >= 100;
							// 这里延迟0.1秒等待系统自动掉控，如果出了Bug系统没进行掉控操作，则由插件进行
						}
					}
				}
			}
		}
	}

	#if BENCHMARK
	g_profiler.Stop();
	PrintToServer("ProfilerTime: %f", g_profiler.Time);
	#endif
	
	return Plugin_Continue;
}

// 与Silvers的[L4D & L4D2] Coop Markers - Flow Distance插件进行兼容 (https://forums.alliedmods.net/showthread.php?p=2682584)
void queryMpGamemode(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
    if(result == ConVarQuery_Okay && GetClientFromSerial(value) == client && strcmp(cvarValue, "versus") != 0)
		g_hGameMode.ReplicateToClient(client, "versus");
}

void Event_TankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(g_esPlayer[client].iLastTeamID != 2 || IsFakeClient(client))
		return;

	if(g_iCmdEnterCooling & (1 << 1))
		g_esPlayer[client].fCmdLastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
	RequestFrame(OnNextFrame_ChangeTeamToSurvivor, GetClientUserId(client));
	CPrintToChat(client, "{green}★ {default}丢失 {olive}Tank控制权 {default}后自动切换回 {blue}生还者队伍");
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int botUID = event.GetInt("bot");
	int playerUID = event.GetInt("player");
	int bot = GetClientOfUserId(botUID);
	int player = GetClientOfUserId(playerUID);

	g_esPlayer[player].iPlayerBot = botUID;
	g_esPlayer[bot].iBotPlayer = playerUID;

	if(GetClientTeam(bot) == 3 && GetEntProp(bot, Prop_Send, "m_zombieClass") == 8)
	{
		if(IsFakeClient(player))
			g_esPlayer[bot].iTankBot = 1; // 防卡功能中踢出FakeClient后，第二次触发Tank产生并替换原有的Tank(BOT替换BOT)
		else
			g_esPlayer[bot].iTankBot = 2; // 主动或被动放弃Tank控制权(BOT替换玩家)
	}
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	g_esPlayer[client].iLastTeamID = 0;

	if(GetClientTeam(client) == 2)
	{
		int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
		if(jockey != -1)
			vCheatCommand(jockey, "dismount", "");
	}
}

Action tmrReturnToSurvivor(Handle timer, int client)
{
	static int i;
	static int iTimes[MAXPLAYERS + 1] = {20, ...};

	if((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		i = iTimes[client]--;
		if(i > 0)
			PrintHintText(client, "还有 %d 秒变回生还者,请到掩体后面按鼠标[左键]重生.按[E]键可传送到生还者附近", i);
		else if(i == 0)
		{
			if(g_iCmdEnterCooling & (1 << 3))
				g_esPlayer[client].fCmdLastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
			vChangeTeamToSurvivor(client);
			i = iTimes[client] = 20;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	i = iTimes[client] = 20;
	return Plugin_Stop;
}

static bool bHasPlayerZombie()
{
	static int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
			return true;
	}
	return false;
}

int iGetTeamPlayers(int iTeam=-1)
{
	int iPlayers, iTeamPlayers;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(iTeam == -1)
				iPlayers++;
			else if(GetClientTeam(i) == iTeam)
				iTeamPlayers++;
		}
	}
	return iTeam == -1 ? iPlayers : iTeamPlayers;
}

int iGetTankPlayers()
{
	int iTankPlayers;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			iTankPlayers++;
	}
	return iTankPlayers;
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

void vSetGodMode(int client, float fDuration)
{
	if(!IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 0);
	
	if(fDuration > 0.0)
		CreateTimer(fDuration, tmrMortal, GetClientUserId(client));
}

Action tmrMortal(Handle timer, int client)
{
	if(!(client = GetClientOfUserId(client)) || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntProp(client, Prop_Data, "m_takedamage", 2);
	return Plugin_Continue;
}

int iFindUselessSurvivorBot(bool bAlive)
{
	int client;
	ArrayList aClients = new ArrayList(2);

	for(int i = MaxClients; i >= 1; i--)
	{
		if(!IsClientInGame(i) || IsClientInKickQueue(i) || !IsFakeClient(i) || GetClientTeam(i) != 2 || iGetIdlePlayerOfBot(i))
			continue;

		aClients.Set(aClients.Push(IsPlayerAlive(i) == bAlive ? (!(client = GetClientOfUserId(g_esPlayer[i].iBotPlayer)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 2 ? 0 : 1) : (!(client = GetClientOfUserId(g_esPlayer[i].iBotPlayer)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 2 ? 2 : 3)), i, 1);
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

bool bIsValidSurvivorBot(int client)
{
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == 2 && !iGetIdlePlayerOfBot(client);
}

int iGetBotOfIdlePlayer(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && iGetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int iGetIdlePlayerOfBot(int client)
{
	static char sNetClass[64];
	GetEntityNetClass(client, sNetClass, sizeof sNetClass);
	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

int iTakeOverTank(int tank)
{
	int client = 1;
	ArrayList aClients = new ArrayList(2);

	bool bAllowsurvivor = bAllowSurvivorTakeOver();
	for(; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client) || IsFakeClient(client))
			continue;

		switch(GetClientTeam(client))
		{
			case 2:
			{
				if(bAllowsurvivor)
					aClients.Set(aClients.Push(g_esPlayer[client].bIsPlayerPB ? 0 : 1), client, 1);
			}

			case 3:
			{
				if(!IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
					aClients.Set(aClients.Push(g_esPlayer[client].bIsPlayerPB ? 0 : 1), client, 1);
			}
		}
	}

	if(!aClients.Length)
		client = 0;
	else
	{
		SetRandomSeed(GetTime());
		if(aClients.FindValue(0) != -1)
		{
			aClients.Sort(Sort_Descending, Sort_Integer);
			client = aClients.Get(GetRandomInt(aClients.FindValue(0), aClients.Length - 1), 1);
		}
		else if(GetRandomFloat(0.0, 1.0) < g_fSurvuivorChance)
			client = aClients.Get(GetRandomInt(0, aClients.Length - 1), 1);
		else
			client = 0;
	}

	delete aClients;

	if(client && iGetStandingSurvivors() >= g_iSurvuivorLimit)
	{
		int iTeam = GetClientTeam(client);
		switch(iTeam)
		{
			case 2:
			{
				g_esData[client].Clean();
				g_esData[client].Save(client, false);
				ChangeClientTeam(client, 3);
			}
			
			case 3:
			{
				if(IsPlayerAlive(client))
				{
					SDKCall(g_hSDKCleanupPlayerState, client);
					ForcePlayerSuicide(client);
				}
			}
		}

		if(GetClientTeam(client) == 3)
			g_esPlayer[client].iLastTeamID = iTeam != 3 ? 2 : 3;
	
		if(iTakeOverZombieBot(client, tank) == 8 && IsPlayerAlive(client))
			return client;
	}

	return 0;
}

int iGetStandingSurvivors()
{
	int iSurvivor;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !bIsPinned(i))
			iSurvivor++;
	}
	return iSurvivor;
}

bool bAllowSurvivorTakeOver()
{
	if(g_bSbAllBotGame || g_bAllowAllBotSur)
		return true;

	int iAlivesurvivor;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			iAlivesurvivor++;
	}
	return iAlivesurvivor > 1;
}

bool bIsPinned(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	return false;
}

void vCreateSurvivorModelGlow(int client)
{
	if(!g_bGlowColorEnable || !bIsRoundStarted() || !IsClientInGame(client) || IsClientInKickQueue(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client) || bIsValidEntRef(g_esPlayer[client].iModelEntRef))
		return;

	int entity = CreateEntityByName("prop_dynamic_ornament");
	if(entity == -1)
		return;

	g_esPlayer[client].iModelEntRef = EntIndexToEntRef(entity);
	g_esPlayer[client].iModelIndex = GetEntProp(client, Prop_Data, "m_nModelIndex");

	static char sModelName[128];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof sModelName);
	DispatchKeyValue(entity, "model", sModelName);
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "glowstate", "3");
	DispatchKeyValue(entity, "glowrange", "20000");
	DispatchKeyValue(entity, "glowrangemin", "1");
	DispatchKeyValue(entity, "rendermode", "10");
	DispatchSpawn(entity);

	// [L4D & L4D2] Hats (https://forums.alliedmods.net/showthread.php?t=153781)
	AcceptEntityInput(entity, "DisableCollision");
	SetEntProp(entity, Prop_Send, "m_noGhostCollision", 1, 1);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({0.0, 0.0, 0.0}));
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({0.0, 0.0, 0.0}));

	vSetGlowColor(client);
	AcceptEntityInput(entity, "StartGlowing");

	SetEntProp(entity, Prop_Data, "m_iEFlags", 0);
	SetEntProp(entity, Prop_Data, "m_fEffects", 0x020); // don't draw entity

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetAttached", client);

	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

Action Hook_SetTransmit(int entity, int client)
{
	if(!IsFakeClient(client) && GetClientTeam(client) == 3)
		return Plugin_Continue;

	return Plugin_Handled;
}

static void vSetGlowColor(int client)
{
	static int iColorType;
	if(GetEntProp(g_esPlayer[client].iModelEntRef, Prop_Send, "m_glowColorOverride") != g_iGlowColor[(iColorType = iGetColorType(client))])
		SetEntProp(g_esPlayer[client].iModelEntRef, Prop_Send, "m_glowColorOverride", g_iGlowColor[iColorType]);
}

static int iGetColorType(int client)
{
	if(GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurvivorMaxInc)
		return 2;
	else
	{
		if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			return 1;
		else
		{
			static float fFadeStartTime;
			if((fFadeStartTime = GetEntPropFloat(client, Prop_Send, "m_vomitFadeStart")) > g_fMapStartTime && fFadeStartTime >= GetGameTime() - 15.0)
				return 3;
			else
				return 0;
		}
	}
}

static void vRemoveSurvivorModelGlow(int client)
{
	static int entity;

	entity = g_esPlayer[client].iModelEntRef;
	g_esPlayer[client].iModelEntRef = 0;

	if(bIsValidEntRef(entity))
		RemoveEntity(entity);
}

static bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}

// ------------------------------------------------------------------------------
// 切换回生还者
void OnNextFrame_ChangeTeamToSurvivor(int client)
{
	if(g_iControlled == 1 || !(client = GetClientOfUserId(client)) || !IsClientInGame(client))
		return;

	vChangeTeamToSurvivor(client);
}

void vChangeTeamToSurvivor(int client)
{
	int iTeam = GetClientTeam(client);
	if(iTeam == 2)
		return;

	// 防止因切换而导致正处于Ghost状态的坦克丢失
	if(GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		SetEntProp(client, Prop_Send, "m_isGhost", 0); // SDKCall(g_hSDKMaterializeFromGhost, client);

	int iBot = GetClientOfUserId(g_esPlayer[client].iPlayerBot);
	if(!iBot || !bIsValidSurvivorBot(iBot))
		iBot = iFindUselessSurvivorBot(true);

	if(iTeam != 1)
		ChangeClientTeam(client, 1);

	if(iBot)
	{
		SDKCall(g_hSDKSetHumanSpectator, iBot, client);
		SDKCall(g_hSDKTakeOverBot, client, true);
	}
	else
		ChangeClientTeam(client, 2);

	if(bIsRoundStarted())
	{
		if(!IsPlayerAlive(client))
			vRoundRespawn(client);

		vSetGodMode(client, 1.0);
		vTeleportToSurvivor(client);
	}

	g_esData[client].Restore(client, false);
	g_esData[client].Clean();
}

enum struct esData
{
	int iRecorded;
	int iCharacter;
	int iHealth;
	int iTempHealth;
	int iBufferTime;
	int iReviveCount;
	int iThirdStrike;
	int iGoingToDie;
	
	char sModel[128];

	int iClip0;
	int iAmmo;
	int iUpgrade;
	int iUpgradeAmmo;
	int iWeaponSkin0;
	int iClip1;
	int iWeaponSkin1;
	bool bDualWielding;

	char sSlot0[32];
	char sSlot1[32];
	char sSlot2[32];
	char sSlot3[32];
	char sSlot4[32];
	char sActive[32];

	// Save Weapon 4.3 (forked)(https://forums.alliedmods.net/showthread.php?p=2398822#post2398822)
	void Clean()
	{
		if(!this.iRecorded)
			return;
	
		this.iRecorded = 0;
		this.iCharacter = -1;
		this.iReviveCount = 0;
		this.iThirdStrike = 0;
		this.iGoingToDie = 0;
		this.iHealth = 0;
		this.iTempHealth = 0;
		this.iBufferTime = 0;
	
		this.sModel[0] = '\0';

		this.iClip0 = 0;
		this.iAmmo = 0;
		this.iUpgrade = 0;
		this.iUpgradeAmmo = 0;
		this.iWeaponSkin0 = 0;
		this.iClip1 = -1;
		this.iWeaponSkin1 = 0;
		this.bDualWielding = false;
	
		this.sSlot0[0] = '\0';
		this.sSlot1[0] = '\0';
		this.sSlot2[0] = '\0';
		this.sSlot3[0] = '\0';
		this.sSlot4[0] = '\0';
		this.sActive[0] = '\0';
	}

	void Save(int client, bool bIdentity = true)
	{
		this.Clean();

		if(GetClientTeam(client) != 2)
			return;
		
		this.iRecorded = 1;

		if(bIdentity)
		{
			this.iCharacter = GetEntProp(client, Prop_Send, "m_survivorCharacter");
			GetClientModel(client, this.sModel, sizeof esData::sModel);
		}

		if(!IsPlayerAlive(client))
		{
			static ConVar hZSurvivorRespa;
			if(hZSurvivorRespa == null)
				hZSurvivorRespa = FindConVar("z_survivor_respawn_health");

			this.iHealth = hZSurvivorRespa.IntValue;
			return;
		}

		if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		{
			if(!GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
			{
				static ConVar hSurvivorReviveH;
				if(hSurvivorReviveH == null)
					hSurvivorReviveH = FindConVar("survivor_revive_health");

				static ConVar hSurvivorMaxInc;
				if(hSurvivorMaxInc == null)
					hSurvivorMaxInc = FindConVar("survivor_max_incapacitated_count");

				this.iHealth = 1;
				this.iTempHealth = hSurvivorReviveH.IntValue;
				this.iBufferTime = 0;
				this.iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount") + 1;
				this.iThirdStrike = this.iReviveCount >= hSurvivorMaxInc.IntValue ? 1 : 0;
				this.iGoingToDie = 1;
			}
			else
			{
				static ConVar hSurvivorIncapH;
				if(hSurvivorIncapH == null)
					hSurvivorIncapH = FindConVar("survivor_incap_health");

				int iPreTemp = GetEntData(client, g_iOffHangingPreTemp);									// 玩家挂边前的虚血
				int iPreReal = GetEntData(client, g_iOffHangingPreReal);									// 玩家挂边前的实血
				int iPreTotal = iPreTemp + iPreReal;														// 玩家挂边前的总血量
				int iHangingCurrent = GetEntData(client, g_iOffHangingCurrent);							// 玩家挂边时的总血量
				int iRevivedTotal = RoundToFloor(iHangingCurrent / hSurvivorIncapH.FloatValue * iPreTotal);	// 玩家挂边起身后的总血量

				int iDelta = iPreTotal - iRevivedTotal;
				if(iPreTemp > iDelta)
				{
					this.iHealth = iPreReal;
					this.iTempHealth = iPreTemp - iDelta;
				}
				else
				{
					this.iHealth = iPreReal - (iDelta - iPreTemp);
					this.iTempHealth = 0;
				}

				this.iBufferTime = 0;
				this.iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
				this.iThirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
				this.iGoingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
			}
		}
		else
		{
			this.iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
			this.iTempHealth = RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
			this.iBufferTime = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));
			this.iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
			this.iThirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
			this.iGoingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
		}

		char sWeapon[32];
		int iSlot = GetPlayerWeaponSlot(client, 0);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot0, sizeof esData::sSlot0, sWeapon);

			this.iClip0 = GetEntProp(iSlot, Prop_Send, "m_iClip1");
			this.iAmmo = iGetOrSetPlayerAmmo(client, iSlot);
			this.iUpgrade = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
			this.iUpgradeAmmo = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
			this.iWeaponSkin0 = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		}

		// Mutant_Tanks (https://github.com/Psykotikism/Mutant_Tanks)
		if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		{
			int iMelee = GetEntDataEnt2(client, g_iOffMelee);
			switch(iMelee > MaxClients && IsValidEntity(iMelee))
			{
				case true:
					iSlot = iMelee;

				case false:
					iSlot = GetPlayerWeaponSlot(client, 1);
			}
		}
		else
			iSlot = GetPlayerWeaponSlot(client, 1);

		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			if(strcmp(sWeapon[7], "melee") == 0)
				GetEntPropString(iSlot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof sWeapon);
			else
			{
				if(strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
					this.iClip1 = GetEntProp(iSlot, Prop_Send, "m_iClip1");

				this.bDualWielding = strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(iSlot, Prop_Send, "m_isDualWielding");
			}

			strcopy(this.sSlot1, sizeof esData::sSlot1, sWeapon);
			this.iWeaponSkin1 = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		}

		iSlot = GetPlayerWeaponSlot(client, 2);
		if(iSlot > MaxClients && (iSlot != GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") || GetEntPropFloat(iSlot, Prop_Data, "m_flNextPrimaryAttack") < GetGameTime()))
		{	//Method from HarryPotter (https://forums.alliedmods.net/showpost.php?p=2768411&postcount=5)
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot2, sizeof esData::sSlot2, sWeapon);
		}

		iSlot = GetPlayerWeaponSlot(client, 3);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot3, sizeof esData::sSlot3, sWeapon);
		}

		iSlot = GetPlayerWeaponSlot(client, 4);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot4, sizeof esData::sSlot4, sWeapon);
		}
	
		iSlot = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sActive, sizeof esData::sActive, sWeapon);
		}
	}

	void Restore(int client, bool bIdentity = true)
	{
		if(!this.iRecorded)
			return;

		if(GetClientTeam(client) != 2)
			return;

		if(bIdentity)
		{
			if(this.iCharacter != -1)
				SetEntProp(client, Prop_Send, "m_survivorCharacter", this.iCharacter);

			if(this.sModel[0] != '\0')
				SetEntityModel(client, this.sModel);
		}
		
		if(!IsPlayerAlive(client)) 
			return;

		if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			SDKCall(g_hSDKOnRevived, client); //SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

		SetEntProp(client, Prop_Send, "m_iHealth", this.iHealth);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * this.iTempHealth);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * this.iBufferTime);
		SetEntProp(client, Prop_Send, "m_currentReviveCount", this.iReviveCount);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", this.iThirdStrike);
		SetEntProp(client, Prop_Send, "m_isGoingToDie", this.iGoingToDie);

		if(!GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike"))
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");

		int iSlot;
		int iWeapon;
		for(; iSlot < 5; iSlot++)
		{
			if((iWeapon = GetPlayerWeaponSlot(client, iSlot)) > MaxClients)
			{
				RemovePlayerItem(client, iWeapon);
				RemoveEdict(iWeapon);
			}
		}

		bool bGiven;
		if(this.sSlot0[0] != '\0')
		{
			vCheatCommand(client, "give", this.sSlot0);

			iSlot = GetPlayerWeaponSlot(client, 0);
			if(iSlot > MaxClients)
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", this.iClip0);
				iGetOrSetPlayerAmmo(client, iSlot, this.iAmmo);

				if(this.iUpgrade > 0)
					SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", this.iUpgrade);

				if(this.iUpgradeAmmo > 0)
					SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", this.iUpgradeAmmo);
				
				if(this.iWeaponSkin0 > 0)
					SetEntProp(iSlot, Prop_Send, "m_nSkin", this.iWeaponSkin0);
				
				bGiven = true;
			}
		}

		if(this.sSlot1[0] != '\0')
		{
			switch(this.bDualWielding)
			{
				case true:
				{
					vCheatCommand(client, "give", "weapon_pistol");
					vCheatCommand(client, "give", "weapon_pistol");
				}

				case false:
					vCheatCommand(client, "give", this.sSlot1);
			}

			iSlot = GetPlayerWeaponSlot(client, 1);
			if(iSlot > MaxClients)
			{
				if(this.iClip1 != -1)
					SetEntProp(iSlot, Prop_Send, "m_iClip1", this.iClip1);
				
				if(this.iWeaponSkin1 > 0)
					SetEntProp(iSlot, Prop_Send, "m_nSkin", this.iWeaponSkin1);
				
				bGiven = true;
			}
		}

		if(this.sSlot2[0] != '\0')
		{
			vCheatCommand(client, "give", this.sSlot2);

			if(GetPlayerWeaponSlot(client, 2) > MaxClients)
				bGiven = true;
		}

		if(this.sSlot3[0] != '\0')
		{
			vCheatCommand(client, "give", this.sSlot3);
	
			if(GetPlayerWeaponSlot(client, 3) > MaxClients)
				bGiven = true;
		}

		if(this.sSlot4[0] != '\0')
		{
			vCheatCommand(client, "give", this.sSlot4);
	
			if(GetPlayerWeaponSlot(client, 4) > MaxClients)
				bGiven = true;
		}
		
		if(bGiven == true)
		{
			if(this.sActive[0] != '\0')
				FakeClientCommand(client, "use %s", this.sActive);
		}
		else
			vCheatCommand(client, "give", "pistol");
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

int iGetOrSetPlayerAmmo(int client, int iWeapon, int iAmmo = -1)
{
	int m_iPrimaryAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if(m_iPrimaryAmmoType != -1)
	{
		if(iAmmo != -1)
			SetEntProp(client, Prop_Send, "m_iAmmo", iAmmo, _, m_iPrimaryAmmoType);
		else
			return GetEntProp(client, Prop_Send, "m_iAmmo", _, m_iPrimaryAmmoType);
	}

	return 0;
}

// https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
bool bAttemptRespawnPZ(int client)
{
	int i = 1;
	int iCount;
	int iClass;
	int iSpawnCounts[6];
	for(; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && 1 <= (iClass = GetEntProp(i, Prop_Send, "m_zombieClass")) <= 6)
		{
			iCount++;
			iSpawnCounts[iClass - 1]++;
		}
	}

	SetRandomSeed(GetTime());

	if(iCount >= g_iSILimit)
	{
		CPrintToChat(client, "{olive}当前存活特感数量{default}-> {red}%d {olive}达到设置总数上限{default}-> {red}%d {olive}将以随机特感类型复活", iCount, g_iSILimit);
		return bRespawnPZ(client, GetRandomInt(1, 6));
	}

	int iTotalWeight;
	int iStandardizedWeight;
	int iTempSpawnWeights[6];
	for(i = 0; i < 6; i++)
	{
		iTempSpawnWeights[i] = iSpawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - iSpawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
		iTotalWeight += iTempSpawnWeights[i];
	}

	static float fIntervalEnds[6];
	float fUnit = 1.0 / iTotalWeight;
	for(i = 0; i < 6; i++)
	{
		if(iTempSpawnWeights[i] < 0)
			continue;

		iStandardizedWeight += iTempSpawnWeights[i];
		fIntervalEnds[i] = iStandardizedWeight * fUnit;
	}

	iClass = -1;
	float fRandom = GetRandomFloat(0.0, 1.0);
	for(i = 0; i < 6; i++)
	{
		if(iTempSpawnWeights[i] <= 0)
			continue;

		if(fIntervalEnds[i] < fRandom)
			continue;

		iClass = i;
		break;
	}

	if(iClass == -1)
	{
		CPrintToChat(client, "当前无满足要求的特感类型可供复活 将以随机特感类型复活");
		return bRespawnPZ(client, GetRandomInt(1, 6));
	}

	return bRespawnPZ(client, iClass + 1);
}

bool bRespawnPZ(int client, int iZombieClass)
{
	/**老方法
	FakeClientCommand(client, "spec_next"); // 相比于手动获取玩家位置传送，更省力和节约资源的方法
	g_iSpawnablePZ = client;
	vCheatCommand(client, "z_spawn_old", g_sZombieClass[iZombieClass - 1]);
	g_iSpawnablePZ = 0;*/

	SDKCall(g_hSDKSetPreSpawnClass, client, iZombieClass);
	SDKCall(g_hSDKState_Transition, client, 8);
	return IsPlayerAlive(client);
}

// ------------------------------------------------------------------------------
//SDKCall
void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iOffMelee = hGameData.GetOffset("CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenMeleeWeapon");
	if(g_iOffMelee == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenMeleeWeapon");

	g_iOffHangingPreTemp = hGameData.GetOffset("CTerrorPlayer::OnRevived::HangingPreTempHealth");
	if(g_iOffHangingPreTemp == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnRevived::HangingPreTempHealth");

	g_iOffHangingPreReal = hGameData.GetOffset("CTerrorPlayer::OnRevived::HangingPreRealHealth");
	if(g_iOffHangingPreReal == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnRevived::HangingPreRealHealth");

	g_iOffHangingCurrent = hGameData.GetOffset("CTerrorPlayer::OnRevived::HangingCurrentHealth");
	if(g_iOffHangingCurrent == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnRevived::HangingCurrentHealth");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnRevived") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::OnRevived");
	g_hSDKOnRevived = EndPrepSDKCall();
	if(g_hSDKOnRevived == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::OnRevived");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::IsInStasis") == false) // https://forums.alliedmods.net/showthread.php?t=302140
		SetFailState("Failed to find offset: CBaseEntity::IsInStasis");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKIsInStasis = EndPrepSDKCall();
	if(g_hSDKIsInStasis == null)
		SetFailState("Failed to create SDKCall: CBaseEntity::IsInStasis");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Tank::LeaveStasis") == false) // https://forums.alliedmods.net/showthread.php?t=319342
		SetFailState("Failed to find signature: Tank::LeaveStasis");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKLeaveStasis = EndPrepSDKCall();
	if(g_hSDKLeaveStasis == null)
		SetFailState("Failed to create SDKCall: Tank::LeaveStasis");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCSPlayer::State_Transition") == false)
		SetFailState("Failed to find signature: CCSPlayer::State_Transition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKState_Transition = EndPrepSDKCall();
	if(g_hSDKState_Transition == null)
		SetFailState("Failed to create SDKCall: CCSPlayer::State_Transition");
		
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::MaterializeFromGhost") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::MaterializeFromGhost");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKMaterializeFromGhost = EndPrepSDKCall();
	if(g_hSDKMaterializeFromGhost == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::MaterializeFromGhost");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SetClass") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::SetClass");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKSetClass = EndPrepSDKCall();
	if(g_hSDKSetClass == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::SetClass");
	
	StartPrepSDKCall(SDKCall_Static);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CBaseAbility::CreateForPlayer") == false)
		SetFailState("Failed to find signature: CBaseAbility::CreateForPlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCreateForPlayer = EndPrepSDKCall();
	if(g_hSDKCreateForPlayer == null)
		SetFailState("Failed to create SDKCall: CBaseAbility::CreateForPlayer");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::CleanupPlayerState") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::CleanupPlayerState");
	g_hSDKCleanupPlayerState = EndPrepSDKCall();
	if(g_hSDKCleanupPlayerState == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::CleanupPlayerState");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverZombieBot") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::TakeOverZombieBot");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDKTakeOverZombieBot = EndPrepSDKCall();
	if(g_hSDKTakeOverZombieBot == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::TakeOverZombieBot");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::ReplaceWithBot") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::ReplaceWithBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDKReplaceWithBot = EndPrepSDKCall();
	if(g_hSDKReplaceWithBot == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::ReplaceWithBot");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SetPreSpawnClass") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::SetPreSpawnClass");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKSetPreSpawnClass = EndPrepSDKCall();
	if(g_hSDKSetPreSpawnClass == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::SetPreSpawnClass");
	
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

	StartPrepSDKCall(SDKCall_Static);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::HasPlayerControlledZombies") == false)
		SetFailState("Failed to find signature: CTerrorGameRules::HasPlayerControlledZombies");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKHasPlayerControlledZombies = EndPrepSDKCall();
	if(g_hSDKHasPlayerControlledZombies == null)
		SetFailState("Failed to create SDKCall: CTerrorGameRules::HasPlayerControlledZombies");

	g_dOnEnterGhostState = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::OnEnterGhostState");
	if(g_dOnEnterGhostState == null)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::OnEnterGhostState");

	g_dMaterializeFromGhost= DynamicDetour.FromConf(hGameData, "CTerrorPlayer::MaterializeFromGhost");
	if(g_dMaterializeFromGhost== null)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::MaterializeFromGhost");

	g_dPlayerZombieAbortControl = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::PlayerZombieAbortControl");
	if(g_dPlayerZombieAbortControl == null)
		SetFailState("Failed to create DynamicDetour: CTerrorPlayer::PlayerZombieAbortControl");

	g_bIsLinuxOS = hGameData.GetOffset("OS") == 2;
	if(g_bIsLinuxOS)
	{
		g_dSpawnablePZScanProtect[0] = DynamicDetour.FromConf(hGameData, "ForEachTerrorPlayer<SpawnablePZScan>");
		if(g_dSpawnablePZScanProtect[0] == null)
			SetFailState("Failed to create DynamicDetour: ForEachTerrorPlayer<SpawnablePZScan>");
	}
	else
	{
		g_dSpawnablePZScanProtect[0] = DynamicDetour.FromConf(hGameData, "Script_ZSpawn");
		if(g_dSpawnablePZScanProtect[0] == null)
			SetFailState("Failed to create DynamicDetour: Script_ZSpawn");

		g_dSpawnablePZScanProtect[1] = DynamicDetour.FromConf(hGameData, "z_spawn_old");
		if(g_dSpawnablePZScanProtect[1] == null)
			SetFailState("Failed to create DynamicDetour: z_spawn_old");

		g_dSpawnablePZScanProtect[2] = DynamicDetour.FromConf(hGameData, "z_spawn");
		if(g_dSpawnablePZScanProtect[2] == null)
			SetFailState("Failed to create DynamicDetour: z_spawn");
	}

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

void vSetInfectedGhost(int client, bool bSavePos = false)
{
	if(GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_isGhost") == 0)
	{
		static float vPos[3];
		static float vAng[3];
		static float vVel[3];

		if(bSavePos)
		{
			GetClientAbsOrigin(client, vPos);
			GetClientEyeAngles(client, vAng);
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		}

		SDKCall(g_hSDKState_Transition, client, 8);

		if(bSavePos)
			TeleportEntity(client, vPos, vAng, vVel);
	}
}

void vSetZombieClass(int client, int iZombieClass)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0);
	if(iWeapon != -1)
	{
		RemovePlayerItem(client, iWeapon);
		RemoveEdict(iWeapon);
	}

	int iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
		RemoveEdict(iAbility);

	SDKCall(g_hSDKSetClass, client, iZombieClass);

	iAbility = SDKCall(g_hSDKCreateForPlayer, client);
	if(iAbility != -1)
		SetEntPropEnt(client, Prop_Send, "m_customAbility", iAbility);
}

int iTakeOverZombieBot(int client, int iZombieBot)
{
	AcceptEntityInput(client, "ClearParent");
	SDKCall(g_hSDKTakeOverZombieBot, client, iZombieBot);
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

void vRoundRespawn(int client)
{
	vStatsConditionPatch(true);
	SDKCall(g_hSDKRoundRespawn, client);
	vStatsConditionPatch(false);
}

// https://forums.alliedmods.net/showthread.php?t=323220
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

void vToggleDetours(bool bEnable)
{
	static bool bEnabled;
	if(!bEnabled && bEnable)
	{
		bEnabled = true;

		if(!g_dOnEnterGhostState.Enable(Hook_Pre, mreOnEnterGhostStatePre))
			SetFailState("Failed to detour pre: CTerrorPlayer::OnEnterGhostState");
		
		if(!g_dOnEnterGhostState.Enable(Hook_Post, mreOnEnterGhostStatePost))
			SetFailState("Failed to detour post: CTerrorPlayer::OnEnterGhostState");
			
		if(!g_dMaterializeFromGhost.Enable(Hook_Pre, mreMaterializeFromGhostPre))
			SetFailState("Failed to detour pre: CTerrorPlayer::MaterializeFromGhost");
		
		if(!g_dMaterializeFromGhost.Enable(Hook_Post, mreMaterializeFromGhostPost))
			SetFailState("Failed to detour post: CTerrorPlayer::MaterializeFromGhost");
			
		if(!g_dPlayerZombieAbortControl.Enable(Hook_Pre, mrePlayerZombieAbortControlPre))
			SetFailState("Failed to detour pre: CTerrorPlayer::PlayerZombieAbortControl");
		
		if(!g_dPlayerZombieAbortControl.Enable(Hook_Post, mrePlayerZombieAbortControlPost))
			SetFailState("Failed to detour post: CTerrorPlayer::PlayerZombieAbortControl");

		if(g_bIsLinuxOS)
		{
			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[0].Enable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre)))
				SetFailState("Failed to detour pre: ForEachTerrorPlayer<SpawnablePZScan>");
		
			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[0].Enable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost)))
				SetFailState("Failed to detour post: ForEachTerrorPlayer<SpawnablePZScan>");
		}
		else
		{
			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[0].Enable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre)))
				SetFailState("Failed to detour pre: Script_ZSpawn");
		
			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[0].Enable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost)))
				SetFailState("Failed to detour post: Script_ZSpawn");

			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[1].Enable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre)))
				SetFailState("Failed to detour pre: z_spawn_old");
		
			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[1].Enable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost)))
				SetFailState("Failed to detour post: z_spawn_old");

			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[2].Enable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre)))
				SetFailState("Failed to detour pre: z_spawn");
		
			if(!(g_bIsSpawnablePZSupported = g_dSpawnablePZScanProtect[2].Enable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost)))
				SetFailState("Failed to detour post: z_spawn");
		}
	}
	else if(bEnabled && !bEnable)
	{
		bEnabled = false;

		g_bIsSpawnablePZSupported = false;

		if(!g_dOnEnterGhostState.Disable(Hook_Pre, mreOnEnterGhostStatePre) || !g_dOnEnterGhostState.Disable(Hook_Post, mreOnEnterGhostStatePost))
			SetFailState("Failed to disable detour: CTerrorPlayer::OnEnterGhostState");
		
		if(!g_dMaterializeFromGhost.Disable(Hook_Pre, mreMaterializeFromGhostPre) || !g_dMaterializeFromGhost.Disable(Hook_Post, mreMaterializeFromGhostPost))
			SetFailState("Failed to disable detour: CTerrorPlayer::MaterializeFromGhost");
		
		if(!g_dPlayerZombieAbortControl.Disable(Hook_Pre, mrePlayerZombieAbortControlPre) || !g_dPlayerZombieAbortControl.Disable(Hook_Post, mrePlayerZombieAbortControlPost))
			SetFailState("Failed to disable detour: CTerrorPlayer::PlayerZombieAbortControl");

		if(g_bIsLinuxOS)
		{
			if(!g_dSpawnablePZScanProtect[0].Disable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre) || !g_dSpawnablePZScanProtect[0].Disable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost))
				SetFailState("Failed to disable detour: ForEachTerrorPlayer<SpawnablePZScan>");
		}
		else
		{
			if(!g_dSpawnablePZScanProtect[0].Disable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre) || !g_dSpawnablePZScanProtect[0].Disable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost))
				SetFailState("Failed to disable detour: Script_ZSpawn");

			if(!g_dSpawnablePZScanProtect[1].Disable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre) || !g_dSpawnablePZScanProtect[1].Disable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost))
				SetFailState("Failed to disable detour: z_spawn_old");

			if(!g_dSpawnablePZScanProtect[2].Disable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre) || !g_dSpawnablePZScanProtect[2].Disable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost))
				SetFailState("Failed to disable detour: z_spawn");
		}
	}
}

MRESReturn mreOnEnterGhostStatePre(int pThis)
{
	if(!bIsRoundStarted())
		return MRES_Supercede; // 阻止死亡状态下的特感玩家在团灭后下一回合开始前进入Ghost State
	
	return MRES_Ignored;
}

MRESReturn mreOnEnterGhostStatePost(int pThis)
{
	if(g_esPlayer[pThis].iMaterialized == 0 && !IsFakeClient(pThis))
		RequestFrame(OnNextFrame_EnterGhostState, GetClientUserId(pThis));
	
	return MRES_Ignored;
}

MRESReturn mreMaterializeFromGhostPre(int pThis)
{
	g_bOnMaterializeFromGhost = true;

	if(!IsFakeClient(pThis) && g_esPlayer[pThis].fBugExploitTime[1] > GetGameTime())
		return MRES_Supercede;

	return MRES_Ignored;
}

MRESReturn mreMaterializeFromGhostPost(int pThis)
{
	g_esPlayer[pThis].iMaterialized++;
	g_bOnMaterializeFromGhost = false;

	if(!IsFakeClient(pThis))
	{
		g_esPlayer[pThis].fBugExploitTime[0] = GetGameTime() + 1.5;
		if(g_esPlayer[pThis].iMaterialized == 1 && g_iPZRespawnTime > 0 && g_iPZPunishTime > 0 && g_esPlayer[pThis].bClassCmdUsed && GetEntProp(pThis, Prop_Send, "m_zombieClass") != 8)
			CPrintToChat(pThis, "{olive}下次重生时间 {default}-> {red}+%d秒", g_iPZPunishTime);
	}

	return MRES_Ignored;
}

MRESReturn mrePlayerZombieAbortControlPre(int pThis)
{
	if(!IsFakeClient(pThis) && g_esPlayer[pThis].fBugExploitTime[0] > GetGameTime())
		return MRES_Supercede;

	return MRES_Ignored;
}

MRESReturn mrePlayerZombieAbortControlPost(int pThis)
{
	if(!IsFakeClient(pThis))
		g_esPlayer[pThis].fBugExploitTime[1] = GetGameTime() + 1.5;

	return MRES_Ignored;
}

MRESReturn mreForEachTerrorPlayerSpawnablePZScanPre()
{
	vSpawnablePZScanProtect(0);
	return MRES_Ignored;
}

MRESReturn mreForEachTerrorPlayerSpawnablePZScanPost()
{
	vSpawnablePZScanProtect(1);
	return MRES_Ignored;
}

void OnNextFrame_EnterGhostState(int client)
{
	if(g_iControlled == 0 && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(g_esPlayer[client].iEnteredGhost == 0)
		{
			if(bCheckClientAccess(client, 0) == true)
				CPrintToChat(client, "{default}聊天栏输入 {olive}!team2 {default}可切换回{blue}生还者");
				
			if(bCheckClientAccess(client, 4) == true)
				CPrintToChat(client, "{red}灵魂状态下{default} 按下 {red}[鼠标中键] {default}可以快速切换特感");
		}

		vClassSelectionMenu(client);
		g_esPlayer[client].iEnteredGhost++;
	
		if(g_iPZSuicideTime > 0)
			g_esPlayer[client].fSuicideStartTime = GetEngineTime();
	}
}

void vClassSelectionMenu(int client)
{
	if((g_iAutoDisplayMenu == -1 || g_esPlayer[client].iEnteredGhost < g_iAutoDisplayMenu) && bCheckClientAccess(client, 5) == true)
	{
		vDisplayClassMenu(client);
		EmitSoundToClient(client, SOUND_CLASSMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
}

static void vSpawnablePZScanProtect(int iState)
{
	static int i;
	static bool bResetGhost[MAXPLAYERS + 1];
	static bool bResetLifeState[MAXPLAYERS + 1];

	switch(iState)
	{
		case 0: 
		{
			for(i = 1; i <= MaxClients; i++)
			{
				if(i == g_iSpawnablePZ || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3)
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

		case 1: 
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
	}
}
