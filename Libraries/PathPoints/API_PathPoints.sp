#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include "path_points"
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/DatabaseServers/database_servers"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Path Points";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API for managing path points.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define RADIUS_TO_SHOW_BEAMS	700.0
#define RADIUS_TO_ADD_POINT 	200.0

new g_iUniqueMapCounter;
new bool:g_bArePathPointsLoadedFromDB;

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

#define DISPLAY_BEAM_DELAY	0.1
#define BEAM_WIDTH			1.5
new const g_iBeamColor[] = {255, 255, 0, 255};
new g_iBeamIndex;
new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";

new Handle:g_hFwd_OnPointsLoaded;

#define MENU_MAIN_ADD	-2

#define MENU_VIEW_RENAME	1
#define MENU_VIEW_DELETE	2

#define MENU_DELETE_YES		1
#define MENU_DELETE_NO		2

new Handle:g_hTrie_PathNameToIndex;
new Handle:g_aPaths;
enum _:PPPath
{
	Handle:Path_Points,
	String:Path_Name[MAX_PATHPOINT_NAME_LEN]
};

enum _:PPPoint
{
	Float:Point_Origin[3],
	Float:Point_Angles[3]
};

new g_iEditingPathIndex[MAXPLAYERS+1];
new bool:g_bEditingPathName[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("api_path_points_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnPointsLoaded = CreateGlobalForward("PathPoints_OnPointsLoaded", ET_Ignore);
	
	g_aPaths = CreateArray(PPPath);
	g_hTrie_PathNameToIndex = CreateTrie();
	
	RegAdminCmd("sm_pathpoints", OnPathPoints, ADMFLAG_BAN, "Opens the path points menu.");
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

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("path_points");
	//CreateNative("PathPoints_GetPathNamePoints", _PathPoints_GetPathNamePoints);
	
	return APLRes_Success;
}

public OnMapStart()
{
	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL);
	
	g_iUniqueMapCounter++;
	g_bArePathPointsLoadedFromDB = false;
	
	decl ePath[PPPath];
	for(new i=0; i<GetArraySize(g_aPaths); i++)
	{
		GetArrayArray(g_aPaths, i, ePath);
		
		if(ePath[Path_Points] != INVALID_HANDLE)
			CloseHandle(ePath[Path_Points]);
	}
	
	ClearArray(g_aPaths);
	ClearTrie(g_hTrie_PathNameToIndex);
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_PathPoints())
		SetFailState("There was an error creating the plugin_pathpoints_points sql table.");
}

bool:Query_CreateTable_PathPoints()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_pathpoints_points\
	(\
		map_id		MEDIUMINT UNSIGNED	NOT NULL,\
		path_name	VARCHAR( 255 )		NOT NULL,\
		point_num	INT UNSIGNED		NOT NULL,\
		origin0		FLOAT( 11, 6 )		NOT NULL,\
		origin1		FLOAT( 11, 6 )		NOT NULL,\
		origin2		FLOAT( 11, 6 )		NOT NULL,\
		angles0		FLOAT( 11, 6 )		NOT NULL,\
		angles1		FLOAT( 11, 6 )		NOT NULL,\
		angles2		FLOAT( 11, 6 )		NOT NULL,\
		PRIMARY KEY ( map_id, path_name, point_num )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public DBMaps_OnMapIDReady(iMapID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetPathPoints, DBPrio_High, g_iUniqueMapCounter, "\
		SELECT path_name, \
		origin0, origin1, origin2, \
		angles0, angles1, angles2 \
		FROM plugin_pathpoints_points \
		WHERE map_id = %i \
		ORDER BY point_num ASC", iMapID);
}

public Query_GetPathPoints(Handle:hDatabase, Handle:hQuery, any:iUniqueMapCounter)
{
	if(g_iUniqueMapCounter != iUniqueMapCounter)
		return;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	AddPathPointsFromQuery(hQuery);
	g_bArePathPointsLoadedFromDB = true;
	
	Forward_OnPointsLoaded();
}

Forward_OnPointsLoaded()
{
	Call_StartForward(g_hFwd_OnPointsLoaded);
	Call_Finish();
}

AddPathPointsFromQuery(Handle:hQuery)
{
	decl String:szPathName[MAX_PATHPOINT_NAME_LEN], Float:fOrigin[3], Float:fAngles[3];
	
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 0, szPathName, sizeof(szPathName));
		
		fOrigin[0] = SQL_FetchFloat(hQuery, 1);
		fOrigin[1] = SQL_FetchFloat(hQuery, 2);
		fOrigin[2] = SQL_FetchFloat(hQuery, 3);
		
		fAngles[0] = AngleNormalize(SQL_FetchFloat(hQuery, 4));
		fAngles[1] = AngleNormalize(SQL_FetchFloat(hQuery, 5));
		fAngles[2] = AngleNormalize(SQL_FetchFloat(hQuery, 6));
		
		AddPathPoint(szPathName, fOrigin, fAngles);
	}
}

Float:AngleNormalize(Float:fAngle)
{
	fAngle = FloatMod(fAngle, 360.0);
	
	if(fAngle > 180.0) 
	{
		fAngle -= 360.0;
	}
	else if(fAngle < -180.0)
	{
		fAngle += 360.0;
	}
	
	return fAngle;
}

Float:FloatMod(Float:fNumerator, Float:fDenominator)
{
    return (fNumerator - fDenominator * RoundToFloor(fNumerator / fDenominator));
}

AddPathPoint(const String:szPathName[], const Float:fOrigin[3], const Float:fAngles[3])
{
	new iIndex = GetPathIndexFromName(szPathName);
	if(iIndex == -1)
		iIndex = CreatePath(szPathName);
	
	if(iIndex == -1)
	{
		LogError("Could not CreatePath for: %s", szPathName);
		return -1;
	}
	
	decl ePath[PPPath];
	GetArrayArray(g_aPaths, iIndex, ePath);
	
	decl ePoint[PPPoint];
	ePoint[Point_Origin][0] = fOrigin[0];
	ePoint[Point_Origin][1] = fOrigin[1];
	ePoint[Point_Origin][2] = fOrigin[2];
	ePoint[Point_Angles][0] = fAngles[0];
	ePoint[Point_Angles][1] = fAngles[1];
	ePoint[Point_Angles][2] = fAngles[2];
	
	return PushArrayArray(ePath[Path_Points], ePoint);
}

CreatePath(const String:szPathName[])
{
	decl ePath[PPPath];
	ePath[Path_Points] = CreateArray(PPPoint);
	strcopy(ePath[Path_Name], MAX_PATHPOINT_NAME_LEN, szPathName);
	new iIndex = PushArrayArray(g_aPaths, ePath);
	
	SetTrieValue(g_hTrie_PathNameToIndex, szPathName, iIndex, true);
	
	return iIndex;
}

GetPathIndexFromName(const String:szPathName[])
{
	decl iIndex;
	if(!GetTrieValue(g_hTrie_PathNameToIndex, szPathName, iIndex))
		return -1;
	
	return iIndex;
}

bool:TransactionStart_SavePathPoints(iPathIndex)
{
	if(iPathIndex < 0 || iPathIndex >= GetArraySize(g_aPaths))
		return false;
	
	new Handle:hDatabase = DB_GetDatabaseHandleFromConnectionName(g_szDatabaseConfigName);
	if(hDatabase == INVALID_HANDLE)
		return false;
	
	new iMapID = DBMaps_GetMapID();
	if(!iMapID)
		return false;
	
	decl ePath[PPPath];
	GetArrayArray(g_aPaths, iPathIndex, ePath);
	
	if(StrEqual(ePath[Path_Name], ""))
		return false;
	
	decl String:szSafePathName[MAX_PATHPOINT_NAME_LEN*2+1];
	if(!DB_EscapeString(g_szDatabaseConfigName, ePath[Path_Name], szSafePathName, sizeof(szSafePathName)))
		return false;
	
	decl String:szQuery[2048];
	new Handle:hTransaction = SQL_CreateTransaction();
	
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM plugin_pathpoints_points WHERE map_id = %i AND path_name = '%s'", iMapID, szSafePathName);
	SQL_AddQuery(hTransaction, szQuery);
	
	decl ePoint[PPPoint];
	for(new i=0; i<GetArraySize(ePath[Path_Points]); i++)
	{
		GetArrayArray(ePath[Path_Points], i, ePoint);
		
		FormatEx(szQuery, sizeof(szQuery), "\
			INSERT IGNORE INTO plugin_pathpoints_points \
			(map_id, path_name, point_num, origin0, origin1, origin2, angles0, angles1, angles2) \
			VALUES \
			(%i, '%s', %i, %f, %f, %f, %f, %f, %f)",
			iMapID, szSafePathName, i,
			ePoint[Point_Origin][0], ePoint[Point_Origin][1], ePoint[Point_Origin][2],
			ePoint[Point_Angles][0], ePoint[Point_Angles][1], ePoint[Point_Angles][2]);
		
		SQL_AddQuery(hTransaction, szQuery);
	}
	
	SQL_ExecuteTransaction(hDatabase, hTransaction, _, _, _, DBPrio_High);
	
	return true;
}

bool:DeleteAllPathPointsFromDatabase(iPathIndex)
{
	if(iPathIndex < 0 || iPathIndex >= GetArraySize(g_aPaths))
		return false;
	
	new iMapID = DBMaps_GetMapID();
	if(!iMapID)
		return false;
	
	decl ePath[PPPath];
	GetArrayArray(g_aPaths, iPathIndex, ePath);
	
	decl String:szSafePathName[MAX_PATHPOINT_NAME_LEN*2+1];
	if(!DB_EscapeString(g_szDatabaseConfigName, ePath[Path_Name], szSafePathName, sizeof(szSafePathName)))
		return false;
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_High, _, "DELETE FROM plugin_pathpoints_points WHERE map_id = %i AND path_name = '%s'", iMapID, szSafePathName);
	
	return true;
}

public Action:OnPathPoints(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!g_bArePathPointsLoadedFromDB)
	{
		ReplyToCommand(iClient, "Please wait until paths are loaded from the database.");
		return Plugin_Handled;
	}
	
	DisplayMenu_Main(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_Main(iClient, iStartItem=0)
{
	CancelClientMenu(iClient);
	
	g_iEditingPathIndex[iClient] = -1;
	g_bEditingPathName[iClient] = false;
	
	new iArraySize = GetArraySize(g_aPaths);
	
	decl String:szBuffer[64];
	FormatEx(szBuffer, sizeof(szBuffer), "Path Points\nTotal paths: %i", iArraySize);
	
	new Handle:hMenu = CreateMenu(MenuHandle_Main);
	SetMenuTitle(hMenu, szBuffer);
	
	decl String:szInfo[12];
	IntToString(MENU_MAIN_ADD, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Add new path");
	
	decl ePath[PPPath];
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aPaths, i, ePath);
		
		FormatEx(szBuffer, sizeof(szBuffer), "%s (%i)", ePath[Path_Name], GetArraySize(ePath[Path_Points]));
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}Error displaying menu.");
}

public MenuHandle_Main(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
	
	new iPathIndex = StringToInt(szInfo);
	
	if(iPathIndex == MENU_MAIN_ADD)
	{
		DisplayMenu_Name(iParam1, CreatePath(""), true);
		return;
	}
	
	DisplayMenu_View(iParam1, iPathIndex);
}

bool:DisplayMenu_View(iClient, iPathIndex, iStartItem=0)
{
	CancelClientMenu(iClient);
	
	if(iPathIndex >= GetArraySize(g_aPaths))
	{
		CPrintToChat(iClient, "{red}The selected path is no longer valid.");
		DisplayMenu_Main(iClient);
		return false;
	}
	
	decl ePath[PPPath];
	GetArrayArray(g_aPaths, iPathIndex, ePath);
	
	decl String:szBuffer[64];
	FormatEx(szBuffer, sizeof(szBuffer), "Walk around to create path points.\nName: %s\nPoints: %i", ePath[Path_Name], GetArraySize(ePath[Path_Points]));
	
	new Handle:hMenu = CreateMenu(MenuHandle_View);
	SetMenuTitle(hMenu, szBuffer);
	
	IntToString(MENU_VIEW_RENAME, szBuffer, sizeof(szBuffer));
	AddMenuItem(hMenu, szBuffer, "Rename");
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(MENU_VIEW_DELETE, szBuffer, sizeof(szBuffer));
	AddMenuItem(hMenu, szBuffer, "Delete");
	
	SetMenuExitBackButton(hMenu, true);
	if(DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		g_iEditingPathIndex[iClient] = iPathIndex;
		SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	}
	else
	{
		CPrintToChat(iClient, "{red}Error displaying menu.");
	}
	
	return true;
}

public MenuHandle_View(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		TransactionStart_SavePathPoints(g_iEditingPathIndex[iParam1]);
		
		g_iEditingPathIndex[iParam1] = -1;
		
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_Main(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENU_VIEW_RENAME:	DisplayMenu_Name(iParam1, g_iEditingPathIndex[iParam1]);
		case MENU_VIEW_DELETE:	DisplayMenu_Delete(iParam1, g_iEditingPathIndex[iParam1]);
	}
}

DisplayMenu_Delete(iClient, iPathIndex)
{
	CancelClientMenu(iClient);
	
	if(iPathIndex >= GetArraySize(g_aPaths))
	{
		CPrintToChat(iClient, "{red}The selected path is no longer valid.");
		DisplayMenu_Main(iClient);
		return;
	}
	
	decl ePath[PPPath];
	GetArrayArray(g_aPaths, iPathIndex, ePath);
	
	decl String:szBuffer[64];
	FormatEx(szBuffer, sizeof(szBuffer), "Delete this path?\n\nName: %s", ePath[Path_Name]);
	
	new Handle:hMenu = CreateMenu(MenuHandle_Delete);
	SetMenuTitle(hMenu, szBuffer);
	
	IntToString(MENU_DELETE_NO, szBuffer, sizeof(szBuffer));
	AddMenuItem(hMenu, szBuffer, "No, do not delete.");
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(MENU_DELETE_YES, szBuffer, sizeof(szBuffer));
	AddMenuItem(hMenu, szBuffer, "Yes, delete this path.");
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuExitButton(hMenu, false);
	if(DisplayMenu(hMenu, iClient, 0))
	{
		g_iEditingPathIndex[iClient] = iPathIndex;
	}
	else
	{
		CPrintToChat(iClient, "{red}Error displaying menu.");
	}
}

public MenuHandle_Delete(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		new iPathIndex = g_iEditingPathIndex[iParam1];
		g_iEditingPathIndex[iParam1] = -1;
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_View(iParam1, iPathIndex);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENU_DELETE_YES:
		{
			DeletePath(g_iEditingPathIndex[iParam1]);
			//DisplayMenu_Main(iParam1); // This will display from the loop within DeletePath.
		}
		case MENU_DELETE_NO:
		{
			DisplayMenu_View(iParam1, g_iEditingPathIndex[iParam1]);
		}
	}
}

DeletePath(iPathIndex)
{
	if(iPathIndex < 0 || iPathIndex >= GetArraySize(g_aPaths))
		return;
	
	// Delete from database first.
	DeleteAllPathPointsFromDatabase(iPathIndex);
	
	// Delete from array
	decl ePath[PPPath];
	GetArrayArray(g_aPaths, iPathIndex, ePath);
	
	if(ePath[Path_Points] != INVALID_HANDLE)
		CloseHandle(ePath[Path_Points]);
	
	RemoveFromArray(g_aPaths, iPathIndex);
	
	// Decrement other clients who are editing a path above this index.
	for(new iPlayer=1; iPlayer<sizeof(g_iEditingPathIndex); iPlayer++)
	{
		if(g_iEditingPathIndex[iPlayer] < 0)
			continue;
		
		// Editing same path index, force main menu open.
		if(g_iEditingPathIndex[iPlayer] == iPathIndex)
		{
			g_iEditingPathIndex[iPlayer] = -1;
			
			if(IsValidClientIndex(iPlayer) && IsClientInGame(iPlayer))
			{
				CPrintToChat(iPlayer, "{red}The path you were viewing has been deleted.");
				DisplayMenu_Main(iPlayer);
			}
			
			continue;
		}
		
		// Decrement
		if(g_iEditingPathIndex[iPlayer] > iPathIndex)
			g_iEditingPathIndex[iPlayer]--;
	}
	
	// Repopulate the pathname to index trie.
	RepopulatePathNameToIndexTrie();
}

RepopulatePathNameToIndexTrie()
{
	ClearTrie(g_hTrie_PathNameToIndex);
	
	decl ePath[PPPath];
	for(new i=0; i<GetArraySize(g_aPaths); i++)
		SetTrieValue(g_hTrie_PathNameToIndex, ePath[Path_Name], i, true);
}

bool:IsValidClientIndex(iClient)
{
	if(iClient < 1 || iClient > MaxClients)
		return false;
	
	return true;
}

DisplayMenu_Name(iClient, iPathIndex, bool:bIsFromInitialAdd=false)
{
	CancelClientMenu(iClient);
	
	if(iPathIndex >= GetArraySize(g_aPaths))
	{
		CPrintToChat(iClient, "{red}The selected path is no longer valid.");
		DisplayMenu_Main(iClient);
		return;
	}
	
	decl ePath[PPPath];
	GetArrayArray(g_aPaths, iPathIndex, ePath);
	
	decl String:szBuffer[64];
	FormatEx(szBuffer, sizeof(szBuffer), "Name this path by typing in chat.\n\nName: %s", ePath[Path_Name]);
	
	new Handle:hMenu = CreateMenu(MenuHandle_Name);
	SetMenuTitle(hMenu, szBuffer);
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	if(bIsFromInitialAdd)
	{
		SetMenuExitBackButton(hMenu, false);
		SetMenuExitButton(hMenu, false);
	}
	else
	{
		SetMenuExitBackButton(hMenu, true);
	}
	
	if(DisplayMenu(hMenu, iClient, 0))
	{
		g_iEditingPathIndex[iClient] = iPathIndex;
		g_bEditingPathName[iClient] = true;
	}
	else
	{
		CPrintToChat(iClient, "{red}Error displaying menu.");
	}
}

public MenuHandle_Name(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		new iPathIndex = g_iEditingPathIndex[iParam1];
		
		g_iEditingPathIndex[iParam1] = -1;
		g_bEditingPathName[iParam1] = false;
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_View(iParam1, iPathIndex);
		
		return;
	}
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_bEditingPathName[iClient] || g_iEditingPathIndex[iClient] == -1)
		return;
	
	new iPathIndex = g_iEditingPathIndex[iClient];
	
	new iArraySize = GetArraySize(g_aPaths);
	if(iPathIndex >= iArraySize)
	{
		CPrintToChat(iClient, "{red}The selected path is no longer valid.");
		DisplayMenu_Main(iClient);
		return;
	}
	
	decl String:szString[MAX_PATHPOINT_NAME_LEN];
	strcopy(szString, sizeof(szString), szArgs);
	TrimString(szString);
	
	if(!szString[0])
	{
		CPrintToChat(iClient, "{red}Invalid name.");
		return;
	}
	
	// Make sure this name doesn't already exist.
	decl ePath[PPPath];
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aPaths, i, ePath);
		
		if(StrEqual(ePath[Path_Name], szString, false))
		{
			CPrintToChat(iClient, "{red}%s is already a path name. Choose again.", szString);
			return;
		}
	}
	
	// Delete points from any previous name before setting the new name.
	DeleteAllPathPointsFromDatabase(iPathIndex);
	
	// Set new name.
	GetArrayArray(g_aPaths, iPathIndex, ePath);
	strcopy(ePath[Path_Name], MAX_PATHPOINT_NAME_LEN, szString);
	SetArrayArray(g_aPaths, iPathIndex, ePath);
	
	DisplayMenu_View(iClient, iPathIndex);
}

public OnPreThinkPost(iClient)
{
	if(g_iEditingPathIndex[iClient] < 0)
	{
		SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
		return;
	}
	
	TryAddOrigin(iClient);
	TryShowClosestBeams(iClient);
}

TryAddOrigin(iClient)
{
	// Return if ground ent is not the world.
	if(GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") != 0)
		return;
	
	// Return if ducking.
	if((GetEntityFlags(iClient) & FL_DUCKING) || (GetClientButtons(iClient) & IN_DUCK))
		return;
	
	// Return if movetype isn't walk.
	if(GetEntityMoveType(iClient) != MOVETYPE_WALK)
		return;
	
	// Get closest point distance from client.
	static Float:fOrigin[3], Float:fVec[3];
	GetClientAbsOrigin(iClient, fOrigin);
	
	static ePath[PPPath], ePoint[PPPoint];
	GetArrayArray(g_aPaths, g_iEditingPathIndex[iClient], ePath);
	
	static iNumPoints, i;
	iNumPoints = GetArraySize(ePath[Path_Points]);
	
	static Float:fClosestDist, Float:fDist;
	fClosestDist = 999999999.0;
	
	for(i=0; i<iNumPoints; i++)
	{
		GetArrayArray(ePath[Path_Points], i, ePoint);
		
		fVec[0] = ePoint[Point_Origin][0];
		fVec[1] = ePoint[Point_Origin][1];
		fVec[2] = ePoint[Point_Origin][2];
		
		fDist = GetVectorDistance(fOrigin, fVec);
		
		if(fDist < fClosestDist)
			fClosestDist = fDist;
	}
	
	// Return if the client's origin is too close to any other point.
	if(fClosestDist < RADIUS_TO_ADD_POINT)
		return;
	
	ePoint[Point_Origin][0] = fOrigin[0];
	ePoint[Point_Origin][1] = fOrigin[1];
	ePoint[Point_Origin][2] = fOrigin[2];
	
	GetClientEyeAngles(iClient, fVec);
	ePoint[Point_Angles][0] = fVec[0];
	ePoint[Point_Angles][1] = fVec[1];
	ePoint[Point_Angles][2] = fVec[2];
	
	PushArrayArray(ePath[Path_Points], ePoint);
	
	DisplayMenu_View(iClient, g_iEditingPathIndex[iClient]);
}

TryShowClosestBeams(iClient)
{
	static Float:fCurTime, Float:fNextUpdate[MAXPLAYERS+1];
	fCurTime = GetEngineTime();
	
	if(fCurTime < fNextUpdate[iClient])
		return;
	
	fNextUpdate[iClient] = fCurTime + DISPLAY_BEAM_DELAY;
	
	// Show points within radius to client.
	static ePath[PPPath], ePoint[PPPoint];
	GetArrayArray(g_aPaths, g_iEditingPathIndex[iClient], ePath);
	
	static iNumPoints, i;
	iNumPoints = GetArraySize(ePath[Path_Points]);
	
	static Float:fOrigin[3], Float:fVec[3];
	GetClientAbsOrigin(iClient, fOrigin);
	
	static Float:fDist;
	for(i=0; i<iNumPoints; i++)
	{
		GetArrayArray(ePath[Path_Points], i, ePoint);
		
		fVec[0] = ePoint[Point_Origin][0];
		fVec[1] = ePoint[Point_Origin][1];
		fVec[2] = ePoint[Point_Origin][2];
		
		fDist = GetVectorDistance(fOrigin, fVec);
		
		if(fDist < RADIUS_TO_SHOW_BEAMS)
		{
			fDist = (RADIUS_TO_SHOW_BEAMS - fDist) / RADIUS_TO_SHOW_BEAMS;
			ShowBeamPoint(iClient, i, RoundFloat(255.0 * fDist));
		}
	}
}

ShowBeamPoint(iClient, iPointIndex, iOpacity)
{
	if(iPointIndex < 0)
		return;
	
	static ePath[PPPath], ePoint[PPPoint];
	GetArrayArray(g_aPaths, g_iEditingPathIndex[iClient], ePath);
	
	static iNumPoints;
	iNumPoints = GetArraySize(ePath[Path_Points]);
	
	if(iPointIndex >= iNumPoints)
		return;
	
	GetArrayArray(ePath[Path_Points], iPointIndex, ePoint);
	
	static Float:fOrigin[3];
	fOrigin[0] = ePoint[Point_Origin][0];
	fOrigin[1] = ePoint[Point_Origin][1];
	fOrigin[2] = ePoint[Point_Origin][2] + 0.1;
	
	static Float:fEndOrigin[3];
	fEndOrigin[0] = fOrigin[0];
	fEndOrigin[1] = fOrigin[1];
	fEndOrigin[2] = fOrigin[2] + 64.0;
	
	static iBeamColor[4];
	iBeamColor[0] = g_iBeamColor[0];
	iBeamColor[1] = g_iBeamColor[1];
	iBeamColor[2] = g_iBeamColor[2];
	iBeamColor[3] = iOpacity;
	
	TE_SetupBeamPoints(fOrigin, fEndOrigin, g_iBeamIndex, 0, 1, 1, DISPLAY_BEAM_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 1.0, iBeamColor, 5);
	TE_SendToClient(iClient);
}