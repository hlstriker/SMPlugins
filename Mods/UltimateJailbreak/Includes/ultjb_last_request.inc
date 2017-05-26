#if defined _ultjb_last_request_included
 #endinput
#endif
#define _ultjb_last_request_included


public SharedPlugin:__pl_ultjb_last_request = 
{
	name = "ultjb_last_request",
	file = "UltJB_API_LastRequest.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



#define TEAM_PRISONERS	2
#define TEAM_GUARDS		3

#define LAST_REQUEST_MAX_NAME_LENGTH		48
#define LAST_REQUEST_MAX_DESCRIPTION_LENGTH	128

#define LR_CATEGORY_MAX_NAME_LENGTH			48

#define LR_FLAG_LAST_PRISONER_ONLY_CAN_USE			(1<<0)	// If this flag is set then the LR can only be selected if only 1 prisoner is alive.
#define LR_FLAG_DONT_END_ON_PRISONER_DEATH			(1<<1)	// By default the LR will end on prisoners death. This flag prevents that.
#define LR_FLAG_DONT_END_ON_GUARD_DEATH				(1<<2)	// By default the LR will end on guards death. This flag prevents that.
#define LR_FLAG_DONT_END_ON_GUARD_LEAVE				(1<<3)	// By default the LR will end if a prisoners opponent leaves. This will prevent that.
#define LR_FLAG_DONT_END_ON_ROUND_END				(1<<4)	// By default the LR will end when the round ends. This flag prevents that.
#define LR_FLAG_DONT_END_ON_GUARD_SELECT_FAIL		(1<<5)	// By default the LR will end if the guard selection menu has a failed callback. This prevents that.
#define LR_FLAG_ALLOW_WEAPON_PICKUPS				(1<<6)	// By default players cannot pickup weapons while in LR. This allows them to.
#define LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT		(1<<7)	// By default players can damage their opponent. This disables opponent damage.
#define LR_FLAG_ALLOW_WEAPON_DROPS					(1<<8)	// By default players cannot drop weapons while in LR. This allows them to.
#define LR_FLAG_DONT_TELEPORT_TO_OPPONENT			(1<<9)	// By default the guard is teleported to their opponent. This disables that.
#define LR_FLAG_FREEDAY								(1<<10)	// If this flag is set it means the LR is a freeday and will slay the prisoner and apply their freeday the next round.
#define LR_FLAG_NORADAR								(1<<11)	// By default players appear on enemy radars at all times. This disables that.
#define LR_FLAG_NOBEACON							(1<<12)	// By default LR participants are marked by a ring and connected by a beam. This disables that.
#define LR_FLAG_TEMP_INVINCIBLE						(1<<13)	// Makes LR participant temporarily invincible at start of LR
#define LR_FLAG_SHOW_ALL_GUARDS_ON_RADAR			(1<<14)	// Shows all guards on the radar for the duration of the LR.
#define LR_FLAG_RANDOM_TELEPORT_LOCATION			(1<<15)	// Teleports LR participant to a random location when the LR starts.

#define LR_SLAYTIMER_FLAG_GUARD			(1<<0)
#define LR_SLAYTIMER_FLAG_PRISONER		(1<<1)



/**
 * The prototype for the start last request callback.
 *
 * @param client			The client index who started the last request.
 * @noreturn
 */
functag public Callback_StartLastRequest(client);

/**
 * The prototype for the end last request callback.
 *
 * @param client			The client index who started the last request.
 * @param opponent			The clients opponent index. If there is no opponent the index is 0.
 * @noreturn
 */
functag public Callback_EndLastRequest(client, opponent);

/**
 * The prototype for when a guards opponent leaves the game callback.
 *
 * @param client			The client index who started the last request.
 * @noreturn
 */
functag public Callback_OnOpponentLeftGame(client);

/**
 * The prototype for the on opponent selected success callback.
 *
 * @param client		The client index who started the last request.
 * @param opponent		The opponent index who this client decided to face.
 * @noreturn
 */
functag public Callback_OnOpponentSelectedSuccess(client, opponent);

/**
 * The prototype for the on opponent selected failed callback.
 * It can fail if a client wasn't found, or if the LR ended.
 *
 * @param client		The client index who started the last request.
 * @noreturn
 */
functag public Callback_OnOpponentSelectedFailed(client);



/**
 * Registers a last request plugin.
 * This must be called in UltJB_LR_OnRegisterReady().
 *
 * @param last_request_name		The name of the last request.
 * @param flags					The flags for this last request.
 * @param start_callback		The callback function when this last request is started.
 * @param end_callback			The callback function when this last request is ended.
 * @param opponent_left_game	The callback function for when a prisoners opponent leaves the game.
 * @return						The last request ID.
 */
native UltJB_LR_RegisterLastRequest(const String:last_request_name[], flags=0, Callback_StartLastRequest:start_callback, Callback_EndLastRequest:end_callback=INVALID_FUNCTION, Callback_OnOpponentLeftGame:opponent_left_game=INVALID_FUNCTION);

/**
 * Notify the core plugin to end the last request for a client.
 *
 * @param last_request_id			The last request ID.
 * @param category_name				The category we want to assign this LR to.
 * @param last_request_description	The description we want to give this LR.
 * @return							True on success, false otherwise.
 */
native bool:UltJB_LR_SetLastRequestData(last_request_id, const String:category_name[]="Other", const String:last_request_description[]="");

/**
 * Notify the core plugin to end the last request for a client.
 *
 * @param client		The client whos last request should be ended.
 * @noreturn
 */
native UltJB_LR_EndLastRequest(client);

/**
 * Sets the clients last request opponent.
 * 
 * @param client		The player index of who we want to set the opponent for.
 * @param opponent		The player index of the opponent we want to set.
 * @return				True if the opponent was set, false otherwise.
 */
native bool:UltJB_LR_SetLastRequestOpponent(client, opponent);

/**
 * Gets the clients last request opponent.
 * 
 * @param client		The player index of who we want to get the opponent for.
 * @return				A players index or 0 if none found.
 */
native UltJB_LR_GetLastRequestOpponent(client);

/**
 * Displays the opponent selection menu to the specified client.
 * 
 * @param client				The client to display the menu to.
 * @param success_callback		The callback function when an opponent is successfully selected.
 * @param failed_callback		The callback function when an opponent could not be found.
 * @return						True if the menu was displayed, false otherwise.
 */
native bool:UltJB_LR_DisplayOpponentSelection(client, Callback_OnOpponentSelectedSuccess:success_callback, Callback_OnOpponentSelectedFailed:failed_callback=INVALID_FUNCTION);

/**
 * Saves the clients current weapon loadout so it can be restored later.
 *
 * @param client		The client whos weapons should be saved.
 * @noreturn
 */
native UltJB_LR_SaveClientsWeapons(client);

/**
 * Restores the clients saved weapon loadout.
 *
 * @param client		The client whos weapons should be restored.
 * @noreturn
 */
native UltJB_LR_RestoreClientsWeapons(client);

/**
 * Strips all the clients weapons.
 *
 * @param client				The client whos weapons should be stripped.
 * @param save_weapons			Should the clients current weapon loadout be saved?
 * @noreturn
 */
native UltJB_LR_StripClientsWeapons(client, bool:save_weapons=false);

/**
 * Sets the clients health (this sets their max health too if the amount is greater than their current max health).
 *
 * @param client		The client whos health should be set.
 * @param health		The amount of health to set.
 * @noreturn
 */
native UltJB_LR_SetClientsHealth(client, health);

/**
 * Checks to see if a client has started a last request (returns false if initialized but not started).
 *
 * @param client		The client to check.
 * @return				True if started LR, false otherwise.
 */
native bool:UltJB_LR_HasStartedLastRequest(client);

/**
 * Checks the clients last request flags.
 *
 * @param client		The client to check.
 * @return				Flag bitmask.
 */
native UltJB_LR_GetLastRequestFlags(client);

/**
 * Gets the current round number.
 *
 * @return		The round number.
 */
native UltJB_LR_GetRoundNumber();

/**
 * Starts a timer to slay the prisoner and/or guard.
 *
 * @param client				The client in the last request.
 * @param time_before_slay		The time to wait before slaying.
 * @param slay_flags			The slay flags. This determines which players to slay.
 * @return						True if the timer started, false on failure.
 */
native bool:UltJB_LR_StartSlayTimer(client, time_before_slay=45, slay_flags=LR_SLAYTIMER_FLAG_PRISONER | LR_SLAYTIMER_FLAG_GUARD);

/**
 * Stops a timer to slay the prisoner and/or guard.
 *
 * @param client				The clients slay timer to stop.
 * @noreturn
 */
native bool:UltJB_LR_StopSlayTimer(client);

/**
 * Gets the number of last requests initialized (when a LR is started it is still initialized).
 *
 * @noparam
 * @return					The number of last requests initialized.
 */
native UltJB_LR_GetNumInitialized();

/**
 * Checks whether or not there are enough prisoners for LR
 *
 * @noparam
 * @return					True if LR can begin, false otherwise
 */
native UltJB_LR_CanLastRequest();

/**
 * Gets the number of last requests started using an ignore mask.
 *
 * @param ignore_mask		A mask of LR_FLAG_* to ignore.
 * @return					The number of last requests started.
 */
native UltJB_LR_GetNumStartedIgnore(ignore_mask=0);

/**
 * Gets the number of last requests started using a contains mask.
 *
 * @param contains_mask		A mask of LR_FLAG_* to check for.
 * @return					The number of last requests started.
 */
native UltJB_LR_GetNumStartedContains(contains_mask=0);


/**
 * Called when its safe to use UltJB_LR_RegisterLastRequest().
 *
 * @noreturn
 */
forward UltJB_LR_OnRegisterReady();

/**
 * Called when a client initializes a last request.
 *
 * @param client			The client who initialized the last request.
 * @noreturn
 */
forward UltJB_LR_OnLastRequestInitialized(client);

/**
 * Called when a client starts a last request.
 *
 * @param client			The client who started the last request.
 * @noreturn
 */
forward UltJB_LR_OnLastRequestStarted(client, lr_flags);
