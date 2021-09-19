#if defined _speed_runs_replay_bot_included
 #endinput
#endif
#define _speed_runs_replay_bot_included


public SharedPlugin:__pl_speed_runs_replay_bot = 
{
	name = "speed_runs_replay_bot",
	file = "SpeedRuns_ReplayBot.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_speed_runs_replay_bot_SetNTVOptional()
{
	MarkNativeAsOptional("SpeedRunsReplayBot_PlayRecord");
	MarkNativeAsOptional("SpeedRunsReplayBot_IsClientReplayBot");
}
#endif

// returns the client index of the bot that will play the record.
native SpeedRunsReplayBot_PlayRecord(record_id);
native bool:SpeedRunsReplayBot_IsClientReplayBot(client);
