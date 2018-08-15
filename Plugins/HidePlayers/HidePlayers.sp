#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include "../../Libraries/ClientCookies/client_cookies"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Hide Players";
new const String:PLUGIN_VERSION[] = "2.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Hides other players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

enum
{
	HIDE_DISABLED = 0,
	HIDE_ALL,
	HIDE_TEAM_ONLY
};

enum
{
	OVERRIDE_NONE = 0,
	OVERRIDE_HIDE_ALL,
	OVERRIDE_HIDE_TEAM_ONLY
};

new g_iHideMode;
new bool:g_bShouldHideOthers[MAXPLAYERS+1];
new Float:g_fNextHideCommand[MAXPLAYERS+1];
#define HIDE_COMMAND_DELAY 0.7

new Handle:cvar_hide_players_override;

new bool:g_bHasIntermissionStarted;


public OnPluginStart()
{
	CreateConVar("hide_players_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_hide_players_override = CreateConVar("hide_players_override", "0", "0: No override -- 1: Always hide all -- 2: Always hide team only.", _, true, 0.0, true, 2.0);
	
	RegConsoleCmd("sm_hide", OnHidePlayers, "Toggles hiding other players on and off.");
	
	HookEvent("cs_intermission", Event_Intermission_Post, EventHookMode_PostNoCopy);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("hide_players");
	CreateNative("HidePlayers_IsClientHidingTarget", _HidePlayers_IsClientHidingTarget);
	
	return APLRes_Success;
}

public _HidePlayers_IsClientHidingTarget(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	if(!g_bShouldHideOthers[iClient])
		return false;
	
	if(GetConVarInt(cvar_hide_players_override) != OVERRIDE_HIDE_ALL && (g_iHideMode == HIDE_TEAM_ONLY || GetConVarInt(cvar_hide_players_override) == OVERRIDE_HIDE_TEAM_ONLY))
	{
		if(GetClientTeam(iClient) != GetClientTeam(GetNativeCell(2)))
			return false;
	}
	
	return true;
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
	
	g_iHideMode = HIDE_DISABLED;
	
	decl String:szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	
	if(StrContains(szMapName, "deathrun_", false) != -1)
	{
		g_iHideMode = HIDE_TEAM_ONLY;
		return;
	}
	
	if(StrContains(szMapName, "dr_", false) != -1)
	{
		g_iHideMode = HIDE_TEAM_ONLY;
		return;
	}
	
	if(StrContains(szMapName, "mg_", false) != -1)
	{
		g_iHideMode = HIDE_ALL;
		return;
	}
	
	if(StrContains(szMapName, "bhop_", false) != -1)
	{
		g_iHideMode = HIDE_ALL;
		return;
	}
	
	if(StrContains(szMapName, "kz_", false) != -1)
	{
		g_iHideMode = HIDE_ALL;
		return;
	}
	
	if(StrContains(szMapName, "xc_", false) != -1)
	{
		g_iHideMode = HIDE_ALL;
		return;
	}
}

public OnClientPutInServer(iClient)
{
	g_fNextHideCommand[iClient] = 0.0;
	g_bShouldHideOthers[iClient] = false;
	SDKHook(iClient, SDKHook_SetTransmit, OnSetTransmit_Player);
}

public Action:OnHidePlayers(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
		
	if(!IsClientInGame(iClient))
		return Plugin_Handled;
	
	if(g_iHideMode == HIDE_DISABLED && GetConVarInt(cvar_hide_players_override) == OVERRIDE_NONE)
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
	
	if(g_bHasIntermissionStarted)
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(!g_bShouldHideOthers[iClient])
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(iPlayerEnt == iClient)
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(!(1 <= iPlayerEnt <= MaxClients))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(!IsPlayerAlive(iClient))
	{
		g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
		return Plugin_Continue;
	}
	
	if(GetConVarInt(cvar_hide_players_override) != OVERRIDE_HIDE_ALL && (g_iHideMode == HIDE_TEAM_ONLY || GetConVarInt(cvar_hide_players_override) == OVERRIDE_HIDE_TEAM_ONLY))
	{
		if(GetClientTeam(iClient) != GetClientTeam(iPlayerEnt))
		{
			g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Continue;
			return Plugin_Continue;
		}
	}
	
	g_CachedTransmitClient[iClient][iPlayerEnt] = Plugin_Handled;
	return Plugin_Handled;
}