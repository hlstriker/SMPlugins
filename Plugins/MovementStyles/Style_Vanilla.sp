#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <cstrike>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Vanilla";
new const String:PLUGIN_VERSION[] = "1.0.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco (original by Danzay)",
	description = "Style: Vanilla Movement.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_VANILLA
#define THIS_STYLE_NAME			"Vanilla"
#define THIS_STYLE_ORDER		220

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_vanilla_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnAllPluginsLoaded()
{
	VNL_OnAllPluginsLoaded();
}

public OnConfigsExecuted()
{
	VNL_OnConfigsExecuted();
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER);
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_vnl");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_vanilla");
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

public OnClientPutInServer(iClient)
{
	VNL_OnClientPutInServer(iClient);
}

//
// GOKZ VANILLA MODE CODE
//

// The original Vanilla Mode plugin is created by Danzay
// https://bitbucket.org/kztimerglobalteam/gokz/src/master/addons/sourcemod/scripting/gokz-mode-vanilla.sp
// It is now modified to be a MovementStyles plugin by Hymns For Disco

enum _:CvarSetting
{
	String:Cvar_Name[255],
	Handle:Cvar_Handle,
	Float:Cvar_Value,
	Float:Cvar_PreviousValue
}

new g_eCvars[][CvarSetting] =
{
	{"sv_accelerate",INVALID_HANDLE, 5.5},
	{"sv_accelerate_use_weapon_speed", INVALID_HANDLE, 1.0},
	{"sv_airaccelerate", INVALID_HANDLE, 12.0},
	{"sv_air_max_wishspeed", INVALID_HANDLE, 30.0},
	{"sv_enablebunnyhopping", INVALID_HANDLE, 0.0},
	{"sv_friction", INVALID_HANDLE, 5.2},
	{"sv_gravity", INVALID_HANDLE, 800.0},
	{"sv_jump_impulse", INVALID_HANDLE, 301.993377},
	{"sv_ladder_scale_speed", INVALID_HANDLE, 0.78},
	{"sv_ledge_mantle_helper", INVALID_HANDLE, 1.0},
	{"sv_maxspeed", INVALID_HANDLE, 320.0},
	{"sv_maxvelocity", INVALID_HANDLE, 3500.0},
	{"sv_staminajumpcost", INVALID_HANDLE, 0.080},
	{"sv_staminalandcost", INVALID_HANDLE, 0.050},
	{"sv_staminamax", INVALID_HANDLE, 80.0},
	{"sv_staminarecoveryrate", INVALID_HANDLE, 60.0},
	{"sv_standable_normal", INVALID_HANDLE, 0.7},
	{"sv_timebetweenducks", INVALID_HANDLE, 0.4},
	{"sv_walkable_normal", INVALID_HANDLE, 0.7},
	{"sv_wateraccelerate", INVALID_HANDLE, 10.0},
	{"sv_water_movespeed_multiplier", INVALID_HANDLE, 0.8},
	{"sv_water_swim_mode", INVALID_HANDLE, 0.0},
	{"sv_weapon_encumbrance_per_item", INVALID_HANDLE, 0.85},
	{"sv_weapon_encumbrance_scale", INVALID_HANDLE, 0.0}
};

new g_bCvarsAreTweaked = false;

// =====[ PLUGIN EVENTS ]=====

VNL_OnConfigsExecuted()
{
	CreateConVars();
}

VNL_OnAllPluginsLoaded()
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

VNL_OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_PreThinkPost, SDKHook_OnClientPreThink_Post);
	SDKHook(client, SDKHook_PostThink, SDKHook_OnClientPostThink);
}

public SDKHook_OnClientPreThink_Post(client)
{
	if (g_bActivated[client])
	{
		TweakConVars();
	}
}

public SDKHook_OnClientPostThink(client)
{
	if (g_bCvarsAreTweaked)
	{
		ResetConVars();
	}
}


// =====[ CONVARS ]=====

CreateConVars()
{
	for (new i = 0; i < sizeof(g_eCvars); i++)
	{
		new Handle:hCvar = FindConVar(g_eCvars[i][Cvar_Name]);
		SetConVarFlags(hCvar, GetConVarFlags(hCvar) & ~FCVAR_REPLICATED & ~FCVAR_NOTIFY);
		g_eCvars[i][Cvar_Handle] = hCvar;
	}
}


//
// New convar handling
//

TweakConVars()
{
	if (g_bCvarsAreTweaked)
	{
		// This is just a sanity check to complain if anyone breaks the plugin in the future,
		// or there is some unexpected behaviour with the calling of SDKHooks or MovementStyle forwards.
		// There may be a better way to handle the convar tweaking.
		ResetConVars();
		SetFailState("BUG: Vanilla style tried to tweak convars twice in a row.");
	}
	
	for (new i = 0; i < sizeof(g_eCvars); i++)
	{
		g_eCvars[i][Cvar_PreviousValue] = GetConVarFloat(g_eCvars[i][Cvar_Handle]);
		/* PrintToServer("prev %s = %f", g_eCvars[i][Cvar_Name], g_eCvars[i][Cvar_PreviousValue]); */
		SetConVarFloat(g_eCvars[i][Cvar_Handle], g_eCvars[i][Cvar_Value], false, false);
	}
	g_bCvarsAreTweaked = true;
}

ResetConVars()
{
	if (!g_bCvarsAreTweaked)
	{
		// This is just a sanity check to complain if anyone breaks the plugin in the future,
		// or there is some unexpected behaviour with the calling of SDKHooks or MovementStyle forwards.
		// There may be a better way to handle the convar tweaking.
		ResetConVars();
		SetFailState("BUG: Vanilla style tried to reset convars twice in a row.");
	}
	
	for (new i = 0; i < sizeof(g_eCvars); i++)
	{
		SetConVarFloat(g_eCvars[i][Cvar_Handle], g_eCvars[i][Cvar_PreviousValue], false, false);
	}
	
	g_bCvarsAreTweaked = false;
}
