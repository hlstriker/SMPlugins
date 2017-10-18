#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Low Gravity";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Low Gravity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_LOW_GRAVITY
#define THIS_STYLE_NAME			"Low Grav"
#define THIS_STYLE_NAME_AUTO	"Low Grav + Auto Bhop"
#define THIS_STYLE_ORDER		50

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

#define LOW_GRAVITY_VALUE	0.5
new bool:g_bActivated[MAXPLAYERS+1];

new bool:g_bUsingCustomGravity[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_low_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_add_autobhop = CreateConVar("style_lowgravity_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_lowgravity_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
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