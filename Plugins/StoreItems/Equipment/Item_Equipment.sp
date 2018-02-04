#include <sourcemod>
#include <sdktools_entinput>
#include <sdktools_variant_t>
#include <sdktools_functions>
#include <sdkhooks>
#include "../../../Libraries/Store/store"
#include "../../../Plugins/HidePlayers/hide_players"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Equipment";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to attach equipment to themselves.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EF_BONEMERGE			1
#define EF_NOSHADOW				16
#define EF_NODRAW				32
#define EF_NORECEIVESHADOW		64
#define EF_BONEMERGE_FASTCULL	128

#define SPECMODE_FIRSTPERSON	4

new const EQUIPMENT_ITEM_TYPES[] =
{
	STOREITEM_TYPE_EQUIPMENT_HEAD,
	STOREITEM_TYPE_EQUIPMENT_FACE,
	STOREITEM_TYPE_EQUIPMENT_TORSO
};

enum EquipmentType
{
	EquipmentType_Head,
	EquipmentType_Face,
	EquipmentType_Torso
};

new g_iEquipmentRefs[MAXPLAYERS+1][EquipmentType];
new Handle:g_aEquipmentIDs[EquipmentType];


public OnPluginStart()
{
	CreateConVar("store_item_equipment_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	for(new i=0; i<sizeof(g_aEquipmentIDs); i++)
		g_aEquipmentIDs[i] = CreateArray();
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_aEquipmentIDs); i++)
		ClearArray(g_aEquipmentIDs[i]);
}

public Store_OnItemsReady()
{
	decl iIndex, iFoundItemID;
	for(new i=0; i<sizeof(g_aEquipmentIDs); i++)
	{
		iIndex = -1;
		while((iIndex = Store_FindItemByType(iIndex, EQUIPMENT_ITEM_TYPES[i], iFoundItemID)) != -1)
		{
			PushArrayCell(g_aEquipmentIDs[i], iFoundItemID);
		}
	}
}

RemoveEquipment(iClient, bool:bKill=true)
{
	decl iEnt;
	for(new i=0; i<sizeof(g_iEquipmentRefs[]); i++)
	{
		iEnt = EntRefToEntIndex(g_iEquipmentRefs[iClient][i]);
		if(!iEnt || iEnt == INVALID_ENT_REFERENCE)
			continue;
		
		SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_NODRAW);
		
		if(bKill)
		{
			AcceptEntityInput(iEnt, "KillHierarchy");
			g_iEquipmentRefs[iClient][i] = INVALID_ENT_REFERENCE;
		}
	}
}

public OnClientDisconnect(iClient)
{
	RemoveEquipment(iClient);
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RemoveEquipment(GetClientOfUserId(GetEventInt(hEvent, "userid")), false);
}

public OnClientPutInServer(iClient)
{
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	decl iItemID;
	for(new i=0; i<sizeof(g_aEquipmentIDs); i++)
	{
		iItemID = GetRandomEquipmentID(iClient, i);
		if(iItemID < 1)
			continue;
		
		GiveEquipmentEntity(iClient, i, iItemID);
	}
}

GetRandomEquipmentID(iClient, iIndex)
{
	decl iItemID;
	new Handle:hOwned = CreateArray();
	for(new i=0; i<GetArraySize(g_aEquipmentIDs[iIndex]); i++)
	{
		iItemID = GetArrayCell(g_aEquipmentIDs[iIndex], i);
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

bool:GiveEquipmentEntity(iClient, iTypeIndex, iItemID)
{
	decl String:szPath[PLATFORM_MAX_PATH];
	if(!Store_GetItemsMainFilePath(iItemID, szPath, sizeof(szPath)))
		return false;
	
	new iEnt = GetEquipmentEntity(iClient, iTypeIndex);
	if(iEnt < 1)
		return false;
	
	SetEntityModel(iEnt, szPath);
	InitEquipmentEntity(iClient, iEnt);
	
	return true;
}

GetEquipmentEntity(iClient, iTypeIndex)
{
	new iEnt = EntRefToEntIndex(g_iEquipmentRefs[iClient][iTypeIndex]);
	if(iEnt > 0)
		return iEnt;
	
	iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1)
		return -1;
	
	SDKHook(iEnt, SDKHook_SetTransmit, OnSetTransmit);
	g_iEquipmentRefs[iClient][iTypeIndex] = EntIndexToEntRef(iEnt);
	
	return iEnt;
}

InitEquipmentEntity(iClient, iEnt)
{
	DispatchKeyValue(iEnt, "solid", "0");
	DispatchKeyValue(iEnt, "fademindist", "1200");
	DispatchKeyValue(iEnt, "fademaxdist", "1800");
	DispatchKeyValue(iEnt, "disableshadows", "1");
	DispatchKeyValue(iEnt, "disableshadowdepth", "1");
	
	SetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity", iClient);
	
	AcceptEntityInput(iEnt, "ClearParent");
	SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_NOSHADOW | EF_NORECEIVESHADOW | EF_BONEMERGE | EF_BONEMERGE_FASTCULL);
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetParent", iClient);
}

// TODO: If CS:GO entity limit increases we will need to increase these arrays.
#define ENTITY_LIMIT 4096
new Action:g_CachedTransmit[MAXPLAYERS+1][ENTITY_LIMIT+1];
new Float:g_fNextTransmit[MAXPLAYERS+1][ENTITY_LIMIT+1];

new bool:g_bCachedHidingTarget[MAXPLAYERS+1][MAXPLAYERS+1];
new Float:g_fNextHideCheck[MAXPLAYERS+1][MAXPLAYERS+1];

public Action:OnSetTransmit(iEnt, iClient)
{
	if(g_fNextTransmit[iClient][iEnt] > GetEngineTime())
		return g_CachedTransmit[iClient][iEnt];
	
	g_fNextTransmit[iClient][iEnt] = GetEngineTime() + GetRandomFloat(0.5, 0.8);
	
	// Don't transmit equipment entities to fake clients (includes Source TV).
	if(IsFakeClient(iClient))
	{
		g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
		return Plugin_Handled;
	}
	
	// Don't transmit equipment entities to their owner.
	static iOwner;
	iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
	if(iOwner == iClient)
	{
		g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
		return Plugin_Handled;
	}
	
	// Don't transmit if the owner isn't alive.
	if(!IsPlayerAlive(iOwner) || GetEntProp(iOwner, Prop_Send, "m_lifeState") == 1)
	{
		g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
		return Plugin_Handled;
	}
	
	// Don't transmit to someone spectating the equipments owner in firstperson.
	if(GetEntProp(iClient, Prop_Send, "m_iObserverMode") == SPECMODE_FIRSTPERSON)
	{
		static iSpectating;
		iSpectating = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		
		if(iOwner == iSpectating)
		{
			g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
			return Plugin_Handled;
		}
	}
	
	// Don't transmit if the item type flags don't allow it (but only run these checks if the player being transmitted to is alive).
	if(IsPlayerAlive(iClient))
	{
		static iClientFlags, iOwnerFlags;
		iClientFlags = Store_GetClientSettings(iClient, STOREITEM_TYPE_EQUIPMENT_HEAD);
		iOwnerFlags = Store_GetClientSettings(iOwner, STOREITEM_TYPE_EQUIPMENT_HEAD);
		
		if(GetClientTeam(iClient) == GetClientTeam(iOwner))
		{
			if(iClientFlags & ITYPE_FLAG_MY_TEAM_DISABLED)
			{
				g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
				return Plugin_Handled;
			}
			
			if(iOwnerFlags & ITYPE_FLAG_MY_ITEM_MY_TEAM_DISABLED)
			{
				g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
				return Plugin_Handled;
			}
		}
		else
		{
			if(iClientFlags & ITYPE_FLAG_OTHER_TEAM_DISABLED)
			{
				g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
				return Plugin_Handled;
			}
			
			if(iOwnerFlags & ITYPE_FLAG_MY_ITEM_OTHER_TEAM_DISABLED)
			{
				g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
				return Plugin_Handled;
			}
		}
	}
	
	// Don't transmit if the client is hiding the equipments owner.
	if(g_fNextHideCheck[iClient][iOwner] <= GetEngineTime())
	{
		g_bCachedHidingTarget[iClient][iOwner] = HidePlayers_IsClientHidingTarget(iClient, iOwner);
		g_fNextHideCheck[iClient][iOwner] = GetEngineTime() + GetRandomFloat(1.1, 1.5);
	}
	
	if(g_bCachedHidingTarget[iClient][iOwner])
	{
		g_CachedTransmit[iClient][iEnt] = Plugin_Handled;
		return Plugin_Handled;
	}
	
	g_CachedTransmit[iClient][iEnt] = Plugin_Continue;
	return Plugin_Continue;
}