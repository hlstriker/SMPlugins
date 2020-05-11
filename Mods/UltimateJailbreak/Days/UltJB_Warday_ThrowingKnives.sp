#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_engine>
#include <sdktools_entinput>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <sdktools_sound>
#include <cstrike>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Throwing Knives";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "Warday: Throwing Knives.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Throwing Knives"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

#define KNIFE_MODEL "models/weapons/w_knife.mdl"

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;

#define SOLID_NONE 0

#define BEAM_MATERIAL "materials/sprites/laserbeam.vmt"
new g_iBeamIndex;

#define SOUND_KNIFE_HIT_WORLD "weapons/knife/knife_hitwall1.wav"
#define SOUND_KNIFE_HIT_PLAYER "weapons/knife/knife_hit1.wav"

#define KNIFE_DAMAGE 100.0


public OnPluginStart()
{
	CreateConVar("warday_throwing_knives_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_KILL_WORLD_WEAPONS, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	AddNormalSoundHook(SoundHook);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
}

public OnDayEnd(iClient)
{
	UnhookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
}

public OnMapStart()
{
	g_iBeamIndex = PrecacheModel(BEAM_MATERIAL);
	PrecacheModel(KNIFE_MODEL);
	
	PrecacheSound(SOUND_KNIFE_HIT_WORLD);
	PrecacheSound(SOUND_KNIFE_HIT_PLAYER);
}

public OnFreezeEnd()
{
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_PRISONERS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			}
			case TEAM_GUARDS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			}
		}
	}
}

public Event_WeaponFire(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	static String:szWeaponName[13];
	GetEventString(hEvent, "weapon", szWeaponName, sizeof(szWeaponName));
	
	if(strlen(szWeaponName) < 8)
		return;
	
	szWeaponName[12] = '\x0';
	
	if(!StrEqual(szWeaponName[7], "knife") && !StrEqual(szWeaponName[7], "bayon"))
		return;
	
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(ThrowKnife(iClient))
	{
		switch(GetClientTeam(iClient))
		{
			case TEAM_PRISONERS:
				SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", GetGameTime() + 1.0);
			case TEAM_GUARDS:
				SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", GetGameTime() + 1.2);
		}
	}
}

bool:ThrowKnife(iClient)
{
	new iEnt = CreateEntityByName("hegrenade_projectile");
	if(iEnt < 1)
		return false;
	
	DispatchSpawn(iEnt);
	
	SetEntityModel(iEnt, KNIFE_MODEL);
	SetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity", iClient);
	
	decl Float:fAngles[3], Float:fVelocity[3];
	GetClientEyeAngles(iClient, fAngles);
	GetAngleVectors(fAngles, fVelocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVelocity, 2250.0);
	
	SetEntPropVector(iEnt, Prop_Data, "m_vecAngVelocity", Float:{2048.0, 0.0, 0.0});
	SetEntPropFloat(iEnt, Prop_Send, "m_flElasticity", 0.2);
	
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID|FSOLID_TRIGGER);
	
	decl Float:fOrigin[3];
	GetClientEyePosition(iClient, fOrigin);
	TeleportEntity(iEnt, fOrigin, fAngles, fVelocity);
	
	SDKHook(iEnt, SDKHook_TouchPost, OnTouchPost);
	
	TE_SetupBeamFollow(iEnt, g_iBeamIndex, 0, 0.5, 2.5, 1.0, 3, {177, 177, 177, 117});
	TE_SendToAll();
	
	return true;
}

public OnTouchPost(iEnt, iOther)
{
	if(GetEntProp(iEnt, Prop_Send, "m_nSolidType") == SOLID_NONE)
		return;
	
	if(iOther == 0)
	{
		RemoveKnife(iEnt, true, false);
		return;
	}
	
	if(iOther < 1 || iOther > MaxClients)
	{
		// TODO: Make sure the entity is solid.
		RemoveKnife(iEnt, true, false);
		return;
	}
	
	// Return if the player can't take damage.
	if(GetEntProp(iOther, Prop_Data, "m_takedamage") == 0)
		return;
	
	// Return if the knife hit a teammate.
	new iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
	
	if(iOwner == -1)
		return;
	
	if(GetClientTeam(iOwner) == GetClientTeam(iOther))
		return;
	
	new iKnife = GetPlayerWeaponSlot(iOwner, CS_SLOT_KNIFE);
	
	if(iKnife < 0)
		iKnife = 0;
	
	// Hit an enemy.
	SDKHooks_TakeDamage(iOther, iKnife, iOwner, KNIFE_DAMAGE, DMG_SLASH, iKnife);
	
	RemoveKnife(iEnt, false, true);
}

RemoveKnife(iEnt, bool:bSparks, bool:bHitPlayer)
{
	// Remove the entities solid type so it can't touch other entities again.
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	if(bSparks)
	{
		decl Float:fOrigin[3], Float:fDirection[3];
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
		
		fDirection[0] = GetRandomFloat(-1.0, 1.0);
		fDirection[1] = GetRandomFloat(-1.0, 1.0);
		fDirection[2] = GetRandomFloat(-1.0, 1.0);
		
		TE_SetupSparks(fOrigin, fDirection, 1, GetRandomInt(1, 3));
		TE_SendToAll();
	}
	
	if(bHitPlayer)
	{
		EmitSoundToAll(SOUND_KNIFE_HIT_PLAYER, iEnt, SNDCHAN_BODY, 326, SND_NOFLAGS);
	}
	else
	{
		EmitSoundToAll(SOUND_KNIFE_HIT_WORLD, iEnt, SNDCHAN_BODY, 326, SND_NOFLAGS);
	}
	
	AcceptEntityInput(iEnt, "KillHierarchy");
}

public Action:SoundHook(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	if(szSample[0] == ')')
	{
		// CS:GO has the ) character before the sound path.
		if(StrEqual(szSample[1], "weapons/hegrenade/he_bounce-1.wav"))
			return Plugin_Stop;
	}
	
	return Plugin_Continue;
}