#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Freeday: Auto Bhop";
new const String:PLUGIN_VERSION[] = "1.1";

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


public OnPluginStart()
{
	CreateConVar("freeday_auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS, OnDayStart, OnDayEnd);
}

public OnDayStart(iClient)
{
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer) || !IsPlayerAlive(iPlayer))
			continue;
		
		if(GetClientTeam(iPlayer) != TEAM_PRISONERS)
			continue;
		
		SDKHook(iPlayer, SDKHook_PostThinkPost, OnPostThinkPost);
	}
}

public OnDayEnd(iClient)
{
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		SDKUnhook(iPlayer, SDKHook_PostThinkPost, OnPostThinkPost);
	}
}

public OnPostThinkPost(iClient)
{
	static iButtons;
	iButtons = GetEntProp(iClient, Prop_Data, "m_nOldButtons");
	iButtons &= ~IN_JUMP;
	SetEntProp(iClient, Prop_Data, "m_nOldButtons", iButtons);
}