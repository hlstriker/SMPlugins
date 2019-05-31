#include <sourcemod>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Classic";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Classic.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Classic"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new g_iEffectSelectedID;
new g_iEffectSelectTimeAndFreezeTime;


public OnPluginStart()
{
	CreateConVar("warday_classic_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO, OnDayStart, OnDayEnd, OnFreezeEnd);
	SetEffectSelectTimeAndFreezeTime(iDayID);
}

SetEffectSelectTimeAndFreezeTime(iDayID)
{
	g_iEffectSelectTimeAndFreezeTime = -1;
	new iEffectSelectTime = -1;
	new iDayFreezeTime = -1;
	
	new Handle:hConvar = FindConVar("ultjb_select_effect_time");
	if(hConvar != INVALID_HANDLE)
		iEffectSelectTime = GetConVarInt(hConvar);
	
	hConvar = FindConVar("ultjb_warday_freeze_time");
	if(hConvar != INVALID_HANDLE)
		iDayFreezeTime = GetConVarInt(hConvar);
	
	// Use the highest of the 2 values.
	if(iEffectSelectTime >= iDayFreezeTime)
		g_iEffectSelectTimeAndFreezeTime = iEffectSelectTime;
	else
		g_iEffectSelectTimeAndFreezeTime = iDayFreezeTime;
	
	// Neither cvar was found. Use whatever time.
	if(g_iEffectSelectTimeAndFreezeTime == -1)
		g_iEffectSelectTimeAndFreezeTime = 10;
	
	UltJB_Day_SetFreezeTime(iDayID, g_iEffectSelectTimeAndFreezeTime);
}

public OnDayStart(iClient)
{
	UltJB_Effects_DisplaySelectionMenu(iClient, OnEffectSelected_Success, OnEffectSelected_Failed, g_iEffectSelectTimeAndFreezeTime);
}

public OnEffectSelected_Success(iClient, iEffectID)
{
	g_iEffectSelectedID = iEffectID;
}

public OnEffectSelected_Failed(iClient)
{
	PrintToChat(iClient, "[SM] Proceeding without an effect.");
	g_iEffectSelectedID = 0;
}

public OnDayEnd(iClient)
{
	SetEffectOnClients(false);
}

SetEffectOnClients(bool:bStart=true)
{
	if(!g_iEffectSelectedID)
		return;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(bStart)
		{
			if(IsPlayerAlive(iClient))
				UltJB_Effects_StartEffect(iClient, g_iEffectSelectedID, UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID));
		}
		else
		{
			UltJB_Effects_StopEffect(iClient, g_iEffectSelectedID);
		}
	}
}

public OnFreezeEnd()
{
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_PRISONERS:
			{
				iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			}
		}
	}
	
	SetEffectOnClients();
}