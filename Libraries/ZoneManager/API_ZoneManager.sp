#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <sdktools_entinput>
#include <sdktools_engine>
#include <sdktools_trace>
#include "zone_manager"
#include "../DatabaseCore/database_core"
#include "../DatabaseMaps/database_maps"
#include "../DatabaseServers/database_servers"
#include "../DatabaseUsers/database_users"
#include "../UserLogs/user_logs"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Zone Manager";
new const String:PLUGIN_VERSION[] = "1.20";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage the zone plugins.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new g_iSelectedZoneID[MAXPLAYERS+1];
new bool:g_bInZoneMenu[MAXPLAYERS+1];

#define MAX_VALUE_NAME_LENGTH	1024

new g_iZoneIDToIndex[MAX_ZONES+1] = {INVALID_ZONE_ID, ...};
new Handle:g_aZones;
enum _:Zone
{
	Zone_ID,
	bool:Zone_IsImported,
	String:Zone_ImportedName[MAX_VALUE_NAME_LENGTH],
	Float:Zone_Origin[3],
	Float:Zone_Mins[3],
	Float:Zone_Maxs[3],
	Float:Zone_Angles[3],
	Zone_Type,
	Zone_EntReference,
	Zone_Data_Int_1,
	Zone_Data_Int_2,
	String:Zone_Data_String_1[MAX_ZONE_DATA_STRING_LENGTH],
	String:Zone_Data_String_2[MAX_ZONE_DATA_STRING_LENGTH],
	String:Zone_Data_String_3[MAX_ZONE_DATA_STRING_LENGTH],
	String:Zone_Data_String_4[MAX_ZONE_DATA_STRING_LENGTH],
	String:Zone_Data_String_5[MAX_ZONE_DATA_STRING_LENGTH]
};

new Handle:g_hTrie_TypeIDToIndex;
new Handle:g_aZoneTypes;
enum _:ZoneType
{
	ZoneType_Type,
	String:ZoneType_Name[MAX_ZONE_TYPE_NAME_LEN],
	Handle:ZoneType_ForwardTouch,
	Handle:ZoneType_ForwardStartTouch,
	Handle:ZoneType_ForwardEndTouch,
	Handle:ZoneType_ForwardEditData,
	Handle:ZoneType_ForwardTypeAssigned,
	Handle:ZoneType_ForwardTypeUnassigned
};

enum
{
	MENU_INFO_ZONE_ADD = 1,
	MENU_INFO_ZONE_SELECT,
	MENU_INFO_ZONE_IMPORT_TRIGGER,
	MENU_INFO_ZONE_IMPORT_MAP_ZONES,
	MENU_INFO_ZONE_TOGGLE_NOCLIP
};

enum
{
	MENU_INFO_SELECT_NEXT = 1,
	MENU_INFO_SELECT_PREVIOUS,
	MENU_INFO_SELECT_EDIT,
	MENU_INFO_SELECT_DELETE
};

enum
{
	MENU_INFO_EDIT_POSITION = 1,
	MENU_INFO_EDIT_SIZE,
	MENU_INFO_EDIT_ANGLES,
	MENU_INFO_EDIT_TYPE,
	MENU_INFO_EDIT_TYPE_DATA
};

enum
{
	MENU_INFO_CONFIRM_NO = 1,
	MENU_INFO_CONFIRM_YES
};

enum
{
	MENU_INFO_SIZE_EXPAND = 1
};

new const SOLID_NONE = 0;
new const SOLID_BBOX = 2;

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;

new const EF_NODRAW = 32;

new const Float:DEFAULT_ZONE_MINS[3] = {-100.0, -100.0, 2.0};
new const Float:DEFAULT_ZONE_MAXS[3] = {100.0, 100.0, 100.0};

#define ZONES_TO_SHOW_IN_RADIUS	5
new const Float:BOX_BEAM_WIDTH = 2.5;
new const Float:BOX_BEAM_WIDTH_RADIUS = 1.2;
new const ZONE_EDIT_COLOR[] = {0, 255, 0, 255};
new const ZONE_EDIT_COLOR_RADIUS[] = {255, 0, 0, 220};

new g_iBeamIndex;
new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";
new const String:SZ_ZONE_MODEL[] = "models/player/tm_leet_variantC.mdl";

new const Float:DISPLAY_BOX_DELAY = 0.1;
new Float:g_fNextDisplayBoxTime[MAXPLAYERS+1];

new bool:g_bIsEditingSize[MAXPLAYERS+1];
new const Float:UPDATE_CHECK_TIME_SIZE = 0.05;
new Float:g_fNextUpdateCheckSize[MAXPLAYERS+1];

new bool:g_bIsEditingPosition[MAXPLAYERS+1];
new const Float:UPDATE_CHECK_TIME_POSITION = 0.05;
new Float:g_fNextUpdateCheckPosition[MAXPLAYERS+1];
new Float:g_fEditPositionDistance[MAXPLAYERS+1];

new bool:g_bIsImportingTrigger[MAXPLAYERS+1];

new Handle:g_hFwd_OnRegisterReady;
new Handle:g_hFwd_OnTypeAssigned;
new Handle:g_hFwd_OnTypeUnassigned;
new Handle:g_hFwd_OnZonesLoaded;
new Handle:g_hFwd_OnZoneCreated;
new Handle:g_hFwd_OnZoneRemoved_Pre;
new Handle:g_hFwd_OnZoneRemoved_Post;
new Handle:g_hFwd_CreateZoneEnts_Pre;

new g_iUniqueMapCounter;
new bool:g_bAreZonesLoadedFromDB;
new bool:g_bNeedsForceSaved;

new bool:g_bIsShowingTriggerNames[MAXPLAYERS+1];
new Handle:g_hTrie_TriggerNameTimes;

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:cvar_can_import_from_another_map;


public OnPluginStart()
{
	CreateConVar("api_zone_manager_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnRegisterReady = CreateGlobalForward("ZoneManager_OnRegisterReady", ET_Ignore);
	g_hFwd_OnTypeAssigned = CreateGlobalForward("ZoneManager_OnTypeAssigned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnTypeUnassigned = CreateGlobalForward("ZoneManager_OnTypeUnassigned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnZonesLoaded = CreateGlobalForward("ZoneManager_OnZonesLoaded", ET_Ignore);
	g_hFwd_OnZoneCreated = CreateGlobalForward("ZoneManager_OnZoneCreated", ET_Ignore, Param_Cell);
	g_hFwd_OnZoneRemoved_Pre = CreateGlobalForward("ZoneManager_OnZoneRemoved_Pre", ET_Ignore, Param_Cell);
	g_hFwd_OnZoneRemoved_Post = CreateGlobalForward("ZoneManager_OnZoneRemoved_Post", ET_Ignore, Param_Cell);
	g_hFwd_CreateZoneEnts_Pre = CreateGlobalForward("ZoneManager_CreateZoneEnts_Pre", ET_Ignore);
	
	g_aZones = CreateArray(Zone);
	g_aZoneTypes = CreateArray(ZoneType);
	
	g_hTrie_TypeIDToIndex = CreateTrie();
	g_hTrie_TriggerNameTimes = CreateTrie();
	
	cvar_can_import_from_another_map = CreateConVar("zm_can_import_from_another_map", "0", "Set to allow importing zones from another map.", _, true, 0.0, true, 1.0);
	
	RegAdminCmd("sm_zonemanager", OnZoneManager, ADMFLAG_BAN, "Opens the zone manager.");
	RegAdminCmd("sm_zm", OnZoneManager, ADMFLAG_BAN, "Opens the zone manager.");
	RegAdminCmd("sm_showtriggernames", OnShowTriggerNames, ADMFLAG_BAN, "Show trigger names in console as you touch them.");
	
	HookEvent("round_start", Event_RoundStart_Pre, EventHookMode_Pre);
}

public OnMapStart()
{
	g_iUniqueMapCounter++;
	g_bAreZonesLoadedFromDB = false;
	g_bNeedsForceSaved = false;
	
	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL);
	PrecacheModel(SZ_ZONE_MODEL);
	
	decl eZoneType[ZoneType];
	for(new i=0; i<GetArraySize(g_aZoneTypes); i++)
	{
		GetArrayArray(g_aZoneTypes, i, eZoneType);
		
		if(eZoneType[ZoneType_ForwardTouch] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardTouch]);
		
		if(eZoneType[ZoneType_ForwardStartTouch] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardStartTouch]);
		
		if(eZoneType[ZoneType_ForwardEndTouch] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardEndTouch]);
		
		if(eZoneType[ZoneType_ForwardEditData] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardEditData]);
		
		if(eZoneType[ZoneType_ForwardTypeAssigned] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardTypeAssigned]);
		
		if(eZoneType[ZoneType_ForwardTypeUnassigned] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardTypeUnassigned]);
	}
	
	ClearArray(g_aZones);
	ClearArray(g_aZoneTypes);
	ClearTrie(g_hTrie_TypeIDToIndex);
	ClearTrie(g_hTrie_TriggerNameTimes);
	
	CreateNotSetZoneType();
	
	new result;
	Call_StartForward(g_hFwd_OnRegisterReady);
	Call_Finish(result);
	
	SortZoneTypesByName();
}

Forward_OnZonesLoaded()
{
	new result;
	Call_StartForward(g_hFwd_OnZonesLoaded);
	Call_Finish(result);
}

Forward_OnZoneCreated(iZoneID)
{
	decl result;
	Call_StartForward(g_hFwd_OnZoneCreated);
	Call_PushCell(iZoneID);
	Call_Finish(result);
}

Forward_OnZoneRemoved(iZoneID, bool:bIsPre)
{
	decl result;
	Call_StartForward(bIsPre ? g_hFwd_OnZoneRemoved_Pre : g_hFwd_OnZoneRemoved_Post);
	Call_PushCell(iZoneID);
	Call_Finish(result);
}

SortZoneTypesByName()
{
	new iArraySize = GetArraySize(g_aZoneTypes);
	decl String:szName[MAX_ZONE_TYPE_NAME_LEN], eZoneType[ZoneType], j, iIndex, iID, iID2, String:szTypeID[12];
	
	for(new i=1; i<iArraySize; i++) // Start at index 1 instead of 0 so Not Set is always first.
	{
		GetArrayArray(g_aZoneTypes, i, eZoneType);
		strcopy(szName, sizeof(szName), eZoneType[ZoneType_Name]);
		iIndex = 0;
		iID = eZoneType[Zone_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aZoneTypes, j, eZoneType);
			if(strcmp(szName, eZoneType[ZoneType_Name], false) < 0)
				continue;
			
			iIndex = j;
			iID2 = eZoneType[Zone_ID];
			strcopy(szName, sizeof(szName), eZoneType[ZoneType_Name]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aZoneTypes, i, iIndex);
		
		// We must swap the IDtoIndex too.
		IntToString(iID, szTypeID, sizeof(szTypeID));
		SetTrieValue(g_hTrie_TypeIDToIndex, szTypeID, iIndex, true);
		
		IntToString(iID2, szTypeID, sizeof(szTypeID));
		SetTrieValue(g_hTrie_TypeIDToIndex, szTypeID, i, true);
	}
}

public OnMapEnd()
{
	if(!g_bNeedsForceSaved)
		return;
	
	TransactionStart_SaveZones();
}

public OnClientPutInServer(iClient)
{
	g_iSelectedZoneID[iClient] = 0;
	g_bInZoneMenu[iClient] = false;
}

CreateNotSetZoneType()
{
	decl eZoneType[ZoneType];
	eZoneType[ZoneType_Type] = ZONE_TYPE_NOT_SET;
	strcopy(eZoneType[ZoneType_Name], MAX_ZONE_TYPE_NAME_LEN, "Not set");
	eZoneType[ZoneType_ForwardTouch] = INVALID_HANDLE;
	eZoneType[ZoneType_ForwardStartTouch] = INVALID_HANDLE;
	eZoneType[ZoneType_ForwardEndTouch] = INVALID_HANDLE;
	eZoneType[ZoneType_ForwardEditData] = INVALID_HANDLE;
	eZoneType[ZoneType_ForwardTypeAssigned] = INVALID_HANDLE;
	eZoneType[ZoneType_ForwardTypeUnassigned] = INVALID_HANDLE;
	new iIndex = PushArrayArray(g_aZoneTypes, eZoneType);
	
	decl String:szTypeID[12];
	IntToString(ZONE_TYPE_NOT_SET, szTypeID, sizeof(szTypeID));
	SetTrieValue(g_hTrie_TypeIDToIndex, szTypeID, iIndex, true);
}

public Event_RoundStart_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	CreateZoneEnts();
}

CreateZoneEnts()
{
	RebuildZoneIDToIndexArray();
	
	Call_StartForward(g_hFwd_CreateZoneEnts_Pre);
	Call_Finish();
	
	decl eZone[Zone];
	for(new i=0; i<GetArraySize(g_aZones); i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		
		if(eZone[Zone_IsImported])
			HookZoneImportedEntity(i);
		else
			CreateZoneEntity(i);
	}
}

public Action:OnShowTriggerNames(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	g_bIsShowingTriggerNames[iClient] = !g_bIsShowingTriggerNames[iClient];
	
	if(g_bIsShowingTriggerNames[iClient])
	{
		SDKHook(iClient, SDKHook_TouchPost, OnClientTouchPost);
		ReplyToCommand(iClient, "You will now see trigger names in the console as you touch them.");
	}
	else
	{
		SDKUnhook(iClient, SDKHook_TouchPost, OnClientTouchPost);
		ReplyToCommand(iClient, "Showing trigger names DEACTIVATED.");
	}
	
	return Plugin_Handled;
}

public OnClientTouchPost(iClient, iOther)
{
	if(!iOther)
		return;
	
	if(!IsValidEntity(iOther))
		return;
	
	// Make sure the classname is a trigger_
	static String:szName[MAX_VALUE_NAME_LENGTH];
	if(!GetEntityClassname(iOther, szName, sizeof(szName)))
		return;
	
	szName[8] = 0x00;
	if(!StrEqual(szName, "trigger_"))
		return;
	
	// Get the triggers name.
	GetEntPropString(iOther, Prop_Data, "m_iName", szName, sizeof(szName));
	
	if(!szName[0])
		return;
	
	TryShowTriggerName(iClient, szName);
}

TryShowTriggerName(iClient, const String:szName[])
{
	decl String:szTrieKey[24], Float:fLastShown;
	
	FormatEx(szTrieKey, sizeof(szTrieKey), "%d-%s", iClient, szName);
	if(GetTrieValue(g_hTrie_TriggerNameTimes, szTrieKey, fLastShown))
	{
		if(GetGameTime() < fLastShown + 2.0)
			return;
	}
	
	SetTrieValue(g_hTrie_TriggerNameTimes, szTrieKey, GetGameTime(), true);
	
	PrintToConsole(iClient, "Trigger name: %s", szName);
}

public Action:OnZoneManager(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!g_bAreZonesLoadedFromDB)
	{
		ReplyToCommand(iClient, "[SM] Please wait for the zones to finish loading from the database.");
		return Plugin_Handled;
	}
	
	g_bNeedsForceSaved = true;
	
	DisplayMenu_ZoneManager(iClient);
	return Plugin_Handled;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("zone_manager");
	
	CreateNative("ZoneManager_RegisterZoneType", _ZoneManager_RegisterZoneType);
	CreateNative("ZoneManager_ShowMenuEditZone", _ZoneManager_ShowMenuEditZone);
	
	CreateNative("ZoneManager_GetDataInt", _ZoneManager_GetDataInt);
	CreateNative("ZoneManager_SetDataInt", _ZoneManager_SetDataInt);
	
	CreateNative("ZoneManager_GetDataString", _ZoneManager_GetDataString);
	CreateNative("ZoneManager_SetDataString", _ZoneManager_SetDataString);
	
	CreateNative("ZoneManager_GetAllZones", _ZoneManager_GetAllZones);
	CreateNative("ZoneManager_GetZoneType", _ZoneManager_GetZoneType);
	
	CreateNative("ZoneManager_GetZoneOrigin", _ZoneManager_GetZoneOrigin);
	CreateNative("ZoneManager_GetZoneAngles", _ZoneManager_GetZoneAngles);
	CreateNative("ZoneManager_GetZoneMins", _ZoneManager_GetZoneMins);
	CreateNative("ZoneManager_GetZoneMaxs", _ZoneManager_GetZoneMaxs);
	CreateNative("ZoneManager_GetZoneEntity", _ZoneManager_GetZoneEntity);
	CreateNative("ZoneManager_RecreateZone", _ZoneManager_RecreateZone);
	
	CreateNative("ZoneManager_IsInZoneMenu", _ZoneManager_IsInZoneMenu);
	CreateNative("ZoneManager_FinishedEditingZoneData", _ZoneManager_FinishedEditingZoneData);
	CreateNative("ZoneManager_RestartEditingZoneData", _ZoneManager_RestartEditingZoneData);
	
	return APLRes_Success;
}

public _ZoneManager_RecreateZone(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters _ZoneManager_RecreateZone.");
		return 0;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return 0;
	
	return RecreateZone(g_iZoneIDToIndex[iZoneID]);
}

public _ZoneManager_RestartEditingZoneData(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iClient = GetNativeCell(1);
	if(g_bInZoneMenu[iClient])
		return;
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public _ZoneManager_FinishedEditingZoneData(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iClient = GetNativeCell(1);
	g_bInZoneMenu[iClient] = false;
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public _ZoneManager_IsInZoneMenu(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	if(!g_bInZoneMenu[GetNativeCell(1)])
		return false;
	
	return true;
}

public _ZoneManager_GetZoneMaxs(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return false;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	SetNativeArray(2, eZone[Zone_Maxs], 3);
	
	return true;
}

public _ZoneManager_GetZoneMins(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return false;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	SetNativeArray(2, eZone[Zone_Mins], 3);
	
	return true;
}

public _ZoneManager_GetZoneAngles(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return false;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	SetNativeArray(2, eZone[Zone_Angles], 3);
	
	return true;
}

public _ZoneManager_GetZoneEntity(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters _ZoneManager_GetZoneEntity");
		return 0;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return 0;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	new iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
	if(iEnt <= 0)
		return 0;
	
	return iEnt;
}

public _ZoneManager_GetZoneOrigin(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return false;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	SetNativeArray(2, eZone[Zone_Origin], 3);
	
	return true;
}

public _ZoneManager_GetZoneType(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return -1;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return -1;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	return eZone[Zone_Type];
}

public _ZoneManager_GetAllZones(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new Handle:hZoneIDs = GetNativeCell(1);
	if(hZoneIDs == INVALID_HANDLE)
		return false;
	
	new iZoneType = GetNativeCell(2);
	
	decl eZone[Zone];
	for(new i=0; i<GetArraySize(g_aZones); i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		
		if(iZoneType >= 0 && iZoneType != eZone[Zone_Type])
			continue;
		
		PushArrayCell(hZoneIDs, eZone[Zone_ID]);
	}
	
	return true;
}

public _ZoneManager_SetDataString(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iNumber = GetNativeCell(2);
	if(iNumber < 1 || iNumber > 5)
	{
		LogError("Invalid string_number of %i", iNumber);
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return false;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	switch(iNumber)
	{
		case 1: GetNativeString(3, eZone[Zone_Data_String_1], MAX_ZONE_DATA_STRING_LENGTH);
		case 2: GetNativeString(3, eZone[Zone_Data_String_2], MAX_ZONE_DATA_STRING_LENGTH);
		case 3: GetNativeString(3, eZone[Zone_Data_String_3], MAX_ZONE_DATA_STRING_LENGTH);
		case 4: GetNativeString(3, eZone[Zone_Data_String_4], MAX_ZONE_DATA_STRING_LENGTH);
		case 5: GetNativeString(3, eZone[Zone_Data_String_5], MAX_ZONE_DATA_STRING_LENGTH);
	}
	
	SetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	return true;
}

public _ZoneManager_GetDataString(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 4)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iNumber = GetNativeCell(2);
	if(iNumber < 1 || iNumber > 5)
	{
		LogError("Invalid string_number of %i", iNumber);
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return false;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	switch(iNumber)
	{
		case 1: SetNativeString(3, eZone[Zone_Data_String_1], GetNativeCell(4));
		case 2: SetNativeString(3, eZone[Zone_Data_String_2], GetNativeCell(4));
		case 3: SetNativeString(3, eZone[Zone_Data_String_3], GetNativeCell(4));
		case 4: SetNativeString(3, eZone[Zone_Data_String_4], GetNativeCell(4));
		case 5: SetNativeString(3, eZone[Zone_Data_String_5], GetNativeCell(4));
	}
	
	return true;
}

public _ZoneManager_ShowMenuEditZone(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	DisplayMenu_EditZone(GetNativeCell(1));
	
	return true;
}

public _ZoneManager_SetDataInt(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iIntegerIndex = GetNativeCell(2);
	if(iIntegerIndex < 1 || iIntegerIndex > 2)
	{
		LogError("Invalid int_number of %i", iIntegerIndex);
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return false;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	switch(iIntegerIndex)
	{
		case 1: eZone[Zone_Data_Int_1] = GetNativeCell(3);
		case 2: eZone[Zone_Data_Int_2] = GetNativeCell(3);
	}
	
	SetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	return true;
}

public _ZoneManager_GetDataInt(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iIntegerIndex = GetNativeCell(2);
	if(iIntegerIndex < 1 || iIntegerIndex > 2)
	{
		LogError("Invalid int_number of %i", iIntegerIndex);
		return false;
	}
	
	new iZoneID = GetNativeCell(1);
	if(!IsValidZoneID(iZoneID))
		return 0;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	switch(iIntegerIndex)
	{
		case 1: return eZone[Zone_Data_Int_1];
		case 2: return eZone[Zone_Data_Int_2];
	}
	
	return 0;
}

public _ZoneManager_RegisterZoneType(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 8)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iZoneType = GetNativeCell(1);
	
	decl eZoneType[ZoneType];
	for(new i=0; i<GetArraySize(g_aZoneTypes); i++)
	{
		GetArrayArray(g_aZoneTypes, i, eZoneType);
		if(eZoneType[ZoneType_Type] != iZoneType)
			continue;
		
		if(eZoneType[ZoneType_ForwardTouch] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardTouch]);
		
		if(eZoneType[ZoneType_ForwardStartTouch] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardStartTouch]);
		
		if(eZoneType[ZoneType_ForwardEndTouch] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardEndTouch]);
		
		if(eZoneType[ZoneType_ForwardEditData] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardEditData]);
		
		if(eZoneType[ZoneType_ForwardTypeAssigned] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardTypeAssigned]);
		
		if(eZoneType[ZoneType_ForwardTypeUnassigned] != INVALID_HANDLE)
			CloseHandle(eZoneType[ZoneType_ForwardTypeUnassigned]);
		
		RemoveFromArray(g_aZoneTypes, i);
		break;
	}
	
	decl String:szZoneTypeName[MAX_ZONE_TYPE_NAME_LEN];
	GetNativeString(2, szZoneTypeName, sizeof(szZoneTypeName));
	
	eZoneType[ZoneType_Type] = iZoneType;
	strcopy(eZoneType[ZoneType_Name], MAX_ZONE_TYPE_NAME_LEN, szZoneTypeName);
	
	// Touch callback.
	new Function:callback = GetNativeCell(3);
	if(callback != INVALID_FUNCTION)
	{
		eZoneType[ZoneType_ForwardTouch] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eZoneType[ZoneType_ForwardTouch], hPlugin, callback);
	}
	else
	{
		eZoneType[ZoneType_ForwardTouch] = INVALID_HANDLE;
	}
	
	// StartTouch callback.
	callback = GetNativeCell(4);
	if(callback != INVALID_FUNCTION)
	{
		eZoneType[ZoneType_ForwardStartTouch] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eZoneType[ZoneType_ForwardStartTouch], hPlugin, callback);
	}
	else
	{
		eZoneType[ZoneType_ForwardStartTouch] = INVALID_HANDLE;
	}
	
	// EndTouch callback.
	callback = GetNativeCell(5);
	if(callback != INVALID_FUNCTION)
	{
		eZoneType[ZoneType_ForwardEndTouch] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eZoneType[ZoneType_ForwardEndTouch], hPlugin, callback);
	}
	else
	{
		eZoneType[ZoneType_ForwardEndTouch] = INVALID_HANDLE;
	}
	
	// Edit data callback.
	callback = GetNativeCell(6);
	if(callback != INVALID_FUNCTION)
	{
		eZoneType[ZoneType_ForwardEditData] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eZoneType[ZoneType_ForwardEditData], hPlugin, callback);
	}
	else
	{
		eZoneType[ZoneType_ForwardEditData] = INVALID_HANDLE;
	}
	
	// Type assigned callback.
	callback = GetNativeCell(7);
	if(callback != INVALID_FUNCTION)
	{
		eZoneType[ZoneType_ForwardTypeAssigned] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eZoneType[ZoneType_ForwardTypeAssigned], hPlugin, callback);
	}
	else
	{
		eZoneType[ZoneType_ForwardTypeAssigned] = INVALID_HANDLE;
	}
	
	// Type unassigned callback.
	callback = GetNativeCell(8);
	if(callback != INVALID_FUNCTION)
	{
		eZoneType[ZoneType_ForwardTypeUnassigned] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eZoneType[ZoneType_ForwardTypeUnassigned], hPlugin, callback);
	}
	else
	{
		eZoneType[ZoneType_ForwardTypeUnassigned] = INVALID_HANDLE;
	}
	
	new iIndex = PushArrayArray(g_aZoneTypes, eZoneType);
	
	decl String:szTypeID[12];
	IntToString(iZoneType, szTypeID, sizeof(szTypeID));
	SetTrieValue(g_hTrie_TypeIDToIndex, szTypeID, iIndex, true);
	
	return true;
}

DisplayMenu_ZoneManager(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_ZoneManager);
	SetMenuTitle(hMenu, "Zone Manager");
	
	decl String:szInfo[4];
	IntToString(MENU_INFO_ZONE_ADD, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Add new zone");
	
	IntToString(MENU_INFO_ZONE_SELECT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Select a zone", GetArraySize(g_aZones) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	IntToString(MENU_INFO_ZONE_IMPORT_TRIGGER, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Import trigger from map");
	
	IntToString(MENU_INFO_ZONE_IMPORT_MAP_ZONES, szInfo, sizeof(szInfo));
	if(GetConVarBool(cvar_can_import_from_another_map))
		AddMenuItem(hMenu, szInfo, "Import zones from another map");
	else
		AddMenuItem(hMenu, szInfo, "Import zones from another map", ITEMDRAW_DISABLED);
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(MENU_INFO_ZONE_TOGGLE_NOCLIP, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, (GetEntityMoveType(iClient) == MOVETYPE_NOCLIP) ? "Disable Noclip" : "Enable Noclip");
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_ZoneManager(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENU_INFO_ZONE_ADD:
		{
			new iZoneID = PrepareAddZone_Client(iParam1);
			if(iZoneID)
			{
				LogChanges(iParam1, ZM_EDITTYPE_CREATE, 0);
				g_iSelectedZoneID[iParam1] = iZoneID;
				DisplayMenu_EditZone(iParam1);
			}
			else
			{
				PrintToChat(iParam1, "[SM] There was an error adding a new zone. Most likely max zones created.");
				DisplayMenu_ZoneManager(iParam1);
			}
		}
		case MENU_INFO_ZONE_SELECT: SelectZone_Next(iParam1);
		case MENU_INFO_ZONE_IMPORT_TRIGGER: DisplayMenu_ImportTrigger(iParam1);
		case MENU_INFO_ZONE_IMPORT_MAP_ZONES: DisplayMenu_ImportMapZones(iParam1);
		case MENU_INFO_ZONE_TOGGLE_NOCLIP:
		{
			if(GetEntityMoveType(iParam1) == MOVETYPE_NOCLIP)
			{
				SetEntProp(iParam1, Prop_Send, "m_nSolidType", SOLID_BBOX);
				SetEntityMoveType(iParam1, MOVETYPE_WALK);
			}
			else
			{
				SetEntProp(iParam1, Prop_Send, "m_nSolidType", SOLID_NONE);
				SetEntityMoveType(iParam1, MOVETYPE_NOCLIP);
			}
			
			DisplayMenu_ZoneManager(iParam1);
		}
	}
}

DisplayMenu_ImportMapZones(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_ImportMapZones);
	SetMenuTitle(hMenu, "Import zones from another map");
	
	static iSerial = -1;
	new Handle:aMapList = CreateArray(64);
	ReadMapList(aMapList, iSerial, "", MAPLIST_FLAG_MAPSFOLDER | MAPLIST_FLAG_NO_DEFAULT);
	
	decl String:szMapName[64];
	for(new i=0; i<GetArraySize(aMapList); i++)
	{
		GetArrayString(aMapList, i, szMapName, sizeof(szMapName));
		AddMenuItem(hMenu, szMapName, szMapName);
	}
	
	CloseHandle(aMapList);
	
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_ImportMapZones(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_ZoneManager(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szMapName[64];
	GetMenuItem(hMenu, iParam2, szMapName, sizeof(szMapName));
	
	PrintToChat(iParam1, "[SM] Importing zones from %s, please wait..", szMapName);
	DBMaps_GetMapIDFromName(szMapName, OnSelectedMapIDFromName, GetClientSerial(iParam1));
}

public OnSelectedMapIDFromName(iMapID, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(!GetZonesForMapID(iMapID, false, iClient))
	{
		PrintToChat(iClient, "[SM] Cannot import zones for the currently played map.");
		DisplayMenu_ImportMapZones(iClient);
		return;
	}
}

DisplayMenu_ImportTrigger(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_ImportTrigger);
	SetMenuTitle(hMenu, "Import Trigger");
	
	AddMenuItem(hMenu, "", "Type the triggers name in chat.", ITEMDRAW_DISABLED);
	
	SetMenuExitButton(hMenu, false);
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bIsImportingTrigger[iClient] = true;
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_ImportTrigger(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_ZoneManager(iParam1);
		
		g_bIsImportingTrigger[iParam1] = false;
		
		return;
	}
	
	DisplayMenu_ImportTrigger(iParam1);
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_bIsImportingTrigger[iClient])
		return;
	
	if(!ImportTrigger(iClient, szArgs))
		DisplayMenu_ImportTrigger(iClient);
}

bool:ImportTrigger(iClient, const String:szTriggerName[])
{
	new bool:bFound;
	decl String:szName[MAX_VALUE_NAME_LENGTH], Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
	for(new iEnt=1; iEnt<=GetMaxEntities(); iEnt++)
	{
		if(!IsValidEntity(iEnt))
			continue;
		
		GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
		if(!StrEqual(szName, szTriggerName, false))
			continue;
		
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
		GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
		GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
		
		if(IsTriggerEntAZone(szName, fOrigin, fMins, fMaxs))
		{
			PrintToChat(iClient, "[SM] Trigger \"%s\" is already a zone.", szTriggerName);
			continue;
		}
		
		PrepareAddZone_Trigger(iEnt);
		PrintToChat(iClient, "[SM] Adding trigger \"%s\".", szTriggerName);
		bFound = true;
	}
	
	if(!bFound)
	{
		PrintToChat(iClient, "[SM] No new triggers matching name \"%s\".", szTriggerName);
		return false;
	}
	
	LogChanges(iClient, ZM_EDITTYPE_IMPORT, 0);
	
	return true;
}

GetZoneTypeIndexFromID(iTypeID)
{
	static iIndex, String:szID[12];
	IntToString(iTypeID, szID, sizeof(szID));
	
	if(!GetTrieValue(g_hTrie_TypeIDToIndex, szID, iIndex))
		return -1;
	
	return iIndex;
}

DisplayMenu_SelectZone(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] There are no zones to select.");
		return;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	new iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
	{
		iIndex = GetZoneTypeIndexFromID(ZONE_TYPE_NOT_SET);
		if(iIndex == -1)
			return;
		
		PrintToChat(iClient, "[SM] WARNING: This zone's type plugin is not loaded.");
	}
	
	decl eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	decl String:szTitle[MAX_VALUE_NAME_LENGTH], iLen;
	iLen = FormatEx(szTitle, sizeof(szTitle), "Zone Selection");
	
	if(eZone[Zone_IsImported])
	{
		iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\n \nImported Trigger:\n%s", eZone[Zone_ImportedName]);
	}
	else
	{
		iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\n \nAdded via plugin.");
	}
	
	iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\nZone Type: %s", eZoneType[ZoneType_Name]);
	iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\n%i -- %i", eZone[Zone_Data_Int_1], eZone[Zone_Data_Int_2]);
	
	new Handle:hMenu = CreateMenu(MenuHandle_SelectZone);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[4];
	IntToString(MENU_INFO_SELECT_NEXT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Select next zone");
	
	IntToString(MENU_INFO_SELECT_PREVIOUS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Select previous zone");
	
	IntToString(MENU_INFO_SELECT_EDIT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit current zone");
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(MENU_INFO_SELECT_DELETE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Delete current zone");
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_SelectZone(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_ZoneManager(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENU_INFO_SELECT_NEXT: SelectZone_Next(iParam1);
		case MENU_INFO_SELECT_PREVIOUS: SelectZone_Previous(iParam1);
		case MENU_INFO_SELECT_EDIT: DisplayMenu_EditZone(iParam1);
		case MENU_INFO_SELECT_DELETE: DisplayMenu_DeleteZone(iParam1);
	}
}

DisplayMenu_DeleteZone(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_DeleteZone);
	SetMenuTitle(hMenu, "Are you sure you want to delete this zone?");
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	decl String:szInfo[6];
	IntToString(MENU_INFO_CONFIRM_NO, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "No");
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(MENU_INFO_CONFIRM_YES, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Yes");
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuExitButton(hMenu, false);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_DeleteZone(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_SelectZone(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!IsValidZoneID(g_iSelectedZoneID[iParam1]))
	{
		PrintToChat(iParam1, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	if(StringToInt(szInfo) != MENU_INFO_CONFIRM_YES)
	{
		DisplayMenu_SelectZone(iParam1);
		return;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]], eZone);
	
	Forward_OnZoneRemoved(eZone[Zone_ID], true);
	
	if(!eZone[Zone_IsImported])
	{
		new iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
		if(iEnt > 0)
			AcceptEntityInput(iEnt, "Kill");
	}
	
	RemoveFromArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]]);
	RebuildZoneIDToIndexArray();
	
	Forward_OnZoneRemoved(eZone[Zone_ID], false);
	
	LogChanges(iParam1, ZM_EDITTYPE_DELETE, eZone[Zone_Type]);
	
	PrintToChat(iParam1, "[SM] The zone has been removed.");
	
	SelectZone_Next(iParam1);
}

RebuildZoneIDToIndexArray()
{
	for(new i=0; i<sizeof(g_iZoneIDToIndex); i++)
		g_iZoneIDToIndex[i] = INVALID_ZONE_ID;
	
	decl eZone[Zone];
	for(new i=0; i<GetArraySize(g_aZones); i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		g_iZoneIDToIndex[eZone[Zone_ID]] = i;
	}
}

DisplayMenu_EditZone(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	new iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
	{
		iIndex = GetZoneTypeIndexFromID(ZONE_TYPE_NOT_SET);
		if(iIndex == -1)
			return;
		
		PrintToChat(iClient, "[SM] WARNING: This zone's type plugin is not loaded.");
	}
	
	decl eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	decl String:szTitle[MAX_VALUE_NAME_LENGTH], iLen;
	iLen = FormatEx(szTitle, sizeof(szTitle), "Edit Zone");
	
	if(eZone[Zone_IsImported])
	{
		iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\n \nImported Trigger:\n%s", eZone[Zone_ImportedName]);
	}
	else
	{
		iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\n \nAdded via plugin.");
	}
	
	iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\nZone Type: %s", eZoneType[ZoneType_Name]);
	iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\n%i -- %i", eZone[Zone_Data_Int_1], eZone[Zone_Data_Int_2]);
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditZone);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[4];
	IntToString(MENU_INFO_EDIT_POSITION, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit position", eZone[Zone_IsImported] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	IntToString(MENU_INFO_EDIT_SIZE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit size", eZone[Zone_IsImported] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	IntToString(MENU_INFO_EDIT_ANGLES, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit angles");
	
	IntToString(MENU_INFO_EDIT_TYPE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit type");
	
	IntToString(MENU_INFO_EDIT_TYPE_DATA, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit type data");
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_EditZone(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_SelectZone(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENU_INFO_EDIT_POSITION: DisplayMenu_EditPosition(iParam1);
		case MENU_INFO_EDIT_SIZE: DisplayMenu_EditSize(iParam1);
		case MENU_INFO_EDIT_ANGLES: DisplayMenu_EditAngles(iParam1);
		case MENU_INFO_EDIT_TYPE: DisplayMenu_EditType(iParam1);
		case MENU_INFO_EDIT_TYPE_DATA: Forward_EditData(iParam1);
	}
}

DisplayMenu_EditAngles(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditAngles);
	SetMenuTitle(hMenu, "Edit Angles");
	
	AddMenuItem(hMenu, "", "Look in the direction for the angle you want.", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "1", "Set angle");
	
	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, false);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_EditAngles(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditZone(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!IsValidZoneID(g_iSelectedZoneID[iParam1]))
	{
		PrintToChat(iParam1, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	if(!StringToInt(szInfo))
		return;
	
	decl eZone[Zone], Float:fAngles[3];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]], eZone);
	GetClientEyeAngles(iParam1, fAngles);
	
	eZone[Zone_Angles] = fAngles;
	SetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]], eZone);
	
	LogChanges(iParam1, ZM_EDITTYPE_ANGLES, eZone[Zone_Type]);
	
	DisplayMenu_EditAngles(iParam1);
}

DisplayMenu_EditPosition(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditPosition);
	SetMenuTitle(hMenu, "Edit Position");
	
	AddMenuItem(hMenu, "", "Look around to move the zone.", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "Left click: Move the zone forwards.", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "Right click: Move the zone backwards.", ITEMDRAW_DISABLED);
	
	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, false);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	decl eZone[Zone], Float:fOrigin[3];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	GetClientEyePosition(iClient, fOrigin);
	
	decl Float:fAngles[3];
	fAngles[0] = eZone[Zone_Origin][0] + ((eZone[Zone_Mins][0] + eZone[Zone_Maxs][0]) * 0.5);
	fAngles[1] = eZone[Zone_Origin][1] + ((eZone[Zone_Mins][1] + eZone[Zone_Maxs][1]) * 0.5);
	fAngles[2] = eZone[Zone_Origin][2] + ((eZone[Zone_Mins][2] + eZone[Zone_Maxs][2]) * 0.5);
	g_fEditPositionDistance[iClient] = GetVectorDistance(fOrigin, fAngles);
	
	SubtractVectors(fAngles, fOrigin, fAngles);
	GetVectorAngles(fAngles, fAngles);
	TeleportEntity(iClient, NULL_VECTOR, fAngles, NULL_VECTOR);
	
	LogChanges(iClient, ZM_EDITTYPE_POSITION, eZone[Zone_Type]);
	
	g_bIsEditingPosition[iClient] = true;
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_EditPosition(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		g_bIsEditingPosition[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditZone(iParam1);
		
		return;
	}
}

Forward_EditData(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	new iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
	{
		iIndex = GetZoneTypeIndexFromID(ZONE_TYPE_NOT_SET);
		if(iIndex == -1)
			return;
		
		PrintToChat(iClient, "[SM] WARNING: This zone's type plugin is not loaded.");
	}
	
	decl eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	if(eZoneType[ZoneType_ForwardEditData] == INVALID_HANDLE)
	{
		PrintToChat(iClient, "[SM] You cannot edit this zones type data.");
		DisplayMenu_EditZone(iClient);
		return;
	}
	
	LogChanges(iClient, ZM_EDITTYPE_DATA, eZone[Zone_Type]);
	
	decl result;
	Call_StartForward(eZoneType[ZoneType_ForwardEditData]);
	Call_PushCell(iClient);
	Call_PushCell(eZone[Zone_ID]);
	Call_Finish(result);
}

Forward_TypeAssigned(iEntityIndex, iZoneID)
{
	if(!IsValidZoneID(iZoneID))
		return;
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	new iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
		return;
	
	decl eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	// Global forward to let all plugins know.
	decl result;
	Call_StartForward(g_hFwd_OnTypeAssigned);
	Call_PushCell(iEntityIndex);
	Call_PushCell(eZone[Zone_ID]);
	Call_PushCell(eZone[Zone_Type]);
	Call_Finish(result);
	
	// Forward for type plugin.
	if(eZoneType[ZoneType_ForwardTypeAssigned] == INVALID_HANDLE)
		return;
	
	Call_StartForward(eZoneType[ZoneType_ForwardTypeAssigned]);
	Call_PushCell(iEntityIndex);
	Call_PushCell(eZone[Zone_ID]);
	Call_Finish(result);
}

Forward_TypeUnassigned(iEntityIndex, iZoneID, iZoneType)
{
	if(!IsValidZoneID(iZoneID))
		return;
	
	new iIndex = GetZoneTypeIndexFromID(iZoneType);
	if(iIndex == -1)
		return;
	
	decl eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	// Global forward to let all plugins know.
	decl result;
	Call_StartForward(g_hFwd_OnTypeUnassigned);
	Call_PushCell(iEntityIndex);
	Call_PushCell(iZoneID);
	Call_PushCell(iZoneType);
	Call_Finish(result);
	
	// Forward for type plugin.
	if(eZoneType[ZoneType_ForwardTypeUnassigned] == INVALID_HANDLE)
		return;
	
	Call_StartForward(eZoneType[ZoneType_ForwardTypeUnassigned]);
	Call_PushCell(iEntityIndex);
	Call_PushCell(iZoneID);
	Call_Finish(result);
}

DisplayMenu_EditType(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	new iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
	{
		iIndex = GetZoneTypeIndexFromID(ZONE_TYPE_NOT_SET);
		if(iIndex == -1)
			return;
		
		PrintToChat(iClient, "[SM] WARNING: This zone's type plugin is not loaded.");
	}
	
	decl eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditType);
	
	decl String:szBuffer[32];
	Format(szBuffer, sizeof(szBuffer), "Zone Type: %s", eZoneType[ZoneType_Name]);
	SetMenuTitle(hMenu, szBuffer);
	
	for(new i=0; i<GetArraySize(g_aZoneTypes); i++)
	{
		GetArrayArray(g_aZoneTypes, i, eZoneType);
		IntToString(i, szBuffer, sizeof(szBuffer));
		AddMenuItem(hMenu, szBuffer, eZoneType[ZoneType_Name]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_EditType(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_bInZoneMenu[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditZone(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!IsValidZoneID(g_iSelectedZoneID[iParam1]))
	{
		PrintToChat(iParam1, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iIndex = StringToInt(szInfo);
	
	decl eZone[Zone], eZoneType[ZoneType];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]], eZone);
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	// If the zone types are already the same just return.
	if(eZone[Zone_Type] == eZoneType[ZoneType_Type])
	{
		DisplayMenu_EditType(iParam1);
		return;
	}
	
	new iOldType = eZone[Zone_Type];
	eZone[Zone_Type] = eZoneType[ZoneType_Type];
	SetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]], eZone);
	
	// Make sure we call this after we set the type.
	if(eZone[Zone_EntReference] != INVALID_ENT_REFERENCE)
	{
		new iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
		if(iEnt > 0)
			Forward_TypeUnassigned(iEnt, eZone[Zone_ID], iOldType);
	}
	
	// Recreate the zone entity after setting the new type.
	RecreateZone(g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]]);
	
	/*
	// NOTE: No longer call the TypeAssigned forward since it will call it in the RecreateZone() call above.
	// Make sure we call this forward after we set the type and recreate the entity.
	if(eZone[Zone_EntReference] != INVALID_ENT_REFERENCE)
	{
		new iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
		if(iEnt > 0)
			Forward_TypeAssigned(iEnt, eZone[Zone_ID]);
	}
	*/
	
	LogChanges(iParam1, ZM_EDITTYPE_ZONETYPE, eZone[Zone_Type]);
	
	DisplayMenu_EditType(iParam1);
}

DisplayMenu_EditSize(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "[SM] Selected zone is no longer valid.");
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditSize);
	SetMenuTitle(hMenu, "Edit Size");
	
	AddMenuItem(hMenu, "", "Look in the direction you want to move.", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "Left click: Expand in looking direction.", ITEMDRAW_DISABLED);
	AddMenuItem(hMenu, "", "Right click: Retract in looking direction.", ITEMDRAW_DISABLED);
	
	decl String:szInfo[4];
	IntToString(MENU_INFO_SIZE_EXPAND, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Expand to wall in looking direction.");
	
	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, false);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
	
	g_bInZoneMenu[iClient] = true;
	g_bIsEditingSize[iClient] = true;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_EditSize(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{

	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		decl eZone[Zone];
		GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]], eZone);
		LogChanges(iParam1, ZM_EDITTYPE_SIZE, eZone[Zone_Type]);
		
		g_bInZoneMenu[iParam1] = false;
		g_bIsEditingSize[iParam1] = false;
		SDKUnhook(iParam1, SDKHook_PreThinkPost, OnPreThinkPost);
		
		// Recreate the zone after done editing the mins/maxs. Some reason it won't update properly.
		if(IsValidZoneID(g_iSelectedZoneID[iParam1]))
			RecreateZone(g_iZoneIDToIndex[g_iSelectedZoneID[iParam1]]);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditZone(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENU_INFO_SIZE_EXPAND: ExpandToWall(iParam1);
	}
	
	DisplayMenu_EditSize(iParam1);
}

RecreateZone(iZoneIndex)
{
	decl eZone[Zone];
	GetArrayArray(g_aZones, iZoneIndex, eZone);
	
	if(eZone[Zone_EntReference] == INVALID_ENT_REFERENCE)
		return 0;
	
	new iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
	if(iEnt < 1)
		return 0;
	
	// If the zone is imported we can't recreate it, but we should still call the TypeAssigned forward since it's called during CreateZoneEntity().
	if(eZone[Zone_IsImported])
	{
		Forward_TypeAssigned(iEnt, eZone[Zone_ID]);
		return iEnt;
	}
	
	AcceptEntityInput(iEnt, "KillHierarchy");
	return CreateZoneEntity(iZoneIndex);
}

bool:IsValidZoneID(iZoneID)
{
	if(g_iZoneIDToIndex[iZoneID] == INVALID_ZONE_ID)
		return false;
	
	return true;
}

SelectZone_Previous(iClient)
{
	new iArraySize = GetArraySize(g_aZones);
	if(!iArraySize)
		return;
	
	decl iIndex;
	if(g_iSelectedZoneID[iClient])
	{
		iIndex = g_iZoneIDToIndex[g_iSelectedZoneID[iClient]] - 1;
		if(iIndex < 0)
			iIndex = iArraySize - 1;
	}
	else
	{
		iIndex = 0;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, iIndex, eZone);
	SetSelectedZone(iClient, eZone[Zone_ID]);
	
	DisplayMenu_SelectZone(iClient);
}

SelectZone_Next(iClient)
{
	new iArraySize = GetArraySize(g_aZones);
	if(!iArraySize)
		return;
	
	decl iIndex;
	if(g_iSelectedZoneID[iClient])
	{
		iIndex = g_iZoneIDToIndex[g_iSelectedZoneID[iClient]] + 1;
		if(iIndex >= iArraySize)
			iIndex = 0;
	}
	else
	{
		iIndex = 0;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, iIndex, eZone);
	SetSelectedZone(iClient, eZone[Zone_ID]);
	
	DisplayMenu_SelectZone(iClient);
}

SetSelectedZone(iClient, iZoneID)
{
	g_iSelectedZoneID[iClient] = iZoneID;
	
	SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
	SetEntProp(iClient, Prop_Send, "m_nSolidType", SOLID_NONE);
	
	decl eZone[Zone], Float:fOrigin[3], Float:fAngles[3];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	fOrigin[0] = eZone[Zone_Origin][0] + ((eZone[Zone_Mins][0] + eZone[Zone_Maxs][0]) * 0.5);
	fOrigin[1] = eZone[Zone_Origin][1] + ((eZone[Zone_Mins][1] + eZone[Zone_Maxs][1]) * 0.5);
	fOrigin[2] = eZone[Zone_Origin][2] + ((eZone[Zone_Mins][2] + eZone[Zone_Maxs][2]) * 0.5);
	fOrigin[2] -= 50;
	
	fAngles[0] = eZone[Zone_Angles][0];
	fAngles[1] = eZone[Zone_Angles][1];
	fAngles[2] = eZone[Zone_Angles][2];
	
	TeleportEntity(iClient, fOrigin, fAngles, NULL_VECTOR);
}

GetNumPlayersSelectedZone(iZoneID)
{
	new iCount;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(g_iSelectedZoneID[iClient] == iZoneID)
			iCount++;
	}
	
	return iCount;
}

bool:IsTriggerEntAZone(const String:szTriggerName[], const Float:fOrigin[3], const Float:fMins[3], const Float:fMaxs[3])
{
	new bool:bFound;
	decl eZone[Zone];
	for(new i=0; i<GetArraySize(g_aZones); i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		
		if(!StrEqual(szTriggerName, eZone[Zone_ImportedName], false))
			continue;
		
		if(!(eZone[Zone_Origin][0] == fOrigin[0]
		&& eZone[Zone_Origin][1] == fOrigin[1]
		&& eZone[Zone_Origin][2] == fOrigin[2]))
			continue;
		
		if(!(eZone[Zone_Mins][0] == fMins[0]
		&& eZone[Zone_Mins][1] == fMins[1]
		&& eZone[Zone_Mins][2] == fMins[2]))
			continue;
		
		if(!(eZone[Zone_Maxs][0] == fMaxs[0]
		&& eZone[Zone_Maxs][1] == fMaxs[1]
		&& eZone[Zone_Maxs][2] == fMaxs[2]))
			continue;
		
		bFound = true;
	}
	
	return bFound;
}

PrepareAddZone_Client(iClient)
{
	decl Float:fOrigin[3], Float:fAngles[3];
	GetClientAbsOrigin(iClient, fOrigin);
	GetClientEyeAngles(iClient, fAngles);

	return AddZone(_, fOrigin, DEFAULT_ZONE_MINS, DEFAULT_ZONE_MAXS, fAngles);
}

PrepareAddZone_Trigger(iTriggerEnt)
{
	decl Float:fOrigin[3], Float:fAngles[3], Float:fMins[3], Float:fMaxs[3], String:szImportedName[MAX_VALUE_NAME_LENGTH];
	GetEntPropVector(iTriggerEnt, Prop_Send, "m_vecOrigin", fOrigin);
	GetEntPropVector(iTriggerEnt, Prop_Send, "m_angRotation", fAngles);
	GetEntPropVector(iTriggerEnt, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iTriggerEnt, Prop_Send, "m_vecMaxs", fMaxs);
	GetEntPropString(iTriggerEnt, Prop_Data, "m_iName", szImportedName, sizeof(szImportedName));
	
	return AddZone(_, fOrigin, fMins, fMaxs, fAngles, true, szImportedName, EntIndexToEntRef(iTriggerEnt));
}

FindFreeZoneID()
{
	for(new i=1; i<sizeof(g_iZoneIDToIndex); i++)
	{
		if(g_iZoneIDToIndex[i] == INVALID_ZONE_ID)
			return i;
	}
	
	return INVALID_ZONE_ID;
}

AddZone(iZoneID=0, const Float:fOrigin[3], const Float:fMins[3], const Float:fMaxs[3], const Float:fAngles[3], const bool:bIsImported=false, const String:szImportedName[]="", const iEntReference=INVALID_ENT_REFERENCE, const iZoneType=ZONE_TYPE_NOT_SET, const iDataInt1=0, const iDataInt2=0, const String:szDataString1[]="", const String:szDataString2[]="", const String:szDataString3[]="", const String:szDataString4[]="", const String:szDataString5[]="")
{
	if(GetArraySize(g_aZones) >= MAX_ZONES)
	{
		LogError("Max zones already created. Increase MAX_ZONES in the plugin source for more.");
		return 0;
	}
	
	if(iZoneID == 0)
	{
		if(!g_bAreZonesLoadedFromDB)
		{
			LogError("Zones must be loaded from the database before adding a new one.");
			return 0;
		}
		
		// Zone is not being loaded from database.
		iZoneID = FindFreeZoneID();
	}
	
	if(iZoneID < 1)
	{
		LogError("Zone ID %i is less than 1. Not sure what went wrong.", iZoneID);
		return 0;
	}
	
	if(iZoneID > MAX_ZONES)
	{
		LogError("Zone ID %i is greater than MAX_ZONES. Increase MAX_ZONES in the plugin source for more.", iZoneID);
		return 0;
	}
	
	decl eZone[Zone];
	eZone[Zone_ID] = iZoneID;
	
	eZone[Zone_Origin] = fOrigin;
	eZone[Zone_Mins] = fMins;
	eZone[Zone_Maxs] = fMaxs;
	eZone[Zone_Angles] = fAngles;
	
	eZone[Zone_Type] = iZoneType;
	eZone[Zone_EntReference] = iEntReference;
	
	eZone[Zone_Data_Int_1] = iDataInt1;
	eZone[Zone_Data_Int_2] = iDataInt2;
	strcopy(eZone[Zone_Data_String_1], MAX_ZONE_DATA_STRING_LENGTH, szDataString1);
	strcopy(eZone[Zone_Data_String_2], MAX_ZONE_DATA_STRING_LENGTH, szDataString2);
	strcopy(eZone[Zone_Data_String_3], MAX_ZONE_DATA_STRING_LENGTH, szDataString3);
	strcopy(eZone[Zone_Data_String_4], MAX_ZONE_DATA_STRING_LENGTH, szDataString4);
	strcopy(eZone[Zone_Data_String_5], MAX_ZONE_DATA_STRING_LENGTH, szDataString5);
	
	eZone[Zone_IsImported] = bIsImported;
	strcopy(eZone[Zone_ImportedName], MAX_VALUE_NAME_LENGTH, szImportedName);
	
	g_iZoneIDToIndex[eZone[Zone_ID]] = PushArrayArray(g_aZones, eZone);
	
	if(bIsImported)
	{
		HookZoneImportedEntity(g_iZoneIDToIndex[eZone[Zone_ID]]);
	}
	else
	{
		CreateZoneEntity(g_iZoneIDToIndex[eZone[Zone_ID]]);
	}
	
	// TODO: Should Forward_OnZoneCreated() also be called wherever we call HookZoneImportedEntity() and CreateZoneEntity()?
	Forward_OnZoneCreated(eZone[Zone_ID]);
	
	return eZone[Zone_ID];
}

HookZoneImportedEntity(iZoneIndex)
{
	decl eZone[Zone];
	GetArrayArray(g_aZones, iZoneIndex, eZone);
	
	decl String:szName[MAX_VALUE_NAME_LENGTH], Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
	for(new iEnt=1; iEnt<=GetMaxEntities(); iEnt++)
	{
		if(!IsValidEntity(iEnt))
			continue;
		
		GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
		if(!StrEqual(szName, eZone[Zone_ImportedName], false))
			continue;
		
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
		if(!(eZone[Zone_Origin][0] == fOrigin[0]
		&& eZone[Zone_Origin][1] == fOrigin[1]
		&& eZone[Zone_Origin][2] == fOrigin[2]))
			continue;
		
		GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
		if(!(eZone[Zone_Mins][0] == fMins[0]
		&& eZone[Zone_Mins][1] == fMins[1]
		&& eZone[Zone_Mins][2] == fMins[2]))
			continue;
		
		GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
		if(!(eZone[Zone_Maxs][0] == fMaxs[0]
		&& eZone[Zone_Maxs][1] == fMaxs[1]
		&& eZone[Zone_Maxs][2] == fMaxs[2]))
			continue;
		
		eZone[Zone_EntReference] = EntIndexToEntRef(iEnt);
		SetArrayArray(g_aZones, iZoneIndex, eZone);
		
		SDKHook(iEnt, SDKHook_TouchPost, OnTouchPost);
		SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost);
		SDKHook(iEnt, SDKHook_EndTouchPost, OnEndTouchPost);
		
		SetZoneID(iEnt, eZone[Zone_ID]);
		Forward_TypeAssigned(iEnt, eZone[Zone_ID]);
		
		break;
	}
}

CreateZoneEntity(iZoneIndex)
{
	new iEnt = CreateTrigger();
	if(!iEnt)
		return 0;
	
	decl eZone[Zone], Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
	GetArrayArray(g_aZones, iZoneIndex, eZone);
	eZone[Zone_EntReference] = EntIndexToEntRef(iEnt);
	SetArrayArray(g_aZones, iZoneIndex, eZone);
	
	fOrigin[0] = eZone[Zone_Origin][0];
	fOrigin[1] = eZone[Zone_Origin][1];
	fOrigin[2] = eZone[Zone_Origin][2];
	
	fMins[0] = eZone[Zone_Mins][0];
	fMins[1] = eZone[Zone_Mins][1];
	fMins[2] = eZone[Zone_Mins][2];
	
	fMaxs[0] = eZone[Zone_Maxs][0];
	fMaxs[1] = eZone[Zone_Maxs][1];
	fMaxs[2] = eZone[Zone_Maxs][2];
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SDKHook(iEnt, SDKHook_TouchPost, OnTouchPost);
	SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost);
	SDKHook(iEnt, SDKHook_EndTouchPost, OnEndTouchPost);
	
	SetZoneID(iEnt, eZone[Zone_ID]);
	Forward_TypeAssigned(iEnt, eZone[Zone_ID]);
	
	return iEnt;
}

CreateTrigger()
{
	//new iEnt = CreateEntityByName("trigger_multiple");
	new iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1 || !IsValidEntity(iEnt))
		return 0;
	
	// WARNING: Don't use a brush based model for this or can have incorrect touch detection.
	// Using a non-brush model will give a warning in the server console but it seems to work fine.
	//GetEntPropString(0, Prop_Data, "m_ModelName", szModelName, sizeof(szModelName));
	//SetEntityModel(iEnt, szModelName);
	
	SetEntityModel(iEnt, SZ_ZONE_MODEL);
	
	//DispatchKeyValue(iEnt, "spawnflags", "1");
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID|FSOLID_TRIGGER);
	
	SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_NODRAW);
	
	return iEnt;
}

public OnTouchPost(iZone, iOther)
{
	static iZoneID;
	iZoneID = GetZoneID(iZone);
	
	if(g_iZoneIDToIndex[iZoneID] == INVALID_ZONE_ID || g_iZoneIDToIndex[iZoneID] >= GetArraySize(g_aZones))
		return;
	
	static eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	static iIndex;
	iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
		return;
	
	static eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	if(eZoneType[ZoneType_ForwardTouch] == INVALID_HANDLE)
		return;
	
	static result;
	Call_StartForward(eZoneType[ZoneType_ForwardTouch]);
	Call_PushCell(iZone);
	Call_PushCell(iOther);
	Call_Finish(result);
}

public OnStartTouchPost(iZone, iOther)
{
	static iZoneID;
	iZoneID = GetZoneID(iZone);
	
	static eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	new iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
		return;
	
	static eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	if(eZoneType[ZoneType_ForwardStartTouch] == INVALID_HANDLE)
		return;
	
	static result;
	Call_StartForward(eZoneType[ZoneType_ForwardStartTouch]);
	Call_PushCell(iZone);
	Call_PushCell(iOther);
	Call_Finish(result);
}

public OnEndTouchPost(iZone, iOther)
{
	static iZoneID;
	iZoneID = GetZoneID(iZone);
	
	static eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[iZoneID], eZone);
	
	new iIndex = GetZoneTypeIndexFromID(eZone[Zone_Type]);
	if(iIndex == -1)
		return;
	
	static eZoneType[ZoneType];
	GetArrayArray(g_aZoneTypes, iIndex, eZoneType);
	
	if(eZoneType[ZoneType_ForwardEndTouch] == INVALID_HANDLE)
		return;
	
	static result;
	Call_StartForward(eZoneType[ZoneType_ForwardEndTouch]);
	Call_PushCell(iZone);
	Call_PushCell(iOther);
	Call_Finish(result);
}

public OnPreThinkPost(iClient)
{
	if(!g_bInZoneMenu[iClient])
	{
		SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
		return;
	}
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	TryUpdateZoneBox(iClient, fCurTime);
	EditZone_Position_TryUpdate(iClient, fCurTime);
	EditZone_Size_TryUpdate(iClient, fCurTime);
}

TryUpdateZoneBox(iClient, const Float:fCurTime)
{
	if(fCurTime < g_fNextDisplayBoxTime[iClient])
		return;
	
	g_fNextDisplayBoxTime[iClient] = fCurTime + DISPLAY_BOX_DELAY;
	
	// Show the zone we're editing.
	if(IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintHintText(iClient, "%i players editing this zone.", GetNumPlayersSelectedZone(g_iSelectedZoneID[iClient]));
		ShowZoneBox(iClient, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], BOX_BEAM_WIDTH, ZONE_EDIT_COLOR);
	}
	
	// Show the X additional zones closest to us.
	static i, j, k, eZone[Zone], Float:fClientOrigin[3], Float:fZoneOrigin[3], Float:fDistance;
	static iNumRadiusZones, iRadiusZoneIndexes[ZONES_TO_SHOW_IN_RADIUS], Float:fRadiusZoneDistances[ZONES_TO_SHOW_IN_RADIUS];
	
	GetClientAbsOrigin(iClient, fClientOrigin);
	iNumRadiusZones = 0;
	
	for(i=0; i<GetArraySize(g_aZones); i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		
		// If this zone is our selected zone continue.
		if(eZone[Zone_ID] == g_iSelectedZoneID[iClient])
			continue;
		
		fZoneOrigin[0] = eZone[Zone_Origin][0];
		fZoneOrigin[1] = eZone[Zone_Origin][1];
		fZoneOrigin[2] = eZone[Zone_Origin][2];
		fDistance = GetVectorDistance(fClientOrigin, fZoneOrigin);
		
		// Loop through the current radius zones to see if this distance is shorter.
		for(j=0; j<iNumRadiusZones; j++)
		{
			// If the distance isn't shorter continue.
			if(fDistance >= fRadiusZoneDistances[j])
				continue;
			
			// Start at our highest index and move every index up one until we reach our target index.
			for(k=(iNumRadiusZones - 1); k>=j; k--)
			{
				// Continue if we have no room to move up.
				if(k >= (sizeof(iRadiusZoneIndexes) - 1))
					continue;
				
				iRadiusZoneIndexes[k+1] = iRadiusZoneIndexes[k];
				fRadiusZoneDistances[k+1] = fRadiusZoneDistances[k];
			}
			
			// Replace the old index.
			iRadiusZoneIndexes[j] = i;
			fRadiusZoneDistances[j] = fDistance;
			
			iNumRadiusZones++;
			if(iNumRadiusZones > sizeof(iRadiusZoneIndexes))
				iNumRadiusZones = sizeof(iRadiusZoneIndexes);
			
			break;
		}
		
		// If didn't break early continue.
		if(j < iNumRadiusZones)
			continue;
		
		// If we don't have anymore room continue.
		if(iNumRadiusZones >= sizeof(iRadiusZoneIndexes))
			continue;
		
		iRadiusZoneIndexes[iNumRadiusZones] = i;
		fRadiusZoneDistances[iNumRadiusZones] = fDistance;
		
		iNumRadiusZones++;
		if(iNumRadiusZones > sizeof(iRadiusZoneIndexes))
			iNumRadiusZones = sizeof(iRadiusZoneIndexes);
	}
	
	for(i=0; i<iNumRadiusZones; i++)
		ShowZoneBox(iClient, iRadiusZoneIndexes[i], BOX_BEAM_WIDTH_RADIUS, ZONE_EDIT_COLOR_RADIUS);
}

ShowZoneBox(iClient, iZoneIndex, Float:fBeamWidth, const iColor[4])
{
	static eZone[Zone];
	if(!GetArrayArray(g_aZones, iZoneIndex, eZone))
		return;
	
	static iEnt;
	iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
	if(iEnt < 1 || iEnt == INVALID_ENT_REFERENCE)
		return;
	
	static Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3], i;
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	new Float:fVertices[8][3];
	
	// Add the entities origin to all the vertices.
	for(i=0; i<8; i++)
	{
		fVertices[i][0] += fOrigin[0];
		fVertices[i][1] += fOrigin[1];
		fVertices[i][2] += fOrigin[2];
	}
	
	// Set the vertices origins.
	fVertices[0][2] += fMins[2];
	fVertices[1][2] += fMins[2];
	fVertices[2][2] += fMins[2];
	fVertices[3][2] += fMins[2];
	
	fVertices[4][2] += fMaxs[2];
	fVertices[5][2] += fMaxs[2];
	fVertices[6][2] += fMaxs[2];
	fVertices[7][2] += fMaxs[2];
	
	fVertices[0][0] += fMins[0];
	fVertices[0][1] += fMins[1];
	fVertices[1][0] += fMins[0];
	fVertices[1][1] += fMaxs[1];
	fVertices[2][0] += fMaxs[0];
	fVertices[2][1] += fMaxs[1];
	fVertices[3][0] += fMaxs[0];
	fVertices[3][1] += fMins[1];
	
	fVertices[4][0] += fMins[0];
	fVertices[4][1] += fMins[1];
	fVertices[5][0] += fMins[0];
	fVertices[5][1] += fMaxs[1];
	fVertices[6][0] += fMaxs[0];
	fVertices[6][1] += fMaxs[1];
	fVertices[7][0] += fMaxs[0];
	fVertices[7][1] += fMins[1];
	
	// Draw the horizontal beams.
	for(i=0; i<4; i++)
	{
		if(i != 3)
			TE_SetupBeamPoints(fVertices[i], fVertices[i+1], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, fBeamWidth, fBeamWidth, 0, 0.0, iColor, 10);
		else
			TE_SetupBeamPoints(fVertices[i], fVertices[0], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, fBeamWidth, fBeamWidth, 0, 0.0, iColor, 10);
		
		TE_SendToClient(iClient);
	}
	
	for(i=4; i<8; i++)
	{
		if(i != 7)
			TE_SetupBeamPoints(fVertices[i], fVertices[i+1], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, fBeamWidth, fBeamWidth, 0, 0.0, iColor, 10);
		else
			TE_SetupBeamPoints(fVertices[i], fVertices[4], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, fBeamWidth, fBeamWidth, 0, 0.0, iColor, 10);
		
		TE_SendToClient(iClient);
	}
	
	// Draw the vertical beams.
	for(i=0; i<4; i++)
	{
		TE_SetupBeamPoints(fVertices[i], fVertices[i+4], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, fBeamWidth, fBeamWidth, 0, 0.0, iColor, 10);
		TE_SendToClient(iClient);
	}
	
	// Draw the forward indicator.
	fVertices[0][0] = fOrigin[0] + ((fMins[0] + fMaxs[0]) * 0.5);
	fVertices[0][1] = fOrigin[1] + ((fMins[1] + fMaxs[1]) * 0.5);
	fVertices[0][2] = fOrigin[2] + ((fMins[2] + fMaxs[2]) * 0.5);
	
	fVertices[2][0] = eZone[Zone_Angles][0];
	fVertices[2][1] = eZone[Zone_Angles][1];
	fVertices[2][2] = eZone[Zone_Angles][2];
	GetAngleVectors(fVertices[2], fVertices[2], NULL_VECTOR, NULL_VECTOR);
	
	fVertices[1] = fVertices[0];
	//fVertices[1][0] += ((fMaxs[0] - fMins[0]) * 0.5);
	fVertices[1][0] += (fVertices[2][0] * 64.0);
	fVertices[1][1] += (fVertices[2][1] * 64.0);
	fVertices[1][2] += (fVertices[2][2] * 64.0);
	
	TE_SetupBeamPoints(fVertices[0], fVertices[1], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, fBeamWidth, fBeamWidth, 0, 0.0, iColor, 10);
	TE_SendToClient(iClient);
}

EditZone_Position_TryUpdate(iClient, const Float:fCurTime)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
		return;
	
	if(!g_bIsEditingPosition[iClient])
		return;
	
	if(fCurTime < g_fNextUpdateCheckPosition[iClient])
		return;
	
	g_fNextUpdateCheckPosition[iClient] = fCurTime + UPDATE_CHECK_TIME_POSITION;
	
	static eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	static iEnt;
	iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
	if(iEnt < 1 || iEnt == INVALID_ENT_REFERENCE)
		return;
	
	static iButtons;
	iButtons = GetClientButtons(iClient);
	
	if(iButtons & IN_ATTACK)
	{
		g_fEditPositionDistance[iClient] += 4.0;
	}
	else if(iButtons & IN_ATTACK2)
	{
		g_fEditPositionDistance[iClient] -= 4.0;
		if(g_fEditPositionDistance[iClient] < 32.0)
			g_fEditPositionDistance[iClient] = 32.0;
	}
	
	static Float:fOrigin[3], Float:fAngles[3];
	GetClientEyePosition(iClient, fOrigin);
	GetClientEyeAngles(iClient, fAngles);
	GetAngleVectors(fAngles, fAngles, NULL_VECTOR, NULL_VECTOR);
	
	fOrigin[0] = fOrigin[0] + (fAngles[0] * g_fEditPositionDistance[iClient]);
	fOrigin[1] = fOrigin[1] + (fAngles[1] * g_fEditPositionDistance[iClient]);
	fOrigin[2] = fOrigin[2] + (fAngles[2] * g_fEditPositionDistance[iClient]);
	
	fOrigin[0] -= ((eZone[Zone_Mins][0] + eZone[Zone_Maxs][0]) * 0.5);
	fOrigin[1] -= ((eZone[Zone_Mins][1] + eZone[Zone_Maxs][1]) * 0.5);
	fOrigin[2] -= ((eZone[Zone_Mins][2] + eZone[Zone_Maxs][2]) * 0.5);
	
	eZone[Zone_Origin][0] = fOrigin[0];
	eZone[Zone_Origin][1] = fOrigin[1];
	eZone[Zone_Origin][2] = fOrigin[2];
	
	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
}

ExpandToWall(iClient)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
	{
		PrintToChat(iClient, "Error expanding. Invalid zone ID.");
		return;
	}
	
	decl eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	new iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
	if(iEnt < 1 || iEnt == INVALID_ENT_REFERENCE)
	{
		PrintToChat(iClient, "Error expanding. Invalid zone entity.");
		return;
	}
	
	decl Float:fAngles[3], Float:fMins[3], Float:fMaxs[3];
	GetClientEyeAngles(iClient, fAngles);
	
	fMins[0] = eZone[Zone_Mins][0];
	fMins[1] = eZone[Zone_Mins][1];
	fMins[2] = eZone[Zone_Mins][2];
	
	fMaxs[0] = eZone[Zone_Maxs][0];
	fMaxs[1] = eZone[Zone_Maxs][1];
	fMaxs[2] = eZone[Zone_Maxs][2];
	
	new Float:fDirection[3];
	if(fAngles[0] > 45.0)
	{
		fDirection[2] = -1.0;
	}
	else if(fAngles[0] < -45.0)
	{
		fDirection[2] = 1.0;
	}
	
	// 90 = +y
	// -90 = -y
	// 0 = +x
	// -180 = -x
	
	if(FloatAbs(fAngles[0]) < 45.0)
	{
		if(fAngles[1] > 45 && fAngles[1] < 135)
		{
			fDirection[1] = 1.0;
		}
		else if(fAngles[1] < -45 && fAngles[1] > -135)
		{
			fDirection[1] = -1.0;
		}
		
		if(fAngles[1] > -45 && fAngles[1] < 45)
		{
			fDirection[0] = 1.0;
		}
		else if(fAngles[1] > 135 || fAngles[1] < -135)
		{
			fDirection[0] = -1.0;
		}
	}
	
	decl Float:fDirectionAngles[3];
	GetVectorAngles(fDirection, fDirectionAngles);
	
	decl Float:fEyePos[3], Float:fEndPos[3];
	GetClientEyePosition(iClient, fEyePos);
	TR_TraceRayFilter(fEyePos, fAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_DontHitPlayers);
	TR_GetEndPosition(fEndPos);
	
	decl Float:fZoneOrigin[3];
	fZoneOrigin[0] = eZone[Zone_Origin][0];
	fZoneOrigin[1] = eZone[Zone_Origin][1];
	fZoneOrigin[2] = eZone[Zone_Origin][2];
	
	if(fDirection[0] == 0.0)
		fEndPos[0] = fZoneOrigin[0];
	
	if(fDirection[1] == 0.0)
		fEndPos[1] = fZoneOrigin[1];
	
	if(fDirection[2] == 0.0)
		fEndPos[2] = fZoneOrigin[2];
	
	new Float:fDistance = GetVectorDistance(fZoneOrigin, fEndPos);
	
	if(fDirection[0] < 0.0)
	{
		fMins[0] = -fDistance;
		
		if(fMins[0] >= fMaxs[0])
			fMins[0] = fMaxs[0] - 1.0;
	}
	else if(fDirection[0] > 0.0)
	{
		fMaxs[0] = fDistance;
		
		if(fMaxs[0] <= fMins[0])
			fMaxs[0] = fMins[0] + 1.0;
	}
	
	if(fDirection[1] < 0.0)
	{
		fMins[1] = -fDistance;
		
		if(fMins[1] >= fMaxs[1])
			fMins[1] = fMaxs[1] - 1.0;
	}
	else if(fDirection[1] > 0.0)
	{
		fMaxs[1] = fDistance;
		
		if(fMaxs[1] <= fMins[1])
			fMaxs[1] = fMins[1] + 1.0;
	}
	
	if(fDirection[2] < 0.0)
	{
		fMins[2] = -fDistance;
		
		if(fMins[2] >= fMaxs[2])
			fMins[2] = fMaxs[2] - 1.0;
	}
	else if(fDirection[2] > 0.0)
	{
		fMaxs[2] = fDistance;
		
		if(fMaxs[2] <= fMins[2])
			fMaxs[2] = fMins[2] + 1.0;
	}
	
	eZone[Zone_Mins][0] = fMins[0];
	eZone[Zone_Mins][1] = fMins[1];
	eZone[Zone_Mins][2] = fMins[2];
	
	eZone[Zone_Maxs][0] = fMaxs[0];
	eZone[Zone_Maxs][1] = fMaxs[1];
	eZone[Zone_Maxs][2] = fMaxs[2];
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	SetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	PrintToChat(iClient, "[SM] Expanding zone to wall.");
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}

EditZone_Size_TryUpdate(iClient, const Float:fCurTime)
{
	if(!IsValidZoneID(g_iSelectedZoneID[iClient]))
		return;
	
	if(!g_bIsEditingSize[iClient])
		return;
	
	static iButtons;
	iButtons = GetClientButtons(iClient);
	
	if(!(iButtons & IN_ATTACK) && !(iButtons & IN_ATTACK2))
		return;
	
	if(fCurTime < g_fNextUpdateCheckSize[iClient])
		return;
	
	g_fNextUpdateCheckSize[iClient] = fCurTime + UPDATE_CHECK_TIME_SIZE;
	
	static eZone[Zone];
	GetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
	
	static iEnt;
	iEnt = EntRefToEntIndex(eZone[Zone_EntReference]);
	if(iEnt < 1 || iEnt == INVALID_ENT_REFERENCE)
		return;
	
	static Float:fAngles[3], Float:fMins[3], Float:fMaxs[3];
	GetClientEyeAngles(iClient, fAngles);
	
	fMins[0] = eZone[Zone_Mins][0];
	fMins[1] = eZone[Zone_Mins][1];
	fMins[2] = eZone[Zone_Mins][2];
	
	fMaxs[0] = eZone[Zone_Maxs][0];
	fMaxs[1] = eZone[Zone_Maxs][1];
	fMaxs[2] = eZone[Zone_Maxs][2];
	
	static iMoveAmount;
	if(iButtons & IN_ATTACK)
	{
		iMoveAmount = 4;
	}
	else if(iButtons & IN_ATTACK2)
	{
		iMoveAmount = -4;
	}
	
	SetMinsMaxsByAngles(fAngles, fMins, fMaxs, iMoveAmount);
	
	eZone[Zone_Mins][0] = fMins[0];
	eZone[Zone_Mins][1] = fMins[1];
	eZone[Zone_Mins][2] = fMins[2];
	
	eZone[Zone_Maxs][0] = fMaxs[0];
	eZone[Zone_Maxs][1] = fMaxs[1];
	eZone[Zone_Maxs][2] = fMaxs[2];
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	SetArrayArray(g_aZones, g_iZoneIDToIndex[g_iSelectedZoneID[iClient]], eZone);
}

SetMinsMaxsByAngles(const Float:fAngles[3], Float:fMins[3], Float:fMaxs[3], const iDistanceToExpand)
{
	// pitch: negative = up, positive = down
	// if abs(pitch) > 45 then dont modify yaw
	
	// 90 = +y
	// -90 = -y
	// 0 = +x
	// -180 = -x
	
	if(fAngles[0] > 45.0)
	{
		fMins[2] -= iDistanceToExpand;
		
		if(fMins[2] >= fMaxs[2])
			fMins[2] = fMaxs[2] - 1.0;
	}
	else if(fAngles[0] < -45.0)
	{
		fMaxs[2] += iDistanceToExpand;
		
		if(fMaxs[2] <= fMins[2])
			fMaxs[2] = fMins[2] + 1.0;
	}
	
	if(FloatAbs(fAngles[0]) < 45.0)
	{
		if(fAngles[1] > 60 && fAngles[1] < 120)
		{
			fMaxs[1] += iDistanceToExpand;
			
			if(fMaxs[1] <= fMins[1])
				fMaxs[1] = fMins[1] + 1.0;
		}
		else if(fAngles[1] < -60 && fAngles[1] > -120)
		{
			fMins[1] -= iDistanceToExpand;
			
			if(fMins[1] >= fMaxs[1])
				fMins[1] = fMaxs[1] - 1.0;
		}
		
		if(fAngles[1] > -30 && fAngles[1] < 30)
		{
			fMaxs[0] += iDistanceToExpand;
			
			if(fMaxs[0] <= fMins[0])
				fMaxs[0] = fMins[0] + 1.0;
		}
		else if(fAngles[1] > 150 || fAngles[1] < -150)
		{
			fMins[0] -= iDistanceToExpand;
			
			if(fMins[0] >= fMaxs[0])
				fMins[0] = fMaxs[0] - 1.0;
		}
	}
}

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateDataTable())
		return;
}

bool:Query_CreateDataTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_zonemanager_data\
	(\
		game_id			SMALLINT UNSIGNED	NOT NULL,\
		map_id			MEDIUMINT UNSIGNED	NOT NULL,\
		zone_id			INT UNSIGNED		NOT NULL,\
		\
		is_imported		BIT( 1 )			NOT NULL,\
		imported_name	TEXT				NOT NULL,\
		\
		origin0			FLOAT( 11, 6 )		NOT NULL,\
		origin1			FLOAT( 11, 6 )		NOT NULL,\
		origin2			FLOAT( 11, 6 )		NOT NULL,\
		\
		mins0			FLOAT( 11, 6 )		NOT NULL,\
		mins1			FLOAT( 11, 6 )		NOT NULL,\
		mins2			FLOAT( 11, 6 )		NOT NULL,\
		\
		maxs0			FLOAT( 11, 6 )		NOT NULL,\
		maxs1			FLOAT( 11, 6 )		NOT NULL,\
		maxs2			FLOAT( 11, 6 )		NOT NULL,\
		\
		angles0			FLOAT( 11, 6 )		NOT NULL,\
		angles1			FLOAT( 11, 6 )		NOT NULL,\
		angles2			FLOAT( 11, 6 )		NOT NULL,\
		\
		type			SMALLINT UNSIGNED	NOT NULL,\
		data_int_1		INT					NOT NULL,\
		data_int_2		INT					NOT NULL,\
		data_string_1	VARCHAR( 255 )		NOT NULL,\
		data_string_2	VARCHAR( 255 )		NOT NULL,\
		data_string_3	VARCHAR( 255 )		NOT NULL,\
		data_string_4	VARCHAR( 255 )		NOT NULL,\
		data_string_5	VARCHAR( 255 )		NOT NULL,\
		\
		PRIMARY KEY ( game_id, map_id, zone_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the plugin_zonemanager_data sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public DBMaps_OnMapIDReady(iMapID)
{
	GetZonesForMapID(iMapID, true, 0);
}

bool:GetZonesForMapID(iMapID, bool:bIsCurrentMap, iClient)
{
	// Return false if a client is trying to load the current map from the menu.
	if(!bIsCurrentMap && iMapID == DBMaps_GetMapID())
		return false;
	
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, g_iUniqueMapCounter);
	WritePackCell(hPack, bIsCurrentMap);
	
	if(iClient)
		WritePackCell(hPack, GetClientSerial(iClient));
	else
		WritePackCell(hPack, 0);
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetZones, DBPrio_High, hPack, "\
		SELECT zone_id, CAST(is_imported AS signed) as is_imported, imported_name,\
		origin0, origin1, origin2,\
		mins0, mins1, mins2,\
		maxs0, maxs1, maxs2,\
		angles0, angles1, angles2,\
		type, data_int_1, data_int_2, data_string_1, data_string_2, data_string_3, data_string_4, data_string_5 \
		\
		FROM plugin_zonemanager_data \
		WHERE (game_id = %i OR game_id = 0) AND map_id = %i", DBServers_GetGameID(), iMapID);
	
	return true;
}

AddZonesFromQuery(Handle:hQuery, bool:bIsZeroQuery)
{
	decl String:szImportedName[MAX_VALUE_NAME_LENGTH];
	decl String:szDataString1[MAX_ZONE_DATA_STRING_LENGTH], String:szDataString2[MAX_ZONE_DATA_STRING_LENGTH], String:szDataString3[MAX_ZONE_DATA_STRING_LENGTH], String:szDataString4[MAX_ZONE_DATA_STRING_LENGTH], String:szDataString5[MAX_ZONE_DATA_STRING_LENGTH];
	decl Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3], Float:fAngles[3], iZoneID;
	
	if(bIsZeroQuery)
		SQL_Rewind(hQuery);
	
	new bool:bFoundZeroID;
	while(SQL_FetchRow(hQuery))
	{
		iZoneID = SQL_FetchInt(hQuery, 0);
		
		if(bIsZeroQuery)
		{
			if(iZoneID)
				continue;
			
			// Since the zone_id was originally 0 we need to find it a new id.
			iZoneID = FindFreeZoneID();
		}
		else
		{
			if(!iZoneID)
			{
				bFoundZeroID = true;
				continue;
			}
		}
		
		SQL_FetchString(hQuery, 2, szImportedName, sizeof(szImportedName));
		SQL_FetchString(hQuery, 18, szDataString1, sizeof(szDataString1));
		SQL_FetchString(hQuery, 19, szDataString2, sizeof(szDataString2));
		SQL_FetchString(hQuery, 20, szDataString3, sizeof(szDataString3));
		SQL_FetchString(hQuery, 21, szDataString4, sizeof(szDataString4));
		SQL_FetchString(hQuery, 22, szDataString5, sizeof(szDataString5));
		
		fOrigin[0] = SQL_FetchFloat(hQuery, 3);
		fOrigin[1] = SQL_FetchFloat(hQuery, 4);
		fOrigin[2] = SQL_FetchFloat(hQuery, 5);
		
		fMins[0] = SQL_FetchFloat(hQuery, 6);
		fMins[1] = SQL_FetchFloat(hQuery, 7);
		fMins[2] = SQL_FetchFloat(hQuery, 8);
		
		fMaxs[0] = SQL_FetchFloat(hQuery, 9);
		fMaxs[1] = SQL_FetchFloat(hQuery, 10);
		fMaxs[2] = SQL_FetchFloat(hQuery, 11);
		
		fAngles[0] = SQL_FetchFloat(hQuery, 12);
		fAngles[1] = SQL_FetchFloat(hQuery, 13);
		fAngles[2] = SQL_FetchFloat(hQuery, 14);
		
		AddZone(iZoneID, fOrigin, fMins, fMaxs, fAngles, bool:SQL_FetchInt(hQuery, 1), szImportedName, _, SQL_FetchInt(hQuery, 15), SQL_FetchInt(hQuery, 16), SQL_FetchInt(hQuery, 17), szDataString1, szDataString2, szDataString3, szDataString4, szDataString5);
		
		if(bIsZeroQuery)
			break;
	}
	
	return bFoundZeroID;
}

public Query_GetZones(Handle:hDatabase, Handle:hQuery, any:hPack)
{
	ResetPack(hPack, false);
	new iUniqueMapCounter = ReadPackCell(hPack);
	new bool:bIsCurrentMap = bool:ReadPackCell(hPack);
	new iClient = GetClientFromSerial(ReadPackCell(hPack));
	CloseHandle(hPack);
	
	if(g_iUniqueMapCounter != iUniqueMapCounter)
	{
		Forward_OnZonesLoaded();
		return;
	}
	
	if(hQuery == INVALID_HANDLE)
	{
		Forward_OnZonesLoaded();
		return;
	}
	
	// Load all none 0 zone_ids first.
	// Then load the 0 zone_id if needed. We must do this last since we have to create a new custom zone_id for it and we have to make sure we don't use a zone_id that is already being loaded.
	// The reason 0 even exists in the database for a zone_id is because we used to save as 0-n, but now 0 should never be used as a zone_id anymore.
	if(AddZonesFromQuery(hQuery, false))
		AddZonesFromQuery(hQuery, true);
	
	if(bIsCurrentMap)
		g_bAreZonesLoadedFromDB = true;
	
	if(iClient)
	{
		new iRows = SQL_GetRowCount(hQuery);
		if(iRows)
			PrintToChat(iClient, "[SM] %i zones have been imported.", iRows);
		else
			PrintToChat(iClient, "[SM] There were no zones to import.");
		
		DisplayMenu_ZoneManager(iClient);
	}
	
	Forward_OnZonesLoaded();
}

bool:TransactionStart_SaveZones()
{
	new Handle:hDatabase = DB_GetDatabaseHandleFromConnectionName(g_szDatabaseConfigName);
	if(hDatabase == INVALID_HANDLE)
		return false;
	
	new iGameID = DBServers_GetGameID();
	new iMapID = DBMaps_GetMapID();
	
	if(!iGameID || !iMapID)
		return false;
	
	decl String:szQuery[2048];
	new Handle:hTransaction = SQL_CreateTransaction();
	
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM plugin_zonemanager_data WHERE game_id = %i AND map_id = %i", iGameID, iMapID);
	SQL_AddQuery(hTransaction, szQuery);
	
	decl eZone[Zone], String:szEscapedImportedName[MAX_VALUE_NAME_LENGTH*2+1];
	decl String:szEscapedString1[MAX_ZONE_DATA_STRING_LENGTH*2+1], String:szEscapedString2[MAX_ZONE_DATA_STRING_LENGTH*2+1], String:szEscapedString3[MAX_ZONE_DATA_STRING_LENGTH*2+1], String:szEscapedString4[MAX_ZONE_DATA_STRING_LENGTH*2+1], String:szEscapedString5[MAX_ZONE_DATA_STRING_LENGTH*2+1];
	for(new i=0; i<GetArraySize(g_aZones); i++)
	{
		GetArrayArray(g_aZones, i, eZone);
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eZone[Zone_ImportedName], szEscapedImportedName, sizeof(szEscapedImportedName)))
			continue;
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eZone[Zone_Data_String_1], szEscapedString1, sizeof(szEscapedString1)))
			continue;
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eZone[Zone_Data_String_2], szEscapedString2, sizeof(szEscapedString2)))
			continue;
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eZone[Zone_Data_String_3], szEscapedString3, sizeof(szEscapedString3)))
			continue;
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eZone[Zone_Data_String_4], szEscapedString4, sizeof(szEscapedString4)))
			continue;
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eZone[Zone_Data_String_5], szEscapedString5, sizeof(szEscapedString5)))
			continue;
		
		FormatEx(szQuery, sizeof(szQuery), "\
			INSERT IGNORE INTO plugin_zonemanager_data \
			(game_id, map_id, zone_id, is_imported, imported_name, origin0, origin1, origin2, mins0, mins1, mins2, maxs0, maxs1, maxs2, angles0, angles1, angles2, type, data_int_1, data_int_2, data_string_1, data_string_2, data_string_3, data_string_4, data_string_5) \
			VALUES \
			(%i, %i, %i, %i, '%s', %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %i, %i, %i, '%s', '%s', '%s', '%s', '%s')",
			iGameID, iMapID, eZone[Zone_ID], eZone[Zone_IsImported], szEscapedImportedName,
			eZone[Zone_Origin][0], eZone[Zone_Origin][1], eZone[Zone_Origin][2],
			eZone[Zone_Mins][0], eZone[Zone_Mins][1], eZone[Zone_Mins][2],
			eZone[Zone_Maxs][0], eZone[Zone_Maxs][1], eZone[Zone_Maxs][2],
			eZone[Zone_Angles][0], eZone[Zone_Angles][1], eZone[Zone_Angles][2],
			eZone[Zone_Type], eZone[Zone_Data_Int_1], eZone[Zone_Data_Int_2], szEscapedString1, szEscapedString2, szEscapedString3, szEscapedString4, szEscapedString5);
		
		SQL_AddQuery(hTransaction, szQuery);
	}
	
	SQL_ExecuteTransaction(hDatabase, hTransaction, _, _, _, DBPrio_High);
	
	return true;
}

LogChanges(iClient, iLogType, iZoneType)
{
	new iUserID = DBUsers_GetUserID(iClient);
	new iMapID = DBMaps_GetMapID();
	
	UserLogs_AddLog(iUserID, USER_LOG_TYPE_ZONEMANAGER, _, iMapID, iLogType, iZoneType);
}