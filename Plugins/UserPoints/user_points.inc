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


native bool:UserPoints_GivePoints(client, amount);
native UserPoints_AddToVisualOffset(client, amount);
native UserPoints_GetPoints(client, bool:get_with_visual_offset=false);
native UserPoints_DisableRoundEndPointsForThisRound();
native UserPoints_DisableClientKillPointsForThisRound(client);


#if !defined REQUIRE_PLUGIN
public __pl_user_points_SetNTVOptional()
{
	MarkNativeAsOptional("UserPoints_GivePoints");
	MarkNativeAsOptional("UserPoints_AddToVisualOffset");
	MarkNativeAsOptional("UserPoints_GetPoints");
	MarkNativeAsOptional("UserPoints_DisableRoundEndPointsForThisRound");
	MarkNativeAsOptional("UserPoints_DisableClientKillPointsForThisRound");
}
#endif