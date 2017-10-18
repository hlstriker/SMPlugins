/*
* Uses code from the CS:GO movement unlocker plugin:
* https://forums.alliedmods.net/showthread.php?t=255298
*/

#include <sourcemod>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: No Landing Cap";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: No Landing Cap.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bActivated[MAXPLAYERS+1];

new Address:g_iPatchAddress;
new g_iOriginalBytes[100];
new g_iNumBytesToNOP;

// NOTE: No landing cap interferes with prestrafing.


public OnPluginStart()
{
	CreateConVar("style_no_land_cap_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
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

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(STYLE_BIT_NO_LAND_CAP, "No Landing Cap", OnActivated, OnDeactivated, 1);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
}

public OnDeactivated(iClient)
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
	
	return Plugin_Changed;
}