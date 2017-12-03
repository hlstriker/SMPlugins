#include <sourcemod>
#include <sdktools_entinput>
#include "../../../Libraries/EntityHooker/entity_hooker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Open Areaportals";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Force opens areaportals.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("open_areaportals_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_OPEN_AREAPORTALS, "Open areaportals", "func_areaportal");
	EntityHooker_RegisterProperty(EH_TYPE_OPEN_AREAPORTALS, Prop_Send, PropField_String, "m_iName");
	EntityHooker_RegisterProperty(EH_TYPE_OPEN_AREAPORTALS, Prop_Data, PropField_String, "m_target");
	EntityHooker_RegisterProperty(EH_TYPE_OPEN_AREAPORTALS, Prop_Data, PropField_String, "m_iParent");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_OPEN_AREAPORTALS)
		return;
	
	AcceptEntityInput(iEnt, "Open");
}