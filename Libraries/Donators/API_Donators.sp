#include <sourcemod>
#include <sdkhooks>
#include "../DatabaseCore/database_core"
#include "../DatabaseUsers/database_users"
#include "../DatabaseServers/database_servers"
#include "../WebPageViewer/web_page_viewer"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Donators";
new const String:PLUGIN_VERSION[] = "2.6";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage donators.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szDatabaseBridgeConfigName[64];
new Handle:cvar_database_bridge_configname;

new Handle:g_hFwd_OnStatusLoaded;

new bool:g_bIsDonator[MAXPLAYERS+1];
new Float:g_fExpiresTime[MAXPLAYERS+1];

new Handle:g_hFwd_OnRegisterSettingsReady;

#define SETTING_MAX_TITLE_LEN	32
new Handle:g_aSettingsMenu;
enum _:SettingsMenu
{
	String:SETTING_TITLE[SETTING_MAX_TITLE_LEN],
	Handle:SETTING_FORWARD
};

const Float:MESSAGE_DISPLAY_DELAY = 120.0;
new Float:g_fNextMessageDisplay[MAXPLAYERS+1];

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("api_donators_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_store", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_shop", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_models", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_skins", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_d", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_donator", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_donate", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_points", OnOpenDonatorMenu, "Opens the donator menu.");
	RegConsoleCmd("sm_credits", OnOpenDonatorMenu, "Opens the donator menu.");
	
	g_hFwd_OnStatusLoaded = CreateGlobalForward("Donators_OnStatusLoaded", ET_Ignore, Param_Cell);
	g_hFwd_OnRegisterSettingsReady = CreateGlobalForward("Donators_OnRegisterSettingsReady", ET_Ignore);
	
	g_aSettingsMenu = CreateArray(SettingsMenu);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("donators");
	CreateNative("Donators_IsDonator", _Donators_IsDonator);
	CreateNative("Donators_GetSubscriptionTimeLeft", _Donators_GetSubscriptionTimeLeft);
	CreateNative("Donators_RegisterSettings", _Donators_RegisterSettings);
	CreateNative("Donators_OpenSettingsMenu", _Donators_OpenSettingsMenu);
	
	return APLRes_Success;
}

public _Donators_OpenSettingsMenu(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
		return false;
	
	new iClient = GetNativeCell(1);
	DisplayMenu_Settings(iClient);
	
	return true;
}

public OnMapStart()
{
	decl eSettingsMenu[SettingsMenu];
	for(new i=0; i<GetArraySize(g_aSettingsMenu); i++)
	{
		GetArrayArray(g_aSettingsMenu, i, eSettingsMenu);
		
		if(eSettingsMenu[SETTING_FORWARD] != INVALID_HANDLE)
			CloseHandle(eSettingsMenu[SETTING_FORWARD]);
	}
	
	ClearArray(g_aSettingsMenu);
	
	Call_StartForward(g_hFwd_OnRegisterSettingsReady);
	Call_Finish();
	
	SortSettingsByTitle();
}

SortSettingsByTitle()
{
	new iArraySize = GetArraySize(g_aSettingsMenu);
	decl String:szTitle[SETTING_MAX_TITLE_LEN], eSettingsMenu[SettingsMenu], j, iIndex;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aSettingsMenu, i, eSettingsMenu);
		strcopy(szTitle, sizeof(szTitle), eSettingsMenu[SETTING_TITLE]);
		iIndex = 0;
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aSettingsMenu, j, eSettingsMenu);
			if(strcmp(szTitle, eSettingsMenu[SETTING_TITLE], false) < 0)
				continue;
			
			iIndex = j;
			strcopy(szTitle, sizeof(szTitle), eSettingsMenu[SETTING_TITLE]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aSettingsMenu, i, iIndex);
	}
}

public _Donators_RegisterSettings(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
		return false;
	
	decl String:szTitle[SETTING_MAX_TITLE_LEN];
	if(GetNativeString(1, szTitle, SETTING_MAX_TITLE_LEN) != SP_ERROR_NONE)
		return false;
	
	new Function:settings_callback = GetNativeCell(2);
	if(settings_callback == INVALID_FUNCTION)
		return false;
	
	decl eSettingsMenu[SettingsMenu];
	strcopy(eSettingsMenu[SETTING_TITLE], SETTING_MAX_TITLE_LEN, szTitle);
	
	eSettingsMenu[SETTING_FORWARD] = CreateForward(ET_Ignore, Param_Cell);
	AddToForward(eSettingsMenu[SETTING_FORWARD], hPlugin, settings_callback);
	
	PushArrayArray(g_aSettingsMenu, eSettingsMenu);
	return true;
}

public _Donators_IsDonator(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	return IsDonator(GetNativeCell(1));
}

bool:IsDonator(iClient)
{
	if(GetSubscriptionTimeLeft(iClient) < 1.0)
		return false;
	
	return true;
}

public _Donators_GetSubscriptionTimeLeft(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return _:0.0;
	}
	
	return _:GetSubscriptionTimeLeft(GetNativeCell(1));
}

Float:GetSubscriptionTimeLeft(iClient)
{
	if(!g_bIsDonator[iClient])
		return 0.0;
	
	new Float:fCurTime = GetGameTime();
	if(fCurTime >= g_fExpiresTime[iClient])
		return 0.0;
	
	return (g_fExpiresTime[iClient] - fCurTime);
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_bridge_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_bridge_configname, g_szDatabaseBridgeConfigName, sizeof(g_szDatabaseBridgeConfigName));
}

public OnAllPluginsLoaded()
{
	cvar_database_bridge_configname = FindConVar("sm_database_bridge_configname");
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_DonatorAmounts())
		return;
	
	if(!Query_CreateTable_DonatorServers())
		return;
	
	if(!Query_CreateTable_DonatorPackages())
		return;
	
	if(!Query_CreateTable_DonatorServerBills())
		return;
}

bool:Query_CreateTable_DonatorAmounts()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS donator_amounts\
	(\
		user_id						INT UNSIGNED		NOT NULL,\
		amt_donations_from_sub		FLOAT(11,2)			NOT NULL,\
		amt_donations_from_direct	FLOAT(11,2)			NOT NULL,\
		PRIMARY KEY ( user_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the donator_amounts sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_DonatorServers()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS donator_servers\
	(\
		user_id					INT UNSIGNED			NOT NULL,\
		server_id				SMALLINT UNSIGNED		NOT NULL,\
		donator_enabled			BIT( 1 )				NOT NULL,\
		donator_end_utime		INT						NOT NULL,\
		PRIMARY KEY ( user_id, server_id ),\
		INDEX ( donator_enabled, donator_end_utime ),\
		INDEX ( user_id, donator_end_utime )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the donator_servers sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_DonatorPackages()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS donator_packages\
	(\
		package_number			SMALLINT UNSIGNED		NOT NULL,\
		package_price			VARCHAR( 8 )			NOT NULL,\
		package_description		VARCHAR( 255 )			NOT NULL,\
		PRIMARY KEY ( package_number )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the donator_packages sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_DonatorServerBills()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseBridgeConfigName, "\
	CREATE TABLE IF NOT EXISTS donator_server_bills\
	(\
		server_id			SMALLINT UNSIGNED	NOT NULL,\
		funds_needed		FLOAT(11,2)			NOT NULL,\
		current_funds		FLOAT(11,2)			NOT NULL,\
		latest_month_paid	TINYINT				NOT NULL,\
		PRIMARY KEY ( server_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the donator_server_bills sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnClientConnected(iClient)
{
	g_bIsDonator[iClient] = false;
	g_fNextMessageDisplay[iClient] = 0.0;
}

public OnClientPutInServer(iClient)
{
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	new Float:fCurTime = GetGameTime();
	if(fCurTime < g_fNextMessageDisplay[iClient])
		return;
	
	g_fNextMessageDisplay[iClient] = fCurTime + MESSAGE_DISPLAY_DELAY;
	
	if(IsDonator(iClient))
	{
		CPrintToChat(iClient, "{olive}Type {lightred}!d {olive}to change your donator settings.");
	}
	else
	{
		CPrintToChat(iClient, "{olive}Enjoy this server? Consider donating to keep it alive.");
		CPrintToChat(iClient, "{olive}Type {lightred}!d {olive}to see the {lightred}perks {olive}you will get when you donate.");
	}
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseBridgeConfigName, Query_GetDonatorStatus, DBPrio_High, GetClientSerial(iClient), "\
		SELECT MAX(donator_end_utime) highest_end_utime, UNIX_TIMESTAMP() as cur_time FROM donator_servers WHERE user_id = %i AND (server_id = 0 OR server_id = %i) GROUP BY user_id",
		iUserID, DBServers_GetServerID());
}

public Query_GetDonatorStatus(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(!SQL_GetRowCount(hQuery))
	{
		_Donators_OnStatusLoaded(iClient);
		return;
	}
	
	if(!SQL_FetchRow(hQuery))
	{
		_Donators_OnStatusLoaded(iClient);
		return;
	}
	
	new iEndTime = SQL_FetchInt(hQuery, 0);
	new iCurTime = SQL_FetchInt(hQuery, 1);
	
	if(iCurTime >= iEndTime)
	{
		_Donators_OnStatusLoaded(iClient);
		return;
	}
	
	g_bIsDonator[iClient] = true;
	g_fExpiresTime[iClient] = GetGameTime() + float(iEndTime - iCurTime);
	
	_Donators_OnStatusLoaded(iClient);
}

_Donators_OnStatusLoaded(iClient)
{
	Call_StartForward(g_hFwd_OnStatusLoaded);
	Call_PushCell(iClient);
	Call_Finish();
}

public Action:OnOpenDonatorMenu(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(IsDonator(iClient))
		DisplayMenu_Settings(iClient);
	else
		DisplayMenu_NonDonator(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_NonDonator(iClient, iPosition=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_NonDonator);
	SetMenuTitle(hMenu, "Donator Menu");
	
	AddMenuItem(hMenu, "1", "Donate to the server.");
	AddMenuItem(hMenu, "2", "View donation perks.");
	
	if(!DisplayMenuAtItem(hMenu, iClient, iPosition, 0))
		CPrintToChat(iClient, "{green}-- {olive}Error.");
}

public MenuHandle_NonDonator(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iNum = StringToInt(szInfo);
	switch(iNum)
	{
		case 1:
		{
			// Donate to the server.
			decl String:szURL[255];
			if(GetClientAuthString(iParam1, szURL, sizeof(szURL)))
			{
				Format(szURL, sizeof(szURL), "http://swoobles.com/page/donate?steamid=%s", szURL);
				WebPageViewer_OpenPage(iParam1, szURL);
			}
		}
		case 2:
		{
			// View donation perks.
			decl String:szURL[255];
			FormatEx(szURL, sizeof(szURL), "http://swoobles.com/page/donate?sid=%i&perks=1#donation_wrapper", DBServers_GetServerID());
			WebPageViewer_OpenPage(iParam1, szURL);
		}
	}
	
	DisplayMenu_NonDonator(iParam1);
}

DisplayMenu_Settings(iClient, iPosition=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Settings);
	SetMenuTitle(hMenu, "Donator Settings");
	
	decl eSettingsMenu[SettingsMenu], String:szInfo[6];
	for(new i=0; i<GetArraySize(g_aSettingsMenu); i++)
	{
		GetArrayArray(g_aSettingsMenu, i, eSettingsMenu);
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, eSettingsMenu[SETTING_TITLE]);
	}
	
	if(!DisplayMenuAtItem(hMenu, iClient, iPosition, 0))
		CPrintToChat(iClient, "{green}-- {olive}There are no settings.");
}

public MenuHandle_Settings(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	decl eSettingsMenu[SettingsMenu];
	GetArrayArray(g_aSettingsMenu, StringToInt(szInfo), eSettingsMenu);
	
	Call_StartForward(eSettingsMenu[SETTING_FORWARD]);
	Call_PushCell(iParam1);
	if(Call_Finish() != SP_ERROR_NONE)
		LogError("Error calling setting forward for %s.", eSettingsMenu[SETTING_TITLE]);
}