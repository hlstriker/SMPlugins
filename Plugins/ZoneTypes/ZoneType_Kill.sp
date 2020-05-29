#include <sourcemod>
#include <sdktools_functions>
#include "../../Libraries/ZoneManager/zone_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Kill";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of kill.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Kill";

enum MenuInfoType
{
	MENU_INFO_SET_NONE = 0,
	MENU_INFO_SET_ENABLED_TIMER,
	MENU_INFO_SET_DISABLED_TIMER,
};

new g_iEditingZoneID[MAXPLAYERS+1];
new MenuInfoType:g_iEditingType[MAXPLAYERS+1];

new Float:g_fRoundStartTime;


public OnPluginStart()
{
	CreateConVar("zone_type_kill_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_KILL, SZ_ZONE_TYPE_NAME, OnTouch, _, _, OnEditData);
}

public OnMapStart()
{
	g_fRoundStartTime = GetEngineTime();
}

public Event_CSPreRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_fRoundStartTime = GetEngineTime(); // We can't use the round_start event to set the roundstart time since the zones are created before that event is called.
}

public OnTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	if(!IsPlayerAlive(iOther))
		return;
	
	static iZoneID;
	iZoneID = GetZoneID(iZone);
	
	if(!ShouldKill(iZoneID))
		return;
	
	ForcePlayerSuicide(iOther);
}

bool:ShouldKill(iZoneID)
{
	static iEnabledTime, iDisabledTime;
	iEnabledTime = ZoneManager_GetDataInt(iZoneID, 1);
	iDisabledTime = ZoneManager_GetDataInt(iZoneID, 2);
	
	static bool:bHasEnabledTimer, bool:bSetEnabledTimer, bool:bHasDisabledTimer, bool:bSetDisabledTimer;
	bHasEnabledTimer = bool:iEnabledTime;
	bSetEnabledTimer = bool:((GetEngineTime() - g_fRoundStartTime) >= iEnabledTime);
	bHasDisabledTimer = bool:iDisabledTime;
	bSetDisabledTimer = bool:((GetEngineTime() - g_fRoundStartTime) >= iDisabledTime);
	
	if(bHasEnabledTimer && bHasDisabledTimer)
	{
		// If both timers were already set we need to find out which was set last.
		if(bSetEnabledTimer && bSetDisabledTimer)
		{
			if(iEnabledTime > iDisabledTime)
				return true;
			
			return false;
		}
		
		// If neither timers were set yet we need to find out which gets set first.
		else if(!bSetEnabledTimer && !bSetDisabledTimer)
		{
			if(iEnabledTime < iDisabledTime)
				return false;
			
			return true;
		}
		
		// If the enabled timer is set, disabled is not set, and vice versa.
		return bSetEnabledTimer;
	}
	else if(bHasEnabledTimer)
	{
		return bSetEnabledTimer;
	}
	else if(bHasDisabledTimer)
	{
		return !bSetDisabledTimer;
	}
	
	// Always kill if neither timer is set.
	return true;
}

public OnEditData(iClient, iZoneID)
{
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, "Edit kill data");
	
	decl String:szInfo[4], String:szBuffer[64];
	IntToString(_:MENU_INFO_SET_ENABLED_TIMER, szInfo, sizeof(szInfo));
	Format(szBuffer, sizeof(szBuffer), "Set enabled timer? [%s - %i]", ZoneManager_GetDataInt(iZoneID, 1) ? "Set" : "Not set", ZoneManager_GetDataInt(iZoneID, 1));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	IntToString(_:MENU_INFO_SET_DISABLED_TIMER, szInfo, sizeof(szInfo));
	Format(szBuffer, sizeof(szBuffer), "Set disabled timer? [%s - %i]", ZoneManager_GetDataInt(iZoneID, 2) ? "Set" : "Not set", ZoneManager_GetDataInt(iZoneID, 2));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		ZoneManager_ShowMenuEditZone(iClient);
		return;
	}
	
	g_iEditingType[iClient] = MENU_INFO_SET_NONE;
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
	
	DisplayMenu_EditTime(iParam1, g_iEditingZoneID[iParam1], MenuInfoType:StringToInt(szInfo));
}

DisplayMenu_EditTime(iClient, iZoneID, MenuInfoType:iEditingType)
{
	decl iIntNumber;
	switch(iEditingType)
	{
		case MENU_INFO_SET_ENABLED_TIMER: iIntNumber = 1;
		case MENU_INFO_SET_DISABLED_TIMER: iIntNumber = 2;
		default:
		{
			DisplayMenu_EditData(iClient, iZoneID);
			return;
		}
	}
	
	decl String:szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "Type the time in seconds in chat.\n%s timer set to %i seconds.", (iIntNumber == 1) ? "Enabled" : "Disabled", ZoneManager_GetDataInt(iZoneID, iIntNumber));
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditTime);
	SetMenuTitle(hMenu, szTitle);
	
	AddMenuItem(hMenu, "1", "Finished");
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuExitButton(hMenu, false);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		ZoneManager_ShowMenuEditZone(iClient);
		return;
	}
	
	g_iEditingType[iClient] = iEditingType;
	g_iEditingZoneID[iClient] = iZoneID;
	ZoneManager_RestartEditingZoneData(iClient);
}

public MenuHandle_EditTime(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
	
	DisplayMenu_EditData(iParam1, g_iEditingZoneID[iParam1]);
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_iEditingZoneID[iClient])
		return;
	
	switch(g_iEditingType[iClient])
	{
		case MENU_INFO_SET_ENABLED_TIMER:
		{
			new iInt = StringToInt(szArgs);
			if(iInt < 0)
			{
				PrintToChat(iClient, "[SM] Error: Invalid input.");
				return;
			}
			
			ZoneManager_SetDataInt(g_iEditingZoneID[iClient], 1, iInt);
			
			PrintToChat(iClient, "[SM] Set enabled timer to %i seconds.", iInt);
		}
		case MENU_INFO_SET_DISABLED_TIMER:
		{
			new iInt = StringToInt(szArgs);
			if(iInt < 0)
			{
				PrintToChat(iClient, "[SM] Error: Invalid input.");
				return;
			}
			
			ZoneManager_SetDataInt(g_iEditingZoneID[iClient], 2, iInt);
			
			PrintToChat(iClient, "[SM] Set disabled timer to %i seconds.", iInt);
		}
	}
	
	if(g_iEditingType[iClient] != MENU_INFO_SET_NONE)
		DisplayMenu_EditTime(iClient, g_iEditingZoneID[iClient], g_iEditingType[iClient]);
}
