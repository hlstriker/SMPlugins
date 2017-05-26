#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseBridge/database_bridge"
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Show Forum Threads";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Shows the latest forum threads.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szDatabaseBridgeConfigName[64];
new Handle:cvar_database_bridge_configname;

#define SUBJECT_MAX_LEN			120
#define THREAD_TABLE_NAME		"fancytable"
#define THREAD_DATABASE_NAME	"fancydatabase"
#define MAX_THREADS_TO_GET		5
new Handle:cvar_show_thread_forum_id;

new bool:g_bWaitingForResponse;
new g_iLastObtainedThreadID;

new g_iNumThreadIDs;
new g_iThreadIDs[MAX_THREADS_TO_GET];
new String:g_szSubjects[MAX_THREADS_TO_GET][SUBJECT_MAX_LEN+1];


public OnPluginStart()
{
	CreateConVar("show_forum_threads_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_show_thread_forum_id = CreateConVar("show_thread_forum_id", "0", "The forum ID to get latest threads from.");
	
	RegConsoleCmd("sm_read", OnRead, "Read a forum thread.");
}

public OnAllPluginsLoaded()
{
	cvar_database_bridge_configname = FindConVar("sm_database_bridge_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_bridge_configname == INVALID_HANDLE)
		return;
	
	GetConVarString(cvar_database_bridge_configname, g_szDatabaseBridgeConfigName, sizeof(g_szDatabaseBridgeConfigName));
	
	g_bWaitingForResponse = false;
	CreateTimer(30.0, Timer_CheckThreads, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action:Timer_CheckThreads(Handle:hTimer)
{
	CheckThreads();
}

CheckThreads()
{
	if(g_bWaitingForResponse)
		return;
	
	new iForumID = GetConVarInt(cvar_show_thread_forum_id);
	if(iForumID < 1)
		return;
	
	g_bWaitingForResponse = true;
	DB_TQuery(g_szDatabaseBridgeConfigName, Query_SelectThreads, DBPrio_Low, _, "SELECT tid, subject FROM %s.%s WHERE fid = %i AND visible = 1 ORDER BY dateline DESC LIMIT 0, %i", THREAD_DATABASE_NAME, THREAD_TABLE_NAME, iForumID, MAX_THREADS_TO_GET);
}

public Query_SelectThreads(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	g_bWaitingForResponse = false;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iNumThreadIDs;
	decl iThreadIDs[MAX_THREADS_TO_GET], iThreadID;
	static String:szSubjects[MAX_THREADS_TO_GET][SUBJECT_MAX_LEN+1];
	
	iThreadIDs[0] = 0;
	
	while(SQL_FetchRow(hQuery))
	{
		iThreadID = SQL_FetchInt(hQuery, 0);
		iThreadIDs[iNumThreadIDs] = iThreadID;
		SQL_FetchString(hQuery, 1, szSubjects[iNumThreadIDs], sizeof(szSubjects[]));
		
		iNumThreadIDs++;
		
		// Don't print any results if there is no last obtained thread ID yet.
		// If there is no ID that most likely means the server was just started and this was the first query.
		if(!g_iLastObtainedThreadID)
			continue;
		
		// Don't display threads we already displayed.
		if(iThreadID <= g_iLastObtainedThreadID)
			continue;
		
		CPrintToChatAll("{olive}Type {lightred}!read %i {olive}to view {lightred}%s{olive}.", iNumThreadIDs, szSubjects[iNumThreadIDs-1]);
	}
	
	g_iLastObtainedThreadID = iThreadIDs[0];
	
	// If there is a new thread we need to rebuild the global thread array.
	if(iThreadIDs[0])
	{
		for(new i=0; i<iNumThreadIDs; i++)
		{
			g_iThreadIDs[i] = iThreadIDs[i];
			strcopy(g_szSubjects[i], sizeof(g_szSubjects[]), szSubjects[i]);
		}
		
		g_iNumThreadIDs = iNumThreadIDs;
	}
}

public Action:OnRead(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	new iForumID = GetConVarInt(cvar_show_thread_forum_id);
	if(iForumID < 1)
		return Plugin_Handled;
	
	if(!g_iNumThreadIDs || !iArgNum)
	{
		OpenForumPage(iClient, iForumID);
		return Plugin_Handled;
	}
	
	decl String:szArg[12];
	GetCmdArg(1, szArg, sizeof(szArg));
	
	new iThreadIndex = StringToInt(szArg) - 1;
	if(iThreadIndex < 0 || iThreadIndex >= g_iNumThreadIDs)
	{
		OpenForumPage(iClient, iForumID);
		return Plugin_Handled;
	}
	
	decl String:szURL[255];
	FormatEx(szURL, sizeof(szURL), "http://swoobles.com/forums/thread-%i.html", g_iThreadIDs[iThreadIndex]);
	WebPageViewer_OpenPage(iClient, szURL);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading {lightred}%s", g_szSubjects[iThreadIndex]);
	
	return Plugin_Handled;
}

OpenForumPage(iClient, iForumID)
{
	decl String:szURL[255];
	FormatEx(szURL, sizeof(szURL), "http://swoobles.com/forums/forum-%i.html", iForumID);
	WebPageViewer_OpenPage(iClient, szURL);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading forum category..");
}