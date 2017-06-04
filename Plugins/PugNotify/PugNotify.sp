#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseBridge/database_bridge"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Pug Notify";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Notifies servers the pug server needs more players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szDatabaseBridgeConfigName[64];
new Handle:cvar_database_bridge_configname;

new Handle:cvar_pug_notify_enable_need;
#define SHOUT_TABLE_NAME		"fancytable"
#define SHOUT_DATABASE_NAME		"fancydatabase"
#define SWOOBLES_BOT_FORUM_ID	3576

// Example: The PUG #1 server is in need of 10 more players.
const MAX_SHOUT_LENGTH = 64;
new const String:CONTAINS_STRING[] = "server is in need of";

new bool:g_bWaitingForResponse;
new g_iLastObtainedTime;

new Handle:cvar_pug_notify_need_delay;
new Float:g_fLastNotify;

new Handle:cvar_pug_server_number;


public OnPluginStart()
{
	CreateConVar("pug_notify_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_pug_notify_enable_need = CreateConVar("pug_notify_enable_need", "0", "Enables the need function for the server.");
	cvar_pug_notify_need_delay = CreateConVar("pug_notify_need_delay", "180", "The delay between using the need command.");
	cvar_pug_server_number = CreateConVar("pug_server_number", "0", "The PUGs server number.");
	
	RegConsoleCmd("sm_need", OnNeed, "Announce the pug server needs more players.");
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
	CreateTimer(20.0, Timer_CheckShouts, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action:Timer_CheckShouts(Handle:hTimer)
{
	CheckShouts();
}

CheckShouts()
{
	if(GetConVarBool(cvar_pug_notify_enable_need))
		return;
	
	if(g_bWaitingForResponse)
		return;
	
	g_bWaitingForResponse = true;
	DB_TQuery(g_szDatabaseBridgeConfigName, Query_SelectShouts, DBPrio_Low, _, "SELECT timestamp, UNIX_TIMESTAMP() as curtime, shout FROM %s.%s WHERE uid = %i", SHOUT_DATABASE_NAME, SHOUT_TABLE_NAME, SWOOBLES_BOT_FORUM_ID);
}

public Query_SelectShouts(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	g_bWaitingForResponse = false;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	decl String:szShout[MAX_SHOUT_LENGTH], iShoutTime;
	while(SQL_FetchRow(hQuery))
	{
		iShoutTime = SQL_FetchInt(hQuery, 0);
		if(iShoutTime == g_iLastObtainedTime)
			continue;
		
		SQL_FetchString(hQuery, 2, szShout, sizeof(szShout));
		if(StrContains(szShout, CONTAINS_STRING) == -1)
			continue;
		
		// If 5 minutes have passed since the last shout don't show it.
		new iCurTime = SQL_FetchInt(hQuery, 1);
		if((iCurTime - iShoutTime) > 300)
			break;
		
		new iHashPos = StrContains(szShout, "#");
		if(iHashPos == -1)
			break;
		
		g_iLastObtainedTime = iShoutTime;
		
		CPrintToChatAll("{olive}The {lightred}PUG #%c server {olive}is in need of {lightred}more players{olive}.", szShout[iHashPos+1]);
		CPrintToChatAll("{olive}Type {lightred}!servers {olive}to join the {lightred}PUG #%c server{olive}.", szShout[iHashPos+1]);
		
		break;
	}
}

public Action:OnNeed(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!GetConVarBool(cvar_pug_notify_enable_need))
		return Plugin_Handled;
	
	if(GetConVarInt(cvar_pug_server_number) < 1)
	{
		ReplyToCommand(iClient, "[SM] Error: pug_server_number not set!");
		return Plugin_Handled;
	}
	
	new Float:fDelayRemaining = (g_fLastNotify + GetConVarFloat(cvar_pug_notify_need_delay)) - GetEngineTime();
	
	if(g_fLastNotify > 0 && fDelayRemaining > 0)
	{
		CPrintToChat(iClient, "{olive}Wait {lightred}%.02f {olive}seconds before using this command.", fDelayRemaining);
		return Plugin_Handled;
	}
	
	g_fLastNotify = GetEngineTime();
	CPrintToChatAll("{lightred}%N {olive}has created a need announcement.", iClient);
	
	g_bWaitingForResponse = true;
	DB_TQuery(g_szDatabaseBridgeConfigName, Query_SelectNeedShout, DBPrio_Low, _, "SELECT sid, shout FROM %s.%s WHERE uid = %i", SHOUT_DATABASE_NAME, SHOUT_TABLE_NAME, SWOOBLES_BOT_FORUM_ID);
	
	return Plugin_Handled;
}

public Query_SelectNeedShout(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	g_bWaitingForResponse = false;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iNumPlayersNeeded = 10;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientConnected(iClient))
			continue;
		
		if(IsFakeClient(iClient) || IsClientSourceTV(iClient))
			continue;
		
		iNumPlayersNeeded--;
	}
	
	if(iNumPlayersNeeded <= 0)
		return;
	
	new iShoutID;
	decl String:szShout[MAX_SHOUT_LENGTH];
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 1, szShout, sizeof(szShout));
		if(StrContains(szShout, CONTAINS_STRING) == -1)
			continue;
		
		iShoutID = SQL_FetchInt(hQuery, 0);
		break;
	}
	
	FormatEx(szShout, sizeof(szShout), "The PUG #%i server is in need of %i more players.", GetConVarInt(cvar_pug_server_number), iNumPlayersNeeded);
	
	decl String:szShoutEscaped[MAX_SHOUT_LENGTH*2];
	if(!DB_EscapeString(g_szDatabaseBridgeConfigName, szShout, szShoutEscaped, sizeof(szShoutEscaped)))
		return;
	
	if(iShoutID)
		DB_TQuery(g_szDatabaseBridgeConfigName, _, DBPrio_Low, _, "DELETE FROM %s.%s WHERE sid=%i", SHOUT_DATABASE_NAME, SHOUT_TABLE_NAME, iShoutID);
	
	DB_TQuery(g_szDatabaseBridgeConfigName, _, DBPrio_Low, _, "INSERT INTO %s.%s (uid, shout, timestamp) VALUES (%i, '%s', UNIX_TIMESTAMP())", SHOUT_DATABASE_NAME, SHOUT_TABLE_NAME, SWOOBLES_BOT_FORUM_ID, szShoutEscaped);
}