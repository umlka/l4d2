#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.8.0"

#define MSGTAG "\x04[PS]\x01"
#define MODULES_SIZE 100

enum
{
	hVersion,
	hEnabled,
	hModes,
	hNotifications,
	hKillSpreeNum,
	hHeadShotNum,
	hTankLimit,
	hWitchLimit,
	hStartPoints,
	hSpawnAttempts,
	hInfectedPlayerLimit
}

enum
{
	CategoryRifles,
	CategorySMG,
	CategorySnipers,
	CategoryShotguns,
	CategoryHealth,
	CategoryUpgrades,
	CategoryThrowables,
	CategoryMisc,
	CategoryMelee,
	CategoryWeapons
}

enum
{
	SurvRewardKillSpree,
	SurvRewardHeadShots,
	SurvKillInfec,
	SurvKillTank,
	SurvKillWitch,
	SurvCrownWitch,
	SurvTeamHeal,
	SurvTeamHealFarm,
	SurvTeamProtect,
	SurvTeamRevive,
	SurvTeamLedge,
	SurvTeamDefib,
	SurvBurnTank,
	SurvBileTank,
	SurvBurnWitch,
	SurvTankSolo,
	InfecChokeSurv,
	InfecPounceSurv,
	InfecChargeSurv,
	InfecImpactSurv,
	InfecRideSurv,
	InfecBoomSurv,
	InfecIncapSurv,
	InfecHurtSurv,
	InfecKillSurv
}

enum
{
	CostP220,
	CostMagnum,
	CostUzi,
	CostSilenced,
	CostMP5,
	CostM16,
	CostAK47,
	CostSCAR,
	CostSG552,
	CostHunting,
	CostMilitary,
	CostAWP,
	CostScout,
	CostAuto,
	CostSPAS,
	CostChrome,
	CostPump,
	CostGrenade,
	CostM60,
	CostGasCan,
	CostOxygen,
	CostPropane,
	CostGnome,
	CostCola,
	CostFireworks,
	CostKnife,
	CostCricketbat,
	CostCrowbar,
	CostElectricguitar,
	CostFireaxe,
	CostFryingpan,
	CostGolfclub,
	CostBaseballbat,
	CostKatana,
	CostMachete,
	CostTonfa,
	CostRiotshield,
	CostPitchfork,
	CostShovel,
	CostCustomMelee,
	CostChainsaw,
	CostPipe,
	CostMolotov,
	CostBile,
	CostHealthKit,
	CostDefib,
	CostAdren,
	CostPills,
	CostExplosiveAmmo,
	CostFireAmmo,
	CostExplosivePack,
	CostFirePack,
	CostLaserSight,
	CostAmmo,
	CostHeal,
	CostSuicide,
	CostHunter,
	CostJockey,
	CostSmoker,
	CostCharger,
	CostBoomer,
	CostSpitter,
	CostInfectedHeal,
	CostWitch,
	CostTank,
	CostTankHealMultiplier,
	CostHorde,
	CostMob,
	CostUncommonMob,
	CostInfectedSlot
}

enum
{
	iTanksSpawned,
	iWitchesSpawned,
	iUCommonLeft
}

int g_iCounterData[3];

void InitCounterData()
{
	g_iCounterData[iTanksSpawned] = 0;
	g_iCounterData[iWitchesSpawned] = 0;
}

//汉化@夏恋灬花火碎片 
enum struct esPlayerData
{
	bool bMessageSent; // 是否给玩家显示欢迎信息
	bool bPointsLoaded; // 是否已经从客户预置数据库中加载一个玩家的分数
	bool bWitchBurning; // 无论玩家是否点燃了女巫
	bool bTankBurning; // 无论玩家是否点燃了坦克
	char sBought[64]; // 最后购买的物品 (多余的)
	char sItemName[64]; // 玩家打算购买的物品
	int iBoughtCost; // 最后购买物品的成本 (多余的)
	int iItemCost; // 玩家打算购买的物品的成本
	int iPlayerPoints; // 可使用点数的数值
	int iProtectCount; // 玩家保护队友的次数
	int iKillCount; // 生还者击杀次数
	int iHeadShotCount; // 生还者爆头击杀次数
	int iHurtCount; // 被感染时对幸存者造成的伤害
}

esPlayerData g_esPlayerData[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Points System",
	author = "McFlurry & evilmaniac and modified by Psykotik",
	description = "Customized edition of McFlurry's points system",
	version = PLUGIN_VERSION,
	url = "http://www.evilmania.net"
}

GlobalForward g_hForward_OnPSLoaded;
GlobalForward g_hForward_OnPSUnloaded;

Database g_hDataBase;

ArrayList g_aModulesArray;

ConVar g_hPluginSettings[11];
ConVar g_hCategoriesEnabled[10];
ConVar g_hPointRewards[25];
ConVar g_hItemCosts[70];
ConVar g_hGameMode;

float g_fVersion;

int g_iMeleeClassCount;
int g_iClipSize_RifleM60;
int g_iClipSize_GrenadeLauncher;

bool g_bIsAllowedGameMode;
bool g_bMapTransition;
bool g_bDatabaseLoaded;
bool g_bInDisconnect[MAXPLAYERS + 1];

char g_sGameMode[64];
char g_sCurrentMap[64];
char g_sSteamId[MAXPLAYERS + 1][32];
char g_sMeleeClass[16][32];

static const char g_sMeleeModels[][] =
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
};

static const char g_sMeleeName[][] =
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
	"riotshield",		//盾牌
};

void InitPlayerData(int client)
{
	if(client <= MaxClients)
	{
		g_esPlayerData[client].bMessageSent = false;
		g_esPlayerData[client].bPointsLoaded = false;
		g_esPlayerData[client].bWitchBurning = false;
		g_esPlayerData[client].bTankBurning = false;

		g_esPlayerData[client].iBoughtCost = 0;
		g_esPlayerData[client].iItemCost = 0;
		g_esPlayerData[client].iPlayerPoints = 0;
		g_esPlayerData[client].iProtectCount 	= 0;
		g_esPlayerData[client].iKillCount = 0;
		g_esPlayerData[client].iHeadShotCount = 0;
		g_esPlayerData[client].iHurtCount = 0;
		InitPlayerData(++client);
	}
}

void InitAllPlayerData()
{
	InitPlayerData(1);
}

void InitPluginSprites()
{
	PrecacheModel("sprites/laserbeam.vmt");
	PrecacheModel("sprites/glow01.vmt");
}

void InitPluginSettings()
{
	g_fVersion = 1.80;

	g_hPluginSettings[hVersion] = CreateConVar("em_points_sys_version", PLUGIN_VERSION, "该服务器上的积分系统版本.", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_REPLICATED);
	g_hPluginSettings[hStartPoints] = CreateConVar("l4d2_points_start", "10", "玩家积分低于该值时将会被重置为该值");
	g_hPluginSettings[hNotifications] = CreateConVar("l4d2_points_notify", "0", "开关提示信息?");
	g_hPluginSettings[hEnabled] = CreateConVar("l4d2_points_enable", "1", "启用积分系统?");
	g_hPluginSettings[hModes] = CreateConVar("l4d2_points_modes", "coop,realism", "哪些游戏模式可以使用积分系统");
	g_hPluginSettings[hTankLimit] = CreateConVar("l4d2_points_tank_limit", "1", "每个队伍允许产生多少只坦克");
	g_hPluginSettings[hWitchLimit] = CreateConVar("l4d2_points_witch_limit", "5", "每个队伍允许产生多少只女巫");
	g_hPluginSettings[hSpawnAttempts] = CreateConVar("l4d2_points_spawn_tries", "2", "特感玩家购买特感允许重试多少次");
	g_hPluginSettings[hKillSpreeNum] = CreateConVar("l4d2_points_cikills", "15", "你需要杀多少普通感染者才能获得杀戮赏金");
	g_hPluginSettings[hHeadShotNum] = CreateConVar("l4d2_points_headshots", "15", "你需要多少次爆头感染者才能获得猎头奖金");
	g_hPluginSettings[hInfectedPlayerLimit] = CreateConVar("l4d2_points_infectedplayer_limit", "2", "允许同时存在多少个被感染者玩家");
}

void InitCategoriesEnabled()
{
	g_hCategoriesEnabled[CategoryRifles] = CreateConVar("l4d2_points_cat_rifles", "1", "启用步枪类别购买");
	g_hCategoriesEnabled[CategorySMG] = CreateConVar("l4d2_points_cat_smg", "1", "启用冲锋枪类别购买");
	g_hCategoriesEnabled[CategorySnipers] = CreateConVar("l4d2_points_cat_snipers", "1", "启用狙击枪类别购买");
	g_hCategoriesEnabled[CategoryShotguns] = CreateConVar("l4d2_points_cat_shotguns", "1", "启动散弹枪类别购买");
	g_hCategoriesEnabled[CategoryHealth] = CreateConVar("l4d2_points_cat_health", "1", "启用医疗急救类别购买");
	g_hCategoriesEnabled[CategoryUpgrades] = CreateConVar("l4d2_points_cat_upgrades", "1", "启用升级包类别购买");
	g_hCategoriesEnabled[CategoryThrowables] = CreateConVar("l4d2_points_cat_throwables", "1", "启用投掷物类别购买");
	g_hCategoriesEnabled[CategoryMisc] = CreateConVar("l4d2_points_cat_misc", "1", "启用杂项类别购买");
	g_hCategoriesEnabled[CategoryMelee] = CreateConVar("l4d2_points_cat_melee", "1", "启用近战类别购买");
	g_hCategoriesEnabled[CategoryWeapons] = CreateConVar("l4d2_points_cat_weapons", "1", "启用武器类别购买");
}

void InitPointRewards()
{
	g_hPointRewards[SurvRewardKillSpree] = CreateConVar("l4d2_points_cikill_value", "3", "击杀一定数量的普通感染者可以获得多少积分");
	g_hPointRewards[SurvRewardHeadShots] = CreateConVar("l4d2_points_headshots_value", "5", "爆头击杀一定数量的感染者可以获得多少积分");
	g_hPointRewards[SurvKillInfec] = CreateConVar("l4d2_points_sikill", "1", "击杀一个特感可以获得多少积分");
	g_hPointRewards[SurvKillTank] = CreateConVar("l4d2_points_tankkill", "5", "击杀一只坦克可以获得多少积分");
	g_hPointRewards[SurvKillWitch] = CreateConVar("l4d2_points_witchkill", "2", "击杀一个女巫可以获得多少积分");
	g_hPointRewards[SurvCrownWitch] = CreateConVar("l4d2_points_witchcrown", "10", "秒杀一个女巫可以获得多少积分");
	g_hPointRewards[SurvTeamHeal] = CreateConVar("l4d2_points_heal", "2", "治疗一个队友可以得到多少积分");
	g_hPointRewards[SurvTeamHealFarm] = CreateConVar("l4d2_points_heal_warning", "0", "治疗一个不需要治疗的队友可以得到多少积分");
	g_hPointRewards[SurvTeamProtect] = CreateConVar("l4d2_points_protect", "5", "保护队友可以得到多少积分");
	g_hPointRewards[SurvTeamRevive] = CreateConVar("l4d2_points_revive", "1", "拉起一个倒地的队友可以得到多少积分");
	g_hPointRewards[SurvTeamLedge] = CreateConVar("l4d2_points_ledge", "1", "拉起一个挂边的队友可以得到多少积分");
	g_hPointRewards[SurvTeamDefib] = CreateConVar("l4d2_points_defib_action", "2", "电击器复活一个队友可以获得多少积分");
	g_hPointRewards[SurvBurnTank] = CreateConVar("l4d2_points_tankburn", "0", "点燃一只坦克可以获得多少积分");
	g_hPointRewards[SurvTankSolo] = CreateConVar("l4d2_points_tanksolo", "5", "单独击杀一只坦克可以获得多少积分");
	g_hPointRewards[SurvBurnWitch] = CreateConVar("l4d2_points_witchburn", "1", "点燃一个女巫可以获得多少积分");
	g_hPointRewards[SurvBileTank] = CreateConVar("l4d2_points_bile_tank", "1", "投掷胆汁命中坦克可以获得多少积分");
	g_hPointRewards[InfecChokeSurv] = CreateConVar("l4d2_points_smoke", "1", "smoker舌头拉住生还者可以获得多少积分");
	g_hPointRewards[InfecPounceSurv] = CreateConVar("l4d2_points_pounce", "1", "hunter扑倒生还者可以获得多少积分");
	g_hPointRewards[InfecChargeSurv] = CreateConVar("l4d2_points_charge", "1", "charge冲撞生还者可以获得多少积分");
	g_hPointRewards[InfecImpactSurv] = CreateConVar("l4d2_points_impact", "1", "spitter吐痰生还者可以获得多少积分");
	g_hPointRewards[InfecRideSurv] = CreateConVar("l4d2_points_ride", "1", "jokey骑乘生还者可以获得多少积分");
	g_hPointRewards[InfecBoomSurv] = CreateConVar("l4d2_points_boom", "1", "boomer喷吐生还者可以获得多少积分");
	g_hPointRewards[InfecIncapSurv] = CreateConVar("l4d2_points_incap", "3", "击倒一个生还者可以获得多少积分");
	g_hPointRewards[InfecHurtSurv] = CreateConVar("l4d2_points_damage", "1", "造成伤害能得到多少积分");
	g_hPointRewards[InfecKillSurv] = CreateConVar("l4d2_points_kill", "20", "击杀一个生还者可以获得多少积分");
}

void InitItemCosts()
{
	g_hItemCosts[CostP220] = CreateConVar("l4d2_points_pistol", "5", "购买小手枪需要多少积分");
	g_hItemCosts[CostMagnum] = CreateConVar("l4d2_points_magnum", "10", "购买马格南手枪需要多少积分");
	g_hItemCosts[CostUzi] = CreateConVar("l4d2_points_smg", "10", "购买乌兹冲锋枪需要多少积分");
	g_hItemCosts[CostSilenced] = CreateConVar("l4d2_points_silenced", "10", "购买消音冲锋枪需要多少积分");
	g_hItemCosts[CostMP5] = CreateConVar("l4d2_points_mp5", "10", "购买MP5冲锋枪需要多少积分");
	g_hItemCosts[CostM16] = CreateConVar("l4d2_points_m16", "12", "购买M16突击步枪需要多少积分");
	g_hItemCosts[CostAK47] = CreateConVar("l4d2_points_ak47", "15", "购买AK47突击步枪需要多少积分");
	g_hItemCosts[CostSCAR] = CreateConVar("l4d2_points_scar", "12", "购买SCAR-H突击步枪需要多少积分");
	g_hItemCosts[CostSG552] = CreateConVar("l4d2_points_sg552", "12", "购买SG552突击步枪需要多少积分");
	g_hItemCosts[CostMilitary] = CreateConVar("l4d2_points_military", "20", "购买30发连发狙击枪需要多少积分");
	g_hItemCosts[CostAWP] = CreateConVar("l4d2_points_awp", "150", "购买awp狙击枪需要多少积分");
	g_hItemCosts[CostScout] = CreateConVar("l4d2_points_scout", "20", "购买侦察狙击步枪(鸟狙)需要多少积分");
	g_hItemCosts[CostHunting] = CreateConVar("l4d2_points_hunting", "20", "购买狩猎狙击步枪(猎枪)需要多少积分");
	g_hItemCosts[CostAuto] = CreateConVar("l4d2_points_auto", "20", "购买一代连喷需要多少积分");
	g_hItemCosts[CostSPAS] = CreateConVar("l4d2_points_spas", "20", "购买二代连喷需要多少积分");
	g_hItemCosts[CostChrome] = CreateConVar("l4d2_points_chrome", "10", "购买二代铁喷需要多少积分");
	g_hItemCosts[CostPump] = CreateConVar("l4d2_points_pump", "10", "购买一代木喷需要多少积分");
	g_hItemCosts[CostGrenade] = CreateConVar("l4d2_points_grenade", "100", "购买榴弹发射器需要多少积分");
	g_hItemCosts[CostM60] = CreateConVar("l4d2_points_m60", "100", "购买M60机枪需要多少积分");
	g_hItemCosts[CostGasCan] = CreateConVar("l4d2_points_gascan", "100", "购买汽油桶需要多少积分");
	g_hItemCosts[CostOxygen] = CreateConVar("l4d2_points_oxygen", "100", "购买氧气罐需要多少积分");
	g_hItemCosts[CostPropane] = CreateConVar("l4d2_points_propane", "100", "购买燃气罐需要多少积分");
	g_hItemCosts[CostGnome] = CreateConVar("l4d2_points_gnome", "15", "购买侏儒人偶需要多少积分");
	g_hItemCosts[CostCola] = CreateConVar("l4d2_points_cola", "100", "购买可乐瓶需要多少积分");
	g_hItemCosts[CostFireworks] = CreateConVar("l4d2_points_fireworks", "100", "购买烟花盒需要多少积分");
	g_hItemCosts[CostKnife] = CreateConVar("l4d2_points_knife", "10", "购买小刀需要多少积分");
	g_hItemCosts[CostCricketbat] = CreateConVar("l4d2_points_cricketbat", "10", "购买板球棒需要多少积分");
	g_hItemCosts[CostCrowbar] = CreateConVar("l4d2_points_crowbar", "10", "购买撬棍需要多少积分");
	g_hItemCosts[CostElectricguitar] = CreateConVar("l4d2_points_electricguitar", "10", "购买电吉他需要多少积分");
	g_hItemCosts[CostFireaxe] = CreateConVar("l4d2_points_fireaxe", "10", "购买消防斧需要多少积分");
	g_hItemCosts[CostFryingpan] = CreateConVar("l4d2_points_fryingpan", "10", "购买平底锅需要多少积分");
	g_hItemCosts[CostGolfclub] = CreateConVar("l4d2_points_golfclub", "10", "购买高尔夫球棍需要多少积分");
	g_hItemCosts[CostBaseballbat] = CreateConVar("l4d2_points_baseballbat", "10", "购买棒球棒需要多少积分");
	g_hItemCosts[CostKatana] = CreateConVar("l4d2_points_katana", "10", "购买武士刀需要多少积分");
	g_hItemCosts[CostMachete] = CreateConVar("l4d2_points_machete", "10", "购买小砍刀需要多少积分");
	g_hItemCosts[CostTonfa] = CreateConVar("l4d2_points_tonfa", "10", "购买警棍需要多少积分");
	g_hItemCosts[CostRiotshield] = CreateConVar("l4d2_points_riotshield", "10", "购买防爆盾牌需要多少积分");
	g_hItemCosts[CostPitchfork] = CreateConVar("l4d2_points_pitchfork", "10", "购买干草叉需要多少积分");
	g_hItemCosts[CostShovel] = CreateConVar("l4d2_points_shovel", "10", "购买铁铲需要多少积分");
	g_hItemCosts[CostCustomMelee] = CreateConVar("l4d2_points_custommelee", "50", "购买第三方近战需要多少积分");
	g_hItemCosts[CostChainsaw] = CreateConVar("l4d2_points_chainsaw", "10", "购买电锯需要多少积分");
	g_hItemCosts[CostPipe] = CreateConVar("l4d2_points_pipe", "10", "购买土制炸弹需要多少积分");
	g_hItemCosts[CostMolotov] = CreateConVar("l4d2_points_molotov", "100", "购买燃烧瓶需要多少积分");
	g_hItemCosts[CostBile] = CreateConVar("l4d2_points_bile", "10", "购买胆汁需要多少积分");
	g_hItemCosts[CostHealthKit] = CreateConVar("l4d2_points_medkit", "25", "购买医疗包需要多少积分");
	g_hItemCosts[CostDefib] = CreateConVar("l4d2_points_defib", "30", "购买电击器需要多少积分");
	g_hItemCosts[CostAdren] = CreateConVar("l4d2_points_adrenaline", "10", "购买肾上腺素需要多少积分");
	g_hItemCosts[CostPills] = CreateConVar("l4d2_points_pills", "10", "购买止痛药需要多少积分");
	g_hItemCosts[CostExplosiveAmmo] = CreateConVar("l4d2_points_explosive_ammo", "15", "购买高爆弹药需要多少积分");
	g_hItemCosts[CostFireAmmo] = CreateConVar("l4d2_points_incendiary_ammo", "15", "购买燃烧弹药需要多少积分");
	g_hItemCosts[CostExplosivePack] = CreateConVar("l4d2_points_explosive_ammo_pack", "20", "购买高爆弹药包需要多少积分");
	g_hItemCosts[CostFirePack] = CreateConVar("l4d2_points_incendiary_ammo_pack", "20", "购买燃烧弹药包需要多少积分");
	g_hItemCosts[CostLaserSight] = CreateConVar("l4d2_points_laser", "10", "购买激光瞄准器需要多少积分");
	g_hItemCosts[CostHeal] = CreateConVar("l4d2_points_survivor_heal", "35", "购买回满血量需要多少积分");
	g_hItemCosts[CostAmmo] = CreateConVar("l4d2_points_refill", "10", "购买弹药补充需要多少积分");

	g_hItemCosts[CostSuicide] = CreateConVar("l4d2_points_suicide", "5", "特感玩家购买自杀需要多少积分");
	g_hItemCosts[CostHunter] = CreateConVar("l4d2_points_hunter", "100", "购买一次成为hunter的机会需要多少积分");
	g_hItemCosts[CostJockey] = CreateConVar("l4d2_points_jockey", "100", "购买一次成为jockey的机会需要多少积分");
	g_hItemCosts[CostSmoker] = CreateConVar("l4d2_points_smoker", "100", "购买一次成为smoker的机会需要多少积分");
	g_hItemCosts[CostCharger] = CreateConVar("l4d2_points_charger", "100", "购买一次成为charger的机会需要多少积分");
	g_hItemCosts[CostBoomer] = CreateConVar("l4d2_points_boomer", "100", "购买一次成为boomer的机会需要多少积分");
	g_hItemCosts[CostSpitter] = CreateConVar("l4d2_points_spitter", "100", "购买一次成为spitter的机会需要多少积分");
	g_hItemCosts[CostInfectedHeal] = CreateConVar("l4d2_points_infected_heal", "100", "感染者治愈自己需要多少积分");
	g_hItemCosts[CostWitch] = CreateConVar("l4d2_points_witch", "100", "购买一次witch需要多少积分");
	g_hItemCosts[CostTank] = CreateConVar("l4d2_points_tank", "2000", "购买一次成为tank的机会需要多少积分");
	g_hItemCosts[CostTankHealMultiplier] = CreateConVar("l4d2_points_tank_heal_mult", "10", "坦克玩家购买治愈相对于其他特感需要多少倍的积分消耗");
	g_hItemCosts[CostHorde] = CreateConVar("l4d2_points_horde", "200", "购买一次horde需要多少积分");
	g_hItemCosts[CostMob] = CreateConVar("l4d2_points_mob", "200", "购买一次mob需要多少积分");
	g_hItemCosts[CostUncommonMob] = CreateConVar("l4d2_points_umob", "200", "购买一次umob需要多少积分");
	g_hItemCosts[CostInfectedSlot] = CreateConVar("l4d2_points_infectedslot", "50", "购买一个感染者槽位需要多少积分");
}

void InitStructures()
{
	InitPluginSettings();
	InitCategoriesEnabled();
	InitPointRewards();
	InitItemCosts();
	InitAllPlayerData();
	InitPluginSprites();
	InitCounterData();
}

void RegisterAdminCommands()
{
	RegAdminCmd("sm_listmodules", ListModules, ADMFLAG_GENERIC, "列出当前加载到积分系统的模块");
	RegAdminCmd("sm_listpoints", ListPoints, ADMFLAG_ROOT, "列出每个玩家的积分数量.");
	RegAdminCmd("sm_heal", Command_Heal, ADMFLAG_SLAY, "sm_heal <目标>给玩家XXX回血");
	RegAdminCmd("sm_givepoints", Command_Points, ADMFLAG_ROOT, "sm_givepoints <目标> [数量]给玩家XXX发XXX数量的积分");
	RegAdminCmd("sm_setpoints", Command_SPoints, ADMFLAG_ROOT, "sm_setpoints <目标> [数量]设置玩家XXX拥有XXX数量的积分");
	RegAdminCmd("sm_delold",	Command_DelOld,	ADMFLAG_ROOT, "sm_delold <天数> 删除超过多少天未上线的玩家记录");
}

void RegisterConsoleCommands()
{
	RegConsoleCmd("sm_buystuff", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_repeatbuy", Command_RBuy, "重复购买上一次购买的物品");
	RegConsoleCmd("sm_buy", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_shop", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_store", BuyMenu, "打开购买菜单(只能在游戏中)");
	RegConsoleCmd("sm_points", ShowPoints, "显示个人积分(只能在游戏中)");
}

void HookEvents()
{
	HookEvent("infected_death", Event_Kill);
	HookEvent("player_incapacitated", Event_Incap);
	HookEvent("player_death", Event_Death);
	HookEvent("tank_killed", Event_TankDeath);
	HookEvent("witch_killed", Event_WitchDeath);
	HookEvent("heal_success", Event_Heal);
	HookEvent("award_earned", Event_Protect);
	HookEvent("revive_success", Event_Revive);
	HookEvent("defibrillator_used", Event_Shock);
	HookEvent("choke_start", Event_Choke);
	HookEvent("player_now_it", Event_Boom);
	HookEvent("lunge_pounce", Event_Pounce);
	HookEvent("jockey_ride", Event_Ride);
	HookEvent("charger_carry_start", Event_Carry);
	HookEvent("charger_impact", Event_Impact);
	HookEvent("player_hurt", Event_Hurt);
	HookEvent("zombie_ignited", Event_Burn);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("map_transition", Event_MapTransition, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_MapTransition, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

bool g_bControlZombies;

public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "control_zombies") == 0)
		g_bControlZombies = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if(strcmp(name, "control_zombies") == 0)
		g_bControlZombies = false;
}

native void CZ_SetSpawnablePZ(int client);
native void CZ_ResetSpawnablePZ();

public void OnPluginStart()
{
	g_aModulesArray = new ArrayList(10); // Reduced from 100 to 10.
	if(g_aModulesArray == null)
		SetFailState("Modules Array Failure");

	AddMultiTargetFilter("@s", FilterSurvivors, "all Survivor players", true);
	AddMultiTargetFilter("@survivor", FilterSurvivors, "all Survivor players", true);
	AddMultiTargetFilter("@survivors", FilterSurvivors, "all Survivor players", true);
	AddMultiTargetFilter("@i", FilterInfected, "all Infected players", true);
	AddMultiTargetFilter("@infected", FilterInfected, "all Infected players", true);

	RegisterAdminCommands();
	RegisterConsoleCommands();
	HookEvents();
	InitStructures();

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(OnGameModeChanged);
	
	if(!g_bDatabaseLoaded)
	{
		g_bDatabaseLoaded = true;
		IniSQLite();
	}
}

public void OnConfigsExecuted()
{
	GetModeCvars();
}

public void OnGameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetModeCvars();
}

void GetModeCvars()
{
	char sEnabledModes[256];
	g_hGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));
	g_hPluginSettings[hModes].GetString(sEnabledModes, sizeof(sEnabledModes));
	g_bIsAllowedGameMode = !!(StrContains(sEnabledModes, g_sGameMode) != -1);
}

void IniSQLite()
{	
	char Error[1024];
	if((g_hDataBase = SQLite_UseDatabase("PointsSystem", Error, sizeof(Error))) == null)
		SetFailState("Could not connect to the database \"PointsSystem\" at the following error:\n%s", Error);
	else
		SQL_FastQuery(g_hDataBase, "CREATE TABLE IF NOT EXISTS PS_Core(SteamID NVARCHAR(32) NOT NULL DEFAULT '', PlayerName NVARCHAR(128) NOT NULL DEFAULT '', Points INT NOT NULL DEFAULT 0, UnixTime INT NOT NULL DEFAULT 0);");
}

int GetAttackerIndex(Event event)
{
	return GetClientOfUserId(event.GetInt("attacker"));
}

int GetClientIndex(Event event)
{
	return GetClientOfUserId(event.GetInt("userid"));
}

bool IsClientPlaying(int client)
{
	return client && IsClientInGame(client) && GetClientTeam(client) > 1;
}

bool IsRealClient(int client)
{
	return client && IsClientInGame(client) && !IsFakeClient(client);
}

bool IsGhost(int client)
{
	return client && GetEntProp(client, Prop_Send, "m_isGhost") == 1;
}

bool IsTank(int client)
{
	return client && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

bool IsSurvivor(int client)
{
	return client && GetClientTeam(client) == 2;
}

bool IsInfected(int client)
{
	return client && GetClientTeam(client) == 3;
}

bool IsModEnabled()
{
	return g_hPluginSettings[hEnabled].IntValue == 1 && g_bIsAllowedGameMode;
}

void SetStartPoints(int client)
{
	g_esPlayerData[client].iPlayerPoints = g_hPluginSettings[hStartPoints].IntValue;
}

void AddPoints(int client, int iPoints, const char[] sMessage)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client))
	{
		g_esPlayerData[client].iPlayerPoints += iPoints;
		if(g_hPluginSettings[hNotifications].BoolValue)
			PrintToChat(client, "%s %T", MSGTAG, sMessage, client, iPoints);
	}
}

void RemovePoints(int client, int iPoints)
{
	g_esPlayerData[client].iPlayerPoints -= iPoints;
}

public bool FilterSurvivors(const char[] pattern, Handle clients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
			PushArrayCell(clients, i);
	}

	return true;
}

public bool FilterInfected(const char[] pattern, Handle clients)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3)
			PushArrayCell(clients, i);
	}

	return true;
}

public void OnAllPluginsLoaded()
{
	Call_StartForward(g_hForward_OnPSLoaded);
	Call_Finish();
}

public void OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));

	InitPluginSprites();

	PrecacheModel("models/w_models/v_rif_m60.mdl", true);
	PrecacheModel("models/w_models/weapons/w_m60.mdl", true);
	PrecacheModel("models/v_models/v_m60.mdl", true);
	PrecacheModel("models/infected/witch_bride.mdl", true);
	PrecacheModel("models/infected/witch.mdl", true);
	PrecacheModel("models/infected/common_male_riot.mdl", true);
	PrecacheModel("models/infected/common_male_ceda.mdl", true);
	PrecacheModel("models/infected/common_male_clown.mdl", true);
	PrecacheModel("models/infected/common_male_mud.mdl", true);
	PrecacheModel("models/infected/common_male_roadcrew.mdl", true);
	PrecacheModel("models/infected/common_male_fallen_survivor.mdl", true);

	int i;
	int iLen;

	iLen = sizeof(g_sMeleeModels);
	for(i = 0; i < iLen; i++)
	{
		if(!IsModelPrecached(g_sMeleeModels[i]))
			PrecacheModel(g_sMeleeModels[i], true);
	}

	iLen = sizeof(g_sMeleeName);
	char sBuffer[64];
	for(i = 0; i < iLen; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "scripts/melee/%s.txt", g_sMeleeName[i]);
		if(!IsGenericPrecached(sBuffer))
			PrecacheGeneric(sBuffer, true);
	}
	
	GetMeleeClasses();
}

stock void GetMeleeClasses()
{
	int iMeleeStringTable = FindStringTable("MeleeWeapons");
	g_iMeleeClassCount = GetStringTableNumStrings(iMeleeStringTable);

	for(int i; i < g_iMeleeClassCount; i++)
		ReadStringTable(iMeleeStringTable, i, g_sMeleeClass[i], sizeof(g_sMeleeClass[]));
}

public Action ListPoints(int client, int iNumArguments)
{
	if(iNumArguments == 0)
	{
		for(int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if(IsClientInGame(iPlayer) && !IsFakeClient(iPlayer)) 
				ReplyToCommand(client, "%s %N: %d", MSGTAG, iPlayer, g_esPlayerData[iPlayer].iPlayerPoints);
		}
	}
	return Plugin_Handled;
}

public Action ListModules(int client, int iNumArguments)
{
	if(iNumArguments == 0)
	{
		ReplyToCommand(client, "%s %T", MSGTAG, "Modules", client);

		int iNumModules = g_aModulesArray.Length;
		for(int iModule; iModule < iNumModules; iModule++)
		{
			char sModuleName[MODULES_SIZE];
			g_aModulesArray.GetString(iModule, sModuleName, MODULES_SIZE);
			if(strlen(sModuleName) > 0)
				ReplyToCommand(client, sModuleName);
		}
	}
	return Plugin_Handled;
}

void LoadTranslationFiles()
{
	LoadTranslations("core.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("points_system.phrases");
	LoadTranslations("points_system_menus.phrases");
}

void CreateNatives()
{
	RegPluginLibrary("ps_natives");

	g_hForward_OnPSLoaded = new GlobalForward("OnPSLoaded", ET_Ignore);
	g_hForward_OnPSUnloaded = new GlobalForward("OnPSUnloaded", ET_Ignore);

	CreateNative("PS_IsSystemEnabled", Native_PS_IsSystemEnabled);
	CreateNative("PS_GetVersion", Native_PS_GetVersion);
	CreateNative("PS_SetPoints", Native_PS_SetPoints);
	CreateNative("PS_SetItem", Native_PS_SetItem);
	CreateNative("PS_SetCost", Native_PS_SetCost);
	CreateNative("PS_SetBought", Native_PS_SetBought);
	CreateNative("PS_SetBoughtCost", Native_PS_SetBoughtCost);
	CreateNative("PS_SetupUMob", Native_PS_SetupUMob);
	CreateNative("PS_GetPoints", Native_PS_GetPoints);
	CreateNative("PS_GetBoughtCost", Native_PS_GetBoughtCost);
	CreateNative("PS_GetCost", Native_PS_GetCost);
	CreateNative("PS_GetItem", Native_PS_GetItem);
	CreateNative("PS_GetBought", Native_PS_GetBought);
	CreateNative("PS_RegisterModule", Native_PS_RegisterModule);
	CreateNative("PS_UnregisterModule", Native_PS_UnregisterModule);
	CreateNative("PS_RemovePoints", Native_PS_RemovePoints);
}

//l4d_info_editor
forward void OnGetWeaponsInfo(int pThis, const char[] classname);
native void InfoEditor_GetString(int pThis, const char[] keyname, char[] dest, int destLen);

/**
 * @link https://sm.alliedmods.net/new-api/sourcemod/AskPluginLoad2
 *
 * @param hPlugin Handle to the plugin.
 * @param bLate Whether or not the plugin was loaded "late" (after map load).
 * @param sError Error message buffer in case load failed.
 * @param iErrorSize Maximum number of characters for error message buffer.
 *
 * @return APLRes_Success for load success, APLRes_Failure or APLRes_SilentFailure otherwise
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	LoadTranslationFiles();

	CreateNatives();
	MarkNativeAsOptional("InfoEditor_GetString");
	return APLRes_Success;
}

public void OnGetWeaponsInfo(int pThis, const char[] classname)
{
	static char sResult[64];
	if(strcmp(classname, "weapon_rifle_m60") == 0)
	{
		InfoEditor_GetString(pThis, "clip_size", sResult, sizeof(sResult));
		g_iClipSize_RifleM60 = StringToInt(sResult);
	}
	else if(strcmp(classname, "weapon_grenade_launcher") == 0)
	{
		InfoEditor_GetString(pThis, "clip_size", sResult, sizeof(sResult));
		g_iClipSize_GrenadeLauncher = StringToInt(sResult);
	}
}

public void OnPluginEnd()
{
	SQL_SaveAll();

	Call_StartForward(g_hForward_OnPSUnloaded);
	Call_Finish();
}

public int Native_PS_IsSystemEnabled(Handle plugin, int numParams)
{
	return IsModEnabled();
}

public int Native_PS_RemovePoints(Handle plugin, int numParams)
{
	RemovePoints(GetNativeCell(1), GetNativeCell(2));
}

public int Native_PS_RegisterModule(Handle plugin, int numParams)
{
	int iNumModules = g_aModulesArray.Length;

	char sNewModuleName[MODULES_SIZE];
	GetNativeString(1, sNewModuleName, MODULES_SIZE);

	// Make sure the module is not already loaded
	for(int iModule; iModule < iNumModules; iModule++)
	{
		char sModuleName[MODULES_SIZE];
		g_aModulesArray.GetString(iModule, sModuleName, MODULES_SIZE);
		if(strcmp(sModuleName, sNewModuleName) == 0)
			return false;
	}

	g_aModulesArray.PushString(sNewModuleName);
	return true;
}

public int Native_PS_UnregisterModule(Handle plugin, int numParams)
{
	int iNumModules = g_aModulesArray.Length;

	char sUnloadModuleName[MODULES_SIZE];
	GetNativeString(1, sUnloadModuleName, MODULES_SIZE);

	for(int iModule; iModule < iNumModules; iModule++)
	{
		char sModuleName[MODULES_SIZE];
		g_aModulesArray.GetString(iModule, sModuleName, MODULES_SIZE);
		if(strcmp(sModuleName, sUnloadModuleName) == 0)
		{
			g_aModulesArray.Erase(iModule);
			return true;
		}
	}
	return false;
}

public any Native_PS_GetVersion(Handle plugin, int numParams)
{
	return g_fVersion;
}

public int Native_PS_SetPoints(Handle plugin, int numParams)
{
	g_esPlayerData[GetNativeCell(1)].iPlayerPoints = GetNativeCell(2);
}

public int Native_PS_SetItem(Handle plugin, int numParams)
{
	GetNativeString(2, g_esPlayerData[GetNativeCell(1)].sItemName, 64);
}

public int Native_PS_SetCost(Handle plugin, int numParams)
{
	g_esPlayerData[GetNativeCell(1)].iItemCost = GetNativeCell(2);
}

public int Native_PS_SetBought(Handle plugin, int numParams)
{
	GetNativeString(2, g_esPlayerData[GetNativeCell(1)].sBought, 64);
}

public int Native_PS_SetBoughtCost(Handle plugin, int numParams)
{
	g_esPlayerData[GetNativeCell(1)].iBoughtCost = GetNativeCell(2);
}

public int Native_PS_SetupUMob(Handle plugin, int numParams)
{
	g_iCounterData[iUCommonLeft] = GetNativeCell(1);
}

public int Native_PS_GetPoints(Handle plugin, int numParams)
{
	return g_esPlayerData[GetNativeCell(1)].iPlayerPoints;
}

public int Native_PS_GetCost(Handle plugin, int numParams)
{
	return g_esPlayerData[GetNativeCell(1)].iItemCost;
}

public int Native_PS_GetBoughtCost(Handle plugin, int numParams)
{
	return g_esPlayerData[GetNativeCell(1)].iBoughtCost;
}

public int Native_PS_GetItem(Handle plugin, int numParams)
{
	SetNativeString(2, g_esPlayerData[GetNativeCell(1)].sItemName, GetNativeCell(3));
}

public int Native_PS_GetBought(Handle plugin, int numParams)
{
	SetNativeString(2, g_esPlayerData[GetNativeCell(1)].sBought, 64);
}

void ResetClientData(int client)
{
	g_esPlayerData[client].iKillCount = 0;
	g_esPlayerData[client].iHurtCount = 0;
	g_esPlayerData[client].iProtectCount = 0;
	g_esPlayerData[client].iHeadShotCount = 0;
	g_esPlayerData[client].bMessageSent = false;
}

//https://forums.alliedmods.net/showthread.php?t=320247
public void OnClientAuthorized(int client, const char[] auth)
{
	// TODO: validate "auth" arg. instead of GetClientAuthId()
	// https://sm.alliedmods.net/new-api/clients/OnClientAuthorized
	
	if(client)
		CacheSteamID(client);
}

bool CacheSteamID(int client)
{
	if(g_sSteamId[client][0] == '\0')
	{
		if(!GetClientAuthId(client, AuthId_Steam2, g_sSteamId[client], sizeof(g_sSteamId[])))
			return false;
	}
	return true;
}

public void OnClientDisconnect(int client)
{
	if(g_bMapTransition == true || g_bInDisconnect[client] == true)
		return;
		
	g_bInDisconnect[client] = true;

	if(client && IsClientInGame(client) && !IsFakeClient(client))
		SQL_Save(client);
}

public void OnClientDisconnect_Post(int client)
{
	g_sSteamId[client][0] = '\0';
	ResetClientData(client);
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	g_bMapTransition = true;
	SQL_SaveAll();
}

void SQL_SaveAll()
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i))
			SQL_Save(i);
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client) || g_bInDisconnect[client] == true)
		return;

	g_bInDisconnect[client] = true;

	SQL_Save(client);
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;

	g_bInDisconnect[client] = false;
	ResetClientData(client);
	SetStartPoints(client);
	CreateTimer(0.5, Timer_OnClientPost, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_OnClientPost(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client))
		SQL_Load(client);
}

void SQL_Save(int client)
{
	if(!CacheSteamID(client))
		return;
	
	static char sQuery[1024];
	static char sPlayerName[MAX_NAME_LENGTH];
	FormatEx(sPlayerName, sizeof(sPlayerName), "%N", client);

	FormatEx(sQuery, sizeof(sQuery), "UPDATE PS_Core SET PlayerName = '%s', Points = %d, UnixTime = %d WHERE SteamID = '%s';", sPlayerName, g_esPlayerData[client].iPlayerPoints, GetTime(), g_sSteamId[client]);
	SQL_FastQuery(g_hDataBase, sQuery);
}

void SQL_Load(int client)
{
	if(!CacheSteamID(client))
		return;
	
	static char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "SELECT * FROM PS_Core WHERE SteamId = '%s';", g_sSteamId[client]);
	SQL_TQuery(g_hDataBase, LoadPlayerData, sQuery, GetClientUserId(client));
}

public void LoadPlayerData(Handle db, Handle results, const char[] error, any client)
{
	if(results == null || (client = GetClientOfUserId(client)) == 0)
		return;

	if(SQL_HasResultSet(results) && SQL_FetchRow(results))
		g_esPlayerData[client].iPlayerPoints = SQL_FetchInt(results, 2);
	else
	{
		static char sQuery[1024];
		static char sPlayerName[MAX_NAME_LENGTH];
		FormatEx(sPlayerName, sizeof(sPlayerName), "%N", client);

		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO PS_Core(SteamID, PlayerName, Points, UnixTime) VALUES ('%s', '%s', %d, %d);", g_sSteamId[client], sPlayerName, g_esPlayerData[client].iPlayerPoints, GetTime());
		SQL_FastQuery(g_hDataBase, sQuery);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bMapTransition = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	InitCounterData();
	SQL_SaveAll();
}

void EventHeadShots(int client)
{
	int iHeadShotReward = g_hPointRewards[SurvRewardHeadShots].IntValue;
	if(iHeadShotReward > 0)
	{
		int iHeadShotsRequired = g_hPluginSettings[hHeadShotNum].IntValue;
		g_esPlayerData[client].iHeadShotCount++;
		if(g_esPlayerData[client].iHeadShotCount >= iHeadShotsRequired)
		{
			AddPoints(client, iHeadShotReward, "Head Hunter");
			g_esPlayerData[client].iHeadShotCount -= iHeadShotsRequired;
		}
	}
}

void EventKillSpree(int client)
{
	int iKillSpreeReward = g_hPointRewards[SurvRewardKillSpree].IntValue;
	if(iKillSpreeReward > 0)
	{
		int iKillSpreeRequired = g_hPluginSettings[hKillSpreeNum].IntValue;
		g_esPlayerData[client].iKillCount++;
		if(g_esPlayerData[client].iKillCount >= iKillSpreeRequired)
		{
			AddPoints(client, iKillSpreeReward, "Killing Spree");
			g_esPlayerData[client].iKillCount -= iKillSpreeRequired;
		}
	}
}

public void Event_Kill(Event event, const char[] name, bool dontBroadcast)
{
	int iAttackerIndex = GetAttackerIndex(event);
	if(IsModEnabled() && IsRealClient(iAttackerIndex))
	{
		if(IsSurvivor(iAttackerIndex))
		{
			if(event.GetBool("headshot"))
				EventHeadShots(iAttackerIndex);

			EventKillSpree(iAttackerIndex);
		}
	}
}

public void Event_Incap(Event event, const char[] name, bool dontBroadcast)
{
	int iAttackerIndex = GetAttackerIndex(event);
	if(IsModEnabled() && IsRealClient(iAttackerIndex))
	{
		if(IsInfected(iAttackerIndex))
		{
			int iIncapPoints = g_hPointRewards[InfecIncapSurv].IntValue;
			if(iIncapPoints > 0)
				AddPoints(iAttackerIndex, iIncapPoints, "Incapped Survivor");
		}
	}
}

public void Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int iAttackerIndex = GetAttackerIndex(event);
	if(IsModEnabled() && IsRealClient(iAttackerIndex))
	{
		int iVictimIndex = GetClientIndex(event);
		if(IsSurvivor(iAttackerIndex))
		{
			int iInfectedKilledReward = g_hPointRewards[SurvKillInfec].IntValue;
			if(iInfectedKilledReward > 0)
			{
				if(IsInfected(iVictimIndex))
				{ // If the person killed by the survivor is infected
					if(IsTank(iVictimIndex)) // Ignore tank death since it is handled elsewhere
						return;
					else
					{
						EventHeadShots(iAttackerIndex);
						AddPoints(iAttackerIndex, iInfectedKilledReward, "Killed SI");
					}
				}
			}
		}
		else if(IsInfected(iAttackerIndex))
		{
			int iSurvivorKilledReward = g_hPointRewards[InfecKillSurv].IntValue;
			if(iSurvivorKilledReward > 0)
			{
				if(IsSurvivor(iVictimIndex)) // If the person killed by the infected is a survivor
					AddPoints(iAttackerIndex, iSurvivorKilledReward, "Killed Survivor");
			}
		}
	}
}

void EventTankKilled()
{
	int iTankKilledReward = g_hPointRewards[SurvKillTank].IntValue;
	if(iTankKilledReward > 0)
		TankKilledPoints(1, iTankKilledReward, "Killed Tank");
}

void TankKilledPoints(int client, int iPoints, const char[] sMessage)
{
	if(client > 0 && MaxClients >= client)
	{
		if(IsRealClient(client) && IsSurvivor(client) && IsPlayerAlive(client))
			AddPoints(client, iPoints, sMessage);

		TankKilledPoints(++client, iPoints, sMessage);
	}
}

public void Event_TankDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iAttackerIndex = GetAttackerIndex(event);
	if(IsModEnabled() && IsRealClient(iAttackerIndex))
	{
		if(IsSurvivor(iAttackerIndex))
		{
			if(event.GetBool("solo")) // If kill was solo
			{
				int iTankSoloReward = g_hPointRewards[SurvTankSolo].IntValue; // Points to be rewarded for killing a tank, solo
				if(iTankSoloReward > 0) // If solo kill reward is enabled
					AddPoints(iAttackerIndex, iTankSoloReward, "TANK SOLO");
			}
			else
				EventTankKilled(); // Reward survivors for killing a tank
		}
	}
	g_esPlayerData[iAttackerIndex].bTankBurning = false;
}

public void Event_WitchDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client))
	{
		if(IsSurvivor(client))
		{
			int iWitchKilledReward = g_hPointRewards[SurvKillWitch].IntValue;
			if(iWitchKilledReward > 0)
				AddPoints(client, iWitchKilledReward, "Killed Witch");

			if(event.GetBool("oneshot"))
			{
				int iWitchCrownedReward = g_hPointRewards[SurvCrownWitch].IntValue;
				if(iWitchCrownedReward > 0)
					AddPoints(client, iWitchCrownedReward, "Crowned Witch");
			}
		}
	}
	g_esPlayerData[client].bWitchBurning = false;
}

public void Event_Heal(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client))
	{
		if(IsSurvivor(client))
		{
			if(client != GetClientOfUserId(event.GetInt("subject")))
			{ // If player did not heal himself with the medkit
				if(event.GetInt("health_restored") > 39)
				{
					int iHealTeamReward = g_hPointRewards[SurvTeamHeal].IntValue;
					if(iHealTeamReward > 0)
						AddPoints(client, iHealTeamReward, "Team Heal");
				}
				else
				{
					int iHealTeamReward = g_hPointRewards[SurvTeamHealFarm].IntValue;
					if(iHealTeamReward > 0)
						AddPoints(client, iHealTeamReward, "Team Heal Warning");
				}
			}
		}
	}
}

void EventProtect(int client)
{
	int iProtectReward = g_hPointRewards[SurvTeamProtect].IntValue;
	if(iProtectReward > 0)
	{
		g_esPlayerData[client].iProtectCount++;
		if(g_esPlayerData[client].iProtectCount == 6)
		{
			AddPoints(client, iProtectReward, "Protect");
			g_esPlayerData[client].iProtectCount -= 6;
		}
	}
}

public void Event_Protect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client) && IsSurvivor(client) && event.GetInt("award") == 67)
		EventProtect(client);
}

public void Event_Revive(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client) && IsSurvivor(client) && client != GetClientOfUserId(event.GetInt("subject")))
	{
		if(event.GetBool("ledge_hang"))
		{
			int iLedgeReviveReward = g_hPointRewards[SurvTeamLedge].IntValue;
			if(iLedgeReviveReward > 0)
				AddPoints(client, iLedgeReviveReward, "Ledge Revive");
		}
		else
		{
			int iReviveReward = g_hPointRewards[SurvTeamRevive].IntValue;
			if(iReviveReward > 0)
				AddPoints(client, iReviveReward, "Revive");
		}
	}
}

public void Event_Shock(Event event, const char[] name, bool dontBroadcast)
{ // Defib
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client) && IsSurvivor(client))
	{
		int iDefibReward = g_hPointRewards[SurvTeamDefib].IntValue;
		if(iDefibReward > 0)
			AddPoints(client, iDefibReward, "Defib");
	}
}

public void Event_Choke(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client) && IsInfected(client))
	{
		int iChokeReward = g_hPointRewards[InfecChokeSurv].IntValue;
		if(iChokeReward > 0)
			AddPoints(client, iChokeReward, "Smoke");
	}
}

public void Event_Boom(Event event, const char[] name, bool dontBroadcast)
{
	int iAttackerIndex = GetAttackerIndex(event);
	if(IsModEnabled() && IsRealClient(iAttackerIndex))
	{
		if(IsInfected(iAttackerIndex)) // If boomer biles survivors
		{ 
			int iBoomedReward = g_hPointRewards[InfecBoomSurv].IntValue;
			if(iBoomedReward > 0)
				AddPoints(iAttackerIndex, iBoomedReward, "Boom");
		}
		else if(IsSurvivor(iAttackerIndex)) // If survivor biles a tank
		{
			int iBiledReward = g_hPointRewards[SurvBileTank].IntValue;
			if(iBiledReward > 0)
			{
				if(IsTank(GetClientIndex(event)))
					AddPoints(iAttackerIndex, iBiledReward, "Biled");
			}
		}
	}
}

public void Event_Pounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client) && IsInfected(client))
	{
		int iPounceReward = g_hPointRewards[InfecPounceSurv].IntValue;
		if(iPounceReward > 0)
			AddPoints(client, iPounceReward, "Pounce");
	}
}

public void Event_Ride(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client) && IsInfected(client))
	{
		int iRideReward = g_hPointRewards[InfecRideSurv].IntValue;
		if(iRideReward > 0)
			AddPoints(client, iRideReward, "Jockey Ride");
	}
}

public void Event_Carry(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client))
	{
		if(IsInfected(client))
		{
			int iCarryReward = g_hPointRewards[InfecChargeSurv].IntValue;
			if(iCarryReward > 0)
				AddPoints(client, iCarryReward, "Charge");
		}
	}
}

public void Event_Impact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client) && IsInfected(client))
	{
		int iImpactReward = g_hPointRewards[InfecImpactSurv].IntValue;
		if(iImpactReward > 0)
			AddPoints(client, iImpactReward, "Charge Collateral");
	}
}

public void Event_Burn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientIndex(event);
	if(IsModEnabled() && IsRealClient(client))
	{
		if(IsSurvivor(client))
		{
			char sVictimName[30];
			event.GetString("victimname", sVictimName, sizeof(sVictimName));
			if(!strcmp(sVictimName, "Tank", false))
			{
				int iTankBurnReward = g_hPointRewards[SurvBurnTank].IntValue;
				if(iTankBurnReward > 0)
				{
					if(!g_esPlayerData[client].bTankBurning)
					{
						g_esPlayerData[client].bTankBurning = true;
						AddPoints(client, iTankBurnReward, "Burn Tank");
					}
				}
			}
			else if(!strcmp(sVictimName, "Witch", false))
			{
				int iWitchBurnReward = g_hPointRewards[SurvBurnWitch].IntValue;
				if(iWitchBurnReward > 0)
				{
					if(!g_esPlayerData[client].bWitchBurning)
					{
						g_esPlayerData[client].bWitchBurning = true;
						AddPoints(client, iWitchBurnReward, "Burn Witch");
					}
				}
			}
		}
	}
}

void EventSpit(int client, int iPoints)
{
	if(g_esPlayerData[client].iHurtCount >= 8)
	{
		AddPoints(client, iPoints, "Spit Damage");
		g_esPlayerData[client].iHurtCount -= 8;
	}
}

void EventDamage(int client, int iPoints)
{
	if(g_esPlayerData[client].iHurtCount >= 3)
	{
		AddPoints(client, iPoints, "Damage");
		g_esPlayerData[client].iHurtCount -= 3;
	}
}

bool IsFireDamage(int iDamageType)
{
	return iDamageType == 8 || iDamageType == 2056;
}

bool IsSpitterDamage(int iDamageType)
{
   return iDamageType == 263168 || iDamageType == 265216;
}

public void Event_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	int iAttackerIndex = GetAttackerIndex(event);
	if(IsModEnabled() && IsRealClient(iAttackerIndex))
	{
		if(IsInfected(iAttackerIndex) && IsSurvivor(GetClientIndex(event)))
		{
			g_esPlayerData[iAttackerIndex].iHurtCount++;
			int iSurvivorDamagedReward = g_hPointRewards[InfecHurtSurv].IntValue;
			if(iSurvivorDamagedReward > 0)
			{
				int iDamageType = event.GetInt("type");
				if(IsFireDamage(iDamageType)) // If infected is dealing fire damage, ignore
					return;
				else if(IsSpitterDamage(iDamageType))
					EventSpit(iAttackerIndex, iSurvivorDamagedReward);
				else
				{
					if(!IsSpitterDamage(iDamageType))
						EventDamage(iAttackerIndex, iSurvivorDamagedReward);
				}
			}
		}
	}
}

public Action BuyMenu(int client, int iNumArguments)
{
	if(IsModEnabled() && iNumArguments == 0)
	{
		if(IsClientPlaying(client))
			BuildBuyMenu(client);
	}
	return Plugin_Handled;
}

public Action ShowPoints(int client, int iNumArguments)
{
	if(IsModEnabled() && iNumArguments == 0)
	{
		if(IsClientPlaying(client))
			ReplyToCommand(client, "%s %T", MSGTAG, "Your Points", client, g_esPlayerData[client].iPlayerPoints);
	}
	return Plugin_Handled;
}

bool CheckPurchase(int client, int iCost)
{
	return client > 0 && IsItemEnabled(client, iCost) && HasEnoughPoints(client, iCost);
}

bool IsItemEnabled(int client, int iCost)
{
	if(client > 0)
	{
		if(iCost >= 0)
			return true;
		else
		{
			ReplyToCommand(client, "%s %T", MSGTAG, "Item Disabled", client);
			return false;
		}
	}
	return false;
}

bool HasEnoughPoints(int client, int iCost)
{
	if(client > 0)
	{
		if(g_esPlayerData[client].iPlayerPoints >= iCost)
			return true;
		else
		{
			ReplyToCommand(client, "%s %T", MSGTAG, "Insufficient Funds", client);
			return false;
		}
	}
	return false;
}

void JoinInfected(int client, int iCost)
{
	if(IsRealClient(client))
	{
		if(IsSurvivor(client))
		{
			ChangeClientTeam(client, 3);
			RemovePoints(client, iCost);
		}
	}
}

void PerformSuicide(int client, int iCost)
{
	if(IsRealClient(client))
	{
		if(IsInfected(client))
		{
			ForcePlayerSuicide(client);
			RemovePoints(client, iCost);
		}
	}
}

public Action Command_RBuy(int client, int iNumArguments)
{
	if(client > 0 && iNumArguments == 0)
	{
		if(IsRealClient(client) && GetClientTeam(client) > 1)
		{
			if(CheckPurchase(client, g_esPlayerData[client].iItemCost))
			{ // Check if item is Enabled & Player has points
				if(!strcmp(g_esPlayerData[client].sItemName, "suicide", false))
				{
					PerformSuicide(client, g_esPlayerData[client].iItemCost);
					return Plugin_Handled;
				}
				else
				{ // If we are not dealing with a suicide
					if(!strcmp(g_esPlayerData[client].sItemName, "give ammo", false))
						ReloadAmmo(client, g_esPlayerData[client].iItemCost, g_esPlayerData[client].sItemName);
					else
					{
						RemovePoints(client, g_esPlayerData[client].iItemCost);
						//do additional actions for certain items
						if(!strcmp(g_esPlayerData[client].sItemName, "z_spawn_old mob", false))
							g_iCounterData[iUCommonLeft] += FindConVar("z_common_limit").IntValue;
						else
							CheatCommand(client, g_esPlayerData[client].sItemName);
					}
					return Plugin_Handled;
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_Heal(int client, int args)
{
	if(args == 0)
	{
		CheatCommand(client, "give health");
		return Plugin_Handled;
	}
	else if(args == 1)
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
			ShowActivity2(client, MSGTAG, " %t", "Give Health", target_name);

			for (int i = 0; i < target_count; i++)
			{
				int targetclient = target_list[i];
				CheatCommand(targetclient, "give health");
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

public Action Command_Points(int client, int args)
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
		else
		{
			for (int i = 0; i < target_count; i++)
			{
				targetclient = target_list[i];
				g_esPlayerData[targetclient].iPlayerPoints += amount;
				SQL_Save(targetclient);
				ReplyToCommand(client, "%s %T", MSGTAG, "Give Points", client, amount, targetclient);
				ReplyToCommand(targetclient, "%s %T", MSGTAG, "Give Target", targetclient, client, amount);
			}
			return Plugin_Handled;
		}
	}
	else
	{
		ReplyToCommand(client, "%s %T", MSGTAG, "Usage sm_givepoints", client);
		return Plugin_Handled;
	}
}

public Action Command_SPoints(int client, int args)
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
		else
		{
			//ShowActivity2(client, MSGTAG, "%t", "Set Points", target_name, amount);
			for (int i = 0; i < target_count; i++)
			{
				targetclient = target_list[i];
				g_esPlayerData[targetclient].iPlayerPoints = amount;
				SQL_Save(targetclient);
				ReplyToCommand(client, "%s %T", MSGTAG, "Set Points", client, targetclient, amount);
				ReplyToCommand(targetclient, "%s %T", MSGTAG, "Set Target", targetclient, client, amount);
			}
			return Plugin_Handled;
		}
	}
	else
	{
		ReplyToCommand(client, "%s %T", MSGTAG, "Usage sm_setpoints", client, MSGTAG);
		return Plugin_Handled;
	}
}

public Action Command_DelOld(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "sm_delold <days>");
		return Plugin_Handled;
	}
	
	char sDays[8];
	GetCmdArg(1, sDays, sizeof(sDays));
	int iDays = StringToInt(sDays);
	
	int iUnixTime = GetTime();
	iUnixTime -= iDays * 60 * 60 * 24;
	
	char sQuery[1024];
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM PS_Core WHERE UnixTime < %i;", iUnixTime);
	SQL_FastQuery(g_hDataBase, sQuery);
	return Plugin_Handled;
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
}

void BuildBuyMenu(int client)
{
	if(GetClientTeam(client) == 2)
	{
		char sInfo[32];
		Menu menu = new Menu(TopMenu);
		if(g_hCategoriesEnabled[CategoryWeapons].IntValue == 1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Weapons", client);
			menu.AddItem("g_WeaponsMenu", sInfo);
		}
		if(g_hCategoriesEnabled[CategoryUpgrades].IntValue == 1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Upgrades", client);
			menu.AddItem("g_UpgradesMenu", sInfo);
		}
		if(g_hCategoriesEnabled[CategoryHealth].IntValue == 1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Health", client);
			menu.AddItem("g_HealthMenu", sInfo);
		}
		if(g_hItemCosts[CostInfectedSlot].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "InfectedSlot", client);
			menu.AddItem("g_InfectedSlot", sInfo);
		}
		
		FormatEx(sInfo, sizeof(sInfo), "%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
		menu.SetTitle(sInfo);
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else if(GetClientTeam(client) == 3)
	{
		char sInfo[32];
		Menu menu = new Menu(InfectedMenu);
		if(g_hItemCosts[CostInfectedHeal].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Heal", client);
			menu.AddItem("heal", sInfo);
		}
		if(g_hItemCosts[CostSuicide].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Suicide", client);
			menu.AddItem("suicide", sInfo);
		}
		if(g_hItemCosts[CostBoomer].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Boomer", client);
			menu.AddItem("boomer", sInfo);
		}
		if(g_hItemCosts[CostSpitter].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Spitter", client);
			menu.AddItem("spitter", sInfo);
		}
		if(g_hItemCosts[CostSmoker].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Smoker", client);
			menu.AddItem("smoker", sInfo);
		}
		if(g_hItemCosts[CostHunter].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Hunter", client);
			menu.AddItem("hunter", sInfo);
		}
		if(g_hItemCosts[CostCharger].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Charger", client);
			menu.AddItem("charger", sInfo);
		}
		if(g_hItemCosts[CostJockey].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Jockey", client);
			menu.AddItem("jockey", sInfo);
		}
		if(g_hItemCosts[CostTank].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Tank", client);
			menu.AddItem("tank", sInfo);
		}
		if(!strcmp(g_sCurrentMap, "c6m1_riverbank", false) && g_hItemCosts[CostWitch].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Witch Bride", client);
			menu.AddItem("witch_bride", sInfo);
		}
		else if(g_hItemCosts[CostWitch].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Witch", client);
			menu.AddItem("witch", sInfo);
		}
		if(g_hItemCosts[CostHorde].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Horde", client);
			menu.AddItem("horde", sInfo);
		}
		if(g_hItemCosts[CostMob].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Mob", client);
			menu.AddItem("mob", sInfo);
		}
		if(g_hItemCosts[CostUncommonMob].IntValue > -1)
		{
			FormatEx(sInfo, sizeof(sInfo), "%T", "Uncommon Mob", client);
			menu.AddItem("uncommon_mob", sInfo);
		}
		FormatEx(sInfo, sizeof(sInfo), "%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
		menu.SetTitle(sInfo);
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

void BuildWeaponsMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler);
	menu.ExitBackButton = true;
	if(g_hCategoriesEnabled[CategoryMelee].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Melee", client);
		menu.AddItem("g_MeleeMenu", sInfo);
	}
	if(g_hCategoriesEnabled[CategorySnipers].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Sniper Rifles", client);
		menu.AddItem("g_SnipersMenu", sInfo);
	}
	if(g_hCategoriesEnabled[CategoryRifles].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Assault Rifles", client);
		menu.AddItem("g_RiflesMenu", sInfo);
	}
	if(g_hCategoriesEnabled[CategoryShotguns].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Shotguns", client);
		menu.AddItem("g_ShotgunsMenu", sInfo);
	}
	if(g_hCategoriesEnabled[CategorySMG].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Submachine Guns", client);
		menu.AddItem("g_SMGMenu", sInfo);
	}
	if(g_hCategoriesEnabled[CategoryThrowables].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Throwables", client);
		menu.AddItem("g_ThrowablesMenu", sInfo);
	}
	if(g_hCategoriesEnabled[CategoryMisc].IntValue == 1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Misc", client);
		menu.AddItem("g_MiscMenu", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int TopMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "g_WeaponsMenu") == 0)
				BuildWeaponsMenu(param1);
			else if(strcmp(sItem, "g_HealthMenu") == 0)
				BuildHealthMenu(param1);
			else if(strcmp(sItem, "g_UpgradesMenu") == 0)
				BuildUpgradesMenu(param1);
			else if(strcmp(sItem, "g_InfectedSlot") == 0)
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "g_InfectedSlot");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostInfectedSlot].IntValue;
				char sInfo[32];
				Menu menu1 = new Menu(MenuHandler_InfectedSlot);
				FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
				menu1.AddItem("yes", sInfo);
				FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
				menu1.AddItem("no", sInfo);
				FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
				menu1.SetTitle(sInfo);
				menu1.ExitBackButton = true;
				menu1.Display(param1, MENU_TIME_FOREVER);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_InfectedSlot(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildBuyMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(!HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
					return;

				if(!strcmp(g_esPlayerData[param1].sItemName, "g_InfectedSlot", false))
				{
					if(GetPlayerZombie() >= g_hPluginSettings[hInfectedPlayerLimit].IntValue)
						PrintToChat(param1,  "%T", "Infected Player Limit", param1);
					else
						JoinInfected(param1, g_esPlayerData[param1].iItemCost);
				}
			}
		}
		case MenuAction_Cancel:
		{
			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

int GetPlayerZombie()
{
	int iZombie;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i))
			iZombie++;
	}
	return iZombie;
}

public int MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "g_MeleeMenu"))
				BuildMeleeMenu(param1);
			else if(!strcmp(sItem, "g_RiflesMenu"))
				BuildRiflesMenu(param1);
			else if(!strcmp(sItem, "g_SnipersMenu"))
				BuildSniperMenu(param1);
			else if(!strcmp(sItem, "g_ShotgunsMenu"))
				BuildShotgunMenu(param1);
			else if(!strcmp(sItem, "g_SMGMenu"))
				BuildSMGMenu(param1);
			else if(!strcmp(sItem, "g_ThrowablesMenu"))
				BuildThrowablesMenu(param1);
			else if(!strcmp(sItem, "g_MiscMenu"))
				BuildMiscMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

void BuildMeleeMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Melee);
	for(int i; i < g_iMeleeClassCount; i++)
	{
		int sequence = GetMeleeCost(g_sMeleeClass[i]);
		int cost;
		if(sequence != -1)
			cost = g_hItemCosts[sequence + 25].IntValue;
		else
			cost = g_hItemCosts[CostCustomMelee].IntValue;
		
		if(cost < 1)
			continue;

		if(sequence != -1)
			FormatEx(sInfo, sizeof(sInfo), "%T", g_sMeleeClass[i], client);
		else
			FormatEx(sInfo, sizeof(sInfo), g_sMeleeClass[i]);
		menu.AddItem(g_sMeleeClass[i], sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

stock int GetMeleeCost(char[] MeleeName)
{
	for(int i; i < sizeof(g_sMeleeName); i++)
	{
		if(strcmp(g_sMeleeName[i], MeleeName) == 0)
			return i;
	}
	return -1;
}

void BuildSniperMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Snipers);
	if(g_hItemCosts[CostHunting].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Hunting Rifle", client);
		menu.AddItem("weapon_hunting_rifle", sInfo);
	}
	if(g_hItemCosts[CostMilitary].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Military Sniper Rifle", client);
		menu.AddItem("weapon_sniper_military", sInfo);
	}
	if(g_hItemCosts[CostAWP].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "AWP Sniper Rifle", client);
		menu.AddItem("weapon_sniper_awp", sInfo);
	}
	if(g_hItemCosts[CostScout].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Scout Sniper Rifle", client);
		menu.AddItem("weapon_sniper_scout", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildRiflesMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Rifles);
	if(g_hItemCosts[CostM60].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "M60 Assault Rifle", client);
		menu.AddItem("weapon_rifle_m60", sInfo);
	}
	if(g_hItemCosts[CostM16].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "M16 Assault Rifle", client);
		menu.AddItem("weapon_rifle", sInfo);
	}
	if(g_hItemCosts[CostSCAR].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "SCAR-L Assault Rifle", client);
		menu.AddItem("weapon_rifle_desert", sInfo);
	}
	if(g_hItemCosts[CostAK47].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "AK-47 Assault Rifle", client);
		menu.AddItem("weapon_rifle_ak47", sInfo);
	}
	if(g_hItemCosts[CostSG552].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "SG552 Assault Rifle", client);
		menu.AddItem("weapon_rifle_sg552", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildShotgunMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Shotguns);
	if(g_hItemCosts[CostAuto].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Tactical Shotgun", client);
		menu.AddItem("weapon_autoshotgun", sInfo);
	}
	if(g_hItemCosts[CostChrome].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Chrome Shotgun", client);
		menu.AddItem("weapon_shotgun_chrome", sInfo);
	}
	if(g_hItemCosts[CostSPAS].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "SPAS Shotgun", client);
		menu.AddItem("weapon_shotgun_spas", sInfo);
	}
	if(g_hItemCosts[CostPump].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Pump Shotgun", client);
		menu.AddItem("weapon_pumpshotgun", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildSMGMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_SMG);
	if(g_hItemCosts[CostUzi].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Uzi", client);
		menu.AddItem("weapon_smg", sInfo);
	}
	if(g_hItemCosts[CostSilenced].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Silenced SMG", client);
		menu.AddItem("weapon_smg_silenced", sInfo);
	}
	if(g_hItemCosts[CostMP5].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "MP5 SMG", client);
		menu.AddItem("weapon_smg_mp5", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildHealthMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Health);
	if(g_hItemCosts[CostHealthKit].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "First Aid Kit", client);
		menu.AddItem("weapon_first_aid_kit", sInfo);
	}
	if(g_hItemCosts[CostDefib].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Defibrillator", client);
		menu.AddItem("weapon_defibrillator", sInfo);
	}
	if(g_hItemCosts[CostPills].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Pills", client);
		menu.AddItem("weapon_pain_pills", sInfo);
	}
	if(g_hItemCosts[CostAdren].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Adrenaline", client);
		menu.AddItem("weapon_adrenaline", sInfo);
	}
	if(g_hItemCosts[CostHeal].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Full Heal", client);
		menu.AddItem("health", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildThrowablesMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Throwables);
	if(g_hItemCosts[CostMolotov].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Molotov", client);
		menu.AddItem("weapon_molotov", sInfo);
	}
	if(g_hItemCosts[CostPipe].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Pipe Bomb", client);
		menu.AddItem("weapon_pipe_bomb", sInfo);
	}
	if(g_hItemCosts[CostBile].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Bile Bomb", client);
		menu.AddItem("weapon_vomitjar", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildMiscMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Misc);
	if(g_hItemCosts[CostGrenade].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Grenade Launcher", client);
		menu.AddItem("weapon_grenade_launcher", sInfo);
	}
	if(g_hItemCosts[CostP220].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "P220 Pistol", client);
		menu.AddItem("weapon_pistol", sInfo);
	}
	if(g_hItemCosts[CostMagnum].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Magnum Pistol", client);
		menu.AddItem("weapon_pistol_magnum", sInfo);
	}
	if(g_hItemCosts[CostChainsaw].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Chainsaw", client);
		menu.AddItem("weapon_chainsaw", sInfo);
	}
	if(g_hItemCosts[CostGnome].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Gnome", client);
		menu.AddItem("weapon_gnome", sInfo);
	}
	if(strcmp(g_sCurrentMap, "c1m2_streets", false) != 0 && g_hItemCosts[CostCola].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Cola Bottles", client);
		menu.AddItem("weapon_cola_bottles", sInfo);
	}
	if(g_hItemCosts[CostFireworks].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Fireworks Crate", client);
		menu.AddItem("weapon_fireworkcrate", sInfo);
	}
	if(strcmp(g_sGameMode, "scavenge", false) != 0 && g_hItemCosts[CostGasCan].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Gascan", client);
		menu.AddItem("weapon_gascan", sInfo);
	}
	if(g_hItemCosts[CostOxygen].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Oxygen Tank", client);
		menu.AddItem("weapon_oxygentank", sInfo);
	}
	if(g_hItemCosts[CostPropane].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Propane Tank", client);
		menu.AddItem("weapon_propanetank", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void BuildUpgradesMenu(int client)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_Upgrades);
	if(g_hItemCosts[CostLaserSight].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Laser Sight", client);
		menu.AddItem("laser_sight", sInfo);
	}
	if(g_hItemCosts[CostExplosiveAmmo].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Explosive Ammo", client);
		menu.AddItem("explosive_ammo", sInfo);
	}
	if(g_hItemCosts[CostFireAmmo].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Incendiary Ammo", client);
		menu.AddItem("incendiary_ammo", sInfo);
	}
	if(g_hItemCosts[CostExplosivePack].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Explosive Ammo Pack", client);
		menu.AddItem("upgradepack_explosive", sInfo);
	}
	if(g_hItemCosts[CostFirePack].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Incendiary Ammo Pack", client);
		menu.AddItem("upgradepack_incendiary", sInfo);
	}
	if(g_hItemCosts[CostAmmo].IntValue > -1)
	{
		FormatEx(sInfo, sizeof(sInfo), "%T", "Ammo", client);
		menu.AddItem("ammo", sInfo);
	}
	FormatEx(sInfo, sizeof(sInfo),"%T", "Points Left", client, g_esPlayerData[client].iPlayerPoints);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Melee(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			FormatEx(g_esPlayerData[param1].sItemName, 64, "give %s", sItem);
			int sequence = GetMeleeCost(sItem);
			if(sequence != -1)
				g_esPlayerData[param1].iItemCost = g_hItemCosts[sequence + 25].IntValue;
			else
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostCustomMelee].IntValue;
			DisplayConfirmMenuMelee(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildWeaponsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_SMG(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "weapon_smg", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give smg");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostUzi].IntValue;
			}
			else if(!strcmp(sItem, "weapon_smg_silenced", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give smg_silenced");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostSilenced].IntValue;
			}
			else if(!strcmp(sItem, "weapon_smg_mp5", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give smg_mp5");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostMP5].IntValue;
			}
			DisplayConfirmMenuSMG(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildWeaponsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Rifles(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "weapon_rifle", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give weapon_rifle");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostM16].IntValue;
			}
			else if(!strcmp(sItem, "weapon_rifle_desert", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give rifle_desert");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostSCAR].IntValue;
			}
			else if(!strcmp(sItem, "weapon_rifle_ak47", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give rifle_ak47");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostAK47].IntValue;
			}
			else if(!strcmp(sItem, "weapon_rifle_sg552", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give rifle_sg552");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostSG552].IntValue;
			}
			else if(!strcmp(sItem, "weapon_rifle_m60", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give rifle_m60");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostM60].IntValue;
			}
			DisplayConfirmMenuRifles(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildWeaponsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Snipers(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "weapon_hunting_rifle", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give hunting_rifle");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostHunting].IntValue;
			}
			else if(!strcmp(sItem, "weapon_sniper_scout", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give sniper_scout");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostScout].IntValue;
			}
			else if(!strcmp(sItem, "weapon_sniper_awp", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give sniper_awp");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostAWP].IntValue;
			}
			else if(!strcmp(sItem, "weapon_sniper_military", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give sniper_military");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostMilitary].IntValue;
			}
			DisplayConfirmMenuSnipers(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildWeaponsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Shotguns(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "weapon_shotgun_chrome", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give shotgun_chrome");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostChrome].IntValue;
			}
			else if(!strcmp(sItem, "weapon_pumpshotgun", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give pumpshotgun");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostPump].IntValue;
			}
			else if(!strcmp(sItem, "weapon_autoshotgun", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give autoshotgun");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostAuto].IntValue;
			}
			else if(!strcmp(sItem, "weapon_shotgun_spas", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give shotgun_spas");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostSPAS].IntValue;
			}
			DisplayConfirmMenuShotguns(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildWeaponsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Throwables(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "weapon_molotov", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give molotov");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostMolotov].IntValue;
			}
			else if(!strcmp(sItem, "weapon_pipe_bomb", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give pipe_bomb");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostPipe].IntValue;
			}
			else if(!strcmp(sItem, "weapon_vomitjar", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give vomitjar");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostBile].IntValue;
			}
			DisplayConfirmMenuThrow(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildWeaponsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Misc(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "weapon_pistol", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give pistol");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostP220].IntValue;
			}
			else if(!strcmp(sItem, "weapon_pistol_magnum", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give pistol_magnum");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostMagnum].IntValue;
			}
			else if(!strcmp(sItem, "weapon_grenade_launcher", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give grenade_launcher");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostGrenade].IntValue;
			}
			else if(!strcmp(sItem, "weapon_chainsaw", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give chainsaw");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostChainsaw].IntValue;
			}
			else if(!strcmp(sItem, "weapon_gnome", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give gnome");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostGnome].IntValue;
			}
			else if(!strcmp(sItem, "weapon_cola_bottles", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give cola_bottles");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostCola].IntValue;
			}
			else if(!strcmp(sItem, "weapon_gascan", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give gascan");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostGasCan].IntValue;
			}
			else if(!strcmp(sItem, "weapon_propanetank", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give propanetank");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostPropane].IntValue;
			}
			else if(!strcmp(sItem, "weapon_fireworkcrate", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give fireworkcrate");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostFireworks].IntValue;
			}
			else if(!strcmp(sItem, "weapon_oxygentank", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give oxygentank");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostOxygen].IntValue;
			}
			DisplayConfirmMenuMisc(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildWeaponsMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Health(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "weapon_first_aid_kit", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give first_aid_kit");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostHealthKit].IntValue;
			}
			else if(!strcmp(sItem, "weapon_defibrillator", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give defibrillator");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostDefib].IntValue;
			}
			else if(!strcmp(sItem, "weapon_pain_pills", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give pain_pills");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostPills].IntValue;
			}
			else if(!strcmp(sItem, "weapon_adrenaline", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give adrenaline");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostAdren].IntValue;
			}
			else if(!strcmp(sItem, "health", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give health");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostHeal].IntValue;
			}
			DisplayConfirmMenuHealth(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_Upgrades(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(!strcmp(sItem, "upgradepack_explosive", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give upgradepack_explosive");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostExplosivePack].IntValue;
			}
			else if(!strcmp(sItem, "upgradepack_incendiary", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give upgradepack_incendiary");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostFirePack].IntValue;
			}
			else if(!strcmp(sItem, "explosive_ammo", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "upgrade_add EXPLOSIVE_AMMO");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostExplosiveAmmo].IntValue;
			}
			else if(!strcmp(sItem, "incendiary_ammo", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "upgrade_add INCENDIARY_AMMO");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostFireAmmo].IntValue;
			}
			else if(!strcmp(sItem, "laser_sight", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "upgrade_add LASER_SIGHT");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostLaserSight].IntValue;
			}
			else if(!strcmp(sItem, "ammo", false))
			{
				strcopy(g_esPlayerData[param1].sItemName, 64, "give ammo");
				g_esPlayerData[param1].iItemCost = g_hItemCosts[CostAmmo].IntValue;
			}
			DisplayConfirmMenuUpgrades(param1);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildBuyMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

public int InfectedMenu(Menu menu, MenuAction action, int client, int iPosition)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(iPosition, sItem, sizeof(sItem));
			if(!strcmp(sItem, "heal", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "give health");
				if(IsTank(client))
					g_esPlayerData[client].iItemCost = g_hItemCosts[CostInfectedHeal].IntValue * g_hItemCosts[CostTankHealMultiplier].IntValue;
				else
					g_esPlayerData[client].iItemCost = g_hItemCosts[CostInfectedHeal].IntValue;
			}
			else if(!strcmp(sItem, "suicide", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "suicide");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostSuicide].IntValue;
			}
			else if(!strcmp(sItem, "boomer", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old boomer");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostBoomer].IntValue;
			}
			else if(!strcmp(sItem, "spitter", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old spitter");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostSpitter].IntValue;
			}
			else if(!strcmp(sItem, "smoker", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old smoker");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostSmoker].IntValue;
			}
			else if(!strcmp(sItem, "hunter", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old hunter");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostHunter].IntValue;
			}
			else if(!strcmp(sItem, "charger", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old charger");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostCharger].IntValue;
			}
			else if(!strcmp(sItem, "jockey", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old jockey");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostJockey].IntValue;
			}
			else if(!strcmp(sItem, "witch", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old witch");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostWitch].IntValue;
			}
			else if(!strcmp(sItem, "witch_bride", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old witch_bride");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostWitch].IntValue;
			}
			else if(!strcmp(sItem, "tank", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old tank");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostTank].IntValue;
			}
			else if(!strcmp(sItem, "horde", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "director_force_panic_event");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostHorde].IntValue;
			}
			else if(!strcmp(sItem, "mob", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old mob");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostMob].IntValue;
			}
			else if(!strcmp(sItem, "uncommon_mob", false))
			{
				strcopy(g_esPlayerData[client].sItemName, 64, "z_spawn_old mob");
				g_esPlayerData[client].iItemCost = g_hItemCosts[CostUncommonMob].IntValue;
			}
			DisplayConfirmMenuI(client);
		}
		case MenuAction_End:
			delete menu;
	}
}

public void OnEntityCreated(int entity, const char[] classPlayerName)
{
	if(!strcmp(classPlayerName, "infected", false) && g_iCounterData[iUCommonLeft] > 0)
	{
		switch(GetRandomInt(1, 6))
		{
			case 1:
				SetEntityModel(entity, "models/infected/common_male_riot.mdl");

			case 2:
				SetEntityModel(entity, "models/infected/common_male_ceda.mdl");

			case 3:
				SetEntityModel(entity, "models/infected/common_male_clown.mdl");

			case 4:
				SetEntityModel(entity, "models/infected/common_male_mud.mdl");

			case 5:
				SetEntityModel(entity, "models/infected/common_male_roadcrew.mdl");

			case 6:
				SetEntityModel(entity, "models/infected/common_male_fallen_survivor.mdl");
		}
		g_iCounterData[iUCommonLeft]--;
	}
}

void DisplayConfirmMenuMelee(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmMelee);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuSMG(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmSMG);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuRifles(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmRifles);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuSnipers(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmSniper);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuShotguns(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmShotguns);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuThrow(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmThrow);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuMisc(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmMisc);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuHealth(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmHealth);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuUpgrades(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmUpgrades);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

void DisplayConfirmMenuI(int param1)
{
	char sInfo[32];
	Menu menu = new Menu(MenuHandler_ConfirmI);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Yes", param1);
	menu.AddItem("yes", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "No", param1);
	menu.AddItem("no", sInfo);
	FormatEx(sInfo, sizeof(sInfo),"%T", "Cost", param1, g_esPlayerData[param1].iItemCost);
	menu.SetTitle(sInfo);
	menu.ExitBackButton = true;
	menu.Display(param1, MENU_TIME_FOREVER);
}

public int MenuHandler_ConfirmMelee(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildMeleeMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
					g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
					RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildMeleeMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmRifles(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildRiflesMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
					g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
					RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildRiflesMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmSniper(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildSniperMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
					g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
					RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildSniperMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmSMG(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildSMGMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
					g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
					RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildSMGMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmShotguns(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildShotgunMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
					g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
					RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildShotgunMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmThrow(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildThrowablesMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
					g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
					RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildThrowablesMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmMisc(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildMiscMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
					g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
					RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildMiscMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmHealth(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildHealthMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
				{
					if(!strcmp(g_esPlayerData[param1].sItemName, "give health", false))
					{
						strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
						g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
						RemovePoints(param1, g_esPlayerData[param1].iItemCost);
						CheatCommand(param1, g_esPlayerData[param1].sItemName);
					}
					else
					{
						strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
						g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
						RemovePoints(param1, g_esPlayerData[param1].iItemCost);
						CheatCommand(param1, g_esPlayerData[param1].sItemName);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildHealthMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

void ReloadAmmo(int client, int iCost, const char[] sItem)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0);
	if(iWeapon > MaxClients && IsValidEntity(iWeapon))
	{

		char sWeapon[32];
		GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
		if(strcmp(sWeapon, "weapon_rifle_m60") == 0)
		{
			if(g_iClipSize_RifleM60 <= 0)
				g_iClipSize_RifleM60 = 150;

			SetEntProp(iWeapon, Prop_Send, "m_iClip1", g_iClipSize_RifleM60);
		}
		else if(strcmp(sWeapon, "weapon_grenade_launcher") == 0)
		{
			if(g_iClipSize_GrenadeLauncher <= 0)
				g_iClipSize_GrenadeLauncher = 1;
			
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", g_iClipSize_GrenadeLauncher);

			int iAmmo_Max = FindConVar("ammo_grenadelauncher_max").IntValue;
			if(iAmmo_Max <= 0)
				iAmmo_Max = 30;

			SetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_iAmmo") + 68, iAmmo_Max);
		}
		CheatCommand(client, sItem);
		RemovePoints(client, iCost);
	}
	else
		PrintToChat(client, "%s %T", MSGTAG, "Primary Warning", client);
}

public int MenuHandler_ConfirmUpgrades(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildUpgradesMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost)){
					if(!strcmp(g_esPlayerData[param1].sItemName, "give ammo", false))
						ReloadAmmo(param1, g_esPlayerData[param1].iItemCost, g_esPlayerData[param1].sItemName);
					else
					{
						strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
						g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
						RemovePoints(param1, g_esPlayerData[param1].iItemCost);
						CheatCommand(param1, g_esPlayerData[param1].sItemName);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
				BuildUpgradesMenu(param1);

			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
}

public int MenuHandler_ConfirmI(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if(strcmp(sItem, "no", false) == 0)
			{
				BuildBuyMenu(param1);
				strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
				g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
			}
			else if(strcmp(sItem, "yes", false) == 0)
			{
				if(!HasEnoughPoints(param1, g_esPlayerData[param1].iItemCost))
					return;

				if(!strcmp(g_esPlayerData[param1].sItemName, "suicide", false))
					PerformSuicide(param1, g_esPlayerData[param1].iItemCost);
				else if(!strcmp(g_esPlayerData[param1].sItemName, "z_spawn_old mob", false))
					g_iCounterData[iUCommonLeft] += FindConVar("z_common_limit").IntValue;
				else if(!strcmp(g_esPlayerData[param1].sItemName, "z_spawn_old tank", false))
				{
					if(g_iCounterData[iTanksSpawned] == g_hPluginSettings[hTankLimit].IntValue)
						PrintToChat(param1,  "%T", "Tank Limit", param1);
					else
						g_iCounterData[iWitchesSpawned]++;
				}
				else if(!strcmp(g_esPlayerData[param1].sItemName, "z_spawn_old witch", false) || !strcmp(g_esPlayerData[param1].sItemName, "z_spawn_old witch_bride", false))
				{
					if(g_iCounterData[iWitchesSpawned] == g_hPluginSettings[hWitchLimit].IntValue)
						PrintToChat(param1,  "%T", "Witch Limit", param1);
					else
						g_iCounterData[iWitchesSpawned]++;
				}
				else if(StrContains(g_esPlayerData[param1].sItemName, "z_spawn_old", false) != -1 && StrContains(g_esPlayerData[param1].sItemName, "mob", false) == -1)
				{
					if(IsPlayerAlive(param1) || IsGhost(param1))
						return;

					vSpawnablePZScanProtect(0, param1);
					CheatCommand(param1, g_esPlayerData[param1].sItemName);

					int iMaxRetry = g_hPluginSettings[hSpawnAttempts].IntValue;
					for(int i; i < iMaxRetry; i++)
					{
						if(!IsPlayerAlive(param1))
							CheatCommand(param1, g_esPlayerData[param1].sItemName);
					}

					vSpawnablePZScanProtect(1);

					if(IsPlayerAlive(param1))
					{
						strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
						g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
						RemovePoints(param1, g_esPlayerData[param1].iItemCost);
					}
					else
						PrintToChat(param1, "%s %T", MSGTAG, "Spawn Failed", param1);

					return;
				}
	
				strcopy(g_esPlayerData[param1].sBought, 64, g_esPlayerData[param1].sItemName);
				g_esPlayerData[param1].iBoughtCost = g_esPlayerData[param1].iItemCost;
				RemovePoints(param1, g_esPlayerData[param1].iItemCost);
				CheatCommand(param1, g_esPlayerData[param1].sItemName);
			}
		}
		case MenuAction_Cancel:
		{
			strcopy(g_esPlayerData[param1].sItemName, 64, g_esPlayerData[param1].sBought);
			g_esPlayerData[param1].iItemCost = g_esPlayerData[param1].iBoughtCost;
		}
		case MenuAction_End:
			delete menu;
	}
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
			if(g_bControlZombies)
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
			if(g_bControlZombies)
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
