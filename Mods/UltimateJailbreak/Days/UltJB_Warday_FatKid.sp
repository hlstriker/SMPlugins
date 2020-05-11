#include <sourcemod>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Fat Kid";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Fat Kid.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Fat Kid"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new const HEALTH_BASE = 2000;
new const HEALTH_PER_CT = 100;


public OnPluginStart()
{
	CreateConVar("warday_fatkid_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO | DAY_FLAG_KILL_WORLD_WEAPONS, OnDayStart, _, OnFreezeEnd);
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
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_M249);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			}
			case TEAM_PRISONERS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
				
				SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", 0.8);
				
				new iHealthToGive = HEALTH_BASE;
				
				for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
				{
					if(!IsClientInGame(iPlayer))
						continue;
					
					if(!IsPlayerAlive(iPlayer))
						continue;
					
					if(GetClientTeam(iPlayer) != TEAM_GUARDS)
						continue;
					
					iHealthToGive += HEALTH_PER_CT;
				}
				
				UltJB_LR_SetClientsHealth(iClient, iHealthToGive);
			}
		}
	}
}