#if defined _donatoritem_colored_chat_included
 #endinput
#endif
#define _donatoritem_colored_chat_included


public SharedPlugin:__pl_donatoritem_colored_chat = 
{
	name = "donatoritem_colored_chat",
	file = "DonatorItem_ColoredChat.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native DItemColoredChat_GetColorByte(client);



#if !defined REQUIRE_PLUGIN
public __pl_donatoritem_colored_chat_SetNTVOptional()
{
	MarkNativeAsOptional("DItemColoredChat_GetColorByte");
}
#endif