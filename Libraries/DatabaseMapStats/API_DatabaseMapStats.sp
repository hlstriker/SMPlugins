#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseServers/database_servers"
#include "../DatabaseMaps/database_maps"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database Map Stats";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the map stats in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:g_hFwd_OnStatsReady;
new Handle:g_hFwd_OnStatsFailed;

new g_iTotalTimePlayed;
new g_iTimePlayedThisMap;

new g_iNumClientsConnected;
new Float:g_fFirstClientConnectionTime;


public OnPluginStart()
{
	CreateConVar("api_database_map_stats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnStatsReady = CreateGlobalForward("DBMapStats_OnStatsReady", ET_Ignore, Param_Cell);
	g_hFwd_OnStatsFailed = CreateGlobalForward("DBMapStats_OnStatsFailed", ET_Ignore);
}

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_map_stats");
	
	CreateNative("DBMapStats_GetTimePlayed", _DBMapStats_GetTimePlayed);
	CreateNative("DBMapStats_GetTotalTimePlayed", _DBMapStats_GetTotalTimePlayed);
	return APLRes_Success;
}

public _DBMapStats_GetTimePlayed(Handle:hPlugin, iNumParams)
{
	if(g_iNumClientsConnected < 1)
		return g_iTimePlayedThisMap;
	
	return g_iTimePlayedThisMap + RoundFloat(GetEngineTime() - g_fFirstClientConnectionTime);
}

public _DBMapStats_GetTotalTimePlayed(Handle:hPlugin, iNumParams)
{
	return g_iTotalTimePlayed;
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	Query_CreateMapStatsTable();
}

bool:Query_CreateMapStatsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_map_stats\
	(\
		map_id			INT UNSIGNED		NOT NULL,\
		server_id		SMALLINT UNSIGNED	NOT NULL,\
		time_played		INT UNSIGNED		NOT NULL,\
		first_utime		INT					NOT NULL,\
		last_utime		INT					NOT NULL,\
		PRIMARY KEY ( server_id, map_id ),\
		INDEX ( map_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_map_stats sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnMapStart()
{
	g_iNumClientsConnected = 0;
	g_iTimePlayedThisMap = 0;
	g_iTotalTimePlayed = 0;
}

public OnClientConnected(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	g_iNumClientsConnected++;
	
	if(g_iNumClientsConnected == 1)
		g_fFirstClientConnectionTime = GetEngineTime();
}

public OnClientDisconnect(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	g_iNumClientsConnected--;
	
	if(g_iNumClientsConnected == 0)
		g_iTimePlayedThisMap += RoundFloat(GetEngineTime() - g_fFirstClientConnectionTime);
}

public DBMaps_OnMapIDReady(iMapID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_SelectMapStats, DBPrio_High, EntIndexToEntRef(0), "\
		SELECT time_played \
		FROM gs_map_stats \
		WHERE server_id=%i AND map_id=%i \
		LIMIT 1",
		DBServers_GetServerID(), iMapID);
}

public Query_SelectMapStats(Handle:hDatabase, Handle:hQuery, any:iClientEntRef)
{
	new iMapIndex = EntRefToEntIndex(iClientEntRef);
	if(iMapIndex == INVALID_ENT_REFERENCE)
		return;
	
	if(hQuery == INVALID_HANDLE)
	{
		Call_StartForward(g_hFwd_OnStatsFailed);
		Call_Finish();
		return;
	}
	
	// Get stats.
	if(SQL_FetchRow(hQuery))
		g_iTotalTimePlayed = SQL_FetchInt(hQuery, 0);
	
	// Call ready forward.
	Call_StartForward(g_hFwd_OnStatsReady);
	Call_PushCell(g_iTotalTimePlayed);
	Call_Finish();
	
	// Go ahead and update the map stats so it updates the last time played.
	UpdateMapStats();
}

public OnMapEnd()
{
	if(!DBMaps_GetMapID())
		return;
	
	UpdateMapStats();
}

UpdateMapStats()
{
	InsertMapStats();
	
	// Reset the time played this map.
	g_iTimePlayedThisMap = 0;
}

InsertMapStats()
{
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		INSERT INTO gs_map_stats \
		(map_id, server_id, time_played, first_utime, last_utime) \
		VALUES \
		(%i, %i, %i, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()) \
		ON DUPLICATE KEY UPDATE time_played=time_played+%i, last_utime=UNIX_TIMESTAMP()",
		DBMaps_GetMapID(), DBServers_GetServerID(), g_iTimePlayedThisMap, g_iTimePlayedThisMap);
}