#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: Weapon Battle - Shot for Shot";
new const String:PLUGIN_VERSION[] = "1.6";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Weapon Battle - Shot for Shot.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Shot for Shot"
#define LR_CATEGORY		"Weapon Battle"
#define LR_DESCRIPTION	""

new bool:g_bWasOpponentSelected[MAXPLAYERS+1];

new g_iWeaponSelectedID[MAXPLAYERS+1];
new g_iEffectSelectedID[MAXPLAYERS+1];

new bool:g_bIsClientsTurn[MAXPLAYERS+1];
new g_iOldClipAmount[MAXPLAYERS+1];

new g_iTimerCountdown[MAXPLAYERS+1];
new Handle:g_hBattleTimer[MAXPLAYERS+1];
new Handle:cvar_weapon_battle_countdown;


public OnPluginStart()
{
	CreateConVar("lr_weapon_battle_shot_for_shot_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_weapon_battle_countdown = FindConVar("lr_weapon_battle_countdown")) == INVALID_HANDLE)
		cvar_weapon_battle_countdown = CreateConVar("lr_weapon_battle_countdown", "5", "The number of seconds to countdown before starting the battle.");
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, _, OnLastRequestStart, OnLastRequestEnd);
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
	
	LastRequestEndCleanup(iClient, g_iEffectSelectedID[iClient]);
	LastRequestEndCleanup(iOpponent, g_iEffectSelectedID[iClient]);
	
	StopTimer_Countdown(iClient);
}

public OnOpponentSelectedSuccess(iClient, iOpponent)
{
	g_bWasOpponentSelected[iClient] = true;
	
	g_bIsClientsTurn[iClient] = false;
	g_bIsClientsTurn[iOpponent] = false;
	
	UltJB_LR_StripClientsWeapons(iClient, true);
	UltJB_LR_StripClientsWeapons(iOpponent, true);
	
	new iFlags[NUM_WPN_CATS];
	iFlags[WPN_CAT_KNIFE] = WPN_FLAGS_DISABLE_KNIFE_KNIFE;
	UltJB_Weapons_DisplaySelectionMenu(iClient, OnWeaponSelected_Success, OnWeaponSelected_Failed, iFlags);
}

public OnWeaponSelected_Success(iClient, iWeaponID, const iFlags[NUM_WPN_CATS])
{
	g_iWeaponSelectedID[iClient] = iWeaponID;
	g_iWeaponSelectedID[UltJB_LR_GetLastRequestOpponent(iClient)] = iWeaponID;
	UltJB_Effects_DisplaySelectionMenu(iClient, OnEffectSelected_Success, OnEffectSelected_Failed);
}

public OnWeaponSelected_Failed(iClient, const iFlags[NUM_WPN_CATS])
{
	UltJB_LR_EndLastRequest(iClient);
}

public OnEffectSelected_Success(iClient, iEffectID)
{
	g_iEffectSelectedID[iClient] = iEffectID;
	PrepareClients(iClient);
}

public OnEffectSelected_Failed(iClient)
{
	PrintToChat(iClient, "[SM] Proceeding without an effect.");
	
	g_iEffectSelectedID[iClient] = 0;
	PrepareClients(iClient);
}

PrepareClients(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StartEffect(iClient, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
		UltJB_Effects_StartEffect(iOpponent, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
	}
	
	new iCountdownTime = GetConVarInt(cvar_weapon_battle_countdown);
	if(iCountdownTime < 1)
	{
		StartBattle(iClient);
		return;
	}
	
	PrintToChat(iClient, "[SM] The battle will start in %i seconds.", iCountdownTime);
	PrintToChat(iOpponent, "[SM] The battle will start in %i seconds.", iCountdownTime);
	
	g_iTimerCountdown[iClient] = 0;
	StartTimer_Countdown(iClient);
}

StopTimer_Countdown(iClient)
{
	if(g_hBattleTimer[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hBattleTimer[iClient]);
	g_hBattleTimer[iClient] = INVALID_HANDLE;
}

StartTimer_Countdown(iClient)
{
	StopTimer_Countdown(iClient);
	g_hBattleTimer[iClient] = CreateTimer(1.0, Timer_Countdown, GetClientSerial(iClient), TIMER_REPEAT);
}

public Action:Timer_Countdown(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
	{
		g_hBattleTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_iTimerCountdown[iClient]++;
	new iCountdownTimeRemaining = GetConVarInt(cvar_weapon_battle_countdown) - g_iTimerCountdown[iClient];
	
	if(!iCountdownTimeRemaining)
	{
		StartBattle(iClient);
		g_hBattleTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	PrintToChat(iClient, "[SM] %i..", iCountdownTimeRemaining);
	PrintToChat(iOpponent, "[SM] %i..", iCountdownTimeRemaining);
	
	return Plugin_Continue;
}

StartBattle(iClient)
{
	UltJB_LR_StartSlayTimer(iClient, 60);
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	PrintToChat(iClient, "[SM] The battle has started!");
	PrintToChat(iOpponent, "[SM] The battle has started!");
	
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SDKHook(iOpponent, SDKHook_PreThinkPost, OnPreThinkPost);
	
	if(GetRandomInt(0, 1))
		SetCurrentTurn(iClient);
	else
		SetCurrentTurn(iOpponent);
}

LastRequestEndCleanup(iClient, iEffectID)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
	
	if(iEffectID)
		UltJB_Effects_StopEffect(iClient, iEffectID);
	
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
	
	SetCurrentTurn(UltJB_LR_GetLastRequestOpponent(iClient));
}

SetCurrentTurn(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(!iOpponent)
		return;
	
	g_bIsClientsTurn[iClient] = true;
	g_bIsClientsTurn[iOpponent] = false;
	
	UltJB_LR_StripClientsWeapons(iOpponent, false);
	
	new iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, g_iWeaponSelectedID[iClient]);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	SetEntProp(iWeapon, Prop_Send, "m_iClip1", 1);
	g_iOldClipAmount[iClient] = 1;
	
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", 0.0);
}