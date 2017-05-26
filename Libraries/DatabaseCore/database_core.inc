#if defined _database_core_included
 #endinput
#endif
#define _database_core_included


public SharedPlugin:__pl_database_core = 
{
	name = "database_core",
	file = "API_DatabaseCore.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * The callback structure for when a connection is ready for use.
 *
 * @noparam
 * @noreturn
 */
functag public DB_Callback_ConnectionReady();

/**
 * The callback structure for a threaded query.
 * You should NOT close the "database" and/or "query" parameter handles.
 *
 * @param query			Handle to the query object.
 * @param data			Data passed in via the original threaded invocation.
 * @noreturn
 */
functag public DB_Callback_TQuery(Handle:database, Handle:query, any:data);



native DB_GetInsertId(const String:connection_name[]);
native bool:DB_EscapeString(const String:connection_name[], const String:source[], String:buffer[], maxlength, &written=0);

native Handle:DB_Query(const String:connection_name[], const String:query[], any:...); // You MUST close the non-threaded query handle.
native bool:DB_CloseQueryHandle(Handle:query_handle);

native bool:DB_TQuery(const String:connection_name[], DB_Callback_TQuery:tquery_callback=INVALID_FUNCTION, DBPriority:prio=DBPrio_Normal, any:data=0, const String:query[], any:...);

native bool:DB_SetupConnection(const String:connection_name[], DB_Callback_ConnectionReady:ready_callback); // This should only be called inside DB_OnStartConnectionSetup().

/*
* This was really only implemented so we could easily use transaction without wrapping it into this API.
* Don't use it for anything but transactions.
*/
native Handle:DB_GetDatabaseHandleFromConnectionName(const String:connection_name[]);


/**
 * Called when it's safe to start setting up connections.
 *
 * @noparam
 * @noreturn
 */
forward DB_OnStartConnectionSetup();
