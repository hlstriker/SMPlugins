#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Letters";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"Letters"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/letters/block.mdl",
	"models/swoobles/blocks/letters/block.dx90.vtx",
	"models/swoobles/blocks/letters/block.phy",
	"models/swoobles/blocks/letters/block.vvd",
	
	"materials/swoobles/blocks/letters/A.vtf",
	"materials/swoobles/blocks/letters/A.vmt",
	"materials/swoobles/blocks/letters/B.vtf",
	"materials/swoobles/blocks/letters/B.vmt",
	"materials/swoobles/blocks/letters/C.vtf",
	"materials/swoobles/blocks/letters/C.vmt",
	"materials/swoobles/blocks/letters/D.vtf",
	"materials/swoobles/blocks/letters/D.vmt",
	"materials/swoobles/blocks/letters/E.vtf",
	"materials/swoobles/blocks/letters/E.vmt",
	"materials/swoobles/blocks/letters/F.vtf",
	"materials/swoobles/blocks/letters/F.vmt",
	"materials/swoobles/blocks/letters/G.vtf",
	"materials/swoobles/blocks/letters/G.vmt",
	"materials/swoobles/blocks/letters/H.vtf",
	"materials/swoobles/blocks/letters/H.vmt",
	"materials/swoobles/blocks/letters/I.vtf",
	"materials/swoobles/blocks/letters/I.vmt",
	"materials/swoobles/blocks/letters/J.vtf",
	"materials/swoobles/blocks/letters/J.vmt",
	"materials/swoobles/blocks/letters/K.vtf",
	"materials/swoobles/blocks/letters/K.vmt",
	"materials/swoobles/blocks/letters/L.vtf",
	"materials/swoobles/blocks/letters/L.vmt",
	"materials/swoobles/blocks/letters/M.vtf",
	"materials/swoobles/blocks/letters/M.vmt",
	"materials/swoobles/blocks/letters/N.vtf",
	"materials/swoobles/blocks/letters/N.vmt",
	"materials/swoobles/blocks/letters/O.vtf",
	"materials/swoobles/blocks/letters/O.vmt",
	"materials/swoobles/blocks/letters/P.vtf",
	"materials/swoobles/blocks/letters/P.vmt",
	"materials/swoobles/blocks/letters/Q.vtf",
	"materials/swoobles/blocks/letters/Q.vmt",
	"materials/swoobles/blocks/letters/R.vtf",
	"materials/swoobles/blocks/letters/R.vmt",
	"materials/swoobles/blocks/letters/S.vtf",
	"materials/swoobles/blocks/letters/S.vmt",
	"materials/swoobles/blocks/letters/T.vtf",
	"materials/swoobles/blocks/letters/T.vmt",
	"materials/swoobles/blocks/letters/U.vtf",
	"materials/swoobles/blocks/letters/U.vmt",
	"materials/swoobles/blocks/letters/V.vtf",
	"materials/swoobles/blocks/letters/V.vmt",
	"materials/swoobles/blocks/letters/W.vtf",
	"materials/swoobles/blocks/letters/W.vmt",
	"materials/swoobles/blocks/letters/X.vtf",
	"materials/swoobles/blocks/letters/X.vmt",
	"materials/swoobles/blocks/letters/Y.vtf",
	"materials/swoobles/blocks/letters/Y.vmt",
	"materials/swoobles/blocks/letters/Z.vtf",
	"materials/swoobles/blocks/letters/Z.vmt"
};

new g_iEditingBlockID[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_letters_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, _, _, OnTypeAssigned, _, OnEditData);
}

public OnTypeAssigned(iBlock, iBlockID)
{
	decl String:szData[3];
	if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)))
		return;
	
	SetEntProp(iBlock, Prop_Send, "m_nSkin", StringToInt(szData));
}

public OnEditData(iClient, iBlockID)
{
	DisplayMenu_EditData(iClient, iBlockID);
}

DisplayMenu_EditData(iClient, iBlockID, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, "Edit Letter");
	
	decl String:szInfo[3], String:szDisplay[2];
	szDisplay[1] = '\x00';
	
	for(new i=0; i<26; i++)
	{
		szDisplay[0] = 65 + i;
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szDisplay);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
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
	
	new iEnt = BlockMaker_GetBlockEntFromID(g_iEditingBlockID[iParam1]);
	if(iEnt < 1)
	{
		PrintToChat(iParam1, "This block doesn't have a valid entity.");
		DisplayMenu_EditData(iParam1, g_iEditingBlockID[iParam1], GetMenuSelectionPosition());
		return;
	}
	
	decl String:szInfo[3];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	SetEntProp(iEnt, Prop_Send, "m_nSkin",  StringToInt(szInfo));
	BlockMaker_SetDataString(g_iEditingBlockID[iParam1], szInfo);
	
	DisplayMenu_EditData(iParam1, g_iEditingBlockID[iParam1], GetMenuSelectionPosition());
}