#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Freeze";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Freeze"
new const String:SOUND_START_TOUCH[] = "sound/physics/glass/glass_impact_bullet4.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/freeze/block.mdl",
	"models/swoobles/blocks/freeze/block.dx90.vtx",
	"models/swoobles/blocks/freeze/block.phy",
	"models/swoobles/blocks/freeze/block.vvd",
	
	"materials/swoobles/blocks/freeze/block.vtf",
	"materials/swoobles/blocks/freeze/block.vmt"
};

#define FFADE_STAYOUT	0x0008
#define FFADE_PURGE		0x0010
new UserMsg:g_msgFade;
new const g_iFadeColorFreeze[] = {0, 128, 255, 100};

#define FREEZE_DAMAGE	5.0
#define FREEZE_TIME		2.0
new Handle:g_hTimer_Freeze[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_freeze_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	g_msgFade = GetUserMessageId("Fade");
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
	
	FreezeClient(iOther, iBlock);
}

public OnClientDisconnect(iClient)
{
	StopTimer_Unfreeze(iClient);
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsClientInGame(iClient))
		return;
	
	if(g_hTimer_Freeze[iClient] == INVALID_HANDLE)
		return;
	
	UnfreezeClient(iClient);
	StopTimer_Unfreeze(iClient);
}

StopTimer_Unfreeze(iClient)
{
	if(g_hTimer_Freeze[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Freeze[iClient]);
	g_hTimer_Freeze[iClient] = INVALID_HANDLE;
}

StartTimer_Unfreeze(iClient)
{
	StopTimer_Unfreeze(iClient);
	g_hTimer_Freeze[iClient] = CreateTimer(FREEZE_TIME, Timer_Unfreeze, GetClientSerial(iClient));
}

public Action:Timer_Unfreeze(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_Freeze[iClient] = INVALID_HANDLE;
	UnfreezeClient(iClient);
}

FreezeClient(iClient, iBlock)
{
	SetEntityMoveType(iClient, MOVETYPE_NONE);
	SetEntityRenderColor(iClient, 0, 128, 255, 192);
	FadeScreen(iClient, 0, 0, g_iFadeColorFreeze, FFADE_STAYOUT | FFADE_PURGE);
	SDKHooks_TakeDamage(iClient, iBlock, iBlock, FREEZE_DAMAGE);
	
	StartTimer_Unfreeze(iClient);
}

UnfreezeClient(iClient)
{
	SetEntityMoveType(iClient, MOVETYPE_WALK);
	SetEntityRenderColor(iClient, 255, 255, 255, 255);
	FadeScreen(iClient, 0, 0, {1, 1, 1, 255}, FFADE_PURGE);
	EmitSoundToAllAny(SOUND_START_TOUCH[6], iClient, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
}

FadeScreen(iClient, iDurationMilliseconds, iHoldMilliseconds, const iColor[4], iFlags)
{
	decl iClients[1];
	iClients[0] = iClient;	
	
	new Handle:hMessage = StartMessageEx(g_msgFade, iClients, 1);
	
	if(GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(hMessage, "duration", iDurationMilliseconds);
		PbSetInt(hMessage, "hold_time", iHoldMilliseconds);
		PbSetInt(hMessage, "flags", iFlags);
		PbSetColor(hMessage, "clr", iColor);
	}
	else
	{
		BfWriteShort(hMessage, iDurationMilliseconds);
		BfWriteShort(hMessage, iHoldMilliseconds);
		BfWriteShort(hMessage, iFlags);
		BfWriteByte(hMessage, iColor[0]);
		BfWriteByte(hMessage, iColor[1]);
		BfWriteByte(hMessage, iColor[2]);
		BfWriteByte(hMessage, iColor[3]);
	}
	
	EndMessage();
}