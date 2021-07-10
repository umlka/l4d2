#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public Plugin myinfo = 
{
	name = "L4D HOTs",
	author = "ProdigySim, CircleSquared",
	description = "Pills and Adrenaline heal over time",
	version = "0.3",
	url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
}

ConVar g_hPillCvar;
ConVar g_hAdrenCvar;
ConVar g_hPillHot;
ConVar g_hPillInterval;
ConVar g_hPillIncrement;
ConVar g_hPillTotal;
ConVar g_hAdrenHot;
ConVar g_hAdrenInterval;
ConVar g_hAdrenIncrement;
ConVar g_hAdrenTotal;

float g_fPillInterval;
float g_fAdrenInterval;

int g_iOldPillValue;
int g_iOldAdrenValue;
int g_iPillIncrement;
int g_iPillTotal;
int g_iAdrenIncrement;
int g_iAdrenTotal;

public void OnPluginStart()
{
	g_hPillCvar = FindConVar("pain_pills_health_value");
	g_hPillHot = CreateConVar("l4d_pills_hot", "0", "Pills heal over time");
	g_hPillInterval = CreateConVar("l4d_pills_hot_interval", "1.0", "Interval for pills hot");
	g_hPillIncrement = CreateConVar("l4d_pills_hot_increment", "10", "Increment iAmount for pills hot");
	g_hPillTotal = CreateConVar("l4d_pills_hot_total", "50", "Total iAmount for pills hot");
	if(g_hPillHot.BoolValue)
		EnablePillHot();

	g_hPillInterval.AddChangeHook(ConVarChanged);
	g_hPillIncrement.AddChangeHook(ConVarChanged);
	g_hPillTotal.AddChangeHook(ConVarChanged);
	g_hPillHot.AddChangeHook(PillHotChanged);

	g_hAdrenCvar = FindConVar("adrenaline_health_buffer");
	g_hAdrenHot = CreateConVar("l4d_adrenaline_hot", "0", "Adrenaline heals over time");
	g_hAdrenInterval = CreateConVar("l4d_adrenaline_hot_interval", "1.0", "Interval for adrenaline hot");
	g_hAdrenIncrement = CreateConVar("l4d_adrenaline_hot_increment", "15", "Increment iAmount for adrenaline hot");
	g_hAdrenTotal = CreateConVar("l4d_adrenaline_hot_total", "25", "Total iAmount for adrenaline hot");
	if(g_hAdrenHot.BoolValue)
		EnableAdrenHot();

	g_hAdrenInterval.AddChangeHook(ConVarChanged);
	g_hAdrenIncrement.AddChangeHook(ConVarChanged);
	g_hAdrenTotal.AddChangeHook(ConVarChanged);
	g_hAdrenHot.AddChangeHook(AdrenHotChanged);
}

public void OnPluginEnd()
{
	DisablePillHot(false);
	DisableAdrenHot(false);
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
	g_fPillInterval = g_hPillInterval.FloatValue;
	g_iPillIncrement = g_hPillIncrement.IntValue;
	g_iPillTotal = g_hPillTotal.IntValue;
	g_fAdrenInterval = g_hAdrenInterval.FloatValue;
	g_iAdrenIncrement = g_hAdrenIncrement.IntValue;
	g_iAdrenTotal = g_hAdrenTotal.IntValue;
}

public void PillHotChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bool bNewVal = StringToInt(newValue) != 0;
	if(bNewVal && StringToInt(oldValue) == 0)
		EnablePillHot();
	else if(!bNewVal && StringToInt(oldValue) != 0)
		DisablePillHot(true);
}

public void AdrenHotChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bool bNewVal = StringToInt(newValue) != 0;
	if(bNewVal && StringToInt(oldValue) == 0)
		EnableAdrenHot();
	else if(!bNewVal && StringToInt(oldValue) != 0)
		DisableAdrenHot(true);
}

void EnablePillHot()
{
	g_iOldPillValue = g_hPillCvar.IntValue;
	g_hPillCvar.SetInt(0);
	HookEvent("pills_used", PillsUsed_Event);
}

void DisablePillHot(bool bUnHook)
{
	if(bUnHook) 
		UnhookEvent("pills_used", PillsUsed_Event);

	g_hPillCvar.SetInt(g_iOldPillValue);
}

void EnableAdrenHot()
{
	g_iOldAdrenValue = g_hAdrenCvar.IntValue;
	g_hAdrenCvar.SetInt(0);
	HookEvent("adrenaline_used", AdrenalineUsed_Event);
}

void DisableAdrenHot(bool bUnHook)
{
	if(bUnHook) 
		UnhookEvent("adrenaline_used", AdrenalineUsed_Event);

	g_hAdrenCvar.SetInt(g_iOldAdrenValue);
}


public Action PillsUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	HealEntityOverTime(GetClientOfUserId(event.GetInt("userid")), g_fPillInterval, g_iPillIncrement, g_iPillTotal);
}

public Action AdrenalineUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
	HealEntityOverTime(GetClientOfUserId(event.GetInt("userid")), g_fAdrenInterval, g_iAdrenIncrement, g_iAdrenTotal);
}

void HealEntityOverTime(int client, float fInterval, int iIncrement, int iTotal)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

	int iMaxHP = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	if(iIncrement >= iTotal)
		HealTowardsMax(client, iTotal, iMaxHP);
	else
	{
		HealTowardsMax(client, iIncrement, iMaxHP);
		DataPack datapack = new DataPack();
		CreateDataTimer(fInterval, __HOT_ACTION, datapack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		datapack.WriteCell(GetClientUserId(client));
		datapack.WriteCell(iIncrement);
		datapack.WriteCell(iTotal-iIncrement);
		datapack.WriteCell(iMaxHP);
	}
}

public Action __HOT_ACTION(Handle timer, DataPack datapack)
{
	datapack.Reset();

	int client = datapack.ReadCell();
	int iIncrement = datapack.ReadCell();
	DataPackPos fPos = datapack.Position;
	int iRemaining = datapack.ReadCell();
	int iMaxHP = datapack.ReadCell();

	if((client = GetClientOfUserId(client)) == 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	if(iIncrement >= iRemaining)
	{
		HealTowardsMax(client, iRemaining, iMaxHP);
		return Plugin_Stop;
	}

	HealTowardsMax(client, iIncrement, iMaxHP);
	datapack.Position = fPos;
	datapack.WriteCell(iRemaining - iIncrement);

	return Plugin_Continue;
}

void HealTowardsMax(int client, int iAmount, int iMax)
{
	float iHB = float(iAmount) + GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float fOverflow = (iHB + GetClientHealth(client)) - iMax;
	if(fOverflow > 0.0)
		iHB -= fOverflow;

	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", iHB);
}
