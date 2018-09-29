#if defined _donators_included
 #endinput
#endif
#define _donators_included


public SharedPlugin:__pl_donators = 
{
	name = "donators",
	file = "API_Donators.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



functag public Callback_OnSettingsCalled(client);



/*
* This is when it's safe to check if a client is a donator or not
*/
forward Donators_OnStatusLoaded(client);

forward Donators_OnRegisterSettingsReady();



/**
 * Checks to see if a client is a donator.
 *
 * @param client			Client index.
 * @return					True if client is a donator, false otherwise.
 */
native bool:Donators_IsDonator(client);

/**
 * Gets the time left on a donators subscription.
 *
 * @param client			Client index.
 * @return					The time left in seconds of the donators subscription.
 */
native Float:Donators_GetSubscriptionTimeLeft(client);

native Donators_GetActiveSubscriptions(client);

native bool:Donators_RegisterSettings(const String:settings_title[], Callback_OnSettingsCalled:settings_callback);

native bool:Donators_OpenSettingsMenu(client);




#if !defined REQUIRE_PLUGIN
public __pl_donators_SetNTVOptional()
{
	MarkNativeAsOptional("Donators_IsDonator");
	MarkNativeAsOptional("Donators_GetSubscriptionTimeLeft");
	MarkNativeAsOptional("Donators_RegisterSettings");
	MarkNativeAsOptional("Donators_OpenSettingsMenu");
	MarkNativeAsOptional("Donators_GetActiveSubscriptions");
}
#endif
