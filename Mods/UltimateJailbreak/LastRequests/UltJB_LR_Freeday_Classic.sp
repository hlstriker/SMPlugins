#include <sourcemod>
#include "../Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: Freeday - Classic";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Freeday - Classic.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Classic LR"
#define LR_CATEGORY		"Freeday"
#define LR_DESCRIPTION	""


public OnPluginStart()
{
	CreateConVar("lr_freeday_classic_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_FREEDAY, OnLastRequestStart);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	//
}