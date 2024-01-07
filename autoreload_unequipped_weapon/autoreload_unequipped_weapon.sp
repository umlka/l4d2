// L4D2
// Autoreload unequipped weapon
// Back 4 Blood - Admin Reload card

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
//#include <sdktools>
//#include <sdkhooks>
#include <left4dhooks>

#define BENCHMARK	0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

StringMap
    g_smAmmo;

Handle
	g_hTimers[MAXPLAYERS + 1];

ConVar
    g_hAutoReloadTime;

bool
	g_bLateLoad;

float
    g_fAutoReloadTime;

public Plugin myinfo = {
	name = "Autoreload unequipped weapon",
	author = "Bacardi",
	description = "Autoreload unequipped weapon (Back 4 Blood - Admin Reload card)",
	version = "",
	url = "https://forums.alliedmods.net/showpost.php?p=2767938&postcount=3"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
    g_smAmmo = new StringMap();

    g_hAutoReloadTime = CreateConVar("autoreload_unequipped_weapon_time", "3.0" , "切枪后多少秒自动加载后台的武器", FCVAR_NOTIFY, true, 0.0);
    g_hAutoReloadTime.AddChangeHook(CvarChanged);

    if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
       	    if (IsClientInGame(i))
			    OnClientPutInServer(i);
        }
	}
}

public void OnConfigsExecuted() {
    GetCvars();
    SetAmmoHashMap();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fAutoReloadTime = g_hAutoReloadTime.FloatValue;
}

public void OnClientPutInServer(int client) {
    if (!IsFakeClient(client))
        SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitchPost);
}

void WeaponSwitchPost(int client, int weapon) {
    if (g_hTimers[client] != null)
        delete g_hTimers[client];

    if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
        return;

    DataPack dPack;
    g_hTimers[client] = CreateDataTimer(g_fAutoReloadTime, tmrDelayAutoReload, dPack);

    dPack.WriteCell(client);
    dPack.WriteCell(GetClientUserId(client));
    dPack.Reset();
}

Action tmrDelayAutoReload(Handle timer, DataPack dPack) {
    g_hTimers[dPack.ReadCell()] = null;

    int client = GetClientOfUserId(dPack.ReadCell());
    if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
        return Plugin_Continue;

    #if BENCHMARK
    g_profiler = new Profiler();
    g_profiler.Start();
    #endif

    int weapon;
    int m_hActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    int m_iPrimaryAmmoType = -1;

    int m_iClip1 = 0xFF;
    int clip_size;
    int fillclip;

    int m_iAmmo;
    int ammo;

    static char sWeapon[32];

    for (int i; i < 2; i++) {
        weapon = GetPlayerWeaponSlot(client, i);
        if (weapon <= MaxClients || weapon == m_hActiveWeapon)
            continue;

        if (!HasEntProp(weapon, Prop_Send, "m_isDualWielding"))
            continue;

        if (!HasEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"))
            continue;

        m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
        if (m_iPrimaryAmmoType == -1)
            continue;

        m_iClip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");
        if (m_iClip1 == -1 || m_iClip1 == 0xFF)
            continue;

        GetEntityClassname(weapon, sWeapon, sizeof sWeapon);
        clip_size = L4D2_GetIntWeaponAttribute(sWeapon, L4D2IWA_ClipSize);
        if (GetEntProp(weapon, Prop_Send, "m_isDualWielding"))
            clip_size *= 2;

        m_iAmmo = GetEntProp(client, Prop_Send, "m_iAmmo", _, m_iPrimaryAmmoType);
        if (m_iClip1 >= clip_size)
            continue;

        g_smAmmo.GetValue(sWeapon, ammo);
    
        if (ammo > 0 && m_iAmmo > 0) {
            fillclip = clip_size - m_iClip1;
            if (fillclip <= m_iAmmo) {
                SetEntProp(weapon, Prop_Send, "m_iClip1", m_iClip1 + fillclip);
                SetEntProp(client, Prop_Send, "m_iAmmo", m_iAmmo - fillclip, _, m_iPrimaryAmmoType);
            }
            else {
                SetEntProp(weapon, Prop_Send, "m_iClip1", m_iClip1 + m_iAmmo);
                SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, m_iPrimaryAmmoType);
            }
        }
        else if (ammo == -2)
            SetEntProp(weapon, Prop_Send, "m_iClip1", clip_size);
    }

    #if BENCHMARK
    g_profiler.Stop();
    PrintToChat(client, "ProfilerTime: %f", g_profiler.Time);
    #endif

    return Plugin_Continue;
}

void SetAmmoHashMap() {
    int ammo;
    ConVar cvAmmo = FindConVar("ammo_autoshotgun_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_autoshotgun", ammo);
    g_smAmmo.SetValue("weapon_shotgun_spas", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_grenadelauncher_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_grenade_launcher", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_huntingrifle_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_hunting_rifle", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_pistol_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_pistol", ammo);
    g_smAmmo.SetValue("weapon_pistol_magnum", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_shotgun_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_pumpshotgun", ammo);
    g_smAmmo.SetValue("weapon_shotgun_chrome", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_assaultrifle_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_rifle", ammo);
    g_smAmmo.SetValue("weapon_rifle_ak47", ammo);
    g_smAmmo.SetValue("weapon_rifle_desert", ammo);
    g_smAmmo.SetValue("weapon_rifle_sg552", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_m60_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_rifle_m60", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_smg_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_smg", ammo);
    g_smAmmo.SetValue("weapon_smg_mp5", ammo);
    g_smAmmo.SetValue("weapon_smg_silenced", ammo);

    ammo = 0;
    cvAmmo = FindConVar("ammo_sniperrifle_max");
    if (cvAmmo)
        ammo = cvAmmo.IntValue;

    g_smAmmo.SetValue("weapon_sniper_awp", ammo);
    g_smAmmo.SetValue("weapon_sniper_military", ammo);
    g_smAmmo.SetValue("weapon_sniper_scout", ammo);
}
