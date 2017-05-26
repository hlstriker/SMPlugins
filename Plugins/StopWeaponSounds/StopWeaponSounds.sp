#include <sourcemod>
#include <sdktools_sound>
#include <sdktools_tempents>
#include "../../Libraries/ClientCookies/client_cookies"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Stop Weapon Sounds";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "GoD-Tony & hlstriker",
	description = "Allows players to stop hearing weapon sounds.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bSoundsEnabled[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("stop_weapon_sounds_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_stopsound", OnSoundToggle, "Toggles weapon sounds from playing.");
	
	AddTempEntHook("Shotgun Shot", OnFireBullets);
	AddNormalSoundHook(OnNormalSound);
}

public Action:OnSoundToggle(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	g_bSoundsEnabled[iClient] = !g_bSoundsEnabled[iClient];
	ClientCookies_SetCookie(iClient, CC_TYPE_WEAPON_SOUND, g_bSoundsEnabled[iClient]);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Weapon sounds turned {lightred}%s{olive}.", g_bSoundsEnabled[iClient] ? "on" : "off");
	
	return Plugin_Handled;
}

public OnClientPutInServer(iClient)
{
	g_bSoundsEnabled[iClient] = true;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_WEAPON_SOUND))
	{
		g_bSoundsEnabled[iClient] = bool:ClientCookies_GetCookie(iClient, CC_TYPE_WEAPON_SOUND);
	}
	else
	{
		g_bSoundsEnabled[iClient] = true;
	}
}

public Action:OnFireBullets(const String:szTempEntName[], iClients[], iNumClients, Float:fDelay)
{
	// Rebuild the clients array.
	new iNewTotal;
	decl iNewClients[MaxClients], iClient;
	for(new i=0; i<iNumClients; i++)
	{
		iClient = iClients[i];
		
		if(g_bSoundsEnabled[iClient])
			iNewClients[iNewTotal++] = iClient;
	}
	
	// No clients were excluded.
	if(iNewTotal == iNumClients)
		return Plugin_Continue;
	
	// All clients were excluded and there is no need to broadcast.
	if(!iNewTotal)
		return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	decl Float:fTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", fTemp);
	TE_WriteVector("m_vecOrigin", fTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(iNewClients, iNewTotal, fDelay);
	
	return Plugin_Stop;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	if(iChannel != SNDCHAN_WEAPON)
		return Plugin_Continue;
	
	decl j;
	for(new i=0; i<iNumClients; i++)
	{
		if(g_bSoundsEnabled[iClients[i]])
			continue;
		
		// Remove the client from the array.
		for(j=i; j<iNumClients-1; j++)
			iClients[j] = iClients[j+1];
		
		iNumClients--;
		i--;
	}
	
	return (iNumClients > 0) ? Plugin_Changed : Plugin_Stop;
}