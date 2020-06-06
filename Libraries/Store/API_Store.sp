#include <sourcemod>
#include <emitsoundany>
#include <sdktools_stringtables>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseUsers/database_users"
#include "../../Libraries/FileDownloader/file_downloader"
#include "../../Plugins/UserPoints/user_points"
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "store"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ParticleManager/particle_manager"
#include "../../Libraries/Donators/donators"
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma dynamic 500000

new const String:PLUGIN_NAME[] = "API: Store";
new const String:PLUGIN_VERSION[] = "1.3";

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

new g_iVisSettingsMenuStartItem[MAXPLAYERS+1];
new Handle:g_aVisSettingsMenuEntries;
enum _:VisSettingsMenuEntry
{
	String:VisSettingsMenuEntry_Name[MAX_STORE_SETTINGS_MENU_LEN],
	ClientCookieType:VisSettingsMenuEntry_ItemTypeFlagsCookie
};

new Handle:g_hTrie_ItemIDToInventoryIndex;
new Handle:g_aInventoryItems;
enum _:InventoryItem
{
	ITEM_ID,
	ITEM_PRICE,
	ITEM_TYPE,
	String:ITEM_NAME[MAX_STORE_ITEM_NAME_LEN],
	String:ITEM_DATA_STRING_1[MAX_STORE_DATA_STRING_LEN],
	String:ITEM_DATA_STRING_2[MAX_STORE_DATA_STRING_LEN],
	String:ITEM_DATA_STRING_3[MAX_STORE_DATA_STRING_LEN],
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
new Handle:g_aClientItemsActive[MAXPLAYERS+1];

new Handle:cvar_plugin_files_url;

new Handle:g_hFwd_OnItemsReady;
new Handle:g_hFwd_OnRegisterVisibilitySettingsReady;

new bool:g_bLibLoaded_ParticleManager;


public OnPluginStart()
{
	CreateConVar("api_store_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_plugin_files_url = FindConVar("plugin_files_url")) == INVALID_HANDLE)
		cvar_plugin_files_url = CreateConVar("plugin_files_url", "", "A URL that points to the web path that stores plugin files.");
	
	g_hTrie_ItemIDToInventoryIndex = CreateTrie();
	g_aVisSettingsMenuEntries = CreateArray(VisSettingsMenuEntry);
	g_aInventoryItems = CreateArray(InventoryItem);
	g_aItemFiles = CreateArray(ItemFile);
	g_aDownloadQueue = CreateArray(PLATFORM_MAX_PATH);
	
	for(new iClient=1; iClient<sizeof(g_aClientItems); iClient++)
	{
		g_aClientItems[iClient] = CreateArray();
		g_aClientItemsActive[iClient] = CreateArray();
	}
	
	g_hFwd_OnItemsReady = CreateGlobalForward("Store_OnItemsReady", ET_Ignore);
	g_hFwd_OnRegisterVisibilitySettingsReady = CreateGlobalForward("Store_OnRegisterVisibilitySettingsReady", ET_Ignore);
	
	CreateTimer(5.0, Timer_ServerCheck, _, TIMER_REPEAT);
	
	RegConsoleCmd("sm_shop", OnOpenStore, "Opens the store.");
	RegConsoleCmd("sm_store", OnOpenStore, "Opens the store.");
	RegConsoleCmd("sm_models", OnOpenStore, "Opens the store.");
	RegConsoleCmd("sm_skins", OnOpenStore, "Opens the store.");
}

public Action:OnOpenStore(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_Store(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_Store(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Store);
	SetMenuTitle(hMenu, "Store");
	
	AddMenuItem(hMenu, "0", "Browse store items");
	AddMenuItem(hMenu, "1", "Toggle specific items on/off");
	AddMenuItem(hMenu, "2", "Item visibility settings");
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
}

public MenuHandle_Store(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case 0:
		{
			WebPageViewer_OpenPage(iParam1, "http://swoobles.com/store-database");
		}
		case 1:
		{
			WebPageViewer_OpenPage(iParam1, "http://swoobles.com/page/storeusersettings");
		}
		case 2:
		{
			DisplayMenu_VisibilitySettings(iParam1);
		}
	}
}

bool:DisplayMenu_VisibilitySettings(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_VisibilitySettings);
	SetMenuTitle(hMenu, "Visibility Settings\nNOTICE: Some settings won't apply\nuntil you reconnect to the server.");
	
	decl eVisSettingsMenuEntry[VisSettingsMenuEntry], String:szInfo[12];
	for(new i=0; i<GetArraySize(g_aVisSettingsMenuEntries); i++)
	{
		GetArrayArray(g_aVisSettingsMenuEntries, i, eVisSettingsMenuEntry);
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, eVisSettingsMenuEntry[VisSettingsMenuEntry_Name]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		PrintToChat(iClient, "[SM] There are no settings.");
		return false;
	}
	
	CPrintToChat(iClient, "{lightred}NOTICE: {olive}Some settings won't apply until you reconnect to the server.");
	
	return true;
}

public MenuHandle_VisibilitySettings(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_Store(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	g_iVisSettingsMenuStartItem[iParam1] = GetMenuSelectionPosition();
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	DisplayMenu_VisibilitySettingsEntry(iParam1, StringToInt(szInfo));
}

DisplayMenu_VisibilitySettingsEntry(iClient, iEntryIndex)
{
	decl eVisSettingsMenuEntry[VisSettingsMenuEntry];
	GetArrayArray(g_aVisSettingsMenuEntries, iEntryIndex, eVisSettingsMenuEntry);
	
	new iItemTypeFlags = GetClientItemTypeFlags(iClient, eVisSettingsMenuEntry[VisSettingsMenuEntry_ItemTypeFlagsCookie]);
	
	decl String:szTitle[MAX_STORE_SETTINGS_MENU_LEN+96];
	FormatEx(szTitle, sizeof(szTitle), "Visibility Settings - %s\nNOTICE: Some settings won't apply\nuntil you reconnect to the server.", eVisSettingsMenuEntry[VisSettingsMenuEntry_Name]);
	
	new Handle:hMenu = CreateMenu(MenuHandle_VisibilitySettingsEntry);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[24], String:szBuffer[64], iBit;
	
	// Whos items do I want to see?
	iBit = ITYPE_FLAG_SELF_DISABLED;
	FormatEx(szInfo, sizeof(szInfo), "%d/%d", iEntryIndex, iBit);
	FormatEx(szBuffer, sizeof(szBuffer), "%s%s", (iItemTypeFlags & iBit) ? "[\xE2\x9C\x93] " : "", "Don't show my items to myself.");
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	iBit = ITYPE_FLAG_MY_TEAM_DISABLED;
	FormatEx(szInfo, sizeof(szInfo), "%d/%d", iEntryIndex, iBit);
	FormatEx(szBuffer, sizeof(szBuffer), "%s%s", (iItemTypeFlags & iBit) ? "[\xE2\x9C\x93] " : "", "Don't show my teams items to myself.");
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	iBit = ITYPE_FLAG_OTHER_TEAM_DISABLED;
	FormatEx(szInfo, sizeof(szInfo), "%d/%d", iEntryIndex, iBit);
	FormatEx(szBuffer, sizeof(szBuffer), "%s%s", (iItemTypeFlags & iBit) ? "[\xE2\x9C\x93] " : "", "Don't show the other teams items to myself.");
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	// Spacer
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	// Who is allowed to see my items?
	iBit = ITYPE_FLAG_MY_ITEM_MY_TEAM_DISABLED;
	FormatEx(szInfo, sizeof(szInfo), "%d/%d", iEntryIndex, iBit);
	FormatEx(szBuffer, sizeof(szBuffer), "%s%s", (iItemTypeFlags & iBit) ? "[\xE2\x9C\x93] " : "", "Don't show my items to my team.");
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	iBit = ITYPE_FLAG_MY_ITEM_OTHER_TEAM_DISABLED;
	FormatEx(szInfo, sizeof(szInfo), "%d/%d", iEntryIndex, iBit);
	FormatEx(szBuffer, sizeof(szBuffer), "%s%s", (iItemTypeFlags & iBit) ? "[\xE2\x9C\x93] " : "", "Don't show my items to the other team.");
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying visibility settings entry menu.");
		return;
	}
}

public MenuHandle_VisibilitySettingsEntry(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_VisibilitySettings(iParam1, g_iVisSettingsMenuStartItem[iParam1]);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[24];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	decl String:szExplode[2][12];
	ExplodeString(szInfo, "/", szExplode, sizeof(szExplode), sizeof(szExplode[]));
	
	new iEntryIndex = StringToInt(szExplode[0]);
	new iBit = StringToInt(szExplode[1]);
	
	decl eVisSettingsMenuEntry[VisSettingsMenuEntry];
	GetArrayArray(g_aVisSettingsMenuEntries, iEntryIndex, eVisSettingsMenuEntry);
	
	new iItemTypeFlags = GetClientItemTypeFlags(iParam1, eVisSettingsMenuEntry[VisSettingsMenuEntry_ItemTypeFlagsCookie]);
	iItemTypeFlags ^= iBit;
	SetClientItemTypeFlags(iParam1, eVisSettingsMenuEntry[VisSettingsMenuEntry_ItemTypeFlagsCookie], iItemTypeFlags);
	
	DisplayMenu_VisibilitySettingsEntry(iParam1, iEntryIndex);
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
	{
		g_bLibLoaded_ParticleManager = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
	{
		g_bLibLoaded_ParticleManager = false;
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("store");
	CreateNative("Store_CanClientUseItem", _Store_CanClientUseItem);
	CreateNative("Store_FindItemByType", _Store_FindItemByType);
	CreateNative("Store_GetItemsMainFilePath", _Store_GetItemsMainFilePath);
	CreateNative("Store_GetItemsMainFilePrecacheID", _Store_GetItemsMainFilePrecacheID);
	CreateNative("Store_GetItemsDataString", _Store_GetItemsDataString);
	CreateNative("Store_RegisterVisibilitySettings", _Store_RegisterVisibilitySettings);
	CreateNative("Store_DisplayVisibilitySettingsMenu", _Store_DisplayVisibilitySettingsMenu);
	CreateNative("Store_GetClientItemTypeFlags", _Store_GetClientItemTypeFlags);
	CreateNative("Store_SetClientItemTypeFlags", _Store_SetClientItemTypeFlags);
	
	return APLRes_Success;
}

public _Store_GetClientItemTypeFlags(Handle:hPlugin, iNumParams)
{
	return GetClientItemTypeFlags(GetNativeCell(1), GetNativeCell(2));
}

GetClientItemTypeFlags(iClient, ClientCookieType:cookieType)
{
	if(!ClientCookies_HaveCookiesLoaded(iClient))
		return ITYPE_FLAG_ALL_ENABLED;
	
	if(!ClientCookies_HasCookie(iClient, cookieType))
		return ITYPE_FLAG_ALL_ENABLED;
	
	return ClientCookies_GetCookie(iClient, cookieType);
}

public _Store_SetClientItemTypeFlags(Handle:hPlugin, iNumParams)
{
	SetClientItemTypeFlags(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

SetClientItemTypeFlags(iClient, ClientCookieType:cookieType, iValue)
{
	if(!ClientCookies_HaveCookiesLoaded(iClient))
	{
		CPrintToChat(iClient, "{lightred}Could apply settings since your data is not loaded yet.");
		return false;
	}
	
	ClientCookies_SetCookie(iClient, cookieType, iValue);
	return true;
}

public _Store_DisplayVisibilitySettingsMenu(Handle:hPlugin, iNumParams)
{
	return DisplayMenu_VisibilitySettings(GetNativeCell(1));
}

public _Store_RegisterVisibilitySettings(Handle:hPlugin, iNumParams)
{
	decl String:szSettingsMenuName[MAX_STORE_SETTINGS_MENU_LEN];
	GetNativeString(1, szSettingsMenuName, sizeof(szSettingsMenuName));
	
	decl eVisSettingsMenuEntry[VisSettingsMenuEntry];
	for(new i=0; i<GetArraySize(g_aVisSettingsMenuEntries); i++)
	{
		GetArrayArray(g_aVisSettingsMenuEntries, i, eVisSettingsMenuEntry);
		
		if(!StrEqual(szSettingsMenuName, eVisSettingsMenuEntry[VisSettingsMenuEntry_Name]))
			continue;
		
		RemoveFromArray(g_aVisSettingsMenuEntries, i);
		break;
	}
	
	strcopy(eVisSettingsMenuEntry[VisSettingsMenuEntry_Name], MAX_STORE_SETTINGS_MENU_LEN, szSettingsMenuName);
	eVisSettingsMenuEntry[VisSettingsMenuEntry_ItemTypeFlagsCookie] = GetNativeCell(2);
	
	PushArrayArray(g_aVisSettingsMenuEntries, eVisSettingsMenuEntry);
	
	return true;
}

public _Store_GetItemsDataString(Handle:hPlugin, iNumParams)
{
	static String:szItemID[12], iIndex;
	IntToString(GetNativeCell(1), szItemID, sizeof(szItemID));
	if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
		return false;
	
	new iStringNum = GetNativeCell(2);
	if(iStringNum < 1 || iStringNum > 3)
		return false;
	
	decl eItem[InventoryItem];
	GetArrayArray(g_aInventoryItems, iIndex, eItem);
	
	switch(iStringNum)
	{
		case 1: SetNativeString(3, eItem[ITEM_DATA_STRING_1], GetNativeCell(4));
		case 2: SetNativeString(3, eItem[ITEM_DATA_STRING_2], GetNativeCell(4));
		case 3: SetNativeString(3, eItem[ITEM_DATA_STRING_3], GetNativeCell(4));
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
	
	if(FindValueInArray(g_aClientItemsActive[iClient], iItemID) == -1)
		return false;
	
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
	
	while(SQL_FetchRow(hQuery))
		GiveClientStoreItem(iClient, SQL_FetchInt(hQuery, 0));
	
	DB_TQuery(g_szDatabaseServersConfigName, Query_GetUserItemsActive, DBPrio_Low, GetClientSerial(iClient), "\
		SELECT item_id FROM store_user_items_active WHERE user_id = %i", DBUsers_GetUserID(iClient));
}

public Query_GetUserItemsActive(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	while(SQL_FetchRow(hQuery))
		ActivateClientItem(iClient, SQL_FetchInt(hQuery, 0), true);
}

ActivateClientItem(iClient, iItemID, bool:bShouldActivate)
{
	if(bShouldActivate)
	{
		if(FindValueInArray(g_aClientItemsActive[iClient], iItemID) != -1)
			return;
		
		PushArrayCell(g_aClientItemsActive[iClient], iItemID);
	}
	else
	{
		new iIndex = FindValueInArray(g_aClientItemsActive[iClient], iItemID);
		if(iIndex == -1)
			return;
		
		RemoveFromArray(g_aClientItemsActive[iClient], iIndex);
	}
}

GiveClientStoreItem(iClient, iItemID, bool:bShouldActivate=false)
{
	if(FindValueInArray(g_aClientItems[iClient], iItemID) != -1)
		return;
	
	PushArrayCell(g_aClientItems[iClient], iItemID);
	
	if(bShouldActivate)
	{
		ActivateClientItem(iClient, iItemID, true);
		
		decl String:szItemID[12], iIndex;
		IntToString(iItemID, szItemID, sizeof(szItemID));
		if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
			return;
		
		decl eItem[InventoryItem];
		GetArrayArray(g_aInventoryItems, iIndex, eItem);
		
		CPrintToChat(iClient, "{olive}Giving item on respawn: {yellow}%s", eItem[ITEM_NAME]);
	}
}

RemoveClientStoreItem(iClient, iItemID, bool:bMessage=false)
{
	ActivateClientItem(iClient, iItemID, false);
	
	new iIndex = FindValueInArray(g_aClientItems[iClient], iItemID);
	if(iIndex == -1)
		return;
	
	RemoveFromArray(g_aClientItems[iClient], iIndex);
	
	if(bMessage)
	{
		decl String:szItemID[12];
		IntToString(iItemID, szItemID, sizeof(szItemID));
		if(!GetTrieValue(g_hTrie_ItemIDToInventoryIndex, szItemID, iIndex))
			return;
		
		decl eItem[InventoryItem];
		GetArrayArray(g_aInventoryItems, iIndex, eItem);
		
		CPrintToChat(iClient, "{lightred}Removing item on respawn: {yellow}%s", eItem[ITEM_NAME]);
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
	
	if(!Query_CreateTable_StoreUserItemsActive())
		SetFailState("There was an error creating the store_user_items_active sql table.");
	
	if(!Query_CreateTable_StoreServerCheck())
		SetFailState("There was an error creating the store_server_check sql table.");
	
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
	ClearArray(g_aClientItemsActive[iClient]);
}

Forward_OnItemsReady()
{
	Call_StartForward(g_hFwd_OnItemsReady);
	Call_Finish();
}

Forward_OnRegisterVisibilitySettingsReady()
{
	Call_StartForward(g_hFwd_OnRegisterVisibilitySettingsReady);
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
	new iLen = FormatEx(szQuery, iQuerySize, "SELECT item_id, item_type, item_name, data_string1, data_string2, data_string3 FROM store_items WHERE item_id IN (");
	
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
		SQL_FetchString(hQuery, 4, eItem[ITEM_DATA_STRING_2], MAX_STORE_DATA_STRING_LEN);
		SQL_FetchString(hQuery, 5, eItem[ITEM_DATA_STRING_3], MAX_STORE_DATA_STRING_LEN);
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

public Action:Timer_ServerCheck(Handle:hTimer)
{
	TransactionStart_ServerCheck();
}

bool:TransactionStart_ServerCheck()
{
	new Handle:hDatabase = DB_GetDatabaseHandleFromConnectionName(g_szDatabaseBridgeConfigName);
	if(hDatabase == INVALID_HANDLE)
		return false;
	
	decl String:szQuery[2048];
	new Handle:hTransaction = SQL_CreateTransaction();
	
	FormatEx(szQuery, sizeof(szQuery), "SELECT type, user_id, item_id, points FROM store_server_check WHERE server_id = %i ORDER BY time ASC", DBServers_GetServerID());
	SQL_AddQuery(hTransaction, szQuery);
	
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM store_server_check WHERE server_id = %i", DBServers_GetServerID());
	SQL_AddQuery(hTransaction, szQuery);
	
	SQL_ExecuteTransaction(hDatabase, hTransaction, TransactionSuccess_ServerCheck, TransactionFailure_ServerCheck, _, DBPrio_Low);
	
	return true;
}

public TransactionSuccess_ServerCheck(Handle:hDatabase, any:data, iNumQueries, Handle:hResults[], any:queryData[])
{
	if(iNumQueries < 1)
		return;
	
	new Handle:hQuery = hResults[0];
	if(hQuery == INVALID_HANDLE)
		return;
	
	while(SQL_FetchRow(hQuery))
		TryAddRemoveUserItem(SQL_FetchInt(hQuery, 0), SQL_FetchInt(hQuery, 1), SQL_FetchInt(hQuery, 2), SQL_FetchInt(hQuery, 3));
}

public TransactionFailure_ServerCheck(Handle:hDatabase, any:data, iNumQueries, const String:szError[], iFailIndex, any:queryData[])
{
	LogMessage("ServerCheck query failed [%i] [%s]", iFailIndex, szError);
}

TryAddRemoveUserItem(iType, iUserID, iItemID, iPoints)
{
	new iClient = FindClientByUserID(iUserID);
	if(!iClient)
		return;
	
	switch(iType)
	{
		case 0: RemoveClientStoreItem(iClient, iItemID, true);
		case 1: GiveClientStoreItem(iClient, iItemID, true);
		case 2: ActivateClientItem(iClient, iItemID, false);
		case 3: ActivateClientItem(iClient, iItemID, true);
	}
	
	UserPoints_AddToVisualOffset(iClient, iPoints);
}

FindClientByUserID(iUserID)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(DBUsers_GetUserID(iClient) == iUserID)
			return iClient;
	}
	
	return 0;
}

public OnMapStart()
{
	ClearArray(g_aVisSettingsMenuEntries);
	Forward_OnRegisterVisibilitySettingsReady();
	
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
				
				if(IsStringInTable(eFile[ITEMFILE_PATH], "downloadables") == -1)
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

IsStringInTable(const String:szString[], const String:szTable[])
{
	new iTable = FindStringTable(szTable);
	if(iTable == INVALID_STRING_TABLE)
		return -1;
	
	new iNumStrings = GetStringTableNumStrings(iTable);
	
	decl String:szTempString[PLATFORM_MAX_PATH], iBytes;
	for(new i=0; i<iNumStrings; i++)
	{
		iBytes = ReadStringTable(iTable, i, szTempString, sizeof(szTempString));
		if(!iBytes)
			continue;
		
		if(StrEqual(szString, szTempString))
			return i;
	}
	
	return -1;
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
		case PRECACHE_TYPE_MODEL:
		{
			new iPrecacheID = IsStringInTable(szPath, "modelprecache");
			if(iPrecacheID == -1)
				iPrecacheID = PrecacheModel(szPath, true);
			
			return iPrecacheID;
		}
		case PRECACHE_TYPE_SOUND:
		{
			/*
			new iPrecacheID = IsStringInTable(szPath[6], "soundprecache");
			if(iPrecacheID == -1)
				iPrecacheID = PrecacheSound(szPath[6], true);
			
			return iPrecacheID;
			*/
			
			return PrecacheSoundAny(szPath[6], true);
		}
		case PRECACHE_TYPE_DECAL:
		{
			new iPrecacheID = IsStringInTable(szPath[10], "decalprecache");
			if(iPrecacheID == -1)
				iPrecacheID = PrecacheDecal(szPath[10], true);
			
			return iPrecacheID;
		}
		case PRECACHE_TYPE_PARTICLE_FILE:
		{
			if(g_bLibLoaded_ParticleManager)
			{
				#if defined _particle_manager_included
				new iPrecacheID = IsStringInTable(szPath, "genericprecache");
				if(iPrecacheID == -1)
					iPrecacheID = PM_PrecacheParticleEffect(szPath);
				
				return iPrecacheID;
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
		data_string2	VARCHAR( 42 )		NOT NULL,\
		data_string3	VARCHAR( 42 )		NOT NULL,\
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
		PRIMARY KEY ( user_id, item_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_StoreUserItemsActive()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseServersConfigName, "\
	CREATE TABLE IF NOT EXISTS store_user_items_active\
	(\
		user_id		INT UNSIGNED		NOT NULL,\
		item_id		SMALLINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( user_id, item_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_StoreServerCheck()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS store_server_check\
	(\
		server_id	SMALLINT UNSIGNED	NOT NULL,\
		type		TINYINT				NOT NULL,\
		user_id		INT UNSIGNED		NOT NULL,\
		item_id		SMALLINT UNSIGNED	NOT NULL,\
		points		INT					NOT NULL,\
		time		INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( server_id, type, user_id, item_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}