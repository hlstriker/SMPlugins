#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <emitsoundany>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <hls_color_chat>
#include "Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Ultimate Jailbreak: Last Guard";
new const String:PLUGIN_VERSION[] = "1.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The last guard plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_guards_needed;
new Handle:cvar_hp_per_prisoner;
new Handle:cvar_hp_per_kill;
new Handle:cvar_damage_wait;
new Handle:cvar_damage_interval;
new Handle:cvar_damage_amount;

new g_iLastGuardSerial;
new Handle:g_hTimer_LastGuard;

new g_iCounter_DamageWait;
new g_iCounter_DamageInterval;

new bool:g_bCanLastGuard;

new const String:PLAYER_MODEL_LAST_GUARD[] = "models/player/ctm_sas_variante.mdl";

new const BEACON_COLOR_GUARD[] = {0, 178, 255, 200};
new const BEACON_COLOR_PRISONER[] = {255, 77, 0, 200};

#define BEACON_DISTANCE_MIN		550.0
#define BEACON_DISTANCE_MAX		2200.0
#define BEACON_DELAY_MIN	0.3
#define BEACON_DELAY_MAX	1.0
#define BEACON_PITCH_MIN 91.0
#define BEACON_PITCH_MAX 120.0

new Float:g_fNextBeaconTime[MAXPLAYERS+1];

new const String:SZ_BEACON_SOUND[] = "sound/buttons/blip1.wav";
new const String:SZ_BEACON_MATERIAL[] = "materials/sprites/laserbeam.vmt";
new g_iBeaconIndex;

new Handle:g_hFwd_OnActivated_Pre;
new Handle:g_hFwd_OnActivated_Post;


public OnPluginStart()
{
	CreateConVar("ultjb_last_guard_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_guards_needed = CreateConVar("ultjb_lastguard_guards_needed", "3", "The number of guards needed for last guard to activate.", _, true, 1.0);
	cvar_hp_per_prisoner = CreateConVar("ultjb_lastguard_hp_per_prisoner", "17", "The amount of health to give the last guard per each alive prisoner.", _, true, 0.0);
	cvar_hp_per_kill = CreateConVar("ultjb_lastguard_hp_per_kill", "5", "The amount of health to give the last guard per each prisoner kill.", _, true, 0.0);
	cvar_damage_wait = CreateConVar("ultjb_lastguard_damage_wait", "20", "The amount of time to wait before damaging the last guard if they haven't attacked a prisoner.", _, true, 0.0);
	cvar_damage_interval = CreateConVar("ultjb_lastguard_damage_interval", "3", "The amount of time to wait between each damage tick.", _, true, 1.0);
	cvar_damage_amount = CreateConVar("ultjb_lastguard_damage_amount", "10", "The amount of damage to give each tick.", _, true, 1.0);
	
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	HookEvent("player_team", EventPlayerTeam_Post, EventHookMode_Post);
	HookEvent("player_hurt", EventPlayerHurt_Post, EventHookMode_Post);
	
	HookEvent("round_end", EventRoundRestart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_start", EventRoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("cs_match_end_restart", EventRoundRestart_Post, EventHookMode_PostNoCopy);
	
	g_hFwd_OnActivated_Pre = CreateGlobalForward("UltJB_LastGuard_OnActivated_Pre", ET_Ignore, Param_Cell);
	g_hFwd_OnActivated_Post = CreateGlobalForward("UltJB_LastGuard_OnActivated_Post", ET_Ignore, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_last_guard");
	
	CreateNative("UltJB_LastGuard_GetLastGuard", _UltJB_LastGuard_GetLastGuard);
	CreateNative("UltJB_LastGuard_GetNumNeeded", _UltJB_LastGuard_GetNumNeeded);
	
	return APLRes_Success;
}

public _UltJB_LastGuard_GetNumNeeded(Handle:hPlugin, iNumParams)
{
	return GetConVarInt(cvar_guards_needed);
}

public _UltJB_LastGuard_GetLastGuard(Handle:hPlugin, iNumParams)
{
	return GetClientFromSerial(g_iLastGuardSerial);
}

public OnMapStart()
{
	PrecacheSoundAny(SZ_BEACON_SOUND[6], true);
	
	PrecacheModel(PLAYER_MODEL_LAST_GUARD, true);
	g_iBeaconIndex = PrecacheModel(SZ_BEACON_MATERIAL, true);
}

public EventRoundRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RemoveLastGuard();
}

public EventRoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RemoveLastGuard();
	
	new iNumGuardsTotal;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		iNumGuardsTotal++;
	}
	
	if(!iNumGuardsTotal)
		return;
	
	if(iNumGuardsTotal >= GetConVarInt(cvar_guards_needed))
	{
		g_bCanLastGuard = true;
		CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%i {olive}guard%s alive at round start. {yellow}Last Guard: {green}active{olive}!", iNumGuardsTotal, (iNumGuardsTotal == 1) ? "" : "s");
	}
	else
	{
		g_bCanLastGuard = false;
		CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%i {olive}guard%s alive at round start. {yellow}Last Guard: {red}disabled{olive}.", iNumGuardsTotal, (iNumGuardsTotal == 1) ? "" : "s");
	}
}

public EventPlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(GetEventInt(hEvent, "team") != TEAM_GUARDS)
		TryRemoveLastGuard(iClient);
}

public EventPlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsPlayer(iVictim))
		return;
	
	SDKUnhook(iVictim, SDKHook_PostThinkPost, OnPostThinkPost);
	
	switch(GetClientTeam(iVictim))
	{
		case TEAM_GUARDS:
		{
			TryRemoveLastGuard(iVictim);
			CheckForLastGuard();
		}
		case TEAM_PRISONERS:
		{
			new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
			if(!IsPlayer(iAttacker))
				return;
			
			if(GetClientTeam(iAttacker) == TEAM_GUARDS)
				CheckForHealthReturn(iAttacker);
		}
	}
}

CheckForHealthReturn(iClient)
{
	new iLastGuard = GetClientFromSerial(g_iLastGuardSerial);
	if(!iLastGuard || iLastGuard != iClient)
		return;
	
	UltJB_LR_SetClientsHealth(iClient, GetClientHealth(iClient) + GetConVarInt(cvar_hp_per_kill));
}

public OnClientDisconnect(iClient)
{
	TryRemoveLastGuard(iClient);
}

CheckForLastGuard()
{
	if(!g_bCanLastGuard)
		return;
	
	decl iLastGuard;
	new iNumGuardsAlive;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		if(!IsPlayerAlive(iClient))
			continue;
		
		iNumGuardsAlive++;
		iLastGuard = iClient;
	}
	
	if(iNumGuardsAlive != 1)
		return;
	
	SetLastGuard(iLastGuard);
}

SetLastGuard(iClient)
{
	// Make sure LR hasn't started, don't count currently in session freeday LRs.
	new iNumInitialized = UltJB_LR_GetNumInitialized() - UltJB_LR_GetNumStartedContains(LR_FLAG_FREEDAY);
	
	if(iNumInitialized > 0)
		return;
	
	new result;
	Call_StartForward(g_hFwd_OnActivated_Pre);
	Call_PushCell(iClient);
	Call_Finish(result);
	
	StopTimer_LastGuard();
	g_iLastGuardSerial = GetClientSerial(iClient);
	
	// Display messages to players.
	new iNumPrisonersAlive;
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer) || !IsPlayerAlive(iPlayer))
			continue;
		
		if(UltJB_LR_HasStartedLastRequest(iPlayer) && (UltJB_LR_GetLastRequestFlags(iPlayer) & LR_FLAG_FREEDAY))
			continue;
		
		g_fNextBeaconTime[iPlayer] = GetGameTime() + GetRandomFloat(0.0, BEACON_DELAY_MAX);
		SDKHook(iPlayer, SDKHook_PostThinkPost, OnPostThinkPost);
		
		if(GetClientTeam(iPlayer) != TEAM_PRISONERS)
			continue;
		
		PrintHintText(iPlayer, "<font color='#DE2626'>%N</font>\n<font color='#6FC41A'>is last guard. Kill them!</font>", iClient);
		iNumPrisonersAlive++;
	}
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}is the last guard!", iClient);
	
	// Give bonus health.
	new iBonusHealth = GetConVarInt(cvar_hp_per_prisoner) * iNumPrisonersAlive;
	UltJB_LR_SetClientsHealth(iClient, GetClientHealth(iClient) + iBonusHealth);
	
	SetEntityModel(iClient, PLAYER_MODEL_LAST_GUARD);
	
	StartTimer_LastGuard(iClient);
	
	Call_StartForward(g_hFwd_OnActivated_Post);
	Call_PushCell(iClient);
	Call_Finish(result);
}

public OnPostThinkPost(iClient)
{
	static Float:fCurTime;
	fCurTime = GetGameTime();
	if(fCurTime < g_fNextBeaconTime[iClient])
		return;
	
	static iBeaconPitch, Float:fBeaconDelay, Float:fBeaconPercent;
	fBeaconPercent = GetBeaconPercent(iClient);
	fBeaconDelay = (((BEACON_DELAY_MAX - BEACON_DELAY_MIN) * fBeaconPercent) + BEACON_DELAY_MIN);
	
	g_fNextBeaconTime[iClient] = fCurTime + fBeaconDelay + 0.2;
	
	static iColor[4];
	switch(GetClientTeam(iClient))
	{
		case TEAM_GUARDS: iColor = BEACON_COLOR_GUARD;
		case TEAM_PRISONERS: iColor = BEACON_COLOR_PRISONER;
		default: return;
	}
	
	static Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	fOrigin[2] += 10.0;
	
	TE_SetupBeamRingPoint(fOrigin, 10.0, 220.0, g_iBeaconIndex, 0, 1, 1, fBeaconDelay, 5.5, 10.0, iColor, 0, 0);
	TE_SendToAll();
	
	iBeaconPitch = RoundFloat(((BEACON_PITCH_MAX - BEACON_PITCH_MIN) * (1.0 - fBeaconPercent)) + BEACON_PITCH_MIN);
	EmitSoundToAllAny(SZ_BEACON_SOUND[6], iClient, _, SNDLEVEL_NORMAL, _, 0.7, iBeaconPitch);
}

Float:GetBeaconPercent(iClient)
{
	decl Float:fDistance;
	new Float:fMinDistance = BEACON_DISTANCE_MAX;
	new iTeam = GetClientTeam(iClient);
	
	decl Float:fClientOrigin[3], Float:fPlayerOrigin[3];
	GetClientAbsOrigin(iClient, fClientOrigin);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer) || !IsPlayerAlive(iPlayer))
			continue;
		
		if(iTeam == GetClientTeam(iPlayer))
			continue;
		
		if(UltJB_LR_HasStartedLastRequest(iPlayer) && (UltJB_LR_GetLastRequestFlags(iPlayer) & LR_FLAG_FREEDAY))
			continue;
		
		GetClientAbsOrigin(iPlayer, fPlayerOrigin);
		fDistance = GetVectorDistance(fClientOrigin, fPlayerOrigin);
		
		if(fDistance < fMinDistance)
			fMinDistance = fDistance;
	}
	
	if(fMinDistance < BEACON_DISTANCE_MIN)
		fMinDistance = BEACON_DISTANCE_MIN;
	
	// Get the percent.
	return ((fMinDistance - BEACON_DISTANCE_MIN) / (BEACON_DISTANCE_MAX - BEACON_DISTANCE_MIN));
}

TryRemoveLastGuard(iClient)
{
	new iLastGuard = GetClientFromSerial(g_iLastGuardSerial);
	if(!iLastGuard || iLastGuard != iClient)
		return;
	
	RemoveLastGuard();
}

public UltJB_LR_OnLastRequestInitialized(iClient)
{
	RemoveLastGuard();
}

RemoveLastGuard()
{
	StopTimer_LastGuard();
	g_iLastGuardSerial = 0;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	}
}

StartTimer_LastGuard(iClient)
{
	g_iCounter_DamageWait = 0;
	g_iCounter_DamageInterval = GetConVarInt(cvar_damage_interval);
	ShowMessageDamageWaitTime(iClient);
	
	g_hTimer_LastGuard = CreateTimer(1.0, Timer_LastGuard, GetClientSerial(iClient), TIMER_REPEAT);
}

StopTimer_LastGuard()
{
	if(g_hTimer_LastGuard == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_LastGuard);
	g_hTimer_LastGuard = INVALID_HANDLE;
}

public Action:Timer_LastGuard(Handle:hTimer, any:iClientSerial)
{
	// Make sure the last guard exists.
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
	{
		RemoveLastGuard();
		return Plugin_Continue;
	}
	
	// Return if the wait time hasn't expired.
	g_iCounter_DamageWait++;
	if(g_iCounter_DamageWait < GetConVarInt(cvar_damage_wait))
	{
		ShowMessageDamageWaitTime(iClient);
		return Plugin_Continue;
	}
	
	// Return if it's not time for the next damage tick.
	g_iCounter_DamageInterval++;
	if(g_iCounter_DamageInterval < GetConVarInt(cvar_damage_interval))
	{
		ShowMessageDamageIntervalTime(iClient);
		return Plugin_Continue;
	}
	
	g_iCounter_DamageInterval = 0;
	
	// Deal damage.
	if(GetClientHealth(iClient) > GetConVarInt(cvar_damage_amount))
	{
		SlapPlayer(iClient, GetConVarInt(cvar_damage_amount), true);
		ShowMessageDamageIntervalTime(iClient);
	}
	else
	{
		ForcePlayerSuicide(iClient);
	}
	
	return Plugin_Continue;
}

public EventPlayerHurt_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iLastGuard = GetClientFromSerial(g_iLastGuardSerial);
	if(!iLastGuard)
		return;
	
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(iAttacker != iLastGuard)
		return;
	
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsPlayer(iVictim))
		return;
	
	ResetDamageCounters();
}

ResetDamageCounters()
{
	g_iCounter_DamageWait = 0;
	g_iCounter_DamageInterval = GetConVarInt(cvar_damage_interval);
	
	new iClient = GetClientFromSerial(g_iLastGuardSerial);
	if(!iClient)
		return;
	
	ShowMessageDamageWaitTime(iClient);
}

ShowMessageDamageWaitTime(iClient)
{
	PrintHintText(iClient, "<font color='#6FC41A'>You have </font><font color='#DE2626'>%i</font><font color='#6FC41A'> seconds\nto damage the prisoners.</font>", GetConVarInt(cvar_damage_wait) - g_iCounter_DamageWait);
}

ShowMessageDamageIntervalTime(iClient)
{
	PrintHintText(iClient, "<font color='#6FC41A'>You have </font><font color='#DE2626'>%i</font><font color='#6FC41A'> seconds\nbefore you're damaged again.</font>", GetConVarInt(cvar_damage_interval) - g_iCounter_DamageInterval);
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}