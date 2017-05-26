#if defined _ultjb_settings_included
 #endinput
#endif
#define _ultjb_settings_included


public SharedPlugin:__pl_ultjb_settings = 
{
	name = "ultjb_settings",
	file = "UltJB_Settings.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Properly strips a weapon from its owner.
 *
 * @param weapon				The weapon index that should be stripped.
 * @noreturn
 */
native UltJB_Settings_StripWeaponFromOwner(weapon);




/**
 * Called after the client is prepared during OnSpawnPost.
 *
 * @param client			The client who was prepared.
 * @noreturn
 */
forward UltJB_Settings_OnSpawnPost(client);
