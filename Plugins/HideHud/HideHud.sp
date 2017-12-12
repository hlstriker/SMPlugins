#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "HUD Menu";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Hide HUD elements via a menu",
	version = PLUGIN_VERSION,
	url = ""
}

//Hide Hud Flags

#define HIDEHUD_ALL (1<<2)
#define HIDEHUD_CHAT (1<<7)
#define HIDEHUD_CROSSHAIR (1<<8)
#define HIDEHUD_MISC (1<<4)
#define HIDEHUD_RADAR (1<<12)
#define HIDEHUD_TOP (1<<13)



enum
{
	MENUSELECT_ALL = 1,
	MENUSELECT_CHAT,
	MENUSELECT_CROSSHAIR,
	MENUSELECT_MISC
};


public OnPluginStart()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			PlayerHooks(iClient);
	}
	RegConsoleCmd("sm_hide_hud", OnHideHud, "Opens the Hide HUD menu");
	RegConsoleCmd("sm_hh", OnHideHud, "Opens the Hide HUD menu");
	
	RegConsoleCmd("sm_hide_chat", OnHideChat, "Toggle the chat");
	RegConsoleCmd("sm_hide_all", OnHideAll, "Toggle all HUD");
}

public OnClientPutInServer(iClient)
{
	PlayerHooks(iClient);
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
}

public Action:OnHideChat(iClient, iArgs)
{
	ToggleClientHideHudFlag(iClient, HIDEHUD_CHAT);
	return Plugin_Handled;
}

public Action:OnHideAll(iClient, iArgs)
{
	ToggleClientHideHudFlag(iClient, HIDEHUD_ALL);
	return Plugin_Handled;
}

public Action:OnHideHud(iClient, iArgs)
{
	DisplayMenu_HideHud(iClient);
	return Plugin_Handled;
}

ClientHasHideHudFlag(iClient, Flag)
{
	return (GetEntProp(iClient, Prop_Send, "m_iHideHUD") & Flag) == Flag;
}

ToggleClientHideHudFlag(iClient, Flag)
{
	SetEntProp(iClient, Prop_Send, "m_iHideHUD", GetEntProp(iClient, Prop_Send, "m_iHideHUD") ^ Flag);
}



DisplayMenu_HideHud(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_HideHud);
	SetMenuTitle(hMenu, "Hide Hud");
	
	decl String:szInfo[4], String:szBuffer[30];
	
	
	FormatEx(szBuffer, sizeof(szBuffer), "Chat: %s", ClientHasHideHudFlag(iClient, HIDEHUD_CHAT) ? "Hidden" : "Shown");
	IntToString(MENUSELECT_CHAT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "Crosshair: %s", ClientHasHideHudFlag(iClient, HIDEHUD_CROSSHAIR) ? "Hidden" : "Shown");
	IntToString(MENUSELECT_CROSSHAIR, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "Misc: %s", ClientHasHideHudFlag(iClient, HIDEHUD_MISC) ? "Hidden" : "Shown");
	IntToString(MENUSELECT_MISC, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "All: %s", ClientHasHideHudFlag(iClient, HIDEHUD_ALL) ? "Hidden" : "Shown");
	IntToString(MENUSELECT_ALL, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);

	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, iClient, 0);
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
	
	new iClient = iParam1;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENUSELECT_ALL:
		{
			DisplayMenu_HideAll(iClient);
			return;
		}
		case MENUSELECT_CHAT:	   ToggleClientHideHudFlag(iClient, HIDEHUD_CHAT);
		case MENUSELECT_CROSSHAIR: ToggleClientHideHudFlag(iClient, HIDEHUD_CROSSHAIR);
		case MENUSELECT_MISC:      ToggleClientHideHudFlag(iClient, HIDEHUD_MISC);
	}
	
	DisplayMenu_HideHud(iClient);
}

DisplayMenu_HideAll(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_HideAll);
	SetMenuTitle(hMenu, "ARE YOU SURE?");
	
	decl String:szInfo[4];
	
	AddMenuItem(hMenu, "", "Warning! Hiding all HUD will make this menu", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "invisible.  You can only make HUD visible again", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "by typing sm_hide_all in console.", ITEMDRAW_DISABLED);
	
	IntToString(MENUSELECT_ALL, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Yes, Disable all HUD");
	
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, iClient, 0);
}

public MenuHandle_HideAll(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	new iClient = iParam1;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENUSELECT_ALL: ToggleClientHideHudFlag(iClient, HIDEHUD_ALL);
	}
}
