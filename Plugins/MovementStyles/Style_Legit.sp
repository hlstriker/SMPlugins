#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Plugins/ClientAirAccelerate/client_air_accelerate"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Legit";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Legit.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define USE_DEFAULT_AIRACCELERATE	-9999999.0
new Handle:cvar_legit_airaccelerate;


public OnPluginStart()
{
	CreateConVar("style_legit_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_legit_airaccelerate = FindConVar("style_legit_airaccelerate")) == INVALID_HANDLE)
	{
		new String:szDefault[16];
		FloatToString(USE_DEFAULT_AIRACCELERATE, szDefault, sizeof(szDefault));
		cvar_legit_airaccelerate = CreateConVar("style_legit_airaccelerate", szDefault, "Set to use a custom legit style sv_airaccelerate.");
	}
}

public MovementStyles_OnBitsChanged_Post(iClient, iOldBits, iNewBits)
{
	static Float:fCustomAirAccelerate;
	fCustomAirAccelerate = GetConVarFloat(cvar_legit_airaccelerate);
	
	if(fCustomAirAccelerate == USE_DEFAULT_AIRACCELERATE)
	{
		ClientAirAccel_ClearCustomValue(iClient);
		return;
	}
	
	if(iNewBits == STYLE_BIT_NONE)
		ClientAirAccel_SetCustomValue(iClient, fCustomAirAccelerate);
	else
		ClientAirAccel_ClearCustomValue(iClient);
}