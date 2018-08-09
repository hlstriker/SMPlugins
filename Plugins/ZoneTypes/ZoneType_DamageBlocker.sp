#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include "../../Libraries/ZoneManager/zone_manager"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type: Damage Blocker";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "A zone type that blocks different forms of damage.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:g_szDamageTypeNames[][] =
{
	"None",
	"Fall",
	"Drown",
	"Crush"
};

new const g_iDamageTypeBits[] =
{
	DMG_GENERIC,
	DMG_FALL,
	DMG_DROWN,
	DMG_CRUSH
};

new g_iEditingZoneID[MAXPLAYERS+1];
new g_iCombinedBits[MAXPLAYERS+1];

new const String:SZ_ZONE_TYPE_NAME[] = "Damage Blocker";


public OnPluginStart()
{
	CreateConVar("zone_type_damageblocker_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", EventRoundStart_Post, EventHookMode_PostNoCopy);
}

public ZoneManager_OnRegisterReady()
{
	ZoneManager_RegisterZoneType(ZONE_TYPE_DAMAGEBLOCKER, SZ_ZONE_TYPE_NAME, _, OnStartTouch, OnEndTouch, OnEditData);
}

public OnClientConnected(iClient)
{
	g_iCombinedBits[iClient] = 0;
}

public Action:EventRoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;
		
		g_iCombinedBits[iClient] = 0;
	}
}

public OnStartTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	if(!IsPlayerAlive(iOther))
		return;
		
	g_iCombinedBits[iOther] |= ZoneManager_GetDataInt(GetZoneID(iZone), 1);
	
	SDKHook(iOther, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnEndTouch(iZone, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	if(!IsPlayerAlive(iOther))
		return;
		
	g_iCombinedBits[iOther] = 0;
	
	SDKUnhook(iOther, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnEditData(iClient, iZoneID)
{
	DisplayMenu_EditData(iClient, iZoneID);
}

DisplayMenu_EditData(iClient, iZoneID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, "Edit damage types");
	
	decl String:szInfo[6], String:szBuffer[64];
	
	for(new i=0; i<sizeof(g_szDamageTypeNames); i++)
	{
		IntToString(i, szInfo, sizeof(szInfo));
		Format(szBuffer, sizeof(szBuffer), "%s%s", (ZoneManager_GetDataInt(iZoneID, 1) & g_iDamageTypeBits[i]) ? "[\xE2\x9C\x93] " : "", g_szDamageTypeNames[i]);
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);

	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		ZoneManager_ShowMenuEditZone(iClient);
		return;
	}
	
	g_iEditingZoneID[iClient] = iZoneID;
	ZoneManager_RestartEditingZoneData(iClient);
}

public MenuHandle_EditData(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_iEditingZoneID[iParam1] = 0;
		ZoneManager_FinishedEditingZoneData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			ZoneManager_ShowMenuEditZone(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
		
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iBitValue = g_iDamageTypeBits[StringToInt(szInfo)];
	
	ZoneManager_SetDataInt(g_iEditingZoneID[iParam1], 1, iBitValue);
		
	DisplayMenu_EditData(iParam1, g_iEditingZoneID[iParam1]);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(1 <= iVictim <= MaxClients))
		return Plugin_Continue;
		
	if(g_iCombinedBits[iVictim] == 0)
		return Plugin_Continue;
	
	if(g_iCombinedBits[iVictim] & iDamageType)
	{
		fDamage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}