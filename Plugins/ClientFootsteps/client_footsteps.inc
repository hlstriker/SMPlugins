#if defined _client_footsteps
 #endinput
#endif
#define _client_footsteps


public SharedPlugin:__pl_client_footsteps = 
{
	name = "client_footsteps",
	file = "ClientFootsteps.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



enum FootstepValue
{
	FOOTSTEP_VALUE_ENABLE_OWN_ONLY = 0,
	FOOTSTEP_VALUE_ENABLE_ALL,
	FOOTSTEP_VALUE_DISABLE_ALL,
	FOOTSTEP_VALUE_USE_SERVER_SETTINGS
};



native ClientFootsteps_SetValue(client, FootstepValue:value);
native FootstepValue:ClientFootsteps_GetValue(client);



#if !defined REQUIRE_PLUGIN
public __pl_client_footsteps_SetNTVOptional()
{
	MarkNativeAsOptional("ClientFootsteps_SetValue");
	MarkNativeAsOptional("ClientFootsteps_GetValue");
}
#endif