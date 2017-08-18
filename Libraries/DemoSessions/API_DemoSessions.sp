#include <sourcemod>
#include <sourcetvmanager>
#include "../DatabaseCore/database_core"
#include "../DatabaseMapSessions/database_map_sessions"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Demo Sessions";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage demos.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_tv_enable;
new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iDemoSessID;
new Float:g_fDemoStartTime;
new bool:g_bIsRecording;


public OnPluginStart()
{
	CreateConVar("api_demo_sessions_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	// WARNING: We need to force tv_delay to 0 since it will offset SourceTV_GetRecordingTick().
	// There is no reliable way to find the offset if it's not 0.
	// If the server needs a tv_delay they should use a real source TV.
	new Handle:hConVar = FindConVar("tv_delay");
	if(hConVar != INVALID_HANDLE)
	{
		HookConVarChange(hConVar, OnConVarChanged);
		SetConVarInt(hConVar, 0);
	}
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarInt(hConVar, 0);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("demo_sessions");
	
	CreateNative("DemoSessions_GetID", _DemoSessions_GetID);
	CreateNative("DemoSessions_GetCurrentTime", _DemoSessions_GetCurrentTime);
	CreateNative("DemoSessions_GetCurrentTick", _DemoSessions_GetCurrentTick);
	CreateNative("DemoSessions_IsRecording", _DemoSessions_IsRecording);
	return APLRes_Success;
}

public _DemoSessions_GetID(Handle:hPlugin, iNumParams)
{
	return g_iDemoSessID;
}

public _DemoSessions_GetCurrentTime(Handle:hPlugin, iNumParams)
{
	if(!g_iDemoSessID)
		return 0;
	
	return RoundFloat(GetEngineTime() - g_fDemoStartTime);
}

public _DemoSessions_GetCurrentTick(Handle:hPlugin, iNumParams)
{
	if(!g_iDemoSessID)
		return 0;
	
	return SourceTV_GetRecordingTick();
	//return 0;
}

public _DemoSessions_IsRecording(Handle:hPlugin, iNumParams)
{
	return g_bIsRecording;
}

public OnAllPluginsLoaded()
{
	cvar_tv_enable = FindConVar("tv_enable");
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	Query_CreateDemoSessionsTable();
}

bool:Query_CreateDemoSessionsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_demo_sessions\
	(\
		demo_sess_id	INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		demo_name		VARCHAR( 80 )		NOT NULL,\
		map_sess_id		INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( demo_sess_id ),\
		INDEX ( map_sess_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_demo_sessions sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

StartDemo()
{
	// Make sure we have stopped recording before starting again.
	StopDemo();
	
	// Return if tv_enable is not set to 1.
	if(cvar_tv_enable == INVALID_HANDLE || GetConVarInt(cvar_tv_enable) != 1)
		return;
	
	// Return if there isn't a map session id.
	if(!DBMapSessions_GetSessionID())
		return;
	
	// Try to insert the new demo information in the database.
	decl String:szDemoName[81], String:szSafeDemoName[161];
	GetCurrentMap(szSafeDemoName, sizeof(szSafeDemoName));
	FormatTime(szDemoName, sizeof(szDemoName), "%Y%m%d-%H%M%S", GetTime());
	
	Format(szDemoName, sizeof(szDemoName), "swbs-%s-%s", szDemoName, szSafeDemoName);
	if(!DB_EscapeString(g_szDatabaseConfigName, szDemoName, szSafeDemoName, sizeof(szSafeDemoName)))
		return;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "INSERT INTO gs_demo_sessions (demo_name, map_sess_id) VALUES ('%s', %i)", szSafeDemoName, DBMapSessions_GetSessionID());
	if(hQuery == INVALID_HANDLE)
		return;
	
	g_iDemoSessID = SQL_GetInsertId(hQuery);
	DB_CloseQueryHandle(hQuery);
	
	if(!g_iDemoSessID)
		return;
	
	ServerCommand("tv_record %s", szDemoName);
	g_bIsRecording = true;
	g_fDemoStartTime = GetEngineTime();
}

StopDemo()
{
	if(!g_bIsRecording)
		return;
	
	ServerCommand("tv_stoprecord");
	g_bIsRecording = false;
	g_iDemoSessID = 0;
}

public OnMapStart()
{
	StopDemo();
}

public OnMapEnd()
{
	StopDemo();
}

public OnClientConnected(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	if(g_bIsRecording)
		return;
	
	StartDemo();
}

public OnClientDisconnect_Post(iClient)
{
	new iNumInGame;
	for(new i=1; i<=MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		iNumInGame++;
	}
	
	if(!iNumInGame)
		StopDemo();
}
