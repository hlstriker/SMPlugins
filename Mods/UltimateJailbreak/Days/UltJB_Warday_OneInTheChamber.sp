#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: One In The Chamber";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "Warday: One In The Chamber.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"One In The Chamber"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

public OnPluginStart()
{
	CreateConVar("warday_oneinthechamber_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_KILL_WORLD_WEAPONS, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	StripWeapons();
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
}

public OnDayEnd(iClient)
{
	UnhookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
			
		SDKUnhook(iPlayer, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public OnFreezeEnd()
{
	GivePlayersR8();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
			
		SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

GivePlayersR8()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
			
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		
		new iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_USP_SILENCER);
		
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", 1);
		SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
	}
}

StripWeapons()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		UltJB_LR_StripClientsWeapons(iClient);
	}
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(IsPlayer(iAttacker)))
		return Plugin_Continue;
		
	if(!((iDamageType & DMG_BULLET) || (iDamageType & DMG_SLASH)))
		return Plugin_Continue;
	
	if((UltJB_LR_GetLastRequestFlags(iAttacker) & LR_FLAG_FREEDAY)
	|| (UltJB_LR_GetLastRequestFlags(iVictim) & LR_FLAG_FREEDAY))
		return Plugin_Continue;

	fDamage = 999.0;

	return Plugin_Changed;
}

public Action:OnPlayerDeath(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if(!iClient || !IsPlayer(iClient))
		return;
	
	decl String:szWeaponNameString[32];
	
	new bool:g_bIsHeadshot = GetEventBool(hEvent, "headshot");
	
	new iWeapon = GetPlayerWeaponSlot(iClient, 1);
	
	GetEventString(hEvent, "weapon", szWeaponNameString, sizeof(szWeaponNameString));
	
	szWeaponNameString[5] = 0x00;
	
	if(StrEqual(szWeaponNameString, "knife") || StrEqual(szWeaponNameString, "bayon"))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", GetEntProp(iWeapon, Prop_Send, "m_iClip1") + 1);
	}
	else if(StrEqual(szWeaponNameString, "usp_s"))
	{
		if(g_bIsHeadshot)
		{
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", GetEntProp(iWeapon, Prop_Send, "m_iClip1") + 2);
		}
		else
		{
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", GetEntProp(iWeapon, Prop_Send, "m_iClip1") + 1);
		}
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}