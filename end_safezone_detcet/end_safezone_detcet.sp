#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <navmesh>

#define SOUND_COUNTDOWN "buttons/blip1.wav"

Handle g_hTimer;

ConVar g_hEndSafezoneMethod;
ConVar g_hEndSafezoneTime;
ConVar g_hRemoveAllInfected;

int g_iCountdown;
int g_iRoundStart; 
int g_iPlayerSpawn;
int g_iChangelevel;
int g_iLastSafeDoor;
int g_iEndSafezoneMethod;
int g_iEndSafezoneTime;

float g_vMins[3];
float g_vMaxs[3];
float g_vChangelevel[3];

bool g_bHasTriggered;
bool g_bRemoveAllInfected;
bool g_bIsInEndSafezone[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "End Safezone Detcet",
    author = "sorallll",
    description = "",
    version = "1.0",
    url = ""
}

public void OnPluginStart()
{
	g_hEndSafezoneMethod = CreateConVar("end_safezone_method", "0", "如何处理未进入终点安全屋的玩家?(0=传送,1=处死)", _, true, 0.0, true, 1.0);
	g_hEndSafezoneTime = CreateConVar("end_safezone_time", "30", "倒计时多久(0=关闭该功能)", _, true, 0.0);
	g_hRemoveAllInfected = CreateConVar("end_safezone_remove", "1", "传送前是否移除终点安全屋内的感染者", _, true, 0.0, true, 1.0);
	
	g_hEndSafezoneMethod.AddChangeHook(ConVarChanged);
	g_hEndSafezoneTime.AddChangeHook(ConVarChanged);
	g_hRemoveAllInfected.AddChangeHook(ConVarChanged);

	//AutoExecConfig(true, "end_safezone_detcet");
	//想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	
	RegAdminCmd("sm_warpend", CmdWarpEnd, ADMFLAG_RCON, "传送所有生还者到终点安全区域");
	RegAdminCmd("sm_finale", CmdFinale, ADMFLAG_RCON, "结局关卡强制过关(强制触发finale_win事件)");
}

public Action CmdWarpEnd(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	if(!IsValidEntRef(g_iChangelevel))
	{
		ReplyToCommand(client, "当前章节无changelevel实体或是结局地图");
		return Plugin_Handled;
	}

	g_bHasTriggered = true;
	TeleportOrSuicide(0);
	return Plugin_Handled;
}

public Action CmdFinale(int client, int args)
{
	if(g_iRoundStart == 0 || g_iPlayerSpawn == 0)
	{
		ReplyToCommand(client, "回合尚未开始.");
		return Plugin_Handled;
	}

	int iFinaleEntity;
	if((iFinaleEntity = FindEntityByClassname(MaxClients + 1, "trigger_finale")) == INVALID_ENT_REFERENCE)
	{
		ReplyToCommand(client, "当前章节不是结局地图.");
		return Plugin_Handled;
	}
	
	AcceptEntityInput(iFinaleEntity, "FinaleEscapeFinished");
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	GetCvars();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iEndSafezoneMethod = g_hEndSafezoneMethod.IntValue;
	g_iEndSafezoneTime = g_hEndSafezoneTime.IntValue;
	g_bRemoveAllInfected = g_hRemoveAllInfected.BoolValue;
}

public void OnMapStart()
{
	PrecacheSound(SOUND_COUNTDOWN);
}

public void OnMapEnd()
{
	delete g_hTimer;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bHasTriggered = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		HookChangelevelEntity();
	g_iPlayerSpawn = 1;
	
	g_bIsInEndSafezone[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		HookChangelevelEntity();
	g_iRoundStart = 1;
	
	delete g_hTimer;
}

void HookChangelevelEntity()
{
	g_iChangelevel = 0;

	int entity = MaxClients + 1;
	if((entity = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == INVALID_ENT_REFERENCE)
		entity = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if(entity != INVALID_ENT_REFERENCE)
	{
		SDKHook(entity, SDKHook_EndTouch, OnEndTouch);
		SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
		g_iChangelevel = EntIndexToEntRef(entity);
		GetChangelevelVector();
	}
}

void GetChangelevelVector()
{
	g_iLastSafeDoor = 0;

	float vMins[3], vMaxs[3], vOrigin[3];
	GetEntPropVector(g_iChangelevel, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(g_iChangelevel, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(g_iChangelevel, Prop_Send, "m_vecMaxs", vMaxs);
		
	g_vChangelevel[0] = vOrigin[0] + (vMins[0] + vMaxs[0]) * 0.5;
	g_vChangelevel[1] = vOrigin[1] + (vMins[1] + vMaxs[1]) * 0.5;
	g_vChangelevel[2] = vOrigin[2] + (vMins[2] + vMaxs[2]) * 0.5;

	AddVectors(vOrigin, vMins, g_vMins);
	AddVectors(vOrigin, vMaxs, g_vMaxs);

	vMins[0] -= 100.0;
	vMins[1] -= 100.0;
	vMins[2] -= 100.0;

	vMaxs[0] += 200.0;
	vMaxs[1] += 200.0;
	vMaxs[2] += 200.0;

	AddVectors(vOrigin, vMins, vMins);
	AddVectors(vOrigin, vMaxs, vMaxs);

	int entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "prop_door_rotating_checkpoint")) != INVALID_ENT_REFERENCE)
	{
		if(GetEntProp(entity, Prop_Data, "m_spawnflags") == 32768)
			continue;
	
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
		if(vMins[0] < vOrigin[0] < vMaxs[0] && vMins[1] < vOrigin[1] < vMaxs[1] && vMins[2] < vOrigin[2] < vMaxs[2])
			break;
	}
	g_iLastSafeDoor = EntIndexToEntRef(entity);
	g_vChangelevel[2] = vOrigin[2];

	entity = MaxClients + 1;
	while((entity = FindEntityByClassname(entity, "info_landmark")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vOrigin);
		if(vMins[0] < vOrigin[0] < vMaxs[0] && vMins[1] < vOrigin[1] < vMaxs[1] && vMins[2] < vOrigin[2] < vMaxs[2])
			break;
	}
	if(g_vChangelevel[2] > vOrigin[2])
		g_vChangelevel[2] = vOrigin[2];

	CNavArea area = NavMesh_GetNearestArea(g_vChangelevel);
	if(area != INVALID_NAV_AREA)
		area.GetRandomPoint(g_vChangelevel);
}

public Action OnEndTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients || GetGameTime() < 30.0)
		return;

	g_bIsInEndSafezone[other] = false;
}

public Action OnStartTouch(int entity, int other)
{
	if(other < 1 || other > MaxClients || GetGameTime() < 30.0)
		return;

	g_bIsInEndSafezone[other] = true;

	if(g_bHasTriggered || !IsClientInGame(other) || GetClientTeam(other) != 2 || !IsPlayerAlive(other))
		return;
		
	g_bHasTriggered = true;
	if(g_iEndSafezoneTime == 0)
		return;

	g_iCountdown = g_iEndSafezoneTime;
	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, Timer_NotifySurvivor, _, TIMER_REPEAT);
}

static const char g_sMethod[][] =
{
	"传送",
	"处死",
};

public Action Timer_NotifySurvivor(Handle timer)
{
	if(g_iCountdown > 0)
	{
		PrintHintTextToTeam2("%d 秒后%s所有未进入终点安全屋的玩家", g_iCountdown--, g_sMethod[g_iEndSafezoneMethod]);
		PlaySound(SOUND_COUNTDOWN);
	}
	else if(g_iCountdown <= 0)
	{
		TeleportOrSuicide(g_iEndSafezoneMethod);
		g_hTimer = null;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

void PrintHintTextToTeam2(const char[] format, any ...)
{
	char buffer[254];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintHintText(i, "%s", buffer);
		}
	}
}

void TeleportOrSuicide(int iSelect)
{
	switch(iSelect)
	{
		case 0:
		{
			SuicideInfectedAttacker();
			CloseAndLockLastSafeDoor();
			TeleportAllSurvivorsToCheckpoint();
		}
		
		case 1:
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsAliveSurvivor(i) && !g_bIsInEndSafezone[i])
					ForcePlayerSuicide(i);
			}
		}
	}
}

stock void SuicideInfectedAttacker()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!g_bIsInEndSafezone[i] && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && L4D2_HasSurvivorVictim(i))
		{
			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			ForcePlayerSuicide(i);
		}
	}
}

stock void CloseAndLockLastSafeDoor()
{
	if(!IsValidEntRef(g_iLastSafeDoor))
			return;

	SetEntProp(g_iLastSafeDoor, Prop_Data, "m_hasUnlockSequence", 0);
	AcceptEntityInput(g_iLastSafeDoor, "Unlock");
	AcceptEntityInput(g_iLastSafeDoor, "Close");
	AcceptEntityInput(g_iLastSafeDoor, "Lock");
	AcceptEntityInput(g_iLastSafeDoor, "forceclosed");
	SetEntProp(g_iLastSafeDoor, Prop_Data, "m_hasUnlockSequence", 1);
	SetVariantString("OnUser1 !self:Unlock::5.0:-1");
	AcceptEntityInput(g_iLastSafeDoor, "AddOutput");
	AcceptEntityInput(g_iLastSafeDoor, "FireUser1");
}

void TeleportAllSurvivorsToCheckpoint()
{
	if(g_bRemoveAllInfected)
		RemoveAllInfected();

	SuicideInfectedAttacker();

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsAliveSurvivor(i))
		{
			SetEntityMoveType(i, MOVETYPE_WALK);
			L4D2_ReviveFromIncap(i);
			TeleportEntity(i, g_vChangelevel, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

stock void RemoveAllInfected()
{
	int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(g_bIsInEndSafezone[i] && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Send, "m_fFlags", GetEntProp(i, Prop_Send, "m_fFlags") & ~FL_FROZEN);
			ForcePlayerSuicide(i);
		}
	}
	
	char sClassName[32];
	float vOrigin[3];
	int iMaxEnts = GetMaxEntities();
	for(i = MaxClients + 1; i <= iMaxEnts; i++)
	{
		if(!IsValidEntity(i))
			continue;

		GetEntityClassname(i, sClassName, sizeof(sClassName));
		if(strcmp(sClassName, "infected") == 0 || strcmp(sClassName, "witch") == 0)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", vOrigin);
			if(IsPointInEndSafezone(vOrigin))
				RemoveEntity(i);
		}
	}
}

stock bool L4D2_HasSurvivorVictim(int client)
{
	/* Charger */
	if(GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0)
		return true;

	/* Hunter */
	if(GetEntPropEnt(client, Prop_Send, "m_pounceVictim") > 0)
		return true;

	/* Smoker */
	if(GetEntPropEnt(client, Prop_Send, "m_tongueVictim") > 0)
		return true;

	/* Jockey */
	if(GetEntPropEnt(client, Prop_Send, "m_jockeyVictim") > 0)
		return true;

	return false;
}

stock bool IsAliveSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

stock void L4D2_ReviveFromIncap(int client) 
{
	if(IsHanging(client))
		L4D2_RunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));
}

//https://forums.alliedmods.net/showpost.php?p=2681159&postcount=10
stock bool IsHanging(int client)
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") > 0;
}

stock void L4D2_RunScript(const char[] sCode, any ...) 
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

//https://forums.alliedmods.net/showpost.php?p=2680639&postcount=3
stock bool IsPointInEndSafezone(const float vLoca[3])
{
	if(!IsValidEntRef(g_iChangelevel))
		return false;

	return g_vMins[0] < vLoca[0] < g_vMaxs[0] && g_vMins[1] < vLoca[1] < g_vMaxs[1] && g_vMins[2] < vLoca[2] < g_vMaxs[2];
}

stock bool IsValidEntRef(int entity)
{
	if(entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

stock void PlaySound(const char[] sSound)
{
	EmitSoundToTeam2(sSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

stock void EmitSoundToTeam2(const char[] sample,
				 int entity = SOUND_FROM_PLAYER,
				 int channel = SNDCHAN_AUTO,
				 int level = SNDLEVEL_NORMAL,
				 int flags = SND_NOFLAGS,
				 float volume = SNDVOL_NORMAL,
				 int pitch = SNDPITCH_NORMAL,
				 int speakerentity = -1,
				 const float origin[3] = NULL_VECTOR,
				 const float dir[3] = NULL_VECTOR,
				 bool updatePos = true,
				 float soundtime = 0.0)
{
	int[] clients = new int[MaxClients];
	int total;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
			clients[total++] = i;
	}

	if(total)
	{
		EmitSound(clients, total, sample, entity, channel,
			level, flags, volume, pitch, speakerentity,
			origin, dir, updatePos, soundtime);
	}
}
