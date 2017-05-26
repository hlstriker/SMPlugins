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

#define DAY_FLAG_ALLOW_WEAPON_PICKUPS		(1<<0)
#define DAY_FLAG_ALLOW_WEAPON_DROPS			(1<<1)
#define DAY_FLAG_STRIP_GUARDS_WEAPONS		(1<<2)	// Note: This flag is for wardays only.
#define DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO	(1<<3)	// Note: This flag is for wardays only.


#define DAY_MAX_NAME_LENGTH		48



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
 * Checks to see if a day is in progress.
 *
 * @noparam
 * @return				True if day is in progress, false otherwise.
 */
native UltJB_Day_IsInProgress();

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
native UltJB_Day_SetFreezeTime(day_id, time);



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
forward UltJB_Day_OnStart(client, DayType:day_type);

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
