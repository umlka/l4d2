#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_NAME				"Incapped Magnum"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.2"
#define PLUGIN_URL				"https://steamcommunity.com/id/sorallll"

#define GAMEDATA				"incap_magnum"

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::OnIncapacitatedAsSurvivor::IncappedWeapon");
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"CTerrorPlayer::OnIncapacitatedAsSurvivor::IncappedWeapon\"");
	else if (patch.Enable()) {
		StoreToAddress(patch.Address + view_as<Address>(hGameData.GetOffset("OS") ? 4 : 1), view_as<int>(GetAddressOfString("weapon_pistol_magnum")), NumberType_Int32);
		PrintToServer("[%s] Enabled patch: \"CTerrorPlayer::OnIncapacitatedAsSurvivor::IncappedWeapon\"", GAMEDATA);
	}

	delete hGameData;
}
