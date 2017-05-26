#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_trace>
#include "../../Libraries/ZoneManager/zone_manager"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Teleport";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of teleport.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Teleport";
new const String:SZ_ZONE_TYPE_NAME_DEST[] = "Teleport Destination";

new const Float:HULL_STANDING_MINS_CSGO[] = {-16.0, -16.0, 0.0};
new const Float:HULL_STANDING_MAXS_CSGO[] = {16.0, 16.0, 72.0};

enum MenuInfoType
{
	MENU_INFO_SET_TELEPORT,
	MENU_INFO_SET_TELEPORT_DEST,
};

new g_iEditingZoneID[MAXPLAYERS+1];
new MenuInfoType:g_iEditingType[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("zone_type_teleport_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("zonetype_teleport");
	CreateNative("ZoneTypeTeleport_TryToTeleport", _ZoneTypeTeleport_TryToTeleport);
	
	return APLRes_Success;
}

public _ZoneTypeTeleport_TryToTeleport(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
		SetFailState("Invalid number of parameters ZoneTypeTeleport_TryToTeleport");
	
	return TryToTeleport(GetNativeCell(1), GetNativeCell(2));
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_TELEPORT, SZ_ZONE_TYPE_NAME, _, OnStartTouch, _, OnEditData);
	ZoneManager_RegisterZoneType(ZONE_TYPE_TELEPORT_DESTINATION, SZ_ZONE_TYPE_NAME_DEST, _, _, _, OnEditDataDest);
}

public OnStartTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	static iZoneID;
	iZoneID = GetZoneID(iZone);
	
	TryToTeleport(iZoneID, iOther);
}

bool:TryToTeleport(iZoneID, iClient)
{
	static String:szTarget[MAX_ZONE_DATA_STRING_LENGTH];
	if(!ZoneManager_GetDataString(iZoneID, 1, szTarget, sizeof(szTarget)) || !szTarget[0])
	{
		CPrintToChat(iClient, "{red}Teleport's destination not set.");
		return false;
	}
	
	static Handle:hZoneIDs;
	hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TELEPORT_DESTINATION);
	
	new iDestZoneID;
	static String:szDestName[MAX_ZONE_DATA_STRING_LENGTH], iTempID;
	for(new i=0; i<GetArraySize(hZoneIDs); i++)
	{
		iTempID = GetArrayCell(hZoneIDs, i);
		
		if(!ZoneManager_GetDataString(iTempID, 1, szDestName, sizeof(szDestName)) || !szDestName[0])
			continue;
		
		if(!StrEqual(szTarget, szDestName))
			continue;
		
		iDestZoneID = iTempID;
		break;
	}
	
	CloseHandle(hZoneIDs);
	
	if(!iDestZoneID)
	{
		CPrintToChat(iClient, "{red}Teleport's destination doesn't exist.");
		return false;
	}
	
	decl Float:fMins[3], Float:fMaxs[3], Float:fDestOrigin[3];
	ZoneManager_GetZoneOrigin(iDestZoneID, fDestOrigin);
	ZoneManager_GetZoneMins(iDestZoneID, fMins);
	ZoneManager_GetZoneMaxs(iDestZoneID, fMaxs);
	
	// Get the center of the zone horizontally, and the bottom of the zone vertically.
	fDestOrigin[0] = fDestOrigin[0] + ((fMins[0] + fMaxs[0]) * 0.5);
	fDestOrigin[1] = fDestOrigin[1] + ((fMins[1] + fMaxs[1]) * 0.5);
	fDestOrigin[2] += fMins[2];
	
	if(!CanTeleportToOrigin(fDestOrigin))
	{
		CPrintToChat(iClient, "{red}Teleporting to the destination would get you stuck.");
		return false;
	}
	
	decl Float:fAngles[3];
	ZoneManager_GetZoneAngles(iDestZoneID, fAngles);
	TeleportEntity(iClient, fDestOrigin, fAngles, Float:{0.0, 0.0, 0.0});
	
	return true;
}

bool:CanTeleportToOrigin(Float:fOrigin[3])
{
	TR_TraceHullFilter(fOrigin, fOrigin, HULL_STANDING_MINS_CSGO, HULL_STANDING_MAXS_CSGO, MASK_PLAYERSOLID, TraceFilter_DontHitPlayers);
	if(TR_DidHit())
		return false;
	
	return true;
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}

public OnEditData(iClient, iZoneID)
{
	g_iEditingType[iClient] = MENU_INFO_SET_TELEPORT;
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, "Edit teleport data\n \nType the teleport's destination name.");
	
	decl String:szDataString[256];
	ZoneManager_GetDataString(iZoneID, 1, szDataString, sizeof(szDataString));
	
	Format(szDataString, sizeof(szDataString), "Destination: %s", szDataString);
	
	AddMenuItem(hMenu, "", szDataString, ITEMDRAW_DISABLED);
	
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
	
	DisplayMenu_EditData(iParam1, g_iEditingZoneID[iParam1]);
}

public OnEditDataDest(iClient, iZoneID)
{
	g_iEditingType[iClient] = MENU_INFO_SET_TELEPORT_DEST;
	DisplayMenu_EditDataDest(iClient, iZoneID);
}

DisplayMenu_EditDataDest(iClient, iZoneID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditDataDest);
	SetMenuTitle(hMenu, "Edit teleport data\n \nType the destination's name.");
	
	decl String:szDataString[256];
	ZoneManager_GetDataString(iZoneID, 1, szDataString, sizeof(szDataString));
	
	Format(szDataString, sizeof(szDataString), "Destination: %s", szDataString);
	
	AddMenuItem(hMenu, "", szDataString, ITEMDRAW_DISABLED);
	
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

public MenuHandle_EditDataDest(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
	
	DisplayMenu_EditDataDest(iParam1, g_iEditingZoneID[iParam1]);
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_iEditingZoneID[iClient])
		return;
	
	decl String:szDataString[MAX_ZONE_DATA_STRING_LENGTH];
	strcopy(szDataString, sizeof(szDataString), szArgs);
	TrimString(szDataString);
	StringToLower(szDataString);
	
	if(!szDataString[0] || StrEqual(szDataString, "-1"))
	{
		ZoneManager_SetDataString(g_iEditingZoneID[iClient], 1, "");
		PrintToChat(iClient, "[SM] Cleared the destination name.");
	}
	else
	{
		ZoneManager_SetDataString(g_iEditingZoneID[iClient], 1, szDataString);
		PrintToChat(iClient, "[SM] Set destination to: %s.", szDataString);
	}
	
	if(g_iEditingType[iClient] == MENU_INFO_SET_TELEPORT)
		DisplayMenu_EditData(iClient, g_iEditingZoneID[iClient]);
	else
		DisplayMenu_EditDataDest(iClient, g_iEditingZoneID[iClient]);
}

StringToLower(String:szString[])
{
	for(new i=0; i<strlen(szString); i++)
		szString[i] = CharToLower(szString[i]);
}