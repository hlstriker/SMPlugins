#include <sourcemod>

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

public OnPluginStart() {
	RegAdminCmd("sm_nc", Command_Noclip);
	RegAdminCmd("sm_p", Command_Noclip);
}

public Action:Command_Noclip(iClient, iArgs) {
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
	return Plugin_Handled;
}
