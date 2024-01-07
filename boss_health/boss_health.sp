#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_NAME				"Boss Health"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

/*****************************************************************************************************/
// ====================================================================================================
// colors.inc
// ====================================================================================================
#define SERVER_INDEX	0
#define NO_INDEX	   -1
#define NO_PLAYER	   -2
#define BLUE_INDEX		2
#define RED_INDEX		3
#define MAX_COLORS		6
#define MAX_MESSAGE_LENGTH 254
static const char CTag[][] = {"{default}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}"};
static const char CTagCode[][] = {"\x01", "\x04", "\x03", "\x03", "\x03", "\x05"};
static const bool CTagReqSayText2[] = {false, false, true, true, true, false};
static const int CProfile_TeamIndex[] = {NO_INDEX, NO_INDEX, SERVER_INDEX, RED_INDEX, BLUE_INDEX, NO_INDEX};

/**
 * @note Prints a message to a specific client in the chat area.
 * @note Supports color tags.
 *
 * @param client		Client index.
 * @param szMessage		Message (formatting rules).
 * @return				No return
 * 
 * On error/Errors:	If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] szMessage, any ...) {
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];

	SetGlobalTransTarget(client);
	FormatEx(szBuffer, sizeof szBuffer, "\x01%s", szMessage);
	VFormat(szCMessage, sizeof szCMessage, szBuffer, 3);
	
	int index = CFormat(szCMessage, sizeof szCMessage);
	if (index == NO_INDEX)
		PrintToChat(client, "%s", szCMessage);
	else
		CSayText2(client, index, szCMessage);
}

/**
 * @note Prints a message to all clients in the chat area.
 * @note Supports color tags.
 *
 * @param client		Client index.
 * @param szMessage		Message (formatting rules)
 * @return				No return
 */
stock void CPrintToChatAll(const char[] szMessage, any ...) {
	char szBuffer[MAX_MESSAGE_LENGTH];

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof szBuffer, szMessage, 2);
			CPrintToChat(i, "%s", szBuffer);
		}
	}
}

/**
 * @note Replaces color tags in a string with color codes
 *
 * @param szMessage		String.
 * @param maxlength		Maximum length of the string buffer.
 * @return				Client index that can be used for SayText2 author index
 * 
 * On error/Errors:	If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] szMessage, int maxlength) {	
	int iRandomPlayer = NO_INDEX;

	for (int i; i < MAX_COLORS; i++) {													//	Para otras etiquetas de color se requiere un bucle.
		if (StrContains(szMessage, CTag[i], false) == -1)								//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if (!CTagReqSayText2[i])
			ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);			//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else {																			//	La etiqueta necesita Saytext2.	
			if (iRandomPlayer == NO_INDEX) {											//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]);			//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if (iRandomPlayer == NO_PLAYER)
					ReplaceString(szMessage, maxlength, CTag[i], CTagCode[5], false);	//	Si no se encuentra un cliente valido, reemplasa la etiqueta con una etiqueta de color verde.
				else 
					ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);	// 	Si el cliente fue encontrado simplemente reemplasa.
			}
			else																		//	Si en caso de usar dos colores de equipo infectado y equipo de superviviente juntos se mandará un mensaje de error.
				ThrowError("Using two team colors in one message is not allowed");		//	Si se ha usadó una combinación de colores no validad se registrara en la carpeta logs.
		}
	}

	return iRandomPlayer;
}

/**
 * @note Founds a random player with specified team
 *
 * @param color_team	Client team.
 * @return				Client index or NO_PLAYER if no player found
 */
stock int CFindRandomPlayerByTeam(int color_team) {
	if (color_team == SERVER_INDEX)
		return 0;
	else {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && GetClientTeam(i) == color_team)
				return i;
		}
	}

	return NO_PLAYER;
}

/**
 * @note Sends a SayText2 usermessage to a client
 *
 * @param szMessage		Client index
 * @param maxlength		Author index
 * @param szMessage		Message
 * @return				No return.
 */
stock void CSayText2(int client, int author, const char[] szMessage) {
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	bf.WriteByte(author);
	bf.WriteByte(true);
	bf.WriteString(szMessage);
	EndMessage();
}
/*****************************************************************************************************/

ConVar
	g_cvTankHpMin,
	g_cvTankHpMax,
	g_cvWitchHpMin,
	g_cvWitchHpMax,
	g_cvAggressive;

int
	g_iTankHpMin,
	g_iTankHpMax,
	g_iWitchHpMin,
	g_iWitchHpMax;

bool
	g_bAggressive,
	g_bTankHpSet[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_cvTankHpMin =		CreateConVar("boss_health_tank_min",	"1000",	"tank最低血量", _, true, 1.0);
	g_cvTankHpMax =		CreateConVar("boss_health_tank_max",	"2000",	"tank最高血量", _, true, 1.0);
	g_cvWitchHpMin =	CreateConVar("boss_health_witch_min",	"1000",	"witch最低血量", _, true, 1.0);
	g_cvWitchHpMax =	CreateConVar("boss_health_witch_max",	"2000",	"witch最高血量", _, true, 1.0);
	g_cvAggressive =	CreateConVar("boss_aggressive_tanks",	"0", 	"AI Tank出生后立即开始攻击而不是原地待命?");

	g_cvTankHpMin.AddChangeHook(CvarChanged);
	g_cvTankHpMax.AddChangeHook(CvarChanged);
	g_cvWitchHpMin.AddChangeHook(CvarChanged);
	g_cvWitchHpMax.AddChangeHook(CvarChanged);
	g_cvAggressive.AddChangeHook(CvarChanged);

	HookEvent("witch_spawn",		Event_WitchSpawn,		EventHookMode_Pre);
	HookEvent("player_spawn",		Event_PlayerSpawn,		EventHookMode_Pre);
	HookEvent("player_bot_replace",	Event_PlayerBotReplace,	EventHookMode_Pre);
	HookEvent("bot_player_replace",	Event_BotPlayerReplace,	EventHookMode_Pre);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_iTankHpMin =	g_cvTankHpMin.IntValue;
	g_iTankHpMax =	g_cvTankHpMax.IntValue;
	g_iWitchHpMin =	g_cvWitchHpMin.IntValue;
	g_iWitchHpMax =	g_cvWitchHpMax.IntValue;
	g_bAggressive =	g_cvAggressive.BoolValue;
}

public void OnMapStart() {
	PrecacheSound("ui/pickup_secret01.wav");
}

void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast) {
	int health = g_iWitchHpMin >= g_iWitchHpMax ? g_iWitchHpMin : GetRandomInt(g_iWitchHpMin, g_iWitchHpMax);

	int witchid = event.GetInt("witchid");
	SetEntProp(witchid, Prop_Data, "m_iHealth", health);
	SetEntProp(witchid, Prop_Data, "m_iMaxHealth", health);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsClientInKickQueue(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Data, "m_iHealth") <= 1)
		return;

	g_bTankHpSet[client] = false;
	CreateTimer(0.2, tmrTankSpawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || !g_bTankHpSet[player])
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot))
		return;

	g_bTankHpSet[bot] = true;
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast) {
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot) || !g_bTankHpSet[bot])
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player))
		return;

	g_bTankHpSet[player] = true;
}

Action tmrTankSpawn(Handle timer, int client) {
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || g_bTankHpSet[client] || IsClientInKickQueue(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Stop;

	g_bTankHpSet[client] = true;

	if (g_bAggressive && IsFakeClient(client)) {
		int survivor = GetRandomSur();
		if (survivor) {
			int damageToTank = GetEntProp(survivor, Prop_Send, "m_checkpointDamageToTank");
			DamagePlayer(client, survivor, 1.0); //https://forums.alliedmods.net/showthread.php?t=302140
			SetEntProp(survivor, Prop_Send, "m_checkpointDamageToTank", damageToTank); //恢复过关屏幕上面的坦克伤害统计
		}
	}

	int health = GetSurCount() * (g_iTankHpMin >= g_iTankHpMax ? g_iTankHpMin : GetRandomInt(g_iTankHpMin, g_iTankHpMax));
	SetEntProp(client, Prop_Data, "m_iHealth", health);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", health);

	EmitSoundToAll("ui/pickup_secret01.wav", SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	CPrintToChatAll("{red}[{olive}%N{red}] {red}%d {default}HP", client, health);

	return Plugin_Continue;
}

int GetRandomSur() {
	int count;
	int[] clients = new int[MaxClients];
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			clients[count++] = i;
	}
	return clients[GetRandomInt(0, count - 1)];
}

void DamagePlayer(int victim, int attacker, float damage, const char[] damagetype = "0") {
	int ent = CreateEntityByName("point_hurt");
	if (ent > MaxClients && IsValidEntity(ent)) {
		char targetName[32];
		FormatEx(targetName, sizeof targetName, "boss_target_%i", GetClientUserId(victim));
		DispatchKeyValue(victim, "targetname", targetName);
		DispatchKeyValueFloat(ent, "Damage", damage);
		DispatchKeyValue(ent, "DamageTarget", targetName);
		DispatchKeyValue(ent, "DamageType", damagetype);

		DispatchSpawn(ent);
		AcceptEntityInput(ent, "Hurt", attacker);
		RemoveEdict(ent);
	}
}

int GetSurCount() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			count++;
	}
	return count;
}