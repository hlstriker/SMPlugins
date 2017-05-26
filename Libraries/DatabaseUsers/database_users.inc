#if defined _database_users_included
 #endinput
#endif
#define _database_users_included


public SharedPlugin:__pl_database_users = 
{
	name = "database_users",
	file = "API_DatabaseUsers.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


/**
 * The callback for a ready security token.
 *
 * @param client		Client index.
 * @noreturn
 */
functag public SecurityTokenReadyCallback(client, const String:security_token[]);


native DBUsers_GetUserID(client);
native bool:DBUsers_GetFormattedAuthID(client, String:auth_id[], maxlen);
native bool:DBUsers_PrepareSecurityToken(client, SecurityTokenReadyCallback:ready_callback);

forward DBUsers_OnUserIDReady(client, user_id);
forward DBUsers_OnNewUserID(user_id, client_serial);
