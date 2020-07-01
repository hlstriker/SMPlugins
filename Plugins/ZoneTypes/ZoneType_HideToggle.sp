#include <sourcemod>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Plugins/HidePlayers/hide_players"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Hide Toggle";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of hide toggle.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Hide Toggle";

new g_iEditingZoneID[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("zone_type_hide_toggle_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_HIDE_TOGGLE, SZ_ZONE_TYPE_NAME, _, OnStartTouch, _, OnEditData);
}

public OnStartTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	HidePlayers_SetClientHideOverride(iOther, ZoneManager_GetDataInt(GetZoneID(iZone), 1));
}

public OnEditData(iClient, iZoneID)
{
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	decl String:szTitle[256];
	FormatEx(szTitle, sizeof(szTitle), "Edit hide plugin status\n \nCurrently set to: %s",
		(ZoneManager_GetDataInt(iZoneID, 1) == HIDE_DISABLED) ? "The player can not use !hide" :
		(ZoneManager_GetDataInt(iZoneID, 1) == HIDE_DEFAULT) ? "Use the server's default hide value." : 
		(ZoneManager_GetDataInt(iZoneID, 1) == HIDE_ALL) ? "The player's !hide will hide all." : 
		(ZoneManager_GetDataInt(iZoneID, 1) == HIDE_TEAM_ONLY) ? "The player's !hide will hide team only." : "Unknown");
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, szTitle);
	
	AddMenuItem(hMenu, "", "Toggle status");
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		ZoneManager_ShowMenuEditZone(iClient);
		return;
	}
	
	g_iEditingZoneID[iClient] = iZoneID;
	ZoneManager_RestartEditingZoneData(iClient);
}

public MenuHandle_EditData(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_iEditingZoneID[iParam1] = 0;
		ZoneManager_FinishedEditingZoneData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			ZoneManager_ShowMenuEditZone(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	new iHideValue = ZoneManager_GetDataInt(g_iEditingZoneID[iParam1], 1) + 1;
	if(iHideValue > HIDE_TEAM_ONLY)
		iHideValue = HIDE_DISABLED;
	
	ZoneManager_SetDataInt(g_iEditingZoneID[iParam1], 1, iHideValue);
	
	DisplayMenu_EditData(iParam1, g_iEditingZoneID[iParam1]);
}