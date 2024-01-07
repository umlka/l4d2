#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <sdktools>
#include <left4dhooks>

#define PLUGIN_NAME				"L4D2 Kill Reward"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

#define MAX_CVAR				11
#define CVAR_FLAGS				FCVAR_NOTIFY

StringMap
	g_smWeapon;

ConVar
	g_cAllow,
	g_cLeeched[MAX_CVAR],
	g_cPainPillsDecay;

bool
	g_bLateLoad,
	g_bCvarAllow,
	g_bIsTankActive;

enum struct Reward {
	int WitchReward;
	int TankReward;
	int RewardBound;
	int AllowedWeapon;

	bool IsTankAlive;

	float RewardBase;
	float DistanceMulti;
	float HeadShotMulti;
	float LowHealth;
	float LowHealMulti;
	float PerRewardMax;
}

Reward
	g_eRewards;

float
	g_fPainPillsDecay;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	g_cAllow =			CreateConVar("l4d2_rewards_allow",		"1",		"是否启用该插件", CVAR_FLAGS);
	g_cLeeched[0] =		CreateConVar("l4d2_rewards_health0",	"50",		"击杀witch回多少血", CVAR_FLAGS, true, 0.0);
	g_cLeeched[1] =		CreateConVar("l4d2_rewards_health1",	"50",		"击杀Tank回多少血", CVAR_FLAGS, true, 0.0);
	g_cLeeched[2] =		CreateConVar("l4d2_rewards_health2",	"1",		"坦克存活时是否关闭特感击杀回血", CVAR_FLAGS);
	g_cLeeched[3] =		CreateConVar("l4d2_rewards_health3",	"80",		"实际血量超过多少后击杀特感不再回血", CVAR_FLAGS, true, 0.0);
	g_cLeeched[4] =		CreateConVar("l4d2_rewards_health4",	"3.0",		"击杀特感的基础回血量", CVAR_FLAGS, true, 0.0);
	g_cLeeched[5] =		CreateConVar("l4d2_rewards_health5",	"0.01",		"击杀特感的回血距离加成", CVAR_FLAGS, true, 0.0);
	g_cLeeched[6] =		CreateConVar("l4d2_rewards_health6",	"1.5",		"爆头击杀加成倍率", CVAR_FLAGS, true, 0.0);
	g_cLeeched[7] =		CreateConVar("l4d2_rewards_health7",	"15.0",		"实际血量低于多少时有额外的回血倍率", CVAR_FLAGS, true, 0.0);
	g_cLeeched[8] =		CreateConVar("l4d2_rewards_health8",	"1.5",		"实际血量低于设定值后的额外回血倍率", CVAR_FLAGS, true, 0.0);
	g_cLeeched[9] =		CreateConVar("l4d2_rewards_health9",	"20.0",		"一次最大回血值", CVAR_FLAGS, true, 0.0);
	g_cLeeched[10] =	CreateConVar("l4d2_rewards_health10",	"1966079",	"允许哪些武器击杀回血", CVAR_FLAGS, true, 0.0);
	
	g_cPainPillsDecay = FindConVar("pain_pills_decay_rate");
	g_cPainPillsDecay.AddChangeHook(CvarChanged);

	g_cAllow.AddChangeHook(CvarChanged_Allow);
	for (int i; i < MAX_CVAR; i++)
		g_cLeeched[i].AddChangeHook(CvarChanged);

	g_smWeapon = new StringMap();
	g_smWeapon.SetValue("pistol", 1);
	g_smWeapon.SetValue("pistol_magnum", 2);
	g_smWeapon.SetValue("chainsaw", 4);
	g_smWeapon.SetValue("smg", 8);
	g_smWeapon.SetValue("smg_mp5", 16);
	g_smWeapon.SetValue("smg_silenced", 32);
	g_smWeapon.SetValue("pumpshotgun", 64);
	g_smWeapon.SetValue("shotgun_chrome", 128);
	g_smWeapon.SetValue("rifle", 256);
	g_smWeapon.SetValue("rifle_desert", 512);
	g_smWeapon.SetValue("rifle_ak47", 1024);
	g_smWeapon.SetValue("rifle_sg552", 2048);
	g_smWeapon.SetValue("autoshotgun", 4096);
	g_smWeapon.SetValue("shotgun_spas", 8192);
	g_smWeapon.SetValue("hunting_rifle", 16384);
	g_smWeapon.SetValue("sniper_military", 32768);
	g_smWeapon.SetValue("sniper_scout", 65536);
	g_smWeapon.SetValue("sniper_awp", 131072);
	g_smWeapon.SetValue("rifle_m60", 262144);
	g_smWeapon.SetValue("grenade_launcher", 524288);
	g_smWeapon.SetValue("melee", 1048576);

	if (g_bLateLoad)
		g_bIsTankActive = FindTank(-1);
}

void CvarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue) {
	IsAllowed();
}

public void OnConfigsExecuted() {
	IsAllowed();
}

void IsAllowed() {
	bool bCvarAllow = g_cAllow.BoolValue;
	GetCvars();

	if (g_bCvarAllow == false && bCvarAllow == true) {
		g_bIsTankActive = FindTank(-1);

		g_bCvarAllow = true;
		HookEvent("round_end",		Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("tank_spawn",		Event_TankSpawn);
		HookEvent("witch_killed",	Event_WitchKilled);
		HookEvent("player_death",	Event_PlayerDeath);
	}
	else if (g_bCvarAllow == true && bCvarAllow == false) {
		g_bCvarAllow = false;
		UnhookEvent("round_end",	Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("tank_spawn",	Event_TankSpawn, EventHookMode_PostNoCopy);
		UnhookEvent("witch_killed",	Event_WitchKilled);
		UnhookEvent("player_death",	Event_PlayerDeath);
	}
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_eRewards.WitchReward =	g_cLeeched[0].IntValue;
	g_eRewards.TankReward =		g_cLeeched[1].IntValue;
	g_eRewards.IsTankAlive =	g_cLeeched[2].BoolValue;
	g_eRewards.RewardBound =	g_cLeeched[3].IntValue;
	g_eRewards.RewardBase =		g_cLeeched[4].FloatValue;
	g_eRewards.DistanceMulti =	g_cLeeched[5].FloatValue;
	g_eRewards.HeadShotMulti =	g_cLeeched[6].FloatValue;
	g_eRewards.LowHealth =		g_cLeeched[7].FloatValue;
	g_eRewards.LowHealMulti =	g_cLeeched[8].FloatValue;
	g_eRewards.PerRewardMax =	g_cLeeched[9].FloatValue;
	g_eRewards.AllowedWeapon =	g_cLeeched[10].IntValue;
	g_fPainPillsDecay =			g_cPainPillsDecay.FloatValue;
}

public void OnMapEnd() {
	g_bIsTankActive = false;
}

public void OnClientDisconnect(int client) {
	if (IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
		CreateTimer(0.1, tmrCheckTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	CreateTimer(0.1, tmrCheckTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast) {
	if (!g_eRewards.WitchReward)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client) || L4D_IsPlayerIncapacitated(client))
		return;

	SetEntityHealth(client, GetClientHealth(client) + g_eRewards.WitchReward);
	GiveAdrenalineEffect(client, 30.0);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int class = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if (class == 8)
		g_bIsTankActive = FindTank(victim);

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2 || !IsPlayerAlive(attacker))
		return;

	if (class == 8 && g_eRewards.TankReward && !IsFakeClient(attacker) && !L4D_IsPlayerIncapacitated(attacker)) {
		SetEntityHealth(attacker, GetClientHealth(attacker) + g_eRewards.TankReward);
		GiveAdrenalineEffect(attacker, 60.0);
		for (int i = 1; i <= MaxClients; i++) {
			if (i != attacker && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !L4D_IsPlayerIncapacitated(i))
				GiveAdrenalineEffect(attacker, 30.0);
		}
	}

	if (!g_eRewards.RewardBase)
		return;

	if ((g_bIsTankActive && g_eRewards.IsTankAlive) || L4D_IsPlayerIncapacitated(attacker))
		return;

	static int realHP;
	realHP = GetRealHealth(attacker);
	if (realHP > g_eRewards.RewardBound)
		return;

	static char weapon[32];
	event.GetString("weapon", weapon, sizeof weapon);

	int offset;
	g_smWeapon.GetValue(weapon, offset);
	if (!offset || offset & g_eRewards.AllowedWeapon == 0)
		return;

	static float leechHP;
	leechHP = g_eRewards.RewardBase;

	if (event.GetBool("headshot"))
		leechHP *= g_eRewards.HeadShotMulti;

	if (realHP < g_eRewards.LowHealth)
		leechHP *= g_eRewards.LowHealMulti;

	static float vPos[3];
	static float vTarg[3];
	GetClientAbsOrigin(attacker, vPos);
	vTarg[0] = event.GetFloat("victim_x");
	vTarg[1] = event.GetFloat("victim_y");
	vTarg[2] = event.GetFloat("victim_z");
	leechHP += g_eRewards.DistanceMulti * GetVectorDistance(vPos, vTarg);

	if (leechHP > g_eRewards.PerRewardMax)
		leechHP = g_eRewards.PerRewardMax;

	SetEntityHealth(attacker, RoundToCeil(GetClientHealth(attacker) + leechHP));
	GiveAdrenalineEffect(attacker, 5.0);
}

int GetRealHealth(int client) {
	return GetClientHealth(client) + RoundToFloor(GetTempHealth(client));
}

float GetTempHealth(int client) {
	static float tempHealth;
	tempHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fPainPillsDecay;
	return tempHealth < 0.0 ? 0.0 : tempHealth;
}

Action tmrCheckTank(Handle timer) {
	g_bIsTankActive = FindTank(-1);
	return Plugin_Continue;
}

bool FindTank(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			return true;
	}
	return false;
}

void GiveAdrenalineEffect(int client, float duration) {
	float time = Terror_GetAdrenalineTime(client);
	if (time == -1.0)
		time = 0.0;

	Terror_SetAdrenalineTime(client, time + (duration * duration) / (duration + time));
}