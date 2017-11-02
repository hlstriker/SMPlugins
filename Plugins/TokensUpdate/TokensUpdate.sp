/*
*	Some code taken directly from the default tokenstash updater plugin:
*	https://github.com/ntoxin66/ts-auto-updater/blob/master/scripting/ts-auto-updater.sp
*/

#include <sourcemod>
#include <steamworks>
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Token Update";
new const String:PLUGIN_VERSION[] = "2.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Updates tokens using various token sites.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define CONFIG_PATH		"cfg/sourcemod/tokensupdate.cfg"
#define CSGOTOKENS_URL	"http://csgotokens.com/token-api.php"
#define TOKENSTASH_URL	"http://api.tokenstash.com/gslt_getservertoken.php"
#define TOKENSTASH_VER	"0.09"

enum TokenSite
{
	TOKENSITE_TOKENSTASH = 0,
	TOKENSITE_CSGOTOKENS,
	NUM_TOKENSITES
};

new TokenSite:g_iLastCheckedSite;

new TokenSite:g_iValidatedTokenSite;
new bool:g_bHibernate;
new bool:g_bAutoUpdate;

new String:g_szApiKey_CsgoTokens[128];

new String:g_szToken[128];
new String:g_szSteamID[128];
new String:g_szApiKey_TokenStash[128];
new String:g_szServerKey[128];


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
	
	if(iFileLastModified + 180.0 < GetTime() || !g_szToken[0])
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
	g_iLastCheckedSite = g_iValidatedTokenSite;
	ValidateSite(g_iValidatedTokenSite);
}

ValidateSite(TokenSite:iSite)
{
	switch(iSite)
	{
		case TOKENSITE_TOKENSTASH: ValidateTokenRequest_TokenStash();
		case TOKENSITE_CSGOTOKENS: ValidateTokenRequest_CsgoTokens();
	}
}

TryValidateNextSite()
{
	g_iLastCheckedSite++;
	if(g_iLastCheckedSite >= NUM_TOKENSITES)
		g_iLastCheckedSite = TokenSite:0;
	
	if(g_iLastCheckedSite == g_iValidatedTokenSite)
	{
		LogError("TokensUpdate: Could not validate with any site.");
		RestartServerCountdown();
		return;
	}
	
	ValidateSite(g_iLastCheckedSite);
}

ValidateTokenRequest_CsgoTokens()
{
	new Handle:hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, CSGOTOKENS_URL);
	if(hRequest == INVALID_HANDLE)
	{
		LogError("SteamWorks_CreateHTTPRequest() created invalid_handle (csgotokens).");
		return;
	}
	
	new hostip = GetConVarInt(FindConVar("hostip"));
	new hostport = GetConVarInt(FindConVar("hostport"));
	
	decl String:szIPPort[22];
	Format(szIPPort, sizeof(szIPPort), "%i.%i.%i.%i:%i", (hostip >> 24) & 255, (hostip >> 16) & 255, (hostip >> 8) & 255, hostip & 255, hostport);
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "collectioncount", "1");
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "ip", szIPPort);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "key", g_szApiKey_CsgoTokens);
	SteamWorks_SetHTTPCallbacks(hRequest, OnCompletedRequest_CsgoTokens);
	SteamWorks_PrioritizeHTTPRequest(hRequest);
	SteamWorks_SendHTTPRequest(hRequest);
}

public OnCompletedRequest_CsgoTokens(Handle:hRequest, bool:bFailure, bool:bRequestSuccessful, EHTTPStatusCode:statusCode)
{
	if(bFailure || !bRequestSuccessful || statusCode != k_EHTTPStatusCode200OK)
	{
		CloseHandle(hRequest);
		TryValidateNextSite();
		return;
	}
	
	SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnBodyCallback_CsgoTokens);
	CloseHandle(hRequest);
}

public OnBodyCallback_CsgoTokens(const String:szData[])
{
	if(strlen(szData) == 32)
	{
		ValidateToken(szData, TOKENSITE_CSGOTOKENS);
		return;
	}
	
	if(StrEqual(szData, "BAD API KEY"))
	{
		LogError("TokensUpdate: CsgoUpdate error: %s", szData);
		TryValidateNextSite();
		return;
	}
	
	LogError("TokensUpdate error: Unknown data returned from CsgoUpdate [%s]", szData);
	TryValidateNextSite();
}

ValidateTokenRequest_TokenStash()
{
	new Handle:hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, TOKENSTASH_URL);
	if(hRequest == INVALID_HANDLE)
	{
		LogError("SteamWorks_CreateHTTPRequest() created invalid_handle (tokenstash).");
		return;
	}
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "version", TOKENSTASH_VER);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "steamid", g_szSteamID);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "apikey", g_szApiKey_TokenStash);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "serverkey", g_szServerKey);
	SteamWorks_SetHTTPCallbacks(hRequest, OnCompletedRequest_TokenStash);
	SteamWorks_PrioritizeHTTPRequest(hRequest);
	SteamWorks_SendHTTPRequest(hRequest);
}

public OnCompletedRequest_TokenStash(Handle:hRequest, bool:bFailure, bool:bRequestSuccessful, EHTTPStatusCode:statusCode)
{
	if(bFailure || !bRequestSuccessful || statusCode != k_EHTTPStatusCode200OK)
	{
		CloseHandle(hRequest);
		TryValidateNextSite();
		return;
	}
	
	SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnBodyCallback_TokenStash);
	CloseHandle(hRequest);
}

public OnBodyCallback_TokenStash(const String:szData[])
{
	new bool:bNoToken = bool:StrEqual(szData, "NO_TOKEN");
	
	if(bNoToken || StrEqual(szData, "ERROR") || StrEqual(szData, "INVALID_AUTH"))
	{
		LogError("TokensUpdate: TokenStash error: %s", szData);
		
		//if(bNoToken)
		TryValidateNextSite();
		
		return;
	}
	
	if(StrContains(szData, "SERVER_TOKEN ") == 0)
	{
		if(strlen(szData) < 14)
		{
			LogError("TokensUpdate: TokenStash error: Token data not long enough.");
			TryValidateNextSite();
			return;
		}
		
		ValidateToken(szData[13], TOKENSITE_TOKENSTASH);
		return;
	}
	
	if(StrContains(szData, "SERVER_KEY ") == 0)
	{
		if(!SetServerKey_TokenStash(szData))
			TryValidateNextSite();
		
		return;
	}
	
	LogError("TokensUpdate error: Unknown data returned from TokenStash [%s]", szData);
	TryValidateNextSite();
}

bool:SetServerKey_TokenStash(const String:szKey[])
{
	if(strlen(szKey) < 12)
	{
		LogError("TokensUpdate error: TokenStash serverkey not long enough.");
		return false;
	}
	
	strcopy(g_szServerKey, sizeof(g_szServerKey), szKey[11]);
	LogMessage("Server's TokenStash serverkey has been updated.");
	
	SaveConfig();
	RestartServerCountdown();
	
	return true;
}

bool:ValidateToken(const String:szToken[], TokenSite:iFromSite)
{
	g_iValidatedTokenSite = iFromSite;
	
	if(StrEqual(szToken, g_szToken, false))
	{
		// The current token is still valid but the server started without using a token for verification, restart it.
		if(g_hTimer == INVALID_HANDLE)
		{
			LogMessage("TokensUpdate: Initial token verification was successful, restarting the server.");
			SaveConfig();
			RestartServer();
		}
		
		// The current token is still valid.
		return;
	}
	
	strcopy(g_szToken, sizeof(g_szToken), szToken);
	LogMessage("Server's token has been updated.");
	
	SaveConfig();
	RestartServerCountdown();
	
	return;
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
		
		if(StrEqual(szKeyValue[0], "tokens_tokensite", false))
		{
			g_iValidatedTokenSite = TokenSite:StringToInt(szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokens_autoupdate", false))
		{
			g_bAutoUpdate = bool:StringToInt(szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokens_hibernate", false))
		{
			g_bHibernate = bool:StringToInt(szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "csgotokens_apikey", false))
		{
			strcopy(g_szApiKey_CsgoTokens, sizeof(g_szApiKey_CsgoTokens), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_token", false))
		{
			strcopy(g_szToken, sizeof(g_szToken), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_steamid", false))
		{
			strcopy(g_szSteamID, sizeof(g_szSteamID), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_apikey", false))
		{
			strcopy(g_szApiKey_TokenStash, sizeof(g_szApiKey_TokenStash), szKeyValue[1]);
		}
		else if(StrEqual(szKeyValue[0], "tokenstash_serverkey", false))
		{
			strcopy(g_szServerKey, sizeof(g_szServerKey), szKeyValue[1]);
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
	
	WriteFileLine(fp, "tokens_tokensite\t\"%i\"", g_iValidatedTokenSite);
	WriteFileLine(fp, "tokens_autoupdate\t\"%i\"", g_bAutoUpdate);
	WriteFileLine(fp, "tokens_hibernate\t\"%i\"", g_bHibernate);
	
	WriteFileLine(fp, "csgotokens_apikey\t\"%s\"", g_szApiKey_CsgoTokens);
	
	WriteFileLine(fp, "tokenstash_token\t\"%s\"", g_szToken);
	WriteFileLine(fp, "tokenstash_steamid\t\"%s\"", g_szSteamID);
	WriteFileLine(fp, "tokenstash_apikey\t\"%s\"", g_szApiKey_TokenStash);
	WriteFileLine(fp, "tokenstash_serverkey\t\"%s\"", g_szServerKey);
	
	CloseHandle(fp);
}