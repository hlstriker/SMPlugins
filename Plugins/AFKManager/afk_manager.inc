#if defined _afk_manager_included
 #endinput
#endif
#define _afk_manager_included


public SharedPlugin:__pl_afk_manager = 
{
	name = "afk_manager",
	file = "AFKManager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



forward AFKManager_OnAway(client);
forward AFKManager_OnBack(client);



native AFKManager_IsAway(client);



#if !defined REQUIRE_PLUGIN
public __pl_afk_manager_SetNTVOptional()
{
	MarkNativeAsOptional("AFKManager_IsAway");
}
#endif