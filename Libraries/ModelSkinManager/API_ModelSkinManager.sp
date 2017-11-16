#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <regex>
#include <cstrike>
#include <sdktools_entinput>
#include "model_skin_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Model Skin Manager";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage player models and skins.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define SOURCEMOD_CORE_CONFIG	"configs/core.cfg"
new bool:g_bFollowGuidelines = true;

#define EF_NODRAW	32

new String:g_szOriginalPlayerModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];
new String:g_szOriginalArmsModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];

new String:g_szCustomPlayerModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];
new String:g_szCustomArmsModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];
new String:g_szCustomArmsModelForReapply[MAXPLAYERS+1][PLATFORM_MAX_PATH];

new bool:g_bRequestedNextFrame[MAXPLAYERS+1];
new Handle:g_hTimer_ApplyPlayerModel[MAXPLAYERS+1];
new Handle:g_hTimer_ReapplyActiveWeapon[MAXPLAYERS+1];
new g_iReapplyActiveWeaponRef[MAXPLAYERS+1];

#define DEFAULT_MODEL_T_PIRATE		"models/player/custom_player/legacy/tm_pirate.mdl"
#define DEFAULT_MODEL_T_ANARCHIST	"models/player/custom_player/legacy/tm_anarchist.mdl"
#define DEFAULT_MODEL_CT_GIGN		"models/player/custom_player/legacy/ctm_gign.mdl"
#define DEFAULT_MODEL_CT_FBI		"models/player/custom_player/legacy/ctm_fbi.mdl"

#define DEFAULT_ARMS_T		"models/weapons/t_arms.mdl"
#define DEFAULT_ARMS_CT		"models/weapons/ct_arms.mdl"

new bool:g_bHasSetInitialArms[MAXPLAYERS+1];
new bool:g_bHasDefaultArms[MAXPLAYERS+1];
new bool:g_bHasCustomArms[MAXPLAYERS+1];
new bool:g_bRemoveArms[MAXPLAYERS+1];

new Handle:g_hFwd_OnSpawnPost;
new Handle:g_hFwd_OnSpawnPost_Post;
new g_iOriginalSpawnTick[MAXPLAYERS+1];
new bool:g_bIsForceRespawning[MAXPLAYERS+1];

new bool:g_bIgnoreDropHook[MAXPLAYERS+1];

new String:g_szSavedTargetName[512];
new Float:g_fSavedOrigin[3];
new Float:g_fSavedAngles[3];
new Float:g_fSavedVelocity[3];
new Float:g_fSavedBaseVelocity[3];
new Float:g_fSavedFallVelocity;
new Float:g_fSavedVelocityModifier;
new bool:g_bSavedDucked;
new bool:g_bSavedDucking;
new Float:g_fSavedDuckAmount;
new Float:g_fSavedDuckSpeed;
new Float:g_fSavedVecViewOffset2;
new Float:g_fSavedVecMaxs[3];
new MoveType:g_iSavedMoveType;
new g_iSavedFlags;

new g_iSavedActiveWeapon;
new g_iSavedWeaponsArray[64];
new g_iSavedClientAmmo[32];

new Float:g_fSavedNextAttack;

new g_iSavedHealth;
new g_iSavedMaxHealth;
new g_iSavedArmorValue;
new bool:g_bHasHelmet;

new g_iWearableOnSpawn_WearableIndex[MAXPLAYERS+1];
new g_iWearableOnSpawn_ItemDefIndex[MAXPLAYERS+1];
new g_iWearableOnSpawn_PaintKitIndex[MAXPLAYERS+1];
new Float:g_fWearableOnSpawn_FloatValue[MAXPLAYERS+1];

new bool:g_bCheckWeaponEquipPost;
new bool:g_bSkipWeaponEquipCheck;

new Handle:cvar_sv_allow_initial_arms_only;


public OnPluginStart()
{
	CreateConVar("api_model_skin_manager_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_sv_allow_initial_arms_only = CreateConVar("sv_allow_initial_arms_only", "0", "Set this to 1 if applying arms mid-round is conflicting with your other plugins.");
	
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	
	g_hFwd_OnSpawnPost = CreateGlobalForward("MSManager_OnSpawnPost", ET_Ignore, Param_Cell);
	g_hFwd_OnSpawnPost_Post = CreateGlobalForward("MSManager_OnSpawnPost_Post", ET_Ignore, Param_Cell);
}

public OnConfigsExecuted()
{
	g_bFollowGuidelines = ShouldFollowCSGOGuidelines();
}

public OnMapStart()
{
	PrecacheModel(DEFAULT_MODEL_T_PIRATE);
	PrecacheModel(DEFAULT_MODEL_T_ANARCHIST);
	PrecacheModel(DEFAULT_MODEL_CT_GIGN);
	PrecacheModel(DEFAULT_MODEL_CT_FBI);
	
	PrecacheModel(DEFAULT_ARMS_T);
	PrecacheModel(DEFAULT_ARMS_CT);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("model_skin_manager");
	CreateNative("MSManager_SetPlayerModel", _MSManager_SetPlayerModel);
	CreateNative("MSManager_SetArmsModel", _MSManager_SetArmsModel);
	CreateNative("MSManager_CreateWearableItem", _MSManager_CreateWearableItem);
	CreateNative("MSManager_RemovePlayerModel", _MSManager_RemovePlayerModel);
	CreateNative("MSManager_RemoveArms", _MSManager_RemoveArms);
	CreateNative("MSManager_DeleteWearableItem", _MSManager_DeleteWearableItem);
	CreateNative("MSManager_CanOnlySetInitialArms", _MSManager_CanOnlySetInitialArms);
	CreateNative("MSManager_HasDefaultArms", _MSManager_HasDefaultArms);
	CreateNative("MSManager_HasCustomArms", _MSManager_HasCustomArms);
	CreateNative("MSManager_HasWearableGloves", _MSManager_HasWearableGloves);
	CreateNative("MSManager_IsBeingForceRespawned", _MSManager_IsBeingForceRespawned);
	
	return APLRes_Success;
}

public _MSManager_IsBeingForceRespawned(Handle:hPlugin, iNumParams)
{
	return g_bIsForceRespawning[GetNativeCell(1)];
}

public _MSManager_HasDefaultArms(Handle:hPlugin, iNumParams)
{
	return g_bHasDefaultArms[GetNativeCell(1)];
}

public _MSManager_HasCustomArms(Handle:hPlugin, iNumParams)
{
	return g_bHasCustomArms[GetNativeCell(1)];
}

public _MSManager_HasWearableGloves(Handle:hPlugin, iNumParams)
{
	return (GetEntPropEnt(GetNativeCell(1), Prop_Send, "m_hMyWearables", WEARABLE_INDEX_GLOVES) != -1);
}

public _MSManager_CanOnlySetInitialArms(Handle:hPlugin, iNumParams)
{
	return GetConVarInt(cvar_sv_allow_initial_arms_only);
}

public _MSManager_SetPlayerModel(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	GetNativeString(2, g_szCustomPlayerModel[iClient], sizeof(g_szCustomPlayerModel[]));
	
	ApplyModelsNextFrame(iClient);
}

public _MSManager_SetArmsModel(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	decl String:szArmsModel[PLATFORM_MAX_PATH];
	GetNativeString(2, szArmsModel, sizeof(szArmsModel));
	
	if(g_bHasSetInitialArms[iClient])
	{
		if(!g_bHasDefaultArms[iClient] && !g_bHasCustomArms[iClient] && szArmsModel[0])
		{
			SetEntPropString(iClient, Prop_Send, "m_szArmsModel", szArmsModel);
			return true;
		}
		
		if(GetConVarInt(cvar_sv_allow_initial_arms_only))
			return false;
	}
	
	g_bRemoveArms[iClient] = false;
	strcopy(g_szCustomArmsModel[iClient], sizeof(g_szCustomArmsModel[]), szArmsModel);
	
	if(g_iOriginalSpawnTick[iClient] == GetGameTickCount())
		ApplyModelsNextFrame(iClient);
	else
		ForceRespawnForNewArms(iClient);
	
	return true;
}

public _MSManager_RemoveArms(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	if(g_bHasSetInitialArms[iClient])
	{
		if(!g_bHasDefaultArms[iClient] && !g_bHasCustomArms[iClient])
			return true;
		
		if(GetConVarInt(cvar_sv_allow_initial_arms_only))
			return false;
	}
	
	RemoveArms(iClient);
	return true;
}

RemoveArms(iClient)
{
	g_bRemoveArms[iClient] = true;
	ClearCustomModels(iClient, false, true);
	
	if(g_iOriginalSpawnTick[iClient] == GetGameTickCount())
		ApplyModelsNextFrame(iClient);
	else
		ForceRespawnForNewArms(iClient);
}

public _MSManager_DeleteWearableItem(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new iWearableIndex = GetNativeCell(2);
	
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWearables");
	if(iWearableIndex >= iArraySize)
	{
		LogError("Trying to delete a wearable index larger than the m_hMyWearables array.");
		return;
	}
	
	new iEnt = GetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", iWearableIndex);
	if(iEnt == -1)
		return;
	
	SetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", -1, iWearableIndex);
	AcceptEntityInput(iEnt, "KillHierarchy");
	
	StartTimer_ReapplyActiveWeapon(iClient);
}

StopTimer_ReapplyActiveWeapon(iClient)
{
	if(g_hTimer_ReapplyActiveWeapon[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_ReapplyActiveWeapon[iClient], false);
	g_hTimer_ReapplyActiveWeapon[iClient] = INVALID_HANDLE;
	
	ReapplyActiveWeaponFromRef(iClient);
}

StartTimer_ReapplyActiveWeapon(iClient)
{
	StopTimer_ReapplyActiveWeapon(iClient);
	
	new iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon == -1)
		return;
	
	g_hTimer_ReapplyActiveWeapon[iClient] = CreateTimer(0.1, Timer_ReapplyActiveWeapon, GetClientSerial(iClient));
	
	g_iReapplyActiveWeaponRef[iClient] = EntIndexToEntRef(iActiveWeapon);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", -1);
}

public Action:Timer_ReapplyActiveWeapon(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_ReapplyActiveWeapon[iClient] = INVALID_HANDLE;
	ReapplyActiveWeaponFromRef(iClient);
}

ReapplyActiveWeaponFromRef(iClient)
{
	if(IsPlayerAlive(iClient))
	{
		new iActiveWeapon = EntRefToEntIndex(g_iReapplyActiveWeaponRef[iClient]);
		if(iActiveWeapon && iActiveWeapon != INVALID_ENT_REFERENCE)
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iActiveWeapon);
	}
	
	g_iReapplyActiveWeaponRef[iClient] = -1;
}

public _MSManager_CreateWearableItem(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new iWearableIndex = GetNativeCell(2);
	new iItemDefIndex = GetNativeCell(3);
	new iPaintKitIndex = GetNativeCell(4);
	new Float:fFloatValue = GetNativeCell(5);
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", iWearableIndex) != -1)
		return false;
	
	if(g_bHasSetInitialArms[iClient])
	{
		if(GetConVarInt(cvar_sv_allow_initial_arms_only) && (g_bHasDefaultArms[iClient] || g_bHasCustomArms[iClient]))
			return false;
		
		// If we need to remove arms we will have to create the wearable when they respawn.
		if(g_bHasDefaultArms[iClient] || g_bHasCustomArms[iClient])
		{
			g_iWearableOnSpawn_WearableIndex[iClient] = iWearableIndex;
			g_iWearableOnSpawn_ItemDefIndex[iClient] = iItemDefIndex;
			g_iWearableOnSpawn_PaintKitIndex[iClient] = iPaintKitIndex;
			g_fWearableOnSpawn_FloatValue[iClient] = fFloatValue;
			
			RemoveArms(iClient);
			return true;
		}
	}
	
	new bool:bReturn = TryCreateNewWearableItem(iClient, iWearableIndex, iItemDefIndex, iPaintKitIndex, fFloatValue);
	
	if(bReturn && !g_bHasSetInitialArms[iClient])
	{
		g_bRemoveArms[iClient] = true;
		ClearCustomModels(iClient, false, true);
	}
	
	return bReturn;
}

bool:TryCreateNewWearableItem(iClient, iWearableIndex, iItemDefinitionIndex, iPaintKitIndex, Float:fFloatValue)
{
	if(g_bFollowGuidelines)
	{
		LogError("Could not create a wearable_item. Set \"FollowCSGOServerGuidelines\" to \"no\" in core.cfg.");
		return false;
	}
	
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWearables");
	if(iWearableIndex >= iArraySize)
	{
		LogError("Trying to set a wearable index larger than the m_hMyWearables array.");
		return false;
	}
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", iWearableIndex) != -1)
		return false;
	
	new iEnt = CreateEntityByName("wearable_item");
	if(iEnt == -1)
		return false;
	
	new iAccountID = GetSteamAccountID(iClient, false);
	SetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", iEnt, iWearableIndex);
	SetEntProp(iClient, Prop_Send, "m_nBody", 1);
	
	SetEntPropEnt(iEnt, Prop_Data, "m_hOwnerEntity", iClient);
	SetEntPropEnt(iEnt, Prop_Data, "m_hParent", iClient);
	SetEntPropEnt(iEnt, Prop_Data, "m_hMoveParent", iClient);
	
	SetEntProp(iEnt, Prop_Send, "m_bInitialized", 1);
	SetEntProp(iEnt, Prop_Send, "m_iItemIDLow", -1);
	SetEntProp(iEnt, Prop_Send, "m_iItemIDHigh", 0);
	SetEntProp(iEnt, Prop_Send, "m_nFallbackSeed", 0);
	SetEntProp(iEnt, Prop_Send, "m_iAccountID", iAccountID);
	SetEntProp(iEnt, Prop_Send, "m_nFallbackStatTrak", iAccountID);
	SetEntProp(iEnt, Prop_Send, "m_iItemDefinitionIndex", iItemDefinitionIndex);
	SetEntProp(iEnt, Prop_Send, "m_nFallbackPaintKit", iPaintKitIndex);
	SetEntPropFloat(iEnt, Prop_Send, "m_flFallbackWear", fFloatValue);
	
	DispatchSpawn(iEnt);
	
	new iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon != -1)
	{
		RemovePlayerItem(iClient, iActiveWeapon);
		
		g_bSkipWeaponEquipCheck = true;
		EquipPlayerWeapon(iClient, iActiveWeapon);
		g_bSkipWeaponEquipCheck = false;
	}
	
	return true;
}

public _MSManager_RemovePlayerModel(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	SetEntityModel(iClient, g_szOriginalPlayerModel[iClient]);
}

ApplyModelsNextFrame(iClient)
{
	StopTimer_ApplyPlayerModel(iClient);
	
	if(g_bRequestedNextFrame[iClient])
		return;
	
	RequestFrame(OnApplyModelsNextFrame, GetClientSerial(iClient));
	g_bRequestedNextFrame[iClient] = true;
}

public OnApplyModelsNextFrame(any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(!g_bRequestedNextFrame[iClient])
		return;
	
	g_bRequestedNextFrame[iClient] = false;
	g_bHasSetInitialArms[iClient] = true;
	SetEntProp(iClient, Prop_Send, "m_nBody", 0);
	
	if(g_szCustomArmsModel[iClient][0])
	{
		SetEntPropString(iClient, Prop_Send, "m_szArmsModel", g_szCustomArmsModel[iClient]);
		g_bHasCustomArms[iClient] = true;
		
		StartTimer_ApplyPlayerModel(iClient);
	}
	else
	{
		if(g_bRemoveArms[iClient])
		{
			ClearCustomModels(iClient, false, true);
			StartTimer_ApplyPlayerModel(iClient);
			
			if(g_iWearableOnSpawn_ItemDefIndex[iClient])
				TryCreateNewWearableItem(iClient, g_iWearableOnSpawn_WearableIndex[iClient], g_iWearableOnSpawn_ItemDefIndex[iClient], g_iWearableOnSpawn_PaintKitIndex[iClient], g_fWearableOnSpawn_FloatValue[iClient]);
		}
		else
		{
			ApplyDefaultArms(iClient);
			
			//ApplyPlayerModel(iClient);
			StartTimer_ApplyPlayerModel(iClient);
			g_bHasDefaultArms[iClient] = true;
		}
	}
	
	g_iWearableOnSpawn_ItemDefIndex[iClient] = 0;
}

ApplyDefaultArms(iClient)
{
	switch(GetClientTeam(iClient))
	{
		case CS_TEAM_T: SetEntPropString(iClient, Prop_Send, "m_szArmsModel", DEFAULT_ARMS_T);
		case CS_TEAM_CT: SetEntPropString(iClient, Prop_Send, "m_szArmsModel", DEFAULT_ARMS_CT);
	}
}

StopTimer_ApplyPlayerModel(iClient)
{
	if(g_hTimer_ApplyPlayerModel[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_ApplyPlayerModel[iClient]);
	g_hTimer_ApplyPlayerModel[iClient] = INVALID_HANDLE;
}

StartTimer_ApplyPlayerModel(iClient)
{
	StopTimer_ApplyPlayerModel(iClient);
	g_hTimer_ApplyPlayerModel[iClient] = CreateTimer(0.1, Timer_ApplyPlayerModel, GetClientSerial(iClient));
}

public Action:Timer_ApplyPlayerModel(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_ApplyPlayerModel[iClient] = INVALID_HANDLE;
	ApplyPlayerModel(iClient);
}

ApplyPlayerModel(iClient)
{
	if(IsPlayerAlive(iClient))
	{
		if(g_szCustomPlayerModel[iClient][0])
			SetEntityModel(iClient, g_szCustomPlayerModel[iClient]);
		else
			SetEntityModel(iClient, g_szOriginalPlayerModel[iClient]);
		
		SetEntProp(iClient, Prop_Send, "m_fEffects", GetEntProp(iClient, Prop_Send, "m_fEffects") & ~EF_NODRAW);
	}
	
	ClearCustomModels(iClient);
	g_bRemoveArms[iClient] = false;
	
	if(g_bHasCustomArms[iClient])
		RequestFrame(OnApplyCustomArmsNextFrame, GetClientSerial(iClient));
}

public OnApplyCustomArmsNextFrame(any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(g_bHasCustomArms[iClient])
		SetEntPropString(iClient, Prop_Send, "m_szArmsModel", g_szCustomArmsModelForReapply[iClient]);
}

CancelApplyAllModels(iClient)
{
	g_bRequestedNextFrame[iClient] = false;
	StopTimer_ApplyPlayerModel(iClient);
}

public Action:Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	if(g_bIsForceRespawning[iClient])
		return;
	
	ResetClientVariables(iClient);
}

ResetClientVariables(iClient)
{
	g_bHasSetInitialArms[iClient] = false;
	CancelApplyAllModels(iClient);
	ClearCustomModels(iClient);
	g_bRemoveArms[iClient] = false;
	g_iWearableOnSpawn_ItemDefIndex[iClient] = 0;
	g_bIsForceRespawning[iClient] = false;
	StopTimer_ReapplyActiveWeapon(iClient);
}

public Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			ResetClientVariables(iClient);
	}
}

public OnClientDisconnect(iClient)
{
	ResetClientVariables(iClient);
}

SaveClientData(iClient)
{
	GetEntPropString(iClient, Prop_Data, "m_iName", g_szSavedTargetName, sizeof(g_szSavedTargetName));
	GetClientAbsOrigin(iClient, g_fSavedOrigin);
	GetClientEyeAngles(iClient, g_fSavedAngles);
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", g_fSavedVelocity);
	GetEntPropVector(iClient, Prop_Send, "m_vecBaseVelocity", g_fSavedBaseVelocity);
	g_fSavedFallVelocity = GetEntPropFloat(iClient, Prop_Send, "m_flFallVelocity");
	g_fSavedVelocityModifier = GetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier");
	g_bSavedDucked = bool:GetEntProp(iClient, Prop_Send, "m_bDucked");
	g_bSavedDucking = bool:GetEntProp(iClient, Prop_Send, "m_bDucking");
	g_fSavedDuckAmount = GetEntPropFloat(iClient, Prop_Send, "m_flDuckAmount");
	g_fSavedDuckSpeed = GetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed");
	g_fSavedVecViewOffset2 = GetEntPropFloat(iClient, Prop_Send, "m_vecViewOffset[2]");
	GetEntPropVector(iClient, Prop_Send, "m_vecMaxs", g_fSavedVecMaxs);
	g_iSavedMoveType = GetEntityMoveType(iClient);
	g_iSavedFlags = GetEntityFlags(iClient);
	
	g_fSavedNextAttack = GetEntPropFloat(iClient, Prop_Send, "m_flNextAttack");
	
	g_iSavedMaxHealth = GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
	g_iSavedHealth = GetEntProp(iClient, Prop_Data, "m_iHealth");
	g_iSavedArmorValue = GetEntProp(iClient, Prop_Send, "m_ArmorValue");
	g_bHasHelmet = bool:GetEntProp(iClient, Prop_Send, "m_bHasHelmet");
	
	SaveClientWeapons(iClient);
}

LoadClientData(iClient)
{
	RestoreClientWeapons(iClient);
	
	SetEntPropString(iClient, Prop_Data, "m_iName", g_szSavedTargetName);
	SetEntPropVector(iClient, Prop_Send, "m_vecBaseVelocity", g_fSavedBaseVelocity);
	SetEntPropFloat(iClient, Prop_Send, "m_flFallVelocity", g_fSavedFallVelocity);
	SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", g_fSavedVelocityModifier);
	SetEntProp(iClient, Prop_Send, "m_bDucked", g_bSavedDucked);
	SetEntProp(iClient, Prop_Send, "m_bDucking", g_bSavedDucking);
	SetEntPropFloat(iClient, Prop_Send, "m_flDuckAmount", g_fSavedDuckAmount);
	SetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed", g_fSavedDuckSpeed);
	SetEntPropFloat(iClient, Prop_Send, "m_vecViewOffset[2]", g_fSavedVecViewOffset2);
	SetEntPropVector(iClient, Prop_Send, "m_vecMaxs", g_fSavedVecMaxs);
	SetEntityMoveType(iClient, g_iSavedMoveType);
	SetEntityFlags(iClient, g_iSavedFlags);
	
	TeleportEntity(iClient, g_fSavedOrigin, g_fSavedAngles, g_fSavedVelocity);
	SetEntPropString(iClient, Prop_Data, "m_iName", g_szSavedTargetName); // Set the clients targetname after teleporting as well.
	
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", g_fSavedNextAttack);
	
	SetEntProp(iClient, Prop_Data, "m_iMaxHealth", g_iSavedMaxHealth);
	SetEntityHealth(iClient, g_iSavedHealth);
	SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_iSavedArmorValue);
	SetEntProp(iClient, Prop_Send, "m_bHasHelmet", g_bHasHelmet);
}

ForceRespawnForNewArms(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	StopTimer_ReapplyActiveWeapon(iClient);
	
	// Make sure we reapply the same model the client is already using when they respawn, but only as long as we aren't already setting a custom player model.
	if(!g_szCustomPlayerModel[iClient][0])
		GetEntPropString(iClient, Prop_Data, "m_ModelName", g_szCustomPlayerModel[iClient], sizeof(g_szCustomPlayerModel[]));
	
	SaveClientData(iClient);
	
	g_bIsForceRespawning[iClient] = true;
	CS_RespawnPlayer(iClient);
	g_bIsForceRespawning[iClient] = false;
	
	LoadClientData(iClient);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	SDKHook(iClient, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquip_Post);
}

public OnWeaponEquip(iClient, iWeapon)
{
	if(g_bSkipWeaponEquipCheck)
	{
		g_bCheckWeaponEquipPost = false;
		return;
	}
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == -1)
		g_bCheckWeaponEquipPost = true;
	else
		g_bCheckWeaponEquipPost = false;
}

public OnWeaponEquip_Post(iClient, iWeapon)
{
	if(!g_bCheckWeaponEquipPost)
		return;
	
	if(!g_bHasSetInitialArms[iClient])
		return;
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") == -1)
		return;
	
	// Wearable gloves don't disappear.
	if(GetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", WEARABLE_INDEX_GLOVES) != -1)
		return;
	
	// When a player loses all their weapons and then regains a weapon their arms will be missing since we unset m_szArmsModel. Reapply them.
	if(g_bHasCustomArms[iClient])
	{
		SetEntPropString(iClient, Prop_Send, "m_szArmsModel", g_szCustomArmsModelForReapply[iClient]);
	}
	else if(g_bHasDefaultArms[iClient])
	{
		ApplyDefaultArms(iClient);
	}
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	g_bHasDefaultArms[iClient] = false;
	g_bHasCustomArms[iClient] = false;
	
	new iGloves = GetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", WEARABLE_INDEX_GLOVES);
	if(iGloves != -1)
	{
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWearables", -1, WEARABLE_INDEX_GLOVES);
		AcceptEntityInput(iGloves, "KillHierarchy");
	}
	
	if(!g_bIsForceRespawning[iClient])
	{
		g_iOriginalSpawnTick[iClient] = GetGameTickCount();
		
		GetEntPropString(iClient, Prop_Data, "m_ModelName", g_szOriginalPlayerModel[iClient], sizeof(g_szOriginalPlayerModel[]));
		strcopy(g_szOriginalArmsModel[iClient], sizeof(g_szOriginalArmsModel[]), "");
		ClearCustomModels(iClient);
		g_bRemoveArms[iClient] = false;
		
		Forward_OnSpawnPost(iClient, true);
		Forward_OnSpawnPost(iClient, false);
	}
	
	ApplyPlayerModelToHideArms(iClient);
	ApplyModelsNextFrame(iClient);
}

Forward_OnSpawnPost(iClient, bool:bPre)
{
	new result;
	Call_StartForward(bPre ? g_hFwd_OnSpawnPost : g_hFwd_OnSpawnPost_Post);
	Call_PushCell(iClient);
	Call_Finish(result);
}

ClearCustomModels(iClient, bool:bClearPlayerModel=true, bool:bClearArmsModel=true)
{
	if(bClearPlayerModel)
		strcopy(g_szCustomPlayerModel[iClient], sizeof(g_szCustomPlayerModel[]), "");
	
	if(bClearArmsModel)
	{
		if(IsClientInGame(iClient))
			SetEntPropString(iClient, Prop_Send, "m_szArmsModel", "");
		
		strcopy(g_szCustomArmsModelForReapply[iClient], sizeof(g_szCustomArmsModelForReapply[]), g_szCustomArmsModel[iClient]);
		strcopy(g_szCustomArmsModel[iClient], sizeof(g_szCustomArmsModel[]), "");
	}
}

ApplyPlayerModelToHideArms(iClient)
{
	SetEntProp(iClient, Prop_Send, "m_fEffects", GetEntProp(iClient, Prop_Send, "m_fEffects") | EF_NODRAW);
	
	if(strlen(g_szOriginalPlayerModel[iClient]) < 40)
		return;
	
	decl iChar;
	switch(GetClientTeam(iClient))
	{
		case CS_TEAM_T:
		{
			iChar = g_szOriginalPlayerModel[iClient][41];
			g_szOriginalPlayerModel[iClient][41] = 0x00;
			
			if(StrEqual(g_szOriginalPlayerModel[iClient][38], "ana"))
				SetEntityModel(iClient, DEFAULT_MODEL_T_PIRATE);
			else
				SetEntityModel(iClient, DEFAULT_MODEL_T_ANARCHIST);
			
			g_szOriginalPlayerModel[iClient][41] = iChar;
		}
		case CS_TEAM_CT:
		{
			iChar = g_szOriginalPlayerModel[iClient][42];
			g_szOriginalPlayerModel[iClient][42] = 0x00;
			
			if(StrEqual(g_szOriginalPlayerModel[iClient][39], "fbi") || StrEqual(g_szOriginalPlayerModel[iClient][39], "sas") || StrEqual(g_szOriginalPlayerModel[iClient][39], "swa"))
				SetEntityModel(iClient, DEFAULT_MODEL_CT_GIGN);
			else
				SetEntityModel(iClient, DEFAULT_MODEL_CT_FBI);
			
			g_szOriginalPlayerModel[iClient][42] = iChar;
		}
	}
}

bool:ShouldFollowCSGOGuidelines()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), SOURCEMOD_CORE_CONFIG);
	
	new Handle:fp = OpenFile(szBuffer, "r");
	if(fp == INVALID_HANDLE)
	{
		LogError("Could not read sourcemod's core config.");
		return true;
	}
	
	new bool:bShouldFollow = true;
	new Handle:hRegex = CompileRegex(".*?\"FollowCSGOServerGuidelines\".*?\"(.*?)\"", PCRE_CASELESS);
	
	while(!IsEndOfFile(fp))
	{
		ReadFileLine(fp, szBuffer, sizeof(szBuffer));
		
		if(MatchRegex(hRegex, szBuffer) < 2)
			continue;
		
		GetRegexSubString(hRegex, 1, szBuffer, sizeof(szBuffer));
		if(StrEqual(szBuffer, "no"))
			bShouldFollow = false;
		
		break;
	}
	
	CloseHandle(hRegex);
	CloseHandle(fp);
	
	return bShouldFollow;
}

SaveClientWeapons(iClient)
{
	g_iSavedActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", -1);
	
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	if(iArraySize > sizeof(g_iSavedWeaponsArray))
	{
		iArraySize = sizeof(g_iSavedWeaponsArray);
		LogError("This plugin needs its g_iSavedWeaponsArray array size increased.");
	}
	
	for(new i=0; i<iArraySize; i++)
	{
		g_iSavedWeaponsArray[i] = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, i);
	}
	
	// Save ammo.
	iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_iAmmo");
	if(iArraySize > sizeof(g_iSavedClientAmmo))
	{
		iArraySize = sizeof(g_iSavedClientAmmo);
		LogError("This plugin needs its g_iSavedClientAmmo array size increased.");
	}
	
	for(new i=0; i<iArraySize; i++)
		g_iSavedClientAmmo[i] = GetEntProp(iClient, Prop_Send, "m_iAmmo", _, i);
}

RestoreClientWeapons(iClient)
{
	StripClientWeapons(iClient);
	
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	if(iArraySize > sizeof(g_iSavedWeaponsArray))
		iArraySize = sizeof(g_iSavedWeaponsArray);
	
	for(new i=0; i<iArraySize; i++)
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", g_iSavedWeaponsArray[i], i);
	
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", g_iSavedActiveWeapon);
	
	if(g_iSavedActiveWeapon != -1)
	{
		RemovePlayerItem(iClient, g_iSavedActiveWeapon);
		
		g_bSkipWeaponEquipCheck = true;
		EquipPlayerWeapon(iClient, g_iSavedActiveWeapon);
		g_bSkipWeaponEquipCheck = false;
	}
	
	// Restore ammo.
	iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_iAmmo");
	if(iArraySize > sizeof(g_iSavedClientAmmo))
		iArraySize = sizeof(g_iSavedClientAmmo);
	
	for(new i=0; i<iArraySize; i++)
		SetEntProp(iClient, Prop_Send, "m_iAmmo", g_iSavedClientAmmo[i], _, i);
}

StripClientWeapons(iClient)
{
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	decl iWeapon;
	for(new i=0; i<iArraySize; i++)
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if(iWeapon < 1)
			continue;
		
		KillOwnedWeapon(iWeapon);
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, i);
	}
}

KillOwnedWeapon(iWeapon)
{
	new iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if(iOwner != -1)
	{
		// First drop the weapon.
		g_bIgnoreDropHook[iOwner] = true;
		SDKHooks_DropWeapon(iOwner, iWeapon);
		g_bIgnoreDropHook[iOwner] = false;
		
		// If the weapon still has an owner after being dropped called RemovePlayerItem.
		// Note we check m_hOwner instead of m_hOwnerEntity here.
		if(GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner") == iOwner)
			RemovePlayerItem(iOwner, iWeapon);
		
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", -1);
	}
	
	KillWeapon(iWeapon);
}

KillWeapon(iWeapon)
{
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel != -1)
	{
		SetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel", -1);
		AcceptEntityInput(iWorldModel, "KillHierarchy");
	}
	
	AcceptEntityInput(iWeapon, "KillHierarchy");
}