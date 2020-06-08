#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../../Libraries/ClientTimes/client_times"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "AFK Manager";
new const String:PLUGIN_VERSION[] = "1.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Manages players that go away from keyboard.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

const TEAM_SPECTATE = 1;
const TRANSFER_WAIT_TIME = 15;
const OBS_MODE_ROAMING = 6;

new bool:g_bWaitingForSpawn[MAXPLAYERS+1];
new bool:g_bWaitingForTransfer[MAXPLAYERS+1];
new Float:g_fStartTransferWaitTime[MAXPLAYERS+1];

new bool:g_bIsAway[MAXPLAYERS+1];

new Handle:cvar_seconds_before_afk;
new Handle:cvar_num_free_slots_before_kicking;
new Handle:cvar_reserved_slots;

new Handle:g_hFwd_OnAway;
new Handle:g_hFwd_OnBack;

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("afk_manager_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_seconds_before_afk = FindConVar("sm_seconds_before_afk")) == INVALID_HANDLE)
		cvar_seconds_before_afk = CreateConVar("sm_seconds_before_afk", "120", "The numbers of seconds before a player is considered AFK.");
	
	if((cvar_num_free_slots_before_kicking = FindConVar("sm_num_free_slots_before_kicking")) == INVALID_HANDLE)
		cvar_num_free_slots_before_kicking = CreateConVar("sm_num_free_slots_before_kicking", "3", "The numbers of free slots needed before kicking AFK players.");
	
	AutoExecConfig(true, "afk_manager", "swoobles");
	
	g_hFwd_OnAway = CreateGlobalForward("AFKManager_OnAway", ET_Ignore, Param_Cell);
	g_hFwd_OnBack = CreateGlobalForward("AFKManager_OnBack", ET_Ignore, Param_Cell);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	}
	
	CreateTimer(3.0, Timer_CheckForAway, _, TIMER_REPEAT);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("afk_manager");
	CreateNative("AFKManager_IsAway", _AFKManager_IsAway);
	
	return APLRes_Success;
}

public _AFKManager_IsAway(Handle:hPlugin, iNumParams)
{
	return g_bIsAway[GetNativeCell(1)];
}

public OnAllPluginsLoaded()
{
	cvar_reserved_slots = FindConVar("sm_reserved_slots");
	ClientTimes_SetTimeBeforeMarkedAsAway(GetConVarInt(cvar_seconds_before_afk), OnAway, OnBack);
	
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	if(!g_bWaitingForSpawn[iClient])
		return;
	
	g_bWaitingForSpawn[iClient] = false;
	SetupTransferDelay(iClient);
}

public OnAway(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	if(!IsPlayerAlive(iClient) && GetClientTeam(iClient) > TEAM_SPECTATE)
	{
		g_bWaitingForSpawn[iClient] = true;
		return;
	}
	
	SetupTransferDelay(iClient);
}

public OnBack(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	StopTransfer(iClient);
	Forward_OnBack(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	StopTransfer(iClient);
}

StopTransfer(iClient)
{
	g_bWaitingForSpawn[iClient] = false;
	g_bWaitingForTransfer[iClient] = false;
	g_bIsAway[iClient] = false;
}

SetupTransferDelay(iClient)
{
	g_fStartTransferWaitTime[iClient] = GetEngineTime();
	g_bWaitingForTransfer[iClient] = true;
}

public Action:Timer_CheckForAway(Handle:hTimer)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		if(!g_bWaitingForTransfer[iClient])
			continue;
		
		if((g_fStartTransferWaitTime[iClient] + TRANSFER_WAIT_TIME) > fCurTime)
			continue;
		
		HandleTransfer(iClient);
	}
}

HandleTransfer(iClient)
{
	StopTransfer(iClient);
	
	// First see if the server is almost full. If it is then the player will be kicked.
	new iNumConnected;
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientConnected(i))
			iNumConnected++;
	}
	
	decl iReservedSlots;
	if(cvar_reserved_slots == INVALID_HANDLE)
		iReservedSlots = 0;
	else
		iReservedSlots = GetConVarInt(cvar_reserved_slots);
	
	g_bIsAway[iClient] = true;
	Forward_OnAway(iClient);
	
	if((MaxClients - iNumConnected) <= (GetConVarInt(cvar_num_free_slots_before_kicking) + iReservedSlots))
	{
		KickClient(iClient, "Reason: AFK when the server is near full");
		return;
	}
	
	// Move the player to spectate if needed.
	if(GetClientTeam(iClient) > TEAM_SPECTATE)
	{
		ForcePlayerSuicide(iClient);
		ChangeClientTeam(iClient, TEAM_SPECTATE);
		SetEntProp(iClient, Prop_Send, "m_iObserverMode", OBS_MODE_ROAMING);
		PrintToChat(iClient, " \x05[SM] \x01You were moved to spectate for being away.");
	}
}

Forward_OnAway(iClient)
{
	Call_StartForward(g_hFwd_OnAway);
	Call_PushCell(iClient);
	Call_Finish();
}

Forward_OnBack(iClient)
{
	Call_StartForward(g_hFwd_OnBack);
	Call_PushCell(iClient);
	Call_Finish();
}