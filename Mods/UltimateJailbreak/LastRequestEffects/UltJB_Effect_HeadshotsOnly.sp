#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR Effect: Headshots Only";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "LR Effect: Headshots Only.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EFFECT_NAME "HS Only"


public OnPluginStart()
{
	CreateConVar("lr_effect_headshots_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Effects_OnRegisterReady()
{
	UltJB_Effects_RegisterEffect(EFFECT_NAME, OnEffectStart, OnEffectStop, 1.5);
}

public OnEffectStart(iClient, Float:fData)
{
	SDKHook(iClient, SDKHook_TraceAttack, OnTraceAttack);
}

public OnEffectStop(iClient)
{
	SDKUnhook(iClient, SDKHook_TraceAttack, OnTraceAttack);
}

public Action:OnTraceAttack(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType, &iAmmoType, iHitBox, iHitGroup)
{
	if(!(1 <= iVictim <= MaxClients) || !(1 <= iAttacker <= MaxClients))
		return Plugin_Continue;
	
	new iWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
	if(iWeapon == -1)
		return Plugin_Continue;
	
	decl String:szWeapon[13];
	GetEntityClassname(iWeapon, szWeapon, sizeof(szWeapon));
	szWeapon[12] = 0x00;
	
	if(iHitGroup == 1 || StrEqual(szWeapon, "weapon_knife"))
		return Plugin_Continue;
	
	fDamage = 0.0;
	
	return Plugin_Changed;

}
