/*====================================================
1.3
	- Fixed the meleeweapons list if some 3rd party map mission do not declare the "meleeweapons".
	- Save the initial meleeweapons list. After changing the new mission, the "meleeweapons" will be restored and redeclared.

1.2
	- Fixed didn'sBasis take effect in time if added Cvars to server.cfg. Thanks to "Target_7" for reporting.

1.1
	- Fixed broken windows signatures.
	- Not forces map to reload any more.
	- Thanks to "Silvers" for reporting and help.

1.0
	- Initial release
======================================================*/
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA 	   "l4d2_melee_spawn_control"
#define FILE_PATH 	   "scripts\\melee\\melee_manifest.txt"
#define DEFAULT_MELEES "fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork;riotshield"

DynamicDetour g_dDetourMeleeWeaponAllowedToExist;
DynamicDetour g_dDetourGameRulesGetMissionInfo;

StringMap g_aMapInitMelee;

Handle g_hSDK_Call_KvGetString; 
Handle g_hSDK_Call_KvSetString; 
Handle g_hSDK_Call_KvFindKey;

ConVar g_hCvarMeleeSpawn;
ConVar g_hCvarAddMelee;

public Plugin myinfo=
{
	name = "l4d2 melee spawn control",
	author = "IA/NanaNana",
	description = "Unlock melee weapons",
	version = "1.3",
	url = "http://forums.alliedmods.net/showthread.php?sBasis=327605"
}

public void OnPluginStart()
{
	LoadGameData();

	g_aMapInitMelee = new StringMap();

	g_hCvarMeleeSpawn = CreateConVar("l4d2_melee_spawn", "", "Melee weapon list for unlock, use ';' to separate between names, e.g: pitchfork,shovel. Empty for no change");
	g_hCvarAddMelee = CreateConVar("l4d2_add_melee", "", "Add melee weapons to map basis melee spawn or l4d2_melee_spawn, use ';' to separate between names. Empty for don'sBasis add");
}

public void OnPluginEnd()
{
	if(!g_dDetourMeleeWeaponAllowedToExist.Disable(Hook_Post, MeleeWeaponAllowedToExistPost))
		SetFailState("Failed to disable detour: CDirectorItemManager::IsMeleeWeaponAllowedToExist");

	if(!g_dDetourGameRulesGetMissionInfo.Disable(Hook_Post, GameRulesGetMissionInfoPost))
		SetFailState("Failed to disable detour: CTerrorGameRules::GetMissionInfo");
}

public MRESReturn MeleeWeaponAllowedToExistPost(DHookReturn hReturn, DHookParam hParams)
{
	/*char sScriptName[32];
	hParams.GetString(1, sScriptName, sizeof(sScriptName));
	if(strcmp(sScriptName, "knife") == 0)
	{
		hReturn.Value = true;
		return MRES_Override;
	}
	
	return MRES_Ignored;*/

	hReturn.Value = true;
	return MRES_Override;
}

public MRESReturn GameRulesGetMissionInfoPost(DHookReturn hReturn)
{
	if(GetGameTime() > 5.0)
		return MRES_Ignored;

	int pThis = hReturn.Value;
	if(pThis == 0)
		return MRES_Ignored;

	char sMap[64], sBasis[512];
	FindConVar("mp_gamemode").GetString(sMap, sizeof(sMap));
	SDKCall(g_hSDK_Call_KvGetString, SDKCall(g_hSDK_Call_KvFindKey, SDKCall(g_hSDK_Call_KvFindKey, SDKCall(g_hSDK_Call_KvFindKey, pThis, "modes", false), sMap, false), "1", false), sMap, sizeof(sMap), "Map", "N/A");
	if(g_aMapInitMelee.GetString(sMap, sBasis, sizeof(sBasis)) == false)
	{
		if(strcmp(sMap, "N/A") != 0)
		{
			SDKCall(g_hSDK_Call_KvGetString, pThis, sBasis, sizeof(sBasis), "meleeweapons", "");
			if(sBasis[0] == 0) //darkwood
				ReadMeleeManifest(sBasis);

			g_aMapInitMelee.SetString(sMap, sBasis, false);
		}
	}

	char sTemp1[512], sTemp2[512];
	g_hCvarMeleeSpawn.GetString(sTemp1, sizeof(sTemp1));
	g_hCvarAddMelee.GetString(sTemp2, sizeof(sTemp2));
	ReplaceString(sTemp1, sizeof(sTemp1), " ", "");
	ReplaceString(sTemp2, sizeof(sTemp2), " ", "");

	if(sTemp1[0] == 0)
	{
		if(sTemp2[0] == 0)
		{
			SDKCall(g_hSDK_Call_KvSetString, pThis, "meleeweapons", sBasis);
			return MRES_Ignored;
		}

		sTemp1 = sBasis[0] != 0 ? sBasis : DEFAULT_MELEES;
	}

	if(sTemp2[0] != 0)
	{
		Format(sTemp1, sizeof(sTemp1), ";%s;", sTemp1);
		int iCount = ReplaceString(sTemp2, sizeof(sTemp2), ";", ";") + 1;
		char[][] sBuffer = new char[iCount][32];
		ExplodeString(sTemp2, ";", sBuffer, iCount, 32);
		sTemp2[0] = 0;

		for(int i; i < iCount; i++)
		{
			if(sBuffer[i][0] == 0)
				continue;
				
			Format(sBuffer[i], 32, ";%s;", sBuffer[i]);
			if(StrContains(sTemp1, sBuffer[i]) == -1)
				StrCat(sTemp2, sizeof(sTemp2), sBuffer[i][1]);
		}

		if(sTemp2[0] != 0)
			StrCat(sTemp1, sizeof(sTemp1), sTemp2);

		strcopy(sTemp1, sizeof(sTemp1), sTemp1[1]);
		sTemp1[strlen(sTemp1) - 1] = 0;
	}

	if(strcmp(sTemp1, sBasis) == 0)
		return MRES_Ignored; // If melee spawn setting same as the mission info, then return

	SDKCall(g_hSDK_Call_KvSetString, pThis, "meleeweapons", sTemp1);
	return MRES_Ignored;
}

void ReadMeleeManifest(char sManifest[512])
{
	File file = OpenFile(FILE_PATH, "r");
	if(file == null)
		file = OpenFile(FILE_PATH, "r", true, NULL_STRING);

	if(file == null)
		return;

	while(!file.EndOfFile())
	{
		char sLine[255];
		if(!file.ReadLine(sLine, sizeof(sLine)))
			break;

		ReplaceString(sLine, sizeof(sLine), " ", "");

		if(strlen(sLine) < 27)
			continue;

		if(SplitStringRight(sLine, "scripts/melee/", sLine, sizeof(sLine)) && SplitString(sLine, ".txt", sLine, sizeof(sLine)) != -1)
			Format(sManifest, sizeof(sManifest), "%s;%s", sManifest, sLine);
	}
	
	if(sManifest[0] != 0)
		strcopy(sManifest, sizeof(sManifest), sManifest[1]);

	file.Close();
}

stock bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen)
{
	int index = StrContains(source, split); // get start index of split string 
	
	if(index == -1) // split string not found.. 
		return false;
	
	index += strlen(split); // get end index of split string
	
	if(index == strlen(source) - 1) // no right side exist
		return false;
	
	strcopy(part, partLen, source[index]); // copy everything after source[ index ] to part 
	return true;
}

void LoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if((g_hSDK_Call_KvGetString = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: KeyValues::GetString");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if((g_hSDK_Call_KvSetString = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: KeyValues::SetString");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::FindKey");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hSDK_Call_KvFindKey = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: KeyValues::FindKey");

	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null)
{
	g_dDetourMeleeWeaponAllowedToExist = DynamicDetour.FromConf(hGameData, "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	if(g_dDetourMeleeWeaponAllowedToExist == null)
		SetFailState("Failed to find signature: CDirectorItemManager::IsMeleeWeaponAllowedToExist");
		
	if(!g_dDetourMeleeWeaponAllowedToExist.Enable(Hook_Post, MeleeWeaponAllowedToExistPost))
		SetFailState("Failed to detour post: CDirectorItemManager::IsMeleeWeaponAllowedToExist");

	g_dDetourGameRulesGetMissionInfo = DynamicDetour.FromConf(hGameData, "CTerrorGameRules::GetMissionInfo");
	if(g_dDetourGameRulesGetMissionInfo == null)
		SetFailState("Failed to find signature: CTerrorGameRules::GetMissionInfo");
		
	if(!g_dDetourGameRulesGetMissionInfo.Enable(Hook_Post, GameRulesGetMissionInfoPost))
		SetFailState("Failed to detour post: CTerrorGameRules::GetMissionInfo");
}
