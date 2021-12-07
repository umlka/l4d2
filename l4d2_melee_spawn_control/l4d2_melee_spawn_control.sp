/*====================================================
1.3
	- Fixed the meleeweapons list if some 3rd party map mission do not declare the "meleeweapons".
	- Save the initial meleeweapons list. After changing the new mission, the "meleeweapons" will be restored and redeclared.

1.2
	- Fixed didn't take effect in time if added Cvars to server.cfg. Thanks to "Target_7" for reporting.

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
#include <dhooks>

#define MAX_MELEE		16
#define GAMEDATA		"l4d2_melee_spawn_control"
#define MELEE_MANIFEST	"scripts\\melee\\melee_manifest.txt"
#define DEFAULT_MELEES	"fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork"

DynamicDetour
	g_dDetour[2];

StringMap
	g_aMapSetMelees,
	g_aMapInitMelees;

Handle
	g_hSDK_Call_KvGetString,
	g_hSDK_Call_KvSetString;

ConVar
	g_hBaseMelees,
	g_hExtraMelees;

bool
	g_bMapStarted;

public Plugin myinfo=
{
	name = "l4d2 melee spawn control",
	author = "IA/NanaNana",
	description = "Unlock melee weapons",
	version = "1.4",
	url = "https://forums.alliedmods.net/showthread.php?p=2719531"
}

public void OnPluginStart()
{
	vLoadGameData();

	g_hBaseMelees = CreateConVar("l4d2_melee_spawn", "", "Melee weapon list for unlock, use ';' to separate between names, e.g: pitchfork;shovel. Empty for no change");
	g_hExtraMelees = CreateConVar("l4d2_add_melee", "", "Add melee weapons to map basis melee spawn or l4d2_melee_spawn, use ';' to separate between names. Empty for don't add");

	g_aMapSetMelees = new StringMap();
	g_aMapInitMelees = new StringMap();
}

public void OnPluginEnd()
{
	if(!g_dDetour[0].Disable(Hook_Post, mreMeleeAllowedPost))
		SetFailState("Failed to disable detour: CDirectorItemManager::IsMeleeWeaponAllowedToExist");

	if(!g_dDetour[1].Disable(Hook_Post, mreGetMissionInfoPost))
		SetFailState("Failed to disable detour: CTerrorGameRules::GetMissionInfo");
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	g_aMapSetMelees.Clear();
}

MRESReturn mreMeleeAllowedPost(DHookReturn hReturn, DHookParam hParams)
{
	/*char sScriptName[32];
	hParams.GetString(1, sScriptName, sizeof(sScriptName));
	if(strcmp(sScriptName, "knife") == 0)
	{
		hReturn.Value = 1;
		return MRES_Override;
	}
	
	return MRES_Ignored;*/

	hReturn.Value = 1;
	return MRES_Override;
}

MRESReturn mreGetMissionInfoPost(DHookReturn hReturn)
{
	if(g_bMapStarted == true)
		return MRES_Ignored;

	int pThis = hReturn.Value;
	if(pThis == 0)
		return MRES_Ignored;

	char sMissionName[64];
	SDKCall(g_hSDK_Call_KvGetString, pThis, sMissionName, sizeof(sMissionName), "Name", "N/A");
	if(strcmp(sMissionName, "N/A") == 0)
		return MRES_Ignored;

	char sMapCurrentMelees[512];
	SDKCall(g_hSDK_Call_KvGetString, pThis, sMapCurrentMelees, sizeof(sMapCurrentMelees), "meleeweapons", "N/A");

	char sMissionBaseMelees[512];
	if(g_aMapInitMelees.GetString(sMissionName, sMissionBaseMelees, sizeof(sMissionBaseMelees)) == false)
	{
		if(strcmp(sMapCurrentMelees, "N/A") != 0)
			strcopy(sMissionBaseMelees, sizeof(sMissionBaseMelees), sMapCurrentMelees);
		else
			vReadMeleeManifest(sMissionBaseMelees, sizeof(sMissionBaseMelees)); //darkwood, eye
			
		if(sMissionBaseMelees[0] == '\0')
			strcopy(sMissionBaseMelees, sizeof(sMissionBaseMelees), DEFAULT_MELEES);

		g_aMapInitMelees.SetString(sMissionName, sMissionBaseMelees, false);
	}

	char sMapSetMelees[512];
	if(g_aMapSetMelees.GetString(sMissionName, sMapSetMelees, sizeof(sMapSetMelees)) == false)
		vGetMapSetMelees(sMissionName, sMissionBaseMelees, sMapSetMelees, sizeof(sMapSetMelees));

	if(sMapSetMelees[0] == '\0')
		return MRES_Ignored;

	if(strcmp(sMapSetMelees, sMapCurrentMelees) == 0)
		return MRES_Ignored;
		
	SDKCall(g_hSDK_Call_KvSetString, pThis, "meleeweapons", sMapSetMelees);
	return MRES_Ignored;
}

void vGetMapSetMelees(const char[] sMissionName, const char[] sMissionBaseMelees, char[] sMapSetMelees, int maxlength)
{
	char sBaseMelees[512], sExtraMelees[512];
	g_hBaseMelees.GetString(sBaseMelees, sizeof(sBaseMelees));
	g_hExtraMelees.GetString(sExtraMelees, sizeof(sExtraMelees));
	ReplaceString(sBaseMelees, sizeof(sBaseMelees), " ", "");
	ReplaceString(sExtraMelees, sizeof(sExtraMelees), " ", "");

	if(sBaseMelees[0] == '\0')
	{
		if(sExtraMelees[0] == '\0')
		{
			g_aMapSetMelees.SetString(sMissionName, "", true);
			return;
		}

		strcopy(sBaseMelees, sizeof(sBaseMelees), sMissionBaseMelees);
	}

	if(sExtraMelees[0] != '\0')
	{
		Format(sBaseMelees, sizeof(sBaseMelees), ";%s;", sBaseMelees);
		int iCount = ReplaceString(sExtraMelees, sizeof(sExtraMelees), ";", ";") + 1;
		char[][] sBuffer = new char[iCount][32];
		ExplodeString(sExtraMelees, ";", sBuffer, iCount, 32);
		sExtraMelees[0] = '\0';

		for(int i; i < iCount; i++)
		{
			if(sBuffer[i][0] == '\0')
				continue;
				
			Format(sBuffer[i], 32, ";%s;", sBuffer[i]);
			if(StrContains(sBaseMelees, sBuffer[i]) == -1)
				StrCat(sExtraMelees, sizeof(sExtraMelees), sBuffer[i][1]);
		}

		if(sExtraMelees[0] != '\0')
			StrCat(sBaseMelees, sizeof(sBaseMelees), sExtraMelees);

		strcopy(sBaseMelees, sizeof(sBaseMelees), sBaseMelees[1]);
		
		sBaseMelees[strlen(sBaseMelees) - 1] = 0;
	}
	
	int pos = iGetCharPosInString(sBaseMelees , ';', MAX_MELEE);
	if(pos != -1)
		sBaseMelees[pos] = '\0';

	strcopy(sMapSetMelees, maxlength, sBaseMelees);
	g_aMapSetMelees.SetString(sMissionName, sBaseMelees, true);
}

int iGetCharPosInString(const char[] str, char c, int position)
{
	int len = strlen(str);
	if(position > len)
		return -1;

	int total;
	for(int i; i < len; i++)
	{
		if(str[i] == c)
		{
			if(++total == position)
				return i;
		}
	}
	return -1;
}

void vReadMeleeManifest(char[] sManifest, int maxlength)
{
	File hFile = OpenFile(MELEE_MANIFEST, "r");
	if(hFile == null)
		hFile = OpenFile(MELEE_MANIFEST, "r", true, NULL_STRING);

	if(hFile == null)
		return;

	char sLine[255];
	while(!hFile.EndOfFile())
	{
		if(!hFile.ReadLine(sLine, sizeof(sLine)))
			break;

		ReplaceString(sLine, sizeof(sLine), " ", "");

		if(strlen(sLine) < 27)
			continue;

		if(bSplitStringRight(sLine, "scripts/melee/", sLine, sizeof(sLine)) && SplitString(sLine, ".txt", sLine, sizeof(sLine)) != -1)
			Format(sManifest, maxlength, "%s;%s", sManifest, sLine);
	}
	
	if(sManifest[0] != '\0')
		strcopy(sManifest, maxlength, sManifest[1]);

	delete hFile;
}

bool bSplitStringRight(const char[] source, const char[] split, char[] part, int partLen)
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

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString") == false)
		SetFailState("Failed to find signature: KeyValues::GetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	g_hSDK_Call_KvGetString = EndPrepSDKCall();
	if(g_hSDK_Call_KvGetString == null)
		SetFailState("Failed to create SDKCall: KeyValues::GetString");

	StartPrepSDKCall(SDKCall_Raw);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString") == false)
		SetFailState("Failed to find signature: KeyValues::SetString");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_hSDK_Call_KvSetString = EndPrepSDKCall();
	if(g_hSDK_Call_KvSetString == null)
		SetFailState("Failed to create SDKCall: KeyValues::SetString");

	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDetours(GameData hGameData = null)
{
	g_dDetour[0] = DynamicDetour.FromConf(hGameData, "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	if(g_dDetour[0] == null)
		SetFailState("Failed to find signature: CDirectorItemManager::IsMeleeWeaponAllowedToExist");
		
	if(!g_dDetour[0].Enable(Hook_Post, mreMeleeAllowedPost))
		SetFailState("Failed to detour post: CDirectorItemManager::IsMeleeWeaponAllowedToExist");

	g_dDetour[1] = DynamicDetour.FromConf(hGameData, "CTerrorGameRules::GetMissionInfo");
	if(g_dDetour[1] == null)
		SetFailState("Failed to find signature: CTerrorGameRules::GetMissionInfo");
		
	if(!g_dDetour[1].Enable(Hook_Post, mreGetMissionInfoPost))
		SetFailState("Failed to detour post: CTerrorGameRules::GetMissionInfo");
}
