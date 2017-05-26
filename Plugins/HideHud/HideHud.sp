#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/ClientCookies/client_cookies"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Hide HUD";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Hides parts of the HUD.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define HIDEHUD_HEALTH_ARMOR_XHAIR	(1<<4)
#define HIDEHUD_RADAR				(1<<12)
#define HIDEHUD_TOP					(1<<13)

new g_iHudBits[MAXPLAYERS+1];

#define CROSSHAIR_HIDE_DELAY	1.0
new Float:g_fNextCrosshairHide[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("hide_hud_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			PlayerHooks(iClient);
	}
	
	RegConsoleCmd("sm_crosshair", OnCrosshair, "Toggles the players crosshair.");
}

public OnClientPutInServer(iClient)
{
	PlayerHooks(iClient);
}

public OnClientConnected(iClient)
{
	g_iHudBits[iClient] = HIDEHUD_RADAR | HIDEHUD_TOP;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_HUD_BITS))
		g_iHudBits[iClient] = ValidateBits(ClientCookies_GetCookie(iClient, CC_TYPE_HUD_BITS));
}

ValidateBits(iBits)
{
	return (iBits & (HIDEHUD_HEALTH_ARMOR_XHAIR | HIDEHUD_RADAR | HIDEHUD_TOP));
}

PlayerHooks(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", HIDEHUD_RADAR | HIDEHUD_TOP);
	
	SetCrosshairHideDelay(iClient);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	
	if(g_iHudBits[iClient] & HIDEHUD_HEALTH_ARMOR_XHAIR)
		SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnWeaponSwitchPost(iClient, iWeapon)
{
	SetCrosshairHideDelay(iClient);
}

SetCrosshairHideDelay(iClient)
{
	g_fNextCrosshairHide[iClient] = GetEngineTime() + CROSSHAIR_HIDE_DELAY;
}

bool:CanHideCrosshair(iClient)
{
	if(g_fNextCrosshairHide[iClient] < GetEngineTime())
		return true;
	
	return false;
}

public OnPostThinkPost(iClient)
{
	if(!CanHideCrosshair(iClient))
		return;
	
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	
	if(!IsPlayerAlive(iClient))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", g_iHudBits[iClient]);
	PrintToChat(iClient, "[SM] When your crosshair is hidden you cannot switch weapons. Type !crosshair to unhide it.");
}

public Action:OnCrosshair(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(g_iHudBits[iClient] & HIDEHUD_HEALTH_ARMOR_XHAIR)
	{
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
		
		g_iHudBits[iClient] &= ~HIDEHUD_HEALTH_ARMOR_XHAIR;
		SetEntProp(iClient, Prop_Send, "m_iHideHUD", g_iHudBits[iClient]);
		
		PrintToChat(iClient, "[SM] You will now see your crosshair and health/weapons.");
	}
	else
	{
		g_iHudBits[iClient] |= HIDEHUD_HEALTH_ARMOR_XHAIR;
		
		if(CanHideCrosshair(iClient))
		{
			SetEntProp(iClient, Prop_Send, "m_iHideHUD", g_iHudBits[iClient]);
			PrintToChat(iClient, "[SM] When your crosshair is hidden you cannot switch weapons. Type !crosshair to unhide it.");
		}
		else
		{
			SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
			PrintToChat(iClient, "[SM] Your crosshair will hide when you stop switching weapons.");
		}
	}
	
	ClientCookies_SetCookie(iClient, CC_TYPE_HUD_BITS, g_iHudBits[iClient]);
	
	return Plugin_Handled;
}