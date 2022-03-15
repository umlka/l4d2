#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <adminmenu>
#include <left4dhooks>

#define PLUGIN_VERSION "1.6.6"
#define PLUGIN_NAME 	"Survivor Chat Select"
#define PLUGIN_PREFIX	"\x01[\x04SCS\x01]"

#define GAMEDATA		"survivor_chat_select"

#define	 NICK		0, 0
#define	 ROCHELLE	1, 1
#define	 COACH		2, 2
#define	 ELLIS		3, 3
#define	 BILL		4, 4
#define	 ZOEY		5, 5
#define	 FRANCIS	6, 6
#define	 LOUIS		7, 7

Handle
	g_hSDK_CDirector_IsInTransition,
	g_hSDK_CTerrorPlayer_IsTransitioned;

Cookie
	g_ckClientID,
	g_ckClientModel;

TopMenu
	hTopMenu;

Address
	g_pDirector;

ConVar
	g_hCookie,
	g_hAutoModel,
	g_hAdminsOnly,
	g_hFixDialogue,
	g_hInTransition,
	g_hPrecacheAllSur;

int
	g_iOrignalMapSet,
	g_iSelectedClient[MAXPLAYERS + 1];

bool
	g_bCookie,
	g_bAutoModel,
	g_bAdminsOnly,
	g_bFixDialogue,
	g_bInTransition,
	g_bHideNameChange,
	g_bShouldIgnoreOnce[MAXPLAYERS + 1];

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
		"Louis",
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
	};

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "DeatChaos25, Mi123456 & Merudo, Lux, SilverShot",
	description = "Select a survivor character by typing their name into the chat.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2399163#post2399163"
}

public void OnPluginStart()
{
	vInitGameData();
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);

	g_ckClientID = new Cookie("Player_Character", "Player's default character ID.", CookieAccess_Protected);
	g_ckClientModel = new Cookie("Player_Model", "Player's default character model.", CookieAccess_Protected);

	RegConsoleCmd("sm_zoey", cmdZoeyUse, "Changes your survivor character into Zoey");
	RegConsoleCmd("sm_nick", cmdNickUse, "Changes your survivor character into Nick");
	RegConsoleCmd("sm_ellis", cmdEllisUse, "Changes your survivor character into Ellis");
	RegConsoleCmd("sm_coach", cmdCoachUse, "Changes your survivor character into Coach");
	RegConsoleCmd("sm_rochelle", cmdRochelleUse, "Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_bill", cmdBillUse, "Changes your survivor character into Bill");
	RegConsoleCmd("sm_francis", cmdBikerUse, "Changes your survivor character into Francis");
	RegConsoleCmd("sm_louis", cmdLouisUse, "Changes your survivor character into Louis");

	RegConsoleCmd("sm_z", cmdZoeyUse, "Changes your survivor character into Zoey");
	RegConsoleCmd("sm_n", cmdNickUse, "Changes your survivor character into Nick");
	RegConsoleCmd("sm_e", cmdEllisUse, "Changes your survivor character into Ellis");
	RegConsoleCmd("sm_c", cmdCoachUse, "Changes your survivor character into Coach");
	RegConsoleCmd("sm_r", cmdRochelleUse, "Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_b", cmdBillUse, "Changes your survivor character into Bill");
	RegConsoleCmd("sm_f", cmdBikerUse, "Changes your survivor character into Francis");
	RegConsoleCmd("sm_l", cmdLouisUse, "Changes your survivor character into Louis");

	RegAdminCmd("sm_csc", cmdCsc, ADMFLAG_ROOT, "Brings up a menu to select a client's character");
	RegConsoleCmd("sm_csm", cmdCsm, "Brings up a menu to select a client's character");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	
	g_hCookie = CreateConVar("l4d_scs_cookie", "0","保存玩家的模型角色喜好?", FCVAR_NOTIFY);
	g_hAutoModel = CreateConVar("l4d_scs_auto_model", "1","开关8人独立模型?", FCVAR_NOTIFY);
	g_hAdminsOnly = CreateConVar("l4d_csm_admins_only", "1","只允许管理员使用csm命令?", FCVAR_NOTIFY);
	g_hFixDialogue = CreateConVar("l4d_csm_fix_dialogue", "0","修复2代人物在1代图中的对话?", FCVAR_NOTIFY);
	g_hInTransition = CreateConVar("l4d_csm_in_transition", "1","启用8人独立模型后不对正在过渡的玩家设置?", FCVAR_NOTIFY);
	g_hPrecacheAllSur = FindConVar("precache_all_survivors");

	g_hCookie.AddChangeHook(vConVarChanged);
	g_hAutoModel.AddChangeHook(vConVarChanged);
	g_hAdminsOnly.AddChangeHook(vConVarChanged);
	g_hFixDialogue.AddChangeHook(vConVarChanged);
	g_hInTransition.AddChangeHook(vConVarChanged);

	AutoExecConfig(true, "survivor_chat_select");

	TopMenu topmenu;
	if(LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
		OnAdminMenuReady(topmenu);
}

public void OnAllPluginsLoaded()
{
	g_pDirector = L4D_GetPointer(POINTER_DIRECTOR);
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if(topmenu == hTopMenu)
		return;

	hTopMenu = topmenu;

	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if(player_commands != INVALID_TOPMENUOBJECT)
		hTopMenu.AddItem("sm_csc", AdminMenu_Csc, player_commands, "sm_csc", ADMFLAG_ROOT);
}

void AdminMenu_Csc(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
			FormatEx(buffer, maxlength, "更改玩家人物模型", "", param);

		case TopMenuAction_SelectOption:
			cmdCsc(param, 0);
	}
}

Action cmdCsc(int client, int args)
{
	if(!client || !IsClientInGame(client))
		return Plugin_Handled;

	char sUserId[16];
	char sName[MAX_NAME_LENGTH];

	Menu menu = new Menu(iCscMenuHandler);
	menu.SetTitle("目标玩家:");

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		FormatEx(sUserId, sizeof sUserId, "%d", GetClientUserId(i));
		FormatEx(sName, sizeof sName, "%N", i);
		menu.AddItem(sUserId, sName);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int iCscMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			menu.GetItem(param2, sItem, sizeof sItem);
			g_iSelectedClient[client] = StringToInt(sItem);

			vShowMenuAdmin(client);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack && hTopMenu != null)
				DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vShowMenuAdmin(int client)
{
	Menu menu = new Menu(iShowMenuAdminMenuHandler);
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

int iShowMenuAdminMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), NICK, false);
				case 1:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ROCHELLE, false);
				case 2:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), COACH, false);
				case 3:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ELLIS, false);
				case 4:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), BILL, false);
				case 5:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ZOEY, false);
				case 6:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), FRANCIS, false);
				case 7:
					vSetCharacter(GetClientOfUserId(g_iSelectedClient[client]), LOUIS, false);
			}
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action cmdCsm(int client, int args)
{
	if(!bCanUse(client)) 
		return Plugin_Handled;

	Menu menu = new Menu(iCsmMenuHandler);
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

int iCsmMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
					vSetCharacter(client, NICK);
				case 1:
					vSetCharacter(client, ROCHELLE);
				case 2:
					vSetCharacter(client, COACH);
				case 3:
					vSetCharacter(client, ELLIS);
				case 4:
					vSetCharacter(client, BILL);
				case 5:
					vSetCharacter(client, ZOEY);
				case 6:
					vSetCharacter(client, FRANCIS);
				case 7:
					vSetCharacter(client, LOUIS);
			}
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

bool bCanUse(int client, bool bCheckAdmin = true)
{
	if(!client || !IsClientInGame(client)) 
	{
		ReplyToCommand(client, "角色选择菜单仅适用于游戏中的玩家.");
		return false;
	}

	if(bCheckAdmin && g_bAdminsOnly && GetUserFlagBits(client) == 0)
	{
		ReplyToCommand(client, "只有管理员才能使用该菜单.");
		return false;
	}

	if(GetClientTeam(client) != 2)
	{
		ReplyToCommand(client, "角色选择菜单仅适用于幸存者.");
		return false;
	}

	if(L4D_IsPlayerStaggering(client))
	{
		ReplyToCommand(client, "硬直状态下无法使用该指令.");
		return false;
	}

	if(bIsGettingUp(client))
	{
		ReplyToCommand(client, "起身过程中无法使用该指令.");
		return false;
	}

	return true;
}

Action cmdZoeyUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;

	vSetCharacter(client, ZOEY);
	return Plugin_Handled;
}

Action cmdNickUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;
	
	vSetCharacter(client, NICK);
	return Plugin_Handled;
}

Action cmdEllisUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;
	
	vSetCharacter(client, ELLIS);
	return Plugin_Handled;
}

Action cmdCoachUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;
	
	vSetCharacter(client, COACH);
	return Plugin_Handled;
}

Action cmdRochelleUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;
	
	vSetCharacter(client, ROCHELLE);
	return Plugin_Handled;
}

Action cmdBillUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;
	
	vSetCharacter(client, BILL);
	return Plugin_Handled;
}

Action cmdBikerUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;
	
	vSetCharacter(client, FRANCIS);
	return Plugin_Handled;
}

Action cmdLouisUse(int client, int args)
{
	if(!bCanUse(client))
		return Plugin_Handled;
	
	vSetCharacter(client, LOUIS);
	return Plugin_Handled;
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

public void OnMapStart()
{
	g_hPrecacheAllSur.IntValue = 1;

	for(int i; i < 8; i++)
		PrecacheModel(g_sSurvivorModels[i], true);
}

public void OnConfigsExecuted()
{
	vGetCvars();
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	g_bCookie = g_hCookie.BoolValue;
	g_bAutoModel= g_hAutoModel.BoolValue;
	g_bAdminsOnly = g_hAdminsOnly.BoolValue;
	g_bFixDialogue = g_hFixDialogue.BoolValue;
	g_bInTransition = g_hInTransition.BoolValue;
}

void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	for(int i; i <= MaxClients; i++)
		g_bShouldIgnoreOnce[i] = false;
}

void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast)
{
	if(!g_bAutoModel)
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if(!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != 2) 
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(!bot || !IsClientInGame(bot))
	{
		vSetLeastUsedCharacter(player);
		return;
	}

	g_bShouldIgnoreOnce[bot] = false;
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	if(!g_bAutoModel)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(!bot || !IsClientInGame(bot))
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if(!player || !IsClientInGame(player) || GetClientTeam(player) != 2)
		return;

	if(IsFakeClient(player))
	{
		vSetLeastUsedCharacter(bot);
		RequestFrame(OnNextFrame_ResetVar, bot);
		return;
	}

	g_bShouldIgnoreOnce[bot] = true;
	RequestFrame(OnNextFrame_ResetVar, bot);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	if(g_bAutoModel && !g_bShouldIgnoreOnce[client] && !IsPlayerAlive(client) && !iGetBotOfIdlePlayer(client))
		RequestFrame(OnNextFrame_PlayerSpawn, event.GetInt("userid"));

	if(g_bCookie)
		CreateTimer(0.6, tmrLoadCookie, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void OnNextFrame_ResetVar(int iBot)
{
	g_bShouldIgnoreOnce[iBot] = false;
}

static int iGetBotOfIdlePlayer(int client)
{
	static int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && iGetIdlePlayerOfBot(i) == client)
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

void OnNextFrame_PlayerSpawn(int client)
{
	if(!g_bAutoModel || !(client = GetClientOfUserId(client)) || g_bShouldIgnoreOnce[client] || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	vSetLeastUsedCharacter(client);
}

Action tmrLoadCookie(Handle timer, int client)
{
	if(!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return Plugin_Stop;

	if(!AreClientCookiesCached(client))
	{
		ReplyToCommand(client, "%s 无法载入你的人物角色,请输入 \x05!csm \x01来设置你的人物角色.", PLUGIN_PREFIX);
		return Plugin_Stop;
	}

	char sID[2];
	g_ckClientID.Get(client, sID, sizeof sID);

	char sModel[128];
	g_ckClientModel.Get(client, sModel, sizeof sModel);

	if(sID[0] != '\0' && sModel[0] != '\0')
	{
		SetEntProp(client, Prop_Send, "m_survivorCharacter", StringToInt(sID));
		SetEntityModel(client, sModel);
	}

	return Plugin_Continue;
}

void vSetCharacter(int client, int iCharacter, int iModelIndex, bool bSave = true)
{
	if(!bCanUse(client, false))
		return;

	vSetCharacterInfo(client, iCharacter, iModelIndex);

	if(bSave && g_bCookie)
	{
		char sProp[2];
		IntToString(iCharacter, sProp, sizeof sProp);
		g_ckClientID.Set(client, sProp);
		g_ckClientModel.Set(client, g_sSurvivorModels[iModelIndex]);
		ReplyToCommand(client, "%s 你的人物角色现在已经被设为 \x03%s\x01.", PLUGIN_PREFIX, g_sSurvivorNames[iModelIndex]);
	}
}

//https://github.com/LuxLuma/L4D2_Adrenaline_Recovery
bool bIsGettingUp(int client)
{
	static char sModel[31];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof sModel);
	switch(sModel[29])
	{
		case 'b'://nick
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 680, 667, 671, 672, 630, 620, 627:
					return true;
			}
		}
		case 'd'://rochelle
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
		case 'c'://coach
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 669, 661, 660, 656, 630, 627, 621:
					return true;
			}
		}
		case 'h'://ellis
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 684, 676, 675, 671, 625, 635, 632:
					return true;
			}
		}
		case 'v'://bill
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}
		case 'n'://zoey
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 824, 823, 819, 809, 547, 544, 537:
					return true;
			}
		}
		case 'e'://francis
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 775, 767, 766, 762, 541, 539, 531:
					return true;
			}
		}
		case 'a'://louis
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}
		case 'w'://adawong
		{
			switch(GetEntProp(client, Prop_Send, "m_nSequence"))
			{
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
	}

	return false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!g_bAutoModel)
		return;

	if(entity < 1 || entity > MaxClients)
		return;

	if((classname[0] == 'p' && strcmp(classname, "player", false) == 0) || (classname[0] == 's' && strcmp(classname, "survivor_bot", false) == 0))
	{
		if(g_bInTransition && SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector) && !SDKCall(g_hSDK_CTerrorPlayer_IsTransitioned, entity))
			return;

		SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
	}
}

void OnSpawnPost(int client)
{
	SDKUnhook(client, SDKHook_SpawnPost, OnSpawnPost);

	if(!g_bAutoModel)
		return;

	if(!IsValidEntity(client) || GetClientTeam(client) == 4 || iGetIdlePlayerOfBot(client))
		return;

	RequestFrame(OnNextFrame_SpawnPost, GetClientUserId(client));
}
/**
bool bIsLeastCharacter(int client)
{
	static int i;
	static int iCharBuffer;
	static int iSurvivorChar;
	int iLeastChar[8];

	for(i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		if((iCharBuffer = GetEntProp(i, Prop_Send, "m_survivorCharacter")) < 0 || iCharBuffer > 7)
			continue;

		iLeastChar[iCharBuffer]++;
	}

	iCharBuffer = 0;
	iSurvivorChar = iLeastChar[0];
	for(i = 0; i <= 7; i++)
	{
		if(iLeastChar[i] < iSurvivorChar)
		{
			iSurvivorChar = iLeastChar[i];
			iCharBuffer = i;
		}
	}

	i = GetEntProp(client, Prop_Send, "m_survivorCharacter");
	if(i < 0 || i > 7)
		return false;

	return iLeastChar[i] <= iLeastChar[iCharBuffer];
}*/

void OnNextFrame_SpawnPost(int client)
{
	if(!g_bAutoModel)
		return;

	if(!(client = GetClientOfUserId(client)) || g_bShouldIgnoreOnce[client] || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	vSetLeastUsedCharacter(client);
}

void vSetLeastUsedCharacter(int client)
{
	switch(iCheckLeastUsedSurvivor(client))
	{
		case 0:
			vSetCharacterInfo(client, NICK);
		case 1:
			vSetCharacterInfo(client, ROCHELLE);
		case 2:
			vSetCharacterInfo(client, COACH);
		case 3:
			vSetCharacterInfo(client, ELLIS);
		case 4:
			vSetCharacterInfo(client, BILL);
		case 5:
			vSetCharacterInfo(client, ZOEY);
		case 6:
			vSetCharacterInfo(client, FRANCIS);
		case 7:
			vSetCharacterInfo(client, LOUIS);	
	}
}

int iCheckLeastUsedSurvivor(int client)
{
	int i = 1;
	int iCharBuffer;
	int iLeastChar[8];
	for(; i <= MaxClients; i++)
	{
		if(i == client || !IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		if((iCharBuffer = GetEntProp(i, Prop_Send, "m_survivorCharacter")) < 0 || iCharBuffer > 7)
			continue;

		iLeastChar[iCharBuffer]++;
	}

	switch(g_iOrignalMapSet)
	{
		case 1:
		{
			iCharBuffer = 7;
			int iSurvivorChar = iLeastChar[7];
			for(i = 7; i >= 0; i--)
			{
				if(iLeastChar[i] < iSurvivorChar)
				{
					iSurvivorChar = iLeastChar[i];
					iCharBuffer = i;
				}
			}
		}

		case 2:
		{
			iCharBuffer = 0;
			int iSurvivorChar = iLeastChar[0];
			for(i = 0; i <= 7; i++)
			{
				if(iLeastChar[i] < iSurvivorChar)
				{
					iSurvivorChar = iLeastChar[i];
					iCharBuffer = i;
				}
			}
		}
	}

	return iCharBuffer;
}

void vSetCharacterInfo(int client, int iCharacter, int iModelIndex)
{
	SetEntProp(client, Prop_Send, "m_survivorCharacter", iCharacter);
	SetEntityModel(client, g_sSurvivorModels[iModelIndex]);

	if(IsFakeClient(client))
	{
		g_bHideNameChange = true;
		SetClientName(client, g_sSurvivorNames[iModelIndex]);
		g_bHideNameChange = false;
	}
		
	vReEquipWeapons(client);
}

void vRemovePlayerWeapon(int client, int iWeapon)
{
	RemovePlayerItem(client, iWeapon);
	RemoveEntity(iWeapon);
}

void vReEquipWeapons(int client)
{
	if(!IsPlayerAlive(client))
		return;

	int iweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(iweapon <= MaxClients)
		return;

	char sActive[32];
	GetEntityClassname(iweapon, sActive, sizeof sActive);

	char sWeapon[32];
	for(int i; i <= 1; i++)
	{
		iweapon = GetPlayerWeaponSlot(client, i);
		if(iweapon <= MaxClients)
			continue;

		switch(i)
		{
			case 0:
			{
				GetEntityClassname(iweapon, sWeapon, sizeof sWeapon);
	
				int iClip1 = GetEntProp(iweapon, Prop_Send, "m_iClip1");
				int iAmmo = iGetOrSetPlayerAmmo(client, iweapon);
				int iUpgrade = GetEntProp(iweapon, Prop_Send, "m_upgradeBitVec");
				int iUpgradeAmmo = GetEntProp(iweapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
				int iWeaponSkin = GetEntProp(iweapon, Prop_Send, "m_nSkin");

				vRemovePlayerWeapon(client, iweapon);
				vCheatCommand(client, "give", sWeapon);

				iweapon = GetPlayerWeaponSlot(client, 0);
				if(iweapon > MaxClients)
				{
					SetEntProp(iweapon, Prop_Send, "m_iClip1", iClip1);
					iGetOrSetPlayerAmmo(client, iweapon, iAmmo);

					if(iUpgrade > 0)
						SetEntProp(iweapon, Prop_Send, "m_upgradeBitVec", iUpgrade);

					if(iUpgradeAmmo > 0)
						SetEntProp(iweapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iUpgradeAmmo);
			
					if(iWeaponSkin > 0)
						SetEntProp(iweapon, Prop_Send, "m_nSkin", iWeaponSkin);
				}
			}

			case 1:
			{
				int iClip1 = -1;
				int iWeaponSkin;
				bool bDualWielding;

				GetEntityClassname(iweapon, sWeapon, sizeof sWeapon);

				if(strcmp(sWeapon[7], "melee") == 0)
					GetEntPropString(iweapon, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof sWeapon);
				else
				{
					if(strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
						iClip1 = GetEntProp(iweapon, Prop_Send, "m_iClip1");

					bDualWielding = strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(iweapon, Prop_Send, "m_isDualWielding");
				}

				iWeaponSkin = GetEntProp(iweapon, Prop_Send, "m_nSkin");

				vRemovePlayerWeapon(client, iweapon);

				switch(bDualWielding)
				{
					case true:
					{
						vCheatCommand(client, "give", "weapon_pistol");
						vCheatCommand(client, "give", "weapon_pistol");
					}

					case false:
						vCheatCommand(client, "give", sWeapon);
				}

				iweapon = GetPlayerWeaponSlot(client, 1);
				if(iweapon > MaxClients)
				{
					if(iClip1 != -1)
						SetEntProp(iweapon, Prop_Send, "m_iClip1", iClip1);
				
					if(iWeaponSkin > 0)
						SetEntProp(iweapon, Prop_Send, "m_nSkin", iWeaponSkin);
				}
			}
		}
	}

	FakeClientCommand(client, "use %s", sActive);
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

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	//[L4D2] Real Zoey Unlock (1.2) (https://forums.alliedmods.net/showthread.php?p=2598539)
	int iOffset = GameConfGetOffset(hGameData, "ZoeyUnlock_Offset");
	if(iOffset != -1)
	{
		Address pZoeyUnlock = GameConfGetAddress(hGameData, "ZoeyUnlock");
		if(!pZoeyUnlock)
			SetFailState("Error finding the 'ZoeyUnlock' signature.");

		int iByte = LoadFromAddress(pZoeyUnlock + view_as<Address>(iOffset), NumberType_Int8);
		if(iByte == 0xE8)
		{
			for(int i; i < 5; i++)
				StoreToAddress(pZoeyUnlock + view_as<Address>(iOffset + i), 0x90, NumberType_Int8);
		}
		else if(iByte != 0x90)
			SetFailState("Error: the 'ZoeyUnlock_Offset' is incorrect.");
	}

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: CDirector::IsInTransition");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CDirector_IsInTransition = EndPrepSDKCall();
	if(!g_hSDK_CDirector_IsInTransition)
		SetFailState("Failed to create SDKCall: CDirector::IsInTransition");

	StartPrepSDKCall(SDKCall_Player);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::IsTransitioned"))
		SetFailState("Failed to find signature: CTerrorPlayer::IsTransitioned");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CTerrorPlayer_IsTransitioned = EndPrepSDKCall();
	if(!g_hSDK_CTerrorPlayer_IsTransitioned)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::IsTransitioned");

	delete hGameData;
}

public Action L4D_OnGetSurvivorSet(int &retVal)
{
	g_iOrignalMapSet = retVal;

	if(!g_bFixDialogue)
		return Plugin_Continue;

	retVal = 2;
	return Plugin_Handled;
}
