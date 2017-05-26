#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseServers/database_servers"
#include "../DatabaseUsers/database_users"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database Users";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the users in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iUserID[MAXPLAYERS+1];

new Handle:g_hFwd_OnUserIDReady;
new Handle:g_hFwd_OnNewUserID;

const SECURITY_TOKEN_STRING_LEN = 16;
const SECURITY_TOKEN_LIFE_TIME = 7200; // 2 hours
new const String:SECURITY_CHARACTERS[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
new Handle:g_hSecurityTokenUsers;

enum _:SecurityTokenUser
{
	TokenUserID,
	Float:TokenTimeSet,
	String:TokenString[SECURITY_TOKEN_STRING_LEN+1],
	Handle:TokenReadyForward
};


public OnPluginStart()
{
	CreateConVar("api_database_users_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnUserIDReady = CreateGlobalForward("DBUsers_OnUserIDReady", ET_Ignore, Param_Cell, Param_Cell);
	g_hFwd_OnNewUserID = CreateGlobalForward("DBUsers_OnNewUserID", ET_Ignore, Param_Cell, Param_Cell);
	
	g_hSecurityTokenUsers = CreateArray(SecurityTokenUser);
}

public OnMapStart()
{
	// Remove expired security tokens.
	new Float:fCurTime = GetEngineTime();
	decl eSecurityTokenUser[SecurityTokenUser];
	
	for(new i=0; i<GetArraySize(g_hSecurityTokenUsers); i++)
	{
		GetArrayArray(g_hSecurityTokenUsers, i, eSecurityTokenUser);
		if((eSecurityTokenUser[TokenTimeSet] + SECURITY_TOKEN_LIFE_TIME) >= fCurTime)
			continue;
		
		if(eSecurityTokenUser[TokenReadyForward] != INVALID_HANDLE)
			CloseHandle(eSecurityTokenUser[TokenReadyForward]);
		
		RemoveFromArray(g_hSecurityTokenUsers, i--);
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_users");
	
	CreateNative("DBUsers_GetUserID", _DBUsers_GetUserID);
	CreateNative("DBUsers_GetFormattedAuthID", _DBUsers_GetFormattedAuthID);
	CreateNative("DBUsers_PrepareSecurityToken", _DBUsers_PrepareSecurityToken);
	return APLRes_Success;
}

public _DBUsers_PrepareSecurityToken(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	if(!IsClientInGame(iClient))
		return false;
	
	if(g_iUserID[iClient] < 1)
		return false;
	
	new Function:ready_callback = GetNativeCell(2);
	if(ready_callback == INVALID_FUNCTION)
		return false;
	
	// Give the user a token if they don't have one yet.
	new iIndex = FindValueInArray(g_hSecurityTokenUsers, g_iUserID[iClient]);
	if(iIndex == -1)
	{
		UpdateSecurityToken(iClient, hPlugin, ready_callback);
		return true;
	}
	
	// Give the user a new token if theirs has expired.
	decl eSecurityTokenUser[SecurityTokenUser];
	GetArrayArray(g_hSecurityTokenUsers, iIndex, eSecurityTokenUser);
	if((eSecurityTokenUser[TokenTimeSet] + SECURITY_TOKEN_LIFE_TIME) < GetEngineTime())
	{
		if(eSecurityTokenUser[TokenReadyForward] != INVALID_HANDLE)
			CloseHandle(eSecurityTokenUser[TokenReadyForward]);
		
		RemoveFromArray(g_hSecurityTokenUsers, iIndex);
		UpdateSecurityToken(iClient, hPlugin, ready_callback);
		return true;
	}
	
	// Clients token hasn't expired. Call the ready forward.
	CloseHandle(eSecurityTokenUser[TokenReadyForward]);
	eSecurityTokenUser[TokenReadyForward] = CreateForward(ET_Ignore, Param_Cell, Param_String);
	AddToForward(eSecurityTokenUser[TokenReadyForward], hPlugin, ready_callback);
	SetArrayArray(g_hSecurityTokenUsers, iIndex, eSecurityTokenUser);
	
	if(CallSecurityTokenReadyForward(iClient))
		return false;
	
	return true;
}

UpdateSecurityToken(iClient, Handle:hPlugin, Function:ready_callback)
{
	decl eSecurityTokenUser[SecurityTokenUser];
	eSecurityTokenUser[TokenUserID] = g_iUserID[iClient];
	eSecurityTokenUser[TokenTimeSet] = GetEngineTime();
	
	eSecurityTokenUser[TokenReadyForward] = CreateForward(ET_Ignore, Param_Cell, Param_String);
	AddToForward(eSecurityTokenUser[TokenReadyForward], hPlugin, ready_callback);
	
	decl String:szSecurityToken[SECURITY_TOKEN_STRING_LEN+1];
	CreateSecurityTokenString(szSecurityToken);
	strcopy(eSecurityTokenUser[TokenString], sizeof(szSecurityToken), szSecurityToken);
	
	PushArrayArray(g_hSecurityTokenUsers, eSecurityTokenUser);
	
	DB_TQuery(g_szDatabaseConfigName, Query_UpdateSecurityToken, DBPrio_Normal, GetClientSerial(iClient), "UPDATE core_users SET security_token='%s' WHERE user_id=%i", szSecurityToken, g_iUserID[iClient]);
}

public Query_UpdateSecurityToken(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	CallSecurityTokenReadyForward(iClient);
}

CreateSecurityTokenString(String:szSecurityToken[SECURITY_TOKEN_STRING_LEN+1])
{
	for(new i=0; i<SECURITY_TOKEN_STRING_LEN; i++)
		szSecurityToken[i] = SECURITY_CHARACTERS[GetRandomInt(0, sizeof(SECURITY_CHARACTERS)-2)];
	
	szSecurityToken[SECURITY_TOKEN_STRING_LEN] = '\x0';
}

bool:CallSecurityTokenReadyForward(iClient)
{
	if(g_iUserID[iClient] < 1)
		return false;
	
	new iIndex = FindValueInArray(g_hSecurityTokenUsers, g_iUserID[iClient]);
	if(iIndex < 0)
		return false;
	
	decl eSecurityTokenUser[SecurityTokenUser];
	GetArrayArray(g_hSecurityTokenUsers, iIndex, eSecurityTokenUser);
	
	Call_StartForward(eSecurityTokenUser[TokenReadyForward]);
	Call_PushCell(iClient);
	Call_PushStringEx(eSecurityTokenUser[TokenString], SECURITY_TOKEN_STRING_LEN+1, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, 0);
	Call_Finish();
	
	return true;
}

public _DBUsers_GetUserID(Handle:hPlugin, iNumParams)
{
	return g_iUserID[GetNativeCell(1)];
}

public _DBUsers_GetFormattedAuthID(Handle:hPlugin, iNumParams)
{
	new iMaxLen = GetNativeCell(3);
	if(iMaxLen < 9)
	{
		SetNativeString(2, "", iMaxLen);
		return false;
	}
	
	decl String:szAuthID[iMaxLen];
	if(!GetClientAuthString(GetNativeCell(1), szAuthID, iMaxLen))
	{
		SetNativeString(2, "", iMaxLen);
		return false;
	}
	
	// Strip the "STEAM_X:" from the auth id. Example output: 1:54217.
	SetNativeString(2, szAuthID[8], iMaxLen);
	return true;
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
	Query_CreateCoreUsersTable();
}

bool:Query_CreateCoreUsersTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS core_users\
	(\
		user_id			INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		steam_id		VARCHAR( 16 )		NOT NULL,\
		first_utime		INT					NOT NULL,\
		last_utime		INT					NOT NULL,\
		security_token	VARCHAR( 16 )		NOT NULL,\
		PRIMARY KEY ( user_id ),\
		UNIQUE ( steam_id ),\
		INDEX ( first_utime )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the core_users sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnClientPostAdminCheck(iClient)
{
	InitUser(iClient);
}

public OnClientDisconnect(iClient)
{
	UpdateTimeLastUsedSteamID(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	g_iUserID[iClient] = 0;
}

InitUser(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	decl String:szAuthID[33];
	DBUsers_GetFormattedAuthID(iClient, szAuthID, sizeof(szAuthID));
	if(!DB_EscapeString(g_szDatabaseConfigName, szAuthID, szAuthID, sizeof(szAuthID)))
		return;
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetUserID, DBPrio_High, GetClientSerial(iClient), "SELECT user_id FROM core_users WHERE steam_id='%s' LIMIT 1", szAuthID);
}

public Query_GetUserID(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(SQL_FetchRow(hQuery))
	{
		g_iUserID[iClient] = SQL_FetchInt(hQuery, 0);
		UpdateTimeLastUsedSteamID(iClient);
		_DBUsers_OnUserIDReady(iClient);
		return;
	}
	
	// This client needs a user_id. Try to create one.
	decl String:szAuthID[33];
	DBUsers_GetFormattedAuthID(iClient, szAuthID, sizeof(szAuthID));
	if(!DB_EscapeString(g_szDatabaseConfigName, szAuthID, szAuthID, sizeof(szAuthID)))
		return;
	
	DB_TQuery(g_szDatabaseConfigName, Query_InsertUser, DBPrio_High, iClientSerial, "INSERT INTO core_users (steam_id, first_utime, last_utime) VALUES ('%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP())", szAuthID);
}

_DBUsers_OnUserIDReady(iClient)
{
	if(!g_iUserID[iClient])
		return;
	
	Call_StartForward(g_hFwd_OnUserIDReady);
	Call_PushCell(iClient);
	Call_PushCell(g_iUserID[iClient]);
	Call_Finish();
}

UpdateTimeLastUsedSteamID(iClient)
{
	if(!g_iUserID[iClient])
		return;
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "UPDATE core_users SET last_utime=UNIX_TIMESTAMP() WHERE user_id=%i", g_iUserID[iClient]);
}

public Query_InsertUser(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iUserID = SQL_GetInsertId(hQuery);
	if(!iUserID)
		return;
	
	// Call the new user_id forward.
	Call_StartForward(g_hFwd_OnNewUserID);
	Call_PushCell(iUserID);
	Call_PushCell(iClientSerial);
	Call_Finish();
	
	// Call the user_id ready forward if the client is still valid.
	new iClient = GetClientFromSerial(iClientSerial);
	if(iClient != 0)
	{
		g_iUserID[iClient] = iUserID;
		_DBUsers_OnUserIDReady(iClient);
	}
}