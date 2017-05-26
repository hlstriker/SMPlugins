#if defined _player_chat_included
 #endinput
#endif
#define _player_chat_included


public SharedPlugin:__pl_player_chat =
{
	name = "player_chat",
	file = "API_PlayerChat.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


enum ChatType
{
	CHAT_TYPE_ALL = 1,
	CHAT_TYPE_TEAM
};



/**
 * Called before a players message is sent.
 *
 * @param client		Client index.
 * @param chat_type		The chat type.
 * @param message		The chat message.
 * @noreturn
 */
forward Action:PlayerChat_OnMessage(client, ChatType:chat_type, const String:message[]);



/**
 * Sets a custom title for the client that will show up when they chat.
 *
 * @param client		Client index.
 * @param title			The custom title to set.
 * @noreturn
 */
native PlayerChat_SetCustomTitle(client, const String:title[]);

/**
 * Clear the clients custom title.
 *
 * @param client		Client index.
 * @noreturn
 */
native PlayerChat_ClearCustomTitle(client);



#if !defined REQUIRE_PLUGIN
public __pl_player_chat_SetNTVOptional()
{
	MarkNativeAsOptional("PlayerChat_SetCustomTitle");
	MarkNativeAsOptional("PlayerChat_ClearCustomTitle");
}
#endif