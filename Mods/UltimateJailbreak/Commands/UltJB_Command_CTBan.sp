#include <sourcemod>
#include <cstrike>
#include <sdktools_functions>

#undef REQUIRE_PLUGIN
#include "../../../Libraries/TimedPunishments/timed_punishments"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Command CT Ban";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The CT Ban plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bLibLoaded_TimedPunishments;

#if !defined MAX_REASON_LENGTH
#define MAX_REASON_LENGTH	255
#endif


public OnPluginStart()
{
	CreateConVar("ultjb_command_ctban_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_ctban", Command_CTBan, ADMFLAG_BAN, "sm_ctban <#steamid|#userid|name> <minutes> \"reason\" - Bans a player from joining the CT team.");
	RegAdminCmd("sm_unctban", Command_UnCTBan, ADMFLAG_BAN, "sm_unctban <#steamid|#userid|name> - Removes a players CT ban.");
	RegAdminCmd("sm_check_ctban", Command_CheckCTBan, ADMFLAG_BAN, "sm_check_ctban <#steamid|#userid|name> - Checks to see if a player is CT banned.");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_TimedPunishments = LibraryExists("timed_punishments");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "timed_punishments"))
	{
		g_bLibLoaded_TimedPunishments = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "timed_punishments"))
	{
		g_bLibLoaded_TimedPunishments = false;
	}
}

#if defined _timed_punishments_included
public TimedPunishment_OnPunishmentLoaded(iClient, TimedPunishmentType:punishment_type)
{
	if(punishment_type != TP_TYPE_CTBAN)
		return;
	
	if(GetClientTeam(iClient) != CS_TEAM_CT)
		return;
	
	ChangeClientTeam(iClient, CS_TEAM_T);
	ForcePlayerSuicide(iClient);
	PrintToChat(iClient, "[SM] You have been moved to T because you are CT banned.");
}
#endif

#if defined _timed_punishments_included
public TimedPunishment_OnPunishmentExpired(iClient, TimedPunishmentType:punishment_type)
{
	if(punishment_type != TP_TYPE_CTBAN)
		return;
	
	PrintToChatAll("[SM] %N's CT ban has expired.", iClient);
}
#endif

public Action:Command_CTBan(iClient, iArgs)
{
	if(iArgs < 3)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_ctban <#steamid|#userid|name> <minutes> \"reason\"");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true);
	if(iTarget != -1)
	{
		GetClientAuthString(iTarget, szTarget, sizeof(szTarget));
	}
	else
	{
		decl String:szAuthID[32], i;
		for(i=1; i<=MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;
			
			GetClientAuthString(i, szAuthID, sizeof(szAuthID));
			if(!StrEqual(szTarget, szAuthID))
				continue;
			
			iTarget = i;
			break;
		}
		
		if(i > MaxClients)
			iTarget = 0;
	}
	
	decl String:szMinutes[12];
	GetCmdArg(2, szMinutes, sizeof(szMinutes));
	new iSeconds = StringToInt(szMinutes) * 60;
	if(iSeconds < 0)
		iSeconds = 0;
	
	new iLen;
	decl String:szReason[MAX_REASON_LENGTH+1], String:szReasonTemp[MAX_REASON_LENGTH+1];
	for(new i=3; i<=iArgs; i++)
	{
		GetCmdArg(i, szReasonTemp, sizeof(szReasonTemp));
		iLen += FormatEx(szReason[iLen], sizeof(szReason)-iLen, " %s", szReasonTemp);
	}
	
	if(!iLen)
	{
		ReplyToCommand(iClient, "[SM] Please enter a reason.");
		return Plugin_Handled;
	}
	
	if(g_bLibLoaded_TimedPunishments)
	{
		#if defined _timed_punishments_included
		if(!TimedPunishment_AddPunishment(iClient, iTarget, TP_TYPE_CTBAN, iSeconds, szReason, szTarget))
		{
			ReplyToCommand(iClient, "[SM] There was an error.");
			return Plugin_Handled;
		}
		#else
		if(g_bLibLoaded_TimedPunishments) // Redundant if statement just to suppress the unreachable code warning.
		{
			ReplyToCommand(iClient, "[SM] Punishment library not included.");
			return Plugin_Handled;
		}
		#endif
	}
	else
	{
		ReplyToCommand(iClient, "[SM] Punishment plugin not loaded.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		if(GetClientTeam(iTarget) == CS_TEAM_CT)
		{
			ChangeClientTeam(iTarget, CS_TEAM_T);
			ForcePlayerSuicide(iTarget);
		}
		
		GetClientName(iTarget, szTarget, sizeof(szTarget));
		
		LogAction(iClient, iTarget, "\"%L\" ct banned \"%L\" (minutes \"%i\")", iClient, iTarget, (iSeconds / 60));
	}
	else
	{
		LogAction(iClient, -1, "\"%L\" ct banned (authid \"%s\") (minutes \"%i\")", iClient, szTarget, (iSeconds / 60));
	}
	
	if(iSeconds)
	{
		//ReplyToCommand(iClient, "[SM] %s has been CT banned for %i minutes.", szTarget, (iSeconds / 60));
		PrintToChatAll("[SM] %s has been CT banned for %i minutes by %N.", szTarget, (iSeconds / 60), iClient);
	}
	else
	{
		//ReplyToCommand(iClient, "[SM] %s has been CT banned permanently.", szTarget);
		PrintToChatAll("[SM] %s has been CT banned permanently by %N.", szTarget, iClient);
	}
	
	return Plugin_Handled;
}

public Action:Command_UnCTBan(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_unctban <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true);
	if(iTarget != -1)
	{
		GetClientAuthString(iTarget, szTarget, sizeof(szTarget));
	}
	else
	{
		decl String:szAuthID[32], i;
		for(i=1; i<=MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;
			
			GetClientAuthString(i, szAuthID, sizeof(szAuthID));
			if(!StrEqual(szTarget, szAuthID))
				continue;
			
			iTarget = i;
			break;
		}
		
		if(i > MaxClients)
			iTarget = 0;
	}
	
	if(g_bLibLoaded_TimedPunishments)
	{
		#if defined _timed_punishments_included
		if(!TimedPunishment_RemovePunishment(iClient, szTarget, TP_TYPE_CTBAN))
		{
			ReplyToCommand(iClient, "[SM] There was an error.");
			return Plugin_Handled;
		}
		#else
		if(g_bLibLoaded_TimedPunishments) // Redundant if statement just to suppress the unreachable code warning.
		{
			ReplyToCommand(iClient, "[SM] Punishment library not included.");
			return Plugin_Handled;
		}
		#endif
	}
	else
	{
		ReplyToCommand(iClient, "[SM] Punishment plugin not loaded.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		//ReplyToCommand(iClient, "[SM] %N's CT ban has been lifted.", iTarget);
		PrintToChatAll("[SM] %N's CT ban has been lifted by %N.", iTarget, iClient);
		
		LogAction(iClient, iTarget, "\"%L\" ct unbanned \"%L\"", iClient, iTarget);
	}
	else
	{
		//ReplyToCommand(iClient, "[SM] %s's CT ban has been lifted.", szTarget);
		PrintToChatAll("[SM] %s's CT ban has been lifted by %N.", szTarget, iClient);
		
		LogAction(iClient, -1, "\"%L\" ct unbanned (authid \"%s\")", iClient, szTarget);
	}
	
	return Plugin_Handled;
}

public Action:Command_CheckCTBan(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_check_ctban <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(g_bLibLoaded_TimedPunishments)
	{
		#if defined _timed_punishments_included
		new iSecondsLeft = TimedPunishment_GetSecondsLeft(iTarget, TP_TYPE_CTBAN);
		if(iSecondsLeft < 0)
		{
			ReplyToCommand(iClient, "[SM] %N is not CT banned.", iTarget);
		}
		else if(iSecondsLeft == 0)
		{
			decl String:szReason[MAX_REASON_LENGTH];
			TimedPunishment_GetReason(iTarget, TP_TYPE_CTBAN, szReason, sizeof(szReason));
			ReplyToCommand(iClient, "[SM] %N is permanently CT banned. Reason: \"%s\"", iTarget, szReason);
		}
		else
		{
			decl String:szReason[MAX_REASON_LENGTH];
			TimedPunishment_GetReason(iTarget, TP_TYPE_CTBAN, szReason, sizeof(szReason));
			ReplyToCommand(iClient, "[SM] %N is CT banned for %.02f more minutes. Reason: \"%s\"", iTarget, (float(iSecondsLeft) / 60.0), szReason);
		}
		#else
		ReplyToCommand(iClient, "[SM] Punishment library not included.");
		#endif
	}
	else
	{
		ReplyToCommand(iClient, "[SM] Punishment plugin not loaded.");
	}
	
	return Plugin_Handled;
}
