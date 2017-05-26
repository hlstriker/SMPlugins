#include <sourcemod>
#include <sdktools_functions>
#include "../../Libraries/TimedPunishments/timed_punishments"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Detect teleport hacking";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Detects teleport hacking.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bWasPunished[MAXPLAYERS+1]; // Use this so a player isn't punished multiple times before the kick takes effect next frame.


public OnPluginStart()
{
	CreateConVar("detect_tp_hacking_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnClientConnected(iClient)
{
	g_bWasPunished[iClient] = false;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(IsFakeClient(iClient))
		return;
	
	if(GetClientTeam(iClient) <= 1)
		return;
	
	if(!IsPlayerAlive(iClient))
		return;
	
	if(g_bWasPunished[iClient])
		return;
	
	if((fAngles[0] > 361.0 || fAngles[0] < -361.0)
	|| (fAngles[1] > 361.0 || fAngles[1] < -361.0)
	|| (fAngles[2] > 361.0 || fAngles[2] < -361.0))
	{
		if(TimedPunishment_AddPunishment(0, iClient, TP_TYPE_BAN, 0, "Teleport hacking"))
		{
			PrintToChatAll("[SM] %N has been banned permanently.", iClient);
			KickClient(iClient, "%s", "Teleport hacking");
			
			g_bWasPunished[iClient] = true;
		}
	}
}