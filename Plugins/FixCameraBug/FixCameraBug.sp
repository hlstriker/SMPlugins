#include <sourcemod>
#include <sdktools_engine>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>

#pragma semicolon 1

new const String:PLUGIN_VERSION[] = "2.0";

public Plugin:myinfo = 
{
	name = "Fix camera bug",
	author = "hlstriker",
	description = "Fixes the camera bug.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

public OnPluginStart()
{
	CreateConVar("hls_fixcamerabug_ver", PLUGIN_VERSION, "Fix Camera Bug Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	AddCommandListener(CheckSuicide, "kill");
	AddCommandListener(CheckSuicide, "explode");
}

public OnClientPutInServer(iClient)
{
	SetClientViewEntity(iClient, iClient);
}

public Action:CheckSuicide(iClient, const String:szCommand[], iArgCount)
{
	RemovePlayerFromViewControl(iClient);
}

public Action:Event_RoundStart(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		RemovePlayerFromViewControl(iClient);
	}
}

RemovePlayerFromViewControl(iClient)
{
	decl iPlayer;
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "point_viewcontrol")) != -1)
	{
		if(GetEntProp(iEnt, Prop_Data, "m_state") != 1)
			continue;
		
		iPlayer = GetEntPropEnt(iEnt, Prop_Data, "m_hPlayer");
		if(iPlayer != iClient)
			continue;
		
		AcceptEntityInput(iEnt, "Disable");
	}
}