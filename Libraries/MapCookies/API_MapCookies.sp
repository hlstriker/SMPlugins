#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseMaps/database_maps"
#include "map_cookies"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Map Cookies";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to handle map cookies.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iMapCookies[NUM_MC_TYPES];
new bool:g_bHaveCookiesChanged[NUM_MC_TYPES];
new bool:g_bHasCookie[NUM_MC_TYPES];
new bool:g_bHaveCookiesLoaded;

new g_iMapCounter;
new Handle:g_hFwd_OnCookiesLoaded;


public OnPluginStart()
{
	CreateConVar("api_map_cookies_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnCookiesLoaded = CreateGlobalForward("MapCookies_OnCookiesLoaded", ET_Ignore);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("map_cookies");
	
	CreateNative("MapCookies_SetCookie", _MapCookies_SetCookie);
	CreateNative("MapCookies_GetCookie", _MapCookies_GetCookie);
	CreateNative("MapCookies_HasCookie", _MapCookies_HasCookie);
	CreateNative("MapCookies_HaveCookiesLoaded", _MapCookies_HaveCookiesLoaded);
	
	return APLRes_Success;
}

public _MapCookies_HaveCookiesLoaded(Handle:hPlugin, iNumParams)
{
	return g_bHaveCookiesLoaded;
}

public _MapCookies_HasCookie(Handle:hPlugin, iNumParams)
{
	new iCookieType = GetNativeCell(1);
	if(iCookieType < 0 || iCookieType >= _:NUM_MC_TYPES)
	{
		decl String:szPluginName[PLATFORM_MAX_PATH];
		GetPluginFilename(hPlugin, szPluginName, sizeof(szPluginName));
		
		LogError("Invalid cookie type %i [%s]", iCookieType, szPluginName);
		return false;
	}
	
	return g_bHasCookie[iCookieType];
}

public _MapCookies_SetCookie(Handle:hPlugin, iNumParams)
{
	new iCookieType = GetNativeCell(1);
	if(iCookieType < 0 || iCookieType >= _:NUM_MC_TYPES)
	{
		decl String:szPluginName[PLATFORM_MAX_PATH];
		GetPluginFilename(hPlugin, szPluginName, sizeof(szPluginName));
		
		LogError("Invalid cookie type %i [%s]", iCookieType, szPluginName);
		return;
	}
	
	new iValue = GetNativeCell(2);
	
	if(g_bHasCookie[iCookieType] && g_iMapCookies[iCookieType] == iValue)
		return;
	
	g_iMapCookies[iCookieType] = iValue;
	g_bHaveCookiesChanged[iCookieType] = true;
	g_bHasCookie[iCookieType] = true;
}

public OnMapEnd()
{
	if(!g_bHaveCookiesLoaded)
		return;
	
	new iMapID = DBMaps_GetMapID();
	if(iMapID < 1)
		return;
	
	for(new i=0; i<sizeof(g_bHaveCookiesChanged); i++)
	{
		if(g_bHaveCookiesChanged[i])
			InsertMapCookie(iMapID, i, g_iMapCookies[i]);
	}
}

InsertMapCookie(iMapID, iCookieType, iValue)
{
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_High, _, "\
		INSERT INTO gs_map_cookies (cookie_map_id, cookie_type, cookie_value) VALUES (%i, %i, %i) ON DUPLICATE KEY UPDATE cookie_value=%i",
		iMapID, iCookieType, iValue, iValue);
}

public _MapCookies_GetCookie(Handle:hPlugin, iNumParams)
{
	new iCookieType = GetNativeCell(1);
	if(iCookieType < 0 || iCookieType >= _:NUM_MC_TYPES)
	{
		decl String:szPluginName[PLATFORM_MAX_PATH];
		GetPluginFilename(hPlugin, szPluginName, sizeof(szPluginName));
		
		LogError("Invalid cookie type %i [%s]", iCookieType, szPluginName);
		return 0;
	}
	
	return g_iMapCookies[iCookieType];
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
	if(!Query_CreateTable_MapCookies())
		SetFailState("There was an error creating the gs_map_cookies sql table.");
}

bool:Query_CreateTable_MapCookies()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_map_cookies\
	(\
		cookie_map_id		MEDIUMINT UNSIGNED		NOT NULL,\
		cookie_type			SMALLINT UNSIGNED		NOT NULL,\
		cookie_value		INT						NOT NULL,\
		PRIMARY KEY ( cookie_map_id, cookie_type )\
	)\
	ENGINE INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnMapStart()
{
	g_iMapCounter++;
	g_bHaveCookiesLoaded = false;
	
	for(new i=0; i<sizeof(g_iMapCookies); i++)
	{
		g_iMapCookies[i] = 0;
		g_bHaveCookiesChanged[i] = false;
		g_bHasCookie[i] = false;
	}
}

public DBMaps_OnMapIDReady(iMapID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetCookies, DBPrio_High, g_iMapCounter, "\
		SELECT cookie_type, cookie_value FROM gs_map_cookies WHERE cookie_map_id = %i", iMapID);
}

public Query_GetCookies(Handle:hDatabase, Handle:hQuery, any:iMapCounter)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	if(iMapCounter != g_iMapCounter)
		return;
	
	decl iCookieType;
	while(SQL_FetchRow(hQuery))
	{
		iCookieType = SQL_FetchInt(hQuery, 0);
		if(iCookieType < 0 || iCookieType >= _:NUM_MC_TYPES)
			continue;
		
		g_iMapCookies[iCookieType] = SQL_FetchInt(hQuery, 1);
		g_bHasCookie[iCookieType] = true;
	}
	
	g_bHaveCookiesLoaded = true;
	
	Call_StartForward(g_hFwd_OnCookiesLoaded);
	Call_Finish();
}