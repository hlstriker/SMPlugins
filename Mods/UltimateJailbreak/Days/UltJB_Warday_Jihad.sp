#include <sourcemod>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_jihad"
#include <emitsoundany>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Jihad";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Jihad.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Jihad"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new const String:SZ_SOUND_MUSIC[] = "sound/swoobles/ultimate_jailbreak/jihad_day.mp3";


public OnPluginStart()
{
	CreateConVar("warday_jihad_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	AddFileToDownloadsTable(SZ_SOUND_MUSIC);
	PrecacheSoundAny(SZ_SOUND_MUSIC[6]);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_KILL_WORLD_WEAPONS | DAY_FLAG_DISABLE_WEAPON_BUYING | DAY_FLAG_FORCE_FREE_FOR_ALL, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	UltJB_Jihad_SetAllowBombDropping(false);
}

public OnFreezeEnd()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		UltJB_Jihad_SetJihad(iClient);
	}
	
	EmitSoundToAllAny(SZ_SOUND_MUSIC[6], _, _, SNDLEVEL_NONE, _, 0.2);
}

public OnDayEnd(iClientEndedDay)
{
	UltJB_Jihad_SetAllowBombDropping(true);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		UltJB_Jihad_ClearJihad(iClient);
	}
}