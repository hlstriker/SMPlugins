#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <cstrike>
#include <sdktools_entinput>
#include <sdkhooks>
#include "../../Libraries/BlockMaker/block_maker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Weapons";
new const String:PLUGIN_VERSION[] = "0.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME		"Weapons"

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/weapons/block.mdl",
	"models/swoobles/blocks/weapons/block.dx90.vtx",
	"models/swoobles/blocks/weapons/block.phy",
	"models/swoobles/blocks/weapons/block.vvd",
	
	"materials/swoobles/blocks/weapons/none.vtf",
	"materials/swoobles/blocks/weapons/none.vmt",
	"materials/swoobles/blocks/weapons/ak47.vtf",
	"materials/swoobles/blocks/weapons/ak47.vmt",
	"materials/swoobles/blocks/weapons/aug.vtf",
	"materials/swoobles/blocks/weapons/aug.vmt",
	"materials/swoobles/blocks/weapons/awp.vtf",
	"materials/swoobles/blocks/weapons/awp.vmt",
	"materials/swoobles/blocks/weapons/cz75.vtf",
	"materials/swoobles/blocks/weapons/cz75.vmt",
	"materials/swoobles/blocks/weapons/deagle.vtf",
	"materials/swoobles/blocks/weapons/deagle.vmt",
	"materials/swoobles/blocks/weapons/decoy.vtf",
	"materials/swoobles/blocks/weapons/decoy.vmt",
	"materials/swoobles/blocks/weapons/dualies.vtf",
	"materials/swoobles/blocks/weapons/dualies.vmt",
	"materials/swoobles/blocks/weapons/famas.vtf",
	"materials/swoobles/blocks/weapons/famas.vmt",
	"materials/swoobles/blocks/weapons/fiveseven.vtf",
	"materials/swoobles/blocks/weapons/fiveseven.vmt",
	"materials/swoobles/blocks/weapons/flashbang.vtf",
	"materials/swoobles/blocks/weapons/flashbang.vmt",
	"materials/swoobles/blocks/weapons/g3sg1.vtf",
	"materials/swoobles/blocks/weapons/g3sg1.vmt",
	"materials/swoobles/blocks/weapons/galil.vtf",
	"materials/swoobles/blocks/weapons/galil.vmt",
	"materials/swoobles/blocks/weapons/glock.vtf",
	"materials/swoobles/blocks/weapons/glock.vmt",
	"materials/swoobles/blocks/weapons/healthshot.vtf",
	"materials/swoobles/blocks/weapons/healthshot.vmt",
	"materials/swoobles/blocks/weapons/hegrenade.vtf",
	"materials/swoobles/blocks/weapons/hegrenade.vmt",
	"materials/swoobles/blocks/weapons/incgrenade.vtf",
	"materials/swoobles/blocks/weapons/incgrenade.vmt",
	"materials/swoobles/blocks/weapons/knife.vtf",
	"materials/swoobles/blocks/weapons/knife.vmt",
	"materials/swoobles/blocks/weapons/m4a1.vtf",
	"materials/swoobles/blocks/weapons/m4a1.vmt",
	"materials/swoobles/blocks/weapons/m4a4.vtf",
	"materials/swoobles/blocks/weapons/m4a4.vmt",
	"materials/swoobles/blocks/weapons/m249.vtf",
	"materials/swoobles/blocks/weapons/m249.vmt",
	"materials/swoobles/blocks/weapons/mac10.vtf",
	"materials/swoobles/blocks/weapons/mac10.vmt",
	"materials/swoobles/blocks/weapons/mag7.vtf",
	"materials/swoobles/blocks/weapons/mag7.vmt",
	"materials/swoobles/blocks/weapons/molotov.vtf",
	"materials/swoobles/blocks/weapons/molotov.vmt",
	"materials/swoobles/blocks/weapons/mp7.vtf",
	"materials/swoobles/blocks/weapons/mp7.vmt",
	"materials/swoobles/blocks/weapons/mp9.vtf",
	"materials/swoobles/blocks/weapons/mp9.vmt",
	"materials/swoobles/blocks/weapons/negev.vtf",
	"materials/swoobles/blocks/weapons/negev.vmt",
	"materials/swoobles/blocks/weapons/nova.vtf",
	"materials/swoobles/blocks/weapons/nova.vmt",
	"materials/swoobles/blocks/weapons/p90.vtf",
	"materials/swoobles/blocks/weapons/p90.vmt",
	"materials/swoobles/blocks/weapons/p250.vtf",
	"materials/swoobles/blocks/weapons/p250.vmt",
	"materials/swoobles/blocks/weapons/p2000.vtf",
	"materials/swoobles/blocks/weapons/p2000.vmt",
	"materials/swoobles/blocks/weapons/ppbizon.vtf",
	"materials/swoobles/blocks/weapons/ppbizon.vmt",
	"materials/swoobles/blocks/weapons/r8.vtf",
	"materials/swoobles/blocks/weapons/r8.vmt",
	"materials/swoobles/blocks/weapons/sawedoff.vtf",
	"materials/swoobles/blocks/weapons/sawedoff.vmt",
	"materials/swoobles/blocks/weapons/scar20.vtf",
	"materials/swoobles/blocks/weapons/scar20.vmt",
	"materials/swoobles/blocks/weapons/sg553.vtf",
	"materials/swoobles/blocks/weapons/sg553.vmt",
	"materials/swoobles/blocks/weapons/smokegrenade.vtf",
	"materials/swoobles/blocks/weapons/smokegrenade.vmt",
	"materials/swoobles/blocks/weapons/ssg08.vtf",
	"materials/swoobles/blocks/weapons/ssg08.vmt",
	"materials/swoobles/blocks/weapons/tagrenade.vtf",
	"materials/swoobles/blocks/weapons/tagrenade.vmt",
	"materials/swoobles/blocks/weapons/taser.vtf",
	"materials/swoobles/blocks/weapons/taser.vmt",
	"materials/swoobles/blocks/weapons/tec9.vtf",
	"materials/swoobles/blocks/weapons/tec9.vmt",
	"materials/swoobles/blocks/weapons/ump.vtf",
	"materials/swoobles/blocks/weapons/ump.vmt",
	"materials/swoobles/blocks/weapons/usps.vtf",
	"materials/swoobles/blocks/weapons/usps.vmt",
	"materials/swoobles/blocks/weapons/xm1014.vtf",
	"materials/swoobles/blocks/weapons/xm1014.vmt"
};

enum
{
	SKININDEX_NONE = 0,
	
	SKININDEX_KNIFE,
	SKININDEX_TASER,
	SKININDEX_HEALTHSHOT,
	
	SKININDEX_GLOCK,
	SKININDEX_P2000,
	SKININDEX_USPS,
	SKININDEX_DUALBERETTAS,
	SKININDEX_P250,
	SKININDEX_CZ75,
	SKININDEX_FIVESEVEN,
	SKININDEX_TEC9,
	SKININDEX_DEAGLE,
	SKININDEX_R8,
	
	SKININDEX_NOVA,
	SKININDEX_XM1014,
	SKININDEX_SAWEDOFF,
	SKININDEX_MAG7,
	SKININDEX_M249,
	SKININDEX_NEGEV,
	
	SKININDEX_MAC10,
	SKININDEX_MP7,
	SKININDEX_MP9,
	SKININDEX_UMP,
	SKININDEX_P90,
	SKININDEX_PPBIZON,
	
	SKININDEX_GALIL,
	SKININDEX_FAMAS,
	SKININDEX_AK47,
	SKININDEX_M4A4,
	SKININDEX_M4A1,
	SKININDEX_SSG08,
	SKININDEX_SG553,
	SKININDEX_AUG,
	SKININDEX_AWP,
	SKININDEX_G3SG1,
	SKININDEX_SCAR20,
	
	SKININDEX_HEGRENADE,
	SKININDEX_FLASHBANG,
	SKININDEX_SMOKEGRENADE,
	SKININDEX_DECOYGRENADE,
	SKININDEX_INCGRENADE,
	SKININDEX_MOLOTOV,
	SKININDEX_TAGRENADE
};

enum
{
	CATEGORY_KNIFE = 0,
	CATEGORY_PISTOLS,
	CATEGORY_HEAVY,
	CATEGORY_SMGS,
	CATEGORY_RIFLES,
	CATEGORY_GRENADES,
	NUM_CATEGORIES
};

new const String:SZ_CATEGORY_NAMES[][] =
{
	"Knife & Misc",
	"Pistol",
	"Heavy",
	"SMG",
	"Rifle",
	"Grenade"
};

#define MAX_WEAPON_NAME_LEN		32
#define MAX_WEAPON_ENT_NAME_LEN	32

new Handle:g_hTrie_EntNameToWeaponIndex;
new Handle:g_aWeaponIndexesInCategory[NUM_CATEGORIES];
new Handle:g_aWeapons;
enum _:WeaponData
{
	String:WEAPON_NAME[MAX_WEAPON_NAME_LEN],
	String:WEAPON_ENT_NAME[MAX_WEAPON_ENT_NAME_LEN],
	WEAPON_TEAM,
	WEAPON_SKIN_INDEX,
	WEAPON_CATEGORY
};

new g_iEditingCategory[MAXPLAYERS+1];
new g_iEditingBlockID[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("block_letters_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hTrie_EntNameToWeaponIndex = CreateTrie();
	g_aWeapons = CreateArray(WeaponData);
	
	for(new i=0; i<sizeof(g_aWeaponIndexesInCategory); i++)
		g_aWeaponIndexesInCategory[i] = CreateArray();
	
	AddWeaponsToArray();
	
	HookEvent("weapon_fire", Event_WeaponFire_Post, EventHookMode_Post);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
}

public BlockMaker_OnRegisterReady()
{
	BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, OnStartTouch, _, OnTypeAssigned, _, OnEditData);
}

public OnTypeAssigned(iBlock, iBlockID)
{
	decl String:szData[MAX_WEAPON_ENT_NAME_LEN];
	if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)))
		return;
	
	decl iIndex;
	if(!GetTrieValue(g_hTrie_EntNameToWeaponIndex, szData, iIndex))
		return;
	
	decl eWeaponData[WeaponData];
	GetArrayArray(g_aWeapons, iIndex, eWeaponData);
	
	SetEntProp(iBlock, Prop_Send, "m_nSkin", eWeaponData[WEAPON_SKIN_INDEX]);
}

public Event_WeaponFire_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!iClient)
		return;
	
	new iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iActiveWeapon < 1)
		return;
	
	// NOTE: This event is fired before the players clip size is reduced. Ex: Has 1 ammo, fires, will still be 1 ammo here.
	if(GetEntProp(iActiveWeapon, Prop_Send, "m_iClip1") > 1 || GetEntProp(iActiveWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount") > 1)
		return;
	
	StripWeaponFromOwner(iActiveWeapon);
}

StripWeaponFromOwner(iWeapon)
{
	// Don't strip the taser after it's fired or it will crash the server!
	// NOTE: We should probably eventually check if mp_taser_recharge_time is less than 0. If its >= 0 the player's taser won't be dropped.
	decl String:szClassName[14];
	if(!GetEntityClassname(iWeapon, szClassName, sizeof(szClassName)))
		return;
	
	if(StrEqual(szClassName, "weapon_taser"))
		return;
	
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

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Handled;
	
	new iBlockID = GetEntityBlockID(iBlock);
	if(!iBlockID)
		return Plugin_Handled;
	
	static String:szData[MAX_WEAPON_ENT_NAME_LEN];
	if(!BlockMaker_GetDataString(iBlockID, szData, sizeof(szData)))
		return Plugin_Handled;
	
	decl iIndex;
	if(!GetTrieValue(g_hTrie_EntNameToWeaponIndex, szData, iIndex))
		return Plugin_Handled;
	
	decl eWeaponData[WeaponData];
	GetArrayArray(g_aWeapons, iIndex, eWeaponData);
	
	new iSlot = -1;
	switch(eWeaponData[WEAPON_CATEGORY])
	{
		case CATEGORY_KNIFE:	iSlot = CS_SLOT_KNIFE;
		case CATEGORY_PISTOLS:	iSlot = CS_SLOT_SECONDARY;
		case CATEGORY_HEAVY:	iSlot = CS_SLOT_PRIMARY;
		case CATEGORY_SMGS:		iSlot = CS_SLOT_PRIMARY;
		case CATEGORY_RIFLES:	iSlot = CS_SLOT_PRIMARY;
		case CATEGORY_GRENADES:	iSlot = CS_SLOT_GRENADE;
	}
	
	if(iSlot == -1)
		return Plugin_Handled;
	
	if(GetPlayerWeaponSlot(iOther, iSlot) > 0)
		return Plugin_Handled;
	
	Format(szData, sizeof(szData), "weapon_%s", szData);
	
	new iClientTeam = GetClientTeam(iOther);
	if(eWeaponData[WEAPON_TEAM])
		SetEntProp(iOther, Prop_Send, "m_iTeamNum", eWeaponData[WEAPON_TEAM]);
	
	new iWeapon = GivePlayerItemCustom(iOther, szData);
	SetEntProp(iOther, Prop_Send, "m_iTeamNum", iClientTeam);
	
	if(iSlot == CS_SLOT_PRIMARY || iSlot == CS_SLOT_SECONDARY)
	{
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", 1);
		SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
	}
	
	return Plugin_Continue;
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

public OnEditData(iClient, iBlockID)
{
	DisplayMenu_EditData(iClient, iBlockID);
}

DisplayMenu_EditData(iClient, iBlockID, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditData);
	SetMenuTitle(hMenu, "Edit Weapon");
	
	decl String:szInfo[3];
	for(new i=0; i<sizeof(g_aWeaponIndexesInCategory); i++)
	{
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, SZ_CATEGORY_NAMES[i]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		PrintToChat(iClient, "Error displaying menu.");
		BlockMaker_DisplayMenu_EditBlock(iClient, iBlockID);
		return;
	}
	
	g_iEditingBlockID[iClient] = iBlockID;
	BlockMaker_RestartEditingBlockData(iClient, iBlockID);
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
		BlockMaker_FinishedEditingBlockData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			BlockMaker_DisplayMenu_EditBlock(iParam1, g_iEditingBlockID[iParam1]);
		
		g_iEditingBlockID[iParam1] = 0;
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[3];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	DisplayMenu_WeaponSelect(iParam1, StringToInt(szInfo));
}

DisplayMenu_WeaponSelect(iClient, iCategory, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_WeaponSelect);
	SetMenuTitle(hMenu, "Edit Weapon");
	
	decl String:szInfo[6], iIndex, eWeaponData[WeaponData];
	new iArraySize = GetArraySize(g_aWeaponIndexesInCategory[iCategory]);
	
	for(new i=0; i<iArraySize; i++)
	{
		iIndex = GetArrayCell(g_aWeaponIndexesInCategory[iCategory], i);
		GetArrayArray(g_aWeapons, iIndex, eWeaponData);
		
		IntToString(iIndex, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, eWeaponData[WEAPON_NAME]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		PrintToChat(iClient, "Error displaying menu.");
		DisplayMenu_EditData(iClient, g_iEditingBlockID[iClient]);
		return;
	}
	
	g_iEditingCategory[iClient] = iCategory;
	BlockMaker_RestartEditingBlockData(iClient, g_iEditingBlockID[iClient]);
}

public MenuHandle_WeaponSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		BlockMaker_FinishedEditingBlockData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditData(iParam1, g_iEditingBlockID[iParam1]);
		else
			g_iEditingBlockID[iParam1] = 0;
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[6];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	decl eWeaponData[WeaponData];
	GetArrayArray(g_aWeapons, StringToInt(szInfo), eWeaponData);
	BlockMaker_SetDataString(g_iEditingBlockID[iParam1], eWeaponData[WEAPON_ENT_NAME]);
	
	new iEnt = BlockMaker_GetBlockEntFromID(g_iEditingBlockID[iParam1]);
	if(iEnt > 0)
		SetEntProp(iEnt, Prop_Send, "m_nSkin", eWeaponData[WEAPON_SKIN_INDEX]);
	
	DisplayMenu_WeaponSelect(iParam1, g_iEditingCategory[iParam1], GetMenuSelectionPosition());
}

AddWeaponsToArray()
{
	// Knife & Misc
	AddWeaponToArray("Knife", "knife", CATEGORY_KNIFE, SKININDEX_KNIFE);
	AddWeaponToArray("Taser", "taser", CATEGORY_KNIFE, SKININDEX_TASER);
	AddWeaponToArray("Healthshot", "healthshot", CATEGORY_KNIFE, SKININDEX_HEALTHSHOT);
	
	// Pistols
	AddWeaponToArray("Glock-18", "glock", CATEGORY_PISTOLS, SKININDEX_GLOCK, CS_TEAM_T);
	AddWeaponToArray("P2000", "hkp2000", CATEGORY_PISTOLS, SKININDEX_P2000, CS_TEAM_CT);
	AddWeaponToArray("USP-S", "usp_silencer", CATEGORY_PISTOLS, SKININDEX_USPS, CS_TEAM_CT);
	AddWeaponToArray("Dual Berettas", "elite", CATEGORY_PISTOLS, SKININDEX_DUALBERETTAS);
	AddWeaponToArray("P250", "p250", CATEGORY_PISTOLS, SKININDEX_P250);
	AddWeaponToArray("CZ75-Auto", "cz75a", CATEGORY_PISTOLS, SKININDEX_CZ75);
	AddWeaponToArray("Five-Seven", "fiveseven", CATEGORY_PISTOLS, SKININDEX_FIVESEVEN, CS_TEAM_CT);
	AddWeaponToArray("Tec-9", "tec9", CATEGORY_PISTOLS, SKININDEX_TEC9, CS_TEAM_T);
	AddWeaponToArray("Desert Eagle", "deagle", CATEGORY_PISTOLS, SKININDEX_DEAGLE);
	AddWeaponToArray("R8 Revolver", "revolver", CATEGORY_PISTOLS, SKININDEX_R8);
	
	// Heavy
	AddWeaponToArray("Nova", "nova", CATEGORY_HEAVY, SKININDEX_NOVA);
	AddWeaponToArray("XM1014", "xm1014", CATEGORY_HEAVY, SKININDEX_XM1014);
	AddWeaponToArray("Sawed-Off", "sawedoff", CATEGORY_HEAVY, SKININDEX_SAWEDOFF, CS_TEAM_T);
	AddWeaponToArray("MAG-7", "mag7", CATEGORY_HEAVY, SKININDEX_MAG7, CS_TEAM_CT);
	AddWeaponToArray("M249", "m249", CATEGORY_HEAVY, SKININDEX_M249);
	AddWeaponToArray("Negev", "negev", CATEGORY_HEAVY, SKININDEX_NEGEV);
	
	// SMGs
	AddWeaponToArray("MAC-10", "mac10", CATEGORY_SMGS, SKININDEX_MAC10, CS_TEAM_T);
	AddWeaponToArray("MP7", "mp7", CATEGORY_SMGS, SKININDEX_MP7);
	AddWeaponToArray("MP9", "mp9", CATEGORY_SMGS, SKININDEX_MP9, CS_TEAM_CT);
	AddWeaponToArray("UMP-45", "ump45", CATEGORY_SMGS, SKININDEX_UMP);
	AddWeaponToArray("P90", "p90", CATEGORY_SMGS, SKININDEX_P90);
	AddWeaponToArray("PP-Bizon", "bizon", CATEGORY_SMGS, SKININDEX_PPBIZON);
	
	// Rifles
	AddWeaponToArray("Galil AR", "galilar", CATEGORY_RIFLES, SKININDEX_GALIL, CS_TEAM_T);
	AddWeaponToArray("FAMAS", "famas", CATEGORY_RIFLES, SKININDEX_FAMAS, CS_TEAM_CT);
	AddWeaponToArray("AK-47", "ak47", CATEGORY_RIFLES, SKININDEX_AK47, CS_TEAM_T);
	AddWeaponToArray("M4A4", "m4a1", CATEGORY_RIFLES, SKININDEX_M4A4, CS_TEAM_CT);
	AddWeaponToArray("M4A1-S", "m4a1_silencer", CATEGORY_RIFLES, SKININDEX_M4A1, CS_TEAM_CT);
	AddWeaponToArray("SSG 08", "ssg08", CATEGORY_RIFLES, SKININDEX_SSG08);
	AddWeaponToArray("SG 553", "sg556", CATEGORY_RIFLES, SKININDEX_SG553, CS_TEAM_T);
	AddWeaponToArray("AUG", "aug", CATEGORY_RIFLES, SKININDEX_AUG, CS_TEAM_CT);
	AddWeaponToArray("AWP", "awp", CATEGORY_RIFLES, SKININDEX_AWP);
	AddWeaponToArray("G3SG1", "g3sg1", CATEGORY_RIFLES, SKININDEX_G3SG1, CS_TEAM_T);
	AddWeaponToArray("SCAR-20", "scar20", CATEGORY_RIFLES, SKININDEX_SCAR20, CS_TEAM_CT);
	
	// Grenades
	AddWeaponToArray("High Explosive Grenade", "hegrenade", CATEGORY_GRENADES, SKININDEX_HEGRENADE);
	AddWeaponToArray("Flashbang", "flashbang", CATEGORY_GRENADES, SKININDEX_FLASHBANG);
	AddWeaponToArray("Smoke Grenade", "smokegrenade", CATEGORY_GRENADES, SKININDEX_SMOKEGRENADE);
	AddWeaponToArray("Decoy Grenade", "decoy", CATEGORY_GRENADES, SKININDEX_DECOYGRENADE);
	AddWeaponToArray("Incendiary Grenade", "incgrenade", CATEGORY_GRENADES, SKININDEX_INCGRENADE, CS_TEAM_CT);
	AddWeaponToArray("Molotov Cocktail", "molotov", CATEGORY_GRENADES, SKININDEX_MOLOTOV, CS_TEAM_T);
	AddWeaponToArray("Tactical Awareness Grenade", "tagrenade", CATEGORY_GRENADES, SKININDEX_TAGRENADE);
}

AddWeaponToArray(const String:szWeaponName[], const String:szWeaponEntName[], const iCategory, const iSkinIndex, const iWeaponTeam=0)
{
	decl eWeaponData[WeaponData];
	strcopy(eWeaponData[WEAPON_NAME], MAX_WEAPON_NAME_LEN, szWeaponName);
	strcopy(eWeaponData[WEAPON_ENT_NAME], MAX_WEAPON_ENT_NAME_LEN, szWeaponEntName);
	eWeaponData[WEAPON_TEAM] = iWeaponTeam;
	eWeaponData[WEAPON_SKIN_INDEX] = iSkinIndex;
	eWeaponData[WEAPON_CATEGORY] = iCategory;
	
	new iIndex = PushArrayArray(g_aWeapons, eWeaponData);
	PushArrayCell(g_aWeaponIndexesInCategory[iCategory], iIndex);
	
	SetTrieValue(g_hTrie_EntNameToWeaponIndex, eWeaponData[WEAPON_ENT_NAME], iIndex, true);
}