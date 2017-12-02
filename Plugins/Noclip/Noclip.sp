#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Noclip";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "HymnsForDisco",
	description = "Allows non-admin players to noclip",
	version = PLUGIN_VERSION,
	url = ""
}

#define SOLID_NONE	0
#define SOLID_BBOX	2


public OnPluginStart()
{
	RegConsoleCmd("sm_nc", Command_Noclip, "Toggles noclip");
	RegConsoleCmd("sm_p", Command_Noclip, "Toggles noclip");
}

public Action:Command_Noclip(iClient, iArgs)
{
	if(!IsPlayerAlive(iClient))
		return Plugin_Handled;
	
	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
	{
		SetEntProp(iClient, Prop_Send, "m_nSolidType", SOLID_BBOX);
		SetEntityMoveType(iClient, MOVETYPE_WALK);
		TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	}
	else
	{
		SetEntProp(iClient, Prop_Send, "m_nSolidType", SOLID_NONE);
		SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
	}
	
	return Plugin_Handled;
}
