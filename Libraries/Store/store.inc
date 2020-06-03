#if defined _store_included
 #endinput
#endif
#define _store_included


public SharedPlugin:__pl_store = 
{
	name = "store",
	file = "API_Store.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define MAX_STORE_ITEM_NAME_LEN		33
#define MAX_STORE_DATA_STRING_LEN	43

#define STOREITEM_TYPE_EQUIPMENT_HEAD			1
#define STOREITEM_TYPE_EQUIPMENT_FACE			2
#define STOREITEM_TYPE_EQUIPMENT_TORSO			3
#define STOREITEM_TYPE_PAINTBALL				4
#define STOREITEM_TYPE_KILL_SOUND				5
#define STOREITEM_TYPE_GRENADESOUND_BOUNCE		6
#define STOREITEM_TYPE_GRENADESOUND_EXPLODE		7
#define STOREITEM_TYPE_PLAYER_EFFECT_TRAIL		8
#define STOREITEM_TYPE_BULLET_TRACER			9
#define STOREITEM_TYPE_EQUIPMENT_COLORS			10
#define STOREITEM_TYPE_EQUIPMENT_EFFECTS		11
#define STOREITEM_TYPE_PLAYER_EFFECT_AURA		12
#define STOREITEM_TYPE_PLAYER_EFFECT_SPARKLES	13
#define STOREITEM_TYPE_PLAYER_EFFECT_RINGS		14

// Item flag settings.
#define ITYPE_FLAG_ALL_ENABLED					0
// Whos items do I want to see?
#define ITYPE_FLAG_SELF_DISABLED				(1<<0)	// Don't show my items to myself.
#define ITYPE_FLAG_MY_TEAM_DISABLED				(1<<1)	// Don't show my teams items to myself.
#define ITYPE_FLAG_OTHER_TEAM_DISABLED			(1<<2)	// Don't show the other teams items to myself.
// Who is allowed to see my items?
#define ITYPE_FLAG_MY_ITEM_MY_TEAM_DISABLED		(1<<3)	// Don't show my items to my team.
#define ITYPE_FLAG_MY_ITEM_OTHER_TEAM_DISABLED	(1<<4)	// Don't show my items to the other team.


forward Store_OnItemsReady();


native Store_FindItemByType(start_index, item_type, &found_item_id);
native bool:Store_GetItemsMainFilePath(item_id, String:file_path[], maxlength);
native Store_GetItemsMainFilePrecacheID(item_id);
native bool:Store_GetItemsDataString(item_id, string_num, String:data_string[], maxlength);

native Store_CanClientUseItem(client, item_id);
native Store_GetClientSettings(client, setting_type);


#if !defined REQUIRE_PLUGIN
public __pl_store_SetNTVOptional()
{
	MarkNativeAsOptional("Store_FindItemByType");
	MarkNativeAsOptional("Store_GetItemsMainFilePath");
	MarkNativeAsOptional("Store_GetItemsMainFilePrecacheID");
	MarkNativeAsOptional("Store_GetItemsDataString");
	MarkNativeAsOptional("Store_CanClientUseItem");
	MarkNativeAsOptional("Store_GetClientSettings");
}
#endif