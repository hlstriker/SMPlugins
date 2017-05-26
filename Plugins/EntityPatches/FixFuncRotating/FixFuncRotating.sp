/*
* 	WARNING: This plugin is no longer needed since CS:GO finally fixed the issue!
*/

#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Fix func_rotating";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Fixes func_rotating desync issue.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aEntRefs;


public OnPluginStart()
{
	CreateConVar("fix_func_rotating_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aEntRefs = CreateArray();
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	HookEnts();
}

public Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	HookEnts();
}

HookEnts()
{
	ClearArray(g_aEntRefs);
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_rotating")) != -1)
		PushArrayCell(g_aEntRefs, EntIndexToEntRef(iEnt));
}

public OnGameFrame()
{
	static iArraySize, iEnt, Float:fAngles[3];
	iArraySize = GetArraySize(g_aEntRefs);
	
	for(new i=0; i<iArraySize; i++)
	{
		iEnt = EntRefToEntIndex(GetArrayCell(g_aEntRefs, i));
		if(iEnt < 1)
			continue;
		
		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
		fAngles[0] = AngleNormalize(fAngles[0]);
		fAngles[1] = AngleNormalize(fAngles[1]);
		fAngles[2] = AngleNormalize(fAngles[2]);
		SetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
	}
}

Float:AngleNormalize(Float:fAngle)
{
	fAngle = FloatMod(fAngle, 360.0);
	
	if(fAngle > 180.0) 
	{
		fAngle -= 360.0;
	}
	else if(fAngle < -180.0)
	{
		fAngle += 360.0;
	}
	
	return fAngle;
}

Float:FloatMod(Float:fNumerator, Float:fDenominator)
{
    return (fNumerator - fDenominator * RoundToFloor(fNumerator / fDenominator));
}