#if defined _client_times_included
 #endinput
#endif
#define _client_times_included


public SharedPlugin:__pl_client_times = 
{
	name = "client_times",
	file = "API_ClientTimes.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * The callback for on away/back
 *
 * @param client		Client index.
 * @noreturn
 */
functag public AwayBackCallback(client);



/**
 * Sets the time until a client is marked as away for the calling plugin.
 * This must be called in OnAllPluginsLoaded().
 *
 * @param seconds		The number of seconds that pass before a client is marked as away.
 * @return				True on success, false otherwise.
 */
native bool:ClientTimes_SetTimeBeforeMarkedAsAway(seconds, AwayBackCallback:away_callback=INVALID_FUNCTION, AwayBackCallback:back_callback=INVALID_FUNCTION);

/**
 * Returns the total time the client has been in the server.
 *
 * @param client		Client index.
 * @return				Number of seconds in server.
 */
native ClientTimes_GetTimeInServer(client);

/**
 * Returns the time the client has played since joining the server.
 * This only returns the time if the plugin first registers to receive the call via ClientTimes_SetTimeBeforeMarkedAsAway().
 *
 * @param client		Client index.
 * @return				Number of seconds played.
 */
native ClientTimes_GetTimePlayed(client);

/**
 * Returns the time the client has been AFK since joining the server.
 * This only returns the time if the plugin first registers to receive the call via ClientTimes_SetTimeBeforeMarkedAsAway().
 *
 * @param client		Client index.
 * @return				Number of seconds away.
 */
native ClientTimes_GetTimeAway(client);

/**
 * Returns the time the client has used a specific clan tag since joining the server.
 *
 * @param client		Client index.
 * @param clan_tag		Clan tag to get time from.
 * @return				Number of seconds clan tag has been worn.
 */
native ClientTimes_GetClanTagTime(client, const String:clan_tag[]);

/**
 * Called when a clients clan tag time updates.
 *
 * @param client		Client index.
 * @param clan_tag		Clan tag that updated.
 * @param time_used		The time this clan tag was used for.
 * @noreturn
 */
forward ClientTimes_OnClanTagTimeUpdated(client, const String:clan_tag[], const Float:time_used);



#if !defined REQUIRE_PLUGIN
public __pl_client_times_SetNTVOptional()
{
	MarkNativeAsOptional("ClientTimes_SetTimeBeforeMarkedAsAway");
	MarkNativeAsOptional("ClientTimes_GetTimeInServer");
	MarkNativeAsOptional("ClientTimes_GetTimePlayed");
	MarkNativeAsOptional("ClientTimes_GetTimeAway");
	MarkNativeAsOptional("ClientTimes_GetClanTagTime");
}
#endif