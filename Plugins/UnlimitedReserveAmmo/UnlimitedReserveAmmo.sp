#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Unlimited Reserve Ammo";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have unlimited reserve ammo.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("unlimited_reserve_ammo_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnEntityCreated(iEnt, const String:szClassName[])
{
	if(strlen(szClassName) < 8)
		return;
	
	if(szClassName[0] != 'w')
		return;
	
	if(StrContains(szClassName, "weapon_") != 0)
		return;
	
	if(StrEqual(szClassName[7], "hegrenade")
	|| StrEqual(szClassName[7], "smokegrenade")
	|| StrEqual(szClassName[7], "incgrenade")
	|| StrEqual(szClassName[7], "decoy")
	|| StrEqual(szClassName[7], "molotov")
	|| StrEqual(szClassName[7], "tagrenade")
	|| StrEqual(szClassName[7], "flashbang"))
		return;
	
	SDKHook(iEnt, SDKHook_Reload, OnWeaponReload);
}

public OnWeaponReload(iWeapon)
{
	SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 500);
}