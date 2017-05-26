#if defined _demo_sessions_included
 #endinput
#endif
#define _demo_sessions_included


public SharedPlugin:__pl_demo_sessions = 
{
	name = "demo_sessions",
	file = "API_DemoSessions.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


native DemoSessions_GetID();
native DemoSessions_GetCurrentTime();
native DemoSessions_GetCurrentTick();
native bool:DemoSessions_IsRecording();
