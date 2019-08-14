#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../AutoBhop/auto_bhop"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Auto Bhop";
new const String:PLUGIN_VERSION[] = "3.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Auto Bhop.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_AUTO_BHOP

public OnPluginStart()
{
	CreateConVar("style_auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, "Auto Bhop", OnActivated, OnDeactivated, 5);
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_auto");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_autobhop");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_abh");
}

public OnActivated(iClient)
{
	if(IsFakeClient(iClient))
		return;

	AutoBhop_SetEnabled(iClient, true);
}

public OnDeactivated(iClient)
{
	if(IsFakeClient(iClient))
		return;

	AutoBhop_SetEnabled(iClient, false);
}
