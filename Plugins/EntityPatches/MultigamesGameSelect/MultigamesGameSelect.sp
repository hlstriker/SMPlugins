#include <sourcemod>
#include <sdktools_entinput>
#include <sdktools_entoutput>
#include <sdktools_functions>
#include <cstrike>
#include "../../../Libraries/EntityHooker/entity_hooker"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Multigames Game Select";
new const String:PLUGIN_VERSION[] = "1.9";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows marking which buttons select a game for multigame maps.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new g_iLastEntityUsedHammerID;
new Handle:g_hTimer_AutoActivate;

new bool:g_bGameSelectedThisRound;
new bool:g_bShouldBlockRoundEnd;

new g_iCountDown;
new Handle:cvar_multigame_auto_select_time;


public OnPluginStart()
{
	CreateConVar("multigames_game_select_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_multigame_auto_select_time = CreateConVar("sv_multigame_auto_select_time", "45", "The time to automatically select a game. 0 disables.", _, true, 0.0);
	
	HookEvent("round_prestart", Event_RoundPrestart_Pre, EventHookMode_Pre);
}

public OnMapStart()
{
	g_iLastEntityUsedHammerID = 0;
	RoundStart();
}

public Action:Event_RoundPrestart_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RoundStart();
}

RoundStart()
{
	StopTimer_AutoActivate();
	
	g_bGameSelectedThisRound = false;
	g_bShouldBlockRoundEnd = false;
}

public OnMapEnd()
{
	StopTimer_AutoActivate();
}

StopTimer_AutoActivate()
{
	if(g_hTimer_AutoActivate == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_AutoActivate);
	g_hTimer_AutoActivate = INVALID_HANDLE;
}

StartTimer_AutoActivate()
{
	g_iCountDown = GetConVarInt(cvar_multigame_auto_select_time);
	
	StopTimer_AutoActivate();
	g_hTimer_AutoActivate = CreateTimer(1.0, Timer_AutoActivate, _, TIMER_REPEAT);
	
	if(g_hTimer_AutoActivate != INVALID_HANDLE)
		g_bShouldBlockRoundEnd = true;
}

public Action:Timer_AutoActivate(Handle:hTimer)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		TryRespawnClient(iClient);
	
	if(!GetConVarInt(cvar_multigame_auto_select_time))
		return Plugin_Continue;
	
	g_iCountDown--;
	if(g_iCountDown > 0)
	{
		switch(g_iCountDown)
		{
			case 60, 30, 20, 10, 5, 4, 3, 2, 1: CPrintToChatAll("{lightred}Auto-select: {green}%i", g_iCountDown);
		}
		
		return Plugin_Continue;
	}
	
	new Handle:hEntList = CreateArray();
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_button")) != -1)
	{
		if(EntityHooker_IsEntityHooked(EH_TYPE_MULTIGAMES_GAME_SELECT, iEnt))
			PushArrayCell(hEntList, iEnt);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_once")) != -1)
	{
		if(EntityHooker_IsEntityHooked(EH_TYPE_MULTIGAMES_GAME_SELECT, iEnt))
			PushArrayCell(hEntList, iEnt);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_multiple")) != -1)
	{
		if(EntityHooker_IsEntityHooked(EH_TYPE_MULTIGAMES_GAME_SELECT, iEnt))
			PushArrayCell(hEntList, iEnt);
	}
	
	new iArraySize = GetArraySize(hEntList);
	if(iArraySize)
	{
		CPrintToChatAll("{green}Automatically selecting a game...");
		
		iEnt = GetArrayCell(hEntList, GetRandomInt(0, iArraySize-1));
		ActivateGameSelectEntity(iEnt);
	}
	
	CloseHandle(hEntList);
	
	g_hTimer_AutoActivate = INVALID_HANDLE;
	return Plugin_Stop;
}

ActivateGameSelectEntity(iEnt)
{
	decl String:szClassName[32];
	if(!GetEntityClassname(iEnt, szClassName, sizeof(szClassName)))
		return;
	
	if(StrEqual(szClassName, "func_button"))
	{
		AcceptEntityInput(iEnt, "Use", _, iEnt);
	}
	else if(StrEqual(szClassName, "trigger_once") || StrEqual(szClassName, "trigger_multiple"))
	{
		new iFoundClient;
		
		for(new iClient=1; iClient<=MaxClients; iClient++)
		{
			if(!IsClientInGame(iClient))
				continue;
			
			if(!IsPlayerAlive(iClient))
				continue;
			
			if(GetClientTeam(iClient) < CS_TEAM_T)
				continue;
			
			iFoundClient = iClient;
			break;
		}
		
		AcceptEntityInput(iEnt, "StartTouch", _, iFoundClient);
	}
}

TryRespawnClient(iClient)
{
	if(!IsClientInGame(iClient) || IsPlayerAlive(iClient))
		return;
	
	if(GetClientTeam(iClient) < CS_TEAM_T)
		return;
	
	CS_RespawnPlayer(iClient);
}

public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_MULTIGAMES_GAME_SELECT, "Multigames game select", "func_button", "trigger_once", "trigger_multiple");
	
	EntityHooker_RegisterProperty(EH_TYPE_MULTIGAMES_GAME_SELECT, Prop_Send, PropField_String, "m_iName");
	EntityHooker_RegisterProperty(EH_TYPE_MULTIGAMES_GAME_SELECT, Prop_Data, PropField_String, "m_target");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_MULTIGAMES_GAME_SELECT)
		return;
	
	new iHammerID = GetEntProp(iEnt, Prop_Data, "m_iHammerID");
	if(!iHammerID)
		return;
	
	if(iHammerID == g_iLastEntityUsedHammerID)
	{
		AcceptEntityInput(iEnt, "KillHierarchy");
		return;
	}
	
	HookGameSelectEntity(iEnt);
	StartTimer_AutoActivate();
}

HookGameSelectEntity(iEnt)
{
	decl String:szClassName[32];
	if(!GetEntityClassname(iEnt, szClassName, sizeof(szClassName)))
		return;
	
	if(StrEqual(szClassName, "func_button"))
	{
		HookSingleEntityOutput(iEnt, "OnPressed", OnButtonPressed, true);
	}
	else if(StrEqual(szClassName, "trigger_once") || StrEqual(szClassName, "trigger_multiple"))
	{
		HookSingleEntityOutput(iEnt, "OnTrigger", OnTriggerTriggered, true);
		HookSingleEntityOutput(iEnt, "OnStartTouch", OnTriggerTriggered, true);
	}
}

public EntityHooker_OnEntityUnhooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_MULTIGAMES_GAME_SELECT)
		return;
	
	UnhookSingleEntityOutput(iEnt, "OnPressed", OnButtonPressed);
}

public OnButtonPressed(const String:szOutput[], iCaller, iActivator, Float:fDelay)
{
	OnGameSelectEntityActivated(iCaller);
}

public OnTriggerTriggered(const String:szOutput[], iCaller, iActivator, Float:fDelay)
{
	OnGameSelectEntityActivated(iCaller);
}

OnGameSelectEntityActivated(iEnt)
{
	if(g_bGameSelectedThisRound)
		return;
	
	g_bShouldBlockRoundEnd = false;
	g_bGameSelectedThisRound = true;
	
	StopTimer_AutoActivate();
	
	CPrintToChatAll("{green}Game selected.");
	
	if(iEnt > 0)
		g_iLastEntityUsedHammerID = GetEntProp(iEnt, Prop_Data, "m_iHammerID");
}

public Action:CS_OnTerminateRound(&Float:fDelay, &CSRoundEndReason:reason)
{
	if(!g_bShouldBlockRoundEnd)
		return Plugin_Continue;
	
	if(reason == CSRoundEnd_GameStart)
		return Plugin_Continue;
	
	// TODO: Should we continue on the round that ends right after CSRoundEnd_GameStart as well?
	// -->
	
	return Plugin_Handled;
}