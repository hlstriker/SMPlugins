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



/**
 * Tries to teleport the client to the specified zone_id.
 *
 * @param zone_id		The zone ID to teleport to.
 * @param client		The client to teleport.
 * @return				True on success, false otherwise.
 */
native bool:ZoneTypeTeleport_TryToTeleport(zone_id, client);
