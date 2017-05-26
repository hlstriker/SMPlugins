#include <sourcemod>
#include <sdkhooks>
#include "../ClientSettings/client_settings"

#undef REQUIRE_PLUGIN
#include <cstrike>
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Client Settings";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to handle clients settings.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new String:g_szClientName[MAXPLAYERS+1][MAX_NAME_LENGTH];
new String:g_szRealClanTag[MAXPLAYERS+1][MAX_CLAN_TAG_LENGTH];
new String:g_szFakeClanTag[MAXPLAYERS+1][MAX_CLAN_TAG_LENGTH];
new bool:g_bHasFakeClanTag[MAXPLAYERS+1];

new Handle:g_hFwd_OnNameChange;
new Handle:g_hFwd_OnRealClanTagChange;
new Handle:g_hFwd_OnFakeClanTagChange;

new bool:g_bLibraryLoaded_cstrike;


public OnPluginStart()
{
	CreateConVar("api_client_settings_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnNameChange = CreateGlobalForward("ClientSettings_OnNameChange", ET_Ignore, Param_Cell, Param_String, Param_String);
	g_hFwd_OnRealClanTagChange = CreateGlobalForward("ClientSettings_OnRealClanTagChange", ET_Event, Param_Cell, Param_String, Param_String, Param_Cell);
	g_hFwd_OnFakeClanTagChange = CreateGlobalForward("ClientSettings_OnFakeClanTagChange", ET_Ignore, Param_Cell, Param_String, Param_String);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("client_settings");
	
	CreateNative("ClientSettings_SetFakeClanTag", _ClientSettings_SetFakeClanTag);
	CreateNative("ClientSettings_ClearFakeClanTag", _ClientSettings_ClearFakeClanTag);
	CreateNative("ClientSettings_HasFakeClanTag", _ClientSettings_HasFakeClanTag);
	
	CreateNative("ClientSettings_GetRealClanTag", _ClientSettings_GetRealClanTag);
	CreateNative("ClientSettings_GetFakeClanTag", _ClientSettings_GetFakeClanTag);
	
	return APLRes_Success;
}

public _ClientSettings_GetRealClanTag(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	if(!g_bLibraryLoaded_cstrike)
	{
		LogError("cstrike library not loaded.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	SetNativeString(2, g_szRealClanTag[iClient], GetNativeCell(3));
	
	return true;
}

public _ClientSettings_GetFakeClanTag(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	if(!g_bLibraryLoaded_cstrike)
	{
		LogError("cstrike library not loaded.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	SetNativeString(2, g_szFakeClanTag[iClient], GetNativeCell(3));
	
	return true;
}

public _ClientSettings_HasFakeClanTag(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	if(!g_bLibraryLoaded_cstrike)
	{
		LogError("cstrike library not loaded.");
		return false;
	}
	
	if(!g_bHasFakeClanTag[GetNativeCell(1)])
		return false;
	
	return true;
}

public _ClientSettings_SetFakeClanTag(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	if(!g_bLibraryLoaded_cstrike)
	{
		LogError("cstrike library not loaded.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	
	decl String:szClanTag[MAX_CLAN_TAG_LENGTH];
	GetNativeString(2, szClanTag, sizeof(szClanTag));
	if(!StrEqual(szClanTag, g_szFakeClanTag[iClient]))
	{
		Call_StartForward(g_hFwd_OnFakeClanTagChange);
		Call_PushCell(iClient);
		Call_PushStringEx(g_szFakeClanTag[iClient], sizeof(g_szFakeClanTag[]), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, 0);
		Call_PushStringEx(szClanTag, sizeof(szClanTag), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, 0);
		Call_Finish();
		
		strcopy(g_szFakeClanTag[iClient], sizeof(g_szFakeClanTag[]), szClanTag);
		
		#if defined _cstrike_included
		CS_SetClientClanTag(iClient, szClanTag);
		#endif
	}
	
	g_bHasFakeClanTag[iClient] = true;
	
	return true;
}

public _ClientSettings_ClearFakeClanTag(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	if(!g_bLibraryLoaded_cstrike)
	{
		LogError("cstrike library not loaded.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	g_bHasFakeClanTag[iClient] = false;
	
	#if defined _cstrike_included
	CS_SetClientClanTag(iClient, g_szRealClanTag[iClient]);
	#endif
	
	return true;
}

public OnAllPluginsLoaded()
{
	g_bLibraryLoaded_cstrike = LibraryExists("cstrike");
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "cstrike"))
		g_bLibraryLoaded_cstrike = false;
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "cstrike"))
		g_bLibraryLoaded_cstrike = true;
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	// Check to see if the clients clan tag changed.
	CheckClanTagChanged(iClient);
	
	#if defined _cstrike_included
	// It seems the clients fake tag will revert to their real tag (not sure when it's triggered).
	// Reapply the fake tag on spawn if needed.
	if(g_bHasFakeClanTag[iClient])
		CS_SetClientClanTag(iClient, g_szFakeClanTag[iClient]);
	#endif
}

public OnClientDisconnect_Post(iClient)
{
	strcopy(g_szClientName[iClient], sizeof(g_szClientName[]), "");
	strcopy(g_szRealClanTag[iClient], sizeof(g_szRealClanTag[]), "");
	strcopy(g_szFakeClanTag[iClient], sizeof(g_szFakeClanTag[]), "");
	g_bHasFakeClanTag[iClient] = false;
}

public OnClientSettingsChanged(iClient)
{
	if(!IsClientInGame(iClient))
		return;
	
	// Forward if the clients name changed.
	decl String:szBuffer[MAX_NAME_LENGTH+1];
	GetClientName(iClient, szBuffer, sizeof(szBuffer));
	if(!StrEqual(szBuffer, g_szClientName[iClient]))
	{
		Call_StartForward(g_hFwd_OnNameChange);
		Call_PushCell(iClient);
		Call_PushStringEx(g_szClientName[iClient], sizeof(g_szClientName[]), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, 0);
		Call_PushStringEx(szBuffer, sizeof(szBuffer), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, 0);
		Call_Finish();
		
		strcopy(g_szClientName[iClient], sizeof(g_szClientName[]), szBuffer);
	}
	
	// Check to see if the clients clan tag changed.
	CheckClanTagChanged(iClient);
}

CheckClanTagChanged(iClient)
{
	if(!g_bLibraryLoaded_cstrike)
		return;
	
	// Forward if the clients real clan tag changed.
	decl String:szBuffer[MAX_CLAN_TAG_LENGTH+1];
	
	#if defined _cstrike_included
	CS_GetClientClanTag(iClient, szBuffer, sizeof(szBuffer));
	#else
	szBuffer[0] = 0x00;
	#endif
	
	// WARNGING: The clan tag that CS_GetClientClanTag() gets can be the real or fake tag.
	// We need to compare variables to see if the real tag changed or not.
	if(g_bHasFakeClanTag[iClient] && StrEqual(szBuffer, g_szFakeClanTag[iClient]))
		return;
	
	if(!StrEqual(szBuffer, g_szRealClanTag[iClient]))
	{
		decl Action:iReturn;
		Call_StartForward(g_hFwd_OnRealClanTagChange);
		Call_PushCell(iClient);
		Call_PushStringEx(g_szRealClanTag[iClient], sizeof(g_szRealClanTag[]), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, 0);
		Call_PushStringEx(szBuffer, sizeof(szBuffer), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, 0);
		Call_PushCell(g_bHasFakeClanTag[iClient]);
		Call_Finish(iReturn);
		
		if(iReturn == Plugin_Continue)
		{
			strcopy(g_szRealClanTag[iClient], sizeof(g_szRealClanTag[]), szBuffer);
		}
		else
		{
			strcopy(g_szRealClanTag[iClient], sizeof(g_szRealClanTag[]), "");
			
			#if defined _cstrike_included
			CS_SetClientClanTag(iClient, "");
			#endif
		}
		
		#if defined _cstrike_included
		// We need to set the fake tag here if needed.
		if(g_bHasFakeClanTag[iClient])
			CS_SetClientClanTag(iClient, g_szFakeClanTag[iClient]);
		#endif
	}
}