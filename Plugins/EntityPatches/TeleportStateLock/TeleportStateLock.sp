#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_entinput>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Teleport State Lock";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Locks trigger_teleport enabled state.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define ENTITY_LIMIT	4096
new bool:g_bOriginalDisabled[ENTITY_LIMIT+1];

new Handle:g_aTriggerTeleportRefs;

new const FSOLID_TRIGGER = 0x0008;


public OnPluginStart()
{
	CreateConVar("teleport_state_lock_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aTriggerTeleportRefs = CreateArray();
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	GetTriggerTeleports();
}

public Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	GetTriggerTeleports();
}

GetTriggerTeleports()
{
	ClearArray(g_aTriggerTeleportRefs);
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_teleport")) != -1)
	{
		g_bOriginalDisabled[iEnt] = bool:GetEntProp(iEnt, Prop_Data, "m_bDisabled");
		PushArrayCell(g_aTriggerTeleportRefs, EntIndexToEntRef(iEnt));
	}
}

public OnGameFrame()
{
	static iArraySize, iEnt, bool:bDisabled, iSolidFlags;
	iArraySize = GetArraySize(g_aTriggerTeleportRefs);
	
	for(new i=0; i<iArraySize; i++)
	{
		iEnt = EntRefToEntIndex(GetArrayCell(g_aTriggerTeleportRefs, i));
		if(iEnt < 1)
			continue;
		
		bDisabled = bool:GetEntProp(iEnt, Prop_Data, "m_bDisabled");
		
		if(bDisabled == g_bOriginalDisabled[iEnt])
			continue;
		
		iSolidFlags = GetEntProp(iEnt, Prop_Send, "m_usSolidFlags");
		
		if(g_bOriginalDisabled[iEnt])
		{
			if(iSolidFlags & FSOLID_TRIGGER)
				iSolidFlags &= ~FSOLID_TRIGGER;
			
			AcceptEntityInput(iEnt, "Disable");
		}
		else
		{
			if(!(iSolidFlags & FSOLID_TRIGGER))
				iSolidFlags |= FSOLID_TRIGGER;
			
			AcceptEntityInput(iEnt, "Enable");
		}
		
		SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", iSolidFlags);
		SetEntProp(iEnt, Prop_Data, "m_bDisabled", g_bOriginalDisabled[iEnt]);
	}
}