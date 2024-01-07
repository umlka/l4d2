#if defined _defib_fix_included
#endinput
#endif
#define _defib_fix_included

/**
*	@Note only called if defib_fix is installed
*	
*	Deathmodels are "survivor_death_model" that can be used with defibrillator.
*
*	@param	client		Client index who died.
*	@param	deathmodel	Entity index of deathmodel for client who died
*	@no return
*/
forward void L4D2_OnSurvivorDeathModelCreated(int client, int deathmodel);

public SharedPlugin __pl_defib_fix  =
{
    name = "defib_fix",
    file = "defib_fix.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
