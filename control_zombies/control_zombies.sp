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
 * @param client	Client index.
 * @param sMessage	Message (formatting rules)
 * @return			No return
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
 * @param maxlength	Maximum length of the string buffer.
 * @return			Client index that can be used for SayText2 author index
 * 
 * On error/Errors:	If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] sMessage, int maxlength)
{	
	int iRandomPlayer = NO_INDEX;
	
	for(int i; i < MAX_COLORS; i++)													//	Para otras etiquetas de color se requiere un bucle.
	{
		if(StrContains(sMessage, CTag[i]) == -1)									//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if(!CTagReqSayText2[i])
			ReplaceString(sMessage, maxlength, CTag[i], CTagCode[i]);				//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else																		//	La etiqueta necesita Saytext2.
		{	
			if(iRandomPlayer == NO_INDEX)											//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
			{
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]);		//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if(iRandomPlayer == NO_PLAYER)
					ReplaceString(sMessage, maxlength, CTag[i], CTagCode[5]);		//	Si no se encuentra un cliente valido, reemplasa la etiqueta con una etiqueta de color verde.
				else 
					ReplaceString(sMessage, maxlength, CTag[i], CTagCode[i]);		// 	Si el cliente fue encontrado simplemente reemplasa.
			}
			else																	//	Si en caso de usar dos colores de equipo infectado y equipo de superviviente juntos se mandará un mensaje de error.
				ThrowError("Using two team colors in one message is not allowed");	//	Si se ha usadó una combinación de colores no validad se registrara en la carpeta logs.
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
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client));
	bf.WriteByte(author);
	bf.WriteByte(true);
	bf.WriteString(sMessage);
	EndMessage();
}
/**************************************************************************/

#define DEBUG				1

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

Handle
	g_hTimer,
	g_hSDK_Call_IsInStasis,
	g_hSDK_Call_LeaveStasis,
	g_hSDK_Call_State_Transition,
	g_hSDK_Call_MaterializeFromGhost,
	g_hSDK_Call_SetClass,
	g_hSDK_Call_CreateForPlayer,
	g_hSDK_Call_CleanupPlayerState,
	g_hSDK_Call_TakeOverZombieBot,
	g_hSDK_Call_RoundRespawn,
	g_hSDK_Call_SetHumanSpectator,
	g_hSDK_Call_TakeOverBot,
	g_hSDK_Call_HasPlayerControlledZombies;

Address
	g_pStatsCondition;

DynamicDetour
	g_dDetour[4];

ConVar
	g_hGameMode,
	g_hMaxTankPlayer,
	g_hAllowSurvuivorLimit,
	g_hSurvuivorAllowChance,
	g_hSbAllBotGame,
	g_hAllowAllBotSurvivorTeam,
	g_hSurvivorMaxIncapacitatedCount,
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

bool
	g_bHasPlayerControlledZombies,
	g_bHasAnySurvivorLeftSafeArea,
	g_bSbAllBotGame,
	g_bAllowAllBotSurvivorTeam,
	g_bExchangeTeam,
	g_bGlowColorEnable,
	g_bPZPunishHealth,
	g_bScaleWeights,
	g_bIsSpawnablePZSupported,
	g_bOnMaterializeFromGhost,
	g_bIsPlayerBP[MAXPLAYERS + 1],
	g_bUsedClassCmd[MAXPLAYERS + 1];

int
	g_iSILimit,
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iSpawnablePZ,
	g_iSurvivorMaxIncapacitatedCount,
	g_iAllowSurvuivorLimit,
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
	g_iSpawnCounts[6],
	g_iUserFlagBits[5],
	g_iImmunityLevels[5],
	g_iTankBot[MAXPLAYERS + 1],
	g_iPlayerBot[MAXPLAYERS + 1],
	g_iBotPlayer[MAXPLAYERS + 1],
	g_iLastTeamId[MAXPLAYERS + 1],
	g_iModelIndex[MAXPLAYERS + 1],
	g_iModelEntRef[MAXPLAYERS + 1],
	g_iMaterialized[MAXPLAYERS + 1],
	g_iEnteredGhostState[MAXPLAYERS + 1],
	g_iCurrentPZRespawnTime[MAXPLAYERS + 1];

float
	g_fSurvuivorAllowChance,
	g_fMapStartTime,
	g_fCmdCooldownTime,
	g_fCmdLastUsedTime[MAXPLAYERS + 1],
	g_fBugExploitTime[MAXPLAYERS + 1][2],
	g_fStartRespawnTime[MAXPLAYERS + 1],
	g_fStartSuicideTime[MAXPLAYERS + 1];

//如果签名失效，请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo = 
{
	name = "Control Zombies In Co-op",
	author = "sorallll",
	description = "",
	version = "3.2.6",
	url = "https://steamcommunity.com/id/sorallll"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CZ_SetSpawnablePZ", aNative_SetSpawnablePZ);
	CreateNative("CZ_ResetSpawnablePZ", aNative_ResetSpawnablePZ);
	CreateNative("CZ_IsSpawnablePZSupported", aNative_IsSpawnablePZSupported);

	RegPluginLibrary("control_zombies");
	return APLRes_Success;
}

public any aNative_SetSpawnablePZ(Handle plugin, int numParams)
{
	g_iSpawnablePZ = GetNativeCell(1);
}

public any aNative_ResetSpawnablePZ(Handle plugin, int numParams)
{
	g_iSpawnablePZ = 0;
}

public any aNative_IsSpawnablePZSupported(Handle plugin, int numParams)
{
	return g_bIsSpawnablePZSupported;
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hMaxTankPlayer = CreateConVar("cz_max_tank_player", "1" , "坦克玩家达到多少后插件将不再控制玩家接管(0=不接管坦克)", CVAR_FLAGS, true, 0.0);
	g_hAllowSurvuivorLimit = CreateConVar("cz_allow_survivor_limit", "3" , "至少有多少名正常生还者(未被控,未倒地,未死亡)时,才允许玩家接管坦克", CVAR_FLAGS, true, 0.0);
	g_hSurvuivorAllowChance = CreateConVar("cz_survivor_allow_chance", "0.0" , "准备叛变的玩家数量为0时,自动抽取生还者和感染者玩家的几率(排除闲置旁观玩家)(0.0=不自动抽取)", CVAR_FLAGS, true, 0.0, true, 1.0);
	g_hExchangeTeam = CreateConVar("cz_exchange_team", "0" , "特感玩家杀死生还者玩家后是否互换队伍?(0=否,1=是)", CVAR_FLAGS);
	g_hPZSuicideTime = CreateConVar("cz_pz_suicide_time", "120" , "特感玩家复活后自动处死的时间(0=不会处死复活后的特感玩家)", CVAR_FLAGS, true, 0.0);
	g_hPZRespawnTime = CreateConVar("cz_pz_respawn_time", "15" , "特感玩家自动复活时间(0=插件不会接管特感玩家的复活)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishTime = CreateConVar("cz_pz_punish_time", "30" , "特感玩家在ghost状态下切换特感类型后下次复活延长的时间(0=插件不会延长复活时间)", CVAR_FLAGS, true, 0.0);
	g_hPZPunishHealth = CreateConVar("cz_pz_punish_health", "1" , "特感玩家在ghost状态下切换特感类型后血量是否减半(0=插件不会减半血量)", CVAR_FLAGS);
	g_hAutoDisplayMenu = CreateConVar("cz_atuo_display_menu", "1" , "在感染玩家进入灵魂状态后自动向其显示更改类型的菜单?(0=不显示,-1=每次都显示,大于0=每回合总计显示的最大次数)", CVAR_FLAGS, true, -1.0);
	g_hPZTeamLimit = CreateConVar("cz_pz_team_limit", "2" , "感染玩家数量达到多少后将限制使用sm_team3命令(-1=感染玩家不能超过生还玩家,大于等于0=感染玩家不能超过该值)", CVAR_FLAGS, true, -1.0);
	g_hCmdCooldownTime = CreateConVar("cz_cmd_cooldown_time", "120.0" , "sm_team2,sm_team3两个命令的冷却时间(0.0-无冷却)", CVAR_FLAGS, true, 0.0);
	g_hCmdEnterCooling = CreateConVar("cz_return_enter_cooling", "31" , "什么情况下sm_team2,sm_team3命令会进入冷却(1=使用其中一个命令,2=坦克玩家掉控,4=坦克玩家死亡,8=坦克玩家未及时重生,16=特感玩家杀掉生还者玩家,31=所有)", CVAR_FLAGS);
	g_hPZChangeTeamTo = CreateConVar("cz_pz_change_team_to", "0" , "换图,过关以及任务失败时是否自动将特感玩家切换到哪个队伍?(0=不切换,1=旁观者,2=生还者)", CVAR_FLAGS, true, 0.0, true, 2.0);
	g_hGlowColorEnable = CreateConVar("cz_survivor_color_enable", "1" , "是否给生还者创发光建模型?(0=否,1=是)", CVAR_FLAGS);
	g_hGlowColor[COLOR_NORMAL] = CreateConVar("cz_survivor_color_normal", "0 180 0" , "特感玩家看到的正常状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_INCAPA] = CreateConVar("cz_survivor_color_incapacitated", "180 0 0" , "特感玩家看到的倒地状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_BLACKW] = CreateConVar("cz_survivor_color_blackwhite", "255 255 255" , "特感玩家看到的黑白状态生还者发光颜色", CVAR_FLAGS);
	g_hGlowColor[COLOR_VOMITED] = CreateConVar("cz_survivor_color_nowit", "155 0 180" , "特感玩家看到的被Boomer喷或炸中过的生还者发光颜色", CVAR_FLAGS);
	g_hUserFlagBits = CreateConVar("cz_user_flagbits", ";z;;;z" , "哪些标志能绕过sm_team2,sm_team3,sm_bp,sm_class,鼠标中键重置冷却的使用限制(留空表示所有人都不会被限制)", CVAR_FLAGS);
	g_hImmunityLevels = CreateConVar("cz_immunity_levels", "99;99;99;99;99" , "要达到什么免疫级别才能绕过sm_team2,sm_team3,sm_bp,sm_class,鼠标中键重置冷的使用限制", CVAR_FLAGS);

	//https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
	g_hSILimit = CreateConVar("cz_si_limit", "32", "同时存在的最大特感数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SMOKER] = CreateConVar("cz_smoker_limit",	"5", "同时存在的最大smoker数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_BOOMER] = CreateConVar("cz_boomer_limit",	"5", "同时存在的最大boomer数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_HUNTER] = CreateConVar("cz_hunter_limit",	"5", "同时存在的最大hunter数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SPITTER] = CreateConVar("cz_spitter_limit", "5", "同时存在的最大spitter数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_JOCKEY] = CreateConVar("cz_jockey_limit",	"5", "同时存在的最大jockey数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_CHARGER] = CreateConVar("cz_charger_limit", "5", "同时存在的最大charger数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_hSpawnWeights[SI_SMOKER] = CreateConVar("cz_smoker_weight", "100", "smoker产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_BOOMER] = CreateConVar("cz_boomer_weight", "50", "boomer产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_HUNTER] = CreateConVar("cz_hunter_weight", "100", "hunter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_SPITTER] = CreateConVar("cz_spitter_weight", "50", "spitter产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_JOCKEY] = CreateConVar("cz_jockey_weight", "100", "jockey产生比重", CVAR_FLAGS, true, 0.0);
	g_hSpawnWeights[SI_CHARGER] = CreateConVar("cz_charger_weight", "50", "charger产生比重", CVAR_FLAGS, true, 0.0);
	g_hScaleWeights = CreateConVar("cz_scale_weights", "1",	"[ 0 = 关闭 | 1 = 开启 ] 缩放相应特感的产生比重", _, true, 0.0, true, 1.0);

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

	vIsAllowed();

	RegAdminCmd("sm_cz", cmdCz, ADMFLAG_ROOT, "测试");
	RegConsoleCmd("sm_team2", cmdTeam2, "切换到Team 2.");
	RegConsoleCmd("sm_team3", cmdTeam3, "切换到Team 3.");
	RegConsoleCmd("sm_bp", cmdBP, "叛变为坦克.");
	RegConsoleCmd("sm_class", cmdChangeClass, "更改特感类型.");
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);

	for(int i = 1; i <= MaxClients; i++)
		vRemoveSurvivorModelGlow(i);
}

public void OnConfigsExecuted()
{
	vIsAllowed();
	vGetOtherCvars();
	vGetColorCvars();
	vGetSpawnCvars();
	vGetAccessCvars();
}

public void vModeConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vIsAllowed()
{
	g_hGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));

	bool bLast = g_bHasPlayerControlledZombies;
	g_bHasPlayerControlledZombies = SDKCall(g_hSDK_Call_HasPlayerControlledZombies);
	if(g_bHasPlayerControlledZombies == true)
	{
		vToggle(false);
		if(bLast != g_bHasPlayerControlledZombies)
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
		if(bLast != g_bHasPlayerControlledZombies)
		{
			if(bHasPlayerZombie())
			{
				float fTime = GetEngineTime();
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
								if(!IsPlayerAlive(i))
								{
									vCalculatePZRespawnTime(i);
									g_fStartRespawnTime[i] = fTime;
								}
								//ChangeClientTeam(i, 1);
								//ChangeClientTeam(i, 3);
								CPrintToChat(i, "如果看不到[{red}特感梯子{default}]，请先[{olive}切换{default}]到其他[{red}团队{default}]再切换回来刷新[{olive}显示状态{default}]");
							}
						}
					}
				}

				delete g_hTimer;
				g_hTimer = CreateTimer(0.1, Timer_Player, _, TIMER_REPEAT);
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

public void vColorConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetColorCvars();
}

void vGetColorCvars()
{
	bool bLast = g_bGlowColorEnable;
	g_bGlowColorEnable = g_hGlowColorEnable.BoolValue;
	g_iSurvivorMaxIncapacitatedCount = g_hSurvivorMaxIncapacitatedCount.IntValue;

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
	hConVar.GetString(sTemp, sizeof(sTemp));

	if(sTemp[0] == 0)
		return 1;

	char sColors[3][4];
	int iColor = ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));

	if(iColor != 3)
		return 1;
		
	iColor = StringToInt(sColors[0]);
	iColor += 256 * StringToInt(sColors[1]);
	iColor += 65536 * StringToInt(sColors[2]);

	return iColor > 0 ? iColor : 1;
}

public void vAccessConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
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
	g_hUserFlagBits.GetString(sTemp, sizeof(sTemp));

	char sUserFlagBits[5][26];
	ExplodeString(sTemp, ";", sUserFlagBits, sizeof(sUserFlagBits), sizeof(sUserFlagBits[]));

	for(int i; i < 5; i++)
		g_iUserFlagBits[i] = ReadFlagString(sUserFlagBits[i]);
}

void vGetImmunityLevels()
{
	char sTemp[128];
	g_hImmunityLevels.GetString(sTemp, sizeof(sTemp));

	char sImmunityLevels[5][8];
	ExplodeString(sTemp, ";", sImmunityLevels, sizeof(sImmunityLevels), sizeof(sImmunityLevels[]));

	for(int i; i < 5; i++)
		g_iImmunityLevels[i] = StringToInt(sImmunityLevels[i]);
}

static bool bCheckClientAccess(int client, int iIndex)
{
	if(g_iUserFlagBits[iIndex] == 0)
		return true;

	static int iFlagBits;
	if((iFlagBits = GetUserFlagBits(client)) & ADMFLAG_ROOT == 0 && iFlagBits & g_iUserFlagBits[iIndex] == 0)
		return false;

	static char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return true;

	return admin.ImmunityLevel >= g_iImmunityLevels[iIndex];
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
	g_bScaleWeights = g_hScaleWeights.BoolValue;
}

public Action cmdCz(int client, int args)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) < 2)
		return Plugin_Handled;

	SDKCall(g_hSDK_Call_CleanupPlayerState, client);
	return Plugin_Handled;
}

public Action cmdTeam2(int client, int args)
{
	if(g_bHasPlayerControlledZombies)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(bCheckClientAccess(client, 0) == false)
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

public Action cmdTeam3(int client, int args)
{
	if(g_bHasPlayerControlledZombies)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
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

public Action cmdBP(int client, int args)
{
	if(g_bHasPlayerControlledZombies)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if(bCheckClientAccess(client, 2) == false)
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

public Action cmdChangeClass(int client, int args)
{
	if(g_bHasPlayerControlledZombies)
	{
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if(bCheckClientAccess(client, 3) == false)
	{
		PrintToChat(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if(GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost") == 0)
	{
		PrintToChat(client, "灵魂状态下的特感才能使用该指令");
		return Plugin_Handled;
	}

	if(g_iMaterialized[client] != 0)
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
	Menu menu = new Menu(iDisplayClassMenuHandler);
	menu.SetTitle("!class付出一定代价更改特感类型?");
	menu.AddItem("yes", "是");
	menu.AddItem("no", "否");
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, 15);
}

public int iDisplayClassMenuHandler(Menu menu, MenuAction action, int client, int param2)
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
	Menu menu = new Menu(iSelectZombieClassMenuHandler);
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
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, 30);
}

public int iSelectZombieClassMenuHandler(Menu menu, MenuAction action, int client, int param2)
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
	if(g_bHasPlayerControlledZombies || IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
		return Plugin_Continue;

	static int iFlags;
	iFlags = GetEntProp(client, Prop_Data, "m_afButtonPressed");
	if(GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(iFlags & IN_ZOOM)
		{
			if(g_iMaterialized[client] == 0 && bCheckClientAccess(client, 3) == true)
				vSelectAscendingZombieClass(client);
		}
		else if(iFlags & IN_ATTACK)
		{
			if(GetEntProp(client, Prop_Send, "m_ghostSpawnState") == 1)
				SDKCall(g_hSDK_Call_MaterializeFromGhost, client);
		}
	}
	else
	{
		if(iFlags & IN_ZOOM && bCheckClientAccess(client, 4) == true)
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
	g_fMapStartTime = GetGameTime();
	for(int i = 1; i <= MaxClients; i++)
		g_fBugExploitTime[i][0] = g_fBugExploitTime[i][1] = g_fMapStartTime;
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasAnySurvivorLeftSafeArea = false;
	delete g_hTimer;
}

public void OnClientDisconnect(int client)
{
	vRemoveSurvivorModelGlow(client);

	if(IsFakeClient(client))
		return;

	if(g_iLastTeamId[client] == 2)
		g_iLastTeamId[client] = GetClientTeam(client);
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;

	vResetClientData(client);
}

void vResetClientData(int client)
{
	vSurvivorClean(client);

	g_iMaterialized[client] = 0;
	g_iEnteredGhostState[client] = 0;
	g_fStartRespawnTime[client] = 0.0;
	g_fStartSuicideTime[client] = 0.0;
	
	g_bIsPlayerBP[client] = false;
	g_bUsedClassCmd[client] = false;
}

//------------------------------------------------------------------------------
//Event
public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{ 
	if(g_bHasAnySurvivorLeftSafeArea || !bIsRoundStarted())
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		CreateTimer(0.1, Timer_PlayerLeftStartArea, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool bIsRoundStarted()
{
	return g_iRoundStart && g_iPlayerSpawn;
}

public Action Timer_PlayerLeftStartArea(Handle timer)
{
	if(!g_bHasAnySurvivorLeftSafeArea && bIsRoundStarted() && bHasAnySurvivorLeftSafeArea())
	{
		g_bHasAnySurvivorLeftSafeArea = true;

		if(!g_bHasPlayerControlledZombies)
		{
			if(g_iPZRespawnTime > 0)
			{
				float fTime = GetEngineTime();
				for(int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3 && !IsPlayerAlive(i))
					{
						g_iCurrentPZRespawnTime[i] = 0;
						g_fStartRespawnTime[i] = fTime;
					}
				}
			}

			delete g_hTimer;
			g_hTimer = CreateTimer(0.1, Timer_Player, _, TIMER_REPEAT);
		}
	}
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
	g_iCurrentPZRespawnTime[client] = g_iPZRespawnTime;

	if(g_iPZPunishTime > 0 && g_bUsedClassCmd[client])
		g_iCurrentPZRespawnTime[client] += g_iPZPunishTime;
		
	g_bUsedClassCmd[client] = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		vRemoveInfectedClips();
	g_iRoundStart = 1;

	delete g_hTimer;
	for(int i = 1; i <= MaxClients; i++)
	{
		g_fStartRespawnTime[i] = 0.0;
		g_fStartSuicideTime[i] = 0.0;
	}
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

	delete g_hTimer;
	for(int i = 1; i <= MaxClients; i++)
		vResetClientData(i);

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

	g_iMaterialized[client] = 0;
	vRemoveSurvivorModelGlow(client);

	if(IsFakeClient(client))
		return;

	g_fStartRespawnTime[client] = 0.0;
	g_fStartSuicideTime[client] = 0.0;

	int team = event.GetInt("team");
	if(team == 3)
	{
		if(g_iPZRespawnTime > 0 && g_bHasAnySurvivorLeftSafeArea == true)
		{
			vCalculatePZRespawnTime(client);
			g_fStartRespawnTime[client] = GetEngineTime();
		}

		CreateTimer(0.1, Timer_LadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);
	}

	switch(event.GetInt("oldteam"))
	{
		case 0:
		{
			if(team == 3 && (g_iPZChangeTeamTo || g_iLastTeamId[client] == 3))
				RequestFrame(OnNextFrame_ChangeTeamTo, userid);

			g_iLastTeamId[client] = 0;
		}
		
		case 3:
		{
			g_iLastTeamId[client] = 0;

			if(team == 2 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
				SetEntProp(client, Prop_Send, "m_isGhost", 0); //SDKCall(g_hSDK_Call_MaterializeFromGhost, client);
			
			CreateTimer(0.1, Timer_LadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_LadderAndGlow(Handle timer, any client)
{
	if(!g_bHasPlayerControlledZombies && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client))
	{
		if(GetClientTeam(client) == 3)
		{
			SendConVarValue(client, g_hGameMode, "versus");
			if(iGetTeamPlayers(3) == 1)
			{
				for(int i = 1; i <= MaxClients; i++)
					vCreateSurvivorModelGlow(i);

				delete g_hTimer;
				g_hTimer = CreateTimer(0.1, Timer_Player, _, TIMER_REPEAT);
			}
		}
		else
		{
			SendConVarValue(client, g_hGameMode, g_sGameMode);
			
			int i;
			for(i = 1; i <= MaxClients; i++)
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
}

void OnNextFrame_ChangeTeamTo(any client)
{
	if(!g_bHasPlayerControlledZombies && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3)
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
	if(!IsPlayerAlive(client))
		return;
	
	g_iTankBot[client] = 0;
	g_fStartRespawnTime[client] = 0.0;

	if(!g_bOnMaterializeFromGhost)
	{
		RequestFrame(OnNextFrame_PlayerSpawn, userid); //player_bot_replace在player_spawn之后触发，延迟一帧进行接管判断

		if(!IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_isGhost") == 0)
			vSetInfectedGhost(client, GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
	}
}

void OnNextFrame_PlayerSpawn(any client)
{
	if(g_bHasPlayerControlledZombies || (client = GetClientOfUserId(client))== 0 || !IsClientInGame(client) || IsClientInKickQueue(client) || !IsPlayerAlive(client))
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
				if(g_iTankBot[client] != 2 && iGetTankPlayers() < g_iMaxTankPlayer)
				{
					if((iPlayer = iTakeOverTank(client)))
						CPrintToChatAll("{green}★ {red}AI Tank {default}已被 {red}%N {olive}接管", iPlayer);
				}

				if(iPlayer == 0 && (GetEntProp(client, Prop_Data, "m_bIsInStasis") == 1 || SDKCall(g_hSDK_Call_IsInStasis, client)))
					SDKCall(g_hSDK_Call_LeaveStasis, client); //解除战役模式下特感方有玩家存在时坦克卡住的问题
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

	g_iMaterialized[client] = 0;
	g_fStartSuicideTime[client] = 0.0;

	switch(GetClientTeam(client))
	{
		case 2:
		{
			vRemoveSurvivorModelGlow(client);
			if(g_bExchangeTeam && !IsFakeClient(client))
			{
				int attacker = GetClientOfUserId(event.GetInt("attacker"));
				if(0 < attacker <= MaxClients && !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
				{
					ChangeClientTeam(client, 3);
					CPrintToChat(client, "{green}★ {red}生还者玩家 {default}被 {red}特感玩家 {default}杀死后，{olive}二者互换队伍");

					if(g_iCmdEnterCooling & (1 << 4))
						g_fCmdLastUsedTime[client] = GetEngineTime();
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
					g_fStartRespawnTime[client] = GetEngineTime();
				}

				if(g_iLastTeamId[client] == 2 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
				{
					if(g_iCmdEnterCooling & (1 << 2))
						g_fCmdLastUsedTime[client] = GetEngineTime();
					RequestFrame(OnNextFrame_ChangeTeamToSurvivor, userid);
					CPrintToChat(client, "{green}★ {olive}玩家Tank {default}死亡后自动切换回 {blue}生还者队伍");
				}
			}
		}
	}
}

public Action Timer_Player(Handle timer)
{
	if(g_bHasPlayerControlledZombies)
		return Plugin_Continue;

	static int i;
	static int iTime;
	static int iModelIndex;
	static int iLastCountdown[MAXPLAYERS + 1];
	static float fTime;
	static float fInterval;
	static char sModelName[128];

	fTime = GetEngineTime();

	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		switch(GetClientTeam(i))
		{
			case 2:
			{
				if(!g_bGlowColorEnable || !IsPlayerAlive(i) || !bIsValidEntRef(g_iModelEntRef[i]))
					continue;

				if(g_iModelIndex[i] != (iModelIndex = GetEntProp(i, Prop_Data, "m_nModelIndex")))
				{
					g_iModelIndex[i] = iModelIndex;
					GetEntPropString(i, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
					SetEntityModel(g_iModelEntRef[i], sModelName);
				}

				vSetGlowColor(i);
			}

			case 3:
			{
				if(!g_bHasAnySurvivorLeftSafeArea || IsFakeClient(i))
					continue;

				if(!IsPlayerAlive(i))
				{
					if(g_fStartRespawnTime[i])
					{
						if((fInterval = fTime - g_fStartRespawnTime[i]) >= g_iCurrentPZRespawnTime[i])
						{
							if(bAttemptRespawnPZ(i))
							{
								PrintToConsole(i, "重生预设->%d秒 实际耗时->%.5f秒", g_iCurrentPZRespawnTime[i], fInterval);
								g_fStartRespawnTime[i] = 0.0;
							}
						}
						else
						{
							iTime = RoundToCeil(g_iCurrentPZRespawnTime[i] - fInterval);
							if(iTime != iLastCountdown[i])
							{
								PrintCenterText(i, "%d 秒后重生", iTime);
								iLastCountdown[i] = iTime;
							}
						}
					}
				}
				else
				{
					if(g_fStartSuicideTime[i] && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
					{
						fInterval = fTime - g_fStartSuicideTime[i];
						if(fTime - g_fStartSuicideTime[i] >= g_iPZSuicideTime)
						{
							ForcePlayerSuicide(i);
							CPrintToChat(i, "{olive}处死预设{default}-> {red}%d秒 {olive}实际耗时{default}-> {red}%.5f秒", g_iPZSuicideTime, fInterval);
							g_fStartSuicideTime[i] = 0.0;
						}
					}	
				}
			}
		}
	}
	
	return Plugin_Continue;
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
	FakeClientCommand(client, "spec_next"); //相比于手动获取玩家位置传送，更省力和节约资源的方法

	if(GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_lifeState") != 1)
		SetEntProp(client, Prop_Send, "m_lifeState", 1);

	g_iSpawnablePZ = client;
	vCheatCommand(client, "z_spawn_old", g_sZombieClass[iZombieClass]);
	g_iSpawnablePZ = 0;
	return IsPlayerAlive(client);
}

public void Event_TankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(g_iLastTeamId[client] != 2 || IsFakeClient(client))
		return;

	if(g_iCmdEnterCooling & (1 << 1))
		g_fCmdLastUsedTime[client] = GetEngineTime();
	RequestFrame(OnNextFrame_ChangeTeamToSurvivor, GetClientUserId(client));
	CPrintToChat(client, "{green}★ {default}丢失 {olive}Tank控制权 {default}后自动切换回 {blue}生还者队伍");
}

public void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int bot_userid = event.GetInt("bot");
	int player_userid = event.GetInt("player");
	int bot = GetClientOfUserId(bot_userid);
	int player = GetClientOfUserId(player_userid);

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

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if(jockey != -1)
		vCheatCommand(jockey, "dismount", "");
}

public Action Timer_ReturnToSurvivor(Handle timer, any client)
{
	static int i;
	static int iTimes[MAXPLAYERS + 1] = {20, ...};

	if((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		i = iTimes[client]--;
		if(i > 0)
			PrintCenterText(client, "还有 %d 秒变回生还者,请到掩体后面按鼠标[左键]重生.按[E]键可传送到生还者附近", i);
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
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !iHasIdlePlayer(client);
}

int iHasIdlePlayer(int client)
{
	char sNetClass[64];
	if(!GetEntityNetClass(client, sNetClass, sizeof(sNetClass)))
		return 0;

	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
	if(client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
		return client;

	return 0;
}

int iTakeOverTank(int tank)
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
				ChangeClientTeam(client, 3);
				CreateTimer(1.0, Timer_ReturnToSurvivor, GetClientUserId(client), TIMER_REPEAT);
			}
			
			case 3:
			{
				if(IsPlayerAlive(client))
				{
					SDKCall(g_hSDK_Call_CleanupPlayerState, client);
					ForcePlayerSuicide(client);
				}
			}
		}

		return iTakeOverZombieBot(client, tank) == 8 && IsPlayerAlive(client) ? client : 0;
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
	if(!g_bGlowColorEnable || bIsRoundStarted() == false || !IsClientInGame(client) || IsClientInKickQueue(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client) || bIsValidEntRef(g_iModelEntRef[client]))
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

	SetEntProp(iEntity, Prop_Data, "m_iEFlags", 0);
	SetEntProp(iEntity, Prop_Data, "m_fEffects", 0x020); //don't draw entity

	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 20000);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", 1);
	vSetGlowColor(client);

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetAttached", client);

	SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action Hook_SetTransmit(int entity, int client)
{
	if(!IsFakeClient(client) && GetClientTeam(client) == 3)
		return Plugin_Continue;

	return Plugin_Handled;
}

static void vSetGlowColor(int client)
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
	if(!bIsValidEntRef(g_iModelEntRef[client]))
		return;

	RemoveEntity(g_iModelEntRef[client]);
	g_iModelEntRef[client] = 0;
}

static bool bIsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

//------------------------------------------------------------------------------
//切换回生还者
void OnNextFrame_ChangeTeamToSurvivor(any client)
{
	if(g_bHasPlayerControlledZombies || (client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client))
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
		SetEntProp(client, Prop_Send, "m_isGhost", 0); //SDKCall(g_hSDK_Call_MaterializeFromGhost, client);

	int iBot = GetClientOfUserId(g_iPlayerBot[client]);
	if(iBot == 0 || !bIsValidAliveSurvivorBot(iBot))
		iBot = iGetAnyValidAliveSurvivorBot();

	if(iTeam != 1)
		ChangeClientTeam(client, 1);

	if(iBot)
	{
		SDKCall(g_hSDK_Call_SetHumanSpectator, iBot, client);
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

//https://forums.alliedmods.net/showthread.php?p=2398822#post2398822
void vSurvivorStatus(int client, int iType)
{
	static bool bRecorded[MAXPLAYERS + 1];
	static int iStatusInfo[MAXPLAYERS + 1][6];
	
	switch(iType)
	{
		case 0:
		{
			bRecorded[client] = false;
			vCleanStatus(client, iStatusInfo);
		}
			
		case 1:
		{
			bRecorded[client] = true;
			vSaveStatus(client, iStatusInfo);
		}
			
		case 2:
		{
			if(bRecorded[client] && IsPlayerAlive(client))
				vSetStatus(client, iStatusInfo);
		}
	}
}

void vCleanStatus(int client, int[][] iStatusInfo)
{
	iStatusInfo[client][0] = 0;
	iStatusInfo[client][1] = 0;
	iStatusInfo[client][2] = 0;
	iStatusInfo[client][3] = 0;
	iStatusInfo[client][4] = 0;
	iStatusInfo[client][5] = 0;
	iStatusInfo[client][6] = -1;
}

void vSaveStatus(int client, int[][] iStatusInfo)
{
	if(!IsPlayerAlive(client))
	{
		iStatusInfo[client][3] = 50;
		return;
	}

	iStatusInfo[client][0] = GetEntProp(client, Prop_Send, "m_currentReviveCount");
	iStatusInfo[client][1] = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
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

void vSetStatus(int client, int[][] iStatusInfo)
{
	if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
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

int g_iGrenadeThrower[MAXPLAYERS + 1];
public void OnEntityCreated(int entity, const char[] classname)
{
	if(classname[0] != 'm' && classname[0] != 'p' && classname[0] != 'v')
		return;

	if(strncmp(classname, "molotov_projectile", 19) == 0 || strncmp(classname, "pipe_bomb_projectile", 21) == 0 || strncmp(classname, "vomitjar_projectile", 20) == 0)
		SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
}

public void Hook_SpawnPost(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
	if(entity <= MaxClients || !IsValidEntity(entity))
		return;

	int iOwner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if(0 < iOwner <= MaxClients && IsClientInGame(iOwner) && GetClientTeam(iOwner) == 2)
	{
		int iSlot = GetPlayerWeaponSlot(iOwner, 2);
		if(iSlot > MaxClients)
			g_iGrenadeThrower[iOwner] = EntIndexToEntRef(iSlot);
	}
}

void vRemoveWeapons(int client)
{
	int iWeapon;
	for(int iSlot; iSlot < 5; iSlot++)
	{
		iWeapon = GetPlayerWeaponSlot(client, iSlot);
		if(iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			if(RemovePlayerItem(client, iWeapon))
				RemoveEdict(iWeapon);
		}
	}
}

void vSurvivorWeapons(int client, int iType)
{
	static bool bRecorded[MAXPLAYERS + 1];
	static int iWeaponInfo[MAXPLAYERS + 1][7];
	static char sWeaponInfo[MAXPLAYERS + 1][6][32];
	
	switch(iType)
	{
		case 0:
		{
			bRecorded[client] = false;
			vCleanWeapons(client, iWeaponInfo, sWeaponInfo);
		}
			
		case 1:
		{
			if(IsPlayerAlive(client) && bSaveWeapons(client, iWeaponInfo, sWeaponInfo, sizeof(sWeaponInfo[][])))
				bRecorded[client] = true;
		}
			
		case 2:
		{
			if(bRecorded[client] == true && IsPlayerAlive(client))
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
	sWeaponInfo[client][5][0] = '\0';
}

bool bSaveWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo, int maxlength)
{
	bool bSaved;
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

		bSaved = true;
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
		
		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 2);
	if(iSlot > MaxClients)
	{
		if(EntIndexToEntRef(iSlot) != g_iGrenadeThrower[client])
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			strcopy(sWeaponInfo[client][2], maxlength, sWeapon);
			
			bSaved = true;
		}
	}

	iSlot = GetPlayerWeaponSlot(client, 3);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][3], maxlength, sWeapon);
		
		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 4);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][4], maxlength, sWeapon);
		
		bSaved = true;
	}
	
	if(bSaved == true)
	{
		iSlot = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			strcopy(sWeaponInfo[client][5], maxlength, sWeapon);
		}
	}
	
	return bSaved;
}

void vGiveWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo)
{
	int iSlot;
	bool bGiven;

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
				
			bGiven = true;
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
				
			bGiven = true;
		}
	}

	if(sWeaponInfo[client][2][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][2]);

		iSlot = GetPlayerWeaponSlot(client, 2);
		if(iSlot > MaxClients)
			bGiven = true;
	}

	if(sWeaponInfo[client][3][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][3]);

		iSlot = GetPlayerWeaponSlot(client, 3);
		if(iSlot > MaxClients)
			bGiven = true;
	}

	if(sWeaponInfo[client][4][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][4]);

		iSlot = GetPlayerWeaponSlot(client, 4);
		if(iSlot > MaxClients)
			bGiven = true;
	}
		
	if(bGiven == true && sWeaponInfo[client][5][0] != '\0')
		FakeClientCommand(client, "use %s", sWeaponInfo[client][5]);
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
	int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags);
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
		if(IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
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

	for(; i < 6; i++)
	{
		iTempSpawnWeights[i] = g_iSpawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - g_iSpawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
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
	for(; i < 6; i++)
		g_iSpawnCounts[i] = 0;

	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			switch(GetEntProp(i, Prop_Send, "m_zombieClass"))
			{
				case 1:
					g_iSpawnCounts[SI_SMOKER]++;

				case 2:
					g_iSpawnCounts[SI_BOOMER]++;

				case 3:
					g_iSpawnCounts[SI_HUNTER]++;

				case 4:
					g_iSpawnCounts[SI_SPITTER]++;

				case 5:
					g_iSpawnCounts[SI_JOCKEY]++;
		
				case 6:
					g_iSpawnCounts[SI_CHARGER]++;
			}
		}
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
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCSPlayer::State_Transition") == false)
		SetFailState("Failed to find signature: CCSPlayer::State_Transition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_State_Transition = EndPrepSDKCall();
	if(g_hSDK_Call_State_Transition == null)
		SetFailState("Failed to create SDKCall: CCSPlayer::State_Transition");
		
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::MaterializeFromGhost") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::MaterializeFromGhost");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_MaterializeFromGhost = EndPrepSDKCall();
	if(g_hSDK_Call_MaterializeFromGhost == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::MaterializeFromGhost");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SetClass") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::SetClass");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Call_SetClass = EndPrepSDKCall();
	if(g_hSDK_Call_SetClass == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::SetClass");
	
	StartPrepSDKCall(SDKCall_Static);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CBaseAbility::CreateForPlayer") == false)
		SetFailState("Failed to find signature: CBaseAbility::CreateForPlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_Call_CreateForPlayer = EndPrepSDKCall();
	if(g_hSDK_Call_CreateForPlayer == null)
		SetFailState("Failed to create SDKCall: CBaseAbility::CreateForPlayer");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::CleanupPlayerState") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::CleanupPlayerState");
	g_hSDK_Call_CleanupPlayerState = EndPrepSDKCall();
	if(g_hSDK_Call_CleanupPlayerState == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::CleanupPlayerState");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverZombieBot") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::TakeOverZombieBot");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_Call_TakeOverZombieBot = EndPrepSDKCall();
	if(g_hSDK_Call_TakeOverZombieBot == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::TakeOverZombieBot");
	
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::RoundRespawn");
	g_hSDK_Call_RoundRespawn = EndPrepSDKCall();
	if(g_hSDK_Call_RoundRespawn == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::RoundRespawn");
	
	vRegisterStatsConditionPatch(hGameData);

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator") == false)
		SetFailState("Failed to find signature: SurvivorBot::SetHumanSpectator");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_Call_SetHumanSpectator = EndPrepSDKCall();
	if(g_hSDK_Call_SetHumanSpectator == null)
		SetFailState("Failed to create SDKCall: SurvivorBot::SetHumanSpectator");

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot") == false)
		SetFailState("Failed to find signature: CTerrorPlayer::TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_TakeOverBot = EndPrepSDKCall();
	if(g_hSDK_Call_TakeOverBot == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::TakeOverBot");

	StartPrepSDKCall(SDKCall_Static);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::HasPlayerControlledZombies") == false)
		SetFailState("Failed to find signature: CTerrorGameRules::HasPlayerControlledZombies");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_Call_HasPlayerControlledZombies = EndPrepSDKCall();
	if(g_hSDK_Call_HasPlayerControlledZombies == null)
		SetFailState("Failed to create SDKCall: CTerrorGameRules::HasPlayerControlledZombies");

	g_dDetour[0] = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::OnEnterGhostState");
	if(g_dDetour[0] == null)
		SetFailState("Failed to load signature: CTerrorPlayer::OnEnterGhostState");

	g_dDetour[1] = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::MaterializeFromGhost");
	if(g_dDetour[1] == null)
		SetFailState("Failed to load signature: CTerrorPlayer::MaterializeFromGhost");

	g_dDetour[2] = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::PlayerZombieAbortControl");
	if(g_dDetour[2] == null)
		SetFailState("Failed to load signature: CTerrorPlayer::PlayerZombieAbortControl");
	
	g_dDetour[3] = DynamicDetour.FromConf(hGameData, "ForEachTerrorPlayer<SpawnablePZScan>");
	if(g_dDetour[3] == null)
		SetFailState("Failed to load signature: ForEachTerrorPlayer<SpawnablePZScan>");

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
	static float vOrigin[3];
	static float vAngles[3];
	static float vVelocity[3];

	if(bSavePos)
	{
		GetClientAbsOrigin(client, vOrigin);
		GetClientEyeAngles(client, vAngles);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVelocity);
	}

	SDKCall(g_hSDK_Call_State_Transition, client, 8);

	if(bSavePos)
		TeleportEntity(client, vOrigin, vAngles, vVelocity);
}

void vSetZombieClass(int client, int iZombieClass)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0);
	if(iWeapon != -1)
	{
		if(RemovePlayerItem(client, iWeapon))
			RemoveEdict(iWeapon);
	}

	int iAbility = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if(iAbility != -1)
		RemoveEdict(iAbility);

	SDKCall(g_hSDK_Call_SetClass, client, iZombieClass);

	iAbility = SDKCall(g_hSDK_Call_CreateForPlayer, client);
	if(iAbility != -1)
		SetEntPropEnt(client, Prop_Send, "m_customAbility", iAbility);
}

int iTakeOverZombieBot(int client, int iZombieBot)
{
	AcceptEntityInput(client, "ClearParent");
	SDKCall(g_hSDK_Call_TakeOverZombieBot, client, iZombieBot);
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

void vRoundRespawn(int client)
{
	vStatsConditionPatch(true);
	SDKCall(g_hSDK_Call_RoundRespawn, client);
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

void vToggleDetours(bool bEnable)
{
	static bool bEnabled;
	if(!bEnabled && bEnable)
	{
		bEnabled = true;

		if(!g_dDetour[0].Enable(Hook_Pre, mreOnEnterGhostStatePre))
			SetFailState("Failed to detour pre: CTerrorPlayer::OnEnterGhostState");
		
		if(!g_dDetour[0].Enable(Hook_Post, mreOnEnterGhostStatePost))
			SetFailState("Failed to detour post: CTerrorPlayer::OnEnterGhostState");
			
		if(!g_dDetour[1].Enable(Hook_Pre, mreMaterializeFromGhostPre))
			SetFailState("Failed to detour pre: CTerrorPlayer::MaterializeFromGhost");
		
		if(!g_dDetour[1].Enable(Hook_Post, mreMaterializeFromGhostPost))
			SetFailState("Failed to detour post: CTerrorPlayer::MaterializeFromGhost");
			
		if(!g_dDetour[2].Enable(Hook_Pre, mrePlayerZombieAbortControlPre))
			SetFailState("Failed to detour pre: CTerrorPlayer::PlayerZombieAbortControl");
		
		if(!g_dDetour[2].Enable(Hook_Post, mrePlayerZombieAbortControlPost))
			SetFailState("Failed to detour post: CTerrorPlayer::PlayerZombieAbortControl");
			
		if(!(g_bIsSpawnablePZSupported = g_dDetour[3].Enable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre)))
			SetFailState("Failed to detour pre: ForEachTerrorPlayer<SpawnablePZScan>");
		
		if(!(g_bIsSpawnablePZSupported = g_dDetour[3].Enable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost)))
			SetFailState("Failed to detour post: ForEachTerrorPlayer<SpawnablePZScan>");
	}
	else if(bEnabled && !bEnable)
	{
		bEnabled = false;

		g_bIsSpawnablePZSupported = false;

		if(!g_dDetour[0].Disable(Hook_Pre, mreOnEnterGhostStatePre) || !g_dDetour[0].Disable(Hook_Post, mreOnEnterGhostStatePost))
			SetFailState("Failed to disable detour: CTerrorPlayer::OnEnterGhostState");
		
		if(!g_dDetour[1].Enable(Hook_Pre, mreMaterializeFromGhostPre) || !g_dDetour[1].Disable(Hook_Post, mreMaterializeFromGhostPost))
			SetFailState("Failed to disable detour: CTerrorPlayer::MaterializeFromGhost");
		
		if(!g_dDetour[2].Enable(Hook_Pre, mrePlayerZombieAbortControlPre) || !g_dDetour[2].Disable(Hook_Post, mrePlayerZombieAbortControlPost))
			SetFailState("Failed to disable detour: CTerrorPlayer::PlayerZombieAbortControl");
		
		if(!g_dDetour[3].Enable(Hook_Pre, mreForEachTerrorPlayerSpawnablePZScanPre) || !g_dDetour[3].Disable(Hook_Post, mreForEachTerrorPlayerSpawnablePZScanPost))
			SetFailState("Failed to disable detour: ForEachTerrorPlayer<SpawnablePZScan>");
	}
}

public MRESReturn mreOnEnterGhostStatePre(int pThis)
{
	if(bIsRoundStarted() == false)
		return MRES_Supercede; //阻止死亡状态下的特感玩家在团灭后下一回合开始前进入Ghost State
	
	return MRES_Ignored;
}

public MRESReturn mreOnEnterGhostStatePost(int pThis)
{
	if(g_iMaterialized[pThis] == 0 && !IsFakeClient(pThis))
		RequestFrame(OnNextFrame_EnterGhostState, GetClientUserId(pThis));
	
	return MRES_Ignored;
}

public MRESReturn mreMaterializeFromGhostPre(int pThis)
{
	g_bOnMaterializeFromGhost = true;

	if(!IsFakeClient(pThis) && GetGameTime() - g_fBugExploitTime[pThis][1] < 1.5)
		return MRES_Supercede;

	return MRES_Ignored;
}

public MRESReturn mreMaterializeFromGhostPost(int pThis)
{
	g_iMaterialized[pThis]++;
	g_bOnMaterializeFromGhost = false;

	if(!IsFakeClient(pThis))
	{
		g_fBugExploitTime[pThis][0] = GetGameTime();
		if(g_iMaterialized[pThis] == 1 && g_iPZRespawnTime > 0 && g_iPZPunishTime > 0 && g_bUsedClassCmd[pThis] && GetEntProp(pThis, Prop_Send, "m_zombieClass") != 8)
			CPrintToChat(pThis, "{olive}下次重生时间 {default}-> {red}+%d秒", g_iPZPunishTime);
	}

	return MRES_Ignored;
}

public MRESReturn mrePlayerZombieAbortControlPre(int pThis)
{
	if(!IsFakeClient(pThis) && GetGameTime() - g_fBugExploitTime[pThis][0] < 1.5)
		return MRES_Supercede;

	return MRES_Ignored;
}

public MRESReturn mrePlayerZombieAbortControlPost(int pThis)
{
	if(!IsFakeClient(pThis))
		g_fBugExploitTime[pThis][1] = GetGameTime();

	return MRES_Ignored;
}

public MRESReturn mreForEachTerrorPlayerSpawnablePZScanPre()
{
	vSpawnablePZScanProtect(0);
	return MRES_Ignored;
}

public MRESReturn mreForEachTerrorPlayerSpawnablePZScanPost()
{
	vSpawnablePZScanProtect(1);
	return MRES_Ignored;
}

void OnNextFrame_EnterGhostState(any client)
{
	if(!g_bHasPlayerControlledZombies && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != 8 && GetEntProp(client, Prop_Send, "m_isGhost") == 1)
	{
		if(g_iEnteredGhostState[client] == 0)
		{
			if(bCheckClientAccess(client, 0) == true)
				CPrintToChat(client, "{default}聊天栏输入 {olive}!team2 {default}可切换回{blue}生还者");
				
			if(bCheckClientAccess(client, 3) == true)
				PrintCenterText(client, "灵魂状态下按下鼠标[中键]可以快速切换特感");
		}

		vClassSelectionMenu(client);
		g_iEnteredGhostState[client]++;
	
		if(g_iPZSuicideTime > 0)
			g_fStartSuicideTime[client] = GetEngineTime();
	}
}

void vClassSelectionMenu(int client)
{
	if((g_iAutoDisplayMenu == -1 || g_iEnteredGhostState[client] < g_iAutoDisplayMenu) && bCheckClientAccess(client, 4) == true)
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
