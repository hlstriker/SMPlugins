#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <hls_color_chat>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: CT Retake";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "Warday: CT Retake.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"CT Retake"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new Handle:cvar_ctretake_freeze_time;
new Handle:g_hTimer_GuardFreeze;
new Handle:g_hTimer_GuardInvincible;

new g_iTimerCountdownFreeze;
new g_FadeUserMsgId;

public OnPluginStart()
{
	CreateConVar("warday_ct_retake_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_ctretake_freeze_time = CreateConVar("ultjb_ctretake_invincible_time", "60", "The number of seconds the guards should be frozen while the prisoners scatter.", _, true, 1.0);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS, OnDayStart, OnDayEnd);
	UltJB_Day_SetFreezeTime(iDayID, 0);
}

public OnDayStart(iClient)
{
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(GetClientTeam(iPlayer) == TEAM_GUARDS)
		{
			FreezeClient(iPlayer);
			PerformBlind(iPlayer, 255);
			
			SDKHook(iPlayer, SDKHook_OnTakeDamage, CTInvuln);
		}
	}
	
	StartTimer_GuardFreeze();
	StartTimer_GuardInvincible();
}

public OnDayEnd(iClient)
{
	StopTimer_GuardFreeze();
	StopTimer_GuardInvincible();
}

StartTimer_GuardFreeze()
{
	g_iTimerCountdownFreeze = 0;
	ShowCountdown_Unfreeze();
	
	StopTimer_GuardFreeze();
	g_hTimer_GuardFreeze = CreateTimer(1.0, Timer_GuardFreeze, _, TIMER_REPEAT);
}

StopTimer_GuardFreeze()
{
	if(g_hTimer_GuardFreeze == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_GuardFreeze);
	g_hTimer_GuardFreeze = INVALID_HANDLE;
}

ShowCountdown_Unfreeze()
{
	PrintHintTextToAll("<font color='#6FC41A'>Unfreezing guards in:</font>\n<font color='#DE2626'>%i</font> <font color='#6FC41A'>seconds.</font>", GetConVarInt(cvar_ctretake_freeze_time) - g_iTimerCountdownFreeze);
}

StartTimer_GuardInvincible()
{
	StopTimer_GuardInvincible();
	g_hTimer_GuardInvincible = CreateTimer(70.0, Timer_GuardInvincible);
}

StopTimer_GuardInvincible()
{
	if(g_hTimer_GuardInvincible == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_GuardInvincible);
	g_hTimer_GuardInvincible = INVALID_HANDLE;
}

public Action:Timer_GuardFreeze(Handle:hTimer)
{
	g_iTimerCountdownFreeze++;
	
	if(g_iTimerCountdownFreeze == 5)
		CPrintToChatAll("{red}----------------------------------");
	
	if(g_iTimerCountdownFreeze == 5)
		CPrintToChatAll("{red}- {green}Guards are frozen for 60 seconds.");
		
	if(g_iTimerCountdownFreeze == 6)
		CPrintToChatAll("{red}- {green}Prisoners run around the map finding weapons.");
		
	if(g_iTimerCountdownFreeze == 7)
		CPrintToChatAll("{red}- {green}When guards are unfrozen, they have to retake the map from the Prisoners.");
		
	if(g_iTimerCountdownFreeze == 8)
		CPrintToChatAll("{red}- {green}Prisoners do not camp the Guards. Guards are invulnerable until it says so.");
		
	if(g_iTimerCountdownFreeze == 9)
		CPrintToChatAll("{red}----------------------------------");
	
	if(g_iTimerCountdownFreeze < GetConVarInt(cvar_ctretake_freeze_time))
	{
		ShowCountdown_Unfreeze();
		return Plugin_Continue;
	}
	
	g_hTimer_GuardFreeze = INVALID_HANDLE;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) == TEAM_GUARDS)
		{
			FreezeClient(iClient, false);
			PerformBlind(iClient, 0);
		}
	}
	
	PrintHintTextToAll("<font color='#6FC41A'>Guards have been unfrozen!</font>");
	
	GiveKnives();
	
	return Plugin_Stop;
}

public Action:Timer_GuardInvincible(Handle:hTimer)
{
	g_hTimer_GuardInvincible = INVALID_HANDLE;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) == TEAM_GUARDS)
			SDKUnhook(iClient, SDKHook_OnTakeDamage, CTInvuln);
	}
	
	PrintHintTextToAll("<font color='#6FC41A'>Guards are now vulnerable!</font>");
	
	return Plugin_Stop;
}

FreezeClient(iClient, bool:bFreeze=true)
{
	if(bFreeze)
	{
		SetEntityMoveType(iClient, MOVETYPE_NONE);
	}
	else
	{
		SetEntityMoveType(iClient, MOVETYPE_WALK);
	}
}

public Action:CTInvuln(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(1 <= iAttacker <= MaxClients))
		return Plugin_Continue;
	
	if((UltJB_LR_GetLastRequestFlags(iAttacker) & LR_FLAG_FREEDAY)
	|| (UltJB_LR_GetLastRequestFlags(iVictim) & LR_FLAG_FREEDAY))
		return Plugin_Continue;

	fDamage = 0.0;

	return Plugin_Changed;
}

PerformBlind(target, amount)
{
	new targets[2];
	targets[0] = target;
	
	new duration = 1536;
	new holdtime = 1536;
	new flags;
	if (amount == 0)
	{
		flags = (0x0001 | 0x0010);
	}
	else
	{
		flags = (0x0002 | 0x0008);
	}
	
	new color[4] = { 0, 0, 0, 0 };
	color[3] = amount;
	
	new Handle:message = StartMessageEx(GetUserMessageId("Fade"), targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	}
	else
	{
		BfWriteShort(message, duration);
		BfWriteShort(message, holdtime);
		BfWriteShort(message, flags);		
		BfWriteByte(message, color[0]);
		BfWriteByte(message, color[1]);
		BfWriteByte(message, color[2]);
		BfWriteByte(message, color[3]);
	}
	g_FadeUserMsgId++;
	EndMessage();
}

GiveKnives()
{
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(DoesClientHaveKnife(iClient))
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_GUARDS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			}
			case TEAM_PRISONERS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			}
		}
	}
}

bool:DoesClientHaveKnife(iClient)
{
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	new iOffset = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
	
	decl iEnt, String:szClassName[13];
	for(new i=0; i<iArraySize; i++)
	{
		iEnt = GetEntDataEnt2(iClient, iOffset + (i * 4));
		if(iEnt < 1)
			continue;
		
		if(!GetEntityClassname(iEnt, szClassName, sizeof(szClassName)))
			continue;
		
		szClassName[12] = '\x00';
		
		if(StrEqual(szClassName, "weapon_knife"))
			return true;
	}
	
	return false;
}