/**
 * =============================================================================
 * Left 4 Dead Stocks Library (C)2011-2012 Buster "Mr. Zero" Nielsen
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU General Public License, version 3.0, as 
 * published by the Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along 
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2,"
 * the "Source Engine," the "SourcePawn JIT," and any Game MODs that run on 
 * software by the Valve Corporation.  You must obey the GNU General Public
 * License in all respects for all other code used.  Additionally, 
 * AlliedModders LLC grants this exception to all derivative works.  
 * AlliedModders LLC defines further exceptions, found in LICENSE.txt 
 * (as of this writing, version JULY-31-2007), or 
 * <http://www.sourcemod.net/license.php>.
 */

/* Credits to ProdigySim for the weapon details, models and original script */

#if defined _l4d_weapon_stocks_included
 #endinput
#endif
#define _l4d_weapon_stocks_included

//#include <adt_trie>
#include <sourcemod>
#include <sdktools>

enum L4D2WeaponId
{
    L4D2WeaponId_None,              // 0
    L4D2WeaponId_Pistol,            // 1
    L4D2WeaponId_Smg,               // 2
    L4D2WeaponId_Pumpshotgun,       // 3
    L4D2WeaponId_Autoshotgun,       // 4
    L4D2WeaponId_Rifle,             // 5
    L4D2WeaponId_HuntingRifle,      // 6
    L4D2WeaponId_SmgSilenced,       // 7
    L4D2WeaponId_ShotgunChrome,     // 8
    L4D2WeaponId_RifleDesert,       // 9
    L4D2WeaponId_SniperMilitary,    // 10
    L4D2WeaponId_ShotgunSpas,       // 11
    L4D2WeaponId_FirstAidKit,       // 12
    L4D2WeaponId_Molotov,           // 13
    L4D2WeaponId_PipeBomb,          // 14
    L4D2WeaponId_PainPills,         // 15
    L4D2WeaponId_Gascan,            // 16
    L4D2WeaponId_PropaneTank,       // 17
    L4D2WeaponId_OxygenTank,        // 18
    L4D2WeaponId_Melee,             // 19
    L4D2WeaponId_Chainsaw,          // 20
    L4D2WeaponId_GrenadeLauncher,   // 21
    L4D2WeaponId_AmmoPack,          // 22
    L4D2WeaponId_Adrenaline,        // 23
    L4D2WeaponId_Defibrillator,     // 24
    L4D2WeaponId_Vomitjar,          // 25
    L4D2WeaponId_RifleAK47,         // 26
    L4D2WeaponId_GnomeChompski,     // 27
    L4D2WeaponId_ColaBottles,       // 28
    L4D2WeaponId_FireworksBox,      // 29
    L4D2WeaponId_IncendiaryAmmo,    // 30
    L4D2WeaponId_FragAmmo,          // 31
    L4D2WeaponId_PistolMagnum,      // 32
    L4D2WeaponId_SmgMP5,            // 33
    L4D2WeaponId_RifleSG552,        // 34
    L4D2WeaponId_SniperAWP,         // 35
    L4D2WeaponId_SniperScout,       // 36
    L4D2WeaponId_RifleM60,          // 37
    L4D2WeaponId_TankClaw,          // 38
    L4D2WeaponId_HunterClaw,        // 39
    L4D2WeaponId_ChargerClaw,       // 40
    L4D2WeaponId_BoomerClaw,        // 41
    L4D2WeaponId_SmokerClaw,        // 42
    L4D2WeaponId_SpitterClaw,       // 43
    L4D2WeaponId_JockeyClaw,        // 44
    L4D2WeaponId_Machinegun,        // 45
    L4D2WeaponId_FatalVomit,        // 46
    L4D2WeaponId_ExplodingSplat,    // 47
    L4D2WeaponId_LungePounce,       // 48
    L4D2WeaponId_Lounge,            // 49
    L4D2WeaponId_FullPull,          // 50
    L4D2WeaponId_Choke,             // 51
    L4D2WeaponId_ThrowingRock,      // 52
    L4D2WeaponId_TurboPhysics,      // 53
    L4D2WeaponId_Ammo,              // 54
    L4D2WeaponId_UpgradeItem        // 55
};

char L4D2WeaponName[][] =
{
    "weapon_none",                      // 0
    "weapon_pistol",                    // 1
    "weapon_smg",                       // 2
    "weapon_pumpshotgun",               // 3
    "weapon_autoshotgun",               // 4
    "weapon_rifle",                     // 5
    "weapon_hunting_rifle",             // 6
    "weapon_smg_silenced",              // 7
    "weapon_shotgun_chrome",            // 8
    "weapon_rifle_desert",              // 9
    "weapon_sniper_military",           // 10
    "weapon_shotgun_spas",              // 11
    "weapon_first_aid_kit",             // 12
    "weapon_molotov",                   // 13
    "weapon_pipe_bomb",                 // 14
    "weapon_pain_pills",                // 15
    "weapon_gascan",                    // 16
    "weapon_propanetank",               // 17
    "weapon_oxygentank",                // 18
    "weapon_melee",                     // 19
    "weapon_chainsaw",                  // 20
    "weapon_grenade_launcher",          // 21
    "weapon_ammo_pack",                 // 22
    "weapon_adrenaline",                // 23
    "weapon_defibrillator",             // 24
    "weapon_vomitjar",                  // 25
    "weapon_rifle_ak47",                // 26
    "weapon_gnome",                     // 27
    "weapon_cola_bottles",              // 28
    "weapon_fireworkcrate",             // 29
    "weapon_upgradepack_incendiary",    // 30
    "weapon_upgradepack_explosive",     // 31
    "weapon_pistol_magnum",             // 32
    "weapon_smg_mp5",                   // 33
    "weapon_rifle_sg552",               // 34
    "weapon_sniper_awp",                // 35
    "weapon_sniper_scout",              // 36
    "weapon_rifle_m60",                 // 37
    "weapon_tank_claw",                 // 38
    "weapon_hunter_claw",               // 39
    "weapon_charger_claw",              // 40
    "weapon_boomer_claw",               // 41
    "weapon_smoker_claw",               // 42
    "weapon_spitter_claw",              // 43
    "weapon_jockey_claw",               // 44
    "weapon_machinegun",                // 45
    "vomit",                            // 46
    "splat",                            // 47
    "pounce",                           // 48
    "lounge",                           // 49
    "pull",                             // 50
    "choke",                            // 51
    "rock",                             // 52
    "physics",                          // 53
    "weapon_ammo",                      // 54
    "upgrade_item"                      // 55
};

char L4D2WeaponWorldModel[][] =
{
    "",                                                
    "/w_models/weapons/w_pistol_b.mdl",
    "/w_models/weapons/w_smg_uzi.mdl",
    "/w_models/weapons/w_shotgun.mdl",
    "/w_models/weapons/w_autoshot_m4super.mdl",
    "/w_models/weapons/w_rifle_m16a2.mdl",
    "/w_models/weapons/w_sniper_mini14.mdl",
    "/w_models/weapons/w_smg_a.mdl",
    "/w_models/weapons/w_pumpshotgun_a.mdl",
    "/w_models/weapons/w_desert_rifle.mdl",             // "/w_models/weapons/w_rifle_b.mdl"
    "/w_models/weapons/w_sniper_military.mdl",
    "/w_models/weapons/w_shotgun_spas.mdl",
    "/w_models/weapons/w_eq_medkit.mdl",
    "/w_models/weapons/w_eq_molotov.mdl",
    "/w_models/weapons/w_eq_pipebomb.mdl",
    "/w_models/weapons/w_eq_painpills.mdl",
    "/props_junk/gascan001a.mdl",
    "/props_junk/propanecanister001.mdl",
    "/props_equipment/oxygentank01.mdl",
    "",                                                 // "/weapons/w_knife_t.mdl",
                                                        // "/weapons/melee/w_bat.mdl",
                                                        // "/weapons/melee/w_chainsaw.mdl
                                                        // "/weapons/melee/w_cricket_bat.mdl",
                                                        // "/weapons/melee/w_crowbar.mdl",
                                                        // "/weapons/melee/w_didgeridoo.mdl",
                                                        // "/weapons/melee/w_electric_guitar.mdl",
                                                        // "/weapons/melee/w_fireaxe.mdl",
                                                        // "/weapons/melee/w_frying_pan.mdl",
                                                        // "/weapons/melee/w_golfclub.mdl",
                                                        // "/weapons/melee/w_katana.mdl",
                                                        // "/weapons/melee/w_machete.mdl",
                                                        // "/weapons/melee/w_riotshield.mdl",
                                                        // "/weapons/melee/w_tonfa.mdl"
    "/weapons/melee/w_chainsaw.mdl",
    "/w_models/weapons/w_grenade_launcher.mdl",
    "",
    "/w_models/weapons/w_eq_adrenaline.mdl",
    "/w_models/weapons/w_eq_defibrillator.mdl",
    "/w_models/weapons/w_eq_bile_flask.mdl",
    "/w_models/weapons/w_rifle_ak47.mdl",
    "/props_junk/gnome.mdl",
    "/w_models/weapons/w_cola.mdl",
    "/props_junk/explosive_box001.mdl",
    "/w_models/weapons/w_eq_incendiary_ammopack.mdl",
    "/w_models/weapons/w_eq_explosive_ammopack.mdl",
    "/w_models/weapons/w_desert_eagle.mdl",            
    "/w_models/weapons/w_smg_mp5.mdl",
    "/w_models/weapons/w_rifle_sg552.mdl",
    "/w_models/weapons/w_sniper_awp.mdl",
    "/w_models/weapons/w_sniper_scout.mdl",
    "/w_models/weapons/w_m60.mdl",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    ""
};

static            StringMap    g_hWeaponNameTrie;

/**
 * Returns whether weapon id is vaild.
 *
 * @param weaponId      Weapon id to check for validity.
 * @return              True if weapon id is valid, false otherwise.
 */
stock bool L4D2_IsValidWeaponId(L4D2WeaponId weaponId)
{
    return weaponId >= L4D2WeaponId_None && weaponId < L4D2WeaponId;
}

/**
 * Returns whether weapon name is a valid weapon.
 *
 * @param weaponName    Weapon name to check for validity.
 * @return              True if weapon name is valid, false otherwise.
 */
stock bool L4D2_IsValidWeaponName(const char[] weaponName)
{
    return L4D2_GetWeaponIdByWeaponName(weaponName) != L4D2WeaponId_None;
}

/**
 * Checks to see if a given weapon id has a known WeaponModel in this file's
 * model array.
 *
 * Note: The melee weapon have multiple valid models. This function will
 * return false for melee weapon.
 *
 * @param weaponId      Weapon id to check for a known weapon model for.
 * @return              True if a valid weapon model exists for weapon id,
 *                      false otherwise.
 */
stock bool L4D2_HasValidWeaponWorldModel(L4D2WeaponId weaponId)
{
    return L4D2WeaponWorldModel[weaponId][0] != '\0';
}

/**
 * Returns weapon world model by weapon id.
 *
 * @note Does not work with melee weapons.
 *
 * @param weaponId      Weapon id.
 * @param dest          Destination string buffer to copy to.
 * @param destlen       Destination buffer length (includes null terminator).
 * @return              Number of cells written.
 */
stock int L4D2_GetWeaponModelByWeaponId(L4D2WeaponId weaponId, char[] dest, int destlen)
{
    if(!L4D2_IsValidWeaponId(weaponId))
        return 0;

    return strcopy(dest, destlen, L4D2WeaponWorldModel[weaponId]);
}

/**
 * Returns weapon id by weapon world model.
 *
 * @note Does not work with melee weapons.
 *
 * @param model         Weapon world model.
 * @return              Weapon Id.
 */
stock L4D2WeaponId L4D2_GetWeaponIdByWeaponModel(const char[] model)
{
    for(int i; i < sizeof(L4D2WeaponWorldModel); i++)
    {
        if(strcmp(model, L4D2WeaponWorldModel[i], false) == 0)
            return view_as<L4D2WeaponId>(i);
    }

    return L4D2WeaponId_None;
}

/**
 * Returns weapon id by weapon name.
 *
 * @param weaponName    Weapon name to get id from.
 * @return              The corresponding weapon id if found, else 
 *                      L4D2WeaponId_None.
 */
stock L4D2WeaponId L4D2_GetWeaponIdByWeaponName(const char[] weaponName)
{
    L4D2_InitWeaponNameTrie();
    L4D2WeaponId weaponId;
    return g_hWeaponNameTrie.GetValue(weaponName, weaponId) ? weaponId : L4D2WeaponId_None;
}

/**
 * Returns weapon name by weapon id.
 *
 * @param weaponName    Weapon id to get name from.
 * @param dest          Destination string buffer to copy to.
 * @param destlen       Destination buffer length (includes null terminator).
 * @return              Number of cells written.
 */
stock int L4D2_GetWeaponNameByWeaponId(L4D2WeaponId weaponId, char[] dest, int destlen)
{
    if(!L4D2_IsValidWeaponId(weaponId))
        return 0;

    return strcopy(dest, destlen, L4D2WeaponName[weaponId]);
}

/**
 * Returns weapon id of entity.
 *
 * @param weapon        Entity index of weapon.
 * @return              Weapon id if found, L4D2WeaponId_None otherwise.
 * @error               Invalid entity index.
 */
stock L4D2WeaponId L4D2_GetWeaponId(int weapon)
{
    char classname[64];
    if(!GetEdictClassname(weapon, classname, sizeof(classname)))
        return L4D2WeaponId_None;

    if(strcmp(classname, "weapon_spawn") == 0)
        return view_as<L4D2WeaponId>(GetEntProp(weapon, Prop_Send, "m_weaponID"));

    int len = strlen(classname);
    if(len - 6 > 0 && StrEqual(classname[len - 6], "_spawn"))
        classname[len - 6] = '\0';

    return L4D2_GetWeaponIdByWeaponName(classname);
}

/**
 * Initilize the L4D2 weapon names trie. Not necessary to be executed, done by
 * the functions that require the trie.
 *
 * @noreturn
 */
stock void L4D2_InitWeaponNameTrie()
{
    if(g_hWeaponNameTrie != null)
        return;

    g_hWeaponNameTrie = new StringMap();
    for(int i; i < view_as<int>(L4D2WeaponId); i++)
        g_hWeaponNameTrie.SetValue(L4D2WeaponName[view_as<L4D2WeaponId>(i)], i);
}
