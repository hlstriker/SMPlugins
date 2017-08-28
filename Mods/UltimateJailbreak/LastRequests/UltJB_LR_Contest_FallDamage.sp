#include <sourcemod>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: Contest - Fall Damage";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Contest - Fall Damage.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Most Fall Damage"
#define LR_CATEGORY		"Contest"
#define LR_DESCRIPTION	""

new bool:g_bWasOpponentSelected[MAXPLAYERS+1];
new g_iEffectSelectedID[MAXPLAYERS+1];

new const Float:STARTING_FALL_DAMAGE = -1.0;
new Float:g_fFallDamage[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("lr_contest_fall_damage_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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
	UltJB_LR_StartSlayTimer(iClient);
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	
	g_fFallDamage[iClient] = STARTING_FALL_DAMAGE;
	g_fFallDamage[iOpponent] = STARTING_FALL_DAMAGE;
	
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(iOpponent, SDKHook_OnTakeDamage, OnTakeDamage);
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StartEffect(iClient, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
		UltJB_Effects_StartEffect(iOpponent, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
	}
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(iDamageType & DMG_FALL))
		return Plugin_Continue;
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iVictim);
	if(!iOpponent)
	{
		UltJB_LR_EndLastRequest(iVictim);
		return Plugin_Continue;
	}
	
	// Don't let the victim take any fall damage again.
	if(g_fFallDamage[iVictim] != STARTING_FALL_DAMAGE)
	{
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	g_fFallDamage[iVictim] = fDamage;
	
	// Check to see if we need to wait on the opponent to jump.
	if(g_fFallDamage[iOpponent] == STARTING_FALL_DAMAGE)
	{
		new Float:fHealth = float(GetClientHealth(iVictim));
		
		if((fHealth - fDamage) < 1.0)
			fDamage = fHealth - 1.0;
		
		return Plugin_Changed;
	}
	
	// Check to see if this victim lost. If so then make it look like they died from their opponent.
	if(g_fFallDamage[iVictim] < g_fFallDamage[iOpponent])
	{
		PrintToChat(iVictim, "[SM] You lost. Took %02f (%02f) damage.", g_fFallDamage[iVictim], g_fFallDamage[iOpponent]);
		PrintToChat(iOpponent, "[SM] You won! Took %02f (%02f) damage.", g_fFallDamage[iOpponent], g_fFallDamage[iVictim]);
		
		SDKHooks_TakeDamage(iVictim, iOpponent, iOpponent, 99999.0);
		
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	// Check to see if this victim won. If so then kill their opponent.
	if(g_fFallDamage[iVictim] > g_fFallDamage[iOpponent])
	{
		PrintToChat(iVictim, "[SM] You won! Took %02f (%02f) damage.", g_fFallDamage[iVictim], g_fFallDamage[iOpponent]);
		PrintToChat(iOpponent, "[SM] You lost. Took %02f (%02f) damage.", g_fFallDamage[iOpponent], g_fFallDamage[iVictim]);
		
		SDKHooks_TakeDamage(iOpponent, iVictim, iVictim, 99999.0);
		
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	// It was a tie.
	PrintToChat(iVictim, "[SM] You tied! Took %02f damage.", g_fFallDamage[iVictim]);
	PrintToChat(iOpponent, "[SM] You tied! Took %02f damage.", g_fFallDamage[iOpponent]);
	
	UltJB_LR_EndLastRequest(iVictim);
	
	fDamage = 0.0;
	return Plugin_Changed;
}