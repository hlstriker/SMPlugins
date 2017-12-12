#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/ClientCookies/client_cookies"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Hide HUD";
new const String:PLUGIN_VERSION[] = "2.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker & Hymns For Disco",
	description = "Hides parts of the HUD.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define HIDEHUD_ALL						(1<<2)	// When crosshair is hidden you can't switch weapons.
#define HIDEHUD_HEALTH_ARMOR_XHAIR_WPNS	(1<<4)	// When crosshair is hidden you can't switch weapons.
#define HIDEHUD_CHAT					(1<<7)
#define HIDEHUD_RADAR					(1<<12)
#define HIDEHUD_ROUNDTIME_AVATARS		(1<<13)

enum
{
	MENUSELECT_ALL = 1,
	MENUSELECT_HEALTH_ARMOR_XHAIR_WPNS,
	MENUSELECT_CHAT,
	MENUSELECT_RADAR,
	MENUSELECT_ROUNDTIME_AVATARS
};

new g_iHudBits[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("hide_hud_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			PlayerHooks(iClient);
	}
	
	RegConsoleCmd("sm_hh", OnHideHudMenu, "Hide Hud: Opens the menu.");
	RegConsoleCmd("sm_hh_unhide", OnHideHudUnhide, "Hide Hud: Unhides everything.");
}

public OnClientPutInServer(iClient)
{
	PlayerHooks(iClient);
}

public OnClientConnected(iClient)
{
	g_iHudBits[iClient] = ValidateBits(HIDEHUD_RADAR | HIDEHUD_ROUNDTIME_AVATARS);
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_HUD_BITS))
		g_iHudBits[iClient] = ValidateBits(ClientCookies_GetCookie(iClient, CC_TYPE_HUD_BITS));
}

ValidateBits(iBits)
{
	return (iBits & (HIDEHUD_ALL | HIDEHUD_HEALTH_ARMOR_XHAIR_WPNS | HIDEHUD_CHAT | HIDEHUD_RADAR | HIDEHUD_ROUNDTIME_AVATARS));
}

PlayerHooks(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", g_iHudBits[iClient]);
}

public Action:OnHideHudUnhide(iClient, iArgs)
{
	if(!iClient)
		return Plugin_Handled;
	
	g_iHudBits[iClient] = 0;
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", g_iHudBits[iClient]);
	SaveHideHudCookie(iClient);
	
	return Plugin_Handled;
}

public Action:OnHideHudMenu(iClient, iArgs)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_HideHud(iClient);
	return Plugin_Handled;
}

DisplayMenu_HideHud(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_HideHud);
	SetMenuTitle(hMenu, "Hide HUD Elements\n \nUse the command sm_hh_unhide in console\nto show all elements again.\n ");
	
	decl String:szInfo[4], String:szBuffer[48];
	FormatEx(szBuffer, sizeof(szBuffer), "%sRadar", (g_iHudBits[iClient] & HIDEHUD_RADAR) ? "[\xE2\x9C\x93] " : "");
	IntToString(MENUSELECT_RADAR, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "%sRound time, Avatars", (g_iHudBits[iClient] & HIDEHUD_ROUNDTIME_AVATARS) ? "[\xE2\x9C\x93] " : "");
	IntToString(MENUSELECT_ROUNDTIME_AVATARS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "%sHealth, Armor, Crosshair, Weapons", (g_iHudBits[iClient] & HIDEHUD_HEALTH_ARMOR_XHAIR_WPNS) ? "[\xE2\x9C\x93] " : "");
	IntToString(MENUSELECT_HEALTH_ARMOR_XHAIR_WPNS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "%sChat", (g_iHudBits[iClient] & HIDEHUD_CHAT) ? "[\xE2\x9C\x93] " : "");
	IntToString(MENUSELECT_CHAT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	// Don't add "everything" since the combination of the others already allow this with fewer issues.
	/*
	FormatEx(szBuffer, sizeof(szBuffer), "%sEverything", (g_iHudBits[iClient] & HIDEHUD_ALL) ? "[\xE2\x9C\x93] " : "");
	IntToString(MENUSELECT_ALL, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	*/
	
	DisplayMenuAtItem(hMenu, iClient, iStartItem, 0);
}

public MenuHandle_HideHud(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iSelected = StringToInt(szInfo);
	switch(iSelected)
	{
		case MENUSELECT_ALL:						ToggleClientHideHudBit(iParam1, HIDEHUD_ALL);
		case MENUSELECT_HEALTH_ARMOR_XHAIR_WPNS:	ToggleClientHideHudBit(iParam1, HIDEHUD_HEALTH_ARMOR_XHAIR_WPNS);
		case MENUSELECT_CHAT:						ToggleClientHideHudBit(iParam1, HIDEHUD_CHAT);
		case MENUSELECT_RADAR:						ToggleClientHideHudBit(iParam1, HIDEHUD_RADAR);
		case MENUSELECT_ROUNDTIME_AVATARS:			ToggleClientHideHudBit(iParam1, HIDEHUD_ROUNDTIME_AVATARS);
	}
	
	if((iSelected == MENUSELECT_ALL && (g_iHudBits[iParam1] & HIDEHUD_ALL))
	|| (iSelected == MENUSELECT_HEALTH_ARMOR_XHAIR_WPNS && (g_iHudBits[iParam1] & HIDEHUD_HEALTH_ARMOR_XHAIR_WPNS)))
	{
		CPrintToChat(iParam1, "{red}WARNING: {olive}You will not be able to switch weapons with this element hidden.");
	}
	
	DisplayMenu_HideHud(iParam1, GetMenuSelectionPosition());
}

ToggleClientHideHudBit(iClient, iBit)
{
	g_iHudBits[iClient] ^= iBit;
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", g_iHudBits[iClient]);
	SaveHideHudCookie(iClient);
}

SaveHideHudCookie(iClient)
{
	// Do not save bits that hide critical parts of the hud or prevent weapon switching in the cookie.
	new iNewBits = g_iHudBits[iClient];
	iNewBits &= ~HIDEHUD_ALL;
	iNewBits &= ~HIDEHUD_HEALTH_ARMOR_XHAIR_WPNS;
	iNewBits &= ~HIDEHUD_CHAT;
	
	ClientCookies_SetCookie(iClient, CC_TYPE_HUD_BITS, iNewBits);
}