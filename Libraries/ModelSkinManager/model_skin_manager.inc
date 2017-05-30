#if defined _model_skin_manager_included
 #endinput
#endif
#define _model_skin_manager_included


public SharedPlugin:__pl_model_skin_manager = 
{
	name = "model_skin_manager",
	file = "API_ModelSkinManager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define WEARABLE_INDEX_GLOVES	0



/**
 * Called when a client spawns. This is called from within a SDKHook_SpawnPost callback.
 * NOTE: You should always use this forward if you're setting player models or arms when a client spawns.
 * WARNING: You should also always use this forward for hooking when a player spawns, or check MSManager_IsBeingForceRespawned() in your spawn function to prevent interference.
 *
 * @param client		The client that spawned.
 * @noreturn
 */
forward MSManager_OnSpawnPost(client);



/**
 * Sets a custom player model on the client.
 *
 * @param client		The client to apply the model on.
 * @param model_path	The model to use.
 * @noreturn
 */
native MSManager_SetPlayerModel(client, const String:model_path[]);

/**
 * Sets custom arms on the client.
 *
 * @param client		The client to give custom arms to.
 * @param model_path	The arms model to use. Use a blank string to use default team arms.
 * @return				True on success, false otherwise.
 */
native bool:MSManager_SetArmsModel(client, const String:model_path[]="");

/**
 * Creates a wearable_item entity for a client.
 * NOTE: If the client is full on wearable_item's then this will fail.
 * WARNING: This function WILL get your server BANNED. For protection it will not get called unless you set "FollowCSGOServerGuidelines" to "no" in core.cfg.
 *
 * @param client			The client to give a wearable_item to.
 * @param wearable_index	The wearable index.
 * @param item_def_index	The item definition index to use.
 * @param paint_kit_index	The paint kit index to use.
 * @param float_value		The float value to use. 1.0 - 0.00000001
 * @return					True on success, false otherwise.
 */
native bool:MSManager_CreateWearableItem(client, wearable_index, item_def_index, paint_kit_index=0, Float:float_value=0.00000001);

/**
 * Removes a client's custom player model.
 *
 * @param client		The client to remove the model from.
 * @noreturn
 */
native MSManager_RemovePlayerModel(client);

/**
 * Remove arms from the client.
 *
 * @param client		The client to remove arms from.
 * @return				True on success, false otherwise.
 */
native bool:MSManager_RemoveArms(client);

/**
 * Deletes a client's wearable_item entity.
 *
 * @param client			The client to remove the wearable_item from.
 * @param wearable_index	The wearable index.
 * @noreturn
 */
native MSManager_DeleteWearableItem(client, wearable_index);

/**
 * Checks to see if only initial arms are allowed to be set.
 *
 * @return				True if only initial arms can be set, false otherwise.
 */
native bool:MSManager_CanOnlySetInitialArms();

/**
 * Checks to see if the client is using default arms.
 *
 * @param client		The client to check.
 * @return				True if on success, false otherwise.
 */
native bool:MSManager_HasDefaultArms(client);

/**
 * Checks to see if the client is using custom arms.
 *
 * @param client		The client to check.
 * @return				True if on success, false otherwise.
 */
native bool:MSManager_HasCustomArms(client);

/**
 * Checks to see if the client is using wearable gloves.
 *
 * @param client		The client to check.
 * @return				True if on success, false otherwise.
 */
native bool:MSManager_HasWearableGloves(client);

/**
 * Checks to see if a client is in the process of being force respawned for arm reapplication.
 *
 * @param client		The client to check.
 * @return				True if being force respawned, false otherwise.
 */
native bool:MSManager_IsBeingForceRespawned(client);


#if !defined REQUIRE_PLUGIN
public __pl_model_skin_manager_SetNTVOptional()
{
	MarkNativeAsOptional("MSManager_SetPlayerModel");
	MarkNativeAsOptional("MSManager_SetArmsModel");
	MarkNativeAsOptional("MSManager_CreateWearableItem");
	MarkNativeAsOptional("MSManager_RemovePlayerModel");
	MarkNativeAsOptional("MSManager_RemoveArms");
	MarkNativeAsOptional("MSManager_DeleteWearableItem");
	MarkNativeAsOptional("MSManager_CanOnlySetInitialArms");
	MarkNativeAsOptional("MSManager_HasDefaultArms");
	MarkNativeAsOptional("MSManager_HasCustomArms");
	MarkNativeAsOptional("MSManager_HasWearableGloves");
	MarkNativeAsOptional("MSManager_IsBeingForceRespawned");
}
#endif