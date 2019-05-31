#if defined _ultjb_effects_included
 #endinput
#endif
#define _ultjb_effects_included


public SharedPlugin:__pl_ultjb_effects = 
{
	name = "ultjb_effects",
	file = "UltJB_API_Effects.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



#define EFFECT_MAX_NAME_LENGTH	32



/**
 * The prototype for the on effect selected success callback.
 *
 * @param client		The client index who started the effect selection.
 * @param effect_id		The effect ID that was selected.
 * @noreturn
 */
functag public Callback_OnEffectSelectedSuccess(client, effect_id);

/**
 * The prototype for the on effect selected failed callback.
 * It will fail whenever the selection menu doesn't have one of the effects chosen.
 *
 * @param client		The client index who started the effect selection.
 * @noreturn
 */
functag public Callback_OnEffectSelectedFailed(client);

/**
 * The prototype for the start effect callback.
 *
 * @param client			The client index who the effect should be started for.
 * @param data				The data sent when starting the effect.
 * @noreturn
 */
functag public Callback_StartEffect(client, Float:data);

/**
 * The prototype for the stop effect callback.
 *
 * @param client			The client index who the effect should be stopped for.
 * @noreturn
 */
functag public Callback_StopEffect(client);



/**
 * Registers an effect plugin.
 * This must be called in UltJB_Effects_OnRegisterReady().
 *
 * @param effect_name			The name of the effect.
 * @param start_callback		The callback function when an effect is started.
 * @param stop_callback			The callback function when an effect is stopped.
 * @param default_data			The default value for the data sent to the start callback.
 * @return						The effect ID.
 */
native UltJB_Effects_RegisterEffect(const String:effect_name[], Callback_StartEffect:start_callback, Callback_StopEffect:stop_callback, Float:default_data=0.0);

/**
 * Displays the effect selection menu to the specified client.
 * 
 * @param client				The client to display the menu to.
 * @param success_callback		The callback function when an effect is successfully selected.
 * @param failed_callback		The callback function when an effect could not be selected.
 * @param select_time_override	An override to the default amount of time the select menu will stay up.
 * @return						True if the menu was displayed, false otherwise.
 */
native bool:UltJB_Effects_DisplaySelectionMenu(client, Callback_OnEffectSelectedSuccess:success_callback, Callback_OnEffectSelectedFailed:failed_callback, select_time_override=0);

/**
 * Cancels any effect selection menu in progress for the specified client.
 *
 * @param client				The client index whos effect selection should be canceled.
 * @return						True if there was an effect selection to cancel, false otherwise.
 */
native bool:UltJB_Effects_CancelEffectSelection(client);

/**
 * Starts an effect for a client using a specified effect ID.
 *
 * @param client				The client index who the effect should be started for.
 * @param effect_id				The effect ID to start.
 * @param data					The optional data to send.
 * @return						True if the effect was started, false otherwise.
 */
native bool:UltJB_Effects_StartEffect(client, effect_id, Float:data=0.0);

/**
 * Stops an effect for a client using a specified effect ID.
 *
 * @param client				The client index who the effect should be stopped for.
 * @param effect_id				The effect ID to stop.
 * @return						True if the effect was stopped, false otherwise.
 */
native bool:UltJB_Effects_StopEffect(client, effect_id);

/**
 * Gets an effect ID based on its effect name.
 *
 * @param effect_name		The name of the effect.
 * @return					The effect ID or 0 on failure.
 */
native UltJB_Effects_GetEffectID(const String:effect_name[]);

/**
 * Gets the default data for a specified effect ID.
 *
 * @param effect_name		The effect ID.
 * @return					The default data.
 */
native Float:UltJB_Effects_GetEffectDefaultData(effect_id);



/**
 * Called when its safe to use UltJB_Effects_RegisterEffect().
 *
 * @noreturn
 */
forward UltJB_Effects_OnRegisterReady();

/**
 * Called when all effects are registered.
 *
 * @noreturn
 */
forward UltJB_Effects_OnRegisterComplete();
