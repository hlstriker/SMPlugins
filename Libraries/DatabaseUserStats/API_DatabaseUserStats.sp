#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseServers/database_servers"
#include "../DatabaseUsers/database_users"
#include "../DatabaseUserStats/database_user_stats"
#include "../ClientTimes/client_times"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database User Stats";
new const String:PLUGIN_VERSION[] = "1.10";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the user stats in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new bool:g_bHaveServerStatsLoaded[MAXPLAYERS+1];
new bool:g_bUserHasServerStats[MAXPLAYERS+1];
new g_iUserServerRank[MAXPLAYERS+1];
new g_iUserServerTimePlayed[MAXPLAYERS+1];
new g_iUserServerTimeAFK[MAXPLAYERS+1];

new bool:g_bHaveGlobalStatsLoaded[MAXPLAYERS+1];
new bool:g_bUserHasGlobalStats[MAXPLAYERS+1];
new g_iUserGlobalRank[MAXPLAYERS+1];
new g_iUserGlobalTimePlayed[MAXPLAYERS+1];
new g_iUserGlobalTimeAFK[MAXPLAYERS+1];

new Handle:g_hFwd_OnServerStatsReady;
new Handle:g_hFwd_OnGlobalStatsReady;
new Handle:g_hFwd_OnServerStatsFailed;
new Handle:g_hFwd_OnGlobalStatsFailed;


public OnPluginStart()
{
	CreateConVar("api_database_user_stats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnServerStatsReady = CreateGlobalForward("DBUserStats_OnServerStatsReady", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnGlobalStatsReady = CreateGlobalForward("DBUserStats_OnGlobalStatsReady", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnServerStatsFailed = CreateGlobalForward("DBUserStats_OnServerStatsFailed", ET_Ignore, Param_Cell);
	g_hFwd_OnGlobalStatsFailed = CreateGlobalForward("DBUserStats_OnGlobalStatsFailed", ET_Ignore, Param_Cell);
}

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
	
	ClientTimes_SetTimeBeforeMarkedAsAway(STATS_SECONDS_BEFORE_AFK);
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_user_stats");
	
	CreateNative("DBUserStats_HasServerStatsLoaded", _DBUserStats_HasServerStatsLoaded);
	CreateNative("DBUserStats_HasServerStats", _DBUserStats_HasServerStats);
	CreateNative("DBUserStats_GetServerRank", _DBUserStats_GetServerRank);
	CreateNative("DBUserStats_GetServerTimePlayed", _DBUserStats_GetServerTimePlayed);
	CreateNative("DBUserStats_GetServerTimeAFK", _DBUserStats_GetServerTimeAFK);
	
	CreateNative("DBUserStats_HasGlobalStatsLoaded", _DBUserStats_HasGlobalStatsLoaded);
	CreateNative("DBUserStats_HasGlobalStats", _DBUserStats_HasGlobalStats);
	CreateNative("DBUserStats_GetGlobalRank", _DBUserStats_GetGlobalRank);
	CreateNative("DBUserStats_GetGlobalTimePlayed", _DBUserStats_GetGlobalTimePlayed);
	CreateNative("DBUserStats_GetGlobalTimeAFK", _DBUserStats_GetGlobalTimeAFK);
	
	return APLRes_Success;
}

public _DBUserStats_HasServerStatsLoaded(Handle:hPlugin, iNumParams)
{
	return g_bHaveServerStatsLoaded[GetNativeCell(1)];
}

public _DBUserStats_HasServerStats(Handle:hPlugin, iNumParams)
{
	return g_bUserHasServerStats[GetNativeCell(1)];
}

public _DBUserStats_GetServerRank(Handle:hPlugin, iNumParams)
{
	return g_iUserServerRank[GetNativeCell(1)];
}

public _DBUserStats_GetServerTimePlayed(Handle:hPlugin, iNumParams)
{
	return g_iUserServerTimePlayed[GetNativeCell(1)];
}

public _DBUserStats_GetServerTimeAFK(Handle:hPlugin, iNumParams)
{
	return g_iUserServerTimeAFK[GetNativeCell(1)];
}

public _DBUserStats_HasGlobalStatsLoaded(Handle:hPlugin, iNumParams)
{
	return g_bHaveGlobalStatsLoaded[GetNativeCell(1)];
}

public _DBUserStats_HasGlobalStats(Handle:hPlugin, iNumParams)
{
	return g_bUserHasGlobalStats[GetNativeCell(1)];
}

public _DBUserStats_GetGlobalRank(Handle:hPlugin, iNumParams)
{
	return g_iUserGlobalRank[GetNativeCell(1)];
}

public _DBUserStats_GetGlobalTimePlayed(Handle:hPlugin, iNumParams)
{
	return g_iUserGlobalTimePlayed[GetNativeCell(1)];
}

public _DBUserStats_GetGlobalTimeAFK(Handle:hPlugin, iNumParams)
{
	return g_iUserGlobalTimeAFK[GetNativeCell(1)];
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateUserStatsTable())
		SetFailState("There was an error creating the gs_user_stats sql table.");
	
	if(!Query_CreateUserStatsRanksTable())
		SetFailState("There was an error creating the gs_user_stats_ranks sql table.");
}

bool:Query_CreateUserStatsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_user_stats\
	(\
		user_id			INT UNSIGNED		NOT NULL,\
		server_id		SMALLINT UNSIGNED	NOT NULL,\
		time_played		INT UNSIGNED		NOT NULL,\
		time_afk		INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( server_id, user_id ),\
		INDEX ( user_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateUserStatsRanksTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_user_stats_ranks\
	(\
		user_id			INT UNSIGNED		NOT NULL,\
		server_id		SMALLINT UNSIGNED	NOT NULL,\
		rank			INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( server_id, user_id ),\
		INDEX ( server_id, rank )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	SelectUserStats(iClient, iUserID);
}

SelectUserStats(iClient, iUserID)
{
	// Select server stats.
	DB_TQuery(g_szDatabaseConfigName, Query_SelectUserServerStats, DBPrio_High, GetClientSerial(iClient), "\
		SELECT r.rank, s.time_played, s.time_afk \
		FROM gs_user_stats s \
		JOIN gs_user_stats_ranks r \
		ON s.server_id = r.server_id AND s.user_id = r.user_id \
		WHERE s.server_id=%i AND s.user_id=%i",
		DBServers_GetServerParentID(), iUserID);
	
	// Select global stats.
	DB_TQuery(g_szDatabaseConfigName, Query_SelectUserGlobalStats, DBPrio_High, GetClientSerial(iClient), "\
		SELECT r.rank, s.time_played, s.time_afk \
		FROM gs_user_stats s \
		JOIN gs_user_stats_ranks r \
		ON s.server_id = r.server_id AND s.user_id = r.user_id \
		WHERE s.server_id=0 AND s.user_id=%i",
		iUserID);
}

public Query_SelectUserServerStats(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_bHaveServerStatsLoaded[iClient] = true;
	
	if(hQuery == INVALID_HANDLE)
	{
		_DBUserStats_OnServerStatsFailed(iClient);
		return;
	}
	
	// Get stats.
	if(SQL_FetchRow(hQuery))
	{
		g_bUserHasServerStats[iClient] = true;
		g_iUserServerRank[iClient] = SQL_FetchInt(hQuery, 0);
		g_iUserServerTimePlayed[iClient] = SQL_FetchInt(hQuery, 1);
		g_iUserServerTimeAFK[iClient] = SQL_FetchInt(hQuery, 2);
	}
	
	// Call ready forward.
	_DBUserStats_OnServerStatsReady(iClient);
}

_DBUserStats_OnServerStatsReady(iClient)
{
	Call_StartForward(g_hFwd_OnServerStatsReady);
	Call_PushCell(iClient);
	Call_PushCell(g_iUserServerRank[iClient]);
	Call_PushCell(g_iUserServerTimePlayed[iClient]);
	Call_PushCell(g_iUserServerTimeAFK[iClient]);
	Call_Finish();
}

_DBUserStats_OnServerStatsFailed(iClient)
{
	Call_StartForward(g_hFwd_OnServerStatsFailed);
	Call_PushCell(iClient);
	Call_Finish();
}

public Query_SelectUserGlobalStats(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_bHaveGlobalStatsLoaded[iClient] = true;
	
	if(hQuery == INVALID_HANDLE)
	{
		_DBUserStats_OnGlobalStatsFailed(iClient);
		return;
	}
	
	// Get stats.
	if(SQL_FetchRow(hQuery))
	{
		g_bUserHasGlobalStats[iClient] = true;
		g_iUserGlobalRank[iClient] = SQL_FetchInt(hQuery, 0);
		g_iUserGlobalTimePlayed[iClient] = SQL_FetchInt(hQuery, 1);
		g_iUserGlobalTimeAFK[iClient] = SQL_FetchInt(hQuery, 2);
	}
	
	// Call ready forward.
	_DBUserStats_OnGlobalStatsReady(iClient);
}

_DBUserStats_OnGlobalStatsReady(iClient)
{
	Call_StartForward(g_hFwd_OnGlobalStatsReady);
	Call_PushCell(iClient);
	Call_PushCell(g_iUserGlobalRank[iClient]);
	Call_PushCell(g_iUserGlobalTimePlayed[iClient]);
	Call_PushCell(g_iUserGlobalTimeAFK[iClient]);
	Call_Finish();
}

_DBUserStats_OnGlobalStatsFailed(iClient)
{
	Call_StartForward(g_hFwd_OnGlobalStatsFailed);
	Call_PushCell(iClient);
	Call_Finish();
}

public OnClientDisconnect(iClient)
{
	if(!DBUsers_GetUserID(iClient))
		return;
	
	// Insert stats.
	new iServerID = DBServers_GetServerParentID();
	if(iServerID > 0)
		InsertUserStats(iClient, DBServers_GetServerParentID());
	
	InsertUserStats(iClient, 0);
}

InsertUserStats(iClient, iServerID)
{
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		INSERT INTO gs_user_stats (user_id, server_id, time_played, time_afk) VALUES (%i, %i, %i, %i) ON DUPLICATE KEY UPDATE time_played=time_played+%i, time_afk=time_afk+%i",
		DBUsers_GetUserID(iClient), iServerID, ClientTimes_GetTimePlayed(iClient), ClientTimes_GetTimeAway(iClient), ClientTimes_GetTimePlayed(iClient), ClientTimes_GetTimeAway(iClient));
}

public OnClientConnected(iClient)
{
	g_bHaveServerStatsLoaded[iClient] = false;
	g_bHaveGlobalStatsLoaded[iClient] = false;
}

public OnClientDisconnect_Post(iClient)
{
	g_bUserHasServerStats[iClient] = false;
	g_iUserServerRank[iClient] = STATS_NOT_RANKED;
	g_iUserServerTimePlayed[iClient] = 0;
	g_iUserServerTimeAFK[iClient] = 0;
	
	g_bUserHasGlobalStats[iClient] = false;
	g_iUserGlobalRank[iClient] = STATS_NOT_RANKED;
	g_iUserGlobalTimePlayed[iClient] = 0;
	g_iUserGlobalTimeAFK[iClient] = 0;
}