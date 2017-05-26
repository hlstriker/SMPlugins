#if defined _particle_manager_included
 #endinput
#endif
#define _particle_manager_included


public SharedPlugin:__pl_particle_manager = 
{
	name = "particle_manager",
	file = "API_ParticleManager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Precaches a particle effect.
 *
 * @param particle_filepath		The file path to the particle systems pcf file.
 * @param particle_effect		The name of the particle effect.
 * @noreturn
 */
native PM_PrecacheParticleEffect(const String:particle_filepath[], const String:particle_effect[]);

native PM_CreateEntityEffect(entity, const String:particle_effect[], attachment_point=0, bool:stop_prior_effects=false, const send_to_clients[]={}, num_send_to_clients=0);

native PM_CreateEntityEffectFollow(entity, const String:particle_effect[], attachment_point=0, bool:stop_prior_effects=false, const send_to_clients[]={}, num_send_to_clients=0);

native PM_CreateEntityEffectCustomOrigin(entity, const String:particle_effect[], const Float:origin[3], const Float:angles[3], const Float:cp_one_origin[3], bool:stop_prior_effects=false, const send_to_clients[]={}, num_send_to_clients=0);

native PM_CreateWorldEffect(const String:particle_effect[], const Float:origin[3], const Float:angles[3], const Float:cp_one_origin[3]);

native PM_StopEntityEffects(entity);



#if !defined REQUIRE_PLUGIN
public __pl_particle_manager_SetNTVOptional()
{
	MarkNativeAsOptional("PM_PrecacheParticleEffect");
	MarkNativeAsOptional("PM_CreateEntityEffect");
	MarkNativeAsOptional("PM_CreateEntityEffectFollow");
	MarkNativeAsOptional("PM_CreateEntityEffectCustomOrigin");
	MarkNativeAsOptional("PM_CreateWorldEffect");
	MarkNativeAsOptional("PM_StopEntityEffects");
}
#endif