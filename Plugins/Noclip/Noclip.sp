#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Noclip";
new const String:PLUGIN_VERSION[] = "1.0";

new const SOLID_NONE = 0;
new const SOLID_BBOX = 2;

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "HymnsForDisco",
	description = "Allows non-admin players to noclip",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	RegConsolenCmd("sm_nc", Command_Noclip, "sm_nc/sm_p - Toggles noclip");
	RegConsoleCmd("sm_p", Command_Noclip, "sm_nc/sm_p - Toggles noclip");
}

public Action:Command_Noclip(iClient, iArgs)
{
	if(IsPlayerAlive(iClient))
	{
		if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		{
			SetEntProp(iClient, Prop_Send, "m_nSolidType", SOLID_BBOX);
			SetEntityMoveType(iClient, MOVETYPE_WALK);
		}
		else
		{
			SetEntProp(iClient, Prop_Send, "m_nSolidType", SOLID_NONE);
			SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
		}
	}
	return Plugin_Handled;
}
