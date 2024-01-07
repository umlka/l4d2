#pragma semicolon 1
#pragma newdecls required
#include <dhooks>
#include <left4dhooks_stocks>

#define PLUGIN_NAME				"Weapon Item Count"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"设置物品拾取次数"
#define PLUGIN_VERSION			"1.2.0"
#define PLUGIN_URL				""

#define GAMEDATA	"weapon_item_count"

enum {
	EntRef,
	UseCount
};

ConVar
	g_cvSpawnerAbsorb;

DynamicDetour
	g_ddDetour;

int
	g_iSpawner[2048 + 1][2];

int
	g_iItemRules[view_as<int>(L4D2WeaponId_MAX)];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	vInitData();

	CreateConVar("weapon_item_count_version", PLUGIN_VERSION, "Weapon Item Count plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvSpawnerAbsorb = CreateConVar("spawner_absorb", "1", "武器生成器吸收回去一件武器后减少对应拾取次数?");
	g_cvSpawnerAbsorb.AddChangeHook(vCvarChanged);

	RegServerCmd("item_count", cmdItemCount);
	RegServerCmd("re_item_count", cmdResetItemCount);

	vResetWeaponRules();
}

public void OnConfigsExecuted()
{
	vToggleDetour(g_cvSpawnerAbsorb.BoolValue);
}

void vCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vToggleDetour(g_cvSpawnerAbsorb.BoolValue);
}

Action cmdItemCount(int args) {
	if (args < 2) {
		PrintToServer("Usage: item_count <match> <count>");
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof arg);
	L4D2WeaponId match = L4D2_GetWeaponIdByWeaponName2(arg);
	if (!L4D2_IsValidWeaponId(match))
		return Plugin_Handled;

	GetCmdArg(2, arg, sizeof arg);
	int count = StringToInt(arg);
	if (count >= 0)
		g_iItemRules[match] = count;

	return Plugin_Handled;
}

Action cmdResetItemCount(int args) {
	vResetWeaponRules();
	return Plugin_Handled;
}
	
void vResetWeaponRules() {
	for (int i; i < view_as<int>(L4D2WeaponId_MAX); i++)
		g_iItemRules[i] = -1;
}

void vInitData() {
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CWeaponSpawn::GiveItem");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CWeaponSpawn::GiveItem\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Pre, DD_CWeaponSpawn_GiveItem_Pre))
		SetFailState("Failed to detour pre: \"DD::CWeaponSpawn::GiveItem\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Post, DD_CWeaponSpawn_GiveItem_Post))
		SetFailState("Failed to detour post: \"DD::CWeaponSpawn::GiveItem\" (%s)", PLUGIN_VERSION);

	g_ddDetour = DynamicDetour.FromConf(hGameData, "DD::CWeaponSpawn::AbsorbWeapon");
	if (!g_ddDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CWeaponSpawn::AbsorbWeapon\" (%s)", PLUGIN_VERSION);

	delete hGameData;
}

void vToggleDetour(bool bEnable) {
	static bool bEnabled;
	if (!bEnabled && bEnable) {
		bEnabled = true;

		if (!g_ddDetour.Enable(Hook_Post, DD_CWeaponSpawn_AbsorbWeapon_Post))
			SetFailState("Failed to detour post: \"DD::CWeaponSpawn::AbsorbWeapon\" (%s)", PLUGIN_VERSION);
	}
	else if (bEnabled && !bEnable) {
		bEnabled = false;

		if (!g_ddDetour.Disable(Hook_Post, DD_CWeaponSpawn_AbsorbWeapon_Post))
			SetFailState("Failed to disable detour post: \"DD::CWeaponSpawn::AbsorbWeapon\" (%s)", PLUGIN_VERSION);
	}
}

bool g_bRemoveSpawner;
MRESReturn DD_CWeaponSpawn_GiveItem_Pre(int pThis, DHookReturn hReturn, DHookParam hParams) {
	if (pThis <= MaxClients || !IsValidEntity(pThis))
		return MRES_Ignored;

	static char cls[64];
	if (!GetEntityNetClass(pThis, cls, sizeof cls))
		return MRES_Ignored;

	if (strcmp(cls, "CWeaponSpawn") != 0)
		return MRES_Ignored;

	if (GetEntProp(pThis, Prop_Data, "m_itemCount") <= 0) {
		RemoveEntity(pThis);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	hParams.GetString(2, cls, sizeof cls);
	L4D2WeaponId weaponId = L4D2_GetWeaponIdByWeaponName(cls);
	if (weaponId <= L4D2WeaponId_None || g_iItemRules[weaponId] < 0)
		return MRES_Ignored;

	if (!g_iItemRules[weaponId]) {
		RemoveEntity(pThis);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	if (!bIsValidEntRef(g_iSpawner[pThis][EntRef])) {
		g_iSpawner[pThis][EntRef] = EntIndexToEntRef(pThis);
		g_iSpawner[pThis][UseCount] = 0;
	}

	int count = g_iItemRules[weaponId] - g_iSpawner[pThis][UseCount];
	if (count <= 0) {
		RemoveEntity(pThis);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	SetEntProp(pThis, Prop_Data, "m_itemCount", count);
	g_bRemoveSpawner = count == 1;
	g_iSpawner[pThis][UseCount]++;
	return MRES_Ignored;
}

MRESReturn DD_CWeaponSpawn_GiveItem_Post(int pThis, DHookReturn hReturn, DHookParam hParams) {
	if (g_bRemoveSpawner && IsValidEntity(pThis))
		RemoveEntity(pThis);

	g_bRemoveSpawner = false;
	return MRES_Ignored;
}

MRESReturn DD_CWeaponSpawn_AbsorbWeapon_Post(int pThis, DHookReturn hReturn, DHookParam hParams) {
	if (!hReturn.Value)
		return MRES_Ignored;

	if (!bIsValidEntRef(g_iSpawner[pThis][EntRef]))
		return MRES_Ignored;

	g_iSpawner[pThis][UseCount]--;
	return MRES_Ignored;
}

L4D2WeaponId L4D2_GetWeaponIdByWeaponName2(const char[] weaponName) {
	static char namebuf[64] = "weapon_";
	L4D2WeaponId weaponId = L4D2_GetWeaponIdByWeaponName(weaponName);

	if (weaponId == L4D2WeaponId_None) {
		strcopy(namebuf[7], sizeof namebuf - 7, weaponName);
		weaponId = L4D2_GetWeaponIdByWeaponName(namebuf);
	}

	return view_as<L4D2WeaponId>(weaponId);
}

bool bIsValidEntRef(int entity) {
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}