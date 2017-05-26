#include <sourcemod>
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Freeday: Classic";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Freeday: Classic.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Classic"
new const DayType:DAY_TYPE = DAY_TYPE_FREEDAY;


public OnPluginStart()
{
	CreateConVar("freeday_classic_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS, OnDayStart);
}

public OnDayStart(iClient)
{
	//
}