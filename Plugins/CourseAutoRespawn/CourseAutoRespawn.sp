#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <sdktools_functions>
#include <sdktools_entinput>
#include "../MapVoting/map_voting"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Course Auto Respawn";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Automatically respawns players on the course server.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MODEL_RESPAWN_BOT	"models/player/custom_player/legacy/tm_phoenix_heavy.mdl"

new Handle:cvar_course_respawn_enabled;
new Handle:cvar_ignore_round_win_conditions;

new g_iBotSerial;
new bool:g_bShouldAutoRespawn;

new Float:g_fRoundStartTime;

new bool:g_EventHooked_RoundPrestart;
new bool:g_EventHooked_RoundStart;
new bool:g_EventHooked_PlayerDeath;
new bool:g_EventHooked_PlayerTeam;

new Handle:g_hTimer_Respawn[MAXPLAYERS+1];
new Handle:g_hTimer_SetBotMoveType;

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("course_auto_respawn_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_course_respawn_enabled = CreateConVar("sv_course_respawn_enabled", "1", "1: Enabled -- 0: Disabled", _, true, 0.0, true, 1.0);
	
	cvar_ignore_round_win_conditions = FindConVar("mp_ignore_round_win_conditions");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = false;
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("course_auto_respawn");
	CreateNative("CourseAutoRespawn_IsAutoRespawnOn", _CourseAutoRespawn_IsAutoRespawnOn);
	
	return APLRes_Success;
}

public _CourseAutoRespawn_IsAutoRespawnOn(Handle:hPlugin, iNumParams)
{
	return g_bShouldAutoRespawn;
}

public OnMapStart()
{
	PrecacheModel(MODEL_RESPAWN_BOT, true);
	g_fRoundStartTime = GetEngineTime();
}

public OnConfigsExecuted()
{
	g_iBotSerial = 0;
	
	if(!GetConVarBool(cvar_course_respawn_enabled))
		return;
	
	g_EventHooked_RoundPrestart = HookEventEx("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	g_EventHooked_RoundStart = HookEventEx("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	g_EventHooked_PlayerDeath = HookEventEx("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	g_EventHooked_PlayerTeam = HookEventEx("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	// Create the bot on a timer to prevent it from spawning in invalid spots.
	CreateTimer(1.0, Timer_CreateBot, _, TIMER_FLAG_NO_MAPCHANGE);
}

public OnMapEnd()
{
	StopTimer_SetBotMoveType();
	
	if(g_EventHooked_RoundPrestart)
	{
		g_EventHooked_RoundPrestart = false;
		UnhookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	}
	
	if(g_EventHooked_RoundStart)
	{
		g_EventHooked_RoundStart = false;
		UnhookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	}
	
	if(g_EventHooked_PlayerDeath)
	{
		g_EventHooked_PlayerDeath = false;
		UnhookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	}
	
	if(g_EventHooked_PlayerTeam)
	{
		g_EventHooked_PlayerTeam = false;
		UnhookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	}
}

public Action:Timer_CreateBot(Handle:hTimer)
{
	new iSpawnTeam = GetBotsTeamToSpawnOn();
	if(!iSpawnTeam)
		return;
	
	new iBot = CreateFakeClient("Mr. Respawn");
	if(!iBot)
		return;
	
	g_iBotSerial = GetClientSerial(iBot);
	
	FakeClientCommand(iBot, "jointeam %i", iSpawnTeam);
	CS_RespawnPlayer(iBot);
	ApplyBotSettings();
}

GetBotsTeamToSpawnOn()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
		return CS_TEAM_CT;
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
		return CS_TEAM_T;
	
	return 0;
}

ApplyBotSettings()
{
	new iBot = GetClientFromSerial(g_iBotSerial);
	if(iBot < 1)
		return;
	
	SetEntityMoveType(iBot, MOVETYPE_WALK);
	
	if(!g_bLibLoaded_ModelSkinManager)
		SetEntityModel(iBot, MODEL_RESPAWN_BOT);
	
	g_bShouldAutoRespawn = true;
	SetConVarBool(cvar_ignore_round_win_conditions, true);
	
	StartTimer_SetBotMoveType();
}

public MSManager_OnSpawnPost(iClient)
{
	new iBot = GetClientFromSerial(g_iBotSerial);
	if(iBot < 1)
		return;
	
	if(iClient != iBot)
		return;
	
	#if defined _model_skin_manager_included
	MSManager_SetPlayerModel(iClient, MODEL_RESPAWN_BOT);
	#endif
}

StopTimer_SetBotMoveType()
{
	if(g_hTimer_SetBotMoveType == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_SetBotMoveType);
	g_hTimer_SetBotMoveType = INVALID_HANDLE;
}

StartTimer_SetBotMoveType()
{
	StopTimer_SetBotMoveType();
	g_hTimer_SetBotMoveType = CreateTimer(1.5, Timer_SetBotMoveType);
}

public Action:Timer_SetBotMoveType(Handle:hTimer)
{
	g_hTimer_SetBotMoveType = INVALID_HANDLE;
	
	new iBot = GetClientFromSerial(g_iBotSerial);
	if(iBot < 1)
		return;
	
	SetEntityMoveType(iBot, MOVETYPE_NONE);
}

public MapVoting_OnVoteRocked(iChangeTimeType)
{
	if(iChangeTimeType != CHANGETIME_INSTANTLY && iChangeTimeType != CHANGETIME_ROUND_END)
		return;
	
	DisableAutoRespawn();
	
	new iBot = GetClientFromSerial(g_iBotSerial);
	if(iBot)
		AcceptEntityInput(iBot, "Kill");
}

public Action:Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_fRoundStartTime = GetEngineTime();
	StopRespawnTimerForAll();
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	ApplyBotSettings();
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(IsFakeClient(iClient))
	{
		new iBot = GetClientFromSerial(g_iBotSerial);
		if(iBot && iBot == iClient)
			DisableAutoRespawn();
		
		if(!g_bShouldAutoRespawn)
			CheckShouldEndRound();
		
		return;
	}
	
	if(!g_bShouldAutoRespawn)
	{
		CheckShouldEndRound();
		return;
	}
	
	StartTimer_Respawn(iClient);
}

public Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(!g_bShouldAutoRespawn)
		return;
	
	if(GetEventInt(hEvent, "team") < CS_TEAM_T)
		return;
	
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	StartTimer_Respawn(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	StopTimer_Respawn(iClient);
	
	new iBot = GetClientFromSerial(g_iBotSerial);
	if(!iBot || iClient == iBot)
		DisableAutoRespawn();
	
	if(!g_bShouldAutoRespawn)
		CheckShouldEndRound();
}

CheckShouldEndRound()
{
	new bool:bAlive;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || IsFakeClient(iClient))
			continue;
		
		bAlive = true;
		break;
	}
	
	if(bAlive)
		return;
	
	CS_TerminateRound(2.0, CSRoundEnd_Draw);
}

DisableAutoRespawn()
{
	if(!g_bShouldAutoRespawn)
		return;
	
	g_bShouldAutoRespawn = false;
	CPrintToChatAll("{green}-- {red}Automatic respawning is now turned off.");
	
	StopRespawnTimerForAll();
}

StopRespawnTimerForAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		StopTimer_Respawn(iClient);
}

StopTimer_Respawn(iClient)
{
	if(g_hTimer_Respawn[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Respawn[iClient]);
	g_hTimer_Respawn[iClient] = INVALID_HANDLE;
}

StartTimer_Respawn(iClient)
{
	StopTimer_Respawn(iClient);
	g_hTimer_Respawn[iClient] = CreateTimer(0.1, Timer_Respawn, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_Respawn(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_Respawn[iClient] = INVALID_HANDLE;
	
	if(!IsClientInGame(iClient) || IsPlayerAlive(iClient))
		return;
	
	if(GetClientTeam(iClient) < CS_TEAM_T)
		return;
	
	CS_RespawnPlayer(iClient);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bShouldAutoRespawn)
		return;
	
	new iBot = GetClientFromSerial(g_iBotSerial);
	if(!iBot)
		return;
	
	if(GetEngineTime() < (g_fRoundStartTime + 10.0))
		return;
	
	ForcePlayerSuicide(iClient);
}