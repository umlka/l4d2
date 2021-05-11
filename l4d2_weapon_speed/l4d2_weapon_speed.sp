#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <weaponhandling>

#define PLUGIN_VERSION 	"1.0"

enum L4D2WeaponSpeed 
{
	L4D2WeaponSpeed_MeleeSwing = 0,
	L4D2WeaponSpeed_StartThrow,
	L4D2WeaponSpeed_ReadyingThrow,
	L4D2WeaponSpeed_ReloadModifier,
	L4D2WeaponSpeed_GetRateOfFire,
	L4D2WeaponSpeed_DeployModifier,
	L4D2WeaponSpeed_Max,
};

static const char L4D2WeaponSpeedName[][] =
{
	"meleeswing",
	"startthrow",
	"readyingthrow",
	"reloadmodifier",
	"getrateoffire",
	"deploymodifier"
};

float g_iGlobalWeaponRules[view_as<int>(L4D2WeaponType_Max)][view_as<int>(L4D2WeaponSpeed_Max)];

public Plugin myinfo = 
{
	name = "L4D2 Weapon Speed",
	author = "",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	RegServerCmd("addweaponspeed", CmdAddWeaponSpeed);
	RegServerCmd("resetweaponspeed", CmdResetWeaponSpeed);
}

public Action CmdAddWeaponSpeed(int args)
{
	if(args < 3)
	{
		LogMessage("Usage: addweaponspeed <weapon> <speedtype> <multiple>");
		return Plugin_Handled;
	}

	char sBuffer[64];
	GetCmdArg(1, sBuffer, sizeof(sBuffer));
	L4D2WeaponType type = GetWeaponTypeFromClassname(sBuffer);
	if(!L4D2_IsValidWeaponType(type))
		return Plugin_Handled;

	GetCmdArg(2, sBuffer, sizeof(sBuffer));
	L4D2WeaponSpeed speed = GetWeaponSpeedFromString(sBuffer);
	if(!L4D2_IsValidWeaponSpeed(speed))
		return Plugin_Handled;
		
	GetCmdArg(3, sBuffer, sizeof(sBuffer));
	float fMultiple = StringToFloat(sBuffer);
	if(fMultiple <= 0.0)
		return Plugin_Handled;

	g_iGlobalWeaponRules[type][speed] = fMultiple;
	return Plugin_Handled;
}

stock bool L4D2_IsValidWeaponType(L4D2WeaponType weapontype)
{
	return weapontype >= L4D2WeaponType_Unknown && weapontype < L4D2WeaponType_Max;
}

L4D2WeaponSpeed GetWeaponSpeedFromString(const char[] sBuffer)
{
	for(int i; i < view_as<int>(L4D2WeaponSpeed_Max); i++)
	{
		if(strcmp(sBuffer, L4D2WeaponSpeedName[i]) == 0) 
			return view_as<L4D2WeaponSpeed>(i);
	}
	return L4D2WeaponSpeed_Max;
}

stock bool L4D2_IsValidWeaponSpeed(L4D2WeaponSpeed weaponspeed)
{
	return weaponspeed != L4D2WeaponSpeed_Max;
}

public Action CmdResetWeaponSpeed(int args)
{
	ResetWeaponRules();
	return Plugin_Handled;
}
	
void ResetWeaponRules()
{
	for(int i; i < view_as<int>(L4D2WeaponType_Max); i++)
		for(int j; j < view_as<int>(L4D2WeaponSpeed_Max); j++)
			g_iGlobalWeaponRules[i][j] = 0.0;
}

// ====================================================================================================
//					WEAPON HANDLING
// ====================================================================================================
public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	if(g_iGlobalWeaponRules[L4D2WeaponType_Melee][L4D2WeaponSpeed_MeleeSwing] > 0.0)
		speedmodifier *= g_iGlobalWeaponRules[L4D2WeaponType_Melee][L4D2WeaponSpeed_MeleeSwing];
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if(g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_StartThrow] > 0.0)
		speedmodifier *= g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_StartThrow];
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if(g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_ReadyingThrow] > 0.0)
		speedmodifier *= g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_ReadyingThrow];
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if(g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_ReloadModifier] > 0.0)
		speedmodifier *= g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_ReloadModifier];
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if(g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_GetRateOfFire] > 0.0)
		speedmodifier *= g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_GetRateOfFire];
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if(g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_DeployModifier] > 0.0)
		speedmodifier *= g_iGlobalWeaponRules[weapontype][L4D2WeaponSpeed_DeployModifier];
}