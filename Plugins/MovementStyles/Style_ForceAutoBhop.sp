#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Force Auto Bhop";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Force Auto Bhop.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_force_auto_bhop_but_not_legit;


public OnPluginStart()
{
	CreateConVar("style_force_auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_force_auto_bhop_but_not_legit = CreateConVar("force_auto_bhop_but_not_legit", "0", "Set to 1 if you don't want to force auto bhop for the legit style.");
}

public MovementStyles_OnBitsChanged(iClient, iOldBits, &iNewBits)
{
	if(GetConVarBool(cvar_force_auto_bhop_but_not_legit))
	{
		if(iNewBits == STYLE_BIT_NONE || iNewBits == STYLE_BIT_NO_LAND_CAP)
			return;
	}
	
	iNewBits |= STYLE_BIT_AUTO_BHOP;
}

public Action:MovementStyles_OnMenuBitsChanged(iClient, iBitsBeingToggled, bool:bBeingToggledOn, &iBitsToForceMenuVisualOnly)
{
	if(GetConVarBool(cvar_force_auto_bhop_but_not_legit))
	{
		if(iBitsBeingToggled == STYLE_BIT_NO_LAND_CAP && bBeingToggledOn)
			return;
		
		new iBits = MovementStyles_GetStyleBits(iClient);
		
		if(iBitsBeingToggled == STYLE_BIT_NONE)
		{
			// Disable all is being selected.
			iBits = STYLE_BIT_NONE;
		}
		else
		{
			if(bBeingToggledOn)
				iBits |= iBitsBeingToggled;
			else
				iBits &= ~iBitsBeingToggled;
		}
		
		if(iBits == STYLE_BIT_NONE)
			return;
	}
	
	iBitsToForceMenuVisualOnly |= STYLE_BIT_AUTO_BHOP;
}