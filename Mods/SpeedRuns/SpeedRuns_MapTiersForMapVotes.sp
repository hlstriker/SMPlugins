#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Plugins/MapVoting/map_voting"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Map tiers for map votes";
new const String:PLUGIN_VERSION[] = "1.3";

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
	MD_Tier
};

new bool:g_bAreMapsLoaded;
new bool:g_bAreTiersLoaded;

new g_iUniqueMapCounter;

new Handle:g_aAllowedTiers;
new Handle:g_hTrie_TierToCategoryID;

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];


public OnPluginStart()
{
	CreateConVar("map_tiers_for_map_votes_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
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
	DB_TQuery(g_szDatabaseConfigName, Query_GetMapTiers, DBPrio_Low, g_iUniqueMapCounter, "SELECT map_name, tier FROM plugin_sr_map_tiers ORDER BY map_name ASC");
}

public Query_GetMapTiers(Handle:hDatabase, Handle:hQuery, any:iUniqueMapCounter)
{
	if(g_iUniqueMapCounter != iUniqueMapCounter)
		return;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	new Handle:aList = CreateArray(MAX_MAP_NAME_LEN);
	MapVoting_GetMapList(aList);
	
	decl String:szMapName[MAX_MAP_NAME_LEN];
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 0, szMapName, sizeof(szMapName));
		
		if(FindStringInArray(aList, szMapName) == -1)
			continue;
		
		AddMapData(szMapName, SQL_FetchInt(hQuery, 1));
	}
	
	g_bAreTiersLoaded = true;
	TryMovingMapsToCategories();
}

AddMapData(const String:szMapName[], iTier)
{
	decl eMapData[MapData];
	strcopy(eMapData[MD_MapName], MAX_MAP_NAME_LEN, szMapName);
	eMapData[MD_Tier] = iTier;
	
	PushArrayArray(g_aMapData, eMapData);
}

TryMovingMapsToCategories()
{
	if(!g_bAreMapsLoaded || !g_bAreTiersLoaded)
		return;
	
	AddTierCategory(1, "Tier 1", "T1");
	AddTierCategory(2, "Tier 2", "T2");
	AddTierCategory(3, "Tier 3", "T3");
	AddTierCategory(4, "Tier 4", "T4");
	AddTierCategory(5, "Tier 5", "T5");
	AddTierCategory(6, "Tier 6", "T6");
	
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
		
		MoveMapToTierCategory(eMapData[MD_Tier], eMapData[MD_MapName]);
	}
	
	MapVoting_RemoveUnusedCategories();
	
	ClearArray(g_aMapData);
	ClearTrie(g_hTrie_TierToCategoryID);
}

AddTierCategory(iTier, const String:szCatName[], const String:szCatTag[])
{
	new iCatID = MapVoting_AddCategory(szCatName, szCatTag);
	if(iCatID == -1)
		return;
	
	decl String:szTier[16];
	IntToString(iTier, szTier, sizeof(szTier));
	
	SetTrieValue(g_hTrie_TierToCategoryID, szTier, iCatID, true);
}

bool:MoveMapToTierCategory(iTier, const String:szMapName[])
{
	decl String:szTier[16];
	IntToString(iTier, szTier, sizeof(szTier));
	
	decl iCatID;
	if(!GetTrieValue(g_hTrie_TierToCategoryID, szTier, iCatID))
		return false;
	
	return MapVoting_SwitchMapsCategory(szMapName, iCatID);
}