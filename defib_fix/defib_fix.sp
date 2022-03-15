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
#define PLUGIN_VERSION	"2.0.2"

GlobalForward
	g_FWD_SurvivorDeathModelCreated;

ArrayList
	g_aDeathModel[MAXPLAYERS + 1];

DynamicHook
	g_dDH_OnStartAction,
	g_dDH_OnActionComplete;

int
	g_iOwner,
	g_iTempClient,
	g_iDeathModel;

bool
	g_bOnActionComplete;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("defib_fix");
	g_FWD_SurvivorDeathModelCreated = new GlobalForward("L4D2_OnSurvivorDeathModelCreated", ET_Event, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D2]Defib_Fix",
	author = "Lux",
	description = "Fixes defibbing from failing when defibbing an alive character index",
	version = PLUGIN_VERSION,
	url = "forums.alliedmods.net/showthread.php?p=2647018"
};

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CSurvivorDeathModel::Create");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: DD::CSurvivorDeathModel::Create");
		
	if(!dDetour.Enable(Hook_Pre, DD_CSurvivorDeathModel_Create_Pre))
		SetFailState("Failed to detour pre: DD::CSurvivorDeathModel::Create");

	if(!dDetour.Enable(Hook_Post, DD_CSurvivorDeathModel_Create_Post))
		SetFailState("Failed to detour post: DD::CSurvivorDeathModel::Create");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GetPlayerByCharacter");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: DD::CTerrorPlayer::GetPlayerByCharacter");

	if(!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_GetPlayerByCharacter_Post))
		SetFailState("Failed to detour post: DD::CTerrorPlayer::GetPlayerByCharacter");
	
	g_dDH_OnStartAction = DynamicHook.FromConf(hGameData, "DH::CItemDefibrillator::OnStartAction");
	if(!g_dDH_OnStartAction)
		SetFailState("Failed to create DynamicHook: DH::CItemDefibrillator::OnStartAction");
	
	g_dDH_OnActionComplete = DynamicHook.FromConf(hGameData, "DH::CItemDefibrillator::OnActionComplete");
	if(!g_dDH_OnActionComplete)
		SetFailState("Failed to create DynamicHook: DH::CItemDefibrillator::OnActionComplete");

	delete hGameData;

	CreateConVar("defib_fix_version", PLUGIN_VERSION, "", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	for(int i = 1; i <= MaxClients; i++)
		g_aDeathModel[i] = new ArrayList();

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++)
		g_aDeathModel[i].Clear();
}

public void OnClientDisconnect_Post(int client)
{
	g_aDeathModel[client].Clear();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if(!player || !IsClientInGame(player) || GetClientTeam(player) != 2) 
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(bot)
	{
		if(!g_aDeathModel[bot].Length)
			g_aDeathModel[player].Clear();
		else
		{
			delete g_aDeathModel[player];
			g_aDeathModel[player] = g_aDeathModel[bot].Clone();
		}

		g_aDeathModel[bot].Clear();
	}
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if(!bot || !IsClientInGame(bot) || GetClientTeam(bot) != 2)
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if(player)
	{
		if(!g_aDeathModel[player].Length)
			g_aDeathModel[bot].Clear();
		else
		{
			delete g_aDeathModel[bot];
			g_aDeathModel[bot] = g_aDeathModel[player].Clone();
		}

		g_aDeathModel[player].Clear();
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(classname[0] != 'w' || strcmp(classname[7], "defibrillator", false) != 0)
	 	return;

	g_dDH_OnStartAction.HookEntity(Hook_Pre, entity, DH_CItemDefibrillator_OnStartAction_Pre);
	g_dDH_OnActionComplete.HookEntity(Hook_Pre, entity, DH_CItemDefibrillator_OnActionComplete_Pre);
	g_dDH_OnActionComplete.HookEntity(Hook_Post, entity, DH_CItemDefibrillator_OnActionComplete_Post);
}

MRESReturn DD_CSurvivorDeathModel_Create_Pre(int pThis)
{
	g_iTempClient = pThis;
	return MRES_Ignored;
}

MRESReturn DD_CSurvivorDeathModel_Create_Post(int pThis, DHookReturn hReturn)
{
	int iDeathModel = hReturn.Value;
	if(!iDeathModel)
		return MRES_Ignored;
	
	float vPos[3];
	GetClientAbsOrigin(g_iTempClient, vPos);
	TeleportEntity(iDeathModel, vPos, NULL_VECTOR, NULL_VECTOR);

	g_aDeathModel[g_iTempClient].Push(EntIndexToEntRef(iDeathModel));

	Call_StartForward(g_FWD_SurvivorDeathModelCreated);
	Call_PushCell(g_iTempClient);
	Call_PushCell(iDeathModel);
	Call_Finish();

	return MRES_Ignored;
}

MRESReturn DH_CItemDefibrillator_OnStartAction_Pre(DHookReturn hReturn, DHookParam hParams)
{
	int iDeathModel = hParams.Get(3);
	if(!iDeathModel)
		return MRES_Ignored;

	if(bIsAllSurvivorsAlive())
	{
		vRemoveAllDeathModel();
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	if(!iFindDeathModelOwner(EntIndexToEntRef(iDeathModel)))
	{
		RemoveEntity(iDeathModel);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn DH_CItemDefibrillator_OnActionComplete_Pre(DHookReturn hReturn, DHookParam hParams)
{
	int iDeathModel = hParams.Get(2);
	if(!iDeathModel)
		return MRES_Ignored;

	if(bIsAllSurvivorsAlive())
	{
		vRemoveAllDeathModel();
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	if(!iFindDeathModelOwner(EntIndexToEntRef(iDeathModel)))
	{
		RemoveEntity(iDeathModel);
		hReturn.Value = 0;
		return MRES_Supercede;
	}
	
	g_bOnActionComplete = true;
	g_iDeathModel = iDeathModel;
	return MRES_Ignored;
}

MRESReturn DH_CItemDefibrillator_OnActionComplete_Post(DHookReturn hReturn, DHookParam hParams)
{
	if(bIsAllSurvivorsAlive())
		vRemoveAllDeathModel();
	else if(g_iOwner)
		vRemoveDeathModel(g_iOwner);

	g_iOwner = 0;
	g_iDeathModel = 0;
	g_bOnActionComplete = false;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GetPlayerByCharacter_Post(DHookReturn hReturn, DHookParam hParams)
{
	if(!g_bOnActionComplete)
		return MRES_Ignored;

	g_iOwner = iFindDeathModelOwner(EntIndexToEntRef(g_iDeathModel));
	if(!g_iOwner)
	{
		hParams.Set(1, 8);
		RemoveEntity(g_iDeathModel);
		return MRES_ChangedHandled;
	}

	hReturn.Value = g_iOwner;
	return MRES_Supercede;
}

int iFindDeathModelOwner(int iDeathModelRef)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerAlive(i) && g_aDeathModel[i].FindValue(iDeathModelRef) != -1)
			return i;
	}
	return 0;
}

void vRemoveDeathModel(int client)
{
	int iEntRef;
	int iLength = g_aDeathModel[client].Length;
	for(int i; i < iLength; i++)
	{
		if(EntRefToEntIndex((iEntRef = g_aDeathModel[client].Get(i))) != INVALID_ENT_REFERENCE)
			RemoveEntity(iEntRef);
	}

	g_aDeathModel[client].Clear();
}

bool bIsAllSurvivorsAlive()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerAlive(i))
			return false;
	}
	return true;
}

void vRemoveAllDeathModel()
{
	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "survivor_death_model")) != INVALID_ENT_REFERENCE)
		RemoveEntity(entity);

	for(entity = 1; entity <= MaxClients; entity++)
		g_aDeathModel[entity].Clear();
}
