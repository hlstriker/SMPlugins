#if defined _hide_players_included
 #endinput
#endif
#define _hide_players_included


public SharedPlugin:__pl_hide_players = 
{
	name = "hide_players",
	file = "HidePlayers.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native bool:HidePlayers_IsClientHidingTarget(client, target_client);
