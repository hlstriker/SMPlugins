#include <sourcemod>
#include <sdkhooks>
#include "../../../Libraries/Store/store"
#include "../../../Libraries/ParticleManager/particle_manager"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Player Effects";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to add effects to themselves.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_hRoundStartTimer = INVALID_HANDLE;
new bool:g_bApplyOnSpawn;

enum PlayerEffectType
{
	PEFFECT_TYPE_AURA = 0,
	PEFFECT_TYPE_SPARKLES,
	PEFFECT_TYPE_RINGS,
	PEFFECT_TYPE_TRAIL
};

new ClientCookieType:g_iEffectTypeToCookieType[] =
{
	CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_AURA,
	CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_SPARKLES,
	CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_RINGS,
	CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_TRAIL
};

new Handle:g_aItems[PlayerEffectType];
new Handle:g_aContinuousEffects[MAXPLAYERS+1][PlayerEffectType];


public OnPluginStart()
{
	CreateConVar("store_item_player_effects_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	for(new i=0; i<sizeof(g_aItems); i++)
		g_aItems[i] = CreateArray();
}

public Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	if(GetEventInt(hEvent, "oldteam") != 0)
		return;
	
	decl String:szEffect[MAX_STORE_DATA_STRING_LEN+1], i, j, iClients[1];
	iClients[0] = iClient;
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		for(i=0; i<sizeof(g_aContinuousEffects[]); i++)
		{
			if(g_aContinuousEffects[iPlayer][i] == INVALID_HANDLE)
				continue;
			
			if(!ShouldSendToClient(iClient, iPlayer, i))
				continue;
			
			for(j=0; j<GetArraySize(g_aContinuousEffects[iPlayer][i]); j++)
			{
				GetArrayString(g_aContinuousEffects[iPlayer][i], j, szEffect, sizeof(szEffect));
				PM_CreateEntityEffectFollow(iPlayer, szEffect, _, _, iClients, 1);
			}
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
	
	g_hRoundStartTimer = CreateTimer(2.0, Timer_ApplyEffects);
}

public Action:Timer_ApplyEffects(Handle:hTimer)
{
	g_hRoundStartTimer = INVALID_HANDLE;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		TrySpawnContinuousEffects(iClient);
	}
	
	g_bApplyOnSpawn = true;
}

public Event_CSPreRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bApplyOnSpawn = false;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
		ClearContinuousEffects(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	ClearContinuousEffects(iClient);
}

public Event_PlayerDeath(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(1 <= iVictim <= MaxClients)
	{
		StopClientsEffects(iVictim);
		//ClearContinuousEffects(iVictim); // Don't clear yet. We want to stop again on spawn.
	}
	
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(1 <= iAttacker <= MaxClients)
	{
		TrySpawnRingEffect(iAttacker);
	}
}

TrySpawnRingEffect(iClient)
{
	new Handle:hOwned = CreateArray();
	
	decl iItemID;
	for(new i=0; i<GetArraySize(Handle:g_aItems[PEFFECT_TYPE_RINGS]); i++)
	{
		iItemID = GetArrayCell(Handle:g_aItems[PEFFECT_TYPE_RINGS], i);
		if(!Store_CanClientUseItem(iClient, iItemID))
			continue;
		
		PushArrayCell(hOwned, iItemID);
	}
	
	if(GetArraySize(hOwned) < 1)
	{
		CloseHandle(hOwned);
		return;
	}
	
	iItemID = GetArrayCell(hOwned, GetRandomInt(0, GetArraySize(hOwned)-1));
	CloseHandle(hOwned);
	
	CreateRingEffect(iClient, iItemID);
}

bool:CreateRingEffect(iClient, iItemID)
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
		
		if(!ShouldSendToClient(iPlayer, iClient, _:PEFFECT_TYPE_RINGS))
			continue;
		
		iClients[iNumClients++] = iPlayer;
	}
	
	if(!iNumClients)
		return true;
	
	PM_CreateEntityEffectFollow(iClient, szEffect, _, _, iClients, iNumClients);
	
	return true;
}

StopClientsEffects(iClient)
{
	static Float:fNextStopAllowed[MAXPLAYERS+1]; // Help prevent sending PM_StopEntityEffects too quickly as it seems to cause the CUtl overflow on clients.
	
	// TODO: We might actually have to set the delay within PM_StopEntityEffects directly per entity.
	// This is because multiple plugins will be calling it at once.
	
	if(fNextStopAllowed[iClient] > GetEngineTime())
		return;
	
	fNextStopAllowed[iClient] = GetEngineTime() + 1.0;
	
	for(new i=0; i<sizeof(g_aContinuousEffects[]); i++)
	{
		if(g_aContinuousEffects[iClient][i] == INVALID_HANDLE)
			continue;
		
		PM_StopEntityEffects(iClient);
		break;
	}
}

ClearContinuousEffects(iClient)
{
	for(new i=0; i<sizeof(g_aContinuousEffects[]); i++)
	{
		if(g_aContinuousEffects[iClient][i] == INVALID_HANDLE)
			continue;
		
		CloseHandle(g_aContinuousEffects[iClient][i]);
		g_aContinuousEffects[iClient][i] = INVALID_HANDLE;
	}
}

SetContinuousEffect(iClient, const String:szEffect[], iEffectTypeIndex)
{
	if(g_aContinuousEffects[iClient][iEffectTypeIndex] == INVALID_HANDLE)
		g_aContinuousEffects[iClient][iEffectTypeIndex] = CreateArray(MAX_STORE_DATA_STRING_LEN+1);
	
	if(FindStringInArray(g_aContinuousEffects[iClient][iEffectTypeIndex], szEffect) != -1)
		return;
	
	PushArrayString(g_aContinuousEffects[iClient][iEffectTypeIndex], szEffect);
}

public OnMapStart()
{
	g_bApplyOnSpawn = true;
	
	for(new i=0; i<sizeof(g_aItems); i++)
		ClearArray(g_aItems[i]);
}

public Store_OnRegisterVisibilitySettingsReady()
{
	Store_RegisterVisibilitySettings("Player Aura", CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_AURA);
	Store_RegisterVisibilitySettings("Player Sparkles", CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_SPARKLES);
	Store_RegisterVisibilitySettings("Player Kill Swirl", CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_RINGS);
	Store_RegisterVisibilitySettings("Player Trail", CC_TYPE_STORE_IFLAGS_PLAYER_EFFECT_TRAIL);
}

public Store_OnItemsReady()
{
	decl iFoundItemID, String:szEffect[MAX_STORE_DATA_STRING_LEN+1];
	
	new iIndex = -1;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_PLAYER_EFFECT_TRAIL, iFoundItemID)) != -1)
	{
		if(!Store_GetItemsDataString(iFoundItemID, 1, szEffect, sizeof(szEffect)))
			continue;
		
		PushArrayCell(Handle:g_aItems[PEFFECT_TYPE_TRAIL], iFoundItemID);
		PM_PrecacheParticleEffect(_, szEffect);
	}
	
	iIndex = -1;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_PLAYER_EFFECT_AURA, iFoundItemID)) != -1)
	{
		if(!Store_GetItemsDataString(iFoundItemID, 1, szEffect, sizeof(szEffect)))
			continue;
		
		PushArrayCell(Handle:g_aItems[PEFFECT_TYPE_AURA], iFoundItemID);
		PM_PrecacheParticleEffect(_, szEffect);
	}
	
	iIndex = -1;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_PLAYER_EFFECT_SPARKLES, iFoundItemID)) != -1)
	{
		if(!Store_GetItemsDataString(iFoundItemID, 1, szEffect, sizeof(szEffect)))
			continue;
		
		PushArrayCell(Handle:g_aItems[PEFFECT_TYPE_SPARKLES], iFoundItemID);
		PM_PrecacheParticleEffect(_, szEffect);
	}
	
	iIndex = -1;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_PLAYER_EFFECT_RINGS, iFoundItemID)) != -1)
	{
		if(!Store_GetItemsDataString(iFoundItemID, 1, szEffect, sizeof(szEffect)))
			continue;
		
		PushArrayCell(Handle:g_aItems[PEFFECT_TYPE_RINGS], iFoundItemID);
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
	
	StopClientsEffects(iClient);
	ClearContinuousEffects(iClient);
	
	TrySpawnContinuousEffects(iClient);
}

TrySpawnContinuousEffects(iClient)
{
	new iItemID = GetRandomItemID(iClient, _:PEFFECT_TYPE_AURA);
	if(iItemID > 0)
		CreateContinuousEffect(iClient, iItemID, _:PEFFECT_TYPE_AURA);
	
	iItemID = GetRandomItemID(iClient, _:PEFFECT_TYPE_SPARKLES);
	if(iItemID > 0)
		CreateContinuousEffect(iClient, iItemID, _:PEFFECT_TYPE_SPARKLES);
	
	iItemID = GetRandomItemID(iClient, _:PEFFECT_TYPE_TRAIL);
	if(iItemID > 0)
		CreateContinuousEffect(iClient, iItemID, _:PEFFECT_TYPE_TRAIL);
}

GetRandomItemID(iClient, iEffectType)
{
	decl iItemID;
	new Handle:hOwned = CreateArray();
	for(new i=0; i<GetArraySize(g_aItems[iEffectType]); i++)
	{
		iItemID = GetArrayCell(g_aItems[iEffectType], i);
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

bool:CreateContinuousEffect(iClient, iItemID, iEffectType)
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
		
		if(!ShouldSendToClient(iPlayer, iClient, iEffectType))
			continue;
		
		iClients[iNumClients++] = iPlayer;
	}
	
	SetContinuousEffect(iClient, szEffect, iEffectType);
	
	if(!iNumClients)
		return true;
	
	PM_CreateEntityEffectFollow(iClient, szEffect, _, _, iClients, iNumClients);
	
	return true;
}

bool:ShouldSendToClient(iClient, iOwner, iEffectType)
{
	new ClientCookieType:cookieType = g_iEffectTypeToCookieType[iEffectType];
	
	new iOwnerFlags = Store_GetClientItemTypeFlags(iOwner, cookieType);
	
	if(iClient == iOwner)
	{
		if(iOwnerFlags & ITYPE_FLAG_SELF_DISABLED)
			return false;
	}
	else
	{
		new iClientFlags = Store_GetClientItemTypeFlags(iClient, cookieType);
		
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