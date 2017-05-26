#include <sourcemod>
#include "../../Libraries/ClientSettings/client_settings"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Clan Tag Filter";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Filters clan tags.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

const MAX_TAGS_IN_BLACKLIST = 512;
new String:g_szBlacklist[MAX_TAGS_IN_BLACKLIST][MAX_CLAN_TAG_LENGTH];
new g_iNumBlacklisted;


public OnPluginStart()
{
	CreateConVar("clan_tag_filter_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public Action:ClientSettings_OnRealClanTagChange(iClient, const String:szOldTag[], const String:szNewTag[], bool:bHasFakeTag)
{
	if(!g_iNumBlacklisted)
		return Plugin_Continue;
	
	if(!szNewTag[0])
		return Plugin_Continue;
	
	for(new i=0; i<g_iNumBlacklisted; i++)
	{
		if(StrContains(szNewTag, g_szBlacklist[i], false) == -1)
			continue;
		
		// Return handled to block this clan tag.
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public OnMapStart()
{
	g_iNumBlacklisted = 0;
	LoadBlacklist();
}

bool:LoadBlacklist()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/swoobles/clan_tag_blacklist.txt");
	
	new Handle:hFile = OpenFile(szBuffer, "r");
	if(hFile == INVALID_HANDLE)
		return false;
	
	while(!IsEndOfFile(hFile))
	{
		if(!ReadFileLine(hFile, szBuffer, sizeof(szBuffer)))
			continue;
		
		TrimString(szBuffer);
		
		if(strlen(szBuffer) < 3)
			continue;
		
		if((szBuffer[0] == '/' && szBuffer[1] == '/') || szBuffer[0] == '#')
			continue;
		
		if(g_iNumBlacklisted >= MAX_TAGS_IN_BLACKLIST)
		{
			LogError("The blacklist array is full. If you want to add more clan tags please recompile the plugin.");
			break;
		}
		
		strcopy(g_szBlacklist[g_iNumBlacklisted], sizeof(g_szBlacklist[]), szBuffer);
		g_iNumBlacklisted++;
	}
	
	CloseHandle(hFile);
	return true;
}