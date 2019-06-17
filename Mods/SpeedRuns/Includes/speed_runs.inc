#if defined _speed_runs_included
 #endinput
#endif
#define _speed_runs_included


public SharedPlugin:__pl_speed_runs = 
{
	name = "speed_runs",
	file = "SpeedRuns_Core.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define MAX_STAGES	256
#define DEFAULT_START_CAP_SPEED	"330"

// WARNING: Do not change the value for these defines.
#define GROUP_TYPE_NONE		0
#define GROUP_TYPE_SURF		1
#define GROUP_TYPE_BHOP		2
#define GROUP_TYPE_COURSE	3
#define GROUP_TYPE_KZ		4
#define GROUP_TYPE_ROCKET	5


enum _:Record
{
	Record_StageNumber,	// Stage 0 = entire map record.
	Record_StyleBits,
	Float:Record_StageTime
};

enum RecordType
{
	RT_StageForMap = 1,
	RT_StageForUser,
	RT_MapForMap,
	RT_MapForUser
};


forward Action:SpeedRuns_OnStageStarted_Pre(client, stage_number, style_bits);
forward SpeedRuns_OnStageStarted_Post(client, stage_number, style_bits);

forward SpeedRuns_OnStageCompleted_Pre(client, stage_number, style_bits, Float:time_taken);
forward SpeedRuns_OnStageCompleted_Post(client, stage_number, style_bits, Float:time_taken);

forward SpeedRuns_OnStageFailed(client, old_stage, new_stage);

forward SpeedRuns_OnRunStopped(client);

forward SpeedRuns_OnNewRecord(client, RecordType:record_type, old_record[Record], new_record[Record]);


native SpeedRuns_ClientTouchStart(client, start_number, iZoneID);
native SpeedRuns_ClientTouchEnd(client, end_number, bool:is_final_end);
native SpeedRuns_TryStageFailed(client, stage_number);

native SpeedRuns_TryCapSpeed(client, speed_cap);

native SpeedRuns_CancelRun(client, bool:cancel_stage_only=false);
native bool:SpeedRuns_PauseRun(client, bool:pause=true);
native bool:SpeedRuns_IsRunPaused(client);

native SpeedRuns_GetCurrentStage(client);
native bool:SpeedRuns_IsInTotalRun(client);

native Float:SpeedRuns_GetTotalRunTime(client);
native Float:SpeedRuns_GetStageRunTime(client);

native SpeedRuns_GetMapTier();
native SpeedRuns_GetMapTierMax();

native SpeedRuns_GetServerGroupType();


#if !defined REQUIRE_PLUGIN
public __pl_speed_runs_SetNTVOptional()
{
	MarkNativeAsOptional("SpeedRuns_ClientTouchStart");
	MarkNativeAsOptional("SpeedRuns_ClientTouchEnd");
	MarkNativeAsOptional("SpeedRuns_TryStageFailed");
	
	MarkNativeAsOptional("SpeedRuns_TryCapSpeed");
	
	MarkNativeAsOptional("SpeedRuns_CancelRun");
	MarkNativeAsOptional("SpeedRuns_PauseRun");
	MarkNativeAsOptional("SpeedRuns_IsRunPaused");
	
	MarkNativeAsOptional("SpeedRuns_GetCurrentStage");
	MarkNativeAsOptional("SpeedRuns_IsInTotalRun");

	MarkNativeAsOptional("SpeedRuns_GetTotalRunTime");
	MarkNativeAsOptional("SpeedRuns_GetStageRunTime");
	
	MarkNativeAsOptional("SpeedRuns_GetMapTier");
	MarkNativeAsOptional("SpeedRuns_GetMapTierMax");
	
	MarkNativeAsOptional("SpeedRuns_GetServerGroupType");
}
#endif
