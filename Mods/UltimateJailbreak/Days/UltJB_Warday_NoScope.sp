#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: No Scope";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: No Scope.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"No Scope"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;


public OnPluginStart()
{
	CreateConVar("warday_noscope_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_KILL_WORLD_WEAPONS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO | DAY_FLAG_GIVE_PRISONERS_INFINITE_AMMO, OnDayStart, OnDayEnd, OnFreezeEnd);
	UltJB_Day_AllowFreeForAll(iDayID, true);
}

public OnDayStart(iClient)
{
	//
}

public OnDayEnd(iClient)
{
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		SDKUnhook(iPlayer, SDKHook_PreThinkPost, OnPreThinkPost);
	}
}

public OnFreezeEnd()
{
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AWP);
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		
		SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	}
}

public OnPreThinkPost(iClient)
{
	static iWeapon;
	iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iWeapon < 1)
		return;
	
	SetupNoScope(iWeapon);
}

SetupNoScope(iWeapon)
{
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 9999999.0);
}