#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Sideways Bhop Only";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Sideways Bhop Only.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_sideways_bhop_only_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(STYLE_ID_SIDEWAYS_BHOP_ONLY, STYLE_BIT_SIDEWAYS_BHOP_ONLY, "Sideways", OnActivated, OnDeactivated, 65);
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
	
	if(GetEntityFlags(iClient) & FL_ONGROUND)
		return Plugin_Continue;
	
	fVel[1] = 0.0;
	
	return Plugin_Changed;
}