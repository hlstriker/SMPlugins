#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseUsers/database_users"
#include "../ClientSettings/client_settings"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database Username Stats";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the username stats in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Float:g_fNameStartTime[MAXPLAYERS+1];
new String:g_szUserName[MAXPLAYERS+1][MAX_NAME_LENGTH+1];


public OnPluginStart()
{
	CreateConVar("api_database_username_stats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	Query_CreateUsernameStatsTable();
}

bool:Query_CreateUsernameStatsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_username_stats\
	(\
		user_id			INT UNSIGNED		NOT NULL,\
		user_name		VARCHAR( 48 )		NOT NULL,\
		total_time		INT UNSIGNED		NOT NULL,\
		first_utime		INT					NOT NULL,\
		last_utime		INT					NOT NULL,\
		PRIMARY KEY ( user_id, user_name ),\
		INDEX( user_id, total_time )\
	) CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_username_stats sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnClientConnected(iClient)
{
	strcopy(g_szUserName[iClient], sizeof(g_szUserName[]), "");
	g_fNameStartTime[iClient] = GetEngineTime();
}

public ClientSettings_OnNameChange(iClient, const String:szOldName[], const String:szNewName[])
{
	InsertUsernameStats(iClient);
	strcopy(g_szUserName[iClient], sizeof(g_szUserName[]), szNewName);
	g_fNameStartTime[iClient] = GetEngineTime();
}

public OnClientDisconnect(iClient)
{
	InsertUsernameStats(iClient);
	g_fNameStartTime[iClient] = GetEngineTime();
}

public DBUserSessions_OnSessionReady(iClient, iUserSessionID)
{
	InsertUsernameStats(iClient);
	g_fNameStartTime[iClient] = GetEngineTime();
}

InsertUsernameStats(iClient)
{
	if(!g_szUserName[iClient][0])
		return;
	
	new iUserID = DBUsers_GetUserID(iClient);
	if(!iUserID)
		return;
	
	decl String:szSafeUserName[MAX_NAME_LENGTH*2+1];
	if(!DB_EscapeString(g_szDatabaseConfigName, g_szUserName[iClient], szSafeUserName, sizeof(szSafeUserName)))
		return;
	
	new iTimeNameUsed = RoundFloat(GetEngineTime() - g_fNameStartTime[iClient]);
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "INSERT INTO gs_username_stats (user_id, user_name, total_time, first_utime, last_utime) VALUES (%i, '%s', %i, UNIX_TIMESTAMP(), UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE total_time=total_time+%i, last_utime=UNIX_TIMESTAMP()", iUserID, szSafeUserName, iTimeNameUsed, iTimeNameUsed);
}