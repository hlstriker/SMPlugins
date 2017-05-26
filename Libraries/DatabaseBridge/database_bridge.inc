#if defined _database_bridge_included
 #endinput
#endif
#define _database_bridge_included


public SharedPlugin:__pl_database_bridge = 
{
	name = "database_bridge",
	file = "API_DatabaseBridge.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


forward DBBridge_OnBridgeReady();
