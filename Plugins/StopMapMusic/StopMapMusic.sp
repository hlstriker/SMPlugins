#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_engine>
#include <sdktools_sound>
#include <sdktools_entinput>
#include "../../Libraries/ClientCookies/client_cookies"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Stop Map Music";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Stops music from playing from the map.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

// NOTE: If the volume is set to 0 (and 1?) it won't allow you to turn the volume back up for currently playing sounds.
// Setting the volume to 2 is best if you want to solve that problem.
//#define ZERO_VOLUME 2
#define ZERO_VOLUME 0

#define SPAWNFLAG_PLAY_EVERYWHERE	1
new Handle:g_aSoundsPlayedThisRound;

enum _:SoundInfo
{
	SI_Entity,
	String:SI_Sound[PLATFORM_MAX_PATH],
	Float:SI_Volume,
	SI_Pitch,
	SI_Level
};

new g_iVolumePercent[MAXPLAYERS+1];
new g_iPitch[MAXPLAYERS+1];

new bool:g_bIsQuerying[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("stop_map_music_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aSoundsPlayedThisRound = CreateArray(SoundInfo);
	
	RegConsoleCmd("sm_music", OnMusicToggle, "Toggles map music from playing.");
	RegConsoleCmd("sm_stopmusic", OnMusicToggle, "Toggles map music from playing.");
	//RegConsoleCmd("sm_stopsound", OnMusicToggle, "Toggles map music from playing.");
	RegConsoleCmd("sm_volume", OnMusicToggle, "Toggles map music from playing.");
	RegConsoleCmd("sm_pitch", OnPitchToggle, "Toggles map music pitch.");
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	AddAmbientSoundHook(OnAmbientSound);
}

public OnMapStart()
{
	ClearArray(g_aSoundsPlayedThisRound);
}

public Event_RoundStart(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	ClearArray(g_aSoundsPlayedThisRound);
}

public OnClientPutInServer(iClient)
{
	g_bIsQuerying[iClient] = false;
	g_iVolumePercent[iClient] = 100;
	g_iPitch[iClient] = 100;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_MAP_MUSIC_VOLUME))
	{
		g_iVolumePercent[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_MAP_MUSIC_VOLUME);
	}
	else
	{
		g_iVolumePercent[iClient] = 100;
	}
	
	if(ClientCookies_HasCookie(iClient, CC_TYPE_MAP_MUSIC_PITCH))
	{
		g_iPitch[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_MAP_MUSIC_PITCH);
	}
	else
	{
		g_iPitch[iClient] = 100;
	}
}

public Action:OnMusicToggle(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_MusicVolume(iClient);
	
	return Plugin_Handled;
}

public Action:OnPitchToggle(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_Pitch(iClient);
	
	return Plugin_Handled;
}

public Action:OnAmbientSound(String:szSample[PLATFORM_MAX_PATH], &iEntity, &Float:fVolume, &iLevel, &iPitch, Float:fPosition[3], &iFlags, &Float:fDelay)
{
	if(!IsValidEntity(iEntity))
		return Plugin_Continue;
	
	if(!(GetEntProp(iEntity, Prop_Data, "m_spawnflags") & SPAWNFLAG_PLAY_EVERYWHERE))
		return Plugin_Continue;
	
	if(iFlags & SND_SPAWNING)
		return Plugin_Continue;
	
	// The map is stopping the music by setting its volume to 0. Remove it from the array if needed and return.
	static eSoundInfo[SoundInfo];
	if(fVolume < 0.01)
	{
		for(new i=0; i<GetArraySize(g_aSoundsPlayedThisRound); i++)
		{
			GetArrayArray(g_aSoundsPlayedThisRound, i, eSoundInfo);
			
			if(eSoundInfo[SI_Entity] != iEntity)
				continue;
			
			if(!StrEqual(eSoundInfo[SI_Sound], szSample))
				continue;
			
			RemoveFromArray(g_aSoundsPlayedThisRound, i);
			break;
		}
		
		// We need to stop it from playing on the EmitSound we started.
		// Let's actually stop it the real way instead of just setting the volume to 0 like the map is trying to do..
		for(new iClient=1; iClient<=MaxClients; iClient++)
		{
			if(!IsClientInGame(iClient))
				continue;
			
			EmitSoundToClient(iClient, szSample, iEntity, SNDCHAN_BODY, iLevel, SND_STOP | SND_STOPLOOPING, 0.0, iPitch, _, fPosition);
		}
		
		return Plugin_Continue;
	}
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		EmitSoundToClient(iClient, szSample, iEntity, SNDCHAN_BODY, iLevel, iFlags, float(g_iVolumePercent[iClient]) / 100.0, (g_iPitch[iClient] != 100) ? g_iPitch[iClient] : iPitch, _, fPosition);
	}
	
	new bool:bIsSoundInArray;
	for(new i=0; i<GetArraySize(g_aSoundsPlayedThisRound); i++)
	{
		GetArrayArray(g_aSoundsPlayedThisRound, i, eSoundInfo);
		
		if(eSoundInfo[SI_Entity] != iEntity)
			continue;
		
		if(!StrEqual(eSoundInfo[SI_Sound], szSample))
			continue;
		
		bIsSoundInArray = true;
		break;
	}
	
	if(!bIsSoundInArray)
	{
		eSoundInfo[SI_Entity] = iEntity;
		eSoundInfo[SI_Volume] = fVolume;
		eSoundInfo[SI_Pitch] = iPitch;
		eSoundInfo[SI_Level] = iLevel;
		strcopy(eSoundInfo[SI_Sound], PLATFORM_MAX_PATH, szSample);
		PushArrayArray(g_aSoundsPlayedThisRound, eSoundInfo);
	}
	
	return Plugin_Stop;
}

DisplayMenu_MusicVolume(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_MusicVolume);
	SetMenuTitle(hMenu, "Select map music volume");
	
	AddMenuItem(hMenu, "100", "100% Volume");
	AddMenuItem(hMenu, "80", "80% Volume");
	AddMenuItem(hMenu, "60", "60% Volume");
	AddMenuItem(hMenu, "40", "40% Volume");
	AddMenuItem(hMenu, "20", "20% Volume");
	AddMenuItem(hMenu, "0", "0% Volume");
	
	if(!DisplayMenu(hMenu, iClient, 0))
		PrintToChat(iClient, "[SM] There are no volume options to select.");
}

public MenuHandle_MusicVolume(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(g_bIsQuerying[iParam1])
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}Please wait a second to select volume.");
		DisplayMenu_MusicVolume(iParam1);
		return;
	}
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iVolume = StringToInt(szInfo);
	
	CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}Set map music volume to {lightred}%i%c{olive}.", iVolume, '%');
	DisplayMenu_MusicVolume(iParam1);
	
	if(!iVolume)
		iVolume = ZERO_VOLUME;
	
	g_bIsQuerying[iParam1] = true;
	QueryClientConVar(iParam1, "snd_musicvolume", OnQueryFinished);
	
	if(iVolume == g_iVolumePercent[iParam1])
		return;
	
	g_iVolumePercent[iParam1] = iVolume;
	ClientCookies_SetCookie(iParam1, CC_TYPE_MAP_MUSIC_VOLUME, iVolume);
	
	ChangeVolumePitch(iParam1);
}

public OnQueryFinished(QueryCookie:cookie, iClient, ConVarQueryResult:result, const String:szConvarName[], const String:szConvarValue[], any:iData)
{
	g_bIsQuerying[iClient] = false;
	
	if(StringToInt(szConvarValue) == 1)
		return;
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Type {green}snd_musicvolume 1 {olive}in console.");
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Type {green}snd_roundstart_volume 0 {olive}in console.");
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Type {green}snd_roundend_volume 0 {olive}in console.");
}

DisplayMenu_Pitch(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Pitch);
	SetMenuTitle(hMenu, "Select map music pitch");
	
	AddMenuItem(hMenu, "100", "Normal");
	AddMenuItem(hMenu, "160", "Highest");
	AddMenuItem(hMenu, "140", "Higher");
	AddMenuItem(hMenu, "120", "High");
	AddMenuItem(hMenu, "80", "Low");
	AddMenuItem(hMenu, "60", "Lower");
	
	if(!DisplayMenu(hMenu, iClient, 0))
		PrintToChat(iClient, "[SM] There are no pitch options to select.");
}

public MenuHandle_Pitch(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iPitch = StringToInt(szInfo);
	
	CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}Set map music pitch to {lightred}%i%c{olive}.", iPitch, '%');
	DisplayMenu_Pitch(iParam1);
	
	if(iPitch == g_iPitch[iParam1])
		return;
	
	g_iPitch[iParam1] = iPitch;
	ClientCookies_SetCookie(iParam1, CC_TYPE_MAP_MUSIC_PITCH, iPitch);
	
	ChangeVolumePitch(iParam1);
}

ChangeVolumePitch(iClient)
{
	decl eSoundInfo[SoundInfo];
	for(new i=0; i<GetArraySize(g_aSoundsPlayedThisRound); i++)
	{
		GetArrayArray(g_aSoundsPlayedThisRound, i, eSoundInfo);
		EmitSoundToClient(iClient, eSoundInfo[SI_Sound], eSoundInfo[SI_Entity], SNDCHAN_BODY, eSoundInfo[SI_Level], SND_CHANGEVOL | SND_CHANGEPITCH, float(g_iVolumePercent[iClient]) / 100.0, (g_iPitch[iClient] != 100) ? g_iPitch[iClient] : eSoundInfo[SI_Pitch]);
	}
}