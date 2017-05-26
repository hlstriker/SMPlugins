#if defined _database_user_bans_included
 #endinput
#endif
#define _database_user_bans_included


public SharedPlugin:__pl_database_user_bans = 
{
	name = "database_user_bans",
	file = "API_DatabaseUserBans.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


/**
 * Called when a clients ban status is loaded.
 *
 * @param client		Client index.
 * @param is_banned		True if the client is banned, false otherwise.
 * @noreturn
 */
forward Bans_OnStatusLoaded(client, bool:is_banned);

/**
 * Tells if a clients ban status has been loaded yet or not.
 *
 * @param client		Client index.
 * @return				True if status is loaded, false otherwise.
 */
native bool:Bans_IsStatusLoaded(client);
