#include <sourcemod>
#include <cstrike>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Plugins/ZoneTypes/Includes/zonetype_named"
#include "../../Plugins/UserPoints/user_points"
#include "../../Plugins/HidePlayers/hide_players"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "User Points For Minigames Winner";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Gives points to the winner of the minigames stage.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bRoundHasWinner;


public OnPluginStart()
{
	CreateConVar("user_points_mg_winner_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
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
	g_bRoundHasWinner = false;
}

public ZoneTypeNamed_OnStartTouch(iZoneEnt, iTouchedEnt)
{
	if(!(1 <= iTouchedEnt <= MaxClients))
		return;
	
	if(!IsPlayerAlive(iTouchedEnt))
		return;
	
	static iZoneID;
	iZoneID = GetZoneID(iZoneEnt);
	
	static String:szString[6];
	if(!ZoneManager_GetDataString(iZoneID, 1, szString, sizeof(szString)))
		return;
	
	if(!StrEqual(szString, "mgwin"))
		return;
	
	OnClientTouchedWinZone(iTouchedEnt);
}

OnClientTouchedWinZone(iClient)
{
	if(g_bRoundHasWinner)
		return;
	
	g_bRoundHasWinner = true;
	UserPoints_DisableRoundEndPointsForThisRound();
	UserPoints_DisableClientKillPointsForThisRound(iClient);
	
	new iPoints = GetWinnerPoints();
	UserPoints_GivePoints(iClient, iPoints);
	CPrintToChatAll("{lightgreen}-- {lightred}%N {olive}was awarded {lightred}%d {olive}points for winning.", iClient, iPoints);
	
	// Make sure we set default hide on all player's incase they were in a hide toggle zone for levels such as kz, slide, etc.
	SetHideDefaultAll();
}

GetWinnerPoints()
{
	new iPoints;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) < CS_TEAM_T)
			continue;
		
		iPoints += 3;
	}
	
	return iPoints;
}

SetHideDefaultAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		HidePlayers_SetClientHideOverride(iClient, HIDE_DEFAULT);
	}
}