#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_variant_t>
#include <vphysics>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Train";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Train"
#define BLOCK_NAME_PATH		"Train Path"

new String:g_szBlockFiles_Train[][] =
{
	"models/swoobles/blocks/train/blockseat.mdl",
	"models/swoobles/blocks/train/blockseat.dx90.vtx",
	"models/swoobles/blocks/train/blockseat.phy",
	"models/swoobles/blocks/train/blockseat.vvd",
	
	"materials/swoobles/blocks/train/block.vtf",
	"materials/swoobles/blocks/train/block.vmt"
};

new String:g_szBlockFiles_Path[][] =
{
	"models/swoobles/blocks/trainpath/block.mdl",
	"models/swoobles/blocks/trainpath/block.dx90.vtx",
	"models/swoobles/blocks/trainpath/block.phy",
	"models/swoobles/blocks/trainpath/block.vvd",
	
	"materials/swoobles/blocks/trainpath/block.vtf",
	"materials/swoobles/blocks/trainpath/block.vmt"
};

new Handle:g_hTrie_TrainNameToPathData;
new Handle:g_aPathDataArrays;
enum _:PathData
{
	PATHDATA_BLOCK_ID,
	PATHDATA_NUM
};

new Handle:g_aTrainNames;
new Handle:g_hTrie_TrainNameToBlockID;
new Handle:g_hTrie_TrainNameToDataIndex;
new Handle:g_aTrainData;
enum _:TrainData
{
	bool:TRAINDATA_DIRECTION,
	TRAINDATA_HEADING_TO_PATH_NUM
};

enum MenuInfoType
{
	MENUINFO_EDIT_TRAIN = 1,
	MENUINFO_EDIT_PATH
};

new Handle:g_hTrie_BlockIDToTrainRef;
new Handle:g_hTrie_BlockIDToUprightRef;

#define MAX_TRAIN_DATA_LEN	28
new g_iEditingBlockID[MAXPLAYERS+1];
new MenuInfoType:g_iEditingType[MAXPLAYERS+1];

#define EF_NODRAW		32
#define SOLID_NONE		0
#define SOLID_VPHYSICS	6
new const FSOLID_TRIGGER = 0x0008;


public OnPluginStart()
{
	CreateConVar("block_train_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aPathDataArrays = CreateArray();
	g_hTrie_TrainNameToPathData = CreateTrie();
	
	g_aTrainNames = CreateArray(MAX_TRAIN_DATA_LEN);
	g_hTrie_TrainNameToBlockID = CreateTrie();
	
	g_aTrainData = CreateArray(TrainData);
	g_hTrie_TrainNameToDataIndex = CreateTrie();
	
	g_hTrie_BlockIDToTrainRef = CreateTrie();
	g_hTrie_BlockIDToUprightRef = CreateTrie();
	
	CreateTimer(0.3, Timer_CheckTrains, _, TIMER_REPEAT);
}

public OnMapStart()
{
	// Train
	for(new i=0; i<sizeof(g_szBlockFiles_Train); i++)
		AddFileToDownloadsTable(g_szBlockFiles_Train[i]);
	
	PrecacheModel(g_szBlockFiles_Train[0], true);
	
	// Path
	for(new i=0; i<sizeof(g_szBlockFiles_Path); i++)
		AddFileToDownloadsTable(g_szBlockFiles_Path[i]);
	
	PrecacheModel(g_szBlockFiles_Path[0], true);
	
	// Clear arrays
	decl Handle:hPathData;
	new iArraySize = GetArraySize(g_aPathDataArrays);
	for(new i=0; i<iArraySize; i++)
	{
		hPathData = GetArrayCell(g_aPathDataArrays, i);
		CloseHandle(hPathData);
	}
	
	ClearArray(g_aPathDataArrays);
	ClearArray(g_aTrainNames);
	ClearArray(g_aTrainData);
	ClearTrie(g_hTrie_TrainNameToPathData);
	ClearTrie(g_hTrie_TrainNameToBlockID);
	ClearTrie(g_hTrie_TrainNameToDataIndex);
	ClearTrie(g_hTrie_BlockIDToTrainRef);
	ClearTrie(g_hTrie_BlockIDToUprightRef);
}

public BlockMaker_OnRegisterReady()
{
	BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles_Train[0], _, _, _, OnTypeAssignedTrain, OnTypeUnassignedTrain, OnEditDataTrain);
	BlockMaker_RegisterBlockType(BLOCK_NAME_PATH, g_szBlockFiles_Path[0], _, _, _, OnTypeAssignedPath, _, OnEditDataPath);
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_iEditingBlockID[iClient])
		return;
	
	switch(g_iEditingType[iClient])
	{
		case MENUINFO_EDIT_PATH: OnClientSayCommand_Post_Path(iClient, szArgs);
		case MENUINFO_EDIT_TRAIN: OnClientSayCommand_Post_Train(iClient, szArgs);
	}
}

public Action:Timer_CheckTrains(Handle:hTimer)
{
	static String:szTrainName[MAX_TRAIN_DATA_LEN], i, j, iArraySize, iIndex, Handle:hPathData, iPathDataArraySize, eTrainData[TrainData], ePathData[PathData], iTrainBlockID;
	static iPathEnt, iTrainParentEnt, Float:fTrainOrigin[3], Float:fPathOrigin[3], Float:fVelocity[3], String:szKey[12], iNextPathIndex, bool:bTrainDir;
	iArraySize = GetArraySize(g_aTrainNames);
	
	for(i=0; i<iArraySize; i++)
	{
		GetArrayString(g_aTrainNames, i, szTrainName, sizeof(szTrainName));
		
		if(!GetTrieValue(g_hTrie_TrainNameToBlockID, szTrainName, iTrainBlockID))
			continue;
		
		IntToString(iTrainBlockID, szKey, sizeof(szKey));
		if(!GetTrieValue(g_hTrie_BlockIDToTrainRef, szKey, iTrainParentEnt))
			continue;
		
		iTrainParentEnt = EntRefToEntIndex(iTrainParentEnt);
		if(iTrainParentEnt == INVALID_ENT_REFERENCE)
			continue;
		
		iIndex = GetTrainsPathDataIndex(szTrainName);
		if(iIndex == -1)
			continue;
		
		hPathData = GetArrayCell(g_aPathDataArrays, iIndex);
		
		if(!GetTrieValue(g_hTrie_TrainNameToDataIndex, szTrainName, iIndex))
			continue;
		
		GetArrayArray(g_aTrainData, iIndex, eTrainData);
		GetEntPropVector(iTrainParentEnt, Prop_Data, "m_vecOrigin", fTrainOrigin);
		bTrainDir = eTrainData[TRAINDATA_DIRECTION];
		
		// TODO: Make a trie map to lookup the path num for specific trains so we don't have to do this loop.
		iPathDataArraySize = GetArraySize(hPathData);
		for(j=0; j<iPathDataArraySize; j++)
		{
			GetArrayArray(hPathData, j, ePathData);
			
			if(eTrainData[TRAINDATA_HEADING_TO_PATH_NUM] == 0)
			{
				eTrainData[TRAINDATA_HEADING_TO_PATH_NUM] = ePathData[PATHDATA_NUM];
				SetArrayArray(g_aTrainData, iIndex, eTrainData);
			}
			else if(ePathData[PATHDATA_NUM] != eTrainData[TRAINDATA_HEADING_TO_PATH_NUM])
				continue;
			
			iPathEnt = BlockMaker_GetBlockEntFromID(ePathData[PATHDATA_BLOCK_ID]);
			if(iPathEnt < 1)
				continue;
			
			GetEntPropVector(iPathEnt, Prop_Data, "m_vecOrigin", fPathOrigin);
			
			SubtractVectors(fPathOrigin, fTrainOrigin, fVelocity);
			GetVectorAngles(fVelocity, fVelocity);
			GetAngleVectors(fVelocity, fVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(fVelocity, 100.0);
			
			//AcceptEntityInput(iTrainParentEnt, "Wake");
			//AcceptEntityInput(iTrainParentEnt, "EnableMotion");
			TeleportEntity(iTrainParentEnt, NULL_VECTOR, NULL_VECTOR, fVelocity);
			
			if(GetVectorDistance(fTrainOrigin, fPathOrigin) < 20.0)
			{
				if(eTrainData[TRAINDATA_DIRECTION])
				{
					iNextPathIndex = j + 1;
					if(iNextPathIndex >= iPathDataArraySize)
					{
						bTrainDir = !bTrainDir;
						iNextPathIndex = j - 1;
						
						if(iNextPathIndex < 0)
							iNextPathIndex = 0;
					}
				}
				else
				{
					iNextPathIndex = j - 1;
					if(iNextPathIndex < 0)
					{
						bTrainDir = !bTrainDir;
						iNextPathIndex = j + 1;
						
						if(iNextPathIndex >= iPathDataArraySize)
							iNextPathIndex = 0;
					}
				}
				
				GetArrayArray(hPathData, iNextPathIndex, ePathData);
				
				eTrainData[TRAINDATA_DIRECTION] = bTrainDir;
				eTrainData[TRAINDATA_HEADING_TO_PATH_NUM] = ePathData[PATHDATA_NUM];
				SetArrayArray(g_aTrainData, iIndex, eTrainData);
			}
			
			break;
		}
	}
}


/////////////////////
// PATH
/////////////////////
public OnTypeAssignedPath(iBlock, iBlockID)
{
	SetEntProp(iBlock, Prop_Data, "m_nSolidType", SOLID_NONE);
	SetEntProp(iBlock, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER);
}

public OnEditDataPath(iClient, iBlockID)
{
	g_iEditingType[iClient] = MENUINFO_EDIT_PATH;
	DisplayMenu_EditDataPath(iClient, iBlockID);
}

DisplayMenu_EditDataPath(iClient, iBlockID)
{
	decl String:szData[MAX_BLOCK_DATA_STRING_LEN];
	if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)))
	{
		PrintToChat(iClient, "Could not get path data.");
		BlockMaker_DisplayMenu_EditBlock(iClient, iBlockID);
		return;
	}
	
	decl String:szTitle[256];
	FormatEx(szTitle, sizeof(szTitle), "Edit Path Name\nName: %s", szData);
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditDataPath);
	SetMenuTitle(hMenu, szTitle);
	
	AddMenuItem(hMenu, "", "Type the name in chat.", ITEMDRAW_DISABLED);
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "Error displaying menu.");
		BlockMaker_DisplayMenu_EditBlock(iClient, iBlockID);
		return;
	}
	
	g_iEditingBlockID[iClient] = iBlockID;
	BlockMaker_RestartEditingBlockData(iClient, iBlockID);
}

public MenuHandle_EditDataPath(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		BlockMaker_FinishedEditingBlockData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			BlockMaker_DisplayMenu_EditBlock(iParam1, g_iEditingBlockID[iParam1]);
		
		g_iEditingBlockID[iParam1] = 0;
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	DisplayMenu_EditDataPath(iParam1, g_iEditingBlockID[iParam1]);
}

OnClientSayCommand_Post_Path(iClient, const String:szArgs[])
{
	decl String:szDataString[MAX_TRAIN_DATA_LEN];
	strcopy(szDataString, sizeof(szDataString), szArgs);
	TrimString(szDataString);
	
	decl String:szTrainName[MAX_TRAIN_DATA_LEN], iPathNumber;
	if(!SplitPathData(szDataString, szTrainName, sizeof(szTrainName), iPathNumber))
		iPathNumber = 0;
	
	if(!szDataString[0] || StrEqual(szDataString, "-1"))
	{
		BlockMaker_SetDataString(g_iEditingBlockID[iClient], "");
		PrintToChat(iClient, "Removed path name.");
	}
	else if(!iPathNumber)
	{
		PrintToChat(iClient, "Error: Use this path format: <TrainName>_<PathNumber>");
	}
	else
	{
		BlockMaker_SetDataString(g_iEditingBlockID[iClient], szDataString);
		PrintToChat(iClient, "Set path name to: %s.", szDataString);
	}
	
	DisplayMenu_EditDataPath(iClient, g_iEditingBlockID[iClient]);
}


/////////////////////
// TRAIN
/////////////////////
public OnTypeAssignedTrain(iBlock, iBlockID)
{
	SetEntProp(iBlock, Prop_Data, "m_nSolidType", SOLID_NONE);
	SetEntProp(iBlock, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER);
	
	CreateBlocksTrainEntity(iBlock, iBlockID);
}

public OnTypeUnassignedTrain(iBlock, iBlockID)
{
	RemoveBlocksTrainEntity(iBlockID);
	RemoveBlocksUprightEntity(iBlockID);
}

RemoveBlocksTrainEntity(iBlockID)
{
	decl String:szKey[12];
	IntToString(iBlockID, szKey, sizeof(szKey));
	
	decl iTrain;
	if(!GetTrieValue(g_hTrie_BlockIDToTrainRef, szKey, iTrain))
		return;
	
	iTrain = EntRefToEntIndex(iTrain);
	if(iTrain != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iTrain, "Kill");
	
	RemoveFromTrie(g_hTrie_BlockIDToTrainRef, szKey);
}

RemoveBlocksUprightEntity(iBlockID)
{
	decl String:szKey[12];
	IntToString(iBlockID, szKey, sizeof(szKey));
	
	decl iEnt;
	if(!GetTrieValue(g_hTrie_BlockIDToUprightRef, szKey, iEnt))
		return;
	
	iEnt = EntRefToEntIndex(iEnt);
	if(iEnt != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iEnt, "Kill");
	
	RemoveFromTrie(g_hTrie_BlockIDToUprightRef, szKey);
}

CreateBlocksTrainEntity(iBlock, iBlockID)
{
	decl String:szKey[12];
	IntToString(iBlockID, szKey, sizeof(szKey));
	
	decl iTrain;
	if(GetTrieValue(g_hTrie_BlockIDToTrainRef, szKey, iTrain))
	{
		iTrain = EntRefToEntIndex(iTrain);
		if(iTrain != INVALID_ENT_REFERENCE)
			return iTrain;
	}
	
	iTrain = CreateTrain(iBlock);
	if(iTrain == -1)
		return -1;
	
	SetTrieValue(g_hTrie_BlockIDToTrainRef, szKey, EntIndexToEntRef(iTrain), true);
	
	decl iKeepUpright;
	if(!GetTrieValue(g_hTrie_BlockIDToUprightRef, szKey, iKeepUpright))
	{
		iKeepUpright = CreateEntityByName("phys_keepupright");
		if(iKeepUpright != -1)
		{
			SetEntPropEnt(iKeepUpright, Prop_Data, "m_attachedObject", iTrain);
			SetEntPropFloat(iKeepUpright, Prop_Data, "m_angularLimit", 9999999.0);
			DispatchSpawn(iKeepUpright);
			ActivateEntity(iKeepUpright);
			
			SetTrieValue(g_hTrie_BlockIDToUprightRef, szKey, EntIndexToEntRef(iKeepUpright), true);
		}
	}
	
	decl Float:fOrigin[3];
	GetEntPropVector(iBlock, Prop_Data, "m_vecOrigin", fOrigin);
	TeleportEntity(iTrain, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(iBlock, "SetParent", iTrain);
	
	return iTrain;
}

CreateTrain(iBlock)
{
	new iEnt = CreateEntityByName("prop_physics_multiplayer");
	if(iEnt == -1)
		return -1;
	
	decl String:szModel[PLATFORM_MAX_PATH];
	GetEntPropString(iBlock, Prop_Data, "m_ModelName", szModel, sizeof(szModel));
	SetEntityModel(iEnt, szModel);
	
	DispatchKeyValue(iEnt, "nodamageforces", "1");
	DispatchKeyValue(iEnt, "massScale", "99999999");
	DispatchKeyValue(iEnt, "inertiaScale", "99999999");
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	Phys_EnableGravity(iEnt, false);
	Phys_EnableDrag(iEnt, false);
	
	SetEntityMoveType(iEnt, MOVETYPE_VPHYSICS);
	SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", GetEntProp(iBlock, Prop_Send, "m_CollisionGroup"));
	SetEntProp(iEnt, Prop_Data, "m_nSolidType", SOLID_VPHYSICS);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 0);
	SetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity", iBlock);
	SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_NODRAW);
	
	return iEnt;
}

public OnEditDataTrain(iClient, iBlockID)
{
	g_iEditingType[iClient] = MENUINFO_EDIT_TRAIN;
	DisplayMenu_EditDataTrain(iClient, iBlockID);
}

DisplayMenu_EditDataTrain(iClient, iBlockID)
{
	decl String:szData[MAX_BLOCK_DATA_STRING_LEN];
	if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)))
	{
		PrintToChat(iClient, "Could not get train data.");
		BlockMaker_DisplayMenu_EditBlock(iClient, iBlockID);
		return;
	}
	
	decl String:szTitle[256];
	FormatEx(szTitle, sizeof(szTitle), "Edit Train Name\nName: %s", szData);
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditDataTrain);
	SetMenuTitle(hMenu, szTitle);
	
	AddMenuItem(hMenu, "", "Type the name in chat.", ITEMDRAW_DISABLED);
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "Error displaying menu.");
		BlockMaker_DisplayMenu_EditBlock(iClient, iBlockID);
		return;
	}
	
	g_iEditingBlockID[iClient] = iBlockID;
	BlockMaker_RestartEditingBlockData(iClient, iBlockID);
}

public MenuHandle_EditDataTrain(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		BlockMaker_FinishedEditingBlockData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			BlockMaker_DisplayMenu_EditBlock(iParam1, g_iEditingBlockID[iParam1]);
		
		g_iEditingBlockID[iParam1] = 0;
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	DisplayMenu_EditDataTrain(iParam1, g_iEditingBlockID[iParam1]);
}

OnClientSayCommand_Post_Train(iClient, const String:szArgs[])
{
	decl String:szDataString[MAX_TRAIN_DATA_LEN];
	strcopy(szDataString, sizeof(szDataString), szArgs);
	TrimString(szDataString);
	
	if(!szDataString[0] || StrEqual(szDataString, "-1"))
	{
		BlockMaker_SetDataString(g_iEditingBlockID[iClient], "");
		PrintToChat(iClient, "Removed train name.");
	}
	else
	{
		BlockMaker_SetDataString(g_iEditingBlockID[iClient], szDataString);
		PrintToChat(iClient, "Set train name to: %s.", szDataString);
	}
	
	DisplayMenu_EditDataTrain(iClient, g_iEditingBlockID[iClient]);
}

public BlockMaker_OnTypeAssigned(iBlockEnt, iBlockID, iBlockTypeID)
{
	if(IsBlockTypeTrainPath(iBlockTypeID))
	{
		RecreatePathing();
	}
	else if(IsBlockTypeTrain(iBlockTypeID))
	{
		RepopulateTrainsArray();
	}
}

public BlockMaker_OnTypeUnassigned(iBlockEnt, iBlockID, iBlockTypeID)
{
	if(IsBlockTypeTrainPath(iBlockTypeID))
	{
		RecreatePathing();
	}
	else if(IsBlockTypeTrain(iBlockTypeID))
	{
		RepopulateTrainsArray();
	}
}

public BlockMaker_OnBlockRemoved_Post(iBlockID, iBlockTypeID)
{
	if(IsBlockTypeTrainPath(iBlockTypeID))
	{
		RecreatePathing();
	}
	else if(IsBlockTypeTrain(iBlockTypeID))
	{
		RepopulateTrainsArray();
	}
}

public BlockMaker_OnDataChanged(iBlockID, iBlockTypeID)
{
	if(IsBlockTypeTrainPath(iBlockTypeID))
	{
		RecreatePathing();
	}
	else if(IsBlockTypeTrain(iBlockTypeID))
	{
		RepopulateTrainsArray();
	}
}

bool:IsBlockTypeTrainPath(iTypeID)
{
	decl String:szTypeName[MAX_BLOCK_TYPE_NAME_LEN];
	if(!BlockMaker_GetBlockTypeNameFromID(iTypeID, false, szTypeName, sizeof(szTypeName)))
		return false;
	
	if(!StrEqual(szTypeName, BLOCK_NAME_PATH))
		return false;
	
	return true;
}

bool:IsBlockTypeTrain(iTypeID)
{
	decl String:szTypeName[MAX_BLOCK_TYPE_NAME_LEN];
	if(!BlockMaker_GetBlockTypeNameFromID(iTypeID, false, szTypeName, sizeof(szTypeName)))
		return false;
	
	if(!StrEqual(szTypeName, BLOCK_NAME))
		return false;
	
	return true;
}

RepopulateTrainsArray()
{
	new iTrainTypeID = BlockMaker_GetBlockTypeIDFromName(BLOCK_NAME);
	if(!iTrainTypeID)
		return;
	
	new Handle:aOldTrainNames = CloneArray(g_aTrainNames);
	ClearArray(g_aTrainNames);
	ClearTrie(g_hTrie_TrainNameToBlockID);
	
	new Handle:hBlockIDs = CreateArray();
	BlockMaker_GetBlocksByType(iTrainTypeID, hBlockIDs);
	
	new iArraySize = GetArraySize(hBlockIDs);
	decl String:szData[MAX_BLOCK_DATA_STRING_LEN], iBlockID, i;
	for(i=0; i<iArraySize; i++)
	{
		iBlockID = GetArrayCell(hBlockIDs, i);
		
		if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)) || !szData[0])
			continue;
		
		PushArrayString(g_aTrainNames, szData);
		SetTrieValue(g_hTrie_TrainNameToBlockID, szData, iBlockID, true);
	}
	
	CloseHandle(hBlockIDs);
	
	decl iIndex, eTrainData[TrainData];
	eTrainData[TRAINDATA_DIRECTION] = true;
	eTrainData[TRAINDATA_HEADING_TO_PATH_NUM] = 0;
	
	iArraySize = GetArraySize(g_aTrainNames);
	for(i=0; i<iArraySize; i++)
	{
		GetArrayString(g_aTrainNames, i, szData, sizeof(szData));
		
		iIndex = FindStringInArray(aOldTrainNames, szData);
		if(iIndex != -1)
			RemoveFromArray(aOldTrainNames, iIndex);
		
		if(GetTrieValue(g_hTrie_TrainNameToDataIndex, szData, iIndex))
			continue;
		
		iIndex = PushArrayArray(g_aTrainData, eTrainData);
		SetTrieValue(g_hTrie_TrainNameToDataIndex, szData, iIndex, true);
	}
	
	iArraySize = GetArraySize(aOldTrainNames);
	new iRemovedCount, iSmallestIndexRemoved = iArraySize;
	for(i=0; i<iArraySize; i++)
	{
		GetArrayString(aOldTrainNames, i, szData, sizeof(szData));
		
		if(GetTrieValue(g_hTrie_TrainNameToDataIndex, szData, iIndex))
		{
			if(iIndex >= iSmallestIndexRemoved)
				iIndex -= iRemovedCount;
			
			RemoveFromArray(g_aTrainData, iIndex);
			iRemovedCount++;
			
			if(iIndex < iSmallestIndexRemoved)
				iSmallestIndexRemoved = iIndex;
		}
		
		RemoveFromTrie(g_hTrie_TrainNameToDataIndex, szData);
	}
	
	CloseHandle(aOldTrainNames);
}

RecreatePathing()
{
	decl i, Handle:hPathData;
	new iArraySize = GetArraySize(g_aPathDataArrays);
	for(i=0; i<iArraySize; i++)
	{
		hPathData = GetArrayCell(g_aPathDataArrays, i);
		CloseHandle(hPathData);
	}
	
	ClearArray(g_aPathDataArrays);
	ClearTrie(g_hTrie_TrainNameToPathData);
	
	new iPathTypeID = BlockMaker_GetBlockTypeIDFromName(BLOCK_NAME_PATH);
	if(!iPathTypeID)
		return;
	
	new Handle:hBlockIDs = CreateArray();
	BlockMaker_GetBlocksByType(iPathTypeID, hBlockIDs);
	
	iArraySize = GetArraySize(hBlockIDs);
	decl String:szData[MAX_BLOCK_DATA_STRING_LEN], iBlockID, iPathNumber, iIndex, ePathData[PathData];
	for(i=0; i<iArraySize; i++)
	{
		iBlockID = GetArrayCell(hBlockIDs, i);
		
		if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)) || !szData[0])
			continue;
		
		if(!SplitPathData(szData, szData, sizeof(szData), iPathNumber))
			continue;
		
		iIndex = GetTrainsPathDataIndex(szData);
		if(iIndex == -1)
		{
			hPathData = CreateArray(PathData);
			iIndex = PushArrayCell(g_aPathDataArrays, hPathData);
			SetTrieValue(g_hTrie_TrainNameToPathData, szData, iIndex, true);
		}
		else
		{
			hPathData = GetArrayCell(g_aPathDataArrays, iIndex);
		}
		
		ePathData[PATHDATA_BLOCK_ID] = iBlockID;
		ePathData[PATHDATA_NUM] = iPathNumber;
		PushArrayArray(hPathData, ePathData);
	}
	
	CloseHandle(hBlockIDs);
	
	iArraySize = GetArraySize(g_aPathDataArrays);
	for(i=0; i<iArraySize; i++)
	{
		hPathData = GetArrayCell(g_aPathDataArrays, i);
		SortADTArrayCustom(hPathData, SortPathData);
	}
}

public SortPathData(iIndex1, iIndex2, Handle:hArray, Handle:hHandle)
{
	decl ePathData1[PathData], ePathData2[PathData];
	GetArrayArray(hArray, iIndex1, ePathData1);
	GetArrayArray(hArray, iIndex2, ePathData2);
	
	if(ePathData1[PATHDATA_NUM] < ePathData2[PATHDATA_NUM])
		return -1;
	
	if(ePathData1[PATHDATA_NUM] > ePathData2[PATHDATA_NUM])
		return 1;
	
	return 0;
}

bool:SplitPathData(const String:szData[], String:szTrainName[], iTrainNameLen, &iPathNumber)
{
	decl String:szBuffer[2][MAX_TRAIN_DATA_LEN];
	new iNumStrings = ExplodeString(szData, "_", szBuffer, sizeof(szBuffer), sizeof(szBuffer[]), false);
	
	if(iNumStrings != 2)
		return false;
	
	new iNum = StringToInt(szBuffer[1]);
	if(iNum < 1)
		return false;
	
	iPathNumber = iNum;
	strcopy(szTrainName, iTrainNameLen, szBuffer[0]);
	
	return true;
}

GetTrainsPathDataIndex(const String:szTrainName[])
{
	static iIndex;
	if(!GetTrieValue(g_hTrie_TrainNameToPathData, szTrainName, iIndex))
		return -1;
	
	return iIndex;
}