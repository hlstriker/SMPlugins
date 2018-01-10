#include <sourcemod>
#include <keyvalues>
#include <hls_color_chat>
#include "../../Libraries/WebPageViewer/web_page_viewer"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Info Menus";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Menus to list URLS that can be opened",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_LENGTH_COMMAND 24
#define MAX_LENGTH_TITLE 128
#define MAX_LENGTH_URL 192


enum _:MenuData
{
	String:MenuData_Title[MAX_LENGTH_TITLE],
	Handle:MenuData_InfoLinks
};

enum _:InfoLink
{
	String:InfoLink_Name[MAX_LENGTH_TITLE],
	String:InfoLink_URL[MAX_LENGTH_URL]
};

new Handle:g_aMenuLookup;
new Handle:g_aMenuData;


public OnPluginStart()
{
	CreateConVar("info_menus_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aMenuData = CreateArray(MenuData, 0);
	g_aMenuLookup = CreateArray(MAX_LENGTH_COMMAND, 0);
}

public OnMapStart()
{
	LoadMenus();
} 

LoadMenus()
{
	ClearArray(g_aMenuData);
	ClearArray(g_aMenuLookup);
	
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/info_menus.txt");
	
	new Handle:kv = CreateKeyValues("InfoMenus");
	if(!FileToKeyValues(kv, szBuffer))
	{
		CloseHandle(kv);
		return;
	}
	
	if(KvGotoFirstSubKey(kv))
	{
		new String:szTitle[MAX_LENGTH_TITLE], String:szCommand[MAX_LENGTH_COMMAND];
		do
		{
			KvSavePosition(kv);
			KvGetSectionName(kv, szTitle, sizeof(szTitle));
			KvGetString(kv, "Command", szCommand, sizeof(szCommand), "ERROR");
			
			if(StrEqual(szCommand, "ERROR"))
				continue;
			
			KvJumpToKey(kv, "URLS");
			
			new Handle:aInfoLinks = CreateArray(InfoLink, 0);
			
			if(KvGotoFirstSubKey(kv, false))
			{
				new String:szLinkName[MAX_LENGTH_TITLE], String:szLinkURL[MAX_LENGTH_URL];
				do 
				{
					KvGetSectionName(kv, szLinkName, sizeof(szLinkName));
					KvGetString(kv, NULL_STRING, szLinkURL, sizeof(szLinkURL));
					decl eInfoLink[InfoLink];
					eInfoLink[InfoLink_Name] = szLinkName;
					eInfoLink[InfoLink_URL] = szLinkURL;
					
					PushArrayArray(aInfoLinks, eInfoLink);
				}
				while (KvGotoNextKey(kv, false));
			} else
			{
				KvGoBack(kv);
				PrintToServer("InfoMenu %s has no urls", szTitle);
				continue;
			}
			KvGoBack(kv);
			KvGoBack(kv);
			new String:szBuffer2[32];
			KvGetSectionName(kv, szBuffer2, sizeof(szBuffer2));
			
			
			decl eMenuData[MenuData];
			eMenuData[MenuData_Title] = szTitle;
			eMenuData[MenuData_InfoLinks] = aInfoLinks;
			
			PushArrayArray(g_aMenuData, eMenuData);
			PushArrayString(g_aMenuLookup, szCommand);
			
			
			
			RegConsoleCmd(szCommand, OnInfoMenu);
		}
		while (KvGotoNextKey(kv));
	} else
	{
		PrintToServer("No Info Menus in sourcemod/configs/info_menus.txt");
	}
	CloseHandle(kv);
}



public Action:OnInfoMenu(iClient, iArgs)
{
	if(!iClient)
		return Plugin_Handled;
		
	
	decl String:szCommand[MAX_LENGTH_COMMAND];
	GetCmdArg(0, szCommand, MAX_LENGTH_COMMAND);
	
	new iMenuIndex = FindStringInArray(g_aMenuLookup, szCommand);
	
	if (iMenuIndex == -1)
		return Plugin_Handled;
	
	DisplayMenu_InfoMenus(iClient, iMenuIndex);
	return Plugin_Handled;
	
}


DisplayMenu_InfoMenus(iClient, iMenuIndex)
{
	decl eMenuData[MenuData];
	GetArrayArray(g_aMenuData, iMenuIndex, eMenuData);
	
	new Handle:hMenu = CreateMenu(MenuHandle_InfoMenus);
	SetMenuTitle(hMenu, eMenuData[MenuData_Title]);
	
	new Handle:aInfoLinks = eMenuData[MenuData_InfoLinks];
	
	for (new i=0;i<GetArraySize(aInfoLinks);i++)
	{
		decl eInfoLink[InfoLink];
		GetArrayArray(aInfoLinks, i, eInfoLink);
		AddMenuItem(hMenu, eInfoLink[InfoLink_URL], eInfoLink[InfoLink_Name]);
	}
	
	DisplayMenu(hMenu, iClient, 0);
}


public MenuHandle_InfoMenus(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szURL[MAX_LENGTH_URL];
	GetMenuItem(hMenu, iParam2, szURL, sizeof(szURL));
	
	CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}Loading Page {blue}%s", szURL);
	WebPageViewer_OpenPage(iParam1, szURL);
}
