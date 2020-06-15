#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: God Mode";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"God Mode"
new const String:SOUND_GOD_START[] = "sound/items/suitchargeok1.wav";
new const String:SOUND_GOD_END[] = "sound/items/suitchargeno1.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/godmode/block.mdl",
	"models/swoobles/blocks/godmode/block.dx90.vtx",
	"models/swoobles/blocks/godmode/block.phy",
	"models/swoobles/blocks/godmode/block.vvd",
	
	"materials/swoobles/blocks/godmode/block.vtf",
	"materials/swoobles/blocks/godmode/block.vmt"
};

#define FFADE_STAYOUT	0x0008
#define FFADE_PURGE		0x0010
new UserMsg:g_msgFade;
new const g_iFadeColorGod[] = {255, 242, 158, 100};

#define	DAMAGE_NO	0
#define DAMAGE_YES	2

#define GOD_TIME		8.0
new Handle:g_hTimer_Effect[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_god_mode_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	g_msgFade = GetUserMessageId("Fade");
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	AddFileToDownloadsTable(SOUND_GOD_END);
	PrecacheSoundAny(SOUND_GOD_END[6], true);
}

public BlockMaker_OnRegisterReady()
{
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, OnStartTouch);
	BlockMaker_SetSounds(iType, SOUND_GOD_START);
	BlockMaker_AllowAsRandom(iType);
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	GodClient(iOther);
}

public OnClientDisconnect(iClient)
{
	StopTimer_Ungod(iClient);
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsClientInGame(iClient))
		return;
	
	if(g_hTimer_Effect[iClient] == INVALID_HANDLE)
		return;
	
	UngodClient(iClient);
	StopTimer_Ungod(iClient);
}

StopTimer_Ungod(iClient)
{
	if(g_hTimer_Effect[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Effect[iClient]);
	g_hTimer_Effect[iClient] = INVALID_HANDLE;
}

StartTimer_Ungod(iClient)
{
	StopTimer_Ungod(iClient);
	g_hTimer_Effect[iClient] = CreateTimer(GOD_TIME, Timer_Ungod, GetClientSerial(iClient));
}

public Action:Timer_Ungod(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_Effect[iClient] = INVALID_HANDLE;
	UngodClient(iClient);
}

GodClient(iClient)
{
	SetEntProp(iClient, Prop_Data, "m_takedamage", DAMAGE_NO);
	SetEntityRenderColor(iClient, 255, 226, 45, 215);
	FadeScreen(iClient, 0, 0, g_iFadeColorGod, FFADE_STAYOUT | FFADE_PURGE);
	
	StartTimer_Ungod(iClient);
}

UngodClient(iClient)
{
	SetEntProp(iClient, Prop_Data, "m_takedamage", DAMAGE_YES);
	SetEntityRenderColor(iClient, 255, 255, 255, 255);
	FadeScreen(iClient, 0, 0, {1, 1, 1, 255}, FFADE_PURGE);
	EmitSoundToAllAny(SOUND_GOD_END[6], iClient, _, SNDLEVEL_NORMAL, _, _, GetRandomInt(95, 120));
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