#if defined _database_servers_included
 #endinput
#endif
#define _database_servers_included


public SharedPlugin:__pl_database_servers = 
{
	name = "database_servers",
	file = "API_DatabaseServers.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


native DBServers_GetGameID();
native DBServers_GetServerID();
native DBServers_GetServerParentID(); /* If a parent_id doesn't exist it will return the server_id */


forward DBServers_OnServerIDReady(server_id, game_id);
