#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>
#include <regex>
#include <sdktools_entinput>
#include "../../Libraries/FileDownloader/file_downloader"
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseUsers/database_users"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ClientCookies/client_cookies"
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma dynamic 9000000

new const String:PLUGIN_NAME[] = "Weapon Skins";
new const String:PLUGIN_VERSION[] = "0.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to select weapon skins.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define VDF_TOKEN_LEN			1024
#define LANG_CODE_LEN			16
#define POSTFIX_LEN				32
#define ITEMS_GAME_FILEPATH		"scripts/items/items_game.txt"
#define STEAM_INF_FILEPATH		"steam.inf"
#define LANG_CONFIG_DIRPATH		"configs/ws_languages"
#define LANG_VERSION_FILENAME	"versions.txt"
#define DELOCALIZED_RANDOM		"RD_RND"

new Handle:g_hTrie_ClientItemDefToPaintKitIndex[MAXPLAYERS+1];

new Handle:g_hTrie_DelocalizedCategoryToCategoryMap;
new Handle:g_hTrie_WeaponEntsForCategoriesMap;
new Handle:g_aWeaponEntsForCategories;
new Handle:g_aWeaponCategories;

new Handle:g_hTrie_WeaponEntToDelocalizedName;

new Handle:g_hTrie_WeaponEntToItemDefIndex;
new Handle:g_hTrie_ItemDefIndexToWeaponEnt;

new Handle:g_aWeaponEntsForPrefabs;
new Handle:g_hTrie_WeaponEntsForPrefabsMap;

new Handle:g_aPaintsForWeaponEnts;
new Handle:g_hTrie_PaintsForWeaponEntsMap;

new Handle:g_aPaintRarities;
new Handle:g_hTrie_PaintNameToRarity;

new Handle:g_aUnusedPaintKitIndexes;

new Handle:g_aPaintKits;
new Handle:g_hTrie_PaintIDToPaintKitIndex;
new Handle:g_hTrie_PaintNameToPaintKitIndex;
enum _:PaintKit
{
	PAINT_ID,
	String:PAINT_NAME[VDF_TOKEN_LEN],
	String:PAINT_TAG[VDF_TOKEN_LEN],
	String:PAINT_POSTFIX[POSTFIX_LEN],
	PAINT_SEED,
	bool:PAINT_FOUND_WEAPON
};

enum ItemsGameCategory
{
	IGC_PAINT_KITS_RARITY = 0,
	IGC_PAINT_KITS,
	IGC_ITEM_SETS,
	IGC_CLIENT_LOOT_LISTS,
	IGC_ITEMS,
	IGC_PREFABS
};

enum
{
	// CategorySelect
	MENUSELECT_SKIN_CURRENT_WEAPON = 1,
	MENUSELECT_SKIN_ANY_WEAPON,
	MENUSELECT_VIEW_WEAPON_SETS,
	MENUSELECT_VIEW_WEAPON_CONTAINERS,
	
	// WeaponOptions
	MENUSELECT_WOPTIONS_THIS_WEAPON,
	MENUSELECT_WOPTIONS_OTHER_WEAPONS,
	MENUSELECT_WOPTIONS_UNUSED,
	MENUSELECT_WOPTIONS_CUSTOM_FLOAT,
	MENUSELECT_WOPTIONS_NAME_TAG
};

new Handle:g_aDelocalizedStringsUsed;
new Handle:g_aLanguageParseQueue;
enum _:LanguageParseQueue
{
	String:LANG_PARSE_CODE[LANG_CODE_LEN],
	String:LANG_FILE[PLATFORM_MAX_PATH]
};

new g_iMenuPosition_WeaponCategorySelect[MAXPLAYERS+1];
new g_iMenuPosition_WeaponSelect[MAXPLAYERS+1];
new g_iMenuPosition_WeaponSelect_Index[MAXPLAYERS+1];
new String:g_szMenuPosition_PaintSelectWeaponEnt[MAXPLAYERS+1][VDF_TOKEN_LEN];
new g_iMenu_CategorySelectType[MAXPLAYERS+1];
new g_iMenu_PaintListType[MAXPLAYERS+1];

new Handle:g_aLanguageKeyValHandles;
new Handle:g_hTrie_LangNumToLangKeyValsHandlesIndex;
new g_iDefaultLanguageNum;
new g_iEnglishLanguageNum;

new bool:g_bHasInitializedPlugin;
new Handle:cvar_encoding_url;

new Handle:g_hTimer_InitPlugin;

new String:g_szDatabaseConfigName[64];
new Handle:cvar_database_servers_configname;

new bool:g_bLibLoaded_ClientCookies;


public OnPluginStart()
{
	CreateConVar("weapon_skins_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	/*
	* 	ws_encoding_url notes:
	* 	- The total length of the URL must be 112 characters or less.
	* 	- Cannot be a URL with a redirect or a page behind a service like Cloudflare.
	*/
	cvar_encoding_url = CreateConVar("ws_encoding_url", "", "A URL that points to the web script that changes the language files encoding.");
	
	g_aPaintKits = CreateArray(PaintKit);
	g_aPaintRarities = CreateArray(VDF_TOKEN_LEN);
	g_aPaintsForWeaponEnts = CreateArray();
	g_aWeaponEntsForPrefabs = CreateArray();
	g_aWeaponEntsForCategories = CreateArray();
	g_aWeaponCategories = CreateArray(VDF_TOKEN_LEN);
	g_aDelocalizedStringsUsed = CreateArray(VDF_TOKEN_LEN);
	g_aLanguageParseQueue = CreateArray(LanguageParseQueue);
	g_aLanguageKeyValHandles = CreateArray();
	g_aUnusedPaintKitIndexes = CreateArray();
	
	g_hTrie_PaintNameToRarity = CreateTrie();
	g_hTrie_PaintNameToPaintKitIndex = CreateTrie();
	g_hTrie_PaintIDToPaintKitIndex = CreateTrie();
	g_hTrie_PaintsForWeaponEntsMap = CreateTrie();
	g_hTrie_WeaponEntToDelocalizedName = CreateTrie();
	g_hTrie_WeaponEntsForPrefabsMap = CreateTrie();
	g_hTrie_DelocalizedCategoryToCategoryMap = CreateTrie();
	g_hTrie_WeaponEntsForCategoriesMap = CreateTrie();
	g_hTrie_LangNumToLangKeyValsHandlesIndex = CreateTrie();
	g_hTrie_WeaponEntToItemDefIndex = CreateTrie();
	g_hTrie_ItemDefIndexToWeaponEnt = CreateTrie();
	
	AddAsUsedDelocalizedString(DELOCALIZED_RANDOM);
	
	RegConsoleCmd("sm_paints", OnSkinSelect, "Opens the weapon skin selection menu.");
	RegConsoleCmd("sm_wskins", OnSkinSelect, "Opens the weapon skin selection menu.");
	RegConsoleCmd("sm_ws", OnSkinSelect, "Opens the weapon skin selection menu.");
	
	RegConsoleCmd("sm_ss", OnSkinSelect, "TODO");
	RegConsoleCmd("sm_showskin", OnSkinSelect, "TODO");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ClientCookies = LibraryExists("client_cookies");
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "client_cookies"))
		g_bLibLoaded_ClientCookies = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "client_cookies"))
		g_bLibLoaded_ClientCookies = false;
}

public OnConfigsExecuted()
{
	if(g_bHasInitializedPlugin)
		return;
	
	if(g_hTimer_InitPlugin != INVALID_HANDLE)
		KillTimer(g_hTimer_InitPlugin);
	
	g_hTimer_InitPlugin = CreateTimer(5.0, Timer_InitPlugin);
}

public Action:Timer_InitPlugin(Handle:hTimer)
{
	g_bHasInitializedPlugin = true;
	
	g_iDefaultLanguageNum = GetServerLanguage();
	g_iEnglishLanguageNum = GetLanguageByCode("en");
	
	LoadData_ItemsGame();
	LoadData_LanguageFiles();
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_WeaponSkins())
		SetFailState("There was an error creating the plugin_weapon_skins sql table.");
}

bool:Query_CreateTable_WeaponSkins()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_weapon_skins\
	(\
		user_id		INT UNSIGNED		NOT NULL,\
		item_def	MEDIUMINT UNSIGNED	NOT NULL,\
		paint		MEDIUMINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( user_id, item_def )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:LoadData_LanguageFiles()
{
	decl String:szEncodingURL[256];
	GetConVarString(cvar_encoding_url, szEncodingURL, sizeof(szEncodingURL));
	if(StrContains(szEncodingURL, "http", false) == -1)
	{
		LogError("The \"ws_encoding_url\" cvar must be a URL pointing to the encoding web script.");
		return false;
	}
	
	decl String:szLangName[64], String:szLangCode[LANG_CODE_LEN];
	for(new i=0; i<GetLanguageCount(); i++)
	{
		GetLanguageInfo(i, szLangCode, sizeof(szLangCode), szLangName, sizeof(szLangName));
		LoadData_LanguageFile(i, szLangName, szLangCode, szEncodingURL);
	}
	
	return true;
}

bool:LoadData_LanguageFile(iLangNumber, const String:szLangName[], const String:szLangCode[], const String:szEncodingURL[])
{
	if(!szLangName[0] || !szLangCode[0])
		return false;
	
	// If the language files are up to date and we can load the cache go ahead and return.
	if(!DoesLanguageNeedUpdated(szLangCode) && LoadData_LanguageFileCache(iLangNumber))
		return true;
	
	// Pass the real language file to the web script to have its encoding changed to UTF-8 so we can actually parse it.
	decl String:szFilePath[PLATFORM_MAX_PATH];
	FormatEx(szFilePath, sizeof(szFilePath), "resource/csgo_%s.txt", szLangName);
	
	new Handle:fp = OpenFile(szFilePath, "rb");
	if(fp == INVALID_HANDLE)
		return false;
	
	PrintToServer("\"%s\" loading...", szFilePath);
	
	new iBytes = FileSize(szFilePath);
	decl iBuffer[iBytes];
	
	new iLoadedBytes = ReadFile(fp, iBuffer, iBytes, 1);
	CloseHandle(fp);
	
	if(iBytes == -1)
	{
		LogError("Could not read real language file \"%s\".", szFilePath);
		return false;
	}
	
	PrintToServer("\"%s\" loaded %i / %i bytes.", szFilePath, iLoadedBytes, iBytes);
	PrintToServer("\"%s\" passing to web script for re-encoding.", szFilePath);
	
	new Handle:hPack = CreateDataPack();
	WritePackString(hPack, szLangCode);
	
	decl String:szSavePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szSavePath, sizeof(szSavePath), "%s/%s.txt", LANG_CONFIG_DIRPATH, szLangName);
	FileDownloader_DownloadFile(szEncodingURL, szSavePath, OnDownloadSuccess, OnDownloadFailed, hPack, iBuffer, iBytes);
	
	return true;
}

bool:DoesLanguageNeedUpdated(const String:szLangCode[])
{
	decl String:szVersion[32];
	if(!GetPatchVersion(szVersion, sizeof(szVersion)))
		return false;
	
	decl String:szVersionPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szVersionPath, sizeof(szVersionPath), "%s/%s", LANG_CONFIG_DIRPATH, LANG_VERSION_FILENAME);
	
	new Handle:hKeyVals = CreateKeyValues("");
	if(!FileToKeyValues(hKeyVals, szVersionPath))
	{
		CloseHandle(hKeyVals);
		return true;
	}
	
	decl String:szFileVersion[32];
	KvGetString(hKeyVals, szLangCode, szFileVersion, sizeof(szFileVersion), "~Nope!");
	CloseHandle(hKeyVals);
	
	if(StrEqual(szVersion, szFileVersion))
		return false;
	
	return true;
}

SetLanguageVersion(const String:szLangCode[])
{
	decl String:szVersion[32];
	if(!GetPatchVersion(szVersion, sizeof(szVersion)))
		return;
	
	decl String:szVersionPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szVersionPath, sizeof(szVersionPath), "%s/%s", LANG_CONFIG_DIRPATH, LANG_VERSION_FILENAME);
	
	new Handle:hKeyVals = CreateKeyValues("Versions");
	FileToKeyValues(hKeyVals, szVersionPath);
	
	KvSetString(hKeyVals, szLangCode, szVersion);
	
	if(!KeyValuesToFile(hKeyVals, szVersionPath))
		LogError("Could not write to the version file for language \"%s\" version \"%s\".", szLangCode, szVersion);
	
	CloseHandle(hKeyVals);
}

bool:GetPatchVersion(String:szVersion[], iVersionLength)
{
	static String:szBuffer[256], bool:bHasVersion = false;
	if(bHasVersion)
	{
		strcopy(szVersion, iVersionLength, szBuffer);
		return true;
	}
	
	new Handle:fp = OpenFile(STEAM_INF_FILEPATH, "r");
	if(fp == INVALID_HANDLE)
	{
		LogError("Error opening \"%s\" for reading.", STEAM_INF_FILEPATH);
		return false;
	}
	
	new bool:bFoundPatchVersion;
	while(!IsEndOfFile(fp))
	{
		if(!ReadFileLine(fp, szBuffer, sizeof(szBuffer)))
			continue;
		
		TrimString(szBuffer);
		
		if(strlen(szBuffer) < 14)
			continue;
		
		szBuffer[12] = 0x00;
		if(!StrEqual(szBuffer, "PatchVersion", false))
			continue;
		
		strcopy(szBuffer, sizeof(szBuffer), szBuffer[13]);
		bFoundPatchVersion = true;
		break;
	}
	
	CloseHandle(fp);
	
	if(!bFoundPatchVersion)
	{
		LogError("Error \"PatchVersion\" not found in \"%s\".", STEAM_INF_FILEPATH);
		return false;
	}
	
	strcopy(szVersion, iVersionLength, szBuffer);
	bHasVersion = true;
	
	return true;
}

public OnDownloadSuccess(const String:szFileSavePath[], any:hPack)
{
	PrintToServer("\"%s\" successfully downloaded from web script.", szFileSavePath);
	
	decl String:szLangCode[LANG_CODE_LEN];
	ResetPack(hPack, false);
	ReadPackString(hPack, szLangCode, sizeof(szLangCode));
	CloseHandle(hPack);
	
	// Do stuff with the file on the next frame since the file seems to still return incorrect file size this frame.
	new Handle:hFramePack = CreateDataPack();
	WritePackString(hFramePack, szFileSavePath);
	WritePackString(hFramePack, szLangCode);
	RequestFrame(OnDownloadSuccessNextFrame, hFramePack);
}

public OnDownloadSuccessNextFrame(any:hPack)
{
	decl String:szFileSavePath[PLATFORM_MAX_PATH], String:szLangCode[LANG_CODE_LEN];
	ResetPack(hPack, false);
	ReadPackString(hPack, szFileSavePath, sizeof(szFileSavePath));
	ReadPackString(hPack, szLangCode, sizeof(szLangCode));
	CloseHandle(hPack);
	
	AddLanguageFileToParseQueue(szLangCode, szFileSavePath);
}

public OnDownloadFailed(const String:szFileSavePath[], any:hPack)
{
	CloseHandle(hPack);
	LogError("Language file \"%s\" failed to download from encoding web script.", szFileSavePath);
}

AddLanguageFileToParseQueue(const String:szLangCode[], const String:szLanguageFile[])
{
	// Split the parsing between frames so the script doesn't timeout.
	decl eParse[LanguageParseQueue];
	strcopy(eParse[LANG_PARSE_CODE], LANG_CODE_LEN, szLangCode);
	strcopy(eParse[LANG_FILE], PLATFORM_MAX_PATH, szLanguageFile);
	PushArrayArray(g_aLanguageParseQueue, eParse);
	
	if(GetArraySize(g_aLanguageParseQueue) == 1)
		RequestFrame(OnParseLanguageFile);
}

public OnParseLanguageFile(any:data)
{
	if(!GetArraySize(g_aLanguageParseQueue))
		return;
	
	decl eParse[LanguageParseQueue];
	GetArrayArray(g_aLanguageParseQueue, 0, eParse);
	RemoveFromArray(g_aLanguageParseQueue, 0);
	
	new iLangNumber = GetLanguageByCode(eParse[LANG_PARSE_CODE]);
	if(iLangNumber != -1)
	{
		PrintToServer("\"%s\" parsing started...", eParse[LANG_FILE]);
		PrintToServer("You may need to increase \"SlowScriptTimeout\" in SourceMod's core.cfg");
		
		if(LoadData_LanguageFileParse(iLangNumber, eParse[LANG_FILE]))
		{
			if(SaveLanguageFileCache(iLangNumber))
				SetLanguageVersion(eParse[LANG_PARSE_CODE]);
		}
		
		PrintToServer("\"%s\" finished.\n", eParse[LANG_FILE]);
		
		CPrintToChatAll("{lightred}The server might lag while it updates some files.");
	}
	
	if(GetArraySize(g_aLanguageParseQueue))
		RequestFrame(OnParseLanguageFile);
}

bool:LoadData_LanguageFileParse(iLangNumber, const String:szLanguageFile[])
{
	// Sure would be nice if we could use FileToKeyValues!
	new Handle:fp = OpenFile(szLanguageFile, "rb");
	if(fp == INVALID_HANDLE)
	{
		LogError("Could not open re-encoded language file \"%s\".", szLanguageFile);
		return false;
	}
	
	new iBytes = FileSize(szLanguageFile) + 1;
	decl String:szFileBuffer[iBytes];
	
	new iReadBytes = ReadFileString(fp, szFileBuffer, iBytes);
	CloseHandle(fp);
	
	if(iReadBytes < 1)
		return false;
	
	decl String:szLangNumber[11];
	IntToString(iLangNumber, szLangNumber, sizeof(szLangNumber));
	
	new iBufferLen = VDF_TOKEN_LEN + 32;
	decl Handle:hRegex, String:szDelocalizedString[VDF_TOKEN_LEN], String:szBuffer[iBufferLen];
	decl iNumSubStrings, String:szSubStringBuffer[VDF_TOKEN_LEN], iSubString;
	
	for(new i=0; i<GetArraySize(g_aDelocalizedStringsUsed); i++)
	{
		GetArrayString(g_aDelocalizedStringsUsed, i, szDelocalizedString, sizeof(szDelocalizedString));
		
		FormatEx(szBuffer, iBufferLen, "\"%s\".*\"(.*)\"", szDelocalizedString);
		hRegex = CompileRegex(szBuffer, PCRE_UTF8 | PCRE_NO_UTF8_CHECK | PCRE_CASELESS);
		
		if(hRegex == INVALID_HANDLE)
		{
			LogError("Could not regex for %s", szDelocalizedString);
			continue;
		}
		
		if((iNumSubStrings = MatchRegex(hRegex, szFileBuffer)) > 1)
		{
			for(iSubString=1; iSubString<iNumSubStrings; iSubString++)
			{
				GetRegexSubString(hRegex, iSubString, szSubStringBuffer, sizeof(szSubStringBuffer));
				AddLanguageString(szLangNumber, szDelocalizedString, szSubStringBuffer);
			}
		}
		
		CloseHandle(hRegex);
	}
	
	return true;
}

bool:SaveLanguageFileCache(iLangNumber)
{
	decl String:szLangNumber[11];
	IntToString(iLangNumber, szLangNumber, sizeof(szLangNumber));
	
	decl iIndex;
	if(!GetTrieValue(g_hTrie_LangNumToLangKeyValsHandlesIndex, szLangNumber, iIndex))
		return false;
	
	decl String:szLangName[48];
	GetLanguageInfo(iLangNumber, _, _, szLangName, sizeof(szLangName));
	
	decl String:szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "%s/%s_cached.txt", LANG_CONFIG_DIRPATH, szLangName);
	
	new Handle:hKeyVals = GetArrayCell(g_aLanguageKeyValHandles, iIndex);
	return KeyValuesToFile(hKeyVals, szPath);
}

bool:LoadData_LanguageFileCache(iLangNumber)
{
	decl String:szLangNumber[11];
	IntToString(iLangNumber, szLangNumber, sizeof(szLangNumber));
	
	// Return if it's already loaded.
	decl iIndex;
	if(GetTrieValue(g_hTrie_LangNumToLangKeyValsHandlesIndex, szLangNumber, iIndex))
		return true;
	
	decl String:szLangName[48];
	GetLanguageInfo(iLangNumber, _, _, szLangName, sizeof(szLangName));
	
	decl String:szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "%s/%s_cached.txt", LANG_CONFIG_DIRPATH, szLangName);
	
	new Handle:hKeyVals = CreateKeyValues("");
	if(!FileToKeyValues(hKeyVals, szPath))
	{
		CloseHandle(hKeyVals);
		return false;
	}
	
	iIndex = PushArrayCell(g_aLanguageKeyValHandles, hKeyVals);
	if(!SetTrieValue(g_hTrie_LangNumToLangKeyValsHandlesIndex, szLangNumber, iIndex, false))
	{
		CloseHandle(hKeyVals);
		RemoveFromArray(g_aLanguageKeyValHandles, iIndex);
		return false;
	}
	
	return true;
}

bool:AddLanguageString(const String:szLangNumber[], const String:szDelocalizedString[], const String:szLocalizedString[])
{
	decl iIndex, Handle:hKeyVals;
	if(!GetTrieValue(g_hTrie_LangNumToLangKeyValsHandlesIndex, szLangNumber, iIndex))
	{
		hKeyVals = CreateKeyValues("Cached");
		iIndex = PushArrayCell(g_aLanguageKeyValHandles, hKeyVals);
		if(!SetTrieValue(g_hTrie_LangNumToLangKeyValsHandlesIndex, szLangNumber, iIndex, false))
		{
			CloseHandle(hKeyVals);
			RemoveFromArray(g_aLanguageKeyValHandles, iIndex);
			return false;
		}
	}
	
	KvSetString(hKeyVals, szDelocalizedString, szLocalizedString);
	
	return true;
}

bool:GetClientsLocalizedString(iClient, const String:szDelocalizedString[], String:szLocalizedString[], iMaxLength)
{
	return GetLocalizedString(GetClientLanguage(iClient), szDelocalizedString, szLocalizedString, iMaxLength);
}

bool:GetLocalizedString(iLangNum, const String:szDelocalizedString[], String:szLocalizedString[], iMaxLength, bool:bTriedDefault=false, bool:bTriedEnglish=false)
{
	static String:szLangNumber[12];
	IntToString(iLangNum, szLangNumber, sizeof(szLangNumber));
	
	static iIndex;
	if(!GetTrieValue(g_hTrie_LangNumToLangKeyValsHandlesIndex, szLangNumber, iIndex))
	{
		if(iLangNum == g_iDefaultLanguageNum)
			bTriedDefault = true;
		
		if(iLangNum == g_iEnglishLanguageNum)
			bTriedEnglish = true;
		
		if(bTriedDefault && bTriedEnglish)
			return false;
		
		if(bTriedDefault)
			iLangNum = g_iEnglishLanguageNum;
		else
			iLangNum = g_iDefaultLanguageNum;
		
		return GetLocalizedString(iLangNum, szDelocalizedString, szLocalizedString, iMaxLength, bTriedDefault, bTriedEnglish);
	}
	
	static Handle:hKeyVals;
	hKeyVals = GetArrayCell(g_aLanguageKeyValHandles, iIndex);
	
	KvGetString(hKeyVals, szDelocalizedString, szLocalizedString, iMaxLength);
	
	if(!szLocalizedString[0])
	{
		if(iLangNum == g_iDefaultLanguageNum)
			bTriedDefault = true;
		
		if(iLangNum == g_iEnglishLanguageNum)
			bTriedEnglish = true;
		
		if(bTriedDefault && bTriedEnglish)
			return false;
		
		if(bTriedDefault)
			iLangNum = g_iEnglishLanguageNum;
		else
			iLangNum = g_iDefaultLanguageNum;
		
		return GetLocalizedString(iLangNum, szDelocalizedString, szLocalizedString, iMaxLength);
	}
	
	return true;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("unsafe_weapon_skins");
	return APLRes_Success;
}

public Action:OnSkinSelect(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_CategorySelect(iClient);
	return Plugin_Handled;
}

DisplayMenu_CategorySelect(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_CategorySelect);
	SetMenuTitle(hMenu, "Weapon skins");
	
	decl String:szInfo[4];
	IntToString(MENUSELECT_SKIN_CURRENT_WEAPON, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Select skin for currently held weapon.");
	
	IntToString(MENUSELECT_SKIN_ANY_WEAPON, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Select skin for any weapon.");
	
	// TODO: Add these features.
	/*
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(MENUSELECT_VIEW_WEAPON_SETS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "View weapon sets.");
	
	IntToString(MENUSELECT_VIEW_WEAPON_CONTAINERS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "View weapon containers.");
	*/
	
	SetMenuPagination(hMenu, false);
	SetMenuExitButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{red}There are no categories.");
}

public MenuHandle_CategorySelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
	new iType = StringToInt(szInfo);
	
	g_iMenu_CategorySelectType[iParam1] = iType;
	
	switch(iType)
	{
		case MENUSELECT_SKIN_CURRENT_WEAPON:
		{
			new iWeapon = GetEntPropEnt(iParam1, Prop_Send, "m_hActiveWeapon");
			if(iWeapon == -1)
			{
				CPrintToChat(iParam1, "{red}You do not have a weapon equipped.");
				DisplayMenu_CategorySelect(iParam1);
				return;
			}
			
			decl String:szBuffer[48];
			IntToString(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"), szBuffer, sizeof(szBuffer));
			
			if(!GetTrieString(g_hTrie_ItemDefIndexToWeaponEnt, szBuffer, szBuffer, sizeof(szBuffer)))
			{
				CPrintToChat(iParam1, "{red}There are no skins for this weapon.");
				DisplayMenu_CategorySelect(iParam1);
				return;
			}
			
			DisplayMenu_WeaponOptions(iParam1, szBuffer);
		}
		case MENUSELECT_SKIN_ANY_WEAPON:
		{
			DisplayMenu_WeaponCategorySelect(iParam1);
		}
		case MENUSELECT_VIEW_WEAPON_SETS:
		{
			//
		}
		case MENUSELECT_VIEW_WEAPON_CONTAINERS:
		{
			//
		}
	}
}

DisplayMenu_WeaponCategorySelect(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_WeaponCategorySelect);
	SetMenuTitle(hMenu, "Select a weapon category");
	
	static String:szInfo[12], String:szBuffer[VDF_TOKEN_LEN];
	for(new i=0; i<GetArraySize(g_aWeaponCategories); i++)
	{
		GetArrayString(g_aWeaponCategories, i, szBuffer, sizeof(szBuffer));
		GetClientsLocalizedString(iClient, szBuffer, szBuffer, sizeof(szBuffer));
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}There are no weapon categories.");
}

public MenuHandle_WeaponCategorySelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_CategorySelect(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	static String:szInfo[12], String:szBuffer[VDF_TOKEN_LEN];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	// Get delocalized name.
	GetArrayString(g_aWeaponCategories, StringToInt(szInfo), szBuffer, sizeof(szBuffer));
	
	// Get the category name.
	GetTrieString(g_hTrie_DelocalizedCategoryToCategoryMap, szBuffer, szBuffer, sizeof(szBuffer));
	
	// Get the weapon ents index.
	decl iWeaponEntsIndex;
	GetTrieValue(g_hTrie_WeaponEntsForCategoriesMap, szBuffer, iWeaponEntsIndex);
	
	g_iMenuPosition_WeaponCategorySelect[iParam1] = GetMenuSelectionPosition();
	DisplayMenu_WeaponSelect(iParam1, iWeaponEntsIndex);
}

DisplayMenu_WeaponSelect(iClient, iWeaponEntsIndex, iStartItem=0)
{
	g_iMenuPosition_WeaponSelect_Index[iClient] = iWeaponEntsIndex;
	
	new Handle:hMenu = CreateMenu(MenuHandle_WeaponSelect);
	SetMenuTitle(hMenu, "Select a weapon");
	
	// Get the weapon ents array.
	new Handle:hWeaponEnts = GetArrayCell(g_aWeaponEntsForCategories, iWeaponEntsIndex);
	
	static String:szInfo[48], String:szBuffer[VDF_TOKEN_LEN];
	for(new i=0; i<GetArraySize(hWeaponEnts); i++)
	{
		GetArrayString(hWeaponEnts, i, szBuffer, sizeof(szBuffer));
		
		if(!GetLocalizedWeaponName(iClient, szBuffer, szBuffer, sizeof(szBuffer)))
			continue;
		
		GetArrayString(hWeaponEnts, i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		CPrintToChat(iClient, "{red}There are no weapons in this category.");
		DisplayMenu_WeaponCategorySelect(iClient);
	}
}

bool:GetLocalizedWeaponName(iClient, const String:szWeaponEnt[], String:szLocalizedWeaponName[], iMaxLength)
{
	// Append which type of knife it is so it doesn't just say "Knife" for each.
	static String:szInfo[6];
	if(StrEqual(szWeaponEnt, "knife"))
	{
		strcopy(szInfo, sizeof(szInfo), " (CT)");
	}
	else if(StrEqual(szWeaponEnt, "knife_t"))
	{
		strcopy(szInfo, sizeof(szInfo), " (T)");
	}
	else if(StrEqual(szWeaponEnt, "knifegg"))
	{
		strcopy(szInfo, sizeof(szInfo), " (GG)");
	}
	else
	{
		szInfo[0] = '\x0';
	}
	
	if(!GetTrieString(g_hTrie_WeaponEntToDelocalizedName, szWeaponEnt, szLocalizedWeaponName, iMaxLength))
		return false;
	
	if(!GetClientsLocalizedString(iClient, szLocalizedWeaponName, szLocalizedWeaponName, iMaxLength))
		return false;
	
	StrCat(szLocalizedWeaponName, iMaxLength, szInfo);
	return true;
}

public MenuHandle_WeaponSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_WeaponCategorySelect(iParam1, g_iMenuPosition_WeaponCategorySelect[iParam1]);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	static String:szInfo[48];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	g_iMenuPosition_WeaponSelect[iParam1] = GetMenuSelectionPosition();
	DisplayMenu_WeaponOptions(iParam1, szInfo);
}

DisplayMenu_WeaponOptions(iClient, const String:szWeaponEnt[])
{
	decl String:szBuffer[VDF_TOKEN_LEN];
	GetLocalizedWeaponName(iClient, szWeaponEnt, szBuffer, sizeof(szBuffer));
	
	new Handle:hMenu = CreateMenu(MenuHandle_WeaponOptions);
	SetMenuTitle(hMenu, szBuffer);
	
	decl String:szInfo[64];
	FormatEx(szInfo, sizeof(szInfo), "%i~%s", MENUSELECT_WOPTIONS_THIS_WEAPON, szWeaponEnt);
	AddMenuItem(hMenu, szInfo, "Skins meant for this weapon.");
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%s", MENUSELECT_WOPTIONS_OTHER_WEAPONS, szWeaponEnt);
	AddMenuItem(hMenu, szInfo, "Skins from other weapons on this weapon.");
	
	if(GetArraySize(g_aUnusedPaintKitIndexes))
	{
		FormatEx(szInfo, sizeof(szInfo), "%i~%s", MENUSELECT_WOPTIONS_UNUSED, szWeaponEnt);
		AddMenuItem(hMenu, szInfo, "Skins that are unknown.");
	}
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%s", MENUSELECT_WOPTIONS_CUSTOM_FLOAT, szWeaponEnt);
	AddMenuItem(hMenu, szInfo, "Set a custom float.");
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%s", MENUSELECT_WOPTIONS_NAME_TAG, szWeaponEnt);
	AddMenuItem(hMenu, szInfo, "Set a name tag.");
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{red}There are no list types.");
}

public MenuHandle_WeaponOptions(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
		{
			if(g_iMenu_CategorySelectType[iParam1] == MENUSELECT_SKIN_CURRENT_WEAPON)
				DisplayMenu_CategorySelect(iParam1);
			else
				DisplayMenu_WeaponSelect(iParam1, g_iMenuPosition_WeaponSelect_Index[iParam1], g_iMenuPosition_WeaponSelect[iParam1]);
		}
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2][64];
	GetMenuItem(hMenu, iParam2, szInfo[0], sizeof(szInfo[]));
	ExplodeString(szInfo[0], "~", szInfo, sizeof(szInfo), sizeof(szInfo[]));
	
	new iListType = StringToInt(szInfo[0]);
	g_iMenu_PaintListType[iParam1] = iListType;
	
	switch(iListType)
	{
		case MENUSELECT_WOPTIONS_THIS_WEAPON:
		{
			DisplayMenu_PaintSelectWeaponEntSpecific(iParam1, szInfo[1]);
		}
		case MENUSELECT_WOPTIONS_OTHER_WEAPONS:
		{
			DisplayMenu_PaintSelectShowAll(iParam1, szInfo[1]);
		}
		case MENUSELECT_WOPTIONS_UNUSED:
		{
			DisplayMenu_PaintSelectShowUnused(iParam1, szInfo[1]);
		}
		case MENUSELECT_WOPTIONS_CUSTOM_FLOAT:
		{
			CPrintToChat(iParam1, "{green}Coming soon!");
			DisplayMenu_WeaponOptions(iParam1, szInfo[1]);
		}
		case MENUSELECT_WOPTIONS_NAME_TAG:
		{
			CPrintToChat(iParam1, "{green}Coming soon!");
			DisplayMenu_WeaponOptions(iParam1, szInfo[1]);
		}
	}
}

DisplayMenu_PaintSelectShowUnused(iClient, const String:szWeaponEnt[], iStartItem=0)
{
	strcopy(g_szMenuPosition_PaintSelectWeaponEnt[iClient], VDF_TOKEN_LEN, szWeaponEnt);
	
	decl String:szBuffer[VDF_TOKEN_LEN];
	GetLocalizedWeaponName(iClient, szWeaponEnt, szBuffer, sizeof(szBuffer));
	
	new Handle:hMenu = CreateMenu(MenuHandle_PaintSelect);
	SetMenuTitle(hMenu, "Skins that are unknown\n%s", szBuffer);
	
	static String:szInfo[VDF_TOKEN_LEN], ePaint[PaintKit];
	decl iIndex;
	for(new i=0; i<GetArraySize(g_aUnusedPaintKitIndexes); i++)
	{
		iIndex = GetArrayCell(g_aUnusedPaintKitIndexes, i);
		GetArrayArray(g_aPaintKits, iIndex, ePaint);
		
		if(!GetClientsLocalizedString(iClient, ePaint[PAINT_TAG], szBuffer, sizeof(szBuffer)))
			strcopy(szBuffer, sizeof(szBuffer), ePaint[PAINT_TAG]);
		
		StrCat(szBuffer, sizeof(szBuffer), ePaint[PAINT_POSTFIX]);
		Format(szBuffer, sizeof(szBuffer), "%s - %i", szBuffer, ePaint[PAINT_ID]);
		
		FormatEx(szInfo, sizeof(szInfo), "%i~%s", iIndex, szWeaponEnt);
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}There are no unknown skins.");
}

DisplayMenu_PaintSelectShowAll(iClient, const String:szWeaponEnt[], iStartItem=0)
{
	strcopy(g_szMenuPosition_PaintSelectWeaponEnt[iClient], VDF_TOKEN_LEN, szWeaponEnt);
	
	decl String:szBuffer[VDF_TOKEN_LEN];
	GetLocalizedWeaponName(iClient, szWeaponEnt, szBuffer, sizeof(szBuffer));
	
	new Handle:hMenu = CreateMenu(MenuHandle_PaintSelect);
	SetMenuTitle(hMenu, "Skins from other weapons on this weapon\n%s", szBuffer);
	
	static String:szInfo[VDF_TOKEN_LEN], ePaint[PaintKit];
	
	GetClientsLocalizedString(iClient, DELOCALIZED_RANDOM, szBuffer, sizeof(szBuffer));
	FormatEx(szInfo, sizeof(szInfo), "-1~%s", szWeaponEnt);
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	for(new i=0; i<GetArraySize(g_aPaintKits); i++)
	{
		GetArrayArray(g_aPaintKits, i, ePaint);
		
		if(!GetClientsLocalizedString(iClient, ePaint[PAINT_TAG], szBuffer, sizeof(szBuffer)))
			strcopy(szBuffer, sizeof(szBuffer), ePaint[PAINT_TAG]);
		
		StrCat(szBuffer, sizeof(szBuffer), ePaint[PAINT_POSTFIX]);
		
		FormatEx(szInfo, sizeof(szInfo), "%i~%s", i, szWeaponEnt);
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}There are no skins.");
}

DisplayMenu_PaintSelectWeaponEntSpecific(iClient, const String:szWeaponEnt[], iStartItem=0)
{
	strcopy(g_szMenuPosition_PaintSelectWeaponEnt[iClient], VDF_TOKEN_LEN, szWeaponEnt);
	
	decl iIndex;
	if(!GetTrieValue(g_hTrie_PaintsForWeaponEntsMap, szWeaponEnt, iIndex))
	{
		CPrintToChat(iClient, "{red}There are no skins for this weapon.");
		DisplayMenu_WeaponOptions(iClient, szWeaponEnt);
		
		return;
	}
	
	new Handle:hPaints = GetArrayCell(g_aPaintsForWeaponEnts, iIndex);
	
	decl String:szBuffer[VDF_TOKEN_LEN];
	GetLocalizedWeaponName(iClient, szWeaponEnt, szBuffer, sizeof(szBuffer));
	
	new Handle:hMenu = CreateMenu(MenuHandle_PaintSelect);
	SetMenuTitle(hMenu, "Skins meant for this weapon\n%s", szBuffer);
	
	static String:szInfo[VDF_TOKEN_LEN], ePaint[PaintKit];
	
	GetClientsLocalizedString(iClient, DELOCALIZED_RANDOM, szBuffer, sizeof(szBuffer));
	FormatEx(szInfo, sizeof(szInfo), "-1~%s", szWeaponEnt);
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	for(new i=0; i<GetArraySize(hPaints); i++)
	{
		iIndex = GetArrayCell(hPaints, i);
		GetArrayArray(g_aPaintKits, iIndex, ePaint);
		
		if(!GetClientsLocalizedString(iClient, ePaint[PAINT_TAG], szBuffer, sizeof(szBuffer)))
			strcopy(szBuffer, sizeof(szBuffer), ePaint[PAINT_TAG]);
		
		StrCat(szBuffer, sizeof(szBuffer), ePaint[PAINT_POSTFIX]);
		
		FormatEx(szInfo, sizeof(szInfo), "%i~%s", iIndex, szWeaponEnt);
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}There are no skins for this weapon.");
}

public MenuHandle_PaintSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_WeaponOptions(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1]);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	static Float:fNextUse[MAXPLAYERS+1];
	if(GetEngineTime() < fNextUse[iParam1])
	{
		CPrintToChat(iParam1, "{red}Please do not spam this menu.");
		
		if(g_iMenu_PaintListType[iParam1] == MENUSELECT_WOPTIONS_UNUSED)
		{
			DisplayMenu_PaintSelectShowUnused(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
		}
		else if(g_iMenu_PaintListType[iParam1] == MENUSELECT_WOPTIONS_THIS_WEAPON)
		{
			DisplayMenu_PaintSelectWeaponEntSpecific(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
		}
		else
		{
			DisplayMenu_PaintSelectShowAll(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
		}
		
		return;
	}
	
	fNextUse[iParam1] = GetEngineTime() + 1.0;
	
	static String:szBuffer[2][VDF_TOKEN_LEN];
	GetMenuItem(hMenu, iParam2, szBuffer[0], sizeof(szBuffer[]));
	
	ExplodeString(szBuffer[0], "~", szBuffer, sizeof(szBuffer), sizeof(szBuffer[]));
	
	if(StrEqual(szBuffer[0], "-1"))
	{
		SetClientsPaintKitForWeapon(iParam1, -1, szBuffer[1]);
		
		GetClientsLocalizedString(iParam1, DELOCALIZED_RANDOM, szBuffer[0], sizeof(szBuffer[]));
		GetLocalizedWeaponName(iParam1, szBuffer[1], szBuffer[1], sizeof(szBuffer[]));
		
		CPrintToChat(iParam1, "{olive}Using {lightred}%s {olive}for your {yellow}%s{olive}.", szBuffer[0], szBuffer[1]);
		
		if(g_iMenu_PaintListType[iParam1] == MENUSELECT_WOPTIONS_UNUSED)
		{
			DisplayMenu_PaintSelectShowUnused(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
		}
		else if(g_iMenu_PaintListType[iParam1] == MENUSELECT_WOPTIONS_THIS_WEAPON)
		{
			DisplayMenu_PaintSelectWeaponEntSpecific(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
		}
		else
		{
			DisplayMenu_PaintSelectShowAll(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
		}
		
		return;
	}
	
	new iPaintKitIndex = StringToInt(szBuffer[0]);
	SetClientsPaintKitForWeapon(iParam1, iPaintKitIndex, szBuffer[1]);
	
	static ePaint[PaintKit];
	GetArrayArray(g_aPaintKits, iPaintKitIndex, ePaint);
	
	GetClientsLocalizedString(iParam1, ePaint[PAINT_TAG], szBuffer[0], sizeof(szBuffer[]));
	GetLocalizedWeaponName(iParam1, szBuffer[1], szBuffer[1], sizeof(szBuffer[]));
	
	CPrintToChat(iParam1, "{olive}Using {lightred}%s {olive}for your {yellow}%s{olive}.", szBuffer[0], szBuffer[1]);
	
	if(g_iMenu_PaintListType[iParam1] == MENUSELECT_WOPTIONS_UNUSED)
	{
		DisplayMenu_PaintSelectShowUnused(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
	}
	else if(g_iMenu_PaintListType[iParam1] == MENUSELECT_WOPTIONS_THIS_WEAPON)
	{
		DisplayMenu_PaintSelectWeaponEntSpecific(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
	}
	else
	{
		DisplayMenu_PaintSelectShowAll(iParam1, g_szMenuPosition_PaintSelectWeaponEnt[iParam1], GetMenuSelectionPosition());
	}
}

SetClientsPaintKitForWeapon(iClient, iPaintKitIndex, const String:szWeaponEnt[])
{
	decl iItemDefIndex;
	if(!GetTrieValue(g_hTrie_WeaponEntToItemDefIndex, szWeaponEnt, iItemDefIndex))
		return false;
	
	decl String:szItemDefIndex[12];
	IntToString(iItemDefIndex, szItemDefIndex, sizeof(szItemDefIndex));
	
	if(iPaintKitIndex == -1)
		RemoveFromTrie(g_hTrie_ClientItemDefToPaintKitIndex[iClient], szItemDefIndex);
	else
		SetTrieValue(g_hTrie_ClientItemDefToPaintKitIndex[iClient], szItemDefIndex, iPaintKitIndex, true);
	
	TryRecreateWeapon(iClient, iItemDefIndex);
	InsertClientsPaintInDatabase(iClient, iItemDefIndex, iPaintKitIndex);
	
	return true;
}

InsertClientsPaintInDatabase(iClient, iItemDefIndex, iPaintKitIndex)
{
	new iUserID = DBUsers_GetUserID(iClient);
	if(iUserID < 1)
		return;
	
	if(iPaintKitIndex == -1)
	{
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "DELETE FROM plugin_weapon_skins WHERE user_id = %i AND item_def = %i", iUserID, iItemDefIndex);
		return;
	}
	
	decl ePaintKit[PaintKit];
	GetArrayArray(g_aPaintKits, iPaintKitIndex, ePaintKit);
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "INSERT INTO plugin_weapon_skins (user_id, item_def, paint) VALUES (%i, %i, %i) ON DUPLICATE KEY UPDATE paint = %i", iUserID, iItemDefIndex, ePaintKit[PAINT_ID], ePaintKit[PAINT_ID]);
}

bool:TryRecreateWeapon(iClient, iItemDefIndex)
{
	if(!IsPlayerAlive(iClient))
		return false;
	
	decl String:szInfo[48], String:szWeaponEnt[48];
	IntToString(iItemDefIndex, szInfo, sizeof(szInfo));
	
	if(!GetTrieString(g_hTrie_ItemDefIndexToWeaponEnt, szInfo, szWeaponEnt, sizeof(szWeaponEnt)))
		return false;
	
	Format(szWeaponEnt, sizeof(szWeaponEnt), "weapon_%s", szWeaponEnt);
	
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	new iWeaponToStrip, iWeaponSlotIndex, iActiveWeapon;
	decl iWeapon, Float:fActiveNextPrimaryAttack;
	for(new i=0; i<iArraySize; i++)
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if(iWeapon < 1)
			continue;
		
		if(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == iWeapon)
		{
			GetEntityClassname(iWeapon, szInfo, sizeof(szInfo));
			iActiveWeapon = iWeapon;
			fActiveNextPrimaryAttack = GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack");
		}
		
		if(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == iItemDefIndex)
		{
			iWeaponToStrip = iWeapon;
			iWeaponSlotIndex = i;
		}
	}
	
	if(!iWeaponToStrip)
		return false;
	
	new iClipSize = GetEntProp(iWeaponToStrip, Prop_Send, "m_iClip1");
	new iReserveSize = GetEntProp(iWeaponToStrip, Prop_Send, "m_iPrimaryReserveAmmoCount");
	new iBurstMode = GetEntProp(iWeaponToStrip, Prop_Send, "m_bBurstMode");
	new iSilencer = GetEntProp(iWeaponToStrip, Prop_Send, "m_bSilencerOn");
	
	StripWeaponFromOwner(iWeaponToStrip);
	SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, iWeaponSlotIndex);
	
	iWeapon = GivePlayerItemCustom(iClient, szWeaponEnt);
	if(iWeapon < 1)
		return false;
	
	SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClipSize);
	SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", iReserveSize);
	SetEntProp(iWeapon, Prop_Send, "m_bBurstMode", iBurstMode);
	SetEntProp(iWeapon, Prop_Send, "m_bSilencerOn", iSilencer);
	
	if(iActiveWeapon)
	{
		if(iActiveWeapon == iWeaponToStrip)
			iActiveWeapon = iWeapon;
		
		// Make sure all knives use "weapon_knife".
		new iChar = szInfo[12];
		szInfo[12] = '\x0';
		
		if(!StrEqual(szInfo, "weapon_knife"))
			szInfo[12] = iChar;
		
		FakeClientCommand(iClient, "use %s", szInfo);
		SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextPrimaryAttack", fActiveNextPrimaryAttack);
	}
	
	return true;
}

GivePlayerItemCustom(iClient, const String:szClassName[])
{
	new iEnt = GivePlayerItem(iClient, szClassName);
	
	/*
	* 	Sometimes GivePlayerItem() will call EquipPlayerWeapon() directly.
	* 	Other times which seems to be directly after stripping weapons or player spawn EquipPlayerWeapon() won't get called.
	* 	Call EquipPlayerWeapon() here if it wasn't called during GivePlayerItem(). Determine that by checking the entities owner.
	*/
	if(iEnt != -1 && GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == -1)
		EquipPlayerWeapon(iClient, iEnt);
	
	return iEnt;
}

StripWeaponFromOwner(iWeapon)
{
	new iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if(iOwner != -1)
	{
		// First drop the weapon.
		SDKHooks_DropWeapon(iOwner, iWeapon);
		
		// If the weapon still has an owner after being dropped call RemovePlayerItem.
		// Note we check m_hOwner instead of m_hOwnerEntity here.
		if(GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner") == iOwner)
			RemovePlayerItem(iOwner, iWeapon);
		
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", -1);
	}
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel != -1)
	{
		SetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel", -1);
		AcceptEntityInput(iWorldModel, "KillHierarchy");
	}
	
	AcceptEntityInput(iWeapon, "KillHierarchy");
}

public OnClientPutInServer(iClient)
{
	if(g_hTrie_ClientItemDefToPaintKitIndex[iClient] == INVALID_HANDLE)
		g_hTrie_ClientItemDefToPaintKitIndex[iClient] = CreateTrie();
	
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public OnClientDisconnect_Post(iClient)
{
	if(g_hTrie_ClientItemDefToPaintKitIndex[iClient] == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hTrie_ClientItemDefToPaintKitIndex[iClient]);
	g_hTrie_ClientItemDefToPaintKitIndex[iClient] = INVALID_HANDLE;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetSkins, DBPrio_Low, GetClientSerial(iClient), "SELECT item_def, paint FROM plugin_weapon_skins WHERE user_id=%i", iUserID);
}

public Query_GetSkins(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	decl iIndex, String:szKey[12];
	while(SQL_FetchRow(hQuery))
	{
		IntToString(SQL_FetchInt(hQuery, 1), szKey, sizeof(szKey));
		if(!GetTrieValue(g_hTrie_PaintIDToPaintKitIndex, szKey, iIndex))
			continue;
		
		IntToString(SQL_FetchInt(hQuery, 0), szKey, sizeof(szKey));
		SetTrieValue(g_hTrie_ClientItemDefToPaintKitIndex[iClient], szKey, iIndex, true);
	}
}

public OnWeaponEquipPost(iClient, iWeapon)
{
	if(iWeapon < 1 || !IsValidEdict(iWeapon))
		return;
	
	if(GetEntPropEnt(iWeapon, Prop_Send, "m_hPrevOwner") > 0)
		return;
	
	new iArraySize = GetArraySize(g_aPaintKits);
	if(!iArraySize)
		return;
	
	static String:szItemDefIndex[12];
	IntToString(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"), szItemDefIndex, sizeof(szItemDefIndex));
	
	decl iIndex;
	if(!GetTrieValue(g_hTrie_ClientItemDefToPaintKitIndex[iClient], szItemDefIndex, iIndex))
		iIndex = GetRandomInt(0, iArraySize-1);
	
	static ePaint[PaintKit];
	GetArrayArray(g_aPaintKits, iIndex, ePaint);
	
	new iAccountID = GetSteamAccountID(iClient, false);
	SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
	SetEntProp(iWeapon, Prop_Send, "m_iItemIDLow", -1);
	SetEntProp(iWeapon, Prop_Send, "m_iItemIDHigh", 0);
	SetEntProp(iWeapon, Prop_Send, "m_nFallbackSeed", ePaint[PAINT_SEED]);
	SetEntProp(iWeapon, Prop_Send, "m_iAccountID", iAccountID);
	SetEntProp(iWeapon, Prop_Send, "m_nFallbackStatTrak", GetStatTrakCount(iClient));
	SetEntProp(iWeapon, Prop_Send, "m_nFallbackPaintKit", ePaint[PAINT_ID]);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flFallbackWear", 0.000001);
	SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 3); // TODO: Remove stattrak from default knives (and gold), grenades, and c4. The stattrak model gets in your view.
	
	// TODO: Add name tags.
	//decl String:szNameTag[21];
	//strcopy(szNameTag, sizeof(szNameTag), "");
	//SetEntDataString(iWeapon, FindSendPropInfo("CBaseAttributableItem", "m_szCustomName"), szNameTag, sizeof(szNameTag), true);
}

GetStatTrakCount(iClient)
{
	if(g_bLibLoaded_ClientCookies)
	{
		#if defined _client_cookies_included
		return ClientCookies_GetCookie(iClient, CC_TYPE_SWOOBLES_POINTS);
		#endif
	}
	
	switch(GetRandomInt(1, 8))
	{
		case 1: return 1337;
		case 2: return 666;
		case 3: return 123456;
		case 4: return 131071;
		case 5: return 65536;
		case 6: return 101010;
		case 7: return 10101;
		case 8: return 80085;
	}
	
	return 0;
}

bool:LoadData_ItemsGame()
{
	new Handle:hKeyVals = CreateKeyValues("");
	if(!FileToKeyValues(hKeyVals, ITEMS_GAME_FILEPATH))
	{
		LogError("File \"%s\" could not be loaded.", ITEMS_GAME_FILEPATH);
		CloseHandle(hKeyVals);
		return false;
	}
	
	if(!ItemsGame_ReadCategories(hKeyVals, IGC_PAINT_KITS_RARITY))
	{
		LogError("File \"%s\" could not read paint_kits_rarity.", ITEMS_GAME_FILEPATH);
		CloseHandle(hKeyVals);
		return false;
	}
	
	if(!ItemsGame_ReadCategories(hKeyVals, IGC_PAINT_KITS))
	{
		LogError("File \"%s\" could not read paint_kits.", ITEMS_GAME_FILEPATH);
		CloseHandle(hKeyVals);
		return false;
	}
	
	if(!ItemsGame_ReadCategories(hKeyVals, IGC_ITEM_SETS))
	{
		LogError("File \"%s\" could not read item_sets.", ITEMS_GAME_FILEPATH);
		CloseHandle(hKeyVals);
		return false;
	}
	
	if(!ItemsGame_ReadCategories(hKeyVals, IGC_CLIENT_LOOT_LISTS))
	{
		LogError("File \"%s\" could not read client_loot_lists.", ITEMS_GAME_FILEPATH);
		CloseHandle(hKeyVals);
		return false;
	}
	
	new Handle:hWeaponsNeedDelocalizedName = CreateArray(VDF_TOKEN_LEN);
	if(!ItemsGame_ReadCategories(hKeyVals, IGC_ITEMS, hWeaponsNeedDelocalizedName))
	{
		LogError("File \"%s\" could not read items.", ITEMS_GAME_FILEPATH);
		CloseHandle(hKeyVals);
		CloseHandle(hWeaponsNeedDelocalizedName);
		return false;
	}
	
	if(!ItemsGame_ReadCategories(hKeyVals, IGC_PREFABS, hWeaponsNeedDelocalizedName))
	{
		LogError("File \"%s\" could not read prefabs.", ITEMS_GAME_FILEPATH);
		CloseHandle(hKeyVals);
		CloseHandle(hWeaponsNeedDelocalizedName);
		return false;
	}
	CloseHandle(hWeaponsNeedDelocalizedName);
	
	ItemsGame_AddUnknownEntPaintsManually();
	ItemsGame_AddPaintKitPostFixesManually();
	ItemsGame_FindUnusedPaints();
	
	// Cleanup
	decl Handle:hWeapons;
	for(new i=0; i<GetArraySize(g_aWeaponEntsForPrefabs); i++)
	{
		hWeapons = GetArrayCell(g_aWeaponEntsForPrefabs, i);
		if(hWeapons != INVALID_HANDLE)
			CloseHandle(hWeapons);
	}
	
	CloseHandle(g_aWeaponEntsForPrefabs);
	CloseHandle(g_hTrie_WeaponEntsForPrefabsMap);
	CloseHandle(hKeyVals);
	
	return true;
}

ItemsGame_FindUnusedPaints()
{
	decl ePaintKit[PaintKit];
	new iArraySize = GetArraySize(g_aPaintKits);
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aPaintKits, i, ePaintKit);
		
		if(ePaintKit[PAINT_FOUND_WEAPON])
			continue;
		
		if(FindValueInArray(g_aUnusedPaintKitIndexes, i) == -1)
			PushArrayCell(g_aUnusedPaintKitIndexes, i);
	}
}

bool:ItemsGame_AddUnknownEntPaintsManually()
{
	// Huntsman
	AddKnifeDuplicatesToKnifeEnt("knife_tactical");
	AddPaintForWeaponClassname("knife_tactical", _, 411);	// Damascus Steel
	AddPaintForWeaponClassname("knife_tactical", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_tactical", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_tactical", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_tactical", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_tactical", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_tactical", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_tactical", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_tactical", _, 620);	// Ultraviolet
	
	// Shadow daggers
	AddKnifeDuplicatesToKnifeEnt("knife_push");
	AddPaintForWeaponClassname("knife_push", _, 411);	// Damascus Steel
	AddPaintForWeaponClassname("knife_push", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_push", _, 618);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_push", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_push", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_push", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_push", _, 619);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_push", _, 617);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_push", _, 98);	// Ultraviolet
	
	// Butterfly
	AddKnifeDuplicatesToKnifeEnt("knife_butterfly");
	AddPaintForWeaponClassname("knife_butterfly", _, 411);	// Damascus Steel
	AddPaintForWeaponClassname("knife_butterfly", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_butterfly", _, 618);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_butterfly", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_butterfly", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_butterfly", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_butterfly", _, 619);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_butterfly", _, 617);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_butterfly", _, 98);	// Ultraviolet
	
	// Falchion
	AddKnifeDuplicatesToKnifeEnt("knife_falchion");
	AddPaintForWeaponClassname("knife_falchion", _, 411);	// Damascus Steel
	AddPaintForWeaponClassname("knife_falchion", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_falchion", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_falchion", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_falchion", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_falchion", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_falchion", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_falchion", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_falchion", _, 621);	// Ultraviolet
	
	// Bowie
	AddKnifeDuplicatesToKnifeEnt("knife_survival_bowie");
	AddPaintForWeaponClassname("knife_survival_bowie", _, 411);	// Damascus Steel
	AddPaintForWeaponClassname("knife_survival_bowie", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_survival_bowie", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_survival_bowie", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_survival_bowie", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_survival_bowie", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_survival_bowie", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_survival_bowie", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_survival_bowie", _, 98);	// Ultraviolet
	
	// Karambit
	AddKnifeDuplicatesToKnifeEnt("knife_karambit");
	AddPaintForWeaponClassname("knife_karambit", _, 410);	// Damascus Steel
	AddPaintForWeaponClassname("knife_karambit", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_karambit", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_karambit", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_karambit", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_karambit", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_karambit", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_karambit", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_karambit", _, 98);	// Ultraviolet
	AddPaintForWeaponClassname("knife_karambit", _, 561);	// Lore
	AddPaintForWeaponClassname("knife_karambit", _, 566);	// Black Laminate
	AddPaintForWeaponClassname("knife_karambit", _, 569);	// Gamma Doppler Phase 1
	AddPaintForWeaponClassname("knife_karambit", _, 570);	// Gamma Doppler Phase 2
	AddPaintForWeaponClassname("knife_karambit", _, 571);	// Gamma Doppler Phase 3
	AddPaintForWeaponClassname("knife_karambit", _, 572);	// Gamma Doppler Phase 4
	AddPaintForWeaponClassname("knife_karambit", _, 568);	// Gamma Doppler Emerald
	AddPaintForWeaponClassname("knife_karambit", _, 576);	// Autotronic
	AddPaintForWeaponClassname("knife_karambit", _, 578);	// Bright Water
	AddPaintForWeaponClassname("knife_karambit", _, 582);	// Freehand
	
	// Gut
	AddKnifeDuplicatesToKnifeEnt("knife_gut");
	AddPaintForWeaponClassname("knife_gut", _, 410);	// Damascus Steel
	AddPaintForWeaponClassname("knife_gut", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_gut", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_gut", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_gut", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_gut", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_gut", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_gut", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_gut", _, 98);		// Ultraviolet
	AddPaintForWeaponClassname("knife_gut", _, 560);	// Lore
	AddPaintForWeaponClassname("knife_gut", _, 565);	// Black Laminate
	AddPaintForWeaponClassname("knife_gut", _, 569);	// Gamma Doppler Phase 1
	AddPaintForWeaponClassname("knife_gut", _, 570);	// Gamma Doppler Phase 2
	AddPaintForWeaponClassname("knife_gut", _, 571);	// Gamma Doppler Phase 3
	AddPaintForWeaponClassname("knife_gut", _, 572);	// Gamma Doppler Phase 4
	AddPaintForWeaponClassname("knife_gut", _, 568);	// Gamma Doppler Emerald
	AddPaintForWeaponClassname("knife_gut", _, 575);	// Autotronic
	AddPaintForWeaponClassname("knife_gut", _, 578);	// Bright Water
	AddPaintForWeaponClassname("knife_gut", _, 580);	// Freehand
	
	// Flip
	AddKnifeDuplicatesToKnifeEnt("knife_flip");
	AddPaintForWeaponClassname("knife_flip", _, 410);	// Damascus Steel
	AddPaintForWeaponClassname("knife_flip", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_flip", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_flip", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_flip", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_flip", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_flip", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_flip", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_flip", _, 98);	// Ultraviolet
	AddPaintForWeaponClassname("knife_flip", _, 559);	// Lore
	AddPaintForWeaponClassname("knife_flip", _, 564);	// Black Laminate
	AddPaintForWeaponClassname("knife_flip", _, 569);	// Gamma Doppler Phase 1
	AddPaintForWeaponClassname("knife_flip", _, 570);	// Gamma Doppler Phase 2
	AddPaintForWeaponClassname("knife_flip", _, 571);	// Gamma Doppler Phase 3
	AddPaintForWeaponClassname("knife_flip", _, 572);	// Gamma Doppler Phase 4
	AddPaintForWeaponClassname("knife_flip", _, 568);	// Gamma Doppler Emerald
	AddPaintForWeaponClassname("knife_flip", _, 574);	// Autotronic
	AddPaintForWeaponClassname("knife_flip", _, 578);	// Bright Water
	AddPaintForWeaponClassname("knife_flip", _, 580);	// Freehand
	
	// Bayonet
	AddKnifeDuplicatesToKnifeEnt("bayonet");
	AddPaintForWeaponClassname("bayonet", _, 410);	// Damascus Steel
	AddPaintForWeaponClassname("bayonet", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("bayonet", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("bayonet", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("bayonet", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("bayonet", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("bayonet", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("bayonet", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("bayonet", _, 98);	// Ultraviolet
	AddPaintForWeaponClassname("bayonet", _, 558);	// Lore
	AddPaintForWeaponClassname("bayonet", _, 563);	// Black Laminate
	AddPaintForWeaponClassname("bayonet", _, 569);	// Gamma Doppler Phase 1
	AddPaintForWeaponClassname("bayonet", _, 570);	// Gamma Doppler Phase 2
	AddPaintForWeaponClassname("bayonet", _, 571);	// Gamma Doppler Phase 3
	AddPaintForWeaponClassname("bayonet", _, 572);	// Gamma Doppler Phase 4
	AddPaintForWeaponClassname("bayonet", _, 568);	// Gamma Doppler Emerald
	AddPaintForWeaponClassname("bayonet", _, 573);	// Autotronic
	AddPaintForWeaponClassname("bayonet", _, 578);	// Bright Water
	AddPaintForWeaponClassname("bayonet", _, 580);	// Freehand
	
	// M9 Bayonet
	AddKnifeDuplicatesToKnifeEnt("knife_m9_bayonet");
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 411);	// Damascus Steel
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 418);	// Doppler Phase 1
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 419);	// Doppler Phase 2
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 420);	// Doppler Phase 3
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 421);	// Doppler Phase 4
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 415);	// Doppler Ruby
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 416);	// Doppler Sapphire
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 417);	// Doppler Black Pearl
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 98);	// Ultraviolet
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 562);	// Lore
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 567);	// Black Laminate
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 569);	// Gamma Doppler Phase 1
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 570);	// Gamma Doppler Phase 2
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 571);	// Gamma Doppler Phase 3
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 572);	// Gamma Doppler Phase 4
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 568);	// Gamma Doppler Emerald
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 577);	// Autotronic
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 579);	// Bright Water
	AddPaintForWeaponClassname("knife_m9_bayonet", _, 581);	// Freehand
}

AddKnifeDuplicatesToKnifeEnt(const String:szWeaponEnt[])
{
	AddPaintForWeaponClassname(szWeaponEnt, _, 12);		// Crimson Web
	AddPaintForWeaponClassname(szWeaponEnt, _, 38);		// Fade
	AddPaintForWeaponClassname(szWeaponEnt, _, 72);		// Safari Mesh
	AddPaintForWeaponClassname(szWeaponEnt, _, 42);		// Blue Steel
	AddPaintForWeaponClassname(szWeaponEnt, _, 44);		// Case Hardened
	AddPaintForWeaponClassname(szWeaponEnt, _, 40);		// Night
	AddPaintForWeaponClassname(szWeaponEnt, _, 77);		// Boreal Forest
	AddPaintForWeaponClassname(szWeaponEnt, _, 43);		// Stained
	AddPaintForWeaponClassname(szWeaponEnt, _, 175);	// Scorched
	AddPaintForWeaponClassname(szWeaponEnt, _, 5);		// Forest DDPAT
	AddPaintForWeaponClassname(szWeaponEnt, _, 413);	// Marble Fade
	AddPaintForWeaponClassname(szWeaponEnt, _, 409);	// Tiger Tooth
	AddPaintForWeaponClassname(szWeaponEnt, _, 414);	// Rust Coat
	AddPaintForWeaponClassname(szWeaponEnt, _, 59);		// Slaughter
	AddPaintForWeaponClassname(szWeaponEnt, _, 143);	// Urban Masked
}

ItemsGame_AddPaintKitPostFixesManually()
{
	ItemsGame_AddPaintPostfix(418, " Phase 1");		// Doppler
	ItemsGame_AddPaintPostfix(419, " Phase 2"); 	// Doppler
	ItemsGame_AddPaintPostfix(420, " Phase 3"); 	// Doppler
	ItemsGame_AddPaintPostfix(421, " Phase 4");		// Doppler
	ItemsGame_AddPaintPostfix(415, " Ruby"); 		// Doppler
	ItemsGame_AddPaintPostfix(416, " Sapphire"); 	// Doppler
	ItemsGame_AddPaintPostfix(619, " Sapphire"); 	// Doppler
	ItemsGame_AddPaintPostfix(417, " Black Pearl");	// Doppler
	ItemsGame_AddPaintPostfix(617, " Black Pearl");	// Doppler
	
	ItemsGame_AddPaintPostfix(569, " Phase 1"); 	// Gamma Doppler
	ItemsGame_AddPaintPostfix(570, " Phase 2"); 	// Gamma Doppler
	ItemsGame_AddPaintPostfix(571, " Phase 3"); 	// Gamma Doppler
	ItemsGame_AddPaintPostfix(572, " Phase 4"); 	// Gamma Doppler
	ItemsGame_AddPaintPostfix(568, " Emerald"); 	// Gamma Doppler
	
	ItemsGame_AddPaintPostfix(411, " Rotated"); 	// Damascus Steel
	ItemsGame_AddPaintPostfix(579, " Rotated"); 	// Bright Water
	
	ItemsGame_AddPaintPostfix(620, " Huntsman");	// Ultraviolet
	ItemsGame_AddPaintPostfix(621, " Falchion");	// Ultraviolet
	
	ItemsGame_AddPaintPostfix(576, " Karambit");	// Autotronic
	ItemsGame_AddPaintPostfix(575, " Gut");			// Autotronic
	ItemsGame_AddPaintPostfix(574, " Flip");		// Autotronic
	ItemsGame_AddPaintPostfix(573, " Bayonet");		// Autotronic
	ItemsGame_AddPaintPostfix(577, " M9 Bayonet");	// Autotronic
	
	ItemsGame_AddPaintPostfix(581, " Rotated");		// Freehand
	ItemsGame_AddPaintPostfix(582, " Fine");		// Freehand
	
	ItemsGame_AddPaintPostfix(561, " Karambit");	// Lore
	ItemsGame_AddPaintPostfix(560, " Gut");			// Lore
	ItemsGame_AddPaintPostfix(559, " Flip");		// Lore
	ItemsGame_AddPaintPostfix(558, " Bayonet");		// Lore
	ItemsGame_AddPaintPostfix(562, " M9 Bayonet");	// Lore
	
	ItemsGame_AddPaintPostfix(566, " Karambit");	// Black Laminate
	ItemsGame_AddPaintPostfix(565, " Gut");			// Black Laminate
	ItemsGame_AddPaintPostfix(564, " Flip");		// Black Laminate
	ItemsGame_AddPaintPostfix(563, " Bayonet");		// Black Laminate
	ItemsGame_AddPaintPostfix(567, " M9 Bayonet");	// Black Laminate
}

bool:ItemsGame_AddPaintPostfix(iPaintID, const String:szPostfix[])
{
	decl String:szPaintID[12];
	IntToString(iPaintID, szPaintID, sizeof(szPaintID));
	
	decl iPaintKitIndex;
	if(!GetTrieValue(g_hTrie_PaintIDToPaintKitIndex, szPaintID, iPaintKitIndex))
	{
		LogMessage("ItemsGame_AddPaintPostfix: Paint ID \"%i\" doesn't exist.", iPaintID);
		return false;
	}
	
	decl ePaintKit[PaintKit];
	GetArrayArray(g_aPaintKits, iPaintKitIndex, ePaintKit);
	strcopy(ePaintKit[PAINT_POSTFIX], POSTFIX_LEN, szPostfix);
	SetArrayArray(g_aPaintKits, iPaintKitIndex, ePaintKit);
	
	return true;
}

bool:ItemsGame_ReadCategories(const Handle:hKeyVals, ItemsGameCategory:iCategory, const Handle:hExtra=INVALID_HANDLE)
{
	if(!KvGotoFirstSubKey(hKeyVals))
		return false;
	
	new bool:bFound;
	decl String:szBuffer[32];
	do
	{
		if(!KvGetSectionName(hKeyVals, szBuffer, sizeof(szBuffer)))
			continue;
		
		switch(iCategory)
		{
			case IGC_PAINT_KITS_RARITY:
			{
				if(!StrEqual(szBuffer, "paint_kits_rarity"))
					continue;
				
				ItemsGame_ReadPaintKitsRarity(hKeyVals);
				bFound = true;
			}
			case IGC_PAINT_KITS:
			{
				if(!StrEqual(szBuffer, "paint_kits"))
					continue;
				
				ItemsGame_ReadPaintKits(hKeyVals);
				bFound = true;
			}
			case IGC_ITEM_SETS:
			{
				if(!StrEqual(szBuffer, "item_sets"))
					continue;
				
				ItemsGame_ReadItemSets(hKeyVals);
				bFound = true;
			}
			case IGC_CLIENT_LOOT_LISTS:
			{
				if(!StrEqual(szBuffer, "client_loot_lists"))
					continue;
				
				new Handle:hClientLootList = CreateArray(VDF_TOKEN_LEN);
				ItemsGame_ReadClientLootLists(hKeyVals, hClientLootList);
				ItemsGame_ReadClientLootLists(hKeyVals, hClientLootList);
				CloseHandle(hClientLootList);
				bFound = true;
			}
			case IGC_ITEMS:
			{
				if(!StrEqual(szBuffer, "items"))
					continue;
				
				ItemsGame_ReadItems(hKeyVals, hExtra);
				bFound = true;
			}
			case IGC_PREFABS:
			{
				if(!StrEqual(szBuffer, "prefabs"))
					continue;
				
				while(ItemsGame_ReadPrefabs(hKeyVals, hExtra))
				{
					//
				}
				
				bFound = true;
			}
		}
	}
	while(KvGotoNextKey(hKeyVals));
	
	KvRewind(hKeyVals);
	return bFound;
}

ItemsGame_ReadItems(const Handle:hKeyVals, const Handle:hWeaponsNeedDelocalizedName)
{
	if(!KvGotoFirstSubKey(hKeyVals))
		return;
	
	decl String:szBuffer[VDF_TOKEN_LEN], String:szBuffer2[VDF_TOKEN_LEN], String:szIndex[11], iTemp, bool:bVal;
	do
	{
		if(!KvGetSectionName(hKeyVals, szIndex, sizeof(szIndex)))
			continue;
		
		KvGetString(hKeyVals, "name", szBuffer, sizeof(szBuffer));
		
		// Check if item is a weapon.
		iTemp = szBuffer[7];
		szBuffer[7] = '\x0';
		bVal = StrEqual(szBuffer, "weapon_");
		szBuffer[7] = iTemp;
		
		if(bVal)
		{
			if(strlen(szBuffer) > 7)
			{
				SetTrieValue(g_hTrie_WeaponEntToItemDefIndex, szBuffer[7], StringToInt(szIndex));
				SetTrieString(g_hTrie_ItemDefIndexToWeaponEnt, szIndex, szBuffer[7]);
				
				KvGetString(hKeyVals, "prefab", szBuffer2, sizeof(szBuffer2));
				if(szBuffer2[0])
					AddWeaponEntForPrefab(szBuffer, szBuffer2);
				
				// Try to get the delocalized string from item_name, if not we have to get it from the prefab table.
				KvGetString(hKeyVals, "item_name", szBuffer2, sizeof(szBuffer2));
				if(szBuffer2[0])
				{
					SetTrieString(g_hTrie_WeaponEntToDelocalizedName, szBuffer[7], szBuffer2[1]);
					AddAsUsedDelocalizedString(szBuffer2[1]);
					continue;
				}
				
				KvGetString(hKeyVals, "prefab", szBuffer, sizeof(szBuffer));
				if(szBuffer[0] && FindStringInArray(hWeaponsNeedDelocalizedName, szBuffer) == -1)
					PushArrayString(hWeaponsNeedDelocalizedName, szBuffer);
			}
			
			continue;
		}
		
		// Check if item is a crate.
		iTemp = szBuffer[6];
		szBuffer[6] = '\x0';
		bVal = StrEqual(szBuffer, "crate_");
		szBuffer[6] = iTemp;
		
		if(bVal)
		{
			// TODO: Implement container feature.
			//PrintToServer(" + %s: %s", szIndex, szBuffer);
			continue;
		}
	}
	while(KvGotoNextKey(hKeyVals));
	
	KvGoBack(hKeyVals);
}

bool:ItemsGame_ReadPrefabs(const Handle:hKeyVals, const Handle:hWeaponsNeedDelocalizedName)
{
	if(!KvGotoFirstSubKey(hKeyVals))
		return false;
	
	new bool:bReloop;
	decl String:szPrefabName[VDF_TOKEN_LEN], String:szBuffer[VDF_TOKEN_LEN], String:szBuffer2[VDF_TOKEN_LEN], iWeaponEntsIndex, Handle:hWeapons, i;
	do
	{
		if(!KvGetSectionName(hKeyVals, szPrefabName, sizeof(szPrefabName)))
			continue;
		
		// Try to get the delocalized name for the weapons that need it still.
		i = FindStringInArray(hWeaponsNeedDelocalizedName, szPrefabName);
		if(i != -1)
		{
			// We have to manually assign the item_class for some weapons that share classnames.
			if(StrEqual(szPrefabName, "weapon_revolver_prefab"))
			{
				strcopy(szBuffer, sizeof(szBuffer), "weapon_revolver");
			}
			else if(StrEqual(szPrefabName, "weapon_usp_silencer_prefab"))
			{
				strcopy(szBuffer, sizeof(szBuffer), "weapon_usp_silencer");
			}
			else if(StrEqual(szPrefabName, "weapon_cz75a_prefab"))
			{
				strcopy(szBuffer, sizeof(szBuffer), "weapon_cz75a");
			}
			else if(StrEqual(szPrefabName, "weapon_m4a1_silencer_prefab"))
			{
				strcopy(szBuffer, sizeof(szBuffer), "weapon_m4a1_silencer");
			}
			else
			{
				KvGetString(hKeyVals, "item_class", szBuffer, sizeof(szBuffer));
			}
			
			KvGetString(hKeyVals, "item_name", szBuffer2, sizeof(szBuffer2));
			
			if(szBuffer[0] && szBuffer2[0])
			{
				SetTrieString(g_hTrie_WeaponEntToDelocalizedName, szBuffer[7], szBuffer2[1]);
				RemoveFromArray(hWeaponsNeedDelocalizedName, i);
				
				AddAsUsedDelocalizedString(szBuffer2[1]);
			}
		}
		
		// Try to put the weapon classnames into their weapon category.
		if(!GetTrieValue(g_hTrie_WeaponEntsForPrefabsMap, szPrefabName, iWeaponEntsIndex))
			continue;
		
		hWeapons = GetArrayCell(g_aWeaponEntsForPrefabs, iWeaponEntsIndex);
		if(hWeapons == INVALID_HANDLE)
			continue;
		
		for(i=0; i<GetArraySize(hWeapons); i++)
		{
			GetArrayString(hWeapons, i, szBuffer, sizeof(szBuffer));
			RemoveFromArray(hWeapons, i);
			i--;
			
			KvGetString(hKeyVals, "item_type_name", szBuffer2, sizeof(szBuffer2));
			
			if(!szBuffer2[0])
			{
				KvGetString(hKeyVals, "prefab", szBuffer2, sizeof(szBuffer2));
				if(szBuffer2[0] && AddWeaponEntForPrefab(szBuffer, szBuffer2))
					bReloop = true;
				
				continue;
			}
			
			if(AddWeaponToCategory(szBuffer, szPrefabName, szBuffer2[1]))
				AddAsUsedDelocalizedString(szBuffer2[1]);
		}
	}
	while(KvGotoNextKey(hKeyVals));
	
	KvGoBack(hKeyVals);
	return bReloop;
}

ItemsGame_ReadPaintKitsRarity(const Handle:hKeyVals)
{
	if(!KvGotoFirstSubKey(hKeyVals, false))
		return;
	
	new Handle:hPaintNames = CreateArray(VDF_TOKEN_LEN);
	decl String:szPaintName[VDF_TOKEN_LEN];
	do
	{
		if(!KvGetSectionName(hKeyVals, szPaintName, sizeof(szPaintName)))
			continue;
		
		PushArrayString(hPaintNames, szPaintName);
	}
	while(KvGotoNextKey(hKeyVals, false));
	
	KvGoBack(hKeyVals);
	
	decl String:szRarity[VDF_TOKEN_LEN];
	for(new i=0; i<GetArraySize(hPaintNames); i++)
	{
		GetArrayString(hPaintNames, i, szPaintName, sizeof(szPaintName));
		KvGetString(hKeyVals, szPaintName, szRarity, sizeof(szRarity));
		SetTrieString(g_hTrie_PaintNameToRarity, szPaintName, szRarity, true);
		
		if(FindStringInArray(g_aPaintRarities, szRarity) == -1)
			PushArrayString(g_aPaintRarities, szRarity);
	}
	
	CloseHandle(hPaintNames);
}

ItemsGame_ReadPaintKits(const Handle:hKeyVals)
{
	if(!KvGotoFirstSubKey(hKeyVals))
		return;
	
	decl String:szBuffer[VDF_TOKEN_LEN], ePaintKit[PaintKit], String:szIndex[11], iIndex, iID;
	do
	{
		if(!KvGetSectionName(hKeyVals, szIndex, sizeof(szIndex)))
			continue;
		
		iID = StringToInt(szIndex);
		
		// Skip "default" and "workshop_default"
		if(iID == 0 || iID == 9001)
			continue;
		
		// All weapon skins have "style" set (for now at least). Filter out anything else by checking this value.
		KvGetString(hKeyVals, "style", szBuffer, sizeof(szBuffer));
		
		if(!szBuffer[0])
			continue;
		
		ePaintKit[PAINT_ID] = iID;
		KvGetString(hKeyVals, "name", ePaintKit[PAINT_NAME], VDF_TOKEN_LEN);
		KvGetString(hKeyVals, "description_tag", szBuffer, sizeof(szBuffer));
		strcopy(ePaintKit[PAINT_POSTFIX], PAINT_POSTFIX, "");
		ePaintKit[PAINT_SEED] = KvGetNum(hKeyVals, "seed");
		ePaintKit[PAINT_FOUND_WEAPON] = false;
		
		// Remove the # from the PAINT_TAG.
		strcopy(ePaintKit[PAINT_TAG], VDF_TOKEN_LEN, szBuffer[1]);
		
		iIndex = PushArrayArray(g_aPaintKits, ePaintKit);
		SetTrieValue(g_hTrie_PaintIDToPaintKitIndex, szIndex, iIndex, true);
		SetTrieValue(g_hTrie_PaintNameToPaintKitIndex, ePaintKit[PAINT_NAME], iIndex, true);
		
		AddAsUsedDelocalizedString(ePaintKit[PAINT_TAG]);
	}
	while(KvGotoNextKey(hKeyVals));
	
	KvGoBack(hKeyVals);
}

ItemsGame_ReadItemSets(const Handle:hKeyVals)
{
	if(!KvGotoFirstSubKey(hKeyVals))
		return;
	
	decl String:szBuffer[VDF_TOKEN_LEN];
	do
	{
		KvGetString(hKeyVals, "name", szBuffer, sizeof(szBuffer));
		if(!szBuffer[0])
			continue;
		
		if(!KvJumpToKey(hKeyVals, "items"))
			continue;
		
		AddAsUsedDelocalizedString(szBuffer[1]);
		
		if(ItemsGame_ReadSetData(hKeyVals, szBuffer, false))
		{
			//
		}
		
		KvGoBack(hKeyVals);
	}
	while(KvGotoNextKey(hKeyVals));
	
	KvGoBack(hKeyVals);
}

ItemsGame_ReadClientLootLists(const Handle:hKeyVals, const Handle:hClientLootList)
{
	if(!KvGotoFirstSubKey(hKeyVals))
		return;
	
	// Getting client_loot_lists items are done in two stages.
	// Stage 1: Populate the hClientLootList array.
	// Stage 2: Get rest of data.
	decl iClientLootListStageNum;
	if(!GetArraySize(hClientLootList))
		iClientLootListStageNum = 1;
	else
		iClientLootListStageNum = 2;
	
	decl String:szBuffer[VDF_TOKEN_LEN], String:szStripped[VDF_TOKEN_LEN];
	do
	{
		if(!KvGetSectionName(hKeyVals, szBuffer, sizeof(szBuffer)))
			continue;
		
		if(iClientLootListStageNum == 1)
		{
			PushArrayString(hClientLootList, szBuffer);
			continue;
		}
		
		StripRarityFromClientLootListName(szBuffer, szStripped, sizeof(szStripped));
		
		if(ItemsGame_ReadSetData(hKeyVals, szStripped, true))
		{
			//
		}
	}
	while(KvGotoNextKey(hKeyVals));
	
	KvGoBack(hKeyVals);
}

StripRarityFromClientLootListName(const String:szName[], String:szStripped[], iMaxLength)
{
	new iNameLen = strlen(szName);
	
	decl String:szRarity[VDF_TOKEN_LEN], iRarityLen, iIndex;
	for(new i=0; i<GetArraySize(g_aPaintRarities); i++)
	{
		GetArrayString(g_aPaintRarities, i, szRarity, sizeof(szRarity));
		
		iRarityLen = strlen(szRarity);
		if(iNameLen < iRarityLen)
			continue;
		
		if(!StrEqual(szRarity, szName[iNameLen - iRarityLen]))
			continue;
		
		strcopy(szStripped, iMaxLength, szName);
		
		iIndex = (iNameLen - iRarityLen) >= iMaxLength ? (iMaxLength - 1) : (iNameLen - iRarityLen - 1);
		if(iIndex < 0)
			iIndex = 0;
		
		szStripped[iIndex] = '\x0';
	}
}

bool:ItemsGame_ReadSetData(const Handle:hKeyVals, const String:szSetName[], bool:bIsClientLootList)
{
	// NOTE: If bIsClientLootList is true it means we are getting data from client_loot_lists, otherwise from item_sets.
	
	if(!KvGotoFirstSubKey(hKeyVals, false))
		return false;
	
	new bool:bFound;
	decl String:szBuffer[VDF_TOKEN_LEN], String:szClassName[64], iPos;
	do
	{
		// Example buffer: [gs_m4a4_pioneer]weapon_m4a1
		// We need to split the paint name from the entity classname.
		if(!KvGetSectionName(hKeyVals, szBuffer, sizeof(szBuffer)))
			continue;
		
		// Make sure the buffer is in the format we are expecting.
		if(StrContains(szBuffer, "[") != 0 || (iPos = StrContains(szBuffer, "]")) == -1)
			continue;
		
		if(strlen(szBuffer) <= (iPos + 8))
			continue;
		
		strcopy(szClassName, sizeof(szClassName), szBuffer[iPos+1]);
		
		// Remove [ and ] from the paint name.
		szBuffer[iPos] = '\x0';
		strcopy(szBuffer, sizeof(szBuffer), szBuffer[1]);
		
		// Make sure the classname is a weapon.
		iPos = szClassName[7];
		szClassName[7] = '\x0';
		
		if(!StrEqual(szClassName, "weapon_"))
			continue;
		
		szClassName[7] = iPos;
		bFound = true;
		
		// TODO: Implement set feature.
		// %i - Set name - Paint kit name - Entity class name
		//PrintToServer("%i - %s: %s - %s", bIsClientLootList, szSetName, szBuffer, szClassName);
		
		AddPaintForWeaponClassname(szClassName[7], szBuffer);
	}
	while(KvGotoNextKey(hKeyVals, false));
	
	KvGoBack(hKeyVals);
	
	return bFound;
}

AddAsUsedDelocalizedString(const String:szDelocalizedString[])
{
	if(FindStringInArray(g_aDelocalizedStringsUsed, szDelocalizedString) == -1)
		PushArrayString(g_aDelocalizedStringsUsed, szDelocalizedString);
}

bool:AddPaintForWeaponClassname(const String:szWeaponEntName[], const String:szPaintKitName[]="", iPaintID=-1)
{
	decl iPaintKitIndex;
	
	if(iPaintID != -1)
	{
		decl String:szPaintID[12];
		IntToString(iPaintID, szPaintID, sizeof(szPaintID));
		if(!GetTrieValue(g_hTrie_PaintIDToPaintKitIndex, szPaintID, iPaintKitIndex))
		{
			LogMessage("AddPaintForWeaponClassname: Paint ID \"%i\" doesn't exist.", iPaintID);
			return false;
		}
	}
	else
	{
		if(!GetTrieValue(g_hTrie_PaintNameToPaintKitIndex, szPaintKitName, iPaintKitIndex))
		{
			LogMessage("AddPaintForWeaponClassname: Paint Name \"%s\" doesn't exist.", szPaintKitName);
			return false;
		}
	}
	
	decl ePaintKit[PaintKit];
	GetArrayArray(g_aPaintKits, iPaintKitIndex, ePaintKit);
	
	decl iWeaponEntsIndex, Handle:hPaints;
	if(!GetTrieValue(g_hTrie_PaintsForWeaponEntsMap, szWeaponEntName, iWeaponEntsIndex))
	{
		hPaints = CreateArray();
		iWeaponEntsIndex = PushArrayCell(g_aPaintsForWeaponEnts, hPaints);
		
		if(!SetTrieValue(g_hTrie_PaintsForWeaponEntsMap, szWeaponEntName, iWeaponEntsIndex, false))
		{
			CloseHandle(hPaints);
			RemoveFromArray(g_aPaintsForWeaponEnts, iWeaponEntsIndex);
			LogMessage("AddPaintForWeaponClassname: Failed adding paint \"%s\" to weapon \"%s\".", ePaintKit[PAINT_NAME], szWeaponEntName);
			return false;
		}
	}
	else
	{
		hPaints = GetArrayCell(g_aPaintsForWeaponEnts, iWeaponEntsIndex);
	}
	
	if(FindValueInArray(hPaints, iPaintKitIndex) == -1)
		PushArrayCell(hPaints, iPaintKitIndex);
	
	ePaintKit[PAINT_FOUND_WEAPON] = true;
	SetArrayArray(g_aPaintKits, iPaintKitIndex, ePaintKit);
	
	return true;
}

bool:AddWeaponEntForPrefab(const String:szWeaponEntName[], const String:szPrefabName[])
{
	decl iWeaponEntsIndex, Handle:hWeapons;
	if(!GetTrieValue(g_hTrie_WeaponEntsForPrefabsMap, szPrefabName, iWeaponEntsIndex))
	{
		hWeapons = CreateArray(VDF_TOKEN_LEN);
		iWeaponEntsIndex = PushArrayCell(g_aWeaponEntsForPrefabs, hWeapons);
		
		if(!SetTrieValue(g_hTrie_WeaponEntsForPrefabsMap, szPrefabName, iWeaponEntsIndex, false))
		{
			CloseHandle(hWeapons);
			RemoveFromArray(g_aWeaponEntsForPrefabs, iWeaponEntsIndex);
			LogMessage("Trying to add prefab name \"%s\" but it failed for some reason.", szPrefabName);
			return false;
		}
	}
	else
	{
		hWeapons = GetArrayCell(g_aWeaponEntsForPrefabs, iWeaponEntsIndex);
	}
	
	if(FindStringInArray(hWeapons, szWeaponEntName) == -1)
		PushArrayString(hWeapons, szWeaponEntName);
	
	return true;
}

bool:AddWeaponToCategory(const String:szWeaponEntName[], const String:szCategory[], const String:szDelocalizedCategory[])
{
	if(strlen(szWeaponEntName) < 8)
		return false;
	
	if(StrEqual(szDelocalizedCategory, "CSGO_Type_Equipment"))
		return false;
	
	if(StrEqual(szDelocalizedCategory, "CSGO_Type_Grenade"))
		return false;
	
	decl iWeaponEntsIndex, Handle:hWeapons;
	if(!GetTrieValue(g_hTrie_WeaponEntsForCategoriesMap, szCategory, iWeaponEntsIndex))
	{
		hWeapons = CreateArray(VDF_TOKEN_LEN);
		iWeaponEntsIndex = PushArrayCell(g_aWeaponEntsForCategories, hWeapons);
		
		if(!SetTrieValue(g_hTrie_WeaponEntsForCategoriesMap, szCategory, iWeaponEntsIndex, false))
		{
			CloseHandle(hWeapons);
			RemoveFromArray(g_aWeaponEntsForCategories, iWeaponEntsIndex);
			LogMessage("Trying to add category name \"%s\" but it failed for some reason.", szCategory);
			return false;
		}
	}
	else
	{
		hWeapons = GetArrayCell(g_aWeaponEntsForCategories, iWeaponEntsIndex);
	}
	
	if(FindStringInArray(hWeapons, szWeaponEntName[7]) == -1)
		PushArrayString(hWeapons, szWeaponEntName[7]);
	
	if(FindStringInArray(g_aWeaponCategories, szDelocalizedCategory) == -1)
		PushArrayString(g_aWeaponCategories, szDelocalizedCategory);
	
	SetTrieString(g_hTrie_DelocalizedCategoryToCategoryMap, szDelocalizedCategory, szCategory, false);
	
	return true;
}