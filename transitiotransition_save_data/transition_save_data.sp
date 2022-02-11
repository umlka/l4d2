#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define GAMEDATA	"transition_save_data"

DynamicHook
	g_dHooksBeginChangeLevel;

ArrayList
	g_aSavedPlayers;

int
	g_iOffAmmo,
	g_iOffMelee,
	g_iOffHangingPreTemp,
	g_iOffHangingPreReal,
	g_iOffHangingCurrent,
	g_iOffPrimaryAmmoType;

bool
	g_bLateLoad,
	g_bTransitionStart;

char
	g_sTargetMap[64];

enum struct esData
{
	int iRecorded;
	int iCharacter;
	int iHealth;
	int iTempHealth;
	int iBufferTime;
	int iReviveCount;
	int iThirdStrike;
	int iGoingToDie;
	
	char sModel[128];

	int iClip0;
	int iAmmo;
	int iUpgrade;
	int iUpgradeAmmo;
	int iWeaponSkin0;
	int iClip1;
	int iWeaponSkin1;
	bool bDualWielding;

	char sSlot0[32];
	char sSlot1[32];
	char sSlot2[32];
	char sSlot3[32];
	char sSlot4[32];
	char sActive[32];

	// Save Weapon 4.3 (forked)(https://forums.alliedmods.net/showthread.php?p=2398822#post2398822)
	// Mutant_Tanks (https://github.com/Psykotikism/Mutant_Tanks)
	void Clean()
	{
		if(!this.iRecorded)
			return;
	
		this.iRecorded = 0;
		this.iCharacter = -1;
		this.iReviveCount = 0;
		this.iThirdStrike = 0;
		this.iGoingToDie = 0;
		this.iHealth = 0;
		this.iTempHealth = 0;
		this.iBufferTime = 0;
	
		this.sModel[0] = '\0';

		this.iClip0 = 0;
		this.iAmmo = 0;
		this.iUpgrade = 0;
		this.iUpgradeAmmo = 0;
		this.iWeaponSkin0 = 0;
		this.iClip1 = -1;
		this.iWeaponSkin1 = 0;
		this.bDualWielding = false;
	
		this.sSlot0[0] = '\0';
		this.sSlot1[0] = '\0';
		this.sSlot2[0] = '\0';
		this.sSlot3[0] = '\0';
		this.sSlot4[0] = '\0';
		this.sActive[0] = '\0';
	}

	void Save(int client, bool bIdentity = true)
	{
		this.Clean();

		if(GetClientTeam(client) != 2)
			return;
	
		this.iRecorded = 1;

		if(bIdentity)
		{
			this.iCharacter = GetEntProp(client, Prop_Send, "m_survivorCharacter");
			GetClientModel(client, this.sModel, sizeof esData::sModel);
		}

		if(!IsPlayerAlive(client))
		{
			static ConVar hZSurvivorRespa;
			if(hZSurvivorRespa == null)
				hZSurvivorRespa = FindConVar("z_survivor_respawn_health");

			this.iHealth = hZSurvivorRespa.IntValue;
			return;
		}

		if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		{
			if(!GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
			{
				static ConVar hSurvivorReviveH;
				if(hSurvivorReviveH == null)
					hSurvivorReviveH = FindConVar("survivor_revive_health");

				static ConVar hSurvivorMaxInc;
				if(hSurvivorMaxInc == null)
					hSurvivorMaxInc = FindConVar("survivor_max_incapacitated_count");

				this.iHealth = 1;
				this.iTempHealth = hSurvivorReviveH.IntValue;
				this.iBufferTime = 0;
				this.iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount") + 1;
				this.iThirdStrike = this.iReviveCount >= hSurvivorMaxInc.IntValue ? 1 : 0;
				this.iGoingToDie = 1;
			}
			else
			{
				static ConVar hSurvivorIncapH;
				if(hSurvivorIncapH == null)
					hSurvivorIncapH = FindConVar("survivor_incap_health");

				int iPreTemp = GetEntData(client, g_iOffHangingPreTemp);									// 玩家挂边前的虚血
				int iPreReal = GetEntData(client, g_iOffHangingPreReal);									// 玩家挂边前的实血
				int iPreTotal = iPreTemp + iPreReal;														// 玩家挂边前的总血量
				int iHangingCurrent = GetEntData(client, g_iOffHangingCurrent);							// 玩家挂边时的总血量
				int iRevivedTotal = RoundToFloor(iHangingCurrent / hSurvivorIncapH.FloatValue * iPreTotal);	// 玩家挂边起身后的总血量

				int iDelta = iPreTotal - iRevivedTotal;
				if(iPreTemp > iDelta)
				{
					this.iHealth = iPreReal;
					this.iTempHealth = iPreTemp - iDelta;
				}
				else
				{
					this.iHealth = iPreReal - (iDelta - iPreTemp);
					this.iTempHealth = 0;
				}

				this.iBufferTime = 0;
				this.iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
				this.iThirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
				this.iGoingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
			}
		}
		else
		{
			this.iHealth = GetEntProp(client, Prop_Data, "m_iHealth");
			this.iTempHealth = RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
			this.iBufferTime = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));
			this.iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
			this.iThirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
			this.iGoingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
		}

		char sWeapon[32];
		int iSlot = GetPlayerWeaponSlot(client, 0);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot0, sizeof esData::sSlot0, sWeapon);

			this.iClip0 = GetEntProp(iSlot, Prop_Send, "m_iClip1");
			this.iAmmo = aGetOrSetPlayerAmmo(client, iSlot);
			this.iUpgrade = GetEntProp(iSlot, Prop_Send, "m_upgradeBitVec");
			this.iUpgradeAmmo = GetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
			this.iWeaponSkin0 = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		}

		if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		{
			int iMelee = GetEntDataEnt2(client, g_iOffMelee);
			switch(iMelee > MaxClients && IsValidEntity(iMelee))
			{
				case true:
					iSlot = iMelee;

				case false:
					iSlot = GetPlayerWeaponSlot(client, 1);
			}
		}
		else
			iSlot = GetPlayerWeaponSlot(client, 1);

		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			if(strcmp(sWeapon[7], "melee") == 0)
				GetEntPropString(iSlot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof sWeapon);
			else
			{
				if(strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
					this.iClip1 = GetEntProp(iSlot, Prop_Send, "m_iClip1");

				this.bDualWielding = strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(iSlot, Prop_Send, "m_isDualWielding");
			}

			strcopy(this.sSlot1, sizeof esData::sSlot1, sWeapon);
			this.iWeaponSkin1 = GetEntProp(iSlot, Prop_Send, "m_nSkin");
		}

		iSlot = GetPlayerWeaponSlot(client, 2);
		if(iSlot > MaxClients && (iSlot != GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") || GetEntPropFloat(iSlot, Prop_Data, "m_flNextPrimaryAttack") < GetGameTime()))
		{	//Method from HarryPotter (https://forums.alliedmods.net/showpost.php?p=2768411&postcount=5)
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot2, sizeof esData::sSlot2, sWeapon);
		}

		iSlot = GetPlayerWeaponSlot(client, 3);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot3, sizeof esData::sSlot3, sWeapon);
		}

		iSlot = GetPlayerWeaponSlot(client, 4);
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sSlot4, sizeof esData::sSlot4, sWeapon);
		}
	
		iSlot = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(iSlot > MaxClients)
		{
			GetEntityClassname(iSlot, sWeapon, sizeof sWeapon);
			strcopy(this.sActive, sizeof esData::sActive, sWeapon);
		}
	}

	void Restore(int client, bool bIdentity = true)
	{
		if(!this.iRecorded)
			return;

		if(GetClientTeam(client) != 2)
			return;

		if(bIdentity)
		{
			if(this.iCharacter != -1)
				SetEntProp(client, Prop_Send, "m_survivorCharacter", this.iCharacter);

			if(this.sModel[0] != '\0')
				SetEntityModel(client, this.sModel);
		}

		if(!IsPlayerAlive(client)) 
			return;

		if(GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			L4D_ReviveSurvivor(client); //SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

		SetEntProp(client, Prop_Send, "m_iHealth", this.iHealth);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * this.iTempHealth);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * this.iBufferTime);
		SetEntProp(client, Prop_Send, "m_currentReviveCount", this.iReviveCount);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", this.iThirdStrike);
		SetEntProp(client, Prop_Send, "m_isGoingToDie", this.iGoingToDie);

		if(!GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike"))
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");

		int iSlot;
		int iWeapon;
		for(; iSlot < 5; iSlot++)
		{
			if((iWeapon = GetPlayerWeaponSlot(client, iSlot)) > MaxClients)
			{
				RemovePlayerItem(client, iWeapon);
				RemoveEdict(iWeapon);
			}
		}

		bool bGiven;
		if(this.sSlot0[0] != '\0')
		{
			GivePlayerItem(client, this.sSlot0);

			iSlot = GetPlayerWeaponSlot(client, 0);
			if(iSlot > MaxClients)
			{
				SetEntProp(iSlot, Prop_Send, "m_iClip1", this.iClip0);
				aGetOrSetPlayerAmmo(client, iSlot, this.iAmmo);

				if(this.iUpgrade > 0)
					SetEntProp(iSlot, Prop_Send, "m_upgradeBitVec", this.iUpgrade);

				if(this.iUpgradeAmmo > 0)
					SetEntProp(iSlot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", this.iUpgradeAmmo);
				
				if(this.iWeaponSkin0 > 0)
					SetEntProp(iSlot, Prop_Send, "m_nSkin", this.iWeaponSkin0);
				
				bGiven = true;
			}
		}

		if(this.sSlot1[0] != '\0')
		{
			switch(this.bDualWielding)
			{
				case true:
				{
					GivePlayerItem(client, "weapon_pistol");
					GivePlayerItem(client, "weapon_pistol");
				}

				case false:
					GivePlayerItem(client, this.sSlot1);
			}

			iSlot = GetPlayerWeaponSlot(client, 1);
			if(iSlot > MaxClients)
			{
				if(this.iClip1 != -1)
					SetEntProp(iSlot, Prop_Send, "m_iClip1", this.iClip1);
				
				if(this.iWeaponSkin1 > 0)
					SetEntProp(iSlot, Prop_Send, "m_nSkin", this.iWeaponSkin1);
				
				bGiven = true;
			}
		}

		if(this.sSlot2[0] != '\0')
		{
			GivePlayerItem(client, this.sSlot2);

			if(GetPlayerWeaponSlot(client, 2) > MaxClients)
				bGiven = true;
		}

		if(this.sSlot3[0] != '\0')
		{
			GivePlayerItem(client, this.sSlot3);
	
			if(GetPlayerWeaponSlot(client, 3) > MaxClients)
				bGiven = true;
		}

		if(this.sSlot4[0] != '\0')
		{
			GivePlayerItem(client, this.sSlot4);
	
			if(GetPlayerWeaponSlot(client, 4) > MaxClients)
				bGiven = true;
		}
		
		if(bGiven)
		{
			if(this.sActive[0] != '\0')
				FakeClientCommand(client, "use %s", this.sActive);
		}
		else
			GivePlayerItem(client, "weapon_pistol");
	}
}

esData
	g_esData[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Player Transition Save Data",
	author = "sorallll",
	description = "Fixed 4+ players' equipment chaotic bug after the transition",
	version = "1.0.7",
	url = "https://forums.alliedmods.net/showthread.php?t=336287"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vLoadGameData();

	g_aSavedPlayers = new ArrayList();

	g_iOffAmmo = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	g_iOffPrimaryAmmoType = FindSendPropInfo("CBaseCombatWeapon", "m_iPrimaryAmmoType");

	if(g_bLateLoad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

public void OnMapStart()
{
	char sMap[64];
	GetCurrentMap(sMap, sizeof sMap);
	if(strcmp(sMap, g_sTargetMap, false) != 0)
	{
		g_aSavedPlayers.Clear();
		for(int i = 1; i <= MaxClients; i++)
			g_esData[i].Clean();
	}

	g_sTargetMap[0] = '\0';
}

public void OnMapEnd()
{
	g_bTransitionStart = false;
}

public void OnClientPutInServer(int client)
{
	if(!IsFakeClient(client))
		g_dHooksBeginChangeLevel.HookEntity(Hook_Post, client, mreOnBeginChangeLevelPost);
}

// Thanks Silvers for a better way to get or set ammo
any aGetOrSetPlayerAmmo(int client, int iWeapon, int iAmmo = -1)
{
	int iOffset = GetEntData(iWeapon, g_iOffPrimaryAmmoType) * 4; // Thanks to "Root" or whoever for this method of not hard-coding offsets: https://github.com/zadroot/AmmoManager/blob/master/scripting/ammo_manager.sp
	if(iOffset)
	{
		if(iAmmo != -1)
			SetEntData(client, g_iOffAmmo + iOffset, iAmmo);
		else
			return GetEntData(client, g_iOffAmmo + iOffset);
	}

	return 0;
}

void vLoadGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iOffMelee = hGameData.GetOffset("CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenMeleeWeapon");
	if(g_iOffMelee == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnIncapacitatedAsSurvivor::HiddenMeleeWeapon");

	g_iOffHangingPreTemp = hGameData.GetOffset("CTerrorPlayer::OnRevived::HangingPreTempHealth");
	if(g_iOffHangingPreTemp == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnRevived::HangingPreTempHealth");

	g_iOffHangingPreReal = hGameData.GetOffset("CTerrorPlayer::OnRevived::HangingPreRealHealth");
	if(g_iOffHangingPreReal == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnRevived::HangingPreRealHealth");

	g_iOffHangingCurrent = hGameData.GetOffset("CTerrorPlayer::OnRevived::HangingCurrentHealth");
	if(g_iOffHangingCurrent == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::OnRevived::HangingCurrentHealth");

	vSetupDynamicHooks(hGameData);
	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDynamicHooks(GameData hGameData = null)
{
	g_dHooksBeginChangeLevel = DynamicHook.FromConf(hGameData, "Hooks_CTerrorPlayer::OnBeginChangeLevel");
	if(g_dHooksBeginChangeLevel == null)
		SetFailState("Failed to create DynamicHook: Hooks_CTerrorPlayer::OnBeginChangeLevel");
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "Detour_CTerrorPlayer::TransitionRestore");
	if(dDetour == null)
		SetFailState("Failed to create DynamicDetour: Detour_CTerrorPlayer::TransitionRestore");
		
	if(!dDetour.Enable(Hook_Post, mreTransitionRestorePost))
		SetFailState("Failed to detour post: Detour_CTerrorPlayer::TransitionRestore");
}

MRESReturn mreOnBeginChangeLevelPost(int pThis, DHookParam hParams)
{
	if(!g_bTransitionStart)
	{
		g_aSavedPlayers.Clear();
		g_bTransitionStart = true;
		for(int i = 1; i <= MaxClients; i++)
			g_esData[i].Clean();

		hParams.GetString(1, g_sTargetMap, sizeof g_sTargetMap);
	}

	if(GetClientTeam(pThis) != 2)
		return MRES_Ignored;

	g_esData[pThis].Save(pThis, true);
	g_aSavedPlayers.Push(GetClientUserId(pThis));
	return MRES_Ignored;
}

MRESReturn mreTransitionRestorePost(int pThis)
{
	if(IsFakeClient(pThis) || GetClientTeam(pThis) != 2)
		return MRES_Ignored;

	if(g_aSavedPlayers.FindValue(GetClientUserId(pThis)) != -1)
		g_esData[pThis].Restore(pThis, true);

	return MRES_Ignored;
}
