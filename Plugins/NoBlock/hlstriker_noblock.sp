#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo = 
{
	name = "Noblock",
	author = "hlstriker",
	description = "Hlstrikers noblock.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const COLLISION_GROUP_DEBRIS_TRIGGER = 2;	// Used for no collisions against players.
new const COLLISION_GROUP_PLAYER = 5;
new const COLLISION_GROUP_PLAYER_MOVEMENT = 8;	// Bots use this.

const MAX_PLAYERS = 64;

new g_iTeam[MAX_PLAYERS+1];

new Handle:cvar_sm_enable_noblock;
new bool:g_bNoblockEnabled;


public OnPluginStart()
{
	CreateConVar("hls_noblock_ver", PLUGIN_VERSION, "Hlstrikers noblock Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_sm_enable_noblock = CreateConVar("sm_enable_noblock", "1", "Removes player collisions");
	g_bNoblockEnabled = GetConVarBool(cvar_sm_enable_noblock);
	HookConVarChange(cvar_sm_enable_noblock, OnConVarChange);
	HandleNoblock();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		g_iTeam[iClient] = GetClientTeam(iClient);
		HookSpawnIfNeeded(iClient);
	}
	
	HookEvent("player_team", hook_PlayerTeam);
}

public OnConVarChange(Handle:hCvar, const String:szOldValue[], const String:szNewValue[])
{
	new bool:bEnabled = GetConVarBool(cvar_sm_enable_noblock);
	
	if(bEnabled == g_bNoblockEnabled)
		return;
	
	g_bNoblockEnabled = bEnabled;
	HandleNoblock();
}

HandleNoblock()
{
	if(g_bNoblockEnabled)
		EnableNoblock();
	else
		DisableNoblock();
}

EnableNoblock()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			SDKHook(iClient, SDKHook_SpawnPost, hook_SpawnPost);
			if(IsPlayerAlive(iClient))
				SetNoblockOnPlayer(iClient);
		}
	}
}

DisableNoblock()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			SDKUnhook(iClient, SDKHook_SpawnPost, hook_SpawnPost);
			if(IsPlayerAlive(iClient))
			{
				if(!IsFakeClient(iClient))
					SetEntProp(iClient, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
				else
					SetEntProp(iClient, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PLAYER_MOVEMENT);
			}
		}
	}
}

public OnClientPutInServer(iClient)
{
	HookSpawnIfNeeded(iClient);
}

HookSpawnIfNeeded(iClient)
{
	if(g_bNoblockEnabled)
		SDKHook(iClient, SDKHook_SpawnPost, hook_SpawnPost);
}

public hook_SpawnPost(iClient)
{
	SetNoblockOnPlayer(iClient);
}

SetNoblockOnPlayer(iClient)
{
	SetEntProp(iClient, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
}

public Action:hook_PlayerTeam(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{	
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsPlayer(iClient))
		return;
	
	g_iTeam[iClient] = GetEventInt(hEvent, "team");
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	return false;
}