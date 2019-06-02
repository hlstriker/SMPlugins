#include <sourcemod>
#include <sdktools_functions>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Backwards";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Style: Backwards",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new bool:g_bActivated[MAXPLAYERS+1];
new bool:g_bGrounded[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_backwards_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(STYLE_BIT_BACKWARDS, "Backwards", OnActivated, OnDeactivated, 56);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(!g_bActivated[iClient])
		return Plugin_Continue;
	
	if(!IsPlayerAlive(iClient))
		return Plugin_Continue;

	new bool:bNewGrounded = false;
	if (GetEntityFlags(iClient) & FL_ONGROUND) bNewGrounded = true;
	
	if(g_bGrounded[iClient] && bNewGrounded) return Plugin_Continue;


	g_bGrounded[iClient] = bNewGrounded;

	decl Float:fRealVel[3], Float:fRealAngles[3];

	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fRealVel);

	if (fRealVel[0]*fRealVel[0] + fRealVel[1]*fRealVel[1] < 1225.0) return Plugin_Continue; // 1225 = 35 ^ 2

	new Float:fMoveAngle = RadToDeg(ArcTangent2(fRealVel[1], fRealVel[0]));

	GetClientEyeAngles(iClient, fRealAngles);

	new Float:fDiff = FloatAbs(fRealAngles[1] - fMoveAngle);
	if (fDiff > 180.0) fDiff = 360.0 - fDiff;

	if (fDiff < 100.0)
	{
		fVel[0] = 0.0;
		fVel[1] = 0.0;
		fVel[2] = 0.0;
	}
	
	return Plugin_Changed;
}