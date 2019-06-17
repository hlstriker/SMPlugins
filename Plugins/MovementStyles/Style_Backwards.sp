#include <sourcemod>
#include <sdktools_functions>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Backwards";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Style: Backwards",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_BACKWARDS
#define THIS_STYLE_NAME			"Backwards"
#define THIS_STYLE_NAME_AUTO	"Backwards + Auto Bhop"
#define THIS_STYLE_ORDER		56

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

new bool:g_bActivated[MAXPLAYERS+1];
new bool:g_bGrounded[MAXPLAYERS+1];



public OnPluginStart()
{
	CreateConVar("style_backwards_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_add_autobhop = CreateConVar("style_backwards_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_backwards_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_backwards");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_bw");
}

public MovementStyles_OnRegisterMultiReady()
{
	if(GetConVarBool(cvar_add_autobhop) && !GetConVarBool(cvar_force_autobhop))
		MovementStyles_RegisterMultiStyle(THIS_STYLE_BIT | STYLE_BIT_AUTO_BHOP, THIS_STYLE_NAME_AUTO, THIS_STYLE_ORDER + 1);
}

public MovementStyles_OnBitsChanged(iClient, iOldBits, &iNewBits)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(iNewBits != THIS_STYLE_BIT)
		return;
	
	iNewBits = TryForceAutoBhopBits(iNewBits);
}

public Action:MovementStyles_OnMenuBitsChanged(iClient, iBitsBeingToggled, bool:bBeingToggledOn, &iExtraBitsToForceOn)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(!bBeingToggledOn || iBitsBeingToggled != THIS_STYLE_BIT)
		return;
	
	iExtraBitsToForceOn = TryForceAutoBhopBits(iExtraBitsToForceOn);
}

TryForceAutoBhopBits(iBits)
{
	if(!GetConVarBool(cvar_force_autobhop))
		return iBits;
	
	return (iBits | STYLE_BIT_AUTO_BHOP);
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