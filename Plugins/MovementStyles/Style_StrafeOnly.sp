#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Plugins/ClientAirAccelerate/client_air_accelerate"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Strafe Only";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Strafe Only.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define USE_DEFAULT_AIRACCELERATE	-1.0
new Handle:cvar_custom_airaccelerate;

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_strafeonly_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	new String:szDefault[4];
	FloatToString(USE_DEFAULT_AIRACCELERATE, szDefault, sizeof(szDefault));
	cvar_custom_airaccelerate = CreateConVar("style_strafeonly_airaccel", szDefault, "Set to use a custom sv_airaccelerate for this style.");
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(STYLE_BIT_STRAFE_ONLY, "A/D-Only", OnActivated, OnDeactivated, 60);
}

public MovementStyles_OnBitsChanged_Post(iClient, iOldBits, iNewBits)
{
	static Float:fCustomAirAccelerate;
	fCustomAirAccelerate = GetConVarFloat(cvar_custom_airaccelerate);
	
	if(fCustomAirAccelerate == USE_DEFAULT_AIRACCELERATE || iNewBits != STYLE_BIT_STRAFE_ONLY)
	{
		ClientAirAccel_ClearCustomValue(iClient);
		return;
	}
	
	ClientAirAccel_SetCustomValue(iClient, fCustomAirAccelerate);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(!g_bActivated[iClient])
		return Plugin_Continue;
	
	if(!IsPlayerAlive(iClient))
		return Plugin_Continue;
	
	fVel[0] = 0.0;
	
	return Plugin_Changed;
}