#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Freeday: Auto Bhop";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Freeday: Auto Bhop.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Auto Bhop"
new const DayType:DAY_TYPE = DAY_TYPE_FREEDAY;

new Handle:g_hAutoBhop;

public OnPluginStart()
{
	CreateConVar("freeday_auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hAutoBhop = FindConVar("sv_autobunnyhopping");
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS, OnDayStart, OnDayEnd);
}

public OnDayStart(iClient)
{
	SetConVarInt(g_hAutoBhop, 1);
}

public OnDayEnd(iClient)
{
	SetConVarInt(g_hAutoBhop, 0);
}