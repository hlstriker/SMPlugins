#include <sourcemod>
#include <sdkhooks>
#include <sdktools_sound>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Disable Fall & Drown Damage";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables fall and drown damage.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:g_szBlockSounds[][] =
{
	//"player/land.wav",
	//"player/land2.wav",
	//"player/land3.wav",
	//"player/land4.wav",
	"player/damage1.wav",
	"player/damage2.wav",
	"player/damage3.wav"
};


public OnPluginStart()
{
	CreateConVar("disable_fall_drown_damage_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(iDamageType & DMG_FALL)
	&& !(iDamageType & DMG_DROWN))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	for(new i=0; i<sizeof(g_szBlockSounds); i++)
	{
		if(StrEqual(g_szBlockSounds[i], szSample))
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}