#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Arrow";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Arrow"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/arrow/block.mdl",
	"models/swoobles/blocks/arrow/block.dx90.vtx",
	"models/swoobles/blocks/arrow/block.phy",
	"models/swoobles/blocks/arrow/block.vvd",
	
	"materials/swoobles/blocks/arrow/block.vtf",
	"materials/swoobles/blocks/arrow/block.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_arrow_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0]);
}