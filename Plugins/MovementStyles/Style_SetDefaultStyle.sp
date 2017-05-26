#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Set Default Style";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Set default style.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("style_set_default_style_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_SetDefaultBits(STYLE_BIT_AUTO_BHOP);
}