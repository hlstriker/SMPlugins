#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Freeday - Auto Bhop";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Freeday - Auto Bhop.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Auto Bhop"
#define LR_CATEGORY		"Freeday"
#define LR_DESCRIPTION	""


public OnPluginStart()
{
	CreateConVar("lr_freeday_auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_FREEDAY, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnPostThinkPost(iClient)
{
	static iButtons;
	iButtons = GetEntProp(iClient, Prop_Data, "m_nOldButtons");
	iButtons &= ~IN_JUMP;
	SetEntProp(iClient, Prop_Data, "m_nOldButtons", iButtons);
}