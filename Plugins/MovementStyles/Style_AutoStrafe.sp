#include <sourcemod>
#include <sdktools_functions>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../AutoStrafe/auto_strafe"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Auto Strafe";
new const String:PLUGIN_VERSION[] = "2.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Style: Auto Strafe.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_AUTO_STRAFE
#define THIS_STYLE_NAME			"Auto Strafe"
#define THIS_STYLE_NAME_AUTO	"Auto Strafe + Auto Bhop"
#define THIS_STYLE_ORDER		130

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

public OnPluginStart()
{
	CreateConVar("style_auto_strafe_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);

	cvar_add_autobhop = CreateConVar("style_autostrafe_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_autostrafe_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_autostrafe");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_as");
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

public OnActivated(iClient)
{
	AutoStrafe_SetEnabled(iClient, true);
}

public OnDeactivated(iClient)
{
	AutoStrafe_SetEnabled(iClient, false);
}
