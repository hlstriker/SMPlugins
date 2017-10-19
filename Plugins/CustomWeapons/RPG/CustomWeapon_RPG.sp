#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools_engine>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_stringtables>
#include <sdktools_trace>
#include <sdktools_tempents>
#include <emitsoundany>

#undef REQUIRE_PLUGIN
#include "../../../Libraries/ParticleManager/particle_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Custom Weapon: RPG";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = PLUGIN_NAME,
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define WEAPONTYPE_NONE		0
#define WEAPONTYPE_RPG		1
new bool:g_bHooked[MAXPLAYERS+1];

#define WEAPON_OFFSET_FORWARD	16.0
#define WEAPON_OFFSET_RIGHT		7.0
#define WEAPON_OFFSET_UP		-6.0

#define SOLID_NONE	0
#define COLLISION_GROUP_PLAYER_MOVEMENT	8
#define ROCKET_COLLISION_GROUP	COLLISION_GROUP_PLAYER_MOVEMENT

#define USE_SPECIFIED_BOUNDS	3

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;
new const FSOLID_USE_TRIGGER_BOUNDS = 0x0080;

new const Float:g_fRocketMins[3] = {-0.0, -0.0, -0.0};
new const Float:g_fRocketMaxs[3] = {0.0, 0.0, 0.0};

new bool:g_bIsReloading[MAXPLAYERS+1];
new Float:g_fReloadEndTime[MAXPLAYERS+1];
new Float:g_fNextAttack[MAXPLAYERS+1];

#define SEQUENCE_IDLE			0
#define SEQUENCE_SHOOT_1		1
#define SEQUENCE_SHOOT_2		2
#define SEQUENCE_DEPLOY			4
#define SEQUENCE_RELOAD_1		5
#define SEQUENCE_RELOAD_2		9

new g_iOnSequence_Shoot[MAXPLAYERS+1];
new g_iOnSequence_Reload[MAXPLAYERS+1];

#define CVARQUERY_INTERVAL_RIGHT_HAND 0.3
new Float:g_fNextCvarQueryCheck_RightHand[MAXPLAYERS+1];
new bool:g_bUsingLeftHand[MAXPLAYERS+1];

new bool:g_bHasUnlimitedAmmo_Clip[MAXPLAYERS+1];
new bool:g_bHasUnlimitedAmmo_Reserve[MAXPLAYERS+1];

#define DEFAULT_MAX_CLIP_SIZE		4
#define DEFAULT_MAX_RESERVE_SIZE	50
new g_iMaxAmmoSize_Clip[MAXPLAYERS+1];
new g_iMaxAmmoSize_Reserve[MAXPLAYERS+1];

new bool:g_bShowToSelfOnly[MAXPLAYERS+1];

new const String:MODEL_ROCKET_LAUNCHER[] = "models/weapons/rocket_launcher/rocket_launcher.mdl";
new g_iModelIndex_RocketLauncher;

new const String:MODEL_ROCKET_LAUNCHER_WORLD[] = "models/weapons/rocket_launcher/w_rocket_launcher.mdl";
new g_iModelIndex_RocketLauncherWorld;

new const String:MODEL_ROCKET_LAUNCHER_FILES[][] =
{
	"materials/models/weapons/rocket_launcher/dm_base.vmt",
	"materials/models/weapons/rocket_launcher/dm_base.vtf",
	"materials/models/weapons/rocket_launcher/rocketl.vmt",
	"materials/models/weapons/rocket_launcher/rocketl.vtf",
	
	"models/weapons/rocket_launcher/rocket_launcher.ani",
	"models/weapons/rocket_launcher/rocket_launcher.dx90.vtx",
	"models/weapons/rocket_launcher/rocket_launcher.vvd",
	
	"models/weapons/rocket_launcher/w_rocket_launcher.phy",
	"models/weapons/rocket_launcher/w_rocket_launcher.dx90.vtx",
	"models/weapons/rocket_launcher/w_rocket_launcher.vvd"
};

new const String:MODEL_ROCKET[] = "models/swoobles/rocket_jumping/missile/missile.mdl";

new const String:MODEL_ROCKET_FILES[][] =
{
	"materials/swoobles/rocket_jumping/missile/missile.vmt",
	"materials/swoobles/rocket_jumping/missile/missile.vtf",
	
	"models/swoobles/rocket_jumping/missile/missile.dx80.vtx",
	"models/swoobles/rocket_jumping/missile/missile.dx90.vtx",
	"models/swoobles/rocket_jumping/missile/missile.sw.vtx",
	"models/swoobles/rocket_jumping/missile/missile.vvd"
};

new const String:SOUND_ROCKET_FLY[] = "sound/ambient/machines/steam_loop_01.wav";
new const String:SOUND_ROCKET_SHOOT[] = "sound/swoobles/rocket_jumping/shoot_v1.mp3";

new const String:SOUND_ROCKET_EXPLODE[][] =
{
	"sound/swoobles/rocket_jumping/explode1.mp3"
};

new const String:DECAL_EXPLOSION[] = "decals/scorch1_subrect";
new g_iDecalIndex_Explosion;

#if defined _particle_manager_included
new const String:PARTICLE_FILE_PATH[] = "particles/swoobles/defrag_v1.pcf";
new const String:PEFFECT_ROCKET_TRAIL[] = "swbs_defrag_rocket_trail";
new const String:PEFFECT_ROCKET_EXPLODE[] = "swbs_defrag_rocket_explosion";
#endif

new bool:g_bLibLoaded_ParticleManager;

new Handle:cvar_base_damage;
new Handle:cvar_rocket_speed;

new Handle:cvar_push_force_base;
new Handle:cvar_push_force_multiplier;
new Handle:cvar_push_falloff_percent;
new Handle:cvar_push_min_distance_clamp;
new Handle:cvar_push_max_distance;

new Handle:cvar_attack_delay_deploy;
new Handle:cvar_attack_delay_attack;
new Handle:cvar_reload_delay;

new Handle:cvar_allow_damage_self;
new Handle:cvar_allow_damage_others;

new Handle:cvar_knockback_enemies;
new Handle:cvar_knockback_self;
new Handle:cvar_knockback_team;

new Handle:cvar_rocket_passthrough_players;


public OnPluginStart()
{
	CreateConVar("customwpn_rpg_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_base_damage	= CreateConVar("wpn_rpg_base_damage", "30.0", "This weapons base damage.");
	cvar_rocket_speed	= CreateConVar("wpn_rpg_rocket_speed", "1000.0", "This weapons rocket speed.");
	
	cvar_push_force_base			= CreateConVar("wpn_rpg_push_force_base", "102.0", "This base push force before calculating the falloff distance.");
	cvar_push_force_multiplier		= CreateConVar("wpn_rpg_push_force_multiplier", "6.0", "The push force multiplier which is multiplied after calculating the falloff.");
	cvar_push_falloff_percent		= CreateConVar("wpn_rpg_push_falloff_percent", "0.55", "The push force falloff percent.");
	cvar_push_min_distance_clamp	= CreateConVar("wpn_rpg_push_min_distance_clamp", "32.0", "Clamp the rockets minimum distance from the player to this value.");
	cvar_push_max_distance			= CreateConVar("wpn_rpg_push_max_distance", "115.0", "The maximum distance the rocket can be from the player while still pushing them.");
	
	cvar_attack_delay_deploy	= CreateConVar("wpn_rpg_attack_delay_deploy", "0.5", "The delay to wait to attack after deploying the weapon.");
	cvar_attack_delay_attack	= CreateConVar("wpn_rpg_attack_delay_attack", "0.8", "The delay to wait to attack again after attacking.");
	cvar_reload_delay			= CreateConVar("wpn_rpg_reload_delay", "1.25", "The delay to wait to reload.");
	
	cvar_allow_damage_self		= CreateConVar("wpn_rpg_allow_damage_self", "1", "Allow this weapon to damage its owner.");
	cvar_allow_damage_others	= CreateConVar("wpn_rpg_allow_damage_others", "1", "Allow this weapon to damage other players.");
	
	cvar_knockback_enemies		= CreateConVar("wpn_rpg_knockback_enemies", "1", "Allow this weapon to knockback enemies.");
	cvar_knockback_self			= CreateConVar("wpn_rpg_knockback_self", "1", "Allow this weapon to knockback its owner.");
	cvar_knockback_team			= CreateConVar("wpn_rpg_knockback_team", "0", "Allow this weapon to knockback teammates.");
	
	cvar_rocket_passthrough_players	= CreateConVar("wpn_rpg_rocket_passthrough_players", "0", "Should the rocket pass through other players or not.");
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ParticleManager = LibraryExists("particle_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = false;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("custom_weapon_rpg");
	
	CreateNative("WpnRPG_AllowUsage", _WpnRPG_AllowUsage);
	CreateNative("WpnRPG_Give", _WpnRPG_Give);
	CreateNative("WpnRPG_Remove", _WpnRPG_Remove);
	CreateNative("WpnRPG_SetUnlimitedAmmo", _WpnRPG_SetUnlimitedAmmo);
	CreateNative("WpnRPG_SetEffectVisibility", _WpnRPG_SetEffectVisibility);
	
	return APLRes_Success;
}

public _WpnRPG_AllowUsage(Handle:hPlugin, iNumParams)
{
	SetAllowUsage(GetNativeCell(1), GetNativeCell(2));
}

SetAllowUsage(iClient, bool:bCanUse)
{
	if(bCanUse)
	{
		TryClientHooks(iClient);
	}
	else
	{
		TryClientUnhooks(iClient);
		StripClientWeapons(iClient, true);
	}
}

public _WpnRPG_Give(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	SetAllowUsage(iClient, true);
	
	g_iMaxAmmoSize_Clip[iClient] = GetNativeCell(4);
	g_iMaxAmmoSize_Reserve[iClient] = GetNativeCell(5);
	
	return GiveRPG(iClient, GetNativeCell(2), GetNativeCell(3));
}

public _WpnRPG_Remove(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new bool:bDisableUsage = GetNativeCell(2);
	
	if(bDisableUsage)
		SetAllowUsage(iClient, false); // Also strips weapon.
	else
		StripClientWeapons(iClient, true);
}

public _WpnRPG_SetUnlimitedAmmo(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	g_bHasUnlimitedAmmo_Clip[iClient] = GetNativeCell(2);
	g_bHasUnlimitedAmmo_Reserve[iClient] = GetNativeCell(3);
}

public _WpnRPG_SetEffectVisibility(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	g_bShowToSelfOnly[iClient] = GetNativeCell(2);
}

public OnMapStart()
{
	g_iModelIndex_RocketLauncher = PrecacheModel(MODEL_ROCKET_LAUNCHER, true);
	AddFileToDownloadsTable(MODEL_ROCKET_LAUNCHER);
	
	g_iModelIndex_RocketLauncherWorld = PrecacheModel(MODEL_ROCKET_LAUNCHER_WORLD, true);
	AddFileToDownloadsTable(MODEL_ROCKET_LAUNCHER_WORLD);
	
	for(new i=0; i<sizeof(MODEL_ROCKET_LAUNCHER_FILES); i++)
		AddFileToDownloadsTable(MODEL_ROCKET_LAUNCHER_FILES[i]);
	
	PrecacheModel(MODEL_ROCKET, true);
	AddFileToDownloadsTable(MODEL_ROCKET);
	
	for(new i=0; i<sizeof(MODEL_ROCKET_FILES); i++)
		AddFileToDownloadsTable(MODEL_ROCKET_FILES[i]);
	
	AddFileToDownloadsTable(SOUND_ROCKET_FLY);
	PrecacheSoundAny(SOUND_ROCKET_FLY[6]);
	
	AddFileToDownloadsTable(SOUND_ROCKET_SHOOT);
	PrecacheSoundAny(SOUND_ROCKET_SHOOT[6]);
	
	for(new i=0; i<sizeof(SOUND_ROCKET_EXPLODE); i++)
	{
		AddFileToDownloadsTable(SOUND_ROCKET_EXPLODE[i]);
		PrecacheSoundAny(SOUND_ROCKET_EXPLODE[i][6]);
	}
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		AddFileToDownloadsTable(PARTICLE_FILE_PATH);
		PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_ROCKET_TRAIL);
		PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_ROCKET_EXPLODE);
		#endif
	}
	
	g_iDecalIndex_Explosion = PrecacheDecal(DECAL_EXPLOSION, true);
}

TryClientHooks(iClient)
{
	if(g_bHooked[iClient])
		return;
	
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	
	g_bHooked[iClient] = true;
}

TryClientUnhooks(iClient)
{
	if(!g_bHooked[iClient])
		return;
	
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKUnhook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKUnhook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	
	g_bHooked[iClient] = false;
}

public OnClientConnected(iClient)
{
	g_bHasUnlimitedAmmo_Clip[iClient] = false;
	g_bHasUnlimitedAmmo_Reserve[iClient] = false;
	
	g_iMaxAmmoSize_Clip[iClient] = DEFAULT_MAX_CLIP_SIZE;
	g_iMaxAmmoSize_Reserve[iClient] = DEFAULT_MAX_RESERVE_SIZE;
	
	g_bShowToSelfOnly[iClient] = false;
}

public OnClientDisconnect_Post(iClient)
{
	g_bHooked[iClient] = false;
}

GiveRPG(iClient, iClipAmount, iReserveAmount)
{
	new iTeam = GetClientTeam(iClient);
	if(iTeam < CS_TEAM_T)
		return -1;
	
	StripClientWeapons(iClient);
	GivePlayerItemCustom(iClient, (iTeam == CS_TEAM_T) ? "weapon_knife_t" : "weapon_knife");
	GivePlayerItemCustom(iClient, (iTeam == CS_TEAM_T) ? "weapon_glock" : "weapon_usp_silencer");
	
	new iWeapon = GivePlayerItemCustom(iClient, "weapon_bizon");
	if(iWeapon < 1)
		return -1;
	
	SetWeaponType(iWeapon, WEAPONTYPE_RPG);
	
	SetEntProp(iWeapon, Prop_Data, "m_iPrimaryAmmoType", 8);
	SetClipCount(iWeapon, iClipAmount);
	SetReserveCount(iWeapon, iReserveAmount);
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == iWeapon)
		OnWeaponSwitchPost(iClient, iWeapon);
	
	return iWeapon;
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

StripClientWeapons(iClient, bool:bStripOnlyRPG=false)
{
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	decl iWeapon;
	for(new i=0; i<iArraySize; i++)
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if(iWeapon < 1)
			continue;
		
		if(bStripOnlyRPG && GetWeaponType(iWeapon) != WEAPONTYPE_RPG)
			continue;
		
		StripWeaponFromOwner(iWeapon);
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, i);
	}
}

StripWeaponFromOwner(iWeapon)
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
	}
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel != -1)
	{
		SetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel", -1);
		AcceptEntityInput(iWorldModel, "KillHierarchy");
	}
	
	AcceptEntityInput(iWeapon, "KillHierarchy");
}

SetWeaponType(iWeapon, iType)
{
	SetEntProp(iWeapon, Prop_Data, "m_iHealth", iType);
}

GetWeaponType(iWeapon)
{
	return GetEntProp(iWeapon, Prop_Data, "m_iHealth");
}

SetClipCount(iWeapon, iCount)
{
	SetEntProp(iWeapon, Prop_Send, "m_iClip1", iCount);
}

GetClipCount(iWeapon)
{
	return GetEntProp(iWeapon, Prop_Send, "m_iClip1");
}

SetReserveCount(iWeapon, iCount)
{
	SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", iCount);
}

GetReserveCount(iWeapon)
{
	return GetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
}

public Action:Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	if(!g_bHooked[iClient])
		return;
	
	ClearViewModel(iClient);
}

public Action:Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	if(!g_bHooked[iClient])
		return;
	
	ClearViewModel(iClient);
}

ClearViewModel(iClient)
{
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(iViewModel > 0)
		SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", 0);
}

TryResetViewModel(iClient)
{
	new iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon < 1)
	{
		ClearViewModel(iClient);
		return;
	}
	
	if(GetWeaponType(iActiveWeapon) != WEAPONTYPE_NONE)
		return;
	
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(iViewModel < 1)
		return;
	
	SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", GetEntProp(iActiveWeapon, Prop_Send, "m_nModelIndex"));
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	TryResetViewModel(iClient);
	
	new iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon < 1 || GetWeaponType(iActiveWeapon) != WEAPONTYPE_RPG)
		return;
	
	OnWeaponSwitchPost(iClient, iActiveWeapon);
}

public OnWeaponSwitchPost(iClient, iWeapon)
{
	StopReloading(iClient, false);
	
	if(GetWeaponType(iWeapon) != WEAPONTYPE_RPG)
		return;
	
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(iViewModel > 0)
		SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", g_iModelIndex_RocketLauncher);
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel > 0)
		SetEntProp(iWorldModel, Prop_Send, "m_nModelIndex", g_iModelIndex_RocketLauncherWorld);
	
	SetEntProp(iWeapon, Prop_Send, "m_nModelIndex", 0);
	
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", 99999999999.0);
	g_fNextAttack[iClient] = GetEngineTime() + GetConVarFloat(cvar_attack_delay_deploy);
	
	SetSequence(iClient, SEQUENCE_DEPLOY);
}

SetSequence(iClient, iSequence)
{
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(iViewModel < 1)
		return;
	
	SetEntProp(iViewModel, Prop_Send, "m_nSequence", iSequence);
	SetEntPropFloat(iViewModel, Prop_Send, "m_flPlaybackRate", 1.0);
}

GetNextSequence_Reload(iClient)
{
	if(g_iOnSequence_Reload[iClient] == SEQUENCE_RELOAD_1)
	{
		g_iOnSequence_Reload[iClient] = SEQUENCE_RELOAD_2;
		return SEQUENCE_RELOAD_2;
	}
	
	g_iOnSequence_Reload[iClient] = SEQUENCE_RELOAD_1;
	return SEQUENCE_RELOAD_1;
}

GetNextSequence_Shoot(iClient)
{
	if(g_iOnSequence_Shoot[iClient] == SEQUENCE_SHOOT_1)
	{
		g_iOnSequence_Shoot[iClient] = SEQUENCE_SHOOT_2;
		return SEQUENCE_SHOOT_2;
	}
	
	g_iOnSequence_Shoot[iClient] = SEQUENCE_SHOOT_1;
	return SEQUENCE_SHOOT_1;
}

StartReloading(iClient)
{
	g_bIsReloading[iClient] = true;
	g_fReloadEndTime[iClient] = GetEngineTime() + GetConVarFloat(cvar_reload_delay);
	
	SetSequence(iClient, GetNextSequence_Reload(iClient));
}

StopReloading(iClient, bool:bPlayAnimation=true)
{
	g_bIsReloading[iClient] = false;
	
	if(bPlayAnimation)
		SetSequence(iClient, SEQUENCE_IDLE);
}

FinishReloading(iClient, iLauncher)
{
	StopReloading(iClient);
	SetClipCount(iLauncher, GetClipCount(iLauncher) + 1);
	
	if(!g_bHasUnlimitedAmmo_Reserve[iClient])
		SetReserveCount(iLauncher, GetReserveCount(iLauncher) - 1);
}

bool:CanReload(iClient, iLauncher)
{
	if(GetClipCount(iLauncher) >= g_iMaxAmmoSize_Clip[iClient])
		return false;
	
	if(GetReserveCount(iLauncher) < 1)
		return false;
	
	return true;
}

TryCvarQuery_RightHand(iClient)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextCvarQueryCheck_RightHand[iClient])
		return;
	
	g_fNextCvarQueryCheck_RightHand[iClient] = fCurTime + CVARQUERY_INTERVAL_RIGHT_HAND;
	QueryClientConVar(iClient, "cl_righthand", OnCvarQueryFinished_RightHand);
}

public OnCvarQueryFinished_RightHand(QueryCookie:cookie, iClient, ConVarQueryResult:result, const String:szConvarName[], const String:szConvarValue[], any:hPack)
{
	g_bUsingLeftHand[iClient] = (StringToInt(szConvarValue) == 0);
}

public OnPreThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	TryCvarQuery_RightHand(iClient);
	
	static iLauncher;
	iLauncher = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iLauncher < 1 || GetWeaponType(iLauncher) != WEAPONTYPE_RPG)
		return;
	
	if(GetEngineTime() < g_fNextAttack[iClient])
		return;
	
	static iButtons;
	iButtons = GetClientButtons(iClient);
	if(iButtons & IN_ATTACK)
	{
		if(TryShootRocket(iClient, iLauncher))
			return;
	}
	
	if(g_bIsReloading[iClient])
	{
		if(!CanReload(iClient, iLauncher))
		{
			StopReloading(iClient);
		}
		else if(GetEngineTime() >= g_fReloadEndTime[iClient])
		{
			FinishReloading(iClient, iLauncher);
		}
	}
	else
	{
		if(CanReload(iClient, iLauncher))
			StartReloading(iClient);
	}
}

bool:TryShootRocket(iClient, iLauncher)
{
	new iClipCount = GetClipCount(iLauncher);
	if(iClipCount < 1)
	{
		// TODO: Play out of ammo sound.
		return false;
	}
	
	return ShootRocket(iClient, iLauncher, iClipCount);
}

bool:ShootRocket(iClient, iLauncher, iClipCount)
{
	new iRocket = CreateRocket(iClient);
	if(!iRocket)
		return false;
	
	decl Float:fEyeAngles[3];
	GetClientEyeAngles(iClient, fEyeAngles);
	
	decl Float:fForward[3], Float:fRight[3], Float:fUp[3];
	GetAngleVectors(fEyeAngles, fForward, fRight, fUp);
	
	// Get the rockets spawn origin.
	decl Float:fEyePos[3], Float:fSpawnOrigin[3];
	GetClientEyePosition(iClient, fEyePos);
	
	// Negate the right if client is using cl_righthand 0
	if(g_bUsingLeftHand[iClient])
	{
		fRight[0] *= -1.0;
		fRight[1] *= -1.0;
		fRight[2] *= -1.0;
	}
	
	fSpawnOrigin[0] = fEyePos[0] + (fForward[0] * WEAPON_OFFSET_FORWARD) + (fRight[0] * WEAPON_OFFSET_RIGHT) + (fUp[0] * WEAPON_OFFSET_UP);
	fSpawnOrigin[1] = fEyePos[1] + (fForward[1] * WEAPON_OFFSET_FORWARD) + (fRight[1] * WEAPON_OFFSET_RIGHT) + (fUp[1] * WEAPON_OFFSET_UP);
	fSpawnOrigin[2] = fEyePos[2] + (fForward[2] * WEAPON_OFFSET_FORWARD) + (fRight[2] * WEAPON_OFFSET_RIGHT) + (fUp[2] * WEAPON_OFFSET_UP);
	
	// Get the rockets velocity.
	TR_TraceRayFilter(fEyePos, fEyeAngles, MASK_SHOT, RayType_Infinite, TraceFilter_DontHitPlayers);
	
	decl Float:fVelocity[3];
	TR_GetEndPosition(fVelocity);
	MakeVectorFromPoints(fSpawnOrigin, fVelocity, fVelocity);
	GetVectorAngles(fVelocity, fVelocity);
	
	GetAngleVectors(fVelocity, fVelocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVelocity, GetConVarFloat(cvar_rocket_speed));
	
	TeleportEntity(iRocket, fSpawnOrigin, fEyeAngles, fVelocity);
	
	// Rocket sound.
	new iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(g_bShowToSelfOnly[iClient])
	{
		if(iWeapon > 0)
			EmitSoundToClientAny(iClient, SOUND_ROCKET_SHOOT[6], iWeapon, SNDCHAN_BODY);
		else
			EmitSoundToClientAny(iClient, SOUND_ROCKET_SHOOT[6], SOUND_FROM_WORLD, _, _, _, _, _, _, fSpawnOrigin);
	}
	else
	{
		if(iWeapon > 0)
			EmitSoundToAllAny(SOUND_ROCKET_SHOOT[6], iWeapon, SNDCHAN_BODY, SNDLEVEL_NORMAL);
		else
			EmitAmbientSoundAny(SOUND_ROCKET_SHOOT[6], fSpawnOrigin, _, SNDLEVEL_NORMAL);
	}
	
	// Remove ammo.
	if(!g_bHasUnlimitedAmmo_Clip[iClient])
		SetClipCount(iLauncher, iClipCount - 1);
	
	g_fNextAttack[iClient] = GetEngineTime() + GetConVarFloat(cvar_attack_delay_attack);
	
	// Stop reloading before playing the shooting sequence.
	StopReloading(iClient);
	SetSequence(iClient, GetNextSequence_Shoot(iClient));
	
	return true;
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}

CreateRocket(iClient)
{
	new iRocket = CreateEntityByName("smokegrenade_projectile");
	if(iRocket < 1 || !IsValidEntity(iRocket))
		return 0;
	
	InitRocket(iClient, iRocket);
	return iRocket;
}

InitRocket(iClient, iRocket)
{
	DispatchSpawn(iRocket);
	
	SetEntityModel(iRocket, MODEL_ROCKET); // WARNING: Make sure we set the rockets model *before* setting the mins/maxs.
	
	SetEntityMoveType(iRocket, MOVETYPE_FLY);
	SetEntProp(iRocket, Prop_Send, "m_CollisionGroup", ROCKET_COLLISION_GROUP);
	SetEntProp(iRocket, Prop_Data, "m_nSolidType", SOLID_NONE);
	SetEntProp(iRocket, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER | (GetConVarBool(cvar_rocket_passthrough_players) ? 0 : FSOLID_USE_TRIGGER_BOUNDS));
	SetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity", iClient);
	
	SetEntProp(iRocket, Prop_Data, "m_nSurroundType", USE_SPECIFIED_BOUNDS);
	SetEntPropFloat(iRocket, Prop_Data, "m_flRadius", 0.0);
	SetEntProp(iRocket, Prop_Data, "m_triggerBloat", 0);
	
	SetEntPropVector(iRocket, Prop_Send, "m_vecMins", g_fRocketMins);
	SetEntPropVector(iRocket, Prop_Send, "m_vecMaxs", g_fRocketMaxs);
	
	SetEntPropVector(iRocket, Prop_Send, "m_vecSpecifiedSurroundingMins", g_fRocketMins);
	SetEntPropVector(iRocket, Prop_Send, "m_vecSpecifiedSurroundingMaxs", g_fRocketMaxs);
	
	SetEntPropVector(iRocket, Prop_Data, "m_vecSurroundingMins", g_fRocketMins);
	SetEntPropVector(iRocket, Prop_Data, "m_vecSurroundingMaxs", g_fRocketMaxs);
	
	SDKHook(iRocket, SDKHook_StartTouchPost, OnStartTouchPost);
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		if(g_bShowToSelfOnly[iClient])
		{
			new iSendToClients[1];
			iSendToClients[0] = iClient;
			PM_CreateEntityEffectFollow(iRocket, PEFFECT_ROCKET_TRAIL, 1, _, iSendToClients, 1);
		}
		else
		{
			PM_CreateEntityEffectFollow(iRocket, PEFFECT_ROCKET_TRAIL, 1);
		}
		#endif
	}
	
	PlaySound_RocketFly(iRocket);
}

PlaySound_RocketFly(iRocket, iFlags=SND_NOFLAGS)
{
	new iOwner = GetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity");
	if(!(1 <= iOwner <= MaxClients) || !IsClientInGame(iOwner))
		return;
	
	if(g_bShowToSelfOnly[iOwner])
		EmitSoundToClientAny(iOwner, SOUND_ROCKET_FLY[6], iRocket, SNDCHAN_BODY, SNDLEVEL_NORMAL, iFlags, _, 10);
	else
		EmitSoundToAllAny(SOUND_ROCKET_FLY[6], iRocket, SNDCHAN_BODY, SNDLEVEL_NORMAL, iFlags, _, 10);
}

PlaySound_Explode(iRocket)
{
	new iOwner = GetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity");
	if(!(1 <= iOwner <= MaxClients) || !IsClientInGame(iOwner))
		return;
	
	decl Float:fOrigin[3];
	GetEntPropVector(iRocket, Prop_Send, "m_vecOrigin", fOrigin);
	
	if(g_bShowToSelfOnly[iOwner])
		EmitSoundToClientAny(iOwner, SOUND_ROCKET_EXPLODE[GetRandomInt(0, sizeof(SOUND_ROCKET_EXPLODE)-1)][6], SOUND_FROM_WORLD, _, 90, _, _, GetRandomInt(85, 120), _, fOrigin);
	else
		EmitAmbientSoundAny(SOUND_ROCKET_EXPLODE[GetRandomInt(0, sizeof(SOUND_ROCKET_EXPLODE)-1)][6], fOrigin, _, 90, _, _, GetRandomInt(85, 120));
}

public OnStartTouchPost(iRocket, iOther)
{
	new iOwner = GetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity");
	if(iOwner == iOther)
		return;
	
	decl Float:fRocketOrigin[3];
	GetEntPropVector(iRocket, Prop_Data, "m_vecOrigin", fRocketOrigin);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		TryPushClient(iOwner, iClient, iRocket, (iClient == iOther));
	}
	
	DrawExplosion(iOwner, iRocket, (1 <= iOther <= MaxClients));
	RemoveRocket(iRocket);
}

RemoveRocket(iRocket)
{
	PlaySound_RocketFly(iRocket, SND_STOPLOOPING | SND_STOP);
	PlaySound_Explode(iRocket);
	
	TeleportEntity(iRocket, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	AcceptEntityInput(iRocket, "KillHierarchy");
}

DrawExplosion(iOwner, iRocket, bool:bDrawAtRocketOrigin)
{
	if(!(1 <= iOwner <= MaxClients) || !IsClientInGame(iOwner))
		return;
	
	decl Float:fVector[3];
	
	if(bDrawAtRocketOrigin)
	{
		GetEntPropVector(iRocket, Prop_Data, "m_vecOrigin", fVector);
	}
	else
	{
		// Pull the rockets origin back a bit so we can trace a line towards the wall it hit.
		decl Float:fOrigin[3], Float:fForward[3];
		GetEntPropVector(iRocket, Prop_Data, "m_vecOrigin", fOrigin);
		GetEntPropVector(iRocket, Prop_Data, "m_vecVelocity", fForward);
		NormalizeVector(fForward, fForward);
		
		fOrigin[0] -= (fForward[0] * 2.0);
		fOrigin[1] -= (fForward[1] * 2.0);
		fOrigin[2] -= (fForward[2] * 2.0);
		
		// Trace a line towards the wall.
		GetVectorAngles(fForward, fVector);
		TR_TraceRayFilter(fOrigin, fVector, MASK_SHOT, RayType_Infinite, TraceFilter_DontHitPlayers);
		
		// Get the walls origin and normal, and again pull back from the wall just a little a bit.
		TR_GetEndPosition(fOrigin);
		TR_GetPlaneNormal(INVALID_HANDLE, fForward);
		ScaleVector(fForward, 1.0001);
		AddVectors(fOrigin, fForward, fVector);
		
		// Draw the decal at the pulled back position.
		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin", fVector);
		TE_WriteNum("m_nIndex", g_iDecalIndex_Explosion);
		
		if(g_bShowToSelfOnly[iOwner])
			TE_SendToClient(iOwner);
		else
			TE_SendToAll();
		
		// Create the explosion effect.
		ScaleVector(fForward, 7.5);
		AddVectors(fOrigin, fForward, fVector);
	}
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		if(g_bShowToSelfOnly[iOwner])
		{
			new iSendToClients[1];
			iSendToClients[0] = iOwner;
			PM_CreateEntityEffectCustomOrigin(0, PEFFECT_ROCKET_EXPLODE, fVector, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0}, _, iSendToClients, 1);
		}
		else
		{
			PM_CreateEntityEffectCustomOrigin(0, PEFFECT_ROCKET_EXPLODE, fVector, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
		}
		#endif
	}
}

TryPushClient(iOwner, iClient, iRocket, bool:bIsDirectHit)
{
	// WARNING: Make sure the rockets mins/maxs are always smaller than the players mins/maxs.
	// If the players mins/maxs are smaller that means the rocket can actually suck the player towards it instead of away.
	
	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return;
	
	// Add the center of the mins/maxs to the rocket origin.
	decl Float:fRocketOrigin[3], Float:fRocketMins[3], Float:fRocketMaxs[3];
	GetEntPropVector(iRocket, Prop_Data, "m_vecOrigin", fRocketOrigin);
	GetEntPropVector(iRocket, Prop_Send, "m_vecMins", fRocketMins);
	GetEntPropVector(iRocket, Prop_Send, "m_vecMaxs", fRocketMaxs);
	
	fRocketOrigin[0] = fRocketOrigin[0] + ((fRocketMins[0] + fRocketMaxs[0]) * 0.5);
	fRocketOrigin[1] = fRocketOrigin[1] + ((fRocketMins[1] + fRocketMaxs[1]) * 0.5);
	fRocketOrigin[2] = fRocketOrigin[2] + ((fRocketMins[2] + fRocketMaxs[2]) * 0.5);
	
	// Add the center of the mins/maxs to the client origin.
	decl Float:fClientOrigin[3], Float:fCheckClientOrigin[3], Float:fEyePos[3], Float:fClientMins[3], Float:fClientMaxs[3];
	GetClientAbsOrigin(iClient, fClientOrigin);
	GetClientAbsOrigin(iClient, fCheckClientOrigin);
	GetClientEyePosition(iClient, fEyePos);
	GetEntPropVector(iClient, Prop_Send, "m_vecMins", fClientMins);
	GetEntPropVector(iClient, Prop_Send, "m_vecMaxs", fClientMaxs);
	
	// Need to see if maxs or eye postion is lower. Use the smaller of the 2 for maxs
	if(fClientOrigin[2] + fClientMaxs[2] > fEyePos[2])
		fClientMaxs[2] = fEyePos[2] - fClientOrigin[2];
	
	// Get the origin we will check distance against.
	fCheckClientOrigin[0] = fCheckClientOrigin[0] + ((fClientMins[0] + fClientMaxs[0]) * 0.5);
	fCheckClientOrigin[1] = fCheckClientOrigin[1] + ((fClientMins[1] + fClientMaxs[1]) * 0.5);
	
	if(fCheckClientOrigin[2] + fClientMaxs[2] < fRocketOrigin[2])
	{
		// The rocket is above the clients height. Set the clients origin to their height.
		fCheckClientOrigin[2] = fCheckClientOrigin[2] + fClientMaxs[2];
	}
	else if(fCheckClientOrigin[2] + fClientMins[2] > fRocketOrigin[2])
	{
		// The rocket is below the clients feet. Set the clients origin to their feet.
		fCheckClientOrigin[2] = fCheckClientOrigin[2] + fClientMins[2];
	}
	else
	{
		// The rocket is somewhere along the players body. Set the clients origin at their midpoint.
		fCheckClientOrigin[2] = fCheckClientOrigin[2] + ((fClientMins[2] + fClientMaxs[2]) * 0.5);
	}
	
	// Get the origin we will push from.
	fClientOrigin[0] = fClientOrigin[0] + ((fClientMins[0] + fClientMaxs[0]) * 0.5);
	fClientOrigin[1] = fClientOrigin[1] + ((fClientMins[1] + fClientMaxs[1]) * 0.5);
	fClientOrigin[2] = fClientOrigin[2] + ((fClientMins[2] + fClientMaxs[2]) * 0.5);
	
	// Make sure the client is in pushing distance of the rocket.
	new Float:fDist = GetVectorDistance(fCheckClientOrigin, fRocketOrigin);
	if(fDist > GetConVarFloat(cvar_push_max_distance))
		return;
	
	if(iOwner == iClient)
	{
		if(GetConVarBool(cvar_allow_damage_self))
			TryDamageClient(iOwner, iClient, fDist, bIsDirectHit);
	}
	else
	{
		if(GetConVarBool(cvar_allow_damage_others))
			TryDamageClient(iOwner, iClient, fDist, bIsDirectHit);
	}
	
	if(fDist < GetConVarFloat(cvar_push_min_distance_clamp))
		fDist = GetConVarFloat(cvar_push_min_distance_clamp);
	
	// Get the push force from the radius.
	decl Float:fDirection[3];
	MakeVectorFromPoints(fRocketOrigin, fClientOrigin, fDirection);
	NormalizeVector(fDirection, fDirection);
	
	decl Float:fPercent;
	if(bIsDirectHit)
		fPercent = 1.0;
	else
		fPercent = 1.0 - (fDist * GetConVarFloat(cvar_push_falloff_percent) / GetConVarFloat(cvar_push_max_distance));
	
	new Float:fPushForce = GetConVarFloat(cvar_push_force_base) * fPercent * GetConVarFloat(cvar_push_force_multiplier);
	
	// Make sure the push force is at least the players current speed as long as they aren't moving downwards.
	decl Float:fCurVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fCurVelocity);
	
	ScaleVector(fDirection, fPushForce);
	
	// See if the player is moving down but the push direction is up.
	new bool:bTryUpwardsPush;
	if(fCurVelocity[2] < 0.0 && fDirection[2] > 0.0)
		bTryUpwardsPush = true;
	
	// Add the players velocity to the push velocity.
	fDirection[0] += fCurVelocity[0];
	fDirection[1] += fCurVelocity[1];
	fDirection[2] += fCurVelocity[2];
	
	// If needed, make sure the push velocity is still going upwards even after adding the players velocity to the push velocity.
	if(bTryUpwardsPush && fDirection[2] < 200.0)
		fDirection[2] = 200.0;
	
	// Return if client can't be pushed.
	if(iOwner == iClient)
	{
		if(!GetConVarBool(cvar_knockback_self))
			return;
	}
	else
	{
		if(GetClientTeam(iOwner) == GetClientTeam(iClient))
		{
			if(!GetConVarBool(cvar_knockback_team))
				return;
		}
		else
		{
			if(!GetConVarBool(cvar_knockback_enemies))
				return;
		}
	}
	
	// Do push.
	if(fDirection[2] > 0.0)
		SetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity", -1);
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fDirection);
}

TryDamageClient(iOwner, iClient, const Float:fDist, bool:bIsDirectHit)
{
	if(iOwner < 1)
		return;
	
	new Float:fDamage = GetConVarFloat(cvar_base_damage) * (1.0 - (fDist / GetConVarFloat(cvar_push_max_distance)));
	
	if(iOwner == iClient)
	{
		// If damaging self we reduce the damage.
		fDamage /= 4.0;
	}
	else
	{
		// TODO: Check for friendly fire.
		if(GetClientTeam(iClient) == GetClientTeam(iOwner))
			return;
		
		if(bIsDirectHit && GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") == -1)
		{
			// Airshot
			fDamage = float(GetClientHealth(iClient));
		}
	}
	
	new iDamageRounded = RoundFloat(fDamage);
	new iNewHealth = GetClientHealth(iClient) - iDamageRounded;
	
	// Only use TakeDamage when the client is going to die since it will "tag" the player and make them walk slow when they land.
	if(iNewHealth > 0)
	{
		SetEntityHealth(iClient, iNewHealth);
		SendEvent_PlayerHurt(iClient, iOwner, iNewHealth, 0, "rpg", iDamageRounded, 0, 0);
	}
	else
	{
		SDKHooks_TakeDamage(iClient, iOwner, iOwner, fDamage + 1.0);
	}
	
	if(IsPlayerAlive(iClient))
	{
		//PlaySound_Pain(iClient);
	}
	else
	{
		//PlaySound_Death(iClient);
		
		// TODO: Play the gib particle effect.
		// -->
	}
}

SendEvent_PlayerHurt(iClient, iAttacker, iRemainingHealth, iRemainingArmor, const String:szWeaponName[], iDamageHealth, iDamageArmor, iHitGroup)
{
	new Handle:hEvent = CreateEvent("player_hurt", true);
	if(hEvent == INVALID_HANDLE)
		return;
	
	SetEventInt(hEvent, "userid", GetClientUserId(iClient));
	SetEventInt(hEvent, "attacker", GetClientUserId(iAttacker));
	
	SetEventInt(hEvent, "health", iRemainingHealth);
	SetEventInt(hEvent, "armor", iRemainingArmor);
	
	SetEventString(hEvent, "weapon", szWeaponName);
	
	SetEventInt(hEvent, "dmg_health", iDamageHealth);
	SetEventInt(hEvent, "dmg_armor", iDamageArmor);
	SetEventInt(hEvent, "hitgroup", iHitGroup);
	
	FireEvent(hEvent, true);
}