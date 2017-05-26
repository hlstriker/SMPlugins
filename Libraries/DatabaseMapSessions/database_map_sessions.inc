#if defined _database_map_sessions_included
 #endinput
#endif
#define _database_map_sessions_included


public SharedPlugin:__pl_database_map_sessions = 
{
	name = "database_map_sessions",
	file = "API_DatabaseMapSessions.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native DBMapSessions_GetSessionID();
