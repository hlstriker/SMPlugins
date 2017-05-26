#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = "Gravity fix",
	author = "hlstriker",
	description = "gravity fix",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	HookEvent("cs_pre_restart", EventRound, EventHookMode_PostNoCopy);
}

public Action:EventRound(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	ServerCommand("sv_gravity 800");
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	SetEntityGravity(iClient, 1.0);
}