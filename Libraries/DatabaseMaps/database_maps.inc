#if defined _database_maps_included
 #endinput
#endif
#define _database_maps_included


public SharedPlugin:__pl_database_maps = 
{
	name = "database_maps",
	file = "API_DatabaseMaps.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



functag public Callback_OnSelectedMapIDFromName(map_id, any:data);



/* Gets the map id for the current loaded map */
native DBMaps_GetMapID();

/* Gets the map id for a specific map name */
native bool:DBMaps_GetMapIDFromName(const String:map_name[], Callback_OnSelectedMapIDFromName:selected_callback, any:data=0);

/* Gets the current map name formatted. Lowercase and workshop/id/ stripped. */
native bool:DBMaps_GetCurrentMapNameFormatted(String:map_name[], maxlength);

/* Formats a map name. Lowercase and workshop/id/ stripped. */
native bool:DBMaps_GetMapNameFormatted(String:map_name[], maxlength);


forward DBMaps_OnMapIDReady(map_id);
