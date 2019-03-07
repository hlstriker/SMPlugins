#include <sourcemod>
#include "../../Libraries/ClientSettings/client_settings"
#include "../../Libraries/ClientCookies/client_cookies"
#include "../../Libraries/Admins/admins"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Admin tags";
new const String:PLUGIN_VERSION[] = "2.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Applies admin clan tags to the admins.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bShouldHideTag[MAXPLAYERS+1];
new Float:g_fNextTagCommand[MAXPLAYERS+1];
#define TAG_COMMAND_DELAY 0.7

new const String:SZ_ADMIN_TAG[] = "Swbs! Admin";


public OnPluginStart()
{
	CreateConVar("admin_tags_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegAdminCmd("sm_admintag", Command_AdminTag, ADMFLAG_GENERIC, "sm_admintag - Allows admins to toggle their clan tag on and off.");
}

public Action:Command_AdminTag(iClient, iArgs)
{
	if(!iClient)
		return Plugin_Handled;
	
	new Float:fCurTime = GetEngineTime();
	if(fCurTime < g_fNextTagCommand[iClient])
	{
		ReplyToCommand(iClient, "[SM] Please wait a second before using this command again.");
		return Plugin_Handled;
	}
	
	g_fNextTagCommand[iClient] = fCurTime + TAG_COMMAND_DELAY;
	
	g_bShouldHideTag[iClient] = !g_bShouldHideTag[iClient];
	
	if(g_bShouldHideTag[iClient])
	{
		ClientSettings_ClearFakeClanTag(iClient);
		ReplyToCommand(iClient, "[SM] Your admin tag is now hidden.");
	}
	else
	{
		SetAdminTagIfNeeded(iClient);
		ReplyToCommand(iClient, "[SM] You will start wearing the admin tag when you next spawn.");
	}
	
	ClientCookies_SetCookie(iClient, CC_TYPE_ADMIN_TAG, g_bShouldHideTag[iClient]);
	
	return Plugin_Handled;
}

SetAdminTagIfNeeded(iClient)
{
	if(Admins_GetLevel(iClient) > AdminLevel_None)
		ClientSettings_SetFakeClanTag(iClient, SZ_ADMIN_TAG);
}

public OnClientPutInServer(iClient)
{
	g_bShouldHideTag[iClient] = false;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	g_bShouldHideTag[iClient] = bool:ClientCookies_GetCookie(iClient, CC_TYPE_ADMIN_TAG);
	
	if(!g_bShouldHideTag[iClient])
		SetAdminTagIfNeeded(iClient);
}