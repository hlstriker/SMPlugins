#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Healing";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"Healing"
#define SOUND_HEAL		"sound/items/medshot4.wav"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/healing/block.mdl",
	"models/swoobles/blocks/healing/block.dx90.vtx",
	"models/swoobles/blocks/healing/block.phy",
	"models/swoobles/blocks/healing/block.vvd",
	
	"materials/swoobles/blocks/healing/block.vtf",
	"materials/swoobles/blocks/healing/block.vmt"
};

#define HEAL_DELAY	1.0
#define HEALTH_INCREASE_AMOUNT	5


public OnPluginStart()
{
	CreateConVar("block_healing_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
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
	BlockMaker_SetSounds(iType, _, SOUND_HEAL);
}

public Action:OnTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Handled;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	static Float:fNextHeal[MAXPLAYERS+1];
	if(fNextHeal[iOther] > fCurTime)
		return Plugin_Handled;
	
	fNextHeal[iOther] = fCurTime + HEAL_DELAY;
	
	if(!HealClient(iOther))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

bool:HealClient(iClient)
{
	new iOrigHealth = GetEntProp(iClient, Prop_Data, "m_iHealth");
	if(iOrigHealth >= 100)
		return false;
	
	new iHealth = iOrigHealth + HEALTH_INCREASE_AMOUNT;
	
	if(iHealth > 100)
		iHealth = 100;
	
	SetEntityHealth(iClient, iHealth);
	
	return true;
}