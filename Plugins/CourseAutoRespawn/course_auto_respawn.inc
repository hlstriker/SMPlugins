#if defined _course_auto_respawn_included
 #endinput
#endif
#define _course_auto_respawn_included


public SharedPlugin:__pl_course_auto_respawn = 
{
	name = "course_auto_respawn",
	file = "CourseAutoRespawn.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



native bool:CourseAutoRespawn_IsAutoRespawnOn();



#if !defined REQUIRE_PLUGIN
public __pl_course_auto_respawn_SetNTVOptional()
{
	MarkNativeAsOptional("CourseAutoRespawn_IsAutoRespawnOn");
}
#endif