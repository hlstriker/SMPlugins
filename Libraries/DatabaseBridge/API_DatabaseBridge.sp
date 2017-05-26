#include <sourcemod>
#include "../DatabaseCore/database_core"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database Bridge";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the bridge to the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szDatabaseBridgeConfigName[64];
new Handle:cvar_database_bridge_configname;

new Handle:g_hFwd_OnBridgeReady;


public OnPluginStart()
{
	CreateConVar("api_database_swoobles_bridge_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_database_bridge_configname = FindConVar("sm_database_bridge_configname")) == INVALID_HANDLE)
		cvar_database_bridge_configname = CreateConVar("sm_database_bridge_configname", "bridge", "The config name to use for the swoobles bridge database.");
	
	AutoExecConfig(true, "database_bridge", "swoobles");
	
	g_hFwd_OnBridgeReady = CreateGlobalForward("DBBridge_OnBridgeReady", ET_Ignore);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_bridge");
	return APLRes_Success;
}

public DB_OnStartConnectionSetup()
{
	GetConVarString(cvar_database_bridge_configname, g_szDatabaseBridgeConfigName, sizeof(g_szDatabaseBridgeConfigName));
	DB_SetupConnection(g_szDatabaseBridgeConfigName, OnConnectionReady);
}

public OnConnectionReady()
{
	if(!Query_SetUnicode())
		return;
	
	Call_StartForward(g_hFwd_OnBridgeReady);
	Call_Finish();
}

bool:Query_SetUnicode()
{
	static bool:bSetUnicode = false;
	if(bSetUnicode)
		return true;
	
	new Handle:hDatabase = DB_GetDatabaseHandleFromConnectionName(g_szDatabaseBridgeConfigName);
	if(hDatabase != INVALID_HANDLE)
		SQL_SetCharset(hDatabase, "utf8");
	
	/*
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "SET NAMES utf8");
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	*/
	
	bSetUnicode = true;
	
	return true;
}