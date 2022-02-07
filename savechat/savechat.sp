#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <geoip>

#define PLUGIN_VERSION "1.3"

ConVar
	g_hHostport;

char
	g_sChatFilePath[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "SaveChat",
	author = "citkabuto, sorallll",
	description = "Records player chat messages to a file",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=117116"
}

public void OnPluginStart()
{
	char sDate[21];
	FormatTime(sDate, sizeof sDate, "%d%m%y", -1);
	BuildPath(Path_SM, g_sChatFilePath, sizeof g_sChatFilePath, "/logs/chat%s-%i.log", sDate, (g_hHostport = FindConVar("hostport")).IntValue);

	CreateConVar("sm_savechat_version", PLUGIN_VERSION, "Save Player CommandListener_ChatSay Messages Plugin", FCVAR_DONTRECORD|FCVAR_REPLICATED);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	AddCommandListener(CommandListener_ChatSay, "say");
	AddCommandListener(CommandListener_ChatSayTeam, "say_team");
}

Action CommandListener_ChatSay(int client, char[] command, int argc)
{
	vLogChat(client, false);
	return Plugin_Continue;
}

Action CommandListener_ChatSayTeam(int client, char[] command, int argc)
{
	vLogChat(client, true);
	return Plugin_Continue;
}

public void OnMapStart()
{
	char sTime[32];
	char sMessageBuffer[512];

	FormatTime(sMessageBuffer, sizeof sMessageBuffer, "%d%m%y", -1);
	BuildPath(Path_SM, g_sChatFilePath, sizeof g_sChatFilePath, "/logs/chat%s-%i.log", sMessageBuffer, g_hHostport.IntValue);

	FormatTime(sTime, sizeof sTime, "%d/%m/%Y %H:%M:%S", -1);

	GetCurrentMap(sMessageBuffer, sizeof sMessageBuffer);
	Format(sMessageBuffer, sizeof sMessageBuffer, "[%s] --- 地图开始: %s ---", sTime, sMessageBuffer);

	vSaveMessage("--=================================================================--");
	vSaveMessage(sMessageBuffer);
	vSaveMessage("--=================================================================--");
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;

	char steamID[32];
	if(!GetClientAuthId(client, AuthId_Steam2, steamID, sizeof steamID))
		return;

	char sTime[32];
	char sCountry[3];
	char sPlayerIP[50];
	char sMessageBuffer[512];

	if(!GetClientIP(client, sPlayerIP, sizeof sPlayerIP, true)) 
		strcopy(sCountry, sizeof sCountry, "  ");
	else 
	{
		if(!GeoipCode2(sPlayerIP, sCountry)) 
			strcopy(sCountry, sizeof sCountry, "  ");
	}

	FormatTime(sTime, sizeof sTime, "%H:%M:%S", -1);
	FormatEx(sMessageBuffer, sizeof sMessageBuffer, "[%s] [%s] %-25N 加入游戏 (%s | %s)", sTime, sCountry, client, steamID, sPlayerIP);

	vSaveMessage(sMessageBuffer);
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || IsFakeClient(client))
		return;

	char steamID[32];
	if(!GetClientAuthId(client, AuthId_Steam2, steamID, sizeof steamID))
		return;

	char sTime[32];
	char sCountry[3];
	char sPlayerIP[50];
	char sMessageBuffer[512];

	if(!GetClientIP(client, sPlayerIP, sizeof sPlayerIP, true)) 
		strcopy(sCountry, sizeof sCountry, "  ");
	else 
	{
		if(!GeoipCode2(sPlayerIP, sCountry)) 
			strcopy(sCountry, sizeof sCountry, "  ");
	}

	FormatTime(sTime, sizeof sTime, "%H:%M:%S", -1);
	event.GetString("reason", sMessageBuffer, sizeof sMessageBuffer);
	Format(sMessageBuffer, sizeof sMessageBuffer, "[%s] [%s] %-25N 离开游戏 (reason: %s) (%s | %s)", sTime, sCountry, client, sMessageBuffer, steamID, sPlayerIP);

	vSaveMessage(sMessageBuffer);
}

void vLogChat(int client, bool bTeamChat)
{
	char sTime[32];
	char sCountry[3];
	char sTeamName[20];
	char sPlayerIP[50];
	char sMessageBuffer[512];

	GetCmdArgString(sMessageBuffer, sizeof sMessageBuffer);
	StripQuotes(sMessageBuffer);

	if(client == 0 || !IsClientInGame(client))
	{
		strcopy(sCountry, sizeof sCountry, "  ");
		strcopy(sTeamName, sizeof sTeamName, "");
	} 
	else 
	{
		if(!GetClientIP(client, sPlayerIP, sizeof sPlayerIP, true)) 
			strcopy(sCountry, sizeof sCountry, "  ");
		else 
		{
			if(!GeoipCode2(sPlayerIP, sCountry)) 
				strcopy(sCountry, sizeof sCountry, "  ");
		}
		GetTeamName(GetClientTeam(client), sTeamName, sizeof sTeamName);
	}

	FormatTime(sTime, sizeof sTime, "%H:%M:%S", -1);
	Format(sMessageBuffer, sizeof sMessageBuffer, "[%s] [%s] [%-11s] %-25N :%s %s", sTime, sCountry, sTeamName, client, bTeamChat == true ? " (TEAM)" : "", sMessageBuffer);

	vSaveMessage(sMessageBuffer);
}

void vSaveMessage(const char[] sMessage)
{
	File file = OpenFile(g_sChatFilePath, "a");
	file.WriteLine("%s", sMessage);
	file.Flush();
	delete file;
}
