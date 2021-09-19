#include <sourcemod>
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/MovementStyles/movement_styles"
#include "Includes/speed_runs"
#include "Includes/speed_runs_replay_bot"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Stats";
new const String:PLUGIN_VERSION[] = "2.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "The speed run stats plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:cvar_records_page_limit;

new String:g_szAverageMapTimeString[20];
new bool:g_bMapAverageCached = false;

new Float:g_fNextGetStagesCommand[MAXPLAYERS+1];
#define GET_STAGES_COMMAND_DELAY 0.7
new Float:g_fNextGetRecordsCommand[MAXPLAYERS+1];
#define GET_RECORDS_COMMAND_DELAY 0.7


public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}


public OnPluginStart()
{
	CreateConVar("speed_runs_stats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_records_page_limit = CreateConVar("speedruns_stats_records_page_limit", "50", "Number of records to show on the records menu", _, true, 1.0, true, 100.0);

	
	RegConsoleCmd("sm_wr", OnStats);	// World record for the map
	RegConsoleCmd("sm_pr", OnStats);	// Personal record for the map
	RegConsoleCmd("sm_mrank", OnStats);	// Personal map rank
	RegConsoleCmd("sm_top", OnStats);
	RegConsoleCmd("sm_stats", OnStats);
	RegConsoleCmd("sm_record", OnStats);
	RegConsoleCmd("sm_records", OnStats);
	
	RegConsoleCmd("sm_wrpage", OnStatsPage);

	RegConsoleCmd("sm_avg", OnAverage); // Average map time
	RegConsoleCmd("sm_average", OnAverage);
}

public OnClientPutInServer(iClient)
{
	g_fNextGetStagesCommand[iClient] = 0.0;
	g_fNextGetRecordsCommand[iClient] = 0.0;
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public OnMapStart()
{
	g_bMapAverageCached = false;
}

public SpeedRuns_OnNewRecord(iClient, RecordType:iRecordType, eOldRecord[Record], eNewRecord[Record])
{
	GetMapAverageTimeString();
}

public DBMaps_OnMapIDReady()
{
	GetMapAverageTimeString();
}

GetMapAverageTimeString()
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetAverage, DBPrio_Low, _, "\
	SELECT SEC_TO_TIME(AVG(r.stage_time)) \
	FROM ( \
	SELECT stage_time FROM plugin_sr_records \
    WHERE map_id = %i AND \
    stage_number = 0 \
    ) r", DBMaps_GetMapID());
}

public Query_GetAverage(Handle:hDatabase, Handle:hQuery, any:data)
{
	if(hQuery == INVALID_HANDLE)
	{
		return;
	}

	if (SQL_FetchRow(hQuery) && !SQL_IsFieldNull(hQuery, 0))
	{
		SQL_FetchString(hQuery, 0, g_szAverageMapTimeString, sizeof(g_szAverageMapTimeString));

		while (StrContains(g_szAverageMapTimeString, "00:") == 0)
		{
			ReplaceStringEx(g_szAverageMapTimeString, sizeof(g_szAverageMapTimeString), "00:", "");
		}

		g_bMapAverageCached = true;
	}
}

public Action:OnStatsPage(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;

	CPrintToChat(iClient, "{lightgreen}-- {olive}To view the map records:");
	CPrintToChat(iClient, "{lightgreen}-- {olive}Open the scoreboard ({lightred}TAB key{olive}), right click, then click the {lightred}SERVER WEBSITE{olive} button in the bottom left.");

	return Plugin_Handled;
}

public Action:OnAverage(iClient, iArgCount)
{
	if (!iClient)
		return Plugin_Handled;

	if(g_bMapAverageCached)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}The average {red}Map {olive}completion time across all styles is {yellow}%s", g_szAverageMapTimeString);
		return Plugin_Handled;
	}
	else
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Map average completion time has not been loaded yet.");
	}

	return Plugin_Handled;
}

public Action:OnStats(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
		
	CPrintToChat(iClient, "{lightgreen}-- {olive}Visit the website to see the full records leaderboards for all styles. Type {lightred}!wrpage{olive} for instructions.");
	
	new iMapID = DBMaps_GetMapID();
	if(!iMapID)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Required data for stats not loaded yet.");
		return Plugin_Handled;
	}
	
	new Float:fCurTime = GetGameTime();
	if(fCurTime < g_fNextGetStagesCommand[iClient])
	{
		PrintToChat(iClient, "[SM] Please wait a second before using this command again.");
		return Plugin_Handled;
	}

	g_fNextGetStagesCommand[iClient] = fCurTime + GET_STAGES_COMMAND_DELAY;

	DB_TQuery(g_szDatabaseConfigName, Query_GetStages, DBPrio_Low, iClient, "\
		SELECT IF(type = 4, data_int_1, data_int_1+1) as stage, data_string_1 as name FROM plugin_zonemanager_data \
		WHERE map_id = %i AND type in (4, 6) \
		ORDER BY stage ASC",
		iMapID);
	
	return Plugin_Handled;
}

public Query_GetStages(Handle:hDatabase, Handle:hQuery, any:iClient)
{
	if (hQuery == INVALID_HANDLE)
		return;

	if (SQL_GetRowCount(hQuery))
	{
		new Handle:hMenu = CreateMenu(MenuHandle_StageSelect);
		SetMenuTitle(hMenu, "Stages");
		SetMenuPagination(hMenu, 6);
		decl String:szInfo[12];
		AddMenuItem(hMenu, "0", "Map");
		
		decl String:szName[32];
		new iStage;
		while(SQL_FetchRow(hQuery))
		{
			iStage = SQL_FetchInt(hQuery, 0);
			SQL_FetchString(hQuery, 1, szName, sizeof(szName));
			if (StrEqual(szName, ""))
				FormatEx(szName, sizeof(szName), "Stage %i", iStage);

			IntToString(iStage, szInfo, sizeof(szInfo));

			AddMenuItem(hMenu, szInfo, szName);
		}

		DisplayMenu(hMenu, iClient, 0);
	}
	else
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no stages to display.");
	}	
}

public MenuHandle_StageSelect(Handle:hMenu, MenuAction:action, iClient, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;

	new iMapID = DBMaps_GetMapID();
	if(!iMapID)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Required data for stats not loaded yet.");
		return;
	}
	
	new Float:fCurTime = GetGameTime();
	if(fCurTime < g_fNextGetRecordsCommand[iClient])
	{
		PrintToChat(iClient, "[SM] Please wait a second before using this command again.");
		return;
	}

	g_fNextGetRecordsCommand[iClient] = fCurTime + GET_RECORDS_COMMAND_DELAY;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iStage = StringToInt(szInfo);

	new iStyleBits = MovementStyles_GetStyleBits(iClient);

	new iStartOffset = 0;
	new iLimit = GetConVarInt(cvar_records_page_limit);
	
	
	decl String:szBuffer[255];
	new Handle:hStyleNames = CreateArray(MAX_STYLE_NAME_LENGTH);
	if (MovementStyles_GetStyleNamesFromBits(iStyleBits, hStyleNames))
	{
		new iStyles = GetArraySize(hStyleNames);
		if (iStyles)
		{
			szBuffer = "Styles: ";
			decl String:szStyleName[MAX_STYLE_NAME_LENGTH];
			new iBufferLen = 8;
			for(new i = 0; i < GetArraySize(hStyleNames); i++)
			{
				GetArrayString(hStyleNames, i, szStyleName, sizeof(szStyleName));

				if(i != 0)
				iBufferLen += Format(szBuffer[iBufferLen], sizeof(szBuffer)-iBufferLen, ", ");

				iBufferLen += Format(szBuffer[iBufferLen], sizeof(szBuffer)-iBufferLen, "%s", szStyleName);
			}
		}
		else
		{
			szBuffer = "Styles: None";
		}
	}
	else
	{
		szBuffer = "Styles: None";
	}
	CloseHandle(hStyleNames);
	
	decl String:szMenuTitle[255];
	if (iStage == 0)
		FormatEx(szMenuTitle, sizeof(szMenuTitle), "Top %i - Map record - %s", iLimit, szBuffer);
	else
		FormatEx(szMenuTitle, sizeof(szMenuTitle), "Top %i - Stage %i - %s", iLimit, iStage, szBuffer);
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, iClient);
	WritePackString(hPack, szMenuTitle);

	DB_TQuery(g_szDatabaseConfigName, Query_GetRecords, DBPrio_Low, hPack, "\
		SELECT DISTINCT r1.user_id, r1.stage_number, SEC_TO_TIME(r1.stage_time), r1.record_id, \
		(SELECT u.user_name FROM gs_username_stats u \
		 WHERE u.user_id = r1.user_id \
		 ORDER BY u.last_utime DESC \
		 LIMIT 1) \
		 \
		FROM plugin_sr_records r1 \
		\
		INNER JOIN \
		( \
			SELECT user_id, MIN(stage_time) as min_stage_time \
			FROM plugin_sr_records \
			WHERE map_id=%i AND stage_number=%i AND style_bits=%i \
			GROUP BY user_id \
		) r2 \
		ON r1.user_id = r2.user_id \
		AND r1.stage_time = r2.min_stage_time \
		\
		WHERE map_id=%i AND stage_number=%i AND style_bits=%i \
		ORDER BY stage_time ASC, utime_complete ASC \
		LIMIT %i,%i",
		iMapID, iStage, iStyleBits, iMapID, iStage, iStyleBits, iStartOffset, iLimit);
}


public Query_GetRecords(Handle:hDatabase, Handle:hQuery, any:hPack)
{
	ResetPack(hPack, false);
	new iClient = ReadPackCell(hPack);
	decl String:szMenuTitle[255];
	ReadPackString(hPack, szMenuTitle, sizeof(szMenuTitle));
	CloseHandle(hPack);
	
	if (hQuery == INVALID_HANDLE)
		return;

	new Handle:hMenu = CreateMenu(MenuHandle_RecordSelect);
	SetMenuTitle(hMenu, szMenuTitle);

	decl String:szTime[32], String:szRecordID[32], String:szUsername[MAX_NAME_LENGTH+1], String:szBuffer[255];
	new iRecordID;
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 2, szTime, sizeof(szTime));
		
		while (StrContains(szTime, "00:") == 0)
		{
			ReplaceStringEx(szTime, sizeof(szTime), "00:", "");
		}

		iRecordID = SQL_FetchInt(hQuery, 3);
		IntToString(iRecordID, szRecordID, sizeof(szRecordID));
		
		SQL_FetchString(hQuery, 4, szUsername, sizeof(szUsername));
		
		FormatEx(szBuffer, sizeof(szBuffer), "%s - %s", szTime, szUsername);

		AddMenuItem(hMenu, szRecordID, szBuffer);
	}

	if (GetMenuItemCount(hMenu))
		DisplayMenu(hMenu, iClient, 0);
	else
	{
		CloseHandle(hMenu);
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no records to display.");
	}
}

public MenuHandle_RecordSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[32];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iRecordID = StringToInt(szInfo);

	DB_TQuery(g_szDatabaseConfigName, Query_GetRecordStats, DBPrio_Low, iParam1 /*client*/, "\
		SELECT r.record_id, SEC_TO_TIME(r.stage_time) as time_string, r.data_int_1, r.data_int_2, u2.user_name, r.user_id, u1.steam_id, \
		DATE_FORMAT(FROM_UNIXTIME(utime_complete), \"%%b %%D, %%Y\") FROM plugin_sr_records r \
		JOIN core_users u1 \
		JOIN gs_username_stats u2 \
		WHERE u2.user_id = r.user_id and r.record_id = %i \
		AND u1.user_id = r.user_id \
		ORDER BY u2.last_utime DESC \
		LIMIT 1",
		iRecordID);
}

public Query_GetRecordStats(Handle:hDatabase, Handle:hQuery, any:iClient)
{
	if (hQuery == INVALID_HANDLE)
		return;

	if(SQL_FetchRow(hQuery))
	{
		new Handle:hMenu = CreateMenu(MenuHandle_RecordStats);
		SetMenuPagination(hMenu, MENU_NO_PAGINATION);
		SetMenuExitButton(hMenu, true);

		new String:szLabel[255];
		
		decl String:szTime[32];
		SQL_FetchString(hQuery, 1, szTime, sizeof(szTime));
		
		while (StrContains(szTime, "00:") == 0)
		{
			ReplaceStringEx(szTime, sizeof(szTime), "00:", "");
		}
		
		decl String:szUsername[MAX_NAME_LENGTH+1];
		SQL_FetchString(hQuery, 4, szUsername, sizeof(szUsername));
		
		FormatEx(szLabel, sizeof(szLabel), "%s - %s", szTime, szUsername);
		
		SetMenuTitle(hMenu, szLabel);
		
		
		SQL_FetchString(hQuery, 6, szLabel, sizeof(szLabel));
		Format(szLabel, sizeof(szLabel), "STEAM_0:%s", szLabel);
		AddMenuItem(hMenu, "", szLabel, ITEMDRAW_DISABLED);
		
		FormatEx(szLabel, sizeof(szLabel), "Average speed: %i", SQL_FetchInt(hQuery, 1));
		AddMenuItem(hMenu, "", szLabel, ITEMDRAW_DISABLED);
		
		FormatEx(szLabel, sizeof(szLabel), "Jumps: %i", SQL_FetchInt(hQuery, 2));
		AddMenuItem(hMenu, "", szLabel, ITEMDRAW_DISABLED);
		
		SQL_FetchString(hQuery, 7, szLabel, sizeof(szLabel));
		AddMenuItem(hMenu, "", szLabel, ITEMDRAW_DISABLED);

		new String:szInfo[32];
		new iRecordID = SQL_FetchInt(hQuery, 0);
		IntToString(iRecordID, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "Play Replay");

		DisplayMenu(hMenu, iClient, 0);
	}

}

public MenuHandle_RecordStats(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iRecordID = StringToInt(szInfo);
	new iBot = SpeedRunsReplayBot_PlayRecord(iRecordID);
	
	if (!iBot) {
		CPrintToChat(iParam1, "{lightgreen}-- {red}The record was not able to be played.");
		return;
	}
	
	ChangeClientTeam(iParam1, 1);
	SetEntPropEnt(iParam1, Prop_Send, "m_hObserverTarget", iBot);
}
