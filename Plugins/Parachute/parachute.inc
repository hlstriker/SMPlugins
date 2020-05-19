#if defined _parachute_included
 #endinput
#endif
#define _parachute_included


public SharedPlugin:__pl_parachute = 
{
	name = "parachute",
	file = "Parachute.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native bool:Parachute_GiveParachute(client);
native bool:Parachute_RemoveParachute(client);
native bool:Parachute_HasParachute(client);



#if !defined REQUIRE_PLUGIN
public __pl_parachute_SetNTVOptional()
{
	MarkNativeAsOptional("Parachute_GiveParachute");
	MarkNativeAsOptional("Parachute_RemoveParachute");
	MarkNativeAsOptional("Parachute_HasParachute");
}
#endif