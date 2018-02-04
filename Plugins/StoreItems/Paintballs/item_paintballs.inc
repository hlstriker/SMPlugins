#if defined _item_paintballs_included
 #endinput
#endif
#define _item_paintballs_included


public SharedPlugin:__pl_item_paintballs = 
{
	name = "item_paintballs",
	file = "Item_Paintballs.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



forward Action:ItemPaintballs_OnShootPaintball(client);
