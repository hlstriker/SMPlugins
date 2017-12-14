#include <sourcemod>
#include <sdkhooks>
#include <cstrike>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_entinput>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Hide & Seek";
new const String:PLUGIN_VERSION[] = "0.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Hide & Seek.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define TEAM_NAME_1		"Seekers"
#define TEAM_NAME_2		"Hiders"

#define TEAM_HIDERS		CS_TEAM_T
#define TEAM_SEEKERS	CS_TEAM_CT

#define FLASHBANG_AMMO_OFFSET	15

new Handle:cvar_mp_teamname_1;
new Handle:cvar_mp_teamname_2;
new Handle:cvar_mp_give_player_c4;

new Handle:cvar_hide_time;

#define FFADE_IN		0x0001
#define FFADE_STAYOUT	0x0008
#define FFADE_PURGE		0x0010
new UserMsg:g_msgFade;

new g_iHideTimeCount;
new Handle:g_hTimer_HideCountdown;

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("hide_and_seek_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_hide_time = CreateConVar("hns_hide_time", "15", "The time the hiders have to hide.");
	
	SetupConVars();
	
	g_msgFade = GetUserMessageId("Fade");
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_Post);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
}

SetupConVars()
{
	if((cvar_mp_teamname_1 = FindConVar("mp_teamname_1")) != INVALID_HANDLE)
	{
		HookConVarChange(cvar_mp_teamname_1, OnConVarChanged);
		SetConVarString(cvar_mp_teamname_1, TEAM_NAME_1);
	}
	
	if((cvar_mp_teamname_2 = FindConVar("mp_teamname_2")) != INVALID_HANDLE)
	{
		HookConVarChange(cvar_mp_teamname_2, OnConVarChanged);
		SetConVarString(cvar_mp_teamname_2, TEAM_NAME_2);
	}
	
	if((cvar_mp_give_player_c4 = FindConVar("mp_give_player_c4")) != INVALID_HANDLE)
	{
		HookConVarChange(cvar_mp_give_player_c4, OnConVarChanged);
		SetConVarInt(cvar_mp_give_player_c4, 0);
	}
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[])
{
	if(hConvar == cvar_mp_teamname_1)
	{
		SetConVarString(cvar_mp_teamname_1, TEAM_NAME_1);
	}
	else if(hConvar == cvar_mp_teamname_2)
	{
		SetConVarString(cvar_mp_teamname_2, TEAM_NAME_2);
	}
	else if(hConvar == cvar_mp_give_player_c4)
	{
		SetConVarInt(cvar_mp_give_player_c4, 0);
	}
}

public Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// Must start the hide countdown timer before fading screens.
	StartTimer_HideCountdown();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		TryStartHideFadeScreen(iClient);
	}
}

public OnMapEnd()
{
	StopTimer_HideCountdown();
}

StopTimer_HideCountdown()
{
	if(g_hTimer_HideCountdown == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_HideCountdown);
	g_hTimer_HideCountdown = INVALID_HANDLE;
	
	UnhookPostThinkPostAll();
}

StartTimer_HideCountdown()
{
	StopTimer_HideCountdown();
	
	g_iHideTimeCount = 0;
	g_hTimer_HideCountdown = CreateTimer(1.0, Timer_HideCountdown, _, TIMER_REPEAT);
	
	PrintHideCountdown();
	HookPostThinkPostAll();
}

HookPostThinkPostAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
		SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	}
}

UnhookPostThinkPostAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	}
}

public OnPostThinkPost(iClient)
{
	SetEntProp(iClient, Prop_Send, "m_bSpotted", 0);
}

public Action:Timer_HideCountdown(Handle:hTimer)
{
	g_iHideTimeCount++;
	if(g_iHideTimeCount >= GetConVarInt(cvar_hide_time))
	{
		// Call fade screen before setting the hide timer to invalid.
		TryEndHideFadeScreenAll();
		
		g_hTimer_HideCountdown = INVALID_HANDLE;
		UnhookPostThinkPostAll();
		
		PrintHintTextToAll("<font color='#6FC41A'>START!</font>");
		
		return Plugin_Stop;
	}
	
	PrintHideCountdown();
	return Plugin_Continue;
}

PrintHideCountdown()
{
	PrintHintTextToAll("<font color='#c41919'>Hiders have <font color='#6FC41A'>%i</font> more seconds to hide!</font>", GetConVarInt(cvar_hide_time) - g_iHideTimeCount);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

TryStartHideFadeScreen(iClient)
{
	if(g_hTimer_HideCountdown == INVALID_HANDLE)
		return;
	
	if(GetClientTeam(iClient) == TEAM_HIDERS)
		return;
	
	FadeScreen(iClient, 0.0, 0.0, {0, 0, 0, 255}, FFADE_STAYOUT | FFADE_PURGE);
}

TryEndHideFadeScreenAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		TryEndHideFadeScreen(iClient);
	}
}

TryEndHideFadeScreen(iClient)
{
	if(g_hTimer_HideCountdown == INVALID_HANDLE)
		return;
	
	if(GetClientTeam(iClient) == TEAM_HIDERS)
		return;
	
	FadeScreen(iClient, 3.0, 0.0, {0, 0, 0, 255}, FFADE_IN | FFADE_PURGE);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	TryStartHideFadeScreen(iClient);
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	StripClientWeapons(iClient);
	
	decl iWeapon;
	if(GetClientTeam(iClient) == TEAM_HIDERS)
	{
		iWeapon = GivePlayerItemCustom(iClient, "weapon_knife_t");
		GivePlayerItemCustom(iClient, "weapon_flashbang");
		SetEntProp(iClient, Prop_Send, "m_iAmmo", 2, _, FLASHBANG_AMMO_OFFSET);
	}
	else
	{
		iWeapon = GivePlayerItemCustom(iClient, "weapon_knife");
	}
	
	if(iWeapon > 0)
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	SetEntityHealth(iClient, 100);
	SetEntProp(iClient, Prop_Data, "m_iMaxHealth", 100);
	SetEntProp(iClient, Prop_Send, "m_ArmorValue", 0);
	SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 0);
	SetEntProp(iClient, Prop_Send, "m_bHasDefuser", 0);
}

GivePlayerItemCustom(iClient, const String:szClassName[])
{
	new iEnt = GivePlayerItem(iClient, szClassName);
	
	/*
	* 	Sometimes GivePlayerItem() will call EquipPlayerWeapon() directly.
	* 	Other times which seems to be directly after stripping weapons or player spawn EquipPlayerWeapon() won't get called.
	* 	Call EquipPlayerWeapon() here if it wasn't called during GivePlayerItem(). Determine that by checking the entities owner.
	*/
	if(iEnt != -1 && GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == -1)
		EquipPlayerWeapon(iClient, iEnt);
	
	return iEnt;
}

public OnWeaponEquipPost(iClient, iWeapon)
{
	if(!IsValidEntity(iWeapon))
		return;
	
	TrySetHidersKnifeAttackTime(iClient, iWeapon);
}

public OnWeaponSwitchPost(iClient, iWeapon)
{
	if(!IsValidEntity(iWeapon))
		return;
	
	TrySetHidersKnifeAttackTime(iClient, iWeapon);
}

TrySetHidersKnifeAttackTime(iClient, iWeapon)
{
	if(GetClientTeam(iClient) != TEAM_HIDERS)
		return;
	
	static String:szClassName[13];
	if(!GetEntityClassname(iWeapon, szClassName, sizeof(szClassName)))
		return;
	
	szClassName[12] = '\x00';
	if(!StrEqual(szClassName[7], "knife") && !StrEqual(szClassName[7], "bayon"))
		return;
	
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", Float:0x7f7fffff);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", Float:0x7f7fffff);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", Float:0x7f7fffff);
}

public Action:CS_OnBuyCommand(iClient, const String:szWeaponName[])
{
	return Plugin_Handled;
}

StripClientWeapons(iClient)
{
	new iArraySize = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	
	decl iWeapon;
	for(new i=0; i<iArraySize; i++)
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if(iWeapon < 1)
			continue;
		
		StripWeaponFromOwner(iWeapon);
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, i);
	}
}

StripWeaponFromOwner(iWeapon)
{
	new iOwner = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if(iOwner != -1)
	{
		// First drop the weapon.
		SDKHooks_DropWeapon(iOwner, iWeapon);
		
		// If the weapon still has an owner after being dropped called RemovePlayerItem.
		// Note we check m_hOwner instead of m_hOwnerEntity here.
		if(GetEntPropEnt(iWeapon, Prop_Send, "m_hOwner") == iOwner)
			RemovePlayerItem(iOwner, iWeapon);
		
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", -1);
	}
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel != -1)
	{
		SetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel", -1);
		AcceptEntityInput(iWorldModel, "KillHierarchy");
	}
	
	AcceptEntityInput(iWeapon, "KillHierarchy");
}

FadeFloatToInt(Float:fValue)
{
	new iOutput = RoundFloat(fValue * (1<<9));
	
	if(iOutput < 0)
		iOutput = 0;
	else if(iOutput > 0xFFFF)
		iOutput = 0xFFFF;
	
	return iOutput;
}

FadeScreen(iClient, Float:fDurationMilliseconds, Float:fHoldMilliseconds, const iColor[4], iFlags)
{
	decl iClients[1];
	iClients[0] = iClient;	
	
	new Handle:hMessage = StartMessageEx(g_msgFade, iClients, 1);
	
	if(GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(hMessage, "duration", FadeFloatToInt(fDurationMilliseconds));
		PbSetInt(hMessage, "hold_time", FadeFloatToInt(fHoldMilliseconds));
		PbSetInt(hMessage, "flags", iFlags);
		PbSetColor(hMessage, "clr", iColor);
	}
	else
	{
		BfWriteShort(hMessage, FadeFloatToInt(fDurationMilliseconds));
		BfWriteShort(hMessage, FadeFloatToInt(fHoldMilliseconds));
		BfWriteShort(hMessage, iFlags);
		BfWriteByte(hMessage, iColor[0]);
		BfWriteByte(hMessage, iColor[1]);
		BfWriteByte(hMessage, iColor[2]);
		BfWriteByte(hMessage, iColor[3]);
	}
	
	EndMessage();
}