#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR Effect: Speed";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "LR Effect: Speed.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EFFECT_NAME "Speed"


public OnPluginStart()
{
	CreateConVar("lr_effect_speed_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Effects_OnRegisterReady()
{
	UltJB_Effects_RegisterEffect(EFFECT_NAME, OnEffectStart, OnEffectStop, 1.5);
}

public OnEffectStart(iClient, Float:fData)
{
	SetSpeed(iClient, fData);
}

public OnEffectStop(iClient)
{
	SetSpeed(iClient, 1.0);
}

SetSpeed(iClient, Float:fValue)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", fValue);
}