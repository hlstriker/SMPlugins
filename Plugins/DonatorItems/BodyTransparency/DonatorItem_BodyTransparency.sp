#include <sourcemod>
#include <sdkhooks>
#include "../../../Libraries/Donators/donators"
#include "../../../Libraries/ClientCookies/client_cookies"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Donator Item: Body Transparency";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have a transparent body.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bHasTransparency[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("donator_item_body_transparency_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	new Handle:hConvar = FindConVar("sv_disable_immunity_alpha");
	if(hConvar != INVALID_HANDLE)
	{
		HookConVarChange(hConvar, OnConVarChanged);
		SetConVarInt(hConvar, 1);
	}
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarInt(hConvar, 1);
}

public OnClientConnected(iClient)
{
	g_bHasTransparency[iClient] = false;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(!ClientCookies_HasCookie(iClient, CC_TYPE_DONATOR_ITEM_BODY_TRANSPARENCY))
		return;
	
	g_bHasTransparency[iClient] = bool:ClientCookies_GetCookie(iClient, CC_TYPE_DONATOR_ITEM_BODY_TRANSPARENCY);
}

public OnClientPutInServer(iClient)
{
	if(!IsFakeClient(iClient))
		SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(!Donators_IsDonator(iClient))
		return;
	
	if(!g_bHasTransparency[iClient])
		return;
	
	SetTransparency(iClient);
}

SetTransparency(iEnt)
{
	SetEntityRenderMode(iEnt, RENDER_TRANSALPHA);
	SetEntityRenderColor(iEnt, _, _, _, 165);
}

ClearTransparency(iEnt)
{
	SetEntityRenderMode(iEnt, RENDER_NORMAL);
	SetEntityRenderColor(iEnt);
}


///////////////////
// START SETTINGS
///////////////////
public Donators_OnRegisterSettingsReady()
{
	Donators_RegisterSettings("Body Transparency", OnSettingsMenu);
}

public OnSettingsMenu(iClient)
{
	DisplayMenu_ToggleItems(iClient);
}

DisplayMenu_ToggleItems(iClient, iPosition=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_ToggleItems);
	SetMenuTitle(hMenu, "Body Transparency");
	
	decl String:szBuffer[32];
	Format(szBuffer, sizeof(szBuffer), "%sTransparent", g_bHasTransparency[iClient] ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, "", szBuffer);
	
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
	
	g_bHasTransparency[iParam1] = !g_bHasTransparency[iParam1];
	
	if(g_bHasTransparency[iParam1])
		SetTransparency(iParam1);
	else
		ClearTransparency(iParam1);
	
	ClientCookies_SetCookie(iParam1, CC_TYPE_DONATOR_ITEM_BODY_TRANSPARENCY, g_bHasTransparency[iParam1]);
	DisplayMenu_ToggleItems(iParam1, GetMenuSelectionPosition());
}