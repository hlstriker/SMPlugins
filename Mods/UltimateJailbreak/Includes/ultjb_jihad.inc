#if defined _ultjb_jihad_included
 #endinput
#endif
#define _ultjb_jihad_included


public SharedPlugin:__pl_ultjb_jihad = 
{
	name = "ultjb_jihad",
	file = "UltJB_Jihad.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};




/**
 * Checks whether a client is a jihad or not.
 *
 * @param client		The client's index.
 * @return				True if client is a jihad, false otherwise.
 */
native bool:UltJB_Jihad_IsJihad(client);

/**
 * Sets a client as a jihad.
 *
 * @param client		The client's index.
 * @noreturn
 */
native UltJB_Jihad_SetJihad(client);

/**
 * Clears a client from being a jihad.
 *
 * @param client		The client's index.
 * @noreturn
 */
native UltJB_Jihad_ClearJihad(client);

/**
 * Sets if clients are allowed to drop their jihad bomb.
 *
 * @param allow		Set to true to allow bomb dropping, false otherwise.
 * @noreturn
 */
native UltJB_Jihad_SetAllowBombDropping(bool:allow);



#if !defined REQUIRE_PLUGIN
public __pl_ultjb_jihad_SetNTVOptional()
{
	MarkNativeAsOptional("UltJB_Jihad_IsJihad");
	MarkNativeAsOptional("UltJB_Jihad_SetJihad");
	MarkNativeAsOptional("UltJB_Jihad_ClearJihad");
	MarkNativeAsOptional("UltJB_Jihad_SetAllowBombDropping");
}
#endif
