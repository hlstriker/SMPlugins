#include <sourcemod>
#include <sdkhooks>
#include <sdktools_entinput>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Grenades For Skill Servers";
new const String:PLUGIN_VERSION[] = "2.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Disables grenade annoyances used for course servers.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("grenades_skill_servers_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_blind", Event_PlayerBlind_Pre, EventHookMode_Pre);
	HookEvent("smokegrenade_detonate", Event_SmokeGrenadeDetonate_Pre, EventHookMode_Pre);
}

public Event_PlayerBlind_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	SetEntPropFloat(iClient, Prop_Send, "m_flFlashDuration", 0.0);
}

public Event_SmokeGrenadeDetonate_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iEnt = GetEventInt(hEvent, "entityid");
	if(iEnt > 0)
		AcceptEntityInput(iEnt, "KillHierarchy");
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
		SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost);
	}
}

public OnStartTouchPost(iEnt, iOther)
{
	static String:szClassName[15];
	if(!GetEntityClassname(iOther, szClassName, sizeof(szClassName)))
		return;
	
	if(!StrEqual(szClassName, "func_breakable"))
		return;
	
	// Detonate/kill grenades if they touch a func_breakable so they don't get stuck forever.
	GrenadeDetonate(iEnt);
}

GrenadeDetonate(iEnt)
{
	// WARNING: The smoke, TA, and decoy are simply removed without blowing up with this function.
	SetEntProp(iEnt, Prop_Send, "m_bIsLive", 1);
	
	SetEntPropEnt(iEnt, Prop_Data, "m_hGroundEntity", 0);
	SetEntProp(iEnt, Prop_Send, "m_nBounces", 10000);
	SetEntProp(iEnt, Prop_Data, "m_nNextThinkTick", 1);
	
	SetEntProp(iEnt, Prop_Data, "m_takedamage", 2); 
	AcceptEntityInput(iEnt, "KillHierarchy");
	SDKHooks_TakeDamage(iEnt, 0, 0, 99999.0);
}