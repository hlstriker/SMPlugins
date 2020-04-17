#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseBridge/database_bridge"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database Servers";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the servers in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szDatabaseBridgeConfigName[64];
new Handle:cvar_database_bridge_configname;

new String:g_szDatabaseServersConfigName[64];
new Handle:cvar_database_servers_configname;
new Handle:cvar_database_servers_code;

new bool:g_bBridgeDBReady;
new bool:g_bServersDBReady;

new g_iServerID;
new g_iServerParentID;
new g_iGameID;
new String:g_szServerName[49];

new Handle:g_hFwd_OnServerIDReady;


public OnPluginStart()
{
	CreateConVar("api_database_servers_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_database_servers_configname = FindConVar("sm_database_servers_configname")) == INVALID_HANDLE)
		cvar_database_servers_configname = CreateConVar("sm_database_servers_configname", "servers", "The config name to use for the database.");
	
	if((cvar_database_servers_code = FindConVar("sm_database_servers_code")) == INVALID_HANDLE)
		cvar_database_servers_code = CreateConVar("sm_database_servers_code", "", "The unique code used to represent this server.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	AutoExecConfig(true, "database_servers", "swoobles");
	
	g_hFwd_OnServerIDReady = CreateGlobalForward("DBServers_OnServerIDReady", ET_Ignore, Param_Cell, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_servers");
	
	CreateNative("DBServers_GetGameID", _DBServers_GetGameID);
	CreateNative("DBServers_GetServerID", _DBServers_GetServerID);
	CreateNative("DBServers_GetServerParentID", _DBServers_GetServerParentID);
	CreateNative("DBServers_GetServerName", _DBServers_GetServerName);
	return APLRes_Success;
}

public _DBServers_GetServerName(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
		return false;
	
	SetNativeString(1, g_szServerName, GetNativeCell(2));
	
	return true;
}

public _DBServers_GetGameID(Handle:hPlugin, iNumParams)
{
	if(!g_bBridgeDBReady || !g_bServersDBReady)
		return 0;
	
	return g_iGameID;
}

public _DBServers_GetServerID(Handle:hPlugin, iNumParams)
{
	return GetServerID();
}

public _DBServers_GetServerParentID(Handle:hPlugin, iNumParams)
{
	if(!g_bBridgeDBReady || !g_bServersDBReady)
		return 0;
	
	if(!g_iServerParentID)
		return GetServerID();
	
	return g_iServerParentID;
}

GetServerID()
{
	if(!g_bBridgeDBReady || !g_bServersDBReady)
		return 0;
	
	return g_iServerID;
}

public OnMapStart()
{
	g_bBridgeDBReady = false;
	g_bServersDBReady = false;
	
	// Don't reset these since we don't get the IDs on every map change now.
	//g_iGameID = 0;
	//g_iServerID = 0;
	//g_iServerParentID = 0;
}

public OnAllPluginsLoaded()
{
	cvar_database_bridge_configname = FindConVar("sm_database_bridge_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_bridge_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_bridge_configname, g_szDatabaseBridgeConfigName, sizeof(g_szDatabaseBridgeConfigName));
	
	GetConVarString(cvar_database_servers_configname, g_szDatabaseServersConfigName, sizeof(g_szDatabaseServersConfigName));
	DB_SetupConnection(g_szDatabaseServersConfigName, OnConnectionReady);
}

public OnConnectionReady()
{
	if(!Query_SetUnicode())
		return;
	
	g_bServersDBReady = true;
	TryServerReadyForward();
}

bool:Query_SetUnicode()
{
	static bool:bSetUnicode = false;
	if(bSetUnicode)
		return true;
	
	new Handle:hDatabase = DB_GetDatabaseHandleFromConnectionName(g_szDatabaseServersConfigName);
	if(hDatabase != INVALID_HANDLE)
		SQL_SetCharset(hDatabase, "utf8");
	
	/*
	new Handle:hQuery = DB_Query(g_szDatabaseServersConfigName, "SET NAMES utf8");
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	*/
	
	bSetUnicode = true;
	
	return true;
}

public DBBridge_OnBridgeReady()
{
	if(!Query_GetServerAndGameID())
		return;
	
	g_bBridgeDBReady = true;
	TryServerReadyForward();
}

TryServerReadyForward()
{
	if(!g_bBridgeDBReady || !g_bServersDBReady)
		return;
	
	Call_StartForward(g_hFwd_OnServerIDReady);
	Call_PushCell(g_iServerID);
	Call_PushCell(g_iGameID);
	Call_Finish();
}

bool:Query_GetServerAndGameID()
{
	static bool:bGotIDs = false;
	if(bGotIDs)
		return true;
	
	decl String:szServerCode[65];
	GetConVarString(cvar_database_servers_code, szServerCode, sizeof(szServerCode));
	if(strlen(szServerCode) < 2)
		return false;
	
	if(!DB_EscapeString(g_szDatabaseBridgeConfigName, szServerCode, szServerCode, sizeof(szServerCode)))
		return false;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "SELECT server_id, server_parent_id, game_id, server_name FROM core_servers WHERE server_enabled=1 AND server_code='%s' LIMIT 1", szServerCode);
	if(hQuery == INVALID_HANDLE)
		return false;
	
	if(SQL_FetchRow(hQuery))
	{
		g_iServerID = SQL_FetchInt(hQuery, 0);
		g_iServerParentID = SQL_FetchInt(hQuery, 1);
		g_iGameID = SQL_FetchInt(hQuery, 2);	
		SQL_FetchString(hQuery, 3, g_szServerName, sizeof(g_szServerName));
	}
	
	DB_CloseQueryHandle(hQuery);
	
	if(!g_iServerID || !g_iGameID)
		return false;
	
	bGotIDs = true;
	
	return true;
}