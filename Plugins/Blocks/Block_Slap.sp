#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Slap";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Slap"
#define SOUND_START_TOUCH	"sound/swoobles/blocks/slap/slap2.mp3"
#define SLAP_DAMAGE			10.0

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/slap/block.mdl",
	"models/swoobles/blocks/slap/block.dx90.vtx",
	"models/swoobles/blocks/slap/block.phy",
	"models/swoobles/blocks/slap/block.vvd",
	
	"materials/swoobles/blocks/slap/block.vtf",
	"materials/swoobles/blocks/slap/block.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_slap_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, OnStartTouch);
	BlockMaker_SetSounds(iType, SOUND_START_TOUCH);
	BlockMaker_AllowAsRandom(iType);
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	SlapPlayerCustom(iOther, iBlock);
}

SlapPlayerCustom(iClient, iBlock)
{
	decl Float:fVelocity[3];
	for(new i=0; i<2; i++)
	{
		if(GetRandomInt(0, 1))
			fVelocity[i] = GetRandomFloat(-250.0, -100.0);
		else
			fVelocity[i] = GetRandomFloat(100.0, 250.0);
	}
	
	fVelocity[2] = GetRandomFloat(100.0, 250.0);
	
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", fVelocity);
	SetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity", -1);
	
	new iFlags = GetEntityFlags(iClient);
	iFlags &= ~FL_ONGROUND;
	//iFlags |= FL_BASEVELOCITY;
	SetEntityFlags(iClient, iFlags);
	
	SDKHooks_TakeDamage(iClient, iBlock, iBlock, SLAP_DAMAGE);
}