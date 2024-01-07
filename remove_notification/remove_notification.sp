#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public Plugin myinfo = {
	author = "sorallll",
	description = "移除游戏自带的玩家闲置提示和离开游戏提示",
	version = "1.0"
}

public void OnPluginStart() {
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookUserMessage(GetUserMessageId("TextMsg"), TextMsg, true);
}

//系统自带的玩家离开游戏提示(聊天提示：XXX 离开了游戏。)
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	event.BroadcastDisabled = true;
}

//系统自带的闲置提示(聊天提示：XXX 已闲置。)
Action TextMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	static char sMsg[254];
	msg.ReadString(sMsg, sizeof sMsg);

	if(StrContains(sMsg, "L4D_idle_spectator") != -1)
		return Plugin_Handled;

	return Plugin_Continue;
}
