// This file has been stripped down to only the elements needed for the simplekz style
// From: https://bitbucket.org/Sikarii/movementhud/

// ================== DOUBLE INCLUDE ========================= //

#if defined _MovementHUD_included_
#endinput
#endif
#define _MovementHUD_included_

// =========================================================== //

/**
 * Gets current ticks on ground for client from MovementHUD tracking
 *
 * @param client		Client index
 * @return				Amount of ticks on ground for the client
 */
native MHud_Movement_GetGroundTicks(client);

/**
 * Gets current speed for client from MovementHUD tracking
 *
 * @param client		Client index
 * @return				Speed of the client as float
 */
native Float:MHud_Movement_GetCurrentSpeed(client);

/**
 * Called when movement takeoff happens for a client
 *
 * @note				This is a single- hook!
 * @param client		Client index
 * @param didJump		Whether the takeoff was from a jump
 * @param didPerf		By-reference value of whether a perfect bunnyhop was done
 * @param takeoffSpeed	By-reference value of what the takeoff speed should be
 */
forward MHud_Movement_OnTakeoff(client, bool:didJump, &bool:didPerf, &Float:takeoffSpeed);

// ======================= PLUGIN INFO ======================= //

public SharedPlugin:__pl_MovementHUD =
{
	name = "MovementHUD",
	file = "MovementHUD.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_MovementHUD_SetNTVOptional()
{
	MarkNativeAsOptional("MHud_Movement_GetGroundTicks");
	MarkNativeAsOptional("MHud_Movement_GetCurrentSpeed");
}
#endif

// =========================================================== //
