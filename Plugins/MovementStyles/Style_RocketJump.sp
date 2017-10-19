#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Plugins/CustomWeapons/RPG/custom_weapon_rpg"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Rocket Jump";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = PLUGIN_NAME,
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_ROCKET_JUMP
#define THIS_STYLE_NAME			"Rocket Jump"
#define THIS_STYLE_NAME_AUTO	"Rocket Jump + Auto Bhop"
#define THIS_STYLE_ORDER		110

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

new Handle:g_hTimer_GiveRPG[MAXPLAYERS+1];
new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_rocketjump_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_add_autobhop = CreateConVar("style_rocketjump_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_rocketjump_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
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
	
	StartTimer_GiveRPG(iClient);
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
	SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
	
	WpnRPG_Remove(iClient, true);
	StopTimer_GiveRPG(iClient);
}

public MovementStyles_OnSpawnPostForwardsSent(iClient)
{
	if(!g_bActivated[iClient])
		return;
	
	StartTimer_GiveRPG(iClient);
}

public OnClientDisconnect(iClient)
{
	StopTimer_GiveRPG(iClient);
}

StopTimer_GiveRPG(iClient)
{
	if(g_hTimer_GiveRPG[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_GiveRPG[iClient]);
	g_hTimer_GiveRPG[iClient] = INVALID_HANDLE;
}

StartTimer_GiveRPG(iClient)
{
	StopTimer_GiveRPG(iClient);
	g_hTimer_GiveRPG[iClient] = CreateTimer(0.5, Timer_GiveRPG, GetClientSerial(iClient));
}

public Action:Timer_GiveRPG(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_hTimer_GiveRPG[iClient] = INVALID_HANDLE;
	
	if(g_bActivated[iClient])
		GiveRPG(iClient);
}

GiveRPG(iClient)
{
	WpnRPG_SetUnlimitedAmmo(iClient, true, true);
	WpnRPG_SetEffectVisibility(iClient, true);
	WpnRPG_Give(iClient, 1, 0, 1, 0);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if(!(iDamageType & DMG_FALL))
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}