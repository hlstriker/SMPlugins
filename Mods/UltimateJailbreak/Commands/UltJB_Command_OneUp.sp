#include <sourcemod>
#include <cstrike>
#include <sdktools_functions>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Command 1Up";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The 1up plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fDeathOrigin[MAXPLAYERS+1][3];
new Float:g_fDeathAngles[MAXPLAYERS+1][3];
new bool:g_bHasDiedThisRound[MAXPLAYERS+1];
new Float:g_fDeathTime[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("ultjb_command_one_up_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_1up", Command_OneUp, ADMFLAG_KICK, "sm_1up <#steamid|#userid|name> - Respawns a player in the spot they died.");
	RegAdminCmd("sm_xup", Command_OneUpSeconds, ADMFLAG_KICK, "sm_xup <seconds> - Respawns terrorists that died in the last X seconds.");
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	
	CreateTimer(0.3, Timer_GetPlayerPositions, _, TIMER_REPEAT);
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		g_bHasDiedThisRound[iClient] = false;
}

public Action:Timer_GetPlayerPositions(Handle:hTimer)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!IsPlayerAlive(iClient))
			continue;
		
		if(GetEntityFlags(iClient) & FL_DUCKING)
			continue;
		
		GetClientAbsOrigin(iClient, g_fDeathOrigin[iClient]);
		GetClientAbsAngles(iClient, g_fDeathAngles[iClient]);
	}
}

/*
public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnPostThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	if(GetEntityFlags(iClient) & FL_DUCKING)
		return;
	
	GetClientAbsOrigin(iClient, g_fDeathOrigin[iClient]);
	GetClientAbsAngles(iClient, g_fDeathAngles[iClient]);
}
*/

public EventPlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	g_bHasDiedThisRound[iClient] = true;
	g_fDeathTime[iClient] = GetEngineTime();
}

public Action:Command_OneUp(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_1up <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, false, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(!OneUp(iTarget, iClient))
	{
		ReplyToCommand(iClient, "[SM] %N has not died this round.", iTarget);
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

public Action:Command_OneUpSeconds(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_xup <seconds>");
		return Plugin_Handled;
	}
	
	decl String:szSeconds[12];
	GetCmdArg(1, szSeconds, sizeof(szSeconds));
	new iSeconds = StringToInt(szSeconds);
	
	if(!OneUpSeconds(iSeconds, iClient))
	{
		ReplyToCommand(iClient, "[SM] No terrorists have died in the last %i seconds.", iSeconds);
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

bool:OneUp(iClient, iAdmin)
{
	if(!g_bHasDiedThisRound[iClient])
		return false;
	
	CS_RespawnPlayer(iClient);
	TeleportEntity(iClient, g_fDeathOrigin[iClient], g_fDeathAngles[iClient], NULL_VECTOR);
	g_bHasDiedThisRound[iClient] = false;
	
	PrintToChatAll("%N has been one upped by %N.", iClient, iAdmin);
	LogAction(iAdmin, iClient, "\"%L\" one upped \"%L\"", iAdmin, iClient);
	
	return true;
}

bool:OneUpSeconds(iSeconds, iAdmin)
{
	new bool:bFoundClient;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != CS_TEAM_T)
			continue;
		
		if(!g_bHasDiedThisRound[iClient])
			continue;
		
		if((GetEngineTime() - iSeconds) > g_fDeathTime[iClient])
			continue;
		
		CS_RespawnPlayer(iClient);
		TeleportEntity(iClient, g_fDeathOrigin[iClient], g_fDeathAngles[iClient], NULL_VECTOR);
		g_bHasDiedThisRound[iClient] = false;
		
		PrintToChatAll("%N has been X upped by %N.", iClient, iAdmin);
		LogAction(iAdmin, iClient, "\"%L\" X upped \"%L\"", iAdmin, iClient);
		
		bFoundClient = true;
	}
	
	return bFoundClient;
}