#include <sourcemod>
#include <regex>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseUsers/database_users"
#include "../../Libraries/DatabaseMapSessions/database_map_sessions"
#include "../../Libraries/DemoSessions/demo_sessions"
#include "../../Libraries/Admins/admins"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Log admin activity";
new const String:PLUGIN_VERSION[] = "1.10";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Logs admin activity to the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define COMMAND_TEXT_LEN 45
#define COMMAND_INFO_LEN 255

#define MAX_COMMANDS_IN_CONFIG_FILE 512
new String:g_szCommandFilter[MAX_COMMANDS_IN_CONFIG_FILE][COMMAND_TEXT_LEN+1];
new g_iNumCommandsFiltered;

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new bool:g_bCanLog;


public OnPluginStart()
{
	CreateConVar("log_admin_activity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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
	Query_CreateAdminActivityTable();
}

bool:Query_CreateAdminActivityTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_admin_activity\
	(\
		activity_id			INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		server_id			SMALLINT UNSIGNED	NOT NULL,\
		map_sess_id			INT UNSIGNED		NOT NULL,\
		demo_sess_id		INT UNSIGNED		NOT NULL,\
		demo_tick_sent		INT UNSIGNED		NOT NULL,\
		client_user_id		INT UNSIGNED		NOT NULL,\
		target_user_id		INT UNSIGNED		NOT NULL,\
		client_admin_level	SMALLINT UNSIGNED	NOT NULL,\
		target_admin_level	SMALLINT UNSIGNED	NOT NULL,\
		is_client_server	BIT( 1 )			NOT NULL,\
		is_target_bot		BIT( 1 )			NOT NULL,\
		command_text		VARCHAR( 45 )		NOT NULL,\
		command_info		VARCHAR( 255 )		NOT NULL,\
		activity_utime		INT					NOT NULL,\
		PRIMARY KEY ( activity_id ),\
		INDEX ( map_sess_id ),\
		INDEX ( client_user_id )\
	)\
	CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_admin_activity sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public Action:OnLogAction(Handle:hSource, Identity:ident, iClient, iTarget, const String:szMessage[])
{
	if(!g_bCanLog)
		return;
	
	// Try to find the command that was used with regex.
	new RegexError:regError;
	new Handle:hRegex = CompileRegex("^\".*<.*><.*><.*>\" ([A-Z a-z0-9_-]+) ?(\".*<.*><.*><.*>\")? ?(\\(.*\\)$)? ?(\"(.*)\"$)?", 0, _, _, regError);
	if(hRegex == INVALID_HANDLE)
		return;
	
	if(regError != REGEX_ERROR_NONE)
	{
		CloseHandle(hRegex);
		return;
	}
	
	new iNumSubStrings = MatchRegex(hRegex, szMessage, regError);
	if(iNumSubStrings < 2 || regError != REGEX_ERROR_NONE) // We check if it's less than 2 because the first substring is the full command.
	{
		CloseHandle(hRegex);
		return;
	}
	
	static String:szCommandText[COMMAND_TEXT_LEN+1], String:szCommandInfo[COMMAND_INFO_LEN+1];
	szCommandText[0] = '\x0';
	szCommandInfo[0] = '\x0';
	
	for(new iSubString=1; iSubString<iNumSubStrings; iSubString++)
	{
		if(iSubString == 1)
		{
			GetRegexSubString(hRegex, iSubString, szCommandText, sizeof(szCommandText));
		}
		/*
		else if(iSubString == 2 && iNumSubStrings == 3)
		{
			GetRegexSubString(hRegex, iSubString, szCommandInfo, sizeof(szCommandInfo));
		}
		*/
		else if(iSubString == 3 && iNumSubStrings == 4)
		{
			GetRegexSubString(hRegex, iSubString, szCommandInfo, sizeof(szCommandInfo));
		}
		else if(iSubString == 5 && iNumSubStrings == 6)
		{
			GetRegexSubString(hRegex, iSubString, szCommandInfo, sizeof(szCommandInfo));
		}
	}
	
	CloseHandle(hRegex);
	TrimString(szCommandText);
	
	// If the command text is filtered we don't want to log it in the database.
	for(new i=0; i<g_iNumCommandsFiltered; i++)
	{
		if(StrEqual(szCommandText, g_szCommandFilter[i]))
			return;
	}
	
	// Get client information.
	new iClientUserID, iClientAdminLevel, bool:bClientIsServer; // A client user_id of 0 is either unknown or the server.
	if(1 <= iClient <= MaxClients)
	{
		iClientUserID = DBUsers_GetUserID(iClient);
		iClientAdminLevel = _:GetAdminsLevel(iClient);
	}
	else if(iClient == 0)
	{
		bClientIsServer = true;
	}
	
	// Don't "changed cvar" commands sent from the server to prevent log spam.
	if(bClientIsServer)
	{
		if(StrEqual(szCommandText, "changed cvar"))
			return;
	}
	
	// Get target information.
	new iTargetUserID, iTargetAdminLevel, bool:bTargetIsBot; // A target user_id of 0 is either unknown or a bot.
	if(1 <= iTarget <= MaxClients)
	{
		if(IsFakeClient(iTarget))
		{
			bTargetIsBot = true;
		}
		else
		{
			iTargetUserID = DBUsers_GetUserID(iTarget);
			iTargetAdminLevel = _:GetAdminsLevel(iTarget);
		}
	}
	
	LogCommandToDatabase(iClientUserID, iClientAdminLevel, bClientIsServer, iTargetUserID, iTargetAdminLevel, bTargetIsBot, szCommandText, szCommandInfo);
	SendCommandToSourceTV(iClient, iTarget, szCommandText, szCommandInfo);
}

LogCommandToDatabase(iClientUserID, iClientAdminLevel, bool:bClientIsServer, iTargetUserID, iTargetAdminLevel, bool:bTargetIsBot, const String:szCommandText[], const String:szCommandInfo[])
{
	static String:szCommandTextSafe[COMMAND_TEXT_LEN*2+1];
	static String:szCommandInfoSafe[COMMAND_INFO_LEN*2+1];
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szCommandText, szCommandTextSafe, sizeof(szCommandTextSafe)))
		return;
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szCommandInfo, szCommandInfoSafe, sizeof(szCommandInfoSafe)))
		return;
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		INSERT INTO gs_admin_activity \
		(server_id, map_sess_id, demo_sess_id, demo_tick_sent, client_user_id, target_user_id, client_admin_level, target_admin_level, is_client_server, is_target_bot, command_text, command_info, activity_utime) \
		VALUES \
		(%i, %i, %i, %i, %i, %i, %i, %i, %i, %i, '%s', '%s', UNIX_TIMESTAMP())",
		DBServers_GetServerID(), DBMapSessions_GetSessionID(), DemoSessions_GetID(), DemoSessions_GetCurrentTick(), iClientUserID, iTargetUserID, iClientAdminLevel, iTargetAdminLevel, bClientIsServer, bTargetIsBot, szCommandTextSafe, szCommandInfoSafe);
}

AdminLevel:GetAdminsLevel(iClient)
{
	new AdminLevel:iLevel = Admins_GetLevel(iClient);
	if(iLevel < AdminLevel_None)
		iLevel = AdminLevel_None;
	
	return iLevel;
}

SendCommandToSourceTV(iClient, iTarget, const String:szCommandText[], const String:szCommandInfo[])
{
	static String:szTargetText[48];
	szTargetText[0] = '\x0';
	
	if(1 <= iTarget <= MaxClients)
	{
		GetClientName(iTarget, szTargetText, sizeof(szTargetText));
		Format(szTargetText, sizeof(szTargetText), " Target: %s", szTargetText);
	}
	
	for(new iSourceTV=1; iSourceTV<=MaxClients; iSourceTV++)
	{
		if(!IsClientInGame(iSourceTV) || !IsClientSourceTV(iSourceTV))
			continue;
		
		PrintToChat(iSourceTV, "%N %s (%s).%s", iClient, szCommandText, szCommandInfo, szTargetText);
	}
}

public OnMapStart()
{
	g_iNumCommandsFiltered = 0;
	LoadFilteredCommands();
}

public OnConfigsExecuted()
{
	g_bCanLog = true;
}

public OnMapEnd()
{
	g_bCanLog = false;
}

bool:LoadFilteredCommands()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/swoobles/admin_activity_filtered_commands.txt");
	
	new Handle:hFile = OpenFile(szBuffer, "r");
	if(hFile == INVALID_HANDLE)
		return false;
	
	while(!IsEndOfFile(hFile))
	{
		if(!ReadFileLine(hFile, szBuffer, sizeof(szBuffer)))
			continue;
		
		TrimString(szBuffer);
		
		if(strlen(szBuffer) < 3)
			continue;
		
		if((szBuffer[0] == '/' && szBuffer[1] == '/') || szBuffer[0] == '#')
			continue;
		
		if(g_iNumCommandsFiltered >= MAX_COMMANDS_IN_CONFIG_FILE)
		{
			LogError("The filter array is full. If you want to add more command texts please recompile the plugin.");
			break;
		}
		
		strcopy(g_szCommandFilter[g_iNumCommandsFiltered], sizeof(g_szCommandFilter[]), szBuffer);
		g_iNumCommandsFiltered++;
	}
	
	CloseHandle(hFile);
	return true;
}