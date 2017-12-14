#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Boost";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Boost"
#define SOUND_START_TOUCH	"sound/swoobles/blocks/boost/boost_v1.mp3"
#define BOOST_SPEED			400.0

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/boost/block_v2.mdl",
	"models/swoobles/blocks/boost/block_v2.dx90.vtx",
	"models/swoobles/blocks/boost/block_v2.phy",
	"models/swoobles/blocks/boost/block_v2.vvd",
	
	"materials/swoobles/blocks/boost/block.vtf",
	"materials/swoobles/blocks/boost/block.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_boost_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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
	
	BoostPlayer(iOther);
}

BoostPlayer(iClient)
{
	decl Float:fVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	fVelocity[2] = 0.0;
	
	new Float:fSpeed = GetVectorLength(fVelocity);
	if(fSpeed <= 0.0)
		fSpeed = 0.1;
	
	fVelocity[0] = (fVelocity[0] / fSpeed) * BOOST_SPEED;
	fVelocity[1] = (fVelocity[1] / fSpeed) * BOOST_SPEED;
	
	fVelocity[2] = fSpeed * 0.3;
	if(fVelocity[2] < 250.0)
		fVelocity[2] = 250.0;
	
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", fVelocity);
	SetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity", -1);
	
	new iFlags = GetEntityFlags(iClient);
	iFlags &= ~FL_ONGROUND;
	//iFlags |= FL_BASEVELOCITY;
	SetEntityFlags(iClient, iFlags);
}