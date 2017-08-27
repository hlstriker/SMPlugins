#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Freeday: Low Gravity";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Freeday: Low Gravity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Low Gravity"
new const DayType:DAY_TYPE = DAY_TYPE_FREEDAY;

#define LOW_GRAVITY_VALUE	0.2


public OnPluginStart()
{
	CreateConVar("freeday_low_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS, OnDayStart, OnDayEnd);
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
		
		//if(GetClientTeam(iClient) != TEAM_PRISONERS)
			//continue;
		
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