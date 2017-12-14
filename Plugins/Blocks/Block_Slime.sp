#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Slime";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Slime"
#define SOUND_START_TOUCH	"sound/player/footsteps/new/mud_01.wav"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/slime/block.mdl",
	"models/swoobles/blocks/slime/block.dx90.vtx",
	"models/swoobles/blocks/slime/block.phy",
	"models/swoobles/blocks/slime/block.vvd",
	
	"materials/swoobles/blocks/slime/block.vtf",
	"materials/swoobles/blocks/slime/block.vmt"
};

#define CUSTOM_LAGGED_MOVEMENT	0.5
#define CUSTOM_GRAVITY			2.5

new Handle:g_hTimer_RemoveEffect[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_slime_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], OnTouch, OnStartTouch, OnEndTouch);
	BlockMaker_SetSounds(iType, SOUND_START_TOUCH);
	BlockMaker_AllowAsRandom(iType);
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	StopTimer_RemoveEffect(iOther);
	
	SetEntPropFloat(iOther, Prop_Send, "m_flLaggedMovementValue", CUSTOM_LAGGED_MOVEMENT);
	SetEntPropFloat(iOther, Prop_Data, "m_flGravity", CUSTOM_GRAVITY);
}

public Action:OnTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	StopTimer_RemoveEffect(iOther);
}

public Action:OnEndTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	StartTimer_RemoveEffect(iOther);
}

public OnClientDisconnect(iClient)
{
	StopTimer_RemoveEffect(iClient);
}

StopTimer_RemoveEffect(iClient)
{
	if(g_hTimer_RemoveEffect[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_RemoveEffect[iClient]);
	g_hTimer_RemoveEffect[iClient] = INVALID_HANDLE;
}

StartTimer_RemoveEffect(iClient)
{
	StopTimer_RemoveEffect(iClient);
	g_hTimer_RemoveEffect[iClient] = CreateTimer(0.5, Timer_RemoveEffect, GetClientSerial(iClient));
}

public Action:Timer_RemoveEffect(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_RemoveEffect[iClient] = INVALID_HANDLE;
	
	if(GetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue") == CUSTOM_LAGGED_MOVEMENT)
		SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", 1.0);
	
	if(GetEntPropFloat(iClient, Prop_Data, "m_flGravity") == CUSTOM_GRAVITY)
		SetEntPropFloat(iClient, Prop_Data, "m_flGravity", 1.0);
}