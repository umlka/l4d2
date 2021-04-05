#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

#define GAMEDATA "tank_animation_accelerator"

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
	EngineVersion test = GetEngineVersion();
	if(test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadGameData();

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
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
	DynamicDetour dDetour;
	dDetour = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Int, ThisPointer_CBaseEntity);
	dDetour.SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SelectWeightedSequence");
	dDetour.AddParam(HookParamType_Int);
	dDetour.Enable(Hook_Pre, OnSequenceSetPre);
	dDetour.Enable(Hook_Post, OnSequenceSetPost);
}

//https://forums.alliedmods.net/showpost.php?p=2673097&postcount=18
int GetAnimation(int entity, const char[] sSequence)
{
	if(entity < 1 || entity > MaxClients || !IsValidEntity(entity))
		return -1;
	
	char sModel[64];
	GetClientModel(entity, sModel, sizeof(sModel));

	int iEntity = CreateEntityByName("prop_dynamic");
	if(iEntity == -1)
		return -1;

	SetEntityModel(iEntity, sModel);
	SetVariantString(sSequence);
	AcceptEntityInput(iEntity, "SetAnimation");
	int iResult = GetEntProp(iEntity, Prop_Send, "m_nSequence");
	RemoveEdict(iEntity);

	return iResult;
}

public MRESReturn OnSequenceSetPre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
    /*Nothing*/
}

public MRESReturn OnSequenceSetPost(int pThis, DHookReturn hReturn, DHookParam hParams)
{
    if(pThis <= 0 || pThis > MaxClients || !IsClientInGame(pThis) || GetClientTeam(pThis) != 3 || !IsPlayerAlive(pThis) || GetEntProp(pThis, Prop_Send, "m_zombieClass") != 8 || GetEntProp(pThis, Prop_Send, "m_isGhost") == 1)
        return MRES_Ignored;

    int sequence = hReturn.Value;
    if(54 <= sequence <= 60) //https://forums.alliedmods.net/showpost.php?p=2669064&postcount=2
    {
		hReturn.Value = GetAnimation(pThis, "ACT_HULK_ATTACK_LOW");
		SetEntPropFloat(pThis, Prop_Send, "m_flCycle", 10.0);
		return MRES_Override;
    }

    return MRES_Ignored;
} 

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		Unhook(i);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	Unhook(client);

	if(client && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
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
		SDKHook(client, SDKHook_PostThinkPost, UpdateThink);
	}
}

void Unhook(int client)
{
	if(g_bHookedThinkPost[client])
	{
		g_bHookedThinkPost[client] = false;
		SDKUnhook(client, SDKHook_PostThinkPost, UpdateThink);
	}
}

public void UpdateThink(int client)
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