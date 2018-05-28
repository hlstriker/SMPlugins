#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <emitsoundany>
#include <sdktools_stringtables>
#include <sdktools_trace>
#include <sdktools_voice>
#include <hls_color_chat>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_lr_effects"
#include "Includes/ultjb_weapon_selection"
#include "Includes/ultjb_warden"
#include "Includes/ultjb_days"
#include "Includes/ultjb_settings"
#include "Includes/ultjb_logger"
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Plugins/ZoneTypes/Includes/zonetype_teleport"

#undef REQUIRE_PLUGIN
#include "../../Libraries/SquelchManager/squelch_manager"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Last Request API";
new const String:PLUGIN_VERSION[] = "1.41";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The last request API for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

const MAX_LAST_REQUESTS = 128;

new Handle:g_aLastRequests;
new g_iLastRequestIDToIndex[MAX_LAST_REQUESTS+1];
enum _:LastRequest
{
	LR_ID,
	String:LR_Name[LAST_REQUEST_MAX_NAME_LENGTH],
	String:LR_Description[LAST_REQUEST_MAX_DESCRIPTION_LENGTH],
	Handle:LR_ForwardStart,
	Handle:LR_ForwardEnd,
	Handle:LR_ForwardOpponentLeft,
	LR_Flags,
	LR_CategoryID
};

new Handle:g_hFwd_OnRegisterReady;
new Handle:g_hFwd_OnLastRequestInitialized;
new Handle:g_hFwd_OnLastRequestStarted;

new Handle:g_hFwd_OnOpponentSelectedSuccess[MAXPLAYERS+1];
new Handle:g_hFwd_OnOpponentSelectedFailed[MAXPLAYERS+1];

new Handle:cvar_prisoners_can_use_percent;
new Handle:cvar_select_last_request_time;
new Handle:cvar_select_opponent_time;
new Handle:cvar_guards_needed_for_rebel;
new Handle:cvar_disable_freeday_lr_time;

new g_iDisconnectTeam[MAXPLAYERS+1];

new bool:g_bHasInitialized[MAXPLAYERS+1];
new bool:g_bHasStarted[MAXPLAYERS+1];

new bool:g_bHasDiedSinceStarted[MAXPLAYERS+1];
new bool:g_bHasRoundEndedSinceStarted[MAXPLAYERS+1];

new bool:g_bCanDealDamage[MAXPLAYERS+1];
new bool:g_bHasInvincibility[MAXPLAYERS+1];

#define INVALID_LAST_REQUEST_INDEX -1
new g_iClientsLastRequestIndex[MAXPLAYERS+1] = {INVALID_LAST_REQUEST_INDEX, ...};

new Handle:g_hMenu_LastRequest[MAXPLAYERS+1];
new Handle:g_hMenu_OpponentSelection[MAXPLAYERS+1];
new g_iCategoryMenuPosition[MAXPLAYERS+1];

new Handle:g_hTimer_SelectLastRequest[MAXPLAYERS+1];
new Handle:g_hTimer_OpponentSelection[MAXPLAYERS+1];
new Handle:g_hTimer_SlayTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new Handle:g_hTimer_SlayClient[MAXPLAYERS+1];
new Handle:g_hTimer_CancelFreeday[MAXPLAYERS+1];
new Handle:g_hTimer_TempInvincibility[MAXPLAYERS+1];

new g_iLastRequestOpponentSerial[MAXPLAYERS+1];
new g_iClientsCachedSerial[MAXPLAYERS+1];

new bool:g_bHasRoundStarted;

const MAX_WEAPONS = 128;
const MAX_WEAPON_CLASSNAME_LENGTH = 32;
new String:g_szSavedActiveWeapon[MAXPLAYERS+1][MAX_WEAPON_CLASSNAME_LENGTH];
new g_iSavedWeaponAmmoClip[MAXPLAYERS+1][MAX_WEAPONS];
new g_iSavedWeaponAmmoReserveGlobal[MAXPLAYERS+1][MAX_WEAPONS];
new g_iSavedWeaponAmmoReservePrimary[MAXPLAYERS+1][MAX_WEAPONS];
new g_iSavedWeaponAmmoReserveSecondary[MAXPLAYERS+1][MAX_WEAPONS];
new Handle:g_aSavedWeapons[MAXPLAYERS+1];

new const BEAM_COLOR_START[] = {0, 255, 0, 200};
new const BEAM_COLOR_END[] = {255, 0, 0, 200};

const Float:EFFECT_BEAM_TIME = 0.5;
const Float:EFFECT_RING_TIME = 0.55;

new Float:g_fNextEffectUpdate_Ring[MAXPLAYERS+1];
new Float:g_fNextEffectUpdate_Beam[MAXPLAYERS+1];

new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";
new const String:SZ_BEAM_WALL_MATERIAL[] = "materials/swoobles/ultimate_jailbreak/wall_beam.vmt";
new g_iBeamIndex;
new g_iBeamWallIndex;

new const String:SZ_SOUND_LR_ACTIVATED[] = "sound/swoobles/ultimate_jailbreak/last_request_activated.mp3";

new g_iSavedHealth[MAXPLAYERS+1];
new g_iSavedMaxHealth[MAXPLAYERS+1];
new g_iSavedArmor[MAXPLAYERS+1];
new g_iSavedHelmet[MAXPLAYERS+1];

new g_iOtherCategoryID;
new Handle:g_aCategories;
new g_iCategoryIDToIndex[MAX_LAST_REQUESTS+1]; // Use MAX_LAST_REQUESTS because each last request should be able to have its own category.
enum _:Category
{
	Category_ID,
	String:Category_Name[LR_CATEGORY_MAX_NAME_LENGTH],
	Handle:Category_LastRequestIDs
};

new g_iRoundNumber;

new g_iTeleportLRZoneID;
new Handle:g_aTeleportLRRebelZone;

new Float:g_fPreLastRequestLocations[MAXPLAYERS+1][3];

#define SetWeaponOwnerSerial(%1,%2)		SetEntProp(%1, Prop_Data, "m_iMaxHealth", %2)
#define GetWeaponOwnerSerial(%1)		GetEntProp(%1, Prop_Data, "m_iMaxHealth")

new const Float:HULL_STANDING_MINS_CSGO[] = {-16.0, -16.0, 0.0};
new const Float:HULL_STANDING_MAXS_CSGO[] = {16.0, 16.0, 72.0};

const MAX_TELEPORT_HOPS = 6;

enum
{
	DIR_X_POS = 0,
	DIR_X_NEG,
	DIR_Y_POS,
	DIR_Y_NEG,
	DIR_BOTH_POS,
	DIR_BOTH_NEG,
	DIR_BOTH_X_POS, // Uses both directions where X is pos and Y is neg.
	DIR_BOTH_X_NEG, // Uses both directions where X is neg and Y is pos.
	NUM_DIR_TYPES
};

new bool:g_bInitializedAdminGivenFreeday[MAXPLAYERS+1];
new g_iAvailableLastRequestSlotCount;

new bool:g_bLibLoaded_SquelchManager;
new bool:g_bLibLoaded_ModelSkinManager;

new Float:g_fLastRequestTeleportOrigins[100][3];
new g_iLastRequestTeleportOriginsTotal;
new g_iLastRequestTeleportOrigins_OldHealth[MAXPLAYERS+1];
new Handle:g_hTimer_LastRequestTeleportOrigins;


public OnPluginStart()
{
	CreateConVar("ultjb_api_last_request_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	LoadTranslations("common.phrases");
	
	cvar_prisoners_can_use_percent = CreateConVar("ultjb_lr_prisoners_can_use_percent", "8", "The percent of prisoners who can use LR.", _, true, 1.0, true, 100.0);
	cvar_select_last_request_time = CreateConVar("ultjb_lr_select_last_request_time", "20", "The number of seconds a prisoner has to select a LR.", _, true, 1.0);
	cvar_select_opponent_time = CreateConVar("ultjb_lr_select_opponent_time", "15", "The number of seconds a prisoner has to select their opponent.", _, true, 1.0);
	cvar_guards_needed_for_rebel = CreateConVar("ultjb_lr_guards_needed_for_rebel", "3", "The number of guards needed before rebel LRs are allowed.", _, true, 1.0);
	cvar_disable_freeday_lr_time = CreateConVar("ultjb_lr_disable_freeday_lr_time", "150", "Disable freeday last requests this many seconds before the map change.", _, true, 0.0);
	
	g_aLastRequests = CreateArray(LastRequest);
	g_aCategories = CreateArray(Category);
	g_aTeleportLRRebelZone = CreateArray();
	
	g_hFwd_OnRegisterReady = CreateGlobalForward("UltJB_LR_OnRegisterReady", ET_Ignore);
	g_hFwd_OnLastRequestInitialized = CreateGlobalForward("UltJB_LR_OnLastRequestInitialized", ET_Ignore, Param_Cell);
	g_hFwd_OnLastRequestStarted = CreateGlobalForward("UltJB_LR_OnLastRequestStarted", ET_Ignore, Param_Cell, Param_Cell);
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart_Pre, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	RegConsoleCmd("sm_lr", OnLastRequest, "Opens the last request menu.");
	RegConsoleCmd("sm_lastrequest", OnLastRequest, "Opens the last request menu.");
	RegConsoleCmd("sm_lrs", OnLastRequestSlots, "Checks how many players can use last request.");
	
	AddCommandListener(OnWeaponDrop, "drop");
	
	RegAdminCmd("sm_abortlr", Command_AbortLastRequest, ADMFLAG_KICK, "sm_abortlr <#steamid|#userid|name> - Aborts a players last request.");
	RegAdminCmd("sm_freeday", Command_GiveFreeday, ADMFLAG_KICK, "sm_freeday <#steamid|#userid|name> - Gives a player a freeday.");
	RegAdminCmd("sm_rspawn", Command_LastRequestTeleportOrigin, ADMFLAG_ROOT, "sm_rspawn <#steamid|#userid|name> <index> - Used for testing rebel spawns only.");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_SquelchManager = LibraryExists("squelch_manager");
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "squelch_manager"))
	{
		g_bLibLoaded_SquelchManager = true;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "squelch_manager"))
	{
		g_bLibLoaded_SquelchManager = false;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = false;
	}
}

public Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(GetEventInt(hEvent, "team") == GetEventInt(hEvent, "oldteam"))
		return;
	
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsClientInGame(iClient))
		return;
	
	UltJB_LR_EndLastRequest(iClient);
}

public Action:Command_AbortLastRequest(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_abortlr <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	decl String:szTargetName[MAX_TARGET_LENGTH];
	decl iTargetList[MAXPLAYERS], iTargetCount, bool:tn_is_ml;
	
	new iFlags = COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS;
	if((iTargetCount = ProcessTargetString(szTarget, iClient, iTargetList, MAXPLAYERS, iFlags, szTargetName, sizeof(szTargetName), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	decl iTarget;
	for(new i=0; i<iTargetCount; i++)
	{
		iTarget = iTargetList[i];
		
		if(iTargetCount == 1 && !HasStartedLastRequest(iTarget))
		{
			ReplyToCommand(iClient, "[SM] %N is not in a last request.", iTarget);
			return Plugin_Handled;
		}
		
		UltJB_LR_EndLastRequest(iTarget);
		
		LogAction(iClient, iTarget, "\"%L\" removed LR for \"%L\"", iClient, iTarget);
		PrintToChatAll("[SM] %N's last request has been removed.", iTarget);
	}
	
	return Plugin_Handled;
}

public Action:Command_GiveFreeday(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_freeday <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	decl String:szTargetName[MAX_TARGET_LENGTH];
	decl iTargetList[MAXPLAYERS], iTargetCount, bool:tn_is_ml;
	
	new iFlags = COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS;
	if((iTargetCount = ProcessTargetString(szTarget, iClient, iTargetList, MAXPLAYERS, iFlags, szTargetName, sizeof(szTargetName), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	decl iTarget;
	new bool:bGaveFreeday;
	for(new i=0; i<iTargetCount; i++)
	{
		iTarget = iTargetList[i];
		
		if(!InitializeAdminGivenFreeday(iClient, iTarget))
			continue;
		
		LogAction(iClient, iTarget, "\"%L\" gave freeday to \"%L\"", iClient, iTarget);
		PrintToChatAll("[SM] %N has been given a freeday.", iTarget);
		
		bGaveFreeday = true;
	}
	
	if(bGaveFreeday)
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Freeday players are automatically respawned after they select their freeday.");
	
	return Plugin_Handled;
}

StartTimer_CancelFreeday(iClient)
{
	StopTimer_CancelFreeday(iClient);
	g_hTimer_CancelFreeday[iClient] = CreateTimer(30.0, Timer_CancelFreeday, GetClientSerial(iClient));
}

StopTimer_CancelFreeday(iClient)
{
	if(g_hTimer_CancelFreeday[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_CancelFreeday[iClient]);
	g_hTimer_CancelFreeday[iClient] = INVALID_HANDLE;
}

public Action:Timer_CancelFreeday(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_CancelFreeday[iClient] = INVALID_HANDLE;
	
	if(!g_bInitializedAdminGivenFreeday[iClient])
		return;
	
	g_bInitializedAdminGivenFreeday[iClient] = false;
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You failed to select a freeday in time, removing your freeday.");
}

public Action:OnLastRequestSlots(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {purple}Last requests available this round: {red}%i", g_iAvailableLastRequestSlotCount);
	
	return Plugin_Handled;
}

public Action:OnLastRequest(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(g_bInitializedAdminGivenFreeday[iClient])
	{
		g_hMenu_LastRequest[iClient] = DisplayMenu_AdminGivenFreeday(iClient);
		return Plugin_Handled;
	}
	
	// Show the category select menu again if the client has already initialized but not yet started a last request.
	if(g_bHasInitialized[iClient] && !g_bHasStarted[iClient])
	{
		g_hMenu_LastRequest[iClient] = DisplayMenu_CategorySelect(iClient);
		return Plugin_Handled;
	}
	
	TryInitializeLastRequest(iClient);
	return Plugin_Handled;
}

TryInitializeLastRequest(iClient)
{
	if(GetClientTeam(iClient) != TEAM_PRISONERS)
	{
		PrintToChat(iClient, "[SM] You must be a prisoner to use that command.");
		return;
	}
	
	if(g_bHasInitialized[iClient])
	{
		PrintToChat(iClient, "[SM] You are already in a last request.");
		return;
	}
	
	if(UltJB_Day_IsInProgress())
	{
		PrintToChat(iClient, "[SM] You cannot use this during a custom day.");
		return;
	}
	
	if(!IsPrisonerLastRequestCandidate(iClient))
	{
		PrintToChat(iClient, "[SM] You cannot use that command yet.");
		return;
	}
	
	InitializeLastRequest(iClient);
}
/*
public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(!IsClientInFreeday(iClient))
		return Plugin_Continue;
	
	iButtons &= ~IN_USE;
	
	return Plugin_Changed;
}
*/
bool:IsClientInFreeday(iClient)
{
	if(!g_bHasStarted[iClient])
		return false;
	
	if(!(GetClientsLastRequestFlags(iClient) & LR_FLAG_FREEDAY))
		return false;
	
	return true;
}

HookBreakablesOnTakeDamage()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_breakable")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnBreakableTakeDamage);
}

public Action:OnBreakableTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fdamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3])
{
	static iOwner;
	if(1 <= iAttacker <= MaxClients)
	{
		if(iAttacker == iInflictor)
			iOwner = iAttacker;
		else
			iOwner = GetEntPropEnt(iInflictor, Prop_Data, "m_hOwnerEntity");
	}
	else
	{
		iOwner = GetEntPropEnt(iAttacker, Prop_Data, "m_hOwnerEntity");
	}
	
	if(!(1 <= iOwner <= MaxClients))
		return Plugin_Continue;
	
	if(!IsClientInFreeday(iOwner))
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public OnMapStart()
{
	AddFileToDownloadsTable(SZ_SOUND_LR_ACTIVATED);
	PrecacheSoundAny(SZ_SOUND_LR_ACTIVATED[6]);
	
	g_iRoundNumber = 0;
	g_iTeleportLRZoneID = 0;
	
	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL);
	g_iBeamWallIndex = PrecacheModel(SZ_BEAM_WALL_MATERIAL);
	
	decl i;
	for(i=0; i<sizeof(g_iLastRequestIDToIndex); i++)
		g_iLastRequestIDToIndex[i] = INVALID_LAST_REQUEST_INDEX;
	
	decl eLastRequest[LastRequest];
	for(i=0; i<GetArraySize(g_aLastRequests); i++)
	{
		GetArrayArray(g_aLastRequests, i, eLastRequest);
		
		if(eLastRequest[LR_ForwardStart] != INVALID_HANDLE)
			CloseHandle(eLastRequest[LR_ForwardStart]);
		
		if(eLastRequest[LR_ForwardEnd] != INVALID_HANDLE)
			CloseHandle(eLastRequest[LR_ForwardEnd]);
		
		if(eLastRequest[LR_ForwardOpponentLeft] != INVALID_HANDLE)
			CloseHandle(eLastRequest[LR_ForwardOpponentLeft]);
	}
	
	decl eCategory[Category];
	for(i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		if(eCategory[Category_LastRequestIDs] != INVALID_HANDLE)
			CloseHandle(eCategory[Category_LastRequestIDs]);
	}
	
	ClearArray(g_aLastRequests);
	ClearArray(g_aCategories);
	ClearArray(g_aTeleportLRRebelZone);
	
	new result;
	Call_StartForward(g_hFwd_OnRegisterReady);
	Call_Finish(result);
	
	SortLastRequestsByName();
	SortCategoriesByName();
	FindOtherCategory();
	
	HookBreakablesOnTakeDamage();
	GetAvailableLastRequestSlotCount();
	
	InitializeLastRequestTeleportOrigins();
}

FindOtherCategory()
{
	g_iOtherCategoryID = 0;
	
	decl eCategory[Category];
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		if(StrEqual(eCategory[Category_Name], "Other", false))
		{
			g_iOtherCategoryID = eCategory[Category_ID];
			return;
		}
	}
}

SortLastRequestsByName()
{
	new iArraySize = GetArraySize(g_aLastRequests);
	decl String:szName[LAST_REQUEST_MAX_NAME_LENGTH], eLastRequest[LastRequest], j, iIndex, iID, iID2;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aLastRequests, i, eLastRequest);
		strcopy(szName, sizeof(szName), eLastRequest[LR_Name]);
		iIndex = 0;
		iID = eLastRequest[LR_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aLastRequests, j, eLastRequest);
			if(strcmp(szName, eLastRequest[LR_Name], false) < 0)
				continue;
			
			iIndex = j;
			iID2 = eLastRequest[LR_ID];
			strcopy(szName, sizeof(szName), eLastRequest[LR_Name]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aLastRequests, i, iIndex);
		
		// We must swap the IDtoIndex too.
		g_iLastRequestIDToIndex[iID] = iIndex;
		g_iLastRequestIDToIndex[iID2] = i;
	}
}

SortCategoriesByName()
{
	new iArraySize = GetArraySize(g_aCategories);
	decl String:szName[LR_CATEGORY_MAX_NAME_LENGTH], eCategory[Category], j, iIndex, iID, iID2;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		strcopy(szName, sizeof(szName), eCategory[Category_Name]);
		iIndex = 0;
		iID = eCategory[Category_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aCategories, j, eCategory);
			if(strcmp(szName, eCategory[Category_Name], false) < 0)
				continue;
			
			iIndex = j;
			iID2 = eCategory[Category_ID];
			strcopy(szName, sizeof(szName), eCategory[Category_Name]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aCategories, i, iIndex);
		
		// We must swap the IDtoIndex too.
		g_iCategoryIDToIndex[iID] = iIndex;
		g_iCategoryIDToIndex[iID2] = i;
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_last_request");
	
	CreateNative("UltJB_LR_RegisterLastRequest", _UltJB_LR_RegisterLastRequest);
	CreateNative("UltJB_LR_SetLastRequestData", _UltJB_LR_SetLastRequestData);
	CreateNative("UltJB_LR_EndLastRequest", _UltJB_LR_EndLastRequest);
	//CreateNative("UltJB_LR_SetLastRequestOpponent", _UltJB_LR_SetLastRequestOpponent);
	CreateNative("UltJB_LR_GetLastRequestOpponent", _UltJB_LR_GetLastRequestOpponent);
	CreateNative("UltJB_LR_DisplayOpponentSelection", _UltJB_LR_DisplayOpponentSelection);
	CreateNative("UltJB_LR_CanLastRequest", _UltJB_LR_CanLastRequest);
	
	CreateNative("UltJB_LR_SaveClientsWeapons", _UltJB_LR_SaveClientsWeapons);
	CreateNative("UltJB_LR_RestoreClientsWeapons", _UltJB_LR_RestoreClientsWeapons);
	CreateNative("UltJB_LR_StripClientsWeapons", _UltJB_LR_StripClientsWeapons);
	
	CreateNative("UltJB_LR_SetClientsHealth", _UltJB_LR_SetClientsHealth);
	
	CreateNative("UltJB_LR_HasStartedLastRequest", _UltJB_LR_HasStartedLastRequest);
	
	CreateNative("UltJB_LR_GetRoundNumber", _UltJB_LR_GetRoundNumber);
	
	CreateNative("UltJB_LR_StartSlayTimer", _UltJB_LR_StartSlayTimer);
	CreateNative("UltJB_LR_StopSlayTimer", _UltJB_LR_StopSlayTimer);
	
	CreateNative("UltJB_LR_GetNumInitialized", _UltJB_LR_GetNumInitialized);
	CreateNative("UltJB_LR_GetNumStartedIgnore", _UltJB_LR_GetNumStartedIgnore);
	CreateNative("UltJB_LR_GetNumStartedContains", _UltJB_LR_GetNumStartedContains);
	
	CreateNative("UltJB_LR_GetLastRequestFlags", _UltJB_LR_GetLastRequestFlags);
	
	return APLRes_Success;
}

public _UltJB_LR_GetLastRequestFlags(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return -1;
	}
	
	return GetClientsLastRequestFlags(GetNativeCell(1));
}

public _UltJB_LR_GetNumStartedContains(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return -1;
	}
	
	new iMask = GetNativeCell(1);
	
	new iNumStarted;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!g_bHasStarted[iClient])
			continue;
		
		if(!(GetClientsLastRequestFlags(iClient) & iMask))
			continue;
		
		iNumStarted++;
	}
	
	return iNumStarted;
}

public _UltJB_LR_GetNumStartedIgnore(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return -1;
	}
	
	new iMask = GetNativeCell(1);
	
	new iNumStarted;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!g_bHasStarted[iClient])
			continue;
		
		if(GetClientsLastRequestFlags(iClient) & iMask)
			continue;
		
		iNumStarted++;
	}
	
	return iNumStarted;
}

public _UltJB_LR_GetNumInitialized(Handle:hPlugin, iNumParams)
{
	new iNumInitialized;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(g_bHasInitialized[iClient])
			iNumInitialized++;
	}
	
	return iNumInitialized;
}

public _UltJB_LR_StopSlayTimer(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iClient = GetNativeCell(1);
	
	decl iPrisoner;
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS: iPrisoner = iClient;
		case TEAM_GUARDS:
		{
			if(!(iPrisoner = GetGuardsLastRequestClient(iClient)))
				return;
		}
		default: return;
	}
	
	StopTimer_SlayTimer(iPrisoner);
}

public _UltJB_LR_StartSlayTimer(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	if(!HasStartedLastRequest(iClient))
		return false;
	
	if(!StartSlayTimer(iClient, GetNativeCell(2), GetNativeCell(3)))
		return false;
	
	return true;
}

public _UltJB_LR_CanLastRequest(Handle:hPlugin, iNumParams)
{
	decl iNumPrisonersAlive, iPrisonersAlive[MAXPLAYERS];
	return CanLastRequest(iNumPrisonersAlive, iPrisonersAlive);
}

bool:CanLastRequest(&iNumPrisonersAlive, iPrisonersAlive[MAXPLAYERS])
{
	if(!g_bHasRoundStarted)
		return false;
	
	if(!g_iAvailableLastRequestSlotCount)
		return false;
	
	new iClient, iNumPrisonersInFreeday, iNumGuards;
	iNumPrisonersAlive = 0;
	
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) == TEAM_GUARDS)
			iNumGuards++;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS)
			continue;
		
		if(!IsPlayerAlive(iClient))
			continue;
		
		if(g_bHasStarted[iClient] && (GetClientsLastRequestFlags(iClient) & LR_FLAG_FREEDAY))
			iNumPrisonersInFreeday++;
		
		iPrisonersAlive[iNumPrisonersAlive++] = iClient;
	}
	
	if(iNumPrisonersAlive < 1)
		return false;
	
	if(iNumGuards < 1)
		return false;
	
	new iNumPrisonersCanUseLastRequest = g_iAvailableLastRequestSlotCount + iNumPrisonersInFreeday;
	
	if(iNumPrisonersAlive > iNumPrisonersCanUseLastRequest)
		return false;
	
	return true;
}

bool:StartSlayTimer(iClient, iTimeBeforeSlay, iSlayFlags)
{
	decl iPrisoner;
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS: iPrisoner = iClient;
		case TEAM_GUARDS:
		{
			if(!(iPrisoner = GetGuardsLastRequestClient(iClient)))
				return false;
		}
		default:
			return false;
	}
	
	StopTimer_SlayTimer(iPrisoner);
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iPrisoner);
	if(!iOpponent)
		return false;
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, 0);
	WritePackCell(hPack, iPrisoner);
	WritePackCell(hPack, iTimeBeforeSlay);
	WritePackCell(hPack, iSlayFlags);
	
	ShowSlayTimerCountdown(iPrisoner, iTimeBeforeSlay, iSlayFlags);
	ShowSlayTimerCountdown(iOpponent, iTimeBeforeSlay, iSlayFlags);
	
	g_hTimer_SlayTimer[iPrisoner] = CreateTimer(1.0, Timer_CheckSlayTimer, hPack, TIMER_REPEAT);
	
	return true;
}

public Action:Timer_CheckSlayTimer(Handle:hTimer, any:hPack)
{
	ResetPack(hPack, false);
	new iTimerTick = ReadPackCell(hPack);
	new iPrisoner = ReadPackCell(hPack);
	new iTimeBeforeSlay = ReadPackCell(hPack);
	new iSlayFlags = ReadPackCell(hPack);
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iPrisoner);
	if(!iOpponent)
	{
		PrintHintText(iPrisoner, "");
		
		CloseHandle(hPack);
		g_hTimer_SlayTimer[iPrisoner] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if(iTimerTick >= iTimeBeforeSlay)
	{
		CloseHandle(hPack);
		g_hTimer_SlayTimer[iPrisoner] = INVALID_HANDLE;
		
		if(iSlayFlags & LR_SLAYTIMER_FLAG_PRISONER)
		{
			ShowSlayHint(iPrisoner);
			ForcePlayerSuicide(iPrisoner);
		}
		else
			PrintHintText(iPrisoner, "");
		
		if(iSlayFlags & LR_SLAYTIMER_FLAG_GUARD)
		{
			ShowSlayHint(iOpponent);
			ForcePlayerSuicide(iOpponent);
		}
		else
			PrintHintText(iOpponent, "");
		
		return Plugin_Stop;
	}
	
	ShowSlayTimerCountdown(iPrisoner, iTimeBeforeSlay - iTimerTick, iSlayFlags);
	ShowSlayTimerCountdown(iOpponent, iTimeBeforeSlay - iTimerTick, iSlayFlags);
	
	ResetPack(hPack, false);
	WritePackCell(hPack, iTimerTick + 1);
	
	return Plugin_Continue;
}

ShowSlayTimerCountdown(iClient, iTimeLeft, iSlayFlags)
{
	decl String:szWho[10];
	if((iSlayFlags & LR_SLAYTIMER_FLAG_PRISONER)
	&& (iSlayFlags & LR_SLAYTIMER_FLAG_GUARD))
	{
		strcopy(szWho, sizeof(szWho), "both");
	}
	else if(iSlayFlags & LR_SLAYTIMER_FLAG_PRISONER)
	{
		strcopy(szWho, sizeof(szWho), "prisoner");
	}
	else if(iSlayFlags & LR_SLAYTIMER_FLAG_GUARD)
	{
		strcopy(szWho, sizeof(szWho), "guard");
	}
	else
	{
		LogError("In the slay counter timer with invalid slay flags.");
		return;
	}
	
	PrintHintText(iClient, "<font color='#6FC41A'>Slaying <font color='#DE2626'>%s</font> <font color='#6FC41A'>in:</font>\n<font color='#DE2626'>%i</font> <font color='#6FC41A'>seconds.</font>", szWho, iTimeLeft);
}

ShowSlayHint(iClient)
{
	PrintHintText(iClient, "<font color='#6FC41A'>You were slayed\nfor taking too long.</font>");
}

StopTimer_SlayTimer(iClient)
{
	if(g_hTimer_SlayTimer[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_SlayTimer[iClient], true);
	g_hTimer_SlayTimer[iClient] = INVALID_HANDLE;
	
	if(!IsClientInGame(iClient))
		return;
	
	PrintHintText(iClient, "");
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(iOpponent)
		PrintHintText(iOpponent, "");
}

public _UltJB_LR_GetRoundNumber(Handle:hPlugin, iNumParams)
{
	return g_iRoundNumber;
}

public _UltJB_LR_HasStartedLastRequest(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	return HasStartedLastRequest(GetNativeCell(1));
}

bool:HasStartedLastRequest(iClient)
{
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS:
		{
			if(g_bHasStarted[iClient])
				return true;
		}
		case TEAM_GUARDS:
		{
			if(GetGuardsLastRequestClient(iClient))
				return true;
		}
	}
	
	return false;
}

public _UltJB_LR_SetLastRequestData(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iLastRequestID = GetNativeCell(1);
	if(g_iLastRequestIDToIndex[iLastRequestID] == INVALID_LAST_REQUEST_INDEX)
		return false;
	
	new iLength;
	if(GetNativeStringLength(2, iLength) != SP_ERROR_NONE)
		return false;
	
	iLength++;
	decl String:szCategoryName[iLength];
	GetNativeString(2, szCategoryName, iLength);
	
	AddLastRequestIDToCategory(iLastRequestID, szCategoryName);
	
	return true;
}

AddLastRequestIDToCategory(iLastRequestID, const String:szCategoryName[])
{
	decl eLastRequest[LastRequest];
	GetArrayArray(g_aLastRequests, g_iLastRequestIDToIndex[iLastRequestID], eLastRequest);
	
	// First see if we need to remove this ID from a previous category.
	new iDeletedCategoryID;
	decl eCategory[Category], iIndex;
	
	if(eLastRequest[LR_CategoryID])
	{
		GetArrayArray(g_aCategories, g_iCategoryIDToIndex[eLastRequest[LR_CategoryID]], eCategory);
		iIndex = FindValueInArray(eCategory[Category_LastRequestIDs], iLastRequestID);
		if(iIndex != -1)
			RemoveFromArray(eCategory[Category_LastRequestIDs], iIndex);
		
		// Check to see if we need to completely remove this category if there are no last requests in it.
		if(GetArraySize(eCategory[Category_LastRequestIDs]) == 0)
		{
			iDeletedCategoryID = eLastRequest[LR_CategoryID];
			CloseHandle(eCategory[Category_LastRequestIDs]);
			RemoveFromArray(g_aCategories, g_iCategoryIDToIndex[eLastRequest[LR_CategoryID]]);
		}
	}
	
	// Try to find the category index for this category name.
	new iArraySize = GetArraySize(g_aCategories);
	for(iIndex=0; iIndex<iArraySize; iIndex++)
	{
		GetArrayArray(g_aCategories, iIndex, eCategory);
		if(StrEqual(eCategory[Category_Name], szCategoryName))
			break;
	}
	
	// Create the category if needed.
	if(iIndex >= iArraySize)
	{
		// Use the deleted category ID if needed.
		if(iDeletedCategoryID)
			eCategory[Category_ID] = iDeletedCategoryID;
		else
			eCategory[Category_ID] = iArraySize + 1;
		
		strcopy(eCategory[Category_Name], LR_CATEGORY_MAX_NAME_LENGTH, szCategoryName);
		eCategory[Category_LastRequestIDs] = CreateArray();
		g_iCategoryIDToIndex[eCategory[Category_ID]] = PushArrayArray(g_aCategories, eCategory);
	}
	
	// Add the ID to the category.
	PushArrayCell(eCategory[Category_LastRequestIDs], iLastRequestID);
	//SetArrayArray(g_aCategories, g_iCategoryIDToIndex[eCategory[Category_ID]], eCategory); // We do not need to update the category array here because all we did was add to the Category_LastRequestIDs handle.
	
	// Update the last request category ID.
	eLastRequest[LR_CategoryID] = eCategory[Category_ID];
	SetArrayArray(g_aLastRequests, g_iLastRequestIDToIndex[iLastRequestID], eLastRequest);
}

public _UltJB_LR_SetClientsHealth(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iClient = GetNativeCell(1);
	new iHealthAmount = GetNativeCell(2);
	
	if(GetEntProp(iClient, Prop_Data, "m_iMaxHealth") < iHealthAmount)
		SetEntProp(iClient, Prop_Data, "m_iMaxHealth", iHealthAmount);
	
	SetEntityHealth(iClient, iHealthAmount);
}

public _UltJB_LR_EndLastRequest(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iClient = GetNativeCell(1);
	
	switch(GetClientTeam(iClient))
	{
		case TEAM_GUARDS: EndLastRequest(GetGuardsLastRequestClient(iClient));
		case TEAM_PRISONERS: EndLastRequest(iClient);
	}
}

public _UltJB_LR_GetLastRequestOpponent(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iClient = GetNativeCell(1);
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS: return GetPrisonersOpponent(iClient);
		case TEAM_GUARDS: return GetGuardsLastRequestClient(iClient);
	}
	
	return 0;
}

public _UltJB_LR_SaveClientsWeapons(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	SaveClientWeapons(GetNativeCell(1));
}

public _UltJB_LR_RestoreClientsWeapons(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	RestoreClientWeapons(GetNativeCell(1));
}

public _UltJB_LR_StripClientsWeapons(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iClient = GetNativeCell(1);
	
	if(GetNativeCell(2))
		SaveClientWeapons(iClient);
	
	StripClientWeapons(iClient);
}

public _UltJB_LR_RegisterLastRequest(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 5)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new Function:start_callback = GetNativeCell(3);
	if(start_callback == INVALID_FUNCTION)
		return 0;
	
	new iLength;
	if(GetNativeStringLength(1, iLength) != SP_ERROR_NONE)
		return 0;
	
	iLength++;
	decl String:szName[iLength];
	GetNativeString(1, szName, iLength);
	
	decl eLastRequest[LastRequest];
	new iArraySize = GetArraySize(g_aLastRequests);
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aLastRequests, i, eLastRequest);
		
		if(StrEqual(szName, eLastRequest[LR_Name], false))
		{
			LogError("Last request [%s] is already registered.", szName);
			return 0;
		}
	}
	
	if(iArraySize >= MAX_LAST_REQUESTS)
	{
		LogError("Cannot add [%s]. Please increase MAX_LAST_REQUESTS and recompile.", szName);
		return 0;
	}
	
	eLastRequest[LR_ID] = iArraySize + 1;
	eLastRequest[LR_CategoryID] = 0;
	
	eLastRequest[LR_ForwardStart] = CreateForward(ET_Ignore, Param_Cell);
	AddToForward(eLastRequest[LR_ForwardStart], hPlugin, start_callback);
	
	new Function:end_callback = GetNativeCell(4);
	if(end_callback != INVALID_FUNCTION)
	{
		eLastRequest[LR_ForwardEnd] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eLastRequest[LR_ForwardEnd], hPlugin, end_callback);
	}
	else
	{
		eLastRequest[LR_ForwardEnd] = INVALID_HANDLE;
	}
	
	new Function:opponent_left_callback = GetNativeCell(5);
	if(opponent_left_callback != INVALID_FUNCTION)
	{
		eLastRequest[LR_ForwardOpponentLeft] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(eLastRequest[LR_ForwardOpponentLeft], hPlugin, opponent_left_callback);
	}
	else
	{
		eLastRequest[LR_ForwardOpponentLeft] = INVALID_HANDLE;
	}
	
	strcopy(eLastRequest[LR_Name], LAST_REQUEST_MAX_NAME_LENGTH, szName);
	strcopy(eLastRequest[LR_Description], LAST_REQUEST_MAX_DESCRIPTION_LENGTH, "");
	eLastRequest[LR_Flags] = GetNativeCell(2);
	
	g_iLastRequestIDToIndex[eLastRequest[LR_ID]] = PushArrayArray(g_aLastRequests, eLastRequest);
	
	return eLastRequest[LR_ID];
}

public OnClientPutInServer(iClient)
{
	g_iClientsCachedSerial[iClient] = GetClientSerial(iClient);
	
	SDKHook(iClient, SDKHook_SetTransmit, OnTransmitClient);
	SDKHook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	SDKHook(iClient, SDKHook_WeaponDropPost, OnWeaponDropPost);
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
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
	
	g_bCanDealDamage[iClient] = true;
	g_bHasInvincibility[iClient] = false;

	decl iNumPrisonersAlive, iPrisonersAlive[MAXPLAYERS];
	if(CanLastRequest(iNumPrisonersAlive, iPrisonersAlive))
		return;

	new iNumLastReqests = UltJB_LR_GetNumInitialized() - UltJB_LR_GetNumStartedContains(LR_FLAG_FREEDAY);
	
	if(iNumLastReqests == 0)
		return;
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}Aborting all last requests.");
	AbortAllLastRequests();
}

UpdateEffectsIfNeeded(iClient, iOpponent)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	static iClientLastRequestFlags;
	iClientLastRequestFlags = GetClientsLastRequestFlags(iClient);
	
	// Show the client on the radar.
	if(!(iClientLastRequestFlags & LR_FLAG_NORADAR))
		SetEntProp(iClient, Prop_Send, "m_bSpotted", 1);
	
	// Show all guards on the radar.
	if(iClientLastRequestFlags & LR_FLAG_SHOW_ALL_GUARDS_ON_RADAR)
	{
		for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
		{
			if(!IsClientInGame(iPlayer) || !IsPlayerAlive(iPlayer))
				continue;
			
			if(GetClientTeam(iPlayer) != TEAM_GUARDS)
				continue;
			
			SetEntProp(iPlayer, Prop_Send, "m_bSpotted", 1);
		}
	}

	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	static iColor[4];
	if(iOpponent && fCurTime >= g_fNextEffectUpdate_Beam[iClient] && !(iClientLastRequestFlags & LR_FLAG_NOBEACON))
	{
		g_fNextEffectUpdate_Beam[iClient] = fCurTime + EFFECT_BEAM_TIME;
		
		CalculateBeamColor(iOpponent, iColor);
		TE_SetupBeamEnts(iOpponent, iClient, g_iBeamWallIndex, 0, 1, 1, EFFECT_BEAM_TIME + 0.1, 1.0, 1.0, 0, 0.0, iColor, 20);
		TE_SendToClient(iClient);
	}
	
	if(fCurTime >= g_fNextEffectUpdate_Ring[iClient] && !(iClientLastRequestFlags & LR_FLAG_NOBEACON))
	{
		g_fNextEffectUpdate_Ring[iClient] = fCurTime + EFFECT_RING_TIME + 0.2;
		
		static Float:fOrigin[3];
		GetClientAbsOrigin(iClient, fOrigin);
		fOrigin[2] += 10.0;
		
		static iTeam;
		iTeam = GetClientTeam(iClient);
		
		if(g_bHasStarted[iClient] || iTeam == TEAM_GUARDS)
		{
			if(iTeam == TEAM_PRISONERS && (iClientLastRequestFlags & LR_FLAG_FREEDAY))
			{
				// Show the last request freeday ring.
				iColor[0] = GetRandomInt(10, 255);
				iColor[1] = GetRandomInt(10, 255);
				iColor[2] = GetRandomInt(10, 255);
				iColor[3] = 200;
				TE_SetupBeamRingPoint(fOrigin, 10.0, 180.0, g_iBeamWallIndex, 0, 1, 1, EFFECT_RING_TIME, 4.3, 5.0, iColor, 0, 0);
			}
			else
			{
				// Show the regular last request ring.
				CalculateBeamColor(iClient, iColor);
				TE_SetupBeamRingPoint(fOrigin, 10.0, 180.0, g_iBeamIndex, 0, 1, 1, EFFECT_RING_TIME, 4.3, 0.0, iColor, 0, 0);
			}
		}
		else
		{
			// Show the initialized ring.
			TE_SetupBeamRingPoint(fOrigin, 180.0, 10.0, g_iBeamIndex, 0, 1, 1, EFFECT_RING_TIME, 4.3, 20.0, {255, 255, 255, 255}, 0, 0);
		}
		
		TE_SendToAll();
	}
}

TE_SetupBeamEnts(iStartEnt, iEndEnt, iModelIndex, iHaloIndex, iStartFrame, iFramerate, Float:fLife, Float:fWidth, Float:fEndWidth, iFadeLength, Float:fAmplitude, iColor[4], iSpeed)
{
	TE_Start("BeamEnts");
	TE_WriteNum("m_nModelIndex", iModelIndex);
	TE_WriteNum("m_nHaloIndex", iHaloIndex);
	TE_WriteNum("m_nStartFrame", iStartFrame);
	TE_WriteNum("m_nFrameRate", iFramerate);
	TE_WriteFloat("m_fLife", fLife);
	TE_WriteFloat("m_fWidth", fWidth);
	TE_WriteFloat("m_fEndWidth", fEndWidth);
	TE_WriteNum("m_nFadeLength", iFadeLength);
	TE_WriteFloat("m_fAmplitude", fAmplitude);
	TE_WriteNum("m_nSpeed", iSpeed);
	TE_WriteNum("r", iColor[0]);
	TE_WriteNum("g", iColor[1]);
	TE_WriteNum("b", iColor[2]);
	TE_WriteNum("a", iColor[3]);
	TE_WriteNum("m_nFlags", 0);
	TE_WriteNum("m_nStartEntity", iStartEnt);
	TE_WriteNum("m_nEndEntity", iEndEnt);
}

CalculateBeamColor(iClient, iColor[4])
{
	static iHealth, iMaxHealth, Float:fPercent;
	iHealth = GetEntProp(iClient, Prop_Data, "m_iHealth");
	iMaxHealth = GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
	
	if(iMaxHealth < 1)
		iMaxHealth = 1;
	
	fPercent = float(iHealth) / iMaxHealth;
	if(fPercent < 0.002)
		fPercent = 0.002;
	
	static iTotalDifference[4];
	iTotalDifference[0] = BEAM_COLOR_START[0] - BEAM_COLOR_END[0];
	iTotalDifference[1] = BEAM_COLOR_START[1] - BEAM_COLOR_END[1];
	iTotalDifference[2] = BEAM_COLOR_START[2] - BEAM_COLOR_END[2];
	iTotalDifference[3] = BEAM_COLOR_START[3] - BEAM_COLOR_END[3];
	
	iColor[0] = BEAM_COLOR_START[0] + RoundFloat(iTotalDifference[0] * fPercent);
	iColor[1] = BEAM_COLOR_START[1] + RoundFloat(iTotalDifference[1] * fPercent);
	iColor[2] = BEAM_COLOR_START[2] + RoundFloat(iTotalDifference[2] * fPercent);
	iColor[3] = BEAM_COLOR_START[3] + RoundFloat(iTotalDifference[3] * fPercent);
}

public OnPostThinkPost(iClient)
{
	static iTeam;
	iTeam = GetClientTeam(iClient);
	
	if(iTeam == TEAM_PRISONERS)
	{
		if(g_bHasInitialized[iClient] || g_bHasStarted[iClient])
			UpdateEffectsIfNeeded(iClient, GetPrisonersOpponent(iClient));
	}
	else if(iTeam == TEAM_GUARDS)
	{
		static iOpponent;
		iOpponent = GetGuardsLastRequestClient(iClient);
		if(iOpponent)
			UpdateEffectsIfNeeded(iClient, iOpponent);
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	TryRemoveAdminGivenFreeday(iVictim, iAttacker);
	
	if(IsPlayer(iAttacker) && !g_bCanDealDamage[iAttacker])
		return Plugin_Handled;
	
	// Don't allow the attacker to damage the victim if the attacker has initialized but not started a LR.
	if(IsPlayer(iAttacker) && g_bHasInitialized[iAttacker] && !g_bHasStarted[iAttacker])
		return Plugin_Handled;
	
	// Don't allow the attacker to damage the victim if the victim has initialized but not started a LR.
	if(g_bHasInitialized[iVictim] && !g_bHasStarted[iVictim])
		return Plugin_Handled;
	
	// Don't allow the attacker to damage the victim if the attacker is in an opponent selection menu.
	if(IsPlayer(iAttacker) && g_hMenu_OpponentSelection[iAttacker] != INVALID_HANDLE)
		return Plugin_Handled;
	
	// Don't allow the attacker to damage the victim if the victim is in an opponent selection menu.
	if(g_hMenu_OpponentSelection[iVictim] != INVALID_HANDLE)
		return Plugin_Handled;
	
	// Don't allow the victim to take damage if they have invincibility.
	if(g_bHasInvincibility[iVictim])
		return Plugin_Handled;
	
	static iOpponent, iVictimsTeam;
	iVictimsTeam = GetClientTeam(iVictim);
	
	// Don't allow anyone to attack a LR player unless they are their opponent.
	if(iVictimsTeam == TEAM_PRISONERS && g_bHasStarted[iVictim])
	{
		if(IsPlayer(iAttacker) && (GetClientsLastRequestFlags(iVictim) & LR_FLAG_FREEDAY))
			return Plugin_Handled;
		
		iOpponent = GetPrisonersOpponent(iVictim);
		if(iOpponent && iAttacker != iOpponent)
		{
			if(IsPlayer(iAttacker))
				return Plugin_Handled;
			
			// Make sure the LR player takes damage from their opponent instead of the world.
			iAttacker = iOpponent;
			iInflictor = iOpponent;
			return Plugin_Changed;
		}
	}
	else if(iVictimsTeam == TEAM_GUARDS)
	{
		iOpponent = GetGuardsLastRequestClient(iVictim);
		if(iOpponent && iAttacker != iOpponent)
		{
			if(IsPlayer(iAttacker))
				return Plugin_Handled;
			
			// Make sure the LR player takes damage from their opponent instead of the world.
			iAttacker = iOpponent;
			iInflictor = iOpponent;
			return Plugin_Changed;
		}
	}
	
	// Don't allow LR players to attack anyone but their opponent if they have one.
	if(!(1 <= iAttacker <= MaxClients))
		return Plugin_Continue;
	
	static iAttackersTeam;
	iAttackersTeam = GetClientTeam(iAttacker);
	
	if(iAttackersTeam == TEAM_PRISONERS && g_bHasStarted[iAttacker])
	{
		static iAttackersLastRequestFlags;
		iAttackersLastRequestFlags = GetClientsLastRequestFlags(iAttacker);
		
		if((iAttackersLastRequestFlags & LR_FLAG_FREEDAY) && iAttackersTeam != iVictimsTeam)
		{
			g_bCanDealDamage[iAttacker] = false; // Note: We set this for instances where a player would throw a grenade then shoot someone before the grenade explodes on someone.
			CreateTimer(0.1, Timer_KillPlayer, GetClientSerial(iAttacker), TIMER_FLAG_NO_MAPCHANGE); // Kill the attacker on a timer since killing them the same frame they do an attack animation will crash the server.
			return Plugin_Handled;
		}
		
		iOpponent = GetPrisonersOpponent(iAttacker);
		if(iOpponent)
		{
			if(iVictim != iOpponent)
				return Plugin_Handled;
			
			if(iAttackersLastRequestFlags & LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT)
				return Plugin_Handled;
		}
	}
	else if(iAttackersTeam == TEAM_GUARDS)
	{
		iOpponent = GetGuardsLastRequestClient(iAttacker);
		if(iOpponent)
		{
			if(iVictim != iOpponent)
				return Plugin_Handled;
			
			if(GetClientsLastRequestFlags(iOpponent) & LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT)
				return Plugin_Handled;
		}
	}
	
	// Continue like normal.
	return Plugin_Continue;
}

public Action:Timer_KillPlayer(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromCachedSerial(iClientSerial);
	if(!iClient || !IsPlayerAlive(iClient))
		return;
	
	ForcePlayerSuicide(iClient);
}

public OnWeaponDropPost(iClient, iWeapon)
{
	if(!IsValidEntity(iWeapon))
		return;
	
	SetWeaponOwnerSerial(iWeapon, GetClientSerial(iClient));
}

public OnWeaponEquipPost(iClient, iWeapon)
{
	if(!IsValidEntity(iWeapon))
		return;
	
	SetWeaponOwnerSerial(iWeapon, GetClientSerial(iClient));
}

public Action:OnWeaponCanUse(iClient, iWeapon)
{
	if(ShouldBlockWeaponGain(iClient, true))
		return Plugin_Handled;
	
	// Don't allow pickups of LR created weapons, but only if they don't belong to the client trying to pick it up.
	if(IsValidEntity(iWeapon))
	{
		static iOwner;
		iOwner = GetClientFromSerial(GetWeaponOwnerSerial(iWeapon));
		
		if(iOwner > 0 && iClient != iOwner && UltJB_Weapons_IsWeaponFromLR(iWeapon))
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

CleanupWeaponsFromLR(iClient)
{
	new iEnt = -1;
	decl iOwner;
	
	while((iEnt = FindEntityByClassname(iEnt, "weapon_*")) != -1)
	{
		iOwner = GetClientFromCachedSerial(GetWeaponOwnerSerial(iEnt));
		if(iOwner > 0 && iClient == iOwner && UltJB_Weapons_IsWeaponFromLR(iEnt))
			AcceptEntityInput(iEnt, "KillHierarchy");
	}
}

public Action:CS_OnBuyCommand(iClient, const String:szWeaponName[])
{
	if(ShouldBlockWeaponGain(iClient))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

bool:ShouldBlockWeaponGain(iClient, bool:bCheckPickupFlag=false)
{
	if(UltJB_Weapons_IsGettingItem(iClient))
		return false;
	
	static iTeam;
	iTeam = GetClientTeam(iClient);
	
	if(iTeam == TEAM_PRISONERS && g_bHasStarted[iClient])
	{
		if(!bCheckPickupFlag)
			return true;
		
		if(!(GetClientsLastRequestFlags(iClient) & LR_FLAG_ALLOW_WEAPON_PICKUPS))
			return true;
	}
	else if(iTeam == TEAM_GUARDS)
	{
		static iGuardsClient;
		iGuardsClient = GetGuardsLastRequestClient(iClient);
		if(iGuardsClient)
		{
			if(!bCheckPickupFlag)
				return true;
			
			if(!(GetClientsLastRequestFlags(iGuardsClient) & LR_FLAG_ALLOW_WEAPON_PICKUPS))
				return true;
		}
	}
	
	return false;
}

bool:ShouldTransmitClientToPrisoner(iClient, iPrisoner, iPrisonersTeam)
{
	if(!g_bHasStarted[iPrisoner])
		return true;
	
	if(GetClientsLastRequestFlags(iPrisoner) & LR_FLAG_FREEDAY)
		return true;
	
	if(GetClientTeam(iClient) == iPrisonersTeam)
		return false;
	
	static iOpponent;
	iOpponent = GetPrisonersOpponent(iPrisoner);
	if(!iOpponent)
		return true;
	
	if(iOpponent == iClient)
		return true;
	
	return false;
}

bool:ShouldTransmitClientToGuard(iClient, iGuard, iGuardsTeam)
{
	static iGuardsClient;
	iGuardsClient = GetGuardsLastRequestClient(iGuard);
	if(!iGuardsClient)
		return true;
	
	if(iGuardsClient == iClient)
		return true;
	
	if(GetClientTeam(iClient) == iGuardsTeam)
		return false;
	
	return false;
}

new Action:g_CachedTransmitClient[MAXPLAYERS+1][MAXPLAYERS+1];
new Float:g_fNextTransmitClient[MAXPLAYERS+1][MAXPLAYERS+1];

public Action:OnTransmitClient(iPlayerEnt, iClient)
{
	if(g_fNextTransmitClient[iClient][iPlayerEnt] > GetEngineTime())
		return g_CachedTransmitClient[iClient][iPlayerEnt];
	
	g_fNextTransmitClient[iClient][iPlayerEnt] = GetEngineTime() + GetRandomFloat(0.5, 0.7);
	
	// Warning: Sometimes iClient is greater than MaxClients. When an invalid client index is passed it seems to crash?
	if(!IsPlayer(iClient))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(iPlayerEnt == iClient)
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	static iClientsTeam;
	iClientsTeam = GetClientTeam(iClient);
	
	if(iClientsTeam <= CS_TEAM_SPECTATOR)
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(iClientsTeam == TEAM_PRISONERS && ShouldTransmitClientToPrisoner(iPlayerEnt, iClient, iClientsTeam))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(iClientsTeam == TEAM_GUARDS && ShouldTransmitClientToGuard(iPlayerEnt, iClient, iClientsTeam))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Handled;
	return Plugin_Handled;
}

public OnClientDisconnect(iClient)
{
	StopTimer_SlayClient(iClient);
	
	if(!IsClientInGame(iClient))
		return;
	
	g_iDisconnectTeam[iClient] = GetClientTeam(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	EndLastRequest(iClient);
	
	// If a prisoner left, check for last request candidates.
	if(g_iDisconnectTeam[iClient] == TEAM_PRISONERS)
	{
		InitializeLastRequestForCandidates();
	}
	// If a guard left, check to see if we need to end their opponents last request.
	else if(g_iDisconnectTeam[iClient] == TEAM_GUARDS)
	{
		// End the last request unless it's set not to end.
		new iGuardsClient = GetGuardsLastRequestClient(iClient, true);
		if(iGuardsClient)
			PrisonersGuardLeftGameCleanUp(iGuardsClient);
	}
	
	// Close the saved weapon handle if needed.
	if(g_aSavedWeapons[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_aSavedWeapons[iClient]);
		g_aSavedWeapons[iClient] = INVALID_HANDLE;
	}
}

PrisonersGuardLeftGameCleanUp(iPrisoner)
{
	if(g_iClientsLastRequestIndex[iPrisoner] == INVALID_LAST_REQUEST_INDEX || g_iClientsLastRequestIndex[iPrisoner] >= GetArraySize(g_aLastRequests))
	{
		EndLastRequest(iPrisoner);
		return;
	}
	
	new bool:bDontEndOnGuardLeave = bool:(GetClientsLastRequestFlags(iPrisoner) & LR_FLAG_DONT_END_ON_GUARD_LEAVE);
	
	decl eLastRequest[LastRequest];
	GetArrayArray(g_aLastRequests, g_iClientsLastRequestIndex[iPrisoner], eLastRequest);
	
	if(eLastRequest[LR_ForwardOpponentLeft] == INVALID_HANDLE)
	{
		if(bDontEndOnGuardLeave)
			LogError("%s is set to not end on guard leave, but there is no on guard left game callback.", eLastRequest[LR_Name]);
		
		EndLastRequest(iPrisoner);
		return;
	}
	
	new result;
	Call_StartForward(eLastRequest[LR_ForwardOpponentLeft]);
	Call_PushCell(iPrisoner);
	if(Call_Finish(result) != SP_ERROR_NONE)
		LogError("Error calling on guard left game forward.");
	
	if(!bDontEndOnGuardLeave)
		EndLastRequest(iPrisoner);
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!iClient || !IsPlayer(iClient))
		return;
	
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS:
		{
			// Make sure a last request that is initialized but not started is forced to end.
			if(g_bHasInitialized[iClient] && !g_bHasStarted[iClient])
			{
				EndLastRequest(iClient);
			}
			else if(g_bHasStarted[iClient])
			{
				// End the last request unless it's set not to end on death.
				if(!(GetClientsLastRequestFlags(iClient) & LR_FLAG_DONT_END_ON_PRISONER_DEATH))
				{
					// If it's a freeday don't end on death until their second death.
					if(GetClientsLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
					{
						if(g_bHasDiedSinceStarted[iClient])
							EndLastRequest(iClient);
						
						g_bHasDiedSinceStarted[iClient] = true;
					}
					else
						EndLastRequest(iClient);
				}
			}
			
			// Check for last request candidates.
			InitializeLastRequestForCandidates();
		}
		case TEAM_GUARDS:
		{
			// End the last request unless it's set not to end.
			new iGuardsClient = GetGuardsLastRequestClient(iClient);
			if(iGuardsClient && g_bHasStarted[iGuardsClient] && !(GetClientsLastRequestFlags(iGuardsClient) & LR_FLAG_DONT_END_ON_GUARD_DEATH))
				EndLastRequest(iGuardsClient);
		}
	}
}

public Event_RoundStart_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_iRoundNumber++;
}

public Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bHasRoundStarted = false;
	RoundCleanUp(); // Note: Make sure this is called before g_bHasRoundStarted is set to true.
	g_bHasRoundStarted = true;
	
	HookBreakablesOnTakeDamage();
	GetAvailableLastRequestSlotCount();
	
	InitializeLastRequestTeleportOrigins();
}

public Event_RoundEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bHasRoundStarted = false;
	RoundCleanUp(true);
	
	StopTimer_GetLastRequestTeleportOrigins();
}

RoundCleanUp(bool:bSkipFreedayCheck=false)
{
	decl iFlags;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		// End the last request unless it's set not to end.
		iFlags = GetClientsLastRequestFlags(iClient);
		if(g_bHasStarted[iClient] && !(iFlags & LR_FLAG_DONT_END_ON_ROUND_END))
		{
			if(iFlags & LR_FLAG_FREEDAY)
			{
				/*
				* This statement will be:
				* 1) False on first round end.
				* 2) True on first round start.
				* 3) True on second round end.
				*/
				if(!bSkipFreedayCheck || g_bHasRoundEndedSinceStarted[iClient])
				{
					if(g_bHasRoundEndedSinceStarted[iClient])
						EndLastRequest(iClient, true);
					
					g_bHasRoundEndedSinceStarted[iClient] = true;
				}
			}
			else
				EndLastRequest(iClient);
		}
		// Uninitialize last requests that have not fully started
		else if(!g_bHasStarted[iClient])
		{
			g_bHasInitialized[iClient] = false;
			g_bInitializedAdminGivenFreeday[iClient] = false;
			
			StopTimer_CancelFreeday(iClient);
			StopTimer_SelectLastRequest(iClient);
			
			if(g_hMenu_LastRequest[iClient] != INVALID_HANDLE)
				CancelMenu(g_hMenu_LastRequest[iClient]);
		}
	}
}

GetClientsLastRequestFlags(iClient)
{
	if(g_iClientsLastRequestIndex[iClient] == INVALID_LAST_REQUEST_INDEX || g_iClientsLastRequestIndex[iClient] >= GetArraySize(g_aLastRequests))
		return 0;
	
	static eLastRequest[LastRequest];
	GetArrayArray(g_aLastRequests, g_iClientsLastRequestIndex[iClient], eLastRequest);
	return eLastRequest[LR_Flags];
}

InitializeLastRequestForCandidates()
{
	if(UltJB_Day_IsInProgress())
		return;
	
	decl iNumCandidates, iCandidates[MAXPLAYERS];
	if(!GetLastRequestCandidates(iNumCandidates, iCandidates))
		return;
	
	for(new i=0; i<iNumCandidates; i++)
	{
		GetClientAbsOrigin(iCandidates[i], g_fPreLastRequestLocations[iCandidates[i]]);
		InitializeLastRequest(iCandidates[i]);
	}
}

bool:IsPrisonerLastRequestCandidate(iClient)
{
	decl iNumCandidates, iCandidates[MAXPLAYERS];
	if(!GetLastRequestCandidates(iNumCandidates, iCandidates))
		return false;
	
	for(new i=0; i<iNumCandidates; i++)
	{
		if(iClient == iCandidates[i])
			return true;
	}
	
	return false;
}

GetAvailableLastRequestSlotCount()
{
	new iNumPrisonersTotal, iNumGuardsTotal;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_PRISONERS: iNumPrisonersTotal++;
			case TEAM_GUARDS: iNumGuardsTotal++;
		}
	}
	
	if(!iNumGuardsTotal)
		return;
	
	if(iNumPrisonersTotal < 1)
	{
		g_iAvailableLastRequestSlotCount = 0;
		CPrintToChatAll("{green}[{lightred}SM{green}] {purple}Last requests available this round: {red}%i", g_iAvailableLastRequestSlotCount);
		return;
	}
	
	g_iAvailableLastRequestSlotCount = RoundFloat(iNumPrisonersTotal * (GetConVarFloat(cvar_prisoners_can_use_percent) / 100.0));
	if(g_iAvailableLastRequestSlotCount < 1)
		g_iAvailableLastRequestSlotCount = 1;
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {purple}Last requests available this round: {red}%i", g_iAvailableLastRequestSlotCount);
}

bool:GetLastRequestCandidates(&iNumCandidates, iCandidates[MAXPLAYERS])
{
	iNumCandidates = 0;
	
	decl iNumPrisonersAlive, iPrisonersAlive[MAXPLAYERS];
	if(!CanLastRequest(iNumPrisonersAlive, iPrisonersAlive))
		return false;
	
	decl iClient;
	for(new i=0; i<iNumPrisonersAlive; i++)
	{
		iClient = iPrisonersAlive[i];
		
		// Make sure the client isn't in a freeday LR and slay them if they are.
		if(g_bHasStarted[iClient] && (GetClientsLastRequestFlags(iClient) & LR_FLAG_FREEDAY))
		{
			// Slay the client on a timer because this function is called from the death event and the logic will be wrong.
			StartTimer_SlayClient(iClient);
			continue;
		}
		
		// Make sure this client hasn't already initialized a last request.
		if(g_bHasInitialized[iClient])
			continue;
		
		iCandidates[iNumCandidates++] = iClient;
	}
	
	if(!iNumCandidates)
		return false;
	
	return true;
}

StartTimer_SlayClient(iClient)
{
	StopTimer_SlayClient(iClient);
	g_hTimer_SlayClient[iClient] = CreateTimer(0.1, Timer_SlayClient, GetClientSerial(iClient));
}

StopTimer_SlayClient(iClient)
{
	if(g_hTimer_SlayClient[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_SlayClient[iClient]);
	g_hTimer_SlayClient[iClient] = INVALID_HANDLE;
}

public Action:Timer_SlayClient(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return Plugin_Continue;
	
	g_hTimer_SlayClient[iClient] = INVALID_HANDLE;
	
	if(IsPlayerAlive(iClient))
		ForcePlayerSuicide(iClient);
	
	return Plugin_Continue;
}

InitializeLastRequest(iClient)
{
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!g_bInitializedAdminGivenFreeday[iPlayer] || g_bHasStarted[iPlayer])
			continue;
		
		if(g_hMenu_LastRequest[iPlayer] != INVALID_HANDLE)
			CancelMenu(g_hMenu_LastRequest[iPlayer]);
		
		StopTimer_CancelFreeday(iClient);
		g_bInitializedAdminGivenFreeday[iPlayer] = false;
	}
	
	if(!IsFakeClient(iClient))
	{
		g_hMenu_LastRequest[iClient] = DisplayMenu_CategorySelect(iClient);
		if(g_hMenu_LastRequest[iClient] == INVALID_HANDLE)
			return;
	}
	
	g_bHasInitialized[iClient] = true;
	
	EmitSoundToAllAny(SZ_SOUND_LR_ACTIVATED[6], _, _, SNDLEVEL_NONE, _, _, 90);
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}LR initialized for {lightred}%N{olive}.", iClient);
	
	g_hTimer_SelectLastRequest[iClient] = CreateTimer(GetConVarFloat(cvar_select_last_request_time), Timer_SelectLastRequest, GetClientSerial(iClient));
	PrintToChat(iClient, "[SM] You have %i seconds to select a last request.", GetConVarInt(cvar_select_last_request_time));
	
	//TeleportToWarden(iClient);
	TeleportToLRZone(iClient);
	
	new result;
	Call_StartForward(g_hFwd_OnLastRequestInitialized);
	Call_PushCell(iClient);
	Call_Finish(result);
}

TeleportToWarden(iClient)
{
	new iTarget = UltJB_Warden_GetWarden();
	if(!iTarget || !IsPlayerAlive(iTarget))
	{
		for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
		{
			if(!IsClientInGame(iPlayer) || !IsPlayerAlive(iPlayer))
				continue;
			
			if(GetClientTeam(iPlayer) != TEAM_GUARDS)
				continue;
			
			iTarget = iPlayer;
			break;
		}
	}
	
	if(iTarget)
		TeleportNearClient(iTarget, iClient, false);
}

TeleportToLRZone(iClient)
{
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
		
	if(!g_iTeleportLRZoneID)
	{
		TeleportToWarden(iClient);
		CPrintToChatAll("{green}[{lightred}SM{green}] {red}This map is still using the old teleport system. Please let leads know so they can setup the zones.");
		return;
	}
	
	if(!ZoneTypeTeleport_TryToTeleport(g_iTeleportLRZoneID, iClient))
		return;
}

TeleportToRebelZone(iClient)
{
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(GetArraySize(g_aTeleportLRRebelZone) == 0)
	{
		GotoRandomLastRequestTeleportOrigin(iClient);
		CPrintToChatAll("{green}[{lightred}SM{green}] {red}This map is still using the old teleport system. Please let leads know so they can setup the zones.");
		return;
	}
		
	new iIndex = GetRandomInt(0, GetArraySize(g_aTeleportLRRebelZone)-1);
	new iZone = GetArrayCell(g_aTeleportLRRebelZone, iIndex);
	
	if(!ZoneTypeTeleport_TryToTeleport(iZone, iClient))
		return;
}

public ZoneManager_CreateZoneEnts_Pre()
{
	ClearArray(g_aTeleportLRRebelZone);
}

public ZoneManager_OnTypeAssigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TELEPORT_DESTINATION)
		return;
	
	decl String:szBuffer[16];
	if(!ZoneManager_GetDataString(iZoneID, 1, szBuffer, sizeof(szBuffer)))
		return;
	
	if(StrEqual(szBuffer, "lr_tele"))
	{
		g_iTeleportLRZoneID = iZoneID;
		return;
	}
	
	if(StrEqual(szBuffer, "rebel_tele"))
	{
		PushArrayCell(g_aTeleportLRRebelZone, iZoneID);
		return;
	}
}

public ZoneManager_OnTypeUnassigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TELEPORT_DESTINATION)
		return;
	
	if(iZoneID == g_iTeleportLRZoneID)
	{
		g_iTeleportLRZoneID = 0;
		return;
	}
	
	new iIndex = FindValueInArray(g_aTeleportLRRebelZone, iZoneID);
	
	if(iIndex != -1)
		RemoveFromArray(g_aTeleportLRRebelZone, iIndex);
}

public ZoneManager_OnZoneRemoved_Pre(iZoneID)
{
	if(iZoneID == g_iTeleportLRZoneID)
	{
		g_iTeleportLRZoneID = 0;
		return;
	}
		
	new iIndex = FindValueInArray(g_aTeleportLRRebelZone, iZoneID);
	
	if(iIndex != -1)
		RemoveFromArray(g_aTeleportLRRebelZone, iIndex);
}

public Action:Timer_SelectLastRequest(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
	{
		InvalidateHandleArrayIndex(hTimer, g_hTimer_SelectLastRequest, sizeof(g_hTimer_SelectLastRequest));
		return;
	}
	
	g_hTimer_SelectLastRequest[iClient] = INVALID_HANDLE;
	
	if(g_hMenu_LastRequest[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_LastRequest[iClient]);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Selecting a random last request.");
	
	StartRandomLastRequest(iClient);
}

Handle:DisplayMenu_CategorySelect(iClient, iStartNum=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_CategorySelect);
	SetMenuTitle(hMenu, "Category Select");
	
	new bool:bCategoryOtherFound;
	decl eCategory[Category], String:szInfo[6];
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		
		IntToString(eCategory[Category_ID], szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, eCategory[Category_Name]);
		
		if(StrEqual(eCategory[Category_Name], "Other", false))
			bCategoryOtherFound = true;
	}
	
	if(!bCategoryOtherFound)
	{
		decl eLastRequest[LastRequest];
		for(new i=0; i<GetArraySize(g_aLastRequests); i++)
		{
			GetArrayArray(g_aLastRequests, i, eLastRequest);
			if(eLastRequest[LR_CategoryID])
				continue;
			
			AddMenuItem(hMenu, "0", "Other");
			break;
		}
	}
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartNum, 0))
	{
		PrintToChat(iClient, "[SM] There are no last request categories.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

public MenuHandle_CategorySelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_LastRequest, sizeof(g_hMenu_LastRequest));
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(IsClientInGame(iParam1) && IsPlayerAlive(iParam1))
			PrintToChat(iParam1, "[SM] Type !lr to show the menu again.");
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!g_bHasInitialized[iParam1])
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	g_iCategoryMenuPosition[iParam1] = GetMenuSelectionPosition();
	
	g_hMenu_LastRequest[iParam1] = DisplayMenu_LastRequest(iParam1, StringToInt(szInfo));
	if(g_hMenu_LastRequest[iParam1] == INVALID_HANDLE)
		g_hMenu_LastRequest[iParam1] = DisplayMenu_CategorySelect(iParam1, GetMenuSelectionPosition());
}

Handle:DisplayMenu_LastRequest(iClient, iCategoryID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_LastRequest);
	
	if(iCategoryID)
	{
		decl String:szTitle[LR_CATEGORY_MAX_NAME_LENGTH+16], eCategory[Category];
		GetArrayArray(g_aCategories, g_iCategoryIDToIndex[iCategoryID], eCategory);
		Format(szTitle, sizeof(szTitle), "Last Request - %s", eCategory[Category_Name]);
		SetMenuTitle(hMenu, szTitle);
	}
	else
		SetMenuTitle(hMenu, "Last Request - Other");
	
	decl eLastRequest[LastRequest], String:szInfo[6], String:szDisplay[LAST_REQUEST_MAX_NAME_LENGTH], iTimeLeft;
	for(new i=0; i<GetArraySize(g_aLastRequests); i++)
	{
		GetArrayArray(g_aLastRequests, i, eLastRequest);
		if(eLastRequest[LR_CategoryID] != iCategoryID
		&& !(eLastRequest[LR_CategoryID] == 0 && iCategoryID == g_iOtherCategoryID))
			continue;
		
		IntToString(i, szInfo, sizeof(szInfo));
		
		// Don't allow players to select freeday last requests if the map is about to change.
		if(eLastRequest[LR_Flags] & LR_FLAG_FREEDAY)
		{
			if(GetMapTimeLeft(iTimeLeft) && iTimeLeft <= GetConVarInt(cvar_disable_freeday_lr_time))
			{
				Format(szDisplay, sizeof(szDisplay), "%s [Map End Soon]", eLastRequest[LR_Name]);
				AddMenuItem(hMenu, szInfo, szDisplay, ITEMDRAW_DISABLED);
				continue;
			}
		}
		
		// Check to see if this last request should only be shown to the last prisoner alive.
		if(eLastRequest[LR_Flags] & LR_FLAG_LAST_PRISONER_ONLY_CAN_USE)
		{
			if(GetNumAliveOnTeam(TEAM_PRISONERS) > 1)
			{
				Format(szDisplay, sizeof(szDisplay), "%s [Last T Only]", eLastRequest[LR_Name]);
				AddMenuItem(hMenu, szInfo, szDisplay, ITEMDRAW_DISABLED);
				continue;
			}
		}
		
		// Check to make sure there are (by default) 3 guards alive.
		if(eLastRequest[LR_Flags] & LR_FLAG_REBEL)
		{
			if(GetNumAliveOnTeam(TEAM_GUARDS) < GetConVarInt(cvar_guards_needed_for_rebel))
			{
				Format(szDisplay, sizeof(szDisplay), "%s [Need More CT]", eLastRequest[LR_Name]);
				AddMenuItem(hMenu, szInfo, szDisplay, ITEMDRAW_DISABLED);
				continue;
			}
		}
		
		AddMenuItem(hMenu, szInfo, eLastRequest[LR_Name]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no last requests in this category.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

StopTimer_SelectLastRequest(iClient)
{
	if(g_hTimer_SelectLastRequest[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hTimer_SelectLastRequest[iClient]);
		g_hTimer_SelectLastRequest[iClient] = INVALID_HANDLE;
	}
}

public MenuHandle_LastRequest(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_LastRequest, sizeof(g_hMenu_LastRequest));
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
		{
			g_hMenu_LastRequest[iParam1] = DisplayMenu_CategorySelect(iParam1, g_iCategoryMenuPosition[iParam1]);
			return;
		}
		
		if(IsClientInGame(iParam1) && IsPlayerAlive(iParam1))
			PrintToChat(iParam1, "[SM] Type !lr to show the menu again.");
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	// First stop the last request select timer.
	StopTimer_SelectLastRequest(iParam1);
	
	if(!g_bHasInitialized[iParam1])
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	StartLastRequest(iParam1, StringToInt(szInfo));
}

bool:InitializeAdminGivenFreeday(iAdmin, iTarget)
{
	if(GetClientTeam(iTarget) != TEAM_PRISONERS)
	{
		CPrintToChat(iAdmin, "{green}[{lightred}SM{green}] {red}%N is not a prisoner.", iTarget);
		return false;
	}
	
	if(g_bInitializedAdminGivenFreeday[iTarget] || g_bHasInitialized[iTarget])
	{
		CPrintToChat(iAdmin, "{green}[{lightred}SM{green}] {red}%N is already in a last request.", iTarget);
		return false;
	}
	
	// Make sure the real LR hasn't already started.
	new iNumInitialized = UltJB_LR_GetNumInitialized() - UltJB_LR_GetNumStartedContains(LR_FLAG_FREEDAY);
	if(iNumInitialized > 0)
	{
		CPrintToChat(iAdmin, "{green}[{lightred}SM{green}] {red}Cannot give freedays after LR has started.");
		return false;
	}
	
	g_hMenu_LastRequest[iTarget] = DisplayMenu_AdminGivenFreeday(iTarget);
	
	if(g_hMenu_LastRequest[iTarget] != INVALID_HANDLE)
	{
		g_bInitializedAdminGivenFreeday[iTarget] = true;
		StartTimer_CancelFreeday(iTarget);
	}
	
	return true;
}

Handle:DisplayMenu_AdminGivenFreeday(iClient)
{
	if(g_bHasStarted[iClient])
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You are already in a last request.");
		return INVALID_HANDLE;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_AdminGivenFreeday);
	SetMenuTitle(hMenu, "Select Freeday");
	
	decl eLastRequest[LastRequest], String:szInfo[6];
	for(new i=0; i<GetArraySize(g_aLastRequests); i++)
	{
		GetArrayArray(g_aLastRequests, i, eLastRequest);
		
		if(!(eLastRequest[LR_Flags] & LR_FLAG_FREEDAY))
			continue;
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, eLastRequest[LR_Name]);
	}
	
	SetMenuExitBackButton(hMenu, false);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no freeday last requests.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

public MenuHandle_AdminGivenFreeday(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_LastRequest, sizeof(g_hMenu_LastRequest));
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(IsClientInGame(iParam1) && g_bInitializedAdminGivenFreeday[iParam1])
			PrintToChat(iParam1, "[SM] Type !lr to show the menu again.");
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!g_bInitializedAdminGivenFreeday[iParam1])
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	StopTimer_CancelFreeday(iParam1);
	StartLastRequest(iParam1, StringToInt(szInfo), true);
}

StartRandomLastRequest(iClient)
{
	new iArraySize = GetArraySize(g_aLastRequests);
	if(!iArraySize)
	{
		PrintToChat(iClient, "[SM] There are no last request options.");
		EndLastRequest(iClient);
		return;
	}
	
	//new iNumPrisonersAlive = GetNumAliveOnTeam(TEAM_PRISONERS);
	//new iNumGuardsAlive = GetNumAliveOnTeam(TEAM_GUARDS);
	
	new iNumCanUse;
	decl eLastRequest[LastRequest], iRequests[MAX_LAST_REQUESTS];
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aLastRequests, i, eLastRequest);
		
		if(eLastRequest[LR_Flags] & LR_FLAG_FREEDAY)
			continue;
		
		if(eLastRequest[LR_Flags] & LR_FLAG_LAST_PRISONER_ONLY_CAN_USE)
			continue;
		
		/*
		if(eLastRequest[LR_Flags] & LR_FLAG_LAST_PRISONER_ONLY_CAN_USE)
		{
			if(iNumPrisonersAlive > 1)
				continue;
			
			if(iNumGuardsAlive < GetConVarInt(cvar_guards_needed_for_rebel))
				continue;
		}
		*/
		
		iRequests[iNumCanUse++] = i;
	}

	
	if(!iNumCanUse)
	{
		PrintToChat(iClient, "[SM] There are no last request options you can use.");
		EndLastRequest(iClient);
		return;
	}
	
	StartLastRequest(iClient, iRequests[GetRandomInt(0, iNumCanUse - 1)]);
}

StartLastRequest(iClient, iLastRequestIndex, bool:bFromFreedayAdminCommand=false)
{
	if(iLastRequestIndex == INVALID_LAST_REQUEST_INDEX
	|| iLastRequestIndex >= GetArraySize(g_aLastRequests))
	{
		PrintToChat(iClient, "[SM] There was an error loading this LR.");
		EndLastRequest(iClient);
		return;
	}
	
	g_bHasInitialized[iClient] = true;
	g_bHasStarted[iClient] = true;
	g_iClientsLastRequestIndex[iClient] = iLastRequestIndex;
	
	g_bHasDiedSinceStarted[iClient] = false;
	g_bHasRoundEndedSinceStarted[iClient] = false;
	
	decl eLastRequest[LastRequest];
	GetArrayArray(g_aLastRequests, iLastRequestIndex, eLastRequest);
	
	decl String:szCategoryName[LR_CATEGORY_MAX_NAME_LENGTH];
	if(eLastRequest[LR_CategoryID])
	{
		decl eCategory[Category];
		GetArrayArray(g_aCategories, g_iCategoryIDToIndex[eLastRequest[LR_CategoryID]], eCategory);
		strcopy(szCategoryName, sizeof(szCategoryName), eCategory[Category_Name]);
	}
	else
		strcopy(szCategoryName, sizeof(szCategoryName), "Other");
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(iPlayer == iClient || !IsClientInGame(iPlayer))
			continue;
		
		CPrintToChat(iPlayer, "{green}[{lightred}SM{green}] {lightred}%N {olive}started LR: {purple}%s {olive}- {purple}%s{olive}.", iClient, szCategoryName, eLastRequest[LR_Name]);
	}
	
	if(eLastRequest[LR_Flags] & LR_FLAG_TEMP_INVINCIBLE)
		SetTempInvincibility(iClient, 1.0);
		
	if(eLastRequest[LR_Flags] & LR_FLAG_RANDOM_TELEPORT_LOCATION)
		//GotoRandomLastRequestTeleportOrigin(iClient);
		TeleportToRebelZone(iClient);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You have chosen {purple}%s {olive}- {purple}%s{olive}.", szCategoryName, eLastRequest[LR_Name]);
	
	FillClientsHealthToDefault(iClient);
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "%N started LR: %s - %s.", iClient, szCategoryName, eLastRequest[LR_Name]);
	UltJB_Logger_LogEvent(szMessage, iClient, 0, LOGTYPE_LASTREQUEST);
	
	// Call private forward.
	Call_StartForward(eLastRequest[LR_ForwardStart]);
	Call_PushCell(iClient);
	
	new result;
	if(Call_Finish(result) != SP_ERROR_NONE)
	{
		PrintToChat(iClient, "[SM] There was an error loading this LR code 1.");
		EndLastRequest(iClient);
		return;
	}
	
	// Call global forward.
	Call_StartForward(g_hFwd_OnLastRequestStarted);
	Call_PushCell(iClient);
	Call_PushCell(eLastRequest[LR_Flags]);
	
	if(Call_Finish(result) != SP_ERROR_NONE)
	{
		PrintToChat(iClient, "[SM] There was an error loading this LR code 2.");
		EndLastRequest(iClient);
		return;
	}
	
	// Slay if it's a freeday last request.
	if(!bFromFreedayAdminCommand)
	{
		if(eLastRequest[LR_Flags] & LR_FLAG_FREEDAY)
		{
			ForcePlayerSuicide(iClient);
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}The next round will be your freeday. If you interfere with other players you will be slain!");
		}
	}
	else
	{
		if(!IsPlayerAlive(iClient))
			CS_RespawnPlayer(iClient);
		
		g_bHasDiedSinceStarted[iClient] = true;
		g_bHasRoundEndedSinceStarted[iClient] = true;
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You are in your freeday. If you interfere with other players you will be slain!");
	}
}

SetTempInvincibility(iClient, Float:fInvincibilityTime)
{
	if(fInvincibilityTime <= 0.0)
	{
		StopTimer_TempInvincibility(iClient);
		g_bHasInvincibility[iClient] = false;
		return;
	}
	
	g_bHasInvincibility[iClient] = true;
	StartTimer_TempInvincibility(iClient, Float:fInvincibilityTime);
}

StopTimer_TempInvincibility(iClient)
{
	if(g_hTimer_TempInvincibility[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_TempInvincibility[iClient]);
	g_hTimer_TempInvincibility[iClient] = INVALID_HANDLE;
}

StartTimer_TempInvincibility(iClient, Float:fInvincibilityTime)
{
	StopTimer_TempInvincibility(iClient);
	g_hTimer_TempInvincibility[iClient] = CreateTimer(fInvincibilityTime, Timer_TempInvincibility, GetClientSerial(iClient));
}

public Action:Timer_TempInvincibility(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_bHasInvincibility[iClient] = false;
	g_hTimer_TempInvincibility[iClient] = INVALID_HANDLE;
}

FillClientsHealthToDefault(iClient)
{
	g_iSavedHealth[iClient] = GetEntProp(iClient, Prop_Data, "m_iHealth");
	g_iSavedMaxHealth[iClient] = GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
	g_iSavedArmor[iClient] = GetEntProp(iClient, Prop_Send, "m_ArmorValue");
	g_iSavedHelmet[iClient] = GetEntProp(iClient, Prop_Send, "m_bHasHelmet");
	
	SetEntityHealth(iClient, 100);
	SetEntProp(iClient, Prop_Data, "m_iMaxHealth", 100);
	SetEntProp(iClient, Prop_Send, "m_ArmorValue", 0);
	SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 0);
}

RestoreClientsHealth(iClient)
{
	if(!iClient)
		return;
	
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_iSavedHealth[iClient])
	{
		SetEntProp(iClient, Prop_Data, "m_iMaxHealth", g_iSavedMaxHealth[iClient]);
		SetEntityHealth(iClient, g_iSavedHealth[iClient]);
		g_iSavedHealth[iClient] = 0;
		g_iSavedMaxHealth[iClient] = 0;
		
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_iSavedArmor[iClient]);
		SetEntProp(iClient, Prop_Send, "m_bHasHelmet", g_iSavedHelmet[iClient]);
	}
}

ResetLastRequestSquelches(iClient, iOpponent)
{
	if(!iClient || !iOpponent)
		return;
	
	if(!IsClientInGame(iClient) || !IsClientInGame(iOpponent))
		return;
	
	if(g_bLibLoaded_SquelchManager)
	{
		#if defined _squelch_manager_included
		if(GetClientTeam(iOpponent) == TEAM_GUARDS)
		{
			// If this clients opponent is a guard we don't want to accidentally mute them since clients are forced to hear guards.
			SquelchManager_ReapplyListeningState(iClient, iOpponent, true);
		}
		else
		{
			SquelchManager_ReapplyListeningState(iClient, iOpponent, false);
		}
		#endif
	}
}

EndLastRequest(iClient, bool:bEndingFromFreeday=false)
{
	StopTimer_SlayTimer(iClient);
	
	g_bHasInitialized[iClient] = false;
	g_bInitializedAdminGivenFreeday[iClient] = false;
	StopTimer_SelectLastRequest(iClient);
	
	SetTempInvincibility(iClient, 0.0);
	
	if(!g_bHasStarted[iClient])
		return;
	
	new iOpponent = GetPrisonersOpponent(iClient);
	new iOpponentCached = GetPrisonersOpponent(iClient, true);
	
	ResetLastRequestSquelches(iClient, iOpponent);
	ResetLastRequestSquelches(iOpponent, iClient);
	
	if(!bEndingFromFreeday)
	{
		CleanupWeaponsFromLR(iClient);
		CleanupWeaponsFromLR(iOpponentCached);
		
		RestoreClientsHealth(iClient);
		RestoreClientsHealth(iOpponent);
	}
	
	g_bHasStarted[iClient] = false;
	g_iLastRequestOpponentSerial[iClient] = 0;
	StopTimer_OpponentSelection(iClient, true);
	
	UltJB_Weapons_CancelWeaponSelection(iClient);
	UltJB_Effects_CancelEffectSelection(iClient);
	
	if(g_hMenu_OpponentSelection[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_OpponentSelection[iClient]);
	
	if(g_iClientsLastRequestIndex[iClient] == INVALID_LAST_REQUEST_INDEX
	|| g_iClientsLastRequestIndex[iClient] >= GetArraySize(g_aLastRequests))
	{
		g_iClientsLastRequestIndex[iClient] = INVALID_LAST_REQUEST_INDEX;
		LogError("The last request array index was invalid.");
		return;
	}
	
	decl eLastRequest[LastRequest];
	GetArrayArray(g_aLastRequests, g_iClientsLastRequestIndex[iClient], eLastRequest);
	
	if(eLastRequest[LR_ForwardEnd] != INVALID_HANDLE)
	{
		new result;
		Call_StartForward(eLastRequest[LR_ForwardEnd]);
		Call_PushCell(iClient);
		Call_PushCell(iOpponent);
		if(Call_Finish(result) != SP_ERROR_NONE)
			LogError("Error calling last request end forward.");
	}
	
	g_iClientsLastRequestIndex[iClient] = INVALID_LAST_REQUEST_INDEX;
	
	// Try to start another last request if needed.
	if(!UltJB_Day_IsInProgress() && g_bHasRoundStarted && IsClientInGame(iClient) && IsPlayerAlive(iClient) && GetNumAvailableGuardsForLR() > 0)
		TryInitializeLastRequest(iClient);
}

GetNumAvailableGuardsForLR()
{
	new iNumAvailable;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		if(UltJB_LR_GetLastRequestOpponent(iClient))
			continue;
		
		iNumAvailable++;
	}
	
	return iNumAvailable;
}

GetNumAliveOnTeam(iTeam)
{
	new iNumAlive;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != iTeam)
			continue;
		
		iNumAlive++;
	}
	
	return iNumAlive;
}

InvalidateHandleArrayIndex(const Handle:hHandleToSearchFor, Handle:hHandleArray[], iNumElements)
{
	for(new i=0; i<iNumElements; i++)
	{
		if(hHandleArray[i] != hHandleToSearchFor)
			continue;
		
		hHandleArray[i] = INVALID_HANDLE;
		return;
	}
}

public _UltJB_LR_DisplayOpponentSelection(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	if(g_hFwd_OnOpponentSelectedSuccess[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hFwd_OnOpponentSelectedSuccess[iClient]);
		g_hFwd_OnOpponentSelectedSuccess[iClient] = INVALID_HANDLE;
	}
	
	if(g_hFwd_OnOpponentSelectedFailed[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hFwd_OnOpponentSelectedFailed[iClient]);
		g_hFwd_OnOpponentSelectedFailed[iClient] = INVALID_HANDLE;
	}
	
	new Function:success_callback = GetNativeCell(2);
	if(success_callback == INVALID_FUNCTION)
		return false;
	
	g_hFwd_OnOpponentSelectedSuccess[iClient] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
	AddToForward(g_hFwd_OnOpponentSelectedSuccess[iClient], hPlugin, success_callback);
	
	new Function:failed_callback = GetNativeCell(3);
	if(failed_callback != INVALID_FUNCTION)
	{
		g_hFwd_OnOpponentSelectedFailed[iClient] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(g_hFwd_OnOpponentSelectedFailed[iClient], hPlugin, failed_callback);
	}
	
	g_hMenu_OpponentSelection[iClient] = DisplayMenu_OpponentSelection(iClient);
	if(g_hMenu_OpponentSelection[iClient] == INVALID_HANDLE)
		return false;
	
	g_hTimer_OpponentSelection[iClient] = CreateTimer(GetConVarFloat(cvar_select_opponent_time), Timer_OpponentSelection, GetClientSerial(iClient));
	//PrintToChat(iClient, "[SM] You have %i seconds to select an opponent.", GetConVarInt(cvar_select_opponent_time));
	
	return true;
}

public Action:Timer_OpponentSelection(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
	{
		InvalidateHandleArrayIndex(hTimer, g_hTimer_OpponentSelection, sizeof(g_hTimer_OpponentSelection));
		return;
	}
	
	g_hTimer_OpponentSelection[iClient] = INVALID_HANDLE;
	
	if(g_hMenu_OpponentSelection[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_OpponentSelection[iClient]);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Selecting a random opponent.");
	SelectRandomOpponent(iClient);
}

SelectRandomOpponent(iClient)
{
	new iNumOpponents;
	decl iGuardsClient, iOpponents[MAXPLAYERS];
	for(new iOpponent=1; iOpponent<=MaxClients; iOpponent++)
	{
		if(!IsClientInGame(iOpponent) || !IsPlayerAlive(iOpponent))
			continue;
		
		if(GetClientTeam(iOpponent) != TEAM_GUARDS)
			continue;
		
		// Continue if this guard is already in a LR with another prisoner.
		iGuardsClient = GetGuardsLastRequestClient(iOpponent);
		if(iGuardsClient && iGuardsClient != iClient)
			continue;
		
		iOpponents[iNumOpponents++] = iOpponent;
	}
	
	if(!iNumOpponents)
	{
		PrintToChat(iClient, "[SM] There are no opponents to select.");
		Forward_OnOpponentSelectedFailed(iClient);
		return;
	}
	
	SelectClientsOpponent(iClient, iOpponents[GetRandomInt(0, iNumOpponents - 1)]);
}

Handle:DisplayMenu_OpponentSelection(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_OpponentSelection);
	
	SetMenuTitle(hMenu, "Select your opponent");
	SetMenuExitButton(hMenu, false);
	
	decl String:szInfo[16], String:szName[33], iGuardsClient;
	for(new iOpponent=1; iOpponent<=MaxClients; iOpponent++)
	{
		if(!IsClientInGame(iOpponent) || !IsPlayerAlive(iOpponent))
			continue;
		
		if(GetClientTeam(iOpponent) != TEAM_GUARDS)
			continue;
		
		// Continue if this guard is already in a LR with another prisoner.
		iGuardsClient = GetGuardsLastRequestClient(iOpponent);
		if(iGuardsClient && iGuardsClient != iClient)
			continue;
		
		GetClientName(iOpponent, szName, sizeof(szName));
		Format(szInfo, sizeof(szInfo), "%i", GetClientSerial(iOpponent));
		AddMenuItem(hMenu, szInfo, szName);
	}
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no opponents to select.");
		Forward_OnOpponentSelectedFailed(iClient);
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

StopTimer_OpponentSelection(iClient, bool:bCallFailedForwardIfNeeded=false)
{
	if(g_hTimer_OpponentSelection[iClient] == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hTimer_OpponentSelection[iClient]);
	g_hTimer_OpponentSelection[iClient] = INVALID_HANDLE;
	
	if(bCallFailedForwardIfNeeded)
		Forward_OnOpponentSelectedFailed(iClient);
}

public MenuHandle_OpponentSelection(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_OpponentSelection, sizeof(g_hMenu_OpponentSelection));
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!g_bHasStarted[iParam1])
	{
		StopTimer_OpponentSelection(iParam1);
		return;
	}
	
	decl String:szInfo[16];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iOpponent = GetClientFromSerial(StringToInt(szInfo));
	if(!iOpponent)
	{
		PrintToChat(iParam1, "[SM] That opponent no longer exists.");
		g_hMenu_OpponentSelection[iParam1] = DisplayMenu_OpponentSelection(iParam1);
		return;
	}
	
	if(!IsPlayerAlive(iOpponent))
	{
		PrintToChat(iParam1, "[SM] %N is no longer alive.", iOpponent);
		g_hMenu_OpponentSelection[iParam1] = DisplayMenu_OpponentSelection(iParam1);
		return;
	}
	
	// Check if this guard is already in a LR with another prisoner.
	new iGuardsClient = GetGuardsLastRequestClient(iOpponent);
	if(iGuardsClient && iGuardsClient != iParam1)
	{
		PrintToChat(iParam1, "[SM] %N is already in a LR.", iOpponent);
		g_hMenu_OpponentSelection[iParam1] = DisplayMenu_OpponentSelection(iParam1);
		return;
	}
	
	StopTimer_OpponentSelection(iParam1);
	SelectClientsOpponent(iParam1, iOpponent);
}

Forward_OnOpponentSelectedFailed(iClient)
{
	if(g_hFwd_OnOpponentSelectedFailed[iClient] == INVALID_HANDLE)
	{
		// End the last request unless it's set not to end.
		if(g_bHasStarted[iClient] && !(GetClientsLastRequestFlags(iClient) & LR_FLAG_DONT_END_ON_GUARD_SELECT_FAIL))
			EndLastRequest(iClient);
		
		return;
	}
	
	new result;
	Call_StartForward(g_hFwd_OnOpponentSelectedFailed[iClient]);
	Call_PushCell(iClient);
	if(Call_Finish(result) != SP_ERROR_NONE)
		LogError("Error calling opponent selection failed.");
	
	// End the last request unless it's set not to end.
	if(g_bHasStarted[iClient] && !(GetClientsLastRequestFlags(iClient) & LR_FLAG_DONT_END_ON_GUARD_SELECT_FAIL))
		EndLastRequest(iClient);
}

SelectClientsOpponent(iClient, iOpponent)
{
	SetPrisonersOpponent(iClient, iOpponent);
	
	new result;
	Call_StartForward(g_hFwd_OnOpponentSelectedSuccess[iClient]);
	Call_PushCell(iClient);
	Call_PushCell(iOpponent);
	if(Call_Finish(result) != SP_ERROR_NONE)
	{
		LogError("Error calling opponent selection success.");
		return;
	}
	
	SetListenOverride(iClient, iOpponent, Listen_Yes);
	SetListenOverride(iOpponent, iClient, Listen_Yes);
}

SetPrisonersOpponent(iClient, iOpponent)
{
	if(!(GetClientsLastRequestFlags(iClient) & LR_FLAG_DONT_TELEPORT_TO_OPPONENT))
		TeleportNearClient(iClient, iOpponent);
	
	g_iLastRequestOpponentSerial[iClient] = GetClientSerial(iOpponent);
	
	FillClientsHealthToDefault(iOpponent);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%N {olive}is your last request opponent.", iOpponent);
	CPrintToChat(iOpponent, "{green}[{lightred}SM{green}] {lightred}%N {olive}has chosen you as their LR opponent.", iClient);
}

GetPrisonersOpponent(iClient, bool:bUseCachedSerial=false)
{
	if(bUseCachedSerial)
		return GetClientFromCachedSerial(g_iLastRequestOpponentSerial[iClient]);
	
	return GetClientFromSerial(g_iLastRequestOpponentSerial[iClient]);
}

GetClientFromCachedSerial(iSerial)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(g_iClientsCachedSerial[iClient] == iSerial)
			return iClient;
	}
	
	return 0;
}

GetGuardsLastRequestClient(iGuard, bool:bUseCachedSerial=false)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(GetPrisonersOpponent(iClient, bUseCachedSerial) == iGuard)
			return iClient;
	}
	
	return 0;
}

SaveClientWeapons(iClient)
{
	if(g_aSavedWeapons[iClient] == INVALID_HANDLE)
		g_aSavedWeapons[iClient] = CreateArray(MAX_WEAPON_CLASSNAME_LENGTH);
	else
		ClearArray(g_aSavedWeapons[iClient]);
	
	// Save the clients active weapon classname.
	new iEnt = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iEnt > 0)
		GetEntityClassname(iEnt, g_szSavedActiveWeapon[iClient], sizeof(g_szSavedActiveWeapon[]));
	else
		strcopy(g_szSavedActiveWeapon[iClient], sizeof(g_szSavedActiveWeapon[]), "");
	
	// Save all weapons and their current clip sizes.
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	decl String:szWeaponName[MAX_WEAPON_CLASSNAME_LENGTH], i;
	for(i=0; i<iArraySize; i++)
	{
		iEnt = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if(iEnt < 1)
			continue;
		
		GetEntityClassname(iEnt, szWeaponName, sizeof(szWeaponName));
		if(FindStringInArray(g_aSavedWeapons[iClient], szWeaponName) == -1)
			PushArrayString(g_aSavedWeapons[iClient], szWeaponName);
		
		g_iSavedWeaponAmmoClip[iClient][i] = GetEntProp(iEnt, Prop_Send, "m_iClip1");
		
		// Save reserve ammo per weapon.
		g_iSavedWeaponAmmoReservePrimary[iClient][i] = GetEntProp(iEnt, Prop_Send, "m_iPrimaryReserveAmmoCount");
		g_iSavedWeaponAmmoReserveSecondary[iClient][i] = GetEntProp(iEnt, Prop_Send, "m_iSecondaryReserveAmmoCount");
	}
	
	// Save reserve ammo global.
	iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_iAmmo");
	
	for(i=0; i<iArraySize; i++)
		g_iSavedWeaponAmmoReserveGlobal[iClient][i] = GetEntProp(iClient, Prop_Send, "m_iAmmo", _, i);
}

RestoreClientWeapons(iClient)
{
	if(g_aSavedWeapons[iClient] == INVALID_HANDLE)
		return;
	
	// First strip any of the clients current weapons.
	StripClientWeapons(iClient);
	
	// Restore the clients weapon entities.
	decl String:szWeaponName[MAX_WEAPON_CLASSNAME_LENGTH], i;
	for(i=0; i<GetArraySize(g_aSavedWeapons[iClient]); i++)
	{
		GetArrayString(g_aSavedWeapons[iClient], i, szWeaponName, sizeof(szWeaponName));
		UltJB_Weapons_GivePlayerItem(iClient, szWeaponName);
	}
	
	// Restore all weapons clip sizes.
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	decl iEnt;
	for(i=0; i<iArraySize; i++)
	{
		iEnt = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if(iEnt < 1)
			continue;
		
		SetEntProp(iEnt, Prop_Send, "m_iClip1", g_iSavedWeaponAmmoClip[iClient][i]);
		
		GetEntityClassname(iEnt, szWeaponName, sizeof(szWeaponName));
		if(StrEqual(g_szSavedActiveWeapon[iClient], szWeaponName))
		{
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iEnt);
			//SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", 0.0); // Don't do this because if they had a grenade it will instantly throw it.
		}
		
		// Restore reserve ammo per weapon.
		SetEntProp(iEnt, Prop_Send, "m_iPrimaryReserveAmmoCount", g_iSavedWeaponAmmoReservePrimary[iClient][i]);
		SetEntProp(iEnt, Prop_Send, "m_iSecondaryReserveAmmoCount", g_iSavedWeaponAmmoReserveSecondary[iClient][i]);
	}
	
	// Restore reserve ammo.
	iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_iAmmo");
	
	for(i=0; i<iArraySize; i++)
		SetEntProp(iClient, Prop_Send, "m_iAmmo", g_iSavedWeaponAmmoReserveGlobal[iClient][i], _, i);
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
		
		UltJB_Settings_StripWeaponFromOwner(iWeapon);
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, i);
	}
}

public Action:OnWeaponDrop(iClient, const String:szCommand[], iArgCount)
{
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS:
		{
			if(g_bHasStarted[iClient] && !(GetClientsLastRequestFlags(iClient) & LR_FLAG_ALLOW_WEAPON_DROPS))
				return Plugin_Handled;
		}
		case TEAM_GUARDS:
		{
			new iGuardsClient = GetGuardsLastRequestClient(iClient);
			if(iGuardsClient && g_bHasStarted[iGuardsClient] && !(GetClientsLastRequestFlags(iGuardsClient) & LR_FLAG_ALLOW_WEAPON_DROPS))
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

bool:TeleportNearClient(iClient, iTarget, bool:bChangeClientsView=true)
{
	decl Float:fStartOrigin[3];
	GetClientAbsOrigin(iClient, fStartOrigin);
	fStartOrigin[2] += 30.0; // Move the start z origin up a bit to account for hills in the ground.
	
	new bool:bDidTeleport, iNumHops = 1;
	for(new iDirType=0; iDirType<NUM_DIR_TYPES; iDirType++)
	{
		if(TryTeleportSpot(iClient, iTarget, fStartOrigin, HULL_STANDING_MINS_CSGO, HULL_STANDING_MAXS_CSGO, iDirType, iNumHops, bChangeClientsView))
		{
			bDidTeleport = true;
			break;
		}
		
		if((iDirType == NUM_DIR_TYPES-1) && iNumHops < MAX_TELEPORT_HOPS)
		{
			iDirType = -1;
			iNumHops++;
		}
	}
	
	if(!bDidTeleport)
	{
		GetClientAbsOrigin(iClient, fStartOrigin);
		TeleportEntity(iTarget, fStartOrigin, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
		return false;
	}
	
	return true;
}

bool:TryTeleportSpot(iClient, iTarget, const Float:fStartOrigin[3], const Float:fMins[3], const Float:fMaxs[3], iDirType, iNumHops, bool:bChangeClientsView)
{
	static Float:fNewOrigin[3], Float:fMove;
	fNewOrigin[0] = fStartOrigin[0];
	fNewOrigin[1] = fStartOrigin[1];
	fNewOrigin[2] = fStartOrigin[2];
	
	switch(iDirType)
	{
		case DIR_X_POS:
		{
			fMove = FloatAbs(fMaxs[0] * iNumHops) + FloatAbs(fMins[0] * iNumHops) + (5 * iNumHops);
			
			if(fMaxs[0] < 0)
				fMove = -fMove;
			
			fNewOrigin[0] = fStartOrigin[0] + fMove;
		}
		case DIR_Y_POS:
		{
			fMove = FloatAbs(fMaxs[1] * iNumHops) + FloatAbs(fMins[1] * iNumHops) + (5 * iNumHops);
			
			if(fMaxs[1] < 0)
				fMove = -fMove;
			
			fNewOrigin[1] = fStartOrigin[1] + fMove;
		}
		case DIR_BOTH_POS:
		{
			// X
			fMove = FloatAbs(fMaxs[0] * iNumHops) + FloatAbs(fMins[0] * iNumHops) + (5 * iNumHops);
			
			if(fMaxs[0] < 0)
				fMove = -fMove;
			
			fNewOrigin[0] = fStartOrigin[0] + fMove;
			
			// Y
			fMove = FloatAbs(fMaxs[1] * iNumHops) + FloatAbs(fMins[1] * iNumHops) + (5 * iNumHops);
			
			if(fMaxs[1] < 0)
				fMove = -fMove;
			
			fNewOrigin[1] = fStartOrigin[1] + fMove;
		}
		
		case DIR_X_NEG:
		{
			fMove = FloatAbs(fMaxs[0] * iNumHops) + FloatAbs(fMins[0] * iNumHops) + (5 * iNumHops);
			
			if(fMins[0] < 0)
				fMove = -fMove;
			
			fNewOrigin[0] = fStartOrigin[0] + fMove;
		}
		case DIR_Y_NEG:
		{
			fMove = FloatAbs(fMaxs[1] * iNumHops) + FloatAbs(fMins[1] * iNumHops) + (5 * iNumHops);
			
			if(fMins[1] < 0)
				fMove = -fMove;
			
			fNewOrigin[1] = fStartOrigin[1] + fMove;
		}
		case DIR_BOTH_NEG:
		{
			// X
			fMove = FloatAbs(fMaxs[0] * iNumHops) + FloatAbs(fMins[0] * iNumHops) + (5 * iNumHops);
			
			if(fMins[0] < 0)
				fMove = -fMove;
			
			fNewOrigin[0] = fStartOrigin[0] + fMove;
			
			// Y
			fMove = FloatAbs(fMaxs[1] * iNumHops) + FloatAbs(fMins[1] * iNumHops) + (5 * iNumHops);
			
			if(fMins[1] < 0)
				fMove = -fMove;
			
			fNewOrigin[1] = fStartOrigin[1] + fMove;
		}
		
		case DIR_BOTH_X_POS:
		{
			// X
			fMove = FloatAbs(fMaxs[0] * iNumHops) + FloatAbs(fMins[0] * iNumHops) + (5 * iNumHops);
			
			if(fMaxs[0] < 0)
				fMove = -fMove;
			
			fNewOrigin[0] = fStartOrigin[0] + fMove;
			
			// Y
			fMove = FloatAbs(fMaxs[1] * iNumHops) + FloatAbs(fMins[1] * iNumHops) + (5 * iNumHops);
			
			if(fMins[1] < 0)
				fMove = -fMove;
			
			fNewOrigin[1] = fStartOrigin[1] + fMove;
		}
		case DIR_BOTH_X_NEG:
		{
			// X
			fMove = FloatAbs(fMaxs[0] * iNumHops) + FloatAbs(fMins[0] * iNumHops) + (5 * iNumHops);
			
			if(fMins[0] < 0)
				fMove = -fMove;
			
			fNewOrigin[0] = fStartOrigin[0] + fMove;
			
			// Y
			fMove = FloatAbs(fMaxs[1] * iNumHops) + FloatAbs(fMins[1] * iNumHops) + (5 * iNumHops);
			
			if(fMaxs[1] < 0)
				fMove = -fMove;
			
			fNewOrigin[1] = fStartOrigin[1] + fMove;
		}
	}
	
	TR_TraceHull(fNewOrigin, fNewOrigin, fMins, fMaxs, MASK_PLAYERSOLID);
	if(TR_DidHit())
		return false;
	
	TR_TraceRayFilter(fStartOrigin, fNewOrigin, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_DontHitPlayers);
	new Float:fFraction = TR_GetFraction();
	if(fFraction < 1.0)
		return false;
	
	decl Float:fVector[3];
	AddVectors(fNewOrigin, Float:{0.0, 0.0, -60.0}, fVector);
	TR_TraceRayFilter(fNewOrigin, fVector, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_DontHitPlayers);
	fFraction = TR_GetFraction();
	if(fFraction >= 1.0)
		return false;
	
	MakeVectorFromPoints(fStartOrigin, fNewOrigin, fVector);
	GetVectorAngles(fVector, fVector);
	fVector[0] = 0.0;
	fVector[2] = 0.0;
	TeleportEntity(iTarget, fNewOrigin, fVector, Float:{0.0, 0.0, 0.0});
	
	if(bChangeClientsView)
	{
		MakeVectorFromPoints(fNewOrigin, fStartOrigin, fVector);
		GetVectorAngles(fVector, fVector);
		fVector[0] = 0.0;
		fVector[2] = 0.0;
		TeleportEntity(iClient, NULL_VECTOR, fVector, Float:{0.0, 0.0, 0.0});
	}
	
	return true;
}

public bool:TraceFilter_DontHitPlayers(iEnt, iContentsMask)
{
	if(iEnt < 1 || iEnt >= MaxClients)
		return true;
	
	return false;
}

public OnEntityCreated(iEnt, const String:szClassName[])
{
	if(!StrEqual(szClassName, "game_player_equip"))
		return;
	
	SDKHook(iEnt, SDKHook_Use, OnUseGamePlayerEquip);
	SDKHook(iEnt, SDKHook_Touch, OnTouchGamePlayerEquip);
}

public Action:OnTouchGamePlayerEquip(iEnt, iOther)
{
	if(!IsPlayer(iOther))
		return Plugin_Continue;
	
	if(!HasStartedLastRequest(iOther))
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Action:OnUseGamePlayerEquip(iEnt, iActivator, iCaller, UseType:type, Float:fValue)
{
	if(!IsPlayer(iActivator))
		return Plugin_Continue;
	
	if(!HasStartedLastRequest(iActivator))
		return Plugin_Continue;
	
	return Plugin_Handled;
}

TryRemoveAdminGivenFreeday(iVictim, iAttacker)
{
	if(!IsPlayer(iVictim) || !IsPlayer(iAttacker))
		return;

	if(GetClientTeam(iVictim) == GetClientTeam(iAttacker))
		return;
	
	// Remove the victims freeday if they take damage before they select a day from the menu.
	if(g_bInitializedAdminGivenFreeday[iVictim] && !g_bHasStarted[iVictim])
	{
		g_bInitializedAdminGivenFreeday[iVictim] = false;
		StopTimer_CancelFreeday(iVictim);
		
		CPrintToChat(iVictim, "{green}[{lightred}SM{green}] {olive}Removing your freeday for being damaged by {blue}%N{olive}.", iAttacker);
	}
	
	// Remove the attackers freeday if they give damage before they select a day from the menu.
	if(g_bInitializedAdminGivenFreeday[iAttacker] && !g_bHasStarted[iAttacker])
	{
		g_bInitializedAdminGivenFreeday[iAttacker] = false;
		StopTimer_CancelFreeday(iAttacker);
		
		CPrintToChat(iAttacker, "{green}[{lightred}SM{green}] {olive}Removing your freeday for damaging {blue}%N{olive}.", iVictim);
	}
}

bool:GotoRandomLastRequestTeleportOrigin(iClient)
{
	if(!g_iLastRequestTeleportOriginsTotal)
		return false;
	
	TeleportEntity(iClient, g_fLastRequestTeleportOrigins[GetRandomInt(0, g_iLastRequestTeleportOriginsTotal-1)], NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	
	return true;
}

public Action:Command_LastRequestTeleportOrigin(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgCount < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_rspawn <#steamid|#userid|name> <index>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, false, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(iArgCount < 2)
	{
		ReplyToCommand(iClient, "[SM] No index provided. Choosing one of %i random locations.", g_iLastRequestTeleportOriginsTotal);
		GotoRandomLastRequestTeleportOrigin(iTarget);
		return Plugin_Handled;
	}
	
	new String:szIndex[4];
	GetCmdArg(2, szIndex, sizeof(szIndex));
	new iIndex = StringToInt(szIndex);
	
	if(iIndex < 0)
	{
		ReplyToCommand(iClient, "[SM] Please provide a proper index to use.");
		return Plugin_Handled;
	}
	
	if(iIndex >= g_iLastRequestTeleportOriginsTotal)
	{
		ReplyToCommand(iClient, "[SM] Index %i invalid. Only index 0-%i are valid.", iIndex, g_iLastRequestTeleportOriginsTotal-1);
		return Plugin_Handled;
	}
	
	TeleportEntity(iTarget, g_fLastRequestTeleportOrigins[iIndex], NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	PrintToChatAll("[SM] Teleported %N to location %d.", iTarget, iIndex);
	
	return Plugin_Handled;
}

InitializeLastRequestTeleportOrigins()
{
	g_iLastRequestTeleportOriginsTotal = 0;
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
	{
		AddLastRequestTeleportOrigin(iEnt);
		break;
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
	{
		AddLastRequestTeleportOrigin(iEnt);
		break;
	}
	
	/*new iTeleportsFound;
	new String:szName[64];
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
	
		if(strcmp(szName, "tw_cru") != -1 || strcmp(szName, "tw_ent1") != -1 || strcmp(szName, "tw_ent2") != -1 || strcmp(szName, "knife_arena_spleef_teleport_destination3") != -1)
			continue;
		
		AddLastRequestTeleportOrigin(iEnt);
		
		iTeleportsFound++;
		if(iTeleportsFound >= 5)
			break;
	}*/
	
	LastRequestTeleportOrigins_ResetHealth();
	StartTimer_PreGetLastRequestTeleportOrigins();
}

AddLastRequestTeleportOrigin(iEnt)
{
	decl Float:fOrigin[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
	
	decl iIndex;
	if(g_iLastRequestTeleportOriginsTotal < sizeof(g_fLastRequestTeleportOrigins))
		iIndex = g_iLastRequestTeleportOriginsTotal++;
	else
		iIndex = GetRandomInt(2, sizeof(g_fLastRequestTeleportOrigins)-1);
	
	g_fLastRequestTeleportOrigins[iIndex] = fOrigin;
}

public Action:Timer_GetLastRequestTeleportOrigins(Handle:hTimer)
{
	decl iHealth;
	new iNumGuardOriginsAdded, iNumPrisonerOriginsAdded;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!IsPlayerAlive(iClient))
			continue;
		
		// Continue if the players health went down since the last time we checked.
		iHealth = GetClientHealth(iClient);
		if(iHealth < g_iLastRequestTeleportOrigins_OldHealth[iClient])
		{
			g_iLastRequestTeleportOrigins_OldHealth[iClient] = iHealth;
			continue;
		}
		
		g_iLastRequestTeleportOrigins_OldHealth[iClient] = iHealth;
		
		// Continue if the player isn't on the ground.
		if(GetEntProp(iClient, Prop_Send, "m_hGroundEntity") == -1)
			continue;
		
		// Continue if the player is ducking.
		if((GetEntityFlags(iClient) & FL_DUCKING) || (GetClientButtons(iClient) & IN_DUCK))
			continue;
		
		// Continue if the player doesn't have the default movetype.
		if(GetEntityMoveType(iClient) != MOVETYPE_WALK)
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_GUARDS:
			{
				// Continue if we already got enough guard origins this iteration.
				if(iNumGuardOriginsAdded > 2)
					continue;
				
				// 1 in 2 chance to add this players origin this iteration.
				if(GetRandomInt(0, 1) != 1)
					continue;
				
				iNumGuardOriginsAdded++;
			}
			case TEAM_PRISONERS:
			{
				// Continue if we already got enough prisoner origins this iteration.
				if(iNumPrisonerOriginsAdded > 1)
					continue;
				
				// 1 in 6 chance to add this players origin this iteration.
				if(GetRandomInt(0, 5) != 5)
					continue;
				
				iNumPrisonerOriginsAdded++;
			}
			default:
				continue;
		}
		
		AddLastRequestTeleportOrigin(iClient);
	}
}

LastRequestTeleportOrigins_ResetHealth()
{
	for(new i=1; i<=MaxClients; i++)
		g_iLastRequestTeleportOrigins_OldHealth[i] = 100;
}

StopTimer_GetLastRequestTeleportOrigins()
{
	if(g_hTimer_LastRequestTeleportOrigins != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_LastRequestTeleportOrigins);
		g_hTimer_LastRequestTeleportOrigins = INVALID_HANDLE;
	}
}

StartTimer_GetLastRequestTeleportOrigins()
{
	StopTimer_GetLastRequestTeleportOrigins();
	g_hTimer_LastRequestTeleportOrigins = CreateTimer(20.0, Timer_GetLastRequestTeleportOrigins, _, TIMER_REPEAT);
}

StartTimer_PreGetLastRequestTeleportOrigins()
{
	StopTimer_GetLastRequestTeleportOrigins();
	g_hTimer_LastRequestTeleportOrigins = CreateTimer(60.0, Timer_PreGetLastRequestTeleportOrigins);
}

public Action:Timer_PreGetLastRequestTeleportOrigins(Handle:hTimer)
{
	StartTimer_GetLastRequestTeleportOrigins();
}

AbortAllLastRequests()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
			
		if(!g_bHasInitialized[iClient])
			continue;
		
		if(GetClientsLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
			continue;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS)
			continue;
		
		EndLastRequest(iClient);
		TeleportEntity(iClient, g_fPreLastRequestLocations[iClient], NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	}
}
