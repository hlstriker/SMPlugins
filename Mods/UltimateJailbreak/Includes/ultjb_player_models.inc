#if defined _ultjb_player_models_included
 #endinput
#endif
#define _ultjb_player_models_included


public SharedPlugin:__pl_ultjb_player_models = 
{
	name = "ultjb_player_models",
	file = "UltJB_PlayerModels.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Called after the client spawns and has their prisoner or guard model applied.
 *
 * @param client			The client who has their model applied.
 * @noreturn
 */
forward UltJB_PlayerModels_OnApplied(client);
