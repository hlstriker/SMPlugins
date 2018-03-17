#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <hls_color_chat>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_warden"
#include "../../Libraries/ClientCookies/client_cookies"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Points";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "The points plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bPointsEnabled = false;
new g_iDeadWarden;

public OnPluginStart()
{
	CreateConVar("ultjb_points_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	HookEvent("round_start", EventRoundStart_Pre, EventHookMode_Pre);
}

public EventRoundStart_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(GetClientCount(true) < 10)
		g_bPointsEnabled = false;
	else
		g_bPointsEnabled = true;
		
	g_iDeadWarden = 0;
}

public UltJB_Warden_OnDeath(iClient)
{
	g_iDeadWarden = iClient;
}

public EventPlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(!g_bPointsEnabled)
		return;
		
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!iClient || !IsPlayer(iClient))
		return;
	
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(!iAttacker || !IsPlayer(iAttacker))
		return;
		
	if(iAttacker == iClient)
		return;
	
	new iPoints = 50;
	
	if(GetClientTeam(iClient) == TEAM_GUARDS)
	{
		if(iClient == g_iDeadWarden)
		{
			ClientCookies_SetCookie(iAttacker, CC_TYPE_SWOOBLES_POINTS, ClientCookies_GetCookie(iAttacker, CC_TYPE_SWOOBLES_POINTS) + (iPoints*2));
			CPrintToChat(iAttacker, "You have been given %i points for killing the warden.", (iPoints*2));
			g_iDeadWarden = 0;
		}
		else
		{
			ClientCookies_SetCookie(iAttacker, CC_TYPE_SWOOBLES_POINTS, ClientCookies_GetCookie(iAttacker, CC_TYPE_SWOOBLES_POINTS) + iPoints);
			CPrintToChat(iAttacker, "You have been given %i points for killing a guard.", iPoints);
		}
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}
