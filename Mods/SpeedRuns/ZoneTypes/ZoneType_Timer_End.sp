#include <sourcemod>
#include "../../../Libraries/ZoneManager/zone_manager"
#include "../Includes/speed_runs"
#include "zonetype_helper_startendlines"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Timer End";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of timer end.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Timer End";

enum MenuInfoType
{
	MENU_INFO_SET_NONE = 0,
	MENU_INFO_SET_NUMBER,
	MENU_INFO_SET_FINAL_END,
	MENU_INFO_SET_TARGETNAME_FILTER,
	MENU_INFO_SET_LINES
};

new g_iEditingZoneID[MAXPLAYERS+1];
new MenuInfoType:g_iEditingType[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("zone_type_timer_end_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_TIMER_END, SZ_ZONE_TYPE_NAME, _, OnStartTouch, _, OnEditData);
}

public OnStartTouch(iZone, iOther)
{
	new iZoneID = GetZoneID(iZone);
	
	// Only touch if they pass the filter check.
	static String:szFilter[MAX_ZONE_DATA_STRING_LENGTH];
	if(ZoneManager_GetDataString(iZoneID, 3, szFilter, sizeof(szFilter)) && szFilter[0])
	{
		static String:szTargetname[64];
		GetEntPropString(iOther, Prop_Data, "m_iName", szTargetname, sizeof(szTargetname));
		
		if(!StrEqual(szFilter, szTargetname, false))
			return;
	}
	
	SpeedRuns_ClientTouchEnd(iOther, ZoneManager_GetDataInt(iZoneID, 1), bool:ZoneManager_GetDataInt(iZoneID, 2));
}

public OnEditData(iClient, iZoneID)
{
	g_iEditingType[iClient] = MENU_INFO_SET_NUMBER;
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	decl String:szTitle[1024];
	switch(g_iEditingType[iClient])
	{
		case MENU_INFO_SET_NUMBER:
			FormatEx(szTitle, sizeof(szTitle), "Edit End Number\n \nCurrently set to: %i", ZoneManager_GetDataInt(iZoneID, 1));
		
		case MENU_INFO_SET_TARGETNAME_FILTER:
		{
			ZoneManager_GetDataString(iZoneID, 3, szTitle, sizeof(szTitle));
			Format(szTitle, sizeof(szTitle), "Edit Targetname Filter\n \nCurrently set to:\n%s\n \nType the targetname in chat (-1 for no filter)", szTitle);
		}
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[4];
	IntToString(_:MENU_INFO_SET_NUMBER, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit end number.");
	
	IntToString(_:MENU_INFO_SET_TARGETNAME_FILTER, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit targetname filter.");
	
	IntToString(_:MENU_INFO_SET_FINAL_END, szInfo, sizeof(szInfo));
	Format(szTitle, sizeof(szTitle), "Is final end of regular stages? (select \"No\" for bonus end) [%s]", ZoneManager_GetDataInt(iZoneID, 2) ? "Yes" : "No");
	AddMenuItem(hMenu, szInfo, szTitle);
	
	IntToString(_:MENU_INFO_SET_LINES, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit line data.");
	
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
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new MenuInfoType:iType = MenuInfoType:StringToInt(szInfo);
	
	if(iType == MENU_INFO_SET_LINES)
	{
		g_iEditingType[iParam1] = MENU_INFO_SET_NONE;
		StartEndLines_DisplayLineMenu(iParam1, g_iEditingZoneID[iParam1], LINE_TYPE_END, OnEditData);
		return;
	}
	
	if(iType == MENU_INFO_SET_FINAL_END)
		ZoneManager_SetDataInt(g_iEditingZoneID[iParam1], 2, !ZoneManager_GetDataInt(g_iEditingZoneID[iParam1], 2));
	else
		g_iEditingType[iParam1] = iType;
		
	DisplayMenu_EditData(iParam1, g_iEditingZoneID[iParam1]);
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_iEditingZoneID[iClient])
		return;
	
	switch(g_iEditingType[iClient])
	{
		case MENU_INFO_SET_NUMBER:
		{
			new iInt = StringToInt(szArgs);
			if(!iInt)
			{
				PrintToChat(iClient, "[SM] Error: Invalid input.");
				return;
			}
			
			if(iInt < 1 || iInt > MAX_STAGES)
			{
				PrintToChat(iClient, "[SM] Error: Must be between 1 and %i.", MAX_STAGES);
				return;
			}
			
			ZoneManager_SetDataInt(g_iEditingZoneID[iClient], 1, iInt);
			PrintToChat(iClient, "[SM] Set end number to: %i.", iInt);
		}
		case MENU_INFO_SET_TARGETNAME_FILTER:
		{
			decl String:szDataString[MAX_ZONE_DATA_STRING_LENGTH];
			strcopy(szDataString, sizeof(szDataString), szArgs);
			TrimString(szDataString);
			
			if(!szDataString[0] || StrEqual(szDataString, "-1"))
			{
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], 3, "");
				PrintToChat(iClient, "[SM] Removed targetname filter.");
			}
			else
			{
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], 3, szDataString);
				PrintToChat(iClient, "[SM] Set targetname filter to: %s.", szDataString);
			}
		}
	}
	
	if(g_iEditingType[iClient] != MENU_INFO_SET_NONE)
		DisplayMenu_EditData(iClient, g_iEditingZoneID[iClient]);
}