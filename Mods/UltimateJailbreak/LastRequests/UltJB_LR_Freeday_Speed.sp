#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Freeday - Speed";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Freeday - Speed.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Speed"
#define LR_CATEGORY		"Freeday"
#define LR_DESCRIPTION	""


public OnPluginStart()
{
	CreateConVar("lr_freeday_speed_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_FREEDAY, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	
	if(IsPlayerAlive(iClient))
		SetSpeed(iClient, 2.4);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	SDKUnhook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	
	if(IsClientInGame(iClient))
		SetSpeed(iClient, 1.0);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	SetSpeed(iClient, 2.4);
}

SetSpeed(iClient, Float:fValue)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", fValue);
}