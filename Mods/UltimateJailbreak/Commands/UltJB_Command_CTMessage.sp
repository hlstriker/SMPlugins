#include <sourcemod>
#include <cstrike>
#include <hls_color_chat>
#include <emitsoundany>
#include <sdktools_stringtables>

#undef REQUIRE_PLUGIN
#include "../../../Libraries/PlayerChat/player_chat"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] CT Message";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to message the CT team even if that team has them gagged.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:CHAT_SOUND[] = "sound/swoobles/ultimate_jailbreak/chat_alert.mp3";

#define MESSAGE_DELAY	0.5
new Float:g_fNextMessage[MAXPLAYERS+1];

new bool:g_bIsAdmin[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("ultjb_command_ct_message_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	RegConsoleCmd("sm_g", OnMessageCT);
}

public OnMapStart()
{
	AddFileToDownloadsTable(CHAT_SOUND);
	PrecacheSoundAny(CHAT_SOUND[6]);
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

public Action:PlayerChat_OnMessage(iClient, ChatType:iChatType, const String:szMessage[])
{
	if(strlen(szMessage) < 3)
		return Plugin_Continue;
	
	if(szMessage[0] != '!'
	|| szMessage[1] != 'g'
	|| szMessage[2] != ' ')
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action:OnMessageCT(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!IsPlayerAlive(iClient))
	{
		ReplyToCommand(iClient, "[SM] You must be alive to use this command.");
		return Plugin_Handled;
	}
	
	if(iArgCount < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_g <message>");
		return Plugin_Handled;
	}
	
	if(GetClientTeam(iClient) == CS_TEAM_CT)
	{
		ReplyToCommand(iClient, "[SM] Please use teamchat to talk to your fellow guards.");
		return Plugin_Handled;
	}
	
	if(g_fNextMessage[iClient] > GetEngineTime())
		return Plugin_Handled;
	
	g_fNextMessage[iClient] = GetEngineTime() + MESSAGE_DELAY;
	
	static String:szMessage[256];
	GetCmdArgString(szMessage, sizeof(szMessage));
	StripQuotes(szMessage);
	TrimString(szMessage);
	
	if(strlen(szMessage) < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_g <message>");
		return Plugin_Handled;
	}
	
	switch(GetClientTeam(iClient))
	{
		case CS_TEAM_T: Format(szMessage, sizeof(szMessage), "{blue}To Guards {white}from {lightred}%N{white}: %s", iClient, szMessage);
		case CS_TEAM_CT: Format(szMessage, sizeof(szMessage), "{blue}To Guards {white}from {blue}%N{white}: %s", iClient, szMessage);
		default: Format(szMessage, sizeof(szMessage), "{blue}To Guards {white}from {purple}%N{white}: %s", iClient, szMessage);
	}
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(!IsFakeClient(iPlayer) && iClient != iPlayer)
		{
			if(!g_bIsAdmin[iPlayer] && GetClientTeam(iPlayer) != CS_TEAM_CT)
				continue;
		}
		
		CPrintToChat(iPlayer, szMessage);
		
		EmitSoundToClientAny(iPlayer, CHAT_SOUND[6], iPlayer, 10, SNDLEVEL_NONE);
	}
	
	return Plugin_Handled;
}