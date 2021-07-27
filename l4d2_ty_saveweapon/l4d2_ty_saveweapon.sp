#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION	"4.3"
#define CVAR_FLAGS		FCVAR_NOTIFY

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
bool g_bCvarAllow, g_bMapStarted, g_bValidMapChange;

bool g_bSpawned[MAXPLAYERS + 1];
bool g_bRecorded[MAXPLAYERS + 1];

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
	// =========================
	// CVARS
	// =========================
	CreateConVar("l4d2_ty_saveweapon", PLUGIN_VERSION, "L4D2 Save Weapon plugin version.", CVAR_FLAGS);

	g_hCvarAllow = CreateConVar("l4d2_ty_allow", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hCvarModes = CreateConVar("l4d2_ty_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hCvarModesOff = CreateConVar("l4d2_ty_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS);
	g_hCvarModesTog = CreateConVar("l4d2_ty_modes_tog", "1", "Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(vAllowConVarChanged);
	g_hCvarModes.AddChangeHook(vAllowConVarChanged);
	g_hCvarModesOff.AddChangeHook(vAllowConVarChanged);
	g_hCvarModesTog.AddChangeHook(vAllowConVarChanged);
	g_hCvarAllow.AddChangeHook(vAllowConVarChanged);

	//AutoExecConfig(true, "l4d2_ty_saveweapon");
}

// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	vIsAllowed();
}

public void vAllowConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vIsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = bIsAllowedGameMode();

	if(g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true)
	{
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);	
		HookEvent("player_spawn", Event_PlayerSpawn);

		g_bCvarAllow = true;
	}
	else if(g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false))
	{
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);	
		UnhookEvent("player_spawn", Event_PlayerSpawn);

		vSurvivorCleanAll();
		g_bCvarAllow = false;
	}
}

int g_iCurrentMode;
bool bIsAllowedGameMode()
{
	if(g_hCvarMPGameMode == null)
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if(iCvarModesTog != 0)
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

		if(!(iCvarModesTog & g_iCurrentMode))
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if(sGameModes[0])
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if(StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

public void vOnGamemode(const char[] output, int caller, int activator, float delay)
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

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnMapStart()
{
	g_bMapStarted = true;
	
	if(!g_bValidMapChange)
		vSurvivorCleanAll();
		
	g_bValidMapChange = false;
}

public void OnClientDisconnect(int client)
{
	if(g_bSpawned[client] == true && g_bRecorded[client] == true)
		vSurvivorClean(client);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		g_bSpawned[i] = false;
}

public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	vSurvivorCleanAll();
	vSurvivorSaveAll();
	g_bValidMapChange = true;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if(g_bSpawned[client] == false && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		CreateTimer(0.5, Timer_Restore, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Restore(Handle timer, int client)
{
	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

	if(g_bRecorded[client] == false && g_bSpawned[client] == false && IsFakeClient(client) && GetGameTime() < 10.0)
		vAppropriateUnusedSave(client);

	if(g_bSpawned[client] == false)
	{
		if(g_bRecorded[client] == true)
		{
			vSurvivorGive(client);
			vSurvivorClean(client);
		}
			
		g_bSpawned[client] = true;
	}
}

void vAppropriateUnusedSave(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && g_bRecorded[i] == true && !IsClientConnected(i))
		{
			vSurvivorCopy(i, client);
			vSurvivorClean(i);
			break;
		}
	}
}

static const char g_sSurvivorNames[8][] =
{
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Francis",
	"Louis"
};

static const char g_sSurvivorModels[8][] =
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

void vSurvivorStatus(int client, int iType, int iTarget = -1)
{
	static bool bRecorded[MAXPLAYERS + 1];
	static int iStatusInfo[MAXPLAYERS + 1][7];
	static char sStatusInfo[MAXPLAYERS + 1][128];
	
	switch(iType)
	{
		case 0:
		{
			bRecorded[client] = false;
			vCleanStatus(client, iStatusInfo, sStatusInfo);
		}
			
		case 1:
		{
			bRecorded[client] = true;
			vSaveStatus(client, iStatusInfo, sStatusInfo, sizeof(sStatusInfo));
		}
			
		case 2:
		{
			if(bRecorded[client])
				vSetStatus(client, iStatusInfo, sStatusInfo);
		}
			
		case 3:
		{
			bRecorded[iTarget] = bRecorded[client];
			vCopyStatus(client, iTarget, iStatusInfo, sStatusInfo, sizeof(sStatusInfo));
		}
	}
}

void vCleanStatus(int client, int[][] iStatusInfo, char[][] sStatusInfo)
{
	iStatusInfo[client][0] = 0;
	iStatusInfo[client][1] = 0;
	iStatusInfo[client][2] = 0;
	iStatusInfo[client][3] = 0;
	iStatusInfo[client][4] = 0;
	iStatusInfo[client][5] = 0;
	iStatusInfo[client][6] = -1;
	
	sStatusInfo[client][0] = '\0';
}

void vSaveStatus(int client, int[][] iStatusInfo, char[][] sStatusInfo, int maxlength)
{
	GetClientModel(client, sStatusInfo[client], maxlength);
	iStatusInfo[client][6] = GetEntProp(client, Prop_Send, "m_survivorCharacter");	

	if(!IsPlayerAlive(client))
	{
		iStatusInfo[client][3] = 50;
		return;
	}

	iStatusInfo[client][0] = GetEntProp(client, Prop_Send, "m_currentReviveCount");
	iStatusInfo[client][1] = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated")) 
	{
		iStatusInfo[client][3] = 1;	
		iStatusInfo[client][4] = 30;
		iStatusInfo[client][5] = 0;
		iStatusInfo[client][2] = 1;
	}
	else 
	{
		iStatusInfo[client][3] = GetEntProp(client, Prop_Data, "m_iHealth");
		iStatusInfo[client][4] = RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
		iStatusInfo[client][5] = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));
		iStatusInfo[client][2] = GetEntProp(client, Prop_Send, "m_isGoingToDie");
	}
}

void vSetStatus(int client, int[][] iStatusInfo, char[][] sStatusInfo)
{
	SetEntProp(client, Prop_Send, "m_survivorCharacter", iStatusInfo[client][6]); 
	SetEntityModel(client, sStatusInfo[client]);
	
	if(IsFakeClient(client))
	{
		for(int i; i < 8; i++)
		{
			if(strcmp(sStatusInfo[client], g_sSurvivorModels[i]) == 0)
				SetClientName(client, g_sSurvivorNames[i]);
		}
	}

	if(!IsPlayerAlive(client)) 
		return;

	if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

	SetEntProp(client, Prop_Send, "m_currentReviveCount", iStatusInfo[client][0]);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", iStatusInfo[client][1]);
	SetEntProp(client, Prop_Send, "m_isGoingToDie", iStatusInfo[client][2]);

	SetEntProp(client, Prop_Send, "m_iHealth", iStatusInfo[client][3]);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * iStatusInfo[client][4]);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * iStatusInfo[client][5]);

	if(iStatusInfo[client][1] != 0)
		StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
}

void vCopyStatus(int client, int iTarget, int[][] iStatusInfo, char[][] sStatusInfo, int maxlength)
{
	for(int i; i < 7; i++)
		iStatusInfo[iTarget][i] = iStatusInfo[client][i];

	strcopy(sStatusInfo[iTarget], maxlength, sStatusInfo[client]);
}

int g_iGrenadeThrower[MAXPLAYERS + 1];
public void OnEntityCreated(int entity, const char[] classname)
{
	if(classname[0] != 'm' && classname[0] != 'p' && classname[0] != 'v')
		return;

	if(strncmp(classname, "molotov_projectile", 19) == 0 || strncmp(classname, "pipe_bomb_projectile", 21) == 0 || strncmp(classname, "vomitjar_projectile", 20) == 0)
		SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
}

public void Hook_SpawnPost(int entity)
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

void vRemoveWeapons(int client)
{
	int iWeapon;
	for(int iSlot; iSlot < 5; iSlot++)
	{
		iWeapon = GetPlayerWeaponSlot(client, iSlot);
		if(iWeapon > MaxClients)
		{
			RemovePlayerItem(client, iWeapon);
			RemoveEntity(iWeapon);
		}
	}
}

void vSurvivorWeapons(int client, int iType, int iTarget = -1)
{
	static bool bRecorded[MAXPLAYERS + 1];
	static int iWeaponInfo[MAXPLAYERS + 1][7];
	static char sWeaponInfo[MAXPLAYERS + 1][6][32];
	
	switch(iType)
	{
		case 0:
		{
			bRecorded[client] = false;
			vCleanWeapons(client, iWeaponInfo, sWeaponInfo);
		}
			
		case 1:
		{
			if(IsPlayerAlive(client) && bSaveWeapons(client, iWeaponInfo, sWeaponInfo, sizeof(sWeaponInfo[][])))
				bRecorded[client] = true;
		}
			
		case 2:
		{
			if(IsPlayerAlive(client) && bRecorded[client] == true)
			{
				vRemoveWeapons(client);
				vGiveWeapons(client, iWeaponInfo, sWeaponInfo);
			}
		}
			
		case 3:
		{
			bRecorded[iTarget] = bRecorded[client];
			vCopyWeapons(client, iTarget, iWeaponInfo, sWeaponInfo, sizeof(sWeaponInfo[][]));
		}
	}
}

void vCleanWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo)
{
	iWeaponInfo[client][0] = 0;
	iWeaponInfo[client][1] = 0;
	iWeaponInfo[client][2] = 0;
	iWeaponInfo[client][3] = 0;
	iWeaponInfo[client][4] = 0;
	iWeaponInfo[client][5] = -1;
	iWeaponInfo[client][6] = 0;
	
	sWeaponInfo[client][0][0] = '\0';
	sWeaponInfo[client][1][0] = '\0';
	sWeaponInfo[client][2][0] = '\0';
	sWeaponInfo[client][3][0] = '\0';
	sWeaponInfo[client][4][0] = '\0';
	sWeaponInfo[client][5][0] = '\0';
}

bool bSaveWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo, int maxlength)
{
	bool bSaved = false;

	char sWeapon[32];
	int iSlot = GetPlayerWeaponSlot(client, 0);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][0], maxlength, sWeapon);

		iWeaponInfo[client][0] = GetEntProp(iSlot, Prop_Send, "m_iClip1");
		iWeaponInfo[client][1] = iGetOrSetPlayerAmmo(client, sWeapon);
		iWeaponInfo[client][2] = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
		iWeaponInfo[client][3] = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
		iWeaponInfo[client][4] = GetEntProp(iSlot, Prop_Send, "m_nSkin");

		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 1);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		if(strcmp(sWeapon[7], "melee") == 0)
			GetEntPropString(iSlot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof(sWeapon));
		else if(strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(iSlot, Prop_Send, "m_isDualWielding") > 0)
			sWeapon = "v_dual_pistol";

		strcopy(sWeaponInfo[client][1], maxlength, sWeapon);

		if(strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
			iWeaponInfo[client][5] = GetEntProp(iSlot, Prop_Send, "m_iClip1");

		iWeaponInfo[client][6] = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		
		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 2);
	if(iSlot > MaxClients)
	{
		if(EntIndexToEntRef(iSlot) != g_iGrenadeThrower[client])
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			strcopy(sWeaponInfo[client][2], maxlength, sWeapon);
			
			bSaved = true;
		}
	}

	iSlot = GetPlayerWeaponSlot(client, 3);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][3], maxlength, sWeapon);
		
		bSaved = true;
	}

	iSlot = GetPlayerWeaponSlot(client, 4);
	if(iSlot > MaxClients)
	{
		GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
		strcopy(sWeaponInfo[client][4], maxlength, sWeapon);
		
		bSaved = true;
	}
	
	if(bSaved == true)
	{
		iSlot = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof(sWeapon));
			strcopy(sWeaponInfo[client][5], maxlength, sWeapon);
		}
	}
	
	return bSaved;
}

void vGiveWeapons(int client, int[][] iWeaponInfo, char[][][] sWeaponInfo)
{
	bool bGived = false;

	int iSlot;
	if(sWeaponInfo[client][0][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][0]);

		iSlot = GetPlayerWeaponSlot(client, 0);
		if(iSlot > MaxClients)
		{
			SetEntProp(iSlot, Prop_Send, "m_iClip1", iWeaponInfo[client][0]);
			iGetOrSetPlayerAmmo(client, sWeaponInfo[client][0], iWeaponInfo[client][1]);

			if(iWeaponInfo[client][2] > 0)
				SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", iWeaponInfo[client][2]);

			if(iWeaponInfo[client][3] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iWeaponInfo[client][3]);
				
			if(iWeaponInfo[client][4] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nSkin", iWeaponInfo[client][4]);
				
			bGived = true;
		}
	}

	if(sWeaponInfo[client][1][0] != '\0')
	{
		if(strcmp(sWeaponInfo[client][1], "v_dual_pistol") == 0)
		{
			vCheatCommand(client, "give", "weapon_pistol");
			vCheatCommand(client, "give", "weapon_pistol");
		}
		else
			vCheatCommand(client, "give", sWeaponInfo[client][1]);

		iSlot = GetPlayerWeaponSlot(client, 1);
		if(iSlot > MaxClients)
		{
			if(iWeaponInfo[client][5] != -1)
				SetEntProp(iSlot, Prop_Send, "m_iClip1", iWeaponInfo[client][5]);
				
			if(iWeaponInfo[client][6] > 0)
				SetEntProp(iSlot, Prop_Send, "m_nSkin", iWeaponInfo[client][6]);
				
			bGived = true;
		}
	}

	if(sWeaponInfo[client][2][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][2]);

		iSlot = GetPlayerWeaponSlot(client, 2);
		if(iSlot > MaxClients)
			bGived = true;
	}

	if(sWeaponInfo[client][3][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][3]);

		iSlot = GetPlayerWeaponSlot(client, 3);
		if(iSlot > MaxClients)
			bGived = true;
	}

	if(sWeaponInfo[client][4][0] != '\0')
	{
		vCheatCommand(client, "give", sWeaponInfo[client][4]);

		iSlot = GetPlayerWeaponSlot(client, 4);
		if(iSlot > MaxClients)
			bGived = true;
	}
		
	if(bGived == true && sWeaponInfo[client][5][0] != '\0')
		FakeClientCommand(client, "use %s", sWeaponInfo[client][5]);
}

void vCopyWeapons(int client, int iTarget, int[][] iWeaponInfo, char[][][] sWeaponInfo, int maxlength)
{
	int i;
	for(; i < 7; i++)
		iWeaponInfo[iTarget][i] = iWeaponInfo[client][i];
		
	i = 0;
	for(; i < 6; i++)
		strcopy(sWeaponInfo[iTarget][i], maxlength, sWeaponInfo[client][i]);
}

void vSurvivorClean(int client)
{
	vSurvivorStatus(client, 0);
	vSurvivorWeapons(client, 0);
	g_bSpawned[client] = false;
	g_bRecorded[client] = false;
}

void vSurvivorSave(int client)
{
	vSurvivorStatus(client, 1);
	vSurvivorWeapons(client, 1);
	g_bRecorded[client] = true;
}

void vSurvivorGive(int client)
{
	vSurvivorStatus(client, 2);
	vSurvivorWeapons(client, 2);
}

void vSurvivorCopy(int client, int iTarget)
{
	vSurvivorStatus(client, 3, iTarget);
	vSurvivorWeapons(client, 3, iTarget);
	g_bSpawned[iTarget] = g_bSpawned[client];
	g_bRecorded[iTarget] = g_bRecorded[client];
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
				int iIdlePlayer = iHasIdlePlayer(i);
				if(iIdlePlayer == 0)
					vSurvivorSave(i);
				else
				{
					vSurvivorSave(i);
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
	static int iCmdFlags, iFlagBits;
	iFlagBits = GetUserFlagBits(client), iCmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(sCommand, iCmdFlags | FCVAR_CHEAT);
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
