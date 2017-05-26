#if defined _speed_runs_teleport_included
 #endinput
#endif
#define _speed_runs_teleport_included


public SharedPlugin:__pl_speed_runs_teleport = 
{
	name = "speed_runs_teleport",
	file = "SpeedRuns_Teleport.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



forward Action:SpeedRunsTeleport_OnTeleport_Pre(client, stage_number);
forward SpeedRunsTeleport_OnTeleport_Post(client, stage_number);

forward SpeedRunsTeleport_OnRestart(client);
forward SpeedRunsTeleport_OnSendToSpawn(client);



native SpeedRunsTeleport_TeleportToStage(client, stage_number, bool:should_cancel_run=true);
native bool:SpeedRunsTeleport_IsAllowedToTeleport(client);



#if !defined REQUIRE_PLUGIN
public __pl_speed_runs_teleport_SetNTVOptional()
{
	MarkNativeAsOptional("SpeedRunsTeleport_TeleportToStage");
	MarkNativeAsOptional("SpeedRunsTeleport_IsAllowedToTeleport");
}
#endif