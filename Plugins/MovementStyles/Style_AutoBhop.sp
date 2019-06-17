#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Auto Bhop";
new const String:PLUGIN_VERSION[] = "2.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Auto Bhop.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_AUTO_BHOP

new bool:g_bActivated[MAXPLAYERS+1];

new Handle:cvar_autobunnyhopping;


public OnPluginStart()
{
	CreateConVar("style_auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	new Handle:hConVar = FindConVar("sv_enablebunnyhopping");
	if(hConVar != INVALID_HANDLE)
	{
		HookConVarChange(hConVar, OnConVarChanged);
		SetConVarInt(hConVar, 1);
	}
	
	cvar_autobunnyhopping = FindConVar("sv_autobunnyhopping");
	SetConVarFlags(cvar_autobunnyhopping, GetConVarFlags(cvar_autobunnyhopping) & ~FCVAR_REPLICATED);
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarInt(hConVar, 1);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, "Auto Bhop", OnActivated, OnDeactivated, 5);
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_auto");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_autobhop");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_abh");
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	if(!g_bActivated[iClient])
		SendConVarValue(iClient, cvar_autobunnyhopping, "0");
	
	SDKHook(iClient, SDKHook_PreThink, OnPreThink);
}

public OnActivated(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	g_bActivated[iClient] = true;
	SendConVarValue(iClient, cvar_autobunnyhopping, "1");
}

public OnDeactivated(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	g_bActivated[iClient] = false;
	SendConVarValue(iClient, cvar_autobunnyhopping, "0");
}

public Action:OnPreThink(iClient)
{
	if(g_bActivated[iClient])
		SetConVarBool(cvar_autobunnyhopping, true);
	else
		SetConVarBool(cvar_autobunnyhopping, false);
	
	return Plugin_Continue;
}