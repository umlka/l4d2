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

ConVar g_hCvarAllow;
ConVar g_hCvarMPGameMode;
ConVar g_hCvarModes;
ConVar g_hCvarModesOff;
ConVar g_hCvarModesTog;
ConVar g_hCvarFreezeNodoor;
ConVar g_hCvarDisplayMode;
ConVar g_hCvarBreakTheDoor;
ConVar g_hCvarPrepareTime1r;
ConVar g_hCvarPrepareTime2r;
ConVar g_hCvarClientTimeOut;
ConVar g_hCvarDisplayPanel;

bool g_bCvarAllow;
bool g_bMapStarted;
bool g_bIsFirstRound;
bool g_bIsFreezeAllowed;
bool g_bCvarFreezeNodoor;
bool g_bIsClientLoading[MAXPLAYERS + 1];

int g_iCountDown;
int g_iRoundStart;
int g_iPlayerSpawn;
int g_iStartSafeDoor;
int g_iCvarPrepareTime1r;
int g_iCvarPrepareTime2r;
int g_iCvarClientTimeOut;
int g_iCvarBreakTheDoor;
int g_iCvarDisplayPanel;
int g_iCvarDisplayMode;
int g_iClientTimeout[MAXPLAYERS + 1];

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

	g_hCvarAllow = CreateConVar("l4d2_dlock_allow", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hCvarModes = CreateConVar("l4d2_dlock_modes", "", "Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS);
	g_hCvarModesOff = CreateConVar("l4d2_dlock_modes_off", "", "Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS);
	g_hCvarModesTog = CreateConVar("l4d2_dlock_modes_tog", "0", "Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS);
	g_hCvarFreezeNodoor = CreateConVar("l4d2_dlock_freezenodoor", "1", "Freeze survivors if start saferoom door is absent");
	g_hCvarPrepareTime1r = CreateConVar("l4d2_dlock_prepare1st", "7", "How many seconds plugin will wait after all clients have loaded before starting first round on a map", CVAR_FLAGS);
	g_hCvarPrepareTime2r = CreateConVar("l4d2_dlock_prepare2nd", "7", "How many seconds plugin will wait after all clients have loaded before starting second round on a map", CVAR_FLAGS);
	g_hCvarClientTimeOut = CreateConVar("l4d2_dlock_timeout", "45", "How many seconds plugin will wait after a map starts before giving up on waiting for a client", CVAR_FLAGS);
	g_hCvarBreakTheDoor = CreateConVar("l4d2_dlock_weakdoor", "1", "Saferoom door will be breaked, once opened.", CVAR_FLAGS);
	g_hCvarDisplayPanel = CreateConVar("l4d2_dlock_displaypanel", "2", "Display players state panel. 0-disabled, 1-hide failed, 2-full info", CVAR_FLAGS);
	g_hCvarDisplayMode = CreateConVar("l4d2_dlock_displaymode", "1", "Set the display mode for the countdown. (0-off,1-hint, 2-center, 3-chat. any other value to hide countdown)", CVAR_FLAGS);
	CreateConVar("l4d2_dlock_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	
	g_hCvarFreezeNodoor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPrepareTime1r.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPrepareTime2r.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarClientTimeOut.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarBreakTheDoor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDisplayPanel.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDisplayMode.AddChangeHook(ConVarChanged_Cvars);

	//AutoExecConfig(true, "l4d2_doorlock");
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	int last = g_iCvarBreakTheDoor;

	g_bCvarFreezeNodoor = g_hCvarFreezeNodoor.BoolValue;
	g_iCvarPrepareTime1r = g_hCvarPrepareTime1r.IntValue;
	g_iCvarPrepareTime2r = g_hCvarPrepareTime2r.IntValue;
	g_iCvarClientTimeOut = g_hCvarClientTimeOut.IntValue;
	g_iCvarBreakTheDoor = g_hCvarBreakTheDoor.IntValue;
	g_iCvarDisplayPanel = g_hCvarDisplayPanel.IntValue;
	g_iCvarDisplayMode = g_hCvarDisplayMode.IntValue;

	if(last != g_iCvarBreakTheDoor)
	{
		if(IsValidEntRef(g_iStartSafeDoor))
		{
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnOpen", OnFirst);
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnFullyOpen", OnFullyOpened);
		}

		InitDoor();
	}
}

//Silvers
void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if(g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true)
	{
		g_bCvarAllow = true;
		InitDoor();
		HookEvents(true);
	}
	else if(g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false))
	{
		g_bCvarAllow = false;
		HookEvents(false);

		if(IsValidEntRef(g_iStartSafeDoor))
		{
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnOpen", OnFirst);
			UnhookSingleEntityOutput(g_iStartSafeDoor, "OnFullyOpen", OnFullyOpened);
		}
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
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

public void OnGamemode(const char[] output, int caller, int activator, float delay)
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

void HookEvents(bool bHook)
{
	if(bHook)
	{
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
		HookEvent("player_team", Event_PlayerTeam);
	}
	else
	{
		UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
		UnhookEvent("player_team", Event_PlayerTeam);
	}
}

public void OnMapStart()
{
	g_bMapStarted = true;
	g_bIsFirstRound = true;

	PrecacheSound(SOUND_COUNTDOWN);
	PrecacheSound(SOUND_MOVEOUT);
	PrecacheSound(SOUND_BREAK1);
	PrecacheSound(SOUND_BREAK2);
}

public void OnMapEnd()
{
	Reset();

	g_bMapStarted = false;
}

void Reset()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bIsFreezeAllowed = false;
}

public Action OnPlayerRunCmd(int client)
{
	if(!g_bIsFreezeAllowed || !IsCountDownStoppedOrRunning())
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

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Reset();

	if(g_bIsFirstRound) 
		g_bIsFirstRound = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		Start();
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		Start();
	g_iPlayerSpawn = 1;
}

void Start()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_iClientTimeout[i] = 0;
		g_bIsClientLoading[i] = true;
	}

	InitDoor();
	CreateTimer(1.0, Timer_StartSequence, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PlayerTeam(Event event, char[] event_name, bool dontBroadcast)
{
	if(!IsCountDownStoppedOrRunning())
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;
		
	g_iClientTimeout[client] = 0;
	g_bIsClientLoading[client] = false;
}

public Action Timer_StartSequence(Handle timer)
{
	g_iCountDown = -1;
	SurvivorBotsStop();

	if(IsValidEntRef(g_iStartSafeDoor))
	{
		LockTheDoor();
		CreateTimer(1.0, LoadingTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
	else if(g_bCvarFreezeNodoor)
	{
		g_bIsFreezeAllowed = true;
		CreateTimer(1.0, LoadingTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
	else
	{
		g_iCountDown = 0;
		SurvivorBotsStart();
	}
}

public Action LoadingTimer(Handle timer)
{
	if(IsFinishedLoading())
	{
		if(!g_bIsFreezeAllowed) 
			UnFreezePlayers();

		if(!IsCountDownRunning())
		{
			if(!g_bIsFreezeAllowed)
				SurvivorBotsStart();

			g_iCountDown = 0;
			CreateTimer(1.0, StartTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		}

		return Plugin_Stop;
	}
	else 
		g_iCountDown = -1;

	return Plugin_Continue;
}

public Action StartTimer(Handle timer)
{
	if(g_iCountDown == -1)
	{
		SurvivorBotsStop();
		return Plugin_Stop;
	}
	else if(g_iCountDown >= (g_bIsFirstRound ? g_iCvarPrepareTime1r : g_iCvarPrepareTime2r))
	{
		g_iCountDown = 0;
		PrintTextAll("%t", "DL_Moveout");
		SurvivorBotsStart();
		UnFreezePlayers();

		if(IsValidEntRef(g_iStartSafeDoor))
			UnlockTheDoor();

		PlaySound(SOUND_MOVEOUT);

		g_bIsFirstRound = false;
		return Plugin_Stop;
	}
	else
	{
		if(!g_bIsFreezeAllowed)
			PrintTextAll("%t", "DL_Locked", (g_bIsFirstRound ? g_iCvarPrepareTime1r : g_iCvarPrepareTime2r) - g_iCountDown);
		else
			PrintTextAll("%t", "DL_Frozen", (g_bIsFirstRound ? g_iCvarPrepareTime1r : g_iCvarPrepareTime2r) - g_iCountDown);

		PlaySound(SOUND_COUNTDOWN);
		g_iCountDown++;
	}
	return Plugin_Continue;
}

void SurvivorBotsStart()
{
	FindConVar("sb_stop").SetInt(0);
}

void SurvivorBotsStop()
{
	FindConVar("sb_stop").SetInt(1);
}

void ShowStatusPanel()
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
			else if(g_iClientTimeout[i] >= g_iCvarClientTimeOut) 
				iLoadFailed++;
			else 
				iConnected++;
		}
	}

	char sInfo[256];
	Panel panel;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			panel = new Panel();
			SetGlobalTransTarget(client);

			FormatEx(sInfo, sizeof(sInfo), "%t", "DL_Menu_Header");
			panel.DrawText(sInfo);

			if(iLoading)
			{
				FormatEx(sInfo, sizeof(sInfo), "%t", "DL_Menu_Connecting");
				panel.DrawText(sInfo);

				iLoading = 0;
				for(i = 1; i <= MaxClients; i++) 
				{
					if(IsClientConnected(i) && !IsFakeClient(i))
					{
						if(g_bIsClientLoading[i])
						{
							iLoading++;
							FormatEx(sInfo, sizeof(sInfo), "->%d. %N", iLoading, i);
							panel.DrawText(sInfo);
						}
					}
				}
			}

			if(iConnected)
			{
				FormatEx(sInfo, sizeof(sInfo), "%t", "DL_Menu_Ingame");
				panel.DrawText(sInfo);

				iConnected = 0;
				for(i = 1; i <= MaxClients; i++) 
				{
					if(IsClientConnected(i) && !IsFakeClient(i))
					{
						if(!g_bIsClientLoading[i] && g_iClientTimeout[i] < g_iCvarClientTimeOut)
						{
							iConnected++;
							FormatEx(sInfo, sizeof(sInfo), "->%d. %N", iConnected, i);
							panel.DrawText(sInfo);
						}
					}
				}
			}

			if(g_iCvarDisplayPanel > 1)
			{
				if(iLoadFailed)
				{
					FormatEx(sInfo, sizeof(sInfo), "%t", "DL_Menu_Fail");
					panel.DrawText(sInfo);

					iLoadFailed = 0;
					for(i = 1; i <= MaxClients; i++) 
					{
						if(IsClientConnected(i) && !IsFakeClient(i))
						{
							if(!g_bIsClientLoading[i] && g_iClientTimeout[i] >= g_iCvarClientTimeOut)
							{
								iLoadFailed++;
								FormatEx(sInfo, sizeof(sInfo), "->%d. %N", iLoadFailed, i);
								panel.DrawText(sInfo);
							}
						}
					}
				}
			}

			panel.Send(client, PanelHandler, 5);
			delete panel;
		}
	}
}

public int PanelHandler(Menu menu, MenuAction action, int param1, int param2)
{

}

void LockTheDoor()
{
	DispatchKeyValue(g_iStartSafeDoor, "spawnflags", "585728");
}

void UnlockTheDoor()
{
	DispatchKeyValue(g_iStartSafeDoor, "spawnflags", "8192");
}

void UnFreezePlayers()
{
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i)) 
		{
			if(GetEntityMoveType(i) == MOVETYPE_NONE) 
				SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}
}

void InitDoor()
{
	g_iStartSafeDoor = 0;
	
	if(g_iCvarBreakTheDoor == 0)
		return;

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
			if(iChangelevel == 0 || !IsDotInEndArea(vOrigin, vMins, vMaxs))
			{
				g_iStartSafeDoor = EntIndexToEntRef(entity);
				HookSingleEntityOutput(entity, "OnOpen", OnFirst, true);
				HookSingleEntityOutput(entity, "OnFullyOpen", OnFullyOpened, true);
				break;
			}
		}
	}
}

stock bool IsDotInEndArea(const float vDot[3], const float vMins[3], const float vMaxs[3])
{
	return vMins[0] < vDot[0] < vMaxs[0] && vMins[1] < vDot[1] < vMaxs[1] && vMins[2] < vDot[2] < vMaxs[2];
}

//https://forums.alliedmods.net/showthread.php?p=2700212
public void OnFirst(const char[] output, int entity, int activator, float delay)
{
	char sModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	float vPos[3], vAng[3], vDir[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

	int door = CreateEntityByName("prop_physics");
	DispatchKeyValue(door, "spawnflags", "4"); // Prevent collision
	DispatchKeyValue(door, "model", sModel);
	DispatchSpawn(door);

	// Tilt ang away
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);

	float dist;

	if(strcmp(sModel, "models/props_doors/checkpoint_door_-01.mdl") == 0)
		dist = -10.0;
	else
		dist = 10.0;

	// Move pos away due to ang change
	vPos[0] += (vDir[0] * dist);
	vPos[1] += (vDir[1] * dist);
	vAng[0] = dist;
	vDir[0] = 0.0;
	vDir[1] = vAng[1] < 270.0 ? 10.0 : -10.0 * dist;
	vDir[2] = 0.0;

	//Lux
	AcceptEntityInput(entity, "DisableCollision");
	SetEntProp(entity, Prop_Send, "m_noGhostCollision", 1);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0x0004);
	SetEntProp(entity, Prop_Data, "m_iEFlags", 0);
	
	SetEntProp(entity, Prop_Data, "m_fEffects", 0x020); //don't draw entity

	TeleportEntity(door, vPos, vAng, vDir);

	// Stop movement
	FormatEx(sModel, sizeof(sModel), "OnUser1 !self:DisableMotion::3.0:1");
	SetVariantString(sModel);
	AcceptEntityInput(door, "AddOutput");
	AcceptEntityInput(door, "FireUser1");

	//AcceptEntityInput(entity, "Kill");

	EmitSoundToAll(GetRandomInt(0, 1) ? SOUND_BREAK1 : SOUND_BREAK2, door);
}

public void OnFullyOpened(const char[] output, int entity, int activator, float delay)
{
	DispatchKeyValue(entity, "spawnflags", "585728");
}

bool IsCountDownRunning()
{
	return g_iCountDown > 0;
}

bool IsCountDownStoppedOrRunning()
{
	return g_iCountDown != 0;
}

bool IsAnyClientLoading()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_bIsClientLoading[i]) 
			return true;
	}
	return false;
}

bool IsFinishedLoading()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(!IsClientInGame(i) && !IsFakeClient(i))
			{
				if(++g_iClientTimeout[i] >= g_iCvarClientTimeOut) 
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

	if(g_iCvarDisplayPanel > 0 && g_bIsFirstRound)
		ShowStatusPanel();

	return !IsAnyClientLoading();
}

void PrintTextAll(const char[] format, any ...)
{
	char buffer[192];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			switch(g_iCvarDisplayMode)
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

bool IsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

stock void PlaySound(const char[] sSound)
{
	EmitSoundToAll(sSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}
