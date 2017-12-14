#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Magnet";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Magnet"
new const String:SOUND_START_TOUCH[] = "sound/swoobles/blocks/magnet/magnet.mp3";
new const String:SOUND_START_TOUCH_HEAD[] = "sound/swoobles/blocks/magnet/magnethead2.mp3";

#define SUCK_SPEED			100.0
#define SUCK_SPEED_HEAD		50.0

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/magnet/block.mdl",
	"models/swoobles/blocks/magnet/block.dx90.vtx",
	"models/swoobles/blocks/magnet/block.phy",
	"models/swoobles/blocks/magnet/block.vvd",
	
	"materials/swoobles/blocks/magnet/block.vtf",
	"materials/swoobles/blocks/magnet/block.vmt"
};


public OnPluginStart()
{
	CreateConVar("block_magnet_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	PrecacheSoundAny(SOUND_START_TOUCH[6], true);
	AddFileToDownloadsTable(SOUND_START_TOUCH);
	
	PrecacheSoundAny(SOUND_START_TOUCH_HEAD[6], true);
	AddFileToDownloadsTable(SOUND_START_TOUCH_HEAD);
}

public BlockMaker_OnRegisterReady()
{
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], OnTouch, OnStartTouch);
	BlockMaker_AllowAsRandom(iType);
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	static Float:fBlockOrigin[3], Float:fClientOrigin[3];
	GetCenterOrigin(iBlock, fBlockOrigin);
	GetCenterOrigin(iOther, fClientOrigin);
	
	if(fClientOrigin[2] < fBlockOrigin[2])
	{
		EmitSoundToAllAny(SOUND_START_TOUCH_HEAD[6], iBlock, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(120, 150));
	}
	else
	{
		EmitSoundToAllAny(SOUND_START_TOUCH[6], iBlock, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
	}
}

public Action:OnTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	SuckPlayer(iBlock, iOther);
}

SuckPlayer(iBlock, iClient)
{
	static Float:fBlockOrigin[3], Float:fClientOrigin[3];
	GetCenterOrigin(iBlock, fBlockOrigin);
	GetCenterOrigin(iClient, fClientOrigin);
	
	static Float:fVector[3];
	if(fClientOrigin[2] < fBlockOrigin[2])
	{
		// If the client is below the magnet we want the magnet to only modify their upward velocity (acts like head magnets in course maps).
		fVector[0] = 0.0;
		fVector[1] = 0.0;
		fVector[2] = 1.0;
		ScaleVector(fVector, SUCK_SPEED_HEAD);
	}
	else
	{
		SubtractVectors(fBlockOrigin, fClientOrigin, fVector);
		NormalizeVector(fVector, fVector);
		ScaleVector(fVector, SUCK_SPEED);
	}
	
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", fVector);
	SetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity", -1);
	
	new iFlags = GetEntityFlags(iClient);
	iFlags &= ~FL_ONGROUND;
	//iFlags |= FL_BASEVELOCITY;
	//SetEntityFlags(iClient, iFlags);
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