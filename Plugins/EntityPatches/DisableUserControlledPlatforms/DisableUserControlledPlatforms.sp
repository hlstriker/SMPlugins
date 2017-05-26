#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Disable User Controlled Platforms";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables users from slowing down or speeding up platforms created by trains.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const SPAWNFLAG_NO_USER_CONTROL = (1<<1);


public OnPluginStart()
{
	CreateConVar("disable_user_controlled_plats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	FindEntitiesToEdit();
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	FindEntitiesToEdit();
}

FindEntitiesToEdit()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_tracktrain")) != -1)
		PatchEntity(iEnt);
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_tanktrain")) != -1)
		PatchEntity(iEnt);
}

PatchEntity(iEnt)
{
	new iSpawnFlags = GetEntProp(iEnt, Prop_Data, "m_spawnflags");
	iSpawnFlags |= SPAWNFLAG_NO_USER_CONTROL;
	SetEntProp(iEnt, Prop_Data, "m_spawnflags", iSpawnFlags);
}