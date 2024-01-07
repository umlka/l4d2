#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <adminmenu>
#include <dhooks>
#include <sdkhooks>

#define PLUGIN_PREFIX			"\x01[\x04SCS\x01]"
#define PLUGIN_NAME				"Survivor Chat Select"
#define PLUGIN_AUTHOR			"DeatChaos25, Mi123456 & Merudo, Lux, SilverShot"
#define PLUGIN_DESCRIPTION		"Select a survivor character by typing their name into the chat."
#define PLUGIN_VERSION			"1.8.6"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?p=2399163#post2399163"

#define GAMEDATA				"survivor_chat_select"

#define DEBUG					0

#define	 NICK					0, 0
#define	 ROCHELLE				1, 1
#define	 COACH					2, 2
#define	 ELLIS					3, 3
#define	 BILL					4, 4
#define	 ZOEY					5, 5
#define	 FRANCIS				6, 6
#define	 LOUIS					7, 7

Handle
	g_hSDK_CTerrorGameRules_GetMissionInfo,
	g_hSDK_CDirector_IsInTransition,
	g_hSDK_KeyValues_GetInt;

DynamicDetour
	g_ddRestoreTransitionedSurvivorBot,
	g_ddInfoChangelevel_ChangeLevelNow;

StringMap
	g_smSurModels;

TopMenu
	g_TopMenu;

Address
	g_pDirector,
	g_pSavedPlayersCount,
	g_pSavedSurvivorBotsCount;

ConVar
	g_cAutoModel,
	g_cTabHUDBar,
	g_cAdminFlags,
	g_cInTransition,
	g_cPrecacheAllSur;

int
	g_iTabHUDBar,
	g_iAdminFlags,
	g_iOrignalSet,
	g_iTransitioning[MAXPLAYERS + 1],
	g_iSelectedClient[MAXPLAYERS + 1];

bool
	g_bAutoModel,
	g_bTransition,
	g_bTransitioned,
	g_bInTransition,
	g_bBlockUserMsg,
	g_bRestoringBots,
	g_bBotPlayer[MAXPLAYERS + 1],
	g_bPlayerBot[MAXPLAYERS + 1],
	g_bFirstSpawn[MAXPLAYERS + 1];

static const char
	g_sSurNames[][] = {
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis",
	},
	g_sSurModels[][] = {
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	};

methodmap CPlayerResource {
	public CPlayerResource() {
		return view_as<CPlayerResource>(GetPlayerResourceEntity());
	}

	public int m_iTeam(int client) {
		return GetEntProp(view_as<int>(this), Prop_Send, "m_iTeam", _, client);
	}

	public int m_bConnected(int client) {
		return GetEntProp(view_as<int>(this), Prop_Send, "m_bConnected", _, client);
	}
}

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitGameData();
	g_smSurModels = new StringMap();
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);

	RegConsoleCmd("sm_zoey",		cmdZoeyUse,		"Changes your survivor character into Zoey");
	RegConsoleCmd("sm_nick",		cmdNickUse,		"Changes your survivor character into Nick");
	RegConsoleCmd("sm_ellis",		cmdEllisUse,	"Changes your survivor character into Ellis");
	RegConsoleCmd("sm_coach",		cmdCoachUse,	"Changes your survivor character into Coach");
	RegConsoleCmd("sm_rochelle",	cmdRochelleUse,	"Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_bill",		cmdBillUse,		"Changes your survivor character into Bill");
	RegConsoleCmd("sm_francis",		cmdBikerUse,	"Changes your survivor character into Francis");
	RegConsoleCmd("sm_louis",		cmdLouisUse,	"Changes your survivor character into Louis");

	RegConsoleCmd("sm_z",			cmdZoeyUse,		"Changes your survivor character into Zoey");
	RegConsoleCmd("sm_n",			cmdNickUse,		"Changes your survivor character into Nick");
	RegConsoleCmd("sm_e",			cmdEllisUse,	"Changes your survivor character into Ellis");
	RegConsoleCmd("sm_c",			cmdCoachUse,	"Changes your survivor character into Coach");
	RegConsoleCmd("sm_r",			cmdRochelleUse,	"Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_b",			cmdBillUse,		"Changes your survivor character into Bill");
	RegConsoleCmd("sm_f",			cmdBikerUse,	"Changes your survivor character into Francis");
	RegConsoleCmd("sm_l",			cmdLouisUse,	"Changes your survivor character into Louis");

	RegConsoleCmd("sm_csm",			cmdCsm,			"Brings up a menu to select a client's character");

	RegAdminCmd("sm_csc",			cmdCsc,			ADMFLAG_ROOT, "Brings up a menu to select a client's character");
	RegAdminCmd("sm_setleast",		cmdSetLeast,	ADMFLAG_ROOT, "重新将所有生还者模型设置为重复次数最少的");

	g_cAutoModel =			CreateConVar("l4d_scs_auto_model",		"1",	"开关8人独立模型?", FCVAR_NOTIFY);
	g_cTabHUDBar =			CreateConVar("l4d_scs_tab_hud_bar",		"1",	"在哪些地图上显示一代人物的TAB状态栏? \n0=默认, 1=一代图, 2=二代图, 3=一代和二代图.", FCVAR_NOTIFY);
	g_cAdminFlags =			CreateConVar("l4d_csm_admin_flags",		"z",	"允许哪些玩家使用csm命令(flag参考admin_levels.cfg)? \n留空=所有玩家都能使用, z=仅限root权限的玩家使用.", FCVAR_NOTIFY);
	g_cInTransition =		CreateConVar("l4d_csm_in_transition",	"1",	"启用8人独立模型后不对正在过渡的玩家设置?", FCVAR_NOTIFY);
	g_cPrecacheAllSur =		FindConVar("precache_all_survivors");

	g_cAutoModel.AddChangeHook(CvarChanged);
	g_cTabHUDBar.AddChangeHook(CvarChanged);
	g_cAdminFlags.AddChangeHook(CvarChanged);
	g_cInTransition.AddChangeHook(CvarChanged);

	AutoExecConfig(true);

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu())))
		OnAdminMenuReady(topmenu);

	for (int i; i < sizeof g_sSurModels; i++)
		g_smSurModels.SetValue(g_sSurModels[i], i);
}

public void OnAdminMenuReady(Handle topmenu) {
	TopMenu tmenu = TopMenu.FromHandle(topmenu);
	if (tmenu == g_TopMenu)
		return;

	g_TopMenu = tmenu;
	TopMenuObject category = g_TopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	if (category != INVALID_TOPMENUOBJECT)
		g_TopMenu.AddItem("sm_csc", ItemHandler, category, "sm_csc", ADMFLAG_ROOT);
}

void ItemHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption:
			FormatEx(buffer, maxlength, "更改生还者模型");

		case TopMenuAction_SelectOption:
			cmdCsc(param, 0);
	}
}

Action cmdSetLeast(int client, int args) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			SetLeastCharacter(i);
	}

	return Plugin_Handled;
}

Action cmdCsc(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	char info[12];
	char disp[MAX_NAME_LENGTH];
	Menu menu = new Menu(Csc_MenuHandler);
	menu.SetTitle("目标玩家:");

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		FormatEx(info, sizeof info, "%d", GetClientUserId(i));
		FormatEx(disp, sizeof disp, "%s - %N", GetModelName(i), i);
		menu.AddItem(info, disp);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

// L4D2_Adrenaline_Recovery (https://github.com/LuxLuma/L4D2_Adrenaline_Recovery/blob/ac3f62eebe95d80fcf610fb6c7c1ed56bf4b31d2/%5BL4D2%5DAdrenaline_Recovery.sp#L96-L177)
char[] GetModelName(int client) {
	int idx;
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b'://nick
			idx = 0;
		case 'd'://rochelle
			idx = 1;
		case 'c'://coach
			idx = 2;
		case 'h'://ellis
			idx = 3;
		case 'v'://bill
			idx = 4;
		case 'n'://zoey
			idx = 5;
		case 'e'://francis
			idx = 6;
		case 'a'://louis
			idx = 7;
		default:
			idx = 8;
	}

	strcopy(model, sizeof model, idx == 8 ? "未知" : g_sSurNames[idx]);
	return model;
}

int Csc_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[12];
			menu.GetItem(param2, item, sizeof item);
			g_iSelectedClient[client] = StringToInt(item);

			ShowMenuAdmin(client);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack && g_TopMenu != null)
				g_TopMenu.Display(client, TopMenuPosition_LastCategory);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowMenuAdmin(int client) {
	Menu menu = new Menu(ShowMenuAdmin_MenuHandler);
	menu.SetTitle("人物:");

	menu.AddItem("0", "Nick");
	menu.AddItem("1", "Rochelle");
	menu.AddItem("2", "Coach");
	menu.AddItem("3", "Ellis");
	menu.AddItem("4", "Bill");
	menu.AddItem("5", "Zoey");
	menu.AddItem("6", "Francis");
	menu.AddItem("7", "Louis");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int ShowMenuAdmin_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 >= 0 && param2 <= 7)
				SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), param2, param2);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action cmdCsm(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	Menu menu = new Menu(Csm_MenuHandler);
	menu.SetTitle("选择人物:");

	menu.AddItem("0", "Nick");
	menu.AddItem("1", "Rochelle");
	menu.AddItem("2", "Coach");
	menu.AddItem("3", "Ellis");
	menu.AddItem("4", "Bill");
	menu.AddItem("5", "Zoey");
	menu.AddItem("6", "Francis");
	menu.AddItem("7", "Louis");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int Csm_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 >= 0 && param2 <= 7)
				SetCharacter(client, param2, param2);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

bool CanUse(int client, bool checkAdmin = true) {
	if (!client || !IsClientInGame(client)) {
		ReplyToCommand(client, "角色选择菜单仅适用于游戏中的玩家.");
		return false;
	}

	if (checkAdmin && !CheckCommandAccess(client, "", g_iAdminFlags)) {
		ReplyToCommand(client, "只有管理员才能使用该菜单.");
		return false;
	}

	if (GetClientTeam(client) != 2) {
		ReplyToCommand(client, "角色选择菜单仅适用于幸存者.");
		return false;
	}

	if (L4D_IsPlayerStaggering(client)) {
		ReplyToCommand(client, "硬直状态下无法使用该指令.");
		return false;
	}

	if (IsGettingUp(client)) {
		ReplyToCommand(client, "起身过程中无法使用该指令.");
		return false;
	}

	if (IsPinned(client)) {
		ReplyToCommand(client, "被控制时无法使用该指令.");
		return false;
	}

	return true;
}

/**
 * @brief Checks if a Survivor is currently staggering
 *
 * @param client			Client ID of the player to affect
 *
 * @return Returns true if player is staggering, false otherwise
 */
stock bool L4D_IsPlayerStaggering(int client)
{
	static int m_iQueuedStaggerType = -1;
	if( m_iQueuedStaggerType == -1 )
	m_iQueuedStaggerType = FindSendPropInfo("CTerrorPlayer", "m_staggerDist") + 4;

	if( GetEntData(client, m_iQueuedStaggerType, 4) == -1 )
	{
		if( GetGameTime() >= GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1) )
		{
			return false;
		}

		static float vStgDist[3], vOrigin[3];
		GetEntPropVector(client, Prop_Send, "m_staggerStart", vStgDist);
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", vOrigin);

		static float fStgDist2;
		fStgDist2 = GetEntPropFloat(client, Prop_Send, "m_staggerDist");

		return GetVectorDistance(vStgDist, vOrigin) <= fStgDist2;
	}

	return true;
}

// L4D2_Adrenaline_Recovery (https://github.com/LuxLuma/L4D2_Adrenaline_Recovery/blob/ac3f62eebe95d80fcf610fb6c7c1ed56bf4b31d2/%5BL4D2%5DAdrenaline_Recovery.sp#L96-L177)
bool IsGettingUp(int client) {
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b': {	//nick
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 680, 667, 671, 672, 630, 620, 627:
					return true;
			}
		}

		case 'd': {	//rochelle
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}

		case 'c': {	//coach
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 669, 661, 660, 656, 630, 627, 621:
					return true;
			}
		}

		case 'h': {	//ellis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 684, 676, 675, 671, 625, 635, 632:
					return true;
			}
		}

		case 'v': {	//bill
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}

		case 'n': {	//zoey
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 824, 823, 819, 809, 547, 544, 537:
					return true;
			}
		}

		case 'e': {	//francis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 775, 767, 766, 762, 541, 539, 531:
					return true;
			}
		}

		case 'a': {	//louis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}

		case 'w': {	//adawong
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
	}

	return false;
}

bool IsPinned(int client) {
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	return false;
}

Action cmdZoeyUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, ZOEY);
	return Plugin_Handled;
}

Action cmdNickUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, NICK);
	return Plugin_Handled;
}

Action cmdEllisUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, ELLIS);
	return Plugin_Handled;
}

Action cmdCoachUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, COACH);
	return Plugin_Handled;
}

Action cmdRochelleUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, ROCHELLE);
	return Plugin_Handled;
}

Action cmdBillUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, BILL);
	return Plugin_Handled;
}

Action cmdBikerUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, FRANCIS);
	return Plugin_Handled;
}

Action cmdLouisUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, LOUIS);
	return Plugin_Handled;
}

Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (!g_bBlockUserMsg)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char buffer[254];
	msg.ReadString(buffer, sizeof buffer, true);
	if (strcmp(buffer, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnMapStart() {
	GetSurvivorSetMap();
	g_cPrecacheAllSur.IntValue = 1;
	for (int i; i < sizeof g_sSurModels; i++)
		PrecacheModel(g_sSurModels[i], true);
}

int GetSurvivorSetMap() {
	Address pMissionInfo = SDKCall(g_hSDK_CTerrorGameRules_GetMissionInfo);
	g_iOrignalSet = pMissionInfo ? SDKCall(g_hSDK_KeyValues_GetInt, pMissionInfo, "survivor_set", 2) : 0;
	return g_iOrignalSet;
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bAutoModel =		g_cAutoModel.BoolValue;

	Toggle(g_bAutoModel);

	g_iTabHUDBar =		g_cTabHUDBar.IntValue;
	char flags[16];
	g_cAdminFlags.GetString(flags, sizeof flags);
	g_iAdminFlags = ReadFlagString(flags);
	g_bInTransition =	g_cInTransition.BoolValue;
}

void Toggle(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;

		HookEvent("round_start",			Event_RoundStart,			EventHookMode_PostNoCopy);
		HookEvent("player_bot_replace",		Event_PlayerBotReplace,		EventHookMode_Pre);
		HookEvent("bot_player_replace",		Event_BotPlayerReplace,		EventHookMode_Pre);
		HookEvent("player_team",			Event_PlayerTeam,			EventHookMode_Pre);

		if (!g_ddRestoreTransitionedSurvivorBot.Enable(Hook_Pre, DD_RestoreTransitionedSurvivorBot_Pre))
			SetFailState("Failed to detour pre: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddRestoreTransitionedSurvivorBot.Enable(Hook_Post, DD_RestoreTransitionedSurvivorBot_Post))
			SetFailState("Failed to detour post: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddInfoChangelevel_ChangeLevelNow.Enable(Hook_Post, DD_InfoChangelevel_ChangeLevelNow_Post))
			SetFailState("Failed to detour post: \"DD::InfoChangelevel::ChangeLevelNow\"");
	}
	else if (enabled && !enable) {
		enabled = false;

		UnhookEvent("round_start",			Event_RoundStart,			EventHookMode_PostNoCopy);
		UnhookEvent("player_bot_replace",	Event_PlayerBotReplace,		EventHookMode_Pre);
		UnhookEvent("bot_player_replace",	Event_BotPlayerReplace,		EventHookMode_Pre);
		UnhookEvent("player_team",			Event_PlayerTeam,			EventHookMode_Pre);

		if (!g_ddRestoreTransitionedSurvivorBot.Disable(Hook_Pre, DD_RestoreTransitionedSurvivorBot_Pre))
			SetFailState("Failed to disable detour pre: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddRestoreTransitionedSurvivorBot.Disable(Hook_Post, DD_RestoreTransitionedSurvivorBot_Post))
			SetFailState("Failed to disable detour post: \"DD::RestoreTransitionedSurvivorBots\"");

		if (!g_ddInfoChangelevel_ChangeLevelNow.Disable(Hook_Post, DD_InfoChangelevel_ChangeLevelNow_Post))
			SetFailState("Failed to disable detour post: \"DD::InfoChangelevel::ChangeLevelNow\"");

		g_bTransition = false;
		g_bTransitioned = false;

		for (int i = 1; i <= MaxClients; i++) {
			g_bBotPlayer[i] = false;
			g_bPlayerBot[i] = false;
			g_iTransitioning[i] = 0;
			if (IsClientInGame(i))
				SDKUnhook(i, SDKHook_SpawnPost, IsFakeClient(i) ? BotSpawnPost : PlayerSpawnPost);
		}
	}
}

void Event_RoundStart(Event event, char[] name, bool dontBroadcast) {
	for (int i; i <= MaxClients; i++) {
		g_bBotPlayer[i] = false;
		g_bPlayerBot[i] = false;
	}
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot))
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || GetClientTeam(player) != 2)
		return;

	if (IsFakeClient(player)) {
		RequestFrame(NextFrame_PlayerBot, bot);
		return;
	}

	g_bPlayerBot[bot] = true;
	g_bBotPlayer[player] = false;
	RequestFrame(NextFrame_PlayerBot, bot);
}

void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != 2)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot) || !CPlayerResource().m_bConnected(bot))
		return;

	g_bPlayerBot[bot] = false;
	g_bBotPlayer[player] = true;
	RequestFrame(NextFrame_BotPlayer, player);
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	if (event.GetInt("team") != 2)
		return;

	switch (event.GetInt("oldteam")) {
		case 1, 3, 4:
			RequestFrame(NextFrame_Player, event.GetInt("userid"));
	}
}

void NextFrame_PlayerBot(int bot) {
	g_bPlayerBot[bot] = false;
}

void NextFrame_BotPlayer(int player) {
	g_bPlayerBot[player] = false;
}

void SetCharacter(int client, int character, int modelIndex) {
	if (!CanUse(client, false))
		return;

	SetCharacterInfo(client, character, modelIndex);
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (!g_bAutoModel)
		return;

	if (entity < 1 || entity > MaxClients)
		return;

	if (classname[0] == 'p' && strcmp(classname[1], "layer", false) == 0) {
		g_bFirstSpawn[entity] = true;
		SDKHook(entity, SDKHook_SpawnPost, PlayerSpawnPost);

		if (g_iTransitioning[entity])
			g_iTransitioning[entity] = -1;
		else
			g_iTransitioning[entity] = IsTransitioning(GetClientUserId(entity)) ? 1 : -1;
	}

	if (classname[0] == 's' && strcmp(classname[1], "urvivor_bot", false) == 0) {
		if (!g_bInTransition || !PrepRestoreBots())
			SDKHook(entity, SDKHook_SpawnPost, BotSpawnPost);
	}
}

void PlayerSpawnPost(int client) {
	if (GetClientTeam(client) != 4) {
		switch (CPlayerResource().m_iTeam(client)) {
			case 0: {
				if (g_bInTransition && g_iTransitioning[client] == 1)
					g_bFirstSpawn[client] = false;
				else
					RequestFrame(NextFrame_Player, GetClientUserId(client));
			}

			case 1, 3, 4:
				RequestFrame(NextFrame_Player, GetClientUserId(client));
		}
	}
}

void NextFrame_Player(int client) {
	client = GetClientOfUserId(client);
	if (!client)
		return;

	if (!IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if ((!g_bFirstSpawn[client] && g_bBotPlayer[client]) || g_bPlayerBot[client])
		return;

	static bool once[MAXPLAYERS + 1];
	if (once[client] && !PrepTransition() && !PrepRestoreBots()) {
		once[client] = false;
		SetLeastCharacter(client);
		g_bFirstSpawn[client] = false;
	}
	else {
		once[client] = !PrepTransition() && !PrepRestoreBots();

		if (!g_bInTransition) {
			SetLeastCharacter(client);
			g_bFirstSpawn[client] = false;
		}
		else
			RequestFrame(NextFrame_Player, GetClientUserId(client));
	}
}

void BotSpawnPost(int client) {
	if (GetClientTeam(client) == 4)
		return;

	SDKUnhook(client, SDKHook_SpawnPost, BotSpawnPost);
	RequestFrame(NextFrame_Bot, GetClientUserId(client));
}

void NextFrame_Bot(int client) {
	client = GetClientOfUserId(client);
	if (!client)
		return;

	if (g_bPlayerBot[client] || g_bBotPlayer[client])
		return;

	if (!IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (g_bInTransition) {
		int userid = GetEntProp(client, Prop_Send, "m_humanSpectatorUserID");
		if (GetClientOfUserId(userid) && IsTransitioning(userid))
			return;
	}

	SetLeastCharacter(client);
}

void SetLeastCharacter(int client) {
	switch (GetLeastCharacter(client)) {
		case 0:
			SetCharacterInfo(client, NICK);

		case 1:
			SetCharacterInfo(client, ROCHELLE);

		case 2:
			SetCharacterInfo(client, COACH);

		case 3:
			SetCharacterInfo(client, ELLIS);

		case 4:
			SetCharacterInfo(client, BILL);

		case 5:
			SetCharacterInfo(client, ZOEY);

		case 6:
			SetCharacterInfo(client, FRANCIS);

		case 7:
			SetCharacterInfo(client, LOUIS);
	}
}

int GetLeastCharacter(int client) {
	int i = 1, buf, least[8];
	static char ModelName[128];
	for (; i <= MaxClients; i++) {
		if (i == client || !IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 2)
			continue;

		GetClientModel(i, ModelName, sizeof ModelName);
		if (g_smSurModels.GetValue(ModelName, buf))
			least[buf]++;
	}

	switch ((g_iOrignalSet > 0 || GetSurvivorSetMap() > 0) ? g_iOrignalSet : 2) {
		case 1: {
			buf = 7;
			int tempChar = least[7];
			for (i = 7; i >= 0; i--) {
				if (least[i] < tempChar) {
					tempChar = least[i];
					buf = i;
				}
			}
		}

		case 2: {
			buf = 0;
			int tempChar = least[0];
			for (i = 0; i <= 7; i++) {
				if (least[i] < tempChar) {
					tempChar = least[i];
					buf = i;
				}
			}
		}
	}

	return buf;
}

void SetCharacterInfo(int client, int character, int modelIndex) {
	if (g_iTabHUDBar && g_iTabHUDBar & ((g_iOrignalSet > 0 || GetSurvivorSetMap() > 0) ? g_iOrignalSet : 2))
		character = ConvertToInternalCharacter(character);

	#if DEBUG
	int buf = -1;
	static char ModelName[128];
	GetClientModel(client, ModelName, sizeof ModelName);
	g_smSurModels.GetValue(ModelName, buf);
	LogError("Set \"%N\" Character \"%s\" to \"%s\"", client, buf != -1 ? g_sSurNames[buf] : ModelName, g_sSurNames[modelIndex]);
	#endif

	SetEntProp(client, Prop_Send, "m_survivorCharacter", character, 2);
	SetEntityModel(client, g_sSurModels[modelIndex]);

	if (IsFakeClient(client)) {
		g_bBlockUserMsg = true;
		SetClientInfo(client, "name", g_sSurNames[modelIndex]);
		g_bBlockUserMsg = false;
	}

	ReEquipWeapons(client);
}

// https://github.com/LuxLuma/Left-4-fix/blob/master/left%204%20fix/Defib_Fix/scripting/Defib_Fix.sp
int ConvertToInternalCharacter(int SurvivorCharacterType) {
	switch (SurvivorCharacterType) {
		case 4:
			return 0;

		case 5:
			return 1;

		case 6:
			return 3;

		case 7:
			return 2;

		case 9:
			return 8;
	}

	return SurvivorCharacterType;
}

void ReEquipWeapons(int client) {
	if (!IsPlayerAlive(client))
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= MaxClients)
		return;

	char active[32];
	GetEntityClassname(weapon, active, sizeof active);

	char cls[32];
	for (int i; i <= 1; i++) {
		weapon = GetPlayerWeaponSlot(client, i);
		if (weapon <= MaxClients)
			continue;

		switch (i) {
			case 0: {
				GetEntityClassname(weapon, cls, sizeof cls);

				int clip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");
				int ammo = GetOrSetPlayerAmmo(client, weapon);
				int upgrade = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
				int upgradeAmmo = GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
				int weaponSkin = GetEntProp(weapon, Prop_Send, "m_nSkin");

				RemovePlayerSlot(client, weapon);
				GivePlayerItem(client, cls);

				weapon = GetPlayerWeaponSlot(client, 0);
				if (weapon > MaxClients) {
					SetEntProp(weapon, Prop_Send, "m_iClip1", clip1);
					GetOrSetPlayerAmmo(client, weapon, ammo);

					if (upgrade > 0)
						SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", upgrade);

					if (upgradeAmmo > 0)
						SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", upgradeAmmo);

					if (weaponSkin > 0)
						SetEntProp(weapon, Prop_Send, "m_nSkin", weaponSkin);
				}
			}

			case 1: {
				int clip1 = -1;
				int weaponSkin;
				bool dualWielding;

				GetEntityClassname(weapon, cls, sizeof cls);
				if (strcmp(cls, "weapon_melee") == 0) {
					GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", cls, sizeof cls);
					if (cls[0] == '\0') {
						// 防爆警察掉落的警棍m_strMapSetScriptName为空字符串 (感谢little_froy的提醒)
						char ModelName[128];
						GetEntPropString(weapon, Prop_Data, "m_ModelName", ModelName, sizeof ModelName);
						if (strcmp(ModelName, "models/weapons/melee/v_tonfa.mdl") == 0)
							strcopy(cls, sizeof cls, "tonfa");
					}
				}
				else {
					if (strncmp(cls, "weapon_pistol", 13) == 0 || strcmp(cls, "weapon_chainsaw") == 0)
						clip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");

					dualWielding = strcmp(cls, "weapon_pistol") == 0 && GetEntProp(weapon, Prop_Send, "m_isDualWielding");
				}

				weaponSkin = GetEntProp(weapon, Prop_Send, "m_nSkin");

				RemovePlayerSlot(client, weapon);

				switch (dualWielding) {
					case true: {
						GivePlayerItem(client, "weapon_pistol");
						GivePlayerItem(client, "weapon_pistol");
					}

					case false:
						GivePlayerItem(client, cls);
				}

				weapon = GetPlayerWeaponSlot(client, 1);
				if (weapon > MaxClients) {
					if (clip1 != -1)
						SetEntProp(weapon, Prop_Send, "m_iClip1", clip1);

					if (weaponSkin > 0)
						SetEntProp(weapon, Prop_Send, "m_nSkin", weaponSkin);
				}
			}
		}
	}

	FakeClientCommand(client, "use %s", active);
}

int GetOrSetPlayerAmmo(int client, int weapon, int ammo = -1) {
	int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (m_iPrimaryAmmoType != -1) {
		if (ammo != -1)
			SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, m_iPrimaryAmmoType);
		else
			return GetEntProp(client, Prop_Send, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	return 0;
}

void RemovePlayerSlot(int client, int weapon) {
	RemovePlayerItem(client, weapon);
	RemoveEntity(weapon);
}

void InitGameData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	g_pSavedPlayersCount = hGameData.GetAddress("SavedPlayersCount");
	if (!g_pSavedPlayersCount)
		SetFailState("Failed to find address: \"SavedPlayersCount\"");

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionInfo"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionInfo\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CTerrorGameRules_GetMissionInfo = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionInfo\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetInt"))
		SetFailState("Failed to find signature: \"KeyValues::GetInt\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_KeyValues_GetInt = EndPrepSDKCall();
	if (!(g_hSDK_KeyValues_GetInt = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetInt\"");

	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null) {
	g_ddRestoreTransitionedSurvivorBot = DynamicDetour.FromConf(hGameData, "DD::RestoreTransitionedSurvivorBots");
	if (!g_ddRestoreTransitionedSurvivorBot)
		SetFailState("Failed to create DynamicDetour: \"DD::RestoreTransitionedSurvivorBots\"");

	g_ddInfoChangelevel_ChangeLevelNow = DynamicDetour.FromConf(hGameData, "DD::InfoChangelevel::ChangeLevelNow");
	if (!g_ddInfoChangelevel_ChangeLevelNow)
		SetFailState("Failed to create DynamicDetour: \"DD::InfoChangelevel::ChangeLevelNow\"");
}

MRESReturn DD_RestoreTransitionedSurvivorBot_Pre() {
	g_bRestoringBots = true;
	return MRES_Ignored;
}

MRESReturn DD_RestoreTransitionedSurvivorBot_Post() {
	g_bRestoringBots = false;
	return MRES_Ignored;
}

MRESReturn DD_InfoChangelevel_ChangeLevelNow_Post(Address pThis) {
	g_bTransition = true;
	return MRES_Ignored;
}

public void OnMapEnd() {
	int val;
	if (g_bTransition)
		g_bTransitioned = true;
	else {
		val = -1;
		g_bTransitioned = false;
	}

	for (int i; i <= MaxClients; i++)
		g_iTransitioning[i] = val;

	g_bTransition = false;
	g_bRestoringBots = false;
}

bool PrepRestoreBots() {
	return g_bTransitioned && (g_bRestoringBots || (SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector) && LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32)));
}

bool PrepTransition() {
	if (!g_bTransitioned)
		return false;

	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return false;

	int count = LoadFromAddress(g_pSavedPlayersCount, NumberType_Int32);
	if (!count)
		return false;

	Address kv = view_as<Address>(LoadFromAddress(g_pSavedPlayersCount + view_as<Address>(4), NumberType_Int32));
	if (!kv)
		return false;

	Address ptr;
	for (int i; i < count; i++) {
		ptr = view_as<Address>(LoadFromAddress(kv + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "teamNumber", 0) != 2)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "restoreState", 0))
			return false;
	}

	return true;
}

bool IsTransitioning(int userid) {
	if (!g_bTransitioned)
		return false;

	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return false;

	int count = LoadFromAddress(g_pSavedPlayersCount, NumberType_Int32);
	if (!count)
		return false;

	Address kv = view_as<Address>(LoadFromAddress(g_pSavedPlayersCount + view_as<Address>(4), NumberType_Int32));
	if (!kv)
		return false;

	Address ptr;
	for (int i; i < count; i++) {
		ptr = view_as<Address>(LoadFromAddress(kv + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "userID", 0) != userid)
			continue;

		if (SDKCall(g_hSDK_KeyValues_GetInt, ptr, "teamNumber", 0) != 2)
			continue;

		if (!SDKCall(g_hSDK_KeyValues_GetInt, ptr, "restoreState", 0))
			return true;
	}

	return false;
}
