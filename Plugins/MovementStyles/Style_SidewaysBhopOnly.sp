#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Plugins/ClientAirAccelerate/client_air_accelerate"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Sideways Bhop Only";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Sideways Bhop Only.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_SIDEWAYS_BHOP_ONLY
#define THIS_STYLE_NAME			"Sideways"
#define THIS_STYLE_NAME_AUTO	"Sideways + Auto Bhop"
#define THIS_STYLE_ORDER		65

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

#define USE_DEFAULT_AIRACCELERATE	-1.0
new Handle:cvar_custom_airaccelerate;
new Handle:cvar_custom_airaccelerate_autobhop;

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_sideways_bhop_only_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_add_autobhop = CreateConVar("style_sideways_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_sideways_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
	
	new String:szDefault[4];
	FloatToString(USE_DEFAULT_AIRACCELERATE, szDefault, sizeof(szDefault));
	cvar_custom_airaccelerate = CreateConVar("style_sideways_airaccel", szDefault, "Set to use a custom sv_airaccelerate for this style.");
	cvar_custom_airaccelerate_autobhop = CreateConVar("style_sideways_airaccel_autobhop", szDefault, "Set to use a custom sv_airaccelerate for this style's auto-bhop variant.");
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_sideways");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_sw");
}

public MovementStyles_OnRegisterMultiReady()
{
	if(GetConVarBool(cvar_add_autobhop) && !GetConVarBool(cvar_force_autobhop))
		MovementStyles_RegisterMultiStyle(THIS_STYLE_BIT | STYLE_BIT_AUTO_BHOP, THIS_STYLE_NAME_AUTO, THIS_STYLE_ORDER + 1);
}

public MovementStyles_OnBitsChanged(iClient, iOldBits, &iNewBits)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(iNewBits != THIS_STYLE_BIT)
		return;
	
	iNewBits = TryForceAutoBhopBits(iNewBits);
}

public Action:MovementStyles_OnMenuBitsChanged(iClient, iBitsBeingToggled, bool:bBeingToggledOn, &iExtraBitsToForceOn)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(!bBeingToggledOn || iBitsBeingToggled != THIS_STYLE_BIT)
		return;
	
	iExtraBitsToForceOn = TryForceAutoBhopBits(iExtraBitsToForceOn);
}

TryForceAutoBhopBits(iBits)
{
	if(!GetConVarBool(cvar_force_autobhop))
		return iBits;
	
	return (iBits | STYLE_BIT_AUTO_BHOP);
}

public MovementStyles_OnBitsChanged_Post(iClient, iOldBits, iNewBits)
{
	static Float:fCustomAirAccelerate;
	
	if(iNewBits == THIS_STYLE_BIT)
	{
		fCustomAirAccelerate = GetConVarFloat(cvar_custom_airaccelerate);
	}
	else if(iNewBits == (THIS_STYLE_BIT | STYLE_BIT_AUTO_BHOP))
	{
		fCustomAirAccelerate = GetConVarFloat(cvar_custom_airaccelerate_autobhop);
	}
	else
	{
		ClientAirAccel_ClearCustomValue(iClient);
		return;
	}
	
	if(fCustomAirAccelerate == USE_DEFAULT_AIRACCELERATE)
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
	
	if(GetEntityFlags(iClient) & FL_ONGROUND)
		return Plugin_Continue;
	
	fVel[1] = 0.0;
	
	return Plugin_Changed;
}