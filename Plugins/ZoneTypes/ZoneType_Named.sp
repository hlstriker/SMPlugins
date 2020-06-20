#include <sourcemod>
#include "../../Libraries/ZoneManager/zone_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Named";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type of named.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_ZONE_TYPE_NAME[] = "Named";

new g_iEditingZoneID[MAXPLAYERS+1];

new Handle:g_hFwd_OnStartTouch;


public OnPluginStart()
{
	CreateConVar("zone_type_named_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnStartTouch = CreateGlobalForward("ZoneTypeNamed_OnStartTouch", ET_Ignore, Param_Cell, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("zonetype_named");
	return APLRes_Success;
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_NAMED, SZ_ZONE_TYPE_NAME, _, OnStartTouch, _, OnEditData);
}

public OnStartTouch(iZone, iOther)
{
	Call_StartForward(g_hFwd_OnStartTouch);
	Call_PushCell(iZone);
	Call_PushCell(iOther);
	Call_Finish();
}

public OnEditData(iClient, iZoneID)
{
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, "Edit named data\n \nType a name for this zone.\nVarious plugins can reference this name.");
	
	decl String:szDataString[256];
	ZoneManager_GetDataString(iZoneID, 1, szDataString, sizeof(szDataString));
	
	Format(szDataString, sizeof(szDataString), "Name: %s", szDataString);
	
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
		PrintToChat(iClient, "[SM] Cleared the name.");
	}
	else
	{
		ZoneManager_SetDataString(g_iEditingZoneID[iClient], 1, szDataString);
		PrintToChat(iClient, "[SM] Set name to: %s.", szDataString);
	}
	
	DisplayMenu_EditData(iClient, g_iEditingZoneID[iClient]);
}

StringToLower(String:szString[])
{
	for(new i=0; i<strlen(szString); i++)
		szString[i] = CharToLower(szString[i]);
}