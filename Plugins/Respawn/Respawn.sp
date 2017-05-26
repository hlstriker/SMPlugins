#include <sourcemod>
#include <cstrike>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Respawn";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows admins to respawn dead players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_hAdminMenu;


public OnPluginStart()
{
	CreateConVar("respawn_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_SLAY, "sm_respawn <#steamid|#userid|name> - Respawns a dead player.");
	
	if(LibraryExists("adminmenu"))
		AdminMenu_Init();
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "adminmenu"))
		AdminMenu_Init();
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "adminmenu"))
		g_hAdminMenu = INVALID_HANDLE;
}

AdminMenu_Init()
{
	new Handle:hTopMenu = GetAdminTopMenu();
	if(hTopMenu == INVALID_HANDLE)
		return;
	
	if(hTopMenu == g_hAdminMenu)
		return;
	
	g_hAdminMenu = hTopMenu;
	AdminMenu_CreateItem_Respawn(hTopMenu);
}

AdminMenu_CreateItem_Respawn(Handle:hTopMenu)
{
	new TopMenuObject:player_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_PLAYERCOMMANDS);
	if(player_commands == INVALID_TOPMENUOBJECT)
		return;
	
	AddToTopMenu(hTopMenu, "sm_respawn", TopMenuObject_Item, AdminMenuHandle_Item_Respawn, player_commands, "sm_respawn", ADMFLAG_SLAY);
}

public AdminMenuHandle_Item_Respawn(Handle:hTopMenu, TopMenuAction:action, TopMenuObject:object_id, iParam, String:szBuffer[], iMaxLength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(szBuffer, iMaxLength, "Respawn player");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		DisplayMenu_Respawn(iParam);
	}
}

DisplayMenu_Respawn(iClient, bool:bShowNoMoreMessage=true)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Respawn);
	SetMenuTitle(hMenu, "Respawn player:");
	SetMenuExitBackButton(hMenu, true);
	
	AddTargetsToMenu2(hMenu, iClient, COMMAND_FILTER_DEAD);
	
	if(!DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER))
	{
		if(bShowNoMoreMessage)
			PrintToChat(iClient, "[SM] There are no players to respawn.");
		
		DisplayTopMenu(g_hAdminMenu, iClient, TopMenuPosition_LastCategory);
	}
}

public MenuHandle_Respawn(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack && g_hAdminMenu != INVALID_HANDLE)
			DisplayTopMenu(g_hAdminMenu, iParam1, TopMenuPosition_LastCategory);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[32];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iTarget = GetClientOfUserId(StringToInt(szInfo));
	
	if(!iTarget)
	{
		PrintToChat(iParam1, "[SM] %t", "Player no longer available");
	}
	else if(!CanUserTarget(iParam1, iTarget))
	{
		PrintToChat(iParam1, "[SM] %t", "Unable to target");
	}
	else if(IsPlayerAlive(iTarget))
	{
		ReplyToCommand(iParam1, "[SM] %N is already alive.", iTarget);
	}
	else
	{
		PerformRespawn(iParam1, iTarget);
		ShowActivity2(iParam1, "[SM] ", "Respawned %N.", iTarget);
	}
	
	DisplayMenu_Respawn(iParam1, false);
}

public Action:Command_Respawn(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_respawn <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTargetName[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTargetName, sizeof(szTargetName));
	
	decl iTargetList[MAXPLAYERS], iTargetCount, bool:tn_is_ml;
	if((iTargetCount = ProcessTargetString(szTargetName, iClient, iTargetList, MAXPLAYERS, COMMAND_FILTER_DEAD, szTargetName, sizeof(szTargetName), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	new iRespawnCount;
	for(new i=0; i<iTargetCount; i++)
	{
		if(GetClientTeam(iTargetList[i]) <= CS_TEAM_SPECTATOR)
			continue;
		
		PerformRespawn(iClient, iTargetList[i]);
		iRespawnCount++;
	}
	
	if(iRespawnCount)
		ShowActivity2(iClient, "[SM] ", "Respawned %s.", szTargetName);
	
	return Plugin_Handled;
}

PerformRespawn(iClient, iTarget)
{
	LogAction(iClient, iTarget, "\"%L\" respawned \"%L\"", iClient, iTarget);
	CS_RespawnPlayer(iTarget);
}