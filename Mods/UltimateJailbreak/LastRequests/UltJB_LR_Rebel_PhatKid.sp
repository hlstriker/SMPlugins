#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Rebel - Phat Kid";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "Last Request: Rebel - Phat Kid.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Phat Kid"
#define LR_CATEGORY		"Rebel"
#define LR_DESCRIPTION	""

#define PHAT_GRAVITY	2.0
#define PHAT_SPEED		1.1
#define PHAT_BASEHEALTH	3000
#define PHAT_CTHEALTH	1000 // Health gained per CT


public OnPluginStart()
{
	CreateConVar("lr_rebel_phat_kid_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_LAST_PRISONER_ONLY_CAN_USE | LR_FLAG_TEMP_INVINCIBLE | LR_FLAG_RANDOM_TELEPORT_LOCATION, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	SetPhatHealth(iClient);
	PrepareWeapons(iClient);
	PrepareGuards();
	SetEntityGravity(iClient, PHAT_GRAVITY);
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", PHAT_SPEED);
	HookGuards();
}

public OnLastRequestEnd(iClient, iOpponent)
{
	RestoreWeaponsIfNeeded(iClient);
	UnhookGuards();
	SetEntityGravity(iClient, 1.0);
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", 1.0);
}

SetPhatHealth(iClient) {

	new startingHealth = PHAT_BASEHEALTH;
	
	for(new i=1;i<=MaxClients;i++) {
		
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != TEAM_GUARDS)
			continue;
			
		startingHealth += PHAT_CTHEALTH;
	
	}
	
	UltJB_LR_SetClientsHealth(iClient, startingHealth);

}

PrepareWeapons(iClient)
{
	UltJB_LR_StripClientsWeapons(iClient, true);
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
}

PrepareGuards()
{
	for(new iClient=1;iClient<=MaxClients;iClient++) {
		
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
			
		
		UltJB_LR_StripClientsWeapons(iClient, true);
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_NEGEV);
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_INCGRENADE);
	
	}
}

RestoreWeaponsIfNeeded(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
}

HookGuards() {

	for(new iClient = 1;iClient<=MaxClients;iClient++) {
		if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
	
		SDKHook(iClient, SDKHook_OnTakeDamage, Hook_GotKnifed);
	}

}

UnhookGuards() {

	for(new iClient=1;iClient<=MaxClients;iClient++) {
		SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_GotKnifed);
	}
	
}

public OnClientDisconnect(iClient) {
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_GotKnifed);
}

public Action:Hook_GotKnifed(iVictim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	new String:Weapon[32];
	
	if(inflictor > 0 && inflictor <= MaxClients)
	{
		new weapon = GetEntPropEnt(inflictor, Prop_Send, "m_hActiveWeapon");
		GetEdictClassname(weapon, Weapon, 32);
	} else {
		return Plugin_Continue;
	}
	
	if(GetClientTeam(attacker) != TEAM_PRISONERS || GetClientTeam(iVictim) != TEAM_GUARDS)
	{
		return Plugin_Continue;
	}
	
	if (StrContains(Weapon, "knife") == -1) {
		damage = 0.0;
	} else {
		damage = 1337.0;
	}
	
	return Plugin_Changed;
}
