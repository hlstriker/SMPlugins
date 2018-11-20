#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Client Air Accelerate";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have a per client air accelerate value.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bHasCustomAirAccelerate[MAXPLAYERS+1];
new Float:g_fCustomAirAccelerate[MAXPLAYERS+1];
new g_iLastSetTick[MAXPLAYERS+1];

new Handle:cvar_airaccelerate;
new Handle:cvar_airaccelerate_default;
new Float:g_fDefaultAirAccelerate;


public OnPluginStart()
{
	CreateConVar("client_air_accelerate_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_airaccelerate = FindConVar("sv_airaccelerate");
	SetConVarFlags(cvar_airaccelerate, GetConVarFlags(cvar_airaccelerate) & ~FCVAR_REPLICATED & ~FCVAR_NOTIFY);
	
	decl String:szDefault[12];
	FloatToString(GetConVarFloat(cvar_airaccelerate), szDefault, sizeof(szDefault));
	
	if((cvar_airaccelerate_default = FindConVar("sv_airaccelerate_default")) == INVALID_HANDLE)
		cvar_airaccelerate_default = CreateConVar("sv_airaccelerate_default", szDefault, "The default sv_airaccelerate to use.");
	
	g_fDefaultAirAccelerate = GetConVarFloat(cvar_airaccelerate_default);
	HookConVarChange(cvar_airaccelerate_default, OnConVarChanged);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("client_air_accelerate");
	CreateNative("ClientAirAccel_SetCustomValue", _ClientAirAccel_SetCustomValue);
	CreateNative("ClientAirAccel_ClearCustomValue", _ClientAirAccel_ClearCustomValue);
	
	return APLRes_Success;
}

public _ClientAirAccel_SetCustomValue(Handle:hPlugin, iNumParams)
{
	new Float:fValue = GetNativeCell(2);
	
	decl String:szValue[12];
	FloatToString(fValue, szValue, sizeof(szValue));
	
	new iClient = GetNativeCell(1);
	g_fCustomAirAccelerate[iClient] = fValue;
	g_bHasCustomAirAccelerate[iClient] = true;
	g_iLastSetTick[iClient] = GetGameTickCount();
	
	if(IsFakeClient(iClient))
		return;
	
	SendConVarValue(iClient, cvar_airaccelerate, szValue);
}

public _ClientAirAccel_ClearCustomValue(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	if(g_iLastSetTick[iClient] == GetGameTickCount())
		return;
	
	g_bHasCustomAirAccelerate[iClient] = false;
	
	if(IsFakeClient(iClient))
		return;
	
	decl String:szValue[12];
	FloatToString(g_fDefaultAirAccelerate, szValue, sizeof(szValue));
	SendConVarValue(iClient, cvar_airaccelerate, szValue);
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	g_fDefaultAirAccelerate = StringToFloat(szNewValue);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		if(!g_bHasCustomAirAccelerate[iClient])
			SendConVarValue(iClient, cvar_airaccelerate, szNewValue);
	}
}

public OnClientPutInServer(iClient)
{
	if(!IsFakeClient(iClient))
	{
		static String:szValue[12];
		FloatToString(g_fDefaultAirAccelerate, szValue, sizeof(szValue));
		SendConVarValue(iClient, cvar_airaccelerate, szValue);
	}
	
	g_bHasCustomAirAccelerate[iClient] = false;
	SDKHook(iClient, SDKHook_PreThink, OnPreThink);
}

public Action:OnPreThink(iClient)
{
	if(g_bHasCustomAirAccelerate[iClient])
		SetConVarFloat(cvar_airaccelerate, g_fCustomAirAccelerate[iClient]);
	else
		SetConVarFloat(cvar_airaccelerate, g_fDefaultAirAccelerate);
	
	return Plugin_Continue;
}