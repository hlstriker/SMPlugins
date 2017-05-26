#include <sourcemod>
#include <cstrike>
#include <sdktools_functions>
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Deathrun Queue";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Adds players to a queue so everyone gets a chance to be button presser.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aQueue;
new g_iTerroristSerial;

new bool:g_bBlockJoinTeamMessage;

new bool:g_bEvent_RoundStart_Post;
new bool:g_bEvent_PlayerTeam_Pre;
new bool:g_bEvent_RoundPrestart_Post;

new bool:g_bEnabled;


public OnPluginStart()
{
	CreateConVar("deathrun_queue_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aQueue = CreateArray();
}

public OnMapStart()
{
	// TODO: Only activate the plugin if the map is prefixed with deathrun_ or dr_
	// Change hooks to be HookEventEx
	// -->
	
	decl String:szMapName[10];
	GetCurrentMap(szMapName, sizeof(szMapName));
	
	szMapName[9] = 0x00;
	if(StrEqual(szMapName, "deathrun_", false))
	{
		EnablePlugin();
		return;
	}
	
	szMapName[3] = 0x00;
	if(StrEqual(szMapName, "dr_", false))
	{
		EnablePlugin();
		return;
	}
}

EnablePlugin()
{
	g_bEvent_RoundStart_Post = HookEventEx("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	g_bEvent_PlayerTeam_Pre = HookEventEx("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);
	
	// Use prestart to remove the old terrorist and add a new terrorist.
	// This is because if the old terrorist goes to spectate the round_end will fire before the player_team event.
	// In that case, we need the player_team event to fire before we run our team switch code.
	g_bEvent_RoundPrestart_Post = HookEventEx("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	
	g_bEnabled = true;
}

public OnMapEnd()
{
	g_bEnabled = false;
	
	if(g_bEvent_RoundStart_Post)
	{
		UnhookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
		g_bEvent_RoundStart_Post = false;
	}
	
	if(g_bEvent_PlayerTeam_Pre)
	{
		UnhookEvent("player_team", Event_PlayerTeam_Pre, EventHookMode_Pre);
		g_bEvent_PlayerTeam_Pre = false;
	}
	
	if(g_bEvent_RoundPrestart_Post)
	{
		UnhookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
		g_bEvent_RoundPrestart_Post = false;
	}
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// If nobody is on Terrorist we need to end the round so it chooses a new player.
	// Return if there is a Terrorist.
	if(GetTeamClientCount(CS_TEAM_T))
	{
		PrintMessageToTerrorist();
		return;
	}
	
	// Don't end the round if there isn't a valid player to put on T.
	if(!GetArraySize(g_aQueue))
		return;
	
	ForceRoundEnd();
}

PrintMessageToTerrorist()
{
	new iClient = GetClientFromSerial(g_iTerroristSerial);
	if(!iClient)
		return;
	
	PrintHintText(iClient, "<font size='20' color='#00FF00'>Try to kill the CT by pressing</font>\n<font size='20' color='#00FF00'>buttons which activate traps.</font>");
}

TryRemoveTerrorist()
{
	new iClient = GetClientFromSerial(g_iTerroristSerial);
	if(!iClient)
		return;
	
	SetClientPendingTeam(iClient, CS_TEAM_CT);
	g_iTerroristSerial = 0;
}

SetClientPendingTeam(iClient, iTeam)
{
	g_bBlockJoinTeamMessage = true;
	
	CS_SwitchTeam(iClient, iTeam);
	SetEntProp(iClient, Prop_Send, "m_iPendingTeamNum", iTeam);
	
	g_bBlockJoinTeamMessage = false;
}

public Action:Event_PlayerTeam_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(g_bBlockJoinTeamMessage)
		SetEventBroadcast(hEvent, true);
	
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(IsFakeClient(iClient))
		return;
	
	if(GetEventInt(hEvent, "team") < CS_TEAM_T || !IsClientInGame(iClient))
		RemoveClientFromQueue(iClient);
	else
		AddClientToQueue(iClient);
	
	if(GetEventInt(hEvent, "oldteam") == CS_TEAM_T)
	{
		g_iTerroristSerial = 0;
		ForceRoundEnd();
	}
}

public Action:Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	TryRemoveTerrorist();
	SetNextTerroristInQueue();
}

SetNextTerroristInQueue()
{
	new iArraySize = GetArraySize(g_aQueue);
	
	decl iClient;
	for(new i=0; i<iArraySize; i++)
	{
		iClient = GetArrayCell(g_aQueue, i);
		if(!IsClientInGame(iClient))
		{
			if(RemoveClientFromQueue(iClient))
				i--;
			
			continue;
		}
		
		RemoveClientFromQueue(iClient);
		AddClientToQueue(iClient);
		
		SetClientPendingTeam(iClient, CS_TEAM_T);
		g_iTerroristSerial = GetClientSerial(iClient);
		
		CPrintToChatAll("{red}%N {green}is the new Terrorist.", iClient);
		
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

public OnClientDisconnect(iClient)
{
	if(!g_bEnabled)
		return;
	
	RemoveClientFromQueue(iClient);
	
	if(GetClientTeam(iClient) == CS_TEAM_T)
	{
		g_iTerroristSerial = 0;
		ForceRoundEnd();
	}
}

ForceRoundEnd()
{
	CS_TerminateRound(0.1, CSRoundEnd_Draw, true);
}

AddClientToQueue(iClient)
{
	if(FindValueInArray(g_aQueue, iClient) != -1)
		return;
	
	PushArrayCell(g_aQueue, iClient);
}

bool:RemoveClientFromQueue(iClient)
{
	new iIndex = FindValueInArray(g_aQueue, iClient);
	if(iIndex == -1)
		return false;
	
	RemoveFromArray(g_aQueue, iIndex);
	return true;
}