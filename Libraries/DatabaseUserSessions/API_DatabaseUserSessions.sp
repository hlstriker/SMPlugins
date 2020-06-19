#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseServers/database_servers"
#include "../DatabaseUsers/database_users"
#include "../DatabaseMaps/database_maps"
#include "../DatabaseMapSessions/database_map_sessions"
#include "../ClientTimes/client_times"

#undef REQUIRE_PLUGIN
#include "../DemoSessions/demo_sessions"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database User Sessions";
new const String:PLUGIN_VERSION[] = "1.9";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the user sessions in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bLibLoaded_DemoSessions;

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iUserSessionID[MAXPLAYERS+1];
new Handle:g_hFwd_OnSessionReady;


public OnPluginStart()
{
	CreateConVar("api_database_user_sessions_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnSessionReady = CreateGlobalForward("DBUserSessions_OnSessionReady", ET_Ignore, Param_Cell, Param_Cell);
}

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
	
	g_bLibLoaded_DemoSessions = LibraryExists("demo_sessions");
	
	ClientTimes_SetTimeBeforeMarkedAsAway(30);
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "demo_sessions"))
	{
		g_bLibLoaded_DemoSessions = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "demo_sessions"))
	{
		g_bLibLoaded_DemoSessions = false;
	}
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_user_sessions");
	
	CreateNative("DBUserSessions_GetSessionID", _DBUserSessions_GetSessionID);
	return APLRes_Success;
}

public _DBUserSessions_GetSessionID(Handle:hPlugin, iNumParams)
{
	return g_iUserSessionID[GetNativeCell(1)];
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	Query_CreateUserSessionsTable();
}

bool:Query_CreateUserSessionsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_user_sessions\
	(\
		sess_id			INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		user_id			INT UNSIGNED		NOT NULL,\
		game_id			SMALLINT UNSIGNED	NOT NULL,\
		server_id		SMALLINT UNSIGNED	NOT NULL,\
		map_sess_id		INT UNSIGNED		NOT NULL,\
		map_id			MEDIUMINT UNSIGNED	NOT NULL,\
		utime_start		INT					NOT NULL,\
		utime_end		INT					NOT NULL,\
		user_ip			VARCHAR( 15 )		NOT NULL,\
		time_played		INT UNSIGNED		NOT NULL,\
		time_afk		INT UNSIGNED		NOT NULL,\
		demo_sess_id	INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( sess_id ),\
		INDEX ( user_id, sess_id ),\
		INDEX ( map_sess_id ),\
		INDEX ( user_id, user_ip ),\
		INDEX ( server_id, utime_start ),\
		INDEX ( user_id, server_id ),\
		INDEX ( user_id, utime_start ),\
		INDEX ( user_ip )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_user_sessions sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	new iDemoSessionID = 0;
	if (g_bLibLoaded_DemoSessions)
	{
		#if defined _demo_sessions_included
		iDemoSessionID = DemoSessions_GetID();
		#endif
	}
	
	decl String:szIP[31];
	GetClientIP(iClient, szIP, sizeof(szIP));
	DB_EscapeString(g_szDatabaseConfigName, szIP, szIP, sizeof(szIP));
	
	DB_TQuery(g_szDatabaseConfigName, Query_InsertUserSession, DBPrio_High, GetClientSerial(iClient), "\
		INSERT INTO gs_user_sessions (user_id, game_id, map_sess_id, server_id, map_id, utime_start, user_ip, demo_sess_id) VALUES (%i, %i, %i, %i, %i, UNIX_TIMESTAMP(), '%s', %i)",
		iUserID, DBServers_GetGameID(), DBMapSessions_GetSessionID(), DBServers_GetServerID(), DBMaps_GetMapID(), szIP, iDemoSessionID);
}

public Query_InsertUserSession(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_iUserSessionID[iClient] = SQL_GetInsertId(hQuery);
	
	Call_StartForward(g_hFwd_OnSessionReady);
	Call_PushCell(iClient);
	Call_PushCell(g_iUserSessionID[iClient]);
	Call_Finish();
}

public OnClientDisconnect(iClient)
{
	if(!g_iUserSessionID[iClient])
		return;
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		UPDATE gs_user_sessions SET utime_end=UNIX_TIMESTAMP(), time_played=%i, time_afk=%i WHERE sess_id=%i",
		ClientTimes_GetTimePlayed(iClient), ClientTimes_GetTimeAway(iClient), g_iUserSessionID[iClient]);
}

public OnClientDisconnect_Post(iClient)
{
	g_iUserSessionID[iClient] = 0;
}
