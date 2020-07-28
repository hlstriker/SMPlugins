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
#include "Includes/ultjb_weapon_selection"
#include "../../Libraries/ParticleManager/particle_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Jihad";
new const String:PLUGIN_VERSION[] = "1.9";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The jihad plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bHooked[MAXPLAYERS+1];
new bool:g_bIsJihad[MAXPLAYERS+1];
new bool:g_bIsBombActivated[MAXPLAYERS+1];
new Handle:g_hTimer_Bomb[MAXPLAYERS+1];
new g_iJihadBombWeaponEntRef[MAXPLAYERS+1];
new g_iJihadBombEntRef[MAXPLAYERS+1];

new bool:g_bAllowBombDropping;

new const String:MODEL_KNIFE_T_WORLD[] = "models/weapons/w_knife.mdl";
new g_iModelIndex_Knife;

new const String:SZ_SOUND_ACTIVATE[] = "sound/survival/breach_activate_01.wav";
new const String:SZ_SOUND_AKBAR[] = "sound/swoobles/ultimate_jailbreak/akbar.mp3";
new const String:SZ_SOUND_EXPLODE[] = "sound/weapons/c4/c4_explode1.wav";

new const String:PARTICLE_FILE_PATH[] = "particles/explosions_fx.pcf";
new const String:PEFFECT_EXPLODE[] = "explosion_coop_mission_c4";

#define MODEL_BOMB	"models/weapons/w_c4_planted.mdl"

new Handle:cvar_mp_teammates_are_enemies;
new Handle:cvar_guards_needed;
new Handle:cvar_bomb_timer;
new Handle:cvar_percent_chance_to_give;
new Handle:cvar_explode_radius;
new Handle:cvar_max_damage;
new Handle:cvar_damage_percent_to_teammates;


public OnPluginStart()
{
	CreateConVar("ultjb_jihad_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_guards_needed = CreateConVar("ultjb_jihad_guards_needed", "3", "The number of guards needed for jihad to be given.", _, true, 1.0);
	cvar_bomb_timer = CreateConVar("ultjb_jihad_bomb_timer", "4.2", "The number of seconds before the bomb explodes.", _, true, 0.0);
	cvar_percent_chance_to_give = CreateConVar("ultjb_jihad_percent_chance_to_give", "40", "The percent chance a single prisoner will get jihad.", _, true, 0.0, true, 100.0);
	cvar_explode_radius = CreateConVar("ultjb_jihad_explode_radius", "750.0", "The jihad bomb explosion radius.", _, true, 1.0);
	cvar_max_damage = CreateConVar("ultjb_jihad_max_damage", "235.0", "The jihad bomb's max damage.", _, true, 0.0);
	cvar_damage_percent_to_teammates = CreateConVar("ultjb_damage_percent_to_teammates", "0.2", "The percent of damage the bomb does to teammates.", _, true, 0.0, true, 1.0);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
	
	AddCommandListener(OnWeaponDrop, "drop");
}

public OnConfigsExecuted()
{
	cvar_mp_teammates_are_enemies = FindConVar("mp_teammates_are_enemies");
	
	/*
	if(cvar_mp_teammates_are_enemies != INVALID_HANDLE)
	{
		new iCvarFlags = GetConVarFlags(cvar_mp_teammates_are_enemies);
		iCvarFlags &= ~FCVAR_NOTIFY;
		SetConVarFlags(cvar_mp_teammates_are_enemies, iCvarFlags);
	}
	*/
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

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_jihad");
	CreateNative("UltJB_Jihad_IsJihad", _UltJB_Jihad_IsJihad);
	CreateNative("UltJB_Jihad_SetJihad", _UltJB_Jihad_SetJihad);
	CreateNative("UltJB_Jihad_ClearJihad", _UltJB_Jihad_ClearJihad);
	CreateNative("UltJB_Jihad_SetAllowBombDropping", _UltJB_Jihad_SetAllowBombDropping);
	
	return APLRes_Success;
}

public _UltJB_Jihad_IsJihad(Handle:hPlugin, iNumParams)
{
	return IsJihad(GetNativeCell(1));
}

public _UltJB_Jihad_SetJihad(Handle:hPlugin, iNumParams)
{
	SetJihad(GetNativeCell(1));
}

public _UltJB_Jihad_ClearJihad(Handle:hPlugin, iNumParams)
{
	ClearJihad(GetNativeCell(1));
}

public _UltJB_Jihad_SetAllowBombDropping(Handle:hPlugin, iNumParams)
{
	g_bAllowBombDropping = bool:GetNativeCell(1);
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bAllowBombDropping = true;
	
	if(!UltJB_CellDoors_DoExist())
		return;
	
	if(GetRandomInt(1, 100) > GetConVarInt(cvar_percent_chance_to_give))
		return;
	
	SetRandomClientAsJihad();
}

public Action:Event_PlayerDeath_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsJihad(iClient))
		return;
	
	EmitSoundToAllAny(SZ_SOUND_AKBAR[6], iClient, SNDCHAN_VOICE, _, SND_STOP | SND_STOPLOOPING | SND_CHANGEVOL, 0.0);
	ClearJihad(iClient);
	DetonateBomb(iClient);
}

bool:SetRandomClientAsJihad()
{
	new Handle:hClients = CreateArray();
	
	new iNumGuards;
	decl iClient, iTeam;
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		iTeam = GetClientTeam(iClient);
		
		if(iTeam < TEAM_PRISONERS)
			continue;
		
		if(iTeam == TEAM_GUARDS)
		{
			iNumGuards++;
			continue;
		}
		
		if(IsJihad(iClient))
			continue;
		
		if(UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
			continue;
		
		PushArrayCell(hClients, iClient);
	}
	
	if(iNumGuards < GetConVarInt(cvar_guards_needed))
	{
		CloseHandle(hClients);
		return false;
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

bool:IsJihad(iClient)
{
	return g_bIsJihad[iClient];
}

RestoreJihadBombWeaponIfNeeded(iClient)
{
	if(!IsJihad(iClient))
		return -1;
	
	if(g_bIsBombActivated[iClient] || GetClientTeam(iClient) != TEAM_PRISONERS)
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
	
	iBombWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_BREACHCHARGE);
	if(iBombWeapon < 1)
		return -1;
	
	g_iJihadBombWeaponEntRef[iClient] = EntIndexToEntRef(iBombWeapon);
	SetEntProp(iBombWeapon, Prop_Send, "m_iClip1", 1);
	OnWeaponSwitchPost(iClient, iBombWeapon);
	
	return iBombWeapon;
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
	if(!g_bAllowBombDropping)
		return;
	
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
	
	if(!g_bAllowBombDropping)
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
		iBomb = CreateEntityByName("prop_dynamic_override");
		g_iJihadBombEntRef[iClient] = EntIndexToEntRef(iBomb);
	}
	
	if(iBomb < 1)
	{
		ClearJihad(iClient);
		PrintToChat(iClient, "Some reason your bomb couldn't be created.");
		return;
	}
	
	SetEntityModel(iBomb, MODEL_BOMB);
	
	DispatchSpawn(iBomb);
	ActivateEntity(iBomb);
	
	SetEntProp(iBomb, Prop_Send, "m_nSolidType", 0);
	SetEntProp(iBomb, Prop_Send, "m_ScaleType", 0);
	SetEntPropFloat(iBomb, Prop_Send, "m_flModelScale", 1.5);
	
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
	
	StartTimer_DetonateBomb(iClient, GetConVarFloat(cvar_bomb_timer));
	
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
	fOrigin[2] += 32.0;
	
	PM_CreateEntityEffectCustomOrigin(0, PEFFECT_EXPLODE, fOrigin, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
	
	EmitAmbientSound(SZ_SOUND_EXPLODE[6], fOrigin, _, 140);
	
	new iC4 = CreateEntityByName("weapon_c4");
	
	KillPlayersInRadius(iClient, fOrigin, iC4);
	
	if(iC4)
		StripWeaponFromOwner(iC4, true);
}

KillPlayersInRadius(iExplodingClient, const Float:fExplodeOrigin[3], iC4)
{
	new iExplodingClientTeam = GetClientTeam(iExplodingClient);

	// Make sure teammates are enemies so team damage works properly.
	new bool:bOriginalTeammatesAreEnemies = false;
	if(cvar_mp_teammates_are_enemies != INVALID_HANDLE)
	{
		bOriginalTeammatesAreEnemies = GetConVarBool(cvar_mp_teammates_are_enemies);
		SetConVarBool(cvar_mp_teammates_are_enemies, true);
	}
	
	// Kill self first.
	new iOriginalTeam = GetEntProp(iExplodingClient, Prop_Send, "m_iTeamNum");
	SetEntProp(iExplodingClient, Prop_Send, "m_ArmorValue", 0);
	SDKHooks_TakeDamage(iExplodingClient, iC4, iExplodingClient, float(GetClientHealth(iExplodingClient) + 1), _, iC4);
	new iNewTeam = GetEntProp(iExplodingClient, Prop_Send, "m_iTeamNum");
	
	// Set the exploding client back to their original team before they exploded. This is incase they got team switched on death.
	SetEntProp(iExplodingClient, Prop_Send, "m_iTeamNum", iOriginalTeam);
	
	// Damage other clients in radius.
	new bool:bIsInFreeForAllDay = (UltJB_Day_IsInProgress() && UltJB_Day_IsFreeForAll());
	
	decl Float:fOrigin[3], Float:fDist, Float:fDamage, iArmorValue;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(iClient == iExplodingClient)
			continue;
		
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
			continue;
		
		GetClientAbsOrigin(iClient, fOrigin);
		
		fDist = GetVectorDistance(fExplodeOrigin, fOrigin);
		if(fDist > GetConVarFloat(cvar_explode_radius))
			continue;
		
		fDamage = GetConVarFloat(cvar_max_damage) * (1.0 - (fDist / GetConVarFloat(cvar_explode_radius)));
		
		// Deal less damage to teammates, but only if not in a FFA day.
		if(!bIsInFreeForAllDay)
		{
			if(GetClientTeam(iClient) == iExplodingClientTeam)
				fDamage *= GetConVarFloat(cvar_damage_percent_to_teammates);
		}
		
		iArmorValue = GetEntProp(iClient, Prop_Send, "m_ArmorValue");
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", 0);
		
		SDKHooks_TakeDamage(iClient, iC4, iExplodingClient, fDamage, _, iC4);
		
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", iArmorValue);
	}
	
	// Set the exploding client back to their new team.
	SetEntProp(iExplodingClient, Prop_Send, "m_iTeamNum", iNewTeam);
	
	// Set teammates are enemies back to its original value.
	if(cvar_mp_teammates_are_enemies != INVALID_HANDLE)
		SetConVarBool(cvar_mp_teammates_are_enemies, bOriginalTeammatesAreEnemies);
}