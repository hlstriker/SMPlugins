#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/Donators/donators"
#include "../../Libraries/ClientCookies/client_cookies"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Donator Item: Body Size";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to set their body size.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

enum
{
	BODY_SIZE_INDEX_SKINNY = 0,
	BODY_SIZE_INDEX_FATSO,
	NUM_BODY_SIZES
};

new const String:g_szBodySizeNames[][] =
{
	"Skinny",
	"Fatso"
};

new g_iItemBits[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("donator_item_body_size_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnClientConnected(iClient)
{
	g_iItemBits[iClient] = 0;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(!ClientCookies_HasCookie(iClient, CC_TYPE_DONATOR_ITEM_BODY_SIZE))
		return;
	
	g_iItemBits[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_DONATOR_ITEM_BODY_SIZE);
}

GetRandomActivatedItemIndex(iClient)
{
	if(!Donators_IsDonator(iClient))
		return -1;
	
	decl iActivated[NUM_BODY_SIZES];
	new iNumFound;
	
	for(new i=0; i<NUM_BODY_SIZES; i++)
	{
		if(!(g_iItemBits[iClient] & (1<<i)))
			continue;
		
		iActivated[iNumFound++] = i;
	}
	
	if(!iNumFound)
		return -1;
	
	return iActivated[GetRandomInt(0, iNumFound-1)];
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
	
	new iItemIndex = GetRandomActivatedItemIndex(iClient);
	if(iItemIndex < 0)
		return;
	
	ScaleClientBySizeIndex(iClient, iItemIndex);
}

ScaleClientBySizeIndex(iClient, iItemIndex)
{
	switch(iItemIndex)
	{
		case BODY_SIZE_INDEX_SKINNY: ScaleClient_Skinny(iClient);
		case BODY_SIZE_INDEX_FATSO: ScaleClient_Fatso(iClient);
	}
}

ScaleEntity(iEnt, iScaleType=0, Float:fScale=1.0)
{
	SetEntProp(iEnt, Prop_Send, "m_ScaleType", iScaleType);
	SetEntPropFloat(iEnt, Prop_Send, "m_flModelScale", fScale);
}

ScaleClient_Skinny(iClient)
{
	ScaleEntity(iClient, 1, 0.5);
}

ScaleClient_Fatso(iClient)
{
	ScaleEntity(iClient, 1, 1.6);
}


///////////////////
// START SETTINGS
///////////////////
public Donators_OnRegisterSettingsReady()
{
	Donators_RegisterSettings("Body Size", OnSettingsMenu);
}

public OnSettingsMenu(iClient)
{
	DisplayMenu_ToggleItems(iClient);
}

DisplayMenu_ToggleItems(iClient, iPosition=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_ToggleItems);
	SetMenuTitle(hMenu, "Body Size");
	
	decl String:szInfo[6], String:szBuffer[32];
	Format(szBuffer, sizeof(szBuffer), "%sNone", (g_iItemBits[iClient] == 0) ? "[\xE2\x9C\x93] " : "");
	AddMenuItem(hMenu, "-1", szBuffer);
	
	for(new i=0; i<NUM_BODY_SIZES; i++)
	{
		IntToString(i, szInfo, sizeof(szInfo));
		Format(szBuffer, sizeof(szBuffer), "%s%s", (g_iItemBits[iClient] & (1<<i)) ? "[\xE2\x9C\x93] " : "", g_szBodySizeNames[i]);
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
	
	if(iItemIndex < 0)
	{
		g_iItemBits[iParam1] = 0;
		ScaleEntity(iParam1, 1, 1.0);
	}
	else
	{
		g_iItemBits[iParam1] ^= (1<<iItemIndex);
		
		if(g_iItemBits[iParam1] & (1<<iItemIndex))
			ScaleClientBySizeIndex(iParam1, iItemIndex);
		else
			ScaleEntity(iParam1, 1, 1.0);
	}
	
	ClientCookies_SetCookie(iParam1, CC_TYPE_DONATOR_ITEM_BODY_SIZE, g_iItemBits[iParam1]);
	DisplayMenu_ToggleItems(iParam1, GetMenuSelectionPosition());
}