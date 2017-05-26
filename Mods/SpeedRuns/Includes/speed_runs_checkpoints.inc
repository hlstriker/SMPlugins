#if defined _speed_runs_checkpoints_included
 #endinput
#endif
#define _speed_runs_checkpoints_included


public SharedPlugin:__pl_speed_runs_checkpoints = 
{
	name = "speed_runs_checkpoints",
	file = "SpeedRuns_Checkpoints.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_speed_runs_checkpoints_SetNTVOptional()
{
	MarkNativeAsOptional("SpeedRunsCheckpoints_GetCountSaved");
	MarkNativeAsOptional("SpeedRunsCheckpoints_GetCountUsed");
	MarkNativeAsOptional("SpeedRunsCheckpoints_AreUsableDuringSpeedRun");
}
#endif


native SpeedRunsCheckpoints_GetCountSaved(client, stage_number);
native SpeedRunsCheckpoints_GetCountUsed(client, stage_number);

native SpeedRunsCheckpoints_AreUsableDuringSpeedRun();
