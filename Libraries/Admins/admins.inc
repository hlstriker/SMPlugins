#if defined _admins_included
 #endinput
#endif
#define _admins_included


public SharedPlugin:__pl_admins =
{
	name = "admins",
	file = "API_Admins.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



enum AdminLevel
{
	AdminLevel_NotLoaded = -1,
	AdminLevel_None,
	AdminLevel_Junior,
	AdminLevel_Senior,
	AdminLevel_Reputable,
	AdminLevel_Lead
};



/**
 * Called when a clients admin status is loaded.
 *
 * @param client	Client index.
 * @param level		The client's admins level.
 * @noreturn
 */
forward Admins_OnLoaded(client, AdminLevel:level);



/**
 * Returns the client's admin level.
 *
 * @param client	Client index.
 * @return			The client's admins level.
 */
native AdminLevel:Admins_GetLevel(client);



#if !defined REQUIRE_PLUGIN
public __pl_admins_SetNTVOptional()
{
	MarkNativeAsOptional("Admins_GetLevel");
}
#endif