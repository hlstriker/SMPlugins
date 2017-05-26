#include <sourcemod>

#pragma semicolon 1
#pragma dynamic 1050000

new const String:PLUGIN_NAME[] = "API: Database Core";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage core database functions.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_hFwd_OnStartConnectionSetup;

// Global query buffer so it doesn't need to be recreated each query call.
new String:g_szQueryBuffer[1048576];

new Handle:g_hConnections_Threaded;
new Handle:g_hConnections_NonThreaded;

const MAX_CONNECTION_NAME_LENGTH = 64;
new Handle:g_aNewConnectionNames;
new Handle:g_aConnectionNames;

enum _:ConnectionNames
{
	String:ConnectionName[MAX_CONNECTION_NAME_LENGTH+1],
	Handle:ConnectionNameReadyForward
};


public OnPluginStart()
{
	CreateConVar("api_database_core_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hConnections_Threaded = CreateTrie();
	g_hConnections_NonThreaded = CreateTrie();
	g_aConnectionNames = CreateArray(ConnectionNames);
	
	g_hFwd_OnStartConnectionSetup = CreateGlobalForward("DB_OnStartConnectionSetup", ET_Ignore);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_core");
	
	CreateNative("DB_SetupConnection", _DB_SetupConnection);
	
	CreateNative("DB_EscapeString", _DB_EscapeString);
	CreateNative("DB_GetInsertId", _DB_GetInsertId);
	
	CreateNative("DB_Query", _DB_Query);
	CreateNative("DB_CloseQueryHandle", _DB_CloseQueryHandle);
	
	CreateNative("DB_TQuery", _DB_TQuery);
	
	CreateNative("DB_GetDatabaseHandleFromConnectionName", _DB_GetDatabaseHandleFromConnectionName);
	
	return APLRes_Success;
}

public _DB_CloseQueryHandle(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
		return false;
	
	return CloseHandle(GetNativeCell(1));
}

public _DB_GetDatabaseHandleFromConnectionName(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
		return _:INVALID_HANDLE;
	
	// Make sure this connection name has a connection associated with it.
	decl String:szConnectionName[MAX_CONNECTION_NAME_LENGTH+1], Handle:hConnection;
	GetNativeString(1, szConnectionName, sizeof(szConnectionName));
	if(!GetTrieValue(g_hConnections_Threaded, szConnectionName, hConnection))
		return _:INVALID_HANDLE;
	
	return _:hConnection;
}

public _DB_TQuery(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 5)
		return false;
	
	// Make sure this connection name has a connection associated with it.
	decl String:szConnectionName[MAX_CONNECTION_NAME_LENGTH+1], Handle:hConnection;
	GetNativeString(1, szConnectionName, sizeof(szConnectionName));
	if(!GetTrieValue(g_hConnections_Threaded, szConnectionName, hConnection))
		return false;
	
	// Add the query to the buffer.
	FormatNativeString(0, 5, 6, sizeof(g_szQueryBuffer), _, g_szQueryBuffer);
	
	// Get the callback function.
	new Handle:hQueryForward, Function:tquery_callback = GetNativeCell(2);
	if(tquery_callback != INVALID_FUNCTION)
	{
		hQueryForward = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(hQueryForward, hPlugin, tquery_callback);
	}
	
	// Setup the data pack.
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, _:hQueryForward);
	WritePackCell(hPack, GetNativeCell(4));
	
	// Run the query.
	SQL_TQuery(hConnection, ThreadedQuery, g_szQueryBuffer, hPack, GetNativeCell(3));
	
	return true;
}

public ThreadedQuery(Handle:hDatabase, Handle:hQuery, const String:szError[], any:hPack)
{
	ResetPack(hPack, false);
	new any:hQueryForward = ReadPackCell(hPack);
	new any:data = ReadPackCell(hPack);
	CloseHandle(hPack);
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("Threaded: %s", szError);
		ThreadedQueryForward(hQueryForward, hDatabase, hQuery, data);
		return;
	}
	
	ThreadedQueryForward(hQueryForward, hDatabase, hQuery, data);
	CloseHandle(hQuery);
}

ThreadedQueryForward(Handle:hQueryForward, Handle:hDatabase, Handle:hQuery, any:data)
{
	if(hQueryForward == INVALID_HANDLE)
		return;
	
	Call_StartForward(hQueryForward);
	Call_PushCell(hDatabase);
	Call_PushCell(hQuery);
	Call_PushCell(data);
	Call_Finish();
	
	CloseHandle(hQueryForward);
}

public _DB_Query(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 2)
		return _:INVALID_HANDLE;
	
	// Make sure this connection name has a connection associated with it.
	decl String:szConnectionName[MAX_CONNECTION_NAME_LENGTH+1], Handle:hConnection;
	GetNativeString(1, szConnectionName, sizeof(szConnectionName));
	if(!GetTrieValue(g_hConnections_NonThreaded, szConnectionName, hConnection))
		return _:INVALID_HANDLE;
	
	FormatNativeString(0, 2, 3, sizeof(g_szQueryBuffer), _, g_szQueryBuffer);
	return _:DatabaseQuery(hConnection, hPlugin);
}

Handle:DatabaseQuery(Handle:hConnection, Handle:hPlugin)
{
	// NOTE: No longer lock the database. Use a second connection dedicated to non-threaded instead.
	// See thread: https://forums.alliedmods.net/showpost.php?p=1406603&postcount=16
	
	//SQL_LockDatabase(hConnection);
	new Handle:hQuery = SQL_Query(hConnection, g_szQueryBuffer);
	//SQL_UnlockDatabase(hConnection);
	
	if(hQuery == INVALID_HANDLE)
	{
		decl String:szError[256], String:szPlugin[256];
		SQL_GetError(hConnection, szError, sizeof(szError));
		GetPluginFilename(hPlugin, szPlugin, sizeof(szPlugin));
		LogError("Non-Threaded: %s - %s", szPlugin, szError);
		return INVALID_HANDLE;
	}
	
	return hQuery;
}

public _DB_EscapeString(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 4 || iNumParams > 5)
		return false;
	
	decl String:szConnectionName[MAX_CONNECTION_NAME_LENGTH+1], Handle:hConnection;
	GetNativeString(1, szConnectionName, sizeof(szConnectionName));
	if(!GetTrieValue(g_hConnections_NonThreaded, szConnectionName, hConnection))
		return false;
	
	decl iSourceLen, iBufferLen;
	GetNativeStringLength(2, iSourceLen);
	iBufferLen = iSourceLen * 2 + 1;
	iSourceLen++;
	
	decl String:szSource[iSourceLen], String:szBuffer[iBufferLen];
	GetNativeString(2, szSource, iSourceLen);
	
	if(!SQL_EscapeString(hConnection, szSource, szBuffer, GetNativeCell(4), iBufferLen))
		return false;
	
	SetNativeString(3, szBuffer, iBufferLen+1);
	SetNativeCellRef(5, iBufferLen);
	
	return true;
}

public _DB_GetInsertId(Handle:hPlugin, iNumParams)
{
	LogError("DB_GetInsertId is not safe to use! Use SQL_GetInsertId instead.");
	return 0;
	
	/*
	decl String:szConnectionName[MAX_CONNECTION_NAME_LENGTH+1], Handle:hConnection;
	GetNativeString(1, szConnectionName, sizeof(szConnectionName));
	if(!GetTrieValue(g_hConnections, szConnectionName, hConnection))
		return 0;
	
	return SQL_GetInsertId(hConnection);
	*/
}

public _DB_SetupConnection(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
		return false;
	
	if(g_aNewConnectionNames == INVALID_HANDLE)
		return false;
	
	decl String:szConnectionName[MAX_CONNECTION_NAME_LENGTH+1];
	GetNativeString(1, szConnectionName, sizeof(szConnectionName));
	
	if(GetConnectionNameArrayIndex(szConnectionName, true) != -1)
	{
		LogError("Another plugin already owns this connection name. Maybe add support later to share connection names?");
		return false;
	}
	
	decl eConnectionName[ConnectionNames];
	eConnectionName[ConnectionName] = szConnectionName;
	
	new Function:ready_callback = GetNativeCell(2);
	if(ready_callback != INVALID_FUNCTION)
	{
		eConnectionName[ConnectionNameReadyForward] = CreateForward(ET_Ignore);
		AddToForward(eConnectionName[ConnectionNameReadyForward], hPlugin, ready_callback);
	}
	else
	{
		eConnectionName[ConnectionNameReadyForward] = INVALID_HANDLE;
	}
	
	PushArrayArray(g_aNewConnectionNames, eConnectionName);
	return true;
}

public OnConfigsExecuted()
{
	// Create the array to store new connection names.
	g_aNewConnectionNames = CreateArray(ConnectionNames);
	
	// Call the forward to accept DB_SetupConnection() calls.
	Call_StartForward(g_hFwd_OnStartConnectionSetup);
	Call_Finish();
	
	// Close and remove any connections that aren't listed in g_aNewConnectionNames.
	decl eConnectionName[ConnectionNames], Handle:hConnection, i, iIndex;
	for(i=0; i<GetArraySize(g_aConnectionNames); i++)
	{
		GetArrayArray(g_aConnectionNames, i, eConnectionName);
		
		if(GetConnectionNameArrayIndex(eConnectionName[ConnectionName], true) != -1)
			continue;
		
		if(GetTrieValue(g_hConnections_NonThreaded, eConnectionName[ConnectionName], hConnection))
		{
			CloseHandle(hConnection);
			RemoveFromTrie(g_hConnections_NonThreaded, eConnectionName[ConnectionName]);
		}
		
		if(GetTrieValue(g_hConnections_Threaded, eConnectionName[ConnectionName], hConnection))
		{
			CloseHandle(hConnection);
			RemoveFromTrie(g_hConnections_Threaded, eConnectionName[ConnectionName]);
		}
		
		if(eConnectionName[ConnectionNameReadyForward] != INVALID_HANDLE)
			CloseHandle(eConnectionName[ConnectionNameReadyForward]);
		
		RemoveFromArray(g_aConnectionNames, i--);
	}
	
	// Create connections for connection names that aren't connected yet.
	for(i=0; i<GetArraySize(g_aNewConnectionNames); i++)
	{
		GetArrayArray(g_aNewConnectionNames, i, eConnectionName);
		
		iIndex = GetConnectionNameArrayIndex(eConnectionName[ConnectionName]);
		if(iIndex == -1)
		{
			// Add the connection name if it's not in the connection array yet.
			PushArrayArray(g_aConnectionNames, eConnectionName);
		}
		else
		{
			// Since this connection was already in the connection array we need to close the old forward handle and update with the new handle.
			GetArrayArray(g_aConnectionNames, iIndex, eConnectionName);
			if(eConnectionName[ConnectionNameReadyForward] != INVALID_HANDLE)
				CloseHandle(eConnectionName[ConnectionNameReadyForward]);
			
			GetArrayArray(g_aNewConnectionNames, i, eConnectionName);
			SetArrayArray(g_aConnectionNames, iIndex, eConnectionName);
		}
		
		// Add the connection if needed for the threaded trie.
		if(!GetTrieValue(g_hConnections_Threaded, eConnectionName[ConnectionName], hConnection))
		{
			hConnection = CreateConnectionForName(eConnectionName[ConnectionName]);
			if(hConnection != INVALID_HANDLE)
			{
				if(!SetTrieValue(g_hConnections_Threaded, eConnectionName[ConnectionName], hConnection, false))
				{
					LogError("Something went wrong. The key \"%s\" is somehow already set in the threaded trie.", eConnectionName[ConnectionName]);
					CloseHandle(hConnection);
				}
			}
		}
		
		// Add the connection if needed for the non-threaded trie.
		if(!GetTrieValue(g_hConnections_NonThreaded, eConnectionName[ConnectionName], hConnection))
		{
			hConnection = CreateConnectionForName(eConnectionName[ConnectionName]);
			if(hConnection != INVALID_HANDLE)
			{
				if(!SetTrieValue(g_hConnections_NonThreaded, eConnectionName[ConnectionName], hConnection, false))
				{
					LogError("Something went wrong. The key \"%s\" is somehow already set in the non-threaded trie.", eConnectionName[ConnectionName]);
					CloseHandle(hConnection);
				}
			}
		}
	}
	
	// Close the array that stored the new connection names.
	CloseHandle(g_aNewConnectionNames);
	g_aNewConnectionNames = INVALID_HANDLE;
	
	// Notify plugins the connected names are ready.
	for(i=0; i<GetArraySize(g_aConnectionNames); i++)
	{
		GetArrayArray(g_aConnectionNames, i, eConnectionName);
		
		if(!GetTrieValue(g_hConnections_Threaded, eConnectionName[ConnectionName], hConnection))
			continue;
		
		if(!GetTrieValue(g_hConnections_NonThreaded, eConnectionName[ConnectionName], hConnection))
			continue;
		
		if(eConnectionName[ConnectionNameReadyForward] == INVALID_HANDLE)
			continue;
		
		Call_StartForward(eConnectionName[ConnectionNameReadyForward]);
		Call_Finish();
	}
}

GetConnectionNameArrayIndex(const String:szConnectionName[], bool:bCheckNewConnections=false)
{
	new Handle:hArrayToUse;
	if(bCheckNewConnections)
		hArrayToUse = g_aNewConnectionNames;
	else
		hArrayToUse = g_aConnectionNames;
	
	decl eConnectionName[ConnectionNames];
	for(new i=0; i<GetArraySize(hArrayToUse); i++)
	{
		GetArrayArray(hArrayToUse, i, eConnectionName);
		if(StrEqual(eConnectionName[ConnectionName], szConnectionName))
			return i;
	}
	
	return -1;
}

Handle:CreateConnectionForName(const String:szConnectionName[])
{
	decl Handle:hConnection, String:szError[256];
	hConnection = SQL_Connect(szConnectionName, false, szError, sizeof(szError));
	
	if(hConnection == INVALID_HANDLE)
	{
		LogError("Error connecting with config \"%s\". %s.", szConnectionName, szError);
		return INVALID_HANDLE;
	}
	
	return hConnection;
}