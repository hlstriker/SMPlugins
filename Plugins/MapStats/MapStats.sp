#include <sourcemod>
#include "../../Libraries/DatabaseMapStats/database_map_stats"
#include "../../Libraries/DatabaseMaps/database_maps"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Map Stats";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows users to see map stats.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("map_stats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_maptime", OnMapTime, "Displays the time this map has been played.");
}

public DBMapStats_OnStatsReady(iTotalTimePlayed)
{
	CreateTimer(120.0, Timer_DisplayMapTime, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_DisplayMapTime(Handle:hTimer)
{
	DisplayMapTimeText(0);
}

public Action:OnMapTime(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMapTimeText(iClient);
	return Plugin_Handled;
}

DisplayMapTimeText(iClient)
{
	decl String:szText[192], String:szTime[32];
	DBMaps_GetCurrentMapNameFormatted(szText, sizeof(szText));
	
	new iTimePlayed = DBMapStats_GetTotalTimePlayed() + DBMapStats_GetTimePlayed();
	if(iTimePlayed > 3600)
		FormatEx(szTime, sizeof(szTime), "%.02f {lightgreen}hours", iTimePlayed / 3600.0);
	else if(iTimePlayed > 60)
		FormatEx(szTime, sizeof(szTime), "%.02f {lightgreen}minutes", iTimePlayed / 60.0);
	else
		FormatEx(szTime, sizeof(szTime), "%i {lightgreen}seconds", iTimePlayed);
	
	Format(szText, sizeof(szText), "{lightgreen}- {olive}Server has played {lightgreen}%s {olive}for {green}%s.", szText, szTime);
	
	if(iClient)
		CPrintToChat(iClient, szText);
	else
		CPrintToChatAll(szText);
}