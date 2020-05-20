#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Plugins/ClientAirAccelerate/client_air_accelerate"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Stock Cap";
new const String:PLUGIN_VERSION[] = "1.0";
new Handle:cvar_force_autobhop;
new Handle:cvar_bunnyhopping;

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
public OnPluginStart()
{
	CreateConVar("style_stock_cap_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	cvar_force_autobhop = CreateConVar("style_stockcap_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
	cvar_bunnyhopping = FindConVar("sv_enablebunnyhopping");
}
public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, "");
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
			
	SendConVarValue(iClient, cvar_bunnyhopping, "1");		
}


