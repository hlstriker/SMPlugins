#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Disable Player Damage";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables player damage.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("disable_player_damage_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_TraceAttack, OnTraceAttack);
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTraceAttack(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType, &iAmmoType, iHitBox, iHitGroup)
{
	if(!(1 <= iVictim <= MaxClients))
		return Plugin_Continue;
	
	if(!(1 <= iAttacker <= MaxClients))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Handled;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(1 <= iVictim <= MaxClients))
		return Plugin_Continue;
	
	if(!(1 <= iAttacker <= MaxClients))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}