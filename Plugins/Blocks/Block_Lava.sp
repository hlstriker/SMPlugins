#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Lava";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Lava"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/lava/block.mdl",
	"models/swoobles/blocks/lava/block.dx90.vtx",
	"models/swoobles/blocks/lava/block.phy",
	"models/swoobles/blocks/lava/block.vvd",
	
	"materials/swoobles/blocks/lava/block.vtf",
	"materials/swoobles/blocks/lava/block.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_lava_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], OnTouch);
	BlockMaker_AllowAsRandom(iType);
}

public Action:OnTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Handled;
	
	IgniteEntity(iOther, 1.0);
	
	return Plugin_Continue;
}