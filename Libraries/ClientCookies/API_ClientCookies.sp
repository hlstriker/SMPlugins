#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseUsers/database_users"
#include "client_cookies"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Client Cookies";
new const String:PLUGIN_VERSION[] = "1.9";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to handle client cookies.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iCachedUserID[MAXPLAYERS+1];

new g_iClientCookies[MAXPLAYERS+1][NUM_CC_TYPES];
new g_iClientCookiesPostIncrement[MAXPLAYERS+1][NUM_CC_TYPES];
new bool:g_bHaveCookiesChanged[MAXPLAYERS+1][NUM_CC_TYPES];
new bool:g_bHasCookie[MAXPLAYERS+1][NUM_CC_TYPES];
new bool:g_bHaveCookiesLoaded[MAXPLAYERS+1];

new Handle:g_hFwd_OnCookiesLoaded;


public OnPluginStart()
{
	CreateConVar("api_client_cookies_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnCookiesLoaded = CreateGlobalForward("ClientCookies_OnCookiesLoaded", ET_Ignore, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("client_cookies");
	
	CreateNative("ClientCookies_SetCookie", _ClientCookies_SetCookie);
	CreateNative("ClientCookies_GetCookie", _ClientCookies_GetCookie);
	CreateNative("ClientCookies_HasCookie", _ClientCookies_HasCookie);
	CreateNative("ClientCookies_HaveCookiesLoaded", _ClientCookies_HaveCookiesLoaded);
	
	return APLRes_Success;
}

public _ClientCookies_HaveCookiesLoaded(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters ClientCookies_HaveCookiesLoaded");
		return false;
	}
	
	return g_bHaveCookiesLoaded[GetNativeCell(1)];
}

public _ClientCookies_HasCookie(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters ClientCookies_HasCookie");
		return false;
	}
	
	new iCookieType = GetNativeCell(2);
	if(iCookieType < 0 || iCookieType >= _:NUM_CC_TYPES)
	{
		decl String:szPluginName[PLATFORM_MAX_PATH];
		GetPluginFilename(hPlugin, szPluginName, sizeof(szPluginName));
		
		LogError("Invalid cookie type %i [%s]", iCookieType, szPluginName);
		return false;
	}
	
	return g_bHasCookie[GetNativeCell(1)][iCookieType];
}

public _ClientCookies_SetCookie(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters ClientCookies_SetCookie");
		return;
	}
	
	new iCookieType = GetNativeCell(2);
	if(iCookieType < 0 || iCookieType >= _:NUM_CC_TYPES)
	{
		decl String:szPluginName[PLATFORM_MAX_PATH];
		GetPluginFilename(hPlugin, szPluginName, sizeof(szPluginName));
		
		LogError("Invalid cookie type %i [%s]", iCookieType, szPluginName);
		return;
	}
	
	new iClient = GetNativeCell(1);
	new iValue = GetNativeCell(3) - g_iClientCookiesPostIncrement[iClient][iCookieType];
	
	if(g_bHasCookie[iClient][iCookieType] && g_iClientCookies[iClient][iCookieType] == iValue)
		return;
	
	g_iClientCookies[iClient][iCookieType] = iValue;
	g_bHaveCookiesChanged[iClient][iCookieType] = true;
	g_bHasCookie[iClient][iCookieType] = true;
}

public OnClientDisconnect(iClient)
{
	g_iCachedUserID[iClient] = DBUsers_GetUserID(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	if(!g_bHaveCookiesLoaded[iClient])
		return;
	
	if(g_iCachedUserID[iClient] < 1)
		return;
	
	for(new i=0; i<sizeof(g_bHaveCookiesChanged[]); i++)
	{
		if(g_bHaveCookiesChanged[iClient][i])
			InsertClientCookie(g_iCachedUserID[iClient], i, g_iClientCookies[iClient][i]);
	}
}

InsertClientCookie(iUserID, iCookieType, iValue)
{
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		INSERT INTO gs_user_cookies (cookie_user_id, cookie_type, cookie_value, post_increment) VALUES (%i, %i, %i + post_increment, 0) ON DUPLICATE KEY UPDATE cookie_value = %i + post_increment, post_increment = 0",
		iUserID, iCookieType, iValue, iValue);
}

public _ClientCookies_GetCookie(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters ClientCookies_GetCookie");
		return 0;
	}
	
	new iCookieType = GetNativeCell(2);
	if(iCookieType < 0 || iCookieType >= _:NUM_CC_TYPES)
	{
		decl String:szPluginName[PLATFORM_MAX_PATH];
		GetPluginFilename(hPlugin, szPluginName, sizeof(szPluginName));
		
		LogError("Invalid cookie type %i [%s]", iCookieType, szPluginName);
		return 0;
	}
	
	new iClient = GetNativeCell(1);
	
	return (g_iClientCookies[iClient][iCookieType] + g_iClientCookiesPostIncrement[iClient][iCookieType]);
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
	Query_CreateTable_ClientCookies();
}

bool:Query_CreateTable_ClientCookies()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_user_cookies\
	(\
		cookie_user_id		INT UNSIGNED		NOT NULL,\
		cookie_type			SMALLINT UNSIGNED	NOT NULL,\
		cookie_value		INT					NOT NULL,\
		post_increment		INT					NOT NULL,\
		PRIMARY KEY ( cookie_user_id, cookie_type )\
	)\
	ENGINE INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_user_cookies sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetCookies, DBPrio_Low, GetClientSerial(iClient), "\
		SELECT cookie_type, cookie_value, post_increment FROM gs_user_cookies WHERE cookie_user_id = %i", iUserID);
}

public OnClientConnected(iClient)
{
	g_bHaveCookiesLoaded[iClient] = false;
	
	for(new i=0; i<sizeof(g_iClientCookies[]); i++)
	{
		g_iClientCookies[iClient][i] = 0;
		g_iClientCookiesPostIncrement[iClient][i] = 0;
		g_bHaveCookiesChanged[iClient][i] = false;
		g_bHasCookie[iClient][i] = false;
	}
}

public Query_GetCookies(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	decl iCookieType;
	while(SQL_FetchRow(hQuery))
	{
		iCookieType = SQL_FetchInt(hQuery, 0);
		if(iCookieType < 0 || iCookieType >= _:NUM_CC_TYPES)
			continue;
		
		g_iClientCookies[iClient][iCookieType] = SQL_FetchInt(hQuery, 1);
		g_iClientCookiesPostIncrement[iClient][iCookieType] = SQL_FetchInt(hQuery, 2);
		g_bHasCookie[iClient][iCookieType] = true;
	}
	
	g_bHaveCookiesLoaded[iClient] = true;
	
	Call_StartForward(g_hFwd_OnCookiesLoaded);
	Call_PushCell(iClient);
	Call_Finish();
}