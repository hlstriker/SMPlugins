#include <sourcemod>
#include <emitsoundany>
#include <sdktools_stringtables>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseUsers/database_users"
#include "../../Libraries/FileDownloader/file_downloader"
#include "store"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ParticleManager/particle_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma dynamic 500000

new const String:PLUGIN_NAME[] = "API: Store";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API for the store.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_bridge_configname;
new String:g_szDatabaseBridgeConfigName[64];

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseServersConfigName[64];

new Handle:g_hTrie_ItemIDToInventoryIndex;
new Handle:g_aInventoryItems;
enum _:InventoryItem
{
	ITEM_ID,
	ITEM_PRICE,
	ITEM_TYPE,
	String:ITEM_NAME[MAX_STORE_ITEM_NAME_LEN],
	String:ITEM_DATA_STRING_1[MAX_STORE_DATA_STRING_LEN],
	Handle:ITEM_FILE_INDEXES,
	ITEM_MAIN_FILE_INDEX,
	bool:ITEM_ENABLED
};

new Handle:g_aItemFiles;
enum _:ItemFile
{
	ITEMFILE_PRECACHE_TYPE,
	ITEMFILE_PRECACHE_ID,
	String:ITEMFILE_PATH[PLATFORM_MAX_PATH]
};

new Handle:g_aDownloadQueue;

enum
{
	PRECACHE_TYPE_NONE = 0,
	PRECACHE_TYPE_MODEL,
	PRECACHE_TYPE_SOUND,
	PRECACHE_TYPE_DECAL,
	PRECACHE_TYPE_PARTICLE_FILE,
	NUM_PRECACHE_TYPES
};

new Handle:g_aClientItems[MAXPLAYERS+1];
new Handle:g_aClientSettings[MAXPLAYERS+1];
new Handle:g_aTrie_ClientSettingsTypeToIndex[MAXPLAYERS+1];
enum _:ClientSettings
{
	CLIENTSETTING_TYPE,
	CLIENTSETTING_VALUE
};

new Handle:cvar_plugin_files_url;

new Handle:g_hFwd_OnItemsReady;

new bool:g_bLibLoaded_ParticleManager;


public OnPluginStart()
{
	CreateConVar("api_store_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_plugin_files_url = FindConVar("plugin_files_url")) == INVALID_HANDLE)
		cvar_plugin_files_url = CreateConVar("plugin_files_url", "", "A URL that points to the web path that stores plugin files.");
	
	g_hTrie_ItemIDToInventoryIndex = CreateTrie();
	g_aInventoryItems = CreateArray(InventoryItem);
	g_aItemFiles = CreateArray(ItemFile);
	g_aDownloadQueue = CreateArray(PLATFORM_MAX_PATH);
	
	for(new iClient=1; iClient<sizeof(g_aClientItems); iClient++)
	{
		g_aClientItems[iClient] = CreateArray();
		g_aClientSettings[iClient] = CreateArray(ClientSettings);
		g_aTrie_ClientSettingsTypeToIndex[iClient] = CreateTrie();
	}
	
	g_hFwd_OnItemsReady = CreateGlobalForward("Store_OnItemsReady", ET_Ignore);
}

public OnAllPluginsLoaded()
{
	cvar_database_bridge_configname = FindConVar("sm_database_bridge_configname");
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
	
	g_bLibLoaded_ParticleManager = LibraryExists("particle_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = false;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("store");
	CreateNative("Store_CanClientUseItem", _Store_CanClientUseItem);
	CreateNative("Store_FindItemByType", _Store_FindItemByType);
	CreateNative("Store_GetItemsMainFilePath", _Store_GetItemsMainFilePath);
	CreateNative("Store_GetItemsMainFilePrecacheID", _Store_GetItemsMainFilePrecacheID);
	CreateNative("Store_GetItemsDataString", _Store_GetItemsDataString);
	CreateNative("Store_GetClientSettings", _Store_GetClientSettings);
	
	return APLRes_Success;
}

public _Store_GetClientSettings(Handle:hPlugin, iNumParams)
{
	static iClient, iSettingType, String:szSettingType[12], iIndex;
	iClient = GetNativeCell(1);
	iSettingType = GetNativeCell(2);
	
	IntToString(iSettingType, szSettingType, sizeof(szSettingType));
	if(!GetTrieValue(g_aTrie_ClientSettingsTypeToIndex[iClient], szSettingType, iIndex))
		return 0;
	
	static eClientSettings[ClientSettings];
	GetArrayArray(g_aClientSettings[iClient], iIndex, eClientSettings);
	
	return eClientSettings[CLIENTSETTING_VALUE];
}

public _Store_GetItemsDataString(Handle:hPlugin, iNumParams)
{
	static String:szItemID[12], iIndex;
	IntToString(GetNativeCell(1), szItemID, sizeof(szItemID));
	if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
		return 0;
	
	new iStringNum = GetNativeCell(2);
	if(iStringNum < 1 || iStringNum > 1)
		return 0;
	
	decl eItem[InventoryItem];
	GetArrayArray(g_aInventoryItems, iIndex, eItem);
	
	switch(iStringNum)
	{
		case 1: SetNativeString(3, eItem[ITEM_DATA_STRING_1], GetNativeCell(4));
	}
	
	return true;
}

public _Store_GetItemsMainFilePath(Handle:hPlugin, iNumParams)
{
	static String:szItemID[12], iIndex;
	IntToString(GetNativeCell(1), szItemID, sizeof(szItemID));
	if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
		return 0;
	
	decl eItem[InventoryItem];
	GetArrayArray(g_aInventoryItems, iIndex, eItem);
	if(eItem[ITEM_MAIN_FILE_INDEX] == -1)
		return 0;
	
	decl eFile[ItemFile];
	GetArrayArray(g_aItemFiles, eItem[ITEM_MAIN_FILE_INDEX], eFile);
	
	SetNativeString(2, eFile[ITEMFILE_PATH], GetNativeCell(3));
	return true;
}

public _Store_GetItemsMainFilePrecacheID(Handle:hPlugin, iNumParams)
{
	static String:szItemID[12], iIndex;
	IntToString(GetNativeCell(1), szItemID, sizeof(szItemID));
	if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
		return 0;
	
	decl eItem[InventoryItem];
	GetArrayArray(g_aInventoryItems, iIndex, eItem);
	if(eItem[ITEM_MAIN_FILE_INDEX] == -1)
		return 0;
	
	decl eFile[ItemFile];
	GetArrayArray(g_aItemFiles, eItem[ITEM_MAIN_FILE_INDEX], eFile);
	
	return eFile[ITEMFILE_PRECACHE_ID];
}

public _Store_CanClientUseItem(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new iItemID = GetNativeCell(2);
	
	if(FindValueInArray(g_aClientItems[iClient], iItemID) == -1)
		return false;
	
	// TODO: Check if item is active.
	// -->
	
	return true;
}

public _Store_FindItemByType(Handle:hPlugin, iNumParams)
{
	new iStartIndex = GetNativeCell(1) + 1;
	new iItemType = GetNativeCell(2);
	
	if(iStartIndex < 0)
		iStartIndex = 0;
	
	decl eItem[InventoryItem];
	for(new i=iStartIndex; i<GetArraySize(g_aInventoryItems); i++)
	{
		GetArrayArray(g_aInventoryItems, i, eItem);
		if(eItem[ITEM_TYPE] != iItemType)
			continue;
		
		if(!eItem[ITEM_ENABLED])
			continue;
		
		SetNativeCellRef(3, eItem[ITEM_ID]);
		return i;
	}
	
	return -1;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseServersConfigName, Query_GetUserItems, DBPrio_Low, GetClientSerial(iClient), "\
		SELECT item_id FROM store_user_items WHERE user_id = %i", iUserID);
}

public Query_GetUserItems(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	decl iItemID;
	while(SQL_FetchRow(hQuery))
	{
		iItemID = SQL_FetchInt(hQuery, 0);
		PushArrayCell(g_aClientItems[iClient], iItemID);
	}
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_bridge_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_bridge_configname, g_szDatabaseBridgeConfigName, sizeof(g_szDatabaseBridgeConfigName));
	
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseServersConfigName, sizeof(g_szDatabaseServersConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_StoreItems())
		SetFailState("There was an error creating the store_items sql table.");
	
	if(!Query_CreateTable_StoreFiles())
		SetFailState("There was an error creating the store_files sql table.");
	
	if(!Query_CreateTable_StoreInventory())
		SetFailState("There was an error creating the store_inventory sql table.");
	
	if(!Query_CreateTable_StoreUserItems())
		SetFailState("There was an error creating the store_user_items sql table.");
	
	if(!Query_CreateTable_StoreUserSettings())
		SetFailState("There was an error creating the store_user_settings sql table.");
	
	new Handle:hItemIDs = CreateArray();
	
	if(!Query_GetInventory(hItemIDs))
	{
		CloseHandle(hItemIDs);
		SetFailState("Could not select from the store_inventory table.");
	}
	
	if(!Query_GetItems(hItemIDs))
	{
		CloseHandle(hItemIDs);
		SetFailState("Could not select from the store_items table.");
	}
	
	if(!Query_GetFiles(hItemIDs))
	{
		CloseHandle(hItemIDs);
		SetFailState("Could not select from the store_files table.");
	}
	
	CloseHandle(hItemIDs);
	
	Forward_OnItemsReady();
}

public OnClientPutInServer(iClient)
{
	ClearArray(g_aClientItems[iClient]);
	ClearArray(g_aClientSettings[iClient]);
	ClearTrie(g_aTrie_ClientSettingsTypeToIndex[iClient]);
}

Forward_OnItemsReady()
{
	Call_StartForward(g_hFwd_OnItemsReady);
	Call_Finish();
}

bool:Query_GetInventory(const Handle:hItemIDs)
{
	static bool:bRanQuery = false;
	if(bRanQuery)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "SELECT item_id, item_price FROM store_inventory WHERE game_id = %i", DBServers_GetGameID());
	if(hQuery == INVALID_HANDLE)
		return false;
	
	decl eItem[InventoryItem], iIndex, String:szItemID[12];
	
	while(SQL_FetchRow(hQuery))
	{
		eItem[ITEM_ID] = SQL_FetchInt(hQuery, 0);
		eItem[ITEM_PRICE] = SQL_FetchInt(hQuery, 1);
		eItem[ITEM_ENABLED] = false;
		eItem[ITEM_FILE_INDEXES] = INVALID_HANDLE;
		iIndex = PushArrayArray(g_aInventoryItems, eItem);
		
		IntToString(eItem[ITEM_ID], szItemID, sizeof(szItemID));
		SetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex);
		
		PushArrayCell(hItemIDs, eItem[ITEM_ID]);
	}
	
	DB_CloseQueryHandle(hQuery);
	bRanQuery = true;
	
	return true;
}

bool:Query_GetItems(const Handle:hItemIDs)
{
	static bool:bRanQuery = false;
	if(bRanQuery)
		return true;
	
	new iArraySize = GetArraySize(hItemIDs);
	if(!iArraySize)
		return true;
	
	new iQuerySize = 128 + (iArraySize * 7);
	decl String:szQuery[iQuerySize];
	new iLen = FormatEx(szQuery, iQuerySize, "SELECT item_id, item_type, item_name, data_string1 FROM store_items WHERE item_id IN (");
	
	decl iItemID;
	for(new i=0; i<iArraySize; i++)
	{
		iItemID = GetArrayCell(hItemIDs, i);
		
		if(!i)
			iLen += FormatEx(szQuery[iLen], iQuerySize-iLen, "%i", iItemID);
		else
			iLen += FormatEx(szQuery[iLen], iQuerySize-iLen, ",%i", iItemID);
	}
	
	iLen += StrCat(szQuery[iLen], iQuerySize-iLen, ")");
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, szQuery);
	if(hQuery == INVALID_HANDLE)
		return false;
	
	decl eItem[InventoryItem], iIndex, String:szItemID[12];
	
	while(SQL_FetchRow(hQuery))
	{
		eItem[ITEM_ID] = SQL_FetchInt(hQuery, 0);
		IntToString(eItem[ITEM_ID], szItemID, sizeof(szItemID));
		if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
			continue;
		
		GetArrayArray(g_aInventoryItems, iIndex, eItem);
		eItem[ITEM_TYPE] = SQL_FetchInt(hQuery, 1);
		
		SQL_FetchString(hQuery, 2, eItem[ITEM_NAME], MAX_STORE_ITEM_NAME_LEN);
		SQL_FetchString(hQuery, 3, eItem[ITEM_DATA_STRING_1], MAX_STORE_DATA_STRING_LEN);
		SetArrayArray(g_aInventoryItems, iIndex, eItem);
	}
	
	DB_CloseQueryHandle(hQuery);
	bRanQuery = true;
	
	return true;
}

bool:Query_GetFiles(const Handle:hItemIDs)
{
	static bool:bRanQuery = false;
	if(bRanQuery)
		return true;
	
	new iArraySize = GetArraySize(hItemIDs);
	if(!iArraySize)
		return true;
	
	new iQuerySize = 128 + (iArraySize * 7);
	decl String:szQuery[iQuerySize];
	new iLen = FormatEx(szQuery, iQuerySize, "SELECT item_id, file_path, precache_type FROM store_files WHERE item_id IN (");
	
	decl iItemID;
	for(new i=0; i<iArraySize; i++)
	{
		iItemID = GetArrayCell(hItemIDs, i);
		
		if(!i)
			iLen += FormatEx(szQuery[iLen], iQuerySize-iLen, "%i", iItemID);
		else
			iLen += FormatEx(szQuery[iLen], iQuerySize-iLen, ",%i", iItemID);
	}
	
	iLen += StrCat(szQuery[iLen], iQuerySize-iLen, ")");
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, szQuery);
	if(hQuery == INVALID_HANDLE)
		return false;
	
	decl eItem[InventoryItem], iIndex, String:szItemID[12], eFile[ItemFile];
	
	while(SQL_FetchRow(hQuery))
	{
		eItem[ITEM_ID] = SQL_FetchInt(hQuery, 0);
		IntToString(eItem[ITEM_ID], szItemID, sizeof(szItemID));
		if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
			continue;
		
		SQL_FetchString(hQuery, 1, eFile[ITEMFILE_PATH], PLATFORM_MAX_PATH);
		eFile[ITEMFILE_PRECACHE_TYPE] = SQL_FetchInt(hQuery, 2);
		
		GetArrayArray(g_aInventoryItems, iIndex, eItem);
		
		if(eItem[ITEM_FILE_INDEXES] == INVALID_HANDLE)
			eItem[ITEM_FILE_INDEXES] = CreateArray();
		
		PushArrayCell(eItem[ITEM_FILE_INDEXES], PushArrayArray(g_aItemFiles, eFile));
		SetArrayArray(g_aInventoryItems, iIndex, eItem);
		
		if(!IsFileDownloaded(eFile[ITEMFILE_PATH]))
			AddFileToDownloadQueue(eFile[ITEMFILE_PATH]);
		
		if(!IsFileDownloaded("%s.bz2", eFile[ITEMFILE_PATH]))
			AddFileToDownloadQueue("%s.bz2", eFile[ITEMFILE_PATH]);
	}
	
	DB_CloseQueryHandle(hQuery);
	bRanQuery = true;
	
	AddToDownloadsTableAndPrecache();
	
	return true;
}

public OnMapStart()
{
	AddToDownloadsTableAndPrecache();
}

AddToDownloadsTableAndPrecache()
{
	decl eItem[InventoryItem], eFile[ItemFile], j, iIndex;
	new iArraySize = GetArraySize(g_aInventoryItems);
	
	// Initial loop to enable all the items by default.
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aInventoryItems, i, eItem);
		
		// Don't enable items that don't have a type.
		if(!eItem[ITEM_TYPE])
			continue;
		
		eItem[ITEM_ENABLED] = true;
		eItem[ITEM_MAIN_FILE_INDEX] = -1;
		SetArrayArray(g_aInventoryItems, i, eItem);
	}
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aInventoryItems, i, eItem);
		
		if(eItem[ITEM_FILE_INDEXES] == INVALID_HANDLE)
			continue;
		
		for(j=0; j<GetArraySize(eItem[ITEM_FILE_INDEXES]); j++)
		{
			iIndex = GetArrayCell(eItem[ITEM_FILE_INDEXES], j);
			GetArrayArray(g_aItemFiles, iIndex, eFile);
			
			if(IsFileDownloaded(eFile[ITEMFILE_PATH]) && IsFileDownloaded("%s.bz2", eFile[ITEMFILE_PATH]))
			{
				if(eFile[ITEMFILE_PRECACHE_TYPE] > PRECACHE_TYPE_NONE && eFile[ITEMFILE_PRECACHE_TYPE] < NUM_PRECACHE_TYPES)
				{
					eFile[ITEMFILE_PRECACHE_ID] = PrecachePathByType(eFile[ITEMFILE_PATH], eFile[ITEMFILE_PRECACHE_TYPE]);
					eItem[ITEM_MAIN_FILE_INDEX] = iIndex;
				}
				
				AddFileToDownloadsTable(eFile[ITEMFILE_PATH]);
				SetArrayArray(g_aItemFiles, iIndex, eFile);
			}
			else
			{
				eItem[ITEM_ENABLED] = false;
			}
		}
		
		SetArrayArray(g_aInventoryItems, i, eItem);
	}
}

bool:IsFileDownloaded(const String:szFormat[], any:...)
{
	decl String:szFilePath[PLATFORM_MAX_PATH];
	VFormat(szFilePath, sizeof(szFilePath), szFormat, 2);
	
	if(!FileExists(szFilePath, true))
		return false;
	
	if(FindStringInArray(g_aDownloadQueue, szFilePath) != -1)
		return false;
	
	return true;
}

AddFileToDownloadQueue(const String:szFormat[], any:...)
{
	decl String:szFilePath[PLATFORM_MAX_PATH];
	VFormat(szFilePath, sizeof(szFilePath), szFormat, 2);
	
	if(FindStringInArray(g_aDownloadQueue, szFilePath) != -1)
		return;
	
	PushArrayString(g_aDownloadQueue, szFilePath);
	
	if(GetArraySize(g_aDownloadQueue) == 1)
		StartNextDownloadInQueue();
}

StartNextDownloadInQueue()
{
	if(!GetArraySize(g_aDownloadQueue))
		return;
	
	decl String:szFilePath[PLATFORM_MAX_PATH];
	GetArrayString(g_aDownloadQueue, 0, szFilePath, sizeof(szFilePath));
	
	decl String:szURL[512];
	GetConVarString(cvar_plugin_files_url, szURL, sizeof(szURL));
	Format(szURL, sizeof(szURL), "%s/%s", szURL, szFilePath);
	
	LogMessage("Starting download: %s", szFilePath);
	FileDownloader_DownloadFile(szURL, szFilePath, OnDownloadSuccess, OnDownloadFailed);
}

public OnDownloadSuccess(const String:szFilePath[], any:data)
{
	LogMessage("Successfully downloaded: %s", szFilePath);
	RemoveFromDownloadQueue(szFilePath);
}

public OnDownloadFailed(const String:szFilePath[], any:data)
{
	LogError("Failed to download: %s", szFilePath);
	RemoveFromDownloadQueue(szFilePath);
}

RemoveFromDownloadQueue(const String:szFilePath[])
{
	new iIndex = FindStringInArray(g_aDownloadQueue, szFilePath);
	if(iIndex != -1)
		RemoveFromArray(g_aDownloadQueue, iIndex);
	
	StartNextDownloadInQueue();
}

PrecachePathByType(const String:szPath[], const iPrecacheType)
{
	switch(iPrecacheType)
	{
		case PRECACHE_TYPE_MODEL: return PrecacheModel(szPath, true);
		case PRECACHE_TYPE_SOUND: return PrecacheSoundAny(szPath[6], true);
		case PRECACHE_TYPE_DECAL: return PrecacheDecal(szPath[10], true);
		case PRECACHE_TYPE_PARTICLE_FILE:
		{
			if(g_bLibLoaded_ParticleManager)
			{
				#if defined _particle_manager_included
				return PM_PrecacheParticleEffect(szPath);
				#endif
			}
			
			LogError("Could not precache [%s] because the particle manager API is not installed.", szPath);
			return 0;
		}
	}
	
	return 0;
}

bool:Query_CreateTable_StoreItems()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS store_items\
	(\
		item_id			SMALLINT UNSIGNED	NOT NULL	AUTO_INCREMENT,\
		item_name		VARCHAR( 32 )		NOT NULL,\
		item_type		TINYINT UNSIGNED	NOT NULL,\
		data_string1	VARCHAR( 42 )		NOT NULL,\
		image_path		TEXT				NOT NULL,\
		PRIMARY KEY ( item_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_StoreFiles()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS store_files\
	(\
		item_id			SMALLINT UNSIGNED	NOT NULL,\
		file_path		VARCHAR( 255 )		NOT NULL,\
		precache_type	TINYINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( item_id, file_path )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_StoreInventory()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS store_inventory\
	(\
		game_id			SMALLINT UNSIGNED	NOT NULL,\
		item_id			SMALLINT UNSIGNED	NOT NULL,\
		item_price		MEDIUMINT			NOT NULL,\
		PRIMARY KEY ( game_id, item_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_StoreUserItems()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseServersConfigName, "\
	CREATE TABLE IF NOT EXISTS store_user_items\
	(\
		user_id			INT UNSIGNED		NOT NULL,\
		item_id			SMALLINT UNSIGNED	NOT NULL,\
		time_obtained	INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( user_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_StoreUserSettings()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseServersConfigName, "\
	CREATE TABLE IF NOT EXISTS store_user_settings\
	(\
		user_id			INT UNSIGNED	NOT NULL,\
		setting_type	SMALLINT		NOT NULL,\
		setting_value	INT				NOT NULL,\
		PRIMARY KEY ( user_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}