#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ParticleManager/particle_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Teleport";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Teleport"
new const String:SOUND_START_TOUCH[] = "sound/swoobles/blocks/teleport/teleport.mp3";
new const String:SOUND_ERROR[] = "sound/buttons/button16.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/teleport/block.mdl",
	"models/swoobles/blocks/teleport/block.dx90.vtx",
	"models/swoobles/blocks/teleport/block.phy",
	"models/swoobles/blocks/teleport/block.vvd",
	
	"materials/swoobles/blocks/teleport/block.vtf",
	"materials/swoobles/blocks/teleport/block.vmt"
};

new String:g_szBlockFiles_In[][] =
{
	"models/swoobles/blocks/teleport/in/block.mdl",
	"models/swoobles/blocks/teleport/in/block.dx90.vtx",
	"models/swoobles/blocks/teleport/in/block.phy",
	"models/swoobles/blocks/teleport/in/block.vvd"
};

new String:g_szBlockFiles_Out[][] =
{
	"models/swoobles/blocks/teleport/out/block.mdl",
	"models/swoobles/blocks/teleport/out/block.dx90.vtx",
	"models/swoobles/blocks/teleport/out/block.phy",
	"models/swoobles/blocks/teleport/out/block.vvd"
};

new const String:PARTICLE_FILE_PATH[] = "particles/swoobles/blocks/teleport.pcf";
#if defined _particle_manager_included
new const String:PEFFECT_TELEPORT_IN[] = "block_teleport_in";
new const String:PEFFECT_TELEPORT_OUT[] = "block_teleport_out";
#endif

new bool:g_bLibLoaded_ParticleManager;

#define MAX_TELEPORT_DATA_LEN	24

enum MenuInfoType
{
	MENUINFO_EDIT_NAME = 1,
	MENUINFO_EDIT_DEST
};

new g_iEditingBlockID[MAXPLAYERS+1];
new MenuInfoType:g_iEditingType[MAXPLAYERS+1];

new Float:g_fNextErrorSound[MAXPLAYERS+1];

new g_iType;


public OnPluginStart()
{
	CreateConVar("block_teleport_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	// Default
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	// In
	for(new i=0; i<sizeof(g_szBlockFiles_In); i++)
		AddFileToDownloadsTable(g_szBlockFiles_In[i]);
	
	PrecacheModel(g_szBlockFiles_In[0], true);
	
	// Out
	for(new i=0; i<sizeof(g_szBlockFiles_Out); i++)
		AddFileToDownloadsTable(g_szBlockFiles_Out[i]);
	
	PrecacheModel(g_szBlockFiles_Out[0], true);
	
	// Particles
	AddFileToDownloadsTable(PARTICLE_FILE_PATH);
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_TELEPORT_IN);
		PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_TELEPORT_OUT);
		#endif
	}
	
	// Sound
	AddFileToDownloadsTable(SOUND_ERROR);
	PrecacheSoundAny(SOUND_ERROR[6], true);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ParticleManager = LibraryExists("particle_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = false;
}

public BlockMaker_OnRegisterReady()
{
	g_iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, OnStartTouch, _, OnTypeAssigned, _, OnEditData);
	BlockMaker_SetSounds(g_iType, SOUND_START_TOUCH);
}

public OnTypeAssigned(iBlock, iBlockID)
{
	TrySetTeleportModel(iBlockID);
}

public BlockMaker_OnDataChanged(iBlockID, iBlockTypeID)
{
	if(IsBlockTypeTeleport(iBlockTypeID))
		TrySetTeleportModel(iBlockID);
}

TrySetTeleportModel(iBlockID)
{
	decl String:szName[MAX_TELEPORT_DATA_LEN], String:szDestination[MAX_TELEPORT_DATA_LEN];
	if(!GetTeleportData(iBlockID, szName, sizeof(szName), szDestination, sizeof(szDestination)))
		return;
	
	new iEnt = BlockMaker_GetBlockEntFromID(iBlockID);
	if(iEnt == -1)
		return;
	
	if(szDestination[0])
	{
		SetEntityModel(iEnt, g_szBlockFiles_In[0]);
	}
	else if(szName[0])
	{
		SetEntityModel(iEnt, g_szBlockFiles_Out[0]);
	}
}

bool:IsBlockTypeTeleport(iTypeID)
{
	decl String:szTypeName[MAX_BLOCK_TYPE_NAME_LEN];
	if(!BlockMaker_GetBlockTypeNameFromID(iTypeID, false, szTypeName, sizeof(szTypeName)))
		return false;
	
	if(!StrEqual(szTypeName, BLOCK_NAME))
		return false;
	
	return true;
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Continue;
	
	new iBlockID = GetEntityBlockID(iBlock);
	if(!iBlockID)
		return Plugin_Handled;
	
	decl String:szDestination[MAX_TELEPORT_DATA_LEN];
	if(!GetTeleportData(iBlockID, _, _, szDestination, sizeof(szDestination)) || !szDestination[0])
	{
		PlayErrorSound(iOther, iBlock);
		return Plugin_Handled;
	}
	
	decl bool:bRandom;
	if(StrEqual(szDestination, "random"))
		bRandom = true;
	else
		bRandom = false;
	
	new Handle:hBlockIDs = CreateArray();
	BlockMaker_GetBlocksByType(g_iType, hBlockIDs);
	
	new iArraySize = GetArraySize(hBlockIDs);
	new Handle:hFoundBlockIDs = CreateArray();
	
	decl String:szName[MAX_TELEPORT_DATA_LEN], iOtherBlockID;
	for(new i=0; i<iArraySize; i++)
	{
		iOtherBlockID = GetArrayCell(hBlockIDs, i);
		if(iBlockID == iOtherBlockID)
			continue;
		
		if(!GetTeleportData(iOtherBlockID, szName, sizeof(szName)) || !szName[0])
			continue;
		
		if(!bRandom)
		{
			if(!StrEqual(szName, szDestination))
				continue;
		}
		
		PushArrayCell(hFoundBlockIDs, iOtherBlockID);
	}
	
	decl iFoundBlockID;
	iArraySize = GetArraySize(hFoundBlockIDs);
	if(iArraySize)
		iFoundBlockID = GetArrayCell(hFoundBlockIDs, GetRandomInt(0, iArraySize-1));
	else
		iFoundBlockID = 0;
	
	CloseHandle(hFoundBlockIDs);
	CloseHandle(hBlockIDs);
	
	if(!iFoundBlockID)
	{
		PlayErrorSound(iOther, iBlock);
		return Plugin_Handled;
	}
	
	new iEnt = BlockMaker_GetBlockEntFromID(iFoundBlockID);
	if(iEnt < 1)
	{
		PlayErrorSound(iOther, iBlock);
		return Plugin_Handled;
	}
	
	decl Float:fOrigin[3];
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
	fOrigin[2] += (GetLargestAbsoluteMinsMaxsSize(iEnt) + 1.0);
	
	g_fNextErrorSound[iOther] = GetEngineTime() + 0.5;
	TeleportEntity(iOther, fOrigin, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	PlayTeleportSound(iOther, iBlock);
	
	return Plugin_Handled;
}

PlayTeleportSound(iClient, iBlock)
{
	new iNumClients;
	decl iClients[MAXPLAYERS+1];
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(iPlayer == iClient)
			continue;
		
		iClients[iNumClients++] = iPlayer;
	}
	
	EmitSoundAny(iClients, iNumClients, SOUND_START_TOUCH[6], iBlock, _, SNDLEVEL_NORMAL, _, 0.6, GetRandomInt(95, 120));
	EmitSoundToClientAny(iClient, SOUND_START_TOUCH[6], iClient, _, SNDLEVEL_NORMAL, _, 0.6, GetRandomInt(95, 120));
}

PlayErrorSound(iClient, iBlock)
{
	if(g_fNextErrorSound[iClient] > GetEngineTime())
		return;
	
	EmitSoundToAllAny(SOUND_ERROR[6], iBlock, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
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

public OnEditData(iClient, iBlockID)
{
	g_iEditingType[iClient] = MENUINFO_EDIT_NAME;
	DisplayMenu_EditData(iClient, iBlockID);
}

DisplayMenu_EditData(iClient, iBlockID)
{
	decl String:szName[MAX_TELEPORT_DATA_LEN], String:szDestination[MAX_TELEPORT_DATA_LEN];
	if(!GetTeleportData(iBlockID, szName, sizeof(szName), szDestination, sizeof(szDestination)))
	{
		PrintToChat(iClient, "Could not get teleport data.");
		BlockMaker_DisplayMenu_EditBlock(iClient, iBlockID);
		return;
	}
	
	decl String:szTitle[256];
	switch(g_iEditingType[iClient])
	{
		case MENUINFO_EDIT_NAME: FormatEx(szTitle, sizeof(szTitle), "Edit Teleport Name\nName: %s\n \nType the name in chat.", szName);
		case MENUINFO_EDIT_DEST: FormatEx(szTitle, sizeof(szTitle), "Edit Teleport Destination\nDestination: %s\n \nType the destination in chat.\nUse \"random\" for a random destination.", szDestination);
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[3];
	IntToString(_:MENUINFO_EDIT_NAME, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit teleport name");
	
	IntToString(_:MENUINFO_EDIT_DEST, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Edit teleport destination");
	
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

public MenuHandle_EditData(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
	
	decl String:szInfo[3];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	g_iEditingType[iParam1] = MenuInfoType:StringToInt(szInfo);
	DisplayMenu_EditData(iParam1, g_iEditingBlockID[iParam1]);
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_iEditingBlockID[iClient])
		return;
	
	decl String:szDataString[MAX_TELEPORT_DATA_LEN];
	strcopy(szDataString, sizeof(szDataString), szArgs);
	TrimString(szDataString);
	
	switch(g_iEditingType[iClient])
	{
		case MENUINFO_EDIT_NAME:
		{
			if(!szDataString[0] || StrEqual(szDataString, "-1"))
			{
				SetTeleportName(g_iEditingBlockID[iClient], "");
				PrintToChat(iClient, "Removed teleport name.");
			}
			else
			{
				SetTeleportName(g_iEditingBlockID[iClient], szDataString);
				PrintToChat(iClient, "Set teleport name to: %s.", szDataString);
			}
		}
		case MENUINFO_EDIT_DEST:
		{
			if(!szDataString[0] || StrEqual(szDataString, "-1"))
			{
				SetTeleportDestination(g_iEditingBlockID[iClient], "");
				PrintToChat(iClient, "Removed teleport destination.");
			}
			else
			{
				SetTeleportDestination(g_iEditingBlockID[iClient], szDataString);
				PrintToChat(iClient, "Set teleport destination to: %s.", szDataString);
			}
		}
	}
	
	DisplayMenu_EditData(iClient, g_iEditingBlockID[iClient]);
}

bool:GetTeleportData(iBlockID, String:szName[]="", iNameLen=0, String:szDestination[]="", iDestLen=0)
{
	decl String:szData[MAX_BLOCK_DATA_STRING_LEN];
	if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)))
		return false;
	
	decl String:szSplit[2];
	szSplit[0] = '\x01';
	szSplit[1] = '\x00';
	
	decl String:szBuffer[2][MAX_TELEPORT_DATA_LEN];
	new iNumStrings = ExplodeString(szData, szSplit, szBuffer, sizeof(szBuffer), sizeof(szBuffer[]), false);
	
	for(new i=iNumStrings; i<sizeof(szBuffer); i++)
		strcopy(szBuffer[i], sizeof(szBuffer[]), "");
	
	strcopy(szName, iNameLen, szBuffer[0]);
	strcopy(szDestination, iDestLen, szBuffer[1]);
	
	return true;
}

bool:SetTeleportData(iBlockID, const String:szName[], const String:szDestination[])
{
	decl String:szData[MAX_BLOCK_DATA_STRING_LEN];
	FormatEx(szData, sizeof(szData), "%s%c%s", szName, '\x01', szDestination);
	
	return BlockMaker_SetDataString(iBlockID, szData);
}

bool:SetTeleportName(iBlockID, const String:szName[])
{
	decl String:szCurName[MAX_TELEPORT_DATA_LEN], String:szCurDest[MAX_TELEPORT_DATA_LEN];
	if(!GetTeleportData(iBlockID, szCurName, sizeof(szCurName), szCurDest, sizeof(szCurDest)))
		return false;
	
	return SetTeleportData(iBlockID, szName, szCurDest);
}

bool:SetTeleportDestination(iBlockID, const String:szDestination[])
{
	decl String:szCurName[MAX_TELEPORT_DATA_LEN], String:szCurDest[MAX_TELEPORT_DATA_LEN];
	if(!GetTeleportData(iBlockID, szCurName, sizeof(szCurName), szCurDest, sizeof(szCurDest)))
		return false;
	
	return SetTeleportData(iBlockID, szCurName, szDestination);
}