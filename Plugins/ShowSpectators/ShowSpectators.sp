#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Libraries/ClientCookies/client_cookies"

#pragma semicolon 1

new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo = 
{
	name = "Show Spectators",
	author = "hlstriker",
	description = "Shows who is spectating a specific player.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define OBS_MODE_IN_EYE		4
#define OBS_MODE_CHASE		5

#define SPEC_MESSAGE_DELAY	0.47

new Handle:g_hHudSync;
new bool:g_bShowSpectators[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("hls_showspec_version", PLUGIN_VERSION, "Show Spectators Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hHudSync = CreateHudSynchronizer();
	
	CreateTimer(SPEC_MESSAGE_DELAY, TimerSpecMessage, _, TIMER_REPEAT);
	
	RegConsoleCmd("sm_speclist", OnSpecList, "Toggles the spectator list when you're spectating someone.");
}

public Action:OnSpecList(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	g_bShowSpectators[iClient] = !g_bShowSpectators[iClient];
	ClientCookies_SetCookie(iClient, CC_TYPE_SHOW_SPECTATORS, g_bShowSpectators[iClient]);
	
	ReplyToCommand(iClient, "The spectator list is now turned %s.", g_bShowSpectators[iClient] ? "ON" : "OFF");
	
	if(!g_bShowSpectators[iClient])
		ClearSyncHud(iClient, g_hHudSync);
	
	return Plugin_Handled;
}

public OnClientConnected(iClient)
{
	g_bShowSpectators[iClient] = true;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SHOW_SPECTATORS))
		g_bShowSpectators[iClient] = bool:ClientCookies_GetCookie(iClient, CC_TYPE_SHOW_SPECTATORS);
}

public Action:TimerSpecMessage(Handle:hTimer)
{
	new iLen[MAXPLAYERS+1];
	static String:szBuffer[MAXPLAYERS+1][254];
	
	new iNumInSpecList;
	static iSpecList[MAXPLAYERS], Handle:hWhosWatching[MAXPLAYERS+1];
	
	// Build the list of players being spectated along with who is watching that player.
	static iObserverMode, iSpectating, iClient, String:szName[14];
	static Handle:hStyleNames, bool:bHasStyles, iNumClientStyles, String:szStyleName[MAX_STYLE_NAME_LENGTH], iStyleIndex;
	new iTotalStylesRegistered = MovementStyles_GetTotalStylesRegistered() - 1; // Subtract 1 because it returns the "None" style.
	
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsPlayerAlive(iClient) || IsFakeClient(iClient))
			continue;
		
		iObserverMode = GetEntProp(iClient, Prop_Send, "m_iObserverMode");
		if(iObserverMode != OBS_MODE_IN_EYE && iObserverMode != OBS_MODE_CHASE)
			continue;
		
		iSpectating = GetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget");
		if(iSpectating < 1)
			continue;
		
		// Does the buffer need initialized?
		if(!iLen[iSpectating])
		{
			hWhosWatching[iSpectating] = CreateArray();
			iSpecList[iNumInSpecList++] = iSpectating;
			
			iLen[iSpectating] += FormatEx(szBuffer[iSpectating][iLen[iSpectating]], sizeof(szBuffer[])-iLen[iSpectating], "!speclist\n");
			
			// Get styles
			hStyleNames = CreateArray(MAX_STYLE_NAME_LENGTH);
			bHasStyles = MovementStyles_GetStyleNames(iSpectating, hStyleNames);
			
			if(bHasStyles || iTotalStylesRegistered)
			{
				iNumClientStyles = GetArraySize(hStyleNames);
				
				iLen[iSpectating] += FormatEx(szBuffer[iSpectating][iLen[iSpectating]], sizeof(szBuffer[])-iLen[iSpectating], "Style%s: ", (iNumClientStyles > 1) ? "s" : "");
				
				if(bHasStyles)
				{
					for(iStyleIndex=0; iStyleIndex<iNumClientStyles; iStyleIndex++)
					{
						GetArrayString(hStyleNames, iStyleIndex, szStyleName, sizeof(szStyleName));
						iLen[iSpectating] += FormatEx(szBuffer[iSpectating][iLen[iSpectating]], sizeof(szBuffer[])-iLen[iSpectating], "%s\n", szStyleName);
					}
				}
				else
				{
					iLen[iSpectating] += FormatEx(szBuffer[iSpectating][iLen[iSpectating]], sizeof(szBuffer[])-iLen[iSpectating], "None\n");
				}
			}
			
			if(hStyleNames != INVALID_HANDLE)
				CloseHandle(hStyleNames);
			
			iLen[iSpectating] += FormatEx(szBuffer[iSpectating][iLen[iSpectating]], sizeof(szBuffer[])-iLen[iSpectating], "---\n");
		}
		
		// Add this spectator to the buffer.
		PushArrayCell(hWhosWatching[iSpectating], iClient);
		
		GetClientName(iClient, szName, sizeof(szName));
		iLen[iSpectating] += FormatEx(szBuffer[iSpectating][iLen[iSpectating]], sizeof(szBuffer[])-iLen[iSpectating], "%s\n", szName);
	}
	
	// Display the buffers to the spectators.
	SetHudTextParams(0.1, -1.0, SPEC_MESSAGE_DELAY + 0.1, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	
	static j, iArraySize;
	for(new i=0; i<iNumInSpecList; i++)
	{
		iSpectating = iSpecList[i];
		
		// Display the buffer to each spectator.
		iArraySize = GetArraySize(hWhosWatching[iSpectating]);
		for(j=0; j<iArraySize; j++)
		{
			iClient = GetArrayCell(hWhosWatching[iSpectating], j);
			
			if(!g_bShowSpectators[iClient])
				continue;
			
			ShowSyncHudText(iClient, g_hHudSync, szBuffer[iSpectating]);
		}
		
		// Close the handle.
		CloseHandle(hWhosWatching[iSpectating]);
		hWhosWatching[iSpectating] = INVALID_HANDLE;
	}
}