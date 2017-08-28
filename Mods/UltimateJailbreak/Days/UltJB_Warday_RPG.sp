#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_engine>
#include <sdktools_stringtables>
#include <emitsoundany>
#include <sdktools_entinput>
#include <sdktools_trace>
#include <sdktools_tempents>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_last_guard"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_settings"
#include "../../../Libraries/ParticleManager/particle_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: RPG";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: RPG.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"RPG"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

#define ROCKET_SPEED	1000.0

#define PUSH_FORCE_BASE			102.0
#define PUSH_RADIUS				115.0
#define PUSH_MULTIPLIER			6.0
#define PUSH_MULTIPLIER_QUAD	1.0
#define PUSH_FALLOFF_PERCENT	0.55
#define PUSH_MIN_DISTANCE		32.0

#define WEAPON_OFFSET_FORWARD	16.0
#define WEAPON_OFFSET_RIGHT		7.0
#define WEAPON_OFFSET_UP		-6.0

#define MAX_CLIP_COUNT	4

#define SOLID_BBOX	2
#define COLLISION_GROUP_PLAYER_MOVEMENT	8

#define USE_SPECIFIED_BOUNDS	3

#define ATTACK_DELAY_DEPLOY	0.5
#define ATTACK_DELAY_SHOOT	0.8
#define RELOAD_DELAY		1.25

#define GetClipCount(%1)		GetEntProp(%1, Prop_Send, "m_iClip1")
#define SetClipCount(%1,%2)		SetEntProp(%1, Prop_Send, "m_iClip1", %2)

#define SetReserveCount(%1,%2)	SetEntProp(%1, Prop_Send, "m_iPrimaryReserveAmmoCount", %2)

new const FSOLID_TRIGGER = 0x0008;
new const FSOLID_USE_TRIGGER_BOUNDS = 0x0080;

new const Float:g_fRocketMins[3] = {-0.0, -0.0, -0.0};
new const Float:g_fRocketMaxs[3] = {0.0, 0.0, 0.0};

new bool:g_bInProgress;

new g_iWeaponEntRefs[MAXPLAYERS+1];

new bool:g_bIsReloading[MAXPLAYERS+1];
new Float:g_fReloadEndTime[MAXPLAYERS+1];
new Float:g_fNextAttack[MAXPLAYERS+1];

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

new const String:SOUND_AIRSHOT[] = "sound/ui/armsrace_level_up.wav";

new const String:SOUND_ROCKET_FLY[] = "sound/ambient/machines/steam_loop_01.wav";
new const String:SOUND_ROCKET_SHOOT[] = "sound/swoobles/rocket_jumping/shoot_v1.mp3";

new const String:SOUND_DEATH[] = "sound/swoobles/rocket_jumping/death.mp3";

new const String:SOUND_PAIN[][] =
{
	"sound/swoobles/rocket_jumping/pain1.mp3",
	"sound/swoobles/rocket_jumping/pain2.mp3"
};

new const String:SOUND_ROCKET_EXPLODE[][] =
{
	"sound/swoobles/rocket_jumping/explode1.mp3"
	//"sound/swoobles/rocket_jumping/explode2.mp3",
	//"sound/swoobles/rocket_jumping/explode3.mp3",
	//"sound/swoobles/rocket_jumping/explode4.mp3"
};

new const String:DECAL_EXPLOSION[] = "decals/scorch1_subrect";
new g_iDecalIndex_Explosion;

new const String:PARTICLE_FILE_PATH[] = "particles/swoobles/defrag_v1.pcf";
new const String:PEFFECT_ROCKET_TRAIL[] = "swbs_defrag_rocket_trail";
new const String:PEFFECT_ROCKET_EXPLODE[] = "swbs_defrag_rocket_explosion";

#define SEQUENCE_IDLE			0
#define SEQUENCE_SHOOT_1		1
#define SEQUENCE_SHOOT_2		2
#define SEQUENCE_DEPLOY			4
#define SEQUENCE_RELOAD_1		5
#define SEQUENCE_RELOAD_2		9

new g_iOnSequence_Shoot[MAXPLAYERS+1];
new g_iOnSequence_Reload[MAXPLAYERS+1];

new const String:g_szBlockFallDamageSounds[][] =
{
	//"player/land.wav",
	//"player/land2.wav",
	//"player/land3.wav",
	//"player/land4.wav",
	"player/damage1.wav",
	"player/damage2.wav",
	"player/damage3.wav"
};

new Handle:cvar_rpg_max_damage;
new Handle:cvar_rpg_guard_damage_multiplier;


public OnPluginStart()
{
	CreateConVar("warday_rpg_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_rpg_max_damage = CreateConVar("ultjb_warday_rpg_max_damage", "30", "The maximum amount of damage the rpg should do.", _, true, 0.0);
	cvar_rpg_guard_damage_multiplier = CreateConVar("ultjb_warday_rpg_guard_damage_multiplier", "1.5", "The rpg damage multiplier to use for guard's damage.", _, true, 1.0);
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
	
	AddFileToDownloadsTable(SOUND_AIRSHOT);
	PrecacheSoundAny(SOUND_AIRSHOT[6]);
	
	AddFileToDownloadsTable(SOUND_DEATH);
	PrecacheSoundAny(SOUND_DEATH[6]);
	
	for(new i=0; i<sizeof(SOUND_ROCKET_EXPLODE); i++)
	{
		AddFileToDownloadsTable(SOUND_ROCKET_EXPLODE[i]);
		PrecacheSoundAny(SOUND_ROCKET_EXPLODE[i][6]);
	}
	
	for(new i=0; i<sizeof(SOUND_PAIN); i++)
	{
		AddFileToDownloadsTable(SOUND_PAIN[i]);
		PrecacheSoundAny(SOUND_PAIN[i][6]);
	}
	
	AddFileToDownloadsTable(PARTICLE_FILE_PATH);
	PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_ROCKET_TRAIL);
	PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_ROCKET_EXPLODE);
	
	g_iDecalIndex_Explosion = PrecacheDecal(DECAL_EXPLOSION, true);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_GUARDS_WEAPONS, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public UltJB_Day_OnSpawnPost(iClient)
{
	if(!g_bInProgress)
		return;
	
	ClientHooks(iClient);	
	PrepareClient(iClient);
}

ClientHooks(iClient)
{
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

ClientUnhooks(iClient)
{
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKUnhook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(iDamageType & DMG_FALL))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	for(new i=0; i<sizeof(g_szBlockFallDamageSounds); i++)
	{
		if(StrEqual(g_szBlockFallDamageSounds[i], szSample))
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public OnDayStart(iClient)
{
	//
}

public OnDayEnd(iClientEnder)
{
	if(!g_bInProgress)
		return;
	
	g_bInProgress = false;
	RemoveNormalSoundHook(OnNormalSound);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		ClientUnhooks(iClient);
		
		if(IsPlayerAlive(iClient))
			UltJB_LR_StripClientsWeapons(iClient);
	}
}

public OnFreezeEnd()
{
	g_bInProgress = true;
	AddNormalSoundHook(OnNormalSound);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
		{
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		}
		else
		{
			ClientHooks(iClient);
			
			if(IsPlayerAlive(iClient))
				PrepareClient(iClient);
		}
	}
}

PrepareClient(iClient)
{
	SetEntProp(iClient, Prop_Send, "m_ArmorValue", 0);
	SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 0);
	
	new iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
	if(iWeapon < 1)
		return 0;
	
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	g_iWeaponEntRefs[iClient] = EntIndexToEntRef(iWeapon);
	
	SetEntPropEnt(iWeapon, Prop_Data, "m_hLocker", iClient);
	SetEntProp(iWeapon, Prop_Data, "m_iPrimaryAmmoType", 8);
	
	SetClipCount(iWeapon, MAX_CLIP_COUNT);
	SetReserveCount(iWeapon, 100);
	
	OnWeaponSwitchPost(iClient, iWeapon);
	
	return iWeapon;
}

public OnPreThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	static iLauncher;
	iLauncher = GetClientsRocketLauncher(iClient);
	
	if(iLauncher < 1 || iLauncher != GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"))
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
		if(!CanReload(iLauncher))
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
		if(CanReload(iLauncher))
			StartReloading(iClient);
	}
}

bool:TryShootRocket(iClient, iLauncher)
{

	if(UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
		return false;
	
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
	
	// TODO: Negate on the right if they are using cl_righthand 0
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
	ScaleVector(fVelocity, ROCKET_SPEED);
	
	TeleportEntity(iRocket, fSpawnOrigin, fEyeAngles, fVelocity);
	
	// Rocket sound.
	new iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iWeapon > 0)
		EmitSoundToAllAny(SOUND_ROCKET_SHOOT[6], iWeapon, SNDCHAN_BODY, SNDLEVEL_NORMAL);
	else
		EmitAmbientSoundAny(SOUND_ROCKET_SHOOT[6], fSpawnOrigin, _, SNDLEVEL_NORMAL);
	
	// Remove ammo.
	SetClipCount(iLauncher, iClipCount - 1);
	g_fNextAttack[iClient] = GetEngineTime() + ATTACK_DELAY_SHOOT;
	
	// Stop reloading before playing the shooting sequence.
	StopReloading(iClient);
	SetSequence(iClient, GetNextSequence_Shoot(iClient));
	
	return true;
}

public OnWeaponSwitchPost(iClient, iWeapon)
{
	new iLauncher = GetClientsRocketLauncher(iClient);
	if(iLauncher < 1)
		return;
	
	StopReloading(iClient, false);
	
	if(iWeapon != iLauncher)
		return;
	
	new iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(iViewModel > 0)
		SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", g_iModelIndex_RocketLauncher);
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel > 0)
		SetEntProp(iWorldModel, Prop_Send, "m_nModelIndex", g_iModelIndex_RocketLauncherWorld);
	
	SetEntProp(iWeapon, Prop_Send, "m_nModelIndex", 0);
	
	OnDeploy(iClient);
}

OnDeploy(iClient)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", 99999999999.0);
	g_fNextAttack[iClient] = GetEngineTime() + ATTACK_DELAY_DEPLOY;
	
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
	g_fReloadEndTime[iClient] = GetEngineTime() + RELOAD_DELAY;
	
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
}

bool:CanReload(iLauncher)
{
	new iClipCount = GetClipCount(iLauncher);
	if(iClipCount >= MAX_CLIP_COUNT)
		return false;
	
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
	SetEntProp(iRocket, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER_MOVEMENT);
	SetEntProp(iRocket, Prop_Data, "m_nSolidType", SOLID_BBOX);
	SetEntProp(iRocket, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER | FSOLID_USE_TRIGGER_BOUNDS);
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
	
	PM_CreateEntityEffectFollow(iRocket, PEFFECT_ROCKET_TRAIL, 1);
	PlaySound_RocketFly(iRocket);
}

PlaySound_RocketFly(iEnt, iFlags=SND_NOFLAGS)
{
	EmitSoundToAllAny(SOUND_ROCKET_FLY[6], iEnt, SNDCHAN_BODY, SNDLEVEL_NORMAL, iFlags, _, 10);
}

PlaySound_Explode(iEnt)
{
	decl Float:fOrigin[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
	
	EmitAmbientSoundAny(SOUND_ROCKET_EXPLODE[GetRandomInt(0, sizeof(SOUND_ROCKET_EXPLODE)-1)][6], fOrigin, _, 90, _, _, GetRandomInt(85, 120));
}

PlaySound_Pain(iEnt)
{
	EmitSoundToAllAny(SOUND_PAIN[GetRandomInt(0, sizeof(SOUND_PAIN)-1)][6], iEnt, SNDCHAN_WEAPON, _, _, _, GetRandomInt(85, 120));
}

PlaySound_Death(iEnt)
{
	EmitSoundToAllAny(SOUND_DEATH[6], iEnt, SNDCHAN_WEAPON, _, _, _, GetRandomInt(85, 120));
}

PlaySound_Airshot(iClient)
{
	EmitSoundToClientAny(iClient, SOUND_AIRSHOT[6], _, _, SNDLEVEL_NONE);
}

public OnStartTouchPost(iRocket, iOther)
{
	new iOwner = GetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity");
	if(iOwner == iOther)
		return;
		
	if((1 <= iOther <= MaxClients) && (UltJB_LR_GetLastRequestFlags(iOther) & LR_FLAG_FREEDAY))
		return;
	
	decl Float:fRocketOrigin[3];
	GetEntPropVector(iRocket, Prop_Data, "m_vecOrigin", fRocketOrigin);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		TryPushClient(iClient, iRocket, (iClient == iOther));
	}
	
	DrawExplosion(iRocket, (1 <= iOther <= MaxClients));
	RemoveRocket(iRocket);
}

RemoveRocket(iRocket)
{
	PlaySound_RocketFly(iRocket, SND_STOPLOOPING | SND_STOP);
	PlaySound_Explode(iRocket);
	
	TeleportEntity(iRocket, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	AcceptEntityInput(iRocket, "KillHierarchy");
}

DrawExplosion(iRocket, bool:bDrawAtRocketOrigin)
{
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
		TE_SendToAll();
		
		// Create the explosion effect.
		ScaleVector(fForward, 7.5);
		AddVectors(fOrigin, fForward, fVector);
	}
	
	PM_CreateEntityEffectCustomOrigin(0, PEFFECT_ROCKET_EXPLODE, fVector, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
}

TryPushClient(iClient, iRocket, bool:bIsDirectHit)
{
	// WARNING: Make sure the rockets mins/maxs are always smaller than the players mins/maxs.
	// If the players mins/maxs are smaller that means the rocket can actually suck the player towards it instead of away.
	
	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return;
	
	if(UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
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
	if(fDist > PUSH_RADIUS)
		return;
	
	TryDamageClient(iClient, iRocket, fDist, bIsDirectHit);
	
	if(fDist < PUSH_MIN_DISTANCE)
		fDist = PUSH_MIN_DISTANCE;
	
	// Get the push force from the radius.
	decl Float:fDirection[3];
	MakeVectorFromPoints(fRocketOrigin, fClientOrigin, fDirection);
	NormalizeVector(fDirection, fDirection);
	
	decl Float:fPercent;
	if(bIsDirectHit)
		fPercent = 1.0;
	else
		fPercent = 1.0 - (fDist * PUSH_FALLOFF_PERCENT / PUSH_RADIUS);
	
	new Float:fPushForce = PUSH_FORCE_BASE * fPercent * PUSH_MULTIPLIER * PUSH_MULTIPLIER_QUAD;
	
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
	
	if(fDirection[2] > 0.0)
		SetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity", -1);
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fDirection);
}

TryDamageClient(iClient, iRocket, const Float:fDist, bool:bIsDirectHit)
{
	new iOwner = GetEntPropEnt(iRocket, Prop_Send, "m_hOwnerEntity");
	if(iOwner < 1)
		return;
	
	new Float:fDamage = GetConVarFloat(cvar_rpg_max_damage) * (1.0 - (fDist / PUSH_RADIUS));
	
	if(iOwner == iClient)
	{
		fDamage /= 4.0;
	}
	else
	{
		if(GetClientTeam(iClient) == GetClientTeam(iOwner))
			return;
		
		if(bIsDirectHit && GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") == -1)
		{
			fDamage = float(GetClientHealth(iClient));
			
			PrintHintText(iClient, "<font size='25' color='#FF6600'>AIRSHOT!\nBy: %N</font>", iOwner);
			PrintHintText(iOwner, "<font size='25' color='#BFFF00'>AIRSHOT!\nOn: %N</font>", iClient);
			
			PlaySound_Airshot(iOwner);
		}
		else if(GetClientTeam(iOwner) == TEAM_GUARDS)
		{
			fDamage *= GetConVarFloat(cvar_rpg_guard_damage_multiplier);
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
		PlaySound_Pain(iClient);
	}
	else
	{
		PlaySound_Death(iClient);
		
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
	
	new iSerial = UltJB_LastGuard_GetLastGuard();
	if((iSerial != 0) && (GetClientTeam(iAttacker) == TEAM_GUARDS))
		UltJB_LastGuard_ResetDamageCounters();
}

GetClientsRocketLauncher(iClient)
{
	return EntRefToEntIndex(g_iWeaponEntRefs[iClient]);
}