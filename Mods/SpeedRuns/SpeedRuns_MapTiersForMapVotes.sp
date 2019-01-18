#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Plugins/MapVoting/map_voting"
#include "../../Libraries/DatabaseServers/database_servers"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Map tiers for map votes";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Assigns tier categories to the map votes.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_MAP_NAME_LEN	72

new Handle:g_aMapData;
enum _:MapData
{
	String:MD_MapName[MAX_MAP_NAME_LEN],
	MD_Tier,
	bool:MD_Linear
};

new bool:g_bAreMapsLoaded;
new bool:g_bAreTiersLoaded;

new g_iUniqueMapCounter;

new Handle:g_aAllowedTiers;
new Handle:g_hTrie_TierToCategoryID;

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:cvar_separate_linear;
new bool:g_bSeparateLinear;

public OnPluginStart()
{
	CreateConVar("map_tiers_for_map_votes_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	cvar_separate_linear = CreateConVar("map_tiers_separate_linear", "0", "Create separate categories for linear maps", _, true, 0.0, true, 1.0);
	
	g_aAllowedTiers = CreateArray();
	g_aMapData = CreateArray(MapData);
	g_hTrie_TierToCategoryID = CreateTrie();
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

public OnMapStart()
{
	g_iUniqueMapCounter++;
	
	g_bAreMapsLoaded = false;
	g_bAreTiersLoaded = false;
	
	ClearArray(g_aMapData);
	ClearTrie(g_hTrie_TierToCategoryID);
	
	ClearArray(g_aAllowedTiers);
	GetAllowedTiers();
}

GetAllowedTiers()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/allowed_tiers.txt");
	
	new Handle:kv = CreateKeyValues("Allowed");
	if(!FileToKeyValues(kv, szBuffer))
	{
		CloseHandle(kv);
		return false;
	}
	
	decl String:szTier[16];
	for(new iTier=1; iTier<=6; iTier++)
	{
		IntToString(iTier, szTier, sizeof(szTier));
		
		if(!KvGetNum(kv, szTier))
			continue;
		
		PushArrayCell(g_aAllowedTiers, iTier);
	}
	
	CloseHandle(kv);
	
	return true;
}

public MapVoting_OnMapsLoaded()
{
	g_bAreMapsLoaded = true;
	TryMovingMapsToCategories();
}

public DBMaps_OnMapIDReady(iMapID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetMapTiers, DBPrio_Low, g_iUniqueMapCounter,
	"SELECT t.map_name, t.tier, COALESCE(d.data_int_2, 0) as is_linear FROM plugin_sr_map_tiers t JOIN gs_maps m ON t.map_name = m.map_name LEFT JOIN plugin_zonemanager_data d ON d.game_id = %i AND d.map_id = m.map_id AND d.type = 5 AND d.data_int_1 = 1 WHERE m.game_id = %i ORDER BY t.map_name ASC",
	DBServers_GetGameID(), DBServers_GetGameID()
	);
}

public Query_GetMapTiers(Handle:hDatabase, Handle:hQuery, any:iUniqueMapCounter)
{
	if(g_iUniqueMapCounter != iUniqueMapCounter)
		return;
	
	if(hQuery == INVALID_HANDLE)
		return;

	g_bSeparateLinear = GetConVarBool(cvar_separate_linear);
	
	new Handle:aList = CreateArray(MAX_MAP_NAME_LEN);
	MapVoting_GetMapList(aList, true);
	
	decl String:szMapName[MAX_MAP_NAME_LEN];
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 0, szMapName, sizeof(szMapName));
		
		if(FindStringInArray(aList, szMapName) == -1)
			continue;
		
		AddMapData(szMapName, SQL_FetchInt(hQuery, 1), (SQL_FetchInt(hQuery, 2) != 0));
	}
	
	g_bAreTiersLoaded = true;
	TryMovingMapsToCategories();
}

AddMapData(const String:szMapName[], iTier, bool:bIsLinear)
{
	decl eMapData[MapData];
	strcopy(eMapData[MD_MapName], MAX_MAP_NAME_LEN, szMapName);
	eMapData[MD_Tier] = iTier;
	eMapData[MD_Linear] = bIsLinear;
	
	PushArrayArray(g_aMapData, eMapData);
}

TryMovingMapsToCategories()
{
	if(!g_bAreMapsLoaded || !g_bAreTiersLoaded)
		return;
	
	if (g_bSeparateLinear)
	{
		AddTierCategory("Tier 1 Linear", "T1] [L");
		AddTierCategory("Tier 1 Staged", "T1] [S");
		AddTierCategory("Tier 2 Linear", "T2] [L");
		AddTierCategory("Tier 2 Staged", "T2] [S");
		AddTierCategory("Tier 3 Linear", "T3] [L");
		AddTierCategory("Tier 3 Staged", "T3] [S");
		AddTierCategory("Tier 4 Linear", "T4] [L");
		AddTierCategory("Tier 4 Staged", "T4] [S");
		AddTierCategory("Tier 5 Linear", "T5] [L");
		AddTierCategory("Tier 5 Staged", "T5] [S");
		AddTierCategory("Tier 6 Linear", "T6] [L");
		AddTierCategory("Tier 6 Staged", "T6] [S");
	}
	else
	{
		AddTierCategory("Tier 1", "T1");
		AddTierCategory("Tier 2", "T2");
		AddTierCategory("Tier 3", "T3");
		AddTierCategory("Tier 4", "T4");
		AddTierCategory("Tier 5", "T5");
		AddTierCategory("Tier 6", "T6");
	}

	
	decl eMapData[MapData];
	new iArraySize = GetArraySize(g_aMapData);
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aMapData, i, eMapData);
		
		if(FindValueInArray(g_aAllowedTiers, eMapData[MD_Tier]) == -1)
		{
			MapVoting_RemoveMap(eMapData[MD_MapName]);
			continue;
		}
		
		MoveMapToTierCategory(eMapData[MD_Tier], eMapData[MD_Linear], eMapData[MD_MapName]);
	}
	
	MapVoting_RemoveUnusedCategories();
	
	ClearArray(g_aMapData);
	ClearTrie(g_hTrie_TierToCategoryID);
}

AddTierCategory(const String:szCatName[], const String:szCatTag[])
{
	new iCatID = MapVoting_AddCategory(szCatName, szCatTag);
	if(iCatID == -1)
		return;
	
	SetTrieValue(g_hTrie_TierToCategoryID, szCatTag, iCatID, true);
}

bool:MoveMapToTierCategory(iTier, bool:bIsLinear, const String:szMapName[])
{
	decl String:szCatTag[16];
	if (g_bSeparateLinear)
		FormatEx(szCatTag, sizeof(szCatTag), "T%i] [%s", iTier, bIsLinear ? "L" : "S");
	else
		FormatEx(szCatTag, sizeof(szCatTag), "T%i", iTier);
	
	decl iCatID;
	if(!GetTrieValue(g_hTrie_TierToCategoryID, szCatTag, iCatID))
		return false;
	
	return MapVoting_SwitchMapsCategory(szMapName, iCatID);
}
