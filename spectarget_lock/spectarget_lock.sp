#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_NAME		"Observer Target Lock"
#define PLUGIN_AUTHOR	"sorallll"
#define PLUGIN_VERSION	"1.0.0"

int
	g_iSpecTarget[MAXPLAYERS + 1][2];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = "锁定旁观目标",
	version = PLUGIN_VERSION,
}

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	RegConsoleCmd("sm_spect", cmdSpecT, "锁定旁观目标");

	HookEvent("player_spawn",	Event_PlayerSpawn);
	HookEvent("player_team",	Event_PlayerTeam);
}

Action cmdSpecT(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (GetClientTeam(client) != 1 || iGetBotOfIdlePlayer(client)) {
		ReplyToCommand(client, "完全旁观玩家才能使用该指令");
		return Plugin_Handled;
	}

	if (!args) {
		ReplyToCommand(client, "\x01!spect/sm_spect <\x05#userid\x01|\x05name\x01> <\x051\x01=\x05第一人称\x01|\x05其他值\x01=\x05第三人称\x01>");
		return Plugin_Handled;
	}

	char arg[32];
	GetCmdArg(1, arg, sizeof arg);
	if (strcmp(arg, "off", false) == 0) {
		ReplyToCommand(client, "已关闭旁观锁定");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_IMMUNITY, target_name, sizeof target_name, tn_is_ml)) <= 0) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	g_iSpecTarget[client][1] = args > 1 && GetCmdArgInt(2) == 1 ? 1 : 0;
	g_iSpecTarget[client][0] = GetClientUserId(target_list[0]);
	if (GetClientTeam(target_list[0]) > 1 && IsPlayerAlive(target_list[0]))
		vSetObserverTarget(client, target_list[0]);

	ReplyToCommand(client, "已启用对 %N 的旁观锁定", target_list[0]);
	return Plugin_Handled;
}

int iGetBotOfIdlePlayer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && iGetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int iGetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

public void OnClientDisconnect(int client) {
	g_iSpecTarget[client][0] = 0;

	int userid = GetClientUserId(client);
	for (int i = 1; i <= MaxClients; i++) {
		if (g_iSpecTarget[i][0] == userid) {
			g_iSpecTarget[i][0] = 0;
			g_iSpecTarget[i][1] = 0;
		}
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) < 2)
		return;

	RequestFrame(OnNextFrame_SetHumanSpectator, event.GetInt("userid"));
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || event.GetInt("team") != 1)
		return;

	RequestFrame(OnNextFrame_SetObserverTarget, event.GetInt("userid"));
}

void OnNextFrame_SetHumanSpectator(int userid) {
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || GetClientTeam(client) < 2 || !IsPlayerAlive(client))
		return;

	for (int i = 1; i <= MaxClients; i++) {
		if (g_iSpecTarget[i][0] == userid && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 1)
			vSetObserverTarget(i, client);
	}
}

void OnNextFrame_SetObserverTarget(int client) {
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 1 || iGetBotOfIdlePlayer(client))
		return;

	int target = GetClientOfUserId(g_iSpecTarget[client][0]);
	if (target && IsClientInGame(target) && GetClientTeam(target) > 1 && IsPlayerAlive(target))
		vSetObserverTarget(client, target);
}

void vSetObserverTarget(int client, int target) {
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
	SetEntProp(client, Prop_Send, "m_iObserverMode", g_iSpecTarget[client][1] ? 4 : 5);
}