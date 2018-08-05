#if defined _skins_for_map_weapons_included
 #endinput
#endif
#define _skins_for_map_weapons_included


public SharedPlugin:__pl_skins_for_map_weapons =
{
	name = "skins_for_map_weapons",
	file = "SkinsForMapWeapons.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

/**
 * Called when a weapon is equipped.
 *
 * @param client			The client index who started the day.
 * @param oldweapon			The weapon before it is skinned.
 * @param newweapon			The weapon after it is skinned.
 * @noreturn
 */
forward SFMW_OnWeaponEquip(client, oldweapon, newweapon);