#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define GAMEDATA "l4d2_air_data"

public Plugin myinfo =
{
	name = "[L4D2] Air Patch",
	author = "BHaType (thanks Vit_amin for testing on his Linux server)",
	description = "Patching abilities of special infected also patch zoom for survivors",
	version = "1.0",
	url = "Nope"
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false) 
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData("l4d2_air_data");
	if(hGameData == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	
	Address pAddress = hGameData.GetAddress("CVomit::IsAbilityReadyToFire");
	StoreToAddress(pAddress + view_as<Address>(hGameData.GetOffset("boomer_offset")), 0x00, NumberType_Int8);
	
	pAddress = hGameData.GetAddress("CCharge::ActivateAbility");
	int oOffset = hGameData.GetOffset("charger_ability");
			
	for(int i; i <= 3; i++)
		StoreToAddress(pAddress + view_as<Address>(oOffset + i), 0x00, NumberType_Int8);

	delete hGameData;
}