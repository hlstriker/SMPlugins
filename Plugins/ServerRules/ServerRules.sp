#include <sourcemod>
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Server Rules";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Displays the server rules to players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_server_rules_url;


public OnPluginStart()
{
	CreateConVar("server_rules_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_server_rules_url = FindConVar("server_rules_url")) == INVALID_HANDLE)
		cvar_server_rules_url = CreateConVar("server_rules_url", "", "The URL to the server rules.");
	
	RegConsoleCmd("sm_rules", OnRules, "Displays the server rules.");
}

public Action:OnRules(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(cvar_server_rules_url == INVALID_HANDLE)
		return Plugin_Handled;
	
	static String:szURL[1024];
	GetConVarString(cvar_server_rules_url, szURL, sizeof(szURL));
	WebPageViewer_OpenPage(iClient, szURL);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading server rules...");
	
	return Plugin_Handled;
}