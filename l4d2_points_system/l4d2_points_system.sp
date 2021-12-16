#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.9.0"

#define MSGTAG "\x04[PS]\x01"
#define MODULES_SIZE 128

GlobalForward
	g_hForwardOnPSLoaded,
	g_hForwardOnPSUnloaded;

Database
	g_dbSQL;

ArrayList
	g_aModules;

bool
	g_bLateLoad,
	g_bMapStarted,
	g_bSettingAllow;

//汉化@夏恋灬花火碎片 
enum struct esPlayer
{
	char g_sBought[64];
	char g_sCommand[64];
	char g_sSteamId[32];
	
	int g_iItemCost;
	int g_iKillCount;
	int g_iHurtCount;
	int g_iBoughtCost;
	int g_iProtectCount;
	int g_iHeadShotCount;
	int g_iPlayerPoints;
	int g_iLeechHealth;

	bool g_bDataLoaded;

	float g_fRealodSpeedUp;
}

esPlayer
	g_esPlayer[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Points System",
	author = "McFlurry & evilmaniac and modified by Psykotik",
	description = "Customized edition of McFlurry's points system",
	version = PLUGIN_VERSION,
	url = "http://www.evilmania.net"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	vCreateNatives();
	MarkNativeAsOptional("CZ_SetSpawnablePZ");
	MarkNativeAsOptional("CZ_ResetSpawnablePZ");
	MarkNativeAsOptional("CZ_IsSpawnablePZSupported");

	g_bLateLoad = late;
	return APLRes_Success;
}

void vCreateNatives()
{
	CreateNative("PS_IsSystemEnabled", aNative_PS_IsSystemEnabled);
	CreateNative("PS_GetVersion", aNative_PS_GetVersion);
	CreateNative("PS_GetPoints", aNative_PS_GetPoints);
	CreateNative("PS_SetPoints", aNative_PS_SetPoints);
	CreateNative("PS_RemovePoints", aNative_PS_RemovePoints);
	CreateNative("PS_GetItem", aNative_PS_GetItem);
	CreateNative("PS_SetItem", aNative_PS_SetItem);
	CreateNative("PS_GetCost", aNative_PS_GetCost);
	CreateNative("PS_SetCost", aNative_PS_SetCost);
	CreateNative("PS_GetBought", aNative_PS_GetBought);
	CreateNative("PS_SetBought", aNative_PS_SetBought);
	CreateNative("PS_GetBoughtCost", aNative_PS_GetBoughtCost);
	CreateNative("PS_SetBoughtCost", aNative_PS_SetBoughtCost);
	CreateNative("PS_RegisterModule", aNative_PS_RegisterModule);
	CreateNative("PS_UnregisterModule", aNative_PS_UnregisterModule);

	RegPluginLibrary("ps_natives");
}

public void OnAllPluginsLoaded()
{
	Call_StartForward(g_hForwardOnPSLoaded);
	Call_Finish();
}

public void OnPluginEnd()
{
	vSQL_SaveAll();
	vMultiTargetFilters(false);

	Call_StartForward(g_hForwardOnPSUnloaded);
	Call_Finish();
}

void vSQL_SaveAll()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
			vSQL_Save(i);
	}
}

any aNative_PS_IsSystemEnabled(Handle plugin, int numParams)
{
	return bIsModEnabled();
}

any aNative_PS_GetVersion(Handle plugin, int numParams)
{
	return StringToFloat(PLUGIN_VERSION);
}

any aNative_PS_GetPoints(Handle plugin, int numParams)
{
	return g_esPlayer[GetNativeCell(1)].g_iPlayerPoints;
}

any aNative_PS_SetPoints(Handle plugin, int numParams)
{
	g_esPlayer[GetNativeCell(1)].g_iPlayerPoints = GetNativeCell(2);
	return 0;
}

any aNative_PS_RemovePoints(Handle plugin, int numParams)
{
	vRemovePoints(GetNativeCell(1), GetNativeCell(2));
	return 0;
}

any aNative_PS_GetItem(Handle plugin, int numParams)
{
	SetNativeString(2, g_esPlayer[GetNativeCell(1)].g_sCommand, GetNativeCell(3));
	return 0;
}

any aNative_PS_SetItem(Handle plugin, int numParams)
{
	GetNativeString(2, g_esPlayer[GetNativeCell(1)].g_sCommand, sizeof(esPlayer::g_sCommand));
	return 0;
}

any aNative_PS_GetCost(Handle plugin, int numParams)
{
	return g_esPlayer[GetNativeCell(1)].g_iItemCost;
}

any aNative_PS_SetCost(Handle plugin, int numParams)
{
	g_esPlayer[GetNativeCell(1)].g_iItemCost = GetNativeCell(2);
	return 0;
}

any aNative_PS_GetBought(Handle plugin, int numParams)
{
	SetNativeString(2, g_esPlayer[GetNativeCell(1)].g_sBought, sizeof(esPlayer::g_sBought));
	return 0;
}

any aNative_PS_SetBought(Handle plugin, int numParams)
{
	GetNativeString(2, g_esPlayer[GetNativeCell(1)].g_sBought, sizeof(esPlayer::g_sBought));
	return 0;
}

any aNative_PS_GetBoughtCost(Handle plugin, int numParams)
{
	return g_esPlayer[GetNativeCell(1)].g_iBoughtCost;
}

any aNative_PS_SetBoughtCost(Handle plugin, int numParams)
{
	g_esPlayer[GetNativeCell(1)].g_iBoughtCost = GetNativeCell(2);
	return 0;
}

any aNative_PS_RegisterModule(Handle plugin, int numParams)
{
	char sNewModule[MODULES_SIZE];
	GetNativeString(1, sNewModule, MODULES_SIZE);

	if(sNewModule[0] == '\0')
		return false;

	if(g_aModules.FindString(sNewModule) != -1)
		return false;

	g_aModules.PushString(sNewModule);
	return true;
}

any aNative_PS_UnregisterModule(Handle plugin, int numParams)
{
	char sUnloadModule[MODULES_SIZE];
	GetNativeString(1, sUnloadModule, MODULES_SIZE);

	if(sUnloadModule[0] == '\0')
		return false;

	int iModule = g_aModules.FindString(sUnloadModule);
	if(iModule != -1)
	{
		g_aModules.Erase(iModule);
		return true;
	}
	return false;
}

bool g_bControlZombies;
bool g_bWeaponHandling;
native void CZ_SetSpawnablePZ(int client);
native void CZ_ResetSpawnablePZ();
native bool CZ_IsSpawnablePZSupported();

public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "control_zombies") == 0)
		g_bControlZombies = true;
	else if(strcmp(name, "WeaponHandling") == 0)
		g_bWeaponHandling = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if(strcmp(name, "control_zombies") == 0)
		g_bControlZombies = false;
	else if(strcmp(name, "WeaponHandling") == 0)
		g_bWeaponHandling = false;
}

enum
{
	cSettingAllow,
	cSettingModes,
	cSettingModesOff,
	cSettingModesTog,
	cSettingNotifications,
	cSettingKillSpreeNum,
	cSettingHeadShotNum,
	cSettingTankLimit,
	cSettingWitchLimit,
	cSettingStartPoints,
	cSettingTraitorLimit,
	cSettingMax
}

enum
{
	cCategoryWeapon,
	cCategoryHealth,
	cCategoryUpgrade,
	cCategoryTraitor,
	cCategorySpecial,
	cCategoryMelee,
	cCategoryRifle,
	cCategorySMG,
	cCategorySniper,
	cCategoryShotgun,
	cCategoryThrowable,
	cCategoryMisc,
	cCategoryMax
}

enum
{
	cRewardSKillSpree,
	cRewardSHeadShots,
	cRewardSKillI,
	cRewardSKillTank,
	cRewardSKillWitch,
	cRewardSCrownWitch,
	cRewardSTeamHeal,
	cRewardSHealFarm,
	cRewardSProtect,
	cRewardSTeamRevive,
	cRewardSTeamLedge,
	cRewardSTeamDefib,
	cRewardSBileTank,
	cRewardSSoloTank,
	cRewardIChokeS,
	cRewardIPounceS,
	cRewardIChargeS,
	cRewardIImpactS,
	cRewardIRideS,
	cRewardIVomitS,
	cRewardIIncapS,
	cRewardIHurtS,
	cRewardIKillS,
	cRewardMax
}

enum
{
	cCostP220,
	cCostMagnum,
	cCostUZI,
	cCostSilenced,
	cCostMP5,
	cCostM16,
	cCostAK47,
	cCostSCAR,
	cCostSG552,
	cCostHunting,
	cCostMilitary,
	cCostAWP,
	cCostScout,
	cCostPump,
	cCostChrome,
	cCostAuto,
	cCostSPAS,
	cCostGrenade,
	cCostM60,
	cCostGasCan,
	cCostOxygen,
	cCostPropane,
	cCostGnome,
	cCostCola,
	cCostFireworks,
	cCostFireaxe,
	cCostFryingpan,
	cCostMachete,
	cCostBaseballbat,
	cCostCrowbar,
	cCostCricketbat,
	cCostTonfa,
	cCostKatana,
	cCostElectricguitar,
	cCostKnife,
	cCostGolfclub,
	cCostShovel,
	cCostPitchfork,
	cCostCustomMelee,
	cCostChainsaw,
	cCostPipe,
	cCostMolotov,
	cCostBile,
	cCostHealthKit,
	cCostDefib,
	cCostAdren,
	cCostPills,
	cCostExplosiveAmmo,
	cCostIncendiaryAmmo,
	cCostExplosivePack,
	cCostIncendiaryPack,
	cCostLaserSight,
	cCostAmmo,
	cCostHeal,
	cCostSuicide,
	cCostPZHeal,
	cCostSmoker,
	cCostBoomer,
	cCostHunter,
	cCostSpitter,
	cCostJockey,
	cCostCharger,
	cCostWitch,
	cCostTank,
	cCostTankHealMulti,
	cCostHorde,
	cCostMob,
	cCostTraitor,
	cCostMax
}

enum
{
	iTankSpawned,
	iWitchSpawned
}

enum struct esGeneral
{
	ConVar g_cGameMode;
	ConVar g_cSettings[cSettingMax];
	ConVar g_cCategories[cCategoryMax];
	ConVar g_cItemCosts[cCostMax];
	ConVar g_cPointRewards[cRewardMax];

	int g_iCounter[2];
	int g_iClipSize[2];

	char g_sCurrentMap[64];
}

esGeneral
	g_esGeneral;

enum struct esSpecial
{
	ConVar g_cLeechHealth[5];
	ConVar g_cRealodSpeedUp[5];
}

esSpecial
	g_esSpecial;


int g_iMeleeClassCount;
char g_sMeleeClass[16][32];

static const char
	g_sMeleeModels[][] =
	{
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl"
	},
	g_sMeleeName[][] =
	{
		"fireaxe",			//斧头
		"frying_pan",		//平底锅
		"machete",			//砍刀
		"baseball_bat",		//棒球棒
		"crowbar",			//撬棍
		"cricket_bat",		//球拍
		"tonfa",			//警棍
		"katana",			//武士刀
		"electric_guitar",	//吉他
		"knife",			//小刀
		"golfclub",			//高尔夫球棍
		"shovel",			//铁铲
		"pitchfork",		//草叉
	};

void vInitSettings()
{
	CreateConVar("em_points_sys_version", PLUGIN_VERSION, "该服务器上的积分系统版本.", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);

	g_esGeneral.g_cSettings[cSettingAllow] 			= CreateConVar("l4d2_points_allow", "1", "0=Plugin off, 1=Plugin on.");
	g_esGeneral.g_cSettings[cSettingModes] 			= CreateConVar("l4d2_points_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).");
	g_esGeneral.g_cSettings[cSettingModesOff] 		= CreateConVar("l4d2_points_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).");
	g_esGeneral.g_cSettings[cSettingModesTog] 		= CreateConVar("l4d2_points_modes_tog", "0", "Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.");
	g_esGeneral.g_cSettings[cSettingStartPoints]	= CreateConVar("l4d2_points_start", "10", "玩家初始积分");
	g_esGeneral.g_cSettings[cSettingNotifications]	= CreateConVar("l4d2_points_notify", "0", "开关提示信息?");
	g_esGeneral.g_cSettings[cSettingTankLimit] 		= CreateConVar("l4d2_points_tank_limit", "1", "每回合允许产生多少只坦克");
	g_esGeneral.g_cSettings[cSettingWitchLimit]		= CreateConVar("l4d2_points_witch_limit", "5", "每回合允许产生多少只女巫");
	g_esGeneral.g_cSettings[cSettingKillSpreeNum] 	= CreateConVar("l4d2_points_cikills", "15", "你需要杀多少普通感染者才能获得杀戮赏金");
	g_esGeneral.g_cSettings[cSettingHeadShotNum] 	= CreateConVar("l4d2_points_headshots", "15", "你需要多少次爆头感染者才能获得猎头奖金");
	g_esGeneral.g_cSettings[cSettingTraitorLimit] 	= CreateConVar("l4d2_points_traitor_limit", "2", "允许同时存在多少个被感染者玩家");

	g_esGeneral.g_cGameMode = FindConVar("mp_gamemode");
	g_esGeneral.g_cGameMode.AddChangeHook(vAllowConVarChanged);
	g_esGeneral.g_cSettings[cSettingAllow].AddChangeHook(vAllowConVarChanged);
	g_esGeneral.g_cSettings[cSettingModes].AddChangeHook(vAllowConVarChanged);
	g_esGeneral.g_cSettings[cSettingModesOff].AddChangeHook(vAllowConVarChanged);
	g_esGeneral.g_cSettings[cSettingModesTog].AddChangeHook(vAllowConVarChanged);
}

void vInitCategories()
{
	g_esGeneral.g_cCategories[cCategoryWeapon] 		= CreateConVar("l4d2_points_cat_weapons", "1", "启用武器项目购买");
	g_esGeneral.g_cCategories[cCategoryUpgrade] 	= CreateConVar("l4d2_points_cat_upgrades", "1", "启用升级项目购买");
	g_esGeneral.g_cCategories[cCategoryHealth] 		= CreateConVar("l4d2_points_cat_health", "1", "启用生命项目购买");
	g_esGeneral.g_cCategories[cCategoryTraitor]		= CreateConVar("l4d2_points_cat_traitor", "1", "启用内鬼项目购买");
	g_esGeneral.g_cCategories[cCategorySpecial] 	= CreateConVar("l4d2_points_cat_special", "1", "启用特殊项目购买");
	g_esGeneral.g_cCategories[cCategoryMelee]		= CreateConVar("l4d2_points_cat_melee", "1", "启用近战项目购买");
	g_esGeneral.g_cCategories[cCategoryRifle] 		= CreateConVar("l4d2_points_cat_rifles", "1", "启用步枪项目购买");
	g_esGeneral.g_cCategories[cCategorySMG] 		= CreateConVar("l4d2_points_cat_smg", "1", "启用冲锋项目购买");
	g_esGeneral.g_cCategories[cCategorySniper] 		= CreateConVar("l4d2_points_cat_snipers", "1", "启用狙击项目购买");
	g_esGeneral.g_cCategories[cCategoryShotgun] 	= CreateConVar("l4d2_points_cat_shotguns", "1", "启动散弹项目购买");
	g_esGeneral.g_cCategories[cCategoryThrowable]	= CreateConVar("l4d2_points_cat_throwables", "1", "启用投掷项目购买");
	g_esGeneral.g_cCategories[cCategoryMisc] 		= CreateConVar("l4d2_points_cat_misc", "1", "启用杂项项目购买");
}

void vInitItemCosts()
{
	g_esGeneral.g_cItemCosts[cCostP220]				= CreateConVar("l4d2_points_pistol", "5", "购买小手枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostMagnum] 			= CreateConVar("l4d2_points_magnum", "10", "购买马格南手枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostUZI] 				= CreateConVar("l4d2_points_smg", "10", "购买乌兹冲锋枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostSilenced] 		= CreateConVar("l4d2_points_silenced", "10", "购买消音冲锋枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostMP5] 				= CreateConVar("l4d2_points_mp5", "10", "购买MP5冲锋枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostM16] 				= CreateConVar("l4d2_points_m16", "30", "购买M16突击步枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostAK47] 			= CreateConVar("l4d2_points_ak47", "30", "购买AK47突击步枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostSCAR] 			= CreateConVar("l4d2_points_scar", "30", "购买SCAR-H突击步枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostSG552] 			= CreateConVar("l4d2_points_sg552", "30", "购买SG552突击步枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostMilitary] 		= CreateConVar("l4d2_points_military", "50", "购买30发连发狙击枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostAWP] 				= CreateConVar("l4d2_points_awp", "500", "购买awp狙击枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostScout] 			= CreateConVar("l4d2_points_scout", "50", "购买侦察狙击步枪(鸟狙)需要多少积分");
	g_esGeneral.g_cItemCosts[cCostHunting] 			= CreateConVar("l4d2_points_hunting", "50", "购买狩猎狙击步枪(猎枪)需要多少积分");
	g_esGeneral.g_cItemCosts[cCostPump] 			= CreateConVar("l4d2_points_pump", "10", "购买一代木喷需要多少积分");
	g_esGeneral.g_cItemCosts[cCostChrome] 			= CreateConVar("l4d2_points_chrome", "10", "购买二代铁喷需要多少积分");
	g_esGeneral.g_cItemCosts[cCostAuto] 			= CreateConVar("l4d2_points_auto", "30", "购买一代连喷需要多少积分");
	g_esGeneral.g_cItemCosts[cCostSPAS] 			= CreateConVar("l4d2_points_spas", "30", "购买二代连喷需要多少积分");
	g_esGeneral.g_cItemCosts[cCostGrenade] 			= CreateConVar("l4d2_points_grenade", "500", "购买榴弹发射器需要多少积分");
	g_esGeneral.g_cItemCosts[cCostM60] 				= CreateConVar("l4d2_points_m60", "200", "购买M60机枪需要多少积分");
	g_esGeneral.g_cItemCosts[cCostGasCan] 			= CreateConVar("l4d2_points_gascan", "100", "购买汽油桶需要多少积分");
	g_esGeneral.g_cItemCosts[cCostOxygen] 			= CreateConVar("l4d2_points_oxygen", "100", "购买氧气罐需要多少积分");
	g_esGeneral.g_cItemCosts[cCostPropane] 			= CreateConVar("l4d2_points_propane", "100", "购买燃气罐需要多少积分");
	g_esGeneral.g_cItemCosts[cCostGnome] 			= CreateConVar("l4d2_points_gnome", "15", "购买侏儒人偶需要多少积分");
	g_esGeneral.g_cItemCosts[cCostCola] 			= CreateConVar("l4d2_points_cola", "100", "购买可乐瓶需要多少积分");
	g_esGeneral.g_cItemCosts[cCostFireworks] 		= CreateConVar("l4d2_points_fireworks", "100", "购买烟花盒需要多少积分");
	g_esGeneral.g_cItemCosts[cCostFireaxe] 			= CreateConVar("l4d2_points_fireaxe", "15", "购买消防斧需要多少积分");
	g_esGeneral.g_cItemCosts[cCostFryingpan]		= CreateConVar("l4d2_points_fryingpan", "10", "购买平底锅需要多少积分");
	g_esGeneral.g_cItemCosts[cCostMachete] 			= CreateConVar("l4d2_points_machete", "15", "购买小砍刀需要多少积分");
	g_esGeneral.g_cItemCosts[cCostBaseballbat] 		= CreateConVar("l4d2_points_baseballbat", "10", "购买棒球棒需要多少积分");
	g_esGeneral.g_cItemCosts[cCostCrowbar] 			= CreateConVar("l4d2_points_crowbar", "15", "购买撬棍需要多少积分");
	g_esGeneral.g_cItemCosts[cCostCricketbat] 		= CreateConVar("l4d2_points_cricketbat", "10", "购买板球棒需要多少积分");
	g_esGeneral.g_cItemCosts[cCostTonfa] 			= CreateConVar("l4d2_points_tonfa", "10", "购买警棍需要多少积分");
	g_esGeneral.g_cItemCosts[cCostKatana] 			= CreateConVar("l4d2_points_katana", "15", "购买武士刀需要多少积分");
	g_esGeneral.g_cItemCosts[cCostElectricguitar]	= CreateConVar("l4d2_points_electricguitar", "10", "购买电吉他需要多少积分");
	g_esGeneral.g_cItemCosts[cCostKnife] 			= CreateConVar("l4d2_points_knife", "15", "购买小刀需要多少积分");
	g_esGeneral.g_cItemCosts[cCostGolfclub] 		= CreateConVar("l4d2_points_golfclub", "10", "购买高尔夫球棍需要多少积分");
	g_esGeneral.g_cItemCosts[cCostShovel] 			= CreateConVar("l4d2_points_shovel", "10", "购买铁铲需要多少积分");
	g_esGeneral.g_cItemCosts[cCostPitchfork] 		= CreateConVar("l4d2_points_pitchfork", "10", "购买干草叉需要多少积分");
	g_esGeneral.g_cItemCosts[cCostCustomMelee] 		= CreateConVar("l4d2_points_custommelee", "50", "购买自定义近战需要多少积分");
	g_esGeneral.g_cItemCosts[cCostChainsaw] 		= CreateConVar("l4d2_points_chainsaw", "10", "购买电锯需要多少积分");
	g_esGeneral.g_cItemCosts[cCostPipe] 			= CreateConVar("l4d2_points_pipe", "10", "购买土制炸弹需要多少积分");
	g_esGeneral.g_cItemCosts[cCostMolotov] 			= CreateConVar("l4d2_points_molotov", "100", "购买燃烧瓶需要多少积分");
	g_esGeneral.g_cItemCosts[cCostBile] 			= CreateConVar("l4d2_points_bile", "10", "购买胆汁需要多少积分");
	g_esGeneral.g_cItemCosts[cCostHealthKit]		= CreateConVar("l4d2_points_medkit", "80", "购买医疗包需要多少积分");
	g_esGeneral.g_cItemCosts[cCostDefib] 			= CreateConVar("l4d2_points_defib", "30", "购买电击器需要多少积分");
	g_esGeneral.g_cItemCosts[cCostAdren] 			= CreateConVar("l4d2_points_adrenaline", "30", "购买肾上腺素需要多少积分");
	g_esGeneral.g_cItemCosts[cCostPills] 			= CreateConVar("l4d2_points_pills", "30", "购买止痛药需要多少积分");
	g_esGeneral.g_cItemCosts[cCostExplosiveAmmo] 	= CreateConVar("l4d2_points_explosive_ammo", "15", "购买高爆弹药需要多少积分");
	g_esGeneral.g_cItemCosts[cCostIncendiaryAmmo] 	= CreateConVar("l4d2_points_incendiary_ammo", "15", "购买燃烧弹药需要多少积分");
	g_esGeneral.g_cItemCosts[cCostExplosivePack] 	= CreateConVar("l4d2_points_explosive_ammo_pack", "15", "购买高爆弹药包需要多少积分");
	g_esGeneral.g_cItemCosts[cCostIncendiaryPack] 	= CreateConVar("l4d2_points_incendiary_ammo_pack", "15", "购买燃烧弹药包需要多少积分");
	g_esGeneral.g_cItemCosts[cCostLaserSight] 		= CreateConVar("l4d2_points_laser", "10", "购买激光瞄准器需要多少积分");
	g_esGeneral.g_cItemCosts[cCostHeal] 			= CreateConVar("l4d2_points_survivor_heal", "100", "购买回满血量需要多少积分");
	g_esGeneral.g_cItemCosts[cCostAmmo] 			= CreateConVar("l4d2_points_refill", "10", "购买弹药补充需要多少积分");
	g_esGeneral.g_cItemCosts[cCostSuicide] 			= CreateConVar("l4d2_points_suicide", "5", "特感玩家购买自杀需要多少积分");
	g_esGeneral.g_cItemCosts[cCostPZHeal] 			= CreateConVar("l4d2_points_infected_heal", "100", "感染者治愈自己需要多少积分");
	g_esGeneral.g_cItemCosts[cCostSmoker] 			= CreateConVar("l4d2_points_smoker", "50", "购买一次成为smoker的机会需要多少积分");
	g_esGeneral.g_cItemCosts[cCostBoomer] 			= CreateConVar("l4d2_points_boomer", "50", "购买一次成为boomer的机会需要多少积分");
	g_esGeneral.g_cItemCosts[cCostHunter]			= CreateConVar("l4d2_points_hunter", "50", "购买一次成为hunter的机会需要多少积分");
	g_esGeneral.g_cItemCosts[cCostSpitter] 			= CreateConVar("l4d2_points_spitter", "50", "购买一次成为spitter的机会需要多少积分");
	g_esGeneral.g_cItemCosts[cCostJockey] 			= CreateConVar("l4d2_points_jockey", "50", "购买一次成为jockey的机会需要多少积分");
	g_esGeneral.g_cItemCosts[cCostCharger] 			= CreateConVar("l4d2_points_charger", "100", "购买一次成为charger的机会需要多少积分");
	g_esGeneral.g_cItemCosts[cCostWitch] 			= CreateConVar("l4d2_points_witch", "1000", "购买一次witch需要多少积分");
	g_esGeneral.g_cItemCosts[cCostTank] 			= CreateConVar("l4d2_points_tank", "2000", "购买一次成为tank的机会需要多少积分");
	g_esGeneral.g_cItemCosts[cCostTankHealMulti] 	= CreateConVar("l4d2_points_tank_heal_mult", "5", "坦克玩家购买治愈相对于其他特感需要多少倍的积分消耗");
	g_esGeneral.g_cItemCosts[cCostHorde] 			= CreateConVar("l4d2_points_horde", "200", "购买一次horde需要多少积分");
	g_esGeneral.g_cItemCosts[cCostMob] 				= CreateConVar("l4d2_points_mob", "200", "购买一次mob需要多少积分");
	g_esGeneral.g_cItemCosts[cCostTraitor] 			= CreateConVar("l4d2_points_traitor", "50", "购买一个感染者位置需要多少积分");
}

void vInitPointRewards()
{
	g_esGeneral.g_cPointRewards[cRewardSKillSpree] 	= CreateConVar("l4d2_points_cikill_value", "3", "击杀一定数量的普通感染者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSHeadShots]	= CreateConVar("l4d2_points_headshots_value", "5", "爆头击杀一定数量的感染者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSKillI] 		= CreateConVar("l4d2_points_sikill", "1", "击杀一个特感可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSKillTank] 	= CreateConVar("l4d2_points_tankkill", "5", "击杀一只坦克可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSKillWitch] 	= CreateConVar("l4d2_points_witchkill", "2", "击杀一个女巫可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSCrownWitch] = CreateConVar("l4d2_points_witchcrown", "5", "秒杀一个女巫可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSTeamHeal] 	= CreateConVar("l4d2_points_heal", "2", "治疗一个队友可以得到多少积分");
	g_esGeneral.g_cPointRewards[cRewardSHealFarm] 	= CreateConVar("l4d2_points_heal_warning", "0", "治疗一个不需要治疗的队友可以得到多少积分");
	g_esGeneral.g_cPointRewards[cRewardSProtect] 	= CreateConVar("l4d2_points_protect", "1", "保护队友可以得到多少积分");
	g_esGeneral.g_cPointRewards[cRewardSTeamRevive] = CreateConVar("l4d2_points_revive", "1", "拉起一个倒地的队友可以得到多少积分");
	g_esGeneral.g_cPointRewards[cRewardSTeamLedge] 	= CreateConVar("l4d2_points_ledge", "1", "拉起一个挂边的队友可以得到多少积分");
	g_esGeneral.g_cPointRewards[cRewardSTeamDefib] 	= CreateConVar("l4d2_points_defib_action", "2", "电击器复活一个队友可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSSoloTank] 	= CreateConVar("l4d2_points_tanksolo", "5", "单独击杀一只坦克可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardSBileTank] 	= CreateConVar("l4d2_points_bile_tank", "1", "投掷胆汁命中坦克可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIChokeS] 	= CreateConVar("l4d2_points_smoke", "1", "smoker舌头拉住生还者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIPounceS] 	= CreateConVar("l4d2_points_pounce", "1", "hunter扑倒生还者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIChargeS] 	= CreateConVar("l4d2_points_charge", "1", "charge冲撞生还者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIImpactS] 	= CreateConVar("l4d2_points_impact", "1", "spitter吐痰生还者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIRideS] 		= CreateConVar("l4d2_points_ride", "1", "jokey骑乘生还者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIVomitS] 	= CreateConVar("l4d2_points_boom", "1", "boomer喷吐生还者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIIncapS] 	= CreateConVar("l4d2_points_incap", "3", "击倒一个生还者可以获得多少积分");
	g_esGeneral.g_cPointRewards[cRewardIHurtS] 		= CreateConVar("l4d2_points_damage", "1", "造成伤害能得到多少积分");
	g_esGeneral.g_cPointRewards[cRewardIKillS] 		= CreateConVar("l4d2_points_kill", "5", "击杀一个生还者可以获得多少积分");
}

void vInitSpecialCosts()
{
	g_esSpecial.g_cLeechHealth[0] 					= CreateConVar("l4d2_points_special_leech0", "10", "购买1生命汲取需要多少积分");
	g_esSpecial.g_cLeechHealth[1] 					= CreateConVar("l4d2_points_special_leech1", "30", "购买2生命汲取需要多少积分");
	g_esSpecial.g_cLeechHealth[2] 					= CreateConVar("l4d2_points_special_leech2", "70", "购买3生命汲取需要多少积分");
	g_esSpecial.g_cLeechHealth[3] 					= CreateConVar("l4d2_points_special_leech3", "130", "购买4生命汲取需要多少积分");
	g_esSpecial.g_cLeechHealth[4] 					= CreateConVar("l4d2_points_special_leech4", "210", "购买5生命汲取需要多少积分");
	g_esSpecial.g_cRealodSpeedUp[0] 				= CreateConVar("l4d2_points_special_reload0", "30", "购买1.5x加速装填需要多少积分");
	g_esSpecial.g_cRealodSpeedUp[1] 				= CreateConVar("l4d2_points_special_reload1", "80", "购买2.0x加速装填需要多少积分");
	g_esSpecial.g_cRealodSpeedUp[2] 				= CreateConVar("l4d2_points_special_reload2", "150", "购买2.5x加速装填需要多少积分");
	g_esSpecial.g_cRealodSpeedUp[3] 				= CreateConVar("l4d2_points_special_reload3", "240", "购买3.0x加速装填需要多少积分");
	g_esSpecial.g_cRealodSpeedUp[4] 				= CreateConVar("l4d2_points_special_reload4", "350", "购买3.5x加速装填需要多少积分");
}

void vCreateConVars()
{
	vInitSettings();
	vInitCategories();
	vInitItemCosts();
	vInitPointRewards();
	vInitSpecialCosts();
}

void vRegisterCommands()
{
	RegAdminCmd("sm_heal", cmdHealPlayer, ADMFLAG_SLAY, "sm_heal <目标>给玩家XXX回血");
	RegAdminCmd("sm_delold",	cmdDelOld,	ADMFLAG_ROOT, "sm_delold <天数> 删除超过多少天未上线的玩家记录");
	RegAdminCmd("sm_listpoints", cmdListPoints, ADMFLAG_ROOT, "列出每个玩家的积分数量.");
	RegAdminCmd("sm_setpoints", cmdSetPoints, ADMFLAG_ROOT, "sm_setpoints <目标> [数量]设置玩家XXX拥有XXX数量的积分");
	RegAdminCmd("sm_givepoints", cmdGivePoints, ADMFLAG_ROOT, "sm_givepoints <目标> [数量]给玩家XXX发XXX数量的积分");
	RegAdminCmd("sm_listmodules", cmdListModules, ADMFLAG_GENERIC, "列出当前加载到积分系统的模块");

	RegConsoleCmd("sm_points", cmdShowPoints, "显示个人积分(只能在游戏中)");
	RegConsoleCmd("sm_buy", cmdBuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_shop", cmdBuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_store", cmdBuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_repeatbuy", cmdRepeatBuy, "重复购买上一次购买的物品");
}

void vHookEvents(bool bToggle)
{
	switch(bToggle)
	{
		case true:
		{
			HookEvent("round_end", Event_RoundEnd);
			HookEvent("infected_death", Event_InfectedDeath);
			HookEvent("player_incapacitated", Event_PlayerIncapacitated);
			HookEvent("player_death", Event_PlayerDeath);
			HookEvent("tank_killed", Event_TankKilled);
			HookEvent("witch_killed", Event_WitchKilled);
			HookEvent("heal_success", Event_HealSuccess);
			HookEvent("award_earned", Event_AwardEarned);
			HookEvent("revive_success", Event_ReviveSuccess);
			HookEvent("defibrillator_used", Event_DefibrillatorUsed);
			HookEvent("choke_start", Event_ChokeStart);
			HookEvent("player_now_it", Event_PlayerNowIt);
			HookEvent("lunge_pounce", Event_LungePounce);
			HookEvent("jockey_ride", Event_JockeyRide);
			HookEvent("charger_carry_start", Event_ChargerCarryStart);
			HookEvent("charger_impact", Event_ChargerImpact);
			HookEvent("player_hurt", Event_PlayerHurt);
		}
		case false:
		{
			UnhookEvent("round_end", Event_RoundEnd);
			UnhookEvent("infected_death", Event_InfectedDeath);
			UnhookEvent("player_incapacitated", Event_PlayerIncapacitated);
			UnhookEvent("player_death", Event_PlayerDeath);
			UnhookEvent("tank_killed", Event_TankKilled);
			UnhookEvent("witch_killed", Event_WitchKilled);
			UnhookEvent("heal_success", Event_HealSuccess);
			UnhookEvent("award_earned", Event_AwardEarned);
			UnhookEvent("revive_success", Event_ReviveSuccess);
			UnhookEvent("defibrillator_used", Event_DefibrillatorUsed);
			UnhookEvent("choke_start", Event_ChokeStart);
			UnhookEvent("player_now_it", Event_PlayerNowIt);
			UnhookEvent("lunge_pounce", Event_LungePounce);
			UnhookEvent("jockey_ride", Event_JockeyRide);
			UnhookEvent("charger_carry_start", Event_ChargerCarryStart);
			UnhookEvent("charger_impact", Event_ChargerImpact);
			UnhookEvent("player_hurt", Event_PlayerHurt);
		}
	}
	
}

void vLoadTranslations()
{
	LoadTranslations("core.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("points_system.phrases");
	LoadTranslations("points_system_menus.phrases");
}

public void OnPluginStart()
{
	g_aModules = new ArrayList(64);
	g_hForwardOnPSLoaded = new GlobalForward("OnPSLoaded", ET_Ignore);
	g_hForwardOnPSUnloaded = new GlobalForward("OnPSUnloaded", ET_Ignore);

	vLoadTranslations();
	vCreateConVars();
	vIsAllowed();
	vRegisterCommands();
	vInitSpecialValue();

	if(g_dbSQL == null)
		vIniSQLite();

	if(g_bLateLoad)
		vSQL_LoadAll();
}

void vSQL_LoadAll()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			vSQL_Load(i);
			vSetPlayerStartPoints(i);
		}
	}
}

void vMultiTargetFilters(bool bToggle)
{
	switch(bToggle)
	{
		case true:
		{
			AddMultiTargetFilter("@s", bSurvivorFilter, "all Survivor", false);
			AddMultiTargetFilter("@survivor", bSurvivorFilter, "all Survivor", false);
			AddMultiTargetFilter("@i", bInfectedFilter, "all Infected", false);
			AddMultiTargetFilter("@infected", bInfectedFilter, "all Infected", false);
		}
		case false:
		{
			RemoveMultiTargetFilter("@s", bSurvivorFilter);
			RemoveMultiTargetFilter("@survivor", bSurvivorFilter);
			RemoveMultiTargetFilter("@i", bInfectedFilter);
			RemoveMultiTargetFilter("@infected", bInfectedFilter);
		}
	}
}

bool bSurvivorFilter(const char[] pattern, Handle clients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
			PushArrayCell(clients, i);
	}
	return true;
}

bool bInfectedFilter(const char[] pattern, Handle clients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3)
			PushArrayCell(clients, i);
	}
	return true;
}

public void OnConfigsExecuted()
{
	vIsAllowed();
}

void vAllowConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vIsAllowed()
{
	bool bAllow = g_esGeneral.g_cSettings[cSettingAllow].BoolValue;
	bool bAllowMode = bIsAllowedGameMode();

	if(g_bSettingAllow == false && bAllow == true && bAllowMode == true)
	{
		g_bSettingAllow = true;

		vMultiTargetFilters(true);
		vHookEvents(true);
	}
	else if(g_bSettingAllow == true && (bAllow == false || bAllowMode == false))
	{
		g_bSettingAllow = false;

		vMultiTargetFilters(false);
		vHookEvents(false);
	}
}

int g_iCurrentMode;
bool bIsAllowedGameMode()
{
	if(g_esGeneral.g_cGameMode == null)
		return false;

	int iModesTog = g_esGeneral.g_cSettings[cSettingModesTog].IntValue;
	if(iModesTog != 0)
	{
		if(g_bMapStarted == false)
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if(IsValidEntity(entity))
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", vOnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", vOnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", vOnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", vOnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if(IsValidEntity(entity)) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity);// Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if(g_iCurrentMode == 0)
			return false;

		if(!(iModesTog & g_iCurrentMode))
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_esGeneral.g_cGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_esGeneral.g_cSettings[cSettingModes].GetString(sGameModes, sizeof(sGameModes));
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}

	g_esGeneral.g_cSettings[cSettingModesOff].GetString(sGameModes, sizeof(sGameModes));
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

void vOnGamemode(const char[] output, int caller, int activator, float delay)
{
	if(strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if(strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if(strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if(strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

void vIniSQLite()
{	
	char Error[1024];
	if((g_dbSQL = SQLite_UseDatabase("PointsSystem", Error, sizeof(Error))) == null)
		SetFailState("Could not connect to the database \"PointsSystem\" at the following error:\n%s", Error);

	SQL_FastQuery(g_dbSQL, "CREATE TABLE IF NOT EXISTS PS_Core(SteamID NVARCHAR(32) NOT NULL DEFAULT '', Points INT NOT NULL DEFAULT 0, UnixTime INT NOT NULL DEFAULT 0);");
}

Action cmdHealPlayer(int client, int args)
{
	if(args == 0)
	{
		vCheatCommandEx(client, "give", "health");
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
		return Plugin_Handled;
	}

	if(args == 1)
	{
		char arg[65];
		GetCmdArg(1, arg, sizeof(arg));
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		if((target_count = ProcessTargetString(
				arg,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_ALIVE,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		else
		{
			//ShowActivity2(client, MSGTAG, " %t", "Give Health", target_name);

			for (int i = 0; i < target_count; i++)
			{
				int targetclient = target_list[i];
				vCheatCommandEx(targetclient, "give", "health");
				SetEntPropFloat(targetclient, Prop_Send, "m_healthBuffer", 0.0);
			}
			return Plugin_Handled;
		}
	}
	else
	{
		ReplyToCommand(client, "%s%T", MSGTAG, "Usage sm_heal", client);
		return Plugin_Handled;
	}
}

Action cmdDelOld(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "sm_delold <days>");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		if(g_dbSQL == null)
		{
			ReplyToCommand(client, "无效的数据库句柄");
			return Plugin_Handled;
		}

		char sDays[8];
		GetCmdArg(1, sDays, sizeof(sDays));
	
		int iUnixTime = GetTime() - (StringToInt(sDays) * 60 * 60 * 24);
	
		char sQuery[1024];
		FormatEx(sQuery, sizeof(sQuery), "DELETE FROM PS_Core WHERE UnixTime < %d;", iUnixTime);
		g_dbSQL.Query(vSQL_CallbackDelOld, sQuery, GetClientUserId(client));
	}

	return Plugin_Handled;
}

void vSQL_CallbackDelOld(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || results == null)
	{
		LogError(error);
		return;
	}

	ReplyToCommand(GetClientOfUserId(data), "总计删除玩家记录: %d 条", results.AffectedRows);
}

Action cmdListPoints(int client, int args)
{
	if(args == 0)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i)) 
				ReplyToCommand(client, "%s %N: %d", MSGTAG, i, g_esPlayer[i].g_iPlayerPoints);
		}
	}
	return Plugin_Handled;
}

Action cmdSetPoints(int client, int args)
{
	if(args == 2)
	{
		char arg[MAX_NAME_LENGTH], arg2[32];
		GetCmdArg(1, arg, sizeof(arg));
		GetCmdArg(2, arg2, sizeof(arg2));
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		int targetclient, amount = StringToInt(arg2);
		if((target_count = ProcessTargetString(
				arg,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_NO_BOTS,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		//ShowActivity2(client, MSGTAG, "%t", "Set Points", target_name, amount);
		for (int i; i < target_count; i++)
		{
			targetclient = target_list[i];
			g_esPlayer[targetclient].g_iPlayerPoints = amount;
			vSQL_Save(targetclient);
			ReplyToCommand(client, "%s %T", MSGTAG, "Set Points", client, targetclient, amount);
			ReplyToCommand(targetclient, "%s %T", MSGTAG, "Set Target", targetclient, client, amount);
		}
	}
	else
		ReplyToCommand(client, "%s %T", MSGTAG, "Usage sm_setpoints", client, MSGTAG);

	return Plugin_Handled;
}

Action cmdGivePoints(int client, int args)
{
	if(args == 2)
	{
		char arg[MAX_NAME_LENGTH], arg2[32];
		GetCmdArg(1, arg, sizeof(arg));
		GetCmdArg(2, arg2, sizeof(arg2));
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		int targetclient, amount = StringToInt(arg2);
		if((target_count = ProcessTargetString(
				arg,
				client,
				target_list,
				MAXPLAYERS,
				COMMAND_FILTER_NO_BOTS,
				target_name,
				sizeof(target_name),
				tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
	
		for (int i; i < target_count; i++)
		{
			targetclient = target_list[i];
			g_esPlayer[targetclient].g_iPlayerPoints += amount;
			vSQL_Save(targetclient);
			ReplyToCommand(client, "%s %T", MSGTAG, "Give Points", client, amount, targetclient);
			ReplyToCommand(targetclient, "%s %T", MSGTAG, "Give Target", targetclient, client, amount);
		}
	}
	else
		ReplyToCommand(client, "%s %T", MSGTAG, "Usage sm_givepoints", client);

	return Plugin_Handled;
}

Action cmdListModules(int client, int args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "%s %T", MSGTAG, "Modules", client);

		int iLength = g_aModules.Length;
		for(int i; i < iLength; i++)
		{
			char sModule[MODULES_SIZE];
			g_aModules.GetString(i, sModule, MODULES_SIZE);
			ReplyToCommand(client, "%d %s", i, sModule);
		}
	}
	return Plugin_Handled;
}

Action cmdShowPoints(int client, int args)
{
	if(args != 0 || !bIsModEnabled() || !bIsClientPlaying(client))
		return Plugin_Handled;
	
	ReplyToCommand(client, "%s %T", MSGTAG, "Your Points", client, g_esPlayer[client].g_iPlayerPoints);
	return Plugin_Handled;
}

Action cmdBuyMenu(int client, int args)
{
	if(args != 0 || !bIsModEnabled() || !bIsClientPlaying(client))
		return Plugin_Handled;

	vBuildBuyMenu(client);
	return Plugin_Handled;
}

Action cmdRepeatBuy(int client, int args)
{
	if(args != 0 || !bIsClientPlaying(client) || !bCheckPurchase(client, g_esPlayer[client].g_iItemCost))
		return Plugin_Handled;

	if(strcmp(g_esPlayer[client].g_sCommand, "suicide") == 0)
	{
		if(bPerformSuicide(client))
			vRemovePoints(client, g_esPlayer[client].g_iItemCost);

		return Plugin_Handled;
	}
	else
	{
		if(strcmp(g_esPlayer[client].g_sCommand, "give ammo") == 0)
			vReloadAmmo(client, g_esPlayer[client].g_iItemCost, g_esPlayer[client].g_sCommand);
		else
		{
			vRemovePoints(client, g_esPlayer[client].g_iItemCost);
			vCheatCommand(client, g_esPlayer[client].g_sCommand);
		}
	}
	return Plugin_Handled;
}

bool bIsModEnabled()
{
	return g_bSettingAllow;
}

bool bIsClientPlaying(int client)
{
	return client > 0 && IsClientInGame(client) && GetClientTeam(client) > 1;
}

bool bIsRealClient(int client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

bool bIsSurvivor(int client)
{
	return GetClientTeam(client) == 2;
}

bool bIsInfected(int client)
{
	return GetClientTeam(client) == 3;
}

bool bIsTank(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

void vSetPlayerStartPoints(int client)
{
	g_esPlayer[client].g_iPlayerPoints = g_esGeneral.g_cSettings[cSettingStartPoints].IntValue;
}

void vAddPoints(int client, int iPoints, const char[] sMessage)
{
	if(client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		g_esPlayer[client].g_iPlayerPoints += iPoints;
		if(g_esGeneral.g_cSettings[cSettingNotifications].BoolValue)
			PrintToChat(client, "%s %T", MSGTAG, sMessage, client, iPoints);
	}
}

void vRemovePoints(int client, int iPoints)
{
	g_esPlayer[client].g_iPlayerPoints -= iPoints;
}

public void OnMapEnd()
{
	g_bMapStarted = false;

	g_esGeneral.g_iCounter[iTankSpawned] = 0;
	g_esGeneral.g_iCounter[iWitchSpawned] = 0;
}

public void OnMapStart()
{
	g_bMapStarted = true;

	GetCurrentMap(g_esGeneral.g_sCurrentMap, sizeof(esGeneral::g_sCurrentMap));

	PrecacheModel("models/v_models/v_m60.mdl");
	PrecacheModel("models/w_models/weapons/w_m60.mdl");
	PrecacheModel("models/infected/witch.mdl");
	PrecacheModel("models/infected/witch_bride.mdl");

	int i;
	int iLength = sizeof(g_sMeleeModels);
	for(i = 0; i < iLength; i++)
	{
		if(!IsModelPrecached(g_sMeleeModels[i]))
			PrecacheModel(g_sMeleeModels[i], true);
	}

	iLength = sizeof(g_sMeleeName);
	char sBuffer[64];
	for(i = 0; i < iLength; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "scripts/melee/%s.txt", g_sMeleeName[i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}
	
	vGetMaxClipSize();
	vGetMeleeClasses();
}

void vGetMaxClipSize()
{
	int entity = CreateEntityByName("weapon_rifle_m60");
	DispatchSpawn(entity);
	g_esGeneral.g_iClipSize[0] = GetEntProp(entity, Prop_Send, "m_iClip1");
	RemoveEdict(entity);

	entity = CreateEntityByName("weapon_grenade_launcher");
	DispatchSpawn(entity);
	g_esGeneral.g_iClipSize[1] = GetEntProp(entity, Prop_Send, "m_iClip1");
	RemoveEdict(entity);
}

void vGetMeleeClasses()
{
	int iMeleeStringTable = FindStringTable("MeleeWeapons");
	g_iMeleeClassCount = GetStringTableNumStrings(iMeleeStringTable);

	for(int i; i < g_iMeleeClassCount; i++)
		ReadStringTable(iMeleeStringTable, i, g_sMeleeClass[i], sizeof(g_sMeleeClass[]));
}

//https://forums.alliedmods.net/showthread.php?t=320247
public void OnClientAuthorized(int client, const char[] auth)
{
	if(client)
		bCacheSteamID(client);
}

bool bCacheSteamID(int client)
{
	if(g_esPlayer[client].g_sSteamId[0] == '\0')
		return GetClientAuthId(client, AuthId_Steam2, g_esPlayer[client].g_sSteamId, sizeof(esPlayer::g_sSteamId));
	return true;
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client))
		vSQL_Save(client);

	g_esPlayer[client].g_iLeechHealth = 0;
	g_esPlayer[client].g_fRealodSpeedUp = 1.0;
}

public void OnClientDisconnect_Post(int client)
{
	vResetClientData(client);
	vSetPlayerStartPoints(client);
	g_esPlayer[client].g_sSteamId[0] = '\0';
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;

	//vResetClientData(client);
	vSetPlayerStartPoints(client);
	vSQL_Load(client);
}

void vResetClientData(int client)
{
	g_esPlayer[client].g_iKillCount = 0;
	g_esPlayer[client].g_iHurtCount = 0;
	g_esPlayer[client].g_iProtectCount = 0;
	g_esPlayer[client].g_iHeadShotCount = 0;
	g_esPlayer[client].g_bDataLoaded = false;
}

void vSQL_Save(int client)
{
	
	if(g_esPlayer[client].g_bDataLoaded == false)
		return;

	if(g_dbSQL == null)
		return;

	if(!bCacheSteamID(client))
		return;

	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE PS_Core SET Points = %d, UnixTime = %d WHERE SteamID = '%s';", g_esPlayer[client].g_iPlayerPoints, GetTime(), g_esPlayer[client].g_sSteamId);
	SQL_FastQuery(g_dbSQL, sQuery);
}

void vSQL_Load(int client)
{
	if(g_dbSQL == null)
		return;

	if(!bCacheSteamID(client))
		return;

	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM PS_Core WHERE SteamId = '%s';", g_esPlayer[client].g_sSteamId);
	g_dbSQL.Query(vSQL_CallbackLoad, sQuery, GetClientUserId(client));
}

void vSQL_CallbackLoad(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || results == null)
	{
		LogError(error);
		return;
	}

	int client;
	if((client = GetClientOfUserId(data)) == 0)
		return;

	if(results.FetchRow())
		g_esPlayer[client].g_iPlayerPoints = results.FetchInt(1);
	else
	{
		char sQuery[1024];
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO PS_Core(SteamID, Points, UnixTime) VALUES ('%s', %d, %d);", g_esPlayer[client].g_sSteamId, g_esPlayer[client].g_iPlayerPoints, GetTime());
		SQL_FastQuery(g_dbSQL, sQuery);
	}

	g_esPlayer[client].g_bDataLoaded = true;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_esGeneral.g_iCounter[iTankSpawned] = 0;
	g_esGeneral.g_iCounter[iWitchSpawned] = 0;
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker == 0 || !bIsRealClient(attacker) || !bIsSurvivor(attacker))
		return;

	if(event.GetBool("headshot"))
		vEventHeadShots(attacker);

	int iReward = g_esGeneral.g_cPointRewards[cRewardSKillSpree].IntValue;
	if(iReward > 0)
	{
		g_esPlayer[attacker].g_iKillCount++;

		int iRequired = g_esGeneral.g_cSettings[cSettingKillSpreeNum].IntValue;
		if(g_esPlayer[attacker].g_iKillCount >= iRequired)
		{
			vAddPoints(attacker, iReward, "Killing Spree");
			g_esPlayer[attacker].g_iKillCount -= iRequired;
		}
	}
}

void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker == 0 || !bIsRealClient(attacker) || !bIsInfected(attacker))
		return;

	int iIncapPoints = g_esGeneral.g_cPointRewards[cRewardIIncapS].IntValue;
	if(iIncapPoints > 0)
		vAddPoints(attacker, iIncapPoints, "Incapped Survivor");
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker == 0 || !bIsRealClient(attacker))
		return;

	int client =GetClientOfUserId(event.GetInt("userid"));
	switch(GetClientTeam(attacker))
	{
		case 2:
		{
			if(client && bIsInfected(client) && !bIsTank(client))
			{
				if(g_esPlayer[attacker].g_iLeechHealth && !GetEntProp(attacker, Prop_Send, "m_isIncapacitated"))
					SetEntityHealth(attacker, GetClientHealth(attacker) + g_esPlayer[attacker].g_iLeechHealth); 

				if(event.GetBool("headshot"))
					vEventHeadShots(attacker);
			
				int iReward = g_esGeneral.g_cPointRewards[cRewardSKillI].IntValue;
				if(iReward > 0)
					vAddPoints(attacker, iReward, "Killed SI");
			}
		}

		case 3:
		{
			if(client && bIsSurvivor(client)) // If the person killed by the infected is a survivor
			{
				int iReward = g_esGeneral.g_cPointRewards[cRewardIKillS].IntValue;
				if(iReward > 0)
					vAddPoints(attacker, iReward, "Killed Survivor");
			}
		}
	}
}

void vEventHeadShots(int client)
{
	int iReward = g_esGeneral.g_cPointRewards[cRewardSHeadShots].IntValue;
	if(iReward > 0)
	{
		g_esPlayer[client].g_iHeadShotCount++;

		int iRequired = g_esGeneral.g_cSettings[cSettingHeadShotNum].IntValue;
		if(g_esPlayer[client].g_iHeadShotCount >= iRequired)
		{
			vAddPoints(client, iReward, "Head Hunter");
			g_esPlayer[client].g_iHeadShotCount -= iRequired;
		}
	}
}

void Event_TankKilled(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker == 0 || !bIsRealClient(attacker) || !bIsSurvivor(attacker))
		return;

	if(event.GetBool("solo"))
	{
		int iReward = g_esGeneral.g_cPointRewards[cRewardSSoloTank].IntValue;
		if(iReward > 0)
			vAddPoints(attacker, iReward, "TANK SOLO");
	}
	else
	{
		int iReward = g_esGeneral.g_cPointRewards[cRewardSKillTank].IntValue;
		if(iReward > 0)
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(bIsRealClient(i) && bIsSurvivor(i) && IsPlayerAlive(i))
					vAddPoints(i, iReward, "Killed Tank");
			}
		}
	}
}

void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsSurvivor(client))
		return;

	int iReward = g_esGeneral.g_cPointRewards[cRewardSKillWitch].IntValue;
	if(iReward > 0)
		vAddPoints(client, iReward, "Killed Witch");

	if(event.GetBool("oneshot"))
	{
		iReward = g_esGeneral.g_cPointRewards[cRewardSCrownWitch].IntValue;
		if(iReward > 0)
			vAddPoints(client, iReward, "Crowned Witch");
	}
}

void Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || client == GetClientOfUserId(event.GetInt("subject")) || !bIsRealClient(client) || !bIsSurvivor(client))
		return;
	
	if(event.GetInt("health_restored") > 39)
	{
		int iReward = g_esGeneral.g_cPointRewards[cRewardSTeamHeal].IntValue;
		if(iReward > 0)
			vAddPoints(client, iReward, "Team Heal");
	}
	else
	{
		int iReward = g_esGeneral.g_cPointRewards[cRewardSHealFarm].IntValue;
		if(iReward > 0)
			vAddPoints(client, iReward, "Team Heal Warning");
	}
}

void Event_AwardEarned(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("award") != 67)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsSurvivor(client))
		return;

	
	int iReward = g_esGeneral.g_cPointRewards[cRewardSProtect].IntValue;
	if(iReward > 0)
	{
		g_esPlayer[client].g_iProtectCount++;
		if(g_esPlayer[client].g_iProtectCount >= 6)
		{
			vAddPoints(client, iReward, "Protect");
			g_esPlayer[client].g_iProtectCount -= 6;
		}
	}
}

void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || client == GetClientOfUserId(event.GetInt("subject")) || !bIsRealClient(client) || !bIsSurvivor(client))
		return;

	if(event.GetBool("ledge_hang"))
	{
		int iReward = g_esGeneral.g_cPointRewards[cRewardSTeamLedge].IntValue;
		if(iReward > 0)
			vAddPoints(client, iReward, "Ledge Revive");
	}
	else
	{
		int iReward = g_esGeneral.g_cPointRewards[cRewardSTeamRevive].IntValue;
		if(iReward > 0)
			vAddPoints(client, iReward, "Revive");
	}
}

void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{ // Defib
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsSurvivor(client))
		return;
	
	int iReward = g_esGeneral.g_cPointRewards[cRewardSTeamDefib].IntValue;
	if(iReward > 0)
		vAddPoints(client, iReward, "Defib");
}

void Event_ChokeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsInfected(client))
		return;
	
	int iReward = g_esGeneral.g_cPointRewards[cRewardIChokeS].IntValue;
	if(iReward > 0)
		vAddPoints(client, iReward, "Smoke");
}

void Event_PlayerNowIt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker == 0 || !bIsRealClient(attacker))
		return;

	switch(GetClientTeam(attacker))
	{
		case 2:
		{
			int client = GetClientOfUserId(event.GetInt("userid"));
			if(client && bIsInfected(client) && bIsTank(client))
			{
				int iReward = g_esGeneral.g_cPointRewards[cRewardSBileTank].IntValue;
				if(iReward > 0)
					vAddPoints(attacker, iReward, "Biled");
			}
		}

		case 3:
		{
			int iReward = g_esGeneral.g_cPointRewards[cRewardIVomitS].IntValue;
			if(iReward > 0)
				vAddPoints(attacker, iReward, "Boom");
		}
	}
}

void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsInfected(client))
		return;

	int iReward = g_esGeneral.g_cPointRewards[cRewardIPounceS].IntValue;
	if(iReward > 0)
		vAddPoints(client, iReward, "Pounce");
}

void Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsInfected(client))
		return;

	int iReward = g_esGeneral.g_cPointRewards[cRewardIRideS].IntValue;
	if(iReward > 0)
		vAddPoints(client, iReward, "Jockey Ride");
}

void Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsInfected(client))
		return;
	
	int iReward = g_esGeneral.g_cPointRewards[cRewardIChargeS].IntValue;
	if(iReward > 0)
		vAddPoints(client, iReward, "Charge");
}

void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsRealClient(client) || !bIsInfected(client))
		return;
	
	int iReward = g_esGeneral.g_cPointRewards[cRewardIImpactS].IntValue;
	if(iReward > 0)
		vAddPoints(client, iReward, "Charge Collateral");
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(attacker == 0 || !bIsRealClient(attacker) || !bIsInfected(attacker))
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !bIsSurvivor(client))
		return;

	g_esPlayer[attacker].g_iHurtCount++;
	int iReward = g_esGeneral.g_cPointRewards[cRewardIHurtS].IntValue;
	if(iReward > 0)
	{
		int iDamageType = event.GetInt("type");
		if(bIsFireDamage(iDamageType)) // If infected is dealing fire damage, ignore
			return;
	
		if(bIsSpitterDamage(iDamageType))
		{
			if(g_esPlayer[attacker].g_iHurtCount >= 8)
			{
				vAddPoints(attacker, iReward, "Spit Damage");
				g_esPlayer[attacker].g_iHurtCount -= 8;
			}
		}
		else
		{
			if(g_esPlayer[attacker].g_iHurtCount >= 3)
			{
				vAddPoints(attacker, iReward, "Damage");
				g_esPlayer[attacker].g_iHurtCount -= 3;
			}
		}
	}
}

bool bIsFireDamage(int iDamageType)
{
	return iDamageType == 8 || iDamageType == 2056;
}

bool bIsSpitterDamage(int iDamageType)
{
   return iDamageType == 263168 || iDamageType == 265216;
}

bool bCheckPurchase(int client, int iCost)
{
	return bIsItemEnabled(client, iCost) && bHasEnoughPoints(client, iCost);
}

bool bIsItemEnabled(int client, int iCost)
{
	if(iCost >= 0)
		return true;

	ReplyToCommand(client, "%s %T", MSGTAG, "Item Disabled", client);
	return false;
}

bool bHasEnoughPoints(int client, int iCost)
{
	if(g_esPlayer[client].g_iPlayerPoints >= iCost)
		return true;

	ReplyToCommand(client, "%s %T", MSGTAG, "Insufficient Funds", client);
	return false;
}

void vJoinInfected(int client, int iCost)
{
	if(bIsSurvivor(client))
	{
		ChangeClientTeam(client, 3);
		vRemovePoints(client, iCost);
	}
}

bool bPerformSuicide(int client)
{
	if(bIsInfected(client) && IsPlayerAlive(client))
	{
		ForcePlayerSuicide(client);
		return true;
	}
	return false;
}

void vBuildBuyMenu(int client)
{
	switch(GetClientTeam(client))
	{
		case 2:
		{
			char sInfo[32];
			Menu menu = new Menu(iSurvivorMenuHandler);
			FormatEx(sInfo, sizeof(sInfo), "%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
			menu.SetTitle(sInfo);

			if(g_esGeneral.g_cCategories[cCategoryWeapon].IntValue == 1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Weapons", client);
				menu.AddItem("w", sInfo);
			}
			if(g_esGeneral.g_cCategories[cCategoryUpgrade].IntValue == 1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Upgrades", client);
				menu.AddItem("u", sInfo);
			}
			if(g_esGeneral.g_cCategories[cCategoryHealth].IntValue == 1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Health", client);
				menu.AddItem("h", sInfo);
			}
			if(g_esGeneral.g_cCategories[cCategoryTraitor].IntValue == 1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Traitor", client);
				menu.AddItem("i", sInfo);
			}
			if(g_esGeneral.g_cCategories[cCategorySpecial].IntValue == 1)
				menu.AddItem("s", "特殊");

			menu.Display(client, MENU_TIME_FOREVER);
		}

		case 3:
		{
			char sInfo[32];
			Menu menu = new Menu(iInfectedMenuHandler);
			FormatEx(sInfo, sizeof(sInfo), "%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
			menu.SetTitle(sInfo);
			if(g_esGeneral.g_cItemCosts[cCostPZHeal].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Heal", client);
				menu.AddItem("heal", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostSuicide].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Suicide", client);
				menu.AddItem("suicide", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostSmoker].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Smoker", client);
				menu.AddItem("smoker", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostBoomer].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Boomer", client);
				menu.AddItem("boomer", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostHunter].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Hunter", client);
				menu.AddItem("hunter", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostSpitter].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Spitter", client);
				menu.AddItem("spitter", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostJockey].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Jockey", client);
				menu.AddItem("jockey", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostCharger].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Charger", client);
				menu.AddItem("charger", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostTank].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Tank", client);
				menu.AddItem("tank", sInfo);
			}
			if(strcmp(g_esGeneral.g_sCurrentMap, "c6m1_riverbank", false) == 0 && g_esGeneral.g_cItemCosts[cCostWitch].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Witch Bride", client);
				menu.AddItem("witch_bride", sInfo);
			}
			else if(g_esGeneral.g_cItemCosts[cCostWitch].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Witch", client);
				menu.AddItem("witch", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostHorde].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Horde", client);
				menu.AddItem("horde", sInfo);
			}
			if(g_esGeneral.g_cItemCosts[cCostMob].IntValue > -1)
			{
				FormatEx(sInfo, sizeof(sInfo), "%T", "Mob", client);
				menu.AddItem("mob", sInfo);
			}
			menu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

void vBuildWeaponMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iWeaponMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cCategories[cCategoryMelee].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Melee", client);
		menu.AddItem("a", sInfo);
	}
	if(g_esGeneral.g_cCategories[cCategorySniper].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Sniper Rifles", client);
		menu.AddItem("b", sInfo);
	}
	if(g_esGeneral.g_cCategories[cCategoryRifle].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Assault Rifles", client);
		menu.AddItem("c", sInfo);
	}
	if(g_esGeneral.g_cCategories[cCategoryShotgun].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Shotguns", client);
		menu.AddItem("d", sInfo);
	}
	if(g_esGeneral.g_cCategories[cCategorySMG].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Submachine Guns", client);
		menu.AddItem("e", sInfo);
	}
	if(g_esGeneral.g_cCategories[cCategoryThrowable].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Throwables", client);
		menu.AddItem("f", sInfo);
	}
	if(g_esGeneral.g_cCategories[cCategoryMisc].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Misc", client);
		menu.AddItem("g", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iSurvivorMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'w':
					vBuildWeaponMenu(param1);

				case 'h':
					vBuildHealthMenu(param1);

				case 'u':
					vBuildUpgradeMenu(param1);

				case 'i':
				{
					g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostTraitor].IntValue;

					char sInfo[32];
					Menu menu1 = new Menu(iTraitorMenuHandler);
					FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayer[param1].g_iItemCost);
					menu1.SetTitle(sInfo);
					FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
					menu1.AddItem("y", sInfo);
					FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
					menu1.AddItem("n", sInfo);
					menu1.ExitButton = true;
					menu1.ExitBackButton = true;
					menu1.Display(param1, MENU_TIME_FOREVER);
				}
		
				case 's':
					vBuildSpecialMenu(param1);
			}
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iTraitorMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
					vBuildBuyMenu(param1);

				case 'y':
				{
					if(!bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
						return 0;

					if(iGetPlayerZombie() >= g_esGeneral.g_cSettings[cSettingTraitorLimit].IntValue)
						PrintToChat(param1,  "%T", "Traitor Limit", param1);
					else
						vJoinInfected(param1, g_esPlayer[param1].g_iItemCost);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iGetPlayerZombie()
{
	int iZombie;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
			iZombie++;
	}
	return iZombie;
}

int iWeaponMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'a':
					vBuildMeleeMenu(param1);
			
				case 'b':
					vBuildSniperMenu(param1);
		
				case 'c':
					vBuildRifleMenu(param1);
			
				case 'd':
					vBuildShotgunMenu(param1);
				
				case 'e':
					vBuildSMGMenu(param1);
		
				case 'f':
					vBuildThrowableMenu(param1);
			
				case 'g':
					vBuildMiscMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vBuildMeleeMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iMeleeMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	for(int i; i < g_iMeleeClassCount; i++)
	{
		int iPos = iGetMeleePos(g_sMeleeClass[i]);
		int iCost = iPos != -1 ? g_esGeneral.g_cItemCosts[iPos + cCostFireaxe].IntValue : g_esGeneral.g_cItemCosts[cCostCustomMelee].IntValue;

		if(iCost < 0)
			continue;

		if(iPos != -1)
			FormatEx(sInfo, sizeof(sInfo), "%T", g_sMeleeClass[i], client);
		else
			FormatEx(sInfo, sizeof(sInfo), g_sMeleeClass[i]);
		menu.AddItem(g_sMeleeClass[i], sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iGetMeleePos(const char[] sMelee)
{
	for(int i; i < sizeof(g_sMeleeName); i++)
	{
		if(strcmp(g_sMeleeName[i], sMelee) == 0)
			return i;
	}
	return -1;
}

void vBuildSniperMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iSniperMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostHunting].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Hunting Rifle", client);
		menu.AddItem("hunting_rifle", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostMilitary].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Military Sniper Rifle", client);
		menu.AddItem("sniper_military", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostAWP].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "AWP Sniper Rifle", client);
		menu.AddItem("sniper_awp", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostScout].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Scout Sniper Rifle", client);
		menu.AddItem("sniper_scout", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vBuildRifleMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iRifleMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostM60].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "M60 Assault Rifle", client);
		menu.AddItem("rifle_m60", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostM16].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "M16 Assault Rifle", client);
		menu.AddItem("rifle", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostSCAR].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "SCAR-L Assault Rifle", client);
		menu.AddItem("rifle_desert", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostAK47].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "AK-47 Assault Rifle", client);
		menu.AddItem("rifle_ak47", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostSG552].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "SG552 Assault Rifle", client);
		menu.AddItem("rifle_sg552", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vBuildShotgunMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iShotgunMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostPump].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Pump Shotgun", client);
		menu.AddItem("pumpshotgun", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostChrome].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Chrome Shotgun", client);
		menu.AddItem("shotgun_chrome", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostAuto].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Tactical Shotgun", client);
		menu.AddItem("autoshotgun", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostSPAS].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "SPAS Shotgun", client);
		menu.AddItem("shotgun_spas", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vBuildSMGMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iSMGMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostUZI].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Uzi", client);
		menu.AddItem("smg", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostSilenced].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Silenced SMG", client);
		menu.AddItem("smg_silenced", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostMP5].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "MP5 SMG", client);
		menu.AddItem("smg_mp5", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vBuildHealthMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iHealthMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostHealthKit].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "First Aid Kit", client);
		menu.AddItem("first_aid_kit", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostDefib].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Defibrillator", client);
		menu.AddItem("defibrillator", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostPills].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Pills", client);
		menu.AddItem("pain_pills", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostAdren].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Adrenaline", client);
		menu.AddItem("adrenaline", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostHeal].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Full Heal", client);
		menu.AddItem("health", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vBuildThrowableMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iThrowableMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostMolotov].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Molotov", client);
		menu.AddItem("molotov", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostPipe].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Pipe Bomb", client);
		menu.AddItem("pipe_bomb", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostBile].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Bile Bomb", client);
		menu.AddItem("vomitjar", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vBuildMiscMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iMiscMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostGrenade].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Grenade Launcher", client);
		menu.AddItem("grenade_launcher", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostP220].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "P220 Pistol", client);
		menu.AddItem("pistol", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostMagnum].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Magnum Pistol", client);
		menu.AddItem("pistol_magnum", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostChainsaw].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Chainsaw", client);
		menu.AddItem("chainsaw", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostGnome].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Gnome", client);
		menu.AddItem("gnome", sInfo);
	}
	if(strcmp(g_esGeneral.g_sCurrentMap, "c1m2_streets", false) != 0 && g_esGeneral.g_cItemCosts[cCostCola].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Cola Bottles", client);
		menu.AddItem("cola_bottles", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostFireworks].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Fireworks Crate", client);
		menu.AddItem("fireworkcrate", sInfo);
	}
	if(g_iCurrentMode != 8 && g_esGeneral.g_cItemCosts[cCostGasCan].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Gascan", client);
		menu.AddItem("gascan", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostOxygen].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Oxygen Tank", client);
		menu.AddItem("oxygentank", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostPropane].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Propane Tank", client);
		menu.AddItem("propanetank", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vBuildUpgradeMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iUpgradeMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	if(g_esGeneral.g_cItemCosts[cCostLaserSight].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Laser Sight", client);
		menu.AddItem("laser_sight", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostExplosiveAmmo].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Explosive Ammo", client);
		menu.AddItem("explosive_ammo", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostIncendiaryAmmo].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Incendiary Ammo", client);
		menu.AddItem("incendiary_ammo", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostExplosivePack].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Explosive Ammo Pack", client);
		menu.AddItem("upgradepack_explosive", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostIncendiaryPack].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Incendiary Ammo Pack", client);
		menu.AddItem("upgradepack_incendiary", sInfo);
	}
	if(g_esGeneral.g_cItemCosts[cCostAmmo].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Ammo", client);
		menu.AddItem("ammo", sInfo);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iMeleeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			FormatEx(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give %s", sItem);
			int sequence = iGetMeleePos(sItem);
			if(sequence != -1)
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[sequence + 25].IntValue;
			else
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostCustomMelee].IntValue;
			vDisplayMeleeConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSMGMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "smg") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give smg");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostUZI].IntValue;
			}
			else if(strcmp(sItem, "smg_silenced") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give smg_silenced");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostSilenced].IntValue;
			}
			else if(strcmp(sItem, "smg_mp5") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give smg_mp5");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostMP5].IntValue;
			}
			vDisplaySMGConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iRifleMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "rifle") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give rifle");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostM16].IntValue;
			}
			else if(strcmp(sItem, "rifle_desert") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give rifle_desert");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostSCAR].IntValue;
			}
			else if(strcmp(sItem, "rifle_ak47") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give rifle_ak47");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostAK47].IntValue;
			}
			else if(strcmp(sItem, "rifle_sg552") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give rifle_sg552");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostSG552].IntValue;
			}
			else if(strcmp(sItem, "rifle_m60") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give rifle_m60");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostM60].IntValue;
			}
			vDisplayRifleConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSniperMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "hunting_rifle") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give hunting_rifle");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostHunting].IntValue;
			}
			else if(strcmp(sItem, "sniper_scout") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give sniper_scout");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostScout].IntValue;
			}
			else if(strcmp(sItem, "sniper_awp") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give sniper_awp");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostAWP].IntValue;
			}
			else if(strcmp(sItem, "sniper_military") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give sniper_military");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostMilitary].IntValue;
			}
			vDisplaySniperConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iShotgunMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "pumpshotgun") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give pumpshotgun");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostPump].IntValue;
			}
			else if(strcmp(sItem, "shotgun_chrome") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give shotgun_chrome");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostChrome].IntValue;
			}
			else if(strcmp(sItem, "autoshotgun") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give autoshotgun");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostAuto].IntValue;
			}
			else if(strcmp(sItem, "shotgun_spas") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give shotgun_spas");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostSPAS].IntValue;
			}
			vDisplayShotgunConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iThrowableMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "molotov") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give molotov");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostMolotov].IntValue;
			}
			else if(strcmp(sItem, "pipe_bomb") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give pipe_bomb");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostPipe].IntValue;
			}
			else if(strcmp(sItem, "vomitjar") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give vomitjar");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostBile].IntValue;
			}
			vDisplayThrowableConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iMiscMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "pistol") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give pistol");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostP220].IntValue;
			}
			else if(strcmp(sItem, "pistol_magnum") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give pistol_magnum");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostMagnum].IntValue;
			}
			else if(strcmp(sItem, "grenade_launcher") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give grenade_launcher");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostGrenade].IntValue;
			}
			else if(strcmp(sItem, "chainsaw") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give chainsaw");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostChainsaw].IntValue;
			}
			else if(strcmp(sItem, "gnome") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give gnome");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostGnome].IntValue;
			}
			else if(strcmp(sItem, "cola_bottles") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give cola_bottles");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostCola].IntValue;
			}
			else if(strcmp(sItem, "gascan") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give gascan");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostGasCan].IntValue;
			}
			else if(strcmp(sItem, "propanetank") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give propanetank");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostPropane].IntValue;
			}
			else if(strcmp(sItem, "fireworkcrate") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give fireworkcrate");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostFireworks].IntValue;
			}
			else if(strcmp(sItem, "oxygentank") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give oxygentank");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostOxygen].IntValue;
			}
			vDisplayMiscConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildWeaponMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iHealthMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "first_aid_kit") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give first_aid_kit");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostHealthKit].IntValue;
			}
			else if(strcmp(sItem, "defibrillator") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give defibrillator");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostDefib].IntValue;
			}
			else if(strcmp(sItem, "pain_pills") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give pain_pills");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostPills].IntValue;
			}
			else if(strcmp(sItem, "adrenaline") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give adrenaline");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostAdren].IntValue;
			}
			else if(strcmp(sItem, "health") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give health");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostHeal].IntValue;
			}
			vDisplayHealthConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iUpgradeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "upgradepack_explosive") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give upgradepack_explosive");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostExplosivePack].IntValue;
			}
			else if(strcmp(sItem, "upgradepack_incendiary") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give upgradepack_incendiary");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostIncendiaryPack].IntValue;
			}
			else if(strcmp(sItem, "explosive_ammo") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "upgrade_add EXPLOSIVE_AMMO");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostExplosiveAmmo].IntValue;
			}
			else if(strcmp(sItem, "incendiary_ammo") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "upgrade_add INCENDIARY_AMMO");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostIncendiaryAmmo].IntValue;
			}
			else if(strcmp(sItem, "laser_sight") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "upgrade_add LASER_SIGHT");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostLaserSight].IntValue;
			}
			else if(strcmp(sItem, "ammo") == 0)
			{
				strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), "give ammo");
				g_esPlayer[param1].g_iItemCost = g_esGeneral.g_cItemCosts[cCostAmmo].IntValue;
			}
			vDisplayUpgradeConfirmMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iInfectedMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "heal") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "give health");
				if(bIsTank(client))
					g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostPZHeal].IntValue * g_esGeneral.g_cItemCosts[cCostTankHealMulti].IntValue;
				else
					g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostPZHeal].IntValue;
			}
			else if(strcmp(sItem, "suicide") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "suicide");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostSuicide].IntValue;
			}
			else if(strcmp(sItem, "smoker") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old smoker");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostSmoker].IntValue;
			}
			else if(strcmp(sItem, "boomer") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old boomer");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostBoomer].IntValue;
			}
			else if(strcmp(sItem, "hunter") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old hunter");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostHunter].IntValue;
			}
			else if(strcmp(sItem, "spitter") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old spitter");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostSpitter].IntValue;
			}
			else if(strcmp(sItem, "jockey") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old jockey");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostJockey].IntValue;
			}
			else if(strcmp(sItem, "charger") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old charger");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostCharger].IntValue;
			}
			else if(strcmp(sItem, "witch") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old witch");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostWitch].IntValue;
			}
			else if(strcmp(sItem, "witch_bride") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old witch_bride");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostWitch].IntValue;
			}
			else if(strcmp(sItem, "tank") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old tank");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostTank].IntValue;
			}
			else if(strcmp(sItem, "horde") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "director_force_panic_event");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostHorde].IntValue;
			}
			else if(strcmp(sItem, "mob") == 0)
			{
				strcopy(g_esPlayer[client].g_sCommand, sizeof(esPlayer::g_sCommand), "z_spawn_old mob");
				g_esPlayer[client].g_iItemCost = g_esGeneral.g_cItemCosts[cCostMob].IntValue;
			}
			vDisplayInfectedConfirmMenu(client);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vDisplayMeleeConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iMeleeConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplaySMGConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iSMGConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplayRifleConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iRifleConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplaySniperConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iSniperConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplayShotgunConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iShotgunConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplayThrowableConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iThrowableConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplayMiscConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iMiscConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplayHealthConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iHealthConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplayUpgradeConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iUpgradeConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplayInfectedConfirmMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iInfectedConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", client);
	menu.AddItem("y", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", client);
	menu.AddItem("n", sInfo);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iMeleeConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildMeleeMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
						g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildMeleeMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iRifleConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildRifleMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
						g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildRifleMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSniperConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildSniperMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						strcopy(g_esPlayer[param1].g_sBought,sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
						g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildSniperMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSMGConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildSMGMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
						g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildSMGMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iShotgunConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildShotgunMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
						g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildShotgunMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iThrowableConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildThrowableMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
						g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildThrowableMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iMiscConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildMiscMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
						g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildMiscMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iHealthConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildHealthMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						if(strcmp(g_esPlayer[param1].g_sCommand, "give health") == 0)
						{
							if(IsPlayerAlive(param1))
							{
								strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
								g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
								vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
								vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
							}
						}
						else
						{
							strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
							g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
							vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
							vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
						}
					}
				}	
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildHealthMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vReloadAmmo(int client, int iCost, const char[] sItem)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0);
	if(iWeapon > MaxClients && IsValidEntity(iWeapon))
	{
		char sWeapon[32];
		GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
		if(strcmp(sWeapon, "weapon_rifle_m60") == 0)
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", g_esGeneral.g_iClipSize[0]);
		else if(strcmp(sWeapon, "grenade_launcher") == 0)
		{
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", g_esGeneral.g_iClipSize[1]);
			int iAmmoMax = FindConVar("ammo_grenadelauncher_max").IntValue;
			if(iAmmoMax < 1)
				iAmmoMax = 30;

			SetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_iAmmo") + 68, iAmmoMax);
		}
		vCheatCommand(client, sItem);
		vRemovePoints(client, iCost);
	}
	else
		PrintToChat(client, "%s %T", MSGTAG, "Primary Warning", client);
}

int iUpgradeConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildUpgradeMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						if(strcmp(g_esPlayer[param1].g_sCommand, "give ammo") == 0)
							vReloadAmmo(param1, g_esPlayer[param1].g_iItemCost, g_esPlayer[param1].g_sCommand);
						else
						{
							strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
							g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
							vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
							vCheatCommand(param1, g_esPlayer[param1].g_sCommand);
						}
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildUpgradeMenu(param1);

			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iInfectedConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'n':
				{
					vBuildBuyMenu(param1);
					strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
					g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
				}

				case 'y':
				{
					if(!bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
						return 0;

					int iPos;
					char sCommand[32], sArguments[32];
					if((iPos = SplitString(g_esPlayer[param1].g_sCommand, " ", sCommand, sizeof(sCommand))) == -1)
						strcopy(sCommand, sizeof(sCommand), g_esPlayer[param1].g_sCommand);
					else
					{
						strcopy(sArguments, sizeof(sArguments), g_esPlayer[param1].g_sCommand[iPos]);
						TrimString(sArguments);
					}

					if(sArguments[0] == '\0' && strcmp(sCommand, "suicide") == 0)
					{
						if(!bPerformSuicide(param1))
							return 0;
					}
					else
					{
						if(strcmp(sArguments, "health") == 0)
						{
							if(!IsPlayerAlive(param1))
								return 0;
						}
						else if(strcmp(sCommand, "z_spawn_old") == 0)
						{
							if(strcmp(sArguments, "tank") == 0)
							{
								if(bReachedTankLimit(param1))
									return 0;
							}
							else if(strncmp(sArguments, "witch", 5) == 0)
							{
								if(bReachedWitchLimit(param1))
									return 0;
							}

							if(sArguments[0] != 'm' && sArguments[0] != 'w')
							{
								if(!IsPlayerAlive(param1))
								{
									vSpawnablePZScanProtect(0, param1);
									vCheatCommandEx(param1, sCommand, sArguments);
									vSpawnablePZScanProtect(1, param1);

									if(IsPlayerAlive(param1))
									{
										strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
										g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
										vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
									}
									else
										PrintToChat(param1, "%s %T", MSGTAG, "Spawn Failed", param1);

									return 0;
								}
							}
						}
						vCheatCommandEx(param1, sCommand, sArguments);
					}
					strcopy(g_esPlayer[param1].g_sBought, sizeof(esPlayer::g_sBought), g_esPlayer[param1].g_sCommand);
					g_esPlayer[param1].g_iBoughtCost = g_esPlayer[param1].g_iItemCost;
					vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
				}
			}
		}
		case MenuAction_Cancel:
		{
			strcopy(g_esPlayer[param1].g_sCommand, sizeof(esPlayer::g_sCommand), g_esPlayer[param1].g_sBought);
			g_esPlayer[param1].g_iItemCost = g_esPlayer[param1].g_iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

bool bReachedTankLimit(int client)
{
	if(g_esGeneral.g_iCounter[iTankSpawned] >= g_esGeneral.g_cSettings[cSettingTankLimit].IntValue)
	{
		PrintToChat(client,  "%T", "Tank Limit", client);
		return true;
	}
	g_esGeneral.g_iCounter[iTankSpawned]++;
	return false;
}

bool bReachedWitchLimit(int client)
{
	if(g_esGeneral.g_iCounter[iWitchSpawned] >= g_esGeneral.g_cSettings[cSettingWitchLimit].IntValue)
	{
		PrintToChat(client,  "%T", "Witch Limit", client);
		return true;
	}
	g_esGeneral.g_iCounter[iWitchSpawned]++;
	return false;
}

void vSpawnablePZScanProtect(int iState, int client = -1)
{
	static int i;
	static bool bResetGhost[MAXPLAYERS + 1];
	static bool bResetLifeState[MAXPLAYERS + 1];

	switch(iState)
	{
		case 0: 
		{
			if(g_bControlZombies && CZ_IsSpawnablePZSupported())
				CZ_SetSpawnablePZ(client);
			else
			{
				for(i = 1; i <= MaxClients; i++)
				{
					if(i == client || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3)
						continue;

					if(GetEntProp(i, Prop_Send, "m_isGhost") == 1)
					{
						bResetGhost[i] = true;
						SetEntProp(i, Prop_Send, "m_isGhost", 0);
					}
					else if(!IsPlayerAlive(i))
					{
						bResetLifeState[i] = true;
						SetEntProp(i, Prop_Send, "m_lifeState", 0);
					}
				}
			}
		}

		case 1: 
		{
			if(g_bControlZombies && CZ_IsSpawnablePZSupported())
				CZ_ResetSpawnablePZ();
			else
			{
				for(i = 1; i <= MaxClients; i++)
				{
					if(bResetGhost[i])
						SetEntProp(i, Prop_Send, "m_isGhost", 1);
					if(bResetLifeState[i])
						SetEntProp(i, Prop_Send, "m_lifeState", 1);
			
					bResetGhost[i] = false;
					bResetLifeState[i] = false;
				}
			}
		}
	}
}

void vCheatCommandEx(int client, const char[] sCommand, const char[] sArguments = "")
{
	static int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags);
}

void vCheatCommand(int client, const char[] sCommand)
{
	char sCmd[32];
	if(SplitString(sCommand, " ", sCmd, sizeof(sCmd)) == -1)
		strcopy(sCmd, sizeof(sCmd), sCommand);

	static int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCmd);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCmd, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, sCommand);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCmd, iCmdFlags);
	
	if(strcmp(sCmd, "give") == 0)
	{
		if(strcmp(sCommand[5], "health") == 0)
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0); //防止有虚血时give health会超过100血
	}
}

void vBuildSpecialMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(iSpecialMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayer[client].g_iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.AddItem("h", "生命汲取");
	if(g_bWeaponHandling)
		menu.AddItem("r", "加速装填");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iSpecialMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch(sItem[0])
			{
				case 'h':
					vHealthLeechMenu(param1);
			
				case 'r':
					vSpeedUpRealodMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vHealthLeechMenu(int client)
{
	Menu menu = new Menu(iHealthLeechMenuHandler);
	menu.SetTitle("定值[%d](效果持续到下张地图)", g_esPlayer[client].g_iLeechHealth);
	if(g_esSpecial.g_cLeechHealth[0].IntValue > -1)
		menu.AddItem("1", "1");
	if(g_esSpecial.g_cLeechHealth[1].IntValue > -1)
		menu.AddItem("2", "2");
	if(g_esSpecial.g_cLeechHealth[2].IntValue > -1)
		menu.AddItem("3", "3");
	if(g_esSpecial.g_cLeechHealth[3].IntValue > -1)
		menu.AddItem("4", "4");
	if(g_esSpecial.g_cLeechHealth[4].IntValue > -1)
		menu.AddItem("5", "5");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vSpeedUpRealodMenu(int client)
{
	Menu menu = new Menu(iSpeedUpRealodMenuHandler);
	menu.SetTitle("倍率[%.1fx](效果持续到下张地图)", g_esPlayer[client].g_fRealodSpeedUp);
	if(g_esSpecial.g_cRealodSpeedUp[0].IntValue > -1)
		menu.AddItem("1.5", "1.5x");
	if(g_esSpecial.g_cRealodSpeedUp[1].IntValue > -1)
		menu.AddItem("2.0", "2.0x");
	if(g_esSpecial.g_cRealodSpeedUp[2].IntValue > -1)
		menu.AddItem("2.5", "2.5x");
	if(g_esSpecial.g_cRealodSpeedUp[3].IntValue > -1)
		menu.AddItem("3.0", "3.0x");
	if(g_esSpecial.g_cRealodSpeedUp[4].IntValue > -1)
		menu.AddItem("3.5", "3.5x");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iHealthLeechMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			menu.GetItem(param2, sItem, sizeof(sItem));
			int iValue = StringToInt(sItem);
			switch(iValue)
			{
				case 1:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cLeechHealth[0].IntValue;
				
				case 2:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cLeechHealth[1].IntValue;
				
				case 3:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cLeechHealth[2].IntValue;

				case 4:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cLeechHealth[3].IntValue;

				case 5:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cLeechHealth[4].IntValue;
			}
			vDisplayHealthLeechConfirmMenu(client, sItem);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildSpecialMenu(client);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSpeedUpRealodMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			menu.GetItem(param2, sItem, sizeof(sItem));
			float iValue = StringToFloat(sItem);
			switch(iValue)
			{
				case 1.5:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cRealodSpeedUp[0].IntValue;
				
				case 2.0:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cRealodSpeedUp[1].IntValue;
				
				case 2.5:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cRealodSpeedUp[2].IntValue;

				case 3.0:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cRealodSpeedUp[3].IntValue;

				case 3.5:
					g_esPlayer[client].g_iItemCost = g_esSpecial.g_cRealodSpeedUp[4].IntValue;
			}
			vDisplaySpeedUpRealodConfirmMenu(client, sItem);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vBuildSpecialMenu(client);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vDisplayHealthLeechConfirmMenu(int client, const char[] sValue)
{
	char sInfo[32];
	char sTrans[32];
	char sTemp[2][16];
	Menu menu = new Menu(iHealthLeechConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	strcopy(sTemp[1], sizeof(sTemp[]), sValue);

	strcopy(sTemp[0], sizeof(sTemp[]), "y");
	ImplodeStrings(sTemp, 2, "|", sInfo, sizeof(sInfo));
	FormatEx(sTrans, sizeof(sTrans),"%T", "Yes", client);
	menu.AddItem(sInfo, sTrans);
	strcopy(sTemp[0], sizeof(sTemp[]), "n");
	ImplodeStrings(sTemp, 2, "|", sInfo, sizeof(sInfo));
	FormatEx(sTrans, sizeof(sTrans),"%T", "No", client);
	menu.AddItem(sInfo, sTrans);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void vDisplaySpeedUpRealodConfirmMenu(int client, const char[] sValue)
{
	char sInfo[32];
	char sTrans[32];
	char sTemp[2][16];
	Menu menu = new Menu(iSpeedUpRealodConfirmMenuHandler);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", client, g_esPlayer[client].g_iItemCost);
	menu.SetTitle(sInfo);
	strcopy(sTemp[1], sizeof(sTemp[]), sValue);

	strcopy(sTemp[0], sizeof(sTemp[]), "y");
	ImplodeStrings(sTemp, 2, "|", sInfo, sizeof(sInfo));
	FormatEx(sTrans, sizeof(sTrans),"%T", "Yes", client);
	menu.AddItem(sInfo, sTrans);
	strcopy(sTemp[0], sizeof(sTemp[]), "n");
	ImplodeStrings(sTemp, 2, "|", sInfo, sizeof(sInfo));
	FormatEx(sTrans, sizeof(sTrans),"%T", "No", client);
	menu.AddItem(sInfo, sTrans);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int iHealthLeechConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			char sInfo[2][16];
			menu.GetItem(param2, sItem, sizeof(sItem));
			ExplodeString(sItem, "|", sInfo, 2, 16);
			switch(sInfo[0][0])
			{
				case 'n':
					vHealthLeechMenu(param1);

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						g_esPlayer[param1].g_iLeechHealth = StringToInt(sInfo[1]);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vHealthLeechMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

int iSpeedUpRealodConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			char sInfo[2][16];
			menu.GetItem(param2, sItem, sizeof(sItem));
			ExplodeString(sItem, "|", sInfo, 2, 16);
			switch(sInfo[0][0])
			{
				case 'n':
					vHealthLeechMenu(param1);

				case 'y':
				{
					if(bHasEnoughPoints(param1, g_esPlayer[param1].g_iItemCost))
					{
						vRemovePoints(param1, g_esPlayer[param1].g_iItemCost);
						g_esPlayer[param1].g_fRealodSpeedUp = StringToFloat(sInfo[1]);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				vSpeedUpRealodMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void vInitSpecialValue()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_esPlayer[i].g_iLeechHealth = 0;
		g_esPlayer[i].g_fRealodSpeedUp = 1.0;
	}
}

enum L4D2WeaponType 
{
	L4D2WeaponType_Unknown = 0,
	L4D2WeaponType_Pistol,
	L4D2WeaponType_Magnum,
	L4D2WeaponType_Rifle,
	L4D2WeaponType_RifleAk47,
	L4D2WeaponType_RifleDesert,
	L4D2WeaponType_RifleM60,
	L4D2WeaponType_RifleSg552,
	L4D2WeaponType_HuntingRifle,
	L4D2WeaponType_SniperAwp,
	L4D2WeaponType_SniperMilitary,
	L4D2WeaponType_SniperScout,
	L4D2WeaponType_SMG,
	L4D2WeaponType_SMGSilenced,
	L4D2WeaponType_SMGMp5,
	L4D2WeaponType_Autoshotgun,
	L4D2WeaponType_AutoshotgunSpas,
	L4D2WeaponType_Pumpshotgun,
	L4D2WeaponType_PumpshotgunChrome,
	L4D2WeaponType_Molotov,
	L4D2WeaponType_Pipebomb,
	L4D2WeaponType_FirstAid,
	L4D2WeaponType_Pills,
	L4D2WeaponType_Gascan,
	L4D2WeaponType_Oxygentank,
	L4D2WeaponType_Propanetank,
	L4D2WeaponType_Vomitjar,
	L4D2WeaponType_Adrenaline,
	L4D2WeaponType_Chainsaw,
	L4D2WeaponType_Defibrilator,
	L4D2WeaponType_GrenadeLauncher,
	L4D2WeaponType_Melee,
	L4D2WeaponType_UpgradeFire,
	L4D2WeaponType_UpgradeExplosive,
	L4D2WeaponType_BoomerClaw,
	L4D2WeaponType_ChargerClaw,
	L4D2WeaponType_HunterClaw,
	L4D2WeaponType_JockeyClaw,
	L4D2WeaponType_SmokerClaw,
	L4D2WeaponType_SpitterClaw,
	L4D2WeaponType_TankClaw,
	L4D2WeaponType_Gnome
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = fSpeedModifier(client, speedmodifier);
}

float fSpeedModifier(int client, float speedmodifier)
{
	if(g_esPlayer[client].g_fRealodSpeedUp > 1.0)
		speedmodifier = speedmodifier * g_esPlayer[client].g_fRealodSpeedUp;

	return speedmodifier;
}