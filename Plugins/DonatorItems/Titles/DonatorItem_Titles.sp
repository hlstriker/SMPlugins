#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseUsers/database_users"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/Donators/donators"
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "donatoritem_titles"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Donator Item: Titles";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Gives titles to players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szDatabaseBridgeConfigName[64];
new Handle:cvar_database_bridge_configname;

new bool:g_bHasTitle[MAXPLAYERS+1];
new String:g_szTitle[MAXPLAYERS+1][MAX_TITLE_LENGTH];


public OnPluginStart()
{
	CreateConVar("donator_item_titles_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("donatoritem_titles");
	CreateNative("DItemTitles_GetTitle", _DItemTitles_GetTitle);
	
	return APLRes_Success;
}

public _DItemTitles_GetTitle(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
		return false;
	
	new iClient = GetNativeCell(1);
	if(!g_bHasTitle[iClient])
		return false;
	
	if(!Donators_IsDonator(iClient))
		return false;
	
	SetNativeString(2, g_szTitle[iClient], GetNativeCell(3));
	
	return true;
}

public OnAllPluginsLoaded()
{
	cvar_database_bridge_configname = FindConVar("sm_database_bridge_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_bridge_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_bridge_configname, g_szDatabaseBridgeConfigName, sizeof(g_szDatabaseBridgeConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_DonatorTitles())
		return;
}

bool:Query_CreateTable_DonatorTitles()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS donator_titles\
	(\
		user_id			INT UNSIGNED		NOT NULL,\
		title			VARCHAR( 12 )		NOT NULL,\
		PRIMARY KEY ( user_id )\
	) CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = MYISAM");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the donator_titles sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnClientConnected(iClient)
{
	g_bHasTitle[iClient] = false;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseBridgeConfigName, Query_GetTitle, DBPrio_Low, GetClientSerial(iClient), "\
		SELECT title FROM donator_titles WHERE user_id = %i", iUserID);
}

public Query_GetTitle(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(!SQL_FetchRow(hQuery))
		return;
	
	SQL_FetchString(hQuery, 0, g_szTitle[iClient], sizeof(g_szTitle[]));
	
	if(g_szTitle[iClient][0])
		g_bHasTitle[iClient] = true;
}


///////////////////
// START SETTINGS
///////////////////
public Donators_OnRegisterSettingsReady()
{
	Donators_RegisterSettings("Title (opens web page)", OnSettingsMenu);
}

public OnSettingsMenu(iClient)
{
	Donators_OpenSettingsMenu(iClient);
	WebPageViewer_OpenPage(iClient, "http://swoobles.com/page/titlechange");
}