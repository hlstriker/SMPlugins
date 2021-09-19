
#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Auto Strafe";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Auto Strafe",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bActivated[MAXPLAYERS+1];
new g_iGroundTicks[MAXPLAYERS+1];

public OnPluginStart()
{
	CreateConVar("auto_strafe_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(!g_bActivated[iClient])
		return Plugin_Continue;

	if(!IsPlayerAlive(iClient))
		return Plugin_Continue;

	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return Plugin_Continue;

	if(GetEntityFlags(iClient) & FL_ONGROUND)
		g_iGroundTicks[iClient]++;
	else
		g_iGroundTicks[iClient] = 0;


	decl Float:fEyeAngles[3];
	GetClientEyeAngles(iClient, fEyeAngles);

	if(g_iGroundTicks[iClient] < 5 && fVel[0] == 0.0 && fVel[1] == 0.0)
	{
		new Float:fPredictedDelta = fAngles[1] - fEyeAngles[1];

		if (fPredictedDelta > 180.0)
			fPredictedDelta -= 360.0;
		if (fPredictedDelta < -180.0)
			fPredictedDelta += 360.0;

		if (fPredictedDelta > 0.0)
		{
			fVel[1] = -450.0;
			return Plugin_Changed;
		}
		if (fPredictedDelta < 0.0)
		{
			fVel[1] = 450.0;
			return Plugin_Changed;
		}

	}
	return Plugin_Continue;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("auto_strafe");

	CreateNative("AutoStrafe_SetEnabled", _AutoStrafe_SetEnabled);
	CreateNative("AutoStrafe_IsEnabled", _AutoStrafe_IsEnabled);

	return APLRes_Success;
}

public _AutoStrafe_SetEnabled(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new bool:bEnabled = GetNativeCell(2);

	g_bActivated[iClient] = bEnabled;
}

public _AutoStrafe_IsEnabled(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);

	return _:g_bActivated[iClient];
}
