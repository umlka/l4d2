/**
 * SourceScramble Manager
 * 
 * A loader for simple memory patches.
 */
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define PLUGIN_NAME				"Source Scramble Manager"
#define PLUGIN_AUTHOR			"nosoop, sorallll"
#define PLUGIN_DESCRIPTION		"Helper plugin to load simple assembly patches from a configuration file."
#define PLUGIN_VERSION			"1.2.2"
#define PLUGIN_URL				"https://github.com/nosoop/SMExt-SourceScramble"

enum struct Patches {
	char file[PLATFORM_MAX_PATH];
	char name[PLATFORM_MAX_PATH];
	bool patched;
	MemoryPatch patch;
}

ArrayList
	g_Patches;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_Patches = new ArrayList(sizeof Patches);

	ParseConfigs();

	RegServerCmd("ssm_list", cmdList);
	RegServerCmd("ssm_patch", cmdPatch);
	RegServerCmd("ssm_unpatch", cmdUnpatch);

	RegServerCmd("ssm_reload", cmdReloadData);
}

Action cmdList(int args) {
	Patches patch;
	int patchCount = g_Patches.Length;

	if (!patchCount) {
		PrintToServer("No patches");
		return Plugin_Handled;
	}

	for (int i; i < patchCount; i++) {
		g_Patches.GetArray(i, patch);
		PrintToServer("[%s] \"%s\" \t\"%s\"", patch.patched ? "●" : "○", patch.file, patch.name);
	}

	return Plugin_Handled;
}

Action cmdPatch(int args) {
	PatchCommand(args, true);
	return Plugin_Handled;
}

Action cmdUnpatch(int args) {
	PatchCommand(args, false);
	return Plugin_Handled;
}

void PatchCommand(int args, bool enable) {
	switch (args) {
		case 0:
			TogglePatch(NULL_STRING, NULL_STRING, enable);

		case 1: {
			char buffer[PLATFORM_MAX_PATH];
			GetCmdArg(1, buffer, sizeof buffer);
			TogglePatch(buffer, NULL_STRING, enable);
		}

		case 2: {
			char file[PLATFORM_MAX_PATH];
			char name[PLATFORM_MAX_PATH];
			GetCmdArg(1, file, sizeof file);
			GetCmdArg(2, name, sizeof name);
			TogglePatch(file, name, enable);
		}
	}
}

Action cmdReloadData(int args) {
	Patches patch;
	int patchCount = g_Patches.Length;
	for (int i; i < patchCount; i++) {
		g_Patches.GetArray(i, patch);
		delete patch.patch;
	}

	g_Patches.Clear();
	ParseConfigs();

	PrintToServer("[sourcescramble] Data config reloaded.");
	return Plugin_Handled;
}

void ParseConfigs() {
	int line;
	SMCError err;
	char error[PLATFORM_MAX_PATH];
	SMCParser parser = new SMCParser();
	parser.OnKeyValue = smcPatchMemConfigEntry;
	
	char configPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof configPath, "configs/sourcescramble_manager.cfg");
	if (FileExists(configPath)) {
		err = parser.ParseFile(configPath, line);
		if (err != SMCError_Okay) {
			SMC_GetErrorString(err, error, sizeof error);
			LogError("Could not parse file (line %d, file \"%s\"):", line, configPath);
			LogError("Parser encountered error: %s", error);
		}
	}

	char configDirectory[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configDirectory, sizeof configDirectory, "configs/sourcescramble");
	if (DirExists(configDirectory)) {
		DirectoryListing dlConfig = OpenDirectory(configDirectory);
		if (dlConfig) {
			char fileEntry[PLATFORM_MAX_PATH];
			FileType dirEntryType;
			while (dlConfig.GetNext(fileEntry, sizeof fileEntry, dirEntryType)) {
				if (dirEntryType != FileType_File)
					continue;

				FormatEx(configPath, sizeof configPath, "%s/%s", configDirectory, fileEntry);
				err = parser.ParseFile(configPath, line);
				if (err != SMCError_Okay) {
					SMC_GetErrorString(err, error, sizeof error);
					LogError("Could not parse file (line %d, file \"%s\"):", line, configPath);
					LogError("Parser encountered error: %s", error);
				}
			}

			delete dlConfig;
		}
	}

	delete parser;
}

SMCResult smcPatchMemConfigEntry(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	static char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", key);
	if (!FileExists(buffer)) {
		LogError("Unable to locate file: \"%s\".", buffer);
		return SMCParse_Continue;
	}

	GameData hGameData = new GameData(key);
	if (!hGameData) {
		LogError("Failed to load \"%s.txt\" gamedata.", key);
		return SMCParse_Continue;
	}

	// patches are cleaned up when the plugin is unloaded
	MemoryPatch mp = MemoryPatch.CreateFromConf(hGameData, value);
	delete hGameData;

	if (!mp.Validate()) {
		LogError("[sourcescramble] Failed to verify patch \"%s\" from \"%s\"", value, key);
		return SMCParse_Continue;
	}

	Patches patch;
	strcopy(patch.file, sizeof patch.file, key);
	strcopy(patch.name, sizeof patch.name, value);
	patch.patch = mp;

	g_Patches.PushArray(patch);

	return SMCParse_Continue;
}

void TogglePatch(const char[] file, const char[] name, bool enable) {
	Patches patch;
	int patchCount = g_Patches.Length;
	for (int i; i < patchCount; i++) {
		g_Patches.GetArray(i, patch);

		if (file[0]) {
			if (strcmp(patch.file, file))
				continue;
		}

		if (name[0]) {
			if (strcmp(patch.name, name))
				continue;
		}

		if (!patch.patched && enable) {
			patch.patch.Enable();
			patch.patched = true;
			PrintToServer("[sourcescramble] Enabled patch \"%s\" from \"%s\" at address: 0x%08X", patch.name, patch.file, patch.patch.Address);
		}
		else if (patch.patched && !enable) {
			patch.patch.Disable();
			patch.patched = false;
			PrintToServer("[sourcescramble] Disabled patch \"%s\" from \"%s\" at address: 0x%08X", patch.name, patch.file, patch.patch.Address);
		}

		g_Patches.SetArray(i, patch, sizeof Patches);
	}
}
