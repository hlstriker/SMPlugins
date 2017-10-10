#if defined _map_cookies_included
 #endinput
#endif
#define _map_cookies_included


public SharedPlugin:__pl_map_cookies = 
{
	name = "map_cookies",
	file = "API_MapCookies.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


// WARNING: Never comment out, delete, or change the order of this enum! Keep adding to the end if you're adding more types.
enum MapCookieType
{
	MC_TYPE_NO_SKILL_SRV_WEAPONS_MENU = 0,
	
	NUM_MC_TYPES = 256 // Set this to a high number since its used to allocate the array size. We dont want to recompile the API each time we add a new cookie type.
};


native MapCookies_SetCookie(MapCookieType:cookie_type, value);
native MapCookies_GetCookie(MapCookieType:cookie_type);
native bool:MapCookies_HasCookie(MapCookieType:cookie_type);
native bool:MapCookies_HaveCookiesLoaded();

forward MapCookies_OnCookiesLoaded();
