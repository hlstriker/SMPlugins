#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Plugins/ClientAirAccelerate/client_air_accelerate"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Legit";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Legit.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define USE_DEFAULT_AIRACCELERATE	-1.0
new Handle:cvar_custom_airaccelerate;


public OnPluginStart()
{
	CreateConVar("style_legit_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	new String:szDefault[4];
	FloatToString(USE_DEFAULT_AIRACCELERATE, szDefault, sizeof(szDefault));
	cvar_custom_airaccelerate = CreateConVar("style_legit_airaccel", szDefault, "Set to use a custom sv_airaccelerate for this style.");
}

public MovementStyles_OnBitsChanged_Post(iClient, iOldBits, iNewBits)
{
	static Float:fCustomAirAccelerate;
	fCustomAirAccelerate = GetConVarFloat(cvar_custom_airaccelerate);
	
	if(fCustomAirAccelerate == USE_DEFAULT_AIRACCELERATE || iNewBits != STYLE_BIT_NONE)
	{
		ClientAirAccel_ClearCustomValue(iClient);
		return;
	}
	
	ClientAirAccel_SetCustomValue(iClient, fCustomAirAccelerate);
}