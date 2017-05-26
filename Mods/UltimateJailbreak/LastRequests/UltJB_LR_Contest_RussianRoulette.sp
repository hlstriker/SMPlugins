#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Contest - Russian Roulette";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Contest - Russian Roulette.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Russian Roulette"
#define LR_CATEGORY		"Contest"
#define LR_DESCRIPTION	""

new bool:g_bWasOpponentSelected[MAXPLAYERS+1];

new bool:g_bIsClientsTurn[MAXPLAYERS+1];
new g_iOldClipAmount[MAXPLAYERS+1];

#define CLIP_SIZE	7
new g_iShotsFired[MAXPLAYERS+1];
new g_iKillShotNumber[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("lr_contest_russian_roulette_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	UltJB_LR_DisplayOpponentSelection(iClient, OnOpponentSelectedSuccess);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	if(!g_bWasOpponentSelected[iClient])
		return;
	
	g_bWasOpponentSelected[iClient] = false;
	
	LastRequestEndCleanup(iClient);
	LastRequestEndCleanup(iOpponent);
}

public OnOpponentSelectedSuccess(iClient, iOpponent)
{
	g_bWasOpponentSelected[iClient] = true;
	
	PrepareClient(iClient);
	PrepareClient(iOpponent);
	
	if(GetRandomInt(0, 1))
		SetCurrentTurn(iClient);
	else
		SetCurrentTurn(iOpponent);
}

PrepareClient(iClient)
{
	g_iKillShotNumber[iClient] = GetRandomInt(1, CLIP_SIZE);
	
	g_bIsClientsTurn[iClient] = false;
	g_iShotsFired[iClient] = 0;
	
	UltJB_LR_StripClientsWeapons(iClient, true);
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

LastRequestEndCleanup(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
	
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public OnPreThinkPost(iClient)
{
	if(!g_bIsClientsTurn[iClient])
		return;
	
	static iWeapon;
	iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iWeapon < 1)
	{
		SetCurrentTurn(UltJB_LR_GetLastRequestOpponent(iClient));
		return;
	}
	
	static iClip;
	iClip = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
	
	if(iClip > g_iOldClipAmount[iClient])
	{
		g_iOldClipAmount[iClient] = iClip;
		return;
	}
	
	if(iClip == g_iOldClipAmount[iClient])
		return;
	
	g_iShotsFired[iClient]++;
	g_iOldClipAmount[iClient] = iClip;
	
	SetCurrentTurn(UltJB_LR_GetLastRequestOpponent(iClient));
	
	if(g_iShotsFired[iClient] == g_iKillShotNumber[iClient])
	{
		new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
		SDKHooks_TakeDamage(iClient, iOpponent, iOpponent, 99999.0);
	}
}

SetCurrentTurn(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(!iOpponent)
		return;
	
	g_bIsClientsTurn[iClient] = true;
	g_bIsClientsTurn[iOpponent] = false;
	
	UltJB_LR_StripClientsWeapons(iOpponent, false);
	
	new iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_DEAGLE);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	new iClipSize = CLIP_SIZE - g_iShotsFired[iClient];
	SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClipSize);
	
	g_iOldClipAmount[iClient] = iClipSize;
	
	if(GetClientTeam(iClient) == TEAM_GUARDS)
		UltJB_LR_StartSlayTimer(iClient, 10, LR_SLAYTIMER_FLAG_GUARD);
	else
		UltJB_LR_StartSlayTimer(iClient, 10, LR_SLAYTIMER_FLAG_PRISONER);
}