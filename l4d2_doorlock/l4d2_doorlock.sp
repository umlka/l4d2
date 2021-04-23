#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "2.6a"

#define SOUND_COUNTDOWN 	"buttons/blip1.wav"
#define SOUND_MOVEOUT 		"ui/survival_teamrec.wav"
#define SOUND_BREAK1		"physics/metal/metal_box_break1.wav"
#define SOUND_BREAK2		"physics/metal/metal_box_break2.wav"

Panel g_hStatusPanel;

ConVar g_hGameMode;
ConVar g_hCvarFreezeNodoor;
ConVar g_hCvarDisplayMode;
ConVar g_hCvarGameModeEnabled;
ConVar g_hCvarBreakTheDoor;
ConVar g_hCvarPrepareTime1r;
ConVar g_hCvarPrepareTime2r;
ConVar g_hCvarClientTimeOut;
ConVar g_hCvarDisplayPanel;

bool g_bIsFirstRound;
bool g_bIsFreezeAllowed;
bool g_bIsDoorBreakeble;
bool g_bIsAllowedGameMode;
bool g_bIsClientLoading[MAXPLAYERS + 1];

int g_iCountDown;
int g_iRoundStart;
int g_iPlayerSpawn;
int g_iStartSafeDoor;
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

	CreateConVar("l4d2_dlock_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hCvarFreezeNodoor = CreateConVar("l4d2_dlock_freezenodoor", "1", "Freeze survivors if start saferoom door is absent");
	g_hCvarPrepareTime1r = CreateConVar("l4d2_dlock_prepare1st", "7", "How many seconds plugin will wait after all clients have loaded before starting first round on a map");
	g_hCvarPrepareTime2r = CreateConVar("l4d2_dlock_prepare2nd", "7", "How many seconds plugin will wait after all clients have loaded before starting second round on a map");
	g_hCvarClientTimeOut = CreateConVar("l4d2_dlock_timeout", "45", "How many seconds plugin will wait after a map starts before giving up on waiting for a client");
	g_hCvarBreakTheDoor = CreateConVar("l4d2_dlock_weakdoor", "1", "Saferoom door will be breaked, once opened.");
	g_hCvarDisplayPanel = CreateConVar("l4d2_dlock_displaypanel", "2", "Display players state panel. 0-disabled, 1-hide iFailed, 2-full info");
	g_hCvarDisplayMode = CreateConVar("l4d2_dlock_displaymode", "1", "Set the display mode for the countdown. (0-off,1-hint, 2-center, 3-chat. any other value to hide countdown)");
	g_hCvarGameModeEnabled = CreateConVar("l4d2_dlock_gamemodeactive", "coop,versus", "Set the game mode for which the plugin should be activated");

	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(ConVarChanged_GameMode);
	
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);

	//AutoExecConfig(true, "l4d2_doorlock");
}

public void OnConfigsExecuted()
{
	GetModeCvars();
}

public void ConVarChanged_GameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetModeCvars();
}

void GetModeCvars()
{
	char sGameMode[64], sEnabledModes[256];
	g_hGameMode.GetString(sGameMode, sizeof(sGameMode));
	g_hCvarGameModeEnabled.GetString(sEnabledModes, sizeof(sEnabledModes));
	g_bIsAllowedGameMode = !!(StrContains(sEnabledModes, sGameMode) != -1);
}

public void OnClientDisconnect(int client)
{
	g_iClientTimeout[client] = 0;
	g_bIsClientLoading[client] = false;
}

public void OnMapStart()
{
	g_bIsFirstRound = true;
	
	PrecacheSound(SOUND_COUNTDOWN);
	PrecacheSound(SOUND_MOVEOUT);
}

public void OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bIsFreezeAllowed = false;
	g_bIsDoorBreakeble = false;
}

public Action OnPlayerRunCmd(int client)
{
	if(!g_bIsFreezeAllowed || !IsCountDownStoppedOrRunning())
		return Plugin_Continue;

	if(GetClientTeam(client) == 2)
		SetEntityMoveType(client, MOVETYPE_NONE);
		
	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();

	if(g_bIsAllowedGameMode)
	{
		if(g_bIsFirstRound) 
			g_bIsFirstRound = false;
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		InitPlugin();
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		InitPlugin();
	g_iPlayerSpawn = 1;
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

void InitPlugin()
{
	if(g_bIsAllowedGameMode)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			g_iClientTimeout[i] = 0;
			g_bIsClientLoading[i] = true;
		}

		SurvivorBotsStop();
		FindStartSafeDoor();
		CreateTimer(0.2, Timer_StartSequence, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else 
		SurvivorBotsStart();
}

public Action Timer_StartSequence(Handle timer)
{
	g_iCountDown = -1;

	if(g_hCvarBreakTheDoor.BoolValue && IsValidEntRef(g_iStartSafeDoor))
		g_bIsDoorBreakeble = true;

	if(IsValidEntRef(g_iStartSafeDoor))
	{
		LockTheDoor();
		CreateTimer(1.0, LoadingTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
	else if(g_hCvarFreezeNodoor.BoolValue)
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
	else if(g_iCountDown >= (g_bIsFirstRound ? g_hCvarPrepareTime1r.IntValue : g_hCvarPrepareTime2r.IntValue))
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
			PrintTextAll("%t", "DL_Locked", (g_bIsFirstRound ? g_hCvarPrepareTime1r.IntValue : g_hCvarPrepareTime2r.IntValue) - g_iCountDown);
		else
			PrintTextAll("%t", "DL_Frozen", (g_bIsFirstRound ? g_hCvarPrepareTime1r.IntValue : g_hCvarPrepareTime2r.IntValue) - g_iCountDown);

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
	int iFailed;
	int iConnected;
	int iTimelimit = g_hCvarClientTimeOut.IntValue;
	for(i = 1; i <= MaxClients; i++) 
	{
		if(IsClientConnected(i) && !IsFakeClient(i)) 
		{
			if(g_bIsClientLoading[i]) 
				iLoading++;
			else if(g_iClientTimeout[i] >= iTimelimit) 
				iFailed++;
			else 
				iConnected++;
		}
	}

	if(g_hStatusPanel != null) 
		delete g_hStatusPanel;

	g_hStatusPanel = new Panel();

	char sReadyPlayers[256];
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			SetGlobalTransTarget(client);

			char DL_Menu_Header[128];
			FormatEx(DL_Menu_Header, sizeof(DL_Menu_Header), "%t", "DL_Menu_Header");
			g_hStatusPanel.DrawText(DL_Menu_Header);

			if(iLoading)
			{
				char DL_Menu_Connecting[128];
				FormatEx(DL_Menu_Connecting, sizeof(DL_Menu_Connecting), "%t", "DL_Menu_Connecting");
				g_hStatusPanel.DrawText(DL_Menu_Connecting);
				iLoading = 0;

				for(i = 1; i <= MaxClients; i++) 
				{
					if(IsClientConnected(i) && !IsFakeClient(i))
					{
						if(g_bIsClientLoading[i])
						{
							iLoading++;
							FormatEx(sReadyPlayers, sizeof(sReadyPlayers), "->%d. %N", iLoading, i);
							g_hStatusPanel.DrawText(sReadyPlayers);
						}
					}
				}
			}

			if(iConnected)
			{
				char DL_Menu_Ingame[128];
				FormatEx(DL_Menu_Ingame, sizeof(DL_Menu_Ingame), "%t", "DL_Menu_Ingame");
				g_hStatusPanel.DrawText(DL_Menu_Ingame);
				iConnected = 0;

				for(i = 1; i <= MaxClients; i++) 
				{
					if(IsClientConnected(i) && !IsFakeClient(i))
					{
						if(!g_bIsClientLoading[i] && g_iClientTimeout[i] < iTimelimit)
						{
							iConnected++;
							FormatEx(sReadyPlayers, sizeof(sReadyPlayers), "->%d. %N", iConnected, i);
							g_hStatusPanel.DrawText(sReadyPlayers);
						}
					}
				}
			}

			if(g_hCvarDisplayPanel.IntValue > 1)
			{
				if(iFailed)
				{
					char DL_Menu_Fail[128];
					FormatEx(DL_Menu_Fail, sizeof(DL_Menu_Fail), "%t", "DL_Menu_Fail");
					g_hStatusPanel.DrawText(DL_Menu_Fail);
					iFailed = 0;

					for(i = 1; i <= MaxClients; i++) 
					{
						if(IsClientConnected(i) && !IsFakeClient(i))
						{
							if(!g_bIsClientLoading[i] && g_iClientTimeout[i] >= iTimelimit)
							{
								iFailed++;
								FormatEx(sReadyPlayers, sizeof(sReadyPlayers), "->%d. %N", iFailed, i);
								g_hStatusPanel.DrawText(sReadyPlayers);
							}
						}
					}
				}
			}

			g_hStatusPanel.Send(client, blankhandler, 5);
		}
	}
	delete g_hStatusPanel;
}

public int blankhandler(Menu menu, MenuAction action, int param1, int param2)
{

}

void LockTheDoor()
{
	if(IsValidEntRef(g_iStartSafeDoor))
		DispatchKeyValue(g_iStartSafeDoor, "spawnflags", "585728");
}

void UnlockTheDoor()
{
	if(IsValidEntRef(g_iStartSafeDoor))
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

void FindStartSafeDoor()
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
	if(!g_bIsDoorBreakeble)
		return;

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
	if(!g_bIsDoorBreakeble)
		return;
		
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
				g_iClientTimeout[i]++;
				if(g_bIsClientLoading[i])
				{
					if(g_iClientTimeout[i] == 1) 
						g_bIsClientLoading[i] = true;
				}

				if(g_iClientTimeout[i] == g_hCvarClientTimeOut.IntValue) 
					g_bIsClientLoading[i] = false;
			}
			else 
				g_bIsClientLoading[i] = false;
		}
		else 
			g_bIsClientLoading[i] = false;
	}

	if(g_hCvarDisplayPanel.IntValue > 0 && g_bIsFirstRound)
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
			switch(g_hCvarDisplayMode.IntValue)
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
