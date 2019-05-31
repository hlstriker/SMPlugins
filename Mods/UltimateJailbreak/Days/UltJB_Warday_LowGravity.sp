#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Low Gravity";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Low Gravity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Low Gravity"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

#define LOW_GRAVITY_VALUE	0.4


public OnPluginStart()
{
	CreateConVar("warday_low_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	SetLowGravityOnAll();
}

public OnDayEnd(iClient)
{
	SetDefaultGravityOnAll();
}

SetLowGravityOnAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
		SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	}
}

SetDefaultGravityOnAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
		SetEntityGravity(iClient, 1.0);
	}
}

public OnPostThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
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
			case TEAM_PRISONERS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			}
		}
	}
}