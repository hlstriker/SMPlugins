#include <sourcemod>
#include <sdkhooks>
#include <hls_color_chat>
#include "../../Libraries/DatabaseUserStats/database_user_stats"
#include "../../Libraries/WebPageViewer/web_page_viewer"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Help Menu";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A menu that links to help web pages.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bDontShowMenu[MAXPLAYERS+1];

#define TITLE_MAX_LEN	48
#define URL_MAX_LEN		512
enum _:HelpMenuEntry
{
	String:HME_Title[TITLE_MAX_LEN],
	String:HME_URL[URL_MAX_LEN]
};

new Handle:g_aHelpMenuEntries;


public OnPluginStart()
{
	CreateConVar("help_menu_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_helpmenu", OnHelpMenu, "Opens the help menu.");
	
	RegAdminCmd("sm_reloadhelpmenu", Command_ReloadHelpMenu, ADMFLAG_BAN, "sm_reloadhelpmenu - Reloads the entries from the help_menu.txt file.");
	
	HookEvent("round_start", Event_RoundStart_Pre, EventHookMode_Pre);
	
	g_aHelpMenuEntries = CreateArray(HelpMenuEntry);
	LoadHelpMenuEntries();
}

public OnClientPutInServer(iClient)
{
	g_bDontShowMenu[iClient] = false;
}

public Event_RoundStart_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		TryShowHelpMenu(iClient);
	}
}

public Action:OnHelpMenu(iClient, iArgs)
{
	if(!iClient || !IsClientInGame(iClient))
		return Plugin_Handled;
	
	DisplayMenu_Help(iClient);
	
	return Plugin_Handled;
}

public DBUserStats_OnServerStatsReady(iClient, iServerRank, iSecondsPlayed, iSecondsAFK)
{
	TryShowHelpMenu(iClient);
}

TryShowHelpMenu(iClient)
{
	if(g_bDontShowMenu[iClient])
		return;
	
	if(!IsPlayerAlive(iClient))
		return;
	
	if(!DBUserStats_HasServerStatsLoaded(iClient))
		return;
	
	// Return if more than 15 hours played.
	new iSecondsPlayed = DBUserStats_GetServerTimePlayed(iClient);
	if(iSecondsPlayed > 54000)
		return;
	
	DisplayMenu_Help(iClient);
}

DisplayMenu_Help(iClient, iStartItem=0)
{
	g_bDontShowMenu[iClient] = true;
	
	new Handle:hMenu = CreateMenu(MenuHandle_Help);
	SetMenuTitle(hMenu, "!helpmenu");
	
	decl String:szInfo[6];
	decl eEntry[HelpMenuEntry];
	for(new i=0; i<GetArraySize(g_aHelpMenuEntries); i++)
	{
		GetArrayArray(g_aHelpMenuEntries, i, eEntry);
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, eEntry[HME_Title]);
	}
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}There are no help entries.");
}

public MenuHandle_Help(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(IsClientInGame(iParam1))
			CPrintToChat(iParam1, "{olive}Type {lightred}!helpmenu {olive}to see help again.");
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iIndex = StringToInt(szInfo);
	
	if(iIndex >= GetArraySize(g_aHelpMenuEntries))
		return;
	
	decl eEntry[HelpMenuEntry];
	GetArrayArray(g_aHelpMenuEntries, iIndex, eEntry);
	WebPageViewer_OpenPage(iParam1, eEntry[HME_URL]);
	
	DisplayMenu_Help(iParam1, GetMenuSelectionPosition());
}

public Action:Command_ReloadHelpMenu(iClient, iArgs)
{
	LoadHelpMenuEntries();
	LogAction(iClient, -1, "\"%L\" reloaded the help menu file", iClient);
	
	return Plugin_Handled;
}

bool:LoadHelpMenuEntries()
{
	ClearArray(g_aHelpMenuEntries);
	
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/swoobles/help_menu.txt");
	
	new Handle:kv = CreateKeyValues("Entries");
	if(!FileToKeyValues(kv, szBuffer))
	{
		CloseHandle(kv);
		return false;
	}
	
	if(!KvGotoFirstSubKey(kv))
	{
		CloseHandle(kv);
		return false;
	}
	
	decl String:szTitle[TITLE_MAX_LEN], String:szURL[URL_MAX_LEN];
	decl eEntry[HelpMenuEntry];
	
	do
	{
		KvGetSectionName(kv, szTitle, sizeof(szTitle));
		if(!szTitle[0])
			continue;
		
		KvGetString(kv, "url", szURL, sizeof(szURL));
		if(!szURL[0])
			continue;
		
		strcopy(eEntry[HME_Title], TITLE_MAX_LEN, szTitle);
		strcopy(eEntry[HME_URL], URL_MAX_LEN, szURL);
		
		PushArrayArray(g_aHelpMenuEntries, eEntry);
	}
	while(KvGotoNextKey(kv));
	
	CloseHandle(kv);
	return true;
}