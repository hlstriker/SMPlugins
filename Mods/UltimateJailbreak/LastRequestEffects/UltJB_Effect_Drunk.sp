#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR Effect: Drunk";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "LR Effect: Drunk.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EFFECT_NAME "Drunk"

new bool:g_bIncreaseFOV[MAXPLAYERS+1];
new bool:g_bIncreaseAngles[MAXPLAYERS+1];
new Float:g_fViewAngle[MAXPLAYERS+1];
new Float:g_fNextViewUpdate[MAXPLAYERS+1];

#define FFADE_IN 0x0001
new UserMsg:g_msgFade;


public OnPluginStart()
{
	CreateConVar("lr_effect_drunk_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_msgFade = GetUserMessageId("Fade");
}

public UltJB_Effects_OnRegisterReady()
{
	UltJB_Effects_RegisterEffect(EFFECT_NAME, OnEffectStart, OnEffectStop);
}

public OnEffectStart(iClient, Float:fData)
{
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnEffectStop(iClient)
{
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	ResetView(iClient);
}

public OnPostThinkPost(iClient)
{
	// Set FOV
	static iFOV;
	iFOV = GetEntProp(iClient, Prop_Send, "m_iDefaultFOV");
	
	if(iFOV <= 30)
		g_bIncreaseFOV[iClient] = true;
	else if(iFOV >= 150)
		g_bIncreaseFOV[iClient] = false;
	
	if(g_bIncreaseFOV[iClient])
		iFOV += GetRandomInt(1, 2);
	else
		iFOV -= GetRandomInt(1, 2);
	
	SetFOV(iClient, iFOV);
	
	// Set view angles
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	if(fCurTime < g_fNextViewUpdate[iClient])
		return;
	
	g_fNextViewUpdate[iClient] = fCurTime + 0.8;
	
	static Float:fAngles[3];
	GetClientEyeAngles(iClient, fAngles);
	
	if(g_fViewAngle[iClient] <= -60)
		g_bIncreaseAngles[iClient] = true;
	else if(g_fViewAngle[iClient] >= 60)
		g_bIncreaseAngles[iClient] = false;
	
	if(g_bIncreaseAngles[iClient])
	{
		g_fViewAngle[iClient] += 5;
		
		if(g_fViewAngle[iClient] > -45 && g_fViewAngle[iClient] < 45)
		{
			g_fViewAngle[iClient] = 45.0;
			FadeScreen(iClient, 1000, 0, {5, 5, 5, 255}, FFADE_IN);
		}
	}
	else
	{
		g_fViewAngle[iClient] -= 5;
		
		if(g_fViewAngle[iClient] < 45 && g_fViewAngle[iClient] > -45)
		{
			g_fViewAngle[iClient] = -45.0;
			FadeScreen(iClient, 1000, 0, {5, 5, 5, 255}, FFADE_IN);
		}
	}
	
	fAngles[2] = g_fViewAngle[iClient];
	TeleportEntity(iClient, NULL_VECTOR, fAngles, NULL_VECTOR);
}

FadeScreen(iClient, iDurationMilliseconds, iHoldMilliseconds, iColor[4], iFlags)
{
	decl iClients[1];
	iClients[0] = iClient;	
	
	new Handle:hMessage = StartMessageEx(g_msgFade, iClients, 1);
	
	if(GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(hMessage, "duration", iDurationMilliseconds);
		PbSetInt(hMessage, "hold_time", iHoldMilliseconds);
		PbSetInt(hMessage, "flags", iFlags);
		PbSetColor(hMessage, "clr", iColor);
	}
	else
	{
		BfWriteShort(hMessage, iDurationMilliseconds);
		BfWriteShort(hMessage, iHoldMilliseconds);
		BfWriteShort(hMessage, iFlags);
		BfWriteByte(hMessage, iColor[0]);
		BfWriteByte(hMessage, iColor[1]);
		BfWriteByte(hMessage, iColor[2]);
		BfWriteByte(hMessage, iColor[3]);
	}
	
	EndMessage();
}

SetFOV(iClient, iFOV)
{
	SetEntProp(iClient, Prop_Send, "m_iFOV", iFOV);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", iFOV);
}

ResetView(iClient)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	SetEntProp(iClient, Prop_Send, "m_iFOV", 0);
	SetEntProp(iClient, Prop_Send, "m_iDefaultFOV", 90);
	
	decl Float:fAngles[3];
	GetClientEyeAngles(iClient, fAngles);
	fAngles[2] = 0.0;
	TeleportEntity(iClient, NULL_VECTOR, fAngles, NULL_VECTOR);
}