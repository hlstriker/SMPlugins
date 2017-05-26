#include <sourcemod>
#include <cstrike>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../ZoneTypes/Includes/zonetype_teleport"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Multigames Queue";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Adds players to a queue so everyone gets a chance to select a multigame.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aQueue;
new g_iTeleportZoneID;


public OnPluginStart()
{
	CreateConVar("multigames_queue_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aQueue = CreateArray();
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	TryTeleportNextValidClient();
}

TryTeleportNextValidClient()
{
	if(!g_iTeleportZoneID)
		return;
	
	new iArraySize = GetArraySize(g_aQueue);
	
	decl iClient;
	for(new i=0; i<iArraySize; i++)
	{
		iClient = GetArrayCell(g_aQueue, i);
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(!ZoneTypeTeleport_TryToTeleport(g_iTeleportZoneID, iClient))
			continue;
		
		RemoveClientFromQueue(iClient);
		AddClientToQueue(iClient);
		
		PrintHintText(iClient, "<font size='20' color='#FF0000'>You were selected to choose!</font>\n<font size='20' color='#00FF00'>Press your +use key (E) on a game.</font>");
		CPrintToChatAll("{red}%N {green}was selected to choose.", iClient);
		
		decl iPosition;
		for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
		{
			if(!IsClientInGame(iPlayer))
				continue;
			
			iPosition = FindValueInArray(g_aQueue, iPlayer);
			if(iPosition != -1)
				CPrintToChat(iPlayer, "{yellow}Your new queue positon: {purple}%i{yellow}/{purple}%i", iPosition + 1, iArraySize);
		}
		
		break;
	}
}

public Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(IsFakeClient(iClient))
		return;
	
	if(GetEventInt(hEvent, "team") < CS_TEAM_T || !IsClientInGame(iClient))
	{
		RemoveClientFromQueue(iClient);
		return;
	}
	
	AddClientToQueue(iClient);
}

public OnClientDisconnect(iClient)
{
	RemoveClientFromQueue(iClient);
}

AddClientToQueue(iClient)
{
	if(FindValueInArray(g_aQueue, iClient) != -1)
		return;
	
	PushArrayCell(g_aQueue, iClient);
}

RemoveClientFromQueue(iClient)
{
	new iIndex = FindValueInArray(g_aQueue, iClient);
	if(iIndex == -1)
		return;
	
	RemoveFromArray(g_aQueue, iIndex);
}

public OnMapStart()
{
	RoundPreStart();
}

public Action:Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RoundPreStart();
}

RoundPreStart()
{
	g_iTeleportZoneID = 0;
}

public ZoneManager_OnTypeAssigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TELEPORT_DESTINATION)
		return;
	
	decl String:szBuffer[11];
	if(!ZoneManager_GetDataString(iZoneID, 1, szBuffer, sizeof(szBuffer)))
		return;
	
	if(!StrEqual(szBuffer, "gameselect"))
		return;
	
	g_iTeleportZoneID = iZoneID;
}

public ZoneManager_OnTypeUnassigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TELEPORT_DESTINATION)
		return;
	
	if(iZoneID != g_iTeleportZoneID)
		return;
	
	g_iTeleportZoneID = 0;
}

public ZoneManager_OnZoneRemoved_Pre(iZoneID)
{
	if(iZoneID != g_iTeleportZoneID)
		return;
	
	g_iTeleportZoneID = 0;
}