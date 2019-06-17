#include <sourcemod>
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/DatabaseCore/database_core"
#include "Includes/speed_runs"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Stats";
new const String:PLUGIN_VERSION[] = "1.6";

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

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64]; 

new String:g_szAverageMapTimeString[20];
new bool:g_bMapAverageCached = false;


public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}


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

	RegConsoleCmd("sm_avg", OnAverage); // Average map time
	RegConsoleCmd("sm_average", OnAverage);
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public OnMapStart()
{
	g_bMapAverageCached = false;
}

public SpeedRuns_OnNewRecord(iClient, RecordType:iRecordType, eOldRecord[Record], eNewRecord[Record])
{
	GetMapAverageTimeString();
}

public DBMaps_OnMapIDReady()
{
	GetMapAverageTimeString();
}

GetMapAverageTimeString()
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetAverage, DBPrio_Low, _, "\
	SELECT SEC_TO_TIME(AVG(r.stage_time)) \
	FROM ( \
	SELECT stage_time FROM plugin_sr_records \
    WHERE map_id = %i AND \
    stage_number = 0 \
    ) r", DBMaps_GetMapID());
}

public Query_GetAverage(Handle:hDatabase, Handle:hQuery, any:data)
{
	if(hQuery == INVALID_HANDLE)
	{
		return;
	}
	
	if (SQL_FetchRow(hQuery) && !SQL_IsFieldNull(hQuery, 0))
	{
		SQL_FetchString(hQuery, 0, g_szAverageMapTimeString, sizeof(g_szAverageMapTimeString));

		while (StrContains(g_szAverageMapTimeString, "00:") == 0)
		{
			ReplaceString(g_szAverageMapTimeString, sizeof(g_szAverageMapTimeString), "00:", "");
		}

		g_bMapAverageCached = true;
	}
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

public Action:OnAverage(iClient, iArgCount)
{
	if (!iClient)
		return Plugin_Handled;

	if(g_bMapAverageCached)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}The average {red}Map {olive}completion time across all styles is {yellow}%s", g_szAverageMapTimeString);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Map average completion time has not been loaded yet.");
	}

	return Plugin_Handled;
}