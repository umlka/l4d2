#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
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

#define GAMEDATA 			"controll_zombies"
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

enum
{
	iClip = 0,
	iClip1,
	iAmmo,
	iUpGrade,
	iUpAmmo,
	iSkin0,
	iSkin1,
	iHealth,
	iHealthTemp,
	iHealthTime,
	iReviveCount,
	iGoingToDie,
	iThirdStrike,
	iRecorded
};

enum
{
	Slot0 = 0,
	Slot1,
	Slot2,
	Slot3,
	Slot4
};

static const char g_sZombieClass[6][16] =
{
	"smoker",
	"boomer",
	"hunter",
	"spitter",
	"jockey", 
	"charger"
};

char g_sGameMode[32];
char g_sWeaponInfo[MAXPLAYERS + 1][5][64];

Handle g_hSDK_Call_IsInStasis;
Handle g_hSDK_Call_LeaveStasis;
Handle g_hSDK_Call_ZombieAbortControl;
Handle g_hSDK_Call_State_Transition;
Handle g_hSDK_Call_SetClass;
Handle g_hSDK_Call_CreateAbility;
Handle g_hSDK_Call_TakeOverZombieBot;
Handle g_hSDK_Call_RoundRespawn;
Handle g_hSDK_Call_SetHumanSpec;
Handle g_hSDK_Call_TakeOverBot;
Handle g_hSDK_Call_HasPlayerControlledZombies;

Handle g_hPZRespawnTimer[MAXPLAYERS + 1];
Handle g_hPZSuicideTimer[MAXPLAYERS + 1];

ConVar g_hGameMode;
ConVar g_hCoopSphereFix;
ConVar g_hMaxTankPlayer;
ConVar g_hAllowSurvuivorLimit; 
ConVar g_hSurvuivorAllowChance;
ConVar g_hSbAllBotGame; 
ConVar g_hAllowAllBotSurvivorTeam;
ConVar g_hSurvivorMaxIncapacitatedCount;
ConVar g_hDirectorNoSpecials; 
ConVar g_hExchangeTeam;
ConVar g_hPZSuicideTime;
ConVar g_hPZRespawnTime;
ConVar g_hPZPunishTime;
ConVar g_hPZPunishHealth;
ConVar g_hAutoDisplayMenu;
ConVar g_hPZTeamLimit;
ConVar g_hCmdCooldownTime;
ConVar g_hCmdEnterCooling;
ConVar g_hPZChangeTeamTo;
ConVar g_hGlowColor[4];
ConVar g_hAccessAdminFlags;
ConVar g_hAdminImmunityLevels;
ConVar g_hSILimit;
ConVar g_hSpawnLimits[6];
ConVar g_hSpawnWeights[6];

bool g_bHasAnySurvivorLeftSafeArea;
bool g_bHasPlayerControlledZombies;
bool g_bSbAllBotGame; 
bool g_bAllowAllBotSurvivorTeam;
bool g_bDirectorNoSpecials;
bool g_bExchangeTeam;
bool g_bPZPunishHealth;
bool g_bIsPlayerBP[MAXPLAYERS + 1];
bool g_bUsedClassCmd[MAXPLAYERS + 1];

int g_iSILimit;
int g_iPZOnSpawn;
int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iSurvivorMaxIncapacitatedCount;
int g_iAllowSurvuivorLimit;
int g_iMaxTankPlayer;
int g_iPZRespawnTime;
int g_iPZPunishTime;
int g_iPZTeamLimit;
int g_iPZChangeTeamTo;
int g_iAutoDisplayMenu;
int g_iCmdEnterCooling;
int g_iGlowColor[4];
int g_iSpawnLimits[6];
int g_iSpawnWeights[6];
int g_iSpawnCounts[6];
int g_iAccessAdminFlags[6];
int g_iAdminImmunityLevels[6];

int g_iTankBot[MAXPLAYERS + 1];
int g_iDisplayed[MAXPLAYERS + 1];
int g_iPZSpawned[MAXPLAYERS + 1];
int g_iPlayerBot[MAXPLAYERS + 1];
int g_iBotPlayer[MAXPLAYERS + 1];
int g_iLastTeamId[MAXPLAYERS + 1];
int g_iModelIndex[MAXPLAYERS + 1];
int g_iModelEntRef[MAXPLAYERS + 1];
int g_iWeaponInfo[MAXPLAYERS + 1][14];
int g_iPZRespawnCountdown[MAXPLAYERS + 1];

float g_fSurvuivorAllowChance;
float g_fPZSuicideTime;
float g_fCmdCooldownTime;
float g_fCmdLastUsedTime[MAXPLAYERS + 1];

bool g_bMutantTanks = false;

public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "mutant_tanks") == 0)
		g_bMutantTanks = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if(strcmp(name, "mutant_tanks") == 0)
		g_bMutantTanks = false;
}

public Plugin myinfo = 
{
	name = "Controll Zombies In Co-op",
	author = "sorallll",
	description = "",
	version = "",
	url = "https://steamcommunity.com/id/sorallll"
}

public void OnPluginStart()
{
	LoadGameData();

	g_hMaxTankPlayer = CreateConVar("cz_max_tank_player", "1" , "坦克玩家达到多少后插件将不再控制玩家接管(0=不接管坦克)", CVAR_FLAGS, true, 0.0);
	g_hAllowSurvuivorLimit = CreateConVar("cz_allow_survivor_limit", "3" , "至少有多少名正常生还者(未被控,未倒地,未死亡)时,才允许玩家接管坦克", CVAR_FLAGS, true, 0.0);
	g_hSurvuivorAllowChance = CreateConVar("cz_survivor_allow_chance", "0.0" , "准备叛变的玩家数量为0时,自动抽取生还者和感染者玩家的几率(排除闲置旁观玩家)(0.0=不自动抽取)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hExchangeTeam = CreateConVar("cz_exchange_team", "1" , "特感玩家杀死生还者玩家后是否互换队伍?(0=否,1=是)", CVAR_FLAGS);
	g_hPZSuicideTime = CreateConVar("cz_pz_suicide_time", "300.0" , "特感玩家复活后自动处死的时间(0=不会处死复活后的特感玩家)", CVAR_FLAGS, true, 0.0);
	g_hPZRespawnTime = CreateConVar("cz_pz_respawn_time", "15" , "特感玩家自动复活时间(0=插件不会接管特感玩家的复活)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishTime = CreateConVar("cz_pz_punish_time", "10" , "特感玩家在ghost状态下切换特感类型后下次复活延长的时间(0=插件不会延长复活时间)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishHealth = CreateConVar("cz_pz_punish_health", "1" , "特感玩家在ghost状态下切换特感类型后血量是否减半(0=插件不会减半血量)", CVAR_FLAGS);
	g_hAutoDisplayMenu = CreateConVar("cz_atuo_display_menu", "1" , "在感染玩家死亡重生后向其显示更改类型的菜单?(0=不显示,小于0=每次都显示,大于0=每回合总计显示的最大次数)", CVAR_FLAGS);
	g_hPZTeamLimit = CreateConVar("cz_pz_team_limit", "-1" , "感染玩家数量达到多少后将限制使用sm_team3命令(0=不限制,小于0=感染玩家不能超过生还玩家,大于0=感染玩家不能超过该值)", CVAR_FLAGS);
	g_hCmdCooldownTime = CreateConVar("cz_cmd_cooldown_time", "60.0" , "sm_team2,sm_team3两个命令的冷却时间(0.0-无冷却)", CVAR_FLAGS, true, 0.0);
	g_hCmdEnterCooling = CreateConVar("cz_return_enter_cooling", "31" , "什么情况下sm_team2,sm_team3命令会进入冷却(1=使用其中一个命令,2=坦克玩家掉控,4=坦克玩家死亡,8=坦克玩家未及时重生,16=特感玩家杀掉生还者玩家,31=所有)", CVAR_FLAGS);
	g_hPZChangeTeamTo = CreateConVar("cz_pz_change_team_to", "0" , "换图,过关以及任务失败时是否自动将特感玩家切换到哪个队伍?(0=不切换,1=旁观者,2=生还者)", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_hGlowColor[COLOR_NORMAL] = CreateConVar("cz_survivor_color_normal", "0 180 0" , "特感玩家看到的正常状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_INCAPA] = CreateConVar("cz_survivor_color_incapacitated", "180 0 0" , "特感玩家看到的倒地状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_BLACKW] = CreateConVar("cz_survivor_color_blackwhite", "255 255 255" , "特感玩家看到的黑白状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_VOMITED] = CreateConVar("cz_survivor_color_nowit", "155 0 180" , "特感玩家看到的被Boomer喷或炸中过的生还者发光颜色", CVAR_FLAGS);
	g_hAccessAdminFlags = CreateConVar("cz_admin_flags", "z;;;;;z" , "哪些标志能绕过sm_team4,sm_team2,sm_team3,sm_bp,sm_class,鼠标中键重置冷却的使用限制(留空表示所有人都不会被限制)", CVAR_FLAGS);
	g_hAdminImmunityLevels = CreateConVar("cz_admin_immunitylevels", "99;99;99;99;99;99" , "要达到什么免疫级别才能绕过sm_team4,sm_team2,sm_team3,sm_bp,sm_class,鼠标中键重置冷的使用限制", CVAR_FLAGS);

	//https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
	g_hSILimit = CreateConVar("cz_si_limit", "24", "同时存在的最大特感数量", CVAR_FLAGS, true, 1.0, true, 28.0);
	g_hSpawnLimits[SI_SMOKER] = CreateConVar("cz_smoker_limit",	"6", "smoker同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 14.0);
	g_hSpawnLimits[SI_BOOMER] = CreateConVar("cz_boomer_limit",	"6", "boomer同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 14.0);
	g_hSpawnLimits[SI_HUNTER] = CreateConVar("cz_hunter_limit",	"2", "hunter同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 14.0);
	g_hSpawnLimits[SI_SPITTER] = CreateConVar("cz_spitter_limit", "6", "spitter同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 14.0);
	g_hSpawnLimits[SI_JOCKEY] = CreateConVar("cz_jockey_limit",	"2", "jockey同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 14.0);
	g_hSpawnLimits[SI_CHARGER] = CreateConVar("cz_charger_limit", "2", "charger同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 14.0);
	g_hSpawnWeights[SI_SMOKER] = CreateConVar("cz_smoker_weight", "75", "smoker产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_BOOMER] = CreateConVar("cz_boomer_weight", "100", "boomer产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_HUNTER] = CreateConVar("cz_hunter_weight", "50", "hunter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_SPITTER] = CreateConVar("cz_spitter_weight", "75", "spitter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_JOCKEY] = CreateConVar("cz_jockey_weight", "30", "jockey产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_CHARGER] = CreateConVar("cz_charger_weight", "10", "charger产生比重", CVAR_FLAGS, true, 0.0);

	//AutoExecConfig(true, "controll_zombies");
	//想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(ConVarChanged_GameMode);
	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hSbAllBotGame.AddChangeHook(ConVarChanged);
	g_hAllowAllBotSurvivorTeam = FindConVar("allow_all_bot_survivor_team");
	g_hAllowAllBotSurvivorTeam.AddChangeHook(ConVarChanged);
	g_hSurvivorMaxIncapacitatedCount = FindConVar("survivor_max_incapacitated_count");
	g_hSurvivorMaxIncapacitatedCount.AddChangeHook(ConVarChanged_Color);
	
	g_hDirectorNoSpecials = FindConVar("director_no_specials");
	g_hDirectorNoSpecials.AddChangeHook(ConVarChanged);

	g_hMaxTankPlayer.AddChangeHook(ConVarChanged);
	g_hAllowSurvuivorLimit.AddChangeHook(ConVarChanged);
	g_hSurvuivorAllowChance.AddChangeHook(ConVarChanged);
	g_hExchangeTeam.AddChangeHook(ConVarChanged);
	g_hPZSuicideTime.AddChangeHook(ConVarChanged);
	g_hPZRespawnTime.AddChangeHook(ConVarChanged);
	g_hPZPunishTime.AddChangeHook(ConVarChanged);
	g_hPZPunishHealth.AddChangeHook(ConVarChanged);
	g_hAutoDisplayMenu.AddChangeHook(ConVarChanged);
	g_hPZTeamLimit.AddChangeHook(ConVarChanged);
	g_hCmdCooldownTime.AddChangeHook(ConVarChanged);
	g_hCmdEnterCooling.AddChangeHook(ConVarChanged);
	g_hPZChangeTeamTo.AddChangeHook(ConVarChanged);

	int i;
	for(i = 0; i < 4; i++)
		g_hGlowColor[i].AddChangeHook(ConVarChanged_Color);

	g_hAccessAdminFlags.AddChangeHook(ConVarChanged_Admin);
	g_hAdminImmunityLevels.AddChangeHook(ConVarChanged_Admin);

	g_hSILimit.AddChangeHook(ConVarChanged_Spawn);
	for(i = 0; i < 6; i++)
	{
		g_hSpawnLimits[i].AddChangeHook(ConVarChanged_Spawn);
		g_hSpawnWeights[i].AddChangeHook(ConVarChanged_Spawn);
	}
	
	//防止战役模式加入特感方时出现紫黑色网格球体以及客户端控制台"Material effects/spawn_sphere has bad reference count 0 when being bound"报错
	g_hCoopSphereFix = FindConVar("z_scrimmage_sphere");
	g_hCoopSphereFix.SetBounds(ConVarBound_Lower, true, 0.0);
	g_hCoopSphereFix.SetBounds(ConVarBound_Upper, true, 0.0);
	g_hCoopSphereFix.SetInt(0);

	//https://wiki.alliedmods.net/Events_(SourceMod_Scripting)#Hooking_Events 防止某些插件在Pre挂钩上面阻止事件广播，导致Post挂钩监听不到事件触发
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_Pre);
	HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("tank_frustrated", Event_TankFrustrated, EventHookMode_Pre);
	HookEvent("bot_player_replace", Event_ClientReplace, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_ClientReplace, EventHookMode_Pre);

	AddCommandListener(CommandListener_Spawn, "z_add");
	AddCommandListener(CommandListener_Spawn, "z_spawn");
	AddCommandListener(CommandListener_Spawn, "z_spawn_old");
	AddCommandListener(CommandListener_CallVote, "callvote");

	RegConsoleCmd("sm_team4", CmdTeam4, "切换到Team 4.");
	RegConsoleCmd("sm_team2", CmdTeam2, "切换到Team 2.");
	RegConsoleCmd("sm_team3", CmdTeam3, "切换到Team 3.");
	RegConsoleCmd("sm_bp", CmdBP, "叛变为坦克.");
	RegConsoleCmd("sm_class", CmdChangeClass, "更改特感类型.");
}

public void OnPluginEnd()
{
	g_hCoopSphereFix.SetBounds(ConVarBound_Lower, false);
	g_hCoopSphereFix.SetBounds(ConVarBound_Upper, false);
	g_hCoopSphereFix.RestoreDefault();
	for(int i = 1; i <= MaxClients; i++)
		RemoveSurvivorModelGlow(i);
}

public void OnConfigsExecuted()
{
	GetModeCvars();
	GetCvars();
	GetColorCvars();
	GetSpawnCvars();
	GetAdminCvars();
}

public void ConVarChanged_GameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetModeCvars();
}

void GetModeCvars()
{
	g_hGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));
	if(g_bHasPlayerControlledZombies != SDKCall(g_hSDK_Call_HasPlayerControlledZombies))
	{
		if(SDKCall(g_hSDK_Call_HasPlayerControlledZombies) == true) //coop->versus
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) == 2)
					RemoveSurvivorModelGlow(i);
			}
		}
		else if(HasPlayerZombie()) //versus->coop
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(!IsClientInGame(i))
					continue;

				switch(GetClientTeam(i))
				{
					case 2:
						CreateSurvivorModelGlow(i);

					case 3:
					{
						if(!IsFakeClient(i))
						{
							//ChangeClientTeam(i, 1);
							//ChangeClientTeam(i, 3);
							CPrintToChat(i, "如果看不到[{red}特感梯子{default}]，请先[{olive}切换{default}]到其他[{red}团队{default}]再切换回来刷新[{olive}显示状态{default}]");
						}
					}
				}
			}
		}
	}

	g_bHasPlayerControlledZombies = SDKCall(g_hSDK_Call_HasPlayerControlledZombies);
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iMaxTankPlayer = g_hMaxTankPlayer.IntValue;
	g_iAllowSurvuivorLimit = g_hAllowSurvuivorLimit.IntValue;
	g_fSurvuivorAllowChance = g_hSurvuivorAllowChance.FloatValue;
	g_bSbAllBotGame = g_hSbAllBotGame.BoolValue;
	g_bAllowAllBotSurvivorTeam = g_hAllowAllBotSurvivorTeam.BoolValue;
	g_bDirectorNoSpecials = g_hDirectorNoSpecials.BoolValue;
	g_bExchangeTeam = g_hExchangeTeam.BoolValue;
	g_fPZSuicideTime = g_hPZSuicideTime.FloatValue;
	g_iPZRespawnTime = g_hPZRespawnTime.IntValue;
	g_iPZPunishTime = g_hPZPunishTime.IntValue;
	g_bPZPunishHealth = g_hPZPunishHealth.BoolValue;
	g_iAutoDisplayMenu = g_hAutoDisplayMenu.IntValue;
	g_iPZTeamLimit = g_hPZTeamLimit.IntValue;
	g_fCmdCooldownTime = g_hCmdCooldownTime.FloatValue;
	g_iCmdEnterCooling = g_hCmdEnterCooling.IntValue;
	g_iPZChangeTeamTo = g_hPZChangeTeamTo.IntValue;
}

public void ConVarChanged_Color(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetColorCvars();
}

void GetColorCvars()
{
	g_iSurvivorMaxIncapacitatedCount = g_hSurvivorMaxIncapacitatedCount.IntValue;

	for(int i; i < 4; i++)
		g_iGlowColor[i] = GetColor(g_hGlowColor[i]);
		
	if(g_bHasPlayerControlledZombies == false && HasPlayerZombie())
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsValidEntRef(g_iModelEntRef[i]))
				SetGlowColor(i);
		}
	}
}

void SetGlowColor(int client)
{
	static int iColorType;
	if(GetEntProp(g_iModelEntRef[client], Prop_Send, "m_glowColorOverride") != g_iGlowColor[(iColorType = GetColorType(client))])
		SetEntProp(g_iModelEntRef[client], Prop_Send, "m_glowColorOverride", g_iGlowColor[iColorType]);
}

static int GetColorType(int client)
{
	if(GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurvivorMaxIncapacitatedCount)
		return 2;
	else
	{
		if(GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)
			return 1;
		else
		{
			if(GetEntPropFloat(client, Prop_Send, "m_vomitFadeStart") >= GetGameTime())
				return 3;
			else
				return 0;
		}
	}
}

int GetColor(ConVar hConVar)
{
	char sTemp[12];
	hConVar.GetString(sTemp, sizeof(sTemp));

	if(sTemp[0] == 0)
		return 0;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));

	if(color != 3)
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

public void ConVarChanged_Admin(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetAdminCvars();
}

void GetAdminCvars()
{
	GetAccessAdminFlags();
	GetAdminImmunityLevels();
}

void GetAccessAdminFlags()
{
	char sTemp[256];
	g_hAccessAdminFlags.GetString(sTemp, sizeof(sTemp));

	char sAccessAdminFlags[6][26];
	ExplodeString(sTemp, ";", sAccessAdminFlags, sizeof(sAccessAdminFlags), sizeof(sAccessAdminFlags[]));

	for(int i; i < 6; i++)
		g_iAccessAdminFlags[i] = ReadFlagString(sAccessAdminFlags[i]);
}

void GetAdminImmunityLevels()
{
	char sTemp[256];
	g_hAdminImmunityLevels.GetString(sTemp, sizeof(sTemp));

	char sAdminImmunityLevels[6][8];
	ExplodeString(sTemp, ";", sAdminImmunityLevels, sizeof(sAdminImmunityLevels), sizeof(sAdminImmunityLevels[]));

	for(int i; i < 6; i++)
		g_iAdminImmunityLevels[i] = StringToInt(sAdminImmunityLevels[i]);
}

bool CheckClientAccess(int client, int index)
{
	if(g_iAccessAdminFlags[index] == 0)
		return true;

	static int iFlagBits;
	if((iFlagBits = GetUserFlagBits(client)) & ADMFLAG_ROOT == 0 && iFlagBits & g_iAccessAdminFlags[index] == 0)
		return false;

	static char sSteamID[64];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return true;

	return admin.ImmunityLevel >= g_iAdminImmunityLevels[index];
}

public void ConVarChanged_Spawn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetSpawnCvars();
}

void GetSpawnCvars()
{
	g_iSILimit = g_hSILimit.IntValue;
	for(int i; i < 6; i++)
	{
		g_iSpawnLimits[i] = g_hSpawnLimits[i].IntValue;
		g_iSpawnWeights[i] = g_hSpawnWeights[i].IntValue;
	}
}

public Action CmdTeam4(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(CheckClientAccess(client, 0) == false)
	{
		PrintToChat(client, "无权使用该指令");
		return Plugin_Handled;
	}

	ChangeClientTeam(client, 4);
	return Plugin_Handled;
}

public Action CmdTeam2(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(CheckClientAccess(client, 1) == false)
	{
		//PrintToChat(client, "无权使用该指令");
		//return Plugin_Handled;
		float fCooldown = GetEngineTime() - g_fCmdLastUsedTime[client];
		if(fCooldown < g_fCmdCooldownTime)
		{
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_fCmdCooldownTime - fCooldown);
			return Plugin_Handled;
		}
	}

	if(GetClientTeam(client) != 3)
	{
		PrintToChat(client, "只有感染者才能使用该指令");
		return Plugin_Handled;
	}

	if(g_iCmdEnterCooling & (1 << 0))
		g_fCmdLastUsedTime[client] = GetEngineTime();
	ChangeTeamToSurvivor(client);
	return Plugin_Handled;
}

public Action CmdTeam3(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
		return Plugin_Handled;

	if(CheckClientAccess(client, 2) == false)
	{
		//PrintToChat(client, "无权使用该指令");
		//return Plugin_Handled;
		float fCooldown = GetEngineTime() - g_fCmdLastUsedTime[client];
		if(fCooldown < g_fCmdCooldownTime)
		{
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_fCmdCooldownTime - fCooldown);
			return Plugin_Handled;
		}

		//总玩家数小于等于2时不限制
		if(g_iPZTeamLimit != 0 && GetTeamPlayers() > 2)
		{
			int iTeam3 = GetTeamPlayers(3);
			int iTeam2 = GetTeamPlayers(2);
			if((g_iPZTeamLimit > 0 && iTeam3 >= g_iPZTeamLimit) || (g_iPZTeamLimit < 0 && iTeam3 >= iTeam2))
			{
				PrintToChat(client, "已到达感染玩家数量限制");
				return Plugin_Handled;
			}
		}
	}
		
	if(g_iCmdEnterCooling & (1 << 0))
		g_fCmdLastUsedTime[client] = GetEngineTime();
		
	TySaveWeapon(client);
	ChangeClientTeam(client, 3);
	return Plugin_Handled;
}

public Action CmdBP(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(CheckClientAccess(client, 3) == false)
	{
		PrintToChat(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if(g_bIsPlayerBP[client] == false)
	{
		g_bIsPlayerBP[client] = true;
		CPrintToChat(client, "已加入叛变列表");
		CPrintToChat(client, "再次输入该指令可退出叛变列表");
		CPrintToChat(client, "坦克出现后将会随机从叛变列表中抽取1人接管");
		CPrintToChat(client, "{olive}当前叛变玩家列表:");

		for(int i = 1; i <= MaxClients; i++)
		{
			if(g_bIsPlayerBP[i] && IsClientInGame(i) && !IsFakeClient(i))
				CPrintToChat(client, "-> {red}%N", i);
		}
	}
	else
	{
		g_bIsPlayerBP[client] = false;
		CPrintToChat(client, "已退出叛变列表");
	}

	return Plugin_Handled;
}

public Action CmdChangeClass(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if(CheckClientAccess(client, 4) == false)
	{
		PrintToChat(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if(GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost") == 0)
	{
		PrintToChat(client, "灵魂状态下的特感才能使用该指令");
		return Plugin_Handled;
	}

	if(g_iPZSpawned[client] != 1)
	{
		PrintToChat(client, "第一次灵魂状态下才能使用该指令");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		char sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		int iZombieClass;
		int iClass = GetZombieClass(sTargetClass);
		if(iClass == -1)
		{
			CPrintToChat(client, "{olive}!class{default}/{olive}sm_class {default}<{red}class{default}>.");
			CPrintToChat(client, "<{olive}class{default}> [ {red}smoker {default}| {red}boomer {default}| {red}hunter {default}| {red}spitter {default}| {red}jockey {default}| {red}charger {default}]");
		}
		else if(++iClass == (iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass")) || iZombieClass == 8)
			CPrintToChat(client, "目标特感类型与当前特感类型相同或当前特感类型为 {red}Tank");
		else
			SetZombieClassAndPunish(client, iClass);
	}
	else
		SelectZombieClassMenu(client);
	
	return Plugin_Handled;
}

void DisplayClassMenu(int client)
{
	Menu menu = new Menu(MenuHandler_DisplayClass);
	menu.SetTitle("!class付出一定代价更改特感类型?");
	menu.AddItem("yes", "是");
	menu.AddItem("no", "否");
	menu.ExitBackButton = false;
	menu.Display(client, 15);
}

public int MenuHandler_DisplayClass(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			if(param2 == 0 && GetClientTeam(client) == 3 && !IsFakeClient(client) && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
				SelectZombieClassMenu(client);
		}
		case MenuAction_End:
			delete menu;
	}
}

void SelectZombieClassMenu(int client)
{
	char sIndex[2];
	Menu menu = new Menu(MenuHandler_SelectZombieClass);
	menu.SetTitle("选择要切换的特感");
	int iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass") - 1;
	for(int i; i < 6; i++)
	{
		if(i != iZombieClass)
		{
			FormatEx(sIndex, sizeof(sIndex), "%d", i);
			menu.AddItem(sIndex, g_sZombieClass[i]);
		}
	}
	menu.ExitBackButton = false;
	menu.Display(client, 30);
}

public int MenuHandler_SelectZombieClass(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			int iZombieClass;
			if(GetClientTeam(client) == 3 && !IsFakeClient(client) && IsPlayerAlive(client) && (iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass")) != 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
			{
				char sItem[2];
				menu.GetItem(param2, sItem, sizeof(sItem));
				int iClass = StringToInt(sItem);
				if(++iClass != iZombieClass)
					SetZombieClassAndPunish(client, iClass);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

void SetZombieClassAndPunish(int client, int iZombieClass)
{
	SetZombieClass(client, iZombieClass);
	if(g_bPZPunishHealth)
		SetEntityHealth(client, RoundToCeil(GetClientHealth(client) / 2.0));
	g_bUsedClassCmd[client] = true;
}

stock int GetZombieClass(const char[] sClass)
{
	for(int i; i < 6; i++)
	{
		if(strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return -1;
}

//兼容总监的多特.hud.api.扩展.7+版本
public Action BinHook_OnSpawnSpecial()
{
	g_iPZOnSpawn = 0;
	GhostsModeProtector();
	g_iPZOnSpawn = 0;
}

public Action CommandListener_Spawn(int client, const char[] command, int argc)
{
	g_iPZOnSpawn = client;
	GhostsModeProtector();
	g_iPZOnSpawn = 0;
}

public Action CommandListener_CallVote(int client, const char[] command, int argc)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
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
	if(IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
		return Plugin_Continue;

	if(GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ZOOM)
		{
			if(g_iPZSpawned[client] == 1 && CheckClientAccess(client, 4) == true)
				SelectAscendingZombieClass(client);

			return Plugin_Continue;
		}

		//在director_no_specials值为1的情况下强制重生
		if(!g_bDirectorNoSpecials)
			return Plugin_Continue;
		
		if(buttons & IN_ATTACK)
		{
			static int iSpawnState;
			if(GetEntProp(client, Prop_Send, "m_ghostSpawnState") == 1)
			{
				SetEntProp(client, Prop_Send, "m_ghostSpawnState", 0);
				iSpawnState = 1;
			}
			else if(iSpawnState == 1 && GetEntProp(client, Prop_Send, "m_ghostSpawnState") == 0)
			{
				buttons &= ~IN_ATTACK;
				iSpawnState = 0;
			}
		}
	}
	else
	{
		if(GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_ZOOM && CheckClientAccess(client, 5) == true)
			ResetInfectedAbility(client, 0.1); //管理员鼠标中键重置技能冷却
	}

	return Plugin_Continue;
}

void SelectAscendingZombieClass(int client)
{
	static int iZombieClass;
	iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if(iZombieClass != 8)
		SetZombieClassAndPunish(client, iZombieClass - RoundToFloor(iZombieClass / 6.0) * 6 + 1);
}

//https://forums.alliedmods.net/showthread.php?p=1542365
stock void ResetInfectedAbility(int client, float fTime)
{
	int iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
	{
		SetEntPropFloat(iAbility, Prop_Send, "m_duration", fTime);
		SetEntPropFloat(iAbility, Prop_Send, "m_timestamp", GetGameTime() + fTime);
	}
}

public void OnMapStart()
{
	PrecacheSound(SOUND_CLASSMENU);
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasAnySurvivorLeftSafeArea = false;
	for(int i = 1; i <= MaxClients; i++)
	{
		DeleteTimer(i);
		ResetClientData(i);
	}
}

public void OnClientDisconnect(int client)
{
	DeleteTimer(client);
	RemoveSurvivorModelGlow(client);

	if(g_iLastTeamId[client] == 2)
		g_iLastTeamId[client] = GetClientTeam(client);
}

public void OnClientPostAdminCheck(int client)
{
	ResetClientData(client);
	SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
}

void DeleteTimer(int client)
{
	delete g_hPZSuicideTimer[client];
	delete g_hPZRespawnTimer[client];
}

void ResetClientData(int client)
{
	TyCleanWeapon(client);

	g_iDisplayed[client] = 0;
	g_iPZSpawned[client] = 0;
	
	g_bIsPlayerBP[client] = false;
	g_bUsedClassCmd[client] = false;
}

public void Hook_PostThinkPost(int client)
{
	if(g_bHasPlayerControlledZombies == true || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

	if(!IsValidEntRef(g_iModelEntRef[client]))
		return;
		
	if(g_iModelIndex[client] && g_iModelIndex[client] != GetEntProp(client, Prop_Data, "m_nModelIndex"))
	{
		g_iModelIndex[client] = GetEntProp(client, Prop_Data, "m_nModelIndex");

		static char sModelName[128];
		GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
		SetEntityModel(g_iModelEntRef[client], sModelName);
	}

	SetGlowColor(client);
}

//------------------------------------------------------------------------------
//Event
public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{ 
	if(IsRoundStarted() == false || g_bHasAnySurvivorLeftSafeArea == true || !L4D2_HasAnySurvivorLeftSafeArea())
		return;
	
	CreateTimer(0.1, CheckSurvivorLeftSafeArea, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool IsRoundStarted()
{
	return g_iRoundStart && g_iPlayerSpawn;
}

public Action CheckSurvivorLeftSafeArea(Handle timer) 
{
	if(g_bHasAnySurvivorLeftSafeArea == false && L4D2_HasAnySurvivorLeftSafeArea())
	{
		g_bHasAnySurvivorLeftSafeArea = true;

		if(g_bHasPlayerControlledZombies == true || g_iPZRespawnTime == 0)
			return;

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3 && g_iPZSpawned[i] == 0)
			{
				delete g_hPZRespawnTimer[i];
				CalculatePZRespawnTime(i);
				g_hPZRespawnTimer[i] = CreateTimer(1.0, Timer_PZRespawn, GetClientUserId(i), TIMER_REPEAT);
			}
		}
	}
}

/**
* Returns whether any survivor have left the safe area.
*
* @return               True if any survivor have left safe area, false
*                       otherwise.
*/
stock bool L4D2_HasAnySurvivorLeftSafeArea()
{
    int entity = L4D_GetResourceEntity();

    return entity > -1 && GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

/**
* Returns resource entity.
*
* @return               Entity index of resource entity, -1 if not found.
*/
stock int L4D_GetResourceEntity()
{
    return FindEntityByClassname(MaxClients + 1, "terror_player_manager");
}

void CalculatePZRespawnTime(int client)
{
	g_iPZRespawnCountdown[client] = g_iPZRespawnTime;

	if(g_iPZPunishTime > 0 && g_bUsedClassCmd[client])
		g_iPZRespawnCountdown[client] += g_iPZPunishTime;
		
	g_bUsedClassCmd[client] = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		RemoveInfectedClips();
	g_iRoundStart = 1;

	for(int i = 1; i <= MaxClients; i++)
		DeleteTimer(i);
}

//移除一些限制特感的透明墙体，增加活动空间. 并且能够修复C2M5上面坦克卡住的情况
void RemoveInfectedClips()
{
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "func_playerinfected_clip")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
		
	entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "func_playerghostinfected_clip")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasAnySurvivorLeftSafeArea = false;
	for(int i = 1; i <= MaxClients; i++)
	{
		DeleteTimer(i);
		ResetClientData(i);
	}
	
	if(g_bHasPlayerControlledZombies == false)
		ForceChangeTeamTo();
}

void ForceChangeTeamTo()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if((g_iPZChangeTeamTo || g_iLastTeamId[i] == 2) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
		{
			switch(g_iPZChangeTeamTo)
			{
				case 1:
					ChangeClientTeam(i, 1);
					
				case 2:
					ChangeTeamToSurvivor(i);
			}
		}
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(client == 0 || !IsClientInGame(client))
		return;

	DeleteTimer(client);
	g_iPZSpawned[client] = 0;
	RemoveSurvivorModelGlow(client);
	RequestFrame(OnNextFrame_CreateSurvivorModelGlow, userid);
	
	if(IsFakeClient(client))
		return;

	CreateTimer(0.1, Timer_LadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);

	int team = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");

	if(team == 3)
	{
		if(g_bHasPlayerControlledZombies == false && g_bHasAnySurvivorLeftSafeArea == true && g_iPZRespawnTime > 0)
		{
			CalculatePZRespawnTime(client);
			g_hPZRespawnTimer[client] = CreateTimer(1.0, Timer_PZRespawn, userid, TIMER_REPEAT);
		}
	}
	
	if(oldteam == 3)
	{
		g_iLastTeamId[client] = 0;

		if(team == 2 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
			SetEntProp(client, Prop_Send, "m_isGhost", 0);
	}
	else if(oldteam == 0)
	{
		if(team == 3 && (g_iPZChangeTeamTo || g_iLastTeamId[client] == 3))
			RequestFrame(OnNextFrame_ChangeTeamTo, userid);

		g_iLastTeamId[client] = 0;
	}
}

public Action Timer_LadderAndGlow(Handle timer, int client)
{
	if(g_bHasPlayerControlledZombies == false && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client))
	{
		if(GetClientTeam(client) == 3)
		{
			SendConVarValue(client, g_hGameMode, "versus");
			if(GetTeamPlayers(3) == 1)
			{
				for(int i = 1; i <= MaxClients; i++)
					CreateSurvivorModelGlow(i);
			}
		}
		else
		{
			SendConVarValue(client, g_hGameMode, g_sGameMode);
			for(int i = 1; i <= MaxClients; i++)
				RemoveSurvivorModelGlow(i);

			if(HasPlayerZombie())
			{
				for(int i = 1; i <= MaxClients; i++)
					CreateSurvivorModelGlow(i);
			}
		}
	}
}

public void OnNextFrame_ChangeTeamTo(int client)
{
	if(g_bHasPlayerControlledZombies == false && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3)
	{
		switch(g_iPZChangeTeamTo)
		{
			case 1:
				ChangeClientTeam(client, 1);
					
			case 2:
				ChangeTeamToSurvivor(client);
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		RemoveInfectedClips();
	g_iPlayerSpawn = 1;

	int userid = event.GetInt("userid");
	
	g_iTankBot[GetClientOfUserId(userid)] = 0;

	RequestFrame(OnNextFrame_PlayerSpawn, userid); //player_bot_replace在player_spawn之后触发，延迟一帧进行接管判断
}

public void OnNextFrame_PlayerSpawn(int userid)
{
	int client = GetClientOfUserId(userid);
	if(client == 0 || !IsClientInGame(client) || IsClientInKickQueue(client) || !IsPlayerAlive(client))
		return;

	switch(GetClientTeam(client))
	{
		case 2:
		{
			if(g_bHasPlayerControlledZombies == false && HasPlayerZombie())
				CreateSurvivorModelGlow(client);
		}
		
		case 3:
		{
			if(IsRoundStarted() == true)
			{
				if(IsFakeClient(client))
				{
					if(g_bHasPlayerControlledZombies == false && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
					{
						bool bTakeOver = !!(g_iTankBot[client] != 2 && GetTankPlayers() < g_iMaxTankPlayer && TakeOverTank(client));

						if(!bTakeOver && !g_bMutantTanks && (GetEntProp(client, Prop_Data, "m_bIsInStasis") == 1 || IsInStasis(client)))
							TankLeaveStasis(client); //解除战役模式下特感方有玩家存在时坦克卡住的问题
					}
				}
				else
				{
					if(g_iPZSpawned[client] == 0)
					{
						if(GetEntProp(client, Prop_Send, "m_isGhost") == 0)
							SetInfectedGhost(client, GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
					}
					else if(g_iPZSpawned[client] == 1)
					{
						if(g_bHasPlayerControlledZombies == false && g_iPZRespawnTime > 0 && g_iPZPunishTime > 0 && g_bUsedClassCmd[client] && GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
							CPrintToChat(client, "{olive}下次重生时间 {default}-> {red}+%d秒", g_iPZPunishTime);
					}
		
					g_iPZSpawned[client]++;
				}
			}
		}
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(client == 0 || !IsClientInGame(client))
		return;

	DeleteTimer(client);
	g_iPZSpawned[client] = 0;

	switch(GetClientTeam(client))
	{
		case 2:
		{
			RemoveSurvivorModelGlow(client);
			if(g_bHasPlayerControlledZombies == false && g_bExchangeTeam && !IsFakeClient(client))
			{
				int attacker = GetClientOfUserId(event.GetInt("attacker"));
				if(0 < attacker <= MaxClients && !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
				{
					ChangeClientTeam(client, 3);
					CPrintToChat(client, "{green}★ {red}生还者玩家 {default}被 {red}特感玩家 {default}杀死后，{olive}二者互换队伍");

					if(g_iCmdEnterCooling & (1 << 4))
						g_fCmdLastUsedTime[client] = GetEngineTime();
					RequestFrame(ChangeTeamToSurvivorDelayed, GetClientUserId(attacker));
					CPrintToChat(attacker, "{green}★ {red}特感玩家 {default}杀死 {red}生还者玩家 {default}后，{olive}二者互换队伍");
				}
			}
		}
		
		case 3:
		{
			if(g_bHasPlayerControlledZombies == false && !IsFakeClient(client))
			{
				if(g_bHasAnySurvivorLeftSafeArea == true && g_iPZRespawnTime > 0)
				{
					CalculatePZRespawnTime(client);
					g_hPZRespawnTimer[client] = CreateTimer(1.0, Timer_PZRespawn, userid, TIMER_REPEAT);
				}

				if(g_iLastTeamId[client] == 2 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
				{
					if(g_iCmdEnterCooling & (1 << 2))
						g_fCmdLastUsedTime[client] = GetEngineTime();
					RequestFrame(ChangeTeamToSurvivorDelayed, userid);
					CPrintToChat(client, "{green}★ {olive}玩家Tank {default}死亡后自动切换回 {blue}生还者队伍");
				}
			}
		}
	}
}

public Action Timer_PZRespawn(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) && IsClientInGame(client))
	{
		if(g_bHasPlayerControlledZombies == false && !IsFakeClient(client) && GetClientTeam(client) == 3 && g_iPZSpawned[client] == 0)
		{
			if(g_iPZRespawnCountdown[client] > 0)
				PrintHintText(client, "%d 秒后重生", g_iPZRespawnCountdown[client]--);
			else if(AttemptRespawnPZ(client))
			{
				g_hPZRespawnTimer[client] = null;
				return Plugin_Stop;
			}
			else if(--g_iPZRespawnCountdown[client] <= -25)
			{
				CPrintToChat(client, "{red}重生失败, 请联系服主检查地图或者服务器配置");
				g_hPZRespawnTimer[client] = null;
				return Plugin_Stop;
			}

			return Plugin_Continue;
		}

		g_hPZRespawnTimer[client] = null;
		return Plugin_Stop;	
	}

	return Plugin_Stop;
}

// https://forums.alliedmods.net/showpost.php?p=2305983&postcount=2
// IsClientObserver();
// Client entity prop "m_iObserverMode" - Observer Mode
// #define SPECMODE_NONE 0
// #define SPECMODE_FIRSTPERSON 4
// #define SPECMODE_3RDPERSON 5
// #define SPECMODE_FREELOOK 6
// Client entity prop "m_hObserverTarget" - Spectated Client
stock bool RespawnPZ(int client, int iZombieClass)
{
	/*if(GetEntProp(client, Prop_Send, "m_iObserverMode") != 6)
		SetEntProp(client, Prop_Send, "m_iObserverMode", 6);*/

	FakeClientCommand(client, "spec_next"); //相比于手动获取玩家位置传送，更省力和节约资源的方法

	if(GetEntProp(client, Prop_Send, "m_lifeState") != 1)
		SetEntProp(client, Prop_Send, "m_lifeState", 1);
	
	CheatCmd_SpawnOld(client, g_sZombieClass[iZombieClass]);
	return IsPlayerAlive(client);
}

stock void CheatCmd_SpawnOld(int client, const char[] args = "")
{
	int bits = GetUserFlagBits(client);
	int flags = GetCommandFlags("z_spawn_old");
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags("z_spawn_old", flags & ~FCVAR_CHEAT);			   
	FakeClientCommand(client, "z_spawn_old %s", args);
	SetCommandFlags("z_spawn_old", flags);
	SetUserFlagBits(client, bits);
}

public void Event_TankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bHasPlayerControlledZombies == true)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(g_iLastTeamId[client] != 2 || IsFakeClient(client))
		return;

	if(g_iCmdEnterCooling & (1 << 1))
		g_fCmdLastUsedTime[client] = GetEngineTime();
	RequestFrame(ChangeTeamToSurvivorDelayed, GetClientUserId(client));
	CPrintToChat(client, "{green}★ {default}丢失 {olive}Tank控制权 {default}后自动切换回 {blue}生还者队伍");
}

public void Event_ClientReplace(Event event, const char[] name, bool dontBroadcast)
{
	int bot_userid = event.GetInt("bot");
	int player_userid = event.GetInt("player");
	int bot = GetClientOfUserId(bot_userid);
	int player = GetClientOfUserId(player_userid);

	g_iPZSpawned[bot] = 0;
	g_iPZSpawned[player] = 0;

	if(name[0] == 'p')
	{
		g_iPlayerBot[player] = bot_userid;
		g_iBotPlayer[bot] = player_userid;

		if(GetClientTeam(bot) == 3 && GetEntProp(bot, Prop_Send, "m_zombieClass") == 8)
		{
			if(IsFakeClient(player))
				g_iTankBot[bot] = 1; //防卡功能中踢出FakeClient后，第二次触发Tank产生并替换原有的Tank(BOT替换BOT)
			else
				g_iTankBot[bot] = 2; //主动或被动放弃Tank控制权(BOT替换玩家)
		}
	}
}

//------------------------------------------------------------------------------
//Timer
public Action Timer_ReturnToSurvivor(Handle timer, int client) 
{
	static int i;
	static int iTimes[MAXPLAYERS + 1] = {20, ...};

	if((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		i = iTimes[client]--;
		if(i > 0)
			PrintHintText(client, "还有%d秒变回生还者,请到掩体后面按鼠标[左键]重生.按[E]键可传送到生还者附近", i);
		else if(i == 0)
		{
			if(g_iCmdEnterCooling & (1 << 3))
				g_fCmdLastUsedTime[client] = GetEngineTime();
			ChangeTeamToSurvivor(client);
			i = iTimes[client] = 20;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	i = iTimes[client] = 20;
	return Plugin_Stop;
}

//------------------------------------------------------------------------------
//Other
stock bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}

static bool HasPlayerZombie()
{
	static int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
			return true;
	}

	return false;
}

stock int GetTeamPlayers(int iTeam=-1)
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

stock int GetTankPlayers()
{
	int iTankPlayers;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			iTankPlayers++;
	}

	return iTankPlayers;
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

//https://forums.alliedmods.net/showthread.php?t=291562
void GhostsModeProtector(int iState=0) 
{
	static int i;
	static int iGhost[MAXPLAYERS + 1];
	static int iLifeState[MAXPLAYERS + 1];

	switch(iState)
	{
		case 0: 
		{
			for(i = 1; i <= MaxClients; i++)
			{
				if(i == g_iPZOnSpawn || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3)
					continue;

				if(g_iPZSpawned[i] != 0)
				{
					if(GetEntProp(i, Prop_Send, "m_isGhost") == 1)
					{
						SetEntProp(i, Prop_Send, "m_isGhost", 0);
						iGhost[i] = 1;
					}
				}
				else
				{
					if(!IsPlayerAlive(i))
					{
						SetEntProp(i, Prop_Send, "m_lifeState", 0);
						iLifeState[i] = 1;
					}
				}
			}
		}

		case 1: 
		{
			for(i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
				{
					if(g_iPZSpawned[i] != 0)
					{
						if(iGhost[i] == 1)
							SetEntProp(i, Prop_Send, "m_isGhost", 1);
					}
					else
					{
						if(iLifeState[i] == 1)
							SetEntProp(i, Prop_Send, "m_lifeState", 1);
					}
				}
				
				iGhost[i] = 0;
				iLifeState[i] = 0;
			}
		}
	}

	if(iState == 0)
		RequestFrame(GhostsModeProtector, 1);
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

bool IsValidAliveSurvivorBot(int client)
{
	return IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && !HasIdlePlayer(client);
}

int HasIdlePlayer(int client)
{
	if(HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
	{
		client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
		if(client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
			return client;
	}
	return 0;
}

bool TakeOverTank(int tank)
{
	int client, iPbCount, iOtherCount;
	int[] iPbClients = new int[MaxClients];
	int[] iOtherClients = new int[MaxClients];

	bool bAllowsurvivor = AllowSurvivorTakeOver();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && ((bAllowsurvivor && GetClientTeam(i) == 2) || (GetClientTeam(i) == 3 && (!IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_zombieClass") != 8))))
		{
			iOtherClients[iOtherCount++] = i;
			if(g_bIsPlayerBP[i])
				iPbClients[iPbCount++] = i;
		}
	}

	client = (iPbCount == 0) ? (FloatCompare(GetRandomFloat(0.0, 1.0), g_fSurvuivorAllowChance) == -1 ? (iOtherCount == 0 ? -1 : iOtherClients[GetRandomInt(0, iOtherCount - 1)]) : -1) : iPbClients[GetRandomInt(0, iPbCount - 1)]; //随机抽取一名幸运玩家
	if(client != -1 && StandingSurvivor() >= g_iAllowSurvuivorLimit)
	{
		int iVictim;
		float vOrigin[3];
		switch((g_iLastTeamId[client] = GetClientTeam(client)))
		{
			case 2:
			{
				TySaveWeapon(client);
				CreateTimer(1.0, Timer_ReturnToSurvivor, GetClientUserId(client), TIMER_REPEAT);
			}
			
			case 3:
			{
				if(IsPlayerAlive(client))
				{
					if(GetEntProp(client, Prop_Send, "m_zombieClass") == 6)
					{
						iVictim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
						if(iVictim == -1)
							iVictim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");

						if(iVictim > 0)
							GetClientAbsOrigin(client, vOrigin);
					}
				
					ForcePlayerSuicide(client);
				}
			}
		}

		TakeOverZombieBot(client, tank);

		if(iVictim > 0)
			TeleportEntity(client, vOrigin, NULL_VECTOR, NULL_VECTOR);

		CPrintToChatAll("{green}★ {red}AI Tank {default}已被 {red}%N {olive}接管", client);

		return true;
	}

	return false;
}

int StandingSurvivor()
{
	int iSurvivor;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsSurvivorPinned(i))
			iSurvivor++;
	}
	return iSurvivor;
}

bool AllowSurvivorTakeOver()
{
	if(g_bSbAllBotGame || g_bAllowAllBotSurvivorTeam)
		return true;

	int iAlivesurvivor;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			iAlivesurvivor++;
	}

	return iAlivesurvivor > 1;
}

stock bool IsSurvivorPinned(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)          //Incapacitated
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)       // charger pound
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)        // charger carry
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)       // hunter
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)       //jockey
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)          //smoker
		return true;
	return false;
}

public void OnNextFrame_CreateSurvivorModelGlow(int client)
{
	if(g_bHasPlayerControlledZombies == false && HasPlayerZombie())
		CreateSurvivorModelGlow(GetClientOfUserId(client));
}

void CreateSurvivorModelGlow(int client)
{
	if(IsRoundStarted() == false || client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client) || IsValidEntRef(g_iModelEntRef[client]))
		return;

	int iEntity = CreateEntityByName("prop_dynamic_ornament");
	if(iEntity == -1)
		return;

	g_iModelEntRef[client] = EntIndexToEntRef(iEntity);
	g_iModelIndex[client] = GetEntProp(client, Prop_Data, "m_nModelIndex");

	static char sModelName[128];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	DispatchKeyValue(iEntity, "model", sModelName);

	DispatchKeyValue(iEntity, "solid", "0");
	DispatchKeyValue(iEntity, "rendermode", "0");
	DispatchKeyValueFloat(iEntity, "fademindist", 20000.0);
	DispatchKeyValueFloat(iEntity, "fademaxdist", 22000.0);
	DispatchKeyValue(iEntity, "disableshadows", "1");
	DispatchKeyValue(iEntity, "disablereceiveshadows", "1");
	DispatchKeyValue(iEntity, "mingpulevel", "1");
	DispatchKeyValue(iEntity, "maxgpulevel", "1");
	DispatchKeyValue(iEntity, "MoveType", "0");
	DispatchKeyValue(iEntity, "CollisionGroup", "0");
	DispatchSpawn(iEntity);

	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 20000);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", 1);
	SetGlowColor(client);

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetAttached", client);

	SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action Hook_SetTransmit(int entity, int client)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
		return Plugin_Continue;

	return Plugin_Handled;
}

void RemoveSurvivorModelGlow(int client)
{
	int entity = g_iModelEntRef[client];
	g_iModelEntRef[client] = 0;

	if(IsValidEntRef(entity))
		RemoveEntity(entity);
}

bool IsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

//------------------------------------------------------------------------------
//切换回生还者
public void ChangeTeamToSurvivorDelayed(int client) 
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client))
		return;

	ChangeTeamToSurvivor(client);
}

void ChangeTeamToSurvivor(int client)
{
	int iTeam = GetClientTeam(client);
	if(iTeam == 2)
		return;

	//防止因切换而导致正处于Ghost状态的坦克丢失
	if(GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		SetEntProp(client, Prop_Send, "m_isGhost", 0);

	int iBot = GetClientOfUserId(g_iPlayerBot[client]);
	if(iBot == 0 || !IsValidAliveSurvivorBot(iBot))
		iBot = GetAnyValidAliveSurvivorBot();

	if(iTeam != 1)
		ChangeClientTeam(client, 1);

	if(iBot)
	{
		SetHumanIdle(iBot, client);
		TakeOverBot(client);
	}
	else
	{
		ChangeClientTeam(client, 2);

		if(IsRoundStarted() == true)
		{
			if(!IsPlayerAlive(client))
				Respawn(client);

			TeleportToSurvivor(client);
			SetGodMode(client, 1.0);
		}
	}

	TyGiveWeapon(client);
}

//------------------------------------------------------------------------------
//保存装备状态，以便切换回生还者后还原 嫖自https://forums.alliedmods.net/showthread.php?p=2398822#post2398822
//------------------------------------------------------------------------------
void TySaveWeapon(int client)
{
	if(GetClientTeam(client) != 2) 
		return;

	TyCleanWeapon(client);

	g_iWeaponInfo[client][iRecorded] = 1;

	if(!IsPlayerAlive(client))
	{
		g_iWeaponInfo[client][iHealth] = 50;
		return;
	}

	RemoveInfectedWeapon(client);

	g_iWeaponInfo[client][iReviveCount] = GetEntProp(client, Prop_Send, "m_currentReviveCount");
	g_iWeaponInfo[client][iThirdStrike] = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1) 
	{
		g_iWeaponInfo[client][iHealth] = 1;	
		g_iWeaponInfo[client][iHealthTemp] = 30;
		g_iWeaponInfo[client][iHealthTime] = 0;
		g_iWeaponInfo[client][iGoingToDie] = 1;
	}
	else 
	{
		g_iWeaponInfo[client][iHealth] = GetEntData(client, FindDataMapInfo(client, "m_iHealth"));
		g_iWeaponInfo[client][iHealthTemp]	= RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
		g_iWeaponInfo[client][iHealthTime] = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));
		g_iWeaponInfo[client][iGoingToDie] = GetEntProp(client, Prop_Send, "m_isGoingToDie");
	}

	int iSlot0 = GetPlayerWeaponSlot(client, 0);
	int iSlot1 = GetPlayerWeaponSlot(client, 1);
	int iSlot2 = GetPlayerWeaponSlot(client, 2);
	int iSlot3 = GetPlayerWeaponSlot(client, 3);
	int iSlot4 = GetPlayerWeaponSlot(client, 4);

	if(iSlot0 > 0)
	{
		GetEdictClassname(iSlot0, g_sWeaponInfo[client][Slot0], sizeof(g_sWeaponInfo[][]));

		g_iWeaponInfo[client][iClip] = GetEntProp(iSlot0, Prop_Send, "m_iClip1");
		g_iWeaponInfo[client][iAmmo] = GetClientAmmo(client, g_sWeaponInfo[client][Slot0]);
		g_iWeaponInfo[client][iUpGrade] = GetEntProp(iSlot0, Prop_Send, "m_upgradeBitVec");
		g_iWeaponInfo[client][iUpAmmo] = GetEntProp(iSlot0, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
		g_iWeaponInfo[client][iSkin0] = GetEntProp(iSlot0, Prop_Send, "m_nSkin");
	}
	
	if(iSlot1 > 0)
	{
		TySaveSlot1(client, iSlot1);
		g_iWeaponInfo[client][iSkin1] = GetEntProp(iSlot1, Prop_Send, "m_nSkin");
	}

	if(iSlot2 > 0) 
		GetEdictClassname(iSlot2, g_sWeaponInfo[client][2], sizeof(g_sWeaponInfo[][]));

	if(iSlot3 > 0) 
		GetEdictClassname(iSlot3, g_sWeaponInfo[client][3], sizeof(g_sWeaponInfo[][]));

	if(iSlot4 > 0) 
		GetEdictClassname(iSlot4, g_sWeaponInfo[client][4], sizeof(g_sWeaponInfo[][]));
}

void RemoveInfectedWeapon(int client)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0);
	if(iWeapon != -1)
	{
		char sClassName[32];
		GetEdictClassname(iWeapon, sClassName, sizeof(sClassName));
		if(StrContains(sClassName, "_claw") + 5 == strlen(sClassName))
		{
			RemovePlayerItem(client, iWeapon);
			RemoveEntity(iWeapon);
		}
	}
}

void TySaveSlot1(int client, int iSlot1)
{
	char sClassName[64];
	char sModelName[64];

	GetEdictClassname(iSlot1, sClassName, sizeof(sClassName));
	
	if(strncmp(sClassName[7], "melee", 5) == 0)
		GetEntPropString(iSlot1, Prop_Data, "m_strMapSetScriptName", g_sWeaponInfo[client][Slot1], sizeof(g_sWeaponInfo[][]));
	else if(strcmp(sClassName[7], "pistol") == 0)
	{
		if(GetEntProp(iSlot1, Prop_Send, "m_hasDualWeapons") == 1)
			g_sWeaponInfo[client][Slot1] = "v_dual_pistol";
		else 
			g_sWeaponInfo[client][Slot1] = "weapon_pistol";
	}
	else
		g_sWeaponInfo[client][Slot1] = sClassName;

	if(g_sWeaponInfo[client][Slot1][0] == '\0')
	{
		GetEntPropString(iSlot1, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if(StrContains(sModelName, "v_pistolA.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "weapon_pistol";
		else if(StrContains(sModelName, "v_dual_pistolA.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "v_dual_pistol";
		else if(StrContains(sModelName, "v_desert_eagle.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "weapon_pistol_magnum";
		else if(StrContains(sModelName, "v_bat.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "baseball_bat";
		else if(StrContains(sModelName, "v_cricket_bat.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "cricket_bat";
		else if(StrContains(sModelName, "v_crowbar.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "crowbar";
		else if(StrContains(sModelName, "v_fireaxe.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "fireaxe";
		else if(StrContains(sModelName, "v_katana.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "katana";
		else if(StrContains(sModelName, "v_golfclub.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "golfclub";
		else if(StrContains(sModelName, "v_machete.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "machete";
		else if(StrContains(sModelName, "v_tonfa.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "tonfa";
		else if(StrContains(sModelName, "v_electric_guitar.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "electric_guitar";
		else if(StrContains(sModelName, "v_frying_pan.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "frying_pan";
		else if(StrContains(sModelName, "v_knife_t.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "knife";
		else if(StrContains(sModelName, "v_chainsaw.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "weapon_chainsaw";
		else if(StrContains(sModelName, "v_riotshield.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "riotshield";
		else if(StrContains(sModelName, "v_pitchfork.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "pitchfork";
		else if(StrContains(sModelName, "v_shovel.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "shovel";
		else if(StrContains(sModelName, "v_foamfinger.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "b_foamfinger";			
		else if(StrContains(sModelName, "v_fubar.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "fubar";		
		else if(StrContains(sModelName, "v_paintrain.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "nail_board";
		else if(StrContains(sModelName, "v_sledgehammer.mdl") != -1)	
			g_sWeaponInfo[client][Slot1] = "sledgehammer";
	}
	
	if(strncmp(g_sWeaponInfo[client][Slot1][7], "pistol", 6) == 0 || strncmp(g_sWeaponInfo[client][Slot1][7], "chainsaw", 8) == 0)
		g_iWeaponInfo[client][iClip1] = GetEntProp(iSlot1, Prop_Send, "m_iClip1");
}

void TyGiveWeapon(int client)
{
	if(g_iWeaponInfo[client][iRecorded] == 0 || !IsPlayerAlive(client)) 
		return;

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1)
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

	SetEntProp(client, Prop_Send, "m_currentReviveCount", g_iWeaponInfo[client][iReviveCount]);
	SetEntProp(client, Prop_Send, "m_isGoingToDie", g_iWeaponInfo[client][iGoingToDie]);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", g_iWeaponInfo[client][iThirdStrike]);
	
	SetEntProp(client, Prop_Send, "m_iHealth", g_iWeaponInfo[client][iHealth]);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * g_iWeaponInfo[client][iHealthTemp]);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * g_iWeaponInfo[client][iHealthTime]);

	DeletePlayerSlotAll(client);

	if(g_sWeaponInfo[client][2][0] != '\0')
		CheatCmd_Give(client, g_sWeaponInfo[client][2]);

	if(g_sWeaponInfo[client][3][0] != '\0')
		CheatCmd_Give(client, g_sWeaponInfo[client][3]);

	if(g_sWeaponInfo[client][4][0] != '\0')
		CheatCmd_Give(client, g_sWeaponInfo[client][4]);
	
	int iSlot;
	
	if(g_sWeaponInfo[client][1][0] != '\0')
	{
		if(strncmp(g_sWeaponInfo[client][1], "v_dual_pistol", 13) == 0)
		{
			CheatCmd_Give(client, "pistol");
			CheatCmd_Give(client, "pistol");
		}
		else
		{
			CheatCmd_Give(client, g_sWeaponInfo[client][1]);
			if(g_iWeaponInfo[client][iSkin1] > 0)
			{
				iSlot = GetPlayerWeaponSlot(client, 1);
				if(iSlot > 0)
					SetEntProp(iSlot, Prop_Send, "m_nSkin", g_iWeaponInfo[client][iSkin1]);
			}	
		}

		if(strncmp(g_sWeaponInfo[client][Slot1][7], "pistol", 6) == 0 || strncmp(g_sWeaponInfo[client][Slot1][7], "chainsaw", 8) == 0)
		{
			iSlot = GetPlayerWeaponSlot(client, 1);
			if(iSlot > 0)
				SetEntProp(iSlot, Prop_Send, "m_iClip1", g_iWeaponInfo[client][iClip1]);
		}
	}
	else
		CheatCmd_Give(client, "pistol");

	if(g_sWeaponInfo[client][0][0] != '\0')
	{
		CheatCmd_Give(client, g_sWeaponInfo[client][0]);
		iSlot = GetPlayerWeaponSlot(client, 0);

		if(iSlot > 0)
		{	
			SetEntProp(iSlot, Prop_Send, "m_iClip1", g_iWeaponInfo[client][iClip]);
			SetClientAmmo(client, g_sWeaponInfo[client][0], g_iWeaponInfo[client][iAmmo]);
			SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", g_iWeaponInfo[client][iUpGrade]);
			SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", g_iWeaponInfo[client][iUpAmmo]);
			SetEntProp(iSlot, Prop_Send, "m_nSkin", g_iWeaponInfo[client][iSkin0]);
		}
	}
	else
		CheatCmd_Give(client, "smg");
}

void TyCleanWeapon(int client)
{
	g_iWeaponInfo[client][iClip] = 0;
	g_iWeaponInfo[client][iClip1] = 0;
	g_iWeaponInfo[client][iAmmo] = 0;
	g_iWeaponInfo[client][iUpGrade] = 0;
	g_iWeaponInfo[client][iUpAmmo] = 0;
	g_iWeaponInfo[client][iSkin0] = 0;
	g_iWeaponInfo[client][iSkin1] = 0;
	
	g_iWeaponInfo[client][iHealth] = 100;	
	g_iWeaponInfo[client][iReviveCount] = 0;
	g_iWeaponInfo[client][iGoingToDie] = 0;
	g_iWeaponInfo[client][iHealthTemp] = 0;
	g_iWeaponInfo[client][iHealthTime] = 0;
	g_iWeaponInfo[client][iThirdStrike] = 0;
	g_iWeaponInfo[client][iRecorded] = 0;
	
	g_sWeaponInfo[client][Slot0][0] = '\0';
	g_sWeaponInfo[client][Slot1][0] = '\0';
	g_sWeaponInfo[client][Slot2][0] = '\0';
	g_sWeaponInfo[client][Slot3][0] = '\0';
	g_sWeaponInfo[client][Slot4][0] = '\0';
}

int GetWeaponOffset(const char[] sWeapon)
{
	int iWeaponOffset;

	if(strncmp(sWeapon[13], "m60", 3) == 0) //先验证M60避免与下面的rifle冲突
		iWeaponOffset = 12;
	else if(strncmp(sWeapon[7], "rifle", 5) == 0)
		iWeaponOffset = 24;
	else if(strncmp(sWeapon[7], "smg", 3) == 0)
		iWeaponOffset = 20;
	else if(strncmp(sWeapon[7], "pumpshotgun", 11) == 0 || strncmp(sWeapon[7], "shotgun_chrome", 14) == 0)
		iWeaponOffset = 28;
	else if(strncmp(sWeapon[7], "autoshotgun", 11) == 0|| strncmp(sWeapon[7], "shotgun_spas", 12) == 0)
		iWeaponOffset = 32;
	else if(strncmp(sWeapon[7], "hunting_rifle", 13) == 0)
		iWeaponOffset = 36;
	else if(strncmp(sWeapon[7], "sniper", 6) == 0)
		iWeaponOffset = 40;
	else if(strncmp(sWeapon[7], "grenade", 7) == 0)
		iWeaponOffset = 68;

	return iWeaponOffset;
}

int GetClientAmmo(int client, const char[] sWeapon)
{
	int iWeaponOffset = GetWeaponOffset(sWeapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	return iWeaponOffset > 0 ? GetEntData(client, iAmmoOffset + iWeaponOffset) : 0;
}

void SetClientAmmo(int client, const char[] sWeapon, int iCount)
{
	int iWeaponOffset = GetWeaponOffset(sWeapon);
	int iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	if(iWeaponOffset > 0) 
		SetEntData(client, iAmmoOffset+iWeaponOffset, iCount);
}

void DeletePlayerSlot(int client, int iWeapon)
{		
	if(RemovePlayerItem(client, iWeapon)) 
		RemoveEntity(iWeapon);
}

void DeletePlayerSlotAll(int client)
{
	int iSlot;
	for(int i; i < 5; i++)
	{
		iSlot = GetPlayerWeaponSlot(client, i);
		if(iSlot > 0)	
			DeletePlayerSlot(client, iSlot);
	}
}

//https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
stock int CountSpecialInfected() 
{
	int iCount;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
			iCount++;
	}
	return iCount;
}

stock bool AttemptRespawnPZ(int client) 
{
	if(CountSpecialInfected() < g_iSILimit)
	{
		SITypeCount();

		int	iClass = GenerateIndex();
		if(iClass == -1) 
			return false;

		return RespawnPZ(client, iClass);
	}

	return false;
}

stock int GenerateIndex() 
{	
	int i;
	int iTotalSpawnWeight;
	int iStandardizedSpawnWeight;
	int iTempSpawnWeights[6];

	for(i = 0; i < 6; i++) 
	{
		if(g_iSpawnCounts[i] < g_iSpawnLimits[i]) 
			iTempSpawnWeights[i] = g_iSpawnWeights[i];
		else 
			iTempSpawnWeights[i] = 0;

		iTotalSpawnWeight += iTempSpawnWeights[i];
	}

	static float fIntervalEnds[6];
	float fUnit = 1.0 / iTotalSpawnWeight;
	for(i = 0; i < 6; i++) 
	{
		if(iTempSpawnWeights[i] >= 0) 
		{
			iStandardizedSpawnWeight += iTempSpawnWeights[i];
			fIntervalEnds[i] = iStandardizedSpawnWeight * fUnit;
		}
	}

	float fRandom = GetRandomFloat(0.0, 1.0);
	for(i = 0; i < 6; i++) 
	{
		if(iTempSpawnWeights[i] <= 0) 
			continue;

		if(fIntervalEnds[i] < fRandom) 
			continue;

		return i;
	}

	return -1;
}

stock void SITypeCount() 
{
	int i;
	for(i = 0; i < 6; i++) 
		g_iSpawnCounts[i] = 0;

	int iZombieClass;
	for(i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && 0 < (iZombieClass = GetEntProp(i, Prop_Send, "m_zombieClass")) < 7)
			g_iSpawnCounts[iZombieClass - 1]++;
	}
}

//------------------------------------------------------------------------------
//SDKCall
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
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::IsInStasis") == false) //https://forums.alliedmods.net/showthread.php?t=302140
		SetFailState("Failed to find offset: CBaseEntity::IsInStasis");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_IsInStasis = EndPrepSDKCall();
	if(g_hSDK_Call_IsInStasis == null)
		SetFailState("Failed to create SDKCall: CBaseEntity::IsInStasis");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Tank::LeaveStasis") == false) //https://forums.alliedmods.net/showthread.php?t=319342
		SetFailState("Failed to find signature: Tank::LeaveStasis");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_LeaveStasis = EndPrepSDKCall();
	if(g_hSDK_Call_LeaveStasis == null)
		SetFailState("Failed to create SDKCall: Tank::LeaveStasis");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "ZombieAbortControl") == false)
	{
		LogError("Failed to find signature: ZombieAbortControl");
		PrepSDKCall_State_Transition(hGameData);
	}
	else
	{
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hSDK_Call_ZombieAbortControl = EndPrepSDKCall();
		if(g_hSDK_Call_ZombieAbortControl == null)
		{
			LogError("Failed to create SDKCall: ZombieAbortControl");
			PrepSDKCall_State_Transition(hGameData);
		}
	}

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SetClass") == false)
		SetFailState("Failed to find signature: SetClass");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_SetClass = EndPrepSDKCall();
	if(g_hSDK_Call_SetClass == null)
		SetFailState("Failed to create SDKCall: SetClass");
	
	StartPrepSDKCall(SDKCall_Static);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CreateAbility") == false)
		SetFailState("Failed to find signature: CreateAbility");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_Call_CreateAbility = EndPrepSDKCall();
	if(g_hSDK_Call_CreateAbility == null)
		SetFailState("Failed to create SDKCall: CreateAbility");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TakeOverZombieBot") == false)
		SetFailState("Failed to find signature: TakeOverZombieBot");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_Call_TakeOverZombieBot = EndPrepSDKCall();
	if(g_hSDK_Call_TakeOverZombieBot == null)
		SetFailState("Failed to create SDKCall: TakeOverZombieBot");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "RoundRespawn") == false)
		SetFailState("Failed to find signature: RoundRespawn");
	g_hSDK_Call_RoundRespawn = EndPrepSDKCall();
	if(g_hSDK_Call_RoundRespawn == null)
		SetFailState("Failed to create SDKCall: RoundRespawn");
	
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

	StartPrepSDKCall(SDKCall_Static);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "HasPlayerControlledZombies") == false)
		SetFailState("Failed to find signature: HasPlayerControlledZombies");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_HasPlayerControlledZombies = EndPrepSDKCall();
	if(g_hSDK_Call_HasPlayerControlledZombies == null)
		SetFailState("Failed to create SDKCall: HasPlayerControlledZombies");

	SetupDetours(hGameData);

	delete hGameData;
}

bool IsInStasis(int client)
{
	return SDKCall(g_hSDK_Call_IsInStasis, client);
}

void TankLeaveStasis(int client)
{
	SDKCall(g_hSDK_Call_LeaveStasis, client);
}

void SetInfectedGhost(int client, bool bSavePos=false)
{
	static float vOrigin[3];
	static float vAngles[3];
	static float vVelocity[3];

	if(bSavePos)
	{
		GetClientAbsOrigin(client, vOrigin);
		GetClientEyeAngles(client, vAngles);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	}

	if(g_hSDK_Call_ZombieAbortControl != null)
		InfectedForceGhost(client);
	else
		State_Transition(client, 8);
		
	if(bSavePos)
		TeleportEntity(client, vOrigin, vAngles, vVelocity);
}

//https://forums.alliedmods.net/showthread.php?p=1118704
void InfectedForceGhost(int client)
{
	SetEntProp(client, Prop_Send,"m_isCulling", 1);
	SDKCall(g_hSDK_Call_ZombieAbortControl, client, 0.0);
}

void State_Transition(int client, int iMode) 
{
	SDKCall(g_hSDK_Call_State_Transition, client, iMode);
}

void SetZombieClass(int client, int iZombieClass)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0);
	if(iWeapon != -1)
	{
		RemovePlayerItem(client, iWeapon);
		RemoveEntity(iWeapon);
	}

	int iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
		RemoveEntity(iAbility);

	SDKCall(g_hSDK_Call_SetClass, client, iZombieClass);

	iAbility = SDKCall(g_hSDK_Call_CreateAbility, client);
	if(iAbility != -1)
		SetEntPropEnt(client, Prop_Send, "m_customAbility", iAbility);
}

void TakeOverZombieBot(int client, int iTarget) 
{
	AcceptEntityInput(client, "clearparent");
	SDKCall(g_hSDK_Call_TakeOverZombieBot, client, iTarget);
}

void Respawn(int client)
{
	SDKCall(g_hSDK_Call_RoundRespawn, client);
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

void PrepSDKCall_State_Transition(GameData hGameData = null)
{
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "State_Transition") == false)
		SetFailState("Failed to find signature: State_Transition");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_hSDK_Call_State_Transition = EndPrepSDKCall();
	if(g_hSDK_Call_State_Transition == null)
		SetFailState("Failed to create SDKCall: State_Transition");
}

void SetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour;
	dDetour = DynamicDetour.FromConf(hGameData, "OnEnterGhostState");
	if(dDetour == null)
		SetFailState("Failed to load signature: OnEnterGhostState");
		
	if(!dDetour.Enable(Hook_Pre, EnterGhostStatePre))
		SetFailState("Failed to detour pre: OnEnterGhostState");
		
	if(!dDetour.Enable(Hook_Post, EnterGhostStatePost))
		SetFailState("Failed to detour post: OnEnterGhostState");
}

public MRESReturn EnterGhostStatePre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(g_bHasPlayerControlledZombies == false && IsRoundStarted() == false)
	{
		hReturn.Value = 0;
		return MRES_Supercede; //阻止死亡状态下的特感玩家在团灭后下一回合开始前进入Ghost State
	}
	
	return MRES_Ignored;
}

public MRESReturn EnterGhostStatePost(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if(!IsFakeClient(pThis) && g_iPZSpawned[pThis] == 0)
		RequestFrame(OnNextFrame_EnterGhostState, GetClientUserId(pThis));
	
	return MRES_Ignored;
}

void OnNextFrame_EnterGhostState(int client)
{
	if(g_bHasPlayerControlledZombies == false && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(g_iDisplayed[client] == 0)
		{
			if(CheckClientAccess(client, 1) == true)
				CPrintToChat(client, "{default}聊天栏输入 {olive}!team2 {default}可切换回{blue}生还者");
				
			if(CheckClientAccess(client, 4) == true)
				PrintHintText(client, "灵魂状态下按下鼠标[中键]可以快速切换特感");
		}

		ClassMenuCheck(client);
	
		if(g_fPZSuicideTime > 0.0)
		{
			delete g_hPZSuicideTimer[client];
			g_hPZSuicideTimer[client] = CreateTimer(g_fPZSuicideTime, Timer_PZSuicide, GetClientUserId(client));
		}
	}
}

void ClassMenuCheck(int client)
{
	if((g_iAutoDisplayMenu < 0 || g_iDisplayed[client] < g_iAutoDisplayMenu) && CheckClientAccess(client, 4) == true)
	{
		DisplayClassMenu(client);
		EmitSoundToClient(client, SOUND_CLASSMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		g_iDisplayed[client]++;
	}
}

public Action Timer_PZSuicide(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) && IsClientInGame(client))
	{
		g_hPZSuicideTimer[client] = null;
		if(g_bHasPlayerControlledZombies == false && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client))
		{
			ForcePlayerSuicide(client);
			CPrintToChat(client, "{olive}复活后自动处死时间 {default}-> {red}%.1f秒", g_fPZSuicideTime);
		}
	}
}
