#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <basecomm>
#include <hls_color_chat>
#include "../../Libraries/PlayerChat/player_chat"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "No Text Spam";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Stops players from spamming text.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define TEXT_DELAY_MIN	5
#define TEXT_DELAY_MAX	50
new Handle:g_hTextTrie[MAXPLAYERS+1];

#define MAX_CHARACTERS_PER_SECOND		15
#define REDUCE_CHARACTERS_PER_SECOND	2
#define DELAY_BEFORE_RESETTING_CPS		3.0
new g_iCharactersPerSecond[MAXPLAYERS+1];
new Float:g_fLastMessage[MAXPLAYERS+1];

#define MAX_MESSAGES_AT_ZERO	3
new g_iNumMessagesAtZero[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("no_text_spam_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	for(new i=0; i<sizeof(g_hTextTrie); i++)
		g_hTextTrie[i] = CreateTrie();
}

public OnClientConnected(iClient)
{
	g_fLastMessage[iClient] = -9999.0;
	g_iNumMessagesAtZero[iClient] = 0;
}

public OnClientDisconnect_Post(iClient)
{
	ClearTrie(g_hTextTrie[iClient]);
}

public Action:PlayerChat_OnMessage(iClient, ChatType:iChatType, const String:szMessage[])
{
	new iMessageLength = strlen(szMessage);
	
	if((g_fLastMessage[iClient] + DELAY_BEFORE_RESETTING_CPS) > GetEngineTime())
	{
		new Float:fSecondsPassed = GetEngineTime() - g_fLastMessage[iClient];
		new iCharactersAllowed = RoundFloat(fSecondsPassed * g_iCharactersPerSecond[iClient]);
		
		if(g_iCharactersPerSecond[iClient] <= 0)
		{
			g_iNumMessagesAtZero[iClient]++;
			
			if(g_iNumMessagesAtZero[iClient] >= MAX_MESSAGES_AT_ZERO)
			{
				BaseComm_SetClientGag(iClient, true);
				CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}You have been gagged for spamming too much.");
			}
			else
			{
				CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}You will be gagged if you continue to spam.");
			}
		}
		
		// Player is typing again before the reset delay. Reduce their allowed CPS.
		g_iCharactersPerSecond[iClient] -= REDUCE_CHARACTERS_PER_SECOND;
		
		if(iCharactersAllowed < iMessageLength)
		{
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Please do not spam.");
			
			g_fLastMessage[iClient] = GetEngineTime();
			return Plugin_Handled;
		}
	}
	else
	{
		// Players delay has passed. Reset their CPS to max.
		g_iCharactersPerSecond[iClient] = MAX_CHARACTERS_PER_SECOND;
		g_iNumMessagesAtZero[iClient] = 0;
	}
	
	g_fLastMessage[iClient] = GetEngineTime();
	
	decl Float:fLastUsed;
	if(GetTrieValue(g_hTextTrie[iClient], szMessage, fLastUsed))
	{
		// Each character adds a second to the delay while clamped between min/max delay.
		new iDelay = iMessageLength;
		
		if(iDelay < TEXT_DELAY_MIN)
		{
			iDelay = TEXT_DELAY_MIN;
		}
		else if(iDelay > TEXT_DELAY_MAX)
		{
			iDelay = TEXT_DELAY_MAX;
		}
		
		if((fLastUsed + iDelay) > GetEngineTime())
		{
			return Plugin_Handled;
		}
	}
	
	SetTrieValue(g_hTextTrie[iClient], szMessage, GetEngineTime(), true);
	
	return Plugin_Continue;
}