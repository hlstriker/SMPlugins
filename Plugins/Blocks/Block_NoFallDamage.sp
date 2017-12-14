#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_sound>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: No Fall Damage";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"No Fall Damage"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/nofalldamage/block.mdl",
	"models/swoobles/blocks/nofalldamage/block.dx90.vtx",
	"models/swoobles/blocks/nofalldamage/block.phy",
	"models/swoobles/blocks/nofalldamage/block.vvd",
	
	"materials/swoobles/blocks/nofalldamage/block.vtf",
	"materials/swoobles/blocks/nofalldamage/block.vmt"
};

new const String:g_szSoundsToBlock[][] =
{
	"player/damage1.wav",
	"player/damage2.wav",
	"player/damage3.wav"
};

new g_iTickToBlock[MAXPLAYERS+1];

new g_iTypeID;


public OnPluginStart()
{
	CreateConVar("block_no_fall_damage_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	AddNormalSoundHook(OnNormalSound);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	g_iTypeID = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0]);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	static iID;
	iID = GetEntPropEnt(iVictim, Prop_Send, "m_hGroundEntity");
	
	if(iID < 1)
		return Plugin_Continue;
	
	iID = GetEntityBlockID(iID);
	if(!iID)
		return Plugin_Continue;
	
	iID = BlockMaker_GetBlockTypeID(iID);
	if(iID != g_iTypeID)
		return Plugin_Continue;
	
	fDamage = 0.0;
	g_iTickToBlock[iVictim] = GetGameTickCount();
	
	return Plugin_Changed;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	if(!(1 <= iEntity <= MaxClients))
		return Plugin_Continue;
	
	if(g_iTickToBlock[iEntity] != GetGameTickCount())
		return Plugin_Continue;
	
	if(szSample[0] != '~')
		return Plugin_Continue;
	
	for(new i=0; i<sizeof(g_szSoundsToBlock); i++)
	{
		if(StrEqual(g_szSoundsToBlock[i], szSample[1]))
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}