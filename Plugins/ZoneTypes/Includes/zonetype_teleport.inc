#if defined _zonetype_teleport_included
 #endinput
#endif
#define _zonetype_teleport_included


public SharedPlugin:__pl_zonetype_teleport = 
{
	name = "zonetype_teleport",
	file = "ZoneType_Teleport.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native bool:ZoneTypeTeleport_TryToTeleport(zone_id, client);
