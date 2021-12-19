#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION	"4.4.4"
#define CVAR_FLAGS		FCVAR_NOTIFY

ConVar
	g_hAllow,
	g_hGameMode,
	g_hModes,
	g_hModesOff,
	g_hModesTog;

int
	g_iStatusInfo[MAXPLAYERS + 1][9],
	g_iWeaponInfo[MAXPLAYERS + 1][7],
	g_iGrenadeThrower[MAXPLAYERS + 1];

bool
	g_bAllow,
	g_bMapStarted,
	g_bHideNameChange,
	g_bValidMapChange;

static const char
	g_sStatusInfo[MAXPLAYERS + 1][128],
	g_sWeaponInfo[MAXPLAYERS + 1][6][32],
	g_sSurvivorNames[8][] =
	{
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis"
	},
	g_sSurvivorModels[8][] =
	{
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	};

public Plugin myinfo =
{
	name = "[L4D2] Save Weapon",
	author = "MAKS, Electr0, Merudo",
	description = "L4D2 coop save weapon",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2398822#post2398822"
}

public void OnPluginStart()
{
	CreateConVar("l4d2_ty_saveweapon", PLUGIN_VERSION, "L4D2 Save Weapon plugin version.", CVAR_FLAGS);

	g_hAllow = CreateConVar("l4d2_ty_allow", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hModes = CreateConVar("l4d2_ty_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hModesOff = CreateConVar("l4d2_ty_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS);
	g_hModesTog = CreateConVar("l4d2_ty_modes_tog", "1", "Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS);

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(vAllowConVarChanged);
	g_hModes.AddChangeHook(vAllowConVarChanged);
	g_hModesOff.AddChangeHook(vAllowConVarChanged);
	g_hModesTog.AddChangeHook(vAllowConVarChanged);
	g_hAllow.AddChangeHook(vAllowConVarChanged);

	//AutoExecConfig(true, "l4d2_ty_saveweapon");

	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);
}

public void OnConfigsExecuted()
{
	vIsAllowed();
}

void vAllowConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vIsAllowed()
{
	bool bAllow = g_hAllow.BoolValue;
	bool bAllowMode = bIsAllowedGameMode();

	if(g_bAllow == false && bAllow == true && bAllowMode == true)
	{
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);	
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		HookEvent("player_team", Event_PlayerTeam);
		HookEvent("player_spawn", Event_PlayerSpawn);

		g_bAllow = true;
	}
	else if(g_bAllow == true && (bAllow == false || bAllowMode == false))
	{
		UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);	
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		UnhookEvent("player_team", Event_PlayerTeam);
		UnhookEvent("player_spawn", Event_PlayerSpawn);

		vSurvivorCleanAll();
		g_bAllow = false;
	}
}

int g_iCurrentMode;
bool bIsAllowedGameMode()
{
	if(g_hGameMode == null)
		return false;

	int iModesTog = g_hModesTog.IntValue;
	if(iModesTog != 0)
	{
		if(g_bMapStarted == false)
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if(IsValidEntity(entity))
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", vOnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", vOnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", vOnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", vOnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if(IsValidEntity(entity)) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity);// Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if(g_iCurrentMode == 0)
			return false;

		if(!(iModesTog & g_iCurrentMode))
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hModes.GetString(sGameModes, sizeof(sGameModes));
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}

	g_hModesOff.GetString(sGameModes, sizeof(sGameModes));
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

void vOnGamemode(const char[] output, int caller, int activator, float delay)
{
	if(strcmp(output, "OnCoop") == 0)
		g_iCurrentMode = 1;
	else if(strcmp(output, "OnSurvival") == 0)
		g_iCurrentMode = 2;
	else if(strcmp(output, "OnVersus") == 0)
		g_iCurrentMode = 4;
	else if(strcmp(output, "OnScavenge") == 0)
		g_iCurrentMode = 8;
}

Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!g_bHideNameChange)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char sMessage[128];
	msg.ReadString(sMessage, sizeof sMessage, true);
	if(strcmp(sMessage, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(classname[0] != 'm' && classname[0] != 'p' && classname[0] != 'v')
		return;

	if(strncmp(classname, "molotov_projectile", 19) == 0 || strncmp(classname, "pipe_bomb_projectile", 21) == 0 || strncmp(classname, "vomitjar_projectile", 20) == 0)
		SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
}

void Hook_SpawnPost(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
	if(entity <= MaxClients || !IsValidEntity(entity))
		return;

	int iOwner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
	if(0 < iOwner <= MaxClients && IsClientInGame(iOwner) && GetClientTeam(iOwner) == 2)
	{
		int iSlot = GetPlayerWeaponSlot(iOwner, 2);
		if(iSlot > MaxClients)
			g_iGrenadeThrower[iOwner] = EntIndexToEntRef(iSlot);
	}
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;

	if(!g_bValidMapChange)
		vSurvivorCleanAll();
	else
	{
		for(int i = 1; i <= MaxClients; i++)
			g_iStatusInfo[i][8] = 0;
	}

	g_bValidMapChange = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		g_iStatusInfo[i][8] = 1;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	vSurvivorCleanAll();
	vSurvivorSaveAll();
	g_bValidMapChange = true;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(g_iStatusInfo[client][7] == 0 || g_iStatusInfo[client][8] == 1)
		return;

	g_iStatusInfo[client][8] = 1;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(g_iStatusInfo[client][7] == 0 || g_iStatusInfo[client][8] == 1)
		return;

	if(event.GetInt("team") > 2)
		g_iStatusInfo[client][8] = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(g_iStatusInfo[client][8] == 1 || !IsPlayerAlive(client))
		return;

	switch(GetClientTeam(client))
	{
		case 2:
			CreateTimer(0.2, Timer_Restore, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

		case 3:
			g_iStatusInfo[client][8] = 1;
	}
}

Action Timer_Restore(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return Plugin_Stop;

	if(IsFakeClient(client))
	{
		if(iHasIdlePlayer(client))
		{
			g_iStatusInfo[client][8] = 1;
			return Plugin_Stop;
		}
		else if(g_iStatusInfo[client][7] == 0 && GetGameTime() < 30.0)
			vAppropriateUnusedSave(client);
	}

	if(g_iStatusInfo[client][8] == 0)
	{
		if(g_iStatusInfo[client][7] == 1)
			vSurvivorGive(client);
			
		g_iStatusInfo[client][8] = 1;
	}

	return Plugin_Continue;
}

void vAppropriateUnusedSave(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && g_iStatusInfo[i][7] == 1 && !IsClientConnected(i))
		{
			vSurvivorCopy(i, client);
			vSurvivorClean(i);
			break;
		}
	}
}

void vSurvivorClean(int client)
{
	g_iStatusInfo[client][0] = 0;
	g_iStatusInfo[client][1] = 0;
	g_iStatusInfo[client][2] = 0;
	g_iStatusInfo[client][3] = 0;
	g_iStatusInfo[client][4] = 0;
	g_iStatusInfo[client][5] = 0;
	g_iStatusInfo[client][6] = -1;
	g_iStatusInfo[client][7] = 0;
	g_iStatusInfo[client][8] = 0;
	
	g_sStatusInfo[client][0] = '\0';

	g_iWeaponInfo[client][0] = 0;
	g_iWeaponInfo[client][1] = 0;
	g_iWeaponInfo[client][2] = 0;
	g_iWeaponInfo[client][3] = 0;
	g_iWeaponInfo[client][4] = 0;
	g_iWeaponInfo[client][5] = -1;
	g_iWeaponInfo[client][6] = 0;
	
	g_sWeaponInfo[client][0][0] = '\0';
	g_sWeaponInfo[client][1][0] = '\0';
	g_sWeaponInfo[client][2][0] = '\0';
	g_sWeaponInfo[client][3][0] = '\0';
	g_sWeaponInfo[client][4][0] = '\0';
	g_sWeaponInfo[client][5][0] = '\0';
}

void vSurvivorSave(int client)
{
	vSurvivorClean(client);

	if(GetClientTeam(client) != 2)
		return;

	g_iStatusInfo[client][7] = 1;

	GetClientModel(client, g_sStatusInfo[client], sizeof(g_sStatusInfo[]));
	g_iStatusInfo[client][6] = GetEntProp(client, Prop_Send, "m_survivorCharacter");	

	if(!IsPlayerAlive(client))
	{
		g_iStatusInfo[client][3] = 50;
		return;
	}

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		vRunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));

	g_iStatusInfo[client][0] = GetEntProp(client, Prop_Send, "m_currentReviveCount");
	g_iStatusInfo[client][1] = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
	g_iStatusInfo[client][2] = GetEntProp(client, Prop_Send, "m_isGoingToDie");
	g_iStatusInfo[client][3] = GetEntProp(client, Prop_Data, "m_iHealth");
	g_iStatusInfo[client][4] = RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
	g_iStatusInfo[client][5] = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));

	bool bSaved;
	char sWeapon[32];

	int iSlot = GetPlayerWeaponSlot(client, 0);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(g_sWeaponInfo[client][0], sizeof(g_sWeaponInfo[][]), sWeapon);

		g_iWeaponInfo[client][0] = GetEntProp(iSlot, Prop_Send, "m_iClip1");
		g_iWeaponInfo[client][1] = iGetOrSetPlayerAmmo(client, sWeapon);
		g_iWeaponInfo[client][2] = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
		g_iWeaponInfo[client][3] = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
		g_iWeaponInfo[client][4] = GetEntProp(iSlot, Prop_Send, "m_nSkin");

		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 1);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		if(strcmp(sWeapon[7], "melee") == 0)
			GetEntPropString(iSlot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof(sWeapon));
		else if(strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(iSlot, Prop_Send, "m_isDualWielding") > 0)
			strcopy(sWeapon, sizeof(sWeapon), "v_dual_pistol");

		strcopy(g_sWeaponInfo[client][1], sizeof(g_sWeaponInfo[][]), sWeapon);

		if(strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
			g_iWeaponInfo[client][5] = GetEntProp(iSlot, Prop_Send, "m_iClip1");

		g_iWeaponInfo[client][6] = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		
		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 2);
	if(iSlot > MaxClients)
	{
		if(EntIndexToEntRef(iSlot) != g_iGrenadeThrower[client])
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			strcopy(g_sWeaponInfo[client][2], sizeof(g_sWeaponInfo[][]), sWeapon);
			
			bSaved = true;
		}
	}

	iSlot = GetPlayerWeaponSlot(client, 3);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(g_sWeaponInfo[client][3], sizeof(g_sWeaponInfo[][]), sWeapon);
		
		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 4);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(g_sWeaponInfo[client][4], sizeof(g_sWeaponInfo[][]), sWeapon);
		
		bSaved = true;
	}
	
	if(bSaved == true)
	{
		iSlot = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			strcopy(g_sWeaponInfo[client][5], sizeof(g_sWeaponInfo[][]), sWeapon);
		}
	}
}

void vRunScript(const char[] sCode, any ...) 
{
	/**
	* Run a VScript (Credit to Timocop)
	*
	* @param sCode		Magic
	* @return void
	*/

	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
			SetFailState("Could not create 'logic_script'");

		DispatchSpawn(iScriptLogic);
	}

	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

void vSurvivorGive(int client)
{
	if(g_iStatusInfo[client][7] == 0)
		return;

	g_iStatusInfo[client][8] = 1;

	SetEntProp(client, Prop_Send, "m_survivorCharacter", g_iStatusInfo[client][6]); 
	SetEntityModel(client, g_sStatusInfo[client]);
	
	if(IsFakeClient(client))
	{
		for(int i; i < 8; i++)
		{
			if(strcmp(g_sStatusInfo[client], g_sSurvivorModels[i]) == 0)
			{
				g_bHideNameChange = true;
				SetClientName(client, g_sSurvivorNames[i]);
				g_bHideNameChange = false;
			}
		}
	}

	if(!IsPlayerAlive(client)) 
		return;

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

	SetEntProp(client, Prop_Send, "m_currentReviveCount", g_iStatusInfo[client][0]);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", g_iStatusInfo[client][1]);
	SetEntProp(client, Prop_Send, "m_isGoingToDie", g_iStatusInfo[client][2]);

	SetEntProp(client, Prop_Send, "m_iHealth", g_iStatusInfo[client][3]);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * g_iStatusInfo[client][4]);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * g_iStatusInfo[client][5]);

	if(g_iStatusInfo[client][1] != 0)
		StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");

	int iSlot;
	int iWeapon;
	for(; iSlot < 5; iSlot++)
	{
		iWeapon = GetPlayerWeaponSlot(client, iSlot);
		if(iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			if(RemovePlayerItem(client, iWeapon))
				RemoveEdict(iWeapon);
		}
	}

	bool bGiven;
	if(g_sWeaponInfo[client][0][0] != '\0')
	{
		vCheatCommand(client, "give", g_sWeaponInfo[client][0]);

		iSlot = GetPlayerWeaponSlot(client, 0);
		if(iSlot > MaxClients)
		{
			SetEntProp(iSlot, Prop_Send, "m_iClip1", g_iWeaponInfo[client][0]);
			iGetOrSetPlayerAmmo(client, g_sWeaponInfo[client][0], g_iWeaponInfo[client][1]);

			if(g_iWeaponInfo[client][2] > 0)
				SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", g_iWeaponInfo[client][2]);

			if(g_iWeaponInfo[client][3] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", g_iWeaponInfo[client][3]);
				
			if(g_iWeaponInfo[client][4] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nSkin", g_iWeaponInfo[client][4]);
				
			bGiven = true;
		}
	}

	if(g_sWeaponInfo[client][1][0] != '\0')
	{
		if(strcmp(g_sWeaponInfo[client][1], "v_dual_pistol") == 0)
		{
			vCheatCommand(client, "give", "weapon_pistol");
			vCheatCommand(client, "give", "weapon_pistol");
		}
		else
			vCheatCommand(client, "give", g_sWeaponInfo[client][1]);

		iSlot = GetPlayerWeaponSlot(client, 1);
		if(iSlot > MaxClients)
		{
			if(g_iWeaponInfo[client][5] != -1)
				SetEntProp(iSlot, Prop_Send, "m_iClip1", g_iWeaponInfo[client][5]);
				
			if(g_iWeaponInfo[client][6] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nSkin", g_iWeaponInfo[client][6]);
				
			bGiven = true;
		}
	}

	if(g_sWeaponInfo[client][2][0] != '\0')
	{
		vCheatCommand(client, "give", g_sWeaponInfo[client][2]);

		if(GetPlayerWeaponSlot(client, 2) > MaxClients)
			bGiven = true;
	}

	if(g_sWeaponInfo[client][3][0] != '\0')
	{
		vCheatCommand(client, "give", g_sWeaponInfo[client][3]);
	
		if(GetPlayerWeaponSlot(client, 3) > MaxClients)
			bGiven = true;
	}

	if(g_sWeaponInfo[client][4][0] != '\0')
	{
		vCheatCommand(client, "give", g_sWeaponInfo[client][4]);
	
		if(GetPlayerWeaponSlot(client, 4) > MaxClients)
			bGiven = true;
	}
		
	if(bGiven == true)
	{
		if(g_sWeaponInfo[client][5][0] != '\0')
			FakeClientCommand(client, "use %s", g_sWeaponInfo[client][5]);
	}
	else
		vCheatCommand(client, "give", "smg");
}

void vSurvivorCopy(int client, int iTarget)
{
	int i;
	for(; i < 9; i++)
		g_iStatusInfo[iTarget][i] = g_iStatusInfo[client][i];

	strcopy(g_sStatusInfo[iTarget], sizeof(g_sStatusInfo[]), g_sStatusInfo[client]);

	for(i = 0; i < 7; i++)
		g_iWeaponInfo[iTarget][i] = g_iWeaponInfo[client][i];

	for(i = 0; i < 6; i++)
		strcopy(g_sWeaponInfo[iTarget][i], sizeof(g_sWeaponInfo[][]), g_sWeaponInfo[client][i]);
}

void vSurvivorCleanAll()
{
	for(int i = 1; i <= MaxClients; i++)
		vSurvivorClean(i);
}

void vSurvivorSaveAll()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			if(!IsFakeClient(i))
				vSurvivorSave(i);
			else
			{
				vSurvivorSave(i);
				int iIdlePlayer = iHasIdlePlayer(i);
				if(iIdlePlayer)
				{
					vSurvivorCopy(i, iIdlePlayer);
					vSurvivorClean(i);
				}
			}
		}
	}
}

int iHasIdlePlayer(int client)
{
	char sNetClass[64];
	if(!GetEntityNetClass(client, sNetClass, sizeof(sNetClass)))
		return 0;

	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
		return client;

	return 0;
}

void vCheatCommand(int client, const char[] sCommand, const char[] sArguments = "")
{
	static int iFlagBits, iCmdFlags;
	iFlagBits = GetUserFlagBits(client);
	iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags);
}

int iGetOrSetPlayerAmmo(int client, const char[] sWeapon, int iAmmo = -1)
{
	static StringMap aWeaponOffsets;
	if(aWeaponOffsets == null)
		aWeaponOffsets = aInitWeaponOffsets(aWeaponOffsets);
		
	static int iOffsetAmmo;
	if(iOffsetAmmo < 1)
		iOffsetAmmo = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");

	int offset;
	aWeaponOffsets.GetValue(sWeapon, offset);

	if(offset)
	{
		if(iAmmo != -1)
			SetEntData(client, iOffsetAmmo + offset, iAmmo);
		else
			return GetEntData(client, iOffsetAmmo + offset);
	}

	return 0;
}

StringMap aInitWeaponOffsets(StringMap aWeaponOffsets)
{
	aWeaponOffsets = new StringMap();
	aWeaponOffsets.SetValue("weapon_rifle", 12);
	aWeaponOffsets.SetValue("weapon_smg", 20);
	aWeaponOffsets.SetValue("weapon_pumpshotgun", 28);
	aWeaponOffsets.SetValue("weapon_shotgun_chrome", 28);
	aWeaponOffsets.SetValue("weapon_autoshotgun", 32);
	aWeaponOffsets.SetValue("weapon_hunting_rifle", 36);
	aWeaponOffsets.SetValue("weapon_rifle_sg552", 12);
	aWeaponOffsets.SetValue("weapon_rifle_desert", 12);
	aWeaponOffsets.SetValue("weapon_rifle_ak47", 12);
	aWeaponOffsets.SetValue("weapon_smg_silenced", 20);
	aWeaponOffsets.SetValue("weapon_smg_mp5", 20);
	aWeaponOffsets.SetValue("weapon_shotgun_spas", 32);
	aWeaponOffsets.SetValue("weapon_sniper_scout", 40);
	aWeaponOffsets.SetValue("weapon_sniper_military", 40);
	aWeaponOffsets.SetValue("weapon_sniper_awp", 40);
	aWeaponOffsets.SetValue("weapon_rifle_m60", 24);
	aWeaponOffsets.SetValue("weapon_grenade_launcher", 68);
	return aWeaponOffsets;
}
