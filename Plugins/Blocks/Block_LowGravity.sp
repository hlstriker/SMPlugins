#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdkhooks>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Low Gravity";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Low Gravity"
#define SOUND_START_TOUCH	"sound/swoobles/blocks/lowgravity/lowgravity.mp3"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/lowgravity/block.mdl",
	"models/swoobles/blocks/lowgravity/block.dx90.vtx",
	"models/swoobles/blocks/lowgravity/block.phy",
	"models/swoobles/blocks/lowgravity/block.vvd",
	
	"materials/swoobles/blocks/lowgravity/block.vtf",
	"materials/swoobles/blocks/lowgravity/block.vmt"
};

#define LOW_GRAVITY_VALUE	0.25
#define LOW_GRAVITY_TIME	15.0
new Float:g_fRemoveGravityTime[MAXPLAYERS+1];
new bool:g_bHasLeftGround[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_low_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
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
	
	g_fRemoveGravityTime[iOther] = GetEngineTime() + LOW_GRAVITY_TIME;
	g_bHasLeftGround[iOther] = (GetEntPropEnt(iOther, Prop_Send, "m_hGroundEntity") == -1);
	GiveLowGravity(iOther);
	
	SDKUnhook(iOther, SDKHook_PostThinkPost, OnPostThinkPost);
	SDKHook(iOther, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnPostThinkPost(iClient)
{
	static iGroundEnt, Float:fCurTime;
	iGroundEnt = GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity");
	fCurTime = GetEngineTime();
	
	if((iGroundEnt != -1 && g_bHasLeftGround[iClient]) || (fCurTime >= g_fRemoveGravityTime[iClient] && !g_bHasLeftGround[iClient]))
	{
		RemoveLowGravity(iClient);
		PrintHintText(iClient, "<font color='#c41919'>Low gravity removed.</font>");
		return;
	}
	
	if(iGroundEnt == -1)
		g_bHasLeftGround[iClient] = true;
	
	GiveLowGravity(iClient);
	
	if(g_bHasLeftGround[iClient])
	{
		PrintHintText(iClient, "<font color='#c41919'>Low gravity will be removed:</font>\n<font color='#6FC41A'>when you land.</font>");
	}
	else
	{
		PrintHintText(iClient, "<font color='#c41919'>Low gravity will be removed:</font>\n<font color='#6FC41A'>in %i seconds.</font>", RoundToCeil(g_fRemoveGravityTime[iClient] - fCurTime));
	}
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsClientInGame(iClient))
		return;
	
	RemoveLowGravity(iClient);
}

GiveLowGravity(iClient)
{
	SetEntityGravity(iClient, LOW_GRAVITY_VALUE);
}

RemoveLowGravity(iClient)
{
	SetEntityGravity(iClient, 1.0);
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}