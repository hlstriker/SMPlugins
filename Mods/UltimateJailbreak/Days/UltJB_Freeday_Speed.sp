#include <sourcemod>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Freeday: Speed";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Freeday: Speed.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Speed"
new const DayType:DAY_TYPE = DAY_TYPE_FREEDAY;


public OnPluginStart()
{
	CreateConVar("freeday_speed_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS, OnDayStart, OnDayEnd);
}

public OnDayStart(iClient)
{
	SetSpeedOnPrisoners(2.0);
	SetSpeedOnGuards(1.5);
}

public OnDayEnd(iClient)
{
	SetSpeedOnPrisoners(1.0, false);
}

SetSpeedOnPrisoners(Float:fSpeed, bool:bDoTeamCheck=true)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(bDoTeamCheck)
		{
			if(GetClientTeam(iClient) != TEAM_PRISONERS)
				continue;
		}
		
		SetSpeed(iClient, fSpeed);
	}
}

SetSpeedOnGuards(Float:fSpeed, bool:bDoTeamCheck=true)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(bDoTeamCheck)
		{
			if(GetClientTeam(iClient) != TEAM_GUARDS)
				continue;
		}
		
		SetSpeed(iClient, fSpeed);
	}
}

SetSpeed(iClient, Float:fValue)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", fValue);
}