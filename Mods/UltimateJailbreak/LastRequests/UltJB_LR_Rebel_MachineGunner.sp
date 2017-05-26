#include <sourcemod>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Rebel - Machine Gunner";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Rebel - Machine Gunner.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Machine Gunner"
#define LR_CATEGORY		"Rebel"
#define LR_DESCRIPTION	""

new const HEALTH_BASE = 175;
new const HEALTH_PER_CT = 25;


public OnPluginStart()
{
	CreateConVar("lr_rebel_machine_gunner_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_LAST_PRISONER_ONLY_CAN_USE | LR_FLAG_ALLOW_WEAPON_PICKUPS | LR_FLAG_ALLOW_WEAPON_DROPS | LR_FLAG_TEMP_INVINCIBLE | LR_FLAG_NORADAR | LR_FLAG_SHOW_ALL_GUARDS_ON_RADAR | LR_FLAG_RANDOM_TELEPORT_LOCATION, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
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
	PrepareWeapons(iClient);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	RestoreWeaponsIfNeeded(iClient);
}

PrepareWeapons(iClient)
{
	UltJB_LR_StripClientsWeapons(iClient, true);
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_M249);
}

RestoreWeaponsIfNeeded(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
}