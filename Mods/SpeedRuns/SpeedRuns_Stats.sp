#include <sourcemod>
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "Includes/speed_runs"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Stats";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed run stats plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

// Must match the array in the records.php file.
new const g_iStyleBitsDefault[] =
{
	0,	// None - None
	1,	// Surf - Auto bhop
	1,	// Bhop - Auto bhop
	0,	// Course - No style
	0,	// KZ - No style
	1	// Rocket - Auto bhop
};


public OnPluginStart()
{
	CreateConVar("speed_runs_stats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_wr", OnStats);	// World record for the map
	RegConsoleCmd("sm_pr", OnStats);	// Personal record for the map
	RegConsoleCmd("sm_mrank", OnStats);	// Personal map rank
	RegConsoleCmd("sm_top", OnStats);
	RegConsoleCmd("sm_stats", OnStats);
	RegConsoleCmd("sm_record", OnStats);
	RegConsoleCmd("sm_records", OnStats);
}

public Action:OnStats(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	new iMapID = DBMaps_GetMapID();
	if(!iMapID)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Required data for stats not loaded yet.");
		return Plugin_Handled;
	}
	
	decl String:szURL[255];
	FormatEx(szURL, sizeof(szURL), "http://swoobles.com/%i-record-database/%i-%i-map-world-records", iMapID, g_iStyleBitsDefault[SpeedRuns_GetServerGroupType()], SpeedRuns_GetServerGroupType());
	
	CPrintToChat(iClient, "{lightgreen}-- {olive}Loading stats page...");
	WebPageViewer_OpenPage(iClient, szURL);
	
	return Plugin_Handled;
}