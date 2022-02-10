#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define GAMEDATA "aggresive_specials_patch"

enum struct esPatch
{
	ArrayList g_aByteSaved;
	Address g_pPatchAddress;
}

esPatch
	g_esPatch[2];

public Plugin myinfo = 
{
	name = "Aggresive Specials Patch",
	author = "sorallll",
	description = "在非脚本模式下实现cm_AggressiveSpecials = 1的效果",
	version = "1.1.0",
	url = ""
};

public void OnPluginStart()
{
	vLoadGameData();
	vSpecialsShouldAssaultPatch(true);
	vAggresiveSpecialsPatch(true);
}

public void OnPluginEnd()
{
	vSpecialsShouldAssaultPatch(false);
	vAggresiveSpecialsPatch(false);
}

void vSpecialsShouldAssaultPatch(bool bPatch)
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		int iLength = g_esPatch[0].g_aByteSaved.Length;
		for(int i; i < iLength; i++)
			StoreToAddress(g_esPatch[0].g_pPatchAddress + view_as<Address>(i), 0x90, NumberType_Int8);
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		int iLength = g_esPatch[0].g_aByteSaved.Length;
		for(int i; i < iLength; i++)
			StoreToAddress(g_esPatch[0].g_pPatchAddress + view_as<Address>(i), g_esPatch[0].g_aByteSaved.Get(i), NumberType_Int8);
	}
}

void vAggresiveSpecialsPatch(bool bPatch)
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		int iLength = g_esPatch[1].g_aByteSaved.Length;
		for(int i; i < iLength; i++)
			StoreToAddress(g_esPatch[1].g_pPatchAddress + view_as<Address>(i), 0x79, NumberType_Int8);
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		int iLength = g_esPatch[1].g_aByteSaved.Length;
		for(int i; i < iLength; i++)
			StoreToAddress(g_esPatch[1].g_pPatchAddress + view_as<Address>(i), g_esPatch[1].g_aByteSaved.Get(i), NumberType_Int8);
	}
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

	vRegisterSpecialsShouldAssaultPatch(hGameData);
	vRegisterAggresiveSpecialsPatch(hGameData);

	delete hGameData;
}

void vRegisterSpecialsShouldAssaultPatch(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("SpecialsShouldAssault_Offset");
	if(iOffset == -1)
		SetFailState("Failed to load offset: SpecialsShouldAssault_Offset");

	int iByteMatch = hGameData.GetOffset("SpecialsShouldAssault_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to load byte: SpecialsShouldAssault_Byte");

	int iByteCount = hGameData.GetOffset("SpecialsShouldAssault_Count");
	if(iByteCount == -1)
		SetFailState("Failed to load count: SpecialsShouldAssault_Count");

	g_esPatch[0].g_pPatchAddress = hGameData.GetAddress("CDirectorChallengeMode::SpecialsShouldAssault");
	if(!g_esPatch[0].g_pPatchAddress)
		SetFailState("Failed to load address: CDirectorChallengeMode::SpecialsShouldAssault");
	
	g_esPatch[0].g_pPatchAddress += view_as<Address>(iOffset);

	g_esPatch[0].g_aByteSaved = new ArrayList();

	for(int i; i < iByteCount; i++)
		g_esPatch[0].g_aByteSaved.Push(LoadFromAddress(g_esPatch[0].g_pPatchAddress + view_as<Address>(i), NumberType_Int8));
	
	if(g_esPatch[0].g_aByteSaved.Get(0) != iByteMatch)
		SetFailState("Failed to load 'CDirectorChallengeMode::SpecialsShouldAssault', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_esPatch[0].g_aByteSaved.Get(0), iByteMatch);
}

void vRegisterAggresiveSpecialsPatch(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("SpecialsShouldAdvanceOnSurvivors_Offset");
	if(iOffset == -1)
		SetFailState("Failed to load offset: SpecialsShouldAdvanceOnSurvivors_Offset");

	int iByteMatch = hGameData.GetOffset("SpecialsShouldAdvanceOnSurvivors_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to load byte: SpecialsShouldAdvanceOnSurvivors_Byte");

	int iByteCount = hGameData.GetOffset("SpecialsShouldAdvanceOnSurvivors_Count");
	if(iByteCount == -1)
		SetFailState("Failed to load count: SpecialsShouldAdvanceOnSurvivors_Count");

	g_esPatch[1].g_pPatchAddress = hGameData.GetAddress("CDirector::SpecialsShouldAdvanceOnSurvivors");
	if(!g_esPatch[1].g_pPatchAddress)
		SetFailState("Failed to load address: CDirector::SpecialsShouldAdvanceOnSurvivors");
	
	g_esPatch[1].g_pPatchAddress += view_as<Address>(iOffset);

	g_esPatch[1].g_aByteSaved = new ArrayList();

	for(int i; i < iByteCount; i++)
		g_esPatch[1].g_aByteSaved.Push(LoadFromAddress(g_esPatch[1].g_pPatchAddress + view_as<Address>(i), NumberType_Int8));
	
	if(g_esPatch[1].g_aByteSaved.Get(0) != iByteMatch)
		SetFailState("Failed to load 'CDirector::SpecialsShouldAdvanceOnSurvivors', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, g_esPatch[1].g_aByteSaved.Get(0), iByteMatch);
}