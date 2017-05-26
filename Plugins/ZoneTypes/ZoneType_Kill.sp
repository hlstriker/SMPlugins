#include <sourcemod>
#include <sdktools_functions>
#include "../../Libraries/ZoneManager/zone_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Kill";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of kill.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Kill";


public OnPluginStart()
{
	CreateConVar("zone_type_kill_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_KILL, SZ_ZONE_TYPE_NAME, _, OnStartTouch);
}

public OnStartTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	if(!IsPlayerAlive(iOther))
		return;
	
	ForcePlayerSuicide(iOther);
}