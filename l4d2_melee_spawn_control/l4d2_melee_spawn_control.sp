#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define MAX_MELEE		16
#define GAMEDATA		"l4d2_melee_spawn_control"
#define MANIFEST		"scripts\\melee\\melee_manifest.txt"
#define MELEEWEAPONS	"fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork"

StringMap
	g_smDefMelee;

Handle
	g_hSDK_CTerrorGameRules_GetMissionInfo,
	g_hSDK_CTerrorGameRules_GetMissionFirstMap,
	g_hSDK_KeyValues_GetString,
	g_hSDK_KeyValues_SetString;

ConVar
	g_cvBaseMelees,
	g_cvExtraMelees;

public Plugin myinfo = {
	name = "l4d2 melee spawn control",
	author = "IA/NanaNana, sorallll",
	description = "Unlock melee weapons",
	version = "1.6",
	url = "https://forums.alliedmods.net/showthread.php?p=2719531"
}

public void OnPluginStart() {
	InitData();
	g_smDefMelee = new StringMap();

	g_cvBaseMelees = 	CreateConVar("l4d2_melee_spawn", 	"", "Melee weapon list for unlock, use ';' to separate between names, e.g: pitchfork;shovel. Empty for no change");
	g_cvExtraMelees =	CreateConVar("l4d2_add_melee", 		"", "Add melee weapons to map basis melee spawn or l4d2_melee_spawn, use ';' to separate between names. Empty for don't add");
}

MRESReturn DD_CMeleeWeaponInfoStore_LoadScripts_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams) {
	int kvMission = SDKCall(g_hSDK_CTerrorGameRules_GetMissionInfo);
	if (!kvMission)
		return MRES_Ignored;

	int kvFirstMap = SDKCall(g_hSDK_CTerrorGameRules_GetMissionFirstMap, 0);
	if (!kvFirstMap)
		return MRES_Ignored;

	char map[64];
	SDKCall(g_hSDK_KeyValues_GetString, kvFirstMap, map, sizeof map, "map", "");
	if (!map[0])
		return MRES_Ignored;

	char def[512];
	StringToLowerCase(map);
	if (!g_smDefMelee.GetString(map, def, sizeof def)) {
		char cur[512];
		SDKCall(g_hSDK_KeyValues_GetString, kvMission, cur, sizeof cur, "meleeweapons", "");

		if (cur[0])
			strcopy(def, sizeof def, cur);
		else
			LoadMeleeStrFromManifest(def, sizeof def); //Dark Wood (Extended), Divine Cybermancy

		if (!def[0])
			strcopy(def, sizeof def, MELEEWEAPONS);

		g_smDefMelee.SetString(map, def, false);
	}

	char set[512];
	set = GetMapMeleeStr(def);
	if (!set[0])
		return MRES_Ignored;

	SDKCall(g_hSDK_KeyValues_SetString, kvMission, "meleeweapons", set);
	return MRES_Ignored;
}

MRESReturn DD_CDirectorItemManager_IsMeleeWeaponAllowedToExistPost(Address pThis, DHookReturn hReturn, DHookParam hParams) {
	/**char sScriptName[32];
	hParams.GetString(1, sScriptName, sizeof sScriptName);
	if (strcmp(sScriptName, "knife", false) == 0) {
		hReturn.Value = 1;
		return MRES_Override;
	}
	
	return MRES_Ignored;*/

	hReturn.Value = 1;
	return MRES_Override;
}

void LoadMeleeStrFromManifest(char[] meleeStr, int maxlength) {
	File file = OpenFile(MANIFEST, "r", true);
	if (file) {
		char str[PLATFORM_MAX_PATH];
		char val[PLATFORM_MAX_PATH];
		while (!file.EndOfFile() && file.ReadLine(str, sizeof str)) {
			TrimString(str);
			if (!KvGetValue(str, "file", val, sizeof val))
				continue;

			if (SplitString(val, ".txt", val, sizeof val) == -1)
				continue;

			if (SplitStringRight(val, "scripts/melee/", val, sizeof val))
				Format(meleeStr, maxlength, "%s;%s", meleeStr, val);
		}
	
		delete file;
		strcopy(meleeStr, maxlength, meleeStr[1]);
	}
}

// [L4D1 & L4D2] Map changer with rating system (https://forums.alliedmods.net/showthread.php?t=311161)
bool KvGetValue(const char[] str, const char[] key, char[] value, int maxlength) {
	value[0] = '\0';
	int posKey, posComment, sizeKey;
	char substr[64];
	FormatEx(substr, sizeof substr, "\"%s\"", key);

	posKey = StrContains(str, substr, false);
	if (posKey != -1) {
		posComment = StrContains(str, "//", true);
		if (posComment == -1 || posComment > posKey) {
			sizeKey = strlen(substr);
			UnQuote(str[posKey + sizeKey], value, maxlength);
			return true;
		}
	}
	return false;
}

void UnQuote(const char[] str, char[] result, int maxlength) {
	int pos;
	static char buf[64];
	strcopy(buf, sizeof buf, str);
	TrimString(buf);
	if (buf[0] == '\"')
		strcopy(buf, sizeof buf, buf[1]);

	pos = FindCharInString(buf, '\"');
	if (pos != -1)
		buf[pos] = '\x0';

	strcopy(result, maxlength, buf);
}

// https://forums.alliedmods.net/showpost.php?p=2094396&postcount=6
bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen) {
	int idx = StrContains(source, split);
	if (idx == -1)
		return false;

	idx += strlen(split);
	if (idx == strlen(source) - 1)
		return false;

	strcopy(part, partLen, source[idx]);
	return true;
}

char[] GetMapMeleeStr(const char[] source) {
	char base[512];
	char extra[512];
	g_cvBaseMelees.GetString(base, sizeof base);
	g_cvExtraMelees.GetString(extra, sizeof extra);
	if (!base[0]) {
		if (!extra[0])
			return base;

		strcopy(base, sizeof base, source);
	}

	ArrayList al_melee = new ArrayList(ByteCountToCells(32));
	ParseMeleeStr(base, al_melee);
	if (extra[0])
		ParseMeleeStr(extra, al_melee);

	base[0] = '\0';
	int count = al_melee.Length;
	if (!count) {
		delete al_melee;
		return base;
	}

	if (count > MAX_MELEE)
		count = MAX_MELEE;

	char meleeStr[32];
	al_melee.GetString(0, meleeStr, sizeof meleeStr);
	StrCat(base, sizeof base, meleeStr);

	for (int i = 1; i < count; i++) {
		StrCat(base, sizeof base, ";");
		al_melee.GetString(i, meleeStr, sizeof meleeStr);
		StrCat(base, sizeof base, meleeStr);
	}

	delete al_melee;
	return base;
}

void ParseMeleeStr(const char[] source, ArrayList array) {
	int reloc_idx, idx;
	char meleeStr[32];
	char path[PLATFORM_MAX_PATH];

	while ((idx = SplitString(source[reloc_idx], ";", meleeStr, sizeof meleeStr)) != -1) {
		reloc_idx += idx;
		TrimString(meleeStr);
		if (!meleeStr[0])
			continue;

		StringToLowerCase(meleeStr);
		if (array.FindString(meleeStr) != -1)
			continue;
			
		FormatEx(path, sizeof path, "scripts/melee/%s.txt", meleeStr);
		if (!FileExists(path, true))
			continue;

		array.PushString(meleeStr);
	}

	if (reloc_idx > 0) {
		strcopy(meleeStr, sizeof meleeStr, source[reloc_idx]);
		TrimString(meleeStr);
		if (meleeStr[0]) {
			StringToLowerCase(meleeStr);
			if (array.FindString(meleeStr) == -1) {
				FormatEx(path, sizeof path, "scripts/melee/%s.txt", meleeStr);
				if (FileExists(path, true))
					array.PushString(meleeStr);
			}
		}
	}
}

/**
 * Converts the given string to lower case
 *
 * @param szString	Input string for conversion and also the output
 * @return			void
 */
void StringToLowerCase(char[] szInput) {
	int iIterator;
	while (szInput[iIterator] != EOS) {
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}

void InitData() {
	char meleeStr[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, meleeStr, sizeof meleeStr, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(meleeStr))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", meleeStr);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionInfo"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionInfo\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CTerrorGameRules_GetMissionInfo = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionInfo\"");

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionFirstMap"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionFirstMap\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain, VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CTerrorGameRules_GetMissionFirstMap = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionFirstMap\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString"))
		SetFailState("Failed to find signature: \"KeyValues::GetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_GetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetString\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString"))
		SetFailState("Failed to find signature: \"KeyValues::SetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_SetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::SetString\"");

	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CMeleeWeaponInfoStore::LoadScripts");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CMeleeWeaponInfoStore::LoadScripts\"");
		
	if (!dDetour.Enable(Hook_Pre, DD_CMeleeWeaponInfoStore_LoadScripts_Pre))
		SetFailState("Failed to detour pre: \"DD::CMeleeWeaponInfoStore::LoadScripts\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist\"");
		
	if (!dDetour.Enable(Hook_Post, DD_CDirectorItemManager_IsMeleeWeaponAllowedToExistPost))
		SetFailState("Failed to detour post: \"DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist\"");
}
