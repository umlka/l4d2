/*  
*    Fixes for gamebreaking bugs and stupid gameplay aspects
*    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>

#define GAMEDATA "defib_fix"
#define PLUGIN_VERSION	"2.0.3"

GlobalForward
	g_fwdSurvivorDeathModelCreated;

ArrayList
	g_aDeathModel[MAXPLAYERS + 1];

DynamicHook
	g_dhOnStartAction,
	g_dhOnActionComplete;

int
	g_iOwner,
	g_iTempClient,
	g_iDeathModel;

bool
	g_bOnActionComplete;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (GetEngineVersion() != Engine_Left4Dead2) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	
	CreateNative("L4D2_RemovePlayerDeathModel", Native_RemovePlayerDeathModel);

	RegPluginLibrary("defib_fix");
	g_fwdSurvivorDeathModelCreated = new GlobalForward("L4D2_OnSurvivorDeathModelCreated", ET_Event, Param_Cell, Param_Cell);
	return APLRes_Success;
}

int Native_RemovePlayerDeathModel(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client index.");
		return 0;
	}

	Remove(client);
	return 1;
}

public Plugin myinfo = {
	name = "[L4D2]Defib_Fix",
	author = "Lux",
	description = "Fixes defibbing from failing when defibbing an alive character index",
	version = PLUGIN_VERSION,
	url = "forums.alliedmods.net/showthread.php?p=2647018"
};

public void OnPluginStart() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CSurvivorDeathModel::Create");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: DD::CSurvivorDeathModel::Create");
		
	if (!dDetour.Enable(Hook_Pre, DD_CSurvivorDeathModel_Create_Pre))
		SetFailState("Failed to detour pre: DD::CSurvivorDeathModel::Create");

	if (!dDetour.Enable(Hook_Post, DD_CSurvivorDeathModel_Create_Post))
		SetFailState("Failed to detour post: DD::CSurvivorDeathModel::Create");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GetPlayerByCharacter");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: DD::CTerrorPlayer::GetPlayerByCharacter");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_GetPlayerByCharacter_Post))
		SetFailState("Failed to detour post: DD::CTerrorPlayer::GetPlayerByCharacter");
	
	g_dhOnStartAction = DynamicHook.FromConf(hGameData, "DH::CItemDefibrillator::OnStartAction");
	if (!g_dhOnStartAction)
		SetFailState("Failed to create DynamicHook: DH::CItemDefibrillator::OnStartAction");
	
	g_dhOnActionComplete = DynamicHook.FromConf(hGameData, "DH::CItemDefibrillator::OnActionComplete");
	if (!g_dhOnActionComplete)
		SetFailState("Failed to create DynamicHook: DH::CItemDefibrillator::OnActionComplete");

	delete hGameData;

	CreateConVar("defib_fix_version", PLUGIN_VERSION, "[L4D2]Defib_Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	for (int i = 1; i <= MaxClients; i++)
		g_aDeathModel[i] = new ArrayList();

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
}

public void OnMapEnd() {
	for (int i = 1; i <= MaxClients; i++)
		g_aDeathModel[i].Clear();
}

public void OnClientDisconnect(int client) {
	g_aDeathModel[client].Clear();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || GetClientTeam(player) != 2) 
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (bot) {
		if (!g_aDeathModel[bot].Length)
			g_aDeathModel[player].Clear();
		else {
			ArrayList aTempArray = g_aDeathModel[player];
			g_aDeathModel[player] = g_aDeathModel[bot];
			g_aDeathModel[bot] = aTempArray;
		}

		g_aDeathModel[bot].Clear();
	}
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot) || GetClientTeam(bot) != 2)
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if (player) {
		if (!g_aDeathModel[player].Length)
			g_aDeathModel[bot].Clear();
		else {
			ArrayList aTempArray = g_aDeathModel[bot];
			g_aDeathModel[bot] = g_aDeathModel[player];
			g_aDeathModel[player] = aTempArray;
		}

		g_aDeathModel[player].Clear();
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (classname[0] != 'w' || strcmp(classname[7], "defibrillator", false) != 0)
	 	return;

	g_dhOnStartAction.HookEntity(Hook_Pre, entity, DH_CItemDefibrillator_OnStartAction_Pre);
	g_dhOnActionComplete.HookEntity(Hook_Pre, entity, DH_CItemDefibrillator_OnActionComplete_Pre);
	g_dhOnActionComplete.HookEntity(Hook_Post, entity, DH_CItemDefibrillator_OnActionComplete_Post);
}


MRESReturn DD_CSurvivorDeathModel_Create_Pre(int pThis) {
	g_iTempClient = pThis;
	return MRES_Ignored;
}

MRESReturn DD_CSurvivorDeathModel_Create_Post(int pThis, DHookReturn hReturn) {
	int deathModel = hReturn.Value;
	if (!deathModel)
		return MRES_Ignored;

	if (!IsClientInGame(g_iTempClient))
		return MRES_Ignored;

	float vPos[3];
	GetClientAbsOrigin(g_iTempClient, vPos);
	TeleportEntity(deathModel, vPos, NULL_VECTOR, NULL_VECTOR);

	g_aDeathModel[g_iTempClient].Push(EntIndexToEntRef(deathModel));

	Call_StartForward(g_fwdSurvivorDeathModelCreated);
	Call_PushCell(g_iTempClient);
	Call_PushCell(deathModel);
	Call_Finish();

	return MRES_Ignored;
}

MRESReturn DH_CItemDefibrillator_OnStartAction_Pre(DHookReturn hReturn, DHookParam hParams) {
	int deathModel = hParams.Get(3);
	if (!deathModel || !IsValidEntity(deathModel))
		return MRES_Ignored;

	if (AllSurAlive()) {
		RemoveAll();
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	if (!FindOwner(EntIndexToEntRef(deathModel))) {
		RemoveEntity(deathModel);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn DH_CItemDefibrillator_OnActionComplete_Pre(DHookReturn hReturn, DHookParam hParams) {
	int deathModel = hParams.Get(2);
	if (!deathModel || !IsValidEntity(deathModel))
		return MRES_Ignored;

	if (AllSurAlive()) {
		RemoveAll();
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	if (!FindOwner(EntIndexToEntRef(deathModel))) {
		RemoveEntity(deathModel);
		hReturn.Value = 0;
		return MRES_Supercede;
	}
	
	g_bOnActionComplete = true;
	g_iDeathModel = EntIndexToEntRef(deathModel);
	return MRES_Ignored;
}

MRESReturn DH_CItemDefibrillator_OnActionComplete_Post(DHookReturn hReturn, DHookParam hParams) {
	if (AllSurAlive())
		RemoveAll();
	else if (g_iOwner)
		Remove(g_iOwner);

	g_iOwner = 0;
	g_iDeathModel = 0;
	g_bOnActionComplete = false;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GetPlayerByCharacter_Post(DHookReturn hReturn, DHookParam hParams) {
	if (!g_bOnActionComplete)
		return MRES_Ignored;

	g_iOwner = FindOwner(g_iDeathModel);
	if (!g_iOwner) {
		if (EntRefToEntIndex(g_iDeathModel) != INVALID_ENT_REFERENCE)
			RemoveEntity(g_iDeathModel);

		hReturn.Value = 0;
		return MRES_Supercede;
	}

	hReturn.Value = g_iOwner;
	return MRES_Supercede;
}

int FindOwner(int deathModelRef) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerAlive(i) && g_aDeathModel[i].FindValue(deathModelRef) != -1)
			return i;
	}
	return 0;
}

bool AllSurAlive() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerAlive(i))
			return false;
	}
	return true;
}

void Remove(int client) {
	int entRef;
	int count = g_aDeathModel[client].Length;
	for (int i; i < count; i++) {
		if (EntRefToEntIndex((entRef = g_aDeathModel[client].Get(i))) != INVALID_ENT_REFERENCE)
			RemoveEntity(entRef);
	}

	g_aDeathModel[client].Clear();
}

void RemoveAll() {
	int entity = MaxClients + 1;
	while ((entity = FindEntityByClassname(entity, "survivor_death_model")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);

	for (entity = 1; entity <= MaxClients; entity++)
		g_aDeathModel[entity].Clear();
}
