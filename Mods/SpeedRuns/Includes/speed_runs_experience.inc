#if defined _speed_runs_experience_included
 #endinput
#endif
#define _speed_runs_experience_included


public SharedPlugin:__pl_speed_runs_experience = 
{
	name = "speed_runs_experience",
	file = "SpeedRuns_Experience.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



forward SpeedRunsExp_OnExperienceGiven(client, amount);
forward SpeedRunsExp_OnLevelUp(client, old_level, new_level);



native SpeedRunsExp_GetClientLevel(client);
native SpeedRunsExp_GetClientExpInCurrentLevel(client);
native SpeedRunsExp_GetClientExpForNextLevel(client);
