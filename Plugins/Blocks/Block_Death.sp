#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Death";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Death"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/death/block.mdl",
	"models/swoobles/blocks/death/block.dx90.vtx",
	"models/swoobles/blocks/death/block.phy",
	"models/swoobles/blocks/death/block.vvd",
	
	"materials/swoobles/blocks/death/block.vtf",
	"materials/swoobles/blocks/death/block.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_death_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, OnStartTouch);
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	SDKHooks_TakeDamage(iOther, iBlock, iBlock, 10000.0);
}