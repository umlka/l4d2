#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"v5.8b"
#define REFRESH			0
#define MAXDIS			1
#define FULLHUD			2
#define NUMCVARS		3

Handle
	g_hSprayTimer;

ConVar
	g_cvSpray[NUMCVARS];

enum struct Sprays {
	float origin[3];

	char name[MAX_NAME_LENGTH];
	char SteamID[32];
}

Sprays
	g_Sprays[MAXPLAYERS + 1];

float
	g_fSprayMaxDist;

bool
	g_bSprayed,
	g_bSprayFullHud;

public Plugin myinfo = {
	name = "Spray Tracer No Menu",
	author = "Nican132, CptMoore, Lebson506th",
	description = "Traces sprays on the wall",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	LoadTranslations("spraytracenomenu.phrases");

	CreateConVar("sm_spraynomenu_version", PLUGIN_VERSION, "Spray tracer plugin version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvSpray[REFRESH] = CreateConVar("sm_spraynomenu_refresh", "1.0","How often the program will trace to see player's spray to the HUD. 0 to disable.");
	g_cvSpray[MAXDIS] = CreateConVar("sm_spraynomenu_dista", "50.0", "How far away the spray will be traced to.");
	g_cvSpray[FULLHUD] = CreateConVar("sm_spray_fullhud", "0", "Toggles showing sprayer's name and Steam ID(1) or just sprayer's name(0) on the HUD");

	g_cvSpray[REFRESH].AddChangeHook(CvarChanged_Timer);

	g_cvSpray[MAXDIS].AddChangeHook(CvarChanged);
	g_cvSpray[FULLHUD].AddChangeHook(CvarChanged);

	AddTempEntHook("Player Decal", tehPlayerSpray);

	_CreateTimer();

	//AutoExecConfig(true);
}

Action tehPlayerSpray(const char[] te_name, const int[] Players, int numClients, float delay) {
	int client = TE_ReadNum("m_nPlayer");
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Continue;

	g_bSprayed = true;
	TE_ReadVector("m_vecOrigin", g_Sprays[client].origin);
	FormatEx(g_Sprays[client].name, sizeof Sprays::name, "%N", client);
	GetClientAuthId(client, AuthId_Steam2, g_Sprays[client].SteamID, sizeof Sprays::SteamID);

	return Plugin_Continue;
}

public void OnConfigsExecuted() {
    GetCvars();
}

void CvarChanged_Timer(ConVar convar, const char[] oldValue, const char[] newValue) {
	_CreateTimer();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fSprayMaxDist = g_cvSpray[MAXDIS].FloatValue;
	g_bSprayFullHud = g_cvSpray[FULLHUD].BoolValue;
}

void _CreateTimer() {
	delete g_hSprayTimer;

	float time = g_cvSpray[REFRESH].FloatValue;
	if (time > 0.0)
		g_hSprayTimer = CreateTimer(time, tmrTraceSpray, _, TIMER_REPEAT);
}

public void OnMapEnd() {
	g_bSprayed = false;
	for(int i = 1; i <= MaxClients; i++)
		ClearSpray(i);
}

void ClearSpray(int client) {
	g_Sprays[client].origin = NULL_VECTOR;
	g_Sprays[client].name[0] = '\0';
	g_Sprays[client].SteamID[0] = '\0';
}

Action tmrTraceSpray(Handle timer) {
	if (!g_bSprayed)
		return Plugin_Continue;

	static int i, x;
	static float vView[3];

	for(i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !GetPlayerViewPoint(i, vView))
			continue;

		for(x = 1; x <= MaxClients; x++) {
			if (!g_Sprays[x].name[0] || GetVectorDistance(vView, g_Sprays[x].origin) > g_fSprayMaxDist)
				continue;

			if (!g_bSprayFullHud)
				PrintHintText(i, "%T", "Sprayed Name", i, g_Sprays[x].name);
			else
				PrintHintText(i, "%T", "Sprayed", i, g_Sprays[x].name, g_Sprays[x].SteamID);

			break;
		}
	}

	return Plugin_Continue;
}

bool GetPlayerViewPoint(int client, float vView[3]) {
	static float vAng[3], vPos[3];
	GetClientEyeAngles(client, vAng);
	GetClientEyePosition(client, vPos);

	static Handle hTrace;
	hTrace = TR_TraceRayFilterEx(vPos, vAng, MASK_SOLID, RayType_Infinite, _TraceEntityFilter);
	if (TR_DidHit(hTrace))  {
		TR_GetEndPosition(vView, hTrace);
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

bool _TraceEntityFilter(int entity, int contentsMask) {
 	return entity > MaxClients;
}