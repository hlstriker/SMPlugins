#if defined _donatoritem_titles_included
 #endinput
#endif
#define _donatoritem_titles_included


public SharedPlugin:__pl_donatoritem_titles = 
{
	name = "donatoritem_titles",
	file = "DonatorItem_Titles.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define MAX_TITLE_LENGTH	16


native bool:DItemTitles_GetTitle(client, String:title[], maxlength);



#if !defined REQUIRE_PLUGIN
public __pl_donatoritem_titles_SetNTVOptional()
{
	MarkNativeAsOptional("DItemTitles_GetTitle");
}
#endif