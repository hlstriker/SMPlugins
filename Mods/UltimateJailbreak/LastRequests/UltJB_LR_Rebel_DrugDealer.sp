#include <sourcemod>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: Rebel - Drug Dealer";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Rebel - Drug Dealer.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Drug Dealer"
#define LR_CATEGORY		"Rebel"
#define LR_DESCRIPTION	""

new const g_iHealthToGive = 300;
new g_iEffectID_Drugs;
new g_iEffectID_Speed;


public OnPluginStart()
{
	CreateConVar("lr_rebel_drug_dealer_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_LAST_PRISONER_ONLY_CAN_USE | LR_FLAG_REBEL | LR_FLAG_TEMP_INVINCIBLE | LR_FLAG_NORADAR | LR_FLAG_SHOW_ALL_GUARDS_ON_RADAR | LR_FLAG_RANDOM_TELEPORT_LOCATION, OnLastRequestStart, OnLastRequestEnd);
	
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public UltJB_Effects_OnRegisterComplete()
{
	g_iEffectID_Drugs = UltJB_Effects_GetEffectID("Drugs");
	g_iEffectID_Speed = UltJB_Effects_GetEffectID("Speed");
}

public OnLastRequestStart(iClient)
{
	UltJB_LR_SetClientsHealth(iClient, g_iHealthToGive);
	PrepareWeapons(iClient);
	
	UltJB_Effects_StartEffect(iClient, g_iEffectID_Drugs, 2.0);
	UltJB_Effects_StartEffect(iClient, g_iEffectID_Speed, UltJB_Effects_GetEffectDefaultData(g_iEffectID_Speed));
}

public OnLastRequestEnd(iClient, iOpponent)
{
	RestoreWeaponsIfNeeded(iClient);
	
	UltJB_Effects_StopEffect(iClient, g_iEffectID_Drugs);
	UltJB_Effects_StopEffect(iClient, g_iEffectID_Speed);
}

PrepareWeapons(iClient)
{
	UltJB_LR_StripClientsWeapons(iClient, true);
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AK47);
}

RestoreWeaponsIfNeeded(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
}