#if defined _force_map_end_included
 #endinput
#endif
#define _force_map_end_included


public SharedPlugin:__pl_force_map_end = 
{
	name = "force_map_end",
	file = "ForceMapEnd.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Sets the current round to be the last round.
 *
 * @noreturn
 */
native ForceMapEnd_SetCurrentRoundAsLast();

/**
 * Forces the map to change in X seconds.
 * WARNING: This will round up (ceil) to the nearest mp_timelimit minute since mp_timelimit doesn't support floats.
 *
 * @param seconds		The number of seconds to change the map in.
 * @return				True on success, false otherwise.
 */
native ForceMapEnd_ForceChangeInSeconds(seconds);



#if !defined REQUIRE_PLUGIN
public __pl_force_map_end_SetNTVOptional()
{
	MarkNativeAsOptional("ForceMapEnd_SetCurrentRoundAsLast");
	MarkNativeAsOptional("ForceMapEnd_ForceChangeInSeconds");
}
#endif