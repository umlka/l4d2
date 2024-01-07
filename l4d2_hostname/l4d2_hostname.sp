#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"L4D2 中文服务器名"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.3"
#define PLUGIN_URL				""

#define FILE_HOSTNAME "configs/hostname/hostname.txt"

Handle
	g_hTimer;

ConVar
	g_hHostName;

int
	g_iFailures,
	g_iMaxChapters,
	g_iCurrentChapter;

char
	g_sHostName[PLATFORM_MAX_PATH];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_hHostName = FindConVar("hostname");

	SetHostName();
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void OnConfigsExecuted() {
	g_iMaxChapters = L4D_GetMaxChapters();
	g_iCurrentChapter = L4D_GetCurrentChapter();

	SetHostName();

	delete g_hTimer;
	g_hTimer = CreateTimer(5.0, tmrUpdateHostName, _, TIMER_REPEAT);
}

public void OnMapEnd() {
	g_iFailures = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_iFailures++;
}

Action tmrUpdateHostName(Handle timer) {
	if (!L4D_HasAnySurvivorLeftSafeArea())
		return Plugin_Continue;

	static int client;
	static float fHighestFlow;
	fHighestFlow = (client = L4D_GetHighestFlowSurvivor()) != -1 ? L4D2Direct_GetFlowDistance(client) : L4D2_GetFurthestSurvivorFlow();
	if (fHighestFlow)
		fHighestFlow = fHighestFlow / L4D2Direct_GetMapMaxFlowDistance() * 100;

	static char buf[PLATFORM_MAX_PATH];
	FormatEx(buf, sizeof buf, "%s [路程:%d%%][地图:%d/%d][重启:%d][运行:%dm]", g_sHostName, RoundToNearest(fHighestFlow), g_iCurrentChapter, g_iMaxChapters, g_iFailures, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_missionDuration") / 60);

	g_hHostName.SetString(buf);
	return Plugin_Continue;
}

void SetHostName() {
	char buf[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buf, sizeof buf, FILE_HOSTNAME);
	if (!FileExists(buf))
		SetFailState("\n==========\n配置文件丢失: \"%s\".\n==========", FILE_HOSTNAME);

	File file = OpenFile(buf, "rb");
	if (file) {
		while (!file.EndOfFile())
			file.ReadLine(g_sHostName, sizeof g_sHostName);

		delete file;
		TrimString(g_sHostName);
	}

	g_hHostName.SetString(g_sHostName);
}
