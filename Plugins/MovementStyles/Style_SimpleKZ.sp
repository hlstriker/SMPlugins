#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <cstrike>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: SimpleKZ";
new const String:PLUGIN_VERSION[] = "1.0.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco (original by Danzay, modified by Brock)",
	description = "Style: SimpleKZ.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_SIMPLE_KZ
#define THIS_STYLE_NAME			"SimpleKZ"
#define THIS_STYLE_ORDER		210

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_simplekz_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);

	SKZ_OnPluginStart();
}

public OnAllPluginsLoaded() {
	SKZ_OnAllPluginsLoaded();
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER);
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_skz");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_simplekz");
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

public OnClientPutInServer(iClient) {
	SKZ_OnClientPutInServer(iClient);
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	return SKZ_OnPlayerRunCmd(iClient, iButtons, iImpulse, fVelocity, fAngles, iWeapon, iSubType, iCmdNum, iTickCount, iSeed, iMouse);
}

//
// SIMPLE KZ CODE
//

// The original SimpleKZ plugin is created by Danzay
// https://bitbucket.org/kztimerglobalteam/gokz/src/master/addons/sourcemod/scripting/gokz-mode-simplekz.sp
// It was modified into a standalone version by Brock
// It is now modified to be a MovementStyles plugin by Hymns For Disco
// The changes are mostly to make compatible with the sourcemod 1.6 compiler, and work with the MovementStyles system
// including refactoring method maps and updating syntax.
// There has not been an effort to re-style the code to be consistent with the SMPlugins codebase.

#include "SKZIncludes/movementapi"

#undef REQUIRE_PLUGIN
#include "SKZIncludes/movementhud"
#define REQUIRE_PLUGIN

#define EPSILON 0.000001

#define PERF_TICKS 4
#define SPEED_NORMAL 250.0

new Float:gF_PSVelMod[MAXPLAYERS + 1];
new Float:gF_PSVelModLanding[MAXPLAYERS + 1];
new gI_OldButtons[MAXPLAYERS + 1];
new gI_OldFlags[MAXPLAYERS + 1];
new bool:gB_OldOnGround[MAXPLAYERS + 1];
new Float:gF_OldOrigin[MAXPLAYERS + 1][3];
new Float:gF_OldAngles[MAXPLAYERS + 1][3];
new Float:gF_OldVelocity[MAXPLAYERS + 1][3];
new bool:gB_Jumpbugged[MAXPLAYERS + 1];



// =====[ PLUGIN EVENTS ]=====

SKZ_OnPluginStart()
{
	if (FloatAbs(1.0 / GetTickInterval() - 128.0) > EPSILON)
	{
		SetFailState("This mode only supports 128 tick.");
	}
}

SKZ_OnAllPluginsLoaded()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}



// =====[ CLIENT EVENTS ]=====

SKZ_OnClientPutInServer(client)
{	
	ResetClient(client);
}

public Action:SKZ_OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if (!g_bActivated[client])
	{
		return Plugin_Continue;
	}
	
	if (!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	// modified to not use MovementAPI method map
	//MovementAPIPlayer player = MovementAPIPlayer(client);
	// if (gB_Jumpbugged[player.ID])
	if (gB_Jumpbugged[client])
	{
		//TweakJumpbug(player);
		TweakJumpbug(client);
	}

	gB_Jumpbugged[client] = false;
	gI_OldButtons[client] = buttons;
	gI_OldFlags[client] = GetEntityFlags(client);
	//gB_OldOnGround[client] = player.OnGround;
	gB_OldOnGround[client] = Movement_GetOnGround(client);
	gF_OldAngles[client] = angles;
	//player.GetVelocity(gF_OldVelocity[client]);
	Movement_GetVelocity(client, gF_OldVelocity[client]);
	
	return Plugin_Continue;
}

public Movement_OnStartTouchGround(client)
{
	//MovementAPIPlayer player = MovementAPIPlayer(client);
	// replace player.ID with client
	gF_PSVelModLanding[client] = gF_PSVelMod[client];
}

public Movement_OnStopTouchGround(client, bool:jumped)
{
	if (!g_bActivated[client])
	{
		return;
	}
	
	//MovementAPIPlayer player = MovementAPIPlayer(client);
	if (jumped)
	{
		// replace player with client
		TweakJump(client);
	}
}

public Movement_OnPlayerJump(client, bool:jumpbug)
{
	if (jumpbug)
	{
		gB_Jumpbugged[client] = true;
	}
}



// =====[ GENERAL ]=====

ResetClient(client)
{
	//MovementAPIPlayer player = MovementAPIPlayer(client);
	// replace player with client
	ResetVelMod(client);
}



// =====[ VELOCITY MODIFIER ]=====

ResetVelMod(client)
{
	gF_PSVelMod[client] = 1.0;
}


// =====[ JUMPING ]=====

TweakJump(client)
{
	new TakeoffCmdNum = Movement_GetTakeoffCmdNum(client);
	new LandingCmdNum = Movement_GetLandingCmdNum(client);
	//cmdsSinceLanding = player.TakeoffCmdNum - player.LandingCmdNum;
	new cmdsSinceLanding = TakeoffCmdNum - LandingCmdNum;
	
	if (cmdsSinceLanding <= PERF_TICKS)
	{
		if (cmdsSinceLanding == 1)
		{
			NerfRealPerf(client);
		}
		
		new Float:TakeoffSpeed = Movement_GetTakeoffSpeed(client);
		if (cmdsSinceLanding > 1 || TakeoffSpeed > SPEED_NORMAL)
		{
			ApplyTweakedTakeoffSpeed(client);
		}
	}
}

NerfRealPerf(client)
{
	new Float:VerticalVelocity = Movement_GetVerticalVelocity(client);
	
	// Not worth worrying about if player is already falling
	//if (player.VerticalVelocity < EPSILON)
	if (VerticalVelocity < EPSILON)
	{
		return;
	}
	
	// Work out where the ground was when they bunnyhopped
	new Float:startPosition[3], Float:endPosition[3], Float:mins[3], Float:maxs[3], Float:groundOrigin[3];
	
	startPosition = gF_OldOrigin[client];
	
	endPosition = startPosition;
	endPosition[2] = endPosition[2] - 2.0; // Should be less than 2.0 units away
	
	GetEntPropVector(client, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", maxs);
	
	new Handle:trace = TR_TraceHullFilterEx(
		startPosition, 
		endPosition, 
		mins, 
		maxs, 
		MASK_PLAYERSOLID, 
		TraceEntityFilterPlayers, 
		client);
	
	// This is expected to always hit
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(groundOrigin, trace);
		
		// Teleport player downwards so it's like they jumped from the ground
		new Float:newOrigin[3];
		//player.GetOrigin(newOrigin);
		Movement_GetOrigin(client, newOrigin);
		newOrigin[2] -= gF_OldOrigin[client][2] - groundOrigin[2];
		
		SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", newOrigin);
	}
	
	CloseHandle(trace);
}

ApplyTweakedTakeoffSpeed(client)
{
	// Note that resulting velocity has same direction as landing velocity, not current velocity
	new Float:velocity[3], Float:baseVelocity[3], Float:newVelocity[3];
	//player.GetVelocity(velocity);
	Movement_GetVelocity(client, velocity);
	//player.GetBaseVelocity(baseVelocity);
	Movement_GetBaseVelocity(client, baseVelocity);
	//player.GetLandingVelocity(newVelocity);
	Movement_GetLandingVelocity(client, newVelocity);
	
	newVelocity[2] = velocity[2];
	SetVectorHorizontalLength(newVelocity, CalcTweakedTakeoffSpeed(client));
	AddVectors(newVelocity, baseVelocity, newVelocity);
	
	//player.SetVelocity(newVelocity);
	Movement_SetVelocity(client, newVelocity);
}

TweakJumpbug(client)
{
	// modified to not use MovementAPI method map
	//if (player.Speed > SPEED_NORMAL)
	new Float:speed = Movement_GetSpeed(client);
	if (speed > SPEED_NORMAL)
	{
		// replace player.ID with client
		Movement_SetSpeed(client, CalcTweakedTakeoffSpeed(client, true), true);
	}
}

// Takeoff speed assuming player has met the conditions to need tweaking
Float:CalcTweakedTakeoffSpeed(client, bool:jumpbug = false)
{
	// Formula
	if (jumpbug)
	{
		//return FloatMin(player.Speed, (0.2 * player.Speed + 200) * gF_PSVelMod[player.ID]);
		return FloatMin(Movement_GetSpeed(client), (0.2 * Movement_GetSpeed(client) + 200) * gF_PSVelMod[client]);
	}
	//else if (player.LandingSpeed > SPEED_NORMAL)
	else if (Movement_GetLandingSpeed(client) > SPEED_NORMAL)
	{
		//return FloatMin(player.LandingSpeed, (0.2 * player.LandingSpeed + 200) * gF_PSVelModLanding[player.ID]);
		return FloatMin(Movement_GetLandingSpeed(client), (0.2 * Movement_GetLandingSpeed(client) + 200) * gF_PSVelModLanding[client]);
	}
	return Movement_GetLandingSpeed(client);
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return entity != data && !(0 < entity <= MaxClients);
}



// gokz.inc stuff

/**
 * Returns the lesser of two Float:values.
 *
 * @param value1		First value.
 * @param value2		Second value.
 * @return				Lesser value.
 */
Float:FloatMin(Float:value1, Float:value2)
{
	if (value1 <= value2)
	{
		return value1;
	}
	return value2;
}


//
// MovementHUD display correction
//
// Not part of the original SKZ standalone plugin

public MHud_Movement_OnTakeoff(iClient, bool:bDidJump, &bool:bDidPerf, &Float:fTakeoffSpeed)
{
	if (g_bActivated[iClient])
	{
		bDidPerf = MHud_Movement_GetGroundTicks(iClient) <= PERF_TICKS;
	}
	else
	{
		bDidPerf = MHud_Movement_GetGroundTicks(iClient) <= 1;
	}
	
	fTakeoffSpeed = MHud_Movement_GetCurrentSpeed(iClient);
}
