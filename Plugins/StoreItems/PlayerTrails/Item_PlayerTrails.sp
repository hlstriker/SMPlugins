#include <sourcemod>
#include <sdkhooks>
#include "../../../Libraries/Store/store"
#include "../../../Libraries/ParticleManager/particle_manager"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Player Trails";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to add trails to themselves.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aItems;

new Handle:g_hRoundStartTimer = INVALID_HANDLE;
new bool:g_bApplyOnSpawn;

new Handle:g_aContinuousEffects[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("store_item_player_trails_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	g_aItems = CreateArray();
}

public Action:Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	if(GetEventInt(hEvent, "oldteam") != 0)
		return;
	
	decl String:szEffect[MAX_STORE_DATA_STRING_LEN+1], i, iClients[1];
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(g_aContinuousEffects[iPlayer] == INVALID_HANDLE)
			continue;
		
		if(!ShouldSendToClient(iClient, iPlayer))
			continue;
		
		for(i=0; i<GetArraySize(g_aContinuousEffects[iPlayer]); i++)
		{
			GetArrayString(g_aContinuousEffects[iPlayer], i, szEffect, sizeof(szEffect));
			
			iClients[0] = iClient;
			PM_CreateEntityEffectFollow(iPlayer, szEffect, _, _, iClients, 1);
		}
	}
}

public Event_RoundStart(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// NOTE: "sv_force_transmit_players" should be set to 1 or trails might not apply to clients not in other clients PVS.
	CreateRoundStartTimer();
}

CreateRoundStartTimer()
{
	if(g_hRoundStartTimer != INVALID_HANDLE)
		KillTimer(g_hRoundStartTimer);
	
	g_hRoundStartTimer = CreateTimer(2.0, Timer_ApplyTrails);
}

public Action:Timer_ApplyTrails(Handle:hTimer)
{
	g_hRoundStartTimer = INVALID_HANDLE;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		TrySpawnTrail(iClient);
	}
	
	g_bApplyOnSpawn = true;
}

public Event_CSPreRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bApplyOnSpawn = false;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
		ClearContinuousEffect(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	ClearContinuousEffect(iClient);
}

public Event_PlayerDeath(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	ClearContinuousEffect(iClient);
}

ClearContinuousEffect(iClient)
{
	if(g_aContinuousEffects[iClient] == INVALID_HANDLE)
		return;
	
	CloseHandle(g_aContinuousEffects[iClient]);
	g_aContinuousEffects[iClient] = INVALID_HANDLE;
}

SetContinuousEffect(iClient, const String:szEffect[])
{
	if(g_aContinuousEffects[iClient] == INVALID_HANDLE)
		g_aContinuousEffects[iClient] = CreateArray(MAX_STORE_DATA_STRING_LEN+1);
	
	if(FindStringInArray(g_aContinuousEffects[iClient], szEffect) != -1)
		return;
	
	PushArrayString(g_aContinuousEffects[iClient], szEffect);
}

public OnMapStart()
{
	g_bApplyOnSpawn = true;
	ClearArray(g_aItems);
}

public Store_OnItemsReady()
{
	new iIndex = -1;
	decl iFoundItemID, String:szEffect[MAX_STORE_DATA_STRING_LEN+1];
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_PLAYER_TRAIL, iFoundItemID)) != -1)
	{
		if(!Store_GetItemsDataString(iFoundItemID, 1, szEffect, sizeof(szEffect)))
			continue;
		
		PushArrayCell(g_aItems, iFoundItemID);
		PM_PrecacheParticleEffect(_, szEffect);
	}
}

public OnClientPutInServer(iClient)
{
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(!g_bApplyOnSpawn)
		return;
	
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	TrySpawnTrail(iClient);
}

TrySpawnTrail(iClient)
{
	new iItemID = GetRandomItemID(iClient);
	if(iItemID < 1)
		return;
	
	CreateTrail(iClient, iItemID);
}

GetRandomItemID(iClient)
{
	decl iItemID;
	new Handle:hOwned = CreateArray();
	for(new i=0; i<GetArraySize(g_aItems); i++)
	{
		iItemID = GetArrayCell(g_aItems, i);
		if(!Store_CanClientUseItem(iClient, iItemID))
			continue;
		
		PushArrayCell(hOwned, iItemID);
	}
	
	if(GetArraySize(hOwned) < 1)
	{
		CloseHandle(hOwned);
		return 0;
	}
	
	iItemID = GetArrayCell(hOwned, GetRandomInt(0, GetArraySize(hOwned)-1));
	CloseHandle(hOwned);
	
	return iItemID;
}

bool:CreateTrail(iClient, iItemID)
{
	decl String:szEffect[MAX_STORE_DATA_STRING_LEN+1];
	if(!Store_GetItemsDataString(iItemID, 1, szEffect, sizeof(szEffect)))
		return false;
	
	new iNumClients;
	decl iClients[MAXPLAYERS];
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(!ShouldSendToClient(iPlayer, iClient))
			continue;
		
		iClients[iNumClients++] = iPlayer;
	}
	
	SetContinuousEffect(iClient, szEffect);
	
	if(!iNumClients)
		return true;
	
	PM_CreateEntityEffectFollow(iClient, szEffect, _, _, iClients, iNumClients);
	
	return true;
}

bool:ShouldSendToClient(iClient, iOwner)
{
	new iOwnerFlags = Store_GetClientSettings(iOwner, STOREITEM_TYPE_PLAYER_TRAIL);
	
	if(iClient == iOwner)
	{
		if(iOwnerFlags & ITYPE_FLAG_SELF_DISABLED)
			return false;
	}
	else
	{
		new iClientFlags = Store_GetClientSettings(iClient, STOREITEM_TYPE_PLAYER_TRAIL);
		
		if(GetClientTeam(iClient) == GetClientTeam(iOwner))
		{
			if(iClientFlags & ITYPE_FLAG_MY_TEAM_DISABLED)
				return false;
			
			if(iOwnerFlags & ITYPE_FLAG_MY_ITEM_MY_TEAM_DISABLED)
				return false;
		}
		else
		{
			if(iClientFlags & ITYPE_FLAG_OTHER_TEAM_DISABLED)
				return false;
			
			if(iOwnerFlags & ITYPE_FLAG_MY_ITEM_OTHER_TEAM_DISABLED)
				return false;
		}
	}
	
	return true;
}