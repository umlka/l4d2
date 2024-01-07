#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_NAME				"SI Climb Speed Modifier"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

#define GAMEDATA				"si_climb_speed_modifier"

Handle
	g_hSDK_CBaseEntity_GetRefEHandle;

ConVar
	g_cvAIClimbSpeed,
	g_cvPZClimbSpeed;

float
	g_fAIClimbSpeed,
	g_fPZClimbSpeed;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitData();
	CreateConVar("si_climb_speed_modifier_version", PLUGIN_VERSION, "SI Climb Speed Modifier plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvAIClimbSpeed = CreateConVar("l4d2_ai_climb_speed", "0.0", "AI特感爬升速度", FCVAR_NOTIFY, true, 0.0);
	g_cvPZClimbSpeed = CreateConVar("l4d2_pz_climb_speed", "0.0", "玩家特感爬升速度", FCVAR_NOTIFY, true, 0.0);
	g_cvAIClimbSpeed.AddChangeHook(CvarChanged);
	g_cvPZClimbSpeed.AddChangeHook(CvarChanged);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fAIClimbSpeed = g_cvAIClimbSpeed.FloatValue;
	g_fPZClimbSpeed = g_cvPZClimbSpeed.FloatValue;
}

void InitData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetRefEHandle"))
		SetFailState("Failed to find offset: \"CBaseEntity::GetRefEHandle\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_CBaseEntity_GetRefEHandle = EndPrepSDKCall();
	if (!g_hSDK_CBaseEntity_GetRefEHandle)
		SetFailState("Failed to create SDKCall: \"CBaseEntity::GetRefEHandle\"");

	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorGameMovement::ClimbSpeed");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorGameMovement::ClimbSpeed\"");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorGameMovement_ClimbSpeed_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorGameMovement::ClimbSpeed\"");
}

MRESReturn DD_CTerrorGameMovement_ClimbSpeed_Post(Address pThis, DHookReturn hReturn) {
	int client = GetEntityIndex(GetRefEHandle(LoadFromAddress(pThis + view_as<Address>(4), NumberType_Int32)));
	if (!IsSpecialInfected(client))
		return MRES_Ignored;

	if (IsFakeClient(client)) {
		if (g_fAIClimbSpeed) {
			hReturn.Value = g_fAIClimbSpeed;
			return MRES_Supercede;
		}
	}
	else {
		if (g_fPZClimbSpeed) {
			hReturn.Value = g_fPZClimbSpeed;
			return MRES_Supercede;
		}
	}

	return MRES_Ignored;
}

// Entity mask information
#define MAX_EDICT_BITS 11
#define NUM_ENT_ENTRY_BITS (MAX_EDICT_BITS + 1)
#define NUM_ENT_ENTRIES (1 << NUM_ENT_ENTRY_BITS)
#define ENT_ENTRY_MASK (NUM_ENT_ENTRIES - 1)
#define INVALID_EHANDLE_INDEX 0xFFFFFFFF

// [L4D & L4D2] Jump System (https://forums.alliedmods.net/showthread.php?p=2769793)
int GetEntityIndex(int ref) {
	return (ref & ENT_ENTRY_MASK);
}

int GetRefEHandle(Address entityHandle) {
	if (!entityHandle)
		return INVALID_EHANDLE_INDEX;

	Address adRefHandle = SDKCall(g_hSDK_CBaseEntity_GetRefEHandle, entityHandle);
	return LoadFromAddress(adRefHandle, NumberType_Int32);
}

bool IsSpecialInfected(int client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}
