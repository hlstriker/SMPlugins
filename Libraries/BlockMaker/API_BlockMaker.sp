#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_trace>
#include <sdktools_engine>
#include <sdktools_entinput>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <emitsoundany>
#include "block_maker"
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/DatabaseServers/database_servers"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Block Maker";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API for managing blocks.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szDefaultBlockFiles[][] =
{
	"models/swoobles/blocks/platform/block.mdl",
	"models/swoobles/blocks/platform/block.dx90.vtx",
	"models/swoobles/blocks/platform/block.phy",
	"models/swoobles/blocks/platform/block.vvd",
	
	"materials/swoobles/blocks/platform/block.vtf",
	"materials/swoobles/blocks/platform/block.vmt"
};

new String:g_szRandomBlockFiles[][] =
{
	"models/swoobles/blocks/random/block.mdl",
	"models/swoobles/blocks/random/block.dx90.vtx",
	"models/swoobles/blocks/random/block.phy",
	"models/swoobles/blocks/random/block.vvd",
	
	"materials/swoobles/blocks/random/block.vtf",
	"materials/swoobles/blocks/random/block.vmt"
};

new Handle:g_hTrie_BlockIDToIndex;
new Handle:g_aBlocks;
enum _:Block
{
	Block_ID,
	Float:Block_Origin[3],
	Float:Block_Angles[3],
	Block_TypeID,
	Block_EntReference,
	String:Block_DataString[MAX_BLOCK_DATA_STRING_LEN]
};

new Handle:g_hTrie_TypeIDToIndex;
new Handle:g_hTrie_TypeNameToID;
new Handle:g_aBlockTypes;
enum _:BlockType
{
	BlockType_ID,
	Handle:BlockType_BlockIDs,
	String:BlockType_Name[MAX_BLOCK_TYPE_NAME_LEN],
	String:BlockType_NameDisplay[MAX_BLOCK_TYPE_NAME_LEN],
	String:BlockType_Model[PLATFORM_MAX_PATH],
	Handle:BlockType_ForwardTouch,
	Handle:BlockType_ForwardStartTouch,
	Handle:BlockType_ForwardEndTouch,
	Handle:BlockType_ForwardTypeAssigned,
	Handle:BlockType_ForwardTypeUnassigned,
	Handle:BlockType_ForwardEditData,
	String:BlockType_SoundStartTouch[PLATFORM_MAX_PATH],
	String:BlockType_SoundTouch[PLATFORM_MAX_PATH],
	bool:BlockType_AllowRandom
};

new Handle:g_hTrie_BlockIDToTouchDelayIndex;
new Handle:g_aTouchDelayTries;

new Handle:g_hTrie_BlockIDToRandomTypeIndex;
new Handle:g_aRandomTypeTries;

enum
{
	MENU_MAIN_ADD = 1,
	MENU_MAIN_COPY,
	MENU_MAIN_CHANGE_TYPE,
	MENU_MAIN_EDIT,
	MAIN_MAIN_DELETE
};

enum
{
	MENU_EDIT_MOVE = 1,
	MENU_EDIT_SNAP,
	MENU_EDIT_PITCH,
	MENU_EDIT_YAW,
	MENU_EDIT_ROLL,
	MENU_EDIT_CHANGE_TYPE,
	MENU_EDIT_DATA,
	MENU_EDIT_DELETE
};

new g_iEditingBlockEntRef[MAXPLAYERS+1];
new bool:g_bIsMovingBlock[MAXPLAYERS+1];

#define MOVE_DISTANCE_DEFAULT	128.0
new Float:g_fEditMoveDistance[MAXPLAYERS+1];

#define GRID_SIZE_DEFAULT	8.0
#define GRID_SIZE_MAX		128.0
new Float:g_fGridSize[MAXPLAYERS+1];

#define SOLID_NONE		0
#define SOLID_VPHYSICS	6

new g_iDefaultTypeID;
new g_iRandomTypeID;
new Handle:g_aAllowedRandomTypeIDs;

new g_iUniqueMapCounter;
new bool:g_bAreBlocksLoadedFromDB;
new bool:g_bNeedsForceSaved;

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:g_hFwd_OnRegisterReady;
new Handle:g_hFwd_OnBlocksLoaded;
new Handle:g_hFwd_OnTypeAssigned;
new Handle:g_hFwd_OnTypeUnassigned;
new Handle:g_hFwd_OnBlockCreated;
new Handle:g_hFwd_OnBlockRemoved_Pre;
new Handle:g_hFwd_OnBlockRemoved_Post;
new Handle:g_hFwd_OnDataChanged;

new Handle:cvar_max_blocks_total;
new Handle:cvar_safe_ent_amount;
new Handle:cvar_disable_building;

#define DISPLAY_BOX_DELAY	0.1
#define BEAM_WIDTH			1.0
new const g_iBeamColor[] = {255, 255, 255, 255};
new g_iBeamIndex;
new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";


public OnPluginStart()
{
	CreateConVar("api_block_maker_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_max_blocks_total = CreateConVar("bm_max_blocks_total", "2000", "The maximum amount of blocks that can be created.");
	cvar_safe_ent_amount = CreateConVar("bm_safe_ent_amount", "350", "Stop making blocks when getting this close to the entity limit.");
	cvar_disable_building = CreateConVar("bm_disable_building", "0", "Disable block building.");
	
	g_aBlocks = CreateArray(Block);
	g_hTrie_BlockIDToIndex = CreateTrie();
	
	g_aBlockTypes = CreateArray(BlockType);
	g_hTrie_TypeIDToIndex = CreateTrie();
	g_hTrie_TypeNameToID = CreateTrie();
	
	g_aAllowedRandomTypeIDs = CreateArray();
	
	g_aTouchDelayTries = CreateArray();
	g_hTrie_BlockIDToTouchDelayIndex = CreateTrie();
	
	g_aRandomTypeTries = CreateArray();
	g_hTrie_BlockIDToRandomTypeIndex = CreateTrie();
	
	g_hFwd_OnRegisterReady = CreateGlobalForward("BlockMaker_OnRegisterReady", ET_Ignore);
	g_hFwd_OnBlocksLoaded = CreateGlobalForward("BlockMaker_OnBlocksLoaded", ET_Ignore);
	g_hFwd_OnTypeAssigned = CreateGlobalForward("BlockMaker_OnTypeAssigned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnTypeUnassigned = CreateGlobalForward("BlockMaker_OnTypeUnassigned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnBlockCreated = CreateGlobalForward("BlockMaker_OnBlockCreated", ET_Ignore, Param_Cell);
	g_hFwd_OnBlockRemoved_Pre = CreateGlobalForward("BlockMaker_OnBlockRemoved_Pre", ET_Ignore, Param_Cell, Param_Cell);
	g_hFwd_OnBlockRemoved_Post = CreateGlobalForward("BlockMaker_OnBlockRemoved_Post", ET_Ignore, Param_Cell, Param_Cell);
	g_hFwd_OnDataChanged = CreateGlobalForward("BlockMaker_OnDataChanged", ET_Ignore, Param_Cell, Param_Cell);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_Post);
	
	RegAdminCmd("sm_bm", OnBlockMaker, ADMFLAG_BAN, "Opens the block maker.");
	RegAdminCmd("sm_blockmaker", OnBlockMaker, ADMFLAG_BAN, "Opens the block maker.");
	
	RegAdminCmd("sm_badd", OnBlockAdd, ADMFLAG_BAN, "Adds a block.");
	RegAdminCmd("sm_bedit", OnBlockEdit, ADMFLAG_BAN, "Edits a block.");
	RegAdminCmd("sm_bcopy", OnBlockCopy, ADMFLAG_BAN, "Copys a block.");
	RegAdminCmd("sm_btype", OnBlockChangeType, ADMFLAG_BAN, "Changes a blocks type.");
	RegAdminCmd("sm_bdel", OnBlockDelete, ADMFLAG_BAN, "Deletes a block.");
	RegAdminCmd("sm_bclosest", OnBlockSelectClosest, ADMFLAG_BAN, "Edits the closest block.");
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

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("block_maker");
	CreateNative("BlockMaker_RegisterBlockType", _BlockMaker_RegisterBlockType);
	CreateNative("BlockMaker_SetSounds", _BlockMaker_SetSounds);
	CreateNative("BlockMaker_AllowAsRandom", _BlockMaker_AllowAsRandom);
	CreateNative("BlockMaker_GetBlocksByType", _BlockMaker_GetBlocksByType);
	CreateNative("BlockMaker_GetBlockEntFromID", _BlockMaker_GetBlockEntFromID);
	CreateNative("BlockMaker_GetBlockTypeID", _BlockMaker_GetBlockTypeID);
	CreateNative("BlockMaker_GetBlockTypeNameFromID", _BlockMaker_GetBlockTypeNameFromID);
	CreateNative("BlockMaker_GetBlockTypeIDFromName", _BlockMaker_GetBlockTypeIDFromName);
	CreateNative("BlockMaker_GetDataString", _BlockMaker_GetDataString);
	CreateNative("BlockMaker_SetDataString", _BlockMaker_SetDataString);
	CreateNative("BlockMaker_FinishedEditingBlockData", _BlockMaker_FinishedEditingBlockData);
	CreateNative("BlockMaker_RestartEditingBlockData", _BlockMaker_RestartEditingBlockData);
	CreateNative("BlockMaker_DisplayMenu_EditBlock", _BlockMaker_DisplayMenu_EditBlock);
	
	return APLRes_Success;
}

public _BlockMaker_GetBlockTypeIDFromName(Handle:hPlugin, iNumParams)
{
	decl String:szTypeName[MAX_BLOCK_TYPE_NAME_LEN];
	GetNativeString(1, szTypeName, sizeof(szTypeName));
	
	return GetBlockTypeIDFromName(szTypeName);
}

public _BlockMaker_GetBlockTypeNameFromID(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockTypeIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return false;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	if(GetNativeCell(2))
		SetNativeString(3, eBlockType[BlockType_Name], GetNativeCell(4));
	else
		SetNativeString(3, eBlockType[BlockType_NameDisplay], GetNativeCell(4));
	
	return true;
}

public _BlockMaker_FinishedEditingBlockData(Handle:hPlugin, iNumParams)
{
	StopMovingBlock(GetNativeCell(1));
}

public _BlockMaker_RestartEditingBlockData(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockIndexFromID(GetNativeCell(2));
	if(iIndex == -1)
		return;
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	if(EntRefToEntIndex(eBlock[Block_EntReference]) < 1)
		return;
	
	StartMovingBlock(GetNativeCell(1), eBlock[Block_EntReference]);
}

public _BlockMaker_DisplayMenu_EditBlock(Handle:hPlugin, iNumParams)
{
	DisplayMenu_EditBlock(GetNativeCell(1), GetNativeCell(2));
}

public _BlockMaker_GetDataString(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return false;
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	SetNativeString(2, eBlock[Block_DataString], GetNativeCell(3));
	
	return true;
}

public _BlockMaker_SetDataString(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return false;
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	GetNativeString(2, eBlock[Block_DataString], MAX_BLOCK_DATA_STRING_LEN);
	SetArrayArray(g_aBlocks, iIndex, eBlock);
	
	Forward_OnDataChanged(eBlock[Block_ID], eBlock[Block_TypeID]);
	
	return true;
}

Forward_OnDataChanged(iBlockID, iBlockType)
{
	Call_StartForward(g_hFwd_OnDataChanged);
	Call_PushCell(iBlockID);
	Call_PushCell(iBlockType);
	Call_Finish();
}

public _BlockMaker_GetBlockTypeID(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return 0;
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	return eBlock[Block_TypeID];
}

public _BlockMaker_GetBlockEntFromID(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return -1;
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	new iBlockEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
	if(iBlockEnt < 1)
		return -1;
	
	return iBlockEnt;
}

public _BlockMaker_GetBlocksByType(Handle:hPlugin, iNumParams)
{
	new Handle:hArray = GetNativeCell(2);
	if(hArray == INVALID_HANDLE)
		return false;
	
	new iIndex = GetBlockTypeIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return false;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	new iArraySize = GetArraySize(eBlockType[BlockType_BlockIDs]);
	for(new i=0; i<iArraySize; i++)
		PushArrayCell(hArray, GetArrayCell(eBlockType[BlockType_BlockIDs], i));
	
	return true;
}

public _BlockMaker_RegisterBlockType(Handle:hPlugin, iNumParams)
{
	decl String:szTypeName[MAX_BLOCK_TYPE_NAME_LEN];
	GetNativeString(1, szTypeName, sizeof(szTypeName));
	
	new iTypeNameLen = strlen(szTypeName);
	decl String:szTypeNameLower[iTypeNameLen+1];
	szTypeNameLower[iTypeNameLen] = '\x0';
	
	for(new i=0; i<iTypeNameLen; i++)
		szTypeNameLower[i] = CharToLower(szTypeName[i]);
	
	decl eBlockType[BlockType];
	for(new i=0; i<GetArraySize(g_aBlockTypes); i++)
	{
		GetArrayArray(g_aBlockTypes, i, eBlockType);
		
		if(!StrEqual(szTypeNameLower, eBlockType[BlockType_Name]))
			continue;
		
		LogError("Block type \"%s\" is already registered in another plugin.", szTypeNameLower);
		return 0;
	}
	
	decl String:szModel[PLATFORM_MAX_PATH], Function:callback;
	GetNativeString(2, szModel, sizeof(szModel));
	
	new Handle:hForwardTouch, Handle:hForwardStartTouch, Handle:hForwardEndTouch, Handle:hForwardTypeAssigned, Handle:hForwardTypeUnassigned, Handle:hForwardEditData;
	
	// Touch callback.
	callback = GetNativeCell(3);
	if(callback != INVALID_FUNCTION)
	{
		hForwardTouch = CreateForward(ET_Hook, Param_Cell, Param_Cell);
		AddToForward(hForwardTouch, hPlugin, callback);
	}
	
	// StartTouch callback.
	callback = GetNativeCell(4);
	if(callback != INVALID_FUNCTION)
	{
		hForwardStartTouch = CreateForward(ET_Hook, Param_Cell, Param_Cell);
		AddToForward(hForwardStartTouch, hPlugin, callback);
	}
	
	// EndTouch callback.
	callback = GetNativeCell(5);
	if(callback != INVALID_FUNCTION)
	{
		hForwardEndTouch = CreateForward(ET_Hook, Param_Cell, Param_Cell);
		AddToForward(hForwardEndTouch, hPlugin, callback);
	}
	
	// Type assigned callback.
	callback = GetNativeCell(6);
	if(callback != INVALID_FUNCTION)
	{
		hForwardTypeAssigned = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(hForwardTypeAssigned, hPlugin, callback);
	}
	
	// Type unassigned callback.
	callback = GetNativeCell(7);
	if(callback != INVALID_FUNCTION)
	{
		hForwardTypeUnassigned = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(hForwardTypeUnassigned, hPlugin, callback);
	}
	
	// Edit data callback.
	callback = GetNativeCell(8);
	if(callback != INVALID_FUNCTION)
	{
		hForwardEditData = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(hForwardEditData, hPlugin, callback);
	}
	
	return AddBlockType(szTypeName, szModel, hForwardTouch, hForwardStartTouch, hForwardEndTouch, hForwardTypeAssigned, hForwardTypeUnassigned, hForwardEditData);
}

public _BlockMaker_SetSounds(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockTypeIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return false;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	decl String:szSound[PLATFORM_MAX_PATH];
	GetNativeString(2, szSound, sizeof(szSound));
	if(!StrEqual(szSound, ""))
	{
		strcopy(eBlockType[BlockType_SoundStartTouch], PLATFORM_MAX_PATH, szSound[6]);
		PrecacheSoundAny(szSound[6], true);
		AddFileToDownloadsTable(szSound);
	}
	
	GetNativeString(3, szSound, sizeof(szSound));
	if(!StrEqual(szSound, ""))
	{
		strcopy(eBlockType[BlockType_SoundTouch], PLATFORM_MAX_PATH, szSound[6]);
		PrecacheSoundAny(szSound[6], true);
		AddFileToDownloadsTable(szSound);
	}
	
	SetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	return true;
}

public _BlockMaker_AllowAsRandom(Handle:hPlugin, iNumParams)
{
	new iIndex = GetBlockTypeIndexFromID(GetNativeCell(1));
	if(iIndex == -1)
		return false;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	eBlockType[BlockType_AllowRandom] = GetNativeCell(2);
	SetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	iIndex = FindValueInArray(g_aAllowedRandomTypeIDs, eBlockType[BlockType_ID]);
	
	if(eBlockType[BlockType_AllowRandom])
	{
		if(iIndex == -1)
			PushArrayCell(g_aAllowedRandomTypeIDs, eBlockType[BlockType_ID]);
	}
	else
	{
		if(iIndex != -1)
			RemoveFromArray(g_aAllowedRandomTypeIDs, iIndex);
	}
	
	return true;
}

public OnMapStart()
{
	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL);
	
	g_iUniqueMapCounter++;
	g_bAreBlocksLoadedFromDB = false;
	g_bNeedsForceSaved = false;
	
	// Default block
	for(new i=0; i<sizeof(g_szDefaultBlockFiles); i++)
		AddFileToDownloadsTable(g_szDefaultBlockFiles[i]);
	
	PrecacheModel(g_szDefaultBlockFiles[0], true);
	
	// Random block
	for(new i=0; i<sizeof(g_szRandomBlockFiles); i++)
		AddFileToDownloadsTable(g_szRandomBlockFiles[i]);
	
	PrecacheModel(g_szRandomBlockFiles[0], true);
	
	decl eBlockType[BlockType];
	for(new i=0; i<GetArraySize(g_aBlockTypes); i++)
	{
		GetArrayArray(g_aBlockTypes, i, eBlockType);
		
		if(eBlockType[BlockType_BlockIDs] != INVALID_HANDLE)
			CloseHandle(eBlockType[BlockType_BlockIDs]);
		
		if(eBlockType[BlockType_ForwardTouch] != INVALID_HANDLE)
			CloseHandle(eBlockType[BlockType_ForwardTouch]);
		
		if(eBlockType[BlockType_ForwardStartTouch] != INVALID_HANDLE)
			CloseHandle(eBlockType[BlockType_ForwardStartTouch]);
		
		if(eBlockType[BlockType_ForwardEndTouch] != INVALID_HANDLE)
			CloseHandle(eBlockType[BlockType_ForwardEndTouch]);
		
		if(eBlockType[BlockType_ForwardTypeAssigned] != INVALID_HANDLE)
			CloseHandle(eBlockType[BlockType_ForwardTypeAssigned]);
		
		if(eBlockType[BlockType_ForwardTypeUnassigned] != INVALID_HANDLE)
			CloseHandle(eBlockType[BlockType_ForwardTypeUnassigned]);
		
		if(eBlockType[BlockType_ForwardEditData] != INVALID_HANDLE)
			CloseHandle(eBlockType[BlockType_ForwardEditData]);
	}
	
	decl Handle:hTrie;
	for(new i=0; i<GetArraySize(g_aTouchDelayTries); i++)
	{
		hTrie = GetArrayCell(g_aTouchDelayTries, i);
		if(hTrie != INVALID_HANDLE)
			CloseHandle(hTrie);
	}
	
	ClearArray(g_aBlocks);
	ClearArray(g_aBlockTypes);
	ClearArray(g_aTouchDelayTries);
	ClearArray(g_aRandomTypeTries);
	ClearArray(g_aAllowedRandomTypeIDs);
	ClearTrie(g_hTrie_BlockIDToIndex);
	ClearTrie(g_hTrie_TypeIDToIndex);
	ClearTrie(g_hTrie_TypeNameToID);
	ClearTrie(g_hTrie_BlockIDToTouchDelayIndex);
	ClearTrie(g_hTrie_BlockIDToRandomTypeIndex);
	
	g_iDefaultTypeID = AddBlockType("Platform", g_szDefaultBlockFiles[0]);
	
	Call_StartForward(g_hFwd_OnRegisterReady);
	Call_Finish();
	
	if(GetArraySize(g_aAllowedRandomTypeIDs))
		g_iRandomTypeID = AddBlockType("Random", g_szRandomBlockFiles[0]);
	else
		g_iRandomTypeID = 0;
	
	SortBlockTypesByName();
}

SortBlockTypesByName()
{
	new iArraySize = GetArraySize(g_aBlockTypes);
	decl String:szName[MAX_BLOCK_TYPE_NAME_LEN], eBlockType[BlockType], j, iIndex, iID, iID2, String:szTypeID[12];
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aBlockTypes, i, eBlockType);
		strcopy(szName, sizeof(szName), eBlockType[BlockType_Name]);
		iIndex = 0;
		iID = eBlockType[BlockType_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aBlockTypes, j, eBlockType);
			if(strcmp(szName, eBlockType[BlockType_Name], false) < 0)
				continue;
			
			iIndex = j;
			iID2 = eBlockType[BlockType_ID];
			strcopy(szName, sizeof(szName), eBlockType[BlockType_Name]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aBlockTypes, i, iIndex);
		
		// We must swap the IDtoIndex too.
		IntToString(iID, szTypeID, sizeof(szTypeID));
		SetTrieValue(g_hTrie_TypeIDToIndex, szTypeID, iIndex, true);
		
		IntToString(iID2, szTypeID, sizeof(szTypeID));
		SetTrieValue(g_hTrie_TypeIDToIndex, szTypeID, i, true);
	}
}

AddBlockType(const String:szTypeName[], const String:szModel[], const Handle:hForwardTouch=INVALID_HANDLE, const Handle:hForwardStartTouch=INVALID_HANDLE, const Handle:hForwardEndTouch=INVALID_HANDLE, const Handle:hForwardTypeAssigned=INVALID_HANDLE, const Handle:hForwardTypeUnassigned=INVALID_HANDLE, const Handle:hForwardEditData=INVALID_HANDLE)
{
	new iTypeNameLen = strlen(szTypeName);
	decl String:szTypeNameLower[iTypeNameLen+1];
	szTypeNameLower[iTypeNameLen] = '\x0';
	
	for(new i=0; i<iTypeNameLen; i++)
		szTypeNameLower[i] = CharToLower(szTypeName[i]);
	
	new iTypeID = GetArraySize(g_aBlockTypes) + 1;
	
	decl eBlockType[BlockType];
	eBlockType[BlockType_ID] = iTypeID;
	eBlockType[BlockType_BlockIDs] = CreateArray();
	strcopy(eBlockType[BlockType_Name], MAX_BLOCK_TYPE_NAME_LEN, szTypeNameLower);
	strcopy(eBlockType[BlockType_NameDisplay], MAX_BLOCK_TYPE_NAME_LEN, szTypeName);
	strcopy(eBlockType[BlockType_Model], PLATFORM_MAX_PATH, szModel);
	eBlockType[BlockType_ForwardTouch] = hForwardTouch;
	eBlockType[BlockType_ForwardStartTouch] = hForwardStartTouch;
	eBlockType[BlockType_ForwardEndTouch] = hForwardEndTouch;
	eBlockType[BlockType_ForwardTypeAssigned] = hForwardTypeAssigned;
	eBlockType[BlockType_ForwardTypeUnassigned] = hForwardTypeUnassigned;
	eBlockType[BlockType_ForwardEditData] = hForwardEditData;
	strcopy(eBlockType[BlockType_SoundStartTouch], PLATFORM_MAX_PATH, "");
	strcopy(eBlockType[BlockType_SoundTouch], PLATFORM_MAX_PATH, "");
	eBlockType[BlockType_AllowRandom] = false;
	
	new iIndex = PushArrayArray(g_aBlockTypes, eBlockType);
	
	decl String:szTypeID[12];
	IntToString(iTypeID, szTypeID, sizeof(szTypeID));
	SetTrieValue(g_hTrie_TypeIDToIndex, szTypeID, iIndex, true);
	SetTrieValue(g_hTrie_TypeNameToID, szTypeNameLower, iTypeID, true);
	
	return iTypeID;
}

public Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RecreateAllBlocks();
}

RecreateAllBlocks()
{
	if(!g_bAreBlocksLoadedFromDB)
		return;
	
	new iArraySize = GetArraySize(g_aBlocks);
	decl eBlock[Block], Float:fOrigin[3], Float:fAngles[3];
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aBlocks, i, eBlock);
		
		fOrigin[0] = eBlock[Block_Origin][0];
		fOrigin[1] = eBlock[Block_Origin][1];
		fOrigin[2] = eBlock[Block_Origin][2];
		
		fAngles[0] = eBlock[Block_Angles][0];
		fAngles[1] = eBlock[Block_Angles][1];
		fAngles[2] = eBlock[Block_Angles][2];
		
		CreateBlockEntity(eBlock[Block_ID], eBlock[Block_TypeID], fOrigin, fAngles);
	}
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_Blocks())
		SetFailState("There was an error creating the plugin_blockmaker_blocks sql table.");
}

bool:Query_CreateTable_Blocks()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_blockmaker_blocks\
	(\
		game_id		SMALLINT UNSIGNED	NOT NULL,\
		map_id		MEDIUMINT UNSIGNED	NOT NULL,\
		block_id	INT UNSIGNED		NOT NULL,\
		type_name	VARCHAR( 255 )		NOT NULL,\
		origin0		FLOAT( 11, 6 )		NOT NULL,\
		origin1		FLOAT( 11, 6 )		NOT NULL,\
		origin2		FLOAT( 11, 6 )		NOT NULL,\
		angles0		FLOAT( 11, 6 )		NOT NULL,\
		angles1		FLOAT( 11, 6 )		NOT NULL,\
		angles2		FLOAT( 11, 6 )		NOT NULL,\
		data_string	VARCHAR( 255 )		NOT NULL,\
		PRIMARY KEY ( game_id, map_id, block_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public DBMaps_OnMapIDReady(iMapID)
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetBlocks, DBPrio_High, g_iUniqueMapCounter, "\
		SELECT block_id, type_name,\
		origin0, origin1, origin2,\
		angles0, angles1, angles2, \
		data_string \
		FROM plugin_blockmaker_blocks \
		WHERE (game_id = %i OR game_id = 0) AND map_id = %i", DBServers_GetGameID(), iMapID);
}

public Query_GetBlocks(Handle:hDatabase, Handle:hQuery, any:iUniqueMapCounter)
{
	if(g_iUniqueMapCounter != iUniqueMapCounter)
		return;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	AddBlocksFromQuery(hQuery);
	g_bAreBlocksLoadedFromDB = true;
	
	Forward_OnBlocksLoaded();
}

Forward_OnBlocksLoaded()
{
	Call_StartForward(g_hFwd_OnBlocksLoaded);
	Call_Finish();
}

AddBlocksFromQuery(Handle:hQuery)
{
	decl String:szTypeName[PLATFORM_MAX_PATH], Float:fOrigin[3], Float:fAngles[3], iType, String:szDataString[MAX_BLOCK_DATA_STRING_LEN];
	
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 1, szTypeName, sizeof(szTypeName));
		
		iType = GetBlockTypeIDFromName(szTypeName);
		if(!iType)
			continue;
		
		fOrigin[0] = SQL_FetchFloat(hQuery, 2);
		fOrigin[1] = SQL_FetchFloat(hQuery, 3);
		fOrigin[2] = SQL_FetchFloat(hQuery, 4);
		
		fAngles[0] = AngleNormalize(SQL_FetchFloat(hQuery, 5));
		fAngles[1] = AngleNormalize(SQL_FetchFloat(hQuery, 6));
		fAngles[2] = AngleNormalize(SQL_FetchFloat(hQuery, 7));
		
		SQL_FetchString(hQuery, 8, szDataString, sizeof(szDataString));
		
		AddBlock(_, SQL_FetchInt(hQuery, 0), iType, fOrigin, fAngles, szDataString);
	}
}

public OnMapEnd()
{
	if(!g_bNeedsForceSaved)
		return;
	
	TransactionStart_SaveBlocks();
}

bool:TransactionStart_SaveBlocks()
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
	
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM plugin_blockmaker_blocks WHERE game_id = %i AND map_id = %i", iGameID, iMapID);
	SQL_AddQuery(hTransaction, szQuery);
	
	decl eBlock[Block], String:szEscapedTypeName[MAX_BLOCK_TYPE_NAME_LEN*2+1], iIndex, String:szID[12], eBlockType[BlockType], String:szEscapedDataString[MAX_BLOCK_DATA_STRING_LEN*2+1];
	for(new i=0; i<GetArraySize(g_aBlocks); i++)
	{
		GetArrayArray(g_aBlocks, i, eBlock);
		
		IntToString(eBlock[Block_TypeID], szID, sizeof(szID));
		if(!GetTrieValue(g_hTrie_TypeIDToIndex, szID, iIndex))
			continue;
		
		GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eBlockType[BlockType_Name], szEscapedTypeName, sizeof(szEscapedTypeName)))
			continue;
		
		if(!DB_EscapeString(g_szDatabaseConfigName, eBlock[Block_DataString], szEscapedDataString, sizeof(szEscapedDataString)))
			continue;
		
		FormatEx(szQuery, sizeof(szQuery), "\
			INSERT IGNORE INTO plugin_blockmaker_blocks \
			(game_id, map_id, block_id, type_name, origin0, origin1, origin2, angles0, angles1, angles2, data_string) \
			VALUES \
			(%i, %i, %i, '%s', %f, %f, %f, %f, %f, %f, '%s')",
			iGameID, iMapID, eBlock[Block_ID],
			szEscapedTypeName,
			eBlock[Block_Origin][0], eBlock[Block_Origin][1], eBlock[Block_Origin][2],
			eBlock[Block_Angles][0], eBlock[Block_Angles][1], eBlock[Block_Angles][2],
			szEscapedDataString);
		
		SQL_AddQuery(hTransaction, szQuery);
	}
	
	SQL_ExecuteTransaction(hDatabase, hTransaction, _, _, _, DBPrio_High);
	
	return true;
}

GetBlockTypeIDFromName(const String:szTypeName[])
{
	new iTypeNameLen = strlen(szTypeName);
	decl String:szTypeNameLower[iTypeNameLen+1];
	szTypeNameLower[iTypeNameLen] = '\x0';
	
	for(new i=0; i<iTypeNameLen; i++)
		szTypeNameLower[i] = CharToLower(szTypeName[i]);
	
	decl iTypeID;
	if(!GetTrieValue(g_hTrie_TypeNameToID, szTypeNameLower, iTypeID))
		return 0;
	
	return iTypeID;
}

GetBlockTypeIndexFromID(iTypeID)
{
	decl iIndex, String:szID[12];
	IntToString(iTypeID, szID, sizeof(szID));
	
	if(!GetTrieValue(g_hTrie_TypeIDToIndex, szID, iIndex))
		return -1;
	
	return iIndex;
}

PrintBlocksLoadingMessage(iClient)
{
	ReplyToCommand(iClient, "[SM] Please wait for the blocks to finish loading from the database.");
}

public Action:OnBlockAdd(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_disable_building))
	{
		ReplyToCommand(iClient, "Block building is disabled.");
		return Plugin_Handled;
	}
	
	if(!g_bAreBlocksLoadedFromDB)
	{
		PrintBlocksLoadingMessage(iClient);
		return Plugin_Handled;
	}
	
	g_bNeedsForceSaved = true;
	TryAddBlock(iClient);
	
	return Plugin_Handled;
}

public Action:OnBlockEdit(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_disable_building))
	{
		ReplyToCommand(iClient, "Block building is disabled.");
		return Plugin_Handled;
	}
	
	if(!g_bAreBlocksLoadedFromDB)
	{
		PrintBlocksLoadingMessage(iClient);
		return Plugin_Handled;
	}
	
	g_bNeedsForceSaved = true;
	TryEditBlock(iClient);
	
	return Plugin_Handled;
}

public Action:OnBlockCopy(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_disable_building))
	{
		ReplyToCommand(iClient, "Block building is disabled.");
		return Plugin_Handled;
	}
	
	if(!g_bAreBlocksLoadedFromDB)
	{
		PrintBlocksLoadingMessage(iClient);
		return Plugin_Handled;
	}
	
	g_bNeedsForceSaved = true;
	TryCopyBlock(iClient);
	
	return Plugin_Handled;
}

public Action:OnBlockChangeType(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_disable_building))
	{
		ReplyToCommand(iClient, "Block building is disabled.");
		return Plugin_Handled;
	}
	
	if(!g_bAreBlocksLoadedFromDB)
	{
		PrintBlocksLoadingMessage(iClient);
		return Plugin_Handled;
	}
	
	new iTypeID;
	if(iArgNum)
	{
		decl String:szTypeName[MAX_BLOCK_TYPE_NAME_LEN];
		GetCmdArgString(szTypeName, sizeof(szTypeName));
		StripQuotes(szTypeName);
		TrimString(szTypeName);
		iTypeID = GetBlockTypeIDFromName(szTypeName);
		
		if(!iTypeID)
			ReplyToCommand(iClient, "Could not find the type name you specified.");
	}
	
	g_bNeedsForceSaved = true;
	TryChangeBlockType(iClient, iTypeID);
	
	return Plugin_Handled;
}

public Action:OnBlockDelete(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_disable_building))
	{
		ReplyToCommand(iClient, "Block building is disabled.");
		return Plugin_Handled;
	}
	
	if(!g_bAreBlocksLoadedFromDB)
	{
		PrintBlocksLoadingMessage(iClient);
		return Plugin_Handled;
	}
	
	g_bNeedsForceSaved = true;
	TryDeleteBlock(iClient);
	
	return Plugin_Handled;
}

public Action:OnBlockSelectClosest(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_disable_building))
	{
		ReplyToCommand(iClient, "Block building is disabled.");
		return Plugin_Handled;
	}
	
	if(!g_bAreBlocksLoadedFromDB)
	{
		PrintBlocksLoadingMessage(iClient);
		return Plugin_Handled;
	}
	
	g_bNeedsForceSaved = true;
	TrySelectClosestBlock(iClient);
	
	return Plugin_Handled;
}

public Action:OnBlockMaker(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_disable_building))
	{
		ReplyToCommand(iClient, "Block building is disabled.");
		return Plugin_Handled;
	}
	
	if(!g_bAreBlocksLoadedFromDB)
	{
		PrintBlocksLoadingMessage(iClient);
		return Plugin_Handled;
	}
	
	g_bNeedsForceSaved = true;
	DisplayMenu_BlockMaker(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_BlockMaker(iClient)
{
	CancelClientMenu(iClient);
	
	// Keep in mind GetEntityCount() isn't the real edict count. It's the highest amount of edicts that have been in the server so far.
	// The server might reuse indexes before the number ever increases. The number will not decrease.
	new iMaxEnts = GetMaxEntities();
	
	new iSafeMaxEntities = iMaxEnts - GetConVarInt(cvar_safe_ent_amount);
	new iMaxBlocks = GetConVarInt(cvar_max_blocks_total);
	if(iMaxBlocks > iSafeMaxEntities)
		iMaxBlocks = iSafeMaxEntities;
	
	decl String:szTitle[64];
	FormatEx(szTitle, sizeof(szTitle), "Block Maker [%i / %i]\nEdict Count [%i / %i]", GetArraySize(g_aBlocks), iMaxBlocks, GetEntityCount(), iMaxEnts);
	
	new Handle:hMenu = CreateMenu(MenuHandle_BlockMaker);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[4];
	IntToString(MENU_MAIN_ADD, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Add block");
	
	IntToString(MENU_MAIN_COPY, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Copy block");
	
	IntToString(MENU_MAIN_EDIT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit block");
	
	IntToString(MENU_MAIN_CHANGE_TYPE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Change block type");
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	IntToString(MAIN_MAIN_DELETE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Delete block");
	
	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{red}Error displaying menu.");
}

TryAddBlock(iClient)
{
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	
	new iBlockID = AddBlock(iClient, _, g_iDefaultTypeID, fOrigin, Float:{0.0, 0.0, 0.0});
	if(iBlockID)
	{
		g_bIsMovingBlock[iClient] = true;
		DisplayMenu_EditBlock(iClient, iBlockID);
	}
	else
		DisplayMenu_BlockMaker(iClient);
}

TryCopyBlock(iClient)
{
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	
	new iBlockID = CopyBlock(iClient, fOrigin);
	if(iBlockID)
	{
		g_bIsMovingBlock[iClient] = true;
		DisplayMenu_EditBlock(iClient, iBlockID);
	}
	else
		DisplayMenu_BlockMaker(iClient);
}

TryChangeBlockType(iClient, iTypeID=0)
{
	new iTargetBlock = GetAimedAtBlock(iClient);
	if(!iTargetBlock)
	{
		CPrintToChat(iClient, "{red}You must aim at the block you want to change.");
		DisplayMenu_BlockMaker(iClient);
		return;
	}
	
	new iBlockID = GetEntityBlockID(iTargetBlock);
	if(!IsValidBlockID(iBlockID))
	{
		CPrintToChat(iClient, "{red}The target is not a valid block.");
		DisplayMenu_BlockMaker(iClient);
		return;
	}
	
	g_bIsMovingBlock[iClient] = false;
	
	if(iTypeID)
		ChangeBlockType(iClient, iBlockID, iTypeID);
	else
		DisplayMenu_EditBlockType(iClient, iBlockID);
}

TryDeleteBlock(iClient)
{
	new iTargetBlock = GetAimedAtBlock(iClient);
	if(!iTargetBlock)
	{
		CPrintToChat(iClient, "{red}You must aim at the block you want to delete.");
		DisplayMenu_BlockMaker(iClient);
		return;
	}
	
	new iIndex = GetBlockIndexFromID(GetEntityBlockID(iTargetBlock));
	if(iIndex == -1)
	{
		CPrintToChat(iClient, "{red}The target is not a valid block.");
		DisplayMenu_BlockMaker(iClient);
		return;
	}
	
	DeleteBlock(iClient, iIndex);
	DisplayMenu_BlockMaker(iClient);
}

TryEditBlock(iClient, iBlockID=0)
{
	if(!iBlockID)
	{
		new iTargetBlock = GetAimedAtBlock(iClient);
		if(!iTargetBlock)
		{
			CPrintToChat(iClient, "{red}You must aim at the block you want to edit.");
			DisplayMenu_BlockMaker(iClient);
			return;
		}
		
		iBlockID = GetEntityBlockID(iTargetBlock);
		if(!IsValidBlockID(iBlockID))
		{
			CPrintToChat(iClient, "{red}The target is not a valid block.");
			DisplayMenu_BlockMaker(iClient);
			return;
		}
	}
	
	g_bIsMovingBlock[iClient] = false;
	g_fEditMoveDistance[iClient] = MOVE_DISTANCE_DEFAULT;
	DisplayMenu_EditBlock(iClient, iBlockID);
}

TrySelectClosestBlock(iClient)
{
	decl Float:fClientOrigin[3];
	GetClientAbsOrigin(iClient, fClientOrigin);
	
	new iBlockID, iArraySize = GetArraySize(g_aBlocks);
	
	decl eBlock[Block], iEnt, Float:fOrigin[3], Float:fClosestDist, Float:fDist;
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aBlocks, i, eBlock);
		
		if(eBlock[Block_EntReference] == INVALID_ENT_REFERENCE)
			continue;
		
		iEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
		if(iEnt < 1)
			continue;
		
		fOrigin[0] = eBlock[Block_Origin][0];
		fOrigin[1] = eBlock[Block_Origin][1];
		fOrigin[2] = eBlock[Block_Origin][2];
		
		fDist = GetVectorDistance(fClientOrigin, fOrigin);
		if(i > 0 && fDist >= fClosestDist)
			continue;
		
		fClosestDist = fDist;
		iBlockID = eBlock[Block_ID];
	}
	
	if(!iBlockID)
	{
		CPrintToChat(iClient, "{red}Could not find any blocks.");
		return;
	}
	
	TryEditBlock(iClient, iBlockID);
}

public MenuHandle_BlockMaker(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENU_MAIN_ADD:			TryAddBlock(iParam1);
		case MENU_MAIN_COPY:		TryCopyBlock(iParam1);
		case MENU_MAIN_CHANGE_TYPE:	TryChangeBlockType(iParam1);
		case MAIN_MAIN_DELETE:		TryDeleteBlock(iParam1);
		case MENU_MAIN_EDIT:		TryEditBlock(iParam1);
	}
}

public OnClientPutInServer(iClient)
{
	g_fGridSize[iClient] = GRID_SIZE_DEFAULT;
	g_fEditMoveDistance[iClient] = MOVE_DISTANCE_DEFAULT;
}

bool:IsValidBlockID(iBlockID)
{
	if(GetBlockIndexFromID(iBlockID) == -1)
		return false;
	
	return true;
}

bool:DisplayMenu_EditBlock(iClient, iBlockID, iStartItem=0)
{
	CancelClientMenu(iClient);
	
	new iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
	{
		CPrintToChat(iClient, "{red}The target is no longer a valid block.");
		DisplayMenu_BlockMaker(iClient);
		return false;
	}
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	new iBlockEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
	if(iBlockEnt < 1)
	{
		CPrintToChat(iClient, "{red}The entity you are editing is no longer valid.");
		DisplayMenu_BlockMaker(iClient);
		return false;
	}
	
	StartMovingBlock(iClient, eBlock[Block_EntReference]);
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditBlock);
	SetMenuTitle(hMenu, "Edit Block");
	
	decl String:szInfo[32], String:szBuffer[24];
	FormatEx(szBuffer, sizeof(szBuffer), "%sMove", g_bIsMovingBlock[iClient] ? "[\xE2\x9C\x93] " : "");
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_MOVE);
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	if(g_fGridSize[iClient] > 1.0)
		FormatEx(szBuffer, sizeof(szBuffer), "[\xE2\x9C\x93] Snap [%i]", RoundFloat(g_fGridSize[iClient]));
	else
		strcopy(szBuffer, sizeof(szBuffer), "Snap");
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_SNAP);
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_PITCH);
	AddMenuItem(hMenu, szInfo, "Pitch");
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_YAW);
	AddMenuItem(hMenu, szInfo, "Yaw");
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_ROLL);
	AddMenuItem(hMenu, szInfo, "Roll");
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_CHANGE_TYPE);
	AddMenuItem(hMenu, szInfo, "Change block type");
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_DATA);
	AddMenuItem(hMenu, szInfo, "Edit block data");
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, MENU_EDIT_DELETE);
	AddMenuItem(hMenu, szInfo, "Delete");
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}Error opening edit menu.");
	
	return true;
}

StartMovingBlock(iClient, iBlockEntRef)
{
	StopMovingBlock(iClient);
	
	g_iEditingBlockEntRef[iClient] = iBlockEntRef;
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

StopMovingBlock(iClient)
{
	g_iEditingBlockEntRef[iClient] = 0;
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public MenuHandle_EditBlock(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		StopMovingBlock(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_BlockMaker(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2][32];
	GetMenuItem(hMenu, iParam2, szInfo[0], sizeof(szInfo[]));
	ExplodeString(szInfo[0], "~", szInfo, sizeof(szInfo), sizeof(szInfo[]));
	
	new iBlockID = StringToInt(szInfo[0]);
	new iMenuType = StringToInt(szInfo[1]);
	
	new iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
	{
		CPrintToChat(iParam1, "{red}The target is no longer a valid block.");
		DisplayMenu_BlockMaker(iParam1);
		return;
	}
	
	switch(iMenuType)
	{
		case MENU_EDIT_DELETE:
		{
			DeleteBlock(iParam1, iIndex);
			DisplayMenu_BlockMaker(iParam1);
			return;
		}
		case MENU_EDIT_CHANGE_TYPE:
		{
			g_bIsMovingBlock[iParam1] = false;
			DisplayMenu_EditBlockType(iParam1, iBlockID);
			return;
		}
		case MENU_EDIT_DATA:
		{
			if(Forward_EditData(iParam1, iIndex))
			{
				g_bIsMovingBlock[iParam1] = false;
			}
			else
			{
				CPrintToChat(iParam1, "{red}You cannot edit this block type's data.");
				DisplayMenu_EditBlock(iParam1, iBlockID, GetMenuSelectionPosition());
			}
			
			return;
		}
	}
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	new iBlockEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
	if(iBlockEnt < 1)
	{
		CPrintToChat(iParam1, "{red}The entity you are editing is no longer valid.");
		DisplayMenu_BlockMaker(iParam1);
		return;
	}
	
	decl Float:fAngles[3];
	fAngles[0] = eBlock[Block_Angles][0];
	fAngles[1] = eBlock[Block_Angles][1];
	fAngles[2] = eBlock[Block_Angles][2];
	
	switch(iMenuType)
	{
		case MENU_EDIT_MOVE:	g_bIsMovingBlock[iParam1] = !g_bIsMovingBlock[iParam1];
		case MENU_EDIT_PITCH:	fAngles[0] += 15.0;
		case MENU_EDIT_YAW:		fAngles[1] += 15.0;
		case MENU_EDIT_ROLL:	fAngles[2] += 15.0;
		
		case MENU_EDIT_SNAP:
		{
			g_fGridSize[iParam1] *= 2.0;
			
			if(g_fGridSize[iParam1] > GRID_SIZE_MAX)
				g_fGridSize[iParam1] = 1.0;
		}
	}
	
	eBlock[Block_Angles][0] = AngleNormalize(fAngles[0]);
	eBlock[Block_Angles][1] = AngleNormalize(fAngles[1]);
	eBlock[Block_Angles][2] = AngleNormalize(fAngles[2]);
	SetArrayArray(g_aBlocks, iIndex, eBlock);
	
	TeleportEntity(iBlockEnt, NULL_VECTOR, fAngles, NULL_VECTOR);
	
	DisplayMenu_EditBlock(iParam1, iBlockID, GetMenuSelectionPosition());
}

Float:AngleNormalize(Float:fAngle)
{
	fAngle = FloatMod(fAngle, 360.0);
	
	if(fAngle > 180.0) 
	{
		fAngle -= 360.0;
	}
	else if(fAngle < -180.0)
	{
		fAngle += 360.0;
	}
	
	return fAngle;
}

Float:FloatMod(Float:fNumerator, Float:fDenominator)
{
    return (fNumerator - fDenominator * RoundToFloor(fNumerator / fDenominator));
}

public OnPreThinkPost(iClient)
{
	static iEnt;
	iEnt = EntRefToEntIndex(g_iEditingBlockEntRef[iClient]);
	if(iEnt < 1)
	{
		SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
		return;
	}
	
	TryMoveBlock(iClient, iEnt);
	TryShowBox(iClient, iEnt);
}

TryShowBox(iClient, iEnt)
{
	static Float:fCurTime, Float:fNextUpdate[MAXPLAYERS+1];
	fCurTime = GetEngineTime();
	
	if(fCurTime < fNextUpdate[iClient])
		return;
	
	fNextUpdate[iClient] = fCurTime + DISPLAY_BOX_DELAY;
	
	static Float:fOrigin[3], Float:fLargest, i;
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
	fLargest = GetLargestAbsoluteMinsMaxsSize(iEnt);
	
	new Float:fVertices[8][3];
	
	// Add the entities origin to all the vertices.
	for(i=0; i<8; i++)
	{
		fVertices[i][0] += fOrigin[0];
		fVertices[i][1] += fOrigin[1];
		fVertices[i][2] += fOrigin[2];
	}
	
	// Set the vertices origins.
	fVertices[0][2] -= fLargest;
	fVertices[1][2] -= fLargest;
	fVertices[2][2] -= fLargest;
	fVertices[3][2] -= fLargest;
	
	fVertices[4][2] += fLargest;
	fVertices[5][2] += fLargest;
	fVertices[6][2] += fLargest;
	fVertices[7][2] += fLargest;
	
	fVertices[0][0] -= fLargest;
	fVertices[0][1] -= fLargest;
	fVertices[1][0] -= fLargest;
	fVertices[1][1] += fLargest;
	fVertices[2][0] += fLargest;
	fVertices[2][1] += fLargest;
	fVertices[3][0] += fLargest;
	fVertices[3][1] -= fLargest;
	
	fVertices[4][0] -= fLargest;
	fVertices[4][1] -= fLargest;
	fVertices[5][0] -= fLargest;
	fVertices[5][1] += fLargest;
	fVertices[6][0] += fLargest;
	fVertices[6][1] += fLargest;
	fVertices[7][0] += fLargest;
	fVertices[7][1] -= fLargest;
	
	// Draw the horizontal beams.
	for(i=0; i<4; i++)
	{
		if(i != 3)
			TE_SetupBeamPoints(fVertices[i], fVertices[i+1], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 0.0, g_iBeamColor, 10);
		else
			TE_SetupBeamPoints(fVertices[i], fVertices[0], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 0.0, g_iBeamColor, 10);
		
		TE_SendToClient(iClient);
	}
	
	for(i=4; i<8; i++)
	{
		if(i != 7)
			TE_SetupBeamPoints(fVertices[i], fVertices[i+1], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 0.0, g_iBeamColor, 10);
		else
			TE_SetupBeamPoints(fVertices[i], fVertices[4], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 0.0, g_iBeamColor, 10);
		
		TE_SendToClient(iClient);
	}
	
	// Draw the vertical beams.
	for(i=0; i<4; i++)
	{
		TE_SetupBeamPoints(fVertices[i], fVertices[i+4], g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 0.0, g_iBeamColor, 10);
		TE_SendToClient(iClient);
	}
	
	// Client to ent beam.
	TE_SetupBeamEnts(iEnt, iClient, g_iBeamIndex, 0, 1, 1, DISPLAY_BOX_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 0.0, g_iBeamColor, 20);
	TE_SendToClient(iClient);
}

TE_SetupBeamEnts(iStartEnt, iEndEnt, iModelIndex, iHaloIndex, iStartFrame, iFramerate, Float:fLife, Float:fWidth, Float:fEndWidth, iFadeLength, Float:fAmplitude, const iColor[4], iSpeed)
{
	TE_Start("BeamEnts");
	TE_WriteNum("m_nModelIndex", iModelIndex);
	TE_WriteNum("m_nHaloIndex", iHaloIndex);
	TE_WriteNum("m_nStartFrame", iStartFrame);
	TE_WriteNum("m_nFrameRate", iFramerate);
	TE_WriteFloat("m_fLife", fLife);
	TE_WriteFloat("m_fWidth", fWidth);
	TE_WriteFloat("m_fEndWidth", fEndWidth);
	TE_WriteNum("m_nFadeLength", iFadeLength);
	TE_WriteFloat("m_fAmplitude", fAmplitude);
	TE_WriteNum("m_nSpeed", iSpeed);
	TE_WriteNum("r", iColor[0]);
	TE_WriteNum("g", iColor[1]);
	TE_WriteNum("b", iColor[2]);
	TE_WriteNum("a", iColor[3]);
	TE_WriteNum("m_nFlags", 0);
	TE_WriteNum("m_nStartEntity", iStartEnt);
	TE_WriteNum("m_nEndEntity", iEndEnt);
}

Float:GetLargestAbsoluteMinsMaxsSize(iEnt)
{
	static Float:fMins[3], Float:fMaxs[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	new Float:fLargest;
	
	static Float:fAbs, i;
	for(i=0; i<sizeof(fMins); i++)
	{
		fAbs = FloatAbs(fMins[i]);
		
		if(fAbs > fLargest)
			fLargest = fAbs;
	}
	
	for(i=0; i<sizeof(fMaxs); i++)
	{
		fAbs = FloatAbs(fMaxs[i]);
		
		if(fAbs > fLargest)
			fLargest = fAbs;
	}
	
	return fLargest;
}

TryMoveBlock(iClient, iEnt)
{
	if(!g_bIsMovingBlock[iClient])
		return;
	
	static iIndex;
	iIndex = GetBlockIndexFromID(GetEntityBlockID(iEnt));
	if(iIndex == -1)
		return;
	
	static eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	// Make sure move increments are based on time and not tickrate.
	static Float:fNextUpdate[MAXPLAYERS+1], Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime >= fNextUpdate[iClient])
	{
		fNextUpdate[iClient] = fCurTime + 0.05;
		
		static iButtons;
		iButtons = GetClientButtons(iClient);
		
		if(iButtons & IN_ATTACK)
		{
			g_fEditMoveDistance[iClient] += g_fGridSize[iClient];
		}
		else if(iButtons & IN_ATTACK2)
		{
			g_fEditMoveDistance[iClient] -= g_fGridSize[iClient];
			if(g_fEditMoveDistance[iClient] < 32.0)
				g_fEditMoveDistance[iClient] = 32.0;
		}
	}
	
	static Float:fOrigin[3], Float:fAngles[3];
	GetClientEyePosition(iClient, fOrigin);
	GetClientEyeAngles(iClient, fAngles);
	GetAngleVectors(fAngles, fAngles, NULL_VECTOR, NULL_VECTOR);
	
	static Float:fMins[3], Float:fMaxs[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	fOrigin[0] = fOrigin[0] + (fAngles[0] * g_fEditMoveDistance[iClient]);
	fOrigin[1] = fOrigin[1] + (fAngles[1] * g_fEditMoveDistance[iClient]);
	fOrigin[2] = fOrigin[2] + (fAngles[2] * g_fEditMoveDistance[iClient]);
	
	fOrigin[0] -= ((fMins[0] + fMaxs[0]) * 0.5);
	fOrigin[1] -= ((fMins[1] + fMaxs[1]) * 0.5);
	fOrigin[2] -= ((fMins[2] + fMaxs[2]) * 0.5);
	
	if(g_fGridSize[iClient] > 0.0)
		MoveBlockSnapToGrid(iClient, fOrigin);
	
	eBlock[Block_Origin][0] = fOrigin[0];
	eBlock[Block_Origin][1] = fOrigin[1];
	eBlock[Block_Origin][2] = fOrigin[2];
	SetArrayArray(g_aBlocks, iIndex, eBlock);
	
	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
}

MoveBlockSnapToGrid(iClient, Float:fOrigin[3])
{
	fOrigin[0] = float(RoundFloat(fOrigin[0] / g_fGridSize[iClient])) * g_fGridSize[iClient];
	fOrigin[1] = float(RoundFloat(fOrigin[1] / g_fGridSize[iClient])) * g_fGridSize[iClient];
	fOrigin[2] = float(RoundFloat(fOrigin[2] / g_fGridSize[iClient])) * g_fGridSize[iClient];
}

DisplayMenu_EditBlockType(iClient, iBlockID, iStartItem=0)
{
	CancelClientMenu(iClient);
	
	new iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
	{
		CPrintToChat(iClient, "{red}The target is no longer a valid block.");
		DisplayMenu_BlockMaker(iClient);
		return;
	}
	
	decl eBlock[Block], eBlockType[BlockType], String:szInfo[32];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	new iBlockEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
	if(iBlockEnt < 1)
	{
		CPrintToChat(iClient, "{red}The entity you are editing is no longer valid.");
		DisplayMenu_BlockMaker(iClient);
		return;
	}
	
	StartMovingBlock(iClient, eBlock[Block_EntReference]);
	
	IntToString(eBlock[Block_TypeID], szInfo, sizeof(szInfo));
	if(GetTrieValue(g_hTrie_TypeIDToIndex, szInfo, iIndex))
	{
		GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
		strcopy(szInfo, sizeof(szInfo), eBlockType[BlockType_NameDisplay]);
	}
	else
	{
		strcopy(szInfo, sizeof(szInfo), "INVALID");
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditBlockType);
	SetMenuTitle(hMenu, "Change Block Type\nCurrent type: %s", szInfo);
	
	new iArraySize = GetArraySize(g_aBlockTypes);
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aBlockTypes, i, eBlockType);
		
		FormatEx(szInfo, sizeof(szInfo), "%i~%i", iBlockID, eBlockType[BlockType_ID]);
		AddMenuItem(hMenu, szInfo, eBlockType[BlockType_NameDisplay]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}There are no block types.");
}

public MenuHandle_EditBlockType(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		StopMovingBlock(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_BlockMaker(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2][32];
	GetMenuItem(hMenu, iParam2, szInfo[0], sizeof(szInfo[]));
	ExplodeString(szInfo[0], "~", szInfo, sizeof(szInfo), sizeof(szInfo[]));
	
	new iBlockID = StringToInt(szInfo[0]);
	new iNewType = StringToInt(szInfo[1]);
	
	new iReturn = ChangeBlockType(iParam1, iBlockID, iNewType);
	switch(iReturn)
	{
		case -1:
		{
			DisplayMenu_BlockMaker(iParam1);
			return;
		}
		case -2:
		{
			DisplayMenu_EditBlockType(iParam1, iBlockID, GetMenuSelectionPosition());
			return;
		}
	}
	
	DisplayMenu_EditBlockType(iParam1, iBlockID, GetMenuSelectionPosition());
}

ChangeBlockType(iClient, iBlockID, iNewType)
{
	new iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
	{
		CPrintToChat(iClient, "{red}The target is no longer a valid block.");
		return -1;
	}
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	if(eBlock[Block_TypeID] == iNewType)
		return -2;
	
	new iOldType = eBlock[Block_TypeID];
	eBlock[Block_TypeID] = iNewType;
	strcopy(eBlock[Block_DataString], MAX_BLOCK_DATA_STRING_LEN, "");
	SetArrayArray(g_aBlocks, iIndex, eBlock);
	
	RemoveBlockIDFromTypeArray(iBlockID, iOldType);
	AddBlockIDToTypeArray(iBlockID, iNewType);
	
	// Make sure we call this after we set the type.
	if(eBlock[Block_EntReference] != INVALID_ENT_REFERENCE)
	{
		new iEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
		if(iEnt > 0)
			Forward_TypeUnassigned(iEnt, eBlock[Block_ID], iOldType);
	}
	
	// Recreate the block entity after setting the new type, this also calls the TypeAssigned forward.
	RecreateBlock(iIndex);
	
	return 1;
}

RemoveBlockIDFromTypeArray(iBlockID, iTypeID)
{
	new iIndex = GetBlockTypeIndexFromID(iTypeID);
	if(iIndex == -1)
		return;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	iIndex = FindValueInArray(eBlockType[BlockType_BlockIDs], iBlockID);
	if(iIndex != -1)
		RemoveFromArray(eBlockType[BlockType_BlockIDs], iIndex);
}

AddBlockIDToTypeArray(iBlockID, iTypeID)
{
	new iIndex = GetBlockTypeIndexFromID(iTypeID);
	if(iIndex == -1)
		return;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	if(FindValueInArray(eBlockType[BlockType_BlockIDs], iBlockID) == -1)
		PushArrayCell(eBlockType[BlockType_BlockIDs], iBlockID);
}

RecreateBlock(iBlockIndex)
{
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iBlockIndex, eBlock);
	
	if(eBlock[Block_EntReference] == INVALID_ENT_REFERENCE)
		return 0;
	
	new iEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
	if(iEnt < 1)
		return 0;
	
	decl Float:fOrigin[3], Float:fAngles[3];
	fOrigin[0] = eBlock[Block_Origin][0];
	fOrigin[1] = eBlock[Block_Origin][1];
	fOrigin[2] = eBlock[Block_Origin][2];
	
	fAngles[0] = eBlock[Block_Angles][0];
	fAngles[1] = eBlock[Block_Angles][1];
	fAngles[2] = eBlock[Block_Angles][2];
	
	Forward_TypeUnassigned(iEnt, eBlock[Block_ID], eBlock[Block_TypeID]);
	
	AcceptEntityInput(iEnt, "KillHierarchy");
	return CreateBlockEntity(eBlock[Block_ID], eBlock[Block_TypeID], fOrigin, fAngles);
}

bool:Forward_EditData(iClient, iBlockIndex)
{
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iBlockIndex, eBlock);
	
	new iIndex = GetBlockTypeIndexFromID(eBlock[Block_TypeID]);
	if(iIndex == -1)
		return false;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	// Forward for type plugin.
	if(eBlockType[BlockType_ForwardEditData] == INVALID_HANDLE)
		return false;
	
	Call_StartForward(eBlockType[BlockType_ForwardEditData]);
	Call_PushCell(iClient);
	Call_PushCell(eBlock[Block_ID]);
	Call_Finish();
	
	return true;
}

Forward_TypeUnassigned(iEntityIndex, iBlockID, iBlockType)
{
	new iIndex = GetBlockTypeIndexFromID(iBlockType);
	if(iIndex == -1)
		return;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	// Global forward to let all plugins know.
	Call_StartForward(g_hFwd_OnTypeUnassigned);
	Call_PushCell(iEntityIndex);
	Call_PushCell(iBlockID);
	Call_PushCell(iBlockType);
	Call_Finish();
	
	// Forward for type plugin.
	if(eBlockType[BlockType_ForwardTypeUnassigned] == INVALID_HANDLE)
		return;
	
	Call_StartForward(eBlockType[BlockType_ForwardTypeUnassigned]);
	Call_PushCell(iEntityIndex);
	Call_PushCell(iBlockID);
	Call_Finish();
}

Forward_TypeAssigned(iEntityIndex, iBlockID)
{
	new iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
		return;
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	iIndex = GetBlockTypeIndexFromID(eBlock[Block_TypeID]);
	if(iIndex == -1)
		return;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	// Global forward to let all plugins know.
	Call_StartForward(g_hFwd_OnTypeAssigned);
	Call_PushCell(iEntityIndex);
	Call_PushCell(iBlockID);
	Call_PushCell(eBlock[Block_TypeID]);
	Call_Finish();
	
	// Forward for type plugin.
	if(eBlockType[BlockType_ForwardTypeAssigned] == INVALID_HANDLE)
		return;
	
	Call_StartForward(eBlockType[BlockType_ForwardTypeAssigned]);
	Call_PushCell(iEntityIndex);
	Call_PushCell(iBlockID);
	Call_Finish();
}

Forward_OnBlockCreated(iBlockID)
{
	Call_StartForward(g_hFwd_OnBlockCreated);
	Call_PushCell(iBlockID);
	Call_Finish();
}

Forward_OnBlockRemoved(iBlockID, iBlockTypeID, bool:bIsPre)
{
	Call_StartForward(bIsPre ? g_hFwd_OnBlockRemoved_Pre : g_hFwd_OnBlockRemoved_Post);
	Call_PushCell(iBlockID);
	Call_PushCell(iBlockTypeID);
	Call_Finish();
}

DeleteBlock(iClient, iIndex)
{
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	Forward_OnBlockRemoved(eBlock[Block_ID], eBlock[Block_TypeID], true);
	
	RemoveBlockIDFromTypeArray(eBlock[Block_ID], eBlock[Block_TypeID]);
	RemoveFromArray(g_aBlocks, iIndex);
	
	new iEnt = EntRefToEntIndex(eBlock[Block_EntReference]);
	if(iEnt > 0)
	{
		Forward_TypeUnassigned(iEnt, eBlock[Block_ID], eBlock[Block_TypeID]);
		AcceptEntityInput(iEnt, "KillHierarchy");
	}
	
	CPrintToChat(iClient, "{red}Block removed.");
	
	// Must rebuild trie.
	ClearTrie(g_hTrie_BlockIDToIndex);
	
	decl String:szID[12];
	new iArraySize = GetArraySize(g_aBlocks);
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aBlocks, i, eBlock);
		
		IntToString(eBlock[Block_ID], szID, sizeof(szID));
		SetTrieValue(g_hTrie_BlockIDToIndex, szID, i, true);
	}
	
	Forward_OnBlockRemoved(eBlock[Block_ID], eBlock[Block_TypeID], false);
}

AddBlock(iClient=0, iBlockID=0, iBlockType, const Float:fOrigin[3], const Float:fAngles[3], const String:szDataString[]="")
{
	new iSafeMaxEntities = GetMaxEntities() - GetConVarInt(cvar_safe_ent_amount);
	new iMaxBlocks = GetConVarInt(cvar_max_blocks_total);
	if(iMaxBlocks > iSafeMaxEntities)
		iMaxBlocks = iSafeMaxEntities;
	
	if(GetArraySize(g_aBlocks) >= iMaxBlocks)
	{
		if(iClient)
			CPrintToChat(iClient, "{red}The level has already reached the block limit.");
		
		return 0;
	}
	
	if(iBlockID == 0)
		iBlockID = FindFreeBlockID();
	
	decl eBlock[Block];
	eBlock[Block_ID] = iBlockID;
	
	eBlock[Block_Origin] = fOrigin;
	eBlock[Block_Angles] = fAngles;
	
	eBlock[Block_TypeID] = iBlockType;
	eBlock[Block_EntReference] = INVALID_ENT_REFERENCE;
	
	strcopy(eBlock[Block_DataString], MAX_BLOCK_DATA_STRING_LEN, szDataString);
	
	new iIndex = PushArrayArray(g_aBlocks, eBlock);
	AddBlockIDToTypeArray(iBlockID, iBlockType);
	
	decl String:szID[12];
	IntToString(iBlockID, szID, sizeof(szID));
	SetTrieValue(g_hTrie_BlockIDToIndex, szID, iIndex, true);
	
	new iBlock = CreateBlockEntity(iBlockID, iBlockType, fOrigin, fAngles);
	if(!iBlock)
	{
		if(iClient)
			CPrintToChat(iClient, "{red}There was a problem creating the block entity.");
		
		return 0;
	}
	
	return iBlockID;
}

FindFreeBlockID()
{
	new iArraySize = GetArraySize(g_aBlocks);
	new Handle:hUsedIDs = CreateArray();
	
	decl eBlock[Block];
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aBlocks, i, eBlock);
		PushArrayCell(hUsedIDs, eBlock[Block_ID]);
	}
	
	new iNewID = INVALID_BLOCK_ID;
	
	iArraySize = GetArraySize(hUsedIDs);
	for(new i=1; i<=iArraySize+1; i++)
	{
		if(FindValueInArray(hUsedIDs, i) != -1)
			continue;
		
		iNewID = i;
		break;
	}
	
	return iNewID;
}

CopyBlock(iClient, const Float:fNewOrigin[3])
{
	new iTargetBlock = GetAimedAtBlock(iClient);
	if(!iTargetBlock)
	{
		CPrintToChat(iClient, "{red}You must aim at the block you want to copy.");
		return 0;
	}
	
	new iIndex = GetBlockIndexFromID(GetEntityBlockID(iTargetBlock));
	if(iIndex == -1)
	{
		CPrintToChat(iClient, "{red}There was an error getting the index from the target block.");
		return 0;
	}
	
	decl eBlock[Block], Float:fAngles[3];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	fAngles[0] = eBlock[Block_Angles][0];
	fAngles[1] = eBlock[Block_Angles][1];
	fAngles[2] = eBlock[Block_Angles][2];
	
	return AddBlock(iClient, _, eBlock[Block_TypeID], fNewOrigin, fAngles);
}

CreateBlockEntity(iBlockID, iTypeID, const Float:fOrigin[3], const Float:fAngles[3])
{
	decl iIndex, String:szID[12];
	IntToString(iTypeID, szID, sizeof(szID));
	
	if(!GetTrieValue(g_hTrie_TypeIDToIndex, szID, iIndex))
		return 0;
	
	decl eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
		return 0;
	
	new iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1)
		return 0;
	
	decl eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	eBlock[Block_EntReference] = EntIndexToEntRef(iEnt);
	SetArrayArray(g_aBlocks, iIndex, eBlock);
	
	SetEntityBlockID(iEnt, iBlockID);
	SetEntityModel(iEnt, eBlockType[BlockType_Model]);
	
	//DispatchKeyValue(iEnt, "fademindist", "1200");
	//DispatchKeyValue(iEnt, "fademaxdist", "1800");
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	// For solids
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 0);
	
	// For non-solids (traces will hit FSOLID_TRIGGER but not when paired with FSOLID_NOT_SOLID).
	//SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_NONE);
	//SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER);
	
	TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);
	
	SDKHook(iEnt, SDKHook_TouchPost, OnTouchPost);
	SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost);
	SDKHook(iEnt, SDKHook_EndTouchPost, OnEndTouchPost);
	
	Forward_OnBlockCreated(iBlockID);
	Forward_TypeAssigned(iEnt, iBlockID);
	
	return iEnt;
}

Handle:GetRandomTypeTrie(iBlockID)
{
	static iIndex, String:szID[12];
	IntToString(iBlockID, szID, sizeof(szID));
	
	if(GetTrieValue(g_hTrie_BlockIDToRandomTypeIndex, szID, iIndex))
		return GetArrayCell(g_aRandomTypeTries, iIndex);
	
	new Handle:hTrie = CreateTrie();
	iIndex = PushArrayCell(g_aRandomTypeTries, hTrie);
	SetTrieValue(g_hTrie_BlockIDToRandomTypeIndex, szID, iIndex, true);
	
	return hTrie;
}

GetRandomTypeID(iBlockID, iEnt, bool:bIsStartTouch)
{
	static iArraySize;
	iArraySize = GetArraySize(g_aAllowedRandomTypeIDs);
	
	if(!iArraySize)
		return g_iDefaultTypeID;
	
	static Handle:hTrie;
	hTrie = GetRandomTypeTrie(iBlockID);
	
	static String:szEntRef[12], iTypeID;
	IntToString(EntIndexToEntRef(iEnt), szEntRef, sizeof(szEntRef));
	
	if(!bIsStartTouch)
	{
		if(GetTrieValue(hTrie, szEntRef, iTypeID))
			return iTypeID;
	}
	
	iTypeID = GetArrayCell(g_aAllowedRandomTypeIDs, GetRandomInt(0, iArraySize-1));
	SetTrieValue(hTrie, szEntRef, iTypeID, true);
	
	return iTypeID;
}

public OnTouchPost(iBlock, iOther)
{
	if((1 <= iOther <= MaxClients) && GetEntityMoveType(iOther) == MOVETYPE_NOCLIP)
		return;
	
	static iBlockID;
	iBlockID = GetEntityBlockID(iBlock);
	
	static iIndex;
	iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
		return;
	
	static eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	if(eBlock[Block_TypeID] == g_iRandomTypeID)
		eBlock[Block_TypeID] = GetRandomTypeID(iBlockID, iOther, false);
	
	iIndex = GetBlockTypeIndexFromID(eBlock[Block_TypeID]);
	if(iIndex == -1)
		return;
	
	static eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	if(eBlockType[BlockType_ForwardTouch] == INVALID_HANDLE)
	{
		if(!StrEqual(eBlockType[BlockType_SoundTouch], ""))
			EmitSoundRandomPitch(iBlock, eBlockType[BlockType_SoundTouch]);
		
		return;
	}
	
	decl Action:result;
	Call_StartForward(eBlockType[BlockType_ForwardTouch]);
	Call_PushCell(iBlock);
	Call_PushCell(iOther);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return;
	
	if(!StrEqual(eBlockType[BlockType_SoundTouch], ""))
		EmitSoundRandomPitch(iBlock, eBlockType[BlockType_SoundTouch]);
}

Handle:GetTouchDelayTrie(iBlockID)
{
	static iIndex, String:szID[12];
	IntToString(iBlockID, szID, sizeof(szID));
	
	if(GetTrieValue(g_hTrie_BlockIDToTouchDelayIndex, szID, iIndex))
		return GetArrayCell(g_aTouchDelayTries, iIndex);
	
	new Handle:hTrie = CreateTrie();
	iIndex = PushArrayCell(g_aTouchDelayTries, hTrie);
	SetTrieValue(g_hTrie_BlockIDToTouchDelayIndex, szID, iIndex, true);
	
	return hTrie;
}

#define ENTITY_START_TOUCH_DELAY	0.25
bool:CanEntityStartTouch(iBlockID, iEnt)
{
	static Handle:hTrie;
	hTrie = GetTouchDelayTrie(iBlockID);
	
	static String:szEntRef[12];
	IntToString(EntIndexToEntRef(iEnt), szEntRef, sizeof(szEntRef));
	
	static Float:fLastTime, Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(GetTrieValue(hTrie, szEntRef, fLastTime))
	{
		if(fCurTime < (fLastTime + ENTITY_START_TOUCH_DELAY))
			return false;
	}
	
	SetTrieValue(hTrie, szEntRef, fCurTime, true);
	return true;
}

public OnStartTouchPost(iBlock, iOther)
{
	if((1 <= iOther <= MaxClients) && GetEntityMoveType(iOther) == MOVETYPE_NOCLIP)
		return;
	
	static iBlockID;
	iBlockID = GetEntityBlockID(iBlock);
	
	static iIndex;
	iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
		return;
	
	if(!CanEntityStartTouch(iBlockID, iOther))
		return;
	
	static eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	if(eBlock[Block_TypeID] == g_iRandomTypeID)
		eBlock[Block_TypeID] = GetRandomTypeID(iBlockID, iOther, true);
	
	iIndex = GetBlockTypeIndexFromID(eBlock[Block_TypeID]);
	if(iIndex == -1)
		return;
	
	static eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	if(eBlockType[BlockType_ForwardStartTouch] == INVALID_HANDLE)
	{
		if(!StrEqual(eBlockType[BlockType_SoundStartTouch], ""))
			EmitSoundRandomPitch(iBlock, eBlockType[BlockType_SoundStartTouch]);
		
		return;
	}
	
	decl Action:result;
	Call_StartForward(eBlockType[BlockType_ForwardStartTouch]);
	Call_PushCell(iBlock);
	Call_PushCell(iOther);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return;
	
	if(!StrEqual(eBlockType[BlockType_SoundStartTouch], ""))
		EmitSoundRandomPitch(iBlock, eBlockType[BlockType_SoundStartTouch]);
}

EmitSoundRandomPitch(iEnt, const String:szSound[])
{
	EmitSoundToAllAny(szSound, iEnt, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
}

public OnEndTouchPost(iBlock, iOther)
{
	static iBlockID;
	iBlockID = GetEntityBlockID(iBlock);
	
	static iIndex;
	iIndex = GetBlockIndexFromID(iBlockID);
	if(iIndex == -1)
		return;
	
	static eBlock[Block];
	GetArrayArray(g_aBlocks, iIndex, eBlock);
	
	if(eBlock[Block_TypeID] == g_iRandomTypeID)
		eBlock[Block_TypeID] = GetRandomTypeID(iBlockID, iOther, false);
	
	iIndex = GetBlockTypeIndexFromID(eBlock[Block_TypeID]);
	if(iIndex == -1)
		return;
	
	static eBlockType[BlockType];
	GetArrayArray(g_aBlockTypes, iIndex, eBlockType);
	
	if(eBlockType[BlockType_ForwardEndTouch] == INVALID_HANDLE)
	{
		// TODO: End touch sound.
		// -->
		
		return;
	}
	
	decl Action:result;
	Call_StartForward(eBlockType[BlockType_ForwardEndTouch]);
	Call_PushCell(iBlock);
	Call_PushCell(iOther);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return;
	
	// TODO: End touch sound.
	// -->
}

GetAimedAtBlock(iClient)
{
	decl Float:fEyePos[3], Float:fAngles[3];
	GetClientEyePosition(iClient, fEyePos);
	GetClientEyeAngles(iClient, fAngles);
	
	TR_TraceRayFilter(fEyePos, fAngles, MASK_ALL, RayType_Infinite, TraceFilter_BlocksOnly);
	TR_GetEndPosition(fAngles);
	
	TE_SetupBeamPoints(fEyePos, fAngles, g_iBeamIndex, 0, 1, 1, 0.1, 1.5, 0.5, 0, 0.0, {255,0,0,255}, 10);
	TE_SendToClient(iClient);
	
	new iHit = TR_GetEntityIndex();
	if(iHit < 1)
		return 0;
	
	return iHit;
}

public bool:TraceFilter_BlocksOnly(iEnt, iMask, any:iData)
{
	static String:szClassName[13];
	if(!GetEntityClassname(iEnt, szClassName, sizeof(szClassName)))
		return false;
	
	szClassName[12] = '\x0';
	if(!StrEqual(szClassName, "prop_dynamic"))
		return false;
	
	if(GetBlockIndexFromID(GetEntityBlockID(iEnt)) == -1)
		return false;
	
	return true;
}

GetBlockIndexFromID(iBlockID)
{
	decl iValue, String:szID[12];
	IntToString(iBlockID, szID, sizeof(szID));
	
	if(!GetTrieValue(g_hTrie_BlockIDToIndex, szID, iValue))
		return -1;
	
	return iValue;
}