#include <sourcemod>
#include <cstrike>
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Force Map End";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Forces the map to end when the timelimit runs out.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_mp_timelimit;
new Handle:cvar_enabled;
new Handle:cvar_waitonroundend;

new Handle:g_hTimer;
new bool:g_bSetAsLastRound;


public OnPluginStart()
{
	CreateConVar("force_map_end_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_mp_timelimit = FindConVar("mp_timelimit");
	
	cvar_enabled = CreateConVar("sv_forcemapend_enabled", "1", "Enable or disable the plugin.");
	cvar_waitonroundend = CreateConVar("sv_forcemapend_waitonroundend", "0", "0: Instantly change on time limit expiring -- 1: Wait on the round to end.");
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("force_map_end");
	
	CreateNative("ForceMapEnd_SetCurrentRoundAsLast", _ForceMapEnd_SetCurrentRoundAsLast);
	CreateNative("ForceMapEnd_ForceChangeInSeconds", _ForceMapEnd_ForceChangeInSeconds);
	
	return APLRes_Success;
}

public _ForceMapEnd_SetCurrentRoundAsLast(Handle:hPlugin, iNumParams)
{
	g_bSetAsLastRound = true;
}

public _ForceMapEnd_ForceChangeInSeconds(Handle:hPlugin, iNumParams)
{
	decl iTimeLimit;
	if(!GetMapTimeLimit(iTimeLimit))
		return false;
	
	decl iTimeLeft;
	if(!GetMapTimeLeft(iTimeLeft))
		return false;
	
	iTimeLimit = (iTimeLimit * 60) - (iTimeLeft - GetNativeCell(1));
	
	SetConVarInt(cvar_mp_timelimit, RoundToCeil(float(iTimeLimit) / 60.0));
	ExtendMapTimeLimit(1);
	
	return true;
}

public OnMapStart()
{
	g_bSetAsLastRound = false;
	StartTimer_CheckTimeLeft();
}

public OnMapEnd()
{
	StopTimer_CheckTimeLeft();
}

StopTimer_CheckTimeLeft()
{
	if(g_hTimer == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer);
	g_hTimer = INVALID_HANDLE;
}

StartTimer_CheckTimeLeft()
{
	StopTimer_CheckTimeLeft();
	g_hTimer = CreateTimer(1.0, Timer_CheckTimeLeft, _, TIMER_REPEAT);
}

public Action:Timer_CheckTimeLeft(Handle:hTimer)
{
	if(!GetConVarBool(cvar_enabled))
	{
		g_hTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	decl iTime;
	if(!GetMapTimeLimit(iTime) || !iTime)
		return Plugin_Continue;
	
	if(!GetMapTimeLeft(iTime))
		return Plugin_Continue;
	
	switch(iTime)
	{
		case 1800: CPrintToChatAll("{red}Time remaining: {olive}30 minutes%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 1200: CPrintToChatAll("{red}Time remaining: {olive}20 minutes%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 600: CPrintToChatAll("{red}Time remaining: {olive}10 minutes%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 300: CPrintToChatAll("{red}Time remaining: {olive}5 minutes%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 120: CPrintToChatAll("{red}Time remaining: {olive}2 minutes%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 60: CPrintToChatAll("{red}Time remaining: {olive}60 seconds%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 30: CPrintToChatAll("{red}Time remaining: {olive}30 seconds%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 15: CPrintToChatAll("{red}Time remaining: {olive}15 seconds%s.", g_bSetAsLastRound ? " {lightgreen}(or round end){olive}" : "");
		case 3: CPrintToChatAll("{red}3..");
		case 2: CPrintToChatAll("{red}2..");
		case 1: CPrintToChatAll("{red}1..");
	}
	
	// WARNING: Must check if its less than at least -1 or lower. Otherwise things can break since GetMapTimeLeft() can return -1 when the server hasn't simulated a tick yet.
	if(iTime < -1)
	{
		g_bSetAsLastRound = true;
		
		if(GetConVarBool(cvar_waitonroundend))
		{
			CPrintToChatAll("{red}This is the last round.");
		}
		else
		{
			CS_TerminateRound(0.1, CSRoundEnd_Draw);
		}
		
		g_hTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:CS_OnTerminateRound(&Float:fDelay, &CSRoundEndReason:reason)
{
	if(!GetConVarBool(cvar_enabled))
		return;
	
	if(cvar_mp_timelimit == INVALID_HANDLE)
		return;
	
	decl iTime;
	if(!GetMapTimeLeft(iTime))
		return;
	
	if(!g_bSetAsLastRound && iTime != 0)
		return;
	
	StopTimer_CheckTimeLeft();
	SetConVarInt(cvar_mp_timelimit, 0);
}