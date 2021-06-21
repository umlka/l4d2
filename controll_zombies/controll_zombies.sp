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
 * @param sMessage	String.
 * @param maxlength   Maximum length of the string buffer.
 * @return			  Client index that can be used for SayText2 author index
 * 
 * On error/Errors:   If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] sMessage, int maxlength)
{	
	int iRandomPlayer = NO_INDEX;
	
	for(int i; i < MAX_COLORS; i++)												//	Para otras etiquetas de color se requiere un bucle.
	{
		if(StrContains(sMessage, CTag[i]) == -1) 										//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if(!CTagReqSayText2[i])
			ReplaceString(sMessage, maxlength, CTag[i], CTagCode[i]); 					//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else																				//	La etiqueta necesita Saytext2.
		{	
			if(iRandomPlayer == NO_INDEX)											//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
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

static const char g_sZombieClass[6][] =
{
	"smoker",
	"boomer",
	"hunter",
	"spitter",
	"jockey", 
	"charger"
};

char g_sGameMode[32];

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

Address g_pRespawn;
Address g_pStatsCondition;

DynamicDetour g_dDetour;

ConVar g_hGameMode;
ConVar g_hMaxTankPlayer;
ConVar g_hAllowSurvuivorLimit; 
ConVar g_hSurvuivorAllowChance;
ConVar g_hSbAllBotGame; 
ConVar g_hAllowAllBotSurvivorTeam;
ConVar g_hSurvivorMaxIncapacitatedCount;
//ConVar g_hDirectorNoSpecials; 
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
//bool g_bDirectorNoSpecials;
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
	vLoadGameData();

	g_hMaxTankPlayer = CreateConVar("cz_max_tank_player", "1" , "坦克玩家达到多少后插件将不再控制玩家接管(0=不接管坦克)", CVAR_FLAGS, true, 0.0);
	g_hAllowSurvuivorLimit = CreateConVar("cz_allow_survivor_limit", "3" , "至少有多少名正常生还者(未被控,未倒地,未死亡)时,才允许玩家接管坦克", CVAR_FLAGS, true, 0.0);
	g_hSurvuivorAllowChance = CreateConVar("cz_survivor_allow_chance", "0.0" , "准备叛变的玩家数量为0时,自动抽取生还者和感染者玩家的几率(排除闲置旁观玩家)(0.0=不自动抽取)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hExchangeTeam = CreateConVar("cz_exchange_team", "1" , "特感玩家杀死生还者玩家后是否互换队伍?(0=否,1=是)", CVAR_FLAGS);
	g_hPZSuicideTime = CreateConVar("cz_pz_suicide_time", "120.0" , "特感玩家复活后自动处死的时间(0=不会处死复活后的特感玩家)", CVAR_FLAGS, true, 0.0);
	g_hPZRespawnTime = CreateConVar("cz_pz_respawn_time", "15" , "特感玩家自动复活时间(0=插件不会接管特感玩家的复活)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishTime = CreateConVar("cz_pz_punish_time", "10" , "特感玩家在ghost状态下切换特感类型后下次复活延长的时间(0=插件不会延长复活时间)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishHealth = CreateConVar("cz_pz_punish_health", "1" , "特感玩家在ghost状态下切换特感类型后血量是否减半(0=插件不会减半血量)", CVAR_FLAGS);
	g_hAutoDisplayMenu = CreateConVar("cz_atuo_display_menu", "1" , "在感染玩家死亡重生后向其显示更改类型的菜单?(0=不显示,-1=每次都显示,大于0=每回合总计显示的最大次数)", CVAR_FLAGS, true, -1.0);
	g_hPZTeamLimit = CreateConVar("cz_pz_team_limit", "-1" , "感染玩家数量达到多少后将限制使用sm_team3命令(-1=感染玩家不能超过生还玩家,大于等于0=感染玩家不能超过该值)", CVAR_FLAGS, true, -1.0);
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
	g_hSILimit = CreateConVar("cz_si_limit", "32", "同时存在的最大特感数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SMOKER] = CreateConVar("cz_smoker_limit",	"6", "smoker同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_BOOMER] = CreateConVar("cz_boomer_limit",	"6", "boomer同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_HUNTER] = CreateConVar("cz_hunter_limit",	"2", "hunter同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SPITTER] = CreateConVar("cz_spitter_limit", "6", "spitter同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_JOCKEY] = CreateConVar("cz_jockey_limit",	"2", "jockey同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_CHARGER] = CreateConVar("cz_charger_limit", "2", "charger同时存在的最大数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnWeights[SI_SMOKER] = CreateConVar("cz_smoker_weight", "75", "smoker产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_BOOMER] = CreateConVar("cz_boomer_weight", "100", "boomer产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_HUNTER] = CreateConVar("cz_hunter_weight", "50", "hunter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_SPITTER] = CreateConVar("cz_spitter_weight", "75", "spitter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_JOCKEY] = CreateConVar("cz_jockey_weight", "30", "jockey产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_CHARGER] = CreateConVar("cz_charger_weight", "10", "charger产生比重", CVAR_FLAGS, true, 0.0);

	//AutoExecConfig(true, "controll_zombies");
	//想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(vModeConVarChanged);
	g_hSbAllBotGame = FindConVar("sb_all_bot_game");
	g_hSbAllBotGame.AddChangeHook(vOtherConVarChanged);
	g_hAllowAllBotSurvivorTeam = FindConVar("allow_all_bot_survivor_team");
	g_hAllowAllBotSurvivorTeam.AddChangeHook(vOtherConVarChanged);
	g_hSurvivorMaxIncapacitatedCount = FindConVar("survivor_max_incapacitated_count");
	g_hSurvivorMaxIncapacitatedCount.AddChangeHook(vColorConVarChanged);
	/*	
	g_hDirectorNoSpecials = FindConVar("director_no_specials");
	g_hDirectorNoSpecials.AddChangeHook(vOtherConVarChanged);
	*/
	g_hMaxTankPlayer.AddChangeHook(vOtherConVarChanged);
	g_hAllowSurvuivorLimit.AddChangeHook(vOtherConVarChanged);
	g_hSurvuivorAllowChance.AddChangeHook(vOtherConVarChanged);
	g_hExchangeTeam.AddChangeHook(vOtherConVarChanged);
	g_hPZSuicideTime.AddChangeHook(vOtherConVarChanged);
	g_hPZRespawnTime.AddChangeHook(vOtherConVarChanged);
	g_hPZPunishTime.AddChangeHook(vOtherConVarChanged);
	g_hPZPunishHealth.AddChangeHook(vOtherConVarChanged);
	g_hAutoDisplayMenu.AddChangeHook(vOtherConVarChanged);
	g_hPZTeamLimit.AddChangeHook(vOtherConVarChanged);
	g_hCmdCooldownTime.AddChangeHook(vOtherConVarChanged);
	g_hCmdEnterCooling.AddChangeHook(vOtherConVarChanged);
	g_hPZChangeTeamTo.AddChangeHook(vOtherConVarChanged);

	int i;
	for(i = 0; i < 4; i++)
		g_hGlowColor[i].AddChangeHook(vColorConVarChanged);

	g_hAccessAdminFlags.AddChangeHook(vAdminConVarChanged);
	g_hAdminImmunityLevels.AddChangeHook(vAdminConVarChanged);

	g_hSILimit.AddChangeHook(vSpawnConVarChanged);
	for(i = 0; i < 6; i++)
	{
		g_hSpawnLimits[i].AddChangeHook(vSpawnConVarChanged);
		g_hSpawnWeights[i].AddChangeHook(vSpawnConVarChanged);
	}
	
	//防止战役模式加入特感方时出现紫黑色网格球体以及客户端控制台"Material effects/spawn_sphere has bad reference count 0 when being bound"报错
	ConVar hConVar = FindConVar("z_scrimmage_sphere");
	hConVar.SetBounds(ConVarBound_Lower, true, 0.0);
	hConVar.SetBounds(ConVarBound_Upper, true, 0.0);
	hConVar.IntValue = 0;
	
	hConVar = FindConVar("z_max_player_zombies");
	hConVar.SetBounds(ConVarBound_Lower, true, 32.0);
	hConVar.SetBounds(ConVarBound_Upper, true, 32.0);
	hConVar.IntValue = 32;

	//https://wiki.alliedmods.net/Events_(SourceMod_Scripting)#Hooking_Events 防止某些插件在Pre挂钩上面阻止事件广播，导致Post挂钩监听不到事件触发
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("tank_frustrated", Event_TankFrustrated);
	HookEvent("bot_player_replace", Event_ClientReplace);
	HookEvent("player_bot_replace", Event_ClientReplace);

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
	ConVar hConVar = FindConVar("z_scrimmage_sphere");
	hConVar.SetBounds(ConVarBound_Lower, false);
	hConVar.SetBounds(ConVarBound_Upper, false);
	hConVar.RestoreDefault();
	
	hConVar = FindConVar("z_max_player_zombies");
	hConVar.SetBounds(ConVarBound_Lower, false);
	hConVar.SetBounds(ConVarBound_Upper, false);
	hConVar.RestoreDefault();

	for(int i = 1; i <= MaxClients; i++)
		vRemoveSurvivorModelGlow(i);
		
	vStatsConditionPatch(false);
	if(!g_dDetour.Disable(Hook_Pre, mreOnEnterGhostStatePre) || !g_dDetour.Disable(Hook_Post, mreOnEnterGhostStatePost))
		SetFailState("Failed to disable detour: CTerrorPlayer::OnEnterGhostState");
}

public void OnConfigsExecuted()
{
	vGetModeCvars();
	vGetOtherCvars();
	vGetColorCvars();
	vGetSpawnCvars();
	vGetAdminCvars();
}

public void vModeConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetModeCvars();
}

void vGetModeCvars()
{
	g_hGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));

	bool bLast = g_bHasPlayerControlledZombies;
	g_bHasPlayerControlledZombies = SDKCall(g_hSDK_Call_HasPlayerControlledZombies);
	if(bLast != g_bHasPlayerControlledZombies)
	{
		if(g_bHasPlayerControlledZombies == true) //coop->versus
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) == 2)
					vRemoveSurvivorModelGlow(i);
			}
		}
		else if(bHasPlayerZombie()) //versus->coop
		{
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
}

public void vOtherConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetOtherCvars();
}

void vGetOtherCvars()
{
	g_iMaxTankPlayer = g_hMaxTankPlayer.IntValue;
	g_iAllowSurvuivorLimit = g_hAllowSurvuivorLimit.IntValue;
	g_fSurvuivorAllowChance = g_hSurvuivorAllowChance.FloatValue;
	g_bSbAllBotGame = g_hSbAllBotGame.BoolValue;
	g_bAllowAllBotSurvivorTeam = g_hAllowAllBotSurvivorTeam.BoolValue;
	//g_bDirectorNoSpecials = g_hDirectorNoSpecials.BoolValue;
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

public void vColorConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetColorCvars();
}

void vGetColorCvars()
{
	g_iSurvivorMaxIncapacitatedCount = g_hSurvivorMaxIncapacitatedCount.IntValue;

	for(int i; i < 4; i++)
		g_iGlowColor[i] = iGetColor(g_hGlowColor[i]);
		
	if(g_bHasPlayerControlledZombies == false && bHasPlayerZombie())
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && bIsValidEntRef(g_iModelEntRef[i]))
				vSetGlowColor(i);
		}
	}
}

void vSetGlowColor(int client)
{
	static int iColorType;
	if(GetEntProp(g_iModelEntRef[client], Prop_Send, "m_glowColorOverride") != g_iGlowColor[(iColorType = iGetColorType(client))])
		SetEntProp(g_iModelEntRef[client], Prop_Send, "m_glowColorOverride", g_iGlowColor[iColorType]);
}

static int iGetColorType(int client)
{
	if(GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurvivorMaxIncapacitatedCount)
		return 2;
	else
	{
		if(GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)
			return 1;
		else
		{
			if(GetEntPropFloat(client, Prop_Send, "m_vomitFadeStart") + 5.0 >= GetGameTime())
				return 3;
			else
				return 0;
		}
	}
}

int iGetColor(ConVar hConVar)
{
	char sTemp[12];
	hConVar.GetString(sTemp, sizeof(sTemp));

	if(sTemp[0] == 0)
		return 0;

	char sColors[3][4];
	int iColor = ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));

	if(iColor != 3)
		return 0;

	iColor = StringToInt(sColors[0]);
	iColor += 256 * StringToInt(sColors[1]);
	iColor += 65536 * StringToInt(sColors[2]);

	return iColor;
}

public void vAdminConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetAdminCvars();
}

void vGetAdminCvars()
{
	vGetAccessAdminFlags();
	vGetAdminImmunityLevels();
}

void vGetAccessAdminFlags()
{
	char sTemp[256];
	g_hAccessAdminFlags.GetString(sTemp, sizeof(sTemp));

	char sAccessAdminFlags[6][26];
	ExplodeString(sTemp, ";", sAccessAdminFlags, sizeof(sAccessAdminFlags), sizeof(sAccessAdminFlags[]));

	for(int i; i < 6; i++)
		g_iAccessAdminFlags[i] = ReadFlagString(sAccessAdminFlags[i]);
}

void vGetAdminImmunityLevels()
{
	char sTemp[128];
	g_hAdminImmunityLevels.GetString(sTemp, sizeof(sTemp));

	char sAdminImmunityLevels[6][8];
	ExplodeString(sTemp, ";", sAdminImmunityLevels, sizeof(sAdminImmunityLevels), sizeof(sAdminImmunityLevels[]));

	for(int i; i < 6; i++)
		g_iAdminImmunityLevels[i] = StringToInt(sAdminImmunityLevels[i]);
}

bool bCheckClientAccess(int client, int iIndex)
{
	if(g_iAccessAdminFlags[iIndex] == 0)
		return true;

	static int iFlagBits;
	if((iFlagBits = GetUserFlagBits(client)) & ADMFLAG_ROOT == 0 && iFlagBits & g_iAccessAdminFlags[iIndex] == 0)
		return false;

	static char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return true;

	return admin.ImmunityLevel >= g_iAdminImmunityLevels[iIndex];
}

public void vSpawnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
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
}

public Action CmdTeam4(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(bCheckClientAccess(client, 0) == false)
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

	if(bCheckClientAccess(client, 1) == false)
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
	vChangeTeamToSurvivor(client);
	return Plugin_Handled;
}

public Action CmdTeam3(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
		return Plugin_Handled;

	if(bCheckClientAccess(client, 2) == false)
	{
		//PrintToChat(client, "无权使用该指令");
		//return Plugin_Handled;
		float fCooldown = GetEngineTime() - g_fCmdLastUsedTime[client];
		if(fCooldown < g_fCmdCooldownTime)
		{
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_fCmdCooldownTime - fCooldown);
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
		g_fCmdLastUsedTime[client] = GetEngineTime();

	vSurvivorClean(client);
	vSurvivorSave(client);
	ChangeClientTeam(client, 3);
	return Plugin_Handled;
}

public Action CmdBP(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(bCheckClientAccess(client, 3) == false)
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
	
	if(bCheckClientAccess(client, 4) == false)
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
		char sTargetClass[16];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		int iZombieClass;
		int iClass = iGetZombieClass(sTargetClass);
		if(iClass == -1)
		{
			CPrintToChat(client, "{olive}!class{default}/{olive}sm_class {default}<{red}class{default}>.");
			CPrintToChat(client, "<{olive}class{default}> [ {red}smoker {default}| {red}boomer {default}| {red}hunter {default}| {red}spitter {default}| {red}jockey {default}| {red}charger {default}]");
		}
		else if(++iClass == (iZombieClass = GetEntProp(client, Prop_Send, "m_zombieClass")) || iZombieClass == 8)
			CPrintToChat(client, "目标特感类型与当前特感类型相同或当前特感类型为 {red}Tank");
		else
			vSetZombieClassAndPunish(client, iClass);
	}
	else
		vSelectZombieClassMenu(client);
	
	return Plugin_Handled;
}

void vDisplayClassMenu(int client)
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
				vSelectZombieClassMenu(client);
		}
		case MenuAction_End:
			delete menu;
	}
}

void vSelectZombieClassMenu(int client)
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
					vSetZombieClassAndPunish(client, iClass);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

void vSetZombieClassAndPunish(int client, int iZombieClass)
{
	vSetZombieClass(client, iZombieClass);
	if(g_bPZPunishHealth)
		SetEntityHealth(client, RoundToCeil(GetClientHealth(client) / 2.0));
	g_bUsedClassCmd[client] = true;
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

//兼容总监的多特.hud.api.扩展.7+版本
public Action BinHook_OnSpawnSpecial()
{
	g_iPZOnSpawn = 0;
	vGhostsModeProtector();
	g_iPZOnSpawn = 0;
}

public Action CommandListener_Spawn(int client, const char[] command, int argc)
{
	g_iPZOnSpawn = client;
	vGhostsModeProtector();
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
// SPAWN_OK			 0
// SPAWN_DISABLED	   1  "Spawning has been disabled..." (e.g. director_no_specials 1)
// WAIT_FOR_SAFE_AREA   2  "Waiting for the Survivors to leave the safe area..."
// WAIT_FOR_FINALE	  4  "Waiting for the finale to begin..."
// WAIT_FOR_TANK		8  "Waiting for Tank battle conclusion..."
// SURVIVOR_ESCAPED	16  "The Survivors have escaped..."
// DIRECTOR_TIMEOUT	32  "The Director has called a time-out..." (lol wat)
// WAIT_FOR_STAMPEDE   64  "Waiting for the next stampede of Infected..."
// CAN_BE_SEEN		128  "Can't spawn here" "You can be seen by the Survivors"
// TOO_CLOSE		  256  "Can't spawn here" "You are too close to the Survivors"
// RESTRICTED_AREA	512  "Can't spawn here" "This is a restricted area"
// INSIDE_ENTITY	 1024  "Can't spawn here" "Something is blocking this spot"
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
		return Plugin_Continue;

	static int iFlags;
	iFlags = GetEntProp(client, Prop_Data, "m_afButtonPressed");

	if(GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(iFlags & IN_ZOOM)
		{
			if(g_iPZSpawned[client] == 1 && bCheckClientAccess(client, 4) == true)
				vSelectAscendingZombieClass(client);

			return Plugin_Continue;
		}

		//在director_no_specials值为1的情况下强制重生
		/*if(!g_bDirectorNoSpecials)
			return Plugin_Continue;*/
		
		if(iFlags & IN_ATTACK)
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
		if(iFlags & IN_ZOOM && bCheckClientAccess(client, 5) == true)
			vResetInfectedAbility(client, 0.1); //管理员鼠标中键重置技能冷却
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

//https://forums.alliedmods.net/showthread.php?p=1542365
void vResetInfectedAbility(int client, float fTime)
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
		vDeleteTimer(i);
		vResetClientData(i);
	}
}

public void OnClientDisconnect(int client)
{
	vRemoveSurvivorModelGlow(client);

	if(IsFakeClient(client))
		return;

	vDeleteTimer(client);
	if(g_iLastTeamId[client] == 2)
		g_iLastTeamId[client] = GetClientTeam(client);
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;

	vResetClientData(client);
}

void vDeleteTimer(int client)
{
	delete g_hPZSuicideTimer[client];
	delete g_hPZRespawnTimer[client];
}

void vResetClientData(int client)
{
	vSurvivorClean(client);

	g_iDisplayed[client] = 0;
	g_iPZSpawned[client] = 0;
	
	g_bIsPlayerBP[client] = false;
	g_bUsedClassCmd[client] = false;
}

//------------------------------------------------------------------------------
//Event
public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{ 
	if(bIsRoundStarted() == false || g_bHasAnySurvivorLeftSafeArea == true || !bHasAnySurvivorLeftSafeArea())
		return;
	
	CreateTimer(0.1, CheckSurvivorLeftSafeArea, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool bIsRoundStarted()
{
	return g_iRoundStart && g_iPlayerSpawn;
}

public Action CheckSurvivorLeftSafeArea(Handle timer) 
{
	if(g_bHasAnySurvivorLeftSafeArea == false && bHasAnySurvivorLeftSafeArea())
	{
		g_bHasAnySurvivorLeftSafeArea = true;

		if(g_bHasPlayerControlledZombies == true || g_iPZRespawnTime == 0)
			return;

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3 && GetPlayerWeaponSlot(i, 0) == -1)
			{
				delete g_hPZRespawnTimer[i];
				vCalculatePZRespawnTime(i);
				g_hPZRespawnTimer[i] = CreateTimer(1.0, Timer_PZRespawn, GetClientUserId(i), TIMER_REPEAT);
			}
		}
	}
}

bool bHasAnySurvivorLeftSafeArea()
{
	int entity = iGetResourceEntity();

	return entity > -1 && GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

int iGetResourceEntity()
{
	return FindEntityByClassname(MaxClients + 1, "terror_player_manager");
}

void vCalculatePZRespawnTime(int client)
{
	g_iPZRespawnCountdown[client] = g_iPZRespawnTime;

	if(g_iPZPunishTime > 0 && g_bUsedClassCmd[client])
		g_iPZRespawnCountdown[client] += g_iPZPunishTime;
		
	g_bUsedClassCmd[client] = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		vRemoveInfectedClips();
	g_iRoundStart = 1;

	for(int i = 1; i <= MaxClients; i++)
		vDeleteTimer(i);
}

//移除一些限制特感的透明墙体，增加活动空间. 并且能够修复C2M5上面坦克卡住的情况
void vRemoveInfectedClips()
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
		vDeleteTimer(i);
		vResetClientData(i);
	}
	
	if(g_bHasPlayerControlledZombies == false)
		vForceChangeTeamTo();
}

void vForceChangeTeamTo()
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
					vChangeTeamToSurvivor(i);
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

	g_iPZSpawned[client] = 0;
	vRemoveSurvivorModelGlow(client);
	
	int team = event.GetInt("team");
	if(team == 2)
		RequestFrame(OnNextFrame_CreateSurvivorModelGlow, userid);
	
	if(IsFakeClient(client))
		return;

	CreateTimer(0.1, Timer_LadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);

	if(team == 3)
	{
		if(g_bHasPlayerControlledZombies == false && g_bHasAnySurvivorLeftSafeArea == true && g_iPZRespawnTime > 0)
		{
			vCalculatePZRespawnTime(client);
			g_hPZRespawnTimer[client] = CreateTimer(1.0, Timer_PZRespawn, userid, TIMER_REPEAT);
		}
	}

	int oldteam = event.GetInt("oldteam");
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
			if(iGetTeamPlayers(3) == 1)
			{
				for(int i = 1; i <= MaxClients; i++)
					vCreateSurvivorModelGlow(i);
			}
		}
		else
		{
			SendConVarValue(client, g_hGameMode, g_sGameMode);
			for(int i = 1; i <= MaxClients; i++)
				vRemoveSurvivorModelGlow(i);

			if(bHasPlayerZombie())
			{
				for(int i = 1; i <= MaxClients; i++)
					vCreateSurvivorModelGlow(i);
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
				vChangeTeamToSurvivor(client);
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		vRemoveInfectedClips();
	g_iPlayerSpawn = 1;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(IsPlayerAlive(client))
	{
		g_iTankBot[client] = 0;
		
		if(!IsFakeClient(client) && GetClientTeam(client) == 3)
		{
			if(g_iPZSpawned[client] == 0)
			{
				if(GetEntProp(client, Prop_Send, "m_isGhost") == 0)
					vSetInfectedGhost(client, GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
			}
			else if(g_iPZSpawned[client] == 1)
			{
				if(g_bHasPlayerControlledZombies == false && g_iPZRespawnTime > 0 && g_iPZPunishTime > 0 && g_bUsedClassCmd[client] && GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
					CPrintToChat(client, "{olive}下次重生时间 {default}-> {red}+%d秒", g_iPZPunishTime);
			}
		}

		g_iPZSpawned[client]++;
		RequestFrame(OnNextFrame_PlayerSpawn, userid); //player_bot_replace在player_spawn之后触发，延迟一帧进行接管判断
	}
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
			if(g_bHasPlayerControlledZombies == false && bHasPlayerZombie())
				vCreateSurvivorModelGlow(client);
		}
		
		case 3:
		{
			if(bIsRoundStarted() == true)
			{
				if(IsFakeClient(client))
				{
					if(g_bHasPlayerControlledZombies == false && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
					{
						bool bTakeOver = !!(g_iTankBot[client] != 2 && iGetTankPlayers() < g_iMaxTankPlayer && bTakeOverTank(client));

						if(!bTakeOver && !g_bMutantTanks && (GetEntProp(client, Prop_Data, "m_bIsInStasis") == 1 || SDKCall(g_hSDK_Call_IsInStasis, client)))
							SDKCall(g_hSDK_Call_LeaveStasis, client); //解除战役模式下特感方有玩家存在时坦克卡住的问题
					}
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

	g_iPZSpawned[client] = 0;

	switch(GetClientTeam(client))
	{
		case 2:
		{
			vRemoveSurvivorModelGlow(client);
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
					vCalculatePZRespawnTime(client);
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
		if(g_bHasPlayerControlledZombies == false && !IsFakeClient(client) && GetClientTeam(client) == 3 && GetPlayerWeaponSlot(client, 0) == -1)
		{
			if(g_iPZRespawnCountdown[client] > 0)
				PrintHintText(client, "%d 秒后重生", g_iPZRespawnCountdown[client]--);
			else if(bAttemptRespawnPZ(client))
			{
				vSetInfectedGhost(client, false);
				SetEntProp(client, Prop_Send,"m_isCulling", 0);

				g_hPZRespawnTimer[client] = null;
				return Plugin_Stop;
			}
			else if(--g_iPZRespawnCountdown[client] <= -10)
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
bool bRespawnPZ(int client, int iZombieClass)
{
	/*if(GetEntProp(client, Prop_Send, "m_iObserverMode") != 6)
		SetEntProp(client, Prop_Send, "m_iObserverMode", 6);*/

	FakeClientCommand(client, "spec_next"); //相比于手动获取玩家位置传送，更省力和节约资源的方法

	if(/*GetClientTeam(client) == 3 && */GetEntProp(client, Prop_Send, "m_lifeState") != 1)
		SetEntProp(client, Prop_Send, "m_lifeState", 1);

	vCheatCommand(client, "z_spawn_old", g_sZombieClass[iZombieClass]);
	return IsPlayerAlive(client);
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
	return (iNormal == 0) ? (iIncap == 0 ? (iHanging == 0 ? -1 : iHangingSurvivors[GetRandomInt(0, iHanging - 1)]) : iIncapSurvivors[GetRandomInt(0, iIncap - 1)]) : iNormalSurvivors[GetRandomInt(0, iNormal - 1)];
}

void vForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

//https://forums.alliedmods.net/showthread.php?t=291562
void vGhostsModeProtector(int iState = 0) 
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
				if(i != g_iPZOnSpawn)
				{
					if(!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3)
						continue;

					if(GetPlayerWeaponSlot(i, 0) != -1)
					{
						if(GetEntProp(i, Prop_Send, "m_isGhost") == 1)
						{
							SetEntProp(i, Prop_Send, "m_isGhost", 0);
							iGhost[i] = 1;
						}
					}
					else
					{
						SetEntProp(i, Prop_Send, "m_lifeState", 0);
						iLifeState[i] = 1;
					}
				}
				else
				{
					iGhost[i] = 0;
					iLifeState[i] = 0;
				}
			}
		}

		case 1: 
		{
			for(i = 1; i <= MaxClients; i++)
			{
				if(i != g_iPZOnSpawn && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
				{
					if(GetPlayerWeaponSlot(i, 0) != -1)
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
		RequestFrame(vGhostsModeProtector, 1);
}

void vSetGodMode(int client, float fDuration)
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

int iGetAnyValidAliveSurvivorBot()
{
	int iPlayer, iHasPlayer, iNotPlayer;
	int[] iHasPlayerBots = new int[MaxClients];
	int[] iNotPlayerBots = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(bIsValidAliveSurvivorBot(i)) 
		{
			if((iPlayer = GetClientOfUserId(g_iBotPlayer[i])) && IsClientInGame(iPlayer) && !IsFakeClient(iPlayer) && GetClientTeam(iPlayer) != 2)
				iHasPlayerBots[iHasPlayer++] = i;
			else
				iNotPlayerBots[iNotPlayer++] = i;
		}
	}
	return (iNotPlayer == 0) ? (iHasPlayer == 0 ? 0 : iHasPlayerBots[GetRandomInt(0, iHasPlayer - 1)]) : iNotPlayerBots[GetRandomInt(0, iNotPlayer - 1)];
}

bool bIsValidAliveSurvivorBot(int client)
{
	return IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && !iHasIdlePlayer(client);
}

int iHasIdlePlayer(int client)
{
	if(HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
	{
		client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
		if(client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
			return client;
	}
	return 0;
}

bool bTakeOverTank(int tank)
{
	int client, iPbCount, iOtherCount;
	int[] iPbClients = new int[MaxClients];
	int[] iOtherClients = new int[MaxClients];

	bool bAllowsurvivor = bAllowSurvivorTakeOver();
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
	if(client != -1 && iGetStandingSurvivors() >= g_iAllowSurvuivorLimit)
	{
		switch((g_iLastTeamId[client] = GetClientTeam(client)))
		{
			case 2:
			{
				vSurvivorClean(client);
				vSurvivorSave(client);
				CreateTimer(1.0, Timer_ReturnToSurvivor, GetClientUserId(client), TIMER_REPEAT);
			}
			
			case 3:
			{
				if(IsPlayerAlive(client))
				{
					SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);
					ForcePlayerSuicide(client);
				}
			}
		}

		vTakeOverZombieBot(client, tank);

		CPrintToChatAll("{green}★ {red}AI Tank {default}已被 {red}%N {olive}接管", client);

		return true;
	}

	return false;
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

bool bIsPinned(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0)
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

public void OnNextFrame_CreateSurvivorModelGlow(int client)
{
	if(g_bHasPlayerControlledZombies == false && bHasPlayerZombie())
		vCreateSurvivorModelGlow(GetClientOfUserId(client));
}

void vCreateSurvivorModelGlow(int client)
{
	if(bIsRoundStarted() == false || client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client) || bIsValidEntRef(g_iModelEntRef[client]))
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
	vSetGlowColor(client);

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetAttached", client);

	SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
	SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
	SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
}

public Action Hook_SetTransmit(int entity, int client)
{
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
		return Plugin_Continue;

	return Plugin_Handled;
}

public void Hook_PostThinkPost(int client)
{
	if(GetClientTeam(client) != 2 || !IsPlayerAlive(client) || !bIsValidEntRef(g_iModelEntRef[client]))
	{
		SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
		return;
	}

	if(g_iModelIndex[client] && g_iModelIndex[client] != GetEntProp(client, Prop_Data, "m_nModelIndex"))
	{
		g_iModelIndex[client] = GetEntProp(client, Prop_Data, "m_nModelIndex");

		static char sModelName[128];
		GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
		SetEntityModel(g_iModelEntRef[client], sModelName);
	}

	vSetGlowColor(client);
}

void vRemoveSurvivorModelGlow(int client)
{
	int entity = g_iModelEntRef[client];
	g_iModelEntRef[client] = 0;

	if(bIsValidEntRef(entity))
		RemoveEntity(entity);
}

bool bIsValidEntRef(int entity)
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

	vChangeTeamToSurvivor(client);
}

void vChangeTeamToSurvivor(int client)
{
	int iTeam = GetClientTeam(client);
	if(iTeam == 2)
		return;

	//防止因切换而导致正处于Ghost状态的坦克丢失
	if(GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		SetEntProp(client, Prop_Send, "m_isGhost", 0);

	int iBot = GetClientOfUserId(g_iPlayerBot[client]);
	if(iBot == 0 || !bIsValidAliveSurvivorBot(iBot))
		iBot = iGetAnyValidAliveSurvivorBot();

	if(iTeam != 1)
		ChangeClientTeam(client, 1);

	if(iBot)
	{
		vSetHumanIdle(iBot, client);
		SDKCall(g_hSDK_Call_TakeOverBot, client, true);
	}
	else
	{
		ChangeClientTeam(client, 2);

		if(bIsRoundStarted() == true)
		{
			if(!IsPlayerAlive(client))
				vRoundRespawn(client);

			vSetGodMode(client, 1.0);
			vTeleportToSurvivor(client);
		}
	}

	vSurvivorGive(client);
	vSurvivorClean(client);
}

//------------------------------------------------------------------------------
//保存装备状态，以便切换回生还者后还原 嫖自https://forums.alliedmods.net/showthread.php?p=2398822#post2398822
//------------------------------------------------------------------------------
/*static const char g_sSurvivorNames[8][] =
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
*/
void vSurvivorStatus(int client, int iType)
{
	static bool bRecorded[MAXPLAYERS + 1];
	static int iStatusInfo[MAXPLAYERS + 1][7];
	//static char sStatusInfo[MAXPLAYERS + 1][128];
	
	switch(iType)
	{
		case 0:
		{
			bRecorded[client] = false;
			vCleanStatus(client, iStatusInfo/*, sStatusInfo*/);
		}
			
		case 1:
		{
			bRecorded[client] = true;
			vSaveStatus(client, iStatusInfo/*, sStatusInfo, sizeof(sStatusInfo)*/);
		}
			
		case 2:
		{
			if(bRecorded[client])
				vSetStatus(client, iStatusInfo/*, sStatusInfo*/);
		}
	}
}

void vCleanStatus(int client, int[][] iStatusInfo/*, char[][] sStatusInfo*/)
{
	iStatusInfo[client][0] = 0;
	iStatusInfo[client][1] = 0;
	iStatusInfo[client][2] = 0;
	iStatusInfo[client][3] = 0;
	iStatusInfo[client][4] = 0;
	iStatusInfo[client][5] = 0;
	iStatusInfo[client][6] = -1;
	
	//sStatusInfo[client][0] = '\0';
}

void vSaveStatus(int client, int[][] iStatusInfo/*, char[][] sStatusInfo, int maxlength*/)
{
	//GetClientModel(client, sStatusInfo[client], maxlength);
	//iStatusInfo[client][6] = GetEntProp(client, Prop_Send, "m_survivorCharacter");	

	if(!IsPlayerAlive(client))
	{
		iStatusInfo[client][3] = 50;
		return;
	}

	iStatusInfo[client][0] = GetEntProp(client, Prop_Send, "m_currentReviveCount");
	iStatusInfo[client][1] = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1) 
	{
		iStatusInfo[client][3] = 1;	
		iStatusInfo[client][4] = 30;
		iStatusInfo[client][5] = 0;
		iStatusInfo[client][2] = 1;
	}
	else 
	{
		iStatusInfo[client][3] = GetEntProp(client, Prop_Data, "m_iHealth");
		iStatusInfo[client][4] = RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
		iStatusInfo[client][5] = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));
		iStatusInfo[client][2] = GetEntProp(client, Prop_Send, "m_isGoingToDie");
	}
}

void vSetStatus(int client, int[][] iStatusInfo/*, char[][] sStatusInfo*/)
{
	/*SetEntProp(client, Prop_Send, "m_survivorCharacter", iStatusInfo[client][6]); 
	SetEntityModel(client, sStatusInfo[client]);
	
	if(IsFakeClient(client))
	{
		for(int i; i < 8; i++)
		{
			if(strcmp(sStatusInfo[client], g_sSurvivorModels[i]) == 0) 
				SetClientInfo(client, "name", g_sSurvivorNames[i]);
		}
	}*/

	if(!IsPlayerAlive(client)) 
		return;

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1)
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

	SetEntProp(client, Prop_Send, "m_currentReviveCount", iStatusInfo[client][0]);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", iStatusInfo[client][1]);
	SetEntProp(client, Prop_Send, "m_isGoingToDie", iStatusInfo[client][2]);

	SetEntProp(client, Prop_Send, "m_iHealth", iStatusInfo[client][3]);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * iStatusInfo[client][4]);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * iStatusInfo[client][5]);

	if(iStatusInfo[client][1] != 0)
		StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
}

void vRemoveWeapons(int client)
{
	int iWeapon;
	for(int iSlot; iSlot < 5; iSlot++)
	{
		iWeapon = GetPlayerWeaponSlot(client, iSlot);
		if(iWeapon > MaxClients)
		{
			RemovePlayerItem(client, iWeapon);
			RemoveEntity(iWeapon);
		}
	}
}

void vSurvivorWeapons(int client, int iType)
{
	static bool bRecorded[MAXPLAYERS + 1];
	static int iWeaponInfo[MAXPLAYERS + 1][7];
	static char sWeaponInfo[MAXPLAYERS + 1][5][32];
	
	switch(iType)
	{
		case 0:
		{
			bRecorded[client] = false;
			vCleanWeapons(client, iWeaponInfo, sWeaponInfo);
		}
			
		case 1:
		{
			bRecorded[client] = true;
			vSaveWeapons(client, iWeaponInfo, sWeaponInfo, sizeof(sWeaponInfo[][]));
		}
			
		case 2:
		{
			if(bRecorded[client])
			{
				vRemoveWeapons(client);
				vGiveWeapons(client, iWeaponInfo, sWeaponInfo);
			}
		}
	}
}

void vCleanWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo)
{
	iWeaponInfo[client][0] = 0;
	iWeaponInfo[client][1] = 0;
	iWeaponInfo[client][2] = 0;
	iWeaponInfo[client][3] = 0;
	iWeaponInfo[client][4] = 0;
	iWeaponInfo[client][5] = -1;
	iWeaponInfo[client][6] = 0;
	
	sWeaponInfo[client][0][0] = '\0';
	sWeaponInfo[client][1][0] = '\0';
	sWeaponInfo[client][2][0] = '\0';
	sWeaponInfo[client][3][0] = '\0';
	sWeaponInfo[client][4][0] = '\0';
}

void vSaveWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo, int maxlength)
{
	char sWeapon[32];
	int iSlot = GetPlayerWeaponSlot(client, 0);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][0], maxlength, sWeapon);

		iWeaponInfo[client][0] = GetEntProp(iSlot, Prop_Send, "m_iClip1");
		iWeaponInfo[client][1] = iGetOrSetPlayerAmmo(client, sWeapon);
		iWeaponInfo[client][2] = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
		iWeaponInfo[client][3] = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
		iWeaponInfo[client][4] = GetEntProp(iSlot, Prop_Send, "m_nSkin");
	}

	iSlot = GetPlayerWeaponSlot(client, 1);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		if(strcmp(sWeapon[7], "melee") == 0)
			GetEntPropString(iSlot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof(sWeapon));
		else if(strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(iSlot, Prop_Send, "m_isDualWielding") > 0)
			sWeapon = "v_dual_pistol";

		strcopy(sWeaponInfo[client][1], maxlength, sWeapon);

		if(strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
			iWeaponInfo[client][5] = GetEntProp(iSlot, Prop_Send, "m_iClip1");

		iWeaponInfo[client][6] = GetEntProp(iSlot, Prop_Send, "m_nSkin");
	}

	iSlot = GetPlayerWeaponSlot(client, 2);
	if(iSlot > MaxClients)
	{
		GetClientWeapon(client, sWeapon, sizeof(sWeapon));
		if(strcmp(sWeapon, "weapon_vomitjar") != 0 && strcmp(sWeapon, "weapon_pipe_bomb") != 0 && strcmp(sWeapon, "weapon_molotov") != 0)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			strcopy(sWeaponInfo[client][2], maxlength, sWeapon);
		}
	}

	iSlot = GetPlayerWeaponSlot(client, 3);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][3], maxlength, sWeapon);
	}

	iSlot = GetPlayerWeaponSlot(client, 4);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][4], maxlength, sWeapon);
	}
}

void vGiveWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo)
{
	int iSlot;
	if(sWeaponInfo[client][0][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][0]);

		iSlot = GetPlayerWeaponSlot(client, 0);
		if(iSlot > MaxClients)
		{
			SetEntProp(iSlot, Prop_Send, "m_iClip1", iWeaponInfo[client][0]);
			iGetOrSetPlayerAmmo(client, sWeaponInfo[client][0], iWeaponInfo[client][1]);

			if(iWeaponInfo[client][2] > 0)
				SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", iWeaponInfo[client][2]);

			if(iWeaponInfo[client][3] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iWeaponInfo[client][3]);
				
			if(iWeaponInfo[client][4] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nSkin", iWeaponInfo[client][4]);
		}
	}

	if(sWeaponInfo[client][1][0] != '\0')
	{
		if(strcmp(sWeaponInfo[client][1], "v_dual_pistol") == 0)
		{
			vCheatCommand(client, "give", "weapon_pistol");
			vCheatCommand(client, "give", "weapon_pistol");
		}
		else
			vCheatCommand(client, "give", sWeaponInfo[client][1]);

		iSlot = GetPlayerWeaponSlot(client, 1);
		if(iSlot > MaxClients)
		{
			if(iWeaponInfo[client][5] != -1)
				SetEntProp(iSlot, Prop_Send, "m_iClip1", iWeaponInfo[client][5]);
				
			if(iWeaponInfo[client][6] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nSkin", iWeaponInfo[client][6]);
		}
	}

	if(sWeaponInfo[client][2][0] != '\0')
		vCheatCommand(client, "give", sWeaponInfo[client][2]);

	if(sWeaponInfo[client][3][0] != '\0')
		vCheatCommand(client, "give", sWeaponInfo[client][3]);

	if(sWeaponInfo[client][4][0] != '\0')
		vCheatCommand(client, "give", sWeaponInfo[client][4]);
}

void vSurvivorClean(int client)
{
	vSurvivorStatus(client, 0);
	vSurvivorWeapons(client, 0);
}

void vSurvivorSave(int client)
{
	vSurvivorStatus(client, 1);
	vSurvivorWeapons(client, 1);
}

void vSurvivorGive(int client)
{
	vSurvivorStatus(client, 2);
	vSurvivorWeapons(client, 2);
}

void vCheatCommand(int client, const char[] sCommand, const char[] sArguments = "")
{
	static int iCmdFlags, iFlagBits;
	iFlagBits = GetUserFlagBits(client), iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags | FCVAR_CHEAT);
}

int iGetOrSetPlayerAmmo(int client, const char[] sWeapon, int iAmmo = -1)
{
	static StringMap aWeaponOffsets;
	if(aWeaponOffsets == null)
		aWeaponOffsets = aInitWeaponOffsets(aWeaponOffsets);
		
	static int iOffsetAmmo;
	if(iOffsetAmmo < 1)
		iOffsetAmmo = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");

	int offset;
	aWeaponOffsets.GetValue(sWeapon, offset);

	if(offset)
	{
		if(iAmmo != -1)
			SetEntData(client, iOffsetAmmo + offset, iAmmo);
		else
			return GetEntData(client, iOffsetAmmo + offset);
	}

	return 0;
}

StringMap aInitWeaponOffsets(StringMap aWeaponOffsets)
{
	aWeaponOffsets = new StringMap();
	aWeaponOffsets.SetValue("weapon_rifle", 12);
	aWeaponOffsets.SetValue("weapon_smg", 20);
	aWeaponOffsets.SetValue("weapon_pumpshotgun", 28);
	aWeaponOffsets.SetValue("weapon_shotgun_chrome", 28);
	aWeaponOffsets.SetValue("weapon_autoshotgun", 32);
	aWeaponOffsets.SetValue("weapon_hunting_rifle", 36);
	aWeaponOffsets.SetValue("weapon_rifle_sg552", 12);
	aWeaponOffsets.SetValue("weapon_rifle_desert", 12);
	aWeaponOffsets.SetValue("weapon_rifle_ak47", 12);
	aWeaponOffsets.SetValue("weapon_smg_silenced", 20);
	aWeaponOffsets.SetValue("weapon_smg_mp5", 20);
	aWeaponOffsets.SetValue("weapon_shotgun_spas", 32);
	aWeaponOffsets.SetValue("weapon_sniper_scout", 40);
	aWeaponOffsets.SetValue("weapon_sniper_military", 40);
	aWeaponOffsets.SetValue("weapon_sniper_awp", 40);
	aWeaponOffsets.SetValue("weapon_rifle_m60", 24);
	aWeaponOffsets.SetValue("weapon_grenade_launcher", 68);
	return aWeaponOffsets;
}

//https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
int iGetInfecteds() 
{
	int iCount;
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
			iCount++;
	}
	return iCount;
}

bool bAttemptRespawnPZ(int client) 
{
	if(iGetInfecteds() < g_iSILimit)
	{
		vSITypeCount();

		int	iClass = iGenerateIndex();
		return bRespawnPZ(client, iClass != -1 ? iClass : GetRandomInt(0, 5));
	}

	return false;
}

int iGenerateIndex() 
{	
	int i;
	int iTotalSpawnWeight;
	int iStandardizedSpawnWeight;
	int iTempSpawnWeights[6];

	for(i = 0; i < 6; i++) 
	{
		iTempSpawnWeights[i] = g_iSpawnCounts[i] < g_iSpawnLimits[i] ? g_iSpawnWeights[i] : 0;
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

void vSITypeCount() 
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
		vPrepSDKCall_StateTransition(hGameData);
	}
	else
	{
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		g_hSDK_Call_ZombieAbortControl = EndPrepSDKCall();
		if(g_hSDK_Call_ZombieAbortControl == null)
		{
			LogError("Failed to create SDKCall: ZombieAbortControl");
			vPrepSDKCall_StateTransition(hGameData);
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
	
	vRegisterStatsConditionPatch(hGameData);

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

	g_pRespawn = hGameData.GetAddress("RoundRespawn");
	if(!g_pRespawn)
		SetFailState("Failed to find address: RoundRespawn");
	
	g_pStatsCondition = g_pRespawn + view_as<Address>(iOffset);
	
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if(iByteOrigin != iByteMatch)
		SetFailState("Failed to load, byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void vSetInfectedGhost(int client, bool bSavePos = false)
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
		vInfectedForceGhost(client);
	else
		vStateTransition(client, 8);
		
	if(bSavePos)
		TeleportEntity(client, vOrigin, vAngles, vVelocity);
}

//https://forums.alliedmods.net/showthread.php?p=1118704
void vInfectedForceGhost(int client)
{
	SetEntProp(client, Prop_Send,"m_isCulling", 1);
	SDKCall(g_hSDK_Call_ZombieAbortControl, client, 0.0);
}

void vStateTransition(int client, int iMode) 
{
	SDKCall(g_hSDK_Call_State_Transition, client, iMode);
}

void vSetZombieClass(int client, int iZombieClass)
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

void vTakeOverZombieBot(int client, int iTarget) 
{
	AcceptEntityInput(client, "clearparent");
	SDKCall(g_hSDK_Call_TakeOverZombieBot, client, iTarget);
}

void vRoundRespawn(int client)
{
	vStatsConditionPatch(true);
	SDKCall(g_hSDK_Call_RoundRespawn, client);
	vStatsConditionPatch(false);
}

//https://forums.alliedmods.net/showthread.php?t=323220
void vStatsConditionPatch(bool bPatch) // Prevents respawn command from reset the player's statistics
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		StoreToAddress(g_pStatsCondition, 0x79, NumberType_Int8); // if(!bool) - 0x75 JNZ => 0x78 JNS (jump short if not sign) - always not jump
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

void vSetHumanIdle(int bot, int client)
{
	SDKCall(g_hSDK_Call_SetHumanSpec, bot, client);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
}

void vPrepSDKCall_StateTransition(GameData hGameData = null)
{
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "State_Transition") == false)
		SetFailState("Failed to find signature: State_Transition");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_hSDK_Call_State_Transition = EndPrepSDKCall();
	if(g_hSDK_Call_State_Transition == null)
		SetFailState("Failed to create SDKCall: State_Transition");
}

void vSetupDetours(GameData hGameData = null)
{
	g_dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::OnEnterGhostState");
	if(g_dDetour == null)
		SetFailState("Failed to load signature: CTerrorPlayer::OnEnterGhostState");
		
	if(!g_dDetour.Enable(Hook_Pre, mreOnEnterGhostStatePre))
		SetFailState("Failed to detour pre: CTerrorPlayer::OnEnterGhostState");
		
	if(!g_dDetour.Enable(Hook_Post, mreOnEnterGhostStatePost))
		SetFailState("Failed to detour post: CTerrorPlayer::OnEnterGhostState");
}

public MRESReturn mreOnEnterGhostStatePre(int pThis)
{
	if(g_bHasPlayerControlledZombies == false && bIsRoundStarted() == false)
		return MRES_Supercede; //阻止死亡状态下的特感玩家在团灭后下一回合开始前进入Ghost State
	
	return MRES_Ignored;
}

public MRESReturn mreOnEnterGhostStatePost(int pThis)
{
	if(!IsFakeClient(pThis) && g_iPZSpawned[pThis] == 0)
	{
		if(g_bHasPlayerControlledZombies == false)
			RequestFrame(OnNextFrame_EnterGhostState, GetClientUserId(pThis));
		else
			g_iPZSpawned[pThis]++;
	}
	
	return MRES_Ignored;
}

void OnNextFrame_EnterGhostState(int client)
{
	if(g_bHasPlayerControlledZombies == false && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(g_iDisplayed[client] == 0)
		{
			if(bCheckClientAccess(client, 1) == true)
				CPrintToChat(client, "{default}聊天栏输入 {olive}!team2 {default}可切换回{blue}生还者");
				
			if(bCheckClientAccess(client, 4) == true)
				PrintHintText(client, "灵魂状态下按下鼠标[中键]可以快速切换特感");
		}

		vClassMenuCheck(client);
	
		if(g_fPZSuicideTime > 0.0)
		{
			delete g_hPZSuicideTimer[client];
			g_hPZSuicideTimer[client] = CreateTimer(g_fPZSuicideTime, Timer_PZSuicide, GetClientUserId(client));
		}
	}
}

void vClassMenuCheck(int client)
{
	if((g_iAutoDisplayMenu == -1 || g_iDisplayed[client] < g_iAutoDisplayMenu) && bCheckClientAccess(client, 4) == true)
	{
		vDisplayClassMenu(client);
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
