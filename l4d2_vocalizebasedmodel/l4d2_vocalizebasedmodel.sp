//配合會在遊戲轉換角色模組的插件
//修正玩家使用插件譬如!csm選擇模組之後角色說不出話
//依照目前模組判定是一二代倖存者則給予相對應的角色語音

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

bool
	g_bLateLoad;

public Plugin myinfo = {
	name = "Voice based on model",
	author = "TBK Duy, Harry",
	description = "Survivors will vocalize based on their model",
	version = "1.1",
	url = "https://steamcommunity.com/profiles/76561198026784913/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (GetEngineVersion() != Engine_Left4Dead2) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

void BillVoice(int client) {
	SetVariantString("who:NamVet:0");
	DispatchKeyValue(client, "targetname", "NamVet");
	AcceptEntityInput(client, "AddContext");
}

void ZoeyVoice(int client) {
	SetVariantString("who:TeenGirl:0");
	DispatchKeyValue(client, "targetname", "TeenGirl");
	AcceptEntityInput(client, "AddContext");
}

void LouisVoice(int client) {
	SetVariantString("who:Manager:0");
	DispatchKeyValue(client, "targetname", "Manager");
	AcceptEntityInput(client, "AddContext");
}

void FrancisVoice(int client) {
	SetVariantString("who:Biker:0");
	DispatchKeyValue(client, "targetname", "Biker");
	AcceptEntityInput(client, "AddContext");
}

void NickVoice(int client) {
	SetVariantString("who:Gambler:0");
	DispatchKeyValue(client, "targetname", "Gambler");
	AcceptEntityInput(client, "AddContext");
}

void RochelleVoice(int client) {
	SetVariantString("who:Producer:0");
	DispatchKeyValue(client, "targetname", "Producer");
	AcceptEntityInput(client, "AddContext");
}

void CoachVoice(int client) {
	SetVariantString("who:Coach:0");
	DispatchKeyValue(client, "targetname", "Coach");
	AcceptEntityInput(client, "AddContext");
}

void EllisVoice(int client) {
	SetVariantString("who:Mechanic:0");
	DispatchKeyValue(client, "targetname", "Mechanic");
	AcceptEntityInput(client, "AddContext");
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}

void Hook_OnPostThinkPost(int client) {
	if (!IsPlayerAlive(client) || GetClientTeam(client) != 2) 
		return;

	VoiceModel(client);
}

void VoiceModel(int client) {
	static char model[31];
	GetClientModel(client, model, sizeof model);
	switch(model[29]) {
		case 'c'://coach
			CoachVoice(client);

		case 'b'://nick
			NickVoice(client);

		case 'd'://rochelle
			RochelleVoice(client);

		case 'h'://ellis
			EllisVoice(client);

		case 'v'://bill
			BillVoice(client);

		case 'n'://zoey
			ZoeyVoice(client);

		case 'e'://francis
			FrancisVoice(client);

		case 'a'://louis
			LouisVoice(client);
	}
}
