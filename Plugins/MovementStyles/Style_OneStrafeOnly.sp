#include <sourcemod>
#include <sdktools_functions>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: One Strafe Only";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Style: One Strafe Only",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_ONE_STRAFE_ONLY
#define THIS_STYLE_NAME			"A only / D only"
#define THIS_STYLE_NAME_AUTO	"A only / D only + Auto Bhop"
#define THIS_STYLE_ORDER		66

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

new bool:g_bActivated[MAXPLAYERS+1];
new bool:g_bGrounded[MAXPLAYERS+1];
new g_iStrafeChoice[MAXPLAYERS+1];



public OnPluginStart()
{
	CreateConVar("style_one_strafe_only_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);

	cvar_add_autobhop = CreateConVar("style_one_strafe_only_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_one_strafe_only_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
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
	g_iStrafeChoice[iClient] = 0;
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
}

public MovementStyles_OnSpawnPostForwardsSent(iClient)
{
	if(!g_bActivated[iClient])
		return;

	g_iStrafeChoice[iClient] = 0;
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

	fVel[0] = 0.0;

	if (!g_iStrafeChoice[iClient])
	{
		if (fVel[1] > 0) g_iStrafeChoice[iClient] = 1;
		else if (fVel[1] < 0) g_iStrafeChoice[iClient] = -1;
		return Plugin_Changed;
	}

	if ((g_iStrafeChoice[iClient] == 1 && fVel[1] < 0.0) || (g_iStrafeChoice[iClient] == -1 && fVel[1] > 0.0))
	{
		fVel[1] = 0.0;
	}

	return Plugin_Changed;
}
