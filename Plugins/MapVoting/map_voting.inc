#if defined _map_voting_included
 #endinput
#endif
#define _map_voting_included


public SharedPlugin:__pl_map_voting = 
{
	name = "map_voting",
	file = "MapVoting.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



#define CHANGETIME_NOT_SET		-1
#define CHANGETIME_INSTANTLY	0
#define CHANGETIME_ROUND_END	1
#define CHANGETIME_MAP_END		2


forward MapVoting_OnCategoriesLoaded();
forward MapVoting_OnMapsLoaded();
forward MapVoting_OnVoteRocked(change_time_type);



native bool:MapVoting_GetMapList(Handle:aList, bool:formatNames=false);

/* Returns the new category ID or -1 on failure */
native MapVoting_AddCategory(const String:cat_name[], const String:cat_tag[]="", played_min=0, played_max=0);

/* Make sure to call MapVoting_RemoveUnusedCategories() after you're done removing maps. */
native bool:MapVoting_RemoveMap(const String:map_name[]);

/* Make sure to call MapVoting_RemoveUnusedCategories() after you're done switching maps. */
native bool:MapVoting_SwitchMapsCategory(const String:map_name[], new_category_id);

native MapVoting_RemoveUnusedCategories();
