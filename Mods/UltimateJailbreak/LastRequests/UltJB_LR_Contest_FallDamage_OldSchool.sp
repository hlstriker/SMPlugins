#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: Contest - Fall Damage Old School";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Contest - Fall Damage Old School.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Fall Damage: Old School"
#define LR_CATEGORY		"Contest"
#define LR_DESCRIPTION	""

#define SLAY_TIMER_SECONDS		20
#define SLAY_TIMER_DECREMENT	5

new bool:g_bWasOpponentSelected[MAXPLAYERS+1];
new g_iEffectSelectedID[MAXPLAYERS+1];

new bool:g_bIsClientsTurn[MAXPLAYERS+1];
new g_iNextSlayTimerSeconds[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("lr_contest_fall_damage_os_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT | LR_FLAG_ALLOW_WEAPON_PICKUPS, OnLastRequestStart, OnLastRequestEnd);
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
	
	SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(iOpponent, SDKHook_OnTakeDamage, OnTakeDamage);
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StopEffect(iClient, g_iEffectSelectedID[iClient]);
		UltJB_Effects_StopEffect(iOpponent, g_iEffectSelectedID[iClient]);
	}
}

public OnOpponentSelectedSuccess(iClient, iOpponent)
{
	g_bIsClientsTurn[iClient] = false;
	g_bIsClientsTurn[iOpponent] = false;
	
	g_bWasOpponentSelected[iClient] = true;
	UltJB_Effects_DisplaySelectionMenu(iClient, OnEffectSelected_Success, OnEffectSelected_Failed);
}

public OnEffectSelected_Success(iClient, iEffectID)
{
	g_iEffectSelectedID[iClient] = iEffectID;
	PrepareClients(iClient);
}

public OnEffectSelected_Failed(iClient)
{
	g_iEffectSelectedID[iClient] = 0;
	PrepareClients(iClient);
}

PrepareClients(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(iOpponent, SDKHook_OnTakeDamage, OnTakeDamage);
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StartEffect(iClient, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
		UltJB_Effects_StartEffect(iOpponent, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
	}
	
	// Prisoner starts first since they have a slight advantage since they start jumping first.
	g_iNextSlayTimerSeconds[iClient] = SLAY_TIMER_SECONDS;
	SetCurrentTurn(iClient);
}

public OnSlayTimerFinished(iClient, iOpponent, iSlayedIndex)
{
	if(iSlayedIndex == LR_SLAYTIMER_SLAYED_NONE)
		return;
	
	if(iSlayedIndex == LR_SLAYTIMER_SLAYED_BOTH)
		return;
	
	DisplayEndMessage((iSlayedIndex == iClient) ? iOpponent : iClient, iSlayedIndex);
}

SetCurrentTurn(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(!iOpponent)
		return;
	
	if(GetClientTeam(iClient) == TEAM_PRISONERS)
	{
		UltJB_LR_StartSlayTimer(iClient, g_iNextSlayTimerSeconds[iClient], LR_SLAYTIMER_FLAG_PRISONER, OnSlayTimerFinished);
	}
	else
	{
		UltJB_LR_StartSlayTimer(iOpponent, g_iNextSlayTimerSeconds[iOpponent], LR_SLAYTIMER_FLAG_GUARD, OnSlayTimerFinished);
		g_iNextSlayTimerSeconds[iOpponent] -= SLAY_TIMER_DECREMENT; // Next prisoner turn will be X less seconds.
	}
	
	g_bIsClientsTurn[iClient] = true;
	g_bIsClientsTurn[iOpponent] = false;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iVictim);
	if(!iOpponent)
	{
		UltJB_LR_EndLastRequest(iVictim);
		return Plugin_Continue;
	}
	
	if(!(iDamageType & DMG_FALL))
	{
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	if(!g_bIsClientsTurn[iVictim])
	{
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	// Check to see if this victim lost. If so then make it look like they died from their opponent.
	new Float:fHealth = float(GetClientHealth(iVictim));
	if((fHealth - fDamage) < 1.0)
	{
		DisplayEndMessage(iOpponent, iVictim);
		SDKHooks_TakeDamage(iVictim, iOpponent, iOpponent, 99999.0);
		
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	SetCurrentTurn(iOpponent);
	
	return Plugin_Continue;
}

DisplayEndMessage(iWinner, iLoser)
{
	if(!IsClientInGame(iWinner) || !IsClientInGame(iLoser))
		return;
	
	PrintToChat(iLoser, "[SM] You lost. Your opponent has %i health remaining.", GetClientHealth(iWinner));
	PrintToChat(iWinner, "[SM] You won with %i health remaining.", GetClientHealth(iWinner));
}