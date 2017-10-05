#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Freeze Tag";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Mark Steele & hlstriker",
	description = "Warday: Freeze Tag.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Freeze Tag"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new const g_iColorFrozen[] = {117, 202, 255, 255};

new Handle:cvar_freezetag_chances_before_death;
new Handle:cvar_freezetag_ct_knife_add;
new Handle:cvar_freezetag_freeze_time;
new Handle:cvar_freezetag_time;
new Handle:g_hTimer_GuardFreeze;
new Handle:g_hTimer_FreezeTag;
new Handle:g_hTimer_GiveKnives;
new g_iTimerCountdown;

new bool:g_bIsStarted;
new g_iFrozenCount[MAXPLAYERS+1];

new g_FadeUserMsgId;


public OnPluginStart()
{
	CreateConVar("warday_freeze_tag_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_freezetag_freeze_time = CreateConVar("ultjb_freezetag_freeze_time", "15", "The number of seconds the guards should be frozen while the prisoners scatter.", _, true, 1.0);
	cvar_freezetag_time = CreateConVar("ultjb_freezetag_time", "240", "The number of seconds the freeze tag lasts.", _, true, 1.0);
	cvar_freezetag_ct_knife_add = CreateConVar("ultjb_freezetag_ct_knife_add", "10", "The number of seconds to add to the clock when a CT knives a T.", _, true, 0.0);
	cvar_freezetag_chances_before_death = CreateConVar("ultjb_chances_before_death", "2", "The number of chances a prisoner gets before they are killed.", _, true, 0.0);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_GUARDS_WEAPONS, OnDayStart, OnDayEnd);
	UltJB_Day_SetFreezeTime(iDayID, 0);
}

public OnDayStart(iClient)
{
	g_bIsStarted = true;
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		PlayerHooks(iPlayer);
		g_iFrozenCount[iPlayer] = 0;
		
		if(GetClientTeam(iPlayer) == TEAM_GUARDS) {
			FreezeClient(iPlayer);
			PerformBlind(iPlayer, 255);
		}
	}
	
	StartTimer_GuardFreeze();
}

public OnDayEnd(iClient)
{
	g_bIsStarted = false;
	
	UnhookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		PlayerUnhooks(iPlayer);
	}
	
	StopTimer_GiveKnives();
	StopTimer_GuardFreeze();
	StopTimer_FreezeTag();
}

public OnClientPutInServer(iClient)
{
	if(g_bIsStarted)
		PlayerHooks(iClient);
}

PlayerHooks(iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

PlayerUnhooks(iClient)
{
	SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(g_hTimer_FreezeTag == INVALID_HANDLE)
		return;
	
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(GetClientTeam(iVictim) == TEAM_PRISONERS && GetEntityMoveType(iVictim) != MOVETYPE_NONE)
		CalculatePrisonersRemaining();
}

public OnClientDisconnect(iClient)
{
	if(g_hTimer_FreezeTag == INVALID_HANDLE)
		return;
	
	if(GetClientTeam(iClient) == TEAM_PRISONERS && GetEntityMoveType(iClient) != MOVETYPE_NONE)
		CalculatePrisonersRemaining();
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(1 <= iAttacker <= MaxClients)
	{
		new iVictimsTeam = GetClientTeam(iVictim);
		new iAttackersTeam = GetClientTeam(iAttacker);
		
		// Go ahead and return if the attack or victim is in a freeday.
		if((UltJB_LR_GetLastRequestFlags(iAttacker) & LR_FLAG_FREEDAY)
		|| (UltJB_LR_GetLastRequestFlags(iVictim) & LR_FLAG_FREEDAY))
			return Plugin_Continue;
		
		if(iAttackersTeam == TEAM_PRISONERS)
		{
			if(iVictimsTeam == iAttackersTeam && GetEntityMoveType(iVictim) == MOVETYPE_NONE)
			{
				FreezeClient(iVictim, false);
				FreezeTag_CountdownHUD();
			}
			
			return Plugin_Handled;
		}
		
		if(iVictimsTeam != iAttackersTeam && GetEntityMoveType(iVictim) != MOVETYPE_NONE)
		{
			g_iFrozenCount[iVictim]++;
			FreezePrisoner(iVictim);
			
			if(g_iFrozenCount[iVictim] > GetConVarInt(cvar_freezetag_chances_before_death))
				ForcePlayerSuicide(iVictim);
		}
		
		return Plugin_Handled;
	}
	else if(iAttacker == 0)
	{
		if(GetEntityMoveType(iVictim) == MOVETYPE_NONE && (iDamageType & DMG_DROWN))
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

FreezePrisoner(iClient)
{
	g_iTimerCountdown -= GetConVarInt(cvar_freezetag_ct_knife_add);
	if(g_iTimerCountdown < 0)
		g_iTimerCountdown = 0;
	
	FreezeClient(iClient, true);
	CalculatePrisonersRemaining();
}

CalculatePrisonersRemaining()
{
	new iActivePrisoners;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS || (UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY))
			continue;
		
		if(GetEntityMoveType(iClient) != MOVETYPE_NONE)
			iActivePrisoners++;
	}
	
	if(!iActivePrisoners)
	{
		PrintHintTextToAll("<font color='#6FC41A'>Guards win!</font>");
		SlayTeam(TEAM_PRISONERS);
	}
	else
	{
		FreezeTag_CountdownHUD();
	}
}

FreezeClient(iClient, bool:bFreeze=true)
{
	if(bFreeze)
	{
		SetEntityMoveType(iClient, MOVETYPE_NONE);
		SetEntityRenderColor(iClient, g_iColorFrozen[0], g_iColorFrozen[1], g_iColorFrozen[2], g_iColorFrozen[3]);
		
		if(GetClientTeam(iClient) == TEAM_PRISONERS)
			SetEntProp(iClient, Prop_Send, "m_nSkin", 1);
	}
	else
	{
		SetEntityMoveType(iClient, MOVETYPE_WALK);
		SetEntityRenderColor(iClient);
		
		if(GetClientTeam(iClient) == TEAM_PRISONERS)
			SetEntProp(iClient, Prop_Send, "m_nSkin", 0);
	}	
}

StartTimer_GuardFreeze()
{
	g_iTimerCountdown = 0;
	ShowCountdown_Unfreeze();
	
	StopTimer_GuardFreeze();
	g_hTimer_GuardFreeze = CreateTimer(1.0, Timer_GuardFreeze, _, TIMER_REPEAT);
}

ShowCountdown_Unfreeze()
{
	PrintHintTextToAll("<font color='#6FC41A'>Unfreezing guards in:</font>\n<font color='#DE2626'>%i</font> <font color='#6FC41A'>seconds.</font>", GetConVarInt(cvar_freezetag_freeze_time) - g_iTimerCountdown);
}

StopTimer_GuardFreeze()
{
	if(g_hTimer_GuardFreeze == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_GuardFreeze);
	g_hTimer_GuardFreeze = INVALID_HANDLE;
}

public Action:Timer_GuardFreeze(Handle:hTimer)
{
	g_iTimerCountdown++;
	if(g_iTimerCountdown < GetConVarInt(cvar_freezetag_freeze_time))
	{
		ShowCountdown_Unfreeze();
		return Plugin_Continue;
	}
	
	g_hTimer_GuardFreeze = INVALID_HANDLE;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) == TEAM_GUARDS) {
			FreezeClient(iClient, false);
			PerformBlind(iClient, 0);
		}
	}
	
	PrintHintTextToAll("<font color='#6FC41A'>Guards have been unfrozen!</font>");
	StartTimer_FreezeTag();
	
	GiveKnives();
	StartTimer_GiveKnives();
	
	return Plugin_Stop;
}

StartTimer_GiveKnives()
{
	StopTimer_GiveKnives();
	g_hTimer_GiveKnives = CreateTimer(3.0, Timer_GiveKnives, _, TIMER_REPEAT);
}

StopTimer_GiveKnives()
{
	if(g_hTimer_GiveKnives == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_GiveKnives);
	g_hTimer_GiveKnives = INVALID_HANDLE;
}

StartTimer_FreezeTag()
{
	g_iTimerCountdown = 0;
	FreezeTag_CountdownHUD();
	
	StopTimer_FreezeTag();
	g_hTimer_FreezeTag = CreateTimer(1.0, Timer_FreezeTag, _, TIMER_REPEAT);
}

FreezeTag_CountdownHUD()
{
	new iTimeLeft = GetConVarInt(cvar_freezetag_time) - g_iTimerCountdown;
	new iMinutes = RoundToFloor(iTimeLeft / 60.0);
	new iSeconds = iTimeLeft % 60;
	
	new iActivePrisoners, iAlivePrisoners;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS || (UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY))
			continue;
		
		iAlivePrisoners++;
		
		if(GetEntityMoveType(iClient) != MOVETYPE_NONE)
			iActivePrisoners++;
	}
	
	if(!iActivePrisoners) // <--- testing fix for not slaying on DC/kick
		SlayTeam(TEAM_PRISONERS);
	
	PrintHintTextToAll("<font color='#6FC41A'>Time remaining: </font><font color='#DE2626'>%02i:%02i</font>\n<font color='#6FC41A'>Active prisoners: </font><font color='#DE2626'>%i / %i</font>", iMinutes, iSeconds, iActivePrisoners, iAlivePrisoners);
}

StopTimer_FreezeTag()
{
	if(g_hTimer_FreezeTag == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_FreezeTag);
	g_hTimer_FreezeTag = INVALID_HANDLE;
}

public Action:Timer_FreezeTag(Handle:hTimer)
{
	g_iTimerCountdown++;
	if(g_iTimerCountdown < GetConVarInt(cvar_freezetag_time))
	{
		FreezeTag_CountdownHUD();
		return Plugin_Continue;
	}
	
	g_hTimer_FreezeTag = INVALID_HANDLE;
	
	PrintHintTextToAll("<font color='#6FC41A'>Prisoners win!</font>");
	SlayTeam(TEAM_GUARDS);
	
	return Plugin_Stop;
}

SlayTeam(iTeam)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(GetClientTeam(iClient) != iTeam)
			continue;
		
		ForcePlayerSuicide(iClient);
	}
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

public Action:Timer_GiveKnives(Handle:hTimer)
{
	GiveKnives();
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