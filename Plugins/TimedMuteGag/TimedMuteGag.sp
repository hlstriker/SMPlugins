#include <sourcemod>
#include <basecomm>
#include "../../Libraries/TimedPunishments/timed_punishments"
#include "../../Libraries/Admins/admins"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Timed mute and gag";
new const String:PLUGIN_VERSION[] = "1.15";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows admins to mute and gag players for a certain time.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("timed_mute_gag_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	LoadTranslations("common.phrases");
	
	RegAdminCmd("sm_timed_gag", Command_TimedGag, ADMFLAG_BAN, "sm_timed_gag <#steamid|#userid|name> <minutes> \"reason\" - Removes a player's ability to use chat based on time.");
	RegAdminCmd("sm_timed_mute", Command_TimedMute, ADMFLAG_BAN, "sm_timed_mute <#steamid|#userid|name> <minutes> \"reason\" - Removes a player's ability to use voice based on time.");
	RegAdminCmd("sm_timed_silence", Command_TimedSilence, ADMFLAG_BAN, "sm_timed_silence <#steamid|#userid|name> <minutes> \"reason\" - Removes a player's ability to use chat & voice based on time.");
	
	RegAdminCmd("sm_timed_ungag", Command_TimedUngag, ADMFLAG_BAN, "sm_timed_ungag <#steamid|#userid|name> - Readds a player's ability to use chat.");
	RegAdminCmd("sm_timed_unmute", Command_TimedUnmute, ADMFLAG_BAN, "sm_timed_unmute <#steamid|#userid|name> - Readds a player's ability to use voice.");
	RegAdminCmd("sm_timed_unsilence", Command_TimedUnsilence, ADMFLAG_BAN, "sm_timed_unsilence <#steamid|#userid|name> - Readds a player's ability to use chat & voice.");
	
	RegAdminCmd("sm_check_mute", Command_CheckMuteGag, ADMFLAG_BAN, "sm_check_mute <#steamid|#userid|name> - Checks to see if a player is muted.");
	RegAdminCmd("sm_check_gag", Command_CheckMuteGag, ADMFLAG_BAN, "sm_check_gag <#steamid|#userid|name> - Checks to see if a player is gagged.");
	RegAdminCmd("sm_check_silence", Command_CheckMuteGag, ADMFLAG_BAN, "sm_check_silence <#steamid|#userid|name> - Checks to see if a player is silenced.");
}

public TimedPunishment_OnPunishmentLoaded(iClient, TimedPunishmentType:punishment_type)
{
	switch(punishment_type)
	{
		case TP_TYPE_MUTE: BaseComm_SetClientMute(iClient, true);
		case TP_TYPE_GAG: BaseComm_SetClientGag(iClient, true);
	}
}

public TimedPunishment_OnPunishmentExpired(iClient, TimedPunishmentType:punishment_type)
{
	switch(punishment_type)
	{
		case TP_TYPE_MUTE:
		{
			PrintToChatAll("[SM] %N's mute punishment has expired.", iClient);
			BaseComm_SetClientMute(iClient, false);
		}
		case TP_TYPE_GAG:
		{
			PrintToChatAll("[SM] %N's gag punishment has expired.", iClient);
			BaseComm_SetClientGag(iClient, false);
		}
	}
}

public Action:Command_CheckMuteGag(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_check_mute/gag/silence <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	// Check gag.
	new iSecondsLeft = TimedPunishment_GetSecondsLeft(iTarget, TP_TYPE_GAG);
	if(iSecondsLeft < 0)
	{
		if(BaseComm_IsClientGagged(iTarget))
			ReplyToCommand(iClient, "[SM] %N is gagged until map change.", iTarget);
		else
			ReplyToCommand(iClient, "[SM] %N is not gagged.", iTarget);
	}
	else if(iSecondsLeft == 0)
	{
		decl String:szReason[MAX_REASON_LENGTH];
		TimedPunishment_GetReason(iTarget, TP_TYPE_GAG, szReason, sizeof(szReason));
		ReplyToCommand(iClient, "[SM] %N is permanently gagged. Reason: \"%s\"", iTarget, szReason);
	}
	else
	{
		decl String:szReason[MAX_REASON_LENGTH];
		TimedPunishment_GetReason(iTarget, TP_TYPE_GAG, szReason, sizeof(szReason));
		ReplyToCommand(iClient, "[SM] %N is gagged for %.02f more minutes. Reason: \"%s\"", iTarget, (float(iSecondsLeft) / 60.0), szReason);
	}
	
	// Check mute.
	iSecondsLeft = TimedPunishment_GetSecondsLeft(iTarget, TP_TYPE_MUTE);
	if(iSecondsLeft < 0)
	{
		if(BaseComm_IsClientMuted(iTarget))
			ReplyToCommand(iClient, "[SM] %N is muted until map change.", iTarget);
		else
			ReplyToCommand(iClient, "[SM] %N is not muted.", iTarget);
	}
	else if(iSecondsLeft == 0)
	{
		decl String:szReason[MAX_REASON_LENGTH];
		TimedPunishment_GetReason(iTarget, TP_TYPE_MUTE, szReason, sizeof(szReason));
		ReplyToCommand(iClient, "[SM] %N is permanently muted. Reason: \"%s\"", iTarget, szReason);
	}
	else
	{
		decl String:szReason[MAX_REASON_LENGTH];
		TimedPunishment_GetReason(iTarget, TP_TYPE_MUTE, szReason, sizeof(szReason));
		ReplyToCommand(iClient, "[SM] %N is muted for %.02f more minutes. Reason: \"%s\"", iTarget, (float(iSecondsLeft) / 60.0), szReason);
	}
	
	return Plugin_Handled;
}

public Action:Command_TimedUngag(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_timed_ungag <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindMuteGagTarget(iClient, szTarget);
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
	
	if(!TimedPunishment_RemovePunishment(iClient, szTarget, TP_TYPE_GAG))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		BaseComm_SetClientGag(iTarget, false);
		ReplyToCommand(iClient, "[SM] %N's timed gag has been lifted.", iTarget);
		PrintToChatAll("[SM] %N's timed gag has been lifted by %N.", iTarget, iClient);
		
		LogAction(iClient, iTarget, "\"%L\" timed ungagged \"%L\"", iClient, iTarget);
	}
	else
	{
		ReplyToCommand(iClient, "[SM] %s's timed gag has been lifted.", szTarget);
		PrintToChatAll("[SM] %s's timed gag has been lifted by %N.", szTarget, iClient);
		
		LogAction(iClient, -1, "\"%L\" timed ungagged (authid \"%s\")", iClient, szTarget);
	}
	
	return Plugin_Handled;
}

public Action:Command_TimedUnmute(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_timed_unmute <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindMuteGagTarget(iClient, szTarget);
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
	
	if(!TimedPunishment_RemovePunishment(iClient, szTarget, TP_TYPE_MUTE))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		BaseComm_SetClientMute(iTarget, false);
		ReplyToCommand(iClient, "[SM] %N's timed mute has been lifted.", iTarget);
		PrintToChatAll("[SM] %N's timed mute has been lifted by %N.", iTarget, iClient);
		
		LogAction(iClient, iTarget, "\"%L\" timed unmuted \"%L\"", iClient, iTarget);
	}
	else
	{
		ReplyToCommand(iClient, "[SM] %s's timed mute has been lifted.", szTarget);
		PrintToChatAll("[SM] %s's timed mute has been lifted by %N.", szTarget, iClient);
		
		LogAction(iClient, -1, "\"%L\" timed unmuted (authid \"%s\")", iClient, szTarget);
	}
	
	return Plugin_Handled;
}

public Action:Command_TimedUnsilence(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_timed_unsilence <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindMuteGagTarget(iClient, szTarget);
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
	
	if(!TimedPunishment_RemovePunishment(iClient, szTarget, TP_TYPE_GAG))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(!TimedPunishment_RemovePunishment(iClient, szTarget, TP_TYPE_MUTE))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		BaseComm_SetClientGag(iTarget, false);
		BaseComm_SetClientMute(iTarget, false);
		ReplyToCommand(iClient, "[SM] %N's timed silence has been lifted.", iTarget);
		PrintToChatAll("[SM] %N's timed silence has been lifted by %N.", iTarget, iClient);
		
		LogAction(iClient, iTarget, "\"%L\" timed unsilenced \"%L\"", iClient, iTarget);
	}
	else
	{
		ReplyToCommand(iClient, "[SM] %s's timed silence has been lifted.", szTarget);
		PrintToChatAll("[SM] %s's timed silence has been lifted by %N.", szTarget, iClient);
		
		LogAction(iClient, -1, "\"%L\" timed unsilenced (authid \"%s\")", iClient, szTarget);
	}
	
	return Plugin_Handled;
}

GetAdminsMaxTime(iClient)
{
	new AdminLevel:iLevel = Admins_GetLevel(iClient);
	
	switch(iLevel)
	{
		case AdminLevel_Junior:		return -1;		// Cannot timed punish
		case AdminLevel_Senior:		return 259200;	// 3 days
		case AdminLevel_Reputable:	return 604800;	// 7 days
		case AdminLevel_Lead:		return 0;		// Permanent
	}
	
	return -1;
}

public Action:Command_TimedGag(iClient, iArgs)
{
	if(iArgs < 3)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_timed_gag <#steamid|#userid|name> <minutes> \"reason\"");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindMuteGagTarget(iClient, szTarget);
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
	
	if((iSeconds < 1 || iSeconds > GetAdminsMaxTime(iClient)) && GetAdminsMaxTime(iClient) > 0)
	{
		ReplyToCommand(iClient, "[SM] The time you entered was too long.");
		return Plugin_Handled;
	}
	
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
	
	if(!TimedPunishment_AddPunishment(iClient, iTarget, TP_TYPE_GAG, iSeconds, szReason, szTarget))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		BaseComm_SetClientGag(iTarget, true);
		GetClientName(iTarget, szTarget, sizeof(szTarget));
		
		LogAction(iClient, iTarget, "\"%L\" timed gagged \"%L\" (minutes \"%i\")", iClient, iTarget, (iSeconds / 60));
	}
	else
	{
		LogAction(iClient, -1, "\"%L\" timed gagged (authid \"%s\") (minutes \"%i\")", iClient, szTarget, (iSeconds / 60));
	}
	
	if(iSeconds)
	{
		ReplyToCommand(iClient, "[SM] %s has been gagged for %i minutes.", szTarget, (iSeconds / 60));
		PrintToChatAll("[SM] %s has been gagged for %i minutes by %N.", szTarget, (iSeconds / 60), iClient);
	}
	else
	{
		ReplyToCommand(iClient, "[SM] %s has been gagged permanently.", szTarget);
		PrintToChatAll("[SM] %s has been gagged permanently by %N.", szTarget, iClient);
	}
	
	return Plugin_Handled;
}

public Action:Command_TimedMute(iClient, iArgs)
{
	if(iArgs < 3)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_timed_mute <#steamid|#userid|name> <minutes> \"reason\"");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindMuteGagTarget(iClient, szTarget);
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
	
	if((iSeconds < 1 || iSeconds > GetAdminsMaxTime(iClient)) && GetAdminsMaxTime(iClient) > 0)
	{
		ReplyToCommand(iClient, "[SM] The time you entered was too long.");
		return Plugin_Handled;
	}
	
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
	
	if(!TimedPunishment_AddPunishment(iClient, iTarget, TP_TYPE_MUTE, iSeconds, szReason, szTarget))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		BaseComm_SetClientMute(iTarget, true);
		GetClientName(iTarget, szTarget, sizeof(szTarget));
		
		LogAction(iClient, iTarget, "\"%L\" timed muted \"%L\" (minutes \"%i\")", iClient, iTarget, (iSeconds / 60));
	}
	else
	{
		LogAction(iClient, -1, "\"%L\" timed muted (authid \"%s\") (minutes \"%i\")", iClient, szTarget, (iSeconds / 60));
	}
	
	if(iSeconds)
	{
		ReplyToCommand(iClient, "[SM] %s has been muted for %i minutes.", szTarget, (iSeconds / 60));
		PrintToChatAll("[SM] %s has been muted for %i minutes by %N.", szTarget, (iSeconds / 60), iClient);
	}
	else
	{
		ReplyToCommand(iClient, "[SM] %s has been muted permanently.", szTarget);
		PrintToChatAll("[SM] %s has been muted permanently by %N.", szTarget, iClient);
	}
	
	return Plugin_Handled;
}

public Action:Command_TimedSilence(iClient, iArgs)
{
	if(iArgs < 3)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_timed_silence <#steamid|#userid|name> <minutes> \"reason\"");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindMuteGagTarget(iClient, szTarget);
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
	
	if((iSeconds < 1 || iSeconds > GetAdminsMaxTime(iClient)) && GetAdminsMaxTime(iClient) > 0)
	{
		ReplyToCommand(iClient, "[SM] The time you entered was too long.");
		return Plugin_Handled;
	}
	
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
	
	if(!TimedPunishment_AddPunishment(iClient, iTarget, TP_TYPE_GAG, iSeconds, szReason, szTarget))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(!TimedPunishment_AddPunishment(iClient, iTarget, TP_TYPE_MUTE, iSeconds, szReason, szTarget))
	{
		ReplyToCommand(iClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	if(iTarget)
	{
		BaseComm_SetClientGag(iTarget, true);
		BaseComm_SetClientMute(iTarget, true);
		GetClientName(iTarget, szTarget, sizeof(szTarget));
		
		LogAction(iClient, iTarget, "\"%L\" timed silenced \"%L\" (minutes \"%i\")", iClient, iTarget, (iSeconds / 60));
	}
	else
	{
		LogAction(iClient, -1, "\"%L\" timed silenced (authid \"%s\") (minutes \"%i\")", iClient, szTarget, (iSeconds / 60));
	}
	
	if(iSeconds)
	{
		ReplyToCommand(iClient, "[SM] %s has been silenced for %i minutes.", szTarget, (iSeconds / 60));
		PrintToChatAll("[SM] %s has been silenced for %i minutes by %N.", szTarget, (iSeconds / 60), iClient);
	}
	else
	{
		ReplyToCommand(iClient, "[SM] %s has been silenced permanently.", szTarget);
		PrintToChatAll("[SM] %s has been silenced permanently by %N.", szTarget, iClient);
	}
	
	return Plugin_Handled;
}

FindMuteGagTarget(iClient, const String:szTarget[])
{
	decl iTargets[1], String:szTargetName[1], bool:tn_is_ml;
	if(ProcessTargetString(szTarget, iClient, iTargets, 1, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_MULTI, szTargetName, sizeof(szTargetName), tn_is_ml) > 0)
	{
		return iTargets[0];
	}
	
	return -1;
}