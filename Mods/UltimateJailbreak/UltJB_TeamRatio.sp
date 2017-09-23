#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <sdktools_functions>
#include <hls_color_chat>
#include "Includes/ultjb_cell_doors"
#include "Includes/ultjb_last_request"

#undef REQUIRE_PLUGIN
#include "../../Libraries/TimedPunishments/timed_punishments"
#include "../../Libraries/ClientTimes/client_times"
#include "../../Libraries/DatabaseUserStats/database_user_stats"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Team Ratio";
new const String:PLUGIN_VERSION[] = "1.14";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The team ratio plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aGuardQueue;
new Handle:cvar_prisoners_per_guard;
new Handle:cvar_pre_guard_queue_time;

new const String:g_szRestrictedSound[] = "buttons/button11.wav";

new bool:g_bHasFinishedPreGuardQueue;
new g_iTimerCountdown;
new Handle:g_hTimer_GuardQueue;

new bool:g_bBlockJoinTeamMessage;

new bool:g_bLibLoaded_TimedPunishments;
new bool:g_bLibLoaded_ClientTimes;
new bool:g_bLibLoaded_DatabaseUserStats;


public OnPluginStart()
{
	CreateConVar("ultjb_team_ratio_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_prisoners_per_guard = CreateConVar("ultjb_prisoners_per_guard", "2", "How many prisoners for each guard.", _, true, 1.0);
	cvar_pre_guard_queue_time = CreateConVar("ultjb_pre_guard_queue_time", "30", "The number of seconds players have to enter the queue before it randomizes itself.", _, true, 1.0);
	
	g_aGuardQueue = CreateArray();
	
	AddCommandListener(OnJoinTeam, "jointeam");
	HookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	
	RegConsoleCmd("sm_guard", OnGuardQueue, "Adds you to the guard queue.");
	
	AddCommandListener(BlockCommand, "kill");
	AddCommandListener(BlockCommand, "explode");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_TimedPunishments = LibraryExists("timed_punishments");
	g_bLibLoaded_ClientTimes = LibraryExists("client_times");
	g_bLibLoaded_DatabaseUserStats = LibraryExists("database_user_stats");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "timed_punishments"))
	{
		g_bLibLoaded_TimedPunishments = true;
	}
	else if(StrEqual(szName, "client_times"))
	{
		g_bLibLoaded_ClientTimes = true;
	}
	else if(StrEqual(szName, "database_user_stats"))
	{
		g_bLibLoaded_DatabaseUserStats = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "timed_punishments"))
	{
		g_bLibLoaded_TimedPunishments = false;
	}
	else if(StrEqual(szName, "client_times"))
	{
		g_bLibLoaded_ClientTimes = false;
	}
	else if(StrEqual(szName, "database_user_stats"))
	{
		g_bLibLoaded_DatabaseUserStats = false;
	}
}

public Action:BlockCommand(iClient, const String:szCommand[], iArgCount)
{
	return Plugin_Handled;
}

public OnMapStart()
{
	g_bHasFinishedPreGuardQueue = false;
}

public OnMapEnd()
{
	StopGuardTimer();
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	StopGuardTimer();
	
	if(GetTeamClientCount(TEAM_GUARDS) > 0)
		return;
	
	// Open the cell doors immediately on the first round.
	UltJB_CellDoors_ForceOpen();
	
	g_iTimerCountdown = 0;
	ShowGuardQueueCountdown();
	g_bHasFinishedPreGuardQueue = false;
	g_hTimer_GuardQueue = CreateTimer(1.0, Timer_RandomizeGuardQueue, _, TIMER_REPEAT);
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}The guard queue will be randomized in {lightred}%i {olive}seconds.", GetConVarInt(cvar_pre_guard_queue_time));
}

StopGuardTimer()
{
	if(g_hTimer_GuardQueue == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hTimer_GuardQueue);
	g_hTimer_GuardQueue = INVALID_HANDLE;
}

ShowGuardQueueCountdown()
{
	PrintHintTextToAll("<font color='#6FC41A'>Selecting guards in:</font>\n<font color='#DE2626'>%i</font> <font color='#6FC41A'>seconds.</font>", GetConVarInt(cvar_pre_guard_queue_time) - g_iTimerCountdown);
}

public Action:Timer_RandomizeGuardQueue(Handle:hTimer)
{
	g_iTimerCountdown++;
	if(g_iTimerCountdown < GetConVarInt(cvar_pre_guard_queue_time))
	{
		ShowGuardQueueCountdown();
		return Plugin_Continue;
	}
	
	g_hTimer_GuardQueue = INVALID_HANDLE;
	
	g_bHasFinishedPreGuardQueue = true;
	PrintHintTextToAll("<font color='#6FC41A'>Guards have been selected!</font>");
	
	new iArraySize = GetArraySize(g_aGuardQueue);
	if(!iArraySize)
	{
		CPrintToChatAll("{green}[{lightred}SM{green}] {olive}No players found in the guard queue.");
		
		// Select a random player to move to guards.
		new iClient = GetRandomClientFromTeam(CS_TEAM_T, true, true);
		
		// Skip the CT ban check.
		if(!iClient)
			iClient = GetRandomClientFromTeam(CS_TEAM_T, false, true);
		
		// Skip the CT ban check and the time played check.
		if(!iClient)
			iClient = GetRandomClientFromTeam(CS_TEAM_T, false, false);
		
		if(!iClient)
		{
			ServerCommand("mp_restartgame 7");
			return Plugin_Stop;
		}
		
		SetClientPendingTeam(iClient, CS_TEAM_CT);
		CPrintToChatAll("{green}[{lightred}SM{green}] {olive}Choosing a random new guard: {lightred}%N{olive}.", iClient);
		
		FixTeamRatio();
		
		ServerCommand("mp_restartgame 7");
		
		return Plugin_Stop;
	}
	
	new iQueueNum;
	decl iQueue[iArraySize];
	
	while(iArraySize > 0)
	{
		iQueue[iQueueNum] = GetArrayCell(g_aGuardQueue, GetRandomInt(0, iArraySize-1));
		RemovePlayerFromGuardQueue(iQueue[iQueueNum]);
		iQueueNum++;
		
		iArraySize--;
	}
	
	ClearArray(g_aGuardQueue);
	
	for(new i=0; i<iQueueNum; i++)
		PushArrayCell(g_aGuardQueue, iQueue[i]);
	
	// Now fix the ratio with the new queue. Manually move the first player in the queue.
	new iClient = GetArrayCell(g_aGuardQueue, 0);
	RemovePlayerFromGuardQueue(iClient);
	SetClientPendingTeam(iClient, CS_TEAM_CT);
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}The guard queue has been randomized, from now on it will be first come first serve.");
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}Choosing a guard from queue: {lightred}%N{olive}.", iClient);
	FixTeamRatio();
	
	ServerCommand("mp_restartgame 7");
	
	return Plugin_Stop;
}

public OnConfigsExecuted()
{
	new Handle:hConVar = FindConVar("mp_force_pick_time");
	if(hConVar == INVALID_HANDLE)
		return;
	
	HookConVarChange(hConVar, OnForcePickTimeChanged);
	SetConVarInt(hConVar, 999999);
}

public OnForcePickTimeChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarInt(hConVar, 999999);
}

public OnClientDisconnect_Post(iClient)
{
	RemovePlayerFromGuardQueue(iClient);
}

public Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(GetEventInt(hEvent, "team") == CS_TEAM_T)
		return;
	
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	RemovePlayerFromGuardQueue(iClient);
}

public Action:Event_RoundEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	FixTeamRatio();
}

public Action:OnJoinTeam(iClient, const String:szCommand[], iArgCount)
{
	if(iArgCount < 1)
		return Plugin_Continue;
	
	decl String:szData[2];
	GetCmdArg(1, szData, sizeof(szData));
	new iTeam = StringToInt(szData);
	
	if(!iTeam)
	{
		ClientCommand(iClient, "play %s", g_szRestrictedSound);
		PrintToChatAndConsole(iClient, "[SM] You cannot use auto select to join a team.");
		return Plugin_Handled;
	}
	
	// Make sure players can join terrorist from unassigned/spec even if T is full.
	if(GetClientTeam(iClient) <= CS_TEAM_SPECTATOR && iTeam == CS_TEAM_T)
	{
		ChangeClientTeam(iClient, iTeam);
		return Plugin_Handled;
	}
	
	if(iTeam != CS_TEAM_CT)
		return Plugin_Continue;
	
	if(!g_bHasFinishedPreGuardQueue)
	{
		ClientCommand(iClient, "play %s", g_szRestrictedSound);
		PrintToChatAndConsole(iClient, "[SM] Cannot join guards yet.");
		return Plugin_Handled;
	}
	
	if(g_bLibLoaded_TimedPunishments)
	{
		#if defined _timed_punishments_included
		if(TimedPunishment_GetSecondsLeft(iClient, TP_TYPE_CTBAN) >= 0)
		{
			ClientCommand(iClient, "play %s", g_szRestrictedSound);
			PrintToChatAndConsole(iClient, "[SM] Cannot join guards because you are CT banned.");
			return Plugin_Handled;
		}
		#endif
	}
	
	if(!DoesClientHaveRequiredHoursForGuard(iClient))
	{
		ClientCommand(iClient, "play %s", g_szRestrictedSound);
		PrintToChatAndConsole(iClient, "[SM] Cannot join guards because you must play at least 5 hours.");
		return Plugin_Handled;
	}
	
	if(!CanClientJoinGuards(iClient))
	{
		new iIndex = FindValueInArray(g_aGuardQueue, iClient);
		if(iIndex == -1)
		{
			PrintToChatAndConsole(iClient, "[SM] Guards team full. Type !guard to join the queue.");
		}
		else
		{
			PrintToChatAndConsole(iClient, "[SM] Guards team full. You are #%i in the queue.", iIndex + 1);
		}
		
		ClientCommand(iClient, "play %s", g_szRestrictedSound);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:OnGuardQueue(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetClientTeam(iClient) == CS_TEAM_CT)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You are already a guard.");
		PrintToConsole(iClient, "[SM] You are already a guard.");
		
		return Plugin_Handled;
	}
	
	if(GetClientTeam(iClient) != CS_TEAM_T)
	{
		ClientCommand(iClient, "play %s", g_szRestrictedSound);
		
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You must be a prisoner to join the queue.");
		PrintToConsole(iClient, "[SM] You must be a prisoner to join the queue.");
		
		return Plugin_Handled;
	}
	
	if(g_bLibLoaded_TimedPunishments)
	{
		#if defined _timed_punishments_included
		if(TimedPunishment_GetSecondsLeft(iClient, TP_TYPE_CTBAN) >= 0)
		{
			ClientCommand(iClient, "play %s", g_szRestrictedSound);
			
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Cannot join guards because you are CT banned.");
			PrintToConsole(iClient, "[SM] Cannot join guards because you are CT banned.");
			
			return Plugin_Handled;
		}
		#endif
	}
	
	if(!DoesClientHaveRequiredHoursForGuard(iClient))
	{
		ClientCommand(iClient, "play %s", g_szRestrictedSound);
		
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Cannot join guards because you must play at least 5 hours.");
		PrintToConsole(iClient, "[SM] Cannot join guards because you must play at least 5 hours.");
		
		return Plugin_Handled;
	}
	
	new iIndex = FindValueInArray(g_aGuardQueue, iClient);
	if(iIndex == -1)
		iIndex = PushArrayCell(g_aGuardQueue, iClient);
	
	if(g_bHasFinishedPreGuardQueue)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You are #%i in the guard queue.", iIndex + 1);
		PrintToConsole(iClient, "[SM] You are #%i in the guard queue.", iIndex + 1);
	}
	else
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You are in the guard queue.");
		PrintToConsole(iClient, "[SM] You are in the guard queue.");
	}
	
	return Plugin_Handled;
}

bool:RemovePlayerFromGuardQueue(iClient)
{
	new iIndex = FindValueInArray(g_aGuardQueue, iClient);
	if(iIndex == -1)
		return;
	
	RemoveFromArray(g_aGuardQueue, iIndex);
}

FixTeamRatio()
{
	new bool:bMovedPlayers;
	while(ShouldMovePrisonerToGuard())
	{
		new iClient;
		if(GetArraySize(g_aGuardQueue))
		{
			iClient = GetArrayCell(g_aGuardQueue, 0);
			RemovePlayerFromGuardQueue(iClient);
			
			CPrintToChatAll("{green}[{lightred}SM{green}] {olive}Choosing a guard from queue: {lightred}%N{olive}.", iClient);
		}
		else
		{
			iClient = GetRandomClientFromTeam(CS_TEAM_T, true, true);
			
			// Skip the CT ban check.
			if(!iClient)
				iClient = GetRandomClientFromTeam(CS_TEAM_T, false, true);
			
			// Skip the CT ban check and the time played check.
			if(!iClient)
				iClient = GetRandomClientFromTeam(CS_TEAM_T, false, false);
			
			if(iClient)
				CPrintToChatAll("{green}[{lightred}SM{green}] {olive}Choosing a random new guard: {lightred}%N{olive}.", iClient);
		}
		
		if(!iClient)
		{
			CPrintToChatAll("{green}[{lightred}SM{green}] {olive}Could not find a valid player to switch to guards.");
			break;
		}
		
		SetClientPendingTeam(iClient, CS_TEAM_CT);
		bMovedPlayers = true;
	}
	
	if(bMovedPlayers)
		return;
	
	while(ShouldMoveGuardToPrisoner())
	{
		new iClient = GetRandomClientFromTeam(CS_TEAM_CT);
		if(!iClient)
			break;
		
		SetClientPendingTeam(iClient, CS_TEAM_T);
		
		ShiftArrayUp(g_aGuardQueue, 0);
		SetArrayCell(g_aGuardQueue, 0, iClient);
	}
}

GetRandomClientFromTeam(iTeam, bool:bCheckCTBans=false, bool:bCheckHoursPlayed=false)
{
	new iNumFound;
	decl iClients[MAXPLAYERS];
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientPendingTeam(iClient) != iTeam)
			continue;
		
		if(bCheckCTBans)
		{
			if(g_bLibLoaded_TimedPunishments)
			{
				#if defined _timed_punishments_included
				if(TimedPunishment_GetSecondsLeft(iClient, TP_TYPE_CTBAN) >= 0)
					continue;
				#endif
			}
		}
		
		if(bCheckHoursPlayed)
		{
			if(!DoesClientHaveRequiredHoursForGuard(iClient))
				continue;
		}
		
		iClients[iNumFound++] = iClient;
	}
	
	if(!iNumFound)
		return 0;
	
	return iClients[GetRandomInt(0, iNumFound-1)];
}

bool:DoesClientHaveRequiredHoursForGuard(iClient)
{
	if(g_bLibLoaded_DatabaseUserStats && g_bLibLoaded_ClientTimes)
	{
		#if defined _database_user_stats_included && defined _client_times_included
		if((DBUserStats_GetServerTimePlayed(iClient) + ClientTimes_GetTimePlayed(iClient)) < 18000)
			return false;
		#else
		if(iClient)
		{
			// Just here to suppress the warning incase define fails.
		}
		#endif
	}
	
	return true;
}

bool:ShouldMoveGuardToPrisoner()
{
	new iNumGuards, iNumPrisoners;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		switch(GetClientPendingTeam(iClient))
		{
			case CS_TEAM_CT: iNumGuards++;
			case CS_TEAM_T: iNumPrisoners++;
		}
	}
	
	if(iNumGuards <= 1)
		return false;
	
	new iMaxGuards = RoundToFloor(float(iNumPrisoners) / GetConVarFloat(cvar_prisoners_per_guard));
	if(iNumGuards <= iMaxGuards)
		return false;
	
	return true;
}

bool:ShouldMovePrisonerToGuard()
{
	new iNumGuards, iNumPrisoners;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		switch(GetClientPendingTeam(iClient))
		{
			case CS_TEAM_CT: iNumGuards++;
			case CS_TEAM_T: iNumPrisoners++;
		}
	}
	
	iNumPrisoners--;
	iNumGuards++;
	
	if(iNumPrisoners < 1)
		return false;
	
	new Float:fNumPrisonersPerGuard = float(iNumPrisoners) / float(iNumGuards);
	if(fNumPrisonersPerGuard < GetConVarFloat(cvar_prisoners_per_guard))
		return false;
	
	return true;
}

bool:CanClientJoinGuards(iClient)
{
	new iNumGuards, iNumPrisoners;
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		switch(GetClientPendingTeam(iPlayer))
		{
			case CS_TEAM_CT: iNumGuards++;
			case CS_TEAM_T: iNumPrisoners++;
		}
	}
	
	iNumGuards++;
	if(GetClientPendingTeam(iClient) == CS_TEAM_T)
		iNumPrisoners--;
	
	if(iNumGuards <= 1)
		return true;
	
	new Float:fNumPrisonersPerGuard = float(iNumPrisoners) / float(iNumGuards);
	if(fNumPrisonersPerGuard < GetConVarFloat(cvar_prisoners_per_guard))
		return false;
	
	new iGuardsNeeded = RoundToCeil(fNumPrisonersPerGuard - GetConVarFloat(cvar_prisoners_per_guard));
	if(iGuardsNeeded < 1)
		iGuardsNeeded = 1;
	
	new iQueueSize = GetArraySize(g_aGuardQueue);
	if(iGuardsNeeded > iQueueSize)
		return true;
	
	for(new i=0; i<iGuardsNeeded; i++)
	{
		if(iClient == GetArrayCell(g_aGuardQueue, i))
			return true;
	}
	
	return false;
}

GetClientPendingTeam(iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_iPendingTeamNum");
}

SetClientPendingTeam(iClient, iTeam)
{
	// If the client is a prisoner make sure to end their last request before moving them.
	if(GetClientTeam(iClient) == TEAM_PRISONERS)
		UltJB_LR_EndLastRequest(iClient);
	
	g_bBlockJoinTeamMessage = true;
	
	CS_SwitchTeam(iClient, iTeam);
	SetEntProp(iClient, Prop_Send, "m_iPendingTeamNum", iTeam);
	
	g_bBlockJoinTeamMessage = false;
}

public Action:Event_PlayerTeam_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(g_bBlockJoinTeamMessage)
		SetEventBroadcast(hEvent, true);
	
	return Plugin_Continue;
}

PrintToChatAndConsole(iClient, const String:szFormat[], any:...)
{
	decl String:szBuffer[256];
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 3);
	
	PrintToChat(iClient, szBuffer);
	PrintToConsole(iClient, szBuffer);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(GetTeamClientCount(TEAM_GUARDS) > 0)
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}