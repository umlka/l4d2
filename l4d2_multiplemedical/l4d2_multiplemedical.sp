#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d_weapon_stocks>

#define PLUGIN_VERSION "1.1"

//ArrayList g_ListSpawner;

int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iGlobalWeaponRules[view_as<int>(L4D2WeaponId)] = {-1, ...};

public Plugin myinfo = 
{
	name = "L4D2 Multiple Medical",
	author = "",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
	//HookEvent("spawner_give_item", Event_SpawnerGiveItem, EventHookMode_Pre);
	
	RegServerCmd("addweaponmultiple", CmdAddWeaponMultiple);
	RegServerCmd("resetweaponmultiple", CmdResetWeaponMultiple);

	//g_ListSpawner = new ArrayList(2);
	
	ResetWeaponRules();
}

public Action CmdAddWeaponMultiple(int args)
{
    if(args < 2)
    {
        LogMessage("Usage: addweaponmultiple <match> <multiple>");
        return Plugin_Handled;
    }

    char sBuffer[64];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));
    L4D2WeaponId match = L4D2_GetWeaponIdByWeaponName2(sBuffer);

    GetCmdArg(2, sBuffer, sizeof(sBuffer));
    int multiple = StringToInt(sBuffer);

    AddWeaponMultiple(match, multiple);
    return Plugin_Handled;
}

void AddWeaponMultiple(L4D2WeaponId match, int multiple)
{
	if(L4D2_IsValidWeaponId(match) && multiple >= 0)
        g_iGlobalWeaponRules[match] = multiple;
}

public Action CmdResetWeaponMultiple(int args)
{
    ResetWeaponRules();
    return Plugin_Handled;
}
	
void ResetWeaponRules()
{
    for(int i; i < view_as<int>(L4D2WeaponId); i++) 
		g_iGlobalWeaponRules[i] = -1;
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	//g_ListSpawner.Clear();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		CreateTimer(0.1, Timer_UpdateCounts, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		CreateTimer(0.1, Timer_UpdateCounts, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public Action Timer_UpdateCounts(Handle timer)
{
	int iEntityCount = GetEntityCount();
	for(int i = 1; i < iEntityCount; i++)
	{
		L4D2WeaponId source = IdentifyWeapon(i);
		if(source > L4D2WeaponId_None && g_iGlobalWeaponRules[source] >= 0)
		{
			if(g_iGlobalWeaponRules[source] == 0)
				RemoveEntity(i);
			else
			{
				static char sCount[5];
				IntToString(g_iGlobalWeaponRules[source], sCount, sizeof(sCount));
				DispatchKeyValue(i, "count", sCount);
			}
		}
	}
}

stock L4D2WeaponId L4D2_GetWeaponIdByWeaponName2(const char[] classname)
{
    static char sBuffer[64] = "weapon_";
    L4D2WeaponId wepid = L4D2_GetWeaponIdByWeaponName(classname);
    if(wepid == L4D2WeaponId_None)
    {
        strcopy(sBuffer[7], sizeof(sBuffer) - 7, classname);
        wepid = L4D2_GetWeaponIdByWeaponName(sBuffer);
    }
    return view_as<L4D2WeaponId>(wepid);
}

stock L4D2WeaponId IdentifyWeapon(int entity)
{
	if(!entity || !IsValidEntity(entity))
		return L4D2WeaponId_None;

	static char classname[64];
	if(!GetEdictClassname(entity, classname, sizeof(classname)))
		return L4D2WeaponId_None;

	if(strcmp(classname, "weapon_spawn") == 0)
		return view_as<L4D2WeaponId>(GetEntProp(entity,Prop_Send,"m_weaponID"));

	int len = strlen(classname);
	if(len - 6 > 0 && strcmp(classname[len - 6], "_spawn") == 0)
	{
		classname[len - 6] = '\0';
		return L4D2_GetWeaponIdByWeaponName(classname);
	}

	return L4D2_GetWeaponIdByWeaponName(classname);
}
/*
public void OnEntityDestroyed(int entity)
{
	if(entity <= MaxClients || entity > 2048)
		return;

	L4D2WeaponId source = IdentifyWeapon(entity);
	if(source > L4D2WeaponId_None && g_iGlobalWeaponRules[source] > 0)
	{
		int index = g_ListSpawner.FindValue(EntIndexToEntRef(entity), 0);
		if(index != -1)
			g_ListSpawner.Erase(index);
	}
}

public void Event_SpawnerGiveItem(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("spawner");
	if(entity <= MaxClients || entity > 2048 || !IsValidEntity(entity))
		return;

	int iCount = GetEntProp(entity, Prop_Data, "m_itemCount");
	if(iCount & (1 << 3))
		return;	// Infinite ammo

	L4D2WeaponId source = IdentifyWeapon(entity);
	if(source > L4D2WeaponId_None && g_iGlobalWeaponRules[source] > 0)
	{
		if(g_iGlobalWeaponRules[source] == 1)
			RemoveEntity(entity);
		else
		{
			int index = g_ListSpawner.FindValue(EntIndexToEntRef(entity), 0);
			if(index == -1)
			{
				SetEntProp(entity, Prop_Data, "m_itemCount", g_iGlobalWeaponRules[source]);
				g_ListSpawner.Set(g_ListSpawner.Push(EntIndexToEntRef(entity)), g_iGlobalWeaponRules[source], 1);
			}
			else
			{
				if((iCount = g_ListSpawner.Get(index, 1)) <= 1)
					RemoveEntity(entity);
				else
					g_ListSpawner.Set(index, iCount--, 1);
			}
		}
	}
}*/
