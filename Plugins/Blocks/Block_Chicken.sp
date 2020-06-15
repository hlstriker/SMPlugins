#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Chicken";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"Chicken"
new const String:SOUND_CHICKEN[] = "sound/ambient/creatures/chicken_death_03.wav";
new const String:SOUND_HUMAN[] = "sound/items/itempickup.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/chicken/block.mdl",
	"models/swoobles/blocks/chicken/block.dx90.vtx",
	"models/swoobles/blocks/chicken/block.phy",
	"models/swoobles/blocks/chicken/block.vvd",
	
	"materials/swoobles/blocks/chicken/block.vtf",
	"materials/swoobles/blocks/chicken/block.vmt"
};

#define MODEL_CHICKEN			"models/chicken/chicken.mdl"
#define MODEL_CHICKEN_ZOMBIE	"models/chicken/chicken_zombie.mdl"

#define FFADE_STAYOUT	0x0008
#define FFADE_PURGE		0x0010
new UserMsg:g_msgFade;
new const g_iFadeColorZombie[] = {75, 219, 35, 100};

#define CHICKEN_HEALTH			1
#define CHICKEN_HEALTH_ZOMBIE	1000

#define CHICKEN_TIME			5.0
#define CHICKEN_TIME_ZOMBIE		12.0
new Float:g_fChickenExpireTime[MAXPLAYERS+1];
new Handle:g_aChickenClientSerials;

new Handle:g_hTimer_Effect;

new g_iOriginalHealth[MAXPLAYERS+1];
new g_iOriginalMaxHealth[MAXPLAYERS+1];
new String:g_szOriginalModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("block_chicken_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aChickenClientSerials = CreateArray();
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	
	g_msgFade = GetUserMessageId("Fade");
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	PrecacheModel(MODEL_CHICKEN, true);
	PrecacheModel(MODEL_CHICKEN_ZOMBIE, true);
	
	AddFileToDownloadsTable(SOUND_CHICKEN);
	PrecacheSoundAny(SOUND_CHICKEN[6], true);
	
	AddFileToDownloadsTable(SOUND_HUMAN);
	PrecacheSoundAny(SOUND_HUMAN[6], true);
}

public BlockMaker_OnRegisterReady()
{
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], OnTouch);
	BlockMaker_AllowAsRandom(iType);
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

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsClientInGame(iClient))
		return;
	
	new iIndex = FindValueInArray(g_aChickenClientSerials, GetClientSerial(iClient));
	if(iIndex == -1)
		return;
	
	RemoveFromArray(g_aChickenClientSerials, iIndex);
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	
	EmitSoundToAllAny(SOUND_CHICKEN[6], iClient, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(85, 95));
}

public Action:OnTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Handled;
	
	static iClientSerial;
	iClientSerial = GetClientSerial(iOther);
	
	if(FindValueInArray(g_aChickenClientSerials, iClientSerial) != -1)
		return Plugin_Handled;
	
	PushArrayCell(g_aChickenClientSerials, iClientSerial);
	
	if(g_hTimer_Effect == INVALID_HANDLE)
		g_hTimer_Effect = CreateTimer(0.5, Timer_Restore, _, TIMER_REPEAT);
	
	if(GetRandomInt(1, 100) <= 70)
	{
		SetChicken(iOther);
		EmitSoundToAllAny(SOUND_CHICKEN[6], iOther, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
		g_fChickenExpireTime[iOther] = GetEngineTime() + CHICKEN_TIME;
	}
	else
	{
		SetChickenZombie(iOther);
		EmitSoundToAllAny(SOUND_CHICKEN[6], iOther, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(50, 60));
		g_fChickenExpireTime[iOther] = GetEngineTime() + CHICKEN_TIME_ZOMBIE;
	}
	
	SDKHook(iOther, SDKHook_PostThinkPost, OnPostThinkPost);
	
	return Plugin_Continue;
}

public OnPostThinkPost(iClient)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed", 99999.0);
	
	if(GetClientButtons(iClient) & IN_DUCK)
	{
		SetEntPropFloat(iClient, Prop_Send, "m_vecViewOffset[2]", 10.0);
		SetEntPropFloat(iClient, Prop_Send, "m_flDuckAmount", 1.0);
		SetEntProp(iClient, Prop_Send, "m_bDucked", 1);
	}
	else
	{
		SetEntPropFloat(iClient, Prop_Send, "m_vecViewOffset[2]", 16.0);
		SetEntPropFloat(iClient, Prop_Send, "m_flDuckAmount", 0.0);
		SetEntProp(iClient, Prop_Send, "m_bDucked", 0);
	}
}

SetChicken(iClient)
{
	SaveHumanValues(iClient);
	
	SetEntityModel(iClient, MODEL_CHICKEN);
	SetEntityHealth(iClient, CHICKEN_HEALTH);
}

SetChickenZombie(iClient)
{
	SaveHumanValues(iClient);
	
	SetEntityModel(iClient, MODEL_CHICKEN_ZOMBIE);
	SetEntProp(iClient, Prop_Data, "m_iMaxHealth", CHICKEN_HEALTH_ZOMBIE);
	SetEntityHealth(iClient, CHICKEN_HEALTH_ZOMBIE);
	
	FadeScreen(iClient, 0, 0, g_iFadeColorZombie, FFADE_STAYOUT | FFADE_PURGE);
}

SaveHumanValues(iClient)
{
	g_iOriginalHealth[iClient] = GetEntProp(iClient, Prop_Data, "m_iHealth");
	g_iOriginalMaxHealth[iClient] = GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
}

SetHuman(iClient)
{
	SetEntityModel(iClient, g_szOriginalModel[iClient]);
	FadeScreen(iClient, 0, 0, {1, 1, 1, 255}, FFADE_PURGE);
	
	SetEntProp(iClient, Prop_Data, "m_iMaxHealth", g_iOriginalMaxHealth[iClient]);
	SetEntityHealth(iClient, g_iOriginalHealth[iClient]);
	SetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed", 4.0);
	
	EmitSoundToAllAny(SOUND_HUMAN[6], iClient, _, SNDLEVEL_NORMAL);
}

FadeScreen(iClient, iDurationMilliseconds, iHoldMilliseconds, const iColor[4], iFlags)
{
	decl iClients[1];
	iClients[0] = iClient;	
	
	new Handle:hMessage = StartMessageEx(g_msgFade, iClients, 1, USERMSG_RELIABLE);
	
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

public Action:Timer_Restore(Handle:hTimer)
{
	new Float:fCurTime = GetEngineTime();
	new iArraySize = GetArraySize(g_aChickenClientSerials);
	
	decl iClient;
	for(new i=0; i<iArraySize; i++)
	{
		iClient = GetClientFromSerial(GetArrayCell(g_aChickenClientSerials, i));
		
		if(!iClient)
		{
			RemoveFromArray(g_aChickenClientSerials, i);
			iArraySize--;
			i--;
		}
		
		if(g_fChickenExpireTime[iClient] > fCurTime)
			break;
		
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
		RemoveFromArray(g_aChickenClientSerials, i);
		iArraySize--;
		i--;
		
		if(!IsPlayerAlive(iClient))
			continue;
		
		SetHuman(iClient);
	}
	
	if(GetArraySize(g_aChickenClientSerials))
		return Plugin_Continue;
	
	g_hTimer_Effect = INVALID_HANDLE;
	return Plugin_Stop;
}