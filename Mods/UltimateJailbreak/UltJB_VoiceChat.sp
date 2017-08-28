#include <sourcemod>
#include <sdkhooks>
#include <basecomm>
#include <sdktools_functions>
#include <hls_color_chat>
#include "Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Voice Chat";
new const String:PLUGIN_VERSION[] = "1.10";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The voice chat plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bHasRoundStarted;
new Handle:g_hMuteTimer;
new Handle:cvar_mute_prisoner_time;

new bool:g_bSkipNextOnClientMute[MAXPLAYERS+1];
new bool:g_bIsClientMutedBySourceMod[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("ultjb_voice_chat_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_mute_prisoner_time = CreateConVar("ultjb_voice_mute_prisoner_time", "60", "The number of seconds to mute prisoners at the start of the round.", _, true, 0.0);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
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

public OnMapEnd()
{
	CancelUnmuteTimer();
	MuteAllPlayers();
}

public OnMapStart()
{
	g_bHasRoundStarted = false;
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

MuteAllPlayers()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
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
	
	BaseComm_SetClientMute(iClient, false);
}