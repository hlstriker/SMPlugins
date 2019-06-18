#if defined _ultjb_settings_included
 #endinput
#endif
#define _ultjb_settings_included


public SharedPlugin:__pl_ultjb_settings = 
{
	name = "ultjb_settings",
	file = "UltJB_Settings.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#include <cstrike>


// Auto respawn teams
#define ART_NONE		0
#define ART_BOTH		1
#define ART_PRISONERS	2
#define ART_GUARDS		3



/**
 * Properly strips a weapon from its owner.
 *
 * @param weapon				The weapon index that should be stripped.
 * @noreturn
 */
native UltJB_Settings_StripWeaponFromOwner(weapon);

/**
 * Starts auto-respawning players.
 *
 * @param reset_clients_respawn_limits			Should reset previous respawn timers limits?
 * @param num_allowed_respawns_per_client		How many respawns each client gets before it stops respawning them. 0 = unlimited
 * @param seconds_to_respawn_for				How many seconds to keep respawning before it auto shuts off. 0 = unlimited
 * @param team_allowed_to_respawn				The team(s) allowed to respawn.
 * @param disable_respawn_on_death				Should respawn be disabled for that player after they die?
 * @param disable_respawn_on_team_change		Should respawn be disabled for that player after they switch teams?
 * @noreturn
 */
native UltJB_Settings_StartAutoRespawning(bool:reset_clients_respawn_limits=false, num_allowed_respawns_per_client=0, seconds_to_respawn_for=0, team_allowed_to_respawn=ART_BOTH, bool:disable_respawn_on_death=false, bool:disable_respawn_on_team_change=true);

/**
 * Stops auto-respawning players.
 *
 * @noparam
 * @noreturn
 */
native UltJB_Settings_StopAutoRespawning();

/**
 * Sets the auto-respawn delay for team(s).
 * WARNING: This must be set after StartAutoRespawning is called.
 *
 * @param delay						The auto-respawn delay. Minimum of 0.1.
 * @param team_to_set_delay_for		The team to set this delay for.
 * @noreturn
 */
native UltJB_Settings_SetAutoRespawnDelay(Float:delay, team_to_set_delay_for=ART_BOTH);

/**
 * Sets if players are allowed to drop their weapons when they die.
 *
 * @param can_drop_weapons			True if allowed to drop weapons, false otherwise.
 * @noreturn
 */
native UltJB_Settings_SetWeaponDroppingOnDeath(bool:can_drop_weapons);

/**
 * Sets if the round termination should be blocked or not.
 *
 * @param block_terminate_round			True to block terminate round, false otherwise.
 * @noreturn
 */
native UltJB_Settings_BlockTerminateRound(bool:block_terminate_round);

/**
 * Sets the next terminate round reason.
 *
 * @param use_reason	True to use this reason, false to use default.
 * @param reason		The reason to use.
 * @noreturn
 */
native UltJB_Settings_SetNextRoundEndReason(bool:use_reason, CSRoundEndReason:reason=CSRoundEnd_Draw);



/**
 * Called after the client is prepared during OnSpawnPost.
 *
 * @param client			The client who was prepared.
 * @noreturn
 */
forward UltJB_Settings_OnSpawnPost(client);
