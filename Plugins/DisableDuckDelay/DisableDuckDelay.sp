#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Disable duck delay";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables the delay between ducks.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

// 8.0 is max duck speed.
// 6.046875 is the duck speed after pressing the key once when already having 8 speed.
#define MINIMUM_DUCK_SPEED	6.046875


public OnPluginStart()
{
	CreateConVar("disable_duck_delay_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	new Handle:hConvar = FindConVar("sv_timebetweenducks");
	if(hConvar != INVALID_HANDLE)
	{
		HookConVarChange(hConvar, OnConVarChanged);
		SetConVarFloat(hConvar, 0.0);
	}
	
	hConvar = FindConVar("post_jump_crouch");
	if(hConvar != INVALID_HANDLE)
	{
		HookConVarChange(hConvar, OnConVarChanged);
		SetConVarFloat(hConvar, 0.0);
	}
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarFloat(hConvar, 0.0);
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(GetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed") < MINIMUM_DUCK_SPEED)
		SetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed", MINIMUM_DUCK_SPEED);
}