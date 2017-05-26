#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Spectate Menu";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to use a menu to spectate other players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

const OBS_MODE_IN_EYE = 4;
new g_iObserverTarget[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("spectate_menu_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_specmenu", OnSpectateMenu, "sm_specmenu - Opens the spectate menu.");
	
	CreateTimer(0.33, Timer_SetTarget, _, TIMER_REPEAT);
}

public Action:OnSpectateMenu(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetClientTeam(iClient) == CS_TEAM_NONE)
		return Plugin_Handled;
	
	DisplayMenu_Spectate(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_Spectate(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Spectate);
	SetMenuTitle(hMenu, "Spectate Menu");
	
	decl String:szBuffer[64], String:szInfo[16];
	
	new iTarget = GetClientFromSerial(g_iObserverTarget[iClient]);
	if(iTarget)
	{
		Format(szBuffer, sizeof(szBuffer), "Clear: %N", iTarget);
		AddMenuItem(hMenu, "-1", szBuffer);
	}
	else
	{
		AddMenuItem(hMenu, "", "Select a target.", ITEMDRAW_DISABLED);
	}
	
	for(iTarget=1; iTarget<=MaxClients; iTarget++)
	{
		if(iClient == iTarget)
			continue;
		
		if(!IsClientInGame(iTarget))
			continue;
		
		if(GetClientTeam(iTarget) == CS_TEAM_NONE)
			continue;
		
		GetClientName(iTarget, szBuffer, sizeof(szBuffer));
		FormatEx(szInfo, sizeof(szInfo), "%i", GetClientSerial(iTarget));
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	DisplayMenuAtItem(hMenu, iClient, iStartItem, 0);
}

public MenuHandle_Spectate(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[16];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iTarget = StringToInt(szInfo);
	if(iTarget < 0)
	{
		g_iObserverTarget[iParam1] = 0;
		
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}Cleared your observer target.");
		DisplayMenu_Spectate(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	iTarget = GetClientFromSerial(iTarget);
	if(!iTarget)
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}That player is no longer in the server.");
		DisplayMenu_Spectate(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	SpectateTarget(iParam1, iTarget);
	CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}Spectating: {lightred}%N{olive}.", iTarget);
	
	DisplayMenu_Spectate(iParam1, GetMenuSelectionPosition());
}

SpectateTarget(iClient, iTarget)
{
	g_iObserverTarget[iClient] = GetClientSerial(iTarget);
	
	// If dead and not a ghost.
	if(!IsPlayerAlive(iClient) && GetEntProp(iClient, Prop_Send, "m_lifeState") != 1)
	{
		SetEntProp(iClient, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE);
		SetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget", iTarget);
	}
}

public Action:Timer_SetTarget(Handle:hTimer)
{
	decl iTarget;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(IsPlayerAlive(iClient))
			continue;
		
		iTarget = GetClientFromSerial(g_iObserverTarget[iClient]);
		if(!iTarget || !IsPlayerAlive(iTarget))
			continue;
		
		SetEntPropEnt(iClient, Prop_Send, "m_hObserverTarget", iTarget);
	}
}