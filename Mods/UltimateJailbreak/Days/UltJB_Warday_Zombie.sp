#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entoutput>
#include <sdktools_entinput>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Zombie";
new const String:PLUGIN_VERSION[] = "1.3";

new g_ZombieMsg;

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "Warday: Zombie.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Zombie"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

#define ZOMBIE_SPEED	0.7
#define ZOMBIE_SPEEDCAP	1.2

new Handle:g_hTimer_ZombieMsg;
new Handle:g_hTimer_ZombieSpeed;

new Float:g_fSpeed = ZOMBIE_SPEED;

public OnPluginStart()
{
	CreateConVar("warday_zombie_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO | DAY_FLAG_KILL_WEAPON_EQUIPS, OnDayStart, OnDayEnd, OnFreezeEnd);
}

public OnDayStart(iClient)
{
	CPrintToChatAll("{red}[{green}Zombie Warday{red}]{default}: Prisoners have been infected.");

	g_ZombieMsg = 0;
	StartTimer_ZombieMsg();
	StartTimer_ZombieSpeed();
}

public OnDayEnd(iClient)
{
	ResetSpeed();
	UnhookPlayers();
	StopTimer_ZombieMsg();
	StopTimer_ZombieSpeed();
}

ResetSpeed()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", 1.0);
	}
}

StartTimer_ZombieMsg()
{
	StopTimer_ZombieMsg();
	g_hTimer_ZombieMsg = CreateTimer(1.0, ZombieMessage, _, TIMER_REPEAT);
}

StopTimer_ZombieMsg()
{
	if(g_hTimer_ZombieMsg == INVALID_HANDLE)
		return;

	KillTimer(g_hTimer_ZombieMsg);
	g_hTimer_ZombieMsg = INVALID_HANDLE;
}

StartTimer_ZombieSpeed()
{
	g_fSpeed = ZOMBIE_SPEED;
	StopTimer_ZombieSpeed();
	g_hTimer_ZombieSpeed = CreateTimer(90.0, ZombieSpeed, _, TIMER_REPEAT);
}

StopTimer_ZombieSpeed()
{
	if(g_hTimer_ZombieSpeed == INVALID_HANDLE)
		return;

	KillTimer(g_hTimer_ZombieSpeed);
	g_hTimer_ZombieSpeed = INVALID_HANDLE;
}

public Action:ZombieMessage(Handle:hTimer)
{
	g_ZombieMsg++;
	
	if(g_ZombieMsg >= 3)
	{
		g_hTimer_ZombieMsg = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	switch(g_ZombieMsg)
	{
		case 1: CPrintToChatAll("{red}[{green}Zombie Warday{red}]{default}: Zombies can only be killed by headshots.");
		case 2: CPrintToChatAll("{red}[{green}Zombie Warday{red}]{default}: Knifing a guard will kill them.");
	}
	
	return Plugin_Continue;
}

public Action:ZombieSpeed(Handle:hTimer)
{
	g_fSpeed += 0.15;
	
	if(g_fSpeed > ZOMBIE_SPEEDCAP)
		g_fSpeed = ZOMBIE_SPEEDCAP;
	
	CPrintToChatAll("{red}[{green}Zombie Warday{red}]{default}: {red}The remaining zombies are getting hungry.");
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) !=  TEAM_PRISONERS)
			continue;
		
		SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", g_fSpeed);
	}
}

public OnFreezeEnd()
{
	HookPlayers(); 
	PrepareClients();
	//KillTeleporters();
}

HookPlayers()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SDKHook(iClient, SDKHook_TraceAttack, OnTraceAttack);
	}
}

UnhookPlayers()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SDKUnhook(iClient, SDKHook_TraceAttack, OnTraceAttack);
	}
}

PrepareClients()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_GUARDS: 
			{
				UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
				UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_DEAGLE);
			}
			case TEAM_PRISONERS:
			{
				UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
				SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", ZOMBIE_SPEED);
			}
		}
	}
}

public Action:OnTraceAttack(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType, &iAmmoType, iHitBox, iHitGroup)
{
	if(!(1 <= iVictim <= MaxClients) || !(1 <= iAttacker <= MaxClients))
		return Plugin_Continue;
	
	switch(GetClientTeam(iVictim))
	{
		case TEAM_GUARDS:
		{
			new iWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
			if(iWeapon == -1)
				return Plugin_Continue;
			
			decl String:szWeapon[13];
			GetEntityClassname(iWeapon, szWeapon, sizeof(szWeapon));
			szWeapon[12] = 0x00;
			
			if(StrEqual(szWeapon, "weapon_knife"))
				fDamage = 250.0;
			else
				fDamage = 0.0;
			
			return Plugin_Changed;
		}
		case TEAM_PRISONERS:
		{
			new iWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
			if(iWeapon == -1)
				return Plugin_Continue;
			
			decl String:szWeapon[13];
			GetEntityClassname(iWeapon, szWeapon, sizeof(szWeapon));
			szWeapon[12] = 0x00;
			
			if(iHitGroup == 1)
				fDamage = 250.0;
			else if(!StrEqual(szWeapon, "weapon_knife"))
				fDamage = 0.0;
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

/*KillTeleporters()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_teleport")) != -1)
	{
		AcceptEntityInput(iEnt, "Kill");
	}
}*/