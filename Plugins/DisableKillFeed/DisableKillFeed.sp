#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Disable Kill Feed";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables the kill feed.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("disable_kill_feed_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	SetEventBroadcast(hEvent, true);
	return Plugin_Continue;
}