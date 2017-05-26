#if defined _client_settings_included
 #endinput
#endif
#define _client_settings_included


public SharedPlugin:__pl_client_settings =
{
	name = "client_settings",
	file = "API_ClientSettings.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



#define MAX_CLAN_TAG_LENGTH	22



/**
 * Called when a clients name changes.
 *
 * @param client		Client index.
 * @param old_name		Clients old name.
 * @param new_name		Clients new name.
 * @noreturn
 */
forward ClientSettings_OnNameChange(client, const String:old_name[], const String:new_name[]);

/**
 * Called when a clients real clan tag changes.
 *
 * @param client		Client index.
 * @param old_tag		Clients old clan tag.
 * @param new_new		Clients new clan tag.
 * @param has_fake_tag	True if the client has a fake tag as well.
 * @noreturn
 */
forward Action:ClientSettings_OnRealClanTagChange(client, const String:old_tag[], const String:new_tag[], bool:has_fake_tag);

/**
 * Called when a clients fake clan tag changes.
 *
 * @param client		Client index.
 * @param old_tag		Clients old clan tag.
 * @param new_new		Clients new clan tag.
 * @noreturn
 */
forward ClientSettings_OnFakeClanTagChange(client, const String:old_tag[], const String:new_tag[]);



/**
 * Returns the clients real clan tag.
 *
 * @param client		Client index.
 * @param clan_tag		Buffer to store the client's clan tag.
 * @param maxlen		Maximum length of string buffer (includes NULL terminator).
 * @return			True on success, false otherwise.
 */
native bool:ClientSettings_GetRealClanTag(client, String:clan_tag[], maxlen);

/**
 * Returns the clients fake clan tag.
 *
 * @param client		Client index.
 * @param clan_tag		Buffer to store the client's clan tag.
 * @param maxlen		Maximum length of string buffer (includes NULL terminator).
 * @return			True on success, false otherwise.
 */
native bool:ClientSettings_GetFakeClanTag(client, String:clan_tag[], maxlen);

/**
 * Sets the clients fake clan tag.
 *
 * @param client		Client index.
 * @param clan_tag		Buffer to store the client's clan tag.
 * @return			True on success, false otherwise.
 */
native bool:ClientSettings_SetFakeClanTag(client, const String:clan_tag[]);

/**
 * Clear the clients fake clan tag.
 *
 * @param client		Client index.
 * @return			True on success, false otherwise.
 */
native bool:ClientSettings_ClearFakeClanTag(client);

/**
 * Checks if a client has a fake clan tag set.
 *
 * @param client		Client index.
 * @return			True if fake tag set, false otherwise.
 */
native bool:ClientSettings_HasFakeClanTag(client);



#if !defined REQUIRE_PLUGIN
public __pl_client_settings_SetNTVOptional()
{
	MarkNativeAsOptional("ClientSettings_GetRealClanTag");
	MarkNativeAsOptional("ClientSettings_GetFakeClanTag");
	MarkNativeAsOptional("ClientSettings_SetFakeClanTag");
	MarkNativeAsOptional("ClientSettings_ClearFakeClanTag");
	MarkNativeAsOptional("ClientSettings_HasFakeClanTag");
}
#endif