#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Disable Player Damage";
new const String:PLUGIN_VERSION[] = "1.5";

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
	if(!IsPlayer(iVictim))
		return Plugin_Continue;
	
	if(!IsPlayer(iAttacker))
		return Plugin_Continue;
	
	if(!IsPlayer(iInflictor) && !IsPlayer(GetEntPropEnt(iInflictor, Prop_Send, "m_hOwnerEntity")))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Handled;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!IsPlayer(iVictim))
		return Plugin_Continue;
	
	if(!IsPlayer(iAttacker))
		return Plugin_Continue;
	
	if(!IsPlayer(iInflictor) && !IsPlayer(GetEntPropEnt(iInflictor, Prop_Send, "m_hOwnerEntity")))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}

bool:IsPlayer(iEnt)
{
	return (1 <= iEnt <= MaxClients);
}