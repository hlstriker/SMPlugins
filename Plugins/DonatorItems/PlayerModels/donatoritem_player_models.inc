#if defined _donatoritem_player_models_included
 #endinput
#endif
#define _donatoritem_player_models_included


public SharedPlugin:__pl_donatoritem_player_models = 
{
	name = "donatoritem_player_models",
	file = "DonatorItem_PlayerModels.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



forward DItemPlayerModels_OnModelSet(client);


native bool:DItemPlayerModels_HasUsableModelActivated(client);



#if !defined REQUIRE_PLUGIN
public __pl_donatoritem_player_models_SetNTVOptional()
{
	MarkNativeAsOptional("DItemPlayerModels_HasUsableModelActivated");
}
#endif