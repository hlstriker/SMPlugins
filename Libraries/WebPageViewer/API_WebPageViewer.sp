#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseUsers/database_users"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Web Page Viewer";
new const String:PLUGIN_VERSION[] = "3.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to let users view web pages.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new bool:g_bQueryingDB[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("api_web_page_viewer_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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
	if(!Query_CreateTable_WebpageViewer())
		SetFailState("There was an error creating the plugin_webpage_viewer sql table.");
}

bool:Query_CreateTable_WebpageViewer()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_webpage_viewer\
	(\
		user_id		INT UNSIGNED		NOT NULL,\
		url			TEXT				NOT NULL,\
		utime		INT UNSIGNED		NOT NULL,\
		user_ip		VARBINARY(16)		NOT NULL,\
		loaded		BIT(1)				NOT NULL,\
		PRIMARY KEY ( user_id ),\
		INDEX ( user_ip )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("web_page_viewer");
	
	CreateNative("WebPageViewer_OpenPage", _WebPageViewer_OpenPage);
	return APLRes_Success;
}

public _WebPageViewer_OpenPage(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	if(g_bQueryingDB[iClient])
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}Please wait...");
		return false;
	}
	
	new iUserID = DBUsers_GetUserID(iClient);
	if(iUserID < 1)
		return false;
	
	static String:szBuffer[4096];
	FormatNativeString(0, 2, 3, sizeof(szBuffer), _, szBuffer);
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szBuffer, szBuffer, sizeof(szBuffer)))
		return false;
	
	decl String:szIP[31];
	GetClientIP(iClient, szIP, sizeof(szIP));
	if(!DB_EscapeString(g_szDatabaseConfigName, szIP, szIP, sizeof(szIP)))
		return false;
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Preparing page for opening...");
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, iClient);
	WritePackCell(hPack, GetClientSerial(iClient));
	
	g_bQueryingDB[iClient] = true;
	DB_TQuery(g_szDatabaseConfigName, Query_InsertURL, DBPrio_High, hPack, "INSERT INTO plugin_webpage_viewer (user_id, url, utime, user_ip, loaded) VALUES (%i, '%s', UNIX_TIMESTAMP(), INET_ATON('%s'), 0) ON DUPLICATE KEY UPDATE url='%s', utime=UNIX_TIMESTAMP(), user_ip=INET_ATON('%s'), loaded=0", iUserID, szBuffer, szIP, szBuffer, szIP);
	
	return true;
}

public OnClientPutInServer(iClient)
{
	g_bQueryingDB[iClient] = false;
}

public Query_InsertURL(Handle:hDatabase, Handle:hQuery, any:hPack)
{
	ResetPack(hPack, false);
	new iClient = ReadPackCell(hPack);
	new iClientFromSerial = GetClientFromSerial(ReadPackCell(hPack));
	g_bQueryingDB[iClient] = false;
	CloseHandle(hPack);
	
	if(!iClientFromSerial)
		return;
	
	CPrintToChat(iClientFromSerial, "{green}[{lightred}SM{green}] {lightred}Right click {olive}on the {lightred}scoreboard{olive}. Click {lightred}Server Website {olive}button.");
	CPrintToChat(iClientFromSerial, "{green}[{lightred}SM{green}] {olive}Make sure you are {lightred}logged in {olive}when the site loads.");
}