#if defined _database_user_sessions_included
 #endinput
#endif
#define _database_user_sessions_included


public SharedPlugin:__pl_database_user_sessions = 
{
	name = "database_user_sessions",
	file = "API_DatabaseUserSessions.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


forward DBUserSessions_OnSessionReady(client, user_session_id);


native DBUserSessions_GetSessionID(client);
