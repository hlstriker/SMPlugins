#include <sourcemod>
#include "../../Libraries/ZoneManager/zone_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Blockade";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of blockade.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Blockade";

new const FSOLID_NOT_SOLID = 0x0004;

enum MenuInfoType
{
	MENU_INFO_SET_NONE = 0,
	MENU_INFO_SET_SOLID_TIMER,
	MENU_INFO_SET_NOT_SOLID_TIMER,
};

new g_iEditingZoneID[MAXPLAYERS+1];
new MenuInfoType:g_iEditingType[MAXPLAYERS+1];

new Float:g_fRoundStartTime;
new Float:g_fNextFrameCheck;

new Handle:g_aZones;
enum _:Zone
{
	Zone_ID,
	bool:Zone_HasSolidTimer,
	bool:Zone_SetSolidTimer,
	bool:Zone_HasNotSolidTimer,
	bool:Zone_SetNotSolidTimer
};

new bool:g_bReturnInTypeAssignedCallback;


public OnPluginStart()
{
	CreateConVar("zone_type_blockade_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
	
	g_aZones = CreateArray(Zone);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_BLOCKADE, SZ_ZONE_TYPE_NAME, _, _, _, OnEditData, OnTypeAssigned, OnTypeUnassigned);
}

public OnTypeAssigned(iEnt, iZoneID)
{
	if(g_bReturnInTypeAssignedCallback)
		return;
	
	AddZoneToArray(iZoneID);
}

public OnTypeUnassigned(iEnt, iZoneID)
{
	SetSolid(iZoneID, false, false);
	RemoveZoneFromArray(iZoneID);
}

SetSolid(iZoneID, bool:bIsSolid=true, bool:bRecreateZone=true)
{
	decl iEnt, iFlags;
	if(bRecreateZone)
	{
		// We must get the old entities solid flags before recreating it.
		iEnt = ZoneManager_GetZoneEntity(iZoneID);
		iFlags = GetEntProp(iEnt, Prop_Send, "m_usSolidFlags");
		
		g_bReturnInTypeAssignedCallback = true;
		iEnt = ZoneManager_RecreateZone(iZoneID);
		g_bReturnInTypeAssignedCallback = false;
	}
	else
	{
		iEnt = ZoneManager_GetZoneEntity(iZoneID);
		iFlags = GetEntProp(iEnt, Prop_Send, "m_usSolidFlags");
	}
	
	if(iEnt < 1)
		return;
	
	if(bIsSolid)
		iFlags &= ~FSOLID_NOT_SOLID;
	else
		iFlags |= FSOLID_NOT_SOLID;
	
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", iFlags);
}

AddZoneToArray(iZoneID)
{
	RemoveZoneFromArray(iZoneID);
	
	new iSolidTime = ZoneManager_GetDataInt(iZoneID, 1);
	new iNotSolidTime = ZoneManager_GetDataInt(iZoneID, 2);
	
	decl eZone[Zone];
	eZone[Zone_ID] = iZoneID;
	eZone[Zone_HasSolidTimer] = bool:iSolidTime;
	eZone[Zone_SetSolidTimer] = bool:((GetEngineTime() - g_fRoundStartTime) >= iSolidTime);
	eZone[Zone_HasNotSolidTimer] = bool:iNotSolidTime;
	eZone[Zone_SetNotSolidTimer] = bool:((GetEngineTime() - g_fRoundStartTime) >= iNotSolidTime);
	
	// Don't add to array if neither timer is set.
	if(!eZone[Zone_HasSolidTimer] && !eZone[Zone_HasNotSolidTimer])
	{
		SetSolid(iZoneID, true);
		return;
	}
	
	if(eZone[Zone_HasSolidTimer] && eZone[Zone_HasNotSolidTimer])
	{
		// If both timers were already set we need to find out which was set last to set its solidity.
		if(eZone[Zone_SetSolidTimer] && eZone[Zone_SetNotSolidTimer])
		{
			if(iSolidTime > iNotSolidTime)
				SetSolid(iZoneID, true);
			else
				SetSolid(iZoneID, false);
		}
		
		// If neither timers were set yet we need to find out which gets set first to set its solidity.
		else if(!eZone[Zone_SetSolidTimer] && !eZone[Zone_SetNotSolidTimer])
		{
			if(iSolidTime < iNotSolidTime)
				SetSolid(iZoneID, false);
			else
				SetSolid(iZoneID, true);
		}
	}
	else if(eZone[Zone_HasSolidTimer])
	{
		SetSolid(iZoneID, false);
	}
	else if(eZone[Zone_HasNotSolidTimer])
	{
		SetSolid(iZoneID, true);
	}
	
	PushArrayArray(g_aZones, eZone);
}

RemoveZoneFromArray(iZoneID)
{
	decl eZone[Zone];
	for(new i=0; i<GetArraySize(g_aZones); i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		
		if(eZone[Zone_ID] != iZoneID)
			continue;
		
		RemoveFromArray(g_aZones, i);
		break;
	}
}

public OnEditData(iClient, iZoneID)
{
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, "Edit blockade data");
	
	decl String:szInfo[4], String:szBuffer[64];
	IntToString(_:MENU_INFO_SET_SOLID_TIMER, szInfo, sizeof(szInfo));
	Format(szBuffer, sizeof(szBuffer), "Set solid timer? [%s - %i]", ZoneManager_GetDataInt(iZoneID, 1) ? "Set" : "Not set", ZoneManager_GetDataInt(iZoneID, 1));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	IntToString(_:MENU_INFO_SET_NOT_SOLID_TIMER, szInfo, sizeof(szInfo));
	Format(szBuffer, sizeof(szBuffer), "Set not-solid timer? [%s - %i]", ZoneManager_GetDataInt(iZoneID, 2) ? "Set" : "Not set", ZoneManager_GetDataInt(iZoneID, 2));
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
		case MENU_INFO_SET_SOLID_TIMER: iIntNumber = 1;
		case MENU_INFO_SET_NOT_SOLID_TIMER: iIntNumber = 2;
		default:
		{
			DisplayMenu_EditData(iClient, iZoneID);
			return;
		}
	}
	
	decl String:szTitle[128];
	FormatEx(szTitle, sizeof(szTitle), "Type the time in seconds in chat.\n%s timer set to %i seconds.", (iIntNumber == 1) ? "Solid" : "Not-solid", ZoneManager_GetDataInt(iZoneID, iIntNumber));
	
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
		case MENU_INFO_SET_SOLID_TIMER:
		{
			new iInt = StringToInt(szArgs);
			if(iInt < 0)
			{
				PrintToChat(iClient, "[SM] Error: Invalid input.");
				return;
			}
			
			ZoneManager_SetDataInt(g_iEditingZoneID[iClient], 1, iInt);
			AddZoneToArray(g_iEditingZoneID[iClient]);
			
			PrintToChat(iClient, "[SM] Set solid timer to %i seconds.", iInt);
		}
		case MENU_INFO_SET_NOT_SOLID_TIMER:
		{
			new iInt = StringToInt(szArgs);
			if(iInt < 0)
			{
				PrintToChat(iClient, "[SM] Error: Invalid input.");
				return;
			}
			
			ZoneManager_SetDataInt(g_iEditingZoneID[iClient], 2, iInt);
			AddZoneToArray(g_iEditingZoneID[iClient]);
			
			PrintToChat(iClient, "[SM] Set not-solid timer to %i seconds.", iInt);
		}
	}
	
	if(g_iEditingType[iClient] != MENU_INFO_SET_NONE)
		DisplayMenu_EditTime(iClient, g_iEditingZoneID[iClient], g_iEditingType[iClient]);
}

public OnMapStart()
{
	ClearArray(g_aZones);
	g_fRoundStartTime = GetEngineTime();
}

public Event_CSPreRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	ClearArray(g_aZones);
	g_fRoundStartTime = GetEngineTime(); // We can't use the round_start event to set the roundstart time since the zones are created before that event is called.
}

public OnGameFrame()
{
	static iArraySize;
	iArraySize = GetArraySize(g_aZones);
	if(!iArraySize)
		return;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextFrameCheck)
		return;
	
	g_fNextFrameCheck = fCurTime + 1.0;
	
	static eZone[Zone], i, bool:bDataChanged;
	for(i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		bDataChanged = false;
		
		if(eZone[Zone_HasSolidTimer] && !eZone[Zone_SetSolidTimer])
		{
			if((fCurTime - g_fRoundStartTime) >= ZoneManager_GetDataInt(eZone[Zone_ID], 1))
			{
				SetSolid(eZone[Zone_ID], true);
				eZone[Zone_SetSolidTimer] = true;
				bDataChanged = true;
			}
		}
		
		if(eZone[Zone_HasNotSolidTimer] && !eZone[Zone_SetNotSolidTimer])
		{
			if((fCurTime - g_fRoundStartTime) >= ZoneManager_GetDataInt(eZone[Zone_ID], 2))
			{
				SetSolid(eZone[Zone_ID], false);
				eZone[Zone_SetNotSolidTimer] = true;
				bDataChanged = true;
			}
		}
		
		if(eZone[Zone_SetSolidTimer] && eZone[Zone_SetNotSolidTimer])
		{
			RemoveFromArray(g_aZones, i);
			i--;
			iArraySize--;
		}
		else if(bDataChanged)
		{
			SetArrayArray(g_aZones, i, eZone);
		}
	}
}