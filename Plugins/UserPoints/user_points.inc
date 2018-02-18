#if defined _user_points_included
 #endinput
#endif
#define _user_points_included


public SharedPlugin:__pl_user_points = 
{
	name = "user_points",
	file = "UserPoints.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


native bool:UserPoints_AddToVisualOffset(client, amount);


#if !defined REQUIRE_PLUGIN
public __pl_user_points_SetNTVOptional()
{
	MarkNativeAsOptional("UserPoints_AddToVisualOffset");
}
#endif