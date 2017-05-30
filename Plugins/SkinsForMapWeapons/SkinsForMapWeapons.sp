#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <cstrike>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Skins for map weapons";
new const String:PLUGIN_VERSION[] = "3.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to use their skins on map spawned weapons.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_WEAPON_ENT_NAME_LEN		32

#define WEAPON_TEAM_ANY		-1
#define WEAPON_TEAM_NONE	0	// Use WEAPON_TEAM_NONE for weapons that break due to inventory loadout.
#define WEAPON_TEAM_T		CS_TEAM_T
#define WEAPON_TEAM_CT		CS_TEAM_CT

new Handle:g_aWeapons;
enum _:WeaponData
{
	String:WEAPON_ENT_NAME[MAX_WEAPON_ENT_NAME_LEN],
	WEAPON_TEAM_NUMBER
};


public OnPluginStart()
{
	CreateConVar("skins_for_map_weapons_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aWeapons = CreateArray(WeaponData);
	AddWeaponsToArray();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			PlayerHooks(iClient);
	}
}

public OnClientPutInServer(iClient)
{
	PlayerHooks(iClient);
}

PlayerHooks(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquip_Post);
}

public OnWeaponEquip_Post(iClient, iWeapon)
{
	if(iWeapon < 1 || !IsValidEntity(iWeapon))
		return;
	
	if(!GetEntProp(iWeapon, Prop_Data, "m_iHammerID"))
		return;
	
	static String:szClassName[MAX_WEAPON_ENT_NAME_LEN];
	if(!GetEntityClassname(iWeapon, szClassName, sizeof(szClassName)))
		return;
	
	SetEntProp(iWeapon, Prop_Data, "m_iHammerID", 0);
	
	// TODO: Delete this if picking up silenced weapons works now.
	/*
	new iItemDefinitionIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	switch(iItemDefinitionIndex)
	{
		case ITEM_DEF_INDEX_M4A1: strcopy(szClassName, sizeof(szClassName), "weapon_m4a1_silencer");
		case ITEM_DEF_INDEX_USP: strcopy(szClassName, sizeof(szClassName), "weapon_usp_silencer");
	}
	*/
	
	new iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon == iWeapon)
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", -1);
	
	RemovePlayerItem(iClient, iWeapon);
	
	if(GiveWeapon(iClient, szClassName))
	{
		AcceptEntityInput(iWeapon, "Kill");
	}
	else
	{
		EquipPlayerWeapon(iClient, iWeapon);
		
		if(iActiveWeapon == iWeapon)
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	}
}

bool:GiveWeapon(iClient, const String:szWeaponName[])
{
	new iIndex = FindStringInArray(g_aWeapons, szWeaponName);
	if(iIndex == -1)
		return false;
	
	static eWeaponData[WeaponData];
	GetArrayArray(g_aWeapons, iIndex, eWeaponData);
	
	new iClientTeam = GetClientTeam(iClient);
	if(eWeaponData[WEAPON_TEAM_NUMBER] != WEAPON_TEAM_ANY)
		SetEntProp(iClient, Prop_Send, "m_iTeamNum", eWeaponData[WEAPON_TEAM_NUMBER]);
	
	new iWeapon = GivePlayerItemCustom(iClient, eWeaponData[WEAPON_ENT_NAME]);
	SetEntProp(iClient, Prop_Send, "m_iTeamNum", iClientTeam);
	
	if(iWeapon == -1)
		return false;
	
	return true;
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

AddWeaponsToArray()
{
	// Knife / Taser
	AddWeaponToArray("weapon_knife", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_knife_t", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_knifegg");
	AddWeaponToArray("weapon_taser");
	
	// Pistols
	AddWeaponToArray("weapon_glock", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_hkp2000", WEAPON_TEAM_NONE);
	AddWeaponToArray("weapon_usp_silencer", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_elite");
	AddWeaponToArray("weapon_p250");
	AddWeaponToArray("weapon_cz75a");
	AddWeaponToArray("weapon_fiveseven", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_tec9", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_deagle");
	AddWeaponToArray("weapon_revolver");
	
	// Heavy
	AddWeaponToArray("weapon_nova");
	AddWeaponToArray("weapon_xm1014");
	AddWeaponToArray("weapon_sawedoff", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_mag7", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_m249");
	AddWeaponToArray("weapon_negev");
	
	// SMGs
	AddWeaponToArray("weapon_mac10", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_mp7");
	AddWeaponToArray("weapon_mp9", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_ump45");
	AddWeaponToArray("weapon_p90");
	AddWeaponToArray("weapon_bizon");
	
	// Rifles
	AddWeaponToArray("weapon_galilar", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_famas", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_ak47", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_m4a1", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_m4a1_silencer", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_ssg08");
	AddWeaponToArray("weapon_sg556", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_aug", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_awp");
	AddWeaponToArray("weapon_g3sg1", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_scar20", WEAPON_TEAM_CT);
	
	// Grenades
	AddWeaponToArray("weapon_hegrenade");
	AddWeaponToArray("weapon_flashbang");
	AddWeaponToArray("weapon_smokegrenade");
	AddWeaponToArray("weapon_decoy");
	AddWeaponToArray("weapon_incgrenade", WEAPON_TEAM_CT);
	AddWeaponToArray("weapon_molotov", WEAPON_TEAM_T);
	AddWeaponToArray("weapon_tagrenade");
	
	// Misc
	AddWeaponToArray("weapon_healthshot");
}

AddWeaponToArray(const String:szWeaponEntName[], const iWeaponTeam=WEAPON_TEAM_ANY)
{
	decl eWeaponData[WeaponData];
	strcopy(eWeaponData[WEAPON_ENT_NAME], MAX_WEAPON_ENT_NAME_LEN, szWeaponEntName);
	eWeaponData[WEAPON_TEAM_NUMBER] = iWeaponTeam;
	
	PushArrayArray(g_aWeapons, eWeaponData);
}