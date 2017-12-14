#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Platform (Disappearing)";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Platform (disappearing)"
#define SOUND_START_TOUCH	"sound/buttons/button1.wav"
new const String:SOUND_DISAPPEAR[] = "sound/buttons/button19.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/platformdisappearing/block.mdl",
	"models/swoobles/blocks/platformdisappearing/block.dx90.vtx",
	"models/swoobles/blocks/platformdisappearing/block.phy",
	"models/swoobles/blocks/platformdisappearing/block.vvd",
	
	"materials/swoobles/blocks/platformdisappearing/block.vtf",
	"materials/swoobles/blocks/platformdisappearing/block.vmt"
};

#define SOLID_NONE		0
#define SOLID_VPHYSICS	6
new const FSOLID_TRIGGER = 0x0008;

#define TO_NON_SOLID_DELAY	0.9
#define TO_SOLID_DELAY		0.82
new Handle:g_aToNonSolid;
new Handle:g_aToSolid;
enum _:BhopBlock
{
	BhopBlock_EntRef,
	Float:BhopBlock_EffectTime
};

new Handle:g_aBlocksRefs;
new Handle:g_hTimer_Effect;


public OnPluginStart()
{
	CreateConVar("block_platform_disappearing_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aToNonSolid = CreateArray(BhopBlock);
	g_aToSolid = CreateArray(BhopBlock);
	g_aBlocksRefs = CreateArray();
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	PrecacheSoundAny(SOUND_DISAPPEAR[6], true);
	AddFileToDownloadsTable(SOUND_DISAPPEAR);
}

public BlockMaker_OnRegisterReady()
{
	// We can't use OnStartTouch for bhop blocks since the player might get stuck when they turn back to solid, in which case OnStartTouch won't trigger again.
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], OnTouch);
	BlockMaker_SetSounds(iType, _, SOUND_START_TOUCH);
	BlockMaker_AllowAsRandom(iType);
}

public Action:OnTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Continue;
	
	static eBhopBlock[BhopBlock];
	eBhopBlock[BhopBlock_EntRef] = EntIndexToEntRef(iBlock);
	
	if(FindValueInArray(g_aBlocksRefs, eBhopBlock[BhopBlock_EntRef]) != -1)
		return Plugin_Handled;
	
	eBhopBlock[BhopBlock_EffectTime] = GetEngineTime() + TO_NON_SOLID_DELAY;
	PushArrayArray(g_aToNonSolid, eBhopBlock);
	PushArrayArray(g_aBlocksRefs, eBhopBlock[BhopBlock_EntRef]);
	
	if(g_hTimer_Effect == INVALID_HANDLE)
		g_hTimer_Effect = CreateTimer(0.1, Timer_Restore, _, TIMER_REPEAT);
	
	return Plugin_Continue;
}

public Action:Timer_Restore(Handle:hTimer)
{
	new iArraySizeToNonSolid = GetArraySize(g_aToNonSolid);
	new iArraySizeToSolid = GetArraySize(g_aToSolid);
	new Float:fCurTime = GetEngineTime();
	
	decl eBhopBlock[BhopBlock], iEnt, i, iIndex;
	
	// Do to solid first so we don't loop through more than needed since the...
	// to non-solid might push some into the to solid array that we know won't need checked this time around.
	for(i=0; i<iArraySizeToSolid; i++)
	{
		GetArrayArray(g_aToSolid, i, eBhopBlock);
		
		if(eBhopBlock[BhopBlock_EffectTime] > fCurTime)
			break;
		
		iEnt = EntRefToEntIndex(eBhopBlock[BhopBlock_EntRef]);
		RemoveFromArray(g_aToSolid, i);
		iArraySizeToSolid--;
		i--;
		
		iIndex = FindValueInArray(g_aBlocksRefs, eBhopBlock[BhopBlock_EntRef]);
		if(iIndex != -1)
			RemoveFromArray(g_aBlocksRefs, iIndex);
		
		if(iEnt < 1)
			continue;
		
		SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
		SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 0);
		SetEntityRenderMode(iEnt, RENDER_NORMAL);
		SetEntityRenderColor(iEnt);
	}
	
	// Now do to non-solid.
	for(i=0; i<iArraySizeToNonSolid; i++)
	{
		GetArrayArray(g_aToNonSolid, i, eBhopBlock);
		
		if(eBhopBlock[BhopBlock_EffectTime] > fCurTime)
			break;
		
		iEnt = EntRefToEntIndex(eBhopBlock[BhopBlock_EntRef]);
		RemoveFromArray(g_aToNonSolid, i);
		iArraySizeToNonSolid--;
		i--;
		
		if(iEnt < 1)
			continue;
		
		SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_NONE);
		SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER);
		SetEntityRenderMode(iEnt, RENDER_TRANSALPHA);
		SetEntityRenderColor(iEnt, _, _, _, 50);
		
		eBhopBlock[BhopBlock_EffectTime] = fCurTime + TO_SOLID_DELAY;
		PushArrayArray(g_aToSolid, eBhopBlock);
		
		EmitSoundToAllAny(SOUND_DISAPPEAR[6], iEnt, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
	}
	
	if(GetArraySize(g_aToSolid) || GetArraySize(g_aToNonSolid))
		return Plugin_Continue;
	
	g_hTimer_Effect = INVALID_HANDLE;
	return Plugin_Stop;
}