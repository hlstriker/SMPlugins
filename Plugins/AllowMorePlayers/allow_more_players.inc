#if defined _allow_more_players_included
 #endinput
#endif
#define _allow_more_players_included


public SharedPlugin:__pl_allow_more_players = 
{
	name = "allow_more_players",
	file = "AllowMorePlayers.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native AllowMorePlayers_GetCreatedSpawnCount();
native AllowMorePlayers_GetCreatedSpawnTeam();
native bool:AllowMorePlayers_GetCreatedSpawnData(spawn_index, Float:origin[3], Float:angles[3]);



#if !defined REQUIRE_PLUGIN
public __pl_allow_more_players_SetNTVOptional()
{
	MarkNativeAsOptional("AllowMorePlayers_GetCreatedSpawnCount");
	MarkNativeAsOptional("AllowMorePlayers_GetCreatedSpawnTeam");
	MarkNativeAsOptional("AllowMorePlayers_GetCreatedSpawnData");
}
#endif