#include <sourcemod>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

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

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	HookEvent("cs_pre_restart", EventRound, EventHookMode_PostNoCopy);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
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
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	SetEntityGravity(iClient, 1.0);
}