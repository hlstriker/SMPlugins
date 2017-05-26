#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_entinput>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Remove Sparks";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Removes sparks from the maps since they can cause serious FPS lag.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define SPARK_AT_START_POS	16
#define SPARK_AT_END_POS	32
#define DECAL_AT_END_POS	64


public OnPluginStart()
{
	CreateConVar("remove_sparks_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	FindEntitiesToPatch();
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	FindEntitiesToPatch();
}

FindEntitiesToPatch()
{
	new iEnt = -1;
	//while((iEnt = FindEntityByClassname(iEnt, "env_spark")) != -1)
	//	AcceptEntityInput(iEnt, "KillHierarchy");
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "env_laser")) != -1)
		PatchBeam(iEnt);
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "env_beam")) != -1)
		PatchBeam(iEnt);
}

PatchBeam(iEnt)
{
	new iFlags = GetEntProp(iEnt, Prop_Data, "m_spawnflags");
	iFlags &= ~SPARK_AT_START_POS;
	iFlags &= ~SPARK_AT_END_POS;
	iFlags &= ~DECAL_AT_END_POS;
	
	SetEntProp(iEnt, Prop_Data, "m_spawnflags", iFlags);
}