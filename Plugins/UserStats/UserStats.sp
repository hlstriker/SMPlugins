#include <sourcemod>
#include "../../Libraries/DatabaseUserStats/database_user_stats"
#include "../../Libraries/DatabaseServers/database_servers"
#include "../../Libraries/ClientTimes/client_times"
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "../../Libraries/DatabaseUserBans/database_user_bans"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "User Stats";
new const String:PLUGIN_VERSION[] = "1.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows users to see each others stats.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("user_stats_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_rank", OnSayRank, "Displays your rank.");
	RegConsoleCmd("sm_ranks", OnSayRanks, "Displays everyones rank in the server.");
	
	HookEvent("player_connect", HookPlayerConnect, EventHookMode_Pre);
}

public OnAllPluginsLoaded()
{
	ClientTimes_SetTimeBeforeMarkedAsAway(STATS_SECONDS_BEFORE_AFK);
}

public Action:HookPlayerConnect(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast)
{
	return Plugin_Handled;
}

public Action:OnSayRank(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayRankText(iClient, iClient);
	ShowRankUpdateText(iClient);
	
	return Plugin_Handled;
}

ShowRankUpdateText(iClient)
{
	CPrintToChat(iClient, "{lightgreen}- {olive}Ranks only update every 30-60 minutes.");
}

DisplayRankText(iDisplayTo, iClient)
{
	decl String:szNameText[48], String:szTime[32];
	
	if(iDisplayTo == iClient)
		strcopy(szNameText, sizeof(szNameText), "You {olive}are");
	else
		FormatEx(szNameText, sizeof(szNameText), "%N {olive}is", iClient);
	
	// Server rank
	decl iTimePlayed;
	if(DBUserStats_HasServerStats(iClient))
	{
		iTimePlayed = DBUserStats_GetServerTimePlayed(iClient) + ClientTimes_GetTimePlayed(iClient);
		
		if(iTimePlayed > 3600)
			FormatEx(szTime, sizeof(szTime), "{green}%.02f {olive}hr", iTimePlayed / 3600.0);
		else if(iTimePlayed > 60)
			FormatEx(szTime, sizeof(szTime), "{green}%.02f {olive}min", iTimePlayed / 60.0);
		else
			FormatEx(szTime, sizeof(szTime), "{green}%i {olive}sec", iTimePlayed);
		
		CPrintToChat(iDisplayTo, "{lightred}%s server {green}rank #%i  {olive}(%s).", szNameText, DBUserStats_GetServerRank(iClient), szTime);
	}
	else
		CPrintToChat(iDisplayTo, "{lightred}%s not yet ranked in this server.", szNameText);
	
	// Global rank
	if(DBUserStats_HasGlobalStats(iClient))
	{
		iTimePlayed = DBUserStats_GetGlobalTimePlayed(iClient) + ClientTimes_GetTimePlayed(iClient);
		
		if(iTimePlayed > 3600)
			FormatEx(szTime, sizeof(szTime), "{green}%.02f {olive}hr", iTimePlayed / 3600.0);
		else if(iTimePlayed > 60)
			FormatEx(szTime, sizeof(szTime), "{green}%.02f {olive}min", iTimePlayed / 60.0);
		else
			FormatEx(szTime, sizeof(szTime), "{green}%i {olive}sec", iTimePlayed);
		
		CPrintToChat(iDisplayTo, "{lightred}%s global {green}rank #%i  {olive}(%s).", szNameText, DBUserStats_GetGlobalRank(iClient), szTime);
	}
	else
		CPrintToChat(iDisplayTo, "{lightred}%s not yet ranked globally.", szNameText);
}

public Action:OnSayRanks(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	ShowRankUpdateText(iClient);
	DisplayMenu_RanksOptions(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_RanksOptions(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_RanksOptions);
	SetMenuTitle(hMenu, "Player Ranks");
	
	AddMenuItem(hMenu, "0", "Ranks of currently on server.");
	AddMenuItem(hMenu, "1", "Ranks of everyone.");
	
	DisplayMenu(hMenu, iClient, 0);
}

public MenuHandle_RanksOptions(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case 0: DisplayRanksMenu(iParam1);
		case 1:
		{
			decl String:szURL[255];
			FormatEx(szURL, sizeof(szURL), "http://swoobles.com/1-ranks-database/%i-ranks", DBServers_GetServerParentID());
			
			WebPageViewer_OpenPage(iParam1, szURL);
		}
	}
}

DisplayRanksMenu(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuRanks_Handle);
	SetMenuTitle(hMenu, "Player Ranks");
	
	new iOrder[MAXPLAYERS], iOrderNum, i, iOrderPos, k;
	for(i=1; i<=MaxClients; i++)
	{
		if(!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		// See where this clients rank falls in the list.
		for(iOrderPos=0; iOrderPos<iOrderNum; iOrderPos++)
		{
			if(DBUserStats_GetServerRank(i) < DBUserStats_GetServerRank(iOrder[iOrderPos]) && DBUserStats_HasServerStats(i))
				break;
		}
		
		// Push all the array indexs up by 1.
		for(k=iOrderNum-1; k>=iOrderPos; k--)
			iOrder[k+1] = iOrder[k];
		
		// Insert this client into its position.
		iOrder[iOrderPos] = i;
		iOrderNum++;
	}
	
	decl String:szBuffer[48], String:szInfo[32];
	for(i=0; i<iOrderNum; i++)
	{
		if(DBUserStats_GetServerRank(iOrder[i]) > 0)
			FormatEx(szBuffer, sizeof(szBuffer), "Rank %i: %N", DBUserStats_GetServerRank(iOrder[i]), iOrder[i]);
		else
			FormatEx(szBuffer, sizeof(szBuffer), "Not Ranked: %N", iOrder[i]);
		
		FormatEx(szInfo, sizeof(szInfo), "%i", GetClientSerial(iOrder[i]));
		
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	DisplayMenuAtItem(hMenu, iClient, iStartItem, 0);
}

public MenuRanks_Handle(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		DisplayMenu_RanksOptions(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[32];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iClient = GetClientFromSerial(StringToInt(szInfo));
	if(!iClient)
	{
		CPrintToChat(iParam1, " {green}[{lightred}Note{green}] {olive}That player is no longer in the server.");
		DisplayRanksMenu(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	DisplayRankText(iParam1, iClient);
	
	DisplayRanksMenu(iParam1, GetMenuSelectionPosition());
}

public DBUserStats_OnServerStatsReady(iClient, iServerRank, iSecondsPlayed, iSecondsAFK)
{
	if(!Bans_IsStatusLoaded(iClient))
		return;
	
	DisplayConnectionMessage(iClient);
}

public DBUserStats_OnServerStatsFailed(iClient)
{
	if(!Bans_IsStatusLoaded(iClient))
		return;
	
	DisplayConnectionMessage(iClient);
}

public Bans_OnStatusLoaded(iClient, bool:bIsBanned)
{
	if(bIsBanned)
		return;
	
	if(!DBUserStats_HasServerStatsLoaded(iClient))
		return;
	
	DisplayConnectionMessage(iClient);
}

DisplayConnectionMessage(iClient)
{
	if(DBUserStats_HasServerStats(iClient))
		CPrintToChatAll("{lightred}%N {lightgreen}({green}rank #%i{lightgreen}) {olive}has joined the server.", iClient, DBUserStats_GetServerRank(iClient));
	else
		CPrintToChatAll("{lightred}%N {lightgreen}({green}not ranked{lightgreen}) {olive}has joined the server.", iClient);
}