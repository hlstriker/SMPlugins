#if defined _custom_weapon_rpg_included
 #endinput
#endif
#define _custom_weapon_rpg_included


public SharedPlugin:__pl_custom_weapon_rpg = 
{
	name = "custom_weapon_rpg",
	file = "CustomWeapon_RPG.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Allows a client to use this weapon or not (also strips weapon if not).
 *
 * @param client			The client.
 * @param allow_usage		True if the client can use this weapon, false otherwise.
 * @noreturn
 */
native WpnRPG_AllowUsage(client, bool:allow_usage);

/**
 * Give this weapon to the specified client and give them usage access.
 *
 * @param client			The client.
 * @param clip_amount		The initial clip ammo amount.
 * @param reserve_amount	The initial reserve ammo amount.
 * @param max_clip_size		The maximum clip size.
 * @param max_reserve_size	The maximum reserve size.
 * @return					The weapon index, -1 on failure.
 */
native WpnRPG_Give(client, clip_amount=4, reserve_amount=50, max_clip_size=4, max_reserve_size=50);

/**
 * Remove this weapon from the specified client.
 *
 * @param client			The client.
 * @param disable_usage		True if the client should no longer have access to using this weapon, false otherwise.
 * @noreturn
 */
native WpnRPG_Remove(client, bool:disable_usage=false);

/**
 * Sets if a client should have unlimited ammo for this weapon or not.
 *
 * @param client			The client.
 * @param clip_ammo			True if the client should have unlimited clip ammo, false otherwise.
 * @param reserve_ammo		True if the client should have unlimited reserve ammo, false otherwise.
 * @noreturn
 */
native WpnRPG_SetUnlimitedAmmo(client, bool:clip_ammo=false, bool:reserve_ammo=false);

/**
 * Sets who can see/hear the rocket effects.
 *
 * @param client				The client.
 * @param show_to_self_only		True if only the client shooting can see/hear, false otherwise.
 * @noreturn
 */
native WpnRPG_SetEffectVisibility(client, bool:show_to_self_only=false);



#if !defined REQUIRE_PLUGIN
public __pl_custom_weapon_rpg_SetNTVOptional()
{
	MarkNativeAsOptional("WpnRPG_AllowUsage");
	MarkNativeAsOptional("WpnRPG_Give");
	MarkNativeAsOptional("WpnRPG_Remove");
	MarkNativeAsOptional("WpnRPG_SetUnlimitedAmmo");
	MarkNativeAsOptional("WpnRPG_SetEffectVisibility");
}
#endif