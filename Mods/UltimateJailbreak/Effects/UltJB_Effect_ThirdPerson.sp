#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Effect: Third Person";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Effect: Third Person.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EFFECT_NAME "Third Person"

#define QUERY_CHECK_INTERVAL 0.3
new Float:g_fNextQueryCheck[MAXPLAYERS+1];
new bool:g_bInEffect[MAXPLAYERS+1];

new Handle:cvar_sv_allow_thirdperson;


public OnPluginStart()
{
	CreateConVar("ultjb_effect_third_person_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
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

public UltJB_Effects_OnRegisterReady()
{
	UltJB_Effects_RegisterEffect(EFFECT_NAME, OnEffectStart, OnEffectStop);
}

public OnEffectStart(iClient, Float:fData)
{
	g_bInEffect[iClient] = true;
	
	SetThirdPerson(iClient);
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public OnEffectStop(iClient)
{
	g_bInEffect[iClient] = false;
	
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
	SetFirstPerson(iClient);
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
	if(!g_bInEffect[iClient])
		return;
	
	if(StringToInt(szConvarValue) == 1)
		return;
	
	SetThirdPerson(iClient);
}