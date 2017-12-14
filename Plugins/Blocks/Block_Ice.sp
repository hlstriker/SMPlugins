/*
* Uses code from the CS:GO movement unlocker plugin:
* https://forums.alliedmods.net/showthread.php?t=255298
*/

#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/BlockMaker/block_maker"
#include "../../Plugins/ClientAirAccelerate/client_air_accelerate"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Ice";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Ice"
#define SOUND_START_TOUCH	"sound/swoobles/blocks/ice/ice4.mp3"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/ice/block.mdl",
	"models/swoobles/blocks/ice/block.dx90.vtx",
	"models/swoobles/blocks/ice/block.phy",
	"models/swoobles/blocks/ice/block.vvd",
	
	"materials/swoobles/blocks/ice/block.vtf",
	"materials/swoobles/blocks/ice/block.vmt"
};

new Address:g_iPatchAddress;
new g_iOriginalBytes[100];
new g_iNumBytesToNOP;

new bool:g_bActivated[MAXPLAYERS+1];
new Handle:g_hTimer_RemoveEffect[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_ice_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	// Load the gamedata file.
	new Handle:hGameConf = LoadGameConfigFile("csgo_movement_unlocker.games");
	if(hGameConf == INVALID_HANDLE)
		SetFailState("Can't find csgo_movement_unlocker.games.txt gamedata.");
	
	// Get the address near our patch area inside CGameMovement::WalkMove
	new Address:iAddr = GameConfGetAddress(hGameConf, "WalkMoveMaxSpeed");
	if(iAddr == Address_Null)
	{
		CloseHandle(hGameConf);
		SetFailState("Can't find WalkMoveMaxSpeed address.");
	}
	
	// Get the offset from the start of the signature to the start of our patch area.
	new iCapOffset = GameConfGetOffset(hGameConf, "CappingOffset");
	if(iCapOffset == -1)
	{
		CloseHandle(hGameConf);
		SetFailState("Can't find CappingOffset in gamedata.");
	}
	
	// Move right in front of the instructions we want to NOP.
	iAddr += Address:iCapOffset;
	g_iPatchAddress = iAddr;
	
	// Get how many bytes we want to NOP.
	g_iNumBytesToNOP = GameConfGetOffset(hGameConf, "PatchBytes");
	if(g_iNumBytesToNOP == -1)
	{
		CloseHandle(hGameConf);
		SetFailState("Can't find PatchBytes in gamedata.");
	}
	
	CloseHandle(hGameConf);
	
	// Make sure our array has enough memory for all the bytes we need to patch.
	if(g_iNumBytesToNOP >= sizeof(g_iOriginalBytes))
		SetFailState("Original bytes array not big enough. Increase size and recompile plugin.");
	
	// Save the original bytes.
	new iData;
	for(new i=0; i<g_iNumBytesToNOP; i++)
	{
		iData = LoadFromAddress(iAddr, NumberType_Int8);
		g_iOriginalBytes[i] = iData;
		iAddr++;
	}
}

public OnPluginEnd()
{
	RestoreOriginalBytes();
}

PatchBytes()
{
	static i;
	for(i=0; i<g_iNumBytesToNOP; i++)
		StoreToAddress(g_iPatchAddress + Address:i, 0x90, NumberType_Int8);
}

RestoreOriginalBytes()
{
	static i;
	for(i=0; i<g_iNumBytesToNOP; i++)
		StoreToAddress(g_iPatchAddress + Address:i, g_iOriginalBytes[i], NumberType_Int8);
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
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	StopTimer_RemoveEffect(iOther);
	
	ClientAirAccel_SetCustomValue(iOther, 0.0);
	g_bActivated[iOther] = true;
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
	g_hTimer_RemoveEffect[iClient] = CreateTimer(0.7, Timer_RemoveEffect, GetClientSerial(iClient));
}

public OnClientDisconnect(iClient)
{
	StopTimer_RemoveEffect(iClient);
}

public Action:Timer_RemoveEffect(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_RemoveEffect[iClient] = INVALID_HANDLE;
	
	ClientAirAccel_ClearCustomValue(iClient);
	g_bActivated[iClient] = false;
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(!g_bActivated[iClient])
	{
		RestoreOriginalBytes();
		return Plugin_Continue;
	}
	
	PatchBytes();
	//iButtons &= ~IN_JUMP;
	
	return Plugin_Changed;
}