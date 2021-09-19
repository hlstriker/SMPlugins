#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <emitsoundany>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseUsers/database_users"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/ClientCookies/client_cookies"
#include "Includes/speed_runs_experience"
#include "Includes/speed_runs"
#include <hls_color_chat>
#include "../../Libraries/Replays/replays"

#undef REQUIRE_PLUGIN
#include "Includes/speed_runs_checkpoints"
#include "Includes/speed_runs_replay_bot"
#include "../../Plugins/EntityPatches/FixTriggerPush/fix_trigger_push"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#include "../../Libraries/DemoSessions/demo_sessions"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Core";
new const String:PLUGIN_VERSION[] = "1.44";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed run core plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bStageStarted[MAXPLAYERS+1];
new g_iStageCurrent[MAXPLAYERS+1];
new g_iStageLastCompleted[MAXPLAYERS+1];

new bool:g_bFirstStarted[MAXPLAYERS+1];
new g_iTickStartedFirst[MAXPLAYERS+1];
new g_iTickStartedCurrent[MAXPLAYERS+1];

new g_iDemoTickStarted[MAXPLAYERS+1][MAX_STAGES+1];

#define HUD_UPDATE_INTERVAL 0.1
#define HUD_UPDATE_INTERVAL_KEYHINT_DELAY 6.0
new Float:g_fNextHUDUpdate[MAXPLAYERS+1];

#define HUD_EXP_TIME	3.5
new Float:g_fExpHUDExpiration[MAXPLAYERS+1];
new g_iExpHUDAmount[MAXPLAYERS+1];

#define HUD_BEAT_MAP_TIME	5.0
new Float:g_fBeatMapHUDExpiration[MAXPLAYERS+1];

new String:g_szStageName[MAXPLAYERS+1][MAX_ZONE_DATA_STRING_LENGTH];

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

// Record variables.
new g_iUniqueMapCounter;
new bool:g_bAreMapRecordsLoaded;
new bool:g_bAreUserRecordsLoaded[MAXPLAYERS+1];

#define INVALID_RECORD_INDEX	-1
new Handle:g_aRecords[MAXPLAYERS+1];

new Handle:g_hFwd_OnStageStarted_Pre;
new Handle:g_hFwd_OnStageStarted_Post;
new Handle:g_hFwd_OnStageCompleted_Pre;
new Handle:g_hFwd_OnStageCompleted_Post;
new Handle:g_hFwd_OnStageFailed;
new Handle:g_hFwd_OnRunStopped;
new Handle:g_hFwd_OnNewRecord;

new HudDisplay:g_iHudDisplay[MAXPLAYERS+1];
enum HudDisplay
{
	HUD_NONE = 0,
	HUD_COMPARE_GLOBAL_TIMES,
	HUD_COMPARE_USER_TIMES
};

new g_iSoundBits[MAXPLAYERS+1];
#define SOUND_BITS_PLAY_ALL						0
#define SOUND_BITS_DISABLE_MAP_RECORDS			(1<<0)
#define SOUND_BITS_DISABLE_STAGE_RECORDS		(1<<1)
#define SOUND_BITS_DISABLE_OWN_MAP_RECORDS		(1<<2)
#define SOUND_BITS_DISABLE_OWN_STAGE_RECORDS	(1<<3)

#define TIER_MAX	6
new g_iMapTier;

enum HudColorType
{
	HUD_COLOR_TYPE_ACHIEVED = 0,
	HUD_COLOR_TYPE_LEVEL_EXP
};

new const HUD_TRANSITION_COLOR_START_ACHIEVED[] = {255, 131, 54};
new const HUD_TRANSITION_COLOR_END_ACHIEVED[] = {134, 255, 54};

new const HUD_TRANSITION_COLOR_START_LEVEL_EXP[] = {190, 255, 20};
new const HUD_TRANSITION_COLOR_END_LEVEL_EXP[] = {190, 255, 100};

#define HUD_COLOR_TRANSITION_TIME	0.75
new Float:g_fHUDColorStartTime[MAXPLAYERS+1];
new Float:g_fHUDColorEndTime[MAXPLAYERS+1];
new bool:g_bHUDColorDirection[MAXPLAYERS+1];

new g_iExpHUDArrayCount[MAXPLAYERS+1];
new g_iExpHUDArray[MAXPLAYERS+1][20];

new const String:g_szSoundsMapRecords[][] =
{
	"sound/swoobles/speed_runs/map_excellent.mp3",
	"sound/swoobles/speed_runs/map_impressive.mp3",
	"sound/swoobles/speed_runs/map_outstanding.mp3",
	"sound/swoobles/speed_runs/map_speed.mp3"
};

new const String:g_szSoundsUserRecords[][] =
{
	"sound/swoobles/speed_runs/user_damn_im_good.mp3",
	"sound/swoobles/speed_runs/user_hail_to_the_king_baby.mp3"
};

new const String:g_szSoundsStageRecords[][] =
{
	"sound/swoobles/speed_runs/stage_very_nice.mp3",
	"sound/swoobles/speed_runs/stage_whos_the_man.mp3"
};

new const String:g_szSoundsUserStageRecords[][] =
{
	"sound/swoobles/speed_runs/user_stage_clap.mp3"
};

new g_iJumpsMap[MAXPLAYERS+1];
new g_iJumpsStage[MAXPLAYERS+1];

new Handle:cvar_sr_group_name;
new g_iServerGroupType;

#define OBS_MODE_IN_EYE	4
#define OBS_MODE_CHASE	5

#define SOLID_BBOX		2
new g_iLastNonSolidTick[MAXPLAYERS+1];

new bool:g_bLibLoaded_CheckPoints;
new bool:g_bLibLoaded_ReplayBot;
new bool:g_bLibLoaded_FixTriggerPush;
new bool:g_bLibLoaded_ModelSkinManager;
new bool:g_bLibLoaded_DemoSessions;


public OnPluginStart()
{
	CreateConVar("speed_runs_core_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);

	if((cvar_sr_group_name = FindConVar("speedruns_group_name")) == INVALID_HANDLE)
		cvar_sr_group_name = CreateConVar("speedruns_group_name", "", "The group name to use for this server (applied on map change)");

	g_hFwd_OnStageStarted_Pre = CreateGlobalForward("SpeedRuns_OnStageStarted_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnStageStarted_Post = CreateGlobalForward("SpeedRuns_OnStageStarted_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

	g_hFwd_OnStageCompleted_Pre = CreateGlobalForward("SpeedRuns_OnStageCompleted_Pre", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float);
	g_hFwd_OnStageCompleted_Post = CreateGlobalForward("SpeedRuns_OnStageCompleted_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float);

	g_hFwd_OnStageFailed = CreateGlobalForward("SpeedRuns_OnStageFailed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnRunStopped = CreateGlobalForward("SpeedRuns_OnRunStopped", ET_Ignore, Param_Cell);

	g_hFwd_OnNewRecord = CreateGlobalForward("SpeedRuns_OnNewRecord", ET_Ignore, Param_Cell, Param_Cell, Param_Array, Param_Array);

	HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);
	HookEvent("player_jump", Event_PlayerJump_Post, EventHookMode_Post);

	RegConsoleCmd("sm_stop", OnCommandStop);
	RegConsoleCmd("sm_cancel", OnCommandStop);
	RegConsoleCmd("sm_tier", OnCommandTier);
	RegConsoleCmd("sm_maptier", OnCommandTier);

	RegConsoleCmd("sm_hud", OnCommandHUD);
	RegConsoleCmd("sm_sound", OnCommandSound);
	RegConsoleCmd("sm_sounds", OnCommandSound);

	RegAdminCmd("sm_settier", Command_SetTier, ADMFLAG_ROOT, "sm_settier <tier number> - Sets the maps tier.");

	HookUserMessage(GetUserMessageId("KeyHintText"), Msg_KeyHintText);
}

public Action:Msg_KeyHintText(UserMsg:msg_id, Handle:hMsg, const iPlayers[], iPlayersNum, bool:bReliable, bool:bInit)
{
	if(iPlayersNum < 1)
		return Plugin_Continue;

	static i, iClient, Float:fCurTime;
	fCurTime = GetGameTime();
	for(i=0; i<iPlayersNum; i++)
	{
		iClient = iPlayers[i];
		g_fNextHUDUpdate[iClient] = fCurTime + HUD_UPDATE_INTERVAL_KEYHINT_DELAY;
	}

	return Plugin_Continue;
}

public Action:Command_SetTier(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_settier <tier number>");
		return Plugin_Handled;
	}

	decl String:szTier[4];
	GetCmdArg(1, szTier, sizeof(szTier));
	new iTier = StringToInt(szTier);

	if(iTier < 0 || iTier > TIER_MAX)
	{
		ReplyToCommand(iClient, "[SM] Error: The tier must be between 0 and %i", TIER_MAX);
		return Plugin_Handled;
	}

	g_iMapTier = iTier;
	CPrintToChatAll("{lightgreen}-- {olive}The maps tier has been set to {lightred}%i{olive}.", g_iMapTier);

	decl String:szMapName[97];
	DBMaps_GetCurrentMapNameFormatted(szMapName, sizeof(szMapName));
	if(DB_EscapeString(g_szDatabaseConfigName, szMapName, szMapName, sizeof(szMapName)))
	{
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_High, _, "\
			INSERT INTO plugin_sr_map_tiers \
			(map_name, tier) \
			VALUES \
			('%s', %i) \
			ON DUPLICATE KEY UPDATE tier=%i",
			szMapName, g_iMapTier, g_iMapTier);
	}

	return Plugin_Handled;
}

public Action:OnCommandTier(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;

	CPrintToChat(iClient, "{lightgreen}-- {olive}This maps tier is {lightred}%i{olive}/{lightred}%i{olive}.", g_iMapTier, TIER_MAX);

	if(!g_iMapTier)
		CPrintToChat(iClient, "{lightgreen}-- {olive}Get an admin to set the tier!");

	return Plugin_Handled;
}

public Action:OnCommandSound(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;

	DisplayMenu_SoundSelect(iClient);

	return Plugin_Handled;
}

public Action:OnCommandHUD(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;

	DisplayMenu_HudSelect(iClient);

	return Plugin_Handled;
}

public Action:OnCommandStop(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;

	if(!g_bFirstStarted[iClient] && !g_bStageStarted[iClient])
		return Plugin_Handled;

	ResetSpeedRunVariables(iClient);
	CPrintToChat(iClient, "{lightgreen}-- {olive}Your run has been canceled.");

	return Plugin_Handled;
}

bool:Forward_OnStageStarted(iClient, iStageNumber, iStyleBits, bool:bIsPre)
{
	new Action:result;
	Call_StartForward(bIsPre ? g_hFwd_OnStageStarted_Pre : g_hFwd_OnStageStarted_Post);
	Call_PushCell(iClient);
	Call_PushCell(iStageNumber);
	Call_PushCell(iStyleBits);
	Call_Finish(result);

	if(bIsPre && result >= Plugin_Handled)
		return false;

	return true;
}

Forward_OnStageCompleted(iClient, iStageNumber, iStyleBits, Float:fTimeTaken, bool:bIsPre)
{
	decl result;
	Call_StartForward(bIsPre ? g_hFwd_OnStageCompleted_Pre : g_hFwd_OnStageCompleted_Post);
	Call_PushCell(iClient);
	Call_PushCell(iStageNumber);
	Call_PushCell(iStyleBits);
	Call_PushFloat(fTimeTaken);
	Call_Finish(result);
}

Forward_OnStageFailed(iClient, iOldStage, iNewStage)
{
	decl result;
	Call_StartForward(g_hFwd_OnStageFailed);
	Call_PushCell(iClient);
	Call_PushCell(iOldStage);
	Call_PushCell(iNewStage);
	Call_Finish(result);
}

Forward_OnRunStopped(iClient)
{
	decl result;
	Call_StartForward(g_hFwd_OnRunStopped);
	Call_PushCell(iClient);
	Call_Finish(result);
}

Forward_OnNewRecord(iClient, RecordType:iRecordType, const eOldRecord[Record], const eNewRecord[Record])
{
	decl result;
	Call_StartForward(g_hFwd_OnNewRecord);
	Call_PushCell(iClient);
	Call_PushCell(iRecordType);
	Call_PushArray(eOldRecord, Record);
	Call_PushArray(eNewRecord, Record);
	Call_Finish(result);
}

public Action:Event_PlayerDeath_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;

	if(!IsClientInGame(iClient))
		return;

	// TODO: If the server is course we still want to reset variables on death.
	// Don't reset timer on spawn/death anymore.
	//ResetSpeedRunVariables(iClient);
}

public Action:Event_PlayerTeam_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;

	if(!IsClientInGame(iClient))
		return;

	// Don't reset timer on spawn/death anymore.
	//ResetSpeedRunVariables(iClient);
}

public Action:Event_PlayerJump_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;

	if(!IsClientInGame(iClient))
		return;

	g_iJumpsMap[iClient]++;
	g_iJumpsStage[iClient]++;
}

public OnClientPutInServer(iClient)
{
	g_bAreUserRecordsLoaded[iClient] = false;

	if(g_aRecords[iClient] != INVALID_HANDLE)
		ClearArray(g_aRecords[iClient]);

	g_fNextHUDUpdate[iClient] = 0.0;
	g_fExpHUDExpiration[iClient] = 0.0;
	g_fBeatMapHUDExpiration[iClient] = 0.0;
	g_fHUDColorEndTime[iClient] = 0.0;
	g_iHudDisplay[iClient] = HUD_COMPARE_GLOBAL_TIMES;
	g_iSoundBits[iClient] = SOUND_BITS_PLAY_ALL;
	g_iLastNonSolidTick[iClient] = -1000;

	ResetSpeedRunVariables(iClient);

	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;

	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}

	// Don't reset timer on spawn/death anymore. I forget, was this due to unpausing?
	//ResetSpeedRunVariables(iClient);
}

HandleTouch_End(iClient, iStageNumber, bool:bIsFinalEnd)
{
	if(!(1 <= iClient <= MaxClients))
		return;

	if(Replays_GetMode(iClient) != REPLAY_RECORD)
		return;

	if(!IsPlayerAlive(iClient))
		return;

	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return;

	if(iStageNumber < 1)
		return;

	if(iStageNumber != g_iStageCurrent[iClient])
		return;

	if(!g_bStageStarted[iClient])
		return;

	StageCompleted(iClient, iStageNumber, bIsFinalEnd);
}

FillRecordStruct(iStageNumber, iStyleBits, Float:fStageTime, eRecord[Record])
{
	eRecord[Record_StageNumber] = iStageNumber;
	eRecord[Record_StyleBits] = iStyleBits;
	eRecord[Record_StageTime] = fStageTime;
}

DisplayBehindTime(iClient, iStageNumber, iStyleBits, Float:fTotalSeconds)
{
	decl iIndexGlobal, iIndexUser, eOldRecordGlobal[Record], eOldRecordUser[Record], eNewRecord[Record];
	FillRecordStruct(iStageNumber, iStyleBits, fTotalSeconds, eNewRecord);

	iIndexGlobal = GetRecordByStage(0, iStageNumber, iStyleBits, eOldRecordGlobal);
	iIndexUser = GetRecordByStage(iClient, iStageNumber, iStyleBits, eOldRecordUser);

	// Make sure we set INVALID_RECORD_INDEX so it doesn't show the improved by time if there was no previous record.
	if(iIndexGlobal == INVALID_RECORD_INDEX)
		eOldRecordGlobal[Record_StageNumber] = INVALID_RECORD_INDEX;

	// Make sure we set INVALID_RECORD_INDEX so it doesn't show the improved by time if there was no previous record.
	if(iIndexUser == INVALID_RECORD_INDEX)
		eOldRecordUser[Record_StageNumber] = INVALID_RECORD_INDEX;

	decl String:szBufferTimeGlobal[128], String:szBufferTimeUser[128];
	GetRecordTimeString(eOldRecordGlobal, eNewRecord, szBufferTimeGlobal, sizeof(szBufferTimeGlobal));
	GetRecordTimeString(eOldRecordUser, eNewRecord, szBufferTimeUser, sizeof(szBufferTimeUser));

	decl iMode;
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer) || !GetClientTeam(iPlayer) || IsFakeClient(iPlayer))
			continue;

		if(iPlayer != iClient)
		{
			iMode = GetEntProp(iPlayer, Prop_Send, "m_iObserverMode");
			if(iMode != OBS_MODE_IN_EYE && iMode != OBS_MODE_CHASE)
				continue;

			if(GetEntPropEnt(iPlayer, Prop_Send, "m_hObserverTarget") != iClient)
				continue;
		}

		if(g_iHudDisplay[iPlayer] == HUD_COMPARE_GLOBAL_TIMES)
		{
			if(iIndexGlobal == INVALID_RECORD_INDEX || fTotalSeconds < eOldRecordGlobal[Record_StageTime])
				continue;

			CPrintToChat(iPlayer, "{lightgreen}-- {lightred}%s {olive}time was %s{olive}.", iStageNumber ? g_szStageName[iClient] : "Map", szBufferTimeGlobal);
		}
		else
		{
			if((iPlayer == iClient) && (iIndexUser == INVALID_RECORD_INDEX || fTotalSeconds < eOldRecordUser[Record_StageTime]))
				continue;

			CPrintToChat(iPlayer, "{lightgreen}-- {lightred}%s {olive}time was %s{olive}.", iStageNumber ? g_szStageName[iClient] : "Map", szBufferTimeUser);
		}
	}
}

StageCompleted(iClient, iStageNumber, bool:bIsFinalEnd)
{
	new Float:fTotalSecondsMap = GetTotalRunTime(iClient);
	new Float:fTotalSecondsStage = GetStageRunTime(iClient);

	decl iIndex, eOldRecord[Record], eNewRecord[Record];
	new iStyleBits = MovementStyles_GetStyleBits(iClient);

	g_iStageLastCompleted[iClient] = iStageNumber;

	// Handle records.
	new bool:bStageRecordForMap, bool:bStageRecordForUser, bool:bMapRecordForMap, bool:bMapRecordForUser;

	Forward_OnStageCompleted(iClient, iStageNumber, iStyleBits, fTotalSecondsStage, true);

	// Is it a new stage record for the map?
	iIndex = GetRecordByStage(0, iStageNumber, iStyleBits, eOldRecord);
	if(iIndex == INVALID_RECORD_INDEX || fTotalSecondsStage < eOldRecord[Record_StageTime])
	{
		if(iIndex == INVALID_RECORD_INDEX)
			eOldRecord[Record_StageNumber] = INVALID_RECORD_INDEX; // Make sure we set INVALID_RECORD_INDEX so it doesn't show the improved by time if there was no previous record.

		FillRecordStruct(iStageNumber, iStyleBits, fTotalSecondsStage, eNewRecord);
		InsertRecord(iClient, RT_StageForMap, true, eOldRecord, eNewRecord);
		SetRecord(iClient, eNewRecord); // If it's a map record that means it's also this users user record. Set that here.

		bStageRecordForMap = true;
	}
	else
	{
		// Display behind time before inserting record. Don't display stage behind times for linear maps.
		if(!(iStageNumber == 1 && bIsFinalEnd))
			DisplayBehindTime(iClient, iStageNumber, iStyleBits, fTotalSecondsStage);

		// Is it a new stage record for the user?
		iIndex = GetRecordByStage(iClient, iStageNumber, iStyleBits, eOldRecord);
		if(iIndex == INVALID_RECORD_INDEX || fTotalSecondsStage < eOldRecord[Record_StageTime])
		{
			if(iIndex == INVALID_RECORD_INDEX)
				eOldRecord[Record_StageNumber] = INVALID_RECORD_INDEX; // Make sure we set INVALID_RECORD_INDEX so it doesn't show the improved by time if there was no previous record.

			FillRecordStruct(iStageNumber, iStyleBits, fTotalSecondsStage, eNewRecord);
			InsertRecord(iClient, RT_StageForUser, true, eOldRecord, eNewRecord);

			bStageRecordForUser = true;
		}
	}

	Forward_OnStageCompleted(iClient, iStageNumber, iStyleBits, fTotalSecondsStage, false);

	if(bIsFinalEnd && g_bFirstStarted[iClient])
	{
		Forward_OnStageCompleted(iClient, 0, iStyleBits, fTotalSecondsMap, true);

		g_fBeatMapHUDExpiration[iClient] = GetGameTime() + HUD_EXP_TIME + HUD_BEAT_MAP_TIME;

		// There's no sense showing the record text twice on linear maps.
		decl bool:bDisplayText;
		if(iStageNumber == 1)
			bDisplayText = false;
		else
			bDisplayText = true;

		// Is it a new map record for the map?
		iIndex = GetRecordByStage(0, 0, iStyleBits, eOldRecord);
		if(iIndex == INVALID_RECORD_INDEX || fTotalSecondsMap < eOldRecord[Record_StageTime])
		{
			if(iIndex == INVALID_RECORD_INDEX)
				eOldRecord[Record_StageNumber] = INVALID_RECORD_INDEX; // Make sure we set INVALID_RECORD_INDEX so it doesn't show the improved by time if there was no previous record.

			FillRecordStruct(0, iStyleBits, fTotalSecondsMap, eNewRecord);
			InsertRecord(iClient, RT_MapForMap, bDisplayText, eOldRecord, eNewRecord);
			SetRecord(iClient, eNewRecord); // If it's a map record that means it's also this users map record. Set that here.

			bMapRecordForMap = true;
		}
		else
		{
			// Display behind time before inserting record.
			DisplayBehindTime(iClient, 0, iStyleBits, fTotalSecondsMap);

			// Is it a new map record for the user?
			iIndex = GetRecordByStage(iClient, 0, iStyleBits, eOldRecord);
			if(iIndex == INVALID_RECORD_INDEX || fTotalSecondsMap < eOldRecord[Record_StageTime])
			{
				if(iIndex == INVALID_RECORD_INDEX)
					eOldRecord[Record_StageNumber] = INVALID_RECORD_INDEX; // Make sure we set INVALID_RECORD_INDEX so it doesn't show the improved by time if there was no previous record.

				FillRecordStruct(0, iStyleBits, fTotalSecondsMap, eNewRecord);
				InsertRecord(iClient, RT_MapForUser, bDisplayText, eOldRecord, eNewRecord);

				bMapRecordForUser = true;
			}
		}

		g_bFirstStarted[iClient] = false;

		Forward_OnStageCompleted(iClient, 0, iStyleBits, fTotalSecondsMap, false);
	}

	// Play sounds
	if(bMapRecordForMap)
	{
		EmitRecordSoundToAll(g_szSoundsMapRecords[GetRandomInt(0, sizeof(g_szSoundsMapRecords)-1)][6], SOUND_BITS_DISABLE_MAP_RECORDS);
	}
	else if(bMapRecordForUser)
	{
		if(!(g_iSoundBits[iClient] & SOUND_BITS_DISABLE_OWN_MAP_RECORDS))
			EmitSoundToClientAny(iClient, g_szSoundsUserRecords[GetRandomInt(0, sizeof(g_szSoundsUserRecords)-1)][6], _, _, SNDLEVEL_NONE, _, _, SNDPITCH_NORMAL);
	}
	else if(bStageRecordForMap)
	{
		EmitRecordSoundToAll(g_szSoundsStageRecords[GetRandomInt(0, sizeof(g_szSoundsStageRecords)-1)][6], SOUND_BITS_DISABLE_STAGE_RECORDS);
	}
	else if(bStageRecordForUser)
	{
		if(!(g_iSoundBits[iClient] & SOUND_BITS_DISABLE_OWN_STAGE_RECORDS))
			EmitSoundToClientAny(iClient, g_szSoundsUserStageRecords[GetRandomInt(0, sizeof(g_szSoundsUserStageRecords)-1)][6], _, _, SNDLEVEL_NONE, _, _, SNDPITCH_NORMAL);
	}

	// Reinitialize the same stage just incase the player attempts it again.
	StageInit(iClient, iStageNumber);
}

EmitRecordSoundToAll(const String:szSound[], iDisabledBitToCheck)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;

		if(g_iSoundBits[iClient] & iDisabledBitToCheck)
			continue;

		EmitSoundToClientAny(iClient, szSound, _, _, SNDLEVEL_NONE, _, _, SNDPITCH_NORMAL);
	}
}

Float:GetAverageSpeed(iClient, bool:bGetStageSpeed=true)
{
	new bool:bExcludeVertical = (g_iServerGroupType != GROUP_TYPE_SURF && g_iServerGroupType != GROUP_TYPE_ROCKET);
	if(bGetStageSpeed)
	{
		return Replays_GetAverageSpeed(iClient, g_iTickStartedCurrent[iClient], Replays_GetTick(iClient), bExcludeVertical);
	}
	else
	{
		return Replays_GetAverageSpeed(iClient, g_iTickStartedFirst[iClient], Replays_GetTick(iClient), bExcludeVertical);
	}
}

InsertRecord(iClient, RecordType:iRecordType, bool:bDisplayText, const eOldRecord[Record], const eNewRecord[Record])
{
	new Handle:hDatabase = DB_GetDatabaseHandleFromConnectionName(g_szDatabaseConfigName);
	if(hDatabase == INVALID_HANDLE)
		return;
		
	new iStartTick = -1;
	if (eNewRecord[Record_StageNumber] == 0)
		iStartTick = g_iTickStartedFirst[iClient];
	else
		iStartTick = g_iTickStartedCurrent[iClient];

	new iEndTick = Replays_GetTick(iClient);
	
	new Handle:hTransaction = SQL_CreateTransaction();
	
	if (Replays_SaveReplay(iClient, iStartTick, iEndTick, hTransaction))
		CPrintToChat(iClient, "{lightgreen}-- {olive}Saving replay.");
	else
		CPrintToChat(iClient, "{lightgreen}-- {lightred}Sorry, your replay was unable to be saved, or there was an error.");
	
	decl iCheckPointsSaved, iCheckPointsUsed;
	if(g_bLibLoaded_CheckPoints)
	{
		iCheckPointsSaved = SpeedRunsCheckpoints_GetCountSaved(iClient, eNewRecord[Record_StageNumber]);
		iCheckPointsUsed = SpeedRunsCheckpoints_GetCountUsed(iClient, eNewRecord[Record_StageNumber]);
	}
	else
	{
		iCheckPointsSaved = -1;
		iCheckPointsUsed = -1;
	}
	
	new iDemoTick = 0;
	new iDemoID = 0;

	if (g_bLibLoaded_DemoSessions)
	{
		#if defined _demo_sessions_included
		iDemoTick = DemoSessions_GetCurrentTick();
		iDemoID = DemoSessions_GetID();
		#endif
	}
	
	decl String:szQuery[2048];

	FormatEx(szQuery, sizeof(szQuery), "\
		INSERT INTO plugin_sr_records \
		(user_id, server_group_type, server_id, map_id, stage_number, stage_time, demo_sess_id, demo_tick_start, demo_tick_end, data_int_1, data_int_2, style_bits, checkpoints_saved, checkpoints_used, utime_complete, replay_id) \
		VALUES \
		(%i, %i, %i, %i, %i, %f, %i, %i, %i, %i, %i, %i, %i, %i, UNIX_TIMESTAMP(), LAST_INSERT_ID())",
		DBUsers_GetUserID(iClient), g_iServerGroupType, DBServers_GetServerID(), DBMaps_GetMapID(), eNewRecord[Record_StageNumber], eNewRecord[Record_StageTime], iDemoID,
		g_iDemoTickStarted[iClient][eNewRecord[Record_StageNumber]], iDemoTick,
		eNewRecord[Record_StageNumber] ? RoundFloat(GetAverageSpeed(iClient, true)) : RoundFloat(GetAverageSpeed(iClient, false)),
		eNewRecord[Record_StageNumber] ? g_iJumpsStage[iClient] : g_iJumpsMap[iClient], MovementStyles_GetStyleBits(iClient), iCheckPointsSaved, iCheckPointsUsed);

	SQL_AddQuery(hTransaction, szQuery);
	SQL_ExecuteTransaction(hDatabase, hTransaction, _, Query_InsertRecord_Failure, _, DBPrio_High);

	if(bDisplayText)
	{
		new iBufferStyleLen;
		decl String:szBufferTime[255], String:szBufferStyles[255];
		GetRecordTimeString(eOldRecord, eNewRecord, szBufferTime, sizeof(szBufferTime));

		new Handle:hStyleNames, bool:bHasStyles, iTotalStylesRegistered;
		hStyleNames = CreateArray(MAX_STYLE_NAME_LENGTH);
		bHasStyles = MovementStyles_GetStyleNames(iClient, hStyleNames);
		iTotalStylesRegistered = MovementStyles_GetTotalStylesRegistered() - 1; // Subtract 1 because it returns the "None" style.

		if(bHasStyles || iTotalStylesRegistered)
		{
			iBufferStyleLen += Format(szBufferStyles[iBufferStyleLen], sizeof(szBufferStyles)-iBufferStyleLen, "{lightgreen}-- {olive}Style bracket: ");

			if(bHasStyles)
			{
				decl String:szStyleName[MAX_STYLE_NAME_LENGTH], i;
				for(i=0; i<GetArraySize(hStyleNames); i++)
				{
					GetArrayString(hStyleNames, i, szStyleName, sizeof(szStyleName));

					if(i != 0)
						iBufferStyleLen += Format(szBufferStyles[iBufferStyleLen], sizeof(szBufferStyles)-iBufferStyleLen, "{olive}, ");

					iBufferStyleLen += Format(szBufferStyles[iBufferStyleLen], sizeof(szBufferStyles)-iBufferStyleLen, "{blue}%s", szStyleName);
				}
			}
			else
			{
				iBufferStyleLen += Format(szBufferStyles[iBufferStyleLen], sizeof(szBufferStyles)-iBufferStyleLen, "{blue}None");
			}

			iBufferStyleLen += Format(szBufferStyles[iBufferStyleLen], sizeof(szBufferStyles)-iBufferStyleLen, "{olive}.");
		}

		if(hStyleNames != INVALID_HANDLE)
			CloseHandle(hStyleNames);

		decl String:szClientName[22]; // Use this so we can trim clients with long names so their name doesnt create 2 lines.
		GetClientName(iClient, szClientName, sizeof(szClientName));
		szClientName[sizeof(szClientName)-1] = '\x0';

		switch(iRecordType)
		{
			case RT_StageForMap:
			{
				CPrintToChatAll("{lightred}---------------");
				CPrintToChatAll("{lightgreen}-- {lightred}%s {olive}set a new {lightred}%s {olive}record!", szClientName, g_szStageName[iClient]);
				CPrintToChatAll("{lightgreen}-- {olive}Time was %s{olive}.", szBufferTime);

				if(iBufferStyleLen)
					CPrintToChatAll(szBufferStyles);

				if(g_bLibLoaded_CheckPoints && SpeedRunsCheckpoints_AreUsableDuringSpeedRun())
					CPrintToChatAll("{lightgreen}-- {olive}Checkpoints used: {lightred}%i{olive} / {lightred}%i{olive}.", iCheckPointsUsed, iCheckPointsSaved);
			}
			case RT_MapForMap:
			{
				CPrintToChatAll("{lightred}---------------");
				CPrintToChatAll("{lightgreen}-- {lightred}%s {olive}set a new {lightred}Map {olive}record!", szClientName);
				CPrintToChatAll("{lightgreen}-- {olive}Time was %s{olive}.", szBufferTime);

				if(iBufferStyleLen)
					CPrintToChatAll(szBufferStyles);

				if(g_bLibLoaded_CheckPoints && SpeedRunsCheckpoints_AreUsableDuringSpeedRun())
					CPrintToChatAll("{lightgreen}-- {olive}Checkpoints used: {lightred}%i{olive} / {lightred}%i{olive}.", iCheckPointsUsed, iCheckPointsSaved);
			}
			case RT_StageForUser:
			{
				CPrintToChat(iClient, "{lightred}---------------");
				CPrintToChat(iClient, "{lightgreen}-- {olive}New personal {lightred}%s {olive}record!", g_szStageName[iClient]);
				CPrintToChat(iClient, "{lightgreen}-- {olive}Time was %s{olive}.", szBufferTime);

				if(iBufferStyleLen)
					CPrintToChat(iClient, szBufferStyles);

				if(g_bLibLoaded_CheckPoints && SpeedRunsCheckpoints_AreUsableDuringSpeedRun())
					CPrintToChat(iClient, "{lightgreen}-- {olive}Checkpoints used: {lightred}%i{olive} / {lightred}%i{olive}.", iCheckPointsUsed, iCheckPointsSaved);
			}
			case RT_MapForUser:
			{
				CPrintToChat(iClient, "{lightred}---------------");
				CPrintToChat(iClient, "{lightgreen}-- {olive}New personal {lightred}Map {olive}record!");
				CPrintToChat(iClient, "{lightgreen}-- {olive}Time was %s{olive}.", szBufferTime);

				if(iBufferStyleLen)
					CPrintToChat(iClient, szBufferStyles);

				if(g_bLibLoaded_CheckPoints && SpeedRunsCheckpoints_AreUsableDuringSpeedRun())
					CPrintToChat(iClient, "{lightgreen}-- {olive}Checkpoints used: {lightred}%i{olive} / {lightred}%i{olive}.", iCheckPointsUsed, iCheckPointsSaved);
			}
		}
	}

	// Make sure the new record is saved to its correct variable.
	switch(iRecordType)
	{
		case RT_StageForMap:	SetRecord(0, eNewRecord);
		case RT_MapForMap:		SetRecord(0, eNewRecord);
		case RT_StageForUser:	SetRecord(iClient, eNewRecord);
		case RT_MapForUser:		SetRecord(iClient, eNewRecord);
	}

	Forward_OnNewRecord(iClient, iRecordType, eOldRecord, eNewRecord);
}

public Query_InsertRecord_Failure(Handle:db, any:data, numQueries, const String:error[], failIndex, any:queryData[])
{
	PrintToServer("FAILED TO INSERT RECORD: %s", error);
}

GetRecordTimeString(const eOldRecord[Record], const eNewRecord[Record], String:szBuffer[], iMaxLength)
{
	new iTotalSeconds = RoundToFloor(eNewRecord[Record_StageTime]);
	new iHour = (iTotalSeconds / 3600) % 24;
	new iMinute = (iTotalSeconds / 60) % 60;
	new iSecond = iTotalSeconds % 60;

	decl String:szDecimal[16], iPos;
	FloatToString(eNewRecord[Record_StageTime], szDecimal, sizeof(szDecimal));

	iPos = StrContains(szDecimal, ".");
	if(iPos != -1)
	{
		Format(szDecimal, sizeof(szDecimal), "%s", szDecimal[iPos+1]);
	}
	else
	{
		strcopy(szDecimal, sizeof(szDecimal), "000000");
	}

	new iLen;
	iLen += Format(szBuffer[iLen], iMaxLength-iLen, "{yellow}");

	if(iHour)
		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iHour);

	if(iMinute)
		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iMinute);

	iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i.%s", iSecond, szDecimal);

	if(eOldRecord[Record_StageNumber] != INVALID_RECORD_INDEX)
	{
		new Float:fTimeDifference = eOldRecord[Record_StageTime] - eNewRecord[Record_StageTime];

		if(fTimeDifference > 0.0)
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "{olive}. Improved by {yellow}");
		else
		{
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "{olive}. Behind by {purple}");

			if(fTimeDifference != 0.0)
				fTimeDifference *= -1;
		}

		iTotalSeconds = RoundToFloor(fTimeDifference);
		iHour = (iTotalSeconds / 3600) % 24;
		iMinute = (iTotalSeconds / 60) % 60;
		iSecond = iTotalSeconds % 60;

		FloatToString(fTimeDifference, szDecimal, sizeof(szDecimal));
		iPos = StrContains(szDecimal, ".");
		if(iPos != -1)
		{
			Format(szDecimal, sizeof(szDecimal), "%s", szDecimal[iPos+1]);
		}
		else
		{
			strcopy(szDecimal, sizeof(szDecimal), "000000");
		}

		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "");

		if(iHour)
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iHour);

		if(iMinute)
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iMinute);

		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i.%s", iSecond, szDecimal);
	}

	return iLen;
}

HandleTouch_Start(iClient, iStageNumber, iZoneID)
{
	if(!(1 <= iClient <= MaxClients))
		return;

	if(Replays_GetMode(iClient) != REPLAY_RECORD)
		return;

	if(!IsPlayerAlive(iClient))
		return;

	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return;

	// Don't let the client touch a start zone for a few frames after their solid type changes from non-solid.
	// The reason is if a player's solid type goes non-solid while they are standing in a start zone, then they leave the start zone and go solid again, the zones OnEndTouch is activated even when far away from the zone itself.
	if(g_iLastNonSolidTick[iClient] + 5 > GetGameTickCount())
		return;

	if(g_iServerGroupType == GROUP_TYPE_NONE)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Have the server owner set a group name.");
		return;
	}

	if(!g_bAreMapRecordsLoaded)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Please wait for the database to finish loading map data.");
		return;
	}

	if(!g_bAreUserRecordsLoaded[iClient])
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Please wait for the database to finish loading your data.");
		return;
	}

	if(iStageNumber < 1)
		return;

	if(iStageNumber != g_iStageCurrent[iClient])
		StageInit(iClient, iStageNumber);

	StageStart(iClient, iStageNumber, iZoneID);
}

TryStageFailed(iClient, iStageNumber)
{
	if(!(1 <= iClient <= MaxClients))
		return;

	if(Replays_GetMode(iClient) != REPLAY_RECORD)
		return;

	if(!g_bStageStarted[iClient])
		return;

	// The code would stop the stage run if you entered the start zone.
	// This was bad because it would stop the run on players even if they wanted to go back using a checkpoint.
	// Only run the code if the checkpoints plugin is not loaded, or if it is loaded but checkpoints aren't usable during a run.
	if(!g_bLibLoaded_CheckPoints || (g_bLibLoaded_CheckPoints && !SpeedRunsCheckpoints_AreUsableDuringSpeedRun()))
	{
		if(iStageNumber == 1)
		{
			g_bFirstStarted[iClient] = false;
			g_bStageStarted[iClient] = false;

			if(g_bLibLoaded_FixTriggerPush)
				TriggerPush_ResetCooldowns(iClient);

			Forward_OnStageFailed(iClient, g_iStageCurrent[iClient], iStageNumber);
		}
		else if(iStageNumber == g_iStageCurrent[iClient])
		{
			g_bStageStarted[iClient] = false;

			if(g_bLibLoaded_FixTriggerPush)
				TriggerPush_ResetCooldowns(iClient);

			Forward_OnStageFailed(iClient, g_iStageCurrent[iClient], iStageNumber);
		}
	}
}

StageInit(iClient, iStageNumber)
{
	g_bStageStarted[iClient] = false;

	if(iStageNumber >= MAX_STAGES)
		return;

	g_iStageCurrent[iClient] = iStageNumber;
}

StageStart(iClient, iStageNumber, iZoneID)
{
	if(iStageNumber >= MAX_STAGES)
		return;

	new iStyleBits = MovementStyles_GetStyleBits(iClient);
	if(!Forward_OnStageStarted(iClient, iStageNumber, iStyleBits, true))
		return;
	
	new iDemoTick = 0;

	if (g_bLibLoaded_DemoSessions)
	{
		#if defined _demo_sessions_included
		iDemoTick = DemoSessions_GetCurrentTick();
		#endif
	}

	g_bStageStarted[iClient] = true;
	g_iTickStartedCurrent[iClient] = Replays_GetTick(iClient);
	g_iDemoTickStarted[iClient][iStageNumber] = iDemoTick;
	g_iJumpsStage[iClient] = 0;
	
	if(iStageNumber == 1)
	{
		g_bFirstStarted[iClient] = true;
		g_iTickStartedFirst[iClient] = g_iTickStartedCurrent[iClient];
		g_iDemoTickStarted[iClient][0] = iDemoTick;
		g_iStageLastCompleted[iClient] = 0;
		g_iJumpsMap[iClient] = 0;
	}
	else if(iStageNumber > (g_iStageLastCompleted[iClient] + 1))
	{
		// Cancel the total speed run if the player somehow skipped a stage.
		if(g_bFirstStarted[iClient])
		{
			CPrintToChat(iClient, "{lightgreen}-- {yellow}Note: {olive}Your map run was canceled for skipping a stage.");
			CPrintToChat(iClient, "{lightgreen}-- {yellow}Note: {olive}Continue with stage records or restart from stage 1.");
			g_bFirstStarted[iClient] = false;
		}
	}

	g_fNextHUDUpdate[iClient] = 0.0;

	if(!ZoneManager_GetDataString(iZoneID, 1, g_szStageName[iClient], sizeof(g_szStageName[])) || !g_szStageName[iClient][0])
		FormatEx(g_szStageName[iClient], sizeof(g_szStageName[]), "Stage %i", iStageNumber);

	Forward_OnStageStarted(iClient, iStageNumber, iStyleBits, false);
}

ResetSpeedRunVariables(iClient)
{
	Forward_OnRunStopped(iClient);

	g_bFirstStarted[iClient] = false;
	g_bStageStarted[iClient] = false;

	g_iStageCurrent[iClient] = 0;
	g_iStageLastCompleted[iClient] = 0;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("speed_runs");

	CreateNative("SpeedRuns_ClientTouchStart", _SpeedRuns_ClientTouchStart);
	CreateNative("SpeedRuns_ClientTouchEnd", _SpeedRuns_ClientTouchEnd);
	CreateNative("SpeedRuns_TryStageFailed", _SpeedRuns_TryStageFailed);
	CreateNative("SpeedRuns_TryCapSpeed", _SpeedRuns_TryCapSpeed);
	CreateNative("SpeedRuns_CancelRun", _SpeedRuns_CancelRun);
	CreateNative("SpeedRuns_GetCurrentStage", _SpeedRuns_GetCurrentStage);
	CreateNative("SpeedRuns_IsInTotalRun", _SpeedRuns_IsInTotalRun);
	CreateNative("SpeedRuns_GetTotalRunTime", _SpeedRuns_GetTotalRunTime);
	CreateNative("SpeedRuns_GetStageRunTime", _SpeedRuns_GetStageRunTime);

	CreateNative("SpeedRuns_GetMapTier", _SpeedRuns_GetMapTier);
	CreateNative("SpeedRuns_GetMapTierMax", _SpeedRuns_GetMapTierMax);

	CreateNative("SpeedRuns_GetServerGroupType", _SpeedRuns_GetServerGroupType);

	return APLRes_Success;
}

public _SpeedRuns_GetServerGroupType(Handle:hPlugin, iNumParams)
{
	return g_iServerGroupType;
}

public _SpeedRuns_IsInTotalRun(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRuns_IsInTotalRun");
		return false;
	}

	return g_bFirstStarted[GetNativeCell(1)];
}

public _SpeedRuns_GetMapTier(Handle:hPlugin, iNumParams)
{
	return g_iMapTier;
}

public _SpeedRuns_GetMapTierMax(Handle:hPlugin, iNumParams)
{
	return TIER_MAX;
}

public _SpeedRuns_GetCurrentStage(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRuns_GetCurrentStage");
		return 0;
	}

	new iClient = GetNativeCell(1);

	if(!g_bStageStarted[iClient])
		return 0;

	return g_iStageCurrent[iClient];
}

Float:GetTotalRunTime(iClient)
{
	if (!g_bFirstStarted[iClient])
		return 0.0;

	return (Replays_GetTick(iClient) - g_iTickStartedFirst[iClient]) * GetTickInterval();
}

public _SpeedRuns_GetTotalRunTime(Handle:hPlugin, iNumParams)
{
	if (iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRuns_GetTotalRunTime");
		return _:0.0;
	}

	return _:GetTotalRunTime(GetNativeCell(1));
}

Float:GetStageRunTime(iClient)
{
	if (!g_bStageStarted[iClient])
		return 0.0;

	return (Replays_GetTick(iClient) - g_iTickStartedCurrent[iClient]) * GetTickInterval();
}

public _SpeedRuns_GetStageRunTime(Handle:hPlugin, iNumParams)
{
	if (iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRuns_GetStageRunTime");
		return _:0.0;
	}

	return _:GetStageRunTime(GetNativeCell(1));
}


public _SpeedRuns_CancelRun(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 1 || iNumParams > 2)
	{
		LogError("Invalid number of parameters SpeedRuns_CancelRun");
		return;
	}

	if(iNumParams > 1)
	{
		// Cancel stage only?
		if(GetNativeCell(2))
		{
			g_bStageStarted[GetNativeCell(1)] = false;
			return;
		}
	}

	ResetSpeedRunVariables(GetNativeCell(1));
}

public _SpeedRuns_TryCapSpeed(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters SpeedRuns_TryCapSpeed");
		return;
	}

	TryCapSpeed(GetNativeCell(1), float(GetNativeCell(2)));
}

TryCapSpeed(iClient, Float:fSpeedCap)
{
	if(fSpeedCap == -1.0)
		return;

	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return;

	if(MovementStyles_GetStyleBits(iClient) & STYLE_BIT_NO_SPEED_CAP)
		return;

	if(fSpeedCap <= 0.0)
	{
		TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
		return;
	}

	static Float:fVelocity[3], Float:fSpeed;
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);

	// Don't cap speed if we are only over the cap by moving up and down.
	static Float:fVerticalVelocity;
	fVerticalVelocity = fVelocity[2];
	fVelocity[2] = 0.0;
	fSpeed = GetVectorLength(fVelocity);
	if(fSpeed <= fSpeedCap)
		return;
	static Float:fPercent;
	fPercent = fSpeedCap / fSpeed;  //Find proportion of speed cap to player's XY plane speed
	fVelocity[0] = fVelocity[0] * fPercent;  //Multiply player's XY plane speed by that proportion, making it equal to the speed cap
	fVelocity[1] = fVelocity[1] * fPercent;
	fVelocity[2] = fVerticalVelocity; // Don't cap vertical velocity.

	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fVelocity);
}

public _SpeedRuns_TryStageFailed(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return;
	}

	TryStageFailed(GetNativeCell(1), GetNativeCell(2));
}

public _SpeedRuns_ClientTouchStart(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return;
	}

	HandleTouch_Start(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public _SpeedRuns_ClientTouchEnd(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return;
	}

	HandleTouch_End(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public OnPreThinkPost(iClient)
{
	if(IsClientSourceTV(iClient))
		return;

	if(GetEntProp(iClient, Prop_Send, "m_nSolidType") != SOLID_BBOX)
		g_iLastNonSolidTick[iClient] = GetGameTickCount();

	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
	{
		if(g_bFirstStarted[iClient] || g_bStageStarted[iClient])
		{
			ResetSpeedRunVariables(iClient);
			CPrintToChat(iClient, "{lightgreen}-- {olive}Your run has been canceled for invalid movetype.");
		}
	}

	CheckDisplayHUD(iClient);
}

CheckDisplayHUD(iClient)
{
	if(g_iHudDisplay[iClient] == HUD_NONE)
		return;

	if(IsVoteInProgress())
		return;

	if(ZoneManager_IsInZoneMenu(iClient))
		return;

	static Float:fCurTime;
	fCurTime = GetGameTime();

	if(fCurTime < g_fNextHUDUpdate[iClient])
		return;

	g_fNextHUDUpdate[iClient] = fCurTime + HUD_UPDATE_INTERVAL;

	if(fCurTime < g_fExpHUDExpiration[iClient])
	{
		ShowExperienceHUD(iClient);
		return;
	}

	if(fCurTime < g_fBeatMapHUDExpiration[iClient])
	{
		ShowBeatMapHUD(iClient);
		return;
	}

	if(IsPlayerAlive(iClient))
		ShowTimerHUD(iClient);
	else
		ShowSpecHUD(iClient);
}

ShowSpecHUD(iClient)
{
	static iMode;
	iMode = GetEntProp(iClient, Prop_Send, "m_iObserverMode");
	if(iMode != OBS_MODE_IN_EYE && iMode != OBS_MODE_CHASE)
		return;

	static iTarget;
	iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");

	if(!(1 <= iTarget <= MaxClients))
		return;

	if(!IsPlayerAlive(iTarget))
		return;

	static String:szBuffer[255], iLen;
	iLen = GetTimerHUD(iTarget, szBuffer, sizeof(szBuffer), g_iHudDisplay[iClient]);

	if(iLen)
		PrintHintText(iClient, szBuffer);
}

ShowBeatMapHUD(iClient)
{
	static iColor[3];
	CalculateHUDColor(iClient, iColor, HUD_COLOR_TYPE_ACHIEVED);

	static String:szRed[3], String:szGreen[3], String:szBlue[3];
	ColorDecimalToHex(iColor[0], szRed, sizeof(szRed));
	ColorDecimalToHex(iColor[1], szGreen, sizeof(szGreen));
	ColorDecimalToHex(iColor[2], szBlue, sizeof(szBlue));

	static String:szBuffer[255], iLen;
	iLen = 0;

	iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "<font size='25' color='#%s%s%s'>Congratulations!\nYou beat the map!</font>", szRed, szGreen, szBlue);

	if(iLen)
		PrintHintText(iClient, szBuffer);
}

public SpeedRunsExp_OnLevelUp(iClient, iOldLevel, iNewLevel)
{
	for(new iLevel=iOldLevel+1; iLevel<=iNewLevel; iLevel++)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}You have reached {lightred}level %i{olive}.", iLevel);
	}
}

public SpeedRunsExp_OnExperienceGiven(iClient, iAmount)
{
	new Float:fCurTime = GetGameTime();

	if(fCurTime > g_fExpHUDExpiration[iClient])
	{
		g_iExpHUDAmount[iClient] = iAmount;
		g_iExpHUDArrayCount[iClient] = 0;
	}
	else
		g_iExpHUDAmount[iClient] += iAmount;

	g_iExpHUDArray[iClient][g_iExpHUDArrayCount[iClient]++] = iAmount;

	g_fHUDColorStartTime[iClient] = fCurTime;
	g_fHUDColorEndTime[iClient] = fCurTime + HUD_COLOR_TRANSITION_TIME;

	g_fExpHUDExpiration[iClient] = fCurTime + HUD_EXP_TIME;
	g_fNextHUDUpdate[iClient] = 0.0;
}

ShowExperienceHUD(iClient)
{
	static iColor[3];
	CalculateHUDColor(iClient, iColor, HUD_COLOR_TYPE_ACHIEVED);

	static String:szRed[3], String:szGreen[3], String:szBlue[3];
	ColorDecimalToHex(iColor[0], szRed, sizeof(szRed));
	ColorDecimalToHex(iColor[1], szGreen, sizeof(szGreen));
	ColorDecimalToHex(iColor[2], szBlue, sizeof(szBlue));

	static String:szBuffer[255], iLen, i;
	iLen = 0;

	if(g_iExpHUDArrayCount[iClient] == 1)
	{
		iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "<font size='11' color='#%s%s%s'>\n", szRed, szGreen, szBlue);
	}
	else
	{
		iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "<font size='14' color='#%s%s%s'>", szRed, szGreen, szBlue);

		for(i=0; i<g_iExpHUDArrayCount[iClient]; i++)
		{
			if(i >= sizeof(g_iExpHUDArray[]))
			{
				iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "...");
				break;
			}

			if(i != 0)
				iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, " + ");

			iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "%i", g_iExpHUDArray[iClient][i]);
		}

		iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "\n");
	}

	iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "<font size='38'>  +%i  XP</font></font>", g_iExpHUDAmount[iClient]);

	if(iLen)
		PrintHintText(iClient, szBuffer);
}

CalculateHUDColor(iClient, iColor[3], HudColorType:iHudColorType)
{
	static Float:fCurTime;
	fCurTime = GetGameTime();

	if(fCurTime >= g_fHUDColorEndTime[iClient])
	{
		g_fHUDColorStartTime[iClient] = fCurTime;
		g_fHUDColorEndTime[iClient] = fCurTime + HUD_COLOR_TRANSITION_TIME;
		g_bHUDColorDirection[iClient] = !g_bHUDColorDirection[iClient];
	}

	static Float:fTotalTime, Float:fDifference;
	fTotalTime = g_fHUDColorEndTime[iClient] - g_fHUDColorStartTime[iClient];
	fDifference = g_fHUDColorEndTime[iClient] - fCurTime;
	fDifference = fTotalTime - fDifference;

	static Float:fPercent;
	fPercent = fDifference / fTotalTime;
	if(fPercent < 0.002)
		fPercent = 0.002;

	if(g_bHUDColorDirection[iClient])
		fPercent = 1.0 - fPercent;

	static iTransitionColorStart[3], iTransitionColorEnd[3];
	switch(iHudColorType)
	{
		case HUD_COLOR_TYPE_LEVEL_EXP:
		{
			iTransitionColorStart[0] = HUD_TRANSITION_COLOR_START_LEVEL_EXP[0];
			iTransitionColorStart[1] = HUD_TRANSITION_COLOR_START_LEVEL_EXP[1];
			iTransitionColorStart[2] = HUD_TRANSITION_COLOR_START_LEVEL_EXP[2];

			iTransitionColorEnd[0] = HUD_TRANSITION_COLOR_END_LEVEL_EXP[0];
			iTransitionColorEnd[1] = HUD_TRANSITION_COLOR_END_LEVEL_EXP[1];
			iTransitionColorEnd[2] = HUD_TRANSITION_COLOR_END_LEVEL_EXP[2];
		}
		case HUD_COLOR_TYPE_ACHIEVED:
		{
			iTransitionColorStart[0] = HUD_TRANSITION_COLOR_START_ACHIEVED[0];
			iTransitionColorStart[1] = HUD_TRANSITION_COLOR_START_ACHIEVED[1];
			iTransitionColorStart[2] = HUD_TRANSITION_COLOR_START_ACHIEVED[2];

			iTransitionColorEnd[0] = HUD_TRANSITION_COLOR_END_ACHIEVED[0];
			iTransitionColorEnd[1] = HUD_TRANSITION_COLOR_END_ACHIEVED[1];
			iTransitionColorEnd[2] = HUD_TRANSITION_COLOR_END_ACHIEVED[2];
		}
		default:
		{
			iTransitionColorStart[0] = HUD_TRANSITION_COLOR_START_ACHIEVED[0];
			iTransitionColorStart[1] = HUD_TRANSITION_COLOR_START_ACHIEVED[1];
			iTransitionColorStart[2] = HUD_TRANSITION_COLOR_START_ACHIEVED[2];

			iTransitionColorEnd[0] = HUD_TRANSITION_COLOR_END_ACHIEVED[0];
			iTransitionColorEnd[1] = HUD_TRANSITION_COLOR_END_ACHIEVED[1];
			iTransitionColorEnd[2] = HUD_TRANSITION_COLOR_END_ACHIEVED[2];
		}
	}

	static iTotalDifference[3];
	iTotalDifference[0] = iTransitionColorStart[0] - iTransitionColorEnd[0];
	iTotalDifference[1] = iTransitionColorStart[1] - iTransitionColorEnd[1];
	iTotalDifference[2] = iTransitionColorStart[2] - iTransitionColorEnd[2];

	iColor[0] = iTransitionColorStart[0] - RoundFloat(iTotalDifference[0] * fPercent);
	iColor[1] = iTransitionColorStart[1] - RoundFloat(iTotalDifference[1] * fPercent);
	iColor[2] = iTransitionColorStart[2] - RoundFloat(iTotalDifference[2] * fPercent);
}

ShowTimerHUD(iClient)
{
	static String:szBuffer[255], iLen;
	iLen = GetTimerHUD(iClient, szBuffer, sizeof(szBuffer), g_iHudDisplay[iClient]);

	if(iLen)
		PrintHintText(iClient, szBuffer);
}

GetNumSpectators(iClient)
{
	static iSpectator, iNum, iMode;
	iNum = 0;

	for(iSpectator=1; iSpectator<=MaxClients; iSpectator++)
	{
		if(!IsClientInGame(iSpectator) || !GetClientTeam(iSpectator) || IsFakeClient(iSpectator))
			continue;

		iMode = GetEntProp(iSpectator, Prop_Send, "m_iObserverMode");
		if(iMode != OBS_MODE_IN_EYE && iMode != OBS_MODE_CHASE)
			continue;

		if(GetEntPropEnt(iSpectator, Prop_Send, "m_hObserverTarget") == iClient)
			iNum++;
	}

	return iNum;
}

GetTimerHUD(iClient, String:szBuffer[], const iMaxLength, HudDisplay:iHudDisplay)
{
	static iLen;
	iLen = 0;
	
	new bool:bIsReplayBot = false;
	
	if(g_bLibLoaded_ReplayBot)
	{
		#if defined _speed_runs_replay_bot_included
		bIsReplayBot = SpeedRunsReplayBot_IsClientReplayBot(iClient);
		#endif
	}

	if(Replays_GetMode(iClient) == REPLAY_FREEZE)
	{
		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#FF0000' size='30'>PAUSED</font>");
		return iLen;
	}

	static Float:fVelocity[3], iSpeed, iNumSpectators;
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);

	// Only calculate vertical velocity for speed on surf servers.
	if(g_iServerGroupType != GROUP_TYPE_SURF && g_iServerGroupType != GROUP_TYPE_ROCKET)
		fVelocity[2] = 0.0;

	iSpeed = RoundFloat(GetVectorLength(fVelocity));

	if (bIsReplayBot)
	{
		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "Replay Bot");
	}
	else if(g_bFirstStarted[iClient] || g_bStageStarted[iClient])
	{
		// Show the timer HUD.
		if(g_bStageStarted[iClient])
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, g_szStageName[iClient]);
		else
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "Between stages");

		iLen += Format(szBuffer[iLen], iMaxLength-iLen, " | <font color='#24C7E0'>%i u/s</font>", iSpeed);

		iNumSpectators = GetNumSpectators(iClient);
		if(iNumSpectators)
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, " | %i\n", iNumSpectators);
		else
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "\n");

		static iTotalSeconds, iHour, iMinute, iSecond, iDecimal, Float:fTotalSeconds, eRecord[Record], iIndex, iStyleBits;
		iStyleBits = MovementStyles_GetStyleBits(iClient);

		new bool:bTotalHasHour;
		if(g_bFirstStarted[iClient])
		{
			iIndex = GetRecordByStage((iHudDisplay == HUD_COMPARE_GLOBAL_TIMES) ? 0 : iClient, 0, iStyleBits, eRecord);

			fTotalSeconds = GetTotalRunTime(iClient);
			iTotalSeconds = RoundToFloor(fTotalSeconds);
			iHour = (iTotalSeconds / 3600) % 24;
			iMinute = (iTotalSeconds / 60) % 60;
			iSecond = iTotalSeconds % 60;
			iDecimal = RoundToFloor((fTotalSeconds - float(iTotalSeconds)) * 10.0);

			if(g_bStageStarted[iClient])
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "T: ");
			else
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "Total: ");

			if(iIndex == INVALID_RECORD_INDEX || fTotalSeconds < eRecord[Record_StageTime])
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#61DB23'>");
			else
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#E62929'>");

			if(iHour)
			{
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iHour);
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iMinute);

				bTotalHasHour = true;
			}
			else if(iMinute)
			{
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iMinute);
			}

			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i.%i", iSecond, iDecimal);

			if(iIndex != INVALID_RECORD_INDEX)
			{
				if(fTotalSeconds < eRecord[Record_StageTime])
					iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%s \t-%.1f", iMinute ? "" : "    ", eRecord[Record_StageTime] - fTotalSeconds + 0.1);
				else
					iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%s \t+%.1f", iMinute ? "" : "    ", fTotalSeconds - eRecord[Record_StageTime]);
			}

			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "</font>\n");
		}

		if(g_bStageStarted[iClient])
		{
			iIndex = GetRecordByStage((iHudDisplay == HUD_COMPARE_GLOBAL_TIMES) ? 0 : iClient, g_iStageCurrent[iClient], iStyleBits, eRecord);

			fTotalSeconds = GetStageRunTime(iClient);
			iTotalSeconds = RoundToFloor(fTotalSeconds);
			iHour = (iTotalSeconds / 3600) % 24;
			iMinute = (iTotalSeconds / 60) % 60;
			iSecond = iTotalSeconds % 60;
			iDecimal = RoundToFloor((fTotalSeconds - float(iTotalSeconds)) * 10.0);

			if(g_bFirstStarted[iClient])
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "S: ");
			else
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "Stage: ");

			if(iIndex == INVALID_RECORD_INDEX || fTotalSeconds < eRecord[Record_StageTime])
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#61DB23'>");
			else
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#E62929'>");

			new bool:bStageHasHour;
			if(iHour)
			{
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iHour);
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iMinute);

				bStageHasHour = true;
			}
			else if(iMinute)
			{
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i:", iMinute);
			}

			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%02i.%i", iSecond, iDecimal);

			if(iIndex != INVALID_RECORD_INDEX)
			{
				if(fTotalSeconds < eRecord[Record_StageTime])
					iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%s %s\t-%.1f", iMinute ? "" : "   ", (bTotalHasHour && !bStageHasHour) ? "\t" : "", eRecord[Record_StageTime] - fTotalSeconds + 0.1);
				else
					iLen += Format(szBuffer[iLen], iMaxLength-iLen, "%s %s\t+%.1f", iMinute ? "" : "   ", (bTotalHasHour && !bStageHasHour) ? "\t" : "",fTotalSeconds - eRecord[Record_StageTime]);
			}

			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "</font>\n");
		}
	}
	else
	{
		// Show the EXP hud.
		static Handle:hStyleNames, bool:bHasStyles, iTotalStylesRegistered;
		hStyleNames = CreateArray(MAX_STYLE_NAME_LENGTH);
		bHasStyles = MovementStyles_GetStyleNames(iClient, hStyleNames);
		iTotalStylesRegistered = MovementStyles_GetTotalStylesRegistered() - 1; // Subtract 1 because it returns the "None" style.

		static iColor[3];
		CalculateHUDColor(iClient, iColor, HUD_COLOR_TYPE_LEVEL_EXP);

		static String:szRed[3], String:szGreen[3], String:szBlue[3];
		ColorDecimalToHex(iColor[0], szRed, sizeof(szRed));
		ColorDecimalToHex(iColor[1], szGreen, sizeof(szGreen));
		ColorDecimalToHex(iColor[2], szBlue, sizeof(szBlue));

		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#%s%s%s'>[Lv. %i]</font>", szRed, szGreen, szBlue, SpeedRunsExp_GetClientLevel(iClient));

		if(bHasStyles || iTotalStylesRegistered)
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, " | <font color='#%s%s%s'>[XP: %i/%i]</font>", szRed, szGreen, szBlue, SpeedRunsExp_GetClientExpInCurrentLevel(iClient), SpeedRunsExp_GetClientExpForNextLevel(iClient));
		else
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "\n<font color='#%s%s%s'>[XP: %i/%i]</font>", szRed, szGreen, szBlue, SpeedRunsExp_GetClientExpInCurrentLevel(iClient), SpeedRunsExp_GetClientExpForNextLevel(iClient));

		iNumSpectators = GetNumSpectators(iClient);
		if(iNumSpectators)
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, " | %i\n", iNumSpectators);
		else
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "\n");

		iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#24C7E0'>%i u/s</font>", iSpeed);
		//iLen += Format(szBuffer[iLen], iMaxLength-iLen, "<font color='#24C7E0'>%f u/s</font>", GetVectorLength(fVelocity));

		if(bHasStyles || iTotalStylesRegistered)
		{
			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "   \t| Styles: <font color='#1070A3'>");

			if(bHasStyles)
			{
				static String:szStyleName[MAX_STYLE_NAME_LENGTH], i, iStyleCount;
				iStyleCount = GetArraySize(hStyleNames);

				if(iStyleCount > 3)
				{
					iLen += Format(szBuffer[iLen], iMaxLength-iLen, "Using %i styles. Type !styles to see.", iStyleCount);
				}
				else
				{
					for(i=0; i<iStyleCount; i++)
					{
						GetArrayString(hStyleNames, i, szStyleName, sizeof(szStyleName));

						if(i != 0)
							iLen += Format(szBuffer[iLen], iMaxLength-iLen, ", ");

						iLen += Format(szBuffer[iLen], iMaxLength-iLen, szStyleName);
					}
				}
			}
			else
			{
				iLen += Format(szBuffer[iLen], iMaxLength-iLen, "None");
			}

			iLen += Format(szBuffer[iLen], iMaxLength-iLen, "</font>");
		}

		if(hStyleNames != INVALID_HANDLE)
			CloseHandle(hStyleNames);
	}

	return iLen;
}

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");

	g_bLibLoaded_CheckPoints = LibraryExists("speed_runs_checkpoints");
	g_bLibLoaded_ReplayBot = LibraryExists("speed_runs_replay_bot");
	g_bLibLoaded_FixTriggerPush = LibraryExists("fix_trigger_push");
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
	g_bLibLoaded_DemoSessions = LibraryExists("demo_sessions");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "speed_runs_checkpoints"))
	{
		g_bLibLoaded_CheckPoints = true;
	}
	if(StrEqual(szName, "speed_runs_replay_bot"))
	{
		g_bLibLoaded_ReplayBot = true;
	}
	else if(StrEqual(szName, "fix_trigger_push"))
	{
		g_bLibLoaded_FixTriggerPush = true;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = true;
	}
	else if(StrEqual(szName, "demo_sessions"))
	{
		g_bLibLoaded_DemoSessions = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "speed_runs_checkpoints"))
	{
		g_bLibLoaded_CheckPoints = false;
	}
	else if(StrEqual(szName, "fix_trigger_push"))
	{
		g_bLibLoaded_FixTriggerPush = false;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = false;
	}
	else if(StrEqual(szName, "demo_sessions"))
	{
		g_bLibLoaded_DemoSessions = false;
	}
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateRecordsTable())
		return;

	if(!Query_CreateTierTable())
		return;
}

bool:Query_CreateRecordsTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;

	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_sr_records\
	(\
		record_id			INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		user_id				INT UNSIGNED		NOT NULL,\
		server_group_type	TINYINT UNSIGNED	NOT NULL,\
		server_id			SMALLINT UNSIGNED	NOT NULL,\
		map_id				MEDIUMINT UNSIGNED	NOT NULL,\
		stage_number		SMALLINT UNSIGNED	NOT NULL,\
		stage_time			FLOAT(11,6)			NOT NULL,\
		demo_sess_id		INT UNSIGNED		NOT NULL,\
		demo_tick_start		INT UNSIGNED		NOT NULL,\
		demo_tick_end		INT UNSIGNED		NOT NULL,\
		data_int_1			INT					NOT NULL,\
		data_int_2			INT					NOT NULL,\
		style_bits			INT					NOT NULL,\
		checkpoints_saved	MEDIUMINT			NOT NULL,\
		checkpoints_used	MEDIUMINT			NOT NULL,\
		utime_complete		INT					NOT NULL,\
		replay_id         INT         NOT NULL,\
		PRIMARY KEY ( record_id ),\
		INDEX ( map_id, user_id, style_bits, stage_number ),\
		INDEX ( stage_number, style_bits, stage_time, map_id, user_id ),\
		INDEX ( server_group_type, map_id ),\
		INDEX ( map_id, style_bits ),\
		INDEX ( map_id, stage_number, style_bits ),\
		INDEX ( server_group_type, style_bits )\
	) ENGINE = INNODB");

	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the plugin_sr_records sql table.");
		return false;
	}

	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;

	return true;
}

bool:Query_CreateTierTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;

	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_sr_map_tiers\
	(\
		map_name		VARCHAR( 48 )		NOT NULL,\
		tier			TINYINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( map_name )\
	) CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE = INNODB");

	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the plugin_sr_map_tiers sql table.");
		return false;
	}

	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;

	return true;
}

public OnMapStart()
{
	g_iMapTier = 0;

	g_iUniqueMapCounter++;
	g_bAreMapRecordsLoaded = false;

	if(g_aRecords[0] != INVALID_HANDLE)
		ClearArray(g_aRecords[0]);

	decl i;
	for(i=0; i<sizeof(g_szSoundsMapRecords); i++)
	{
		AddFileToDownloadsTable(g_szSoundsMapRecords[i]);
		PrecacheSoundAny(g_szSoundsMapRecords[i][6]);
	}

	for(i=0; i<sizeof(g_szSoundsStageRecords); i++)
	{
		AddFileToDownloadsTable(g_szSoundsStageRecords[i]);
		PrecacheSoundAny(g_szSoundsStageRecords[i][6]);
	}

	for(i=0; i<sizeof(g_szSoundsUserRecords); i++)
	{
		AddFileToDownloadsTable(g_szSoundsUserRecords[i]);
		PrecacheSoundAny(g_szSoundsUserRecords[i][6]);
	}

	for(i=0; i<sizeof(g_szSoundsUserStageRecords); i++)
	{
		AddFileToDownloadsTable(g_szSoundsUserStageRecords[i]);
		PrecacheSoundAny(g_szSoundsUserStageRecords[i][6]);
	}

	// Get the cookie type to use for exp.
	decl String:szGroupName[32];
	GetConVarString(cvar_sr_group_name, szGroupName, sizeof(szGroupName));

	if(StrEqual(szGroupName, "surf", false))
	{
		g_iServerGroupType = GROUP_TYPE_SURF;
	}
	else if(StrEqual(szGroupName, "bhop", false))
	{
		g_iServerGroupType = GROUP_TYPE_BHOP;
	}
	else if(StrEqual(szGroupName, "course", false))
	{
		g_iServerGroupType = GROUP_TYPE_COURSE;
	}
	else if(StrEqual(szGroupName, "kz", false))
	{
		g_iServerGroupType = GROUP_TYPE_KZ;
	}
	else if(StrEqual(szGroupName, "rocket", false))
	{
		g_iServerGroupType = GROUP_TYPE_ROCKET;
	}
	else
	{
		g_iServerGroupType = GROUP_TYPE_NONE;
	}
}

public DBMaps_OnMapIDReady(iMapID)
{
	decl String:szMapName[97];
	DBMaps_GetCurrentMapNameFormatted(szMapName, sizeof(szMapName));

	if(DB_EscapeString(g_szDatabaseConfigName, szMapName, szMapName, sizeof(szMapName)))
	{
		DB_TQuery(g_szDatabaseConfigName, Query_GetMapTier, DBPrio_High, g_iUniqueMapCounter, "SELECT tier FROM plugin_sr_map_tiers WHERE map_name='%s'", szMapName);
	}

	DB_TQuery(g_szDatabaseConfigName, Query_GetMapRecords, DBPrio_High, g_iUniqueMapCounter, "\
		SELECT r1.user_id, r1.stage_number, r1.style_bits, r1.stage_time \
		FROM plugin_sr_records r1 \
		\
		INNER JOIN\
		(\
			SELECT stage_number, style_bits, MIN(stage_time) as min_stage_time \
			FROM plugin_sr_records \
			WHERE map_id = %i \
			GROUP BY stage_number, style_bits\
		) r2 \
		\
		ON r1.stage_number = r2.stage_number \
		AND r1.style_bits = r2.style_bits \
		AND r1.stage_time = r2.min_stage_time \
		WHERE map_id = %i", iMapID, iMapID);
}

public Query_GetMapTier(Handle:hDatabase, Handle:hQuery, any:iUniqueMapCounter)
{
	if(g_iUniqueMapCounter != iUniqueMapCounter)
		return;

	if(hQuery == INVALID_HANDLE)
		return;

	if(!SQL_FetchRow(hQuery))
		return;

	g_iMapTier = SQL_FetchInt(hQuery, 0);
}

public Query_GetMapRecords(Handle:hDatabase, Handle:hQuery, any:iUniqueMapCounter)
{
	if(g_iUniqueMapCounter != iUniqueMapCounter)
		return;

	if(hQuery == INVALID_HANDLE)
		return;

	decl eRecord[Record];
	while(SQL_FetchRow(hQuery))
	{
		FillRecordStruct(SQL_FetchInt(hQuery, 1), SQL_FetchInt(hQuery, 2), SQL_FetchFloat(hQuery, 3), eRecord);
		SetRecord(0, eRecord);
	}

	g_bAreMapRecordsLoaded = true;

	CPrintToChatAll("{lightgreen}-- {olive}The maps record data is now loaded.");
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetUserRecords, DBPrio_Normal, GetClientSerial(iClient), "\
		SELECT r1.stage_number, r1.style_bits, r1.stage_time \
		FROM plugin_sr_records r1 \
		\
		INNER JOIN\
		(\
			SELECT stage_number, style_bits, MIN(stage_time) as min_stage_time \
			FROM plugin_sr_records \
			WHERE map_id = %i AND user_id = %i \
			GROUP BY stage_number, style_bits\
		) r2 \
		\
		ON r1.stage_number = r2.stage_number \
		AND r1.style_bits = r2.style_bits \
		AND r1.stage_time = r2.min_stage_time \
		WHERE map_id = %i AND user_id = %i", DBMaps_GetMapID(), iUserID, DBMaps_GetMapID(), iUserID);
}

public Query_GetUserRecords(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;

	if(hQuery == INVALID_HANDLE)
		return;

	decl eRecord[Record];
	while(SQL_FetchRow(hQuery))
	{
		FillRecordStruct(SQL_FetchInt(hQuery, 0), SQL_FetchInt(hQuery, 1), SQL_FetchFloat(hQuery, 2), eRecord);
		SetRecord(iClient, eRecord);
	}

	g_bAreUserRecordsLoaded[iClient] = true;

	CPrintToChat(iClient, "{lightgreen}-- {olive}Your record data is now loaded.");
}

SetRecord(iClient, const eRecord[Record])
{
	if(eRecord[Record_StageNumber] >= MAX_STAGES)
	{
		LogError("Stage number %i >= MAX_STAGES (%i).", eRecord[Record_StageNumber], MAX_STAGES);
		return;
	}

	if(g_aRecords[iClient] == INVALID_HANDLE)
		g_aRecords[iClient] = CreateArray(Record);

	new iArraySize = GetArraySize(g_aRecords[iClient]);
	decl eTempRecord[Record], iIndex;
	for(iIndex=0; iIndex<iArraySize; iIndex++)
	{
		GetArrayArray(g_aRecords[iClient], iIndex, eTempRecord);

		if(eTempRecord[Record_StageNumber] != eRecord[Record_StageNumber])
			continue;

		if(eTempRecord[Record_StyleBits] != eRecord[Record_StyleBits])
			continue;

		break;
	}

	if(iIndex >= iArraySize)
		PushArrayArray(g_aRecords[iClient], eRecord);
	else
		SetArrayArray(g_aRecords[iClient], iIndex, eRecord);
}

GetRecordByStage(iClient, iStageNumber, iStyleBits, eRecord[Record])
{
	if(g_aRecords[iClient] == INVALID_HANDLE)
		return INVALID_RECORD_INDEX;

	static iArraySize;
	iArraySize = GetArraySize(g_aRecords[iClient]);

	if(!iArraySize)
		return INVALID_RECORD_INDEX;

	static i;
	for(i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aRecords[iClient], i, eRecord);

		if(eRecord[Record_StageNumber] != iStageNumber)
			continue;

		if(eRecord[Record_StyleBits] != iStyleBits)
			continue;

		return i;
	}

	return INVALID_RECORD_INDEX;
}

DisplayMenu_SoundSelect(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_SoundSelect);
	SetMenuTitle(hMenu, "Sound Select");

	decl String:szInfo[12];

	IntToString(SOUND_BITS_DISABLE_MAP_RECORDS, szInfo, sizeof(szInfo));
	if(g_iSoundBits[iClient] & SOUND_BITS_DISABLE_MAP_RECORDS)
	{
		AddMenuItem(hMenu, szInfo, "Map record sounds [OFF]");
	}
	else
	{
		AddMenuItem(hMenu, szInfo, "Map record sounds [ON]");
	}

	IntToString(SOUND_BITS_DISABLE_STAGE_RECORDS, szInfo, sizeof(szInfo));
	if(g_iSoundBits[iClient] & SOUND_BITS_DISABLE_STAGE_RECORDS)
	{
		AddMenuItem(hMenu, szInfo, "Stage record sounds [OFF]");
	}
	else
	{
		AddMenuItem(hMenu, szInfo, "Stage record sounds [ON]");
	}

	IntToString(SOUND_BITS_DISABLE_OWN_MAP_RECORDS, szInfo, sizeof(szInfo));
	if(g_iSoundBits[iClient] & SOUND_BITS_DISABLE_OWN_MAP_RECORDS)
	{
		AddMenuItem(hMenu, szInfo, "Personal map record sounds [OFF]");
	}
	else
	{
		AddMenuItem(hMenu, szInfo, "Personal map record sounds [ON]");
	}

	IntToString(SOUND_BITS_DISABLE_OWN_STAGE_RECORDS, szInfo, sizeof(szInfo));
	if(g_iSoundBits[iClient] & SOUND_BITS_DISABLE_OWN_STAGE_RECORDS)
	{
		AddMenuItem(hMenu, szInfo, "Personal stage record sounds [OFF]");
	}
	else
	{
		AddMenuItem(hMenu, szInfo, "Personal stage record sounds [ON]");
	}

	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error displaying the menu.");
}

public MenuHandle_SoundSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}

	if(action != MenuAction_Select)
		return;

	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));

	new iSoundBit = StringToInt(szInfo);
	g_iSoundBits[iParam1] ^= iSoundBit;
	ClientCookies_SetCookie(iParam1, CC_TYPE_SPEEDRUNS_SOUND_BITS, g_iSoundBits[iParam1]);

	DisplayMenu_SoundSelect(iParam1);
}

DisplayMenu_HudSelect(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_HudSelect);
	SetMenuTitle(hMenu, "HUD Select");

	decl String:szInfo[4];
	IntToString(_:HUD_NONE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Disable HUD");

	IntToString(_:HUD_COMPARE_GLOBAL_TIMES, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Compare global times (default)");

	IntToString(_:HUD_COMPARE_USER_TIMES, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Compare personal times");

	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error displaying the menu.");
}

public MenuHandle_HudSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}

	if(action != MenuAction_Select)
		return;

	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));

	new HudDisplay:iNewHudDisplay = HudDisplay:StringToInt(szInfo);

	switch(iNewHudDisplay)
	{
		case HUD_NONE:
		{
			CPrintToChat(iParam1, "{lightgreen}-- {olive}The HUD will not be displayed.");

			if(iNewHudDisplay != g_iHudDisplay[iParam1])
				PrintHintText(iParam1, "This HUD will no longer be displayed.\nHiding in a few seconds.");
		}
		case HUD_COMPARE_GLOBAL_TIMES: CPrintToChat(iParam1, "{lightgreen}-- {olive}The HUD will compare times globally.");
		case HUD_COMPARE_USER_TIMES: CPrintToChat(iParam1, "{lightgreen}-- {olive}The HUD will compare times against yourself.");
	}

	g_iHudDisplay[iParam1] = iNewHudDisplay;
	ClientCookies_SetCookie(iParam1, CC_TYPE_SPEEDRUNS_HUD_DISPLAY, _:iNewHudDisplay);

	DisplayMenu_HudSelect(iParam1);
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SPEEDRUNS_HUD_DISPLAY))
		g_iHudDisplay[iClient] = HudDisplay:ClientCookies_GetCookie(iClient, CC_TYPE_SPEEDRUNS_HUD_DISPLAY);
	else
		g_iHudDisplay[iClient] = HUD_COMPARE_GLOBAL_TIMES;

	if(ClientCookies_HasCookie(iClient, CC_TYPE_SPEEDRUNS_SOUND_BITS))
		g_iSoundBits[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_SPEEDRUNS_SOUND_BITS);
	else
		g_iSoundBits[iClient] = SOUND_BITS_PLAY_ALL;
}

bool:ColorDecimalToHex(iNumber, String:szBase16[], iMaxLength)
{
	decl iTemp;
	new i, iQuotient = iNumber;

	while(iQuotient != 0)
	{
		if(i >= (iMaxLength - 1))
			return false;

		iTemp = iQuotient % 16;

		if(iTemp < 10)
			iTemp = iTemp + 48;
		else
			iTemp = iTemp + 55;

		szBase16[i++] = iTemp;

		iQuotient = iQuotient / 16;
	}

	if(i == 0)
	{
		szBase16[0] = '0';
		szBase16[1] = '0';
		i += 2;
	}
	else if(i == 1)
	{
		szBase16[1] = szBase16[0];
		szBase16[0] = '0';
		i++;
	}
	else
	{
		iTemp = szBase16[0];
		szBase16[0] = szBase16[1];
		szBase16[1] = iTemp;
	}

	szBase16[i] = '\x0';

	return true;
}

public MovementStyles_OnBitsChanged(iClient, iOldBits, &iNewBits)
{
	if(iOldBits == iNewBits)
		return;

	// If the player is respawning and their style changed we need to cancel any run they are in.
	ResetSpeedRunVariables(iClient);
}

public Replays_OnLoadTick_Pre(iClient, iTick)
{
	if (iTick < g_iTickStartedCurrent[iClient])
		g_bStageStarted[iClient] = false;

	if (iTick < g_iTickStartedFirst[iClient])
		g_bFirstStarted[iClient] = false;

}
