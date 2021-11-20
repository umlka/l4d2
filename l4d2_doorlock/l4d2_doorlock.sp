#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION 	"2.6a"

#define SOUND_COUNTDOWN "buttons/blip1.wav"
#define SOUND_MOVEOUT 	"ui/survival_teamrec.wav"
#define SOUND_BREAK1	"physics/metal/metal_box_break1.wav"
#define SOUND_BREAK2	"physics/metal/metal_box_break2.wav"
#define CVAR_FLAGS		FCVAR_NOTIFY

Handle
	g_hTimer;

Panel
	g_hPanel;

ConVar
	g_hAllow,
	g_hGameMode,
	g_hModes,
	g_hModesOff,
	g_hModesTog,
	g_hFreezeNodoor,
	g_hDisplayMode,
	g_hBreakTheDoor,
	g_hPrepareTime1r,
	g_hPrepareTime2r,
	g_hClientTimeOut,
	g_hDisplayPanel;

bool
	g_bCvarAllow,
	g_bMapStarted,
	g_bIsFirstRound,
	g_bIsFreezeAllowed,
	g_bCvarFreezeNodoor,
	g_bIsClientLoading[MAXPLAYERS + 1];

int
	g_iCountDown,
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iStartSafeDoor,
	g_iPrepareTime1r,
	g_iPrepareTime2r,
	g_iClientTimeOut,
	g_iBreakTheDoor,
	g_iDisplayPanel,
	g_iDisplayMode,
	g_iClientTimeout[MAXPLAYERS + 1];

char
	g_sInfo[256];

public Plugin myinfo =
{
	name = "L4D2 Door Lock",
	author = "Glide Loading",
	description = "Saferoom Door locked until all players loaded and infected are ready to spawn",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showpost.php?p=1373587&postcount=136"
};

public void OnPluginStart()
{
	LoadTranslations("doorlock.phrases");

	CreateConVar("l4d2_dlock_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);

	g_hAllow = CreateConVar("l4d2_dlock_allow", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hModes = CreateConVar("l4d2_dlock_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hModesOff = CreateConVar("l4d2_dlock_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS);
	g_hModesTog = CreateConVar("l4d2_dlock_modes_tog", "0", "Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS);
	g_hFreezeNodoor = CreateConVar("l4d2_dlock_freezenodoor", "0", "Freeze survivors if start saferoom door is absent");
	g_hPrepareTime1r = CreateConVar("l4d2_dlock_prepare1st", "7", "How many seconds plugin will wait after all clients have loaded before starting first round on a map", CVAR_FLAGS);
	g_hPrepareTime2r = CreateConVar("l4d2_dlock_prepare2nd", "7", "How many seconds plugin will wait after all clients have loaded before starting second round on a map", CVAR_FLAGS);
	g_hClientTimeOut = CreateConVar("l4d2_dlock_timeout", "45", "How many seconds plugin will wait after a map starts before giving up on waiting for a client", CVAR_FLAGS);
	g_hBreakTheDoor = CreateConVar("l4d2_dlock_weakdoor", "1", "Saferoom door will be breaked, once opened.", CVAR_FLAGS);
	g_hDisplayPanel = CreateConVar("l4d2_dlock_displaypanel", "2", "Display players state panel. 0-disabled, 1-hide failed, 2-full info", CVAR_FLAGS);
	g_hDisplayMode = CreateConVar("l4d2_dlock_displaymode", "1", "Set the display mode for the countdown. (0-off,1-hint, 2-center, 3-chat. any other value to hide countdown)", CVAR_FLAGS);

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(vAllowConVarChanged);
	g_hModes.AddChangeHook(vAllowConVarChanged);
	g_hModesOff.AddChangeHook(vAllowConVarChanged);
	g_hModesTog.AddChangeHook(vAllowConVarChanged);
	g_hAllow.AddChangeHook(vAllowConVarChanged);
	
	g_hFreezeNodoor.AddChangeHook(vOtherConVarChanged);
	g_hPrepareTime1r.AddChangeHook(vOtherConVarChanged);
	g_hPrepareTime2r.AddChangeHook(vOtherConVarChanged);
	g_hClientTimeOut.AddChangeHook(vOtherConVarChanged);
	g_hBreakTheDoor.AddChangeHook(vOtherConVarChanged);
	g_hDisplayPanel.AddChangeHook(vOtherConVarChanged);
	g_hDisplayMode.AddChangeHook(vOtherConVarChanged);

	//AutoExecConfig(true, "l4d2_doorlock");
}

public void OnConfigsExecuted()
{
	vIsAllowed();
}

void vAllowConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vIsAllowed();
}

void vOtherConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	int iLast = g_iBreakTheDoor;

	g_bCvarFreezeNodoor = g_hFreezeNodoor.BoolValue;
	g_iPrepareTime1r = g_hPrepareTime1r.IntValue;
	g_iPrepareTime2r = g_hPrepareTime2r.IntValue;
	g_iClientTimeOut = g_hClientTimeOut.IntValue;
	g_iBreakTheDoor = g_hBreakTheDoor.IntValue;
	g_iDisplayPanel = g_hDisplayPanel.IntValue;
	g_iDisplayMode = g_hDisplayMode.IntValue;

	if(iLast != g_iBreakTheDoor)
	{
		if(bIsValidEntRef(g_iStartSafeDoor))
		{
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnOpen", vOnFirstOpen);
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnFullyOpen", vOnFullyOpen);
		}

		vInitDoor();
	}
}

//Silvers
void vIsAllowed()
{
	bool bCvarAllow = g_hAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	vGetCvars();

	if(g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true)
	{
		g_bCvarAllow = true;
		vInitDoor();
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
		HookEvent("player_team", Event_PlayerTeam);
	}
	else if(g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false))
	{
		g_bCvarAllow = false;
		UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
		UnhookEvent("player_team", Event_PlayerTeam);

		if(bIsValidEntRef(g_iStartSafeDoor))
		{
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnOpen", vOnFirstOpen);
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnFullyOpen", vOnFullyOpen);
		}

		delete g_hTimer;
		vUnFreezeBots();
		vUnFreezePlayers();
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if(g_hGameMode == null)
		return false;

	int iCvarModesTog = g_hModesTog.IntValue;
	if(iCvarModesTog != 0)
	{
		if(g_bMapStarted == false)
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if(IsValidEntity(entity))
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if(IsValidEntity(entity)) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if(g_iCurrentMode == 0)
			return false;

		if(!(iCvarModesTog & g_iCurrentMode))
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

void OnGamemode(const char[] output, int caller, int activator, float delay)
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

public Action OnPlayerRunCmd(int client)
{
	if(!g_bIsFreezeAllowed || g_iCountDown == 0)
		return Plugin_Continue;

	if(GetClientTeam(client) == 2)
		SetEntityMoveType(client, MOVETYPE_NONE);
		
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	g_iClientTimeout[client] = 0;
	g_bIsClientLoading[client] = false;
}

public void OnMapStart()
{
	g_bMapStarted = true;
	g_bIsFirstRound = true;

	PrecacheSound(SOUND_BREAK1);
	PrecacheSound(SOUND_BREAK2);
	PrecacheSound(SOUND_MOVEOUT);
	PrecacheSound(SOUND_COUNTDOWN);
}

public void OnMapEnd()
{
	delete g_hTimer;

	g_iCountDown = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bIsFreezeAllowed = false;

	g_bMapStarted = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;

	g_iCountDown = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bIsFreezeAllowed = false;

	if(g_bIsFirstRound)
		g_bIsFirstRound = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		vInitPlugin();
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		vInitPlugin();
	g_iPlayerSpawn = 1;
}

void vInitPlugin()
{
	delete g_hTimer;

	for(int i = 1; i <= MaxClients; i++)
		vResetLoading(i);

	vInitDoor();
	vStartSequence();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iCountDown == 0)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;
		
	vResetLoading(client);
}

void vResetLoading(int client)
{
	g_iClientTimeout[client] = 0;
	g_bIsClientLoading[client] = false;
}

void vStartSequence()
{
	if(bIsValidEntRef(g_iStartSafeDoor))
	{
		g_iCountDown = -1;

		vLockDoor();
		vFreezeBots();
		g_hTimer = CreateTimer(1.0, Timer_Loading, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	else
	{
		if(g_bCvarFreezeNodoor)
		{
			g_iCountDown = -1;

			g_bIsFreezeAllowed = true;
			vExecuteCheatCommand("nb_stop", "1");
			g_hTimer = CreateTimer(1.0, Timer_Loading, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		}
	}
}

Action Timer_Loading(Handle timer)
{
	if(g_iCountDown >= 0)
	{
		if(g_iCountDown >= (g_bIsFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r))
		{
			g_iCountDown = 0;

			vPrintTextAll("%t", "DL_Moveout");

			if(!g_bIsFreezeAllowed)
				vUnFreezeBots();
			else
				vUnFreezePlayers();

			if(bIsValidEntRef(g_iStartSafeDoor))
				vUnLockDoor();

			vPlaySound(SOUND_MOVEOUT);

			g_hTimer = null;
			return Plugin_Stop;
		}
		else
		{
			if(!g_bIsFreezeAllowed)
				vPrintTextAll("%t", "DL_Locked", (g_bIsFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r) - g_iCountDown);
			else
				vPrintTextAll("%t", "DL_Frozen", (g_bIsFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r) - g_iCountDown);

			vPlaySound(SOUND_COUNTDOWN);
			g_iCountDown++;
		}
	}
	else
	{
		if(bIsFinishedLoading())
			g_iCountDown = 0;
		else
			g_iCountDown = -1;
	}

	return Plugin_Continue;
}

void vShowStatusPanel()
{
	int i;
	int iLoading;
	int iConnected;
	int iLoadFailed;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			if(g_bIsClientLoading[i])
				iLoading++;
			else if(g_iClientTimeout[i] >= g_iClientTimeOut)
				iLoadFailed++;
			else 
				iConnected++;
		}
	}

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			g_hPanel = new Panel();
			SetGlobalTransTarget(client);

			FormatEx(g_sInfo, sizeof(g_sInfo), "%t", "DL_Menu_Header");
			g_hPanel.DrawText(g_sInfo);

			if(iLoading)
			{
				FormatEx(g_sInfo, sizeof(g_sInfo), "%t", "DL_Menu_Connecting");
				g_hPanel.DrawText(g_sInfo);

				iLoading = 0;
				for(i = 1; i <= MaxClients; i++)
				{
					if(IsClientConnected(i) && !IsFakeClient(i))
					{
						if(g_bIsClientLoading[i])
						{
							iLoading++;
							FormatEx(g_sInfo, sizeof(g_sInfo), "->%d. %N", iLoading, i);
							g_hPanel.DrawText(g_sInfo);
						}
					}
				}
			}

			if(iConnected)
			{
				FormatEx(g_sInfo, sizeof(g_sInfo), "%t", "DL_Menu_Ingame");
				g_hPanel.DrawText(g_sInfo);

				iConnected = 0;
				for(i = 1; i <= MaxClients; i++)
				{
					if(IsClientConnected(i) && !IsFakeClient(i))
					{
						if(!g_bIsClientLoading[i] && g_iClientTimeout[i] < g_iClientTimeOut)
						{
							iConnected++;
							FormatEx(g_sInfo, sizeof(g_sInfo), "->%d. %N", iConnected, i);
							g_hPanel.DrawText(g_sInfo);
						}
					}
				}
			}

			if(g_iDisplayPanel > 1)
			{
				if(iLoadFailed)
				{
					FormatEx(g_sInfo, sizeof(g_sInfo), "%t", "DL_Menu_Fail");
					g_hPanel.DrawText(g_sInfo);

					iLoadFailed = 0;
					for(i = 1; i <= MaxClients; i++)
					{
						if(IsClientConnected(i) && !IsFakeClient(i))
						{
							if(!g_bIsClientLoading[i] && g_iClientTimeout[i] >= g_iClientTimeOut)
							{
								iLoadFailed++;
								FormatEx(g_sInfo, sizeof(g_sInfo), "->%d. %N", iLoadFailed, i);
								g_hPanel.DrawText(g_sInfo);
							}
						}
					}
				}
			}

			g_hPanel.Send(client, iPanelHandler, 5);
			delete g_hPanel;
		}
	}
}

int iPanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

void vLockDoor()
{
	SetEntProp(g_iStartSafeDoor, Prop_Send, "m_spawnflags", 585728);
}

void vUnLockDoor()
{
	SetEntProp(g_iStartSafeDoor, Prop_Send, "m_spawnflags", 8192);
}

void vFreezeBots()
{
	vExecuteCheatCommand("sb_stop", "1");
}

void vUnFreezeBots()
{
	vExecuteCheatCommand("sb_stop", "0");
}

void vUnFreezePlayers()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetEntityMoveType(i) == MOVETYPE_NONE)
				SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}

	vExecuteCheatCommand("nb_stop", "0");
}

void vInitDoor()
{
	g_iStartSafeDoor = 0;

	int iChangelevel;
	int entity = INVALID_ENT_REFERENCE;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");
		
	float vMins[3], vMaxs[3], vOrigin[3];
	if(entity != INVALID_ENT_REFERENCE)
	{
		iChangelevel = entity;

		GetEntPropVector(entity, Prop_Send, "m_vecMins", vMins);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vMaxs);
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);

		vMins[0] -= 100.0;
		vMins[1] -= 100.0;
		vMins[2] -= 100.0;
	
		vMaxs[0] += 100.0;
		vMaxs[1] += 100.0;
		vMaxs[2] += 100.0;
	
		AddVectors(vOrigin, vMins, vMins);
		AddVectors(vOrigin, vMaxs, vMaxs);
	}

	entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
	{
		if(g_iStartSafeDoor == 0 && GetEntProp(entity, Prop_Send, "m_bLocked") == 1 && GetEntProp(entity, Prop_Data, "m_eDoorState") == 0)
		{
			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
			if(iChangelevel == 0 || !bIsDotInEndArea(vOrigin, vMins, vMaxs))
			{
				g_iStartSafeDoor = EntIndexToEntRef(entity);
				if(g_iBreakTheDoor == 1)
					HookSingleEntityOutput(entity, "OnOpen", vOnFirstOpen, true);
				HookSingleEntityOutput(entity, "OnFullyOpen", vOnFullyOpen, true);
				break;
			}
		}
	}
}

bool bIsDotInEndArea(const float vDot[3], const float vMins[3], const float vMaxs[3])
{
	return vMins[0] < vDot[0] < vMaxs[0] && vMins[1] < vDot[1] < vMaxs[1] && vMins[2] < vDot[2] < vMaxs[2];
}

//https://forums.alliedmods.net/showthread.php?p=2700212
void vOnFirstOpen(const char[] output, int entity, int activator, float delay)
{
	char sModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	float vPos[3], vAng[3], vDir[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);

	AcceptEntityInput(entity, "DisableCollision");
	SetEntProp(entity, Prop_Data, "m_iEFlags", 0);
	SetEntProp(entity, Prop_Data, "m_fEffects", 0x020);

	int door = CreateEntityByName("prop_physics");
	DispatchKeyValue(door, "spawnflags", "4");
	DispatchKeyValue(door, "model", sModel);
	DispatchSpawn(door);

	TeleportEntity(door, vPos, vAng, NULL_VECTOR);

	SetVariantString("unlock");
	AcceptEntityInput(entity, "SetAnimation");

	entity = EntRefToEntIndex(entity);
	for(int att; att < 2048; att++)
	{
		if(IsValidEdict(att))
		{
			if(HasEntProp(att, Prop_Send, "moveparent") && GetEntPropEnt(att, Prop_Send, "moveparent") == entity)
			{
				SetVariantString("!activator");
				AcceptEntityInput(att, "SetParent", door);
			}
		}
	}

	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);

	float dist = strcmp(sModel, "models/props_doors/checkpoint_door_-01.mdl") == 0 ? -10.0 : 10.0;

	vPos[0] += (vDir[0] * dist);
	vPos[1] += (vDir[1] * dist);
	vAng[0] = dist;
	vDir[0] = 0.0;
	vDir[1] = vAng[1] < 270.0 ? 10.0 : -10.0 * dist;
	vDir[2] = 0.0;

	TeleportEntity(door, vPos, vAng, vDir);

	EmitSoundToAll(GetRandomInt(0, 1) ? SOUND_BREAK1 : SOUND_BREAK2, door);
}

void vOnFullyOpen(const char[] output, int entity, int activator, float delay)
{
	vLockDoor();
}

bool bIsAnyClientLoading()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bIsClientLoading[i])
			return true;
	}
	return false;
}

bool bIsFinishedLoading()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(!IsClientInGame(i) && !IsFakeClient(i))
			{
				if(++g_iClientTimeout[i] >= g_iClientTimeOut)
					g_bIsClientLoading[i] = false;
				else
					g_bIsClientLoading[i] = true;
			}
			else 
				g_bIsClientLoading[i] = false;
		}
		else 
			g_bIsClientLoading[i] = false;
	}

	if(g_iDisplayPanel > 0 && g_bIsFirstRound)
		vShowStatusPanel();

	return !bIsAnyClientLoading();
}

void vPrintTextAll(const char[] format, any ...)
{
	char buffer[192];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			switch(g_iDisplayMode)
			{
				case 1:
					PrintHintText(i, buffer);
				case 2:
					PrintCenterText(i, buffer);
				case 3:
					PrintToChat(i, buffer);
			}
		}
	}
}

bool bIsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

void vPlaySound(const char[] sSound)
{
	EmitSoundToAll(sSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

void vExecuteCheatCommand(const char[] sCommand, const char[] sValue = "")
{
	int iCmdFlags = GetCommandFlags(sCommand);
	SetCommandFlags(sCommand, iCmdFlags & ~FCVAR_CHEAT);
	ServerCommand("%s %s", sCommand, sValue);
	ServerExecute();
	SetCommandFlags(sCommand, iCmdFlags);
}
