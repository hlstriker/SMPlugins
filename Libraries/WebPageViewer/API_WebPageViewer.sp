#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseUsers/database_users"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Web Page Viewer";
new const String:PLUGIN_VERSION[] = "2.0";

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
new bool:g_bQueryingCvar[MAXPLAYERS+1];


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
		PRIMARY KEY ( user_id )\
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
	
	if(g_bQueryingDB[iClient] || g_bQueryingCvar[iClient])
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}Please wait...");
		return false;
	}
	
	new iUserID = DBUsers_GetUserID(iClient);
	if(iUserID < 1)
		return false;
	
	static String:szBuffer[4096];
	FormatNativeString(0, 2, 3, sizeof(szBuffer), _, szBuffer);
	
	if(StrContains(szBuffer, "swoobles.com") != -1)
	{
		// From web page viewer = 1
		if(StrContains(szBuffer, "?") != -1)
		{
			Format(szBuffer, sizeof(szBuffer), "%s&wpv=1", szBuffer);
		}
		else
		{
			Format(szBuffer, sizeof(szBuffer), "%s?wpv=1", szBuffer);
		}
	}
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szBuffer, szBuffer, sizeof(szBuffer)))
		return false;
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, iClient);
	WritePackCell(hPack, GetClientSerial(iClient));
	
	g_bQueryingDB[iClient] = true;
	DB_TQuery(g_szDatabaseConfigName, Query_InsertURL, DBPrio_High, hPack, "INSERT INTO plugin_webpage_viewer (user_id, url, utime) VALUES (%i, '%s', UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE url='%s', utime=UNIX_TIMESTAMP()", iUserID, szBuffer, szBuffer);
	
	g_bQueryingCvar[iClient] = true;
	QueryClientConVar(GetNativeCell(1), "cl_disablehtmlmotd", Query_GetCvarValue, hPack);
	
	return true;
}

public OnClientPutInServer(iClient)
{
	g_bQueryingCvar[iClient] = false;
	g_bQueryingDB[iClient] = false;
}

public Query_InsertURL(Handle:hDatabase, Handle:hQuery, any:hPack)
{
	TryShowMOTD(hPack, false);
}

public Query_GetCvarValue(QueryCookie:cookie, iClient, ConVarQueryResult:result, const String:szConvarName[], const String:szConvarValue[], any:hPack)
{
	TryShowMOTD(hPack, true, StringToInt(szConvarValue));
}

TryShowMOTD(Handle:hPack, bool:bFromCvar, iCvarValue=0)
{
	ResetPack(hPack, false);
	new iClient = ReadPackCell(hPack);
	new iClientFromSerial = GetClientFromSerial(ReadPackCell(hPack));
	
	if(bFromCvar)
		g_bQueryingCvar[iClient] = false;
	else
		g_bQueryingDB[iClient] = false;
	
	if(g_bQueryingDB[iClient] || g_bQueryingCvar[iClient])
		return;
	
	CloseHandle(hPack);
	
	if(!iClientFromSerial)
		return;
	
	if(iCvarValue != 0)
	{
		CPrintToChat(iClientFromSerial, "{green}[{lightred}SM{green}] {olive}Type {green}cl_disablehtmlmotd 0 {olive}in console.");
		return;
	}
	
	new iUserID = DBUsers_GetUserID(iClientFromSerial);
	if(iUserID < 1)
		return;
	
	decl String:szURL[128];
	Format(szURL, sizeof(szURL), "https://swoobles.com/plugin_page_viewer/web_page_viewer_db.php?uid=%i", iUserID);
	
	ShowMOTDPanel(iClientFromSerial, "", szURL, MOTDPANEL_TYPE_URL);
}