#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include "../../Libraries/ClientCookies/client_cookies"
#include "hide_players"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Hide Players";
new const String:PLUGIN_VERSION[] = "2.11";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Hides other players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new g_iMapsHideMode;
new g_iPluginHideOverride[MAXPLAYERS+1];
new bool:g_bShouldHideOthers[MAXPLAYERS+1];
new Float:g_fNextHideCommand[MAXPLAYERS+1];
#define HIDE_COMMAND_DELAY 0.7

new Handle:cvar_mp_teammates_are_enemies;
new Handle:cvar_hide_players_override;

new bool:g_bHasIntermissionStarted;


public OnPluginStart()
{
	CreateConVar("hide_players_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_hide_players_override = CreateConVar("hide_players_override", "0", "-1: Always disabled -- 0: No override -- 1: Always hide all -- 2: Always hide team only.", _, true, -1.0, true, 2.0);
	
	RegConsoleCmd("sm_hide", OnHidePlayers, "Toggles hiding other players on and off.");
	
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	HookEvent("cs_intermission", Event_Intermission_Post, EventHookMode_PostNoCopy);
}

public OnConfigsExecuted()
{
	cvar_mp_teammates_are_enemies = FindConVar("mp_teammates_are_enemies");
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("hide_players");
	CreateNative("HidePlayers_IsClientHidingTarget", _HidePlayers_IsClientHidingTarget);
	CreateNative("HidePlayers_SetClientHideOverride", _HidePlayers_SetClientHideOverride);
	
	return APLRes_Success;
}

public _HidePlayers_IsClientHidingTarget(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	if(!g_bShouldHideOthers[iClient])
		return false;
	
	if(GetConVarInt(cvar_hide_players_override) != HIDE_ALL && (g_iMapsHideMode == HIDE_TEAM_ONLY || GetConVarInt(cvar_hide_players_override) == HIDE_TEAM_ONLY))
	{
		if(GetClientTeam(iClient) != GetClientTeam(GetNativeCell(2)))
			return false;
	}
	
	return true;
}

public _HidePlayers_SetClientHideOverride(Handle:hPlugin, iNumParams)
{
	g_iPluginHideOverride[GetNativeCell(1)] = GetNativeCell(2);
}

public Action:Event_Intermission_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bHasIntermissionStarted = true;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	g_bShouldHideOthers[iClient] = bool:ClientCookies_GetCookie(iClient, CC_TYPE_HIDE_PLAYERS);
}

public OnMapStart()
{
	g_bHasIntermissionStarted = false;
	
	g_iMapsHideMode = HIDE_DISABLED;
	
	decl String:szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	
	if(StrContains(szMapName, "deathrun_", false) != -1)
	{
		g_iMapsHideMode = HIDE_TEAM_ONLY;
		return;
	}
	
	if(StrContains(szMapName, "dr_", false) != -1)
	{
		g_iMapsHideMode = HIDE_TEAM_ONLY;
		return;
	}
	
	if(StrContains(szMapName, "mg_", false) != -1)
	{
		g_iMapsHideMode = HIDE_ALL;
		return;
	}
	
	if(StrContains(szMapName, "bhop_", false) != -1)
	{
		g_iMapsHideMode = HIDE_ALL;
		return;
	}
	
	if(StrContains(szMapName, "kz_", false) != -1)
	{
		g_iMapsHideMode = HIDE_ALL;
		return;
	}
	
	if(StrContains(szMapName, "xc_", false) != -1)
	{
		g_iMapsHideMode = HIDE_ALL;
		return;
	}
}

public Action:Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		g_iPluginHideOverride[iClient] = HIDE_DEFAULT;
}

public OnClientPutInServer(iClient)
{
	g_fNextHideCommand[iClient] = 0.0;
	g_iPluginHideOverride[iClient] = HIDE_DEFAULT;
	g_bShouldHideOthers[iClient] = false;
	SDKHook(iClient, SDKHook_SetTransmit, OnSetTransmit_Player);
}

public Action:OnHidePlayers(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
		
	if(!IsClientInGame(iClient))
		return Plugin_Handled;
	
	if(g_iMapsHideMode == HIDE_DISABLED && GetConVarInt(cvar_hide_players_override) == HIDE_DISABLED)
	{
		PrintToChat(iClient, "[SM] Hiding other players is disabled.");
		return Plugin_Handled;
	}
	
	new Float:fCurTime = GetGameTime();
	if(fCurTime < g_fNextHideCommand[iClient])
	{
		PrintToChat(iClient, "[SM] Please wait a second before using this command again.");
		return Plugin_Handled;
	}
	
	g_fNextHideCommand[iClient] = fCurTime + HIDE_COMMAND_DELAY;
	
	g_bShouldHideOthers[iClient] = !g_bShouldHideOthers[iClient];
	
	if(g_bShouldHideOthers[iClient])
		PrintToChat(iClient, "[SM] Type !hide again to show players.");
	else
		PrintToChat(iClient, "[SM] You will now see other players.");
	
	ClientCookies_SetCookie(iClient, CC_TYPE_HIDE_PLAYERS, g_bShouldHideOthers[iClient]);
	
	return Plugin_Handled;
}

new Action:g_CachedTransmitClient[MAXPLAYERS+1][MAXPLAYERS+1];
new Float:g_fNextTransmitClient[MAXPLAYERS+1][MAXPLAYERS+1];

public Action:OnSetTransmit_Player(iPlayerEnt, iClient)
{
	if(g_fNextTransmitClient[iClient][iPlayerEnt] > GetEngineTime())
		return g_CachedTransmitClient[iClient][iPlayerEnt];
	
	g_fNextTransmitClient[iClient][iPlayerEnt] = GetEngineTime() + GetRandomFloat(0.5, 0.7);
	
	// Don't hide in certain situations.
	if(!CanHide(iClient, iPlayerEnt))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	// Hide if we are hiding from another plugin overriding this client's hide value.
	if(ShouldHideFromPluginHideOverride(iClient, iPlayerEnt))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Handled;
		return Plugin_Handled;
	}
	
	// Should hide?
	if(ShouldHide(iClient, iPlayerEnt))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Handled;
		return Plugin_Handled;
	}
	
	// Don't hide.
	g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
	return Plugin_Continue;
}

bool:CanHide(iClient, iPlayerEnt)
{
	if(g_bHasIntermissionStarted)
		return false;
	
	if(!g_bShouldHideOthers[iClient])
		return false;
	
	if(iPlayerEnt == iClient)
		return false;
	
	if(!(1 <= iPlayerEnt <= MaxClients))
		return false;
	
	if(!IsPlayerAlive(iClient))
		return false;
	
	if(g_iPluginHideOverride[iClient] == HIDE_DISABLED)
		return false;
	
	return true;
}

bool:ShouldHideFromPluginHideOverride(iClient, iPlayerEnt)
{
	switch(g_iPluginHideOverride[iClient])
	{
		case HIDE_DEFAULT, HIDE_DISABLED:
		{
			return false;
		}
		case HIDE_TEAM_ONLY:
		{
			if(!CanHideBasedOnTeam(iClient, iPlayerEnt))
				return false;
		}
	}
	
	return true;
}

bool:ShouldHide(iClient, iPlayerEnt)
{
	if(g_iMapsHideMode == HIDE_DISABLED && GetConVarInt(cvar_hide_players_override) <= HIDE_DEFAULT)
	{
		return false;
	}
	
	if(GetConVarInt(cvar_hide_players_override) != HIDE_ALL && (g_iMapsHideMode == HIDE_TEAM_ONLY || GetConVarInt(cvar_hide_players_override) == HIDE_TEAM_ONLY))
	{
		if(!CanHideBasedOnTeam(iClient, iPlayerEnt))
			return false;
	}
	
	return true;
}

bool:CanHideBasedOnTeam(iClient, iPlayerEnt)
{
	if(GetConVarBool(cvar_mp_teammates_are_enemies))
		return false;
	
	if(GetClientTeam(iClient) != GetClientTeam(iPlayerEnt))
		return false;
	
	return true;
}