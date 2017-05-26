#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Contest - Most Jumps";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Contest - Most Jumps.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Most Jumps"
#define LR_CATEGORY		"Contest"
#define LR_DESCRIPTION	""

new bool:g_bHasOpponent[MAXPLAYERS+1];
new g_iEffectSelectedID[MAXPLAYERS+1];

new g_iJumpCount[MAXPLAYERS+1];

new Handle:g_hJumpTimer[MAXPLAYERS+1];
new g_iTimerCountdown[MAXPLAYERS+1];

new Handle:cvar_countdown;
new Handle:cvar_timelimit;


public OnPluginStart()
{
	CreateConVar("lr_contest_most_jumps_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_countdown = CreateConVar("lr_jump_contest_most_jumps_countdown", "5", "The number of seconds to countdown before starting the contest.", _, true, 1.0);
	cvar_timelimit = CreateConVar("lr_jump_contest_most_jumps_timelimit", "20", "The number of seconds the contest lasts.", _, true, 1.0);
	
	HookEvent("player_jump", EventPlayerJump_Post, EventHookMode_Post);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT | LR_FLAG_ALLOW_WEAPON_PICKUPS, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	UltJB_LR_DisplayOpponentSelection(iClient, OnOpponentSelectedSuccess);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	if(!g_bHasOpponent[iClient])
		return;
	
	g_bHasOpponent[iClient] = false;
	g_bHasOpponent[iOpponent] = false;
	
	if(g_hJumpTimer[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hJumpTimer[iClient]);
		g_hJumpTimer[iClient] = INVALID_HANDLE;
	}
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StopEffect(iClient, g_iEffectSelectedID[iClient]);
		UltJB_Effects_StopEffect(iOpponent, g_iEffectSelectedID[iClient]);
	}
}

public OnOpponentSelectedSuccess(iClient, iOpponent)
{
	g_bHasOpponent[iClient] = true;
	g_bHasOpponent[iOpponent] = true;
	
	UltJB_Effects_DisplaySelectionMenu(iClient, OnEffectSelected_Success, OnEffectSelected_Failed);
}

public OnEffectSelected_Success(iClient, iEffectID)
{
	g_iEffectSelectedID[iClient] = iEffectID;
	PrepareClients(iClient);
}

public OnEffectSelected_Failed(iClient)
{
	g_iEffectSelectedID[iClient] = 0;
	PrepareClients(iClient);
}

PrepareClients(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	
	g_iTimerCountdown[iClient] = 0;
	g_hJumpTimer[iClient] = CreateTimer(1.0, Timer_Countdown, iClient, TIMER_REPEAT);
	
	PrintToChat(iClient, "[SM] The jump contest will start in %i seconds.", GetConVarInt(cvar_countdown));
	PrintToChat(iOpponent, "[SM] The jump contest will start in %i seconds.", GetConVarInt(cvar_countdown));
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StartEffect(iClient, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
		UltJB_Effects_StartEffect(iOpponent, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
	}
}

public EventPlayerJump_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	static iClient;
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!g_bHasOpponent[iClient])
		return;
	
	g_iJumpCount[iClient]++;
}

public Action:Timer_Countdown(Handle:hTimer, any:iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(!iOpponent)
	{
		g_hJumpTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_iTimerCountdown[iClient]++;
	
	if(g_iTimerCountdown[iClient] == GetConVarInt(cvar_countdown))
	{
		g_iJumpCount[iClient] = 0;
		g_iJumpCount[iOpponent] = 0;
		
		PrintToChat(iClient, "[SM] The jump contest will end in %i seconds.", GetConVarInt(cvar_timelimit));
		PrintToChat(iOpponent, "[SM] The jump contest will end in %i seconds.", GetConVarInt(cvar_timelimit));
		
		g_hJumpTimer[iClient] = CreateTimer(GetConVarFloat(cvar_timelimit), Timer_JumpEnd, iClient);
		return Plugin_Stop;
	}
	
	PrintToChat(iClient, "[SM] %i..", GetConVarInt(cvar_countdown) - g_iTimerCountdown[iClient]);
	PrintToChat(iOpponent, "[SM] %i..", GetConVarInt(cvar_countdown) - g_iTimerCountdown[iClient]);
	
	return Plugin_Continue;
}

public Action:Timer_JumpEnd(Handle:hTimer, any:iClient)
{
	g_hJumpTimer[iClient] = INVALID_HANDLE;
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(!iOpponent)
	{
		UltJB_LR_EndLastRequest(iClient);
		return;
	}
	
	decl iWinner, iLoser;
	
	if(g_iJumpCount[iClient] == g_iJumpCount[iOpponent])
	{
		PrintToChat(iClient, "[SM] You tied! Jumped %i times.", g_iJumpCount[iClient]);
		PrintToChat(iOpponent, "[SM] You tied! Jumped %i times.", g_iJumpCount[iOpponent]);
		
		UltJB_LR_EndLastRequest(iClient);
		return;
	}
	else if(g_iJumpCount[iClient] > g_iJumpCount[iOpponent])
	{
		iWinner = iClient;
		iLoser = iOpponent;
	}
	else
	{
		iWinner = iOpponent;
		iLoser = iClient;
	}
	
	PrintToChat(iWinner, "[SM] You won the contest with %i (%i) jumps!", g_iJumpCount[iWinner], g_iJumpCount[iLoser]);
	PrintToChat(iLoser, "[SM] %N won the contest with %i (%i) jumps.", iWinner, g_iJumpCount[iWinner], g_iJumpCount[iLoser]);
	
	SDKHooks_TakeDamage(iLoser, iWinner, iWinner, 99999.0);
}