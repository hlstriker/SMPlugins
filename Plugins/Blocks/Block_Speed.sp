#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Speed";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"Speed"
new const String:SOUND_START_TOUCH[] = "sound/player/suit_sprint.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/speed/block.mdl",
	"models/swoobles/blocks/speed/block.dx90.vtx",
	"models/swoobles/blocks/speed/block.phy",
	"models/swoobles/blocks/speed/block.vvd",
	
	"materials/swoobles/blocks/speed/block.vtf",
	"materials/swoobles/blocks/speed/block.vmt"
};

#define CUSTOM_LAGGED_MOVEMENT	2.0

#define EFFECT_TIME		8.0
new Handle:g_hTimer_RemoveEffect[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_speed_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
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
	
	GiveClientEffect(iOther);
}

public OnClientDisconnect(iClient)
{
	StopTimer_RemoveEffect(iClient);
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsClientInGame(iClient))
		return;
	
	if(g_hTimer_RemoveEffect[iClient] == INVALID_HANDLE)
		return;
	
	RemoveClientEffect(iClient);
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
	g_hTimer_RemoveEffect[iClient] = CreateTimer(EFFECT_TIME, Timer_RemoveEffect, GetClientSerial(iClient));
}

public Action:Timer_RemoveEffect(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_RemoveEffect[iClient] = INVALID_HANDLE;
	RemoveClientEffect(iClient);
}

GiveClientEffect(iClient)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", CUSTOM_LAGGED_MOVEMENT);
	StartTimer_RemoveEffect(iClient);
}

RemoveClientEffect(iClient)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", 1.0);
}