#if defined _path_points_included
 #endinput
#endif
#define _path_points_included


public SharedPlugin:__pl_path_points = 
{
	name = "path_points",
	file = "API_PathPoints.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define MAX_PATHPOINT_NAME_LEN		32


forward PathPoints_OnPointsLoaded();

