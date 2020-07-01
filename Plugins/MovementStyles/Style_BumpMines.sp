#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <cstrike>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Bump Mines";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Style: Bump Mines.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_BUMP_MINES
#define THIS_STYLE_NAME			"Bump Mines"
#define THIS_STYLE_NAME_AUTO	"Bump Mines + Auto Bhop"
#define THIS_STYLE_ORDER		200

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

new Handle:g_hTimer_GiveBumpMine[MAXPLAYERS+1];
new bool:g_bActivated[MAXPLAYERS+1];

new g_iBumpMineEntRef[MAXPLAYERS+1];
new g_iBumpMineProjectileEntRef[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_bump_mines_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_add_autobhop = CreateConVar("style_bumpmines_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_bumpmines_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
	
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	
	AddCommandListener(OnWeaponDrop, "drop");
	
	new Handle:hConvar = FindConVar("sv_bumpmine_arm_delay");
	if(hConvar != INVALID_HANDLE)
	{
		HookConVarChange(hConvar, OnConVarChanged);
		SetConVarFloat(hConvar, 0.0);
	}
	
	hConvar = FindConVar("sv_bumpmine_detonate_delay");
	if(hConvar != INVALID_HANDLE)
	{
		HookConVarChange(hConvar, OnConVarChanged);
		SetConVarFloat(hConvar, 0.0);
	}
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarFloat(hConvar, 0.0);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_bm");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_bumpmines");
}

public MovementStyles_OnRegisterMultiReady()
{
	if(GetConVarBool(cvar_add_autobhop) && !GetConVarBool(cvar_force_autobhop))
		MovementStyles_RegisterMultiStyle(THIS_STYLE_BIT | STYLE_BIT_AUTO_BHOP, THIS_STYLE_NAME_AUTO, THIS_STYLE_ORDER + 1);
}

public MovementStyles_OnBitsChanged(iClient, iOldBits, &iNewBits)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(iNewBits != THIS_STYLE_BIT)
		return;
	
	iNewBits = TryForceAutoBhopBits(iNewBits);
}

public Action:MovementStyles_OnMenuBitsChanged(iClient, iBitsBeingToggled, bool:bBeingToggledOn, &iExtraBitsToForceOn)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(!bBeingToggledOn || iBitsBeingToggled != THIS_STYLE_BIT)
		return;
	
	iExtraBitsToForceOn = TryForceAutoBhopBits(iExtraBitsToForceOn);
}

TryForceAutoBhopBits(iBits)
{
	if(!GetConVarBool(cvar_force_autobhop))
		return iBits;
	
	return (iBits | STYLE_BIT_AUTO_BHOP);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	StartTimer_GiveBumpMine(iClient);
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
	SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	
	StopTimer_GiveBumpMine(iClient);
	RemoveBumpMine(iClient);
	RemoveBumpMineProjectile(iClient);
}

public MovementStyles_OnSpawnPostForwardsSent(iClient)
{
	if(!g_bActivated[iClient])
		return;
	
	StartTimer_GiveBumpMine(iClient);
}

public OnClientDisconnect(iClient)
{
	StopTimer_GiveBumpMine(iClient);
	RemoveBumpMine(iClient);
	RemoveBumpMineProjectile(iClient);
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!IsClientInGame(iClient))
		return;
	
	StopTimer_GiveBumpMine(iClient);
	RemoveBumpMine(iClient);
	RemoveBumpMineProjectile(iClient);
}

StopTimer_GiveBumpMine(iClient)
{
	if(g_hTimer_GiveBumpMine[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_GiveBumpMine[iClient]);
	g_hTimer_GiveBumpMine[iClient] = INVALID_HANDLE;
}

StartTimer_GiveBumpMine(iClient)
{
	StopTimer_GiveBumpMine(iClient);
	g_hTimer_GiveBumpMine[iClient] = CreateTimer(0.5, Timer_GiveBumpMine, GetClientSerial(iClient));
}

public Action:Timer_GiveBumpMine(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_GiveBumpMine[iClient] = INVALID_HANDLE;
	
	if(g_bActivated[iClient])
		GiveBumpMine(iClient);
}

GetBumpMine(iClient)
{
	new iEnt = EntRefToEntIndex(g_iBumpMineEntRef[iClient]);
	if(iEnt < 1)
		return -1;
	
	if(GetEntityFlags(iEnt) & FL_KILLME)
		return -1;
	
	return iEnt;
}

GiveBumpMine(iClient)
{
	new iEnt = GetBumpMine(iClient);
	if(iEnt > 0)
		return iEnt;
	
	iEnt = GivePlayerItemCustom(iClient, "weapon_bumpmine");
	if(iEnt < 1)
		return -1;
	
	g_iBumpMineEntRef[iClient] = EntIndexToEntRef(iEnt);
	
	return iEnt;
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

bool:RemoveBumpMine(iClient)
{
	new iEnt = GetBumpMine(iClient);
	if(iEnt == -1)
		return false;
	
	AcceptEntityInput(iEnt, "KillHierarchy");
	return true;
}

public OnEntityCreated(iEnt, const String:szClassName[])
{
	if(strlen(szClassName) != 19)
		return;
	
	if(szClassName[8] != '_')
		return;
	
	if(!StrEqual(szClassName, "bumpmine_projectile"))
		return;
	
	SDKHook(iEnt, SDKHook_SpawnPost, OnBumpMineProjectileSpawnPost);
}

public OnBumpMineProjectileSpawnPost(iEnt)
{
	SDKUnhook(iEnt, SDKHook_SpawnPost, OnBumpMineProjectileSpawnPost);
	
	new iOwner;
	iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
	
	if(!IsPlayer(iOwner))
		return;
	
	RemoveBumpMineProjectile(iOwner);
	SetBumpMineProjectile(iOwner, iEnt);
	
	new iWeapon = GetBumpMine(iOwner);
	if(iWeapon > 0)
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", 3);
}

GetBumpMineProjectile(iClient)
{
	new iEnt = EntRefToEntIndex(g_iBumpMineProjectileEntRef[iClient]);
	if(iEnt < 1)
		return -1;
	
	if(GetEntityFlags(iEnt) & FL_KILLME)
		return -1;
	
	return iEnt;
}

SetBumpMineProjectile(iClient, iEnt)
{
	g_iBumpMineProjectileEntRef[iClient] = EntIndexToEntRef(iEnt);
}

bool:RemoveBumpMineProjectile(iClient)
{
	new iEnt = GetBumpMineProjectile(iClient);
	if(iEnt == -1)
		return false;
	
	AcceptEntityInput(iEnt, "KillHierarchy");
	return true;
}

public Action:OnWeaponDrop(iClient, const String:szCommand[], iArgCount)
{
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	return HasBumpMineWeaponDeployed(iClient) ? Plugin_Handled : Plugin_Continue;
}

public Action:CS_OnCSWeaponDrop(iClient, iWeapon)
{
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	return HasBumpMineWeaponDeployed(iClient) ? Plugin_Handled : Plugin_Continue;
}

bool:HasBumpMineWeaponDeployed(iClient)
{
	new iWeapon = GetBumpMine(iClient);
	if(iWeapon == -1)
		return false;
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") != iWeapon)
		return false;
	
	return true;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(iDamageType & DMG_FALL))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}

bool:IsPlayer(iEnt)
{
	return (1 <= iEnt <= MaxClients);
}