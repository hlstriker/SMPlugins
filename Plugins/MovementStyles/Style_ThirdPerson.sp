#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Third Person";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = PLUGIN_NAME,
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define QUERY_CHECK_INTERVAL 0.3
new Float:g_fNextQueryCheck[MAXPLAYERS+1];

new Handle:cvar_sv_allow_thirdperson;

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_thirdperson_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_sv_allow_thirdperson = FindConVar("sv_allow_thirdperson")) == INVALID_HANDLE)
		SetFailState("Could not find cvar sv_allow_thirdperson");
	
	SetConVarInt(cvar_sv_allow_thirdperson, 1);
	HookConVarChange(cvar_sv_allow_thirdperson, OnConVarChanged);
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	if(hConVar == cvar_sv_allow_thirdperson)
		SetConVarInt(hConVar, 1);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(STYLE_BIT_THIRDPERSON, "Thirdperson", OnActivated, OnDeactivated, 100);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
	
	SetThirdPerson(iClient);
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
	
	SetFirstPerson(iClient);
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

SetThirdPerson(iClient)
{
	ClientCommand(iClient, "thirdperson;cam_idealdist 150;cam_idealyaw 0");
}

SetFirstPerson(iClient)
{
	ClientCommand(iClient, "firstperson");
}

public OnPreThinkPost(iClient)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextQueryCheck[iClient])
		return;
	
	g_fNextQueryCheck[iClient] = fCurTime + QUERY_CHECK_INTERVAL;
	
	QueryClientConVar(iClient, "cam_command", OnQueryFinished);
}

public OnQueryFinished(QueryCookie:cookie, iClient, ConVarQueryResult:result, const String:szConvarName[], const String:szConvarValue[], any:hPack)
{
	if(!g_bActivated[iClient])
		return;
	
	if(StringToInt(szConvarValue) == 1)
		return;
	
	SetThirdPerson(iClient);
}