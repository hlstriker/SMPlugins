#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_variant_t>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Light";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"Light"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/light/block.mdl",
	"models/swoobles/blocks/light/block.dx90.vtx",
	"models/swoobles/blocks/light/block.phy",
	"models/swoobles/blocks/light/block.vvd",
	
	"materials/swoobles/blocks/light/block.vtf",
	"materials/swoobles/blocks/light/block.vmt"
};

new Handle:g_hTrie_BlockRefToLightRef;

#define SOLID_NONE	0
new const FSOLID_TRIGGER = 0x0008;


public OnPluginStart()
{
	CreateConVar("block_light_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hTrie_BlockRefToLightRef = CreateTrie();
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	ClearTrie(g_hTrie_BlockRefToLightRef);
}

public BlockMaker_OnRegisterReady()
{
	BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, _, _, OnTypeAssigned, OnTypeUnassigned);
}

CreateBlocksLightEntity(iBlock)
{
	new iBlockRef = EntIndexToEntRef(iBlock);
	if(iBlockRef == INVALID_ENT_REFERENCE)
		return -1;
	
	decl String:szKey[12];
	IntToString(iBlockRef, szKey, sizeof(szKey));
	
	decl iLight;
	if(GetTrieValue(g_hTrie_BlockRefToLightRef, szKey, iLight))
	{
		iLight = EntRefToEntIndex(iLight);
		if(iLight != INVALID_ENT_REFERENCE)
			return iLight;
	}
	
	iLight = CreateLight();
	if(iLight == -1)
		return -1;
	
	decl Float:fOrigin[3];
	GetEntPropVector(iBlock, Prop_Data, "m_vecOrigin", fOrigin);
	TeleportEntity(iLight, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(iLight, "SetParent", iBlock);
	
	SetTrieValue(g_hTrie_BlockRefToLightRef, szKey, iLight, true);
	
	return iLight;
}

CreateLight()
{
	new iEnt = CreateEntityByName("light_dynamic");
	if(iEnt == -1)
		return -1;
	
	DispatchKeyValue(iEnt, "_light", "255 250 244 200");
	DispatchKeyValue(iEnt, "brightness", "8");
	DispatchKeyValue(iEnt, "distance", "250");
	DispatchKeyValue(iEnt, "style", "0");
	DispatchSpawn(iEnt);
	
	return iEnt;
}

RemoveBlocksLightEntity(iBlock)
{
	new iBlockRef = EntIndexToEntRef(iBlock);
	if(iBlockRef == INVALID_ENT_REFERENCE)
		return;
	
	decl String:szKey[12];
	IntToString(iBlockRef, szKey, sizeof(szKey));
	
	decl iLight;
	if(!GetTrieValue(g_hTrie_BlockRefToLightRef, szKey, iLight))
		return;
	
	iLight = EntRefToEntIndex(iLight);
	if(iLight != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iLight, "Kill");
	
	RemoveFromTrie(g_hTrie_BlockRefToLightRef, szKey);
}

public OnTypeAssigned(iBlock, iBlockID)
{
	SetEntProp(iBlock, Prop_Data, "m_nSolidType", SOLID_NONE);
	SetEntProp(iBlock, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER);
	
	CreateBlocksLightEntity(iBlock);
}

public OnTypeUnassigned(iBlock, iBlockID)
{
	RemoveBlocksLightEntity(iBlock);
}