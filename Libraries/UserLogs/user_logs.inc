#if defined _user_logs_included
 #endinput
#endif
#define _user_logs_included


public SharedPlugin:__pl_user_logs = 
{
	name = "user_logs",
	file = "API_UserLogs.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


// WARNING: Never change the value of these defines!
#define USER_LOG_TYPE_PURCHASED_ITEM			1	// Purchased item from in-game store.
#define USER_LOG_TYPE_GIVEN_ITEM_IDLE			2	// Given an item from the idle server.
#define USER_LOG_TYPE_GIVEN_ITEM_DONATOR		3	// Given an item from the donator status random drop.
#define USER_LOG_TYPE_GIVEN_ITEM_DONATOR_RENEW	4	// Given an item from the donator status renewal.
#define USER_LOG_TYPE_ADMIN_DEMOTED				5	// An admin got demoted.
#define USER_LOG_TYPE_DONATION_RECEIVED			6	// A user donated.
#define USER_LOG_TYPE_ZONEMANAGER				7   // An admin used zonemanager.
#define USER_LOG_TYPE_ENTITYHOOKER				8   // An admin used entity hooker.

native bool:UserLogs_AddLog(user_id, log_type, Handle:transaction=INVALID_HANDLE, data1=0, data2=0, data3=0, data4=0);
