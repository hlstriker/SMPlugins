#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Heavy Assault";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "Warday: Heavy Assault.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME		"Heavy Assault"
#define HEAVY_BUYTIME 	20

new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new Handle:g_hBuyAnywhere;
new Handle:g_hAllowHeavy;
new Handle:g_hTimer_BuyWeapons;

new g_iTimerCountdown;

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
	PrepWeapons(true);
}

public OnDayEnd(iClient)
{
	StopTimer_BuyWeapons();
	SetConVarInt(g_hAllowHeavy, 0);
	RemoveSuits();
}

GivePlayersSuits()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
			
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
			
		SetEntProp(iClient, Prop_Send, "m_bHasHeavyArmor", 1);
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", 250);
	}
}

public OnFreezeEnd()
{
	PrepWeapons(false);
	SetConVarInt(g_hAllowHeavy, 1);
	GivePlayersSuits();
	StartTimer_BuyWeapons();
}

PrepWeapons(bool:bStrip=true)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(bStrip)
			UltJB_LR_StripClientsWeapons(iClient);
		else
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
	}
}

RemoveSuits()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", 0);
		SetEntProp(iClient, Prop_Send, "m_bHasHeavyArmor", 0);
	}
}

StartTimer_BuyWeapons()
{
	g_iTimerCountdown = 0;
	ShowCountdown_BuyWeapons();
	
	StopTimer_BuyWeapons();
	
	SetConVarInt(g_hBuyAnywhere, 1);
	
	g_hTimer_BuyWeapons = CreateTimer(1.0, Timer_BuyWeapons, _, TIMER_REPEAT);
}

ShowCountdown_BuyWeapons()
{
	PrintHintTextToAll("<font color='#FF0000'>Time remaining to buy:</font>\n<font color='#FFFFFF'>%i</font> <font color='#FF0000'>seconds.</font>", HEAVY_BUYTIME - g_iTimerCountdown);
}

StopTimer_BuyWeapons()
{
	if(g_hTimer_BuyWeapons == INVALID_HANDLE)
		return;
	
	SetConVarInt(g_hBuyAnywhere, 0);
	KillTimer(g_hTimer_BuyWeapons);
	g_hTimer_BuyWeapons = INVALID_HANDLE;
}

public Action:Timer_BuyWeapons(Handle:hTimer)
{
	g_iTimerCountdown++;
	if(g_iTimerCountdown < HEAVY_BUYTIME)
	{
		ShowCountdown_BuyWeapons();
		return Plugin_Continue;
	}
	
	SetConVarInt(g_hBuyAnywhere, 0);
	
	KillTimer(g_hTimer_BuyWeapons);
	g_hTimer_BuyWeapons = INVALID_HANDLE;
	
	PrintHintTextToAll("<font color='#FF0000'>Buy time is up!</font>");
	
	return Plugin_Stop;
}