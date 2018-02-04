#include <sourcemod>
#include <emitsoundany>
#include "../../../Libraries/Store/store"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Kill Sounds";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have kill sounds.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_DEFAULT_KILL_SOUNDS[][] =
{
	"player/death1.wav",
	"player/death2.wav",
	"player/death3.wav",
	"player/death4.wav",
	"player/death5.wav",
	"player/death6.wav"
};

new const String:SZ_DEFAULT_HEADSHOT_SOUNDS[][] =
{
	"player/headshot1.wav",
	"player/headshot2.wav"
};

new Handle:g_aItems;
new Handle:g_aDefaultKillSounds;


public OnPluginStart()
{
	CreateConVar("store_item_kill_sounds_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aItems = CreateArray();
	g_aDefaultKillSounds = CreateArray(PLATFORM_MAX_PATH);
	LoadDefaultKillSoundArray();
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	AddNormalSoundHook(OnNormalSound);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(SZ_DEFAULT_KILL_SOUNDS); i++)
		PrecacheSoundAny(SZ_DEFAULT_KILL_SOUNDS[i]);
	
	for(new i=0; i<sizeof(SZ_DEFAULT_HEADSHOT_SOUNDS); i++)
		PrecacheSoundAny(SZ_DEFAULT_HEADSHOT_SOUNDS[i]);
	
	ClearArray(g_aItems);
}

public Store_OnItemsReady()
{
	new iIndex = -1;
	decl iFoundItemID;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_KILL_SOUND, iFoundItemID)) != -1)
	{
		PushArrayCell(g_aItems, iFoundItemID);
	}
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(!(1 <= iAttacker <= MaxClients))
		return;
	
	if(IsFakeClient(iAttacker))
		return;
	
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	new bool:bIsHeadshot = GetEventBool(hEvent, "headshot");
	
	new iItemID = GetRandomItemID(iAttacker);
	if(iItemID < 1)
	{
		EmulateDefaultSound(iVictim, bIsHeadshot);
		return;
	}
	
	decl String:szSoundPath[PLATFORM_MAX_PATH];
	if(!Store_GetItemsMainFilePath(iItemID, szSoundPath, sizeof(szSoundPath)))
	{
		EmulateDefaultSound(iVictim, bIsHeadshot);
		return;
	}
	
	new iRagDoll = GetEntPropEnt(iVictim, Prop_Send, "m_hRagdoll");
	if(iRagDoll > 0)
		PlaySound(iVictim, szSoundPath[6], iRagDoll);
	else
		PlaySound(iVictim, szSoundPath[6]);
}

EmulateDefaultSound(iVictim, bool:bIsHeadshot)
{
	if(bIsHeadshot)
	{
		// Play a headshot sound.
		PlaySound(iVictim, SZ_DEFAULT_HEADSHOT_SOUNDS[GetRandomInt(0, sizeof(SZ_DEFAULT_HEADSHOT_SOUNDS)-1)]);
	}
	else
	{
		// Play a kill sound.
		PlaySound(iVictim, SZ_DEFAULT_KILL_SOUNDS[GetRandomInt(0, sizeof(SZ_DEFAULT_KILL_SOUNDS)-1)]);
	}
}

PlaySound(iVictim, String:szSample[], iRagdoll=-1)
{
	// Only play the custom kill sounds to players with kill sounds enabled.
	new iNumClients;
	decl iClients[64];
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		if(!ShouldSendItemToPlayer(iVictim, iClient))
			continue;
		
		iClients[iNumClients++] = iClient;
	}
	
	if(iNumClients)
		EmitSoundAny(iClients, iNumClients, szSample, (iRagdoll != -1) ? iRagdoll : iVictim, SNDCHAN_BODY, 80);
}

LoadDefaultKillSoundArray()
{
	ClearArray(g_aDefaultKillSounds);
	PushArrayString(g_aDefaultKillSounds, "player/death1.wav");
	PushArrayString(g_aDefaultKillSounds, "player/death2.wav");
	PushArrayString(g_aDefaultKillSounds, "player/death3.wav");
	PushArrayString(g_aDefaultKillSounds, "player/death4.wav");
	PushArrayString(g_aDefaultKillSounds, "player/death5.wav");
	PushArrayString(g_aDefaultKillSounds, "player/death6.wav");
	PushArrayString(g_aDefaultKillSounds, "player/headshot1.wav");
	PushArrayString(g_aDefaultKillSounds, "player/headshot2.wav");
	PushArrayString(g_aDefaultKillSounds, ")player/headshot1.wav");
	PushArrayString(g_aDefaultKillSounds, ")player/headshot2.wav");
}

bool:ShouldSendItemToPlayer(iOwner, iPlayer)
{
	new iOwnerFlags = Store_GetClientSettings(iOwner, STOREITEM_TYPE_KILL_SOUND);
	new iPlayerFlags = Store_GetClientSettings(iPlayer, STOREITEM_TYPE_KILL_SOUND);
	
	// Don't show my items to myself.
	if(iOwner == iPlayer && (iOwnerFlags & ITYPE_FLAG_SELF_DISABLED))
		return false;
	
	new iOwnerTeam = GetClientTeam(iOwner);
	new iPlayerTeam = GetClientTeam(iPlayer);
	
	// Don't show my teams items to myself.
	if(iOwnerTeam == iPlayerTeam && (iPlayerFlags & ITYPE_FLAG_MY_TEAM_DISABLED))
		return false;
	
	// Don't show the other teams items to myself.
	if(iOwnerTeam != iPlayerTeam && (iPlayerFlags & ITYPE_FLAG_OTHER_TEAM_DISABLED))
		return false;
	
	// Don't show my items to my team.
	if(iOwnerTeam == iPlayerTeam && (iOwnerFlags & ITYPE_FLAG_MY_ITEM_MY_TEAM_DISABLED))
		return false;
	
	// Don't show my items to the other team.
	if(iOwnerTeam == iPlayerTeam && (iOwnerFlags & ITYPE_FLAG_MY_ITEM_OTHER_TEAM_DISABLED))
		return false;
	
	return true;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	// Allow the sound to play if it's our emulated kill sound. We use a the body channel instead of voice.
	if(iChannel != SNDCHAN_VOICE)
		return Plugin_Continue;
	
	// Return if the entity isn't a player.
	if(!(1 <= iEntity <= MaxClients))
		return Plugin_Continue;
	
	// Return if the sound isn't a kill sound.
	if(FindStringInArray(g_aDefaultKillSounds, szSample) == -1)
		return Plugin_Continue;
	
	// Only play the default kill sounds to players with kill sounds disabled.
	new iNumNewClients;
	decl iNewClients[64];
	for(new i=0; i<iNumClients; i++)
	{
		if(ShouldSendItemToPlayer(iEntity, iClients[i]))
			continue;
		
		iNewClients[iNumNewClients++] = iClients[i];
	}
	
	for(new i=0; i<iNumNewClients; i++)
		iClients[i] = iNewClients[i];
	
	iNumClients = iNumNewClients;
	
	return Plugin_Changed;
}

GetRandomItemID(iClient)
{
	decl iItemID;
	new Handle:hOwned = CreateArray();
	for(new i=0; i<GetArraySize(g_aItems); i++)
	{
		iItemID = GetArrayCell(g_aItems, i);
		if(!Store_CanClientUseItem(iClient, iItemID))
			continue;
		
		PushArrayCell(hOwned, iItemID);
	}
	
	if(GetArraySize(hOwned) < 1)
	{
		CloseHandle(hOwned);
		return 0;
	}
	
	iItemID = GetArrayCell(hOwned, GetRandomInt(0, GetArraySize(hOwned)-1));
	CloseHandle(hOwned);
	
	return iItemID;
}