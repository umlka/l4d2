#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d_weapon_stocks>

#define PLUGIN_VERSION "1.1"

ArrayList g_ListSpawner;

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
	HookEvent("spawner_give_item", Event_SpawnerGiveItem, EventHookMode_Pre);
	
	RegServerCmd("addweaponmultiple", CmdAddWeaponMultiple);
	RegServerCmd("resetweaponmultiple", CmdResetWeaponMultiple);

	g_ListSpawner = new ArrayList(2);
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
    L4D2WeaponId match = L4D2_GetWeaponIdByWeaponName(sBuffer);

    GetCmdArg(2, sBuffer, sizeof(sBuffer));
    int multiple = StringToInt(sBuffer);

    AddWeaponMultiple(match, multiple);
    return Plugin_Handled;
}

void AddWeaponMultiple(L4D2WeaponId match, int multiple)
{
	if(L4D2_IsValidWeaponId(match) && multiple > 0)
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
	ResetWeaponRules();
	g_ListSpawner.Clear();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void OnEntityDestroyed(int entity)
{
	if(entity <= MaxClients || entity > 2048 || !IsValidEdict(entity))
		return;
	
	static char classname[32];
	GetEdictClassname(entity, classname, sizeof(classname));
	if(classname[0] != 'w' || classname[6] != '_')
		return;

	int len = strlen(classname);
	if(strncmp(classname[len - 6], "_spawn", 7) != 0)
		return;
		
	classname[len - 6] = '\0';
	L4D2WeaponId source = L4D2_GetWeaponIdByWeaponName(classname);
	if(g_iGlobalWeaponRules[source] < 1)
		return;
	
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
	if(entity <= MaxClients || entity > 2048 || !IsValidEdict(entity))
		return;

	int iCount = GetEntProp(entity, Prop_Data, "m_itemCount");
	if(iCount & (1 << 3))
		return;	// Infinite ammo

	static char classname[32];
	GetEdictClassname(entity, classname, sizeof(classname));
	if(classname[0] != 'w' || classname[6] != '_')
		return;

	int len = strlen(classname);
	if(strncmp(classname[len - 6], "_spawn", 7) != 0)
		return;
		
	classname[len - 6] = '\0';
	L4D2WeaponId source = L4D2_GetWeaponIdByWeaponName(classname);
	if(g_iGlobalWeaponRules[source] < 1)
		return;

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
}