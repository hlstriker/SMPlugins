#include <sourcemod>
#include <cstrike>
#include <hls_color_chat>
#include <emitsoundany>
#include <sdktools_stringtables>
#include "../Includes/ultjb_last_request"

#undef REQUIRE_PLUGIN
#include "../../../Libraries/PlayerChat/player_chat"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Command Notify Admins";
new const String:PLUGIN_VERSION[] = "1.9";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The notify admins plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:FREEKILL_SOUND[] = "sound/swoobles/ultimate_jailbreak/freekill.mp3";

new bool:g_bHasDiedThisRound[MAXPLAYERS+1];
new String:g_szKilledBy[MAXPLAYERS+1][MAX_NAME_LENGTH+1];
new bool:g_bIsAdmin[MAXPLAYERS+1];

#define FREEKILL_USAGE_DELAY	30.0
new Float:g_fNextFreekillUsage[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("ultjb_command_notify_admins_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_freekill", OnFreeKill, "sm_freekill <msg> - Used to let admins know you were freekilled.");
	//RegConsoleCmd("sm_other", OnOther, "sm_other <msg> - Message an admin.");
	RegAdminCmd("sm_whokilled", OnWhoKilled, ADMFLAG_SLAY, "sm_whokilled <who> - Used to check who killed a player.");
	RegAdminCmd("sm_wk", OnWhoKilled, ADMFLAG_SLAY, "sm_wk <who> - Used to check who killed a player.");
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
}

public OnMapStart()
{
	AddFileToDownloadsTable(FREEKILL_SOUND);
	PrecacheSoundAny(FREEKILL_SOUND[6]);
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		g_bHasDiedThisRound[iClient] = false;
		g_fNextFreekillUsage[iClient] = 0.0;
	}
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	g_bHasDiedThisRound[iClient] = true;
	
	if(1 <= iAttacker <= MaxClients)
	{
		GetClientName(iAttacker, g_szKilledBy[iClient], sizeof(g_szKilledBy[]));
	}
	else
	{
		strcopy(g_szKilledBy[iClient], sizeof(g_szKilledBy[]), "world");
	}
}

public Action:PlayerChat_OnMessage(iClient, ChatType:iChatType, const String:szMessage[])
{
	if(strlen(szMessage) < 9)
		return Plugin_Continue;
	
	if(szMessage[0] != '!'
	|| szMessage[1] != 'f'
	|| szMessage[2] != 'r'
	|| szMessage[3] != 'e'
	|| szMessage[4] != 'e'
	|| szMessage[5] != 'k'
	|| szMessage[6] != 'i'
	|| szMessage[7] != 'l'
	|| szMessage[8] != 'l')
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action:OnFreeKill(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgCount < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_freekill <msg explaining the freekill>");
		return Plugin_Handled;
	}
	
	if(!g_bHasDiedThisRound[iClient] || IsPlayerAlive(iClient))
	{
		ReplyToCommand(iClient, "[SM] You have not died this round.");
		return Plugin_Handled;
	}
	
	if(g_fNextFreekillUsage[iClient] > GetEngineTime())
	{
		ReplyToCommand(iClient, "[SM] You cannot use this command again so soon.");
		return Plugin_Handled;
	}
	
	if(g_bIsAdmin[iClient])
	{
		ReplyToCommand(iClient, "[SM] You are an admin, handle your own freekills.");
		return Plugin_Handled;
	}
	
	if(GetClientTeam(iClient) == TEAM_GUARDS)
	{
		ReplyToCommand(iClient, "[SM] Guards may not use the freekill command.");
		return Plugin_Handled;
	}
	
	g_fNextFreekillUsage[iClient] = GetEngineTime() + FREEKILL_USAGE_DELAY;
	
	new iLen;
	decl String:szReason[256], String:szReasonTemp[256], String:szReasonColored[256];
	
	for(new i=1; i<=iArgCount; i++)
	{
		GetCmdArg(i, szReasonTemp, sizeof(szReasonTemp));
		iLen += FormatEx(szReason[iLen], sizeof(szReason)-iLen, " %s", szReasonTemp);
	}
	
	strcopy(szReasonColored, sizeof(szReasonColored), szReason);
	
	if(iLen)
		Format(szReasonColored, sizeof(szReasonColored), "{red}Message: {yellow}%s", szReason);
	
	Format(szReasonTemp, sizeof(szReasonTemp), "{red}[FREEKILL] {olive}%N {white}freekilled by {olive}%s{white}?", iClient, g_szKilledBy[iClient]);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(iClient != iPlayer)
		{
			if(!g_bIsAdmin[iPlayer] && GetClientTeam(iPlayer) != TEAM_GUARDS && !IsFakeClient(iPlayer))
				continue;
		}
		
		CPrintToChat(iPlayer, szReasonTemp);
		
		if(iLen)
			CPrintToChat(iPlayer, szReasonColored);
		
		EmitSoundToClientAny(iPlayer, FREEKILL_SOUND[6], iPlayer, 9, SNDLEVEL_NONE);
	}
	
	LogAction(iClient, -1, "\"%L\" triggered freekill (text %s)", iClient, szReason);
	
	return Plugin_Handled;
}

public Action:OnOther(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgCount < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_other <msg>");
		return Plugin_Handled;
	}
	
	new iLen;
	decl String:szReason[256], String:szReasonTemp[256];
	for(new i=1; i<=iArgCount; i++)
	{
		GetCmdArg(i, szReasonTemp, sizeof(szReasonTemp));
		iLen += FormatEx(szReason[iLen], sizeof(szReason)-iLen, " %s", szReasonTemp);
	}
	
	Format(szReason, sizeof(szReason), "{purple}[OTHER] {olive}%N: {yellow}%s", iClient, szReason);
	
	for(new iAdmin=1; iAdmin<=MaxClients; iAdmin++)
	{
		if(!IsClientInGame(iAdmin))
			continue;
		
		if(!g_bIsAdmin[iAdmin])
			continue;
		
		CPrintToChat(iAdmin, szReason);
	}
	
	return Plugin_Handled;
}

public Action:OnWhoKilled(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_whokilled <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, false, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(!g_bHasDiedThisRound[iTarget] || IsPlayerAlive(iTarget))
	{
		ReplyToCommand(iClient, "[SM] %N has not died this round.", iTarget);
		return Plugin_Handled;
	}
	
	ReplyToCommand(iClient, "[SM] %N was killed by %s.", iTarget, g_szKilledBy[iTarget]);
	
	return Plugin_Handled;
}

public OnClientConnected(iClient)
{
	g_bIsAdmin[iClient] = false;
}

public OnClientPostAdminCheck(iClient)
{
	if(CheckCommandAccess(iClient, "sm_say", ADMFLAG_CHAT, false))
		g_bIsAdmin[iClient] = true;
}

