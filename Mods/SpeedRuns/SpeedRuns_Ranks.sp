#include <sourcemod>
#include <cstrike>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseUsers/database_users"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "Includes/speed_runs"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Ranks";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "The speed rank titles plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_SPEEDRUN_RANKS  15
#define DEFAULT_RANK		"Newb"


new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new bool:g_bHaveSpeedrunRanksLoaded;
new bool:g_bHaveSpeedrunPointsLoaded[MAXPLAYERS+1];
new bool:g_bServersReady;
new bool:g_bTablesLoaded = false;
new g_iSpeedrunRank[MAXPLAYERS+1];

new Handle:g_aSpeedrunRankNames;
new Handle:g_aSpeedrunRankPercentiles;
new Handle:g_aSpeedrunCustomRankIDs;
new Handle:g_aSpeedrunCustomRanks;


new g_iUserSpeedrunPoints[MAXPLAYERS+1];
new g_iSpeedrunRankTotal;

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public OnPluginStart()
{
	CreateConVar("speed_runs_ranks_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aSpeedrunRankNames = CreateArray(32);
	g_aSpeedrunRankPercentiles = CreateArray();
	g_aSpeedrunCustomRankIDs = CreateArray();
	g_aSpeedrunCustomRanks = CreateArray(32);
	
	AddSkillRank(0.0, DEFAULT_RANK, 0);
	
	RegAdminCmd("sm_rankstat", OnRankStat, ADMFLAG_ROOT, "Debug command for rank stats.");
	RegAdminCmd("sm_rankload", OnRankLoad, ADMFLAG_ROOT, "Debug command for rank stats.");
	RegConsoleCmd("sm_rank", OnRank, "Check your server skill rank.");
	RegConsoleCmd("sm_ranklist", OnRankList, "List all server ranks in order of skill.");
}

public OnMapStart()
{
	for(new iClient=0;iClient<=MaxClients;iClient++)
	{
		g_iUserSpeedrunPoints[iClient] = 0;
		g_bHaveSpeedrunPointsLoaded[iClient] = false;
	}
}

public DBMaps_OnMapIDReady(iMapID)
{
	if(!g_bTablesLoaded)
	{
		if(!Query_CreateSpeedrunRanksTable())
			SetFailState("There was an error creating the plugin_sr_points sql table.");

		if(!Query_CreateSpeedrunRankNamesTable())
			SetFailState("There was an error creating the plugin_sr_ranks sql table.");
	
		if(!Query_CreateSpeedrunCustomRanksTable())
			SetFailState("There was an error creating the plugin_sr_custom_ranks sql table.");
	
		g_bTablesLoaded = true;
	}
	
	LoadTotalPoints();
	LoadRankNames();
	LoadCustomRanks();
}

public Action:OnRank(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!g_bHaveSpeedrunPointsLoaded[iClient] || !g_bHaveSpeedrunRanksLoaded)
	{
		PrintToChat(iClient, "[SM] Skill rank data is still loading, please be patient.");
		PrintToConsole(iClient, "[SM] Skill rank data is still loading, please be patient.");
		return Plugin_Handled;
	}

	new iPerc, String:szTemp[32];
	
	GetArrayString(g_aSpeedrunRankNames, g_iSpeedrunRank[iClient], szTemp, sizeof(szTemp));
	
	new iFlat = RoundToFloor(g_iUserSpeedrunPoints[0] * Float:GetArrayCell(g_aSpeedrunRankPercentiles, g_iSpeedrunRank[iClient]));
	new iNext = RoundToFloor(g_iUserSpeedrunPoints[0] * Float:GetArrayCell(g_aSpeedrunRankPercentiles, g_iSpeedrunRank[iClient]+1));
	
	iPerc = ((g_iUserSpeedrunPoints[iClient] - iFlat) *  100) / ((iNext - iFlat));
	
	PrintToChat(iClient, "[SM] Skill rank: %s (%d%% of the way to next rank)", szTemp, iPerc);
	PrintToConsole(iClient, "[SM] Skill rank: %s (%d%% of the way to next rank)", szTemp, iPerc);
	
	return Plugin_Handled;
}


public Action:OnRankStat(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	PrintToChat(iClient, "Displaying user rank.");
	PrintToChat(iClient, "Servers ready: %i", g_bServersReady);
	PrintToChat(iClient, "Rank names loaded: %b", g_bHaveSpeedrunRanksLoaded);
	PrintToChat(iClient, "Your current rank is %i.", g_iSpeedrunRank[iClient]);
	new String:szTemp[64];
	GetArrayString(g_aSpeedrunRankNames, g_iSpeedrunRank[iClient], szTemp, sizeof(szTemp));
	PrintToChat(iClient, "Your rank title: %s.", szTemp);
	PrintToChat(iClient, "You have %d points.", g_iUserSpeedrunPoints[iClient]);
	PrintToChat(iClient, "Total points: %d.", g_iUserSpeedrunPoints[0]);
	CalcUserRank(iClient, true);
	
	new iFlat = RoundToFloor(g_iUserSpeedrunPoints[0] * Float:GetArrayCell(g_aSpeedrunRankPercentiles, g_iSpeedrunRank[iClient]));
	new iNext = RoundToFloor(g_iUserSpeedrunPoints[0] * Float:GetArrayCell(g_aSpeedrunRankPercentiles, g_iSpeedrunRank[iClient]+1));
	
	
	new iPerc = ((g_iUserSpeedrunPoints[iClient] - iFlat) *  100) / ((iNext - iFlat));
	PrintToChat(iClient, "iFlat calculated to: %d", iFlat);
	PrintToChat(iClient, "iNext calculated to: %d", iNext);
	PrintToChat(iClient, "iPerc calculated to: %d", iPerc);
	
	return Plugin_Handled;
}


public Action:OnRankList(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	ReplyToCommand(iClient, "[SM] Skill ranks listed in console.");
	
	PrintToConsole(iClient, "[SM] Skill ranks:");
	PrintToConsole(iClient, "-");
	new String:szTemp[64];
	
	for(new i=g_iSpeedrunRankTotal-1;i>=0;i--)
	{
		GetArrayString(g_aSpeedrunRankNames, i, szTemp, sizeof(szTemp));
		PrintToConsole(iClient, "%d: %s", (g_iSpeedrunRankTotal - i), szTemp);
	}
	
	PrintToConsole(iClient, "-");
	
	return Plugin_Handled;
}

public Action:OnRankLoad(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	PrintToChat(iClient, "Recreating tables.");
	
	new bDone;
	
	
	bDone = Query_CreateSpeedrunRanksTable();
	
	PrintToChat(iClient, "Created points table: %s.", bDone ? "true" : "false");
	
	bDone = Query_CreateSpeedrunRankNamesTable();
	
	PrintToChat(iClient, "Created points table: %s.", bDone ? "true" : "false");
	
	new iUserID = DBUsers_GetUserID(iClient);
	
	PrintToChat(iClient, "Getting points for user with ID %d.", iUserID);
	
	SelectUserPoints(iClient, iUserID);
	
	PrintToChat(iClient, "Loading total points.");
	
	LoadTotalPoints();
	
	PrintToChat(iClient, "Loading rank names.");
	LoadRankNames();
	LoadCustomRanks();
	
	CalcUserRank(iClient, true);
	
	return Plugin_Handled;
}

public OnGameFrame()
{
	SetPlayerTags();
}

bool:Query_CreateSpeedrunRanksTable()
{
	static bool:bTableCreated = false;
	
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_sr_points\
	(\
		user_id					INT UNSIGNED		NOT NULL,\
		server_group_type		SMALLINT UNSIGNED	NOT NULL,\
		points					INT UNSIGNED		NOT NULL,\
		map_id					INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( user_id, server_group_type, map_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateSpeedrunRankNamesTable()
{
	static bool:bNameTableCreated = false;
	if(bNameTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_sr_ranks\
	(\
		percentile				FLOAT				NOT NULL,\
		rank_name				VARCHAR(32)			NOT NULL,\
		server_group_type		SMALLINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( rank_name, server_group_type )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bNameTableCreated = true;
	
	return true;
}

bool:Query_CreateSpeedrunCustomRanksTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_sr_custom_ranks\
	(\
		id						INT UNSIGNED		NOT NULL,\
		rank_name				VARCHAR(32)			NOT NULL,\
		server_group_type		SMALLINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( id, server_group_type )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public Query_SelectSpeedrunPoints(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient;
	if(iClientSerial == 0)
	{
		iClient = 0;
	}
	else
	{
		iClient = GetClientFromSerial(iClientSerial);
		if(!iClient)
			return;
	}
	g_bHaveSpeedrunPointsLoaded[iClient] = true;
	
	if(hQuery == INVALID_HANDLE)
	{
		return;
	}
	
	if(SQL_FetchRow(hQuery))
	{
		g_iUserSpeedrunPoints[iClient] = SQL_FetchInt(hQuery, 0);
	}
	else
	{
		g_iUserSpeedrunPoints[iClient] = 0;
	}
	
	CalcUserRank(iClient);
	
}

public Query_SelectSpeedrunRanks(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{	
	g_bHaveSpeedrunRanksLoaded = true;
	if(hQuery == INVALID_HANDLE)
	{
		return;
	}
	
	ClearArray(g_aSpeedrunRankNames);
	ClearArray(g_aSpeedrunRankPercentiles);
	
	AddSkillRank(0.0, DEFAULT_RANK, 0);
	g_iSpeedrunRankTotal = 1;
	
	decl String:szTemp[32];
	decl Float:fPerc;
	
	while(SQL_FetchRow(hQuery) && g_iSpeedrunRankTotal < 32)
	{
		fPerc = SQL_FetchFloat(hQuery, 1);
		SQL_FetchString(hQuery, 0, szTemp, sizeof(szTemp));
		AddSkillRank(fPerc, szTemp, g_iSpeedrunRankTotal);
		g_iSpeedrunRankTotal++;
	}
	
}
public Query_SelectCustomRanks(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
	{
		return;
	}
	
	ClearArray(g_aSpeedrunCustomRanks);
	ClearArray(g_aSpeedrunCustomRankIDs);
	
	decl String:szTemp[32];
	decl iID;
	
	while(SQL_FetchRow(hQuery) && g_iSpeedrunRankTotal < 32)
	{
		iID = SQL_FetchInt(hQuery, 1);
		SQL_FetchString(hQuery, 0, szTemp, sizeof(szTemp));
		AddCustomRank(iID, szTemp);
	}
}

AddSkillRank(Float:fPerc, String:szName[], iPos=-1)
{
	new iSize = GetArraySize(g_aSpeedrunRankNames);
	if(iPos >= 0 && iPos < iSize)
	{
		SetArrayString(g_aSpeedrunRankNames, iPos, szName);
		SetArrayCell(g_aSpeedrunRankPercentiles, iPos, fPerc);
	}
	else
	{
		PushArrayString(g_aSpeedrunRankNames, szName);
		PushArrayCell(g_aSpeedrunRankPercentiles, fPerc);
	}
}

AddCustomRank(iID, String:szName[])
{
	PushArrayString(g_aSpeedrunCustomRanks, szName);
	PushArrayCell(g_aSpeedrunCustomRankIDs, iID);
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	SelectUserPoints(iClient, iUserID);
}

SelectUserPoints(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_SelectSpeedrunPoints, DBPrio_High, GetClientSerial(iClient), "\
		SELECT points, user_id FROM plugin_sr_points WHERE map_id=0 AND server_group_type=%i AND user_id=%i",
		SpeedRuns_GetServerGroupType(), iUserID);
}

LoadTotalPoints()
{
	DB_TQuery(g_szDatabaseConfigName, Query_SelectSpeedrunPoints, DBPrio_High, 0, "\
		SELECT points, user_id FROM plugin_sr_points WHERE map_id=0 AND server_group_type=%i AND user_id=0",
		SpeedRuns_GetServerGroupType());
}

LoadRankNames()
{
	DB_TQuery(g_szDatabaseConfigName, Query_SelectSpeedrunRanks, DBPrio_High, 0, "\
		SELECT rank_name, percentile FROM plugin_sr_ranks WHERE server_group_type=%i ORDER BY percentile ASC",
		SpeedRuns_GetServerGroupType());
}

LoadCustomRanks()
{
	DB_TQuery(g_szDatabaseConfigName, Query_SelectCustomRanks, DBPrio_High, 0, "\
		SELECT rank_name, id FROM plugin_sr_custom_ranks WHERE server_group_type=%i OR server_group_type=0 GROUP BY id ORDER BY server_group_type DESC",
		SpeedRuns_GetServerGroupType());
}

CalcUserRank(iClient, bool:bDisplay=false)
{
	g_iSpeedrunRank[iClient] = 0;
	
	if(!g_bHaveSpeedrunRanksLoaded)
		return;
	
	if(!g_bHaveSpeedrunPointsLoaded[iClient])
		return;
			
	if(g_iUserSpeedrunPoints[iClient] == 0)
		return;
		
	if(g_iSpeedrunRankTotal == 0)
		return;
		
	new Float:fPerc = float(g_iUserSpeedrunPoints[iClient]) / float(g_iUserSpeedrunPoints[0]);
	
	if(bDisplay)
		PrintToChat(iClient, "fPerc calculated to %f (%d / %d)", fPerc, g_iUserSpeedrunPoints[iClient], g_iSpeedrunRankTotal);
	
	for(new i=1;i<g_iSpeedrunRankTotal;i++)
	{
		if(GetArrayCell(g_aSpeedrunRankPercentiles, i) > fPerc)
			break;
		
		g_iSpeedrunRank[iClient] = i;
	}
	
	new String:szTemp[64];
	GetArrayString(g_aSpeedrunRankNames, g_iSpeedrunRank[iClient], szTemp, sizeof(szTemp));
	
	new iFind = FindValueInArray(g_aSpeedrunCustomRankIDs, DBUsers_GetUserID(iClient));
	if(bDisplay)
		PrintToChat(iClient, "Custom name found at index %d.", iFind);
	if(iFind != -1)
	{
		GetArrayString(g_aSpeedrunCustomRanks, iFind, szTemp, sizeof(szTemp));
		if(bDisplay)
			PrintToChat(iClient, "Got custom name as %s.", szTemp);
	}
	
	CS_SetClientClanTag(iClient, szTemp);
}

SetPlayerTags()
{
	for(new iClient=1;iClient<=MaxClients;iClient++)
	{		
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
			
		if(!g_bHaveSpeedrunPointsLoaded[iClient])
			continue;			
		new String:szTemp[64];
		GetArrayString(g_aSpeedrunRankNames, g_iSpeedrunRank[iClient], szTemp, sizeof(szTemp));
	
		new iFind = FindValueInArray(g_aSpeedrunCustomRankIDs, DBUsers_GetUserID(iClient));
		if(iFind != -1)
			GetArrayString(g_aSpeedrunCustomRanks, iFind, szTemp, sizeof(szTemp));
			
		CS_SetClientClanTag(iClient, szTemp);
	}
}

public OnClientConnected(iClient)
{
	g_bHaveSpeedrunPointsLoaded[iClient] = false;
}

public OnClientDisconnect_Post(iClient)
{
	g_iUserSpeedrunPoints[iClient] = 0;
}
