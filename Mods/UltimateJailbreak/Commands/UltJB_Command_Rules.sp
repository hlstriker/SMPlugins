#include <sourcemod>
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../../Libraries/WebPageViewer/web_page_viewer"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Ultimate Jailbreak: Command Rules";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to open the jailbreak rules page.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_rules_url;
new Handle:cvar_definitions_url;

new bool:g_bLibLoaded_WebPageViewer;


public OnPluginStart()
{
	CreateConVar("ultjb_command_jbrules_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_rules_url = FindConVar("jailbreak_rules_url")) == INVALID_HANDLE)
		cvar_rules_url = CreateConVar("jailbreak_rules_url", "", "The URL to the jailbreak rules.");
	
	if((cvar_definitions_url = FindConVar("jailbreak_definitions_url")) == INVALID_HANDLE)
		cvar_definitions_url = CreateConVar("jailbreak_definitions_url", "", "The URL to the jailbreak definitions.");
	
	RegConsoleCmd("sm_jbrules", OnRules);
	RegConsoleCmd("sm_definitions", OnDefinitions);
	RegConsoleCmd("sm_defs", OnDefinitions);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_WebPageViewer = LibraryExists("web_page_viewer");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "web_page_viewer"))
	{
		g_bLibLoaded_WebPageViewer = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "web_page_viewer"))
	{
		g_bLibLoaded_WebPageViewer = false;
	}
}

public Action:OnRules(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(cvar_rules_url == INVALID_HANDLE)
		return Plugin_Handled;
	
	if(g_bLibLoaded_WebPageViewer)
	{
		#if defined _web_page_viewer_included
		static String:szURL[1024];
		GetConVarString(cvar_rules_url, szURL, sizeof(szURL));
		WebPageViewer_OpenPage(iClient, szURL);
		
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading jailbreak rules...");
		#endif
	}
	
	return Plugin_Handled;
}

public Action:OnDefinitions(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(cvar_definitions_url == INVALID_HANDLE)
		return Plugin_Handled;
	
	if(g_bLibLoaded_WebPageViewer)
	{
		#if defined _web_page_viewer_included
		static String:szURL[1024];
		GetConVarString(cvar_rules_url, szURL, sizeof(szURL));
		WebPageViewer_OpenPage(iClient, szURL);
		
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading jailbreak definitions...");
		#endif
	}
	
	return Plugin_Handled;
}