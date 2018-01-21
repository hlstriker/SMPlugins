#include <sourcemod>
#include <sdkhooks>
#include <basecomm>
#include <sdktools_functions>
#include <sdktools_voice>
#include <hls_color_chat>
#include <emitsoundany>
#include "Includes/ultjb_last_request"
#include "../../Libraries/TimedPunishments/timed_punishments"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Voice Chat";
new const String:PLUGIN_VERSION[] = "1.16";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The voice chat plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bHasRoundStarted;
new bool:g_bHasMapEnded;
new Handle:g_hMuteTimer;
new Handle:cvar_mute_prisoner_time;

new bool:g_bSkipNextOnClientMute[MAXPLAYERS+1];
new bool:g_bIsClientMutedBySourceMod[MAXPLAYERS+1];

#define MUTE_MESSAGE_DELAY	4.0

new const String:g_szRestrictedSound[] = "sound/buttons/button11.wav";


public OnPluginStart()
{
	CreateConVar("ultjb_voice_chat_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_mute_prisoner_time = CreateConVar("ultjb_voice_mute_prisoner_time", "60", "The number of seconds to mute prisoners at the start of the round.", _, true, 0.0);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	HookEvent("cs_intermission", Event_Intermission_Post, EventHookMode_PostNoCopy);
}

public SquelchManager_OnClientStartSpeaking(iClient)
{
	if(!(GetClientListeningFlags(iClient) & VOICE_MUTED))
		return;
	
	static Float:fNextMessageTime[MAXPLAYERS+1], Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fNextMessageTime[iClient] > fCurTime)
		return;
	
	fNextMessageTime[iClient] = fCurTime + MUTE_MESSAGE_DELAY;
	
	if(g_hMuteTimer == INVALID_HANDLE)
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Your microphone is muted right now. Possible Reasons: Talking over Warden, Admin Muted, Timed Muted, Dead");
	else
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Your microphone is muted right now. T's are muted for the first 60 seconds of the round.");
	
	EmitSoundToClientAny(iClient, g_szRestrictedSound[6], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_LIBRARY, SND_NOFLAGS);
}

public EventPlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(!g_bHasRoundStarted)
		return;
	
	MutePlayer(GetClientOfUserId(GetEventInt(hEvent, "userid")));
}

CancelUnmuteTimer()
{
	if(g_hMuteTimer == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hMuteTimer);
	g_hMuteTimer = INVALID_HANDLE;
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(GetTeamClientCount(TEAM_GUARDS) < 1)
		return;
	
	g_bHasRoundStarted = true;
	MuteAllPrisoners();
	
	CancelUnmuteTimer();
	
	if(GetConVarInt(cvar_mute_prisoner_time) > 0)
		g_hMuteTimer = CreateTimer(GetConVarFloat(cvar_mute_prisoner_time), Timer_UnmutePrisoners);
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}The prisoners have been muted for {lightred}%i {olive}seconds.", GetConVarInt(cvar_mute_prisoner_time));
}

public Action:Timer_UnmutePrisoners(Handle:hTimer)
{
	g_hMuteTimer = INVALID_HANDLE;
	UnmuteAllAlivePlayers();
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}The prisoners may now speak quietly.");
}

public Action:Event_RoundEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	CancelUnmuteTimer();
	
	g_bHasRoundStarted = false;
	UnmuteAllPlayers();
}

public Event_Intermission_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bHasMapEnded = true;
	CancelUnmuteTimer();
	MuteNonAdmins();
}

public OnMapStart()
{
	g_bHasRoundStarted = false;
	g_bHasMapEnded = false;
	
	AddFileToDownloadsTable(g_szRestrictedSound);
	PrecacheSoundAny(g_szRestrictedSound[6]);
}

public OnClientPutInServer(iClient)
{
	g_bIsClientMutedBySourceMod[iClient] = false;
	
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	
	MutePlayer(iClient);
}

CheckToMutePlayer(iClient)
{
	// Mute players if the map is over.
	if(g_bHasMapEnded)
	{
		MutePlayer(iClient);
		return;
	}
	
	// Don't mute anyone if there aren't any guards yet.
	if(GetTeamClientCount(TEAM_GUARDS) < 1)
	{
		UnmutePlayer(iClient);
		return;
	}
	
	// Don't mute anyone if they spawn before round_start. The round_start callback will handle it.
	if(!g_bHasRoundStarted)
	{
		UnmutePlayer(iClient);
		return;
	}
	
	// Mute players if they are dead.
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
	{
		MutePlayer(iClient);
		return;
	}
	
	// Mute players if the mute timer is active and they are a prisoner.
	if(g_hMuteTimer != INVALID_HANDLE && GetClientTeam(iClient) == TEAM_PRISONERS)
	{
		MutePlayer(iClient);
		return;
	}
	
	// Unmute for every other situation.
	UnmutePlayer(iClient);
}

public OnSpawnPost(iClient)
{
	CheckToMutePlayer(iClient);
}

public Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!iClient)
		return;
	
	CheckToMutePlayer(iClient);
}

UnmuteAllAlivePlayers()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		UnmutePlayer(iClient);
	}
}

UnmuteAllPlayers()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		UnmutePlayer(iClient);
	}
}

MuteAllPrisoners()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS)
			continue;
		
		MutePlayer(iClient);
	}
}

MuteNonAdmins()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
			
		if(CheckCommandAccess(iClient, "sm_say", ADMFLAG_CHAT, false))
			continue;
		
		MutePlayer(iClient);
	}
}

MutePlayer(iClient)
{
	if(BaseComm_IsClientMuted(iClient))
		return;
	
	g_bSkipNextOnClientMute[iClient] = true;
	BaseComm_SetClientMute(iClient, true);
}

public BaseComm_OnClientMute(iClient, bool:bMuteState)
{
	if(g_bSkipNextOnClientMute[iClient])
	{
		g_bSkipNextOnClientMute[iClient] = false;
		return;
	}
	
	g_bIsClientMutedBySourceMod[iClient] = bMuteState;
}

UnmutePlayer(iClient)
{
	if(g_bIsClientMutedBySourceMod[iClient])
		return;
	
	new iSecondsLeft = TimedPunishment_GetSecondsLeft(iClient, TP_TYPE_MUTE);
	
	if(iSecondsLeft >= 0)
		return;
	
	BaseComm_SetClientMute(iClient, false);
}