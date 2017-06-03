#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Fix Round End Classnames";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Fixes a crash for maps that change a client's classname.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("fix_round_end_classnames_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
}

public Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SetEntPropString(iClient, Prop_Data, "m_iClassname", "player");
	}
}