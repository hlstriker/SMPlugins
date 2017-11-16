#if defined _unsafe_gloves_included
 #endinput
#endif
#define _unsafe_gloves_included


public SharedPlugin:__pl_unsafe_gloves = 
{
	name = "unsafe_gloves",
	file = "Unsafe_Gloves.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


forward Action:Gloves_OnApply(client);
