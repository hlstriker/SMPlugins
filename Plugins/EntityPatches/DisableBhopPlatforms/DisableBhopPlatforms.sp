#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Disable Bhop Platforms";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables platforms from moving when a player jumps on them.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const SPAWNFLAG_STARTS_LOCKED = (1<<7);


public OnPluginStart()
{
	CreateConVar("disable_bhop_plats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
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
	while((iEnt = FindEntityByClassname(iEnt, "func_door")) != -1)
		PatchEntity(iEnt);
}

PatchEntity(iEnt)
{
	decl Float:fMoveDir[3];
	GetEntPropVector(iEnt, Prop_Data, "m_vecMoveDir", fMoveDir);
	
	if(fMoveDir[2] != -1.0)
		return;
	
	SetEntProp(iEnt, Prop_Data, "m_spawnflags", SPAWNFLAG_STARTS_LOCKED);
}