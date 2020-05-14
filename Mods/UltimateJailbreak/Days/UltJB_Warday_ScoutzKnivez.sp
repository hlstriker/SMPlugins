#include <sourcemod>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Scoutz Knivez";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Scoutz Knivez.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Scoutz Knivez"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

#define GRAVITY	0.275


public OnPluginStart()
{
	CreateConVar("warday_scoutzknivez_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_KILL_WORLD_WEAPONS, OnDayStart, OnDayEnd, OnFreezeEnd);
	UltJB_Day_AllowFreeForAll(iDayID, true);
}

public OnDayStart(iClient)
{
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
}

public OnDayEnd(iClient)
{
	UnhookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
}

public OnFreezeEnd()
{
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_SSG08);
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", 10);
		SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_GUARDS: UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
			case TEAM_PRISONERS: UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
		}
		
		SetEntityGravity(iClient, GRAVITY);
		
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", 100);
		SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 0);
	}
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(!IsPlayer(iClient))
		return;
	
	decl String:szWeaponNameString[6];
	GetEventString(hEvent, "weapon", szWeaponNameString, sizeof(szWeaponNameString));
	szWeaponNameString[5] = 0x00;
	
	if(StrEqual(szWeaponNameString, "knife") || StrEqual(szWeaponNameString, "bayon"))
	{
		new iWeapon = GetPlayerWeaponSlot(iClient, 0);
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", GetEntProp(iWeapon, Prop_Send, "m_iClip1") + 2);
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}