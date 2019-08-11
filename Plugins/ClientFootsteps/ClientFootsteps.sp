#include <sourcemod>
#include <sdkhooks>
#include <sdktools_sound>
#include "client_footsteps"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Client Footsteps";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have a per client footsteps value.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bHasCustomFootsteps[MAXPLAYERS+1];
new FootstepValue:g_iCustomFootstepsValue[MAXPLAYERS+1];
new g_iLastSetTick[MAXPLAYERS+1];

new Handle:cvar_footsteps;

new const String:SZ_STEP_SOUNDS[][] =
{
	"~player/footsteps/",
	"~)player/land"
};

new Handle:g_aCachedStrLen;


public OnPluginStart()
{
	CreateConVar("client_footsteps_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aCachedStrLen = CreateArray();
	CacheStepStringLengths();
	
	cvar_footsteps = FindConVar("sv_footsteps");
	SetConVarFlags(cvar_footsteps, GetConVarFlags(cvar_footsteps) | FCVAR_REPLICATED);
	SetConVarBool(cvar_footsteps, true);
	HookConVarChange(cvar_footsteps, OnConVarChanged);
	
	AddNormalSoundHook(OnNormalSound);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("client_footsteps");
	CreateNative("ClientFootsteps_SetValue", _ClientFootsteps_SetValue);
	CreateNative("ClientFootsteps_GetValue", _ClientFootsteps_GetValue);
	
	return APLRes_Success;
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	// NOTE: If we want to allow the server to toggle sv_footsteps on and off we will still have to keep it forced on here and disable it via SetValue instead.
	SetConVarBool(cvar_footsteps, true);
}

public OnClientPutInServer(iClient)
{
	g_bHasCustomFootsteps[iClient] = false;
}

public _ClientFootsteps_GetValue(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	
	if(!g_bHasCustomFootsteps[iClient])
		return _:FOOTSTEP_VALUE_USE_SERVER_SETTINGS;
	
	return _:g_iCustomFootstepsValue[iClient];
}

public _ClientFootsteps_SetValue(Handle:hPlugin, iNumParams)
{
	SetValue(GetNativeCell(1), GetNativeCell(2));
}

SetValue(iClient, FootstepValue:iValue)
{
	if(iValue < FootstepValue:0 || iValue >= FOOTSTEP_VALUE_USE_SERVER_SETTINGS)
	{
		ClearCustomValue(iClient);
		return;
	}
	
	g_bHasCustomFootsteps[iClient] = true;
	g_iCustomFootstepsValue[iClient] = iValue;
	g_iLastSetTick[iClient] = GetGameTickCount();
}

ClearCustomValue(iClient)
{
	if(g_iLastSetTick[iClient] == GetGameTickCount())
		return;
	
	g_bHasCustomFootsteps[iClient] = false;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	// Return if the entity isn't a player.
	if(!(1 <= iEntity <= MaxClients))
		return Plugin_Continue;
	
	// Return if the sound isn't a step sound.
	static i, iStrLen, iChar, bool:bIsStepSound;
	bIsStepSound = false;
	
	for(i=0; i<sizeof(SZ_STEP_SOUNDS); i++)
	{
		iStrLen = GetArrayCell(g_aCachedStrLen, i);
		
		iChar = szSample[iStrLen];
		szSample[iStrLen] = '\x0';
		
		if(!StrEqual(szSample, SZ_STEP_SOUNDS[i]))
		{
			szSample[iStrLen] = iChar;
			continue;
		}
		
		bIsStepSound = true;
		szSample[iStrLen] = iChar;
		break;
	}
	
	if(!bIsStepSound)
		return Plugin_Continue;
	
	// Only play the step sound to the correct players.
	new iNumNewClients;
	decl iNewClients[64];
	for(i=0; i<iNumClients; i++)
	{
		if(!ShouldSendSoundToPlayer(iEntity, iClients[i]))
			continue;
		
		iNewClients[iNumNewClients++] = iClients[i];
	}
	
	for(i=0; i<iNumNewClients; i++)
		iClients[i] = iNewClients[i];
	
	iNumClients = iNumNewClients;
	
	return Plugin_Changed;
}

bool:ShouldSendSoundToPlayer(iOwner, iPlayer)
{
	if(!g_bHasCustomFootsteps[iPlayer])
		return true;
	
	switch(g_iCustomFootstepsValue[iPlayer])
	{
		case FOOTSTEP_VALUE_ENABLE_OWN_ONLY:
		{
			if(iOwner == iPlayer)
				return true;
			else
				return false;
		}
		case FOOTSTEP_VALUE_ENABLE_ALL: return true;
		case FOOTSTEP_VALUE_DISABLE_ALL: return false;
	}
	
	return true;
}

CacheStepStringLengths()
{
	decl iLen;
	for(new i=0; i<sizeof(SZ_STEP_SOUNDS); i++)
	{
		iLen = strlen(SZ_STEP_SOUNDS[i]);
		
		if(iLen >= PLATFORM_MAX_PATH)
		{
			iLen = PLATFORM_MAX_PATH - 1;
			LogMessage("WARNING: A footstep sound string is too long [%s]", SZ_STEP_SOUNDS[i]);
		}
		
		PushArrayCell(g_aCachedStrLen, iLen);
	}
}