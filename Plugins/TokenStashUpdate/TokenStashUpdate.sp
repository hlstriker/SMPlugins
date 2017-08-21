/*
*	Some code taken directly from the default tokenstash updater plugin:
*	https://github.com/ntoxin66/ts-auto-updater/blob/master/scripting/ts-auto-updater.sp
*/

#include <sourcemod>
#include <steamworks>
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Token Stash Update";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Custom version to auto update tokens from tokenstash.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define CONFIG_PATH		"cfg/sourcemod/tokenstash.cfg"
#define TOKENSTASH_URL	"http://api.tokenstash.com/gslt_getservertoken.php"
#define TOKENSTASH_VER	"0.09"

new String:g_szToken[128];
new String:g_szSteamID[128];
new String:g_szApiKey[128];
new String:g_szServerKey[128];
new bool:g_bHibernate;
new bool:g_bAutoUpdate;

new Handle:g_hTimer;
new g_iRestartCountDown;


public OnPluginStart()
{
	ServerCommand("sv_setsteamaccount \"\"");
	
	if(!LoadConfig())
		SetFailState("Could not load config.");
	
	if(!g_bAutoUpdate)
	{
		ServerCommand("sv_setsteamaccount \"%s\"", g_szToken);
		return;
	}
	
	new iFileLastModified = GetFileTime(CONFIG_PATH, FileTime_LastChange);
	if(iFileLastModified == -1)
		SetFailState("Could not get configs last modified time.");
	
	if(iFileLastModified + 180.0 < GetTime() || !g_szToken[0] || !g_szServerKey[0])
	{
		RequestFrame(RequestFrame_ValidateTokenRequest);
		return;
	}
	
	ServerCommand("sv_setsteamaccount \"%s\"", g_szToken);
	g_hTimer = CreateTimer(30.0, Timer_ValidateTokenRequest, _, TIMER_REPEAT);
}

public OnConfigsExecuted()
{
	ServerCommand("sv_hibernate_when_empty %i", g_bHibernate);
}

public RequestFrame_ValidateTokenRequest(any:data)
{
	ValidateTokenRequest();
}

public Action:Timer_ValidateTokenRequest(Handle:hTimer)
{
	ValidateTokenRequest();
}

ValidateTokenRequest()
{
	new Handle:hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, TOKENSTASH_URL);
	if(hRequest == INVALID_HANDLE)
	{
		LogError("SteamWorks_CreateHTTPRequest() created invalid_handle.");
		return;
	}
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "version", TOKENSTASH_VER);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "steamid", g_szSteamID);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "apikey", g_szApiKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "serverkey", g_szServerKey);
	SteamWorks_SetHTTPCallbacks(hRequest, OnCompletedRequest);
	SteamWorks_PrioritizeHTTPRequest(hRequest);
	SteamWorks_SendHTTPRequest(hRequest);
}

public OnCompletedRequest(Handle:hRequest, bool:bFailure, bool:bRequestSuccessful, EHTTPStatusCode:statusCode)
{
	if(!bFailure && bRequestSuccessful && statusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnBodyCallback);
	
	CloseHandle(hRequest);
}

public OnBodyCallback(const String:szData[])
{
	new bool:bNoToken = bool:StrEqual(szData, "NO_TOKEN");
	
	if(bNoToken || StrEqual(szData, "ERROR") || StrEqual(szData, "INVALID_AUTH"))
	{
		LogError("TokenStash error: %s", szData);
		
		if(bNoToken)
			RestartServerCountdown();
		
		return;
	}
	
	if(StrContains(szData, "SERVER_TOKEN ") == 0)
	{
		ValidateToken(szData);
		return;
	}
	
	if(StrContains(szData, "SERVER_KEY ") == 0)
	{
		SetServerKey(szData);
		return;
	}
	
	LogError("TokenStash error: Unknown data returned.");
}

ValidateToken(const String:szToken[])
{
	if(strlen(szToken) < 14)
	{
		LogError("TokenStash error: Token data not long enough.");
		return;
	}
	
	if(StrEqual(szToken[13], g_szToken))
	{
		// The current token is still valid but the server started without using a token for verification, restart it.
		if(g_hTimer == INVALID_HANDLE)
		{
			LogMessage("TokenStash: Initial token verification was successful, restarting the server.");
			SaveConfig();
			RestartServer();
		}
		
		// The current token is still valid.
		return;
	}
	
	strcopy(g_szToken, sizeof(g_szToken), szToken[13]);
	LogMessage("Server's token has been updated.");
	
	SaveConfig();
	RestartServerCountdown();
}

SetServerKey(const String:szKey[])
{
	if(strlen(szKey) < 12)
	{
		LogError("TokenStash error: Key data not long enough.");
		return;
	}
	
	strcopy(g_szServerKey, sizeof(g_szServerKey), szKey[11]);
	LogMessage("Server's key has been updated.");
	
	SaveConfig();
	RestartServerCountdown();
}

RestartServerCountdown()
{
	if(g_hTimer == INVALID_HANDLE)
	{
		// Restart the server immediately.
		RestartServer();
		return;
	}
	
	CloseHandle(g_hTimer);
	
	g_iRestartCountDown = 240;
	g_hTimer = CreateTimer(1.0, Timer_RestartServer, _, TIMER_REPEAT);
	PrintRestartTimeToChat();
}

public Action:Timer_RestartServer(Handle:hTimer)
{
	g_iRestartCountDown--;
	
	if(g_iRestartCountDown == 0)
	{
		RestartServer();
		g_hTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	switch(g_iRestartCountDown)
	{
		case
			1800,
			1500,
			1200,
			900,
			600,
			300,
			180,
			120,
			60,
			45,
			30,
			15,
			10,
			5,
			4,
			3,
			2,
			1:
			PrintRestartTimeToChat();
	}
	
	return Plugin_Continue;
}

PrintRestartTimeToChat()
{
	CPrintToChatAll("{red}Server restarting in: {yellow}%.1f %s.", (g_iRestartCountDown >= 60) ? float(g_iRestartCountDown) / 60.0 : float(g_iRestartCountDown), (g_iRestartCountDown >= 60) ? "minutes" : "seconds");
	PrintToServer("Server restarting in: %.1f %s.", (g_iRestartCountDown >= 60) ? float(g_iRestartCountDown) / 60.0 : float(g_iRestartCountDown), (g_iRestartCountDown >= 60) ? "minutes" : "seconds");
}

public OnMapEnd()
{
	if(g_iRestartCountDown > 0)
		RestartServer();
}

RestartServer()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(IsFakeClient(iClient))
			continue;
		
		KickClientEx(iClient, "Server is restarting...");
	}
	
	ServerCommand("quit");
}

bool:LoadConfig()
{
	new Handle:fp = OpenFile(CONFIG_PATH, "r");
	if(fp == INVALID_HANDLE)
	{
		LogError("Error opening \"%s\" for reading.", CONFIG_PATH);
		return false;
	}
	
	decl String:szBuffer[256], String:szKeyValue[2][128];
	while(!IsEndOfFile(fp))
	{
		if(!ReadFileLine(fp, szBuffer, sizeof(szBuffer)))
			continue;
		
		if(ExplodeString(szBuffer, "\t", szKeyValue, sizeof(szKeyValue), sizeof(szKeyValue[])) != 2)
			continue;
		
		TrimString(szKeyValue[0]);
		TrimString(szKeyValue[1]);
		
		StripQuotes(szKeyValue[0]);
		StripQuotes(szKeyValue[1]);
		
		if(StrEqual(szKeyValue[0], "tokenstash_token", false))
		{
			strcopy(g_szToken, sizeof(g_szToken), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_steamid", false))
		{
			strcopy(g_szSteamID, sizeof(g_szSteamID), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_apikey", false))
		{
			strcopy(g_szApiKey, sizeof(g_szApiKey), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_serverkey", false))
		{
			strcopy(g_szServerKey, sizeof(g_szServerKey), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_hibernate", false))
		{
			g_bHibernate = bool:StringToInt(szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_autoupdate", false))
		{
			g_bAutoUpdate = bool:StringToInt(szKeyValue[1]);
		}
	}
	
	CloseHandle(fp);
	return true;
}

SaveConfig()
{
	new Handle:fp = OpenFile(CONFIG_PATH, "w");
	if(fp == INVALID_HANDLE)
	{
		LogError("Error opening \"%s\" for writing.", CONFIG_PATH);
		return;
	}
	
	WriteFileLine(fp, "tokenstash_token\t\"%s\"", g_szToken);
	WriteFileLine(fp, "tokenstash_steamid\t\"%s\"", g_szSteamID);
	WriteFileLine(fp, "tokenstash_apikey\t\"%s\"", g_szApiKey);
	WriteFileLine(fp, "tokenstash_serverkey\t\"%s\"", g_szServerKey);
	WriteFileLine(fp, "tokenstash_hibernate\t\"%i\"", g_bHibernate);
	WriteFileLine(fp, "tokenstash_autoupdate\t\"%i\"", g_bAutoUpdate);
	
	CloseHandle(fp);
}