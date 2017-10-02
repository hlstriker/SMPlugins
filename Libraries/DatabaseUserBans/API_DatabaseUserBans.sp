#include <sourcemod>
#include "../TimedPunishments/timed_punishments"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Database User Bans";
new const String:PLUGIN_VERSION[] = "1.6";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the user bans in the database.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bIsBanned[MAXPLAYERS+1];

new bool:g_bIsStatusLoaded[MAXPLAYERS+1];
new Handle:g_hFwd_OnStatusLoaded;


public OnPluginStart()
{
	CreateConVar("api_database_user_bans_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnStatusLoaded = CreateGlobalForward("Bans_OnStatusLoaded", ET_Ignore, Param_Cell, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("database_user_bans");
	CreateNative("Bans_IsStatusLoaded", _Bans_IsStatusLoaded);
	
	return APLRes_Success;
}

public _Bans_IsStatusLoaded(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	return g_bIsStatusLoaded[iClient];
}

public OnClientConnected(iClient)
{
	g_bIsBanned[iClient] = false;
	g_bIsStatusLoaded[iClient] = false;
}

public TimedPunishment_OnAllPunishmentsLoaded(iClient)
{
	g_bIsStatusLoaded[iClient] = true;
	
	// Call forward here which we will use to display the player connection message.
	Forward_OnStatusLoaded(iClient, g_bIsBanned[iClient]);
}

Forward_OnStatusLoaded(iClient, bool:bIsBanned)
{
	Call_StartForward(g_hFwd_OnStatusLoaded);
	Call_PushCell(iClient);
	Call_PushCell(bIsBanned);
	Call_Finish();
}

public TimedPunishment_OnPunishmentLoaded(iClient, TimedPunishmentType:punishment_type, bool:bIsPunishmentPerm, iCurUnixTime, iExpiresUnixTime, const String:szReason[])
{
	if(punishment_type != TP_TYPE_BAN)
		return;
	
	decl String:szExpiresDate[32];
	if(bIsPunishmentPerm)
		strcopy(szExpiresDate, sizeof(szExpiresDate), "Never (permanently banned)");
	else
		FormatTime(szExpiresDate, sizeof(szExpiresDate), "%b %d, %Y - %I:%M %p", iExpiresUnixTime);
	
	KickClient(iClient, "Ban ends: %s.\nReason: %s", szExpiresDate, szReason);
	
	g_bIsBanned[iClient] = true;
}

public Action:OnBanClient(iClient, iTime, iFlags, const String:szReason[], const String:szKickMessage[], const String:szCommand[], any:iAdminClient)
{
	if(!TimedPunishment_AddPunishment(iAdminClient, iClient, TP_TYPE_BAN, (iTime * 60), szReason))
	{
		ReplyToCommand(iAdminClient, "[SM] There was an error.");
		return Plugin_Handled;
	}
	
	LogAction(iAdminClient, iClient, "\"%L\" banned \"%L\" (minutes \"%i\")", iAdminClient, iClient, iTime);
	
	if(iTime)
	{
		ReplyToCommand(iAdminClient, "[SM] %N has been banned for %i minutes.", iClient, iTime);
		PrintToChatAll("[SM] %N has been banned for %i minutes by %N.", iClient, iTime, iAdminClient);
	}
	else
	{
		ReplyToCommand(iAdminClient, "[SM] %N has been banned permanently.", iClient);
		PrintToChatAll("[SM] %N has been banned permanently by %N.", iClient, iAdminClient);
	}
	
	// Return handled since we don't want the game to handle bans.
	return Plugin_Handled;
}

public Action:OnBanIdentity(const String:szIdentity[], iTime, iFlags, const String:szReason[], const String:szCommand[], any:iAdminClient)
{
	// TODO: Add banning by IP back when we add IP adding to timed punishments.
	/*
	if(iFlags & BANFLAG_IP)
	{
		AddBanToDatabase(0, iAdminClient, iTime, "", szIdentity, szReason, "");
	}
	else */if(iFlags & BANFLAG_AUTHID)
	{
		// Check if this user is in game and get their index and IP if possible.
		decl String:szTemp[33], iClient;
		for(iClient=1; iClient<=MaxClients; iClient++)
		{
			if(!IsClientInGame(iClient))
				continue;
			
			GetClientAuthString(iClient, szTemp, sizeof(szTemp));
			if(StrEqual(szIdentity[8], szTemp[8]))
				break;
		}
		
		if(iClient > MaxClients)
		{
			// Player owning this identity isn't in the server. Add ban to database without their index.
			if(!TimedPunishment_AddPunishment(iAdminClient, 0, TP_TYPE_BAN, (iTime * 60), szReason, szIdentity))
			{
				ReplyToCommand(iAdminClient, "[SM] There was an error.");
				return Plugin_Handled;
			}
			
			LogAction(iAdminClient, -1, "\"%L\" banned (authid \"%s\") (minutes \"%i\")", iAdminClient, szIdentity, iTime);
			
			if(iTime)
			{
				ReplyToCommand(iAdminClient, "[SM] %s has been banned for %i minutes.", szIdentity, iTime);
				PrintToChatAll("[SM] %s has been banned for %i minutes by %N.", szIdentity, iTime, iAdminClient);
			}
			else
			{
				ReplyToCommand(iAdminClient, "[SM] %s has been banned permanently.", szIdentity);
				PrintToChatAll("[SM] %s has been banned permanently by %N.", szIdentity, iAdminClient);
			}
		}
		else
		{
			// Player owning this identity is in the server.
			if(!TimedPunishment_AddPunishment(iAdminClient, iClient, TP_TYPE_BAN, (iTime * 60), szReason, szIdentity))
			{
				ReplyToCommand(iAdminClient, "[SM] There was an error.");
				return Plugin_Handled;
			}
			
			LogAction(iAdminClient, iClient, "\"%L\" banned \"%L\" (minutes \"%i\")", iAdminClient, iClient, iTime);
			
			if(iTime)
			{
				ReplyToCommand(iAdminClient, "[SM] %N has been banned for %i minutes.", iClient, iTime);
				PrintToChatAll("[SM] %N has been banned for %i minutes by %N.", iClient, iTime, iAdminClient);
			}
			else
			{
				ReplyToCommand(iAdminClient, "[SM] %N has been banned permanently.", iClient);
				PrintToChatAll("[SM] %N has been banned permanently by %N.", iClient, iAdminClient);
			}
			
			// Go ahead and kick this client as well since sm_addban doesn't kick.
			KickClient(iClient, "%s", szReason);
		}
	}
	
	// Return handled since we don't want the game to handle bans.
	return Plugin_Handled;
}

public Action:OnRemoveBan(const String:szIdentity[], iFlags, const String:szCommand[], any:iAdminClient)
{
	// TODO: Add removing a ban by IP back when we add IP removing to timed punishments.
	/*
	if(iFlags & BANFLAG_IP)
	{
		LiftBanByIP(iAdminClient, szIdentity);
	}
	else */if(iFlags & BANFLAG_AUTHID)
	{
		if(!TimedPunishment_RemovePunishment(iAdminClient, szIdentity, TP_TYPE_BAN))
		{
			ReplyToCommand(iAdminClient, "[SM] There was an error.");
			return Plugin_Handled;
		}
		
		ReplyToCommand(iAdminClient, "[SM] %s's ban has been lifted.", szIdentity);
		PrintToChatAll("[SM] %s's ban has been lifted by %N.", szIdentity, iAdminClient);
		
		LogAction(iAdminClient, -1, "\"%L\" unbanned (authid \"%s\")", iAdminClient, szIdentity);
	}
	
	// Return handled since we don't want the game to handle bans.
	return Plugin_Handled;
}