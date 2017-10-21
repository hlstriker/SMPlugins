#if defined _client_cookies_included
 #endinput
#endif
#define _client_cookies_included


public SharedPlugin:__pl_client_cookies = 
{
	name = "client_cookies",
	file = "API_ClientCookies.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


// WARNING: Never comment out, delete, or change the order of this enum! Keep adding to the end if you're adding more types.
enum ClientCookieType
{
	CC_TYPE_HIDE_PLAYERS = 0,
	CC_TYPE_SPEEDRUNS_HUD_DISPLAY,
	CC_TYPE_SPOOFED_KNIVES,
	CC_TYPE_ADMIN_TAG,
	CC_TYPE_MOVEMENT_STYLE_BITS,
	CC_TYPE_SPEEDRUNS_SOUND_BITS,
	CC_TYPE_SPEEDRUNS_EXPERIENCE_SURF,
	CC_TYPE_SPEEDRUNS_EXPERIENCE_BHOP,
	CC_TYPE_SPEEDRUNS_EXPERIENCE_COURSE,
	CC_TYPE_SPEEDRUNS_EXPERIENCE_KZ,
	CC_TYPE_HUD_BITS,
	CC_TYPE_MAP_MUSIC_VOLUME,
	CC_TYPE_MAP_MUSIC_PITCH,
	CC_TYPE_SPEEDRUNS_EXPERIENCE_ROCKET,
	CC_TYPE_WEAPON_SOUND,
	CC_TYPE_SPEEDRUNS_CHECKPOINT_BITS,
	CC_TYPE_DONATOR_ITEM_COLORED_CHAT,
	CC_TYPE_DONATOR_ITEM_PLAYER_MODELS,
	CC_TYPE_SKILL_SERVER_WEAPONS_KNIFE_INDEX,
	CC_TYPE_SKILL_SERVER_WEAPONS_PISTOL_INDEX,
	CC_TYPE_SKILL_SERVER_WEAPONS_HIDE,
	CC_TYPE_SHOW_SPECTATORS,
	CC_TYPE_DONATOR_ITEM_BODY_SIZE,
	CC_TYPE_DONATOR_ITEM_BODY_TRANSPARENCY,
	CC_TYPE_SPOOFED_SKINS_GLOVES_TYPE,
	CC_TYPE_SPOOFED_SKINS_GLOVES_PAINT,
	CC_TYPE_SPOOFED_SKINS_WEAPONS_TYPE,
	CC_TYPE_SPOOFED_SKINS_WEAPONS_PAINT,
	CC_TYPE_SWOOBLES_POINTS,
	
	NUM_CC_TYPES = 256 // Set this to a high number since its used to allocate the array size. We dont want to recompile the API each time we add a new cookie type.
};


native ClientCookies_SetCookie(client, ClientCookieType:cookie_type, value);
native ClientCookies_GetCookie(client, ClientCookieType:cookie_type);
native bool:ClientCookies_HasCookie(client, ClientCookieType:cookie_type);
native bool:ClientCookies_HaveCookiesLoaded(client);

forward ClientCookies_OnCookiesLoaded(client);
