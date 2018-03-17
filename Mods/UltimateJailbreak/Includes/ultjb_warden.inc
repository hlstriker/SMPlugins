#if defined _ultjb_warden_included
 #endinput
#endif
#define _ultjb_warden_included


public SharedPlugin:__pl_ultjb_warden = 
{
	name = "ultjb_warden",
	file = "UltJB_Warden.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Gets the client who is the warden.
 *
 * @return				The wardens client index. 0 if there is no warden.
 */
native UltJB_Warden_GetWarden();

/**
 * Gets the number of times this client has been a warden.
 *
 * @param client		The client to check.
 * @return				The number of times this client has been selected as warden.
 */
native UltJB_Warden_GetClientWardenCount(client);



/**
 * Called when a warden is selected.
 *
 * @param client		The client that was selected as warden.
 * @noreturn
 */
forward UltJB_Warden_OnSelected(client);

/**
 * Called when a warden is removed.
 *
 * @param client		The client that was removed from warden.
 * @noreturn
 */
forward UltJB_Warden_OnRemoved(client);

/**
 * Called when a warden dies.
 *
 * @param client		The client that was warden that died.
 * @noreturn
 */
forward UltJB_Warden_OnDeath(client);


#if !defined REQUIRE_PLUGIN
public __pl_ultjb_warden_SetNTVOptional()
{
	MarkNativeAsOptional("UltJB_Warden_GetWarden");
	MarkNativeAsOptional("UltJB_Warden_GetClientWardenCount");
}
#endif
