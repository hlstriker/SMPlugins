#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entoutput>
#include "Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Ultimate Jailbreak: Damage Tracker";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The damage tracker plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fNextDamageMessage[MAXPLAYERS+1];
new bool:g_bIsAdmin[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("ultjb_damage_tracker_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("player_hurt", EventPlayerHurt_Post, EventHookMode_Post);
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	HookEvent("round_start", EventRoundStart_Post, EventHookMode_PostNoCopy);
	
	SetupConVars();
	
	HookEntityOutput("func_button", "OnIn", OnButtonIn);
	HookEntityOutput("func_rot_button", "OnIn", OnButtonIn);
}

SetupConVars()
{
	new Handle:hConvar = FindConVar("sv_damage_print_enable");
	if(hConvar == INVALID_HANDLE)
		return;
	
	HookConVarChange(hConvar, OnConVarChanged);
	SetConVarBool(hConvar, false);
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarBool(hConvar, false);
}

public OnMapStart()
{
	FindEntitiesToHook();
}

public EventRoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	FindEntitiesToHook();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		PrintToConsole(iClient, "\n---------------------\n+ NEW ROUND STARTED +\n---------------------\n");
	}
}

FindEntitiesToHook()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_breakable")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamage);
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_button")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamageButton);
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_rot_button")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamageButton);
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "momentary_rot_button")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamageButton);
}

public OnButtonIn(const String:szOutput[], iCaller, iActivator, Float:fDelay)
{
	if(!(1 <= iActivator <= MaxClients))
	{
		if(iActivator < 0)
			return;
		
		iActivator = GetEntPropEnt(iActivator, Prop_Data, "m_hOwnerEntity");
		if(!(1 <= iActivator <= MaxClients))
			return;
	}
	
	static String:szClientName[MAX_NAME_LENGTH];
	if(GetClientTeam(iActivator) == TEAM_PRISONERS)
	{
		strcopy(szClientName, sizeof(szClientName), "A prisoner");
		return; // We should actually just return here so guards can't cheat to determine where a prisoner is going based on button presses.
	}
	else
	{
		GetClientName(iActivator, szClientName, sizeof(szClientName));
	}
	
	static String:szName[64];
	GetEntPropString(iCaller, Prop_Data, "m_iName", szName, sizeof(szName));
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!g_bIsAdmin[iClient] && !IsClientSourceTV(iClient))
			continue;
		
		PrintToConsole(iClient, "   +++   Button pressed by: %s - (%s)", szClientName, szName);
	}
}

public Action:OnTakeDamageButton(iVictim, &iAttacker, &iInflictor, &Float:fdamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3])
{
	if(1 <= iInflictor <= MaxClients)
		return Plugin_Continue;
	
	return Plugin_Stop;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fdamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3])
{
	static iOwner;
	if(1 <= iAttacker <= MaxClients)
	{
		if(iAttacker == iInflictor)
			iOwner = iAttacker;
		else
			iOwner = GetEntPropEnt(iInflictor, Prop_Data, "m_hOwnerEntity");
	}
	else
	{
		iOwner = GetEntPropEnt(iAttacker, Prop_Data, "m_hOwnerEntity");
	}
	
	if(!(1 <= iOwner <= MaxClients))
		return;
	
	if(GetClientTeam(iOwner) != TEAM_GUARDS)
		return;
	
	if(g_fNextDamageMessage[iOwner] > GetEngineTime())
		return;
	
	g_fNextDamageMessage[iOwner] = GetEngineTime() + 0.04;
	
	new iEnt;
	if(iWeapon != -1)
	{
		iEnt = iWeapon;
	}
	else
	{
		if(!(1 <= iInflictor <= MaxClients))
			iEnt = iInflictor;
		else if(!(1 <= iAttacker <= MaxClients))
			iEnt = iAttacker;
	}
	
	decl String:szWeapon[32];
	if(iEnt)
		GetEntityClassname(iEnt, szWeapon, sizeof(szWeapon));
	else
		strcopy(szWeapon, sizeof(szWeapon), "unknown weapon");
	
	static String:szName[64];
	GetEntPropString(iVictim, Prop_Data, "m_iName", szName, sizeof(szName));
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!g_bIsAdmin[iClient] && !IsClientSourceTV(iClient))
			continue;
		
		PrintToConsole(iClient, "   +++   Vent damaged by: %N using %s - (%s)", iOwner, szWeapon, szName);
	}
}

public OnClientConnected(iClient)
{
	g_bIsAdmin[iClient] = false;
}

public OnClientPostAdminCheck(iClient)
{
	if(CheckCommandAccess(iClient, "sm_say", ADMFLAG_CHAT, false))
		g_bIsAdmin[iClient] = true;
}

public EventPlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsPlayer(iVictim))
		return;
	
	decl String:szWeaponNameString[32], String:szVictimName[MAX_NAME_LENGTH+8], String:szAttackerName[MAX_NAME_LENGTH+8];
	
	if(iAttacker == iVictim)
	{
		GetClientName(iVictim, szAttackerName, sizeof(szAttackerName));
		Format(szAttackerName, sizeof(szAttackerName), "(%s) %s", (GetClientTeam(iVictim) == TEAM_GUARDS) ? "CT" : "T", szAttackerName);
		
		strcopy(szVictimName, sizeof(szVictimName), "themself");
		strcopy(szWeaponNameString, sizeof(szWeaponNameString), "From suicide");
	}
	else if(!IsPlayer(iAttacker))
	{
		GetClientName(iVictim, szAttackerName, sizeof(szAttackerName));
		Format(szAttackerName, sizeof(szAttackerName), "(%s) %s", (GetClientTeam(iVictim) == TEAM_GUARDS) ? "CT" : "T", szAttackerName);
		
		strcopy(szVictimName, sizeof(szVictimName), "themself");
		strcopy(szWeaponNameString, sizeof(szWeaponNameString), "From world damage");
	}
	else
	{
		GetClientName(iAttacker, szAttackerName, sizeof(szAttackerName));
		Format(szAttackerName, sizeof(szAttackerName), "(%s) %s", (GetClientTeam(iAttacker) == TEAM_GUARDS) ? "CT" : "T", szAttackerName);
		
		GetClientName(iVictim, szVictimName, sizeof(szVictimName));
		Format(szVictimName, sizeof(szVictimName), "(%s) %s", (GetClientTeam(iVictim) == TEAM_GUARDS) ? "CT" : "T", szVictimName);
		
		GetEventString(hEvent, "weapon", szWeaponNameString, sizeof(szWeaponNameString));
		Format(szWeaponNameString, sizeof(szWeaponNameString), "With weapon %s", szWeaponNameString);
	}
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		PrintToConsole(iClient, "   ---   \"%s\" killed \"%s\"  --  %s.", szAttackerName, szVictimName, szWeaponNameString);
	}
}

public EventPlayerHurt_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iAttacker == iVictim)
		return;
	
	if(!IsPlayer(iAttacker) || !IsPlayer(iVictim))
		return;
	
	if(GetClientTeam(iAttacker) == TEAM_PRISONERS)
		return;
	
	new iDamageHealth = GetEventInt(hEvent, "dmg_health");
	new iDamageArmor = GetEventInt(hEvent, "dmg_armor");
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		PrintToConsole(iClient, "   ---   %N damaged %N for %i Health and %i Armor.", iAttacker, iVictim, iDamageHealth, iDamageArmor);
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}