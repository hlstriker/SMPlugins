#include <sourcemod>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Warday: Gang";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Gang.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Gang"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;


public OnPluginStart()
{
	CreateConVar("warday_gang_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO, OnDayStart, _, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	//
}

public OnFreezeEnd()
{
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_GUARDS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_M4A1_SILENCER);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
				
				UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_USP_SILENCER);
				UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
			}
			case TEAM_PRISONERS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AK47);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
				
				UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_GLOCK);
				UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
			}
		}
	}
}