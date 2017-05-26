#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Freeday - Low Gravity";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Freeday - Low Gravity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Low Gravity"
#define LR_CATEGORY		"Freeday"
#define LR_DESCRIPTION	""

#define LOW_GRAVITY_VALUE	0.2


public OnPluginStart()
{
	CreateConVar("lr_freeday_low_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_FREEDAY, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	
	if(IsPlayerAlive(iClient))
		SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	SDKUnhook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	
	if(IsClientInGame(iClient))
		SetEntityGravity(iClient, 1.0);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
}

public OnPostThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
}