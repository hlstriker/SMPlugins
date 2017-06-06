#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseServers/database_servers"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database Maps";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the maps in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_MAP_NAME_LENGTH	64

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iMapID;

new Handle:g_hFwd_OnMapIDReady;


public OnPluginStart()
{
	CreateConVar("api_database_maps_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnMapIDReady = CreateGlobalForward("DBMaps_OnMapIDReady", ET_Ignore, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_maps");
	
	CreateNative("DBMaps_GetMapID", _DBMaps_GetMapID);
	CreateNative("DBMaps_GetMapIDFromName", _DBMaps_GetMapIDFromName);
	
	return APLRes_Success;
}

public _DBMaps_GetMapID(Handle:hPlugin, iNumParams)
{
	return g_iMapID;
}

public _DBMaps_GetMapIDFromName(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 2 || iNumParams > 3)
		return false;
	
	new iGameID = DBServers_GetGameID();
	if(!iGameID)
		return false;
	
	new Function:callback = GetNativeCell(2);
	if(callback == INVALID_FUNCTION)
		return false;
	
	new Handle:hForward = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
	AddToForward(hForward, hPlugin, callback);
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, hForward);
	WritePackCell(hPack, GetNativeCell(3));
	
	decl String:szMapName[MAX_MAP_NAME_LENGTH*2+1];
	GetNativeString(1, szMapName, sizeof(szMapName));
	DB_EscapeString(g_szDatabaseConfigName, szMapName, szMapName, sizeof(szMapName));
	
	DB_TQuery(g_szDatabaseConfigName, Query_SelectMapIDFromName, _, hPack, "SELECT map_id FROM gs_maps WHERE game_id=%i AND map_name='%s' LIMIT 1", iGameID, szMapName);
	
	return true;
}

public Query_SelectMapIDFromName(Handle:hDatabase, Handle:hQuery, any:hPack)
{
	ResetPack(hPack, false);
	new Handle:hForward = ReadPackCell(hPack);
	new data = ReadPackCell(hPack);
	CloseHandle(hPack);
	
	if(hQuery == INVALID_HANDLE || !SQL_FetchRow(hQuery))
	{
		Forward_SelectedMapIDFromName(hForward, 0, data);
		return;
	}
	
	new iMapID = SQL_FetchInt(hQuery, 0);
	Forward_SelectedMapIDFromName(hForward, iMapID, data);
}

Forward_SelectedMapIDFromName(Handle:hForward, iMapID, any:data)
{
	decl result;
	Call_StartForward(hForward);
	Call_PushCell(iMapID);
	Call_PushCell(data);
	Call_Finish(result);
	
	CloseHandle(hForward);
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

public OnMapStart()
{
	g_iMapID = 0;
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateMapsTable())
		return;
	
	if(!Query_GetMapID(iGameID))
		return;
	
	Call_StartForward(g_hFwd_OnMapIDReady);
	Call_PushCell(g_iMapID);
	Call_Finish();
}

bool:Query_CreateMapsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_maps\
	(\
		game_id			SMALLINT UNSIGNED		NOT NULL,\
		map_name		VARCHAR( 48 )			NOT NULL,\
		map_id			MEDIUMINT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		PRIMARY KEY ( game_id, map_name ),\
		UNIQUE ( map_id )\
	) CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_maps sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_GetMapID(iGameID)
{
	decl String:szMapName[MAX_MAP_NAME_LENGTH*2+1];
	GetCurrentMap(szMapName, sizeof(szMapName));
	DB_EscapeString(g_szDatabaseConfigName, szMapName, szMapName, sizeof(szMapName));
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "SELECT map_id FROM gs_maps WHERE game_id=%i AND map_name='%s' LIMIT 1", iGameID, szMapName);
	if(hQuery == INVALID_HANDLE)
		return false;
	
	if(SQL_FetchRow(hQuery))
	{
		g_iMapID = SQL_FetchInt(hQuery, 0);
	}
	else
	{
		// Try to insert a new map and get its id
		DB_CloseQueryHandle(hQuery);
		
		if(!Query_InsertMap(iGameID, szMapName))
			return false;
		
		return true;
	}
	
	DB_CloseQueryHandle(hQuery);
	
	if(!g_iMapID)
		return false;
	
	return true;
}

bool:Query_InsertMap(iGameID, const String:szMapName[])
{
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "INSERT INTO gs_maps (game_id, map_name) VALUES (%i, '%s')", iGameID, szMapName);
	if(hQuery == INVALID_HANDLE)
		return false;
	
	g_iMapID = SQL_GetInsertId(hQuery);
	DB_CloseQueryHandle(hQuery);
	
	if(!g_iMapID)
		return false;
	
	return true;
}