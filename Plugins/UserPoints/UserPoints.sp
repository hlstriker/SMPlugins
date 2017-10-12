#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/ClientCookies/client_cookies"
#include "../../Libraries/ClientTimes/client_times"
#include "../../Libraries/WebPageViewer/web_page_viewer"
#include "../../Libraries/Donators/donators"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "User Points";
new const String:PLUGIN_VERSION[] = "1.0";

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

const Float:POINT_DISPLAY_DELAY = 120.0;
new Float:g_fNextPointDisplay[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("user_points_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_points_per_minute = FindConVar("points_per_minute")) == INVALID_HANDLE)
		cvar_points_per_minute = CreateConVar("points_per_minute", "1", "The number of points to give per minute.");
	
	if((cvar_points_count_afk_time = FindConVar("points_count_afk_time")) == INVALID_HANDLE)
		cvar_points_count_afk_time = CreateConVar("points_count_afk_time", "0", "Should points be given for AFK time?");
	
	if((cvar_points_clantag_bonus_percent = FindConVar("points_clantag_bonus_percent")) == INVALID_HANDLE)
		cvar_points_clantag_bonus_percent = CreateConVar("points_clantag_bonus_percent", "50", "The percent of clan tag bonus points to give.");
	
	if((cvar_points_event_bonus_percent = FindConVar("points_event_bonus_percent")) == INVALID_HANDLE)
		cvar_points_event_bonus_percent = CreateConVar("points_event_bonus_percent", "0", "The percent of event bonus points to give.");
	
	if((cvar_points_donator_bonus_percent = FindConVar("points_donator_bonus_percent")) == INVALID_HANDLE)
		cvar_points_donator_bonus_percent = CreateConVar("points_donator_bonus_percent", "150", "The percent of donator bonus points to give.");
	
	if((cvar_tag_url = FindConVar("clan_tag_url")) == INVALID_HANDLE)
		cvar_tag_url = CreateConVar("clan_tag_url", "http://swoobles.com/forums/thread-7728.html#posts", "The URL to the clan tag help page.");
	
	HookEvent("cs_intermission", Event_Intermission_Post, EventHookMode_PostNoCopy);
	
	RegConsoleCmd("sm_points", OnCheckPoints, "Displays the number of store points a user has.");
	RegConsoleCmd("sm_credits", OnCheckPoints, "Displays the number of store points a user has.");
	RegConsoleCmd("sm_tag", OnTag, "Displays the clan tag help page.");
	RegConsoleCmd("sm_clantag", OnTag, "Displays the clan tag help page.");
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("user_points");
	return APLRes_Success;
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
}

public OnClientPutInServer(iClient)
{
	g_fNextPointDisplay[iClient] = 0.0;
	
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
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
	CPrintToChat(iClient, "{olive}You have {lightred}%i {olive}points.", ClientCookies_GetCookie(iClient, CC_TYPE_SWOOBLES_POINTS));
}

public OnClientDisconnect(iClient)
{
	if(IsFakeClient(iClient) || !ClientCookies_HaveCookiesLoaded(iClient))
		return;
	
	decl iPoints, iTagPoints, iSpecialPoints, iDonatorPoints;
	new iTotalPoints = GetDisconnectPoints(iClient, iPoints, iTagPoints, iSpecialPoints, iDonatorPoints);
	if(iTotalPoints)
		ClientCookies_SetCookie(iClient, CC_TYPE_SWOOBLES_POINTS, ClientCookies_GetCookie(iClient, CC_TYPE_SWOOBLES_POINTS) + iTotalPoints);
}

GetDisconnectPoints(iClient, &iPoints, &iTagPoints, &iSpecialPoints, &iDonatorPoints)
{
	iPoints = 0;
	iTagPoints = 0;
	iSpecialPoints = 0;
	iDonatorPoints = 0;
	
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
	if(Donators_IsDonator(iClient))
		iNumDonatorPoints = RoundToFloor(iNumPoints * (GetConVarFloat(cvar_points_donator_bonus_percent) / 100.0));
	else
		iNumDonatorPoints = 0;
	
	// Set the by reference points before calculating the total points.
	iPoints = iNumPoints;
	iTagPoints = iNumTagPoints;
	iSpecialPoints = iNumSpecialPoints;
	iDonatorPoints = iNumDonatorPoints;
	
	// Add bonus points to the total.
	iNumPoints += iNumTagPoints;
	iNumPoints += iNumSpecialPoints;
	iNumPoints += iNumDonatorPoints;
	
	return iNumPoints;
}

public Event_Intermission_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	decl iTotalPoints, iPoints, iTagPoints, iSpecialPoints, iDonatorPoints;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		iTotalPoints = GetDisconnectPoints(iClient, iPoints, iTagPoints, iSpecialPoints, iDonatorPoints);
		if(iTotalPoints)
		{
			if(iSpecialPoints)
				CPrintToChat(iClient, "{olive}Gained {lightred}%i points {olive}({yellow}+%i tag bonus, +%i event bonus, +%i donator bonus{olive}).", iTotalPoints, iTagPoints, iSpecialPoints, iDonatorPoints);
			else
				CPrintToChat(iClient, "{olive}Gained {lightred}%i points {olive}({yellow}+%i clantag bonus, +%i donator bonus{olive}).", iTotalPoints, iTagPoints, iDonatorPoints);
			
			if(!iTagPoints)
				CPrintToChat(iClient, "{olive}Type {yellow}!tag {olive}to get {yellow}%i%% extra {olive}points per map!", GetConVarInt(cvar_points_clantag_bonus_percent));
		}
		else
		{
			CPrintToChat(iClient, "{olive}Remember to type {yellow}!shop {olive}to see {yellow}items you can get{olive}!");
		}
	}
}