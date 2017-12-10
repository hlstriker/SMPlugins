#include <sourcemod>

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

#define HIDEHUD_ALL 1<<2
#define HIDEHUD_CHAT 1<<7
#define HIDEHUD_CROSSHAIR 1<<8
#define HIDEHUD_MISC 1<<4



enum
{
	MENUSELECT_ALL = 1,
	MENUSELECT_CHAT,
	MENUSELECT_CROSSHAIR,
	MENUSELECT_MISC
};


public OnPluginStart()
{
	RegConsoleCmd("sm_hide_hud", OnHideHud, "Opens the Hide HUD menu");
	RegConsoleCmd("sm_hh", OnHideHud, "Opens the Hide HUD menu");
	
	RegConsoleCmd("sm_hide_chat", OnHideChat, "Toggle the chat");
	RegConsoleCmd("sm_hud_all", OnHudAll, "Toggle all HUD");
}

public Action:OnHideChat(iClient, iArgs)
{
	ToggleClientHideHudFlag(iClient, HIDEHUD_CHAT);
}

public Action:OnHudAll(iClient, iArgs)
{
	ToggleClientHideHudFlag(iClient, HIDEHUD_ALL);
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

	AddMenuItem(hMenu, "", "To unhide All, press the", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "same button again or type", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "sm_hud_all in console", ITEMDRAW_DISABLED);
	
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
		case MENUSELECT_ALL:	   ToggleClientHideHudFlag(iClient, HIDEHUD_ALL);
		case MENUSELECT_CHAT:	   ToggleClientHideHudFlag(iClient, HIDEHUD_CHAT);
		case MENUSELECT_CROSSHAIR: ToggleClientHideHudFlag(iClient, HIDEHUD_CROSSHAIR);
		case MENUSELECT_MISC:      ToggleClientHideHudFlag(iClient, HIDEHUD_MISC);
	}
	
	DisplayMenu_HideHud(iClient);
}
