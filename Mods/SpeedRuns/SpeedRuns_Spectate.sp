#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include "Includes/speed_runs"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "Includes/speed_runs_teleport"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Spectate";
new const String:PLUGIN_VERSION[] = "1.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed run spectate plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define OBS_MODE_IN_EYE		4
#define OBS_MODE_CHASE		5

new bool:g_bLibLoaded_SpeedRunsTeleport;

new Handle:cvar_tele_to_start_on_spawn;


public OnPluginStart()
{
	CreateConVar("speed_runs_spectate_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_tele_to_start_on_spawn = CreateConVar("speedruns_spectate_tele_to_start_on_spawn", "1", "1: Player will teleport to stage 1 on spawn. -- 0: Don't teleport.", _, true, 0.0, true, 1.0);
	
	LoadTranslations("common.phrases");
	
	RegConsoleCmd("sm_spec", OnCommandSpectate);
	RegConsoleCmd("sm_spectate", OnCommandSpectate);
	
	RegConsoleCmd("sm_si", OnCommandSpecInfo);
	RegConsoleCmd("sm_specinfo", OnCommandSpecInfo);
	
	AddCommandListener(OnSpectate, "spectate");
	AddCommandListener(OnJoinTeam, "jointeam");
	
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_SpeedRunsTeleport = LibraryExists("speed_runs_teleport");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "speed_runs_teleport"))
		g_bLibLoaded_SpeedRunsTeleport = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "speed_runs_teleport"))
		g_bLibLoaded_SpeedRunsTeleport = false;
}

public Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// We want to cancel all players runs when the round restarts.
	// This is so players can't "cheat" by pausing, then waiting on the next round to start and teleporting back to their position.
	// Doing this isn't a big deal since the round will never restart on servers like surf/kz/bhop.
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SpeedRuns_CancelRun(iClient, false);
	}
}

public Action:OnSpectate(iClient, const String:szCommand[], iArgCount)
{
	MoveToSpec(iClient);
	return Plugin_Handled;
}

public Action:OnJoinTeam(iClient, const String:szCommand[], iArgCount)
{
	if(iArgCount < 1)
		return Plugin_Continue;
	
	decl String:szTeam[2];
	GetCmdArg(1, szTeam, sizeof(szTeam));
	
	if(StringToInt(szTeam) != CS_TEAM_SPECTATOR)
		return Plugin_Continue;
	
	MoveToSpec(iClient);
	
	return Plugin_Handled;
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(SpeedRuns_IsRunPaused(iClient))
	{
		SpeedRuns_PauseRun(iClient, false);
	}
	else
	{
		#if defined _speed_runs_teleport_included
		if(g_bLibLoaded_SpeedRunsTeleport && GetConVarBool(cvar_tele_to_start_on_spawn))
			SpeedRunsTeleport_TeleportToStage(iClient, 1, true);
		#endif
	}
}

public Action:OnCommandSpectate(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	MoveToSpec(iClient);
	
	return Plugin_Handled;
}

MoveToSpec(iClient)
{
	if(GetClientTeam(iClient) == CS_TEAM_SPECTATOR)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}You are already spectating.");
		return;
	}
	
	new bool:bPaused;
	
	// TODO: For now don't allow pausing runs since it can mess the demo rendering program up.
	// Will need to eventually log the ticks each time a run is paused/unpaused and treat them as separate runs in the demo program, then stitch the clips together.
	/*
	if(SpeedRuns_IsInTotalRun(iClient) || SpeedRuns_GetCurrentStage(iClient))
	{
		bPaused = true;
		SpeedRuns_PauseRun(iClient, true);
	}
	*/
	
	// TODO: Instead of killing the player we should send the team event if ChangeClientTeam() doesn't. Need to check this.
	// -->
	ChangeClientTeam(iClient, CS_TEAM_SPECTATOR);
	
	if(bPaused)
		CPrintToChat(iClient, "{lightgreen}-- {olive}You are now spectating. Your run has been paused.");
	else
		CPrintToChat(iClient, "{lightgreen}-- {olive}You are now spectating.");
}

public Action:OnCommandSpecInfo(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgCount < 1)
	{
		HandleTarget(iClient, 0);
	}
	else
	{
		decl String:szTarget[MAX_TARGET_LENGTH];
		GetCmdArg(1, szTarget, sizeof(szTarget));
		
		new iTarget = FindTarget(iClient, szTarget, false, false);
		if(iTarget != -1)
			HandleTarget(iClient, iTarget);
	}
	
	return Plugin_Handled;
}

HandleTarget(iClient, iTarget)
{
	// The client specified a specific target.
	if(iTarget)
	{
		// First check to see if their target is a spectator. If so we need to get that spectators target.
		if(GetClientTeam(iTarget) <= CS_TEAM_SPECTATOR)
		{
			new iOriginalTarget = iTarget;
			new iMode = GetEntProp(iTarget, Prop_Send, "m_iObserverMode");
			iTarget = GetEntPropEnt(iTarget, Prop_Send, "m_hObserverTarget");
			
			if(!iTarget || (iMode != OBS_MODE_IN_EYE && iMode != OBS_MODE_CHASE))
			{
				CPrintToChat(iClient, "{lightgreen}-- {lightred}%N {olive}is a spectator without a target.", iOriginalTarget);
				return;
			}
		}
		
		PrintSpectators(iClient, iTarget);
		return;
	}
	
	if(GetClientTeam(iClient) <= CS_TEAM_SPECTATOR)
	{
		new iMode = GetEntProp(iClient, Prop_Send, "m_iObserverMode");
		iTarget = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		
		if(!iTarget || (iMode != OBS_MODE_IN_EYE && iMode != OBS_MODE_CHASE))
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}You are not spectating anyone.");
			return;
		}
		
		// The client is spectating someone. Show who is spectating the person the client is spectating.
		PrintSpectators(iClient, iTarget);
	}
	else
	{
		// The client is playing. Just show who is spectating them.
		PrintSpectators(iClient, iClient);
	}
}

PrintSpectators(iClient, iTarget)
{
	static String:szBuffer[255], iLen;
	iLen = Format(szBuffer, sizeof(szBuffer), "{olive}Players spectating {lightred}%N{olive}: {yellow}", iTarget);
	
	static iSpectator, iMode, iNum;
	iNum = 0;
	
	for(iSpectator=1; iSpectator<=MaxClients; iSpectator++)
	{
		if(!IsClientInGame(iSpectator) || !GetClientTeam(iSpectator) || IsFakeClient(iSpectator))
			continue;
		
		iMode = GetEntProp(iSpectator, Prop_Send, "m_iObserverMode");
		if(iMode != OBS_MODE_IN_EYE && iMode != OBS_MODE_CHASE)
			continue;
		
		if(GetEntPropEnt(iSpectator, Prop_Send, "m_hObserverTarget") != iTarget)
			continue;
		
		// If the length of buffer is greater than the total buffer size minus a players name length we need to go ahead and dump it.
		if(iLen >= sizeof(szBuffer) - 64)
		{
			CPrintToChat(iClient, szBuffer);
			iLen = 0;
		}
		
		iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "%s%N", ((iLen && iNum) ? ", " : ""), iSpectator);
		iNum++;
	}
	
	if(iNum)
	{
		CPrintToChat(iClient, szBuffer);
	}
	else
	{
		iLen += Format(szBuffer[iLen], sizeof(szBuffer)-iLen, "{purple}Nobody{olive}.");
		CPrintToChat(iClient, szBuffer);
	}
}