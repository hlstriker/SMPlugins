#if defined _ultjb_weapon_selection_included
 #endinput
#endif
#define _ultjb_weapon_selection_included


public SharedPlugin:__pl_ultjb_weapon_selection = 
{
	name = "ultjb_weapon_selection",
	file = "UltJB_API_WeaponSelection.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



#include <cstrike>



// Note: Make sure to delete these when sourcemod implements their own values and remove the checks in UltJB_Weapons_GetEntNameFromWeaponID().
#define CSWeapon_CZ75A			1001
#define CSWeapon_M4A1_SILENCER	1002
#define CSWeapon_USP_SILENCER	1003
#define CSWeapon_KNIFE_T		1004
#define CSWeapon_HEALTHSHOT		1005
#define CSWeapon_TAGRENADE		1006
#define CSWeapon_REVOLVER		1007



#define WEAPON_MAX_NAME_LENGTH			32
#define WEAPON_MAX_ENTITY_NAME_LENGTH	32
#define ITEM_MAX_ENTITY_NAME_LENGTH		32



#define WPN_FLAGS_DISABLE_KNIFE_KNIFE			(1<<0)
#define WPN_FLAGS_DISABLE_KNIFE_TASER			(1<<1)

#define WPN_FLAGS_DISABLE_KNIVES				WPN_FLAGS_DISABLE_KNIFE_KNIFE			|\
												WPN_FLAGS_DISABLE_KNIFE_TASER

#define WPN_FLAGS_DISABLE_PISTOL_GLOCK			(1<<0)
#define WPN_FLAGS_DISABLE_PISTOL_HPK2000		(1<<1)
#define WPN_FLAGS_DISABLE_PISTOL_USP_SILENCER	(1<<2)
#define WPN_FLAGS_DISABLE_PISTOL_ELITE			(1<<3)
#define WPN_FLAGS_DISABLE_PISTOL_P250			(1<<4)
#define WPN_FLAGS_DISABLE_PISTOL_CZ75A			(1<<5)
#define WPN_FLAGS_DISABLE_PISTOL_FIVESEVEN		(1<<6)
#define WPN_FLAGS_DISABLE_PISTOL_TEC9			(1<<7)
#define WPN_FLAGS_DISABLE_PISTOL_DEAGLE			(1<<8)
#define WPN_FLAGS_DISABLE_PISTOL_REVOLVER		(1<<9)

#define WPN_FLAGS_DISABLE_PISTOLS				WPN_FLAGS_DISABLE_PISTOL_GLOCK			|\
												WPN_FLAGS_DISABLE_PISTOL_HPK2000		|\
												WPN_FLAGS_DISABLE_PISTOL_USP_SILENCER	|\
												WPN_FLAGS_DISABLE_PISTOL_ELITE			|\
												WPN_FLAGS_DISABLE_PISTOL_P250			|\
												WPN_FLAGS_DISABLE_PISTOL_CZ75A			|\
												WPN_FLAGS_DISABLE_PISTOL_FIVESEVEN		|\
												WPN_FLAGS_DISABLE_PISTOL_TEC9			|\
												WPN_FLAGS_DISABLE_PISTOL_DEAGLE			|\
												WPN_FLAGS_DISABLE_PISTOL_REVOLVER

#define WPN_FLAGS_DISABLE_HEAVY_NOVA			(1<<0)
#define WPN_FLAGS_DISABLE_HEAVY_XM1014			(1<<1)
#define WPN_FLAGS_DISABLE_HEAVY_SAWEDOFF		(1<<2)
#define WPN_FLAGS_DISABLE_HEAVY_MAG7			(1<<3)
#define WPN_FLAGS_DISABLE_HEAVY_M249			(1<<4)
#define WPN_FLAGS_DISABLE_HEAVY_NEGEV			(1<<5)

#define WPN_FLAGS_DISABLE_HEAVYS				WPN_FLAGS_DISABLE_HEAVY_NOVA		|\
												WPN_FLAGS_DISABLE_HEAVY_XM1014		|\
												WPN_FLAGS_DISABLE_HEAVY_SAWEDOFF	|\
												WPN_FLAGS_DISABLE_HEAVY_MAG7		|\
												WPN_FLAGS_DISABLE_HEAVY_M249		|\
												WPN_FLAGS_DISABLE_HEAVY_NEGEV

#define WPN_FLAGS_DISABLE_SMG_MAC10				(1<<0)
#define WPN_FLAGS_DISABLE_SMG_MP7				(1<<1)
#define WPN_FLAGS_DISABLE_SMG_MP9				(1<<2)
#define WPN_FLAGS_DISABLE_SMG_UMP45				(1<<3)
#define WPN_FLAGS_DISABLE_SMG_P90				(1<<4)
#define WPN_FLAGS_DISABLE_SMG_BIZON				(1<<5)

#define WPN_FLAGS_DISABLE_SMGS					WPN_FLAGS_DISABLE_SMG_MAC10		|\
												WPN_FLAGS_DISABLE_SMG_MP7		|\
												WPN_FLAGS_DISABLE_SMG_MP9		|\
												WPN_FLAGS_DISABLE_SMG_UMP45		|\
												WPN_FLAGS_DISABLE_SMG_P90		|\
												WPN_FLAGS_DISABLE_SMG_BIZON

#define WPN_FLAGS_DISABLE_RIFLE_GALILAR			(1<<0)
#define WPN_FLAGS_DISABLE_RIFLE_FAMAS			(1<<1)
#define WPN_FLAGS_DISABLE_RIFLE_AK47			(1<<2)
#define WPN_FLAGS_DISABLE_RIFLE_M4A1			(1<<3)
#define WPN_FLAGS_DISABLE_RIFLE_M4A1_SILENCER	(1<<4)
#define WPN_FLAGS_DISABLE_RIFLE_SSG08			(1<<5)
#define WPN_FLAGS_DISABLE_RIFLE_SG556			(1<<6)
#define WPN_FLAGS_DISABLE_RIFLE_AUG				(1<<7)
#define WPN_FLAGS_DISABLE_RIFLE_AWP				(1<<8)
#define WPN_FLAGS_DISABLE_RIFLE_G3SG1			(1<<9)
#define WPN_FLAGS_DISABLE_RIFLE_SCAR20			(1<<10)

#define WPN_FLAGS_DISABLE_RIFLES				WPN_FLAGS_DISABLE_RIFLE_GALILAR			|\
												WPN_FLAGS_DISABLE_RIFLE_FAMAS			|\
												WPN_FLAGS_DISABLE_RIFLE_AK47			|\
												WPN_FLAGS_DISABLE_RIFLE_M4A1			|\
												WPN_FLAGS_DISABLE_RIFLE_M4A1_SILENCER	|\
												WPN_FLAGS_DISABLE_RIFLE_SSG08			|\
												WPN_FLAGS_DISABLE_RIFLE_SG556			|\
												WPN_FLAGS_DISABLE_RIFLE_AUG				|\
												WPN_FLAGS_DISABLE_RIFLE_AWP				|\
												WPN_FLAGS_DISABLE_RIFLE_G3SG1			|\
												WPN_FLAGS_DISABLE_RIFLE_SCAR20


enum
{
	WPN_CAT_KNIFE = 0,
	WPN_CAT_PISTOLS,
	WPN_CAT_HEAVY,
	WPN_CAT_SMGS,
	WPN_CAT_RIFLES,
	WPN_CAT_GRENADES,
	NUM_WPN_CATS
};


#define WEAPON_TEAM_ANY		-1
#define WEAPON_TEAM_NONE	0	// Use WEAPON_TEAM_NONE for weapons that break due to inventory loadout.
#define WEAPON_TEAM_T		CS_TEAM_T
#define WEAPON_TEAM_CT		CS_TEAM_CT


/**
 * The prototype for the on weapon selected success callback.
 *
 * @param client		The client index who started the weapon selection.
 * @param weapon_id		The weapon ID that was selected.
 * @param flags			The flags that were sent when starting the weapon selection menu.
 * @noreturn
 */
functag public Callback_OnWeaponSelectedSuccess(client, weapon_id, const flags[NUM_WPN_CATS]);

/**
 * The prototype for the on weapon selected failed callback.
 * It will fail whenever the selection menu doesn't have one of the weapons chosen.
 *
 * @param client		The client index who started the weapon selection.
 * @param flags			The flags that were sent when starting the weapon selection menu.
 * @noreturn
 */
functag public Callback_OnWeaponSelectedFailed(client, const flags[NUM_WPN_CATS]);



/**
 * Displays the weapon selection menu to the specified client.
 * 
 * @param client				The client to display the menu to.
 * @param success_callback		The callback function when a weapon is successfully selected.
 * @param failed_callback		The callback function when a weapon could not be selected.
 * @param flags					The weapon selection flags.
 * @return						True if the menu was displayed, false otherwise.
 */
native bool:UltJB_Weapons_DisplaySelectionMenu(client, Callback_OnWeaponSelectedSuccess:success_callback, Callback_OnWeaponSelectedFailed:failed_callback, const flags[NUM_WPN_CATS]);

/**
 * Cancels any weapon selection menu in progress for the specified client.
 *
 * @param client		The client index whos weapon selection should be canceled.
 * @return				True if there was a weapon selection to cancel, false otherwise.
 */
native bool:UltJB_Weapons_CancelWeaponSelection(client);

/**
 * Gets a weapons entity name from its weapon ID.
 *
 * @param weapon_id		The WeaponID to get the entity name for.
 * @param entity_name	Destination string to hold the entity name.
 * @param maxlength		Length of the destination array.
 * @return				Returns number of cells written.
 */
native UltJB_Weapons_GetEntNameFromWeaponID(weapon_id, String:entity_name[], maxlength);


/**
 * Gets a weapons item definition index from its weapon ID.
 *
 * @param weapon_id		The WeaponID to get the item definition index for.
 * @return				Item definition index or 0 on unknown.
 */
native UltJB_Weapons_GetItemDefIndexFromWeaponID(weapon_id);

/**
 * Gets a weapons default team.
 *
 * @param weapon_classname		The weapons classname to get the default team for.
 * @return						The weapons default team.
 */
native UltJB_Weapons_GetWeaponsDefaultTeam(const String:weapon_classname[]);

/**
 * Gives a player a weapon that uses their custom skin if they have one.
 *
 * @param client				The client to give the weapon to.
 * @param weapon_id				The weapon to give based on weapon ID.
 * @return						Weapon entity index on success, -1 on failure.
 */
native UltJB_Weapons_GivePlayerWeapon(client, weapon_id);

/**
 * Gives an item to a client.
 *
 * @param client				The client to give the item to.
 * @param item_classname		The items classname.
 * @return						Item entity index on success, -1 on failure.
 */
native UltJB_Weapons_GivePlayerItem(client, const String:item_classname[]);

/**
 * Checks to see if a player is currently being given an item.
 *
 * @param client				The client to check.
 * @return						True if getting an item, false otherwise.
 */
native bool:UltJB_Weapons_IsGettingItem(client);

/**
 * Checks to see if a weapon was given to a client on their last request.
 *
 * @param weapon				The weapon entity index to check.
 * @return						True if from LR, false otherwise.
 */
native bool:UltJB_Weapons_IsWeaponFromLR(weapon);
