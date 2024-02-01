#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME				"L4D2 Map vote"
#define PLUGIN_AUTHOR			"fdxx, sorallll, HatsuneImagine"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0"
#define PLUGIN_URL				""

#define TRANSLATION_MISSIONS	"missions.phrases.txt"
#define TRANSLATION_CHAPTERS	"chapters.phrases.txt"

#define SOUND_MENU				"ui/pickup_secret01.wav"

#define NOTIFY_CHAT				(1<<0)
#define NOTIFY_HINT				(1<<1)
#define NOTIFY_MENU				(1<<2)

#define BENCHMARK				0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#include <sourcemod>
#include <sdktools>
#include <l4d2_nativevote>			// https://github.com/fdxx/l4d2_nativevote
#include <l4d2_source_keyvalues>	// https://github.com/fdxx/l4d2_source_keyvalues
#include <colors>
#include <localizer>
#include <left4dhooks>

Localizer
	loc;

Address
	g_pDirector,
	g_pMatchExtL4D;

Handle
	g_hSDK_GetAllMissions,
	g_hSDK_OnChangeMissionVote;

StringMap
	g_smExclude,
	g_smFirstMap;

ConVar
	g_cvMPGameMode,
	g_cvNotifyMapNext;

char
	g_sMode[128];

bool
	g_bOnce,
	g_bMapChanger;

int
	g_iNotifyMapNext,
	g_iType[MAXPLAYERS + 1],
	g_iPos[MAXPLAYERS + 1][2];

static const char
	g_sLangCode[][] = {
		"en",
		"chi"
	};

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

native bool MC_SetNextMap(const char[] map);
public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "map_changer") == 0)
		g_bMapChanger = true;
}

public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "map_changer") == 0)
		g_bMapChanger = false;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("l4d2_map_vote");
	MarkNativeAsOptional("MC_SetNextMap");
	return APLRes_Success;
}

public void OnPluginStart() {
	Init();
	g_smFirstMap = new StringMap();

	loc = new Localizer();
	loc.Delegate_InitCompleted(OnPhrasesReady);

	CreateConVar("l4d2_map_vote_version", PLUGIN_VERSION, "L4D2 Map vote plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvNotifyMapNext =	CreateConVar("notify_map_next", "1", "终局开始后提示投票下一张地图的方式. \n0=不提示, 1=聊天栏, 2=屏幕中央, 4=弹出菜单.", FCVAR_NOTIFY);
	g_cvNotifyMapNext.AddChangeHook(CvarChanged);

	//AutoExecConfig(true);

	g_cvMPGameMode = FindConVar("mp_gamemode");
	g_cvMPGameMode.AddChangeHook(CvarChanged_Mode);

	RegConsoleCmd("sm_v3", 		cmdMapVote);
	RegConsoleCmd("sm_maps", 	cmdMapVote);
	RegConsoleCmd("sm_chmap", 	cmdMapVote);
	RegConsoleCmd("sm_vmap",	cmdMapVote);
	RegConsoleCmd("sm_votemap",	cmdMapVote);

	RegConsoleCmd("sm_mapvote",		cmdMapNext);
	RegConsoleCmd("sm_mapnext",		cmdMapNext);
	RegConsoleCmd("sm_votenext",	cmdMapNext);

	RegAdminCmd("sm_reload_vpk",		cmdReload,		ADMFLAG_ROOT);
	RegAdminCmd("sm_update_vpk",		cmdReload,		ADMFLAG_ROOT);
	//RegAdminCmd("sm_missions_reload",	cmdReload,		ADMFLAG_ROOT);
	RegAdminCmd("sm_missions_export",	cmdRxport,		ADMFLAG_ROOT);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);
}

enum struct esPhrase {
	char key[64];
	char val[64];
	int official;
}

public void OnPhrasesReady() {
	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	esPhrase esp;
	ArrayList al_missions = new ArrayList(sizeof esPhrase);
	ArrayList al_chapters = new ArrayList(sizeof esPhrase);

	int value;
	char phrase[64];
	char translation[64];
	SourceKeyValues kvModes;
	SourceKeyValues kvChapters;
	SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
	for (kvMissions = kvMissions.GetFirstTrueSubKey(); !kvMissions.IsNull(); kvMissions = kvMissions.GetNextTrueSubKey()) {
		kvMissions.GetName(phrase, sizeof phrase);
		if (g_smExclude.ContainsKey(phrase))
			continue;

		kvModes = kvMissions.FindKey("modes");
		if (kvModes.IsNull())
			continue;

		value = kvMissions.GetInt("builtin");
		if (al_missions.FindString(phrase) == -1) {
			kvMissions.GetString("DisplayTitle", translation, sizeof translation, "N/A");
			strcopy(esp.key, sizeof esp.key, phrase);
			strcopy(esp.val, sizeof esp.val, !strcmp(translation, "N/A") ? phrase : translation);
			esp.official = value;
			al_missions.PushArray(esp);
		}

		for (kvModes = kvModes.GetFirstTrueSubKey(); !kvModes.IsNull(); kvModes = kvModes.GetNextTrueSubKey()) {
			for (kvChapters = kvModes.GetFirstTrueSubKey(); !kvChapters.IsNull(); kvChapters = kvChapters.GetNextTrueSubKey()) {
				kvChapters.GetString("Map", phrase, sizeof phrase, "N/A");
				if (!strcmp(phrase, "N/A") || FindCharInString(phrase, '/') != -1)
					continue;

				if (al_chapters.FindString(phrase) == -1) {
					kvChapters.GetString("DisplayName", translation, sizeof translation, "N/A");
					strcopy(esp.key, sizeof esp.key, phrase);
					strcopy(esp.val, sizeof esp.val, !strcmp(translation, "N/A") ? phrase : translation);
					esp.official = value;
					al_chapters.PushArray(esp);
				}
			}
		}
	}

	int x;
	File file;
	KeyValues kv;
	char buffer[64];
	char FilePath[PLATFORM_MAX_PATH];

	int missions_len = al_missions.Length;
	int chapters_len = al_chapters.Length;
	for (int i; i < sizeof g_sLangCode; i++) {
		kv = new KeyValues("Phrases");
		BuildPhrasePath(FilePath, sizeof FilePath, TRANSLATION_MISSIONS, g_sLangCode[i]);
		if (!FileExists(FilePath)) {
			file = OpenFile(FilePath, "w");
			if (!file) {
				LogError("Cannot open file: \"%s\"", FilePath);
				continue;
			}

			if (!file.WriteLine("")) {
				LogError("Cannot write file line: \"%s\"", FilePath);
				delete file;
				continue;
			}

			delete file;

			for (x = 0; x < missions_len; x++) {
				al_missions.GetArray(x, esp);
				if (kv.JumpToKey(esp.key, true)) {
					if (!esp.official)
						kv.SetString(g_sLangCode[i], esp.val);
					else {
						loc.PhraseTranslateToLang(esp.val, buffer, sizeof buffer, _, _, g_sLangCode[i], esp.val);
						kv.SetString(g_sLangCode[i], buffer);
					}
					kv.Rewind();
					kv.ExportToFile(FilePath);
				}
			}
		}
		else if(kv.ImportFromFile(FilePath)) {
			for (x = 0; x < missions_len; x++) {
				al_missions.GetArray(x, esp);
				if (kv.JumpToKey(esp.key, true)) {
					if (!kv.JumpToKey(g_sLangCode[i])) {
						if (!esp.official)
							kv.SetString(g_sLangCode[i], esp.val);
						else {
							loc.PhraseTranslateToLang(esp.val, buffer, sizeof buffer, _, _, g_sLangCode[i], esp.val);
							kv.SetString(g_sLangCode[i], buffer);
						}
						kv.SetString(g_sLangCode[i], esp.val);
						kv.Rewind();
						kv.ExportToFile(FilePath);
					}
					kv.Rewind();
				}
			}
		}

		delete kv;

		kv = new KeyValues("Phrases");
		BuildPhrasePath(FilePath, sizeof FilePath, TRANSLATION_CHAPTERS, g_sLangCode[i]);
		if (!FileExists(FilePath)) {
			file = OpenFile(FilePath, "w");
			if (!file) {
				LogError("Cannot open file: \"%s\"", FilePath);
				continue;
			}

			if (!file.WriteLine("")) {
				LogError("Cannot write file line: \"%s\"", FilePath);
				delete file;
				continue;
			}

			delete file;

			for (x = 0; x < chapters_len; x++) {
				al_chapters.GetArray(x, esp);
				if (kv.JumpToKey(esp.key, true)) {
					if (!esp.official)
						kv.SetString(g_sLangCode[i], esp.val);
					else {
						loc.PhraseTranslateToLang(esp.val, buffer, sizeof buffer, _, _, g_sLangCode[i], esp.val);
						kv.SetString(g_sLangCode[i], buffer);
					}
					kv.Rewind();
					kv.ExportToFile(FilePath);
				}
			}
		}
		else if(kv.ImportFromFile(FilePath)) {
			for (x = 0; x < chapters_len; x++) {
				al_chapters.GetArray(x, esp);
				if (kv.JumpToKey(esp.key, true)) {
					if (!kv.JumpToKey(g_sLangCode[i])) {
						if (!esp.official)
							kv.SetString(g_sLangCode[i], esp.val);
						else {
							loc.PhraseTranslateToLang(esp.val, buffer, sizeof buffer, _, _, g_sLangCode[i], esp.val);
							kv.SetString(g_sLangCode[i], buffer);
						}
						kv.Rewind();
						kv.ExportToFile(FilePath);
					}
				}
				kv.Rewind();
			}
		}

		delete kv;
	}

	loc.Close();
	delete al_missions;
	delete al_chapters;

	value = 0;
	BuildPhrasePath(FilePath, sizeof FilePath, TRANSLATION_MISSIONS, "en");
	if (FileExists(FilePath)) {
		value = 1;
		LoadTranslations("missions.phrases");
	}

	BuildPhrasePath(FilePath, sizeof FilePath, TRANSLATION_CHAPTERS, "en");
	if (FileExists(FilePath)) {
		value = 1;
		LoadTranslations("chapters.phrases");
	}

	if (value) {
		InsertServerCommand("sm_reload_translations");
		ServerExecute();
	}

	#if BENCHMARK
	g_profiler.Stop();
	LogError("Export Phrases Time: %f", g_profiler.Time);
	#endif
}

void BuildPhrasePath(char[] buffer, int maxlength, const char[] fliename, const char[] lang_code) {
	strcopy(buffer, maxlength, "translations/");

	int len;
	if (strcmp(lang_code, "en")) {
		len = strlen(buffer);
		FormatEx(buffer[len], maxlength - len, "%s/", lang_code);
	}

	len = strlen(buffer);
	FormatEx(buffer[len], maxlength - len, "%s", fliename);
	BuildPath(Path_SM, buffer, maxlength, "%s", buffer);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bOnce = false;
}

void OnFinaleStart(const char[] output, int caller, int activator, float delay) {
	if (!g_bOnce && L4D_IsMissionFinalMap()) {
		g_bOnce = true;

		if (g_iNotifyMapNext & NOTIFY_CHAT)
			PrintToChatAll("\x01聊天栏输入 \x05!mapnext \x01投票下一张地图.");

		if (g_iNotifyMapNext & NOTIFY_HINT)
			PrintHintTextToAll("聊天栏输入 !mapnext 投票下一张地图");

		if (g_iNotifyMapNext & NOTIFY_MENU) {
			int team;
			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i) && !IsFakeClient(i) && ((team = GetClientTeam(i)) == 2) || team == 3)
					cmdMapNext(i, 0);
			}
			EmitSoundToAll(SOUND_MENU, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		}
	}
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void CvarChanged_Mode(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Mode();
}

public void OnConfigsExecuted() {
	GetCvars();
	GetCvars_Mode();

	static bool val;
	if (val)
		return;

	val = true;
	SetFirstMapString();
}

void GetCvars() {
	g_iNotifyMapNext = g_cvNotifyMapNext.IntValue;
}

void GetCvars_Mode() {
	g_cvMPGameMode.GetString(g_sMode, sizeof g_sMode);
}

void SetFirstMapString() {
	g_smFirstMap.Clear();
	char key[64], mission[64], map[64];
	SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
	for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
		FormatEx(key, sizeof key, "modes/%s/1/Map", g_sMode);
		SourceKeyValues kvFirstMap = kvSub.FindKey(key);
		if (kvFirstMap.IsNull())
			continue;

		kvSub.GetName(mission, sizeof mission);
		kvFirstMap.GetString(NULL_STRING, map, sizeof map);
		g_smFirstMap.SetString(map, mission);
	}
}

Action cmdReload(int client, int args) {
	ServerCommand("update_addon_paths; mission_reload");
	ServerExecute();
	OnPhrasesReady();
	SetFirstMapString();

	ReplyToCommand(client, "更新VPK文件");
	return Plugin_Handled;
}

Action cmdRxport(int client, int args) {
	if (args != 1) {
		ReplyToCommand(client, "sm_missions_export <file>");
		return Plugin_Handled;
	}

	char file[PLATFORM_MAX_PATH];
	GetCmdArg(1, file, sizeof file);
	SourceKeyValues kv = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
	if (kv.SaveToFile(file))
		ReplyToCommand(client, "Save to file succeeded: %s", file);

	return Plugin_Handled;
}

Action cmdMapNext(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bMapChanger) {
		PrintToChat(client, "前置插件未安装");
		return Plugin_Handled;
	}

	if (!L4D_IsMissionFinalMap()) {
		PrintToChat(client, "当前地图非终局地图");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == 1) {
		PrintToChat(client, "旁观者无法进行投票");
		return Plugin_Handled;
	}

	Menu menu = new Menu(MapNext_MenuHandler);
	menu.SetTitle("选择下一张地图:");
	menu.AddItem("", "官方地图");
	menu.AddItem("", "三方地图");
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int MapNext_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			g_iPos[client][0] = 0;
			g_iPos[client][1] = 0;
			g_iType[client] = param2;

			ShowNextMap(client);
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowNextMap(int client) {
	char title[64];
	char buffer[64];
	Menu menu = new Menu(ShowNextMap_MenuHandler);
	menu.SetTitle("选择地图:");

	SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
	for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
		kvSub.GetName(title, sizeof title);
		if (g_smExclude.ContainsKey(title))
			continue;

		FormatEx(buffer, sizeof buffer, "modes/%s", g_sMode);
		if (kvSub.FindKey(buffer).IsNull())
			continue;

		int val;
		val = kvSub.GetInt("builtin");
		if (val && g_iType[client] == 0) {
			fmt_Translate(title, buffer, sizeof buffer, client, title);
			menu.AddItem(title, buffer);
		}
		else if (!val && g_iType[client] == 1) {
			fmt_Translate(title, buffer, sizeof buffer, client, title);
			menu.AddItem(title, buffer);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iPos[client][g_iType[client]], 30);
}

int ShowNextMap_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			g_iPos[client][g_iType[client]] = menu.Selection;

			char item[64];
			menu.GetItem(param2, item, sizeof item);
			VoteNextMap(client, item);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				cmdMapNext(client, 0);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void VoteNextMap(int client, const char[] item) {
	if (!L4D2NativeVote_IsAllowNewVote()) {
		PrintToChat(client, "投票正在进行中, 暂不能发起新的投票");
		return;
	}

	char buffer[128];
	FormatEx(buffer, sizeof buffer, "%s/modes/%s", item, g_sMode);
	SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
	SourceKeyValues kvChapters = kvMissions.FindKey(buffer);
	if (kvChapters.IsNull()) {
		PrintToChat(client, "无有效的章节地图存在");
		return;
	}

	bool find;
	char info[2][64];
	SourceKeyValues kvMap;
	for (kvMap = kvChapters.GetFirstTrueSubKey(); !kvMap.IsNull(); kvMap = kvMap.GetNextTrueSubKey()) {
		kvMap.GetString("Map", info[1], sizeof info[], "N/A");
		if (IsMapValidEx(info[1])) {
			find = true;
			break;
		}
	}

	if (!find) {
		PrintToChat(client, "无有效的章节地图存在");
		return;
	}

	strcopy(info[0], sizeof info[], item);
	ImplodeStrings(info, sizeof info, "//", buffer, sizeof buffer);

	L4D2NativeVote vote = L4D2NativeVote(NextMap_Handler);
	vote.Initiator = client;
	vote.SetInfo(buffer);

	int team;
	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || (team = GetClientTeam(i)) < 2 || team > 3)
			continue;

		fmt_Translate(item, buffer, sizeof buffer, i, item);
		vote.SetTitle("设置下一张地图为: %s", buffer);

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, 20);
}

void NextMap_Handler(L4D2NativeVote vote, VoteAction action, int param1, int param2) {
	switch (action) {
		case VoteAction_Start: {
			char buffer[128];
			char info[2][64];
			vote.GetInfo(buffer, sizeof buffer);
			ExplodeString(buffer, "//", info, sizeof info, sizeof info[]);

			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i) && !IsFakeClient(i)) {
					fmt_Translate(info[0], info[0], sizeof info[], i, info[0]);
					CPrintToChat(i, "{blue}%N {default}发起投票 {olive}设置下一张地图为: %s", param1, info[0]);
				}
			}
		}

		case VoteAction_PlayerVoted:
			CPrintToChatAll("{blue}%N {default}已投票", param1);

		case VoteAction_End: {
			if (vote.YesCount > vote.PlayerCount / 2) {
				vote.SetPass("设置中...");

				char buffer[128];
				char info[2][64];
				vote.GetInfo(buffer, sizeof buffer);
				ExplodeString(buffer, "//", info, sizeof info, sizeof info[]);

				if (!g_bMapChanger || !MC_SetNextMap(info[1]))
					PrintToChatAll("设置失败");
				else {
					for (int i = 1; i <= MaxClients; i++) {
						if (IsClientInGame(i) && !IsFakeClient(i)) {
							fmt_Translate(info[0], info[0], sizeof info[], i, info[0]);
							PrintToChat(i, "\x01下一张地图已设置为 \x05%s", info[0]);
						}
					}
				}
			}
			else
				vote.SetFail();
		}
	}
}

Action cmdMapVote(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (GetClientTeam(client) == 1) {
		PrintToChat(client, "旁观者无法进行投票");
		return Plugin_Handled;
	}

	Menu menu = new Menu(MapVote_MenuHandler);
	menu.SetTitle("选择地图类型:");
	menu.AddItem("", "官方地图");
	menu.AddItem("", "三方地图");
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int MapVote_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			g_iPos[client][0] = 0;
			g_iPos[client][1] = 0;
			g_iType[client] = param2;

			ShowVoteMap(client);
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowVoteMap(int client) {
	char title[64];
	char buffer[64];
	Menu menu = new Menu(ShowVoteMap_MenuHandler);
	menu.SetTitle("选择地图:");

	SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
	for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
		kvSub.GetName(title, sizeof title);
		if (g_smExclude.ContainsKey(title))
			continue;

		FormatEx(buffer, sizeof buffer, "modes/%s", g_sMode);
		if (kvSub.FindKey(buffer).IsNull())
			continue;
		
		int val;
		val = kvSub.GetInt("builtin");
		if (val && g_iType[client] == 0) {
			fmt_Translate(title, buffer, sizeof buffer, client, title);
			menu.AddItem(title, buffer);
		}
		else if (!val && g_iType[client] == 1) {
			fmt_Translate(title, buffer, sizeof buffer, client, title);
			menu.AddItem(title, buffer);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, g_iPos[client][g_iType[client]], 30);
}

int ShowVoteMap_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			g_iPos[client][g_iType[client]] = menu.Selection;

			char item[64];
			menu.GetItem(param2, item, sizeof item);
			ShowChaptersMenu(client, item);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				cmdMapVote(client, 0);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowChaptersMenu(int client, const char[] item) {
	char buffer[128];
	char info[2][64];
	FormatEx(buffer, sizeof buffer, "%s/modes/%s", item, g_sMode);
	SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
	SourceKeyValues kvChapters = kvMissions.FindKey(buffer);
	if (kvChapters.IsNull()) {
		PrintToChat(client, "无有效的章节地图存在");
		return;
	}

	Menu menu = new Menu(Chapters_MenuHandler);
	menu.SetTitle("选择章节:");

	bool valid_map;
	strcopy(info[0], sizeof info[], item);
	for (SourceKeyValues kvSub = kvChapters.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
		kvSub.GetString("Map", info[1], sizeof info[], "N/A");
		if (!IsMapValidEx(info[1]))
			continue;

		valid_map = true;
		ImplodeStrings(info, sizeof info, "//", buffer, sizeof buffer);
		fmt_Translate(info[1], info[1], sizeof info[], client, info[1]);
		menu.AddItem(buffer, info[1]);
	}

	if (!valid_map)
		PrintToChat(client, "无有效的章节地图存在");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Chapters_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[128];
			menu.GetItem(param2, item, sizeof item);
			VoteChangeMap(client, item);
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack)
				ShowVoteMap(client);
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void VoteChangeMap(int client, const char[] item) {
	if (!L4D2NativeVote_IsAllowNewVote()) {
		PrintToChat(client, "投票正在进行中, 暂不能发起新的投票");
		return;
	}

	L4D2NativeVote vote = L4D2NativeVote(ChangeMap_Handler);
	vote.Initiator = client;
	vote.SetInfo(item);

	char info[2][64];
	ExplodeString(item, "//", info, sizeof info, sizeof info[]);

	int team;
	int playerCount = 0;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || (team = GetClientTeam(i)) < 2 || team > 3)
			continue;

		fmt_Translate(info[0], info[0], sizeof info[], i, info[0]);
		fmt_Translate(info[1], info[1], sizeof info[], i, info[1]);
		vote.SetTitle("更换地图: %s (%s)", info[0], info[1]);

		clients[playerCount++] = i;
	}
	vote.DisplayVote(clients, playerCount, 20);
}

void ChangeMap_Handler(L4D2NativeVote vote, VoteAction action, int param1, int param2) {
	switch (action) {
		case VoteAction_Start: {
			char buffer[128];
			char info[2][64];
			vote.GetInfo(buffer, sizeof buffer);
			ExplodeString(buffer, "//", info, sizeof info, sizeof info[]);

			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i) && !IsFakeClient(i)) {
					fmt_Translate(info[0], info[0], sizeof info[], i, info[0]);
					fmt_Translate(info[1], info[1], sizeof info[], i, info[1]);
					CPrintToChat(i, "{blue}%N {default}发起投票 {olive}更换地图: %s (%s)", param1, info[0], info[1]);
				}
			}
		}

		case VoteAction_PlayerVoted:
			CPrintToChatAll("{blue}%N {default}已投票", param1);

		case VoteAction_End: {
			if (vote.YesCount > vote.PlayerCount / 2) {
				vote.SetPass("加载中...");

				char buffer[128];
				char info[2][64];
				vote.GetInfo(buffer, sizeof buffer);
				ExplodeString(buffer, "//", info, sizeof info, sizeof info[]);
				if (!g_smFirstMap.GetString(info[1], buffer, sizeof buffer))
					ServerCommand("changelevel %s", info[1]);
				else
					SDKCall(g_hSDK_OnChangeMissionVote, g_pDirector, buffer);
			}
			else
				vote.SetFail();
		}
	}
}

public void OnMapStart() {
	PrecacheSound(SOUND_MENU);
}

void Init() {
	GameData hGameData = new GameData("l4d2_map_vote");
	if (!hGameData)
		SetFailState("Failed to load \"l4d2_map_vote.txt\" file");
	
	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	g_pMatchExtL4D = hGameData.GetAddress("g_pMatchExtL4D");
	if (!g_pMatchExtL4D)
		SetFailState("Failed to find address: \"g_pMatchExtL4D\"");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(0);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_GetAllMissions = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"MatchExtL4D::GetAllMissions\"");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::OnChangeMissionVote");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_OnChangeMissionVote = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::OnChangeMissionVote\"");

	delete hGameData;

	g_smExclude = new StringMap();
	g_smExclude.SetValue("credits", 1);
	g_smExclude.SetValue("HoldoutChallenge", 1);
	g_smExclude.SetValue("HoldoutTraining", 1);
	g_smExclude.SetValue("parishdash", 1);
	g_smExclude.SetValue("shootzones", 1);
}

bool IsMapValidEx(const char[] map) {
	if (!map[0])
		return false;

	char foundmap[1];
	return FindMap(map, foundmap, sizeof foundmap) == FindMap_Found;
}

void fmt_Translate(const char[] phrase, char[] buffer, int maxlength, int client, const char[] defvalue="") {
	if (!TranslationPhraseExists(phrase))
		strcopy(buffer, maxlength, defvalue);
	else
		Format(buffer, maxlength, "%T", phrase, client);
}