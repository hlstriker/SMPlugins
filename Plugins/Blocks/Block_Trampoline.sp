#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Trampoline";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Trampoline"
#define SOUND_START_TOUCH	"sound/swoobles/blocks/trampoline/trampoline.mp3"
#define BOOST_SPEED			550.0

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/trampoline/block.mdl",
	"models/swoobles/blocks/trampoline/block.dx90.vtx",
	"models/swoobles/blocks/trampoline/block.phy",
	"models/swoobles/blocks/trampoline/block.vvd",
	
	"materials/swoobles/blocks/trampoline/block.vtf",
	"materials/swoobles/blocks/trampoline/block.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_trampoline_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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
		return Plugin_Continue;
	
	if(!BoostPlayer(iOther, iBlock))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

bool:BoostPlayer(iClient, iBlock)
{
	// Make sure the players feet are above the blocks center.
	decl Float:fOrigin[3], Float:fClientOrigin[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecOrigin", fClientOrigin);
	GetEntPropVector(iClient, Prop_Send, "m_vecMins", fOrigin);
	fClientOrigin[2] += fOrigin[2];
	
	GetCenterOrigin(iBlock, fOrigin);
	fOrigin[2] -= 5.0;
	
	if(fClientOrigin[2] < fOrigin[2])
		return false;
	
	decl Float:fVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	fVelocity[2] = 0.0;
	
	new Float:fSpeed = GetVectorLength(fVelocity);
	if(fSpeed <= 0.0)
		fSpeed = 0.1;
	
	GetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", fVelocity);
	
	fVelocity[2] = fSpeed * 0.85;
	if(fVelocity[2] < BOOST_SPEED)
		fVelocity[2] = BOOST_SPEED;
	
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", fVelocity);
	SetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity", -1);
	
	new iFlags = GetEntityFlags(iClient);
	iFlags &= ~FL_ONGROUND;
	//iFlags |= FL_BASEVELOCITY;
	SetEntityFlags(iClient, iFlags);
	
	return true;
}

GetCenterOrigin(iEnt, Float:fOrigin[3])
{
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
	
	static Float:fMins[3], Float:fMaxs[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	fOrigin[0] = fOrigin[0] + ((fMins[0] + fMaxs[0]) * 0.5);
	fOrigin[1] = fOrigin[1] + ((fMins[1] + fMaxs[1]) * 0.5);
	fOrigin[2] = fOrigin[2] + ((fMins[2] + fMaxs[2]) * 0.5);
}