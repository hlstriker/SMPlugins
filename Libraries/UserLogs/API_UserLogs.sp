#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseUsers/database_users"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: User Logs";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage user logs in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];


public OnPluginStart()
{
	CreateConVar("api_user_logs_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("user_logs");
	CreateNative("UserLogs_AddLog", _UserLogs_AddLog);
	
	return APLRes_Success;
}

public _UserLogs_AddLog(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 7)
	{
		LogError("Invalid number of parameters _UserLogs_AddLog().");
		return false;
	}
	
	new iUserID = GetNativeCell(1);
	if(iUserID < 0)
		return false;
	
	new iLogType = GetNativeCell(2);
	new Handle:hTransaction = GetNativeCell(3);
	new iData1 = GetNativeCell(4);
	new iData2 = GetNativeCell(5);
	new iData3 = GetNativeCell(6);
	new iData4 = GetNativeCell(7);
	
	decl String:szQuery[256];
	FormatEx(szQuery, sizeof(szQuery), "INSERT INTO gs_user_logs (user_id, log_type, log_data1, log_data2, log_data3, log_data4, log_time) VALUES (%i, %i, %i, %i, %i, %i, UNIX_TIMESTAMP())", iUserID, iLogType, iData1, iData2, iData3, iData4);
	
	if(hTransaction != INVALID_HANDLE)
	{
		SQL_AddQuery(hTransaction, szQuery);
	}
	else
	{
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, szQuery);
	}
	
	return true;
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
	if(!Query_CreateStoreUserLogsTable())
	{
		SetFailState("Log table could not be created.");
		return;
	}
}

bool:Query_CreateStoreUserLogsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_user_logs\
	(\
		log_id			INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		user_id			INT UNSIGNED		NOT NULL,\
		log_type		TINYINT UNSIGNED	NOT NULL,\
		log_data1		BIGINT				NOT NULL,\
		log_data2		BIGINT				NOT NULL,\
		log_data3		BIGINT				NOT NULL,\
		log_data4		BIGINT				NOT NULL,\
		log_time		INT					NOT NULL,\
		PRIMARY KEY ( log_id ),\
		INDEX ( user_id, log_type, log_time )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_user_logs sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}