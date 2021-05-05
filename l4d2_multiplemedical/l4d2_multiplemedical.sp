#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d_weapon_stocks>

#define PLUGIN_VERSION 	"1.1"

//ArrayList g_ListSpawner;

int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iGlobalWeaponRules[view_as<int>(L4D2WeaponId_Max)];

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

	ResetWeaponRules();
	//g_ListSpawner = new ArrayList(2);
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
    for(int i; i < view_as<int>(L4D2WeaponId_Max); i++) 
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
		if(!IsValidEntity(i))
			continue;

		L4D2WeaponId source = IdentifyWeapon(i);
		if(source > L4D2WeaponId_None && g_iGlobalWeaponRules[source] >= 0)
		{
			if(g_iGlobalWeaponRules[source] == 0)
				RemoveEntity(i);
			else
				SetEntProp(i, Prop_Data, "m_itemCount", g_iGlobalWeaponRules[source]);
		}
	}
}
/*
public void OnEntityDestroyed(int entity)
{
	if(entity <= MaxClients || entity > 2048 || !IsValidEdict(entity))
		return;
	
	L4D2WeaponId source = IdentifyWeapon(entity);
	if(source > L4D2WeaponId_None && g_iGlobalWeaponRules[source] > 0)
	{
		int iIndex = g_ListSpawner.FindValue(EntIndexToEntRef(entity), 0);
		if(iIndex != -1)
			g_ListSpawner.Erase(iIndex);
	}
}

public void Event_SpawnerGiveItem(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("spawner");
	if(entity <= MaxClients || entity > 2048 || !IsValidEdict(entity))
		return;

	L4D2WeaponId source = IdentifyWeapon(entity);
	if(source > L4D2WeaponId_None && g_iGlobalWeaponRules[source] > 0)
	{
		if(g_iGlobalWeaponRules[source] == 1)
			RemoveEntity(entity);
		else
		{
			static int iIndex;
			iIndex = g_ListSpawner.FindValue(EntIndexToEntRef(entity), 0);
			if(iIndex == -1)
			{
				SetEntProp(entity, Prop_Data, "m_itemCount", g_iGlobalWeaponRules[source]);
				g_ListSpawner.Set(g_ListSpawner.Push(EntIndexToEntRef(entity)), g_iGlobalWeaponRules[source], 1);
			}
			else
			{
				static int iCount;
				if((iCount = g_ListSpawner.Get(iIndex, 1)) <= 1)
					RemoveEntity(entity);
				else
					g_ListSpawner.Set(iIndex, iCount--, 1);
			}
		}
	}
}
*/
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
	static char classname[64];
	if(!GetEdictClassname(entity, classname, sizeof(classname)))
		return L4D2WeaponId_None;

	int len = strlen(classname);
	if(len < 12)
		return L4D2WeaponId_None;

	if(strncmp(classname, "weapon_", 7) != 0)
		return L4D2WeaponId_None;

	if(strncmp(classname[len - 6], "_spawn", 7) != 0)
		return L4D2WeaponId_None;
	
	if(len == 12)
		return view_as<L4D2WeaponId>(GetEntProp(entity,Prop_Send,"m_weaponID"));

	classname[len - 6] = '\0';
	return L4D2_GetWeaponIdByWeaponName(classname);
}
