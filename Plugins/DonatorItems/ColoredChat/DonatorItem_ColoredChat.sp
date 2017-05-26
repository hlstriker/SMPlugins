#include <sourcemod>
#include "../../Libraries/Donators/donators"
#include "../../Libraries/ClientCookies/client_cookies"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Donator Item: Colored Chat";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have colored chat.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new g_iLoadedColorIndex[MAXPLAYERS+1];

new const String:g_ColorChat_Names[][] =
{
	"Olive",
	"Green",
	"Light green",

	"Red",
	"Light red",
	"Blue",
	"Yellow",
	"Purple"
};

new const g_ColorChat_Bytes[] =
{
	0x06,	// Olive
	0x04,	// Green
	0x05,	// Light green
	0x02,	// Red
	0x07,	// Light red
	0x0B,	// Blue
	0x09,	// Yellow
	0x0E	// Purple
};


public OnPluginStart()
{
	CreateConVar("donator_item_colored_chat_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnClientConnected(iClient)
{
	g_iLoadedColorIndex[iClient] = -1;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(!ClientCookies_HasCookie(iClient, CC_TYPE_DONATOR_ITEM_COLORED_CHAT))
		return;
	
	g_iLoadedColorIndex[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_DONATOR_ITEM_COLORED_CHAT);
	
	if(g_iLoadedColorIndex[iClient] < -1 || g_iLoadedColorIndex[iClient] >= sizeof(g_ColorChat_Bytes))
		g_iLoadedColorIndex[iClient] = -1;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("donatoritem_colored_chat");
	CreateNative("DItemColoredChat_GetColorByte", _DItemColoredChat_GetColorByte);
	
	return APLRes_Success;
}

public _DItemColoredChat_GetColorByte(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
		return 0;
	
	new iClient = GetNativeCell(1);
	if(!Donators_IsDonator(iClient))
		return 0;
	
	if(g_iLoadedColorIndex[iClient] < 0)
		return 0;
	
	return g_ColorChat_Bytes[g_iLoadedColorIndex[iClient]];
}


///////////////////
// START SETTINGS
///////////////////
public Donators_OnRegisterSettingsReady()
{
	Donators_RegisterSettings("Colored Chat", OnSettingsMenu);
}

public OnSettingsMenu(iClient)
{
	DisplayMenu_ToggleItems(iClient);
}

DisplayMenu_ToggleItems(iClient, iPosition=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_ToggleItems);
	SetMenuTitle(hMenu, "Colored Chat");
	
	decl String:szInfo[6], String:szBuffer[64];
	Format(szBuffer, sizeof(szBuffer), "%sNone", (g_iLoadedColorIndex[iClient] == -1) ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, "-1", szBuffer);
	
	for(new i=0; i<sizeof(g_ColorChat_Names); i++)
	{
		IntToString(i, szInfo, sizeof(szInfo));
		Format(szBuffer, sizeof(szBuffer), "%s%s", (g_iLoadedColorIndex[iClient] == i) ? "[\xE2\x9C\x93] " : "", g_ColorChat_Names[i]);
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iPosition, 0))
	{
		CPrintToChat(iClient, "{green}-- {red}This category has no items.");
		Donators_OpenSettingsMenu(iClient);
		return;
	}
}

public MenuHandle_ToggleItems(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		Donators_OpenSettingsMenu(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iItemIndex = StringToInt(szInfo);
	
	if(iItemIndex == g_iLoadedColorIndex[iParam1])
	{
		g_iLoadedColorIndex[iParam1] = -1;
	}
	else
	{
		g_iLoadedColorIndex[iParam1] = iItemIndex;
	}
	
	ClientCookies_SetCookie(iParam1, CC_TYPE_DONATOR_ITEM_COLORED_CHAT, iItemIndex);
	DisplayMenu_ToggleItems(iParam1, GetMenuSelectionPosition());
}