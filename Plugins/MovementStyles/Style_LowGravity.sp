#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Low Gravity";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Low Gravity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LOW_GRAVITY_VALUE	0.5
new bool:g_bActivated[MAXPLAYERS+1];

new bool:g_bUsingCustomGravity[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_low_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(STYLE_ID_LOW_GRAVITY, STYLE_BIT_LOW_GRAVITY, "Low Grav", OnActivated, OnDeactivated, 50);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
	g_bUsingCustomGravity[iClient] = false;
	
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
	
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	SetEntityGravity(iClient, 1.0);
}

public OnPostThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	static Float:fGravity;
	fGravity = GetEntityGravity(iClient);
	
	if(fGravity == 1.0 || fGravity == 0.0) // When on ladders the gravity is set to 0.0 and never resets to 1.0. It seems to be normal gravity at 0.0 as well.
	{
		g_bUsingCustomGravity[iClient] = false;
	}
	else if(fGravity != LOW_GRAVITY_VALUE)
	{
		g_bUsingCustomGravity[iClient] = true;
	}
	
	if(g_bUsingCustomGravity[iClient])
		return;
	
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
}