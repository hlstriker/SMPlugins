#if defined _database_map_stats_included
 #endinput
#endif
#define _database_map_stats_included


public SharedPlugin:__pl_database_map_stats = 
{
	name = "database_map_stats",
	file = "API_DatabaseMapStats.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



forward DBMapStats_OnStatsReady(total_time_played);
forward DBMapStats_OnStatsFailed();


native DBMapStats_GetTimePlayed();
native DBMapStats_GetTotalTimePlayed();
