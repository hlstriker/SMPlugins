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


#define HIDE_DISABLED	-1	// Disable hide
#define HIDE_DEFAULT	0	// Use default visibility.
#define HIDE_ALL		1	// Hide all players.
#define HIDE_TEAM_ONLY	2	// Hide player's teammates only.


native bool:HidePlayers_IsClientHidingTarget(client, target_client);
native bool:HidePlayers_SetClientHideOverride(client, hide_override=HIDE_DEFAULT);
