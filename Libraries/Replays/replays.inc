#if defined _replays_included
 #endinput
#endif
#define _replays_included


public SharedPlugin:__pl_replays =
{
	name = "replays",
	file = "API_Replays.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

enum ReplayMode
{
	REPLAY_RECORD = 0,
	REPLAY_FREEZE,
	REPLAY_REWIND,
  REPLAY_PLAYBACK
};

functag public Replays_Callback_LoadReplayToClient(client, replay_id, any:data);

/* forward Action:Replays_OnTick(client, &buttons, &impulse, Float:velocity[3], Float:angles[3], &weapon, &subtype, &cmd_num, &tick_count, &seed, mouse[2]); */
forward Replays_OnLoadTick_Pre(client, tick);

native Replays_GetTick(client);
native ReplayMode:Replays_GetMode(client);
native Replays_SetMode(client, ReplayMode:mode);
native Replays_SetBreakpoint(client, tick=-1);

native Replays_SaveReplay(client, start_tick, end_tick, Handle:transaction=INVALID_HANDLE);
native Replays_LoadReplayToClient(client, replay_id/*, Replays_Callback_LoadReplayToClient:callback*/);

// For SpeedRuns
native Float:Replays_GetAverageSpeed(client, start_tick, end_tick, bool:exclude_vertical);
