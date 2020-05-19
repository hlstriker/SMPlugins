#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_variant_t>
#include <emitsoundany>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_settings"
#include "Includes/ultjb_cell_doors"
#include "Includes/ultjb_days"
#include "../../Libraries/ParticleManager/particle_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Jihad";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The jihad plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define PERCENT_CHANCE_TO_GIVE_JIHAD	10
#define EXPLODE_RADIUS		750.0
#define EXPLODE_MAX_DAMAGE	235.0
new bool:g_bHooked[MAXPLAYERS+1];
new bool:g_bIsJihad[MAXPLAYERS+1];
new bool:g_bIsBombActivated[MAXPLAYERS+1];
new Handle:g_hTimer_Bomb[MAXPLAYERS+1];
new g_iJihadBombWeaponEntRef[MAXPLAYERS+1];
new g_iJihadBombEntRef[MAXPLAYERS+1];

new const String:MODEL_KNIFE_T_WORLD[] = "models/weapons/w_knife.mdl";
new g_iModelIndex_Knife;

new const String:SZ_SOUND_ACTIVATE[] = "sound/survival/breach_activate_01.wav";
new const String:SZ_SOUND_AKBAR[] = "sound/swoobles/ultimate_jailbreak/akbar.mp3";
new const String:SZ_SOUND_EXPLODE[] = "sound/weapons/c4/c4_explode1.wav";

new const String:PARTICLE_FILE_PATH[] = "particles/explosions_fx.pcf";
new const String:PEFFECT_EXPLODE[] = "explosion_coop_mission_c4";

new Handle:cvar_bomb_timer;


public OnPluginStart()
{
	CreateConVar("ultjb_jihad_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_bomb_timer = CreateConVar("ultjb_jihad_bomb_timer", "3.4", "The number of seconds before the bomb explodes.", _, true, 0.0);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
	
	AddCommandListener(OnWeaponDrop, "drop");
}

public OnMapStart()
{
	g_iModelIndex_Knife = PrecacheModel(MODEL_KNIFE_T_WORLD, true);
	PrecacheSound(SZ_SOUND_ACTIVATE[6]);
	PrecacheSound(SZ_SOUND_EXPLODE[6]);
	
	AddFileToDownloadsTable(SZ_SOUND_AKBAR);
	PrecacheSoundAny(SZ_SOUND_AKBAR[6]);
	
	PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_EXPLODE);
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(!UltJB_CellDoors_DoExist())
		return;
	
	if(GetRandomInt(1, 100) > PERCENT_CHANCE_TO_GIVE_JIHAD)
		return;
	
	SetRandomClientAsJihad();
	ClearJihadCT();
}

public Action:Event_RoundEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for (new iClient=1; iClient <= MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
			
		ClearJihad(iClient);
		
	}
}

public UltJB_Day_OnStart(iClient, DayType:iDayType, bool:bIsFreeForAll)
{
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		ClearJihad(iPlayer);
	}
}

bool:SetRandomClientAsJihad()
{
	new Handle:hClients = CreateArray();
	
	decl iClient;
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS)
			continue;
		
		if(IsJihad(iClient))
			continue;
		
		PushArrayCell(hClients, iClient);
	}
	
	new iArraySize = GetArraySize(hClients);
	if(!iArraySize)
	{
		CloseHandle(hClients);
		return false;
	}
	
	iClient = GetArrayCell(hClients, GetRandomInt(0, iArraySize-1));
	CloseHandle(hClients);
	
	SetJihad(iClient);
	
	return true;
}

public UltJB_Settings_OnSpawnPost(iClient)
{
	RestoreJihadBombWeaponIfNeeded(iClient);
}

SetJihad(iClient)
{
	if(IsJihad(iClient))
		return;
	
	g_bIsJihad[iClient] = true;
	g_bIsBombActivated[iClient] = false;
	TryClientHooks(iClient);
	CreateJihadBombWeapon(iClient);
}

ClearJihad(iClient)
{
	if(!IsJihad(iClient))
		return;
	
	g_bIsJihad[iClient] = false;
	RemoveJihadBombWeapon(iClient);
	TryClientUnhooks(iClient);
	StopTimer_Bomb(iClient);
}

ClearJihadCT()
{
	for (new iClient=1; iClient <= MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) == CS_TEAM_CT)
		{
		ClearJihad(iClient);
		}
		
	}
}

bool:IsJihad(iClient)
{
	return g_bIsJihad[iClient];
}

RestoreJihadBombWeaponIfNeeded(iClient)
{
	if(!IsJihad(iClient))
		return -1;
	
	if(g_bIsBombActivated[iClient])
	{
		ClearJihad(iClient);
		return -1;
	}
	
	RemoveJihadBombWeapon(iClient);
	new iBombWeapon = CreateJihadBombWeapon(iClient);
	
	return iBombWeapon;
}

CreateJihadBombWeapon(iClient)
{
	new iBombWeapon = EntRefToEntIndex(g_iJihadBombWeaponEntRef[iClient]);
	if(iBombWeapon > 0 && !(GetEntityFlags(iBombWeapon) & FL_KILLME))
		return iBombWeapon;
	
	iBombWeapon = GivePlayerItemCustom(iClient, "weapon_breachcharge");
	if(iBombWeapon < 1)
		return -1;
	
	g_iJihadBombWeaponEntRef[iClient] = EntIndexToEntRef(iBombWeapon);
	SetEntProp(iBombWeapon, Prop_Send, "m_iClip1", 1);
	OnWeaponSwitchPost(iClient, iBombWeapon);
	
	return iBombWeapon;
}

GivePlayerItemCustom(iClient, const String:szClassName[])
{
	new iEnt = GivePlayerItem(iClient, szClassName);
	
	/*
	* 	Sometimes GivePlayerItem() will call EquipPlayerWeapon() directly.
	* 	Other times which seems to be directly after stripping weapons or player spawn EquipPlayerWeapon() won't get called.
	* 	Call EquipPlayerWeapon() here if it wasn't called during GivePlayerItem(). Determine that by checking the entities owner.
	*/
	if(iEnt != -1 && GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == -1)
		EquipPlayerWeapon(iClient, iEnt);
	
	return iEnt;
}

RemoveJihadBombWeapon(iClient)
{
	new iBombWeapon = EntRefToEntIndex(g_iJihadBombWeaponEntRef[iClient]);
	if(iBombWeapon > 0)
		StripWeaponFromOwner(iBombWeapon, true);
}

bool:HasJihadBombWeaponDeployed(iClient)
{
	if(!IsJihad(iClient))
		return false;
	
	new iBombWeapon = EntRefToEntIndex(g_iJihadBombWeaponEntRef[iClient]);
	if(iBombWeapon < 1)
		return false;
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") != iBombWeapon)
		return false;
	
	return true;
}

TryClientHooks(iClient)
{
	if(g_bHooked[iClient])
		return;
	
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	
	g_bHooked[iClient] = true;
}

TryClientUnhooks(iClient)
{
	if(!g_bHooked[iClient])
		return;
	
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKUnhook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	
	g_bHooked[iClient] = false;
}

public OnClientDisconnect(iClient)
{
	ClearJihad(iClient);
}

public Action:OnWeaponDrop(iClient, const String:szCommand[], iArgCount)
{
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	if(!HasJihadBombWeaponDeployed(iClient))
		return Plugin_Continue;
	
	DisplayMenu_DropJihadBombWeapon(iClient);
	
	return Plugin_Handled;
}

public Action:CS_OnCSWeaponDrop(iClient, iWeapon)
{
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	if(!HasJihadBombWeaponDeployed(iClient))
		return Plugin_Continue;
	
	DisplayMenu_DropJihadBombWeapon(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_DropJihadBombWeapon(iClient)
{
	if(g_bIsBombActivated[iClient])
		return;
	
	new Handle:hMenu = CreateMenu(MenuHandle_DropJihadBombWeapon);
	SetMenuTitle(hMenu, "Drop your jihad bomb?\nIt will be destroyed and won't explode.\n \n+attack2 activates the bomb.\nUsually right click.\n ");
	
	AddMenuItem(hMenu, "0", "No, do not drop it.");
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "1", "Yes, drop it without exploding.");
	
	SetMenuExitButton(hMenu, false);
	if(!DisplayMenu(hMenu, iClient, 0))
		PrintToChat(iClient, "[SM] Error showing drop menu.");
}

public MenuHandle_DropJihadBombWeapon(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	if(StringToInt(szInfo))
		ClearJihad(iParam1);
}

StripWeaponFromOwner(iWeapon, bool:bKill)
{
	new iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if(iOwner != -1)
	{
		// First drop the weapon.
		SDKHooks_DropWeapon(iOwner, iWeapon);
		
		// If the weapon still has an owner after being dropped call RemovePlayerItem.
		// Note we check m_hOwner instead of m_hOwnerEntity here.
		if(GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner") == iOwner)
			RemovePlayerItem(iOwner, iWeapon);
		
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", -1);
		
		g_iJihadBombWeaponEntRef[iOwner] = INVALID_ENT_REFERENCE;
	}
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel != -1)
	{
		SetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel", -1);
		AcceptEntityInput(iWorldModel, "KillHierarchy");
	}
	
	if(bKill)
		AcceptEntityInput(iWeapon, "KillHierarchy");
}

public OnWeaponSwitchPost(iClient, iWeapon)
{
	if(!HasJihadBombWeaponDeployed(iClient))
		return;
	
	if(g_iModelIndex_Knife)
	{
		new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
		if(iWorldModel > 0)
			SetEntProp(iWorldModel, Prop_Send, "m_nModelIndex", g_iModelIndex_Knife);
	}
	
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", Float:0x7f7fffff);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", Float:0x7f7fffff);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.5);
}

public OnPreThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	if(!HasJihadBombWeaponDeployed(iClient))
		return;
	
	static iButtons;
	iButtons = GetClientButtons(iClient);
	if(iButtons & IN_ATTACK2)
		TryActivateBomb(iClient);
}

TryActivateBomb(iClient)
{
	new iBombWeapon = EntRefToEntIndex(g_iJihadBombWeaponEntRef[iClient]);
	if(iBombWeapon < 1)
	{
		ClearJihad(iClient);
		return;
	}
	
	if(GetEntPropFloat(iBombWeapon, Prop_Send, "m_flNextSecondaryAttack") > GetGameTime())
		return;
	
	if(!UltJB_CellDoors_HaveOpened())
	{
		SetEntPropFloat(iBombWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.5);
		PrintToChat(iClient, "You cannot use your bomb until the cell doors open.");
		return;
	}
	
	if(g_bIsBombActivated[iClient])
		return;
	
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", 0.0);
	EmitSoundToAll(SZ_SOUND_ACTIVATE[6], iBombWeapon);
	
	StartTimer_ActivateBomb(iClient);
}

StopTimer_Bomb(iClient)
{
	if(g_hTimer_Bomb[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Bomb[iClient]);
	g_hTimer_Bomb[iClient] = INVALID_HANDLE;
}

StartTimer_ActivateBomb(iClient)
{
	StopTimer_Bomb(iClient);
	
	g_bIsBombActivated[iClient] = true;
	g_hTimer_Bomb[iClient] = CreateTimer(0.3, Timer_ActivateBomb, GetClientSerial(iClient));
}

public Action:Timer_ActivateBomb(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_Bomb[iClient] = INVALID_HANDLE;
	
	RemoveJihadBombWeapon(iClient);
	CreateBomb(iClient);
}

CreateBomb(iClient)
{
	new iBomb = EntRefToEntIndex(g_iJihadBombEntRef[iClient]);
	if(iBomb < 1)
	{
		iBomb = CreateEntityByName("planted_c4");
		g_iJihadBombEntRef[iClient] = EntIndexToEntRef(iBomb);
	}
	
	if(iBomb < 1)
	{
		ClearJihad(iClient);
		PrintToChat(iClient, "Some reason your bomb couldn't be created.");
		return;
	}
	
	DispatchSpawn(iBomb);
	
	SetEntProp(iBomb, Prop_Send, "m_bBombTicking", 1);
	
	new Float:fBombTimer = GetConVarFloat(cvar_bomb_timer);
	SetEntPropFloat(iBomb, Prop_Send, "m_flC4Blow", GetGameTime() + fBombTimer);
	SetEntPropFloat(iBomb, Prop_Send, "m_flTimerLength", fBombTimer);
	
	SetEntProp(iBomb, Prop_Send, "m_ScaleType", 0);
	SetEntPropFloat(iBomb, Prop_Send, "m_flModelScale", 3.5);
	
	// Attach bomb to player.
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	fOrigin[2] += 90.0;
	
	decl Float:fAngles[3];
	GetClientAbsAngles(iClient, fAngles);
	fAngles[0] = 270.0;
	fAngles[1] += 180.0;
	fAngles[2] = 0.0;
	
	TeleportEntity(iBomb, fOrigin, fAngles, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(iBomb, "SetParent", iClient);
	
	//SetVariantString("defusekit");
	//AcceptEntityInput(iBomb, "SetParentAttachment", iClient);
	
	SetEntityRenderColor(iClient, 255, 0, 199, 255);
	SetEntProp(iClient, Prop_Send, "m_nSkin", 1);
	
	StartTimer_DetonateBomb(iClient, fBombTimer + 0.8);
	
	EmitSoundToAllAny(SZ_SOUND_AKBAR[6], iClient, SNDCHAN_VOICE, _, _, 0.27);
}

StartTimer_DetonateBomb(iClient, Float:fDetTime)
{
	StopTimer_Bomb(iClient);
	
	g_hTimer_Bomb[iClient] = CreateTimer(fDetTime, Timer_DetonateBomb, GetClientSerial(iClient));
}

public Action:Timer_DetonateBomb(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_Bomb[iClient] = INVALID_HANDLE;
	
	DetonateBomb(iClient);
}

DetonateBomb(iClient)
{
	new iBomb = EntRefToEntIndex(g_iJihadBombEntRef[iClient]);
	if(iBomb < 1)
		return;
	
	AcceptEntityInput(iBomb, "KillHierarchy");
	
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	PM_CreateEntityEffectCustomOrigin(0, PEFFECT_EXPLODE, fOrigin, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
	
	EmitAmbientSound(SZ_SOUND_EXPLODE[6], fOrigin, _, 140);
	
	new iC4 = CreateEntityByName("weapon_c4");
	
	KillPlayersInRadius(iClient, fOrigin, iC4);
	
	if(iC4)
		StripWeaponFromOwner(iC4, true);
}

KillPlayersInRadius(iExplodingClient, Float:fExplodeOrigin[3], iC4)
{
	// Kill self first.
	SDKHooks_TakeDamage(iExplodingClient, iC4, iExplodingClient, float(GetClientHealth(iExplodingClient) + 1), _, iC4);
	
	new iFoundAliveT;
	new iFoundAliveCT;
	
	// Damage other clients in radius.
	decl Float:fOrigin[3], Float:fDist, Float:fDamage, iTeam;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(iClient == iExplodingClient)
			continue;
		
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		iTeam = GetClientTeam(iClient);
		switch(iTeam)
		{
			case TEAM_PRISONERS:
			{
				iFoundAliveT++;
			}
			case TEAM_GUARDS:
			{
				iFoundAliveCT++;
			}
		}
		
		GetClientAbsOrigin(iClient, fOrigin);
		
		fDist = GetVectorDistance(fExplodeOrigin, fOrigin);
		if(fDist > EXPLODE_RADIUS)
			continue;
		
		fDamage = EXPLODE_MAX_DAMAGE * (1.0 - (fDist / EXPLODE_RADIUS));
		
		SDKHooks_TakeDamage(iClient, iC4, iExplodingClient, fDamage, _, iC4);
		
		// Check IsPlayerAlive again after SDKHooks_TakeDamage.
		if(!IsPlayerAlive(iClient))
		{
			switch(iTeam)
			{
				case TEAM_PRISONERS:
				{
					iFoundAliveT--;
				}
				case TEAM_GUARDS:
				{
					iFoundAliveCT--;
				}
			}
		}
	}
	
	// Some reason the round doesn't end if there are no terrorists remaining but there are CT remaining.
	if(!iFoundAliveT && iFoundAliveCT)
		CS_TerminateRound(3.0, CSRoundEnd_CTWin);
}
