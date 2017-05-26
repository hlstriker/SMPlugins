#if defined _database_user_stats_included
 #endinput
#endif
#define _database_user_stats_included


public SharedPlugin:__pl_database_user_stats = 
{
	name = "database_user_stats",
	file = "API_DatabaseUserStats.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define STATS_NOT_RANKED 0
#define STATS_SECONDS_BEFORE_AFK 60


forward DBUserStats_OnServerStatsReady(client, server_rank, seconds_played, seconds_afk);
forward DBUserStats_OnGlobalStatsReady(client, global_rank, seconds_played, seconds_afk);
forward DBUserStats_OnServerStatsFailed(client);
forward DBUserStats_OnGlobalStatsFailed(client);


native bool:DBUserStats_HasServerStatsLoaded(client);
native bool:DBUserStats_HasServerStats(client);
native DBUserStats_GetServerRank(client);
native DBUserStats_GetServerTimePlayed(client);
native DBUserStats_GetServerTimeAFK(client);

native bool:DBUserStats_HasGlobalStatsLoaded(client);
native bool:DBUserStats_HasGlobalStats(client);
native DBUserStats_GetGlobalRank(client);
native DBUserStats_GetGlobalTimePlayed(client);
native DBUserStats_GetGlobalTimeAFK(client);



#if !defined REQUIRE_PLUGIN
public __pl_database_user_stats_SetNTVOptional()
{
	MarkNativeAsOptional("DBUserStats_HasServerStatsLoaded");
	MarkNativeAsOptional("DBUserStats_HasServerStats");
	MarkNativeAsOptional("DBUserStats_GetServerRank");
	MarkNativeAsOptional("DBUserStats_GetServerTimePlayed");
	MarkNativeAsOptional("DBUserStats_GetServerTimeAFK");
	
	MarkNativeAsOptional("DBUserStats_HasGlobalStatsLoaded");
	MarkNativeAsOptional("DBUserStats_HasGlobalStats");
	MarkNativeAsOptional("DBUserStats_GetGlobalRank");
	MarkNativeAsOptional("DBUserStats_GetGlobalTimePlayed");
	MarkNativeAsOptional("DBUserStats_GetGlobalTimeAFK");
}
#endif