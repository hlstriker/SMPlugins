#if defined _squelch_manager_included
 #endinput
#endif
#define _squelch_manager_included


public SharedPlugin:__pl_squelch_manager = 
{
	name = "squelch_manager",
	file = "API_SquelchManager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define TIME_TO_SQUELCH_REMOVE		0
#define TIME_TO_SQUELCH_MAP_END		-1
#define TIME_TO_SQUELCH_ROUND_END	-2


forward SquelchManager_OnClientStartSpeaking(client);
forward SquelchManager_OnClientStopSpeaking(client);
forward SquelchManager_OnClientSpeaking(client);


native bool:SquelchManager_IsClientSpeaking(client);

native bool:SquelchManager_IsClientMutingTarget(client, target);
native bool:SquelchManager_IsClientGaggingTarget(client, target);

native bool:SquelchManager_SetClientMutingTarget(client, target, time_in_seconds);
native bool:SquelchManager_SetClientGaggingTarget(client, target, time_in_seconds);

/*
* return_if_listen_state_is_yes:
* 	If set to true and the clients listening state is forced to "yes" for the target, don't reapply the state (most likely another plugin forced it to yes).
* 	If set to false it will reapply the listening state no matter what the clients listening state is currently set to.
*/
native SquelchManager_ReapplyListeningState(client, target, return_if_listen_state_is_yes=false);



#if !defined REQUIRE_PLUGIN
public __pl_squelch_manager_SetNTVOptional()
{
	MarkNativeAsOptional("SquelchManager_IsClientSpeaking");
	MarkNativeAsOptional("SquelchManager_IsClientMutingTarget");
	MarkNativeAsOptional("SquelchManager_IsClientGaggingTarget");
	MarkNativeAsOptional("SquelchManager_SetClientMutingTarget");
	MarkNativeAsOptional("SquelchManager_SetClientGaggingTarget");
	MarkNativeAsOptional("SquelchManager_ReapplyListeningState");
}
#endif