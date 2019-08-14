
#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Auto Bhop";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Auto Bhop",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bActivated[MAXPLAYERS+1];

new Handle:cvar_autobunnyhopping;

public OnPluginStart()
{
	CreateConVar("auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);

	new Handle:hConVar = FindConVar("sv_enablebunnyhopping");
	if(hConVar != INVALID_HANDLE)
	{
		HookConVarChange(hConVar, OnConVarChanged);
		SetConVarInt(hConVar, 1);
	}

	cvar_autobunnyhopping = FindConVar("sv_autobunnyhopping");
	SetConVarFlags(cvar_autobunnyhopping, GetConVarFlags(cvar_autobunnyhopping) & ~FCVAR_REPLICATED);
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarInt(hConVar, 1);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;

	if(!g_bActivated[iClient])
		SendConVarValue(iClient, cvar_autobunnyhopping, "0");

	SDKHook(iClient, SDKHook_PreThink, OnPreThink);
}

public Action:OnPreThink(iClient)
{
	if(g_bActivated[iClient])
		SetConVarBool(cvar_autobunnyhopping, true);
	else
		SetConVarBool(cvar_autobunnyhopping, false);

	return Plugin_Continue;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
  RegPluginLibrary("auto_bhop");

  CreateNative("AutoBhop_SetEnabled", _AutoBhop_SetEnabled);
  CreateNative("AutoBhop_IsEnabled", _AutoBhop_IsEnabled);

  return APLRes_Success;
}

public _AutoBhop_SetEnabled(Handle:hPlugin, iNumParams)
{
  new iClient = GetNativeCell(1);
  new bool:bEnabled = GetNativeCell(2);

  g_bActivated[iClient] = bEnabled;
  SendConVarValue(iClient, cvar_autobunnyhopping, bEnabled ? "1" : "0");
}

public _AutoBhop_IsEnabled(Handle:hPlugin, iNumParams)
{
  new iClient = GetNativeCell(1);

  return _:g_bActivated[iClient];
}
