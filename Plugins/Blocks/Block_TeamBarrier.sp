#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Team Barrier";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME_ALLOW_T			"Team Barrier (allow T)"
#define BLOCK_NAME_ALLOW_CT			"Team Barrier (allow CT)"

new String:g_szBlockFiles_AllowT[][] =
{
	"models/swoobles/blocks/teambarrier/allow_t.mdl",
	"models/swoobles/blocks/teambarrier/allow_t.dx90.vtx",
	"models/swoobles/blocks/teambarrier/allow_t.phy",
	"models/swoobles/blocks/teambarrier/allow_t.vvd",
	
	"materials/swoobles/blocks/teambarrier/allow_t.vtf",
	"materials/swoobles/blocks/teambarrier/allow_t.vmt"
};

new String:g_szBlockFiles_AllowCT[][] =
{
	"models/swoobles/blocks/teambarrier/allow_ct.mdl",
	"models/swoobles/blocks/teambarrier/allow_ct.dx90.vtx",
	"models/swoobles/blocks/teambarrier/allow_ct.phy",
	"models/swoobles/blocks/teambarrier/allow_ct.vvd",
	
	"materials/swoobles/blocks/teambarrier/allow_ct.vtf",
	"materials/swoobles/blocks/teambarrier/allow_ct.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_team_barrier_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	// T
	for(new i=0; i<sizeof(g_szBlockFiles_AllowT); i++)
		AddFileToDownloadsTable(g_szBlockFiles_AllowT[i]);
	
	PrecacheModel(g_szBlockFiles_AllowT[0], true);
	
	// CT
	for(new i=0; i<sizeof(g_szBlockFiles_AllowCT); i++)
		AddFileToDownloadsTable(g_szBlockFiles_AllowCT[i]);
	
	PrecacheModel(g_szBlockFiles_AllowCT[0], true);
}

public BlockMaker_OnRegisterReady()
{
	BlockMaker_RegisterBlockType(BLOCK_NAME_ALLOW_T, g_szBlockFiles_AllowT[0]);
	BlockMaker_RegisterBlockType(BLOCK_NAME_ALLOW_CT, g_szBlockFiles_AllowCT[0]);
}