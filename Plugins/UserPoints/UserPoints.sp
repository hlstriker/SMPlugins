#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/ClientCookies/client_cookies"
#include "../../Libraries/ClientTimes/client_times"
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "../../Libraries/Donators/donators"
#include "../../Libraries/DatabaseUserStats/database_user_stats"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include <cstrike>
#include "../../Libraries/Store/store"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "User Points";
new const String:PLUGIN_VERSION[] = "1.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Gives users points.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_tag_url;
new Handle:cvar_points_per_minute;
new Handle:cvar_points_count_afk_time;
new Handle:cvar_points_clantag_bonus_percent;
new Handle:cvar_points_event_bonus_percent;
new Handle:cvar_points_donator_bonus_percent;
new Handle:cvar_points_hours_played_bonus_percent;
new Handle:cvar_points_round_end_give_winning_team;
new Handle:cvar_points_round_end_give_survivor_only;
new Handle:cvar_points_round_end_points_per_player;

const Float:POINT_DISPLAY_DELAY = 120.0;
new Float:g_fNextPointDisplay[MAXPLAYERS+1];

new g_iClientTotalPoints[MAXPLAYERS+1];
new g_iPointsOffset[MAXPLAYERS+1];

new Float:g_fRoundStartTime;
#define REQUIRED_ELAPSED_SECONDS_ROUND_END_POINTS	30

#if defined _cstrike_included
new const g_iRoundEndReasonToWinningTeam[] =
{
	CS_TEAM_T,		// Target Successfully Bombed!
	CS_TEAM_CT,		// The VIP has escaped!
	CS_TEAM_T,		// VIP has been assassinated!
	CS_TEAM_T,		// The terrorists have escaped!
	CS_TEAM_CT,		// The CTs have prevented most of the terrorists from escaping!
	CS_TEAM_CT,		// Escaping terrorists have all been neutralized!
	CS_TEAM_CT,		// The bomb has been defused!
	CS_TEAM_CT,		// Counter-Terrorists Win!
	CS_TEAM_T,		// Terrorists Win!
	CS_TEAM_NONE,	// Round Draw!
	CS_TEAM_CT,		// All Hostages have been rescued!
	CS_TEAM_CT,		// Target has been saved!
	CS_TEAM_T,		// Hostages have not been rescued!
	CS_TEAM_CT,		// Terrorists have not escaped!
	CS_TEAM_T,		// VIP has not escaped!
	CS_TEAM_NONE,	// Game Commencing!
	CS_TEAM_CT,		// Terrorists Surrender
	CS_TEAM_T,		// CTs Surrender
};
#endif

new bool:g_bRoundEndPointsDisabled;

new bool:g_bLibLoaded_Store;


public OnPluginStart()
{
	CreateConVar("user_points_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_points_per_minute = FindConVar("points_per_minute")) == INVALID_HANDLE)
		cvar_points_per_minute = CreateConVar("points_per_minute", "1", "The number of points to give per minute.", _, true, 0.0);
	
	if((cvar_points_count_afk_time = FindConVar("points_count_afk_time")) == INVALID_HANDLE)
		cvar_points_count_afk_time = CreateConVar("points_count_afk_time", "0", "Should points be given for AFK time?", _, true, 0.0, true, 1.0);
	
	if((cvar_points_clantag_bonus_percent = FindConVar("points_clantag_bonus_percent")) == INVALID_HANDLE)
		cvar_points_clantag_bonus_percent = CreateConVar("points_clantag_bonus_percent", "50", "The percent of clan tag bonus points to give.", _, true, 0.0);
	
	if((cvar_points_event_bonus_percent = FindConVar("points_event_bonus_percent")) == INVALID_HANDLE)
		cvar_points_event_bonus_percent = CreateConVar("points_event_bonus_percent", "0", "The percent of event bonus points to give.", _, true, 0.0);
	
	if((cvar_points_donator_bonus_percent = FindConVar("points_donator_bonus_percent")) == INVALID_HANDLE)
		cvar_points_donator_bonus_percent = CreateConVar("points_donator_bonus_percent", "150", "The percent of donator bonus points to give.", _, true, 0.0);
	
	if((cvar_points_hours_played_bonus_percent = FindConVar("points_hours_played_bonus_percent")) == INVALID_HANDLE)
		cvar_points_hours_played_bonus_percent = CreateConVar("points_hours_played_bonus_percent", "0.05", "The percent of bonus points to give per hours played.", _, true, 0.0);
	
	if((cvar_points_round_end_give_winning_team = FindConVar("points_round_end_give_winning_team")) == INVALID_HANDLE)
		cvar_points_round_end_give_winning_team = CreateConVar("points_round_end_give_winning_team", "0", "Give the winning teams players points on round end?", _, true, 0.0, true, 1.0);
	
	if((cvar_points_round_end_give_survivor_only = FindConVar("points_round_end_give_survivor_only")) == INVALID_HANDLE)
		cvar_points_round_end_give_survivor_only = CreateConVar("points_round_end_give_survivor_only", "0", "Give only the winning teams surviving players points?", _, true, 0.0, true, 1.0);
	
	if((cvar_points_round_end_points_per_player = FindConVar("points_round_end_points_per_player")) == INVALID_HANDLE)
		cvar_points_round_end_points_per_player = CreateConVar("points_round_end_points_per_player", "5", "The number of points to add to the shared pool per player on the winning team.", _, true, 0.0);
	
	if((cvar_tag_url = FindConVar("clan_tag_url")) == INVALID_HANDLE)
		cvar_tag_url = CreateConVar("clan_tag_url", "http://swoobles.com/forums/thread-7728.html#posts", "The URL to the clan tag help page.");
	
	HookEvent("cs_intermission", Event_Intermission_Post, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	
	RegConsoleCmd("sm_points", OnCheckPoints, "Displays the number of store points a user has.");
	RegConsoleCmd("sm_credits", OnCheckPoints, "Displays the number of store points a user has.");
	RegConsoleCmd("sm_tag", OnTag, "Displays the clan tag help page.");
	RegConsoleCmd("sm_clantag", OnTag, "Displays the clan tag help page.");
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("user_points");
	CreateNative("UserPoints_GivePoints", _UserPoints_GivePoints);
	CreateNative("UserPoints_AddToVisualOffset", _UserPoints_AddToVisualOffset);
	CreateNative("UserPoints_GetPoints", _UserPoints_GetPoints);
	CreateNative("UserPoints_DisableRoundEndPointsForThisRound", _UserPoints_DisableRoundEndPointsForThisRound);
	
	return APLRes_Success;
}

public _UserPoints_GivePoints(Handle:hPlugin, iNumParams)
{
	return GivePoints(GetNativeCell(1), GetNativeCell(2));
}

public _UserPoints_AddToVisualOffset(Handle:hPlugin, iNumParams)
{
	g_iPointsOffset[GetNativeCell(1)] += GetNativeCell(2);
}

public _UserPoints_GetPoints(Handle:hPlugin, iNumParams)
{
	return GetPoints(GetNativeCell(1), GetNativeCell(2));
}

GetPoints(iClient, bool:bGetWithVisualOffset=false)
{
	new iPoints = g_iClientTotalPoints[iClient];
	
	if(bGetWithVisualOffset)
		iPoints += g_iPointsOffset[iClient];
	
	return iPoints;
}

public _UserPoints_DisableRoundEndPointsForThisRound(Handle:hPlugin, iNumParams)
{
	g_bRoundEndPointsDisabled = true;
}

public Action:OnTag(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(cvar_tag_url == INVALID_HANDLE)
	{
		CPrintToChat(iClient, "{red}Tell the server owner to fix this!");
		return Plugin_Handled;
	}
	
	static String:szURL[1024];
	GetConVarString(cvar_tag_url, szURL, sizeof(szURL));
	WebPageViewer_OpenPage(iClient, szURL);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading tag page...");
	
	return Plugin_Handled;
}

public Action:OnCheckPoints(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayPointsMessage(iClient);
	
	return Plugin_Handled;
}

public OnAllPluginsLoaded()
{
	ClientTimes_SetTimeBeforeMarkedAsAway(45);
	g_bLibLoaded_Store = LibraryExists("store");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "store"))
		g_bLibLoaded_Store = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "store"))
		g_bLibLoaded_Store = false;
}

public OnClientConnected(iClient)
{
	g_iClientTotalPoints[iClient] = 0;
}

public OnClientPutInServer(iClient)
{
	g_iPointsOffset[iClient] = 0;
	g_fNextPointDisplay[iClient] = 0.0;
	
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SWOOBLES_POINTS))
	{
		g_iClientTotalPoints[iClient] += ClientCookies_GetCookie(iClient, CC_TYPE_SWOOBLES_POINTS);
	}
	
	// Instantly set points here incase they already had some before cookies were loaded.
	// We set here because we didn't set it before cookies were loaded since that could result in data loss.
	ClientCookies_SetCookie(iClient, CC_TYPE_SWOOBLES_POINTS, g_iClientTotalPoints[iClient]);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	new Float:fCurTime = GetGameTime();
	if(fCurTime < g_fNextPointDisplay[iClient])
		return;
	
	g_fNextPointDisplay[iClient] = fCurTime + POINT_DISPLAY_DELAY;
	DisplayPointsMessage(iClient);
}

DisplayPointsMessage(iClient)
{
	CPrintToChat(iClient, "{olive}You have {lightred}%i {olive}points.", GetPoints(iClient, true));
}

public OnClientDisconnect(iClient)
{
	if(IsFakeClient(iClient) || !ClientCookies_HaveCookiesLoaded(iClient))
		return;
	
	decl iPoints, iTagPoints, iSpecialPoints, iDonatorPoints, iSubscriptions, iHoursPlayedPoints;
	new iTotalPoints = GetDisconnectPoints(iClient, iPoints, iTagPoints, iSpecialPoints, iDonatorPoints, iSubscriptions, iHoursPlayedPoints);
	GivePoints(iClient, iTotalPoints);
}

bool:GivePoints(iClient, iAmount)
{
	if(IsFakeClient(iClient))
		return false;
	
	if(iAmount <= 0)
		return false;
	
	g_iClientTotalPoints[iClient] += iAmount;
	
	if(ClientCookies_HaveCookiesLoaded(iClient))
		ClientCookies_SetCookie(iClient, CC_TYPE_SWOOBLES_POINTS, g_iClientTotalPoints[iClient]);
	
	return true;
}

GetDisconnectPoints(iClient, &iPoints, &iTagPoints, &iSpecialPoints, &iDonatorPoints, &iSubscriptions, &iHoursPlayedPoints)
{
	iPoints = 0;
	iTagPoints = 0;
	iSpecialPoints = 0;
	iDonatorPoints = 0;
	iHoursPlayedPoints = 0;
	iSubscriptions = 0;
	
	decl iTimePlayed;
	
	if(GetConVarBool(cvar_points_count_afk_time))
		iTimePlayed = ClientTimes_GetTimeInServer(iClient);
	else
		iTimePlayed = ClientTimes_GetTimePlayed(iClient);
	
	if(iTimePlayed < 1)
		return 0;
	
	new iNumPoints = RoundToFloor((iTimePlayed / 60.0) * GetConVarFloat(cvar_points_per_minute));
	if(iNumPoints < 1)
		return 0;
	
	// Give bonus points for wearing certain clan tags.
	new Float:fTimeInServer = float(ClientTimes_GetTimeInServer(iClient));
	
	new Float:fTagPercent;
	fTagPercent += (ClientTimes_GetClanTagTime(iClient, "Swoobles!") / fTimeInServer);
	fTagPercent += (ClientTimes_GetClanTagTime(iClient, "Swbs! Admin") / fTimeInServer);
	fTagPercent += (ClientTimes_GetClanTagTime(iClient, "S!~") / fTimeInServer);
	if(fTagPercent > 1.0)
		fTagPercent = 1.0;
	
	new iNumTagPoints = RoundToCeil((iNumPoints * (GetConVarFloat(cvar_points_clantag_bonus_percent) / 100.0)) * fTagPercent);
	
	// Give bonus points for special occasions.
	new iNumSpecialPoints = RoundToFloor(iNumPoints * (GetConVarFloat(cvar_points_event_bonus_percent) / 100.0));
	
	// Give bonus points for donators.
	decl iNumDonatorPoints;
	decl iNumSubscriptions;
	if(Donators_IsDonator(iClient))
	{
		iNumSubscriptions = Donators_GetActiveSubscriptions(iClient);
		iNumDonatorPoints = RoundToFloor(iNumPoints * (GetConVarFloat(cvar_points_donator_bonus_percent) * iNumSubscriptions / 100.0));
	}
	else
		iNumDonatorPoints = 0;
	
	// Give a percent bonus for every hour played.
	new iNumHoursPlayedPoints = RoundToFloor(iNumPoints * (GetPointsPerHourBonusPercent(iClient) / 100.0));
	
	// Set the by reference points before calculating the total points.
	iPoints = iNumPoints;
	iTagPoints = iNumTagPoints;
	iSpecialPoints = iNumSpecialPoints;
	iDonatorPoints = iNumDonatorPoints;
	iHoursPlayedPoints = iNumHoursPlayedPoints;
	iSubscriptions = iNumSubscriptions;
	
	// Add bonus points to the total.
	iNumPoints += iNumTagPoints;
	iNumPoints += iNumSpecialPoints;
	iNumPoints += iNumDonatorPoints;
	iNumPoints += iNumHoursPlayedPoints;
	
	return iNumPoints;
}

Float:GetPointsPerHourBonusPercent(iClient)
{
	return (float(DBUserStats_GetGlobalTimePlayed(iClient) + ClientTimes_GetTimePlayed(iClient)) / 60.0 / 60.0) * GetConVarFloat(cvar_points_hours_played_bonus_percent);
}

public Event_Intermission_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	decl iTotalPoints, iPoints, iTagPoints, iSpecialPoints, iDonatorPoints, iSubscriptions, iHoursPlayedPoints;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		CPrintToChat(iClient, "{yellow}Points per minute bonus: {purple}%.02f%%{yellow} (based on hours played)", GetPointsPerHourBonusPercent(iClient));
		
		iTotalPoints = GetDisconnectPoints(iClient, iPoints, iTagPoints, iSpecialPoints, iDonatorPoints, iSubscriptions, iHoursPlayedPoints);
		if(iTotalPoints)
		{
			if(iSpecialPoints)
				CPrintToChat(iClient, "{olive}Gained {lightred}%i points {olive}({yellow}+%i tag bonus, +%i event bonus, +%i donator bonus for %i subscriptions{olive}).", iTotalPoints, iTagPoints, iSpecialPoints, iDonatorPoints, iSubscriptions);
			else
				CPrintToChat(iClient, "{olive}Gained {lightred}%i points {olive}({yellow}+%i clantag bonus, +%i donator bonus for %i subscriptions{olive}).", iTotalPoints, iTagPoints, iDonatorPoints, iSubscriptions);
			
			if(!iTagPoints)
				CPrintToChat(iClient, "{olive}Type {yellow}!tag {olive}to get {yellow}%i%% extra {olive}points per map!", GetConVarInt(cvar_points_clantag_bonus_percent));
		}
		else
		{
			if(g_bLibLoaded_Store)
				CPrintToChat(iClient, "{olive}Remember to type {yellow}!shop {olive}to see {yellow}items you can get{olive}!");
		}
	}
}

public OnMapStart()
{
	OnRoundStart();
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	OnRoundStart();
}

OnRoundStart()
{
	g_fRoundStartTime = GetGameTime();
	g_bRoundEndPointsDisabled = false;
}

public Action:CS_OnTerminateRound(&Float:fDelay, &CSRoundEndReason:reason)
{
	TryGiveRoundEndPoints(reason);
}

TryGiveRoundEndPoints(CSRoundEndReason:reason)
{
	if(g_bRoundEndPointsDisabled)
		return;
	
	if(!GetConVarBool(cvar_points_round_end_give_winning_team))
		return;
	
	// Make sure enough time has elapsed in the round to give points.
	if(GetGameTime() - g_fRoundStartTime < REQUIRED_ELAPSED_SECONDS_ROUND_END_POINTS)
		return;
	
	// Set round start time to the current time incase the round somehow ends again quickly.
	g_fRoundStartTime = GetGameTime();
	
	// Give the winning team points.
	GiveRoundEndWinningTeamPoints(GetWinningTeam(reason));
}

GetWinningTeam(CSRoundEndReason:reason)
{
	if(_:reason >= sizeof(g_iRoundEndReasonToWinningTeam))
		return CS_TEAM_NONE;
	
	return g_iRoundEndReasonToWinningTeam[reason];
}

GiveRoundEndWinningTeamPoints(iWinningTeam)
{
	if(iWinningTeam == CS_TEAM_NONE)
		return;
	
	decl iClient, iClientsAlive[MAXPLAYERS+1];
	new iNumAlive, iTotalPoints;
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) != iWinningTeam)
			continue;
		
		// Give points to every player on the team if needed.
		if(!GetConVarBool(cvar_points_round_end_give_survivor_only))
		{
			GivePoints(iClient, GetConVarInt(cvar_points_round_end_points_per_player));
			CPrintToChat(iClient, "{lightgreen}-- {olive}Awarded {lightred}%d {olive}store points for winning the round.", GetConVarInt(cvar_points_round_end_points_per_player));
			continue;
		}
		
		// We are only giving points to the survivors. See how many total points we can give based on the number of players on the team.
		iTotalPoints += GetConVarInt(cvar_points_round_end_points_per_player);
		
		if(IsPlayerAlive(iClient))
			iClientsAlive[iNumAlive++] = iClient;
	}
	
	if(GetConVarBool(cvar_points_round_end_give_survivor_only))
	{
		// Give points to the survivors on the team only.
		new iPointsPerPlayer = RoundFloat(float(iTotalPoints) / float(iNumAlive));
		
		for(new i=0; i<iNumAlive; i++)
		{
			iClient = iClientsAlive[i];
			
			GivePoints(iClient, iPointsPerPlayer);
			CPrintToChat(iClient, "{lightgreen}-- {olive}Awarded {lightred}%d {olive}store points for surviving the round.", iPointsPerPlayer);
		}
	}
}