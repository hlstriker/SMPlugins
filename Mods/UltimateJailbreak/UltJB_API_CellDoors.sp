#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_trace>
#include <sdktools_engine>
#include <sdktools_entoutput>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Cell Doors API";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The cell doors API for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_VALUE 1024

enum
{
	EDIT_MENU_ADD = 1,
	EDIT_MENU_REMOVE,
	EDIT_MENU_SAVE
};

new Handle:g_aDoorNames;
new Handle:g_aDoorEntRefs;

new g_iLookingAtEntRef[MAXPLAYERS+1];
new bool:g_bHaveCellDoorsOpened;

new Handle:g_hFwd_OnOpened;


public OnPluginStart()
{
	CreateConVar("ultjb_api_cell_doors_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aDoorNames = CreateArray(MAX_VALUE);
	g_aDoorEntRefs = CreateArray();
	
	HookEvent("round_start", EventRoundStart_Pre, EventHookMode_Pre);
	
	RegAdminCmd("sm_celldoors_edit", OnCellDoorsEdit, ADMFLAG_ROOT, "Allows you to edit which doors are cell doors.");
	
	g_hFwd_OnOpened = CreateGlobalForward("UltJB_CellDoors_OnOpened", ET_Ignore);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_cell_doors");
	
	CreateNative("UltJB_CellDoors_ForceOpen", _UltJB_CellDoors_ForceOpen);
	CreateNative("UltJB_CellDoors_HaveOpened", _UltJB_CellDoors_HaveOpened);
	CreateNative("UltJB_CellDoors_DoExist", _UltJB_CellDoors_DoExist);
	
	return APLRes_Success;
}

public _UltJB_CellDoors_DoExist(Handle:hPlugin, iNumParams)
{
	if(GetArraySize(g_aDoorEntRefs))
		return true;
	
	return false;
}

public _UltJB_CellDoors_ForceOpen(Handle:hPlugin, iNumParams)
{
	if(OpenCellDoors())
		return true;
	
	return false;
}

public _UltJB_CellDoors_HaveOpened(Handle:hPlugin, iNumParams)
{
	if(g_bHaveCellDoorsOpened)
		return true;
	
	return false;
}

public OnCellDoorOpen(const String:szOutput[], iCaller, iActivator, Float:fDelay)
{
	if(g_bHaveCellDoorsOpened)
		return;
	
	g_bHaveCellDoorsOpened = true;
	
	Call_StartForward(g_hFwd_OnOpened);
	Call_Finish();
}

public OnPostThinkPost(iClient)
{
	static Float:fEyePosition[3], Float:fEyeAngles[3], iHit, iOldLookingAtEnt;
	GetClientEyePosition(iClient, fEyePosition);
	GetClientEyeAngles(iClient, fEyeAngles);
	
	TR_TraceRayFilter(fEyePosition, fEyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_OnlyHitDoors);
	iHit = TR_GetEntityIndex();
	
	iOldLookingAtEnt = EntRefToEntIndex(g_iLookingAtEntRef[iClient]);
	
	if(iHit < 1)
	{
		g_iLookingAtEntRef[iClient] = INVALID_ENT_REFERENCE;
		
		if(iOldLookingAtEnt != INVALID_ENT_REFERENCE)
			DisplayMenu_EditCellDoors(iClient);
		
		return;
	}
	
	// Make sure we are getting the parent of whatever we hit.
	static iParent;
	do
	{
		iParent = GetEntPropEnt(iHit, Prop_Data, "m_hParent");
		if(iParent > 0)
			iHit = iParent;
	}
	while(iParent > 0);
	
	static String:szClassName[10];
	GetEntityClassname(iHit, szClassName, sizeof(szClassName));
	if(StrEqual(szClassName[5], "dyna"))
	{
		g_iLookingAtEntRef[iClient] = INVALID_ENT_REFERENCE;
		
		if(iOldLookingAtEnt != INVALID_ENT_REFERENCE)
			DisplayMenu_EditCellDoors(iClient);
		
		return;
	}
	
	if(iHit != iOldLookingAtEnt)
	{
		g_iLookingAtEntRef[iClient] = EntIndexToEntRef(iHit);
		DisplayMenu_EditCellDoors(iClient);
		return;
	}
}

public bool:TraceFilter_OnlyHitDoors(iEnt, iMask, any:iData)
{
	static String:szClassName[10];
	GetEntityClassname(iEnt, szClassName, sizeof(szClassName));
	
	if(StrEqual(szClassName[5], "door")
	|| StrEqual(szClassName[5], "brea") // For func_breakable
	|| StrEqual(szClassName[5], "dyna") // For prop_dynamic*
	|| StrEqual(szClassName[5], "wall") // For func_wall_toggle
	|| StrEqual(szClassName[5], "move")) // For func_movelinear
		return true;
	
	return false;
}

DisplayMenu_EditCellDoors(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditCellDoors);
	
	decl String:szInfo[5];
	new iLookingAtEnt = EntRefToEntIndex(g_iLookingAtEntRef[iClient]);
	
	if(iLookingAtEnt != INVALID_ENT_REFERENCE)
	{
		decl String:szClassName[32], String:szTargetName[MAX_VALUE];
		GetEntityClassname(iLookingAtEnt, szClassName, sizeof(szClassName));
		GetEntPropString(iLookingAtEnt, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));
		
		SetMenuTitle(hMenu, "Edit Cell Doors\n------------------\n%s\n%s\n------------------", szClassName, szTargetName);
		
		if(!IsEntACellDoor(iLookingAtEnt))
		{
			IntToString(EDIT_MENU_ADD, szInfo, sizeof(szInfo));
			AddMenuItem(hMenu, szInfo, "Add this door.");
		}
		else
		{
			IntToString(EDIT_MENU_REMOVE, szInfo, sizeof(szInfo));
			AddMenuItem(hMenu, szInfo, "Remove this door.");
		}
	}
	else
	{
		SetMenuTitle(hMenu, "Edit Cell Doors\n------------------");
		AddMenuItem(hMenu, "", "Look at a cell door.", ITEMDRAW_DISABLED);
	}
	
	IntToString(EDIT_MENU_SAVE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, szInfo, "Save doors.");
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
		PrintToChat(iClient, "[SM] Something went wrong!");
		return;
	}
	
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public MenuHandle_EditCellDoors(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		SDKUnhook(iParam1, SDKHook_PostThinkPost, OnPostThinkPost);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[5];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case EDIT_MENU_SAVE: SaveCellDoorNamesForMap(iParam1);
		case EDIT_MENU_ADD: AddCellDoor(iParam1);
		case EDIT_MENU_REMOVE: RemoveCellDoor(iParam1);
	}
	
	DisplayMenu_EditCellDoors(iParam1);
}

AddCellDoor(iClient)
{
	new iEnt = EntRefToEntIndex(g_iLookingAtEntRef[iClient]);
	if(iEnt == INVALID_ENT_REFERENCE)
	{
		PrintToChat(iClient, "[SM] There was a problem adding this door, try again.");
		return;
	}
	
	decl String:szName[MAX_VALUE];
	GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
	PushArrayString(g_aDoorNames, szName);
	
	// Because multiple ents might share the same name we need to loop through them all.
	iEnt = -1;
	decl String:szBuffer[MAX_VALUE];
	
	while((iEnt = FindEntityByClassname(iEnt, "func_door")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen, true);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_door_rotating")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen, true);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "prop_door_rotating")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen, true);
	}
	
	// Breakables are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_breakable")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnBreak", OnCellDoorOpen, true);
	}
	
	// Movelinears are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_movelinear")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnFullyOpen", OnCellDoorOpen, true);
	}
	
	// Tracktrains are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_tracktrain")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		// Note: These "doors" cannot be detected when opened.
	}
	
	// WallToggles are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_wall_toggle")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		// Note: These "doors" cannot be detected when opened.
	}
	
	PrintToChat(iClient, "[SM] Door \"%s\" is now a cell door.", szName);
}

RemoveCellDoor(iClient)
{
	new iEnt = EntRefToEntIndex(g_iLookingAtEntRef[iClient]);
	if(iEnt == INVALID_ENT_REFERENCE)
	{
		PrintToChat(iClient, "[SM] There was a problem removing this door, try again.");
		return;
	}
	
	decl String:szName[MAX_VALUE];
	GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
	
	new iIndex = FindStringInArray(g_aDoorNames, szName);
	if(iIndex != -1)
		RemoveFromArray(g_aDoorNames, iIndex);
	
	// Because multiple ents might share the same name we need to loop through them all.
	iEnt = -1;
	decl String:szBuffer[MAX_VALUE];
	
	while((iEnt = FindEntityByClassname(iEnt, "func_door")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		iIndex = FindValueInArray(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		if(iIndex != -1)
			RemoveFromArray(g_aDoorEntRefs, iIndex);
		
		UnhookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_door_rotating")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		iIndex = FindValueInArray(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		if(iIndex != -1)
			RemoveFromArray(g_aDoorEntRefs, iIndex);
		
		UnhookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "prop_door_rotating")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		iIndex = FindValueInArray(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		if(iIndex != -1)
			RemoveFromArray(g_aDoorEntRefs, iIndex);
		
		UnhookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen);
	}
	
	// Breakables are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_breakable")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		iIndex = FindValueInArray(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		if(iIndex != -1)
			RemoveFromArray(g_aDoorEntRefs, iIndex);
		
		UnhookSingleEntityOutput(iEnt, "OnBreak", OnCellDoorOpen);
	}
	
	// Movelinears are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_movelinear")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		iIndex = FindValueInArray(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		if(iIndex != -1)
			RemoveFromArray(g_aDoorEntRefs, iIndex);
		
		UnhookSingleEntityOutput(iEnt, "OnFullyOpen", OnCellDoorOpen);
	}
	
	// Tracktrains are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_tracktrain")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		iIndex = FindValueInArray(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		if(iIndex != -1)
			RemoveFromArray(g_aDoorEntRefs, iIndex);
		
		// Note: These "doors" cannot be detected when opened.
	}
	
	// WallToggles are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_wall_toggle")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		if(!StrEqual(szName, szBuffer))
			continue;
		
		iIndex = FindValueInArray(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		if(iIndex != -1)
			RemoveFromArray(g_aDoorEntRefs, iIndex);
		
		// Note: These "doors" cannot be detected when opened.
	}
	
	PrintToChat(iClient, "[SM] Door \"%s\" is no longer a cell door.", szName);
}

public Action:OnCellDoorsEdit(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	g_iLookingAtEntRef[iClient] = INVALID_ENT_REFERENCE;
	DisplayMenu_EditCellDoors(iClient);
	
	return Plugin_Handled;
}

bool:OpenCellDoors()
{
	new iArraySize = GetArraySize(g_aDoorEntRefs);
	if(!iArraySize)
		return false;
	
	decl iEnt, String:szClassName[10];
	for(new i=0; i<iArraySize; i++)
	{
		iEnt = EntRefToEntIndex(GetArrayCell(g_aDoorEntRefs, i));
		if(iEnt < 1 || iEnt == INVALID_ENT_REFERENCE)
			continue;
		
		GetEntityClassname(iEnt, szClassName, sizeof(szClassName));
		
		if(StrEqual(szClassName[5], "door") || StrEqual(szClassName[5], "move"))
		{
			AcceptEntityInput(iEnt, "Unlock");
			AcceptEntityInput(iEnt, "Open");
		}
		else if(StrEqual(szClassName[5], "brea"))
		{
			AcceptEntityInput(iEnt, "Break");
		}
		else if(StrEqual(szClassName[5], "wall"))
		{
			//AcceptEntityInput(iEnt, "Toggle");
			AcceptEntityInput(iEnt, "KillHierarchy"); // Since this can't be detected when open let's just kill it instead.
		}
		else if(StrEqual(szClassName[5], "trac"))
		{
			//AcceptEntityInput(iEnt, "StartForward");
			AcceptEntityInput(iEnt, "KillHierarchy"); // Since this can't be detected when open let's just kill it instead.
		}
	}
	
	return true;
}

public OnMapStart()
{
	g_bHaveCellDoorsOpened = false;
	
	LoadCellDoorNamesForMap();
	GetCellDoorEnts();
}

public EventRoundStart_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_bHaveCellDoorsOpened = false;
	GetCellDoorEnts();
}

GetCellDoorEnts()
{
	ClearArray(g_aDoorEntRefs);
	
	if(!GetArraySize(g_aDoorNames))
		return;
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_door")) != -1)
	{
		if(!IsEntACellDoor(iEnt))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen, true);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_door_rotating")) != -1)
	{
		if(!IsEntACellDoor(iEnt))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen, true);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "prop_door_rotating")) != -1)
	{
		if(!IsEntACellDoor(iEnt))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnOpen", OnCellDoorOpen, true);
	}
	
	// Breakables are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_breakable")) != -1)
	{
		if(!IsEntACellDoor(iEnt))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnBreak", OnCellDoorOpen, true);
	}
	
	// Movelinears are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_movelinear")) != -1)
	{
		if(!IsEntACellDoor(iEnt))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		HookSingleEntityOutput(iEnt, "OnFullyOpen", OnCellDoorOpen, true);
	}
	
	// Tracktrains are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_tracktrain")) != -1)
	{
		if(!IsEntACellDoor(iEnt))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		// Note: These "doors" cannot be detected when opened.
	}
	
	// WallToggles are used as doors in some maps.
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_wall_toggle")) != -1)
	{
		if(!IsEntACellDoor(iEnt))
			continue;
		
		PushArrayCell(g_aDoorEntRefs, EntIndexToEntRef(iEnt));
		// Note: These "doors" cannot be detected when opened.
	}
}

bool:IsEntACellDoor(const iEnt)
{
	decl String:szName[MAX_VALUE];
	GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
	
	if(FindStringInArray(g_aDoorNames, szName) != -1)
		return true;
	
	return false;
}

LoadCellDoorNamesForMap()
{
	ClearArray(g_aDoorNames);
	
	decl String:szBuffer[PLATFORM_MAX_PATH];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/cell_doors/%s.txt", szBuffer);
	
	new Handle:fp = OpenFile(szBuffer, "r");
	if(fp == INVALID_HANDLE)
		return;
	
	while(!IsEndOfFile(fp))
	{
		if(!ReadFileLine(fp, szBuffer, sizeof(szBuffer)))
			continue;
		
		TrimString(szBuffer);
		
		if(strlen(szBuffer) < 1)
			continue;
		
		if(FindStringInArray(g_aDoorNames, szBuffer) == -1)
			PushArrayString(g_aDoorNames, szBuffer);
	}
	
	CloseHandle(fp);
}

SaveCellDoorNamesForMap(iClient)
{
	decl String:szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/cell_doors");
	if(!DirExists(szPath) && !CreateDirectory(szPath, 775))
	{
		PrintToChat(iClient, "[SM] Error creating cell_doors directory.");
		return;
	}
	
	decl String:szBuffer[MAX_VALUE];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	Format(szPath, sizeof(szPath), "%s/%s.txt", szPath, szBuffer);
	
	new Handle:fp = OpenFile(szPath, "w");
	if(fp == INVALID_HANDLE)
	{
		PrintToChat(iClient, "[SM] Error creating save file.");
		return;
	}
	
	for(new i=0; i<GetArraySize(g_aDoorNames); i++)
	{
		GetArrayString(g_aDoorNames, i, szBuffer, sizeof(szBuffer));
		WriteFileLine(fp, szBuffer);
	}
	
	CloseHandle(fp);
	
	PrintToChat(iClient, "[SM] The cell doors have been saved.");
}

GetLowercaseMapName(String:szMapName[], iMaxLength)
{
	GetCurrentMap(szMapName, iMaxLength);
	StringToLower(szMapName);
}

StringToLower(String:szString[])
{
	for(new i=0; i<strlen(szString); i++)
		szString[i] = CharToLower(szString[i]);
}