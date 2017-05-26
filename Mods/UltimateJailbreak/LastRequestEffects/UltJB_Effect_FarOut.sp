#include <sourcemod>
#include <sdktools_functions>
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR Effect: Far Out";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "LR Effect: Far Out.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EFFECT_NAME "Far Out"


public OnPluginStart()
{
	CreateConVar("lr_effect_far_out_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Effects_OnRegisterReady()
{
	UltJB_Effects_RegisterEffect(EFFECT_NAME, OnEffectStart, OnEffectStop);
}

public OnEffectStart(iClient, Float:fData)
{
	SetFOV(iClient, 160);
}

public OnEffectStop(iClient)
{
	ResetView(iClient);
}

SetFOV(iClient, iFOV)
{
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFOV);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFOV);
}

ResetView(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_iFOV", 0);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", 90);
}