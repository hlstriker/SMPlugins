#if defined _ultjb_last_guard_included
 #endinput
#endif
#define _ultjb_last_guard_included


public SharedPlugin:__pl_ultjb_last_guard = 
{
	name = "ultjb_last_guard",
	file = "UltJB_LastGuard.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Gets the client who is the last guard.
 *
 * @return				The last guards client index. 0 if there is no last guard.
 */
native bool:UltJB_LastGuard_GetLastGuard();

/**
 * Gets the number of guards needed on the team before last guard can activate.
 *
 * @return				The number of guards needed.
 */
native UltJB_LastGuard_GetNumNeeded();

/**
 * Resets the damage timers for the Last Guard.
 *
 * @return				Always true.
 */
native bool:UltJB_LastGuard_ResetDamageCounters()

/**
 * Called before the last guard is activated.
 *
 * @param client		The client that was set as last guard.
 * @noreturn
 */
forward UltJB_LastGuard_OnActivated_Pre(client);


/**
 * Called after the last guard is activated.
 *
 * @param client		The client that was set as last guard.
 * @noreturn
 */
forward UltJB_LastGuard_OnActivated_Post(client);
