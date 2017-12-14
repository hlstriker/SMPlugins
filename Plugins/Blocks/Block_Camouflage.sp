#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <cstrike>
#include "../../Libraries/BlockMaker/block_maker"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Camouflage";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"Camouflage"
new const String:SOUND_START_TOUCH[] = "sound/items/spraycan_spray.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/camouflage/block.mdl",
	"models/swoobles/blocks/camouflage/block.dx90.vtx",
	"models/swoobles/blocks/camouflage/block.phy",
	"models/swoobles/blocks/camouflage/block.vvd",
	
	"materials/swoobles/blocks/camouflage/block.vtf",
	"materials/swoobles/blocks/camouflage/block.vmt"
};

#define EFFECT_TIME		8.0
new Handle:g_hTimer_RemoveEffect[MAXPLAYERS+1];

#define MODEL_T		"models/player/custom_player/legacy/tm_leet_variantB.mdl"
#define MODEL_CT	"models/player/custom_player/legacy/ctm_idf.mdl"
new String:g_szOriginalModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("block_camouflage_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(g_bLibLoaded_ModelSkinManager)
		return;
	
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	GetClientModel(iClient, g_szOriginalModel[iClient], sizeof(g_szOriginalModel[]));
}

public MSManager_OnSpawnPost_Post(iClient)
{
	MSManager_GetPlayerModel(iClient, g_szOriginalModel[iClient], sizeof(g_szOriginalModel[]));
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	PrecacheModel(MODEL_T, true);
	PrecacheModel(MODEL_CT, true);
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

public Event_PlayerDeath_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
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
	switch(GetClientTeam(iClient))
	{
		case CS_TEAM_T:		SetEntityModel(iClient, MODEL_CT);
		case CS_TEAM_CT:	SetEntityModel(iClient, MODEL_T);
		default: return;
	}
	
	StartTimer_RemoveEffect(iClient);
}

RemoveClientEffect(iClient)
{
	SetEntityModel(iClient, g_szOriginalModel[iClient]);
}