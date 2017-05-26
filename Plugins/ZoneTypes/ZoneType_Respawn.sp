#include <sourcemod>
#include <sdktools_functions>
#include <cstrike>
#include "../../Libraries/ZoneManager/zone_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Respawn";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of respawn.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Respawn";

enum
{
	TEAM_T = 0,
	TEAM_CT,
	NUM_TEAMS
};

#define MAX_SPAWNS	64
new g_iNumSpawns[NUM_TEAMS];
new Float:g_fSpawnOrigins[NUM_TEAMS][MAX_SPAWNS][3];
new Float:g_fSpawnAngles[NUM_TEAMS][MAX_SPAWNS][3];


public OnPluginStart()
{
	CreateConVar("zone_type_respawn_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_RESPAWN, SZ_ZONE_TYPE_NAME, _, OnStartTouch);
}

public OnMapStart()
{
	FindSpawns(TEAM_T, "info_player_terrorist");
	FindSpawns(TEAM_CT, "info_player_counterterrorist");
}

FindSpawns(iTeamNum, const String:szEntityName[])
{
	g_iNumSpawns[iTeamNum] = 0;
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, szEntityName)) != -1)
	{
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", g_fSpawnOrigins[iTeamNum][g_iNumSpawns[iTeamNum]]);
		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", g_fSpawnAngles[iTeamNum][g_iNumSpawns[iTeamNum]]);
		
		g_iNumSpawns[iTeamNum]++;
		
		if(g_iNumSpawns[iTeamNum] >= MAX_SPAWNS)
			break;
	}
}

public OnStartTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	switch(GetClientTeam(iOther))
	{
		case CS_TEAM_T:
		{
			if(!RespawnAtTeamsSpawnPoint(iOther, TEAM_T))
				RespawnAtTeamsSpawnPoint(iOther, TEAM_CT);
		}
		case CS_TEAM_CT:
		{
			if(!RespawnAtTeamsSpawnPoint(iOther, TEAM_CT))
				RespawnAtTeamsSpawnPoint(iOther, TEAM_T);
		}
	}
}

bool:RespawnAtTeamsSpawnPoint(iClient, iTeamNum)
{
	if(!g_iNumSpawns[iTeamNum])
		return false;
	
	new iSpawnNum = GetRandomInt(0, g_iNumSpawns[iTeamNum]-1);
	TeleportEntity(iClient, g_fSpawnOrigins[iTeamNum][iSpawnNum], g_fSpawnAngles[iTeamNum][iSpawnNum], Float:{0.0, 0.0, 0.0});
	
	return true;
}