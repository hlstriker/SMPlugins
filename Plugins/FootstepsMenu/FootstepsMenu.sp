#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/ClientCookies/client_cookies"
#include "../../Plugins/ClientFootsteps/client_footsteps"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Footsteps Menu";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to toggle footsteps.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("footsteps_menu_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_footsteps", OnFootsteps, "Opens the footsteps menu.");
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_FOOTSTEPS_MENU))
		ClientFootsteps_SetValue(iClient, FootstepValue:ClientCookies_GetCookie(iClient, CC_TYPE_FOOTSTEPS_MENU));
}

public Action:OnFootsteps(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_Footsteps(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_Footsteps(iClient)
{
	new FootstepValue:iCurValue = ClientFootsteps_GetValue(iClient);
	
	new Handle:hMenu = CreateMenu(MenuHandle_Footsteps);
	SetMenuTitle(hMenu, "Change footsteps");
	
	decl String:szInfo[2], String:szDisplay[32];
	IntToString(_:FOOTSTEP_VALUE_ENABLE_OWN_ONLY, szInfo, sizeof(szInfo));
	Format(szDisplay, sizeof(szDisplay), "%sEnable my footsteps only", (iCurValue == FOOTSTEP_VALUE_ENABLE_OWN_ONLY) ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, szInfo, szDisplay);
	
	IntToString(_:FOOTSTEP_VALUE_ENABLE_ALL, szInfo, sizeof(szInfo));
	Format(szDisplay, sizeof(szDisplay), "%sEnable all footsteps", (iCurValue == FOOTSTEP_VALUE_ENABLE_ALL) ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, szInfo, szDisplay);
	
	IntToString(_:FOOTSTEP_VALUE_DISABLE_ALL, szInfo, sizeof(szInfo));
	Format(szDisplay, sizeof(szDisplay), "%sDisable all footsteps", (iCurValue == FOOTSTEP_VALUE_DISABLE_ALL) ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, szInfo, szDisplay);
	
	IntToString(_:FOOTSTEP_VALUE_USE_SERVER_SETTINGS, szInfo, sizeof(szInfo));
	Format(szDisplay, sizeof(szDisplay), "%sUse server settings", (iCurValue == FOOTSTEP_VALUE_USE_SERVER_SETTINGS) ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, szInfo, szDisplay);
	
	if(!DisplayMenu(hMenu, iClient, 0))
		PrintToChat(iClient, "[SM] There are no options to select.");
}

public MenuHandle_Footsteps(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iSelection = StringToInt(szInfo);
	
	ClientFootsteps_SetValue(iParam1, FootstepValue:iSelection);
	ClientCookies_SetCookie(iParam1, CC_TYPE_FOOTSTEPS_MENU, iSelection);
	
	DisplayMenu_Footsteps(iParam1);
}