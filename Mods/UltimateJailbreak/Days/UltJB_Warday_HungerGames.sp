#include <sourcemod>
#include <sdkhooks>
#include <emitsoundany>
#include <sdktools_functions>
#include <sdktools_entinput>
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../../../Libraries/PathPoints/path_points"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Hunger Games";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Hunger Games.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Hunger Games"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

#define FREEZE_TIME		5

new g_iThisDayID;

new Handle:cvar_mp_teammates_are_enemies;

new const String:SZ_SOUND_ALARM[] = "sound/survival/rocketalarmclose.wav";
new const String:SZ_SOUND_WEAPONBOX[] = "sound/physics/wood/wood_box_impact_hard1.wav";
new const String:SZ_SOUND_UNFREEZE[] = "sound/music/finalfight.wav";

#define SOLID_BBOX				2
#define COLLISION_GROUP_DEBRIS_TRIGGER	2

#define MODEL_WEAPON_BOX	"models/props_junk/wood_crate001a.mdl"

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;


public OnPluginStart()
{
	CreateConVar("warday_hunger_games_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	PrecacheSound(SZ_SOUND_ALARM[6]);
	PrecacheSound(SZ_SOUND_WEAPONBOX[6]);
	PrecacheSound(SZ_SOUND_UNFREEZE[6]);
	PrecacheModel(MODEL_WEAPON_BOX);
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

public UltJB_Day_OnRegisterReady()
{
	g_iThisDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE,
		DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_STRIP_PRISONERS_WEAPONS | 
		DAY_FLAG_KILL_WEAPON_EQUIPS | DAY_FLAG_DISABLE_PRISONERS_RADAR | DAY_FLAG_DISABLE_GUARDS_RADAR,
		OnDayStart, OnDayEnd, OnFreezeEnd);
	
	UltJB_Day_SetFreezeTime(g_iThisDayID, FREEZE_TIME);
	UltJB_Day_SetFreezeTeams(g_iThisDayID, FREEZE_TEAM_GUARDS | FREEZE_TEAM_PRISONERS);
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// Need at least X amount of rebels path points to activate this day.
	if(g_iThisDayID)
		UltJB_Day_SetEnabled(g_iThisDayID, (PathPoints_GetPointCount("rebels") >= 90) ? true : false);
}

public OnDayStart(iClient)
{
	if(cvar_mp_teammates_are_enemies != INVALID_HANDLE)
		SetConVarBool(cvar_mp_teammates_are_enemies, true, true);
	
	CPrintToChatAll("{red}WARNING: {lightred}Free for all activated. Kill teammates too!");
	CPrintToChatAll("{red}WARNING: {lightred}Find and run into a wooden box to get a weapon.");
	
	EmitSoundToAll(SZ_SOUND_ALARM[6], _, _, SNDLEVEL_NONE);
	
	TeleportPlayersToPoints();
	SpawnWeaponBoxes();
}

public OnDayEnd(iClient)
{
	if(cvar_mp_teammates_are_enemies != INVALID_HANDLE)
		SetConVarBool(cvar_mp_teammates_are_enemies, false, true);
}

public OnFreezeEnd()
{
	EmitSoundToAll(SZ_SOUND_UNFREEZE[6], _, _, SNDLEVEL_NONE);
}

TeleportPlayersToPoints()
{
	new iPointIndex1, iPointIndex2;
	if(!PathPoints_GetFurthestTwoPoints("rebels", iPointIndex1, iPointIndex2))
	{
		// TODO: Force end day.
		return;
	}
	
	decl Float:fOrigin[3], Float:fAngles[3];
	
	decl iClient;
	new Handle:hClients = CreateArray();
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		PushArrayCell(hClients, iClient);
	}
	
	new iNumClientsSet = 0;
	new iNumClientsInArray = GetArraySize(hClients);
	decl iIndex;
	
	while((iNumClientsInArray = GetArraySize(hClients)))
	{
		iIndex = GetRandomInt(0, iNumClientsInArray-1);
		iClient = GetArrayCell(hClients, iIndex);
		RemoveFromArray(hClients, iIndex);
		
		iNumClientsSet++;
		
		switch(iNumClientsSet)
		{
			case 1:
			{
				if(!PathPoints_GetPoint("rebels", iPointIndex1, fOrigin, fAngles))
					continue;
			}
			case 2:
			{
				if(!PathPoints_GetPoint("rebels", iPointIndex2, fOrigin, fAngles))
					continue;
			}
			default:
			{
				if(!PathPoints_GetNextFurthestPoint("rebels", iPointIndex1))
					continue;
				
				if(!PathPoints_GetPoint("rebels", iPointIndex1, fOrigin, fAngles))
					continue;
			}
		}
		
		GetClientEyeAngles(iClient, fAngles);
		fAngles[1] += GetRandomFloat(0.0, 360.0);
		TeleportEntity(iClient, fOrigin, fAngles, Float:{0.0, 0.0, 0.0});
	}
	
	CloseHandle(hClients);
}

SpawnWeaponBoxes()
{
	decl Float:fOrigin[3], Float:fAngles[3];
	
	new iNumToSpawn = RoundFloat(GetNumberClientsOnTeams() * 1.3);
	if(iNumToSpawn < 20)
		iNumToSpawn = 20;
	
	// Spawn some additional boxes if there are a lot of points on this map.
	iNumToSpawn += RoundFloat(float(PathPoints_GetPointCount("rebels")) * 0.02);
	
	decl iEnt, iPointIndex;
	for(new i=0; i<iNumToSpawn; i++)
	{
		if(!PathPoints_GetNextFurthestPoint("rebels", iPointIndex))
			break;
		
		iEnt = CreateWeaponBox();
		if(iEnt == -1)
			continue;
		
		if(!PathPoints_GetPoint("rebels", iPointIndex, fOrigin, fAngles))
			continue;
		
		fOrigin[2] += 30.0;
		
		fAngles[0] = 0.0;
		fAngles[1] += GetRandomFloat(0.0, 360.0);
		fAngles[2] = 0.0;
		TeleportEntity(iEnt, fOrigin, fAngles, Float:{0.0, 0.0, 0.0});
	}
}

GetNumberClientsOnTeams()
{
	new iCount;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) < TEAM_PRISONERS)
			continue;
		
		iCount++;
	}
	
	return iCount;
}

CreateWeaponBox()
{
	new iEnt = CreateEntityByName("breachcharge_projectile");
	if(iEnt < 1)
		return -1;
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	SetEntProp(iEnt, Prop_Send, "m_bShouldExplode", 0);
	
	SetEntityModel(iEnt, MODEL_WEAPON_BOX);
	
	SetEntityMoveType(iEnt, MOVETYPE_FLYGRAVITY);
	SetEntityGravity(iEnt, 1.0);
	
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER);
	
	SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", Float:{-15.0, -15.0, -18.0});
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", Float:{15.0, 15.0, 20.0});
	
	SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost_WeaponBox);
	
	return iEnt;
}

public OnStartTouchPost_WeaponBox(iEnt, iOther)
{
	if(!IsPlayer(iOther) || !IsPlayerAlive(iOther))
		return;
	
	SpawnWeaponEnt(iEnt);
	
	AcceptEntityInput(iEnt, "KillHierarchy");
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}

SpawnWeaponEnt(iWeaponBox)
{
	new iFlags[NUM_WPN_CATS];
	new iWeaponID = UltJB_Weapons_GetRandomWeaponFromFlags(iFlags);
	if(iWeaponID == _:CSWeapon_NONE)
		return -1;
	
	decl String:szName[64];
	if(!UltJB_Weapons_GetEntNameFromWeaponID(iWeaponID, szName, sizeof(szName)))
		return -1;
	
	new iEnt = CreateEntityByName(szName);
	if(iEnt < 1)
		return -1;
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	decl Float:fOrigin[3], Float:fAngles[3];
	GetEntPropVector(iWeaponBox, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iWeaponBox, Prop_Data, "m_angAbsRotation", fAngles);
	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	
	SetEntProp(iEnt, Prop_Send, "m_ScaleType", 0);
	SetEntPropFloat(iEnt, Prop_Send, "m_flModelScale", 2.0);
	
	EmitSoundToAll(SZ_SOUND_WEAPONBOX[6], iEnt, _, _, _, _, GetRandomInt(95, 110));
	
	return iEnt;
}