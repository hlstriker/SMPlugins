#include <sourcemod>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Rebel - Sniper";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "Last Request: Rebel - Sniper",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Sniper"
#define LR_CATEGORY		"Rebel"
#define LR_DESCRIPTION	""

new const HEALTH_BASE = 125;


public OnPluginStart()
{
	CreateConVar("lr_rebel_sniper_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_LAST_PRISONER_ONLY_CAN_USE | LR_FLAG_TEMP_INVINCIBLE | LR_FLAG_NORADAR | LR_FLAG_RANDOM_TELEPORT_LOCATION, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	UltJB_LR_SetClientsHealth(iClient, HEALTH_BASE);
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
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AWP);
}

RestoreWeaponsIfNeeded(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
}
