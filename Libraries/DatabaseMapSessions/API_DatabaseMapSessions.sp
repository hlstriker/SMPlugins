#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseServers/database_servers"
#include "../DatabaseMaps/database_maps"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database Map Sessions";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the map sessions in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iMapSessionID;


public OnPluginStart()
{
	CreateConVar("api_database_map_sessions_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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
	RegPluginLibrary("database_map_sessions");
	
	CreateNative("DBMapSessions_GetSessionID", _DBMapSessions_GetSessionID);
	return APLRes_Success;
}

public _DBMapSessions_GetSessionID(Handle:hPlugin, iNumParams)
{
	return g_iMapSessionID;
}

public OnMapStart()
{
	g_iMapSessionID = 0;
}

public DBMaps_OnMapIDReady(iMapID)
{
	if(!Query_CreateMapSessionsTable())
		return;
	
	Query_InsertMapSession(iMapID);
}

bool:Query_CreateMapSessionsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_map_sessions\
	(\
		sess_id			INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		game_id			SMALLINT UNSIGNED	NOT NULL,\
		server_id		SMALLINT UNSIGNED	NOT NULL,\
		map_id			MEDIUMINT UNSIGNED	NOT NULL,\
		utime_start		INT					NOT NULL,\
		utime_end		INT					NOT NULL,\
		total_time		INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( sess_id ),\
		INDEX ( utime_start ),\
		INDEX ( server_id ),\
		INDEX ( map_id, utime_start )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_map_sessions sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_InsertMapSession(iMapID)
{
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "INSERT INTO gs_map_sessions (game_id, server_id, map_id, utime_start) VALUES (%i, %i, %i, UNIX_TIMESTAMP())", DBServers_GetGameID(), DBServers_GetServerID(), iMapID);
	if(hQuery == INVALID_HANDLE)
		return false;
	
	g_iMapSessionID = SQL_GetInsertId(hQuery);
	DB_CloseQueryHandle(hQuery);
	
	if(!g_iMapSessionID)
		return false;
	
	return true;
}

public OnMapEnd()
{
	// Update the map session if it has a session id.
	if(g_iMapSessionID)
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "UPDATE gs_map_sessions SET utime_end=UNIX_TIMESTAMP(), total_time=UNIX_TIMESTAMP() - utime_start WHERE sess_id=%i", g_iMapSessionID);
}