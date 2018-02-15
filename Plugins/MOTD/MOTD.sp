#include <sourcemod>
#include "../../Libraries/DatabaseServers/database_servers"

#undef REQUIRE_PLUGIN
#include "../../../Source Plugins/AdManager/admanager_twitchoverride"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "MOTD";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The Swoobles MOTD.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_URL_LENGTH 256
new bool:g_bHasJoinedTeam[MAXPLAYERS+1];

new bool:g_bLibLoaded_TwitchOverride;


public OnPluginStart()
{
	CreateConVar("motd_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookUserMessage(GetUserMessageId("VGUIMenu"), Msg_VGUIMenu, true);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_TwitchOverride = LibraryExists("admanager_twitchoverride");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "admanager_twitchoverride"))
		g_bLibLoaded_TwitchOverride = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "admanager_twitchoverride"))
		g_bLibLoaded_TwitchOverride = false;
}

public OnClientPutInServer(iClient)
{
	g_bHasJoinedTeam[iClient] = false;
}

public Action:Msg_VGUIMenu(UserMsg:msg_id, Handle:hMsg, const iPlayers[], iPlayersNum, bool:bReliable, bool:bInit)
{
	if(iPlayersNum < 1)
		return Plugin_Continue;
	
	static iClient;
	iClient = iPlayers[0];
	if(!(1 <= iClient <= MaxClients))
		return Plugin_Continue;
	
	if(g_bHasJoinedTeam[iClient])
		return Plugin_Continue;
	
	static String:szName[5];
	PbReadString(hMsg, "name", szName, sizeof(szName));
	
	// Return if it's not the MOTD.
	if(!StrEqual(szName, "info"))
		return Plugin_Continue;
	
	new iSubKeys = PbGetRepeatedFieldCount(hMsg, "subkeys");
	decl Handle:hSubMsg[iSubKeys], String:szSubName[6], String:szType[5];
	new iIndexType = -1, iIndexMsg = -1;
	
	for(new i=0; i<iSubKeys; i++)
	{
		hSubMsg[i] = PbReadRepeatedMessage(hMsg, "subkeys", i);
		PbReadString(hSubMsg[i], "name", szSubName, sizeof(szSubName));
		
		if(StrEqual(szSubName, "type"))
		{
			iIndexType = i;
			PbReadString(hSubMsg[i], "str", szType, sizeof(szType));
		}
		else if(StrEqual(szSubName, "msg"))
		{
			iIndexMsg = i;
		}
	}
	
	if(iIndexType != -1 && iIndexMsg != -1 && StrEqual(szType, "1"))
	{
		decl String:szAuthID[32];
		if(GetClientAuthString(iClient, szAuthID, sizeof(szAuthID)))
		{
			decl String:szURL[MAX_URL_LENGTH];
			GetClientName(iClient, szURL, sizeof(szURL));
			
			Format(szURL, sizeof(szURL), "http://swoobles.com/page/motd?steamid=%s&server=%i&rand=%i%i&twitch=%i&wpv=1&name=%s", szAuthID, DBServers_GetServerID(), GetTime(), GetRandomInt(0, 255), (g_bLibLoaded_TwitchOverride && AdmanagerTwitch_IsStreaming()), szURL);
			
			PbSetString(hSubMsg[iIndexType], "str", "2");
			PbSetString(hSubMsg[iIndexMsg], "str", szURL);
		}
	}
	
	for(new i=0; i<iSubKeys; i++)
		CloseHandle(hSubMsg[i]);
	
	return Plugin_Continue;
}

public Action:Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	if(g_bHasJoinedTeam[iClient])
		return;
	
	g_bHasJoinedTeam[iClient] = true;
}