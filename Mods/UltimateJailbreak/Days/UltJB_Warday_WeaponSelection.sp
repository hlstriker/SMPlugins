#include <sourcemod>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_logger"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Weapon Selection";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Weapon Selection.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Weapon Selection"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new g_iWeaponSelectedID;

new bool:g_bEventHooked_TaserShot;


public OnPluginStart()
{
	CreateConVar("warday_weapon_selection_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO | DAY_FLAG_KILL_WORLD_WEAPONS, OnDayStart, OnDayEnd, OnFreezeEnd);
	UltJB_Day_AllowFreeForAll(iDayID, true);
}

public OnDayStart(iClient)
{
	g_iWeaponSelectedID = _:CSWeapon_NEGEV;
	
	new iFlags[NUM_WPN_CATS];
	iFlags[WPN_CAT_KNIFE] = WPN_FLAGS_DISABLE_KNIFE_KNIFE | WPN_FLAGS_DISABLE_KNIFE_TASER;
	UltJB_Weapons_DisplaySelectionMenu(iClient, OnWeaponSelected_Success, OnWeaponSelected_Failed, iFlags);
}

public OnWeaponSelected_Success(iClient, iWeaponID, const iFlags[NUM_WPN_CATS])
{
	g_iWeaponSelectedID = iWeaponID;
	
	new String:szName[64];
	UltJB_Weapons_GetEntNameFromWeaponID(iWeaponID, szName, sizeof(szName));
	
	decl String:szMessage[128];
	FormatEx(szMessage, sizeof(szMessage), "%N selected weapon %s.", iClient, szName);
	UltJB_Logger_LogEvent(szMessage, iClient, 0, LOGTYPE_ANY);
	
	//if(iWeaponID == _:CSWeapon_TASER)
	//	g_bEventHooked_TaserShot = HookEventEx("weapon_fire", Event_TaserShot);
}

public OnWeaponSelected_Failed(iClient, const iFlags[NUM_WPN_CATS])
{
	//
}

public OnDayEnd(iClient)
{
	UltJB_Weapons_CancelWeaponSelection(iClient);
	
	if(g_bEventHooked_TaserShot)
	{
		UnhookEvent("weapon_fire", Event_TaserShot);
		g_bEventHooked_TaserShot = false;
	}
}

public Event_TaserShot(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!iClient)
		return;
	
	if(GetClientTeam(iClient) != TEAM_GUARDS)
		return;
	
	new iTaser = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(!IsValidEdict(iTaser))
		return;
	
	decl String:szClassName[13];
	if(!GetEntityClassname(iTaser, szClassName, sizeof(szClassName)))
		return;
	
	if(!StrEqual("weapon_taser", szClassName))
		return;
	
	SetEntProp(iTaser, Prop_Send, "m_iClip1", 2);
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", GetGameTime() + 0.5);
}

public OnFreezeEnd()
{
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, g_iWeaponSelectedID);
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_GUARDS: UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
			case TEAM_PRISONERS: UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
		}
	}
}