#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <sdktools_functions>
#include <emitsoundany>
#include <sdktools_stringtables>
#include <sdktools_entinput>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_weapon_selection"
#include "Includes/ultjb_cell_doors"
#include "Includes/ultjb_days"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Settings";
new const String:PLUGIN_VERSION[] = "1.24";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The settings plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define PRISONER_SPAWN_DIST_FROM_WEAPON	300.0
#define MAX_IN_CELL_CLIP_SIZE	15

#define TEAM_NAME_1 "Guards"
#define TEAM_NAME_2 "Prisoners"

#define HEALTHSHOT_AMOUNT	25

new Handle:cvar_mp_teamname_1;
new Handle:cvar_mp_teamname_2;
new Handle:cvar_healthshot_health;
new Handle:cvar_mp_death_drop_gun;
new Handle:cvar_sv_disable_immunity_alpha;

new g_iModelIndex_Healthshot;
new const String:MODEL_HEALTHSHOT[] = "models/weapons/v_healthshot.mdl";

new const String:SZ_SOUND_GUARDS_WIN[] = "sound/swoobles/ultimate_jailbreak/guards_win_v5.mp3";
new const String:SZ_SOUND_PRISONERS_WIN[] = "sound/swoobles/ultimate_jailbreak/prisoners_win_v5.mp3";

new const String:SZ_OVERLAY_GUARDS_WIN[] = "materials/swoobles/ultimate_jailbreak/overlay_guards_win_v15.vtf";
new const String:SZ_OVERLAY_GUARDS_WIN_VMT[] = "materials/swoobles/ultimate_jailbreak/overlay_guards_win_v15.vmt";
new const String:SZ_OVERLAY_PRISONERS_WIN[] = "materials/swoobles/ultimate_jailbreak/overlay_prisoners_win_v15.vtf";
new const String:SZ_OVERLAY_PRISONERS_WIN_VMT[] = "materials/swoobles/ultimate_jailbreak/overlay_prisoners_win_v15.vmt";

new const COLLISION_GROUP_DEBRIS_TRIGGER = 2;	// Used for no collisions against players.

new Handle:g_hTimer_AutoRespawn;
new Float:g_fTimeStartedAutoRespawn;
new bool:g_bShouldDenyAutoRespawn[MAXPLAYERS+1];

new Handle:cvar_max_auto_respawn_seconds;

new g_iOriginalTeam[MAXPLAYERS+1];
new Float:g_fOriginalOrigin[MAXPLAYERS+1][3];
new Float:g_fOriginalAngles[MAXPLAYERS+1][3];

new Handle:g_aInCellWeapons;

new Handle:g_aWeaponDropRefs[MAXPLAYERS+1];
new g_iWeaponDropTick[MAXPLAYERS+1];

#define MODIFYING_WEAPON_EQUIP_TIME	90
new Float:g_fRoundStartTime;

new Handle:g_hFwd_OnSpawnPost;

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("ultjb_settings_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_max_auto_respawn_seconds = CreateConVar("ultjb_max_auto_respawn_seconds", "60", "The number of seconds to wait before disabling auto-respawn.", _, true, 0.0);
	
	g_aInCellWeapons = CreateArray();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
		g_aWeaponDropRefs[iClient] = CreateArray();
	
	g_hFwd_OnSpawnPost = CreateGlobalForward("UltJB_Settings_OnSpawnPost", ET_Ignore, Param_Cell);
	
	HookEvent("round_start", EventRoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventRoundEnd_Pre, EventHookMode_Pre);
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	HookEvent("player_team", EventPlayerTeam_Post, EventHookMode_Post);
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", EventPlayerDeath_Pre, EventHookMode_Pre);
	AddNormalSoundHook(OnNormalSound);
	
	//AddCommandListener(OnWeaponDrop, "drop");
	
	SetupConVars();
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_settings");
	CreateNative("UltJB_Settings_StripWeaponFromOwner", _UltJB_Settings_StripWeaponFromOwner);
	
	return APLRes_Success;
}

public _UltJB_Settings_StripWeaponFromOwner(Handle:hPlugin, iNumParams)
{
	StripWeaponFromOwner(GetNativeCell(1));
}

StripWeaponFromOwner(iWeapon)
{
	new iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if(iOwner != -1)
	{
		// First drop the weapon.
		SDKHooks_DropWeapon(iOwner, iWeapon);
		
		// If the weapon still has an owner after being dropped called RemovePlayerItem.
		// Note we check m_hOwner instead of m_hOwnerEntity here.
		if(GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner") == iOwner)
			RemovePlayerItem(iOwner, iWeapon);
		
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", -1);
	}
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel != -1)
	{
		SetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel", -1);
		AcceptEntityInput(iWorldModel, "KillHierarchy");
	}
	
	AcceptEntityInput(iWeapon, "KillHierarchy");
}

public EventPlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(GetEventInt(hEvent, "team") == TEAM_PRISONERS
	&& g_iOriginalTeam[iClient] == TEAM_GUARDS)
	{
		g_bShouldDenyAutoRespawn[iClient] = true;
	}
}

ResetOriginalTeams()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		g_iOriginalTeam[iClient] = CS_TEAM_NONE;
}

public Event_CSPreRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	ResetOriginalTeams();
}

RemoveReserveAmmoFromCellWeapons()
{
	ClearArray(g_aInCellWeapons);
	
	decl String:szClassName[20], Float:fOrigin[3],  iTemp;
	for(new iEnt=1; iEnt<=GetMaxEntities(); iEnt++)
	{
		if(!IsValidEntity(iEnt))
			continue;
		
		if(!GetEntityClassname(iEnt, szClassName, sizeof(szClassName)))
			continue;
		
		iTemp = szClassName[7];
		szClassName[19] = 0x00;
		
		szClassName[7] = 0x00;
		if(!StrEqual(szClassName, "weapon_"))
			continue;
		
		szClassName[7] = iTemp;
		if(StrEqual(szClassName[7], "hegrenade")
		|| StrEqual(szClassName[7], "smokegrenade")
		|| StrEqual(szClassName[7], "incgrenade")
		|| StrEqual(szClassName[7], "decoy")
		|| StrEqual(szClassName[7], "molotov")
		|| StrEqual(szClassName[7], "tagrenade")
		|| StrEqual(szClassName[7], "flashbang"))
			continue;
		
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
		if(!IsPrisonerSpawnWithinDistance(fOrigin))
			continue;
		
		PushArrayCell(g_aInCellWeapons, EntIndexToEntRef(iEnt));
	}
}

public OnWeaponEquipPost(iClient, iWeapon)
{
	if(GetEngineTime() > g_fRoundStartTime + MODIFYING_WEAPON_EQUIP_TIME)
		return;
	
	if(GetClientTeam(iClient) != TEAM_PRISONERS)
		return;
	
	if(!IsValidEntity(iWeapon))
		return;
	
	new iEntRef = EntIndexToEntRef(iWeapon);
	if(iEntRef == INVALID_ENT_REFERENCE)
		return;
	
	new iIndex = FindValueInArray(g_aInCellWeapons, iEntRef);
	if(iIndex == -1)
		return;
	
	RemoveFromArray(g_aInCellWeapons, iIndex);
	
	SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
	SetEntProp(iWeapon, Prop_Send, "m_iSecondaryReserveAmmoCount", 0);
	
	new iClipSize = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
	if(iClipSize > MAX_IN_CELL_CLIP_SIZE)
		iClipSize = MAX_IN_CELL_CLIP_SIZE;
	
	SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClipSize);
}

bool:IsPrisonerSpawnWithinDistance(const Float:fCheckOrigin[3])
{
	new iEnt = -1;
	decl Float:fSpawnOrigin[3];
	while((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fSpawnOrigin);
		if(GetVectorDistance(fCheckOrigin, fSpawnOrigin) <= PRISONER_SPAWN_DIST_FROM_WEAPON)
			return true;
	}
	
	return false;
}

public OnMapStart()
{
	AddFileToDownloadsTable(SZ_SOUND_GUARDS_WIN);
	AddFileToDownloadsTable(SZ_SOUND_PRISONERS_WIN);
	
	AddFileToDownloadsTable(SZ_OVERLAY_GUARDS_WIN);
	AddFileToDownloadsTable(SZ_OVERLAY_GUARDS_WIN_VMT);
	AddFileToDownloadsTable(SZ_OVERLAY_PRISONERS_WIN);
	AddFileToDownloadsTable(SZ_OVERLAY_PRISONERS_WIN_VMT);
	
	PrecacheSoundAny(SZ_SOUND_GUARDS_WIN[6]);
	PrecacheSoundAny(SZ_SOUND_PRISONERS_WIN[6]);
	
	g_iModelIndex_Healthshot = PrecacheModel(MODEL_HEALTHSHOT, true);
	
	ResetOriginalTeams();
	OnRoundStart();
}

SetupConVars()
{
	if((cvar_mp_teamname_1 = FindConVar("mp_teamname_1")) != INVALID_HANDLE)
	{
		HookConVarChange(cvar_mp_teamname_1, OnConVarChanged);
		SetConVarString(cvar_mp_teamname_1, TEAM_NAME_1);
	}
	
	if((cvar_mp_teamname_2 = FindConVar("mp_teamname_2")) != INVALID_HANDLE)
	{
		HookConVarChange(cvar_mp_teamname_2, OnConVarChanged);
		SetConVarString(cvar_mp_teamname_2, TEAM_NAME_2);
	}
	
	if((cvar_healthshot_health = FindConVar("healthshot_health")) != INVALID_HANDLE)
	{
		HookConVarChange(cvar_healthshot_health, OnConVarChanged);
		SetConVarInt(cvar_healthshot_health, HEALTHSHOT_AMOUNT);
	}
	
	if((cvar_sv_disable_immunity_alpha = FindConVar("sv_disable_immunity_alpha")) != INVALID_HANDLE)
	{
		HookConVarChange(cvar_sv_disable_immunity_alpha, OnConVarChanged);
		SetConVarInt(cvar_sv_disable_immunity_alpha, 1);
	}
	
	cvar_mp_death_drop_gun = FindConVar("cvar_mp_death_drop_gun");
}

AllowWeaponDroppingOnDeath(bool:bShouldAllow)
{
	if(cvar_mp_death_drop_gun != INVALID_HANDLE)
		SetConVarInt(cvar_mp_death_drop_gun, bShouldAllow ? 1 : 0);
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[])
{
	if(hConvar == cvar_mp_teamname_1)
	{
		SetConVarString(cvar_mp_teamname_1, TEAM_NAME_1);
	}
	else if(hConvar == cvar_mp_teamname_2)
	{
		SetConVarString(cvar_mp_teamname_2, TEAM_NAME_2);
	}
	else if(hConvar == cvar_healthshot_health)
	{
		SetConVarInt(cvar_healthshot_health, HEALTHSHOT_AMOUNT);
	}
	else if(hConvar == cvar_sv_disable_immunity_alpha)
	{
		SetConVarInt(cvar_sv_disable_immunity_alpha, 1);
	}
}

public Action:EventRoundEnd_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// Blocks the round end sounds.
	SetEventBroadcast(hEvent, true);
	return Plugin_Continue;
}

public Action:CS_OnTerminateRound(&Float:fDelay, &CSRoundEndReason:reason)
{
	switch(reason)
	{
		case CSRoundEnd_CTWin, CSRoundEnd_TargetSaved, CSRoundEnd_VIPEscaped, CSRoundEnd_CTStoppedEscape, CSRoundEnd_TerroristsStopped, CSRoundEnd_BombDefused, CSRoundEnd_HostagesRescued, CSRoundEnd_TerroristsNotEscaped, CSRoundEnd_TerroristsSurrender:
		{
			EmitSoundToAllAny(SZ_SOUND_GUARDS_WIN[6], _, _, SNDLEVEL_NONE, _, _, 90);
			ShowOverlayToAll(SZ_OVERLAY_GUARDS_WIN_VMT[10]);
		}	
		case CSRoundEnd_TerroristWin, CSRoundEnd_VIPKilled, CSRoundEnd_TerroristsEscaped, CSRoundEnd_HostagesNotRescued, CSRoundEnd_VIPNotEscaped, CSRoundEnd_CTSurrender, CSRoundEnd_TargetBombed:
		{
			EmitSoundToAllAny(SZ_SOUND_PRISONERS_WIN[6], _, _, SNDLEVEL_NONE, _, _, 90);
			ShowOverlayToAll(SZ_OVERLAY_PRISONERS_WIN_VMT[10]);
		}
	}
}

ShowOverlayToAll(const String:szOverlayPath[])
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		ClientCommand(iClient, "r_screenoverlay \"%s\"", szOverlayPath);
	}
}

public Action:EventRoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	ShowOverlayToAll("");
	OnRoundStart();
}

OnRoundStart()
{
	g_fRoundStartTime = GetEngineTime();
	
	StartAutoRespawning();
	RemoveReserveAmmoFromCellWeapons();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SetEntityGravity(iClient, 1.0);
		SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", 1.0);
	}
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(iClient, SDKHook_WeaponDropPost, OnWeaponDropPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	SetEntProp(iClient, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	
	UltJB_LR_StripClientsWeapons(iClient);
	
	new iTeam = GetClientTeam(iClient);
	if(g_iOriginalTeam[iClient] == CS_TEAM_NONE)
	{
		g_iOriginalTeam[iClient] = iTeam;
		GetClientAbsOrigin(iClient, g_fOriginalOrigin[iClient]);
		GetClientAbsAngles(iClient, g_fOriginalAngles[iClient]);
	}
	else
	{
		if(iTeam == g_iOriginalTeam[iClient])
			TeleportEntity(iClient, g_fOriginalOrigin[iClient], g_fOriginalAngles[iClient], NULL_VECTOR);
	}
	
	decl iWeapon;
	if(iTeam == TEAM_GUARDS)
	{
		iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_FIVESEVEN);
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_HEALTHSHOT);
		
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", 100);
		SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 0);
	}
	else
	{
		iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
		
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", 0);
		SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 0);
	}
	
	if(iWeapon > 0)
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	SetEntityHealth(iClient, 100);
	SetEntProp(iClient, Prop_Data, "m_iMaxHealth", 100);
	
	Forward_OnSpawnPost(iClient);
}

Forward_OnSpawnPost(iClient)
{
	new result;
	Call_StartForward(g_hFwd_OnSpawnPost);
	Call_PushCell(iClient);
	Call_Finish(result);
}

StartAutoRespawning(bool:bClearDenyList=true)
{
	if(bClearDenyList)
	{
		for(new iClient=1; iClient<=MaxClients; iClient++)
			g_bShouldDenyAutoRespawn[iClient] = false;
	}
	
	if(UltJB_CellDoors_DoExist())
	{
		AllowWeaponDroppingOnDeath(false);
		StartTimer_AutoRespawn();
	}
	else
	{
		AllowWeaponDroppingOnDeath(true);
	}
}

StartTimer_AutoRespawn()
{
	StopTimer_AutoRespawn();
	
	g_fTimeStartedAutoRespawn = GetEngineTime();
	g_hTimer_AutoRespawn = CreateTimer(0.1, Timer_AutoRespawn, _, TIMER_REPEAT);
}

StopTimer_AutoRespawn()
{
	AllowWeaponDroppingOnDeath(true);
	
	if(g_hTimer_AutoRespawn == INVALID_HANDLE)
		return;
		
	KillTimer(g_hTimer_AutoRespawn);
	g_hTimer_AutoRespawn = INVALID_HANDLE;
}

public OnMapEnd()
{
	StopTimer_AutoRespawn();
}

public Action:Timer_AutoRespawn(Handle:hTimer)
{
	static iClient, iTeam;
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(g_bShouldDenyAutoRespawn[iClient])
			continue;
		
		if(IsPlayerAlive(iClient))
			continue;
		
		iTeam = GetClientTeam(iClient);
		if(iTeam != TEAM_PRISONERS)
			continue;
		
		g_bShouldDenyAutoRespawn[iClient] = true;
		CS_RespawnPlayer(iClient);
	}
	
	if(GetEngineTime() >= (g_fTimeStartedAutoRespawn + GetConVarFloat(cvar_max_auto_respawn_seconds)))
	{
		AllowWeaponDroppingOnDeath(true);
		g_hTimer_AutoRespawn = INVALID_HANDLE;
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public UltJB_CellDoors_OnOpened()
{
	StopTimer_AutoRespawn();
}

public UltJB_Day_OnWardayStart(iClient)
{
	StartAutoRespawning(false);
}

public UltJB_Day_OnWardayFreezeEnd()
{
	StopTimer_AutoRespawn();
}

public OnWeaponDropPost(iClient, iWeapon)
{
	if(iWeapon < 1)
		return;
	
	new iTick = GetGameTickCount();
	if(iTick != g_iWeaponDropTick[iClient])
	{
		ClearArray(g_aWeaponDropRefs[iClient]);
		g_iWeaponDropTick[iClient] = iTick;
	}
	
	PushArrayCell(g_aWeaponDropRefs[iClient], EntIndexToEntRef(iWeapon));
}

public EventPlayerDeath_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!iClient)
		return;
	
	if(g_iWeaponDropTick[iClient] != GetGameTickCount())
		return;
	
	if(iClient != GetClientOfUserId(GetEventInt(hEvent, "attacker")))
		return;
	
	if(GetClientTeam(iClient) != TEAM_GUARDS)
		return;
	
	decl iWeapon;
	for(new i=0; i<GetArraySize(g_aWeaponDropRefs[iClient]); i++)
	{
		iWeapon = EntRefToEntIndex(GetArrayCell(g_aWeaponDropRefs[iClient], i));
		if(iWeapon > 0)
			AcceptEntityInput(iWeapon, "Kill");
	}
}

public EventPlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iVictim <= MaxClients))
		return;
	
	// Suicide
	//new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	//if(iAttacker == iVictim)
		//return;
	
	g_bShouldDenyAutoRespawn[iVictim] = true;
}

public Action:OnWeaponDrop(iClient, const String:szCommand[], iArgCount)
{
	new iWeapon = GetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon");
	if(iWeapon < 1)
		return Plugin_Continue;
	
	if(GetEntProp(iWeapon, Prop_Send, "m_nModelIndex") != g_iModelIndex_Healthshot)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	if(iChannel != SNDCHAN_BODY)
		return Plugin_Continue;
	
	static String:szClassName[16];
	if(!GetEntityClassname(iEntity, szClassName, sizeof(szClassName)))
		return Plugin_Continue;
	
	if(strlen(szClassName) != 14)
		return Plugin_Continue;
	
	if(!StrEqual(szClassName[5], "breakable"))
		return Plugin_Continue;
	
	new iNumNewClients;
	decl iClient, iNewClients[64];
	for(new i=0; i<iNumClients; i++)
	{
		iClient = iClients[i];
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS)
			continue;
		
		iNewClients[iNumNewClients++] = iClient;
	}
	
	for(new i=0; i<iNumNewClients; i++)
		iClients[i] = iNewClients[i];
	
	iNumClients = iNumNewClients;
	
	return Plugin_Changed;
}