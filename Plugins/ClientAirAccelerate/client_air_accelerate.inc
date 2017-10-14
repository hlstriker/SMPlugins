#if defined _client_air_accelerate
 #endinput
#endif
#define _client_air_accelerate


public SharedPlugin:__pl_client_air_accelerate = 
{
	name = "client_air_accelerate",
	file = "ClientAirAccelerate.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native ClientAirAccel_SetCustomValue(client, Float:value);
native ClientAirAccel_ClearCustomValue(client);



#if !defined REQUIRE_PLUGIN
public __pl_client_air_accelerate_SetNTVOptional()
{
	MarkNativeAsOptional("ClientAirAccel_SetCustomValue");
	MarkNativeAsOptional("ClientAirAccel_ClearCustomValue");
}
#endif