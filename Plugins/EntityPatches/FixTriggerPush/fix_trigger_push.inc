#if defined _fix_trigger_push_included
 #endinput
#endif
#define _fix_trigger_push_included


public SharedPlugin:__pl_fix_trigger_push = 
{
	name = "fix_trigger_push",
	file = "FixTriggerPush.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native TriggerPush_ResetCooldowns(client);



#if !defined REQUIRE_PLUGIN
public __pl_fix_trigger_push_SetNTVOptional()
{
	MarkNativeAsOptional("TriggerPush_ResetCooldowns");
}
#endif