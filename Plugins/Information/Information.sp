#include <sourcemod>
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Information";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Shows information about the current server.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_info_url;


public OnPluginStart()
{
	CreateConVar("information_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_info_url = CreateConVar("info_url", "", "The URL to the information page for this server.");
	
	RegConsoleCmd("sm_info", OnInfo, "Displays information about the current server.");
}

public Action:OnInfo(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	decl String:szURL[255];
	GetConVarString(cvar_info_url, szURL, sizeof(szURL));
	
	if(!szURL[0])
		return Plugin_Handled;
	
	WebPageViewer_OpenPage(iClient, szURL);
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading information page...");
	
	return Plugin_Handled;
}