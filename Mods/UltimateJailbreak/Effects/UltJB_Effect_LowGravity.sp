#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Effect: Low Gravity";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Effect: Low Gravity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EFFECT_NAME "Low Gravity"
#define LOW_GRAVITY_VALUE	0.4


public OnPluginStart()
{
	CreateConVar("ultjb_effect_low_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Effects_OnRegisterReady()
{
	UltJB_Effects_RegisterEffect(EFFECT_NAME, OnEffectStart, OnEffectStop);
}

public OnEffectStart(iClient, Float:fData)
{
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnEffectStop(iClient)
{
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	SetEntityGravity(iClient, 1.0);
}

public OnPostThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
}