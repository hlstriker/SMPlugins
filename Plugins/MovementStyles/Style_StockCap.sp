#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Stock Cap";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Smiley",
	description = "Style: Stock Cap",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_STOCK_CAP
#define THIS_STYLE_NAME			"Stock Cap"
#define THIS_STYLE_ORDER		10

new Handle:cvar_bunnyhopping;

public OnPluginStart()
{
	CreateConVar("style_stock_cap_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	cvar_bunnyhopping = FindConVar("sv_enablebunnyhopping");
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER);
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_stockcap");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_stock");
}

public OnActivated(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	SendConVarValue(iClient, cvar_bunnyhopping, "0");
}

public OnDeactivated(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	// Use the value of the server's sv_enablebunnyhopping cvar on deactivation.
	decl String:szValue[4];
	GetConVarString(cvar_bunnyhopping, szValue, sizeof(szValue));
	
	SendConVarValue(iClient, cvar_bunnyhopping, szValue);
}