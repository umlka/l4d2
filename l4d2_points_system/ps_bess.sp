#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <ps_natives>

#define PLUGIN_VERSION "2.0.0"
#define MSGTAG 			"\x04[PS]\x01"
#define PS_ModuleName "Buy Extended Support Structure (BESS Module)"

public Plugin myinfo =
{
	name = "[PS] Buy Extended Support Structure",
	author = "McFlurry && evilmaniac and modified by Psykotik",
	description = "Module to extend buy support, example: !buy pills // this would buy you pills",
	version = PLUGIN_VERSION,
	url = "http://www.evilmania.net"
}

ConVar
	g_hEnabled;

StringMap
	g_aItemMap,
	g_aPriceMap,
	g_aTeamExclusive;

float
	g_fMinLibraryVersion;

bool
	g_bModuleLoaded;

void vPopulateItemMap()
{
	// Health Items
	g_aItemMap.SetString("pills", "give pain_pills", true);
	g_aItemMap.SetString("pill", "give pain_pills", true);
	g_aItemMap.SetString("medkit", "give first_aid_kit", true);
	g_aItemMap.SetString("kit", "give first_aid_kit", true);
	g_aItemMap.SetString("defib", "give defibrillator", true);
	g_aItemMap.SetString("def", "give defibrillator", true);
	g_aItemMap.SetString("adrenaline", "give adrenaline", true);
	g_aItemMap.SetString("adren", "give adrenaline", true);
	g_aItemMap.SetString("shot", "give adrenaline", true);
	g_aItemMap.SetString("fheal", "give health", true);
	g_aItemMap.SetString("heal", "give health", true);

	// Secondary Pistols
	g_aItemMap.SetString("pistol", "give pistol", true);
	g_aItemMap.SetString("p220", "give pistol", true);
	g_aItemMap.SetString("magnum", "give pistol_magnum", true);
	g_aItemMap.SetString("deagle", "give pistol_magnum", true);

	// SMGs
	g_aItemMap.SetString("smg", "give smg", true);
	g_aItemMap.SetString("silenced", "give smg_silenced", true);
	g_aItemMap.SetString("silence", "give smg_silenced", true);
	g_aItemMap.SetString("silent", "give smg_silenced", true);
	g_aItemMap.SetString("sil", "give smg_silenced", true);
	g_aItemMap.SetString("mp5", "give smg_mp5", true);

	// Rifles
	g_aItemMap.SetString("m16", "give rifle", true);
	g_aItemMap.SetString("scar", "give rifle_desert", true);
	g_aItemMap.SetString("desert", "give rifle_desert", true);
	g_aItemMap.SetString("ak47", "give rifle_ak47", true);
	g_aItemMap.SetString("sg552", "give rifle_sg552", true);
	g_aItemMap.SetString("m60", "give rifle_m60", true);

	// Sniper
	g_aItemMap.SetString("hunting", "give hunting_rifle", true);
	g_aItemMap.SetString("scout", "give sniper_scout", true);
	g_aItemMap.SetString("military", "give sniper_military", true);
	g_aItemMap.SetString("awp", "give sniper_awp", true);

	// Shotguns
	g_aItemMap.SetString("chrome", "give shotgun_chrome", true);
	g_aItemMap.SetString("pump", "give pumpshotgun", true);
	g_aItemMap.SetString("spas", "give shotgun_spas", true);
	g_aItemMap.SetString("auto", "give autoshotgun", true);

	// Throwables
	g_aItemMap.SetString("molotov", "give molotov", true);
	g_aItemMap.SetString("mol", "give molotov", true);
	g_aItemMap.SetString("pipe", "give pipe_bomb", true);
	g_aItemMap.SetString("bile", "give vomitjar", true);
	g_aItemMap.SetString("puke", "give vomitjar", true);
	g_aItemMap.SetString("vomit", "give vomitjar", true);

	// Misc
	g_aItemMap.SetString("chainsaw", "give chainsaw", true);
	g_aItemMap.SetString("grenade", "give grenade_launcher", true);
	g_aItemMap.SetString("gnome", "give gnome", true);
	g_aItemMap.SetString("cola", "give cola_bottles", true);
	g_aItemMap.SetString("gas", "give gascan", true);
	g_aItemMap.SetString("propane", "give propanetank", true);
	g_aItemMap.SetString("fworks", "give fireworkcrate", true);
	g_aItemMap.SetString("oxy", "give oxygentank", true);

	// Upgrades
	g_aItemMap.SetString("packex", "give upgradepack_explosive", true);
	g_aItemMap.SetString("packin", "give upgradepack_incendiary", true);
	g_aItemMap.SetString("ammo", "give ammo", true);
	g_aItemMap.SetString("exammo", "upgrade_add EXPLOSIVE_AMMO", true);
	g_aItemMap.SetString("inammo", "upgrade_add INCENDIARY_AMMO", true);
	g_aItemMap.SetString("laser", "upgrade_add LASER_SIGHT", true);

	// Melee
	g_aItemMap.SetString("baseball_bat", "give baseball_bat", true);
	g_aItemMap.SetString("bat", "give baseball_bat", true);
	g_aItemMap.SetString("cricket_bat", "give cricket_bat", true);
	g_aItemMap.SetString("cricket", "give cricket_bat", true);
	g_aItemMap.SetString("cbat", "give cricket_bat", true);
	g_aItemMap.SetString("crowbar", "give crowbar", true);
	g_aItemMap.SetString("electric_guitar", "give electric_guitar", true);
	g_aItemMap.SetString("guitar", "give electric_guitar", true);
	g_aItemMap.SetString("fireaxe", "give fireaxe", true);
	g_aItemMap.SetString("axe", "give fireaxe", true);
	g_aItemMap.SetString("frying_pan", "give frying_pan", true);
	g_aItemMap.SetString("pan", "give frying_pan", true);
	g_aItemMap.SetString("golfclub", "give golfclub", true);
	g_aItemMap.SetString("club", "give golfclub", true);
	g_aItemMap.SetString("katana", "give katana", true);
	g_aItemMap.SetString("ninja", "give katana", true);
	g_aItemMap.SetString("machete", "give machete", true);
	g_aItemMap.SetString("tonfa", "give tonfa", true);
	g_aItemMap.SetString("nightstick", "give tonfa", true);

	// Infected
	g_aItemMap.SetString("kill", "kill", true);
	g_aItemMap.SetString("boomer", "z_spawn_old boomer auto", true);
	g_aItemMap.SetString("smoker", "z_spawn_old smoker auto", true);
	g_aItemMap.SetString("hunter", "z_spawn_old hunter auto", true);
	g_aItemMap.SetString("spitter", "z_spawn_old spitter auto", true);
	g_aItemMap.SetString("jockey", "z_spawn_old jockey auto", true);
	g_aItemMap.SetString("charger", "z_spawn_old charger auto", true);
	g_aItemMap.SetString("witch", "z_spawn_old witch auto", true);
	g_aItemMap.SetString("bride", "z_spawn_old witch_bride auto", true);
	g_aItemMap.SetString("tank", "z_spawn_old tank auto", true);
	g_aItemMap.SetString("horde", "director_force_panic_event", true);
	g_aItemMap.SetString("mob", "z_spawn_old mob auto", true);
}

void vPopulatePriceMap()
{
	// Health Items
	g_aPriceMap.SetValue("pills", FindConVar("l4d2_points_pills").IntValue, true);
	g_aPriceMap.SetValue("pill", FindConVar("l4d2_points_pills").IntValue, true);
	g_aPriceMap.SetValue("medkit", FindConVar("l4d2_points_medkit").IntValue, true);
	g_aPriceMap.SetValue("kit", FindConVar("l4d2_points_medkit").IntValue, true);
	g_aPriceMap.SetValue("defib", FindConVar("l4d2_points_defib").IntValue, true);
	g_aPriceMap.SetValue("def", FindConVar("l4d2_points_defib").IntValue, true);
	g_aPriceMap.SetValue("adrenaline", FindConVar("l4d2_points_adrenaline").IntValue, true);
	g_aPriceMap.SetValue("adren", FindConVar("l4d2_points_adrenaline").IntValue, true);
	g_aPriceMap.SetValue("shot", FindConVar("l4d2_points_adrenaline").IntValue, true);

	// Secondary Pistols
	g_aPriceMap.SetValue("pistol", FindConVar("l4d2_points_pistol").IntValue, true);
	g_aPriceMap.SetValue("p220", FindConVar("l4d2_points_pistol").IntValue, true);
	g_aPriceMap.SetValue("magnum", FindConVar("l4d2_points_magnum").IntValue, true);
	g_aPriceMap.SetValue("deagle", FindConVar("l4d2_points_magnum").IntValue, true);

	// SMGs
	g_aPriceMap.SetValue("smg", FindConVar("l4d2_points_smg").IntValue, true);
	g_aPriceMap.SetValue("silenced", FindConVar("l4d2_points_silenced").IntValue, true);
	g_aPriceMap.SetValue("silence", FindConVar("l4d2_points_silenced").IntValue, true);
	g_aPriceMap.SetValue("silent", FindConVar("l4d2_points_silenced").IntValue, true);
	g_aItemMap.SetString("sil", "give smg_silenced", true);
	g_aPriceMap.SetValue("mp5", FindConVar("l4d2_points_mp5").IntValue, true);

	// Rifles
	g_aPriceMap.SetValue("m16", FindConVar("l4d2_points_m16").IntValue, true);
	g_aPriceMap.SetValue("scar", FindConVar("l4d2_points_scar").IntValue, true);
	g_aPriceMap.SetValue("desert", FindConVar("l4d2_points_scar").IntValue, true);
	g_aPriceMap.SetValue("ak47", FindConVar("l4d2_points_ak47").IntValue, true);
	g_aPriceMap.SetValue("sg552", FindConVar("l4d2_points_sg552").IntValue, true);
	g_aPriceMap.SetValue("m60", FindConVar("l4d2_points_m60").IntValue, true);

	// Snipers
	g_aPriceMap.SetValue("hunting", FindConVar("l4d2_points_hunting").IntValue, true);
	g_aPriceMap.SetValue("scout", FindConVar("l4d2_points_scout").IntValue, true);
	g_aPriceMap.SetValue("military", FindConVar("l4d2_points_military").IntValue, true);
	g_aPriceMap.SetValue("awp", FindConVar("l4d2_points_awp").IntValue, true);

	// Shotguns
	g_aPriceMap.SetValue("chrome", FindConVar("l4d2_points_chrome").IntValue, true);
	g_aPriceMap.SetValue("pump", FindConVar("l4d2_points_pump").IntValue, true);
	g_aPriceMap.SetValue("spas", FindConVar("l4d2_points_spas").IntValue, true);
	g_aPriceMap.SetValue("auto", FindConVar("l4d2_points_auto").IntValue, true);

	// Throwables
	g_aPriceMap.SetValue("molotov", FindConVar("l4d2_points_molotov").IntValue, true);
	g_aPriceMap.SetValue("mol", FindConVar("l4d2_points_molotov").IntValue, true);
	g_aPriceMap.SetValue("pipe", FindConVar("l4d2_points_pipe").IntValue, true);
	g_aPriceMap.SetValue("bile", FindConVar("l4d2_points_bile").IntValue, true);
	g_aPriceMap.SetValue("puke", FindConVar("l4d2_points_bile").IntValue, true);
	g_aPriceMap.SetValue("vomit", FindConVar("l4d2_points_bile").IntValue, true);

	// Misc
	g_aPriceMap.SetValue("chainsaw", FindConVar("l4d2_points_chainsaw").IntValue, true);
	g_aPriceMap.SetValue("grenade", FindConVar("l4d2_points_grenade").IntValue, true);
	g_aPriceMap.SetValue("gnome", FindConVar("l4d2_points_gnome").IntValue, true);
	g_aPriceMap.SetValue("cola", FindConVar("l4d2_points_cola").IntValue, true);
	g_aPriceMap.SetValue("gas", FindConVar("l4d2_points_gascan").IntValue, true);
	g_aPriceMap.SetValue("propane", FindConVar("l4d2_points_propane").IntValue, true);
	g_aPriceMap.SetValue("fworks", FindConVar("l4d2_points_fireworks").IntValue, true);
	g_aPriceMap.SetValue("oxy", FindConVar("l4d2_points_oxygen").IntValue, true);

	// Upgrades
	g_aPriceMap.SetValue("packex", FindConVar("l4d2_points_explosive_ammo_pack").IntValue, true);
	g_aPriceMap.SetValue("packin", FindConVar("l4d2_points_incendiary_ammo_pack").IntValue, true);
	g_aPriceMap.SetValue("ammo", FindConVar("l4d2_points_refill").IntValue, true);
	g_aPriceMap.SetValue("exammo", FindConVar("l4d2_points_explosive_ammo").IntValue, true);
	g_aPriceMap.SetValue("inammo", FindConVar("l4d2_points_incendiary_ammo").IntValue, true);
	g_aPriceMap.SetValue("laser", FindConVar("l4d2_points_laser").IntValue, true);

	// Melee
	g_aPriceMap.SetValue("baseball_bat", FindConVar("l4d2_points_baseballbat").IntValue, true);
	g_aPriceMap.SetValue("bat", FindConVar("l4d2_points_baseballbat").IntValue, true);
	g_aPriceMap.SetValue("cricket_bat", FindConVar("l4d2_points_cricketbat").IntValue, true);
	g_aPriceMap.SetValue("cricket", FindConVar("l4d2_points_cricketbat").IntValue, true);
	g_aPriceMap.SetValue("cbat", FindConVar("l4d2_points_cricketbat").IntValue, true);
	g_aPriceMap.SetValue("crowbar", FindConVar("l4d2_points_crowbar").IntValue, true);
	g_aPriceMap.SetValue("electric_guitar", FindConVar("l4d2_points_electricguitar").IntValue, true);
	g_aPriceMap.SetValue("guitar", FindConVar("l4d2_points_electricguitar").IntValue, true);
	g_aPriceMap.SetValue("fireaxe", FindConVar("l4d2_points_fireaxe").IntValue, true);
	g_aPriceMap.SetValue("axe", FindConVar("l4d2_points_fireaxe").IntValue, true);
	g_aPriceMap.SetValue("frying_pan", FindConVar("l4d2_points_fryingpan").IntValue, true);
	g_aPriceMap.SetValue("pan", FindConVar("l4d2_points_fryingpan").IntValue, true);
	g_aPriceMap.SetValue("golfclub", FindConVar("l4d2_points_golfclub").IntValue, true);
	g_aPriceMap.SetValue("club", FindConVar("l4d2_points_golfclub").IntValue, true);
	g_aPriceMap.SetValue("katana", FindConVar("l4d2_points_katana").IntValue, true);
	g_aPriceMap.SetValue("ninja", FindConVar("l4d2_points_katana").IntValue, true);
	g_aPriceMap.SetValue("machete", FindConVar("l4d2_points_machete").IntValue, true);
	g_aPriceMap.SetValue("tonfa", FindConVar("l4d2_points_tonfa").IntValue, true);
	g_aPriceMap.SetValue("nightstick", FindConVar("l4d2_points_tonfa").IntValue, true);

	// Infected
	g_aPriceMap.SetValue("kill", FindConVar("l4d2_points_suicide").IntValue, true);
	g_aPriceMap.SetValue("boomer", FindConVar("l4d2_points_boomer").IntValue, true);
	g_aPriceMap.SetValue("smoker", FindConVar("l4d2_points_smoker").IntValue, true);
	g_aPriceMap.SetValue("hunter", FindConVar("l4d2_points_hunter").IntValue, true);
	g_aPriceMap.SetValue("spitter", FindConVar("l4d2_points_spitter").IntValue, true);
	g_aPriceMap.SetValue("jockey", FindConVar("l4d2_points_jockey").IntValue, true);
	g_aPriceMap.SetValue("charger", FindConVar("l4d2_points_charger").IntValue, true);
	g_aPriceMap.SetValue("witch", FindConVar("l4d2_points_witch").IntValue, true);
	g_aPriceMap.SetValue("bride", FindConVar("l4d2_points_witch").IntValue, true);
	g_aPriceMap.SetValue("tank", FindConVar("l4d2_points_tank").IntValue, true);
	g_aPriceMap.SetValue("horde", FindConVar("l4d2_points_horde").IntValue, true);
	g_aPriceMap.SetValue("mob", FindConVar("l4d2_points_mob").IntValue, true);
}

void vPopulateExclusiveItemsMap()
{
	//  Infected Only
	g_aTeamExclusive.SetValue("kill", 3, true);
	g_aTeamExclusive.SetValue("boomer", 3, true);
	g_aTeamExclusive.SetValue("smoker", 3, true);
	g_aTeamExclusive.SetValue("hunter", 3, true);
	g_aTeamExclusive.SetValue("spitter", 3, true);
	g_aTeamExclusive.SetValue("jockey", 3, true);
	g_aTeamExclusive.SetValue("charger", 3, true);
	g_aTeamExclusive.SetValue("witch", 3, true);
	g_aTeamExclusive.SetValue("bride", 3, true);
	g_aTeamExclusive.SetValue("tank", 3, true);
	g_aTeamExclusive.SetValue("horde", 3, true);
	g_aTeamExclusive.SetValue("mob", 3, true);

	// Survivor Only
	g_aTeamExclusive.SetValue("laser", 2, true);
	g_aTeamExclusive.SetValue("packex", 2, true);
	g_aTeamExclusive.SetValue("packin", 2, true);
	g_aTeamExclusive.SetValue("exammo", 2, true);
	g_aTeamExclusive.SetValue("inammo", 2, true);
}

void vBuildMap()
{
	g_aItemMap = new StringMap();
	g_aPriceMap = new StringMap();
	g_aTeamExclusive = new StringMap();

	vPopulateItemMap();
	vPopulatePriceMap();
	vPopulateExclusiveItemsMap();
}

public void OnPluginStart()
{
	g_fMinLibraryVersion = 1.77;

	LoadTranslations("points_system.phrases");

	CreateConVar("em_ps_bess", PLUGIN_VERSION, "PS Bess version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);
	g_hEnabled = CreateConVar("ps_bess_enable", "1", "Enable BESS Module", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bModuleLoaded = false;

	RegConsoleCmd("sm_buy", cmdBuy);
	//AutoExecConfig(true, "ps_bess");
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("ps_natives"))
		SetFailState("[PS] PS Natives are not loaded.");

	if(PS_GetVersion() < g_fMinLibraryVersion)
		SetFailState("[PS] Outdated version of Points System installed.");
	if(!PS_RegisterModule(PS_ModuleName)) // If module registeration has failed
		LogMessage("[PS] Plugin already registered.");
	else
	{
		vBuildMap();
		g_bModuleLoaded = true;
	}
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
	vPopulatePriceMap();
}

bool bIsModuleActive()
{
	return g_bModuleLoaded && g_hEnabled.BoolValue && PS_IsSystemEnabled();
}

bool bIsClientSurvivor(int client)
{
	return client > 0 && GetClientTeam(client) == 2;
}

bool bIsClientInfected(int client)
{
	return client > 0 && GetClientTeam(client) == 3;
}

bool bIsClientTank(int client)
{
	return client > 0 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

bool bCheckDisabled(int iCost)
{
	if(iCost <= -1)
	{
		//PrintToChat(client, "%s %T", MSGTAG, "Item Disabled", client);
		return true;
	}

	return false;
}

bool bCheckPoints(int client, int iCost)
{
	if(PS_GetPoints(client) >= iCost)
		return true;

	PrintToChat(client, "%s %T", MSGTAG, "Insufficient Funds", client);
	return false;
}

bool bHasEnoughPoints(int client, int iCost)
{
	return bCheckPoints(client, iCost);
}

void vRemovePoints(int client, int iPoints)
{
	PS_RemovePoints(client, iPoints);
}

int iGetHealCost(int client)
{
	int iCost = -1;
	if(bIsClientInfected(client))
	{
		iCost = FindConVar("l4d2_points_infected_heal").IntValue;

		if(bIsClientTank(client))
			iCost *= FindConVar("l4d2_points_tank_heal_mult").IntValue;
	}
	else if(bIsClientSurvivor(client))
		iCost = FindConVar("l4d2_points_survivor_heal").IntValue;

	return(iCost);
}

Action cmdBuy(int client, int args)
{
	if(args != 1)
		return Plugin_Continue;

	if(client == 0 || !IsClientInGame(client) || !bIsModuleActive())
		return Plugin_Continue;

	if(!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[PS] Must Be Alive To Buy Items!");
		return Plugin_Continue;
	}

	char sPlayerInput[64];
	char sPurchaseCmd[64];
	GetCmdArg(1, sPlayerInput, sizeof sPlayerInput);

	if(g_aItemMap.GetString(sPlayerInput, sPurchaseCmd, sizeof sPurchaseCmd))
	{ // If an entry exists
		int iRequiredTeam;
		if(g_aTeamExclusive.GetValue(sPlayerInput, iRequiredTeam))
			if(GetClientTeam(client) != iRequiredTeam)
				return Plugin_Continue;

		int iCost = -2; //-2 = invalid
		if(strcmp(sPlayerInput, "cola", false) == 0)
		{
			char sMap[64];
			GetCurrentMap(sMap, sizeof sMap);
			if(strcmp(sMap, "c1m2_streets", false) == 0)
				PrintToChat(client, "[PS] This item is unavailable during this map");
		}
		else if(strcmp(sPlayerInput, "fheal", false) == 0 || strcmp(sPlayerInput, "heal", false) == 0)
		{
			iCost = iGetHealCost(client);
			if(!bCheckDisabled(iCost))
				vPerformHeal(client, iCost);
		}
		else
		{ // If not a special case
			if(g_aPriceMap.GetValue(sPlayerInput, iCost) && !bCheckDisabled(iCost))
			{
				if(strcmp(sPlayerInput, "kill", false) == 0)
					vPerformSuicide(client, iCost);
				else if(GetClientTeam(client) > 1) // If not a spectator
					vPerformPurchase(client, iCost, sPurchaseCmd);
			}
		}
	}
	return Plugin_Continue;
}

void vReloadAmmo(int client, int iCost, const char[] sItem)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0);
	if(iWeapon != -1)
	{
		char sWeapon[40];
		GetEdictClassname(iWeapon, sWeapon, sizeof sWeapon);
		if(strcmp(sWeapon, "weapon_rifle_m60") == 0)
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", 150);
		else if(strcmp(sWeapon, "weapon_grenade_launcher") == 0)
			SetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_iAmmo") + 68, 30);

		vCheatCommand(client, sItem);
		vRemovePoints(client, iCost);
	}
	else
		PrintToChat(client, "%s %T", MSGTAG, "Primary Warning", client);
}

void vSetLastPurchase(int client, int iCost, const char[] sPurchaseCmd)
{ // We are doing this so !repeatbuy works
	PS_SetItem(client, sPurchaseCmd);
	PS_SetCost(client, iCost);
}

void vPerformPurchase(int client, int iCost, const char[] sPurchaseCmd)
{ // sItem[] should be const
	if(iCost >= 0 && bHasEnoughPoints(client, iCost))
	{
		if(strcmp(sPurchaseCmd, "give ammo", false) == 0)
		{
			vReloadAmmo(client, iCost, sPurchaseCmd);
			vSetLastPurchase(client, iCost, sPurchaseCmd);
		}
		else
		{
			vCheatCommand(client, sPurchaseCmd);
			vRemovePoints(client, iCost);
			vSetLastPurchase(client, iCost, sPurchaseCmd);
		}
	}
}

void vPerformHeal(int client, int iCost)
{
	if(iCost >= 0)
	{
		if(bHasEnoughPoints(client, iCost))
		{
			vCheatCommand(client, "give health");
			vRemovePoints(client, iCost);
		}
	}
}

void vPerformSuicide(int client, int iCost)
{
	if(iCost >= 0 && bHasEnoughPoints(client, iCost))
	{
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			ForcePlayerSuicide(client);
			vRemovePoints(client, iCost);	
		}
	}
}

void vCheatCommand(int client, const char[] sCommand)
{
	if(client == 0 || !IsClientInGame(client))
		return;

	char sCmd[32];
	if(SplitString(sCommand, " ", sCmd, sizeof sCmd) == -1)
		strcopy(sCmd, sizeof sCmd, sCommand);

	int bits = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(sCmd);
	SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, sCommand);
	SetCommandFlags(sCmd, flags);
	SetUserFlagBits(client, bits);
	if(sCommand[0] == 'g' && strcmp(sCommand[5], "health") == 0)
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0); //防止有虚血时give health会超过100血
}