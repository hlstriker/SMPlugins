#include <sourcemod>
#include <sdkhooks>
#include "../Equipment/item_equipment"
#include "../../../Libraries/Store/store"
#include "../../../Libraries/ParticleManager/particle_manager"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Equipment Effects";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to add effects to their equipment.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aItems;

new Handle:g_hRoundStartTimer = INVALID_HANDLE;
new bool:g_bApplyOnSpawn;

new Handle:g_aContinuousEffects[MAXPLAYERS+1][EquipmentType];


public OnPluginStart()
{
	CreateConVar("store_item_equipment_effects_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	g_aItems = CreateArray();
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
	
	decl iEquipmentEntities[EquipmentType], j, iEnt;
	decl String:szEffect[MAX_STORE_DATA_STRING_LEN+1], i, iClients[1];
	iClients[0] = iClient;
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(!ShouldSendToClient(iClient, iPlayer))
			continue;
		
		if(!ItemEquipment_GetEntities(iPlayer, iEquipmentEntities))
			continue;
		
		for(i=0; i<sizeof(g_aContinuousEffects[]); i++)
		{
			if(g_aContinuousEffects[iPlayer][i] == INVALID_HANDLE)
				continue;
			
			iEnt = iEquipmentEntities[i];
			if(iEnt < 1)
				continue;
			
			for(j=0; j<GetArraySize(g_aContinuousEffects[iPlayer][i]); j++)
			{
				GetArrayString(g_aContinuousEffects[iPlayer][i], j, szEffect, sizeof(szEffect));
				PM_CreateEntityEffectFollow(iEnt, szEffect, _, _, iClients, 1);
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
	
	g_hRoundStartTimer = CreateTimer(2.5, Timer_ApplyEffects);
}

public Action:Timer_ApplyEffects(Handle:hTimer)
{
	g_hRoundStartTimer = INVALID_HANDLE;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		TrySpawnEffects(iClient);
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
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	// Doesn't seem to always work on death maybe because the equipment gets hidden?
	StopClientsEquipmentEffects(iClient);
	//ClearContinuousEffects(iClient); // Don't clear yet. We want to stop again on spawn.
}

StopClientsEquipmentEffects(iClient)
{
	static Float:fNextStopAllowed[MAXPLAYERS+1]; // Help prevent sending PM_StopEntityEffects too quickly as it seems to cause the CUtl overflow on clients.
	
	if(fNextStopAllowed[iClient] > GetEngineTime())
		return;
	
	fNextStopAllowed[iClient] = GetEngineTime() + 1.0;
	
	decl iEquipmentEntities[EquipmentType];
	if(!ItemEquipment_GetEntities(iClient, iEquipmentEntities))
		return;
	
	decl iEnt;
	for(new i=0; i<sizeof(g_aContinuousEffects[]); i++)
	{
		if(g_aContinuousEffects[iClient][i] == INVALID_HANDLE)
			continue;
		
		iEnt = iEquipmentEntities[i];
		if(iEnt < 1)
			continue;
		
		PM_StopEntityEffects(iEnt);
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

SetContinuousEffect(iClient, const String:szEffect[], iEquipmentTypeIndex)
{
	if(g_aContinuousEffects[iClient][iEquipmentTypeIndex] == INVALID_HANDLE)
		g_aContinuousEffects[iClient][iEquipmentTypeIndex] = CreateArray(MAX_STORE_DATA_STRING_LEN+1);
	
	if(FindStringInArray(g_aContinuousEffects[iClient][iEquipmentTypeIndex], szEffect) != -1)
		return;
	
	PushArrayString(g_aContinuousEffects[iClient][iEquipmentTypeIndex], szEffect);
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
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_EQUIPMENT_EFFECTS, iFoundItemID)) != -1)
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
	
	StopClientsEquipmentEffects(iClient);
	ClearContinuousEffects(iClient);
	
	TrySpawnEffects(iClient);
}

TrySpawnEffects(iClient)
{
	decl iEquipmentEntities[EquipmentType];
	if(!ItemEquipment_GetEntities(iClient, iEquipmentEntities))
		return;
	
	decl iEnt, iItemID;
	for(new i=0; i<sizeof(iEquipmentEntities); i++)
	{
		iEnt = iEquipmentEntities[i];
		if(iEnt < 1)
			continue;
		
		iItemID = GetRandomItemID(iClient);
		if(iItemID < 1)
			continue;
		
		CreateEffect(iClient, iItemID, i, iEnt);
	}
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

bool:CreateEffect(iClient, iItemID, iEquipmentTypeIndex, iEnt)
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
	
	SetContinuousEffect(iClient, szEffect, iEquipmentTypeIndex);
	
	if(!iNumClients)
		return true;
	
	PM_CreateEntityEffectFollow(iEnt, szEffect, _, _, iClients, iNumClients);
	
	return true;
}

public Store_OnRegisterVisibilitySettingsReady()
{
	Store_RegisterVisibilitySettings("Equipment Effects", CC_TYPE_STORE_IFLAGS_EQUIPMENT_EFFECTS);
}

bool:ShouldSendToClient(iClient, iOwner)
{
	new iOwnerFlags = Store_GetClientItemTypeFlags(iOwner, CC_TYPE_STORE_IFLAGS_EQUIPMENT_EFFECTS);
	
	if(iClient == iOwner)
	{
		if(iOwnerFlags & ITYPE_FLAG_SELF_DISABLED)
			return false;
	}
	else
	{
		new iClientFlags = Store_GetClientItemTypeFlags(iClient, CC_TYPE_STORE_IFLAGS_EQUIPMENT_EFFECTS);
		
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