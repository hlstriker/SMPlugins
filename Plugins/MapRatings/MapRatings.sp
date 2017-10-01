#include <sourcemod>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/DatabaseUsers/database_users"
#include "../../Libraries/ClientTimes/client_times"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Map Ratings";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to rate maps.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define SECONDS_IN_SERVER_TO_RATE	480

new String:g_szDatabaseConfigName[64];
new Handle:cvar_database_servers_configname;

new bool:g_bLoadedFromDB[MAXPLAYERS+1];
new g_iCurrentStars[MAXPLAYERS+1];

enum Rating
{
	RATING_DONT_CARE = 0,
	RATING_1_STAR,
	RATING_2_STAR,
	RATING_3_STAR
};

new const String:g_szRatingName[][] =
{
	"I don't care.",
	"Map sucks.. hate it.",
	"Map is alright, sometimes.",
	"Map is really good!"
};

new Handle:cvar_mp_endmatch_votenextleveltime;


public OnPluginStart()
{
	CreateConVar("map_ratings_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("cs_intermission", Event_Intermission_Post, EventHookMode_PostNoCopy);
}

public OnConfigsExecuted()
{
	if((cvar_mp_endmatch_votenextleveltime = FindConVar("mp_endmatch_votenextleveltime")) == INVALID_HANDLE)
		return;
	
	if(GetConVarInt(cvar_mp_endmatch_votenextleveltime) < 10)
		SetConVarInt(cvar_mp_endmatch_votenextleveltime, 10);
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
	if(!Query_CreateTable_MapRatings())
		SetFailState("There was an error creating the plugin_map_ratings sql table.");
}

bool:Query_CreateTable_MapRatings()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_map_ratings\
	(\
		user_id		INT UNSIGNED		NOT NULL,\
		map_id		INT UNSIGNED		NOT NULL,\
		rating		TINYINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( user_id, map_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnClientPutInServer(iClient)
{
	g_bLoadedFromDB[iClient] = false;
	g_iCurrentStars[iClient] = 0;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetRating, DBPrio_Low, GetClientSerial(iClient), "SELECT rating FROM plugin_map_ratings WHERE user_id=%i AND map_id=%i", iUserID, DBMaps_GetMapID());
}

public Query_GetRating(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_bLoadedFromDB[iClient] = true;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	if(SQL_FetchRow(hQuery))
		g_iCurrentStars[iClient] = PercentToStars(SQL_FetchInt(hQuery, 0));
}

public Event_Intermission_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		if(g_iCurrentStars[iClient])
			DisplayMenu_RerateMap(iClient);
		else
			DisplayMenu_RateMap(iClient);
	}
}

bool:CanRateMap(iClient)
{
	if(!g_bLoadedFromDB[iClient])
		return false;
	
	if(ClientTimes_GetTimeInServer(iClient) < SECONDS_IN_SERVER_TO_RATE)
		return false;
		
	return true;
}

DisplayMenu_RerateMap(iClient)
{
	if(!CanRateMap(iClient))
		return;
	
	decl String:szTitle[128];
	Format(szTitle, sizeof(szTitle), "You already gave this map a rating of:\n%s\n \nWould you like to re-rate this map?", g_szRatingName[g_iCurrentStars[iClient]]);
	
	new Handle:hMenu = CreateMenu(MenuHandle_RerateMap);
	SetMenuTitle(hMenu, szTitle);
	
	AddMenuItem(hMenu, "0", "No");
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "1", "Yes");
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, false);
	DisplayMenu(hMenu, iClient, 0);
}

public MenuHandle_RerateMap(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
	
	if(StringToInt(szInfo) == 1)
		DisplayMenu_RateMap(iParam1);
}

DisplayMenu_RateMap(iClient)
{
	if(!CanRateMap(iClient))
		return;
	
	new Handle:hMenu = CreateMenu(MenuHandle_RateMap);
	SetMenuTitle(hMenu, "Please tell us what you thought of this map.");
	
	decl String:szInfo[2];
	IntToString(_:RATING_DONT_CARE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, g_szRatingName[RATING_DONT_CARE]);
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(_:RATING_2_STAR, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, g_szRatingName[RATING_2_STAR]);
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(_:RATING_3_STAR, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, g_szRatingName[RATING_3_STAR]);
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(_:RATING_1_STAR, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, g_szRatingName[RATING_1_STAR]);
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, false);
	DisplayMenu(hMenu, iClient, 0);
}

public MenuHandle_RateMap(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
	
	new iRating = StringToInt(szInfo);
	new iPercent = StarsToPercent(iRating);
	
	if(!iPercent)
		return;
	
	new iUserID = DBUsers_GetUserID(iParam1);
	if(iUserID < 1)
	{
		CPrintToChat(iParam1, "{red}There was an error rating.");
		return;
	}
	
	g_iCurrentStars[iParam1] = iRating;
	
	CPrintToChat(iParam1, "{olive}Rated as: {yellow}%s", g_szRatingName[iRating]);
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "INSERT INTO plugin_map_ratings (user_id, map_id, rating) VALUES (%i, %i, %i) ON DUPLICATE KEY UPDATE rating=%i", iUserID, DBMaps_GetMapID(), iPercent, iPercent);
}

PercentToStars(iPercent)
{
	if(iPercent >= 0 && iPercent <= 34)
	{
		return 1;
	}
	else if(iPercent >= 35 && iPercent <= 66)
	{
		return 2;
	}
	else if(iPercent >= 67 && iPercent <= 100)
	{
		return 3;
	}
	
	return 0;
}

StarsToPercent(iStars)
{
	switch(iStars)
	{
		case 1: return 1;
		case 2: return 50;
		case 3: return 100;
	}
	
	return 0;
}