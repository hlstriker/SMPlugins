#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseMaps/database_maps"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_VERSION[] = "3.3";

public Plugin:myinfo =
{
	name = "Rotating Messages",
	author = "hlstriker",
	description = "Shows messages to the players",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

enum _:Messages
{
	MessageNumLines,
	Handle:MessageLines
};

new Handle:g_aMessages;
new g_iOnMessageIndex;

new Handle:cvar_sv_message_rotation_time;

new String:g_szDatabaseConfigName[64];
new Handle:cvar_database_servers_configname;

new Handle:g_hTimer_Messages;


public OnPluginStart()
{
	CreateConVar("rotating_messages_ver", PLUGIN_VERSION, "Shows messages to the players", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aMessages = CreateArray(Messages);
	cvar_sv_message_rotation_time = CreateConVar("sv_message_rotation_time", "100", "The number of seconds between each message.");
	
	RegAdminCmd("sm_reloadmessages", Command_ReloadMessages, ADMFLAG_ROOT, "sm_reloadmessages - Reloads the rotating messages.");
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
	Query_CreateTable_RotatingMessages();
}

bool:Query_CreateTable_RotatingMessages()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_rotating_messages\
	(\
		id			INT					NOT NULL	AUTO_INCREMENT,\
		message		TEXT				NOT NULL,\
		server_id	SMALLINT UNSIGNED	NOT NULL,\
		ordering	TINYINT UNSIGNED	NOT NULL,\
		enabled		BIT( 1 )			NOT NULL	DEFAULT 1,\
		PRIMARY KEY ( id ),\
		INDEX ( enabled, server_id, ordering )\
	) CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the plugin_rotating_messages sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public Action:Command_ReloadMessages(iClient, iArgs)
{
	LoadMessages();
	ReplyToCommand(iClient, "[SM] Reloading the rotating messages.");
	return Plugin_Handled;
}

public DBMaps_OnMapIDReady(iMapID)
{
	LoadMessages();
}

LoadMessages()
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetMessages, DBPrio_Low, _, "SELECT message FROM plugin_rotating_messages WHERE enabled=1 AND (server_id=0 OR server_id=%i) ORDER BY ordering ASC", DBServers_GetServerID());
}

public Query_GetMessages(Handle:hDatabase, Handle:hQuery, any:iUniqueMapCounter)
{
	StopTimer();
	g_iOnMessageIndex = 0;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	// Close the old message line handles.
	decl eMessage[Messages];
	for(new i=0; i<GetArraySize(g_aMessages); i++)
	{
		GetArrayArray(g_aMessages, i, eMessage);
		CloseHandle(eMessage[MessageLines]);
	}
	
	// Clear the old messages.
	ClearArray(g_aMessages);
	
	// Load in the new messages.
	decl String:szBuffer[1024], String:szExplode[10][255], String:szKey[3], i, String:szNewLine[2], String:szCarriage[2];
	szNewLine[0] = 0x0A;
	szCarriage[0] = 0x0D;
	szNewLine[1] = szCarriage[1] = 0x00;
	
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 0, szBuffer, sizeof(szBuffer));
		
		// Trim any whitespace characters.
		TrimString(szBuffer);
		
		// Remove new lines and carriage returns.
		ReplaceString(szBuffer, sizeof(szBuffer), szNewLine, "", true);
		ReplaceString(szBuffer, sizeof(szBuffer), szCarriage, "", true);
		
		// Make sure this isn't an empty line.
		if(strlen(szBuffer) < 3)
			continue;
		
		// Make sure this isn't a comment.
		if((szBuffer[0] == '/' && szBuffer[1] == '/') || szBuffer[0] == '#')
			continue;
		
		eMessage[MessageNumLines] = ExplodeString(szBuffer, "\\n", szExplode, sizeof(szExplode), sizeof(szExplode[]));
		if(!eMessage[MessageNumLines])
			continue;
		
		eMessage[MessageLines] = CreateTrie();
		for(i=0; i<eMessage[MessageNumLines]; i++)
		{
			IntToString(i+1, szKey, sizeof(szKey));
			SetTrieString(eMessage[MessageLines], szKey, szExplode[i]);
		}
		
		PushArrayArray(g_aMessages, eMessage);
	}
	
	// Start timer if needed.
	if(GetArraySize(g_aMessages))
		StartTimer();
}

StartTimer()
{
	StopTimer();
	g_hTimer_Messages = CreateTimer(GetConVarFloat(cvar_sv_message_rotation_time), DisplayMessage, _, TIMER_REPEAT);
}

StopTimer()
{
	if(g_hTimer_Messages == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Messages);
	g_hTimer_Messages = INVALID_HANDLE;
}

public Action:DisplayMessage(Handle:hTimer)
{
	if(GetArraySize(g_aMessages) <= g_iOnMessageIndex)
		return;
	
	decl eMessage[Messages];
	GetArrayArray(g_aMessages, g_iOnMessageIndex, eMessage);
	
	decl String:szBuffer[255], String:szKey[3];
	for(new iLine=1; iLine<=eMessage[MessageNumLines]; iLine++)
	{
		IntToString(iLine, szKey, sizeof(szKey));
		if(!GetTrieString(eMessage[MessageLines], szKey, szBuffer, sizeof(szBuffer)))
			continue;
		
		CPrintToChatAll(szBuffer);
	}
	
	g_iOnMessageIndex++;
	if(g_iOnMessageIndex >= GetArraySize(g_aMessages))
		g_iOnMessageIndex = 0;
}