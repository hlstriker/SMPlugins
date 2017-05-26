#if defined _ultjb_wardenmenu_included
 #endinput
#endif
#define _ultjb_wardenmenu_included


public SharedPlugin:__pl_ultjb_wardenmenu = 
{
	name = "ultjb_wardenmenu",
	file = "UltJB_WardenMenu.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native UltJB_WardenMenu_CreateRing(client, ring_index, const Float:position[3], Float:ring_radius);



#if !defined REQUIRE_PLUGIN
public __pl_ultjb_wardenmenu_SetNTVOptional()
{
	MarkNativeAsOptional("UltJB_WardenMenu_CreateRing");
}
#endif