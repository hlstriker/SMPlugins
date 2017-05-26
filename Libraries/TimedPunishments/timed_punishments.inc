#if defined _timed_punishments_included
 #endinput
#endif
#define _timed_punishments_included


public SharedPlugin:__pl_timed_punishments = 
{
	name = "timed_punishments",
	file = "API_TimedPunishments.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


// WARNING: Never comment out or change the order of this enum!!!
enum TimedPunishmentType
{
	TP_TYPE_MUTE = 0,
	TP_TYPE_GAG,
	TP_TYPE_CTBAN,
	TP_TYPE_BAN,
	NUM_TP_TYPES
};


#define MAX_REASON_LENGTH 255


native bool:TimedPunishment_AddPunishment(admin_id, client_id, TimedPunishmentType:punishment_type, punishment_time, const String:punishment_reason[], const String:client_auth_id[]="");
native bool:TimedPunishment_RemovePunishment(admin_id, const String:auth_id[], TimedPunishmentType:punishment_type);

native TimedPunishment_GetSecondsLeft(client_id, TimedPunishmentType:punishment_type);
native bool:TimedPunishment_GetReason(client_id, TimedPunishmentType:punishment_type, String:reason[], maxlength);


forward TimedPunishment_OnAllPunishmentsLoaded(client_id);
forward TimedPunishment_OnPunishmentLoaded(client_id, TimedPunishmentType:punishment_type, bool:is_perm, cur_unix_time, expires_unix_time, const String:reason[]);
forward TimedPunishment_OnPunishmentExpired(client_id, TimedPunishmentType:punishment_type);



#if !defined REQUIRE_PLUGIN
public __pl_timed_punishments_SetNTVOptional()
{
	MarkNativeAsOptional("TimedPunishment_AddPunishment");
	MarkNativeAsOptional("TimedPunishment_RemovePunishment");
	MarkNativeAsOptional("TimedPunishment_GetSecondsLeft");
	MarkNativeAsOptional("TimedPunishment_GetReason");
}
#endif