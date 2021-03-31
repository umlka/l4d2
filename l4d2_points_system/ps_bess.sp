#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <ps_natives>

#define PLUGIN_VERSION "2.0.0"
#define PS_ModuleName "\nBuy Extended Support Structure (BESS Module)"

#define MSGTAG "\x04[PS]\x01"

public Plugin myinfo =
{
	name = "[PS] Buy Extended Support Structure",
	author = "McFlurry && evilmaniac and modified by Psykotik",
	description = "Module to extend buy support, example: !buy pills // this would buy you pills",
	version = PLUGIN_VERSION,
	url = "http://www.evilmania.net"
}

//float g_fVersion;
float g_fMinLibraryVersion;
bool g_bModuleLoaded;

enum
{
	hVersion,
	hEnabled
}

ConVar ModuleSettings[2];

void initPluginSettings()
{
	//g_fVersion = 2.00;
	g_fMinLibraryVersion = 1.77;

	ModuleSettings[hVersion] = CreateConVar("em_ps_bess", PLUGIN_VERSION, "PS Bess version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);
	ModuleSettings[hEnabled] = CreateConVar("ps_bess_enable", "1", "Enable BESS Module", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bModuleLoaded = false;
	return;
}

StringMap hItemMap = null;
StringMap hPriceMap = null;
StringMap hTeamExclusive = null;

void populateItemMap()
{
	// Health Items
	hItemMap.SetString("pills", "give pain_pills", true);
	hItemMap.SetString("pill", "give pain_pills", true);
	hItemMap.SetString("medkit", "give first_aid_kit", true);
	hItemMap.SetString("kit", "give first_aid_kit", true);
	hItemMap.SetString("defib", "give defibrillator", true);
	hItemMap.SetString("def", "give defibrillator", true);
	hItemMap.SetString("adrenaline", "give adrenaline", true);
	hItemMap.SetString("adren", "give adrenaline", true);
	hItemMap.SetString("shot", "give adrenaline", true);
	hItemMap.SetString("fheal", "give health", true);
	hItemMap.SetString("heal", "give health", true);

	// Secondary Pistols
	hItemMap.SetString("pistol", "give pistol", true);
	hItemMap.SetString("p220", "give pistol", true);
	hItemMap.SetString("magnum", "give pistol_magnum", true);
	hItemMap.SetString("deagle", "give pistol_magnum", true);

	// SMGs
	hItemMap.SetString("smg", "give smg", true);
	hItemMap.SetString("silenced", "give smg_silenced", true);
	hItemMap.SetString("silence", "give smg_silenced", true);
	hItemMap.SetString("silent", "give smg_silenced", true);
	hItemMap.SetString("sil", "give smg_silenced", true);
	hItemMap.SetString("mp5", "give smg_mp5", true);

	// Rifles
	hItemMap.SetString("m16", "give rifle", true);
	hItemMap.SetString("scar", "give rifle_desert", true);
	hItemMap.SetString("desert", "give rifle_desert", true);
	hItemMap.SetString("ak47", "give rifle_ak47", true);
	hItemMap.SetString("sg552", "give rifle_sg552", true);
	hItemMap.SetString("m60", "give rifle_m60", true);

	// Sniper
	hItemMap.SetString("hunting", "give hunting_rifle", true);
	hItemMap.SetString("scout", "give sniper_scout", true);
	hItemMap.SetString("military", "give sniper_military", true);
	hItemMap.SetString("awp", "give sniper_awp", true);

	// Shotguns
	hItemMap.SetString("chrome", "give shotgun_chrome", true);
	hItemMap.SetString("pump", "give pumpshotgun", true);
	hItemMap.SetString("spas", "give shotgun_spas", true);
	hItemMap.SetString("auto", "give autoshotgun", true);

	// Throwables
	hItemMap.SetString("molotov", "give molotov", true);
	hItemMap.SetString("mol", "give molotov", true);
	hItemMap.SetString("pipe", "give pipe_bomb", true);
	hItemMap.SetString("bile", "give vomitjar", true);
	hItemMap.SetString("puke", "give vomitjar", true);
	hItemMap.SetString("vomit", "give vomitjar", true);

	// Misc
	hItemMap.SetString("chainsaw", "give chainsaw", true);
	hItemMap.SetString("grenade", "give grenade_launcher", true);
	hItemMap.SetString("gnome", "give gnome", true);
	hItemMap.SetString("cola", "give cola_bottles", true);
	hItemMap.SetString("gas", "give gascan", true);
	hItemMap.SetString("propane", "give propanetank", true);
	hItemMap.SetString("fworks", "give fireworkcrate", true);
	hItemMap.SetString("oxy", "give oxygentank", true);

	// Upgrades
	hItemMap.SetString("packex", "give upgradepack_explosive", true);
	hItemMap.SetString("packin", "give upgradepack_incendiary", true);
	hItemMap.SetString("ammo", "give ammo", true);
	hItemMap.SetString("exammo", "upgrade_add EXPLOSIVE_AMMO", true);
	hItemMap.SetString("inammo", "upgrade_add INCENDIARY_AMMO", true);
	hItemMap.SetString("laser", "upgrade_add LASER_SIGHT", true);

	// Melee
	hItemMap.SetString("baseball_bat", "give baseball_bat", true);
	hItemMap.SetString("bat", "give baseball_bat", true);
	hItemMap.SetString("cricket_bat", "give cricket_bat", true);
	hItemMap.SetString("cricket", "give cricket_bat", true);
	hItemMap.SetString("cbat", "give cricket_bat", true);
	hItemMap.SetString("crowbar", "give crowbar", true);
	hItemMap.SetString("electric_guitar", "give electric_guitar", true);
	hItemMap.SetString("guitar", "give electric_guitar", true);
	hItemMap.SetString("fireaxe", "give fireaxe", true);
	hItemMap.SetString("axe", "give fireaxe", true);
	hItemMap.SetString("frying_pan", "give frying_pan", true);
	hItemMap.SetString("pan", "give frying_pan", true);
	hItemMap.SetString("golfclub", "give golfclub", true);
	hItemMap.SetString("club", "give golfclub", true);
	hItemMap.SetString("katana", "give katana", true);
	hItemMap.SetString("ninja", "give katana", true);
	hItemMap.SetString("machete", "give machete", true);
	hItemMap.SetString("tonfa", "give tonfa", true);
	hItemMap.SetString("nightstick", "give tonfa", true);

	// Infected
	hItemMap.SetString("kill", "kill", true);
	hItemMap.SetString("boomer", "z_spawn_old boomer auto", true);
	hItemMap.SetString("smoker", "z_spawn_old smoker auto", true);
	hItemMap.SetString("hunter", "z_spawn_old hunter auto", true);
	hItemMap.SetString("spitter", "z_spawn_old spitter auto", true);
	hItemMap.SetString("jockey", "z_spawn_old jockey auto", true);
	hItemMap.SetString("charger", "z_spawn_old charger auto", true);
	hItemMap.SetString("witch", "z_spawn_old witch auto", true);
	hItemMap.SetString("bride", "z_spawn_old witch_bride auto", true);
	hItemMap.SetString("tank", "z_spawn_old tank auto", true);
	hItemMap.SetString("horde", "director_force_panic_event", true);
	hItemMap.SetString("mob", "z_spawn_old mob auto", true);
	hItemMap.SetString("umob", "z_spawn_old mob", true);

	return;
}

void populatePriceMap()
{
	// Health Items
	hPriceMap.SetValue("pills", FindConVar("l4d2_points_pills").IntValue, true);
	hPriceMap.SetValue("pill", FindConVar("l4d2_points_pills").IntValue, true);
	hPriceMap.SetValue("medkit", FindConVar("l4d2_points_medkit").IntValue, true);
	hPriceMap.SetValue("kit", FindConVar("l4d2_points_medkit").IntValue, true);
	hPriceMap.SetValue("defib", FindConVar("l4d2_points_defib").IntValue, true);
	hPriceMap.SetValue("def", FindConVar("l4d2_points_defib").IntValue, true);
	hPriceMap.SetValue("adrenaline", FindConVar("l4d2_points_adrenaline").IntValue, true);
	hPriceMap.SetValue("adren", FindConVar("l4d2_points_adrenaline").IntValue, true);
	hPriceMap.SetValue("shot", FindConVar("l4d2_points_adrenaline").IntValue, true);

	// Secondary Pistols
	hPriceMap.SetValue("pistol", FindConVar("l4d2_points_pistol").IntValue, true);
	hPriceMap.SetValue("p220", FindConVar("l4d2_points_pistol").IntValue, true);
	hPriceMap.SetValue("magnum", FindConVar("l4d2_points_magnum").IntValue, true);
	hPriceMap.SetValue("deagle", FindConVar("l4d2_points_magnum").IntValue, true);

	// SMGs
	hPriceMap.SetValue("smg", FindConVar("l4d2_points_smg").IntValue, true);
	hPriceMap.SetValue("silenced", FindConVar("l4d2_points_silenced").IntValue, true);
	hPriceMap.SetValue("silence", FindConVar("l4d2_points_silenced").IntValue, true);
	hPriceMap.SetValue("silent", FindConVar("l4d2_points_silenced").IntValue, true);
	hItemMap.SetString("sil", "give smg_silenced", true);
	hPriceMap.SetValue("mp5", FindConVar("l4d2_points_mp5").IntValue, true);

	// Rifles
	hPriceMap.SetValue("m16", FindConVar("l4d2_points_m16").IntValue, true);
	hPriceMap.SetValue("scar", FindConVar("l4d2_points_scar").IntValue, true);
	hPriceMap.SetValue("desert", FindConVar("l4d2_points_scar").IntValue, true);
	hPriceMap.SetValue("ak47", FindConVar("l4d2_points_ak47").IntValue, true);
	hPriceMap.SetValue("sg552", FindConVar("l4d2_points_sg552").IntValue, true);
	hPriceMap.SetValue("m60", FindConVar("l4d2_points_m60").IntValue, true);

	// Snipers
	hPriceMap.SetValue("hunting", FindConVar("l4d2_points_hunting").IntValue, true);
	hPriceMap.SetValue("scout", FindConVar("l4d2_points_scout").IntValue, true);
	hPriceMap.SetValue("military", FindConVar("l4d2_points_military").IntValue, true);
	hPriceMap.SetValue("awp", FindConVar("l4d2_points_awp").IntValue, true);

	// Shotguns
	hPriceMap.SetValue("chrome", FindConVar("l4d2_points_chrome").IntValue, true);
	hPriceMap.SetValue("pump", FindConVar("l4d2_points_pump").IntValue, true);
	hPriceMap.SetValue("spas", FindConVar("l4d2_points_spas").IntValue, true);
	hPriceMap.SetValue("auto", FindConVar("l4d2_points_auto").IntValue, true);

	// Throwables
	hPriceMap.SetValue("molotov", FindConVar("l4d2_points_molotov").IntValue, true);
	hPriceMap.SetValue("mol", FindConVar("l4d2_points_molotov").IntValue, true);
	hPriceMap.SetValue("pipe", FindConVar("l4d2_points_pipe").IntValue, true);
	hPriceMap.SetValue("bile", FindConVar("l4d2_points_bile").IntValue, true);
	hPriceMap.SetValue("puke", FindConVar("l4d2_points_bile").IntValue, true);
	hPriceMap.SetValue("vomit", FindConVar("l4d2_points_bile").IntValue, true);

	// Misc
	hPriceMap.SetValue("chainsaw", FindConVar("l4d2_points_chainsaw").IntValue, true);
	hPriceMap.SetValue("grenade", FindConVar("l4d2_points_grenade").IntValue, true);
	hPriceMap.SetValue("gnome", FindConVar("l4d2_points_gnome").IntValue, true);
	hPriceMap.SetValue("cola", FindConVar("l4d2_points_cola").IntValue, true);
	hPriceMap.SetValue("gas", FindConVar("l4d2_points_gascan").IntValue, true);
	hPriceMap.SetValue("propane", FindConVar("l4d2_points_propane").IntValue, true);
	hPriceMap.SetValue("fworks", FindConVar("l4d2_points_fireworks").IntValue, true);
	hPriceMap.SetValue("oxy", FindConVar("l4d2_points_oxygen").IntValue, true);

	// Upgrades
	hPriceMap.SetValue("packex", FindConVar("l4d2_points_explosive_ammo_pack").IntValue, true);
	hPriceMap.SetValue("packin", FindConVar("l4d2_points_incendiary_ammo_pack").IntValue, true);
	hPriceMap.SetValue("ammo", FindConVar("l4d2_points_refill").IntValue, true);
	hPriceMap.SetValue("exammo", FindConVar("l4d2_points_explosive_ammo").IntValue, true);
	hPriceMap.SetValue("inammo", FindConVar("l4d2_points_incendiary_ammo").IntValue, true);
	hPriceMap.SetValue("laser", FindConVar("l4d2_points_laser").IntValue, true);

	// Melee
	hPriceMap.SetValue("baseball_bat", FindConVar("l4d2_points_baseballbat").IntValue, true);
	hPriceMap.SetValue("bat", FindConVar("l4d2_points_baseballbat").IntValue, true);
	hPriceMap.SetValue("cricket_bat", FindConVar("l4d2_points_cricketbat").IntValue, true);
	hPriceMap.SetValue("cricket", FindConVar("l4d2_points_cricketbat").IntValue, true);
	hPriceMap.SetValue("cbat", FindConVar("l4d2_points_cricketbat").IntValue, true);
	hPriceMap.SetValue("crowbar", FindConVar("l4d2_points_crowbar").IntValue, true);
	hPriceMap.SetValue("electric_guitar", FindConVar("l4d2_points_electricguitar").IntValue, true);
	hPriceMap.SetValue("guitar", FindConVar("l4d2_points_electricguitar").IntValue, true);
	hPriceMap.SetValue("fireaxe", FindConVar("l4d2_points_fireaxe").IntValue, true);
	hPriceMap.SetValue("axe", FindConVar("l4d2_points_fireaxe").IntValue, true);
	hPriceMap.SetValue("frying_pan", FindConVar("l4d2_points_fryingpan").IntValue, true);
	hPriceMap.SetValue("pan", FindConVar("l4d2_points_fryingpan").IntValue, true);
	hPriceMap.SetValue("golfclub", FindConVar("l4d2_points_golfclub").IntValue, true);
	hPriceMap.SetValue("club", FindConVar("l4d2_points_golfclub").IntValue, true);
	hPriceMap.SetValue("katana", FindConVar("l4d2_points_katana").IntValue, true);
	hPriceMap.SetValue("ninja", FindConVar("l4d2_points_katana").IntValue, true);
	hPriceMap.SetValue("machete", FindConVar("l4d2_points_machete").IntValue, true);
	hPriceMap.SetValue("tonfa", FindConVar("l4d2_points_tonfa").IntValue, true);
	hPriceMap.SetValue("nightstick", FindConVar("l4d2_points_tonfa").IntValue, true);

	// Infected
	hPriceMap.SetValue("kill", FindConVar("l4d2_points_suicide").IntValue, true);
	hPriceMap.SetValue("boomer", FindConVar("l4d2_points_boomer").IntValue, true);
	hPriceMap.SetValue("smoker", FindConVar("l4d2_points_smoker").IntValue, true);
	hPriceMap.SetValue("hunter", FindConVar("l4d2_points_hunter").IntValue, true);
	hPriceMap.SetValue("spitter", FindConVar("l4d2_points_spitter").IntValue, true);
	hPriceMap.SetValue("jockey", FindConVar("l4d2_points_jockey").IntValue, true);
	hPriceMap.SetValue("charger", FindConVar("l4d2_points_charger").IntValue, true);
	hPriceMap.SetValue("witch", FindConVar("l4d2_points_witch").IntValue, true);
	hPriceMap.SetValue("bride", FindConVar("l4d2_points_witch").IntValue, true);
	hPriceMap.SetValue("tank", FindConVar("l4d2_points_tank").IntValue, true);
	hPriceMap.SetValue("horde", FindConVar("l4d2_points_horde").IntValue, true);
	hPriceMap.SetValue("mob", FindConVar("l4d2_points_mob").IntValue, true);
	hPriceMap.SetValue("umob", FindConVar("l4d2_points_umob").IntValue, true);

	return;
}

void populateExclusiveItemsMap()
{
	//  Infected Only
	hTeamExclusive.SetValue("kill", 2, true);
	hTeamExclusive.SetValue("boomer", 2, true);
	hTeamExclusive.SetValue("smoker", 2, true);
	hTeamExclusive.SetValue("hunter", 2, true);
	hTeamExclusive.SetValue("spitter", 2, true);
	hTeamExclusive.SetValue("jockey", 2, true);
	hTeamExclusive.SetValue("charger", 2, true);
	hTeamExclusive.SetValue("witch", 2, true);
	hTeamExclusive.SetValue("bride", 2, true);
	hTeamExclusive.SetValue("tank", 2, true);
	hTeamExclusive.SetValue("horde", 2, true);
	hTeamExclusive.SetValue("mob", 2, true);
	hTeamExclusive.SetValue("umob", 2, true);

	// Survivor Only
	hTeamExclusive.SetValue("laser", 2, true);
	hTeamExclusive.SetValue("packex", 2, true);
	hTeamExclusive.SetValue("packin", 2, true);
	hTeamExclusive.SetValue("exammo", 2, true);
	hTeamExclusive.SetValue("inammo", 2, true);

	return;
}

void buildMap()
{
	hItemMap = new StringMap();
	hPriceMap = new StringMap();
	hTeamExclusive = new StringMap();

	populateItemMap();
	populatePriceMap();
	populateExclusiveItemsMap();
	return;
}

void registerConsoleCommands()
{
	RegConsoleCmd("sm_buy", Cmd_Buy);
	return;
}

bool IsModuleActive()
{
	if(ModuleSettings[hEnabled].BoolValue)
		if(g_bModuleLoaded)
			if(PS_IsSystemEnabled())
				return true;
	return false;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	initPluginSettings();
	registerConsoleCommands();

	//AutoExecConfig(true, "ps_bess");
	LoadTranslations("points_system.phrases");
	return;
}

public void OnAllPluginsLoaded()
{
	if(LibraryExists("ps_natives"))
	{
		if(PS_GetVersion() >= g_fMinLibraryVersion)
		{
			if(!PS_RegisterModule(PS_ModuleName)) // If module registeration has failed
				LogMessage("[PS] Plugin already registered.");
			else
			{
				buildMap();
				g_bModuleLoaded = true;
			}
		}
		else
			SetFailState("[PS] Outdated version of Points System installed.");
	}
	else
		SetFailState("[PS] PS Natives are not loaded.");
}

public void OnPluginEnd()
{
	PS_UnregisterModule(PS_ModuleName);
}

public void  OnPSUnloaded()
{
	g_bModuleLoaded = false;
}

public void OnConfigsExecuted()
{
	populatePriceMap();
}

bool IsClientSurvivor(int iClientIndex)
{
	if(iClientIndex > 0 && GetClientTeam(iClientIndex) == 2)
		return true;

	return false;
}

bool IsClientInfected(int iClientIndex)
{
	if(iClientIndex > 0 && GetClientTeam(iClientIndex) == 3)
		return true;

	return false;
}

bool IsClientTank(int iClientIndex)
{
	if(iClientIndex > 0 && GetEntProp(iClientIndex, Prop_Send, "m_zombieClass") == 8)
		return true;

	return false;
}

bool checkDisabled(int iCost)
{
	if(iCost <= -1)
	{
		//PrintToChat(iClientIndex, "%s %T", MSGTAG, "Item Disabled", iClientIndex);
		return true;
	}
	else
	{
		return false;
	}
}

bool checkPoints(int iClientIndex, int iCost)
{
	if(PS_GetPoints(iClientIndex) >= iCost)
	{
		return true;
	}
	else
	{
		PrintToChat(iClientIndex, "%s %T", MSGTAG, "Insufficient Funds", iClientIndex);
		return false;
	}
}

bool hasEnoughPoints(int iClientIndex, int iCost)
{
	return checkPoints(iClientIndex, iCost);
}

void removePoints(int iClientIndex, int iPoints)
{
	PS_RemovePoints(iClientIndex, iPoints);
	return;
}

int getHealCost(int iClientIndex)
{
	int iCost = -1;
	if(IsClientInfected(iClientIndex))
	{
		iCost = FindConVar("l4d2_points_infected_heal").IntValue;

		if(IsClientTank(iClientIndex))
			iCost *= FindConVar("l4d2_points_tank_heal_mult").IntValue;
	}
	else if(IsClientSurvivor(iClientIndex))
		iCost = FindConVar("l4d2_points_survivor_heal").IntValue;

	return(iCost);
}

public Action Cmd_Buy(int iClientIndex, int iNumArgs)
{
	if(iNumArgs != 1)
		return Plugin_Continue;

	if(!IsModuleActive() || !IsClientInGame(iClientIndex) || iClientIndex > MaxClients)
		return Plugin_Continue;

	if(!IsPlayerAlive(iClientIndex))
	{
		ReplyToCommand(iClientIndex, "[PS] Must Be Alive To Buy Items!");
		return Plugin_Continue;
	}

	char sPlayerInput[50];
	char sPurchaseCmd[100];
	GetCmdArg(1, sPlayerInput, sizeof(sPlayerInput));

	if(hItemMap.GetString(sPlayerInput, sPurchaseCmd, sizeof(sPurchaseCmd))){ // If an entry exists
		int iRequiredTeam = 0;
		if(hTeamExclusive.GetValue(sPlayerInput, iRequiredTeam))
			if(GetClientTeam(iClientIndex) != iRequiredTeam)
				return Plugin_Continue;

		int iCost = -2; //-2 = invalid
		if(!strcmp(sPlayerInput, "cola", false))
		{
			char sMapName[100];

			GetCurrentMap(sMapName, 100);
			if(!strcmp(sMapName, "c1m2_streets", false))
				PrintToChat(iClientIndex, "[PS] This item is unavailable during this map");
		}
		else if(!strcmp(sPlayerInput, "fheal", false) || !strcmp(sPlayerInput, "heal", false))
		{
			iCost = getHealCost(iClientIndex);
			if(!checkDisabled(iCost))
				performHeal(iClientIndex, iCost);
			return Plugin_Continue;
		}
		else
		{ // If not a special case
			if(hPriceMap.GetValue(sPlayerInput, iCost) && !checkDisabled(iCost))
			{
				if(!strcmp(sPlayerInput, "kill", false))
					performSuicide(iClientIndex, iCost);
				else if(!strcmp(sPlayerInput, "umob", false) && IsClientInfected(iClientIndex))
				{
					PS_SetBoughtCost(iClientIndex, iCost);
					PS_SetBought(iClientIndex, sPurchaseCmd);
					HandleUMob(iClientIndex);
				}
				else if(GetClientTeam(iClientIndex) > 1) // If not a spectator
					performPurchase(iClientIndex, iCost, sPurchaseCmd);
			}
		}
	}
	return Plugin_Continue;
}

bool IsCarryingWeapon(int iClientIndex)
{
	int iWeapon = GetPlayerWeaponSlot(iClientIndex, 0);
	if(iWeapon == -1)
		return false;
	else 
		return true;
}

public void reloadAmmo(int iClientIndex, int iCost, const char[] sItem)
{
	int hWeapon = GetPlayerWeaponSlot(iClientIndex, 0);
	if(IsCarryingWeapon(iClientIndex))
	{

		char sWeapon[40];
		GetEdictClassname(hWeapon, sWeapon, sizeof(sWeapon));
		if(!strcmp(sWeapon, "weapon_rifle_m60", false))
		{
			int iAmmo_m60 = 150;
			ConVar hGunControl_m60 = FindConVar("l4d2_guncontrol_m60ammo");
			if(hGunControl_m60 != null)
			{
				iAmmo_m60 = hGunControl_m60.IntValue;
				delete hGunControl_m60;
			}
			SetEntProp(hWeapon, Prop_Send, "m_iClip1", iAmmo_m60);
		}
		else if(!strcmp(sWeapon, "weapon_grenade_launcher", false))
		{
			int iAmmo_Launcher = 30;
			ConVar hGunControl_Launcher = FindConVar("l4d2_guncontrol_grenadelauncherammo");
			if(hGunControl_Launcher != null)
			{
				iAmmo_Launcher = hGunControl_Launcher.IntValue;
				delete hGunControl_Launcher;
			}
			int uOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
			SetEntData(iClientIndex, uOffset + 68, iAmmo_Launcher);
		}
		CheatCommand(iClientIndex, sItem);
		removePoints(iClientIndex, iCost);
	}
	else
		PrintToChat(iClientIndex, "%s %T", MSGTAG, "Primary Warning", iClientIndex);
	return;
}

void setLastPurchase(int iClientIndex, int iCost, const char[] sPurchaseCmd)
{ // We are doing this so !repeatbuy works
	PS_SetItem(iClientIndex, sPurchaseCmd);
	PS_SetCost(iClientIndex, iCost);
	return;
}

void performPurchase(int iClientIndex, int iCost, const char[] sPurchaseCmd)
{ // sItem[] should be const
	if(iCost >= 0)
	{
		if(hasEnoughPoints(iClientIndex, iCost))
		{
			if(!strcmp(sPurchaseCmd, "give ammo", false))
			{
				reloadAmmo(iClientIndex, iCost, sPurchaseCmd);
				setLastPurchase(iClientIndex, iCost, sPurchaseCmd);
			}
			else
			{
				CheatCommand(iClientIndex, sPurchaseCmd);
				removePoints(iClientIndex, iCost);
				setLastPurchase(iClientIndex, iCost, sPurchaseCmd);
			}
		}
	}
	return;
}

void performHeal(int iClientIndex, int iCost)
{
	if(iCost >= 0)
	{
		if(hasEnoughPoints(iClientIndex, iCost))
		{
			CheatCommand(iClientIndex, "give health");
			removePoints(iClientIndex, iCost);
		}
	}
	return;
}

void performSuicide(int iClientIndex, int iCost)
{
	if(iCost >= 0)
	{
		if(hasEnoughPoints(iClientIndex, iCost))
		{
			if(IsClientInGame(iClientIndex) && IsPlayerAlive(iClientIndex))
			{
				ForcePlayerSuicide(iClientIndex);
				if(IsClientTank(iClientIndex))
					return;
				else
					removePoints(iClientIndex, iCost);
			}
		}
	}
	return;
}

stock void HandleUMob(int iClientIndex)
{
	PS_SetCost(iClientIndex, PS_GetBoughtCost(iClientIndex));
	if(PS_GetCost(iClientIndex) > -1 && PS_GetPoints(iClientIndex) >= PS_GetCost(iClientIndex))
	{
		PS_SetupUMob(FindConVar("z_common_limit").IntValue);
		PS_SetItem(iClientIndex, "z_spawn_old mob");

		removePoints(iClientIndex, PS_GetCost(iClientIndex));

	}
	else if(checkDisabled(PS_GetCost(iClientIndex)))
		PS_SetBoughtCost(iClientIndex, PS_GetBoughtCost(iClientIndex));
	else
	{
		PS_SetBoughtCost(iClientIndex, PS_GetBoughtCost(iClientIndex));
		ReplyToCommand(iClientIndex, "%s %T", MSGTAG, "Insufficient Funds", iClientIndex);
	}
}

void CheatCommand(int client, const char[] sCommand)
{
	if(client == 0 || !IsClientInGame(client))
		return;

	char sCmd[32];
	if(SplitString(sCommand, " ", sCmd, sizeof(sCmd)) == -1)
		strcopy(sCmd, sizeof(sCmd), sCommand);

	int bits = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(sCmd);
	SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, sCommand);
	SetCommandFlags(sCmd, flags);
	SetUserFlagBits(client, bits);
	if(sCommand[0] == 'g' && strcmp(sCommand[5], "health") == 0)
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0); //防止有虚血时give health会超过100血

	return;
}