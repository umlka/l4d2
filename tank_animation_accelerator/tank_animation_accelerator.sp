#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define GAMEDATA "tank_animation_accelerator"

DynamicDetour g_dDetour;

bool g_bLateLoad;
bool g_bHookedThinkPost[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Tank Animation Accelerator", 
	author = "Lux, sorallll", 
	description = "", 
	version = "", 
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	if(g_bLateLoad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
				Hook(i);
		}
	}

	LoadGameData();

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
}

public void OnPluginEnd()
{
	if(!g_dDetour.Disable(Hook_Pre, SelectWeightedSequencePre) || !g_dDetour.Disable(Hook_Post, SelectWeightedSequencePost))
		SetFailState("Failed to disable detour: CTerrorPlayer::SelectWeightedSequence");
}

public MRESReturn SelectWeightedSequencePre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
    /*Nothing*/
}

public MRESReturn SelectWeightedSequencePost(int pThis, DHookReturn hReturn, DHookParam hParams)
{
    if(pThis <= 0 || pThis > MaxClients || !IsClientInGame(pThis) || GetClientTeam(pThis) != 3 || !IsPlayerAlive(pThis) || GetEntProp(pThis, Prop_Send, "m_zombieClass") != 8 || GetEntProp(pThis, Prop_Send, "m_isGhost") == 1)
        return MRES_Ignored;

    if(54 <= hReturn.Value <= 60) //https://forums.alliedmods.net/showpost.php?p=2669064&postcount=2
    {
		hReturn.Value = GetAnimation(pThis, "ACT_HULK_ATTACK_LOW");
		SetEntPropFloat(pThis, Prop_Send, "m_flCycle", 15.0);
		return MRES_Override;
    }

    return MRES_Ignored;
} 

//https://forums.alliedmods.net/showpost.php?p=2673097&postcount=18
int GetAnimation(int entity, const char[] sSequence)
{
	int iEntity = CreateEntityByName("prop_dynamic");
	if(iEntity == -1)
		return -1;

	char sModel[64];
	GetClientModel(entity, sModel, sizeof(sModel));
	SetEntityModel(iEntity, sModel);
	SetVariantString(sSequence);
	AcceptEntityInput(iEntity, "SetAnimation");
	int iResult = GetEntProp(iEntity, Prop_Send, "m_nSequence");
	RemoveEdict(iEntity);

	return iResult;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			Unhook(i);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	Unhook(client);

	if(client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
		Hook(client);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	Unhook(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	Unhook(GetClientOfUserId(event.GetInt("userid")));
}

void Hook(int client)
{
	if(!g_bHookedThinkPost[client])
	{
		g_bHookedThinkPost[client] = true;
		SDKHook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
	}
}

void Unhook(int client)
{
	if(g_bHookedThinkPost[client])
	{
		g_bHookedThinkPost[client] = false;
		SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost);
	}
}

public void Hook_PostThinkPost(int client)
{
	if(!IsPlayerAlive(client))
		return;

	switch(GetEntProp(client, Prop_Send, "m_nSequence"))
	{
		case 17: //爬比较矮的障碍,设置的值过大会有几率导致坦克飞出去
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 2.0);

		case 18, 19, 20, 21, 22, 23: //爬围栏/障碍
			SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", 10.0); //不能设置太高否则无法爬上去
	}
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

	SetupDetours(hGameData);

	delete hGameData;
}

void SetupDetours(GameData hGameData = null)
{
	g_dDetour = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Int, ThisPointer_CBaseEntity);
	g_dDetour.SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SelectWeightedSequence");
	g_dDetour.AddParam(HookParamType_Int);
	g_dDetour.Enable(Hook_Pre, SelectWeightedSequencePre);
	g_dDetour.Enable(Hook_Post, SelectWeightedSequencePost);
}
