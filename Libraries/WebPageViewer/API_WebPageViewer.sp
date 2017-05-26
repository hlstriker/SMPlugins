#include <sourcemod>
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Web Page Viewer";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to let users view web pages.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("api_web_page_viewer_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("web_page_viewer");
	
	CreateNative("WebPageViewer_OpenPage", _WebPageViewer_OpenPage);
	return APLRes_Success;
}

public _WebPageViewer_OpenPage(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 4 || iNumParams > 5)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	decl String:szFullURL[2048];
	GetNativeString(2, szFullURL, sizeof(szFullURL));
	
	if(StrContains(szFullURL, "swoobles.com") != -1)
	{
		// From web page viewer = 1
		if(StrContains(szFullURL, "?") != -1)
		{
			Format(szFullURL, sizeof(szFullURL), "%s&wpv=1", szFullURL);
		}
		else
		{
			Format(szFullURL, sizeof(szFullURL), "%s?wpv=1", szFullURL);
		}
	}
	
	decl String:szReplaceChar[2];
	szReplaceChar[0] = '\x11';
	szReplaceChar[1] = '\x0';
	ReplaceString(szFullURL, sizeof(szFullURL), "?", szReplaceChar);
	
	szReplaceChar[0] = '\x12';
	ReplaceString(szFullURL, sizeof(szFullURL), "&", szReplaceChar);
	
	szReplaceChar[0] = '\x13';
	ReplaceString(szFullURL, sizeof(szFullURL), "#", szReplaceChar);
	
	Format(szFullURL, sizeof(szFullURL), "https://swoobles.com/plugin_page_viewer/web_page_viewer.php?url=%s&w=%i&h=%i&r=%i%i", szFullURL, GetNativeCell(3), GetNativeCell(4), GetTime(), GetRandomInt(1, 100));
	
	if(iNumParams >= 5 && !GetNativeCell(5))
	{
		ShowMOTDPanel(GetNativeCell(1), "", szFullURL, MOTDPANEL_TYPE_URL);
		return;
	}
	
	new Handle:hPack = CreateDataPack();
	WritePackString(hPack, szFullURL);
	QueryClientConVar(GetNativeCell(1), "cl_disablehtmlmotd", OnQueryFinished, hPack);
}

public OnQueryFinished(QueryCookie:cookie, iClient, ConVarQueryResult:result, const String:szConvarName[], const String:szConvarValue[], any:hPack)
{
	if(StringToInt(szConvarValue) != 0)
	{
		CloseHandle(hPack);
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Type {green}cl_disablehtmlmotd 0 {olive}in console.");
		return;
	}
	
	decl String:szFullURL[2048];
	ResetPack(hPack, false);
	ReadPackString(hPack, szFullURL, sizeof(szFullURL));
	CloseHandle(hPack);
	
	ShowMOTDPanel(iClient, "", szFullURL, MOTDPANEL_TYPE_URL);
}