#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <weaponhandling>

#define PLUGIN_NAME				"L4D2 Weapon Speed"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.1.0"
#define PLUGIN_URL				""

enum L4D2WeaponSpeed {
	L4D2WeaponSpeed_MeleeSwing = 0,
	L4D2WeaponSpeed_StartThrow,
	L4D2WeaponSpeed_ReadyingThrow,
	L4D2WeaponSpeed_ReloadModifier,
	L4D2WeaponSpeed_GetRateOfFire,
	L4D2WeaponSpeed_DeployModifier,
	L4D2WeaponSpeed_Max,
};

static const char 
	L4D2WeaponSpeedName[][] = {
		"meleeswing",
		"startthrow",
		"readyingthrow",
		"reloadmodifier",
		"getrateoffire",
		"deploymodifier"
	};

float
	g_iWeaponRules[view_as<int>(L4D2WeaponType_Max)][view_as<int>(L4D2WeaponSpeed_Max)];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	CreateConVar("l4d2_weapon_speed_version", PLUGIN_VERSION, "L4D2 Weapon Speed plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegServerCmd("weapon_speed", cmdWeaponSpeed);
	RegServerCmd("re_weapon_speed", cmdResetWeaponSpeed);
}

Action cmdWeaponSpeed(int args) {
	if (args < 3) {
		LogMessage("Usage: weapon_speed <weapon> <speedtype> <multiple>");
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	L4D2WeaponType type = GetWeaponTypeFromClassname(arg);
	if (!L4D2_IsValidWeaponType(type))
		return Plugin_Handled;

	GetCmdArg(2, arg, sizeof(arg));
	L4D2WeaponSpeed speed = GetWeaponSpeedFromString(arg);
	if (!L4D2_IsValidWeaponSpeed(speed))
		return Plugin_Handled;
		
	GetCmdArg(3, arg, sizeof(arg));
	float fMult = StringToFloat(arg);
	if (fMult <= 0.0)
		return Plugin_Handled;

	g_iWeaponRules[type][speed] = fMult;
	return Plugin_Handled;
}

bool L4D2_IsValidWeaponType(L4D2WeaponType weapontype) {
	return weapontype >= L4D2WeaponType_Unknown && weapontype < L4D2WeaponType_Max;
}

L4D2WeaponSpeed GetWeaponSpeedFromString(const char[] name) {
	for (int i; i < view_as<int>(L4D2WeaponSpeed_Max); i++) {
		if (strcmp(name, L4D2WeaponSpeedName[i]) == 0)
			return view_as<L4D2WeaponSpeed>(i);
	}
	return L4D2WeaponSpeed_Max;
}

bool L4D2_IsValidWeaponSpeed(L4D2WeaponSpeed weaponspeed) {
	return weaponspeed != L4D2WeaponSpeed_Max;
}

Action cmdResetWeaponSpeed(int args) {
	vResetWeaponRules();
	return Plugin_Handled;
}
	
void vResetWeaponRules() {
	for (int i; i < view_as<int>(L4D2WeaponType_Max); i++)
		for (int j; j < view_as<int>(L4D2WeaponSpeed_Max); j++)
			g_iWeaponRules[i][j] = 0.0;
}

// ====================================================================================================
//					WEAPON HANDLING
// ====================================================================================================
public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier) {
	if (g_iWeaponRules[L4D2WeaponType_Melee][L4D2WeaponSpeed_MeleeSwing] > 0.0)
		speedmodifier *= g_iWeaponRules[L4D2WeaponType_Melee][L4D2WeaponSpeed_MeleeSwing];
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	if (g_iWeaponRules[weapontype][L4D2WeaponSpeed_StartThrow] > 0.0)
		speedmodifier *= g_iWeaponRules[weapontype][L4D2WeaponSpeed_StartThrow];
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	if (g_iWeaponRules[weapontype][L4D2WeaponSpeed_ReadyingThrow] > 0.0)
		speedmodifier *= g_iWeaponRules[weapontype][L4D2WeaponSpeed_ReadyingThrow];
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	if (g_iWeaponRules[weapontype][L4D2WeaponSpeed_ReloadModifier] > 0.0)
		speedmodifier *= g_iWeaponRules[weapontype][L4D2WeaponSpeed_ReloadModifier];
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	if (g_iWeaponRules[weapontype][L4D2WeaponSpeed_GetRateOfFire] > 0.0)
		speedmodifier *= g_iWeaponRules[weapontype][L4D2WeaponSpeed_GetRateOfFire];
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier) {
	if (g_iWeaponRules[weapontype][L4D2WeaponSpeed_DeployModifier] > 0.0)
		speedmodifier *= g_iWeaponRules[weapontype][L4D2WeaponSpeed_DeployModifier];
}
