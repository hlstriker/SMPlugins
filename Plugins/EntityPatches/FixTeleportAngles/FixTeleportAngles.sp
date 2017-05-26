#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Fix Teleport Angles";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Fixes the angles of teleport destinations.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("fix_teleport_angles_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
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
	while((iEnt = FindEntityByClassname(iEnt, "trigger_teleport")) != -1)
		PatchEntity(iEnt);
}

PatchEntity(iEnt)
{
	decl String:szLandmark[256];
	GetEntPropString(iEnt, Prop_Data, "m_iLandmark", szLandmark, sizeof(szLandmark));
	
	// Return if the landmark string isn't blank (that means it's a seamless teleport and we don't want to set the angles.)
	if(szLandmark[0])
		return;
	
	SetEntProp(iEnt, Prop_Data, "m_bUseLandmarkAngles", 1);
}