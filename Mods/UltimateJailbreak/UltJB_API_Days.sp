#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <hls_color_chat>
#include <sdktools_functions>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_days"
#include "Includes/ultjb_warden"
#include "Includes/ultjb_cell_doors"
#include "Includes/ultjb_settings"
#include "Includes/ultjb_logger"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Days API";
new const String:PLUGIN_VERSION[] = "1.9";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The days API for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define ROUND_DAY_ENABLED	-1
#define INVALID_DAY_INDEX	-1
#define MAX_DAYS	64

new Handle:g_aDays;
new g_iDayIDToIndex[MAX_DAYS+1];
enum _:Day
{
	Day_ID,
	String:Day_Name[DAY_MAX_NAME_LENGTH],
	Handle:Day_ForwardStart,
	Handle:Day_ForwardEnd,
	Handle:Day_ForwardFreezeEnd,
	Day_Flags,
	DayType:Day_Type,
	Day_FreezeTime
};

new Handle:g_hFwd_OnRegisterReady;
new Handle:g_hFwd_OnStart;
new Handle:g_hFwd_OnWardayStart;
new Handle:g_hFwd_OnWardayFreezeEnd;

new g_iCurrentDayID;
new DayType:g_iCurrentDayType;

new g_iWardenCountForRound;
new Float:g_fWardenSelectedTime;

new Handle:cvar_select_time;
new Handle:cvar_warday_freeze_time;
new g_iTimerCountdown;

new g_iWardayFreezeTime;
new Handle:g_hTimer_WardayFreeze;

new g_iRoundsAfterDay[DayType];
new Handle:g_aUsedSteamIDs;

new bool:g_bArePrisonersFrozen;

new Handle:g_hFwd_OnSpawnPost;
new g_iSpawnedTick[MAXPLAYERS+1];

new bool:g_bInDaysSpawnPostForward[MAXPLAYERS+1];
new bool:g_bIsDayAllowed[MAX_DAYS+1] = {true, ...};

public OnPluginStart()
{
	CreateConVar("ultjb_api_days_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_select_time = CreateConVar("ultjb_day_select_time", "15", "The number of seconds a day can be selected after the warden is selected.", _, true, 1.0);
	cvar_warday_freeze_time = CreateConVar("ultjb_warday_freeze_time", "30", "The number of seconds the prisoners should be frozen before warday starts.", _, true, 1.0);
	
	g_hFwd_OnSpawnPost = CreateGlobalForward("UltJB_Day_OnSpawnPost", ET_Ignore, Param_Cell);
	
	g_aDays = CreateArray(Day);
	g_hFwd_OnRegisterReady = CreateGlobalForward("UltJB_Day_OnRegisterReady", ET_Ignore);
	g_hFwd_OnStart = CreateGlobalForward("UltJB_Day_OnStart", ET_Ignore, Param_Cell, Param_Cell);
	g_hFwd_OnWardayStart = CreateGlobalForward("UltJB_Day_OnWardayStart", ET_Ignore, Param_Cell);
	g_hFwd_OnWardayFreezeEnd = CreateGlobalForward("UltJB_Day_OnWardayFreezeEnd", ET_Ignore);
	
	g_aUsedSteamIDs = CreateArray(48);
	
	HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("cs_match_end_restart", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_PostNoCopy);
	
	//RegConsoleCmd("sm_d", OnDaysMenu, "Opens the days menu."); - removed because of donator
	RegConsoleCmd("sm_day", OnDaysMenu, "Opens the days menu.");
	RegAdminCmd("sm_de", OnDaysEdit, ADMFLAG_UNBAN, "Edits the day configuration for the current map.");
	RegAdminCmd("sm_daysedit", OnDaysEdit, ADMFLAG_UNBAN, "Edits the day configuration for the current map.");
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_Spawn, OnSpawn);
	SDKHook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public OnEntityCreated(iEnt, const String:szClassName[])
{
	if(strlen(szClassName) < 8)
		return;
	
	if(StrContains(szClassName, "weapon_") == -1)
		return;
	
	if(StrEqual(szClassName[7], "hegrenade")
	|| StrEqual(szClassName[7], "smokegrenade")
	|| StrEqual(szClassName[7], "incgrenade")
	|| StrEqual(szClassName[7], "decoy")
	|| StrEqual(szClassName[7], "molotov")
	|| StrEqual(szClassName[7], "tagrenade")
	|| StrEqual(szClassName[7], "flashbang")
	|| StrEqual(szClassName[7], "apon_manager"))	// Catches game_weapon_manager
		return;
	
	SDKHook(iEnt, SDKHook_ReloadPost, OnWeaponReload);
}

public OnWeaponReload(iWeapon, bool:bSuccess)
{
	if(!bSuccess)
		return;
	
	if(!IsDayInProgress())
		return;
	
	decl eDay[Day];
	GetArrayArray(g_aDays, g_iDayIDToIndex[g_iCurrentDayID], eDay);
	
	if(!(eDay[Day_Flags] & DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO))
		return;
	
	new iClient = GetEntPropEnt(iWeapon, Prop_Data, "m_hOwnerEntity");
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(GetClientTeam(iClient) != TEAM_GUARDS)
		return;
	
	GivePlayerAmmo(iClient, 500, GetEntProp(iWeapon, Prop_Data, "m_iPrimaryAmmoType"), true);
}

public OnSpawn(iClient)
{
	g_iSpawnedTick[iClient] = GetGameTickCount();
}

public UltJB_Settings_OnSpawnPost(iClient)
{
	if(g_iCurrentDayType == DAY_TYPE_WARDAY)
	{
		switch(GetClientTeam(iClient))
		{
			case TEAM_PRISONERS:
			{
				decl eDay[Day];
				GetArrayArray(g_aDays, g_iDayIDToIndex[g_iCurrentDayID], eDay);
				
				if(!(eDay[Day_Flags] & DAY_FLAG_KEEP_PRISONERS_WEAPONS))
					UltJB_LR_StripClientsWeapons(iClient);
				
				if(g_hTimer_WardayFreeze != INVALID_HANDLE)
					SetEntityMoveType(iClient, MOVETYPE_NONE);
			}
			case TEAM_GUARDS:
			{
				decl eDay[Day];
				GetArrayArray(g_aDays, g_iDayIDToIndex[g_iCurrentDayID], eDay);
				
				if(eDay[Day_Flags] & DAY_FLAG_STRIP_GUARDS_WEAPONS)
					UltJB_LR_StripClientsWeapons(iClient);
			}
		}
	}
	
	if(g_iCurrentDayType != DAY_TYPE_NONE)
		Forward_OnSpawnPost(iClient);
}

Forward_OnSpawnPost(iClient)
{
	g_bInDaysSpawnPostForward[iClient] = true;
	
	new result;
	Call_StartForward(g_hFwd_OnSpawnPost);
	Call_PushCell(iClient);
	Call_Finish(result);
	
	g_bInDaysSpawnPostForward[iClient] = false;
}

public Action:OnWeaponCanUse(iClient, iWeapon)
{
	if(ShouldBlockWeaponGain(iClient, iWeapon))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:CS_OnBuyCommand(iClient, const String:szWeaponName[])
{
	if(ShouldBlockWeaponGain(iClient, 0))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

bool:ShouldBlockWeaponGain(iClient, iWeapon)
{
	if(!IsDayInProgress())
		return false;
	
	if(!g_bInDaysSpawnPostForward[iClient] && iWeapon > 0 && g_iSpawnedTick[iClient] == GetGameTickCount())
	{
		UltJB_Settings_StripWeaponFromOwner(iWeapon);
		return true;
	}
	
	if(g_bArePrisonersFrozen && GetClientTeam(iClient) == TEAM_PRISONERS)
		return true;
	
	decl eDay[Day];
	GetArrayArray(g_aDays, g_iDayIDToIndex[g_iCurrentDayID], eDay);
	
	if(eDay[Day_Flags] & DAY_FLAG_ALLOW_WEAPON_PICKUPS)
		return false;
	
	return true;
}

public Action:CS_OnCSWeaponDrop(iClient, iWeapon)
{
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	if(!IsDayInProgress())
		return Plugin_Continue;
	
	decl eDay[Day];
	GetArrayArray(g_aDays, g_iDayIDToIndex[g_iCurrentDayID], eDay);
	
	if(eDay[Day_Flags] & DAY_FLAG_ALLOW_WEAPON_DROPS)
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_iWardenCountForRound = 0;
	
	for(new i=0; i<sizeof(g_iRoundsAfterDay); i++)
	{
		if(g_iRoundsAfterDay[i] == ROUND_DAY_ENABLED)
			continue;
		
		g_iRoundsAfterDay[i]++;
		if(g_iRoundsAfterDay[i] >= 3)
			g_iRoundsAfterDay[i] = ROUND_DAY_ENABLED;
	}
}

public Event_PlayerDeath_Post(Handle:event, const String:name[], bool:bDontBroadcast)
{
	decl iClient, iFreeDayClients[MAXPLAYERS];
	new iNumPrisoners, iNumFreedays;
	
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS)
			continue;
		
		if(UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY)
			iFreeDayClients[iNumFreedays++] = iClient;
		
		iNumPrisoners++;
	}
	
	// Return if no prisoner is in a freeday or if there are still prisoners remaining outside of a freeday.
	if(!iNumFreedays || iNumFreedays < iNumPrisoners)
		return;
	
	PrintToChatAll("All remaining prisoners are in a freeday.. slaying them.");
	
	for(new i=0; i<iNumFreedays; i++)
		ForcePlayerSuicide(iFreeDayClients[i]);
}

public Action:OnDaysMenu(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iClient != UltJB_Warden_GetWarden())
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You must be the warden to use the days menu.");
		PrintToConsole(iClient, "[SM] You must be the warden to use the days menu.");
		return Plugin_Handled;
	}
	
	if(IsDayInProgress())
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}A day is already in progress.");
		PrintToConsole(iClient, "[SM] A day is already in progress.");
		return Plugin_Handled;
	}
	
	if(HasSelectTimeExpired())
	{
		ShowSelectTimeExpiredMessage(iClient);
		return Plugin_Handled;
	}
	
	DisplayMenu_DayTypeSelect(iClient);
	
	return Plugin_Handled;
}

ShowSelectTimeExpiredMessage(iClient)
{
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}The time to select a day has expired.");
	PrintToConsole(iClient, "[SM] The time to select a day has expired.");
}

public UltJB_Warden_OnSelected(iClient)
{
	g_iWardenCountForRound++;
	if(g_iWardenCountForRound != 1)
		return;
	
	g_fWardenSelectedTime = GetGameTime();
}

bool:HasSelectTimeExpired()
{
	if(!UltJB_Warden_GetWarden())
		return true;
	
	if(GetGameTime() > (g_fWardenSelectedTime + GetConVarFloat(cvar_select_time)))
		return true;
	
	return false;
}

public Event_RoundEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	EndDay();
}

public OnMapEnd()
{
	EndDay();
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_days");
	
	CreateNative("UltJB_Day_RegisterDay", _UltJB_Day_RegisterDay);
	CreateNative("UltJB_Day_IsInProgress", _UltJB_Day_IsInProgress);
	CreateNative("UltJB_Day_SetFreezeTime", _UltJB_Day_SetFreezeTime);
	CreateNative("UltJB_Day_GetCurrentDayType", _UltJB_Day_GetCurrentDayType);
	
	return APLRes_Success;
}

public OnMapStart()
{
	ClearArray(g_aUsedSteamIDs);
	
	g_iWardenCountForRound = 0;
	
	decl i;
	for(i=0; i<sizeof(g_iRoundsAfterDay); i++)
		g_iRoundsAfterDay[i] = ROUND_DAY_ENABLED;
	
	for(i=0; i<sizeof(g_iDayIDToIndex); i++)
		g_iDayIDToIndex[i] = INVALID_DAY_INDEX;
	
	decl eDay[Day];
	for(i=0; i<GetArraySize(g_aDays); i++)
	{
		GetArrayArray(g_aDays, i, eDay);
		
		if(eDay[Day_ForwardStart] != INVALID_HANDLE)
			CloseHandle(eDay[Day_ForwardStart]);
		
		if(eDay[Day_ForwardEnd] != INVALID_HANDLE)
			CloseHandle(eDay[Day_ForwardEnd]);
		
		if(eDay[Day_ForwardFreezeEnd] != INVALID_HANDLE)
			CloseHandle(eDay[Day_ForwardFreezeEnd]);
	}
	
	ClearArray(g_aDays);
	
	new result;
	Call_StartForward(g_hFwd_OnRegisterReady);
	Call_Finish(result);
	
	LoadDayConfig();
	SortDaysByName();
}

SortDaysByName()
{
	new iArraySize = GetArraySize(g_aDays);
	decl String:szName[DAY_MAX_NAME_LENGTH], eDay[Day], j, iIndex, iID, iID2;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aDays, i, eDay);
		strcopy(szName, sizeof(szName), eDay[Day_Name]);
		iIndex = 0;
		iID = eDay[Day_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aDays, j, eDay);
			if(strcmp(szName, eDay[Day_Name], false) < 0)
				continue;
			
			iIndex = j;
			iID2 = eDay[Day_ID];
			strcopy(szName, sizeof(szName), eDay[Day_Name]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aDays, i, iIndex);
		
		// We must swap the IDtoIndex too.
		g_iDayIDToIndex[iID] = iIndex;
		g_iDayIDToIndex[iID2] = i;
	}
}

public _UltJB_Day_SetFreezeTime(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iDayID = GetNativeCell(1);
	new iTime = GetNativeCell(2);
	
	decl eDay[Day];
	for(new i=0; i<GetArraySize(g_aDays); i++)
	{
		GetArrayArray(g_aDays, i, eDay);
		
		if(eDay[Day_ID] != iDayID)
			continue;
		
		eDay[Day_FreezeTime] = iTime;
		SetArrayArray(g_aDays, i, eDay);
		
		return true;
	}
	
	return false;
}

public _UltJB_Day_IsInProgress(Handle:hPlugin, iNumParams)
{
	if(IsDayInProgress())
		return true;
	
	return false;
}

public _UltJB_Day_GetCurrentDayType(Handle:hPlugin, iNumParams)
{
	return _:g_iCurrentDayType;
}

public _UltJB_Day_RegisterDay(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 6)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new Function:start_callback = GetNativeCell(4);
	if(start_callback == INVALID_FUNCTION)
		return 0;
	
	new iLength;
	if(GetNativeStringLength(1, iLength) != SP_ERROR_NONE)
		return 0;
	
	iLength++;
	decl String:szName[iLength];
	GetNativeString(1, szName, iLength);
	
	decl eDay[Day];
	new iArraySize = GetArraySize(g_aDays);
	
	new DayType:iDayType = GetNativeCell(2);
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aDays, i, eDay);
		
		if(eDay[Day_Type] != iDayType)
			continue;
		
		if(StrEqual(szName, eDay[Day_Name], false))
		{
			LogError("Day [%s] is already registered.", szName);
			return 0;
		}
	}
	
	if(iArraySize >= MAX_DAYS)
	{
		LogError("Cannot add [%s]. Please increase MAX_DAYS and recompile.", szName);
		return 0;
	}
	
	eDay[Day_ID] = iArraySize + 1;
	
	eDay[Day_ForwardStart] = CreateForward(ET_Ignore, Param_Cell);
	AddToForward(eDay[Day_ForwardStart], hPlugin, start_callback);
	
	new Function:end_callback = GetNativeCell(5);
	if(end_callback != INVALID_FUNCTION)
	{
		eDay[Day_ForwardEnd] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(eDay[Day_ForwardEnd], hPlugin, end_callback);
	}
	else
	{
		eDay[Day_ForwardEnd] = INVALID_HANDLE;
	}
	
	new Function:freeze_end_callback = GetNativeCell(6);
	if(freeze_end_callback != INVALID_FUNCTION)
	{
		eDay[Day_ForwardFreezeEnd] = CreateForward(ET_Ignore);
		AddToForward(eDay[Day_ForwardFreezeEnd], hPlugin, freeze_end_callback);
	}
	else
	{
		eDay[Day_ForwardFreezeEnd] = INVALID_HANDLE;
	}
	
	strcopy(eDay[Day_Name], DAY_MAX_NAME_LENGTH, szName);
	eDay[Day_Type] = iDayType;
	eDay[Day_Flags] = GetNativeCell(3);
	eDay[Day_FreezeTime] = GetConVarInt(cvar_warday_freeze_time);
	
	g_iDayIDToIndex[eDay[Day_ID]] = PushArrayArray(g_aDays, eDay);
	
	return eDay[Day_ID];
}

bool:StartDay(iClient, iDayID)
{
	if(IsDayInProgress())
	{
		PrintToChat(iClient, "[SM] A day is already in progress.");
		return false;
	}
	
	if(g_iDayIDToIndex[iDayID] == INVALID_DAY_INDEX)
		return false;
	
	decl eDay[Day];
	GetArrayArray(g_aDays, g_iDayIDToIndex[iDayID], eDay);
	
	Call_StartForward(eDay[Day_ForwardStart]);
	Call_PushCell(iClient);
	
	new result;
	if(Call_Finish(result) != SP_ERROR_NONE)
	{
		PrintToChat(iClient, "[SM] There was an error loading this day.");
		return false;
	}
	
	g_iCurrentDayID = iDayID;
	g_iCurrentDayType = eDay[Day_Type];
	g_iRoundsAfterDay[eDay[Day_Type]] = 0;
	
	Forward_OnStart(iClient, eDay[Day_Type]);
	
	decl String:szDayType[8];
	switch(eDay[Day_Type])
	{
		case DAY_TYPE_FREEDAY:
		{
			strcopy(szDayType, sizeof(szDayType), "Freeday");
		}
		case DAY_TYPE_WARDAY:
		{
			strcopy(szDayType, sizeof(szDayType), "Warday");
			InitWarday(iClient, eDay[Day_Flags], eDay[Day_FreezeTime], eDay[Day_ForwardFreezeEnd]);
		}
	}
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}has started {lightred}%s {olive}- {lightred}%s{olive}.", iClient, szDayType, eDay[Day_Name]);
	
	SetDayUsed(iClient);
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "%N has started %s - %s.", iClient, szDayType, eDay[Day_Name]);
	UltJB_Logger_LogEvent(szMessage, iClient, 0, LOGTYPE_ANY);
	
	return true;
}

InitWarday(iClient, iFlags, iFreezeTime, Handle:hForwardFreezeEnd)
{
	if(!(iFlags & DAY_FLAG_KEEP_PRISONERS_WEAPONS))
		StripTeamsWeapons(TEAM_PRISONERS);
	
	if(iFlags & DAY_FLAG_STRIP_GUARDS_WEAPONS)
		StripTeamsWeapons(TEAM_GUARDS);
	
	if(!UltJB_CellDoors_HaveOpened())
		UltJB_CellDoors_ForceOpen();
	
	g_iWardayFreezeTime = iFreezeTime;
	
	if(iFreezeTime > 0)
	{
		FreezeAllPrisoners();
		
		Forward_OnWardayStart(iClient);
		StartTimer_WardayFreeze();
	}
	else
	{
		Forward_OnWardayStart(iClient);
		Forward_FreezeEnd(hForwardFreezeEnd);
	}
}

StripTeamsWeapons(iTeam)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != iTeam)
			continue;
		
		UltJB_LR_StripClientsWeapons(iClient);
	}
}

StartTimer_WardayFreeze()
{
	g_iTimerCountdown = 0;
	ShowCountdown_Unfreeze();
	
	StopTimer_WardayFreeze();
	g_hTimer_WardayFreeze = CreateTimer(1.0, Timer_WardayFreeze, _, TIMER_REPEAT);
}

ShowCountdown_Unfreeze()
{
	PrintHintTextToAll("<font color='#6FC41A'>Unfreezing prisoners in:</font>\n<font color='#DE2626'>%i</font> <font color='#6FC41A'>seconds.</font>", g_iWardayFreezeTime - g_iTimerCountdown);
}

StopTimer_WardayFreeze()
{
	if(g_hTimer_WardayFreeze == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_WardayFreeze);
	g_hTimer_WardayFreeze = INVALID_HANDLE;
}

public Action:Timer_WardayFreeze(Handle:hTimer)
{
	g_iTimerCountdown++;
	if(g_iTimerCountdown < g_iWardayFreezeTime)
	{
		ShowCountdown_Unfreeze();
		return Plugin_Continue;
	}
	
	g_hTimer_WardayFreeze = INVALID_HANDLE;
	
	FreezeAllPrisoners(false);
	
	if(!IsDayInProgress())
		return Plugin_Stop;
	
	if(g_iDayIDToIndex[g_iCurrentDayID] == INVALID_DAY_INDEX)
		return Plugin_Stop;
	
	decl eDay[Day];
	GetArrayArray(g_aDays, g_iDayIDToIndex[g_iCurrentDayID], eDay);
	Forward_FreezeEnd(eDay[Day_ForwardFreezeEnd]);
	
	PrintHintTextToAll("<font color='#6FC41A'>Prisoners have been unfrozen!</font>");
	
	return Plugin_Stop;
}

Forward_FreezeEnd(Handle:hForwardFreezeEnd)
{
	new result;
	if(hForwardFreezeEnd != INVALID_HANDLE)
	{
		Call_StartForward(hForwardFreezeEnd);
		Call_Finish(result);
	}
	
	Call_StartForward(g_hFwd_OnWardayFreezeEnd);
	Call_Finish(result);
}

Forward_OnStart(iClient, DayType:iDayType)
{
	new result;
	Call_StartForward(g_hFwd_OnStart);
	Call_PushCell(iClient);
	Call_PushCell(iDayType);
	Call_Finish(result);
}

Forward_OnWardayStart(iClient)
{
	new result;
	Call_StartForward(g_hFwd_OnWardayStart);
	Call_PushCell(iClient);
	Call_Finish(result);
}

FreezeAllPrisoners(bool:bFreeze=true)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(bFreeze)
		{
			if(GetClientTeam(iClient) != TEAM_PRISONERS)
				continue;
		}
		
		SetEntityMoveType(iClient, bFreeze ? MOVETYPE_NONE : MOVETYPE_WALK);
	}
	
	g_bArePrisonersFrozen = bFreeze;
}

bool:EndDay(iClient=0)
{
	if(!IsDayInProgress())
		return false;
	
	if(g_iDayIDToIndex[g_iCurrentDayID] == INVALID_DAY_INDEX)
		return false;
	
	FreezeAllPrisoners(false);
	StopTimer_WardayFreeze();
	
	decl eDay[Day];
	GetArrayArray(g_aDays, g_iDayIDToIndex[g_iCurrentDayID], eDay);
	
	if(eDay[Day_ForwardEnd] != INVALID_HANDLE)
	{
		Call_StartForward(eDay[Day_ForwardEnd]);
		Call_PushCell(iClient);
		
		new result;
		if(Call_Finish(result) != SP_ERROR_NONE)
		{
			LogError("There was an error ending day [%s].", eDay[Day_Name]);
			PrintToChatAll("[SM] There was an error ending day [%s].", eDay[Day_Name]);
			return false;
		}
	}
	
	g_iCurrentDayID = 0;
	g_iCurrentDayType = DAY_TYPE_NONE;
	
	return true;
}

bool:IsDayInProgress()
{
	if(g_iCurrentDayID > 0)
		return true;
	
	return false;
}

DisplayMenu_DayTypeSelect(iClient)
{
	if(UltJB_Warden_GetWarden() != iClient)
		return;
	
	if(HasUsedDay(iClient) && false)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You already used your day for this map.");
		PrintToConsole(iClient, "[SM] You already used your day for this map.");
		
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_DayTypeSelect);
	SetMenuTitle(hMenu, "Custom Day");
	
	decl String:szInfo[6];
	
	// Freeday check.
	IntToString(_:DAY_TYPE_FREEDAY, szInfo, sizeof(szInfo));
	if(CanSelectFreeday(iClient))
	{
		AddMenuItem(hMenu, szInfo, "Freeday");
	}
	else
	{
		AddMenuItem(hMenu, szInfo, "Freeday [Wait a round]", ITEMDRAW_DISABLED);
	}
	
	// Warday check.
	IntToString(_:DAY_TYPE_WARDAY, szInfo, sizeof(szInfo));
	if(CanSelectWarday(iClient))
	{
		AddMenuItem(hMenu, szInfo, "Warday");
	}
	else
	{
		AddMenuItem(hMenu, szInfo, "Warday [Wait a round]", ITEMDRAW_DISABLED);
	}
	
	if(!DisplayMenu(hMenu, iClient, 0))
		PrintToChat(iClient, "[SM] There are no day types.");
}

bool:HasUsedDay(iClient)
{
	decl String:szAuthID[48];
	if(!GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID), false))
		return true;
	
	if(FindStringInArray(g_aUsedSteamIDs, szAuthID) != -1)
		return true;
	
	return false;
}

SetDayUsed(iClient)
{
	decl String:szAuthID[48];
	if(!GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID), false))
		return;
	
	if(FindStringInArray(g_aUsedSteamIDs, szAuthID) != -1)
		return;
	
	PushArrayString(g_aUsedSteamIDs, szAuthID);
}

bool:CanSelectFreeday(iClient)
{
	if(UltJB_Warden_GetClientWardenCount(iClient) < 2)
		return false;
	
	if(g_iRoundsAfterDay[DAY_TYPE_FREEDAY] != ROUND_DAY_ENABLED || g_iRoundsAfterDay[DAY_TYPE_WARDAY] == 1)
		return false;
	
	return true;
}

bool:CanSelectWarday(iClient)
{
	if(UltJB_Warden_GetClientWardenCount(iClient) < 2)
		return false;
	
	if(g_iRoundsAfterDay[DAY_TYPE_WARDAY] != ROUND_DAY_ENABLED || g_iRoundsAfterDay[DAY_TYPE_FREEDAY] == 1)
		return false;
	
	return true;
}

public MenuHandle_DayTypeSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(UltJB_Warden_GetWarden() != iParam1)
		return;
	
	if(HasSelectTimeExpired())
	{
		ShowSelectTimeExpiredMessage(iParam1);
		return;
	}
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	DisplayMenu_DaySelect(iParam1, DayType:StringToInt(szInfo));
}

DisplayMenu_DaySelect(iClient, DayType:iDayType)
{
	if(UltJB_Warden_GetWarden() != iClient)
		return;
	
	new Handle:hMenu = CreateMenu(MenuHandle_DaySelect);
	
	switch(iDayType)
	{
		case DAY_TYPE_WARDAY:
		{
			if(!UltJB_CellDoors_DoExist())
			{
				PrintToChat(iClient, "[SM] Cannot select warday because the cell doors are not set.");
				DisplayMenu_DayTypeSelect(iClient);
				return;
			}
			
			SetMenuTitle(hMenu, "Wardays");
		}
		case DAY_TYPE_FREEDAY: SetMenuTitle(hMenu, "Freedays");
		default: return;
	}
	
	decl eDay[Day], String:szInfo[6];
	for(new i=0; i<GetArraySize(g_aDays); i++)
	{
		GetArrayArray(g_aDays, i, eDay);
		
		if(eDay[Day_Type] != iDayType)
			continue;
		
		IntToString(eDay[Day_ID], szInfo, sizeof(szInfo));
		
		if(g_bIsDayAllowed[eDay[Day_ID]])
			AddMenuItem(hMenu, szInfo, eDay[Day_Name]);
		else
			AddMenuItem(hMenu, szInfo, eDay[Day_Name], ITEMDRAW_DISABLED);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no days.");
		DisplayMenu_DayTypeSelect(iClient);
	}
}

public MenuHandle_DaySelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_DayTypeSelect(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(UltJB_Warden_GetWarden() != iParam1)
		return;
	
	if(HasSelectTimeExpired())
	{
		ShowSelectTimeExpiredMessage(iParam1);
		return;
	}
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	StartDay(iParam1, StringToInt(szInfo));
}

DisplayMenu_EditTypeSelect(iClient)
{
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditTypeSelect);
	SetMenuTitle(hMenu, "Custom Day");
	
	decl String:szInfo[6];
	
	IntToString(_:DAY_TYPE_FREEDAY, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Freeday");
	
	
	IntToString(_:DAY_TYPE_WARDAY, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Warday");
	
	if(!DisplayMenu(hMenu, iClient, 0))
		PrintToChat(iClient, "[SM] There are no day types.");

}

DisplayMenu_EditDay(iClient, DayType:iDayType)
{
	new Handle:hMenu = CreateMenu(MenuHandle_DayEdit);
	
	switch(iDayType)
	{
		case DAY_TYPE_WARDAY: SetMenuTitle(hMenu, "Wardays Allowed");
		case DAY_TYPE_FREEDAY: SetMenuTitle(hMenu, "Freedays Allowed");
		default: return;
	}
	
	decl eDay[Day], String:szInfo[6], String:szLine[512];
	for(new i=0; i<GetArraySize(g_aDays); i++)
	{
		GetArrayArray(g_aDays, i, eDay);
		
		if(eDay[Day_Type] != iDayType)
			continue;
		
		IntToString(eDay[Day_ID], szInfo, sizeof(szInfo));
		Format(szLine, sizeof(szLine), "[%s] %s", (g_bIsDayAllowed[eDay[Day_ID]] ? "Y" : "N"), eDay[Day_Name]);
		AddMenuItem(hMenu, szInfo, szLine);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no days.");
		DisplayMenu_EditTypeSelect(iClient);
	}
}

public Action:OnDaysEdit(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_EditTypeSelect(iClient);
	
	return Plugin_Handled;
}

public MenuHandle_EditTypeSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(!(1 <= iParam1 <= MaxClients))
		return;
		
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	DisplayMenu_EditDay(iParam1, DayType:StringToInt(szInfo));
}

public MenuHandle_DayEdit(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(!(1 <= iParam1 <= MaxClients))
		return;

	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditTypeSelect(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	decl eDay[Day];
	GetArrayArray(g_aDays, g_iDayIDToIndex[StringToInt(szInfo)], eDay);
	
	g_bIsDayAllowed[eDay[Day_ID]] = !g_bIsDayAllowed[eDay[Day_ID]];
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "[SM] %s %s.", eDay[Day_Name], (g_bIsDayAllowed[eDay[Day_ID]] ? "enabled" : "disabled"));
	PrintToChat(iParam1, szMessage);
	SaveDayConfig(iParam1);
	DisplayMenu_EditDay(iParam1, eDay[Day_Type]);
}

SaveDayConfig(iClient)
{	
	decl String:szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/day_configs");
	if(!DirExists(szPath) && !CreateDirectory(szPath, 775))
	{
		PrintToChat(iClient, "[SM] Error creating day_configs directory.");
		return;
	}
	
	decl String:szBuffer[512];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	Format(szPath, sizeof(szPath), "%s/%s.txt", szPath, szBuffer);
	
	new Handle:fp = OpenFile(szPath, "w");
	if(fp == INVALID_HANDLE)
	{
		PrintToChat(iClient, "[SM] Error creating save file.");
		return;
	}
	
	decl eDay[Day];
	
	for(new i=0; i<=MAX_DAYS; i++)
	{
		if(g_bIsDayAllowed[i])
			continue;
		
		GetArrayArray(g_aDays, g_iDayIDToIndex[i], eDay);
		
		Format(szBuffer, sizeof(szBuffer), "%d-%s", eDay[Day_Type], eDay[Day_Name]);
		WriteFileLine(fp, szBuffer);
	}
	
	CloseHandle(fp);
	
	PrintToChat(iClient, "[SM] Day configs have been saved.");
}

LoadDayConfig()
{
	for(new iDay=0;iDay<=MAX_DAYS;iDay++)
		g_bIsDayAllowed[iDay] = true;

	new Handle:aNames = CreateArray(DAY_MAX_NAME_LENGTH);
	
	decl String:szBuffer[PLATFORM_MAX_PATH];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/day_configs/%s.txt", szBuffer);
	
	new Handle:fp = OpenFile(szBuffer, "r");
	if(fp == INVALID_HANDLE)
		return;
	
	new iTypes[MAX_DAYS+1], String:szType[2];
	
	while(!IsEndOfFile(fp))
	{
		if(!ReadFileLine(fp, szBuffer, sizeof(szBuffer)))
			continue;
		
		TrimString(szBuffer);
		
		if(strlen(szBuffer) < 1)
			continue;
		
		szType[0] = szBuffer[0];
		PrintToServer("szBuffer (%s), szType (%s), iType (%d)", szBuffer, szType, StringToInt(szType));
		iTypes[GetArraySize(aNames)+1] = StringToInt(szType);
		PrintToServer("Stored name %s", szBuffer[2]);
		PushArrayString(aNames, szBuffer[2]);
	}
	
	CloseHandle(fp);
	
	decl eDay[Day];
	new iMatch;
	
	for(new i=0;i<GetArraySize(g_aDays); i++)
	{
		GetArrayArray(g_aDays, i, eDay);
		PrintToServer("Checking day %s", eDay[Day_Name]);
			
		iMatch = FindStringInArray(aNames, eDay[Day_Name]);
		
		if(iMatch == -1)
			continue;
		
		PrintToServer("Comparing %d to %d", _:eDay[Day_Type], iTypes[iMatch]);
	
		if(_:eDay[Day_Type] != iTypes[iMatch])
			continue;
		
		PrintToServer("--- Disabling day");
		g_bIsDayAllowed[eDay[Day_ID]] = false;
	}
	
}

GetLowercaseMapName(String:szMapName[], iMaxLength)
{
	GetCurrentMap(szMapName, iMaxLength);
	StringToLower(szMapName);
}

StringToLower(String:szString[])
{
	for(new i=0; i<strlen(szString); i++)
		szString[i] = CharToLower(szString[i]);
}