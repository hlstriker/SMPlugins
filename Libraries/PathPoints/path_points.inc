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



/**
 * Gets the number of points for a specific path name.
 *
 * @param path_name			The name of the path to get the number of points for.
 * @return					The number of points for this path.
 */
native PathPoints_GetPointCount(const String:path_name[]);

/**
 * Gets the point for a specific path name and point index.
 *
 * @param path_name			The name of the path to get the points for.
 * @param point_index		The point index to get.
 * @return					True on success, false otherwise.
 */
native bool:PathPoints_GetPoint(const String:path_name[], point_index, Float:origin[3], Float:angles[3]);

/**
 * Gets the two points furthest apart from one another.
 *
 * @param path_name			The name of the path to check.
 * @param point_index_1		The first point index.
 * @param point_index_2		The second point index.
 * @return					True on success, false otherwise.
 */
native bool:PathPoints_GetFurthestTwoPoints(const String:path_name[], &point_index_1, &point_index_2);

/**
 * Gets the next furthest point in the path. Must call PathPoints_GetFurthestTwoPoints() first.
 *
 * @param path_name			The name of the path to check.
 * @param point_index		The next furthest point index.
 * @return					True on success, false otherwise.
 */
native bool:PathPoints_GetNextFurthestPoint(const String:path_name[], &point_index);

/**
 * Gets the next random point in the path.
 *
 * @param path_name					The name of the path to check.
 * @param reset_point_check_array	Reset the point check array or not.
 * @param point_index				The point index found.
 * @return							True on success, false otherwise.
 */
native bool:PathPoints_GetNextRandomPoint(const String:path_name[], bool:reset_point_check_array=false, &point_index);



#if !defined REQUIRE_PLUGIN
public __pl_path_points_SetNTVOptional()
{
	MarkNativeAsOptional("PathPoints_GetPointCount");
	MarkNativeAsOptional("PathPoints_GetPoint");
	MarkNativeAsOptional("PathPoints_GetFurthestTwoPoints");
	MarkNativeAsOptional("PathPoints_GetNextFurthestPoint");
	MarkNativeAsOptional("PathPoints_GetNextRandomPoint");
}
#endif
