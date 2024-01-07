#pragma semicolon 1
#pragma newdecls required
#include <basecomm>
#include <sdktools_voice>

public Plugin myinfo = {
	name = "[ANY] Speaking List",
	author = "Accelerator (Fork by Dragokas, Grey83)",
	description = "Voice Announce. Print To Center Message who's Speaking",
	version = "1.4.4",
	url = "https://forums.alliedmods.net/showthread.php?t=339934"
}

/*
	ChangeLog:
	
	 * 1.4.1 (26-Jan-2020) (Dragokas)
	  - Client in game check fixed
	  - Code is simplified
	  - New syntax
	  
	 * 1.4.2 (23-Dec-2020) (Dragokas)
	  - Updated to use with SM 1.11
	  - Timer is increased 0.7 => 1.0
	  
	 * 1.4.4 (10-Oct-2022) (Grey83)
	  - Optimization: timer moved from OnPluginStart to OnMapStart.
	  - Optimization: max. buffer checks and caching.
*/

bool
	g_bSpeaking[MAXPLAYERS + 1];

char
	g_sSpeaking[PLATFORM_MAX_PATH];

public void OnMapStart() {
    for (int i = 1; i <= MaxClients; i++)
		g_bSpeaking[i] = false;

    CreateTimer(1.0, tmrUpdateList, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientSpeaking(int client) {
	g_bSpeaking[client] = true;
}

/*
public void OnClientSpeakingEnd(int client) {
	g_bSpeaking[client] = false;
}
*/

Action tmrUpdateList(Handle timer) {
	static int i;
	static bool show;
	g_sSpeaking[0] = '\0';
	show = false;

	for (i = 1; i <= MaxClients; i++) {
		if (!g_bSpeaking[i])
			continue;

		g_bSpeaking[i] = false;
		if (!IsClientInGame(i))
			continue;

		if (BaseComm_IsClientMuted(i))
			continue;

		if (Format(g_sSpeaking, sizeof g_sSpeaking, "%s\n%N", g_sSpeaking, i) >= (sizeof g_sSpeaking - 1))
			break;

		show = true;
	}

	if (show)
		PrintCenterTextAll("语音中:%s", g_sSpeaking);

	return Plugin_Continue;
}
