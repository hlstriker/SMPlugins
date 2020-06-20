#if defined _zonetype_named_included
 #endinput
#endif
#define _zonetype_named_included


public SharedPlugin:__pl_zonetype_named = 
{
	name = "zonetype_named",
	file = "ZoneType_Named.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



forward ZoneTypeNamed_OnStartTouch(zone_ent, touched_ent);

