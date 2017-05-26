#include <sourcemod>
#include "../../Libraries/ZoneManager/zone_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Flashlight";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of flashlight.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Flashlight";

#define EF_DIMLIGHT		4

new g_iEditingZoneID[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("zone_type_flashlight_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_FLASHLIGHT, SZ_ZONE_TYPE_NAME, _, OnStartTouch, _, OnEditData);
}

public OnStartTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	static iZoneID;
	iZoneID = GetZoneID(iZone);
	
	if(ZoneManager_GetDataInt(iZoneID, 1))
		SetEntProp(iOther, Prop_Send, "m_fEffects", GetEntProp(iOther, Prop_Send, "m_fEffects") | EF_DIMLIGHT);
	else
		SetEntProp(iOther, Prop_Send, "m_fEffects", GetEntProp(iOther, Prop_Send, "m_fEffects") & ~EF_DIMLIGHT);
}

public OnEditData(iClient, iZoneID)
{
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	decl String:szBuffer[64];
	FormatEx(szBuffer, sizeof(szBuffer), "Edit flashlight data\n \nFlashlight will turn: %s", ZoneManager_GetDataInt(iZoneID, 1) ? "ON" : "OFF");
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, szBuffer);
	
	AddMenuItem(hMenu, "", "Toggle flashlight");
	
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
	
	ZoneManager_SetDataInt(g_iEditingZoneID[iParam1], 1, !ZoneManager_GetDataInt(g_iEditingZoneID[iParam1], 1));
	DisplayMenu_EditData(iParam1, g_iEditingZoneID[iParam1]);
}