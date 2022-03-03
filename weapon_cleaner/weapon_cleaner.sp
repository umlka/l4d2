#pragma semicolon 1
#pragma newdecls optional

//#define DEBUG

#define PLUGIN_AUTHOR "xZk"
#define PLUGIN_VERSION "2.2.5"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CFG_WHITELIST "data/weapon_cleaner_whitelist.cfg"
#define MAXENTITIES 2048

enum L4D2GlowType
{
    L4D2Glow_None		= 0,
    L4D2Glow_OnUse		= 1,
    L4D2Glow_OnLookAt	= 2,
    L4D2Glow_Constant	= 3
}

char g_sItemNameGun[][] =
{
	"pistol"			   //0 
	,"pistol_magnum"	   //1 
	,"chainsaw"			   //2 
	,"smg"				   //3	 
	,"smg_silenced"		   //4 
	,"smg_mp5"			   //5 
	,"pumpshotgun"		   //6	 
	,"shotgun_chrome"	   //7 
	,"rifle"			   //8 
	,"rifle_desert"		   //9 
	,"rifle_ak47"		   //10
	,"rifle_sg552"		   //11
	,"hunting_rifle"	   //12
	,"sniper_military"	   //13
	,"sniper_scout"		   //14
	,"sniper_awp"		   //15
	,"autoshotgun"		   //16
	,"shotgun_spas"		   //17
	,"rifle_m60"		   //18		 
	,"grenade_launcher"	   //19	  
};

char g_sModelNameGun[][] =
{
	// "models/w_models/weapons/w_pistol_A.mdl"
	// "models/w_models/weapons/w_pistol_B.mdl"
	"models/w_models/weapons/w_pistol_"					//0 
	,"models/w_models/weapons/w_desert_eagle.mdl"		//1 
	,"models/weapons/melee/w_chainsaw.mdl"				//2 
	,"models/w_models/weapons/w_smg_uzi.mdl"			//3	 
	,"models/w_models/weapons/w_smg_a.mdl"				//4 
	,"models/w_models/weapons/w_smg_mp5.mdl"			//5 
	,"models/w_models/weapons/w_shotgun.mdl"			//6	 
	,"models/w_models/weapons/w_pumpshotgun_A.mdl"		//7 
	,"models/w_models/weapons/w_rifle_m16a2.mdl"		//8 
	,"models/w_models/weapons/w_desert_rifle.mdl"		//9 
	,"models/w_models/weapons/w_rifle_ak47.mdl"			//10
	,"models/w_models/weapons/w_rifle_sg552.mdl"		//11
	,"models/w_models/weapons/w_sniper_mini14.mdl"		//12
	,"models/w_models/weapons/w_sniper_military.mdl"	//13
	,"models/w_models/weapons/w_sniper_scout.mdl"		//14
	,"models/w_models/weapons/w_sniper_awp.mdl"			//15
	,"models/w_models/weapons/w_autoshot_m4super.mdl"	//16
	,"models/w_models/weapons/w_shotgun_spas.mdl"		//17
	,"models/w_models/weapons/w_m60.mdl"				//18
	,"models/w_models/weapons/w_grenade_launcher.mdl"	//19  
};													  


char g_sItemNameMelee[][] =
{
	"fireaxe",
	"frying_pan",
	"machete",
	"baseball_bat",
	"crowbar",
	"cricket_bat",
	"tonfa",
	"katana",
	"electric_guitar",
	"golfclub",
	"knife",
	"shovel",
	"pitchfork",
	"riotshield"
};

char g_sModelNameMelee[][] =
{
	"models/weapons/melee/w_fireaxe.mdl",
	"models/weapons/melee/w_frying_pan.mdl",
	"models/weapons/melee/w_machete.mdl",
	"models/weapons/melee/w_bat.mdl",
	"models/weapons/melee/w_crowbar.mdl",
	"models/weapons/melee/w_cricket_bat.mdl",
	"models/weapons/melee/w_tonfa.mdl",
	"models/weapons/melee/w_katana.mdl",
	"models/weapons/melee/w_electric_guitar.mdl",
	"models/weapons/melee/w_golfclub.mdl",
	"models/w_models/weapons/w_knife_t.mdl",
	"models/weapons/melee/w_shovel.mdl",
	"models/weapons/melee/w_pitchfork.mdl",
	"models/weapons/melee/w_riotshield.mdl"
};

char g_sItemNameGrenade[][] =
{
	"pipe_bomb",	
	"molotov",	
	"vomitjar"
};

char g_sModelNameGrenade[][] =
{
	"models/w_models/weapons/w_eq_pipebomb.mdl"	
	,"models/w_models/weapons/w_eq_molotov.mdl"	
	,"models/w_models/weapons/w_eq_bile_flask.mdl"
};

char g_sItemNamePack[][] =
{
	"first_aid_kit",		
	"defibrillator",		
	"upgradepack_explosive",
	"upgradepack_incendiary"
};

char g_sModelNamePack[][] =
{
	"models/w_models/weapons/w_eq_medkit.mdl"//models/w_models/weapons/w_eq_Medkit.mdl
	,"models/w_models/weapons/w_eq_defibrillator.mdl"
	,"models/w_models/weapons/w_eq_explosive_ammopack.mdl"
	,"models/w_models/weapons/w_eq_incendiary_ammopack.mdl"
};

char g_sItemNameConsumable[][] =
{
	"pain_pills",		
	"adrenaline"
};

char g_sModelNameConsumable[][] =
{
	"models/w_models/weapons/w_eq_painpills.mdl"
	,"models/w_models/weapons/w_eq_adrenaline.mdl"
};

char g_sItemNameCarry[][] =
{
	"fireworkcrate",
	"gascan",
	"oxygentank",
	"propanetank",
	"gnome",
	"cola_bottles"
};

char g_sModelNameCarry[][] =
{
	"models/props_junk/explosive_box001.mdl"
	,"models/props_junk/gascan001a.mdl"
	,"models/props_equipment/oxygentank01.mdl"
	,"models/props_junk/propanecanister001.mdl"
	,"models/props_junk/gnome.mdl"
	,"models/w_models/weapons/w_cola.mdl"
};

ConVar cvarEnable;
ConVar cvarDrop;
ConVar cvarClass;
ConVar cvarSpawn;
ConVar cvarPhysics;
ConVar cvarAmmo;
ConVar cvarDelay;
ConVar cvarEffectMode;
ConVar cvarEffectTime;
ConVar cvarEffectGlowColor;
ConVar cvarEffectGlowRange;
ConVar cvarVisible;
ConVar cvarVisibleMode;

bool g_bEnable;
bool g_bDrop;
bool g_bVisible;
bool g_bPhisics;
bool g_bAmmo;
int g_iSpawn;
int g_iClassWeapon;
int g_iCleanDelay;
int g_iEffectMode;
int g_iEffectGlowRange;
int g_iVisibleMode;
int g_iEffectGlowColor[3];
float g_fEffectTime;

StringMap g_smWhiteList;
Handle g_hTimerCleaning;
Handle g_hTimerCheckSpawnWeapons;
int g_iItemTime[MAXENTITIES + 1] = {-1, ...};
int g_iWeaponsRef[MAXENTITIES + 1];
bool g_bLateLoad;
bool g_bIsL4D2;
bool g_bSpawnedWeapons;

public Plugin myinfo = 
{
	name = "Weapon Cleaner", 
	author = PLUGIN_AUTHOR, 
	description = "Clean drop weapons on the ground with delay timer, like KF", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=315058"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bIsL4D2 = false;
	else if( test == Engine_Left4Dead2 ) g_bIsL4D2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_smWhiteList = new StringMap();
	LoadWhiteList();
	
	cvarEnable= CreateConVar("weapon_cleaner_enable", "1", "0:Disable, 1:Enable Plugin", FCVAR_NONE);
	cvarSpawn= CreateConVar("weapon_cleaner_spawn", "2", "0:Detect all weapons when spawned, 1:Ignore weapons spawned by map, 2: Ignore weapons when the round starts (thirparty plugins)");
	cvarDrop= CreateConVar("weapon_cleaner_drop", "0", "0: Clean all weapons not equipped in the game, 1: Clean only dropped weapons when taking another weapon");
	cvarClass= CreateConVar("weapon_cleaner_class", "1", "1:Clean only Weapons that do not belong to the spawn class, 2:Clean only Weapons of the class with suffix: \"_spawn\", 3:All weapons with any class name(\"weapon_*\")", FCVAR_NONE, true, 1.0, true, 3.0);
	cvarPhysics= CreateConVar("weapon_cleaner_physics", "0", "0:Ignore prop_physics weapons, 1:Allow detect prop_physics");
	cvarAmmo= CreateConVar("weapon_cleaner_ammo", "0", "0:Ignore ammo pile, 1:Allow detect ammo pile(weapon_ammo_spawn)");
	cvarDelay= CreateConVar("weapon_cleaner_delay", "120", "Set delay to clean each weapon in seconds", FCVAR_NONE, true, 1.0);
	cvarEffectMode= CreateConVar("weapon_cleaner_effect_mode", "1", "0:Disable effects on weapons in timer cleaning, 1:Set blink effect(RenderFx), 2:Set glow effect(L4D2), 3:All effects modes");
	cvarEffectTime= CreateConVar("weapon_cleaner_effect_time", "0.8", "Set percentage of delay time to activate effects on weapons, ex:(\"0.2\")=>(0.2*delay=0.2*300s=60s) or Set time in seconds value if: (value >= 1), ex:(\"60\")s", FCVAR_NONE, true, 0.01);
	cvarEffectGlowColor= CreateConVar("weapon_cleaner_effect_glowcolor", "128,128,128", "Set glow color in RGB Format (L4D2)");
	cvarEffectGlowRange= CreateConVar("weapon_cleaner_effect_glowrange", "1000", "Set maximum range of glow (L4D2)");
	cvarVisible= CreateConVar("weapon_cleaner_visible", "0", "0:Disable, 1:Enable visibility filter on weapons");
	cvarVisibleMode= CreateConVar("weapon_cleaner_visible_mode", "0", "0:Pause timer if is visible weapon , 1:Pause timer if someone is aiming at the weapon, 2:Reset timer if is visible weapon, 3:Reset timer if someone is aiming at the weapon", FCVAR_NONE, true, 0.0, true, 3.0);
	//AutoExecConfig(true, "weapon_cleaner");
	
	RegAdminCmd("sm_wc_reload", CmdReloadWhiteList, ADMFLAG_CHEATS, "reload config data Whitelist");
	RegAdminCmd("sm_wclean", CmdCleanWeapon, ADMFLAG_CHEATS, "clean weapons no equipped by name or/and classname, examples: 'sm_wclean pistol' 'sm_wclean weapon_pistol' 'sm_wclean pistol weapon_spawn'");
	RegAdminCmd("sm_wcleanall", CmdCleanAllWeapons, ADMFLAG_CHEATS, "clean all weapons no equipped");
	RegAdminCmd("sm_wclear", CmdClearWeapon, ADMFLAG_CHEATS, "clear weapons all weapons by name or/and classname, examples: 'sm_wclean pistol' 'sm_wclear weapon_pistol' 'sm_wclean pistol weapon_spawn'");
	RegAdminCmd("sm_wclearall", CmdClearAllWeapons, ADMFLAG_CHEATS, "clear all weapons");
	
	cvarEnable.AddChangeHook(CvarChange_Enable);
	cvarSpawn.AddChangeHook(CvarsChange);
	cvarDrop.AddChangeHook(CvarsChange);
	cvarClass.AddChangeHook(CvarsChange);
	cvarPhysics.AddChangeHook(CvarsChange);
	cvarAmmo.AddChangeHook(CvarsChange);
	cvarDelay.AddChangeHook(CvarsChange);
	cvarVisible.AddChangeHook(CvarsChange);
	cvarVisibleMode.AddChangeHook(CvarsChange);
	cvarEffectMode.AddChangeHook(CvarsChange);
	cvarEffectTime.AddChangeHook(CvarsChange);
	cvarEffectGlowColor.AddChangeHook(CvarsChange);
	cvarEffectGlowRange.AddChangeHook(CvarsChange);
	
	EnablePlugin();
}

public void OnPluginEnd() {
	DisablePlugin();
}

public void OnMapEnd(){
	StopTimerClean();
	StopTimerCheckSpawnWeapons();
	g_bSpawnedWeapons = false;
}

Action CmdReloadWhiteList(int client, int args)
{
	if (!g_bEnable)
		return Plugin_Continue;
	
	LoadWhiteList();
	ReplyToCommand(client, "reloaded: %s", CFG_WHITELIST);
	return Plugin_Handled;
}

Action CmdCleanWeapon(int client, int args)
{
	if (!g_bEnable)
		return Plugin_Continue;
	
	if(args > 0){
		int count;
		char arg1[32], arg2[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		if(strncmp(arg1, "weapon_", 7) == 0)
			count = CleanWeapons(arg1, arg2);
		else
			count = CleanWeapons(arg2, arg1);
		
		ReplyToCommand(client, "cleaned (%i) %s %s",count, arg1, arg2);
	}else{
		ReplyToCommand(client, "Usage: sm_wclean <name> | <classname>");
	}
	return Plugin_Handled;
}

Action CmdCleanAllWeapons(int client, int args)
{
	if (!g_bEnable)
		return Plugin_Continue;
	
	int count = CleanWeapons();
	ReplyToCommand(client, "cleaned all (%i) weapons no equipped", count);
	return Plugin_Handled;
}

Action CmdClearWeapon(int client, int args)
{
	if (!g_bEnable)
		return Plugin_Continue;
	
	if(args > 0){
		int count;
		char arg1[32], arg2[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		if(strncmp(arg1, "weapon_", 7) == 0)
			count = CleanWeapons(arg1, arg2, true);
		else
			count = CleanWeapons(arg2, arg1, true);
		
		ReplyToCommand(client, "cleaned all (%i) %s %s",count, arg1, arg2);
	}else{
		ReplyToCommand(client, "Usage: sm_wclear <name> | <classname>");
	}
	return Plugin_Handled;
}

Action CmdClearAllWeapons(int client, int args)
{
	if (!g_bEnable)
		return Plugin_Continue;
	
	int count = CleanWeapons(_, _, true);
	ReplyToCommand(client, "cleaned all (%i) weapons", count);
	return Plugin_Handled;
}

Action CmdListenWeaponDrop(int client, const char[] command, int argc)
{
	if(IsValidClient(client)){
		int weapon = GetActiveWeapon(client);
		if(IsItemToClean(weapon)){
			RemoveEffects(weapon);
			SetWeaponClean(weapon);
		}
	}

	return Plugin_Continue;
}

void CvarChange_Enable(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	g_bEnable = cvar.BoolValue;
	if (g_bEnable && (strcmp(oldVal, "0") == 0) )
		ReloadPlugin();
	else if (!g_bEnable && (strcmp(oldVal, "1") == 0) )
		DisablePlugin();
}

void CvarsChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	GetCvars();
}

void EnablePlugin(){
	g_bEnable = cvarEnable.BoolValue;
	if(g_bEnable && g_bLateLoad){
		ReloadPlugin();
	}else if(g_bEnable){
		HookEvents();
		AddCommandListener(CmdListenWeaponDrop, "sm_drop");
	}
	GetCvars();
}

void HookEvents(){
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStarted);
	if(g_bIsL4D2)
		HookEvent("weapon_drop", Event_WeaponDrop);
}

void GetCvars() {
	g_bDrop			     = cvarDrop.BoolValue;
	g_bPhisics		     = cvarPhysics.BoolValue;
	g_bAmmo			     = cvarAmmo.BoolValue;
	g_iSpawn			 = cvarSpawn.IntValue;
	g_iClassWeapon	     = cvarClass.IntValue;
	g_iCleanDelay		 = cvarDelay.IntValue;
	g_bVisible		     = cvarVisible.BoolValue;
	g_iVisibleMode	     = cvarVisibleMode.IntValue;
	g_iEffectMode		 = cvarEffectMode.IntValue;
	g_fEffectTime        = cvarEffectTime.FloatValue;
	g_iEffectGlowRange   = cvarEffectGlowRange.IntValue;
	char sTemp[16];
	cvarEffectGlowColor.GetString(sTemp, sizeof(sTemp));
	g_iEffectGlowColor   = StringRGBToIntRGB(sTemp);
}

void LoadWhiteList(){
	//get file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CFG_WHITELIST);

	//create file
	KeyValues hFile = new KeyValues("whitelist");
	if(!FileExists(sPath))
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
		
		if(hFile.JumpToKey("guns", true))
		{
			for( int i = 0; i < sizeof(g_sItemNameGun); i++ )
				hFile.SetNum(g_sItemNameGun[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if(hFile.JumpToKey("melees", true))
		{
			for( int i = 0; i < sizeof(g_sItemNameMelee); i++ )
				hFile.SetNum(g_sItemNameMelee[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if(hFile.JumpToKey("grenades", true))
		{
			for( int i = 0; i < sizeof(g_sItemNameGrenade); i++ )
				hFile.SetNum(g_sItemNameGrenade[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if(hFile.JumpToKey("packs", true))
		{
			for( int i = 0; i < sizeof(g_sItemNamePack); i++ )
				hFile.SetNum(g_sItemNamePack[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if(hFile.JumpToKey("consumables", true))
		{
			for( int i = 0; i < sizeof(g_sItemNameConsumable); i++ )
				hFile.SetNum(g_sItemNameConsumable[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if(hFile.JumpToKey("carryables", true))
		{
			for( int i = 0; i < sizeof(g_sItemNameCarry); i++ )
				hFile.SetNum(g_sItemNameCarry[i], 1);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s", CFG_WHITELIST);
	}
	// Load config
	g_smWhiteList.Clear();
	if( hFile.ImportFromFile(sPath) )
	{
		if(hFile.JumpToKey("guns", true)){
			for( int i = 0; i < sizeof(g_sItemNameGun); i++ ){
				if(hFile.GetNum(g_sItemNameGun[i]) == 1)
					g_smWhiteList.SetValue(g_sItemNameGun[i], true);
			}
			hFile.Rewind();
		}
		if(hFile.JumpToKey("melees", true)){
			for( int i = 0; i < sizeof(g_sItemNameMelee); i++ ){
				if(hFile.GetNum(g_sItemNameMelee[i]) == 1)
					g_smWhiteList.SetValue(g_sItemNameMelee[i],true);
			}
			hFile.Rewind();
		}
		if(hFile.JumpToKey("grenades", true)){
			for( int i = 0; i < sizeof(g_sItemNameGrenade); i++ ){
				if(hFile.GetNum(g_sItemNameGrenade[i]) == 1)
					g_smWhiteList.SetValue(g_sItemNameGrenade[i],true);
			}
			hFile.Rewind();
		}
		if(hFile.JumpToKey("packs", true)){
			for( int i = 0; i < sizeof(g_sItemNamePack); i++ ){
				if(hFile.GetNum(g_sItemNamePack[i]) == 1)
					g_smWhiteList.SetValue(g_sItemNamePack[i],true);
			}
			hFile.Rewind();
		}
		if(hFile.JumpToKey("consumables", true)){
			for( int i = 0; i < sizeof(g_sItemNameConsumable); i++ ){
				if(hFile.GetNum(g_sItemNameConsumable[i]) == 1)
					g_smWhiteList.SetValue(g_sItemNameConsumable[i],true);
			}
			hFile.Rewind();
		}
		if(hFile.JumpToKey("carryables", true)){
			for( int i = 0; i < sizeof(g_sItemNameCarry); i++ ){
				if(hFile.GetNum(g_sItemNameCarry[i]) == 1)
					g_smWhiteList.SetValue(g_sItemNameCarry[i],true);
			}
		}
	}
	delete hFile;
}

int CleanWeapons(char[] classname="", char[] itemname="", bool equipped = false){
	
	int ent=MaxClients+1, count;
	char name[64];
	char class[64];
	bool noname = strlen(itemname) == 0;
	strcopy(class, sizeof(class), strlen(classname) == 0 ? "*" : classname);
	while ((ent = FindEntityByClassname(ent, class)) != -1) {
		if(IsValidWeapon(ent) || IsPropPhysic(ent)){
			GetItemName(ent, name, sizeof(name));
			if(noname || strcmp(name, itemname) == 0){
				if(!equipped && IsWeaponEquipped(ent))
					continue;
				AcceptEntityInput(ent, "Kill");
				count++;
			}
		}
	}
	return count;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	LoadWhiteList();
	StopTimerClean();
	StopTimerCheckSpawnWeapons();
	g_bSpawnedWeapons = false;
}

void Event_RoundStarted(Event event, const char[] name, bool dontBroadcast) //postcheck weapons spowned on map or when round started
{	
	if(g_iSpawn == 1)
		g_bSpawnedWeapons = true;
	else if(g_iSpawn == 2)
		StartTimerCheckSpawnWeapons();
	StartTimerClean();
}

void Event_WeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
	int weapon = event.GetInt("propid");
	if(IsItemToClean(weapon)){
		RemoveEffects(weapon);
		SetWeaponClean(weapon);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnable) 
		return;
	
	if (!g_iSpawn || g_bSpawnedWeapons) {
		if (!g_bDrop && strncmp(classname, "weapon_", 7) == 0 )
		{
			SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
		}
		if (g_bPhisics && ( strcmp(classname, "physics_prop") == 0 || strcmp(classname, "prop_physics") == 0 ) )
		{
			SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!g_bEnable) 
		return;
		
	if (IsItemToClean(entity))
	{
		UnSetWeaponClean(entity);
		_debug("deleted:%d ", entity);
	}
}

public void OnClientPutInServer(int client) 
{
	if (!g_bEnable) 
		return;
		
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
}

public void OnClientDisconnect(int client) 
{
	if (!g_bEnable) 
		return;
	
	if(IsValidSurvivor(client)){
		for(int i; i < 5; i++){
			int weapon = GetPlayerWeaponSlot(client, i);
			if(IsItemToClean(weapon)){
				RemoveEffects(weapon);
				SetWeaponClean(weapon);
			}
		}
	}
}

void OnSpawnPost(int entity) {
	
	if (IsItemToClean(entity)) {
		SetWeaponClean(entity);
		_debug("Spawn:%d", entity);
	}
}

void OnWeaponEquip(int client, int weapon) {
	
	if (IsValidSurvivor(client) && IsItemToClean(weapon))
	{
		RemoveEffects(weapon);
		UnSetWeaponClean(weapon);
		_debug("HOOK-player:%d Equip : %d", client, weapon);
	}
}

void OnWeaponDrop(int client, int weapon) {
	
	if (IsValidSurvivor(client) && IsItemToClean(weapon) && !IsWeaponEquipped(weapon) )
	{
		RemoveEffects(weapon);
		SetWeaponClean(weapon);
		_debug("HOOK-player:%d Drop : %d", client, weapon);
	}
}

Action CheckSpawnWeapons(Handle timer) {
	g_hTimerCheckSpawnWeapons = null;
	g_bSpawnedWeapons = true;

	return Plugin_Continue;
}

Action CleaningWeapons(Handle timer) 
{
	for(int i = MaxClients+1; i < sizeof(g_iWeaponsRef); i++){
		if(!g_iWeaponsRef[i])
			continue;
			
		int weapon = EntRefToEntIndex(g_iWeaponsRef[i]);
		if (IsItemToClean(weapon)) {
			if (g_iItemTime[weapon] >= 0) {
				if (IsWeaponEquipped(weapon))
				{
					_debug("USER: %d", weapon);
					RemoveEffects(weapon);
					//g_iItemTime[weapon] = g_iCleanDelay;
					UnSetWeaponClean(weapon);
					continue;
				} else if (g_iItemTime[weapon] == 0) {
					UnSetWeaponClean(weapon);
					AcceptEntityInput(weapon, "kill");
					continue;
				}else if (g_bVisible && IsVisibleToPlayers(weapon)) {
					SetEffects(weapon);
					switch (g_iVisibleMode) {
						case 0: {  //Pause Timer
							_debug("Pause Time: %d", g_iItemTime[weapon]);
							continue;
						}
						case 1: {  //Pause Timer on aiming
							if (IsAimToPlayers(weapon)) {
								_debug("Pause Time: %d", g_iItemTime[weapon]);
								continue;
							}
						}
						case 2: {  //Reset Timer
							g_iItemTime[weapon] = g_iCleanDelay;
							RemoveEffects(weapon);
							_debug("Reset Time: %d", g_iItemTime[weapon]);
							continue;
						}
						case 3: {  //Reset Timer on aiming
							if (IsAimToPlayers(weapon)) {
								g_iItemTime[weapon] = g_iCleanDelay;
								RemoveEffects(weapon);
								_debug("Pause Time: %d", g_iItemTime[weapon]);
								continue;
							}
						}
					}
					
				}
			} else {
				UnSetWeaponClean(weapon);
				continue;
			}
			SetEffects(weapon);
			g_iItemTime[weapon]--;
			_debug("Time: %d", g_iItemTime[weapon]);
		} else {
			UnSetWeaponClean(weapon);
			continue;
		}
	}
	return Plugin_Continue;
}

void StartTimerCheckSpawnWeapons(){
	StopTimerCheckSpawnWeapons();
	g_hTimerCheckSpawnWeapons = CreateTimer(3.0, CheckSpawnWeapons);
}

void StopTimerCheckSpawnWeapons(){
	delete g_hTimerCheckSpawnWeapons;
}

void StartTimerClean(){
	StopTimerClean();
	g_hTimerCleaning = CreateTimer(1.0, CleaningWeapons, _, TIMER_REPEAT);
}

void StopTimerClean(){
	delete g_hTimerCleaning;
}

void SetEffects(int item) {
	if(!IsItemToClean(item) || g_iItemTime[item] <= 0)
		return;

	int time_fx=0;
	if (g_fEffectTime < 1.0) {
		time_fx = RoundFloat(float(g_iCleanDelay) * g_fEffectTime);
	} else {
		time_fx = RoundFloat(g_fEffectTime);
	}
	
	if (g_iItemTime[item] <= time_fx)
	{
		//old effects
		/*
		if (g_iEffectMode & 1) {
			if (g_iItemTime[item] == (time_fx / 4)) {
				SetEntityRenderFx(item, RENDERFX_STROBE_FASTER);
			} else if (g_iItemTime[item] == (time_fx / 2)) {
				SetEntityRenderFx(item, RENDERFX_STROBE_FAST);
			} else if (g_iItemTime[item] == time_fx) {
				SetEntityRenderFx(item, RENDERFX_STROBE_SLOW);
			}
		}
		*/
		if (g_iEffectMode & 1) {
			if (g_iItemTime[item] == time_fx)
				SetEntityRenderFx(item, RENDERFX_PULSE_SLOW);
			if (g_iItemTime[item] == time_fx / 2)
				SetEntityRenderFx(item, RENDERFX_PULSE_FAST);
			if (g_iItemTime[item] == time_fx / 3)
				SetEntityRenderFx(item, RENDERFX_PULSE_SLOW_WIDE);
			if (g_iItemTime[item] == time_fx / 4)
				SetEntityRenderFx(item, RENDERFX_PULSE_FAST_WIDE);
			if (g_iItemTime[item] == time_fx / 5)
				SetEntityRenderFx(item, RENDERFX_EXPLODE);
		}
		if (g_iEffectMode & 2) {
			if (g_bIsL4D2) {
				//g_iGlowColor = StringToRGB(g_iEffectGlowColor);
				if (g_iItemTime[item] == (time_fx / 2)) {
					L4D2_SetEntityGlow(item, L4D2Glow_OnLookAt, g_iEffectGlowRange, 100, g_iEffectGlowColor, true);
				} else if (g_iItemTime[item] == time_fx) {
					L4D2_SetEntityGlow(item, L4D2Glow_OnLookAt, g_iEffectGlowRange, 100, g_iEffectGlowColor, false);
				}
			}
		}
	}
}

void RemoveEffects(int item) {
	if(IsItemToClean(item) && g_iItemTime[item]){
		if (g_bIsL4D2) {
			L4D2_RemoveEntityGlow(item);
		}
		SetEntityRenderFx(item, RENDERFX_NONE);
	}
}

bool IsVisibleToPlayers(int entity) {
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i) && IsPlayerAlive(i) && (GetClientAimTarget(i, false) == entity || IsEntVisibleCam(i, entity))) {
			return true;
		}
	}
	return false;
}

bool IsAimToPlayers(int entity) {
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidSurvivor(i) && IsPlayerAlive(i) && GetClientAimTarget(i, false) == entity) {
			return true;
		}
	}
	return false;
}

bool IsEntVisibleCam(int client, int entity, float fov = 60.0)
{
	float vPos[3], vAng[3], vAim[3], vTarget[3], vEnt[3];
	GetClientEyePosition(client, vPos);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vEnt);
	if(IsVisibleTo(vPos, vEnt)){
		GetClientEyeAngles(client, vAng);
		SubtractVectors(vEnt, vPos, vTarget);
		GetAngleVectors(vAng, vAim, NULL_VECTOR, NULL_VECTOR);
		float ang  = ArcCosine( GetVectorDotProduct(vAim, vTarget) / (GetVectorLength(vAim) * GetVectorLength(vTarget) ) ) * 360.0 / 2.0 / FLOAT_PI;
		return (ang < fov);
	}
	return false;
}
// credits = "AtomicStryker"
bool IsVisibleTo(float position[3], float targetposition[3])
{
	static float vAngles[3], vLookAt[3];

	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	static Handle trace;
	trace = TR_TraceRayFilterEx(position, vAngles, MASK_ALL, RayType_Infinite, _TraceFilter);

	static bool isVisible;
	isVisible = false;

	if( TR_DidHit(trace) )
	{
		static float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if( (GetVectorDistance(position, vStart, false) + 25.0 ) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true; // if trace ray length plus tolerance equal or bigger absolute distance, you hit the target
		}
	}
	delete trace;

	return isVisible;
}

public bool _TraceFilter(int entity, int contentsMask){
	if( entity <= MaxClients || !IsValidEntity(entity) )
		return false;
	return true;
}

bool IsWeaponEquipped(int weapon)
{	
	if(IsValidWeapon(weapon) && !IsWeaponSpawner(weapon)){
		int client = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity");
		if (IsValidClient(client))
			return true;
	}
	return false;
}

void GetItemName(int ent,	char[] name, int size)
{
	strcopy(name, size, NULL_STRING);
	if(IsValidWeapon(ent) && !IsWeaponSpawner(ent)){
		if (IsWeaponMeleeClass(ent)){
			GetNameWeaponMelee(ent, name, size);
		}else{
			GetEntityClassname(ent, name, size);
			SplitStringRight(name, "weapon_", name, size);
		}
	}
	else if(IsWeaponSpawner(ent) || IsPropPhysic(ent))
	{	
		char modelname[64];
		GetEntPropString(ent, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
		//guns
		for(int i; i < sizeof(g_sItemNameGun); i++){
			if(i == 0 && strncmp(modelname, g_sModelNameGun[i], strlen(g_sModelNameGun[i]), false)==0){
				strcopy(name, size, g_sItemNameGun[i]);
				return;
			}
			if(strcmp(modelname, g_sModelNameGun[i], false)==0){
				strcopy(name, size, g_sItemNameGun[i]);
				return;
			}
		}
		//melees
		for(int i; i < sizeof(g_sItemNameMelee); i++){
			if(strcmp(modelname, g_sModelNameMelee[i], false)==0){
				strcopy(name, size, g_sItemNameMelee[i]);
				return;
			}
		}
		//grenades
		for(int i; i < sizeof(g_sItemNameGrenade); i++){
			if(strcmp(modelname, g_sModelNameGrenade[i], false)==0){
				strcopy(name, size, g_sItemNameGrenade[i]);
				return;
			}
		}
		//packs
		for(int i; i < sizeof(g_sItemNamePack); i++){
			if(strcmp(modelname, g_sModelNamePack[i], false)==0){
				strcopy(name, size, g_sItemNamePack[i]);
				return;
			}
		}
		//meds
		for(int i; i < sizeof(g_sItemNameConsumable); i++){
			if(strcmp(modelname, g_sModelNameConsumable[i], false)==0){
				strcopy(name, size, g_sItemNameConsumable[i]);
				return;
			}
		}
		//carries
		for(int i; i < sizeof(g_sItemNameCarry); i++){
			if(strcmp(modelname, g_sModelNameCarry[i], false)==0){
				strcopy(name, size, g_sItemNameCarry[i]);
				return;
			}
		}
	}
	return;
}

bool IsWeaponClassEnable(int weapon) {
	if (!IsWeaponSpawner(weapon) && g_iClassWeapon & 1)
		return true;
	
	if (IsWeaponItemSpawner(weapon) && g_iClassWeapon & 2)
		return true;
	
	return false;
}

bool IsWeaponPhysicsEnable(int weapon) {
	return (IsWeaponPhysic(weapon) && g_bPhisics);
}
//check _spawn
bool IsItemExclude(int item) {

	if(IsValidWeapon(item) || IsWeaponPhysic(item)){
		char item_name[64];
		GetItemName(item, item_name, sizeof(item_name));//weapon_first_aid_kit_spawn
		if(IsNullString(item_name))
			return false;

		bool exclude;
		if(g_smWhiteList.GetValue(item_name, exclude)){
			return exclude;
		}
	}
	return false;
}

bool IsItemToClean(int item) {
	return ( 
		(
		(IsValidWeapon(item) && IsWeaponClassEnable(item)) 
		|| IsWeaponPhysicsEnable(item) 
		|| (g_bAmmo && IsWeaponAmmoPile(item))
		)
		&& (!IsItemExclude(item) && !IsScavengeGascan(item))
	);
}

bool IsWeaponItemSpawner(int weapon){
	return (IsWeaponSpawner(weapon) && !IsWeaponAmmoPile(weapon) && !IsWeaponScavengeItem(weapon));
}

void SetWeaponClean(int weapon) {
	g_iItemTime[weapon] = g_iCleanDelay;
	g_iWeaponsRef[weapon] = EntIndexToEntRef(weapon);
}

void UnSetWeaponClean(int item) {
	if (item > 0 && item <= MAXENTITIES) {
		g_iItemTime[item] = -1;
		g_iWeaponsRef[item] = 0;
	}
}

stock int GetActiveWeapon(int client){
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}

//credits to Lux
stock bool IsScavengeGascan(int entity)
{
	if(!IsValidEnt(entity))
		return false;
		
	char sTempString[33];
	GetEntityClassname(entity, sTempString, sizeof(sTempString));
	if(sTempString[0] != 'w' && sTempString[0] != 'p')
		return false;

	if(strcmp(sTempString, "weapon_gascan")!=0 && strcmp(sTempString, "prop_physics")!=0 && strcmp(sTempString, "physics_prop")!=0)
		return false;

	GetEntPropString(entity, Prop_Data, "m_ModelName", sTempString, sizeof(sTempString));
	if(strcmp(sTempString, "models/props_junk/gascan001a.mdl", false)!=0)
		return false;

	int skin = GetEntProp(entity, Prop_Send, "m_nSkin");
	
	return skin >= 1;
}

stock void GetNameWeaponMelee(int weapon, char[] melee_name, int size){
	if(IsWeaponMeleeClass(weapon))
		GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", melee_name, size);
}

stock bool IsWeaponMeleeClass(int weapon){
	if(IsValidWeapon(weapon))
	{
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_melee") == 0);
	}
	return false;
}

stock bool IsWeaponScavengeItem(int weapon){
	if(IsValidWeapon(weapon) ){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return ( strcmp(class_name, "weapon_scavenge_item_spawn") == 0);
	}
	return false;
}

stock bool IsWeaponSpawnClass(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return ( strcmp(class_name, "weapon_spawn") == 0);
	}
	return false;
}

stock bool IsWeaponSpawner(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strncmp(class_name[strlen(class_name)-6], "_spawn", 7) == 0);
	}
	return false;
}

stock bool IsPropPhysic(int ent){
	if (IsValidEnt(ent)){
		char class_name[64];
		GetEntityClassname(ent, class_name, sizeof(class_name));
		return (strcmp(class_name, "prop_physics") == 0);
	}
	return false;
}

stock bool IsWeaponPhysic(int weapon){
	if (IsPropPhysic(weapon)){
		char weapon_name[64];
		GetItemName(weapon, weapon_name, sizeof(weapon_name));
		return (!IsNullString(weapon_name));
	}
	return false;
}

stock bool IsWeaponAmmoPile(int weapon){
	if (IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_ammo_spawn") == 0);
	}
	return false;
}

stock bool IsValidWeapon(int weapon){
	if (IsValidEnt(weapon)) {
		char class_name[64];
		GetEntityClassname(weapon,class_name,sizeof(class_name));
		return (strncmp(class_name, "weapon_", 7) == 0);
	}
	return false;
}

stock bool IsValidEnt(int entity){
	return (entity > 0 && entity > MaxClients && IsValidEntity(entity) && entity != INVALID_ENT_REFERENCE);
}

stock bool IsValidSpect(int client){ 
	return (IsValidClient(client) && GetClientTeam(client) == 1 );
}

stock bool IsValidSurvivor(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 2 );
}

stock bool IsValidInfected(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 3 );
}

stock bool IsValidClient(int client){
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock int[] StringRGBToIntRGB(const char[] str_rgb) {
	int colorRGB[3];
	char str_color[16][3];
	char color_string[16];
	strcopy(color_string, sizeof(color_string), str_rgb);
	TrimString(color_string);
	ExplodeString(color_string, ",", str_color, sizeof(str_color[]), sizeof(str_color));
	colorRGB[0] = StringToInt(str_color[0]);
	colorRGB[1] = StringToInt(str_color[1]);
	colorRGB[2] = StringToInt(str_color[2]);
	return colorRGB;
}

stock bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen)
{
	int index = StrContains(source, split); // get start index of split string 
	
	if (index == -1) // split string not found.. 
		return false;
	
	index += strlen(split); // get end index of split string
	
	if (index == strlen(source) - 1) // no right side exist
		return false;
	
	strcopy(part, partLen, source[index]); // copy everything after source[ index ] to part 
	return true;
}

stock void _debug(const char[] szFormat, int ...)
{
	char szText[4096];
	VFormat(szText, sizeof(szText), szFormat, 2);
	//server_print("#DEBUG: %s", szText);
	#if defined DEBUG
	PrintToChatAll("#DEBUG: %s", szText);
	#endif
}

void ReloadPlugin() {
	HookEvents();
	AddCommandListener(CmdListenWeaponDrop, "sm_drop");
	for (int i = MaxClients + 1; i <= GetMaxEntities(); i++) {
		if (IsItemToClean(i) && !IsWeaponEquipped(i)) {
			SetWeaponClean(i);
		}
	}
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i)) {
			SDKHook(i, SDKHook_WeaponEquipPost, OnWeaponEquip);
			SDKHook(i, SDKHook_WeaponDropPost, OnWeaponDrop);
		}
	}
	StartTimerClean();
}

void DisablePlugin() {
	UnHookEvents();
	RemoveCommandListener(CmdListenWeaponDrop, "sm_drop");
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i)) {
			SDKUnhook(i, SDKHook_WeaponEquipPost, OnWeaponEquip);
			SDKUnhook(i, SDKHook_WeaponDropPost, OnWeaponDrop);
		}
	}
	StopTimerClean();
}

void UnHookEvents(){
	UnhookEvent("round_end", Event_RoundEnd);
	UnhookEvent("round_start", Event_RoundStarted);
	if(g_bIsL4D2){
		UnhookEvent("weapon_drop", Event_WeaponDrop);
	}
}

/**
 * Set entity glow. This is consider safer and more robust over setting each glow
 * property on their own because glow offset will be check first.
 *
 * @param entity        Entity index.
 * @parma type          Glow type.
 * @param range         Glow max range, 0 for unlimited.
 * @param minRange      Glow min range.
 * @param colorOverride Glow color, RGB.
 * @param flashing      Whether the glow will be flashing.
 * @return              True if glow was set, false if entity does not support
 *                      glow.
 */
stock bool L4D2_SetEntityGlow(int entity, L4D2GlowType type, int range, int minRange, int colorOverride[3], bool flashing)
{
    if(!IsValidEntity(entity))
        return false;

    char netclass[128];
    GetEntityNetClass(entity, netclass, 128);
    if(FindSendPropInfo(netclass, "m_iGlowType") < 1)
        return false;

    L4D2_SetEntityGlow_Type(entity, type);
    L4D2_SetEntityGlow_Range(entity, range);
    L4D2_SetEntityGlow_MinRange(entity, minRange);
    L4D2_SetEntityGlow_Color(entity, colorOverride);
    L4D2_SetEntityGlow_Flashing(entity, flashing);
    return true;
}

/**
 * Set entity glow type.
 *
 * @param entity        Entity index.
 * @parma type          Glow type.
 * @noreturn
 * @error               Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntityGlow_Type(int entity, L4D2GlowType type)
{
    SetEntProp(entity, Prop_Send, "m_iGlowType", view_as<int>(type));
}

/**
 * Set entity glow range.
 *
 * @param entity        Entity index.
 * @parma range         Glow range.
 * @noreturn
 * @error               Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntityGlow_Range(int entity, int range)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
}

/**
 * Set entity glow min range.
 *
 * @param entity        Entity index.
 * @parma minRange      Glow min range.
 * @noreturn
 * @error               Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntityGlow_MinRange(int entity, int minRange)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
}

/**
 * Set entity glow color.
 *
 * @param entity        Entity index.
 * @parma colorOverride Glow color, RGB.
 * @noreturn
 * @error               Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntityGlow_Color(int entity, int colorOverride[3])
{
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
}

/**
 * Set entity glow flashing state.
 *
 * @param entity        Entity index.
 * @parma flashing      Whether glow will be flashing.
 * @noreturn
 * @error               Invalid entity index or entity does not support glow.
 */
stock void L4D2_SetEntityGlow_Flashing(int entity, bool flashing)
{
    SetEntProp(entity, Prop_Send, "m_bFlashing", view_as<int>(flashing));
}

/**
 * Removes entity glow.
 *
 * @param entity        Entity index.
 * @return              True if glow was removed, false if entity does not
 *                      support glow.
 */
stock bool L4D2_RemoveEntityGlow(int entity)
{
    return L4D2_SetEntityGlow(entity, L4D2Glow_None, 0, 0, { 0, 0, 0 }, false);
}
