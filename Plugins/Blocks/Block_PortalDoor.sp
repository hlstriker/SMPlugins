#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_trace>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Portal door";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Portal door"
new const String:SOUND_START_TOUCH[] = "sound/ambient/energy/zap9.wav";
new const String:SOUND_ERROR[] = "sound/buttons/button16.wav";

#define NUM_INCREMENT_CHECKS	16

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/portaldoor/block.mdl",
	"models/swoobles/blocks/portaldoor/block.dx90.vtx",
	"models/swoobles/blocks/portaldoor/block.phy",
	"models/swoobles/blocks/portaldoor/block.vvd",
	
	"materials/swoobles/blocks/portaldoor/block.vtf",
	"materials/swoobles/blocks/portaldoor/block.vmt"
};

new const Float:HULL_STANDING_MINS_CSGO[] = {-16.0, -16.0, 0.0};
new const Float:HULL_STANDING_MAXS_CSGO[] = {16.0, 16.0, 72.0};

new const Float:g_fDirections[][] =
{
	{1.0, 0.0, 0.0},
	{0.0, 1.0, 0.0},
	{-1.0, 0.0, 0.0},
	{0.0, -1.0, 0.0},
	{0.0, 0.0, 1.0},
	{0.0, 0.0, -1.0}
};

#define SOLID_NONE	0
#define USE_SPECIFIED_BOUNDS	3

new const FSOLID_TRIGGER = 0x0008;
new const FSOLID_USE_TRIGGER_BOUNDS	= 0x0080;

new g_iType;


public OnPluginStart()
{
	CreateConVar("block_portal_door_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	AddFileToDownloadsTable(SOUND_ERROR);
	PrecacheSoundAny(SOUND_ERROR[6], true);
}

public BlockMaker_OnRegisterReady()
{
	g_iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, OnStartTouch, _, OnTypeAssigned);
	BlockMaker_SetSounds(g_iType, SOUND_START_TOUCH);
}

public OnTypeAssigned(iBlock, iBlockID)
{
	// For traces AND collision to hit a non-solid we must NOT use FSOLID_NOT_SOLID.
	// Traces will not hit an entity using FSOLID_NOT_SOLID no matter what.
	SetEntProp(iBlock, Prop_Data, "m_nSolidType", SOLID_NONE);
	SetEntProp(iBlock, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER | FSOLID_USE_TRIGGER_BOUNDS);
	
	decl Float:fMins[3], Float:fMaxs[3];
	new Float:fLargest = GetLargestAbsoluteMinsMaxsSize(iBlock) / 2.0;
	fMins[0] = -fLargest;
	fMins[1] = -fLargest;
	fMins[2] = -fLargest;
	fMaxs[0] = fLargest;
	fMaxs[1] = fLargest;
	fMaxs[2] = fLargest;
	
	SetEntProp(iBlock, Prop_Data, "m_nSurroundType", USE_SPECIFIED_BOUNDS);
	SetEntPropVector(iBlock, Prop_Send, "m_vecSpecifiedSurroundingMins", fMins);
	SetEntPropVector(iBlock, Prop_Send, "m_vecSpecifiedSurroundingMaxs", fMaxs);
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Handled;
	
	new Handle:hBlockIDs = CreateArray();
	BlockMaker_GetBlocksByType(g_iType, hBlockIDs);
	
	new iArraySize = GetArraySize(hBlockIDs);
	if(!iArraySize)
	{
		CloseHandle(hBlockIDs);
		return Plugin_Handled;
	}
	
	decl iEnt, i;
	new Handle:hBlockEnts = CreateArray();
	for(i=0; i<iArraySize; i++)
	{
		iEnt = BlockMaker_GetBlockEntFromID(GetArrayCell(hBlockIDs, i));
		if(iEnt > 0 && iEnt != iBlock)
			PushArrayCell(hBlockEnts, iEnt);
	}
	
	CloseHandle(hBlockIDs);
	
	iArraySize = GetArraySize(hBlockEnts);
	if(!iArraySize)
	{
		CloseHandle(hBlockEnts);
		return Plugin_Handled;
	}
	
	decl Float:fOrigin[3], Float:fForward[3];
	GetEntPropVector(iBlock, Prop_Data, "m_vecOrigin", fOrigin);
	GetEntPropVector(iOther, Prop_Data, "m_vecVelocity", fForward);
	NormalizeVector(fForward, fForward);
	LargestNormalizedVector(fForward);
	
	iEnt = CanTeleportInDirection(iOther, iBlock, fOrigin, fForward, hBlockEnts, fForward);
	if(!iEnt)
	{
		for(i=0; i<sizeof(g_fDirections); i++)
		{
			iEnt = CanTeleportInDirection(iOther, iBlock, fOrigin, g_fDirections[i], hBlockEnts, fForward);
			if(iEnt)
				break;
		}
	}
	
	CloseHandle(hBlockEnts);
	
	if(!iEnt)
	{
		PlayErrorSound(iBlock);
		return Plugin_Handled;
	}
	
	TeleportEntity(iOther, fForward, NULL_VECTOR, NULL_VECTOR);
	PlayTeleportSound(iOther, iBlock);
	
	return Plugin_Handled;
}

PlayTeleportSound(iClient, iBlock)
{
	new iNumClients;
	decl iClients[MAXPLAYERS+1];
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(iPlayer == iClient)
			continue;
		
		iClients[iNumClients++] = iPlayer;
	}
	
	EmitSoundAny(iClients, iNumClients, SOUND_START_TOUCH[6], iBlock, _, SNDLEVEL_NORMAL, _, 0.6, GetRandomInt(95, 120));
	EmitSoundToClientAny(iClient, SOUND_START_TOUCH[6], iClient, _, SNDLEVEL_NORMAL, _, 0.6, GetRandomInt(95, 120));
}

PlayErrorSound(iBlock)
{
	EmitSoundToAllAny(SOUND_ERROR[6], iBlock, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
}

CanTeleportInDirection(const iClient, const iBlock, const Float:fBlockOrigin[3], const Float:fDirection[3], const Handle:hBlockEnts, Float:fNewOrigin[3])
{
	decl Float:fForward[3];
	fForward[0] = fDirection[0];
	fForward[1] = fDirection[1];
	fForward[2] = fDirection[2];
	
	new Float:fIncrement = GetLargestAbsoluteMinsMaxsSize(iBlock);
	ScaleVector(fForward, fIncrement * 2.0);
	
	decl Float:fMins[3], Float:fMaxs[3];
	fMins[0] = -fIncrement;
	fMins[1] = -fIncrement;
	fMins[2] = -fIncrement;
	fMaxs[0] = fIncrement;
	fMaxs[1] = fIncrement;
	fMaxs[2] = fIncrement;
	
	decl i, j, iEnt;
	fNewOrigin[0] = fBlockOrigin[0];
	fNewOrigin[1] = fBlockOrigin[1];
	fNewOrigin[2] = fBlockOrigin[2];
	
	new iArraySize = GetArraySize(hBlockEnts);
	new Handle:hIntersectingEnts = CreateArray();
	
	for(i=0; i<NUM_INCREMENT_CHECKS; i++)
	{
		AddVectors(fNewOrigin, fForward, fNewOrigin);
		
		for(j=0; j<iArraySize; j++)
		{
			iEnt = GetArrayCell(hBlockEnts, j);
			
			if(IsIntersecting(iEnt, fNewOrigin, fMins, fMaxs))
				PushArrayCell(hIntersectingEnts, iEnt);
		}
	}
	
	new iClosestEnt;
	decl Float:fClosestDist, Float:fDist;
	
	iArraySize = GetArraySize(hIntersectingEnts);
	for(i=0; i<iArraySize; i++)
	{
		iEnt = GetArrayCell(hIntersectingEnts, i);
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fNewOrigin);
		
		fDist = GetVectorDistance(fBlockOrigin, fNewOrigin);
		
		if(i > 0 && fDist > fClosestDist)
			continue;
		
		fClosestDist = fDist;
		iClosestEnt = iEnt;
	}
	
	CloseHandle(hIntersectingEnts);
	
	if(!iClosestEnt)
		return 0;
	
	GetEntPropVector(iClosestEnt, Prop_Data, "m_vecOrigin", fNewOrigin);
	AddVectors(fNewOrigin, fForward, fNewOrigin);
	
	if(!CanTeleportToOrigin(iClient, fNewOrigin))
		return 0;
	
	return iClosestEnt;
}

bool:CanTeleportToOrigin(iClient, const Float:fOrigin[3])
{
	TR_TraceHullFilter(fOrigin, fOrigin, HULL_STANDING_MINS_CSGO, HULL_STANDING_MAXS_CSGO, MASK_PLAYERSOLID, TraceFilter_DontHitPlayers, GetClientTeam(iClient));
	if(TR_DidHit())
		return false;
	
	return true;
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iTeam)
{
	if(!(1 <= iEnt <= MaxClients))
		return true;
	
	// TODO: Check for "mp_solid_teammates".
	// -->
	
	if(GetClientTeam(iEnt) != iTeam)
		return true;
	
	return false;
}

LargestNormalizedVector(Float:fVector[3])
{
	new Float:fLargest = -1.0;
	
	decl Float:fAbs, iIndex, i;
	for(i=0; i<sizeof(fVector); i++)
	{
		fAbs = FloatAbs(fVector[i]);
		
		if(fAbs > fLargest)
		{
			fLargest = fAbs;
			iIndex = i;
		}
	}
	
	for(i=0; i<sizeof(fVector); i++)
	{
		if(i == iIndex)
			continue;
		
		fVector[i] = 0.0;
	}
}

Float:GetLargestAbsoluteMinsMaxsSize(iEnt)
{
	decl Float:fMins[3], Float:fMaxs[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	new Float:fLargest;
	
	decl Float:fAbs, i;
	for(i=0; i<sizeof(fMins); i++)
	{
		fAbs = FloatAbs(fMins[i]);
		
		if(fAbs > fLargest)
			fLargest = fAbs;
	}
	
	for(i=0; i<sizeof(fMaxs); i++)
	{
		fAbs = FloatAbs(fMaxs[i]);
		
		if(fAbs > fLargest)
			fLargest = fAbs;
	}
	
	return fLargest;
}

bool:IsIntersecting(iEnt, const Float:fOrigin[3], const Float:fMins[3], const Float:fMaxs[3])
{
	// Get ent mins/maxs.
	new Float:fIncrement = GetLargestAbsoluteMinsMaxsSize(iEnt);
	
	decl Float:fEntMins[3], Float:fEntMaxs[3];
	fEntMins[0] = -fIncrement;
	fEntMins[1] = -fIncrement;
	fEntMins[2] = -fIncrement;
	
	fEntMaxs[0] = fIncrement;
	fEntMaxs[1] = fIncrement;
	fEntMaxs[2] = fIncrement;
	
	decl Float:fEntOrigin[3];
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fEntOrigin);
	AddVectors(fEntOrigin, fEntMins, fEntMins);
	AddVectors(fEntOrigin, fEntMaxs, fEntMaxs);
	
	// Get other mins/maxs.
	decl Float:fNewMins[3], Float:fNewMaxs[3];
	AddVectors(fOrigin, fMins, fNewMins);
	AddVectors(fOrigin, fMaxs, fNewMaxs);
	
	if(fNewMins[0] > fEntMaxs[0]
	|| fNewMins[1] > fEntMaxs[1]
	|| fNewMins[2] > fEntMaxs[2]
	
	|| fNewMaxs[0] < fEntMins[0]
	|| fNewMaxs[1] < fEntMins[1]
	|| fNewMaxs[2] < fEntMins[2])
	{
		return false;
	}
	
	return true;
}