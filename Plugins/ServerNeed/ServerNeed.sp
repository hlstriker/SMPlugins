#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseBridge/database_bridge"
#include "../../Libraries/DatabaseServers/database_servers"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Server Need";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Notifies systems a server needs more players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:cvar_reserved_slots;
new Handle:cvar_display_to_gameservers;
new Handle:cvar_display_to_shoutbox;
new Handle:cvar_need_command_delay;
new Handle:cvar_maxplayers_override;
new Handle:cvar_enable_sub;

new Float:g_fLastNeedIssued;

new Handle:g_hTrie_ServerNeedsTimeSent;

new bool:g_bWaitingForResponse;


public OnPluginStart()
{
	CreateConVar("server_need_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_display_to_gameservers = CreateConVar("serverneed_display_to_gameservers", "1", "Display this server's need notifications to other game servers.", _, true, 0.0, true, 1.0);
	cvar_display_to_shoutbox = CreateConVar("serverneed_display_to_shoutbox", "1", "Display this server's need notifications to the shoutbox.", _, true, 0.0, true, 1.0);
	cvar_need_command_delay = CreateConVar("serverneed_need_command_delay", "180", "The delay between using the need command.", _, true, 120.0);
	cvar_maxplayers_override = CreateConVar("serverneed_maxplayers_override", "0", "An override for the maximum amount of players needed.", _, true, 0.0);
	cvar_enable_sub = CreateConVar("serverneed_enable_sub", "0", "Enables the sub command.", _, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_need", OnNeed, "Announce this server needs more players.");
	RegConsoleCmd("sm_needsub", OnNeedSub, "Announce this server needs a sub.");
	RegConsoleCmd("sm_sub", OnNeedSub, "Announce this server needs a sub.");
	
	g_hTrie_ServerNeedsTimeSent = CreateTrie();
}

public OnConfigsExecuted()
{
	cvar_reserved_slots = FindConVar("sm_reserved_slots");
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
	if(!Query_CreateTable_ServerNeedQueue())
		return;
	
	g_bWaitingForResponse = false;
	CreateTimer(20.0, Timer_CheckNeedQueue, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

bool:Query_CreateTable_ServerNeedQueue()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_server_need_queue\
	(\
		server_id				SMALLINT UNSIGNED	NOT NULL,\
		server_name				VARCHAR( 48 )		NOT NULL,\
		players_needed			TINYINT UNSIGNED	NOT NULL,\
		display_to_gameservers	BIT(1)				NOT NULL,\
		display_to_shoutbox		BIT(1)				NOT NULL,\
		time_sent				INT					NOT NULL,\
		PRIMARY KEY ( server_id ),\
		INDEX ( server_id, display_to_gameservers, time_sent ),\
		INDEX ( display_to_shoutbox, time_sent )\
	) CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the plugin_server_need_queue sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public Action:Timer_CheckNeedQueue(Handle:hTimer)
{
	CheckNeedQueue();
}

CheckNeedQueue()
{
	if(g_bWaitingForResponse)
		return;
	
	g_bWaitingForResponse = true;
	DB_TQuery(g_szDatabaseConfigName, Query_SelectNeeds, DBPrio_Low, _, "SELECT server_id, server_name, players_needed, time_sent FROM plugin_server_need_queue WHERE server_id != %d AND display_to_gameservers = 1 AND time_sent > (UNIX_TIMESTAMP() - 600) ORDER BY time_sent ASC", DBServers_GetServerID());
}

public Query_SelectNeeds(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	g_bWaitingForResponse = false;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	static String:szServerName[SERVER_NAME_MAX_LENGTH], iServerID, iPlayersNeeded, iTimeSent;
	
	while(SQL_FetchRow(hQuery))
	{
		iServerID = SQL_FetchInt(hQuery, 0);
		iTimeSent = SQL_FetchInt(hQuery, 3);
		
		if(GetServersLastNeedTimeSent(iServerID) == iTimeSent)
			continue;
		
		SetServersLastNeedTimeSent(iServerID, iTimeSent);
		
		SQL_FetchString(hQuery, 1, szServerName, sizeof(szServerName));
		iPlayersNeeded = SQL_FetchInt(hQuery, 2);
		
		if(iPlayersNeeded)
			CPrintToChatAll("{olive}The {lightred}%s server {olive}is in need of {lightred}%d more players{olive}.", szServerName, iPlayersNeeded);
		else
			CPrintToChatAll("{olive}The {lightred}%s server {olive}is in need of {lightred}a sub{olive}.", szServerName);
		
		CPrintToChatAll("{olive}Type {lightred}!servers {olive}to join the {lightred}%s server{olive}.", szServerName);
		
		break;
	}
}

GetServersLastNeedTimeSent(iServerID)
{
	static String:szServerID[6];
	IntToString(iServerID, szServerID, sizeof(szServerID));
	
	static iTimeSent;
	if(!GetTrieValue(g_hTrie_ServerNeedsTimeSent, szServerID, iTimeSent))
		return 0;
	
	return iTimeSent;
}

SetServersLastNeedTimeSent(iServerID, iTimeSent)
{
	static String:szServerID[6];
	IntToString(iServerID, szServerID, sizeof(szServerID));
	
	SetTrieValue(g_hTrie_ServerNeedsTimeSent, szServerID, iTimeSent, true);
}

public Action:OnNeed(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!CanUseNeedCommand(iClient))
		return Plugin_Handled;
	
	IssueNeed(iClient, false);
	
	return Plugin_Handled;
}

public Action:OnNeedSub(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!GetConVarBool(cvar_enable_sub))
		return Plugin_Handled;
	
	if(!CanUseNeedCommand(iClient))
		return Plugin_Handled;
	
	IssueNeed(iClient, true);
	
	return Plugin_Handled;
}

bool:CanUseNeedCommand(iClient)
{
	if(!GetConVarBool(cvar_display_to_gameservers) && !GetConVarBool(cvar_display_to_shoutbox))
		return false;
	
	new Float:fDelayRemaining = (g_fLastNeedIssued + GetConVarFloat(cvar_need_command_delay)) - GetEngineTime();
	
	if(g_fLastNeedIssued > 0 && fDelayRemaining > 0)
	{
		CPrintToChat(iClient, "{olive}Wait {lightred}%.02f {olive}seconds before using this command.", fDelayRemaining);
		return false;
	}
	
	return true;
}

IssueNeed(iClient, bool:bIsSub=false)
{
	g_fLastNeedIssued = GetEngineTime();
	
	static String:szServerNameEscaped[SERVER_NAME_MAX_LENGTH*2+1];
	if(!DBServers_GetServerName(szServerNameEscaped, sizeof(szServerNameEscaped)))
		strcopy(szServerNameEscaped, sizeof(szServerNameEscaped), "unknown");
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szServerNameEscaped, szServerNameEscaped, sizeof(szServerNameEscaped)))
		return;
	
	decl iPlayersNeeded;
	
	if(bIsSub)
	{
		iPlayersNeeded = 0;
		
		CPrintToChatAll("{lightred}%N {olive}has created a need sub announcement.", iClient);
	}
	else
	{
		if(GetConVarInt(cvar_maxplayers_override))
		{
			iPlayersNeeded = GetConVarInt(cvar_maxplayers_override);
		}
		else
		{
			iPlayersNeeded = GetMaxHumanPlayers();
			
			if(cvar_reserved_slots != INVALID_HANDLE)
				iPlayersNeeded -= GetConVarInt(cvar_reserved_slots);
		}
		
		iPlayersNeeded -= GetNumRealPlayersInServer();
		
		if(iPlayersNeeded < 1)
			return;
		
		CPrintToChatAll("{lightred}%N {olive}has created a need players announcement.", iClient);
	}
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _,
		"INSERT INTO plugin_server_need_queue (server_id, server_name, players_needed, display_to_gameservers, display_to_shoutbox, time_sent) VALUES (%d, '%s', %d, %d, %d, UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE server_name='%s', players_needed=%d, display_to_gameservers=%d, display_to_shoutbox=%d, time_sent=UNIX_TIMESTAMP()",
		DBServers_GetServerID(), szServerNameEscaped, iPlayersNeeded, GetConVarInt(cvar_display_to_gameservers), GetConVarInt(cvar_display_to_shoutbox), szServerNameEscaped, iPlayersNeeded, GetConVarInt(cvar_display_to_gameservers), GetConVarInt(cvar_display_to_shoutbox));
}

GetNumRealPlayersInServer()
{
	new iCount;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(IsFakeClient(iClient))
			continue;
		
		iCount++;
	}
	
	return iCount;
}