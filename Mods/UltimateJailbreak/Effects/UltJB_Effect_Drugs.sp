#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Effect: Drugs";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Effect: Drugs.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EFFECT_NAME "Drugs"

#define FFADE_STAYOUT	0x0008
#define FFADE_PURGE		0x0010
new UserMsg:g_msgFade;

enum
{
	STEP_INCREASE_BLUE = 0,
	STEP_DECREASE_RED,
	STEP_INCREASE_GREEN,
	STEP_DECREASE_BLUE,
	STEP_INCREASE_RED,
	STEP_DECREASE_GREEN
};
new g_iCurrentStep[MAXPLAYERS+1];

#define COLOR_RED	0
#define COLOR_GREEN	1
#define COLOR_BLUE	2
#define COLOR_ALPHA	3
new g_iFadeColor[MAXPLAYERS+1][4];

#define DRUG_CHANGE_AMOUNT	3
#define DRUG_DELAY			0.01
#define DEFAULT_SLAP_DELAY	0.75
new Float:g_fNextDrugUpdate[MAXPLAYERS+1];
new Float:g_fNextSlapUpdate[MAXPLAYERS+1];

new Float:g_fSlapDelay[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("ultjb_effect_drugs_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_msgFade = GetUserMessageId("Fade");
}

public UltJB_Effects_OnRegisterReady()
{
	UltJB_Effects_RegisterEffect(EFFECT_NAME, OnEffectStart, OnEffectStop, DEFAULT_SLAP_DELAY);
}

public OnEffectStart(iClient, Float:fData)
{
	g_fSlapDelay[iClient] = fData;
	InitDrugs(iClient);
}

public OnEffectStop(iClient)
{
	SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	FadeScreen(iClient, 0, 0, {1, 1, 1, 255}, FFADE_PURGE);
}

InitDrugs(iClient)
{
	g_iFadeColor[iClient][COLOR_RED] = 255;
	g_iFadeColor[iClient][COLOR_GREEN] = 0;
	g_iFadeColor[iClient][COLOR_BLUE] = 0;
	g_iFadeColor[iClient][COLOR_ALPHA] = 140;
	g_iCurrentStep[iClient] = STEP_INCREASE_BLUE;
	
	g_fNextDrugUpdate[iClient] = 0.0;
	g_fNextSlapUpdate[iClient] = GetEngineTime() + g_fSlapDelay[iClient];
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
}

public OnPostThinkPost(iClient)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime >= g_fNextSlapUpdate[iClient])
	{
		SlapPlayer(iClient, 0, false);
		g_fNextSlapUpdate[iClient] = fCurTime + g_fSlapDelay[iClient];
	}
	
	if(fCurTime < g_fNextDrugUpdate[iClient])
		return;
	
	g_fNextDrugUpdate[iClient] = fCurTime + DRUG_DELAY;
	
	switch(g_iCurrentStep[iClient])
	{
		case STEP_INCREASE_BLUE:
		{
			g_iFadeColor[iClient][COLOR_BLUE] += DRUG_CHANGE_AMOUNT;
			if(g_iFadeColor[iClient][COLOR_BLUE] >= 255)
				g_iCurrentStep[iClient]++;
		}
		case STEP_DECREASE_RED:
		{
			g_iFadeColor[iClient][COLOR_RED] -= DRUG_CHANGE_AMOUNT;
			if(g_iFadeColor[iClient][COLOR_RED] <= 0)
				g_iCurrentStep[iClient]++;
		}
		case STEP_INCREASE_GREEN:
		{
			g_iFadeColor[iClient][COLOR_GREEN] += DRUG_CHANGE_AMOUNT;
			if(g_iFadeColor[iClient][COLOR_GREEN] >= 255)
				g_iCurrentStep[iClient]++;
		}
		case STEP_DECREASE_BLUE:
		{
			g_iFadeColor[iClient][COLOR_BLUE] -= DRUG_CHANGE_AMOUNT;
			if(g_iFadeColor[iClient][COLOR_BLUE] <= 0)
				g_iCurrentStep[iClient]++;
		}
		case STEP_INCREASE_RED:
		{
			g_iFadeColor[iClient][COLOR_RED] += DRUG_CHANGE_AMOUNT;
			if(g_iFadeColor[iClient][COLOR_RED] >= 255)
				g_iCurrentStep[iClient]++;
		}
		case STEP_DECREASE_GREEN:
		{
			g_iFadeColor[iClient][COLOR_GREEN] -= DRUG_CHANGE_AMOUNT;
			if(g_iFadeColor[iClient][COLOR_GREEN] <= 0)
				g_iCurrentStep[iClient] = STEP_INCREASE_BLUE;
		}
	}
	
	FadeScreen(iClient, 0, 0, g_iFadeColor[iClient], FFADE_STAYOUT | FFADE_PURGE);
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