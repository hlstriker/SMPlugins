#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: High FOV";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Style: High FOV",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_HIGH_FOV
#define THIS_STYLE_NAME			"High FOV"
#define THIS_STYLE_NAME_AUTO	"High FOV + Auto Bhop"
#define THIS_STYLE_ORDER		150

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_high_fov_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_add_autobhop = CreateConVar("style_highfov_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_highfov_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
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
	SetFOV(iClient, 140);
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
	ResetView(iClient);
}

SetFOV(iClient, iFOV)
{
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFOV);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFOV);
}

ResetView(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_iFOV", 0);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", 90);
}
