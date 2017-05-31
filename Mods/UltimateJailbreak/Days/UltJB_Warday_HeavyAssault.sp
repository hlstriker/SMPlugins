#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Warday: Heavy Assault";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "Warday: Heavy Assault.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Heavy Assault"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new Handle:g_hBuyAnywhere;
new Handle:g_hAllowHeavy;

public OnPluginStart()
{
	CreateConVar("warday_heavy_assault_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	g_hBuyAnywhere = FindConVar("mp_buy_anywhere");
	g_hAllowHeavy = FindConVar("mp_weapons_allow_heavyassaultsuit");
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_ALLOW_WEAPON_DROPS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	SetConVarInt(g_hAllowHeavy, 1);
	GivePlayersSuits();
	SetConVarInt(g_hBuyAnywhere, 1);
}

public OnDayEnd(iClient)
{
	SetConVarInt(g_hAllowHeavy, 0);
}

GivePlayersSuits()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
			
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		GivePlayerItem(iClient, "item_heavyassaultsuit");
	}
}

public OnFreezeEnd()
{
	SetConVarInt(g_hBuyAnywhere, 0);
}