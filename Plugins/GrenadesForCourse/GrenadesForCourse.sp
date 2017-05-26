#include <sourcemod>
#include <sdkhooks>
#include <sdktools_entinput>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Grenades For Course";
new const String:PLUGIN_VERSION[] = "2.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables grenade annoyances used for course servers.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("grenade_remove_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_blind", Event_PlayerBlind_Pre, EventHookMode_Pre);
	HookEvent("smokegrenade_detonate", Event_SmokeGrenadeDetonate_Pre, EventHookMode_Pre);
}

public Event_PlayerBlind_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	SetEntPropFloat(iClient, Prop_Send, "m_flFlashDuration", 0.0);
}

public Event_SmokeGrenadeDetonate_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iEnt = GetEventInt(hEvent, "entityid");
	if(iEnt > 0)
		AcceptEntityInput(iEnt, "Kill");
}