#include <sourcemod>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: Rebel - Coked Taser";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "Last Request: Rebel - Coked Taser.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Coked Taser"
#define LR_CATEGORY		"Rebel"
#define LR_DESCRIPTION	""

new Handle:g_hTaserTime;


public OnPluginStart()
{
	CreateConVar("lr_rebel_coked_taser_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_LAST_PRISONER_ONLY_CAN_USE | LR_FLAG_REBEL | LR_FLAG_TEMP_INVINCIBLE , OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", 3.0);
	UltJB_LR_SetClientsHealth(iClient, 200);
	
	g_hTaserTime = FindConVar("mp_taser_recharge_time");
	SetConVarInt(g_hTaserTime, 1);
	
	PrepareWeapons(iClient);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	RestoreWeaponsIfNeeded(iClient);
	SetConVarInt(g_hTaserTime, -1);
}

PrepareWeapons(iClient)
{
	UltJB_LR_StripClientsWeapons(iClient, true);
	
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_TASER);
}

RestoreWeaponsIfNeeded(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
}