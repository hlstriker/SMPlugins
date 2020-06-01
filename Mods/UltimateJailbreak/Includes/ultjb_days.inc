#if defined _ultjb_days_included
 #endinput
#endif
#define _ultjb_days_included


public SharedPlugin:__pl_ultjb_days = 
{
	name = "ultjb_days",
	file = "UltJB_API_Days.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



enum DayType
{
	DAY_TYPE_NONE = -1,
	DAY_TYPE_FREEDAY,
	DAY_TYPE_WARDAY
};

#define DAY_FLAG_ALLOW_WEAPON_PICKUPS			(1<<0)
#define DAY_FLAG_ALLOW_WEAPON_DROPS				(1<<1)
#define DAY_FLAG_STRIP_GUARDS_WEAPONS			(1<<2)
#define DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO		(1<<3)
#define DAY_FLAG_STRIP_PRISONERS_WEAPONS		(1<<4)
#define DAY_FLAG_KILL_WORLD_WEAPONS				(1<<5)
#define DAY_FLAG_GIVE_PRISONERS_INFINITE_AMMO	(1<<6)
#define DAY_FLAG_DISABLE_PRISONERS_RADAR		(1<<7)
#define DAY_FLAG_DISABLE_GUARDS_RADAR			(1<<8)
#define DAY_FLAG_FORCE_FREE_FOR_ALL				(1<<9)
#define DAY_FLAG_DISABLE_WEAPON_BUYING			(1<<10)
#define DAY_FLAG_ALLOW_WEAPON_PICKUPS_FROM_DAY	(1<<11)


#define DAY_MAX_NAME_LENGTH		48

#define FREEZE_TEAM_GUARDS		(1<<0)
#define FREEZE_TEAM_PRISONERS	(1<<1)



/**
 * The prototype for the start day callback.
 *
 * @param client			The client index who started the day.
 * @noreturn
 */
functag public Callback_StartDay(client);

/**
 * The prototype for the end day callback.
 *
 * @param client			The client index who ended the day.
 * @noreturn
 */
functag public Callback_EndDay(client);

/**
 * The prototype for when the warday freeze time ends.
 *
 * @noparam
 * @noreturn
 */
functag public Callback_WardayFreezeEnd();



/**
 * Registers a day plugin.
 * This must be called in UltJB_Day_OnRegisterReady().
 *
 * @param day_name				The name of the day.
 * @param day_type				The type of day.
 * @param flags					The flags for this day.
 * @param start_callback		The callback function when this day is started.
 * @param end_callback			The callback function when this day is ended.
 * @param freeze_end_callback	The callback function for wardays when the freeze time ends.
 * @return						The day ID.
 */
native UltJB_Day_RegisterDay(const String:day_name[], DayType:day_type, flags=0, Callback_StartDay:start_callback, Callback_EndDay:end_callback=INVALID_FUNCTION, Callback_WardayFreezeEnd:freeze_end_callback=INVALID_FUNCTION);

/**
 * Sets the enabled state on the day. This will enable or disable the day in the days menu.
 *
 * @param day_id		The days ID.
 * @param enabled		The enabled state.
 * @return				True if day found, false otherwise.
 */
native bool:UltJB_Day_SetEnabled(day_id, bool:enabled);

/**
 * Modify the day flags.
 *
 * @param day_id		The days ID.
 * @param time			The flags to use.
 * @return				True if set, false otherwise.
 */
native bool:UltJB_Day_SetFlags(day_id, flags);

/**
 * Checks to see if a day is in progress.
 *
 * @noparam
 * @return				True if day is in progress, false otherwise.
 */
native bool:UltJB_Day_IsInProgress();

/**
 * Gets the current day ID.
 *
 * @noparam
 * @return				The day ID.
 */
native UltJB_Day_GetCurrentDayID();

/**
 * Gets the current day type.
 *
 * @noparam
 * @return				The day type.
 */
native DayType:UltJB_Day_GetCurrentDayType();

/**
 * Sets a wardays freezetime.
 *
 * @param day_id		The days ID.
 * @param time			The freezetime to use.
 * @return				True if set, false otherwise.
 */
native bool:UltJB_Day_SetFreezeTime(day_id, time);

/**
 * Sets the teams that should be frozen during freezetime.
 *
 * @param day_id			The days ID.
 * @param freeze_team_bits	A bitmask of the FREEZE_TEAM_* defines.
 * @return					True if set, false otherwise.
 */
native bool:UltJB_Day_SetFreezeTeams(day_id, freeze_team_bits);

/**
 * Force ends any freeze time in progress.
 *
 * @noparam
 * @noreturn
 */
native UltJB_Day_FreezeTimeForceEnd();

/**
 * Gets the freeze time remaining for wardays.
 *
 * @noparam
 * @return				The freeze time remaining in seconds.
 */
native UltJB_Day_GetFreezeTimeRemaining();

/**
 * Sets if this day is allowed to choose free for all.
 *
 * @param day_id		The days ID.
 * @param enabled		The allowed state.
 * @return				True if day found, false otherwise.
 */
native bool:UltJB_Day_AllowFreeForAll(day_id, bool:allow);

/**
 * Gets whether the current day is in free for all or not.
 *
 * @noparam
 * @return				True if in free-for-all, false otherwise.
 */
native bool:UltJB_Day_IsFreeForAll();

/**
 * Sets this entity as spawned by day or not.
 *
 * @param day_id				The entity index to set.
 * @param spawned_by_day		True if spawned by day, false otherwise.
 * @noreturn
 */
native UltJB_Day_SetEntityAsSpawnedByDay(entity, bool:spawned_by_day=true);



/**
 * Called when its safe to use UltJB_Day_RegisterDay().
 *
 * @noreturn
 */
forward UltJB_Day_OnRegisterReady();

/**
 * Called when a day starts.
 *
 * @param client			The client index who started the day.
 * @param day_type			The type of day.
 * @noreturn
 */
forward UltJB_Day_OnStart(client, DayType:day_type, bool:is_free_for_all);

/**
 * Called when a warday starts (after OnStart and before OnWardayFreezeEnd).
 *
 * @param client			The client index who started the day.
 * @noreturn
 */
forward UltJB_Day_OnWardayStart(client);

/**
 * Called when a wardays freeze time ends.
 *
 * @noreturn
 */
forward UltJB_Day_OnWardayFreezeEnd();

/**
 * Called after the client is prepared during OnSpawnPost.
 *
 * @param client			The client who was prepared.
 * @noreturn
 */
forward UltJB_Day_OnSpawnPost(client);
