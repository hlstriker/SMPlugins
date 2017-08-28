#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Taser";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "Warday: Taser.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Taser"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new Handle:g_hTaserTime;

public OnPluginStart()
{
	CreateConVar("warday_taser_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	g_hTaserTime = FindConVar("mp_taser_recharge_time");
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, _, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	SetConVarInt(g_hTaserTime, 15);
	StripWeapons();
}

public OnDayEnd(iClient)
{
	SetConVarInt(g_hTaserTime, -1);
}

StripWeapons()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		UltJB_LR_StripClientsWeapons(iClient);
	}
}

GivePlayersTasers()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_TASER);
	}
}

public OnFreezeEnd()
{
	GivePlayersTasers();
}
