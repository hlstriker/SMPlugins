#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Rebel - Ghost";
new const String:PLUGIN_VERSION[] = "1.1";

new bool:g_bIsGhostVisible;
new bool:g_bCanDropWeapons = true;

new Handle:g_hTimer_EnableRadar;
new Handle:g_hTimer_DisableRadar;

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "Last Request: Rebel - Ghost",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Ghost"
#define LR_CATEGORY		"Rebel"
#define LR_DESCRIPTION	""


public OnPluginStart()
{
	CreateConVar("lr_rebel_ghost_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_LAST_PRISONER_ONLY_CAN_USE | LR_FLAG_NORADAR | LR_FLAG_NOBEACON | LR_FLAG_RANDOM_TELEPORT_LOCATION, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	UltJB_LR_SetClientsHealth(iClient, 1);
	PrepareWeapons(iClient);
	//SDKHook(iClient, SDKHook_SetTransmit, Hook_HidePlayer);
	SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnDamage);
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	SetEntityRenderMode(iClient, RENDER_NONE);
	HookGuards();
	PrepareGuards();
	StartTimer_EnableRadar();
	g_bCanDropWeapons = false;
}

public OnLastRequestEnd(iClient, iOpponent)
{
	g_bCanDropWeapons = true;
	RestoreWeaponsIfNeeded(iClient);
	//SDKUnhook(iClient, SDKHook_SetTransmit, Hook_HidePlayer);
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_OnDamage);
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	SetEntityRenderMode(iClient, RENDER_NORMAL);
	UnhookGuards();
	StopTimer_EnableRadar();
}

PrepareWeapons(iClient)
{
	UltJB_LR_StripClientsWeapons(iClient, true);
	UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
}

PrepareGuards()
{
	for(new iClient=1;iClient<=MaxClients;iClient++) {
		
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
			
		UltJB_LR_StripClientsWeapons(iClient, true);
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_NOVA);
	
	}
}

RestoreWeaponsIfNeeded(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
}

public Action:Hook_HidePlayer(ent, iClient) 
{ 
    if (iClient != ent) 
        return Plugin_Handled;
     
    return Plugin_Continue; 
}  

HookGuards()
{
	for(new iClient = 1;iClient<=MaxClients;iClient++) {
		if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
	
		SDKHook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
		SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnDamage);
	}
}

UnhookGuards()
{
	for(new iClient = 1;iClient<=MaxClients;iClient++) {
		SDKUnhook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
		SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_OnDamage);
	}
}

public OnClientDisconnect(iClient)
{
	SDKUnhook(iClient, SDKHook_OnTakeDamage, Hook_OnDamage);
	SDKUnhook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action:Hook_OnDamage(iVictim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(iVictim < 1 || iVictim > MaxClients)
		return Plugin_Continue;
	
	decl String:sWeapon[32];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
	
	if (StrContains(sWeapon, "player") != -1)
	{
		new weapon = GetEntPropEnt(inflictor, Prop_Send, "m_hActiveWeapon");
		GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
	}
	
	switch(GetClientTeam(iVictim))
	{
		case TEAM_PRISONERS:
		{
			if(damagetype == DMG_FALL)
			{
				damage = 0.0;
			}
			else if((StrContains(sWeapon, "hegrenade") != -1) || (StrContains(sWeapon, "inferno") != -1) || (StrContains(sWeapon, "molotov") != -1)) {
				damage = 0.0;
			} else {
				return Plugin_Continue;
			}
		}
		case TEAM_GUARDS:
		{
			if (StrContains(sWeapon, "knife") == -1) {
				damage = 0.0;
			} else {
				damage = 1337.0;
			}
		}
		default: return Plugin_Continue;
		
	}

	return Plugin_Changed;
}

StartTimer_EnableRadar()
{
	StopTimer_EnableRadar();
	StopTimer_DisableRadar();

	g_hTimer_EnableRadar = CreateTimer(4.0, Timer_EnableRadar, _, TIMER_REPEAT);
}

StopTimer_EnableRadar()
{
	if(g_hTimer_EnableRadar != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_EnableRadar);
		g_hTimer_EnableRadar = INVALID_HANDLE;
	}
		
	if(g_hTimer_DisableRadar != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_DisableRadar);
		g_hTimer_DisableRadar = INVALID_HANDLE;
	}
}

StartTimer_DisableRadar()
{
	StopTimer_DisableRadar();

	g_hTimer_DisableRadar = CreateTimer(0.5, Timer_DisableRadar);
}

StopTimer_DisableRadar()
{
	if(g_hTimer_DisableRadar != INVALID_HANDLE)
	{
		KillTimer(g_hTimer_DisableRadar);
		g_hTimer_DisableRadar = INVALID_HANDLE;
	}
}

public Action:Timer_EnableRadar(Handle:hTimer)
{
	g_bIsGhostVisible = true;
	StartTimer_DisableRadar();
}

public Action:Timer_DisableRadar(Handle:hTimer)
{
	g_bIsGhostVisible = false;
	g_hTimer_DisableRadar = INVALID_HANDLE;
}

public OnPostThinkPost(iClient)
{
	if(g_bIsGhostVisible)
		SetEntProp(iClient, Prop_Send, "m_bSpotted", 1);
	else
		SetEntProp(iClient, Prop_Send, "m_bSpotted", 0);
}

public Action:CS_OnCSWeaponDrop(iClient, iWeapon)
{
	if(g_bCanDropWeapons)
		return Plugin_Continue;
	else
		return Plugin_Handled;
}


public Action:OnWeaponCanUse(iClient, iWeapon)
{
	return Plugin_Handled;
}