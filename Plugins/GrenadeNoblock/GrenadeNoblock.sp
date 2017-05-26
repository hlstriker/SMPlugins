#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Grenade Noblock";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Grenades will not collide with players.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("grenade_noblock_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnEntityCreated(iEnt, const String:szClassName[])
{
	if(strlen(szClassName) < 16)
		return;
	
	if(StrContains(szClassName, "_projectile") == -1)
		return;
	
	if(StrEqual(szClassName, "hegrenade_projectile")
	|| StrEqual(szClassName, "smokegrenade_projectile")
	|| StrEqual(szClassName, "incgrenade_projectile")
	|| StrEqual(szClassName, "decoy_projectile")
	|| StrEqual(szClassName, "molotov_projectile")
	|| StrEqual(szClassName, "tagrenade_projectile")
	|| StrEqual(szClassName, "flashbang_projectile"))
	{
		SDKHook(iEnt, SDKHook_SpawnPost, OnSpawnPost);
	}
}

public OnSpawnPost(iEnt)
{
	SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 0);
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 0);
}