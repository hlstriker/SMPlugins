#include <sourcemod>
#include "../../../Libraries/ZoneManager/zone_manager"
#include "../Includes/speed_runs"
#include "zonetype_helper_startendlines"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Timer Start";
new const String:PLUGIN_VERSION[] = "1.6";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of timer start.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Timer Start";

enum MenuInfoType
{
	MENU_INFO_SET_NONE = 0,
	MENU_INFO_SET_NUMBER,
	MENU_INFO_SET_CUSTOM_START_NAME,
	MENU_INFO_SET_SPEED_CAP,
	MENU_INFO_SET_TELEPORT_DEST_NAME,
	MENU_INFO_SET_TARGETNAME_FILTER,
	MENU_INFO_SET_LINES
};

new g_iEditingZoneID[MAXPLAYERS+1];
new MenuInfoType:g_iEditingType[MAXPLAYERS+1];

#define DATA_STRING_START_NAME			1
#define DATA_STRING_TELEPORT_TARGETNAME	2
#define DATA_STRING_TARGETNAME_FILTER	3
#define DATA_STRING_TELEPORT_POSITION	4
//#define DATA_STRING_LINE_DATA			5 // Set in zonetype_helper_startendlines include.

new Handle:cvar_default_start_speed_cap;


public OnPluginStart()
{
	CreateConVar("zone_type_timer_start_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_default_start_speed_cap = FindConVar("speedruns_default_start_speed_cap")) == INVALID_HANDLE)
		cvar_default_start_speed_cap = CreateConVar("speedruns_default_start_speed_cap", DEFAULT_START_CAP_SPEED, "The default start zone speed cap.", _, true, -1.0);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_TIMER_START, SZ_ZONE_TYPE_NAME, OnTouch, OnStartTouch, OnEndTouch, OnEditData, OnTypeAssigned);
}

public OnTypeAssigned(iEnt, iZoneID)
{
	if(!ZoneManager_GetDataInt(iZoneID, 2))
		ZoneManager_SetDataInt(iZoneID, 2, GetConVarInt(cvar_default_start_speed_cap));
}

public OnTouch(iZone, iOther)
{
	static iZoneID;
	iZoneID = GetZoneID(iZone);
	
	// Only touch if they pass the filter check.
	static String:szFilter[MAX_ZONE_DATA_STRING_LENGTH];
	if(ZoneManager_GetDataString(iZoneID, DATA_STRING_TARGETNAME_FILTER, szFilter, sizeof(szFilter)) && szFilter[0])
	{
		static String:szTargetname[64];
		GetEntPropString(iOther, Prop_Data, "m_iName", szTargetname, sizeof(szTargetname));
		
		if(!StrEqual(szFilter, szTargetname, false))
			return;
	}
	
	SpeedRuns_TryCapSpeed(iOther, ZoneManager_GetDataInt(iZoneID, 2));
}

public OnStartTouch(iZone, iOther)
{
	new iZoneID = GetZoneID(iZone);
	
	// Only touch if they pass the filter check.
	static String:szFilter[MAX_ZONE_DATA_STRING_LENGTH];
	if(ZoneManager_GetDataString(iZoneID, DATA_STRING_TARGETNAME_FILTER, szFilter, sizeof(szFilter)) && szFilter[0])
	{
		static String:szTargetname[64];
		GetEntPropString(iOther, Prop_Data, "m_iName", szTargetname, sizeof(szTargetname));
		
		if(!StrEqual(szFilter, szTargetname, false))
			return;
	}
	
	SpeedRuns_TryStageFailed(iOther, ZoneManager_GetDataInt(iZoneID, 1));
}

public OnEndTouch(iZone, iOther)
{	
	new iZoneID = GetZoneID(iZone);
	
	// Only touch if they pass the filter check.
	static String:szFilter[MAX_ZONE_DATA_STRING_LENGTH];
	if(ZoneManager_GetDataString(iZoneID, DATA_STRING_TARGETNAME_FILTER, szFilter, sizeof(szFilter)) && szFilter[0])
	{
		static String:szTargetname[64];
		GetEntPropString(iOther, Prop_Data, "m_iName", szTargetname, sizeof(szTargetname));
		
		if(!StrEqual(szFilter, szTargetname, false))
			return;
	}
	
	SpeedRuns_ClientTouchStart(iOther, ZoneManager_GetDataInt(iZoneID, 1), iZoneID);
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
			FormatEx(szTitle, sizeof(szTitle), "Edit Start Number\n \nCurrently set to: %i\n \nType the number in chat.", ZoneManager_GetDataInt(iZoneID, 1));
		
		case MENU_INFO_SET_SPEED_CAP:
			FormatEx(szTitle, sizeof(szTitle), "Edit Speed Cap\n \nCurrently caps at: %i\n \nType the speed cap in chat (-1 for no cap)", ZoneManager_GetDataInt(iZoneID, 2));
		
		case MENU_INFO_SET_CUSTOM_START_NAME:
		{
			ZoneManager_GetDataString(iZoneID, DATA_STRING_START_NAME, szTitle, sizeof(szTitle));
			Format(szTitle, sizeof(szTitle), "Edit Custom Start Name\n \nCurrently set to:\n%s\n \nType the custom name in chat (-1 for no custom name)", szTitle);
		}
		
		case MENU_INFO_SET_TELEPORT_DEST_NAME:
		{
			new bool:bHasCustomOrigin;
			ZoneManager_GetDataString(iZoneID, DATA_STRING_TELEPORT_POSITION, szTitle, sizeof(szTitle));
			
			if(szTitle[0])
			{
				decl String:szExplode[3][16];
				new iNumExplodes = ExplodeString(szTitle, "/", szExplode, sizeof(szExplode), sizeof(szExplode[]));
				if(iNumExplodes == 3)
				{
					Format(szTitle, sizeof(szTitle), "%i, %i, %i", RoundFloat(StringToFloat(szExplode[0])), RoundFloat(StringToFloat(szExplode[1])), RoundFloat(StringToFloat(szExplode[2])));
					bHasCustomOrigin = true;
				}
			}
			
			if(!bHasCustomOrigin)
				ZoneManager_GetDataString(iZoneID, DATA_STRING_TELEPORT_TARGETNAME, szTitle, sizeof(szTitle));
			
			Format(szTitle, sizeof(szTitle), "Edit Custom Start Teleport Destination\n \nCurrently set to:\n%s\n \nTo teleport to current position:\nType <pos> in chat\n \nTo teleport to existing map entity:\nType entities targetname in chat\n \nType -1 to clear custom destination", szTitle);
		}
		
		case MENU_INFO_SET_TARGETNAME_FILTER:
		{
			ZoneManager_GetDataString(iZoneID, DATA_STRING_TARGETNAME_FILTER, szTitle, sizeof(szTitle));
			Format(szTitle, sizeof(szTitle), "Edit Targetname Filter\n \nCurrently set to:\n%s\n \nType the targetname in chat (-1 for no filter)", szTitle);
		}
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[4];
	IntToString(_:MENU_INFO_SET_NUMBER, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit start number.");
	
	IntToString(_:MENU_INFO_SET_SPEED_CAP, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit speed cap.");
	
	IntToString(_:MENU_INFO_SET_CUSTOM_START_NAME, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit custom start name.");
	
	IntToString(_:MENU_INFO_SET_TELEPORT_DEST_NAME, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit custom start teleport destination.");
	
	IntToString(_:MENU_INFO_SET_TARGETNAME_FILTER, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit targetname filter.");
	
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
		StartEndLines_DisplayLineMenu(iParam1, g_iEditingZoneID[iParam1], LINE_TYPE_START, OnEditData);
		return;
	}
	
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
			PrintToChat(iClient, "[SM] Set start number to: %i.", iInt);
		}
		case MENU_INFO_SET_SPEED_CAP:
		{
			new iInt = StringToInt(szArgs);
			if(!iInt)
			{
				PrintToChat(iClient, "[SM] Invalid input.");
				return;
			}
			
			ZoneManager_SetDataInt(g_iEditingZoneID[iClient], 2, iInt);
			PrintToChat(iClient, "[SM] Set speed cap to: %i.", iInt);
		}
		case MENU_INFO_SET_CUSTOM_START_NAME:
		{
			decl String:szDataString[MAX_ZONE_DATA_STRING_LENGTH];
			strcopy(szDataString, sizeof(szDataString), szArgs);
			TrimString(szDataString);
			
			if(!szDataString[0] || StrEqual(szDataString, "-1"))
			{
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_START_NAME, "");
				PrintToChat(iClient, "[SM] Removed custom start name.");
			}
			else
			{
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_START_NAME, szDataString);
				PrintToChat(iClient, "[SM] Set custom start name to: %s.", szDataString);
			}
		}
		case MENU_INFO_SET_TELEPORT_DEST_NAME:
		{
			decl String:szDataString[MAX_ZONE_DATA_STRING_LENGTH];
			strcopy(szDataString, sizeof(szDataString), szArgs);
			TrimString(szDataString);
			
			if(!szDataString[0] || StrEqual(szDataString, "-1"))
			{
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_TELEPORT_TARGETNAME, "");
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_TELEPORT_POSITION, "");
				PrintToChat(iClient, "[SM] Removed custom teleport destination.");
			}
			else
			{
				if(StrEqual(szDataString, "<pos>", false))
				{
					decl Float:fOrigin[3];
					GetClientAbsOrigin(iClient, fOrigin);
					Format(szDataString, sizeof(szDataString), "%f/%f/%f", fOrigin[0], fOrigin[1], fOrigin[2]);
					
					ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_TELEPORT_POSITION, szDataString);
					PrintToChat(iClient, "[SM] Set teleport position to: %i, %i, %i.", RoundFloat(fOrigin[0]), RoundFloat(fOrigin[1]), RoundFloat(fOrigin[2]));
				}
				else
				{
					ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_TELEPORT_POSITION, "");
					ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_TELEPORT_TARGETNAME, szDataString);
					PrintToChat(iClient, "[SM] Set teleport targetname to: %s.", szDataString);
				}
			}
		}
		case MENU_INFO_SET_TARGETNAME_FILTER:
		{
			decl String:szDataString[MAX_ZONE_DATA_STRING_LENGTH];
			strcopy(szDataString, sizeof(szDataString), szArgs);
			TrimString(szDataString);
			
			if(!szDataString[0] || StrEqual(szDataString, "-1"))
			{
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_TARGETNAME_FILTER, "");
				PrintToChat(iClient, "[SM] Removed targetname filter.");
			}
			else
			{
				ZoneManager_SetDataString(g_iEditingZoneID[iClient], DATA_STRING_TARGETNAME_FILTER, szDataString);
				PrintToChat(iClient, "[SM] Set targetname filter to: %s.", szDataString);
			}
		}
	}
	
	if(g_iEditingType[iClient] != MENU_INFO_SET_NONE)
		DisplayMenu_EditData(iClient, g_iEditingZoneID[iClient]);
}