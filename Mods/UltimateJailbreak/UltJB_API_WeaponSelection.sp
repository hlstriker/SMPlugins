#include <sourcemod>
#include <cstrike>
#include <sdktools_functions>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Ultimate Jailbreak: Weapon Selection";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The weapon selection plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_hFwd_OnWeaponSelectedSuccess[MAXPLAYERS+1];
new Handle:g_hFwd_OnWeaponSelectedFailed[MAXPLAYERS+1];
new g_iWeaponSelectionFlags[MAXPLAYERS+1][NUM_WPN_CATS];

new bool:g_bIsGettingItem[MAXPLAYERS+1];

new Handle:g_hMenu_WeaponSelection[MAXPLAYERS+1];
new Handle:g_hTimer_WeaponSelection[MAXPLAYERS+1];

new Handle:cvar_select_weapon_time;

new Handle:g_aWeaponTeams;
enum _:WeaponTeam
{
	String:WEAPON_ENT_NAME[WEAPON_MAX_ENTITY_NAME_LENGTH],
	WEAPON_TEAM
};

#define ITEMDEF_CZ75A			63
#define ITEMDEF_M4A1_SILENCER	60
#define ITEMDEF_USP_SILENCER	61
#define ITEMDEF_HKP2000			32

#define SetWeaponAsFromLR(%1)	SetEntProp(%1, Prop_Data, "m_iPendingTeamNum", 1)
#define IsWeaponFromLR(%1)		GetEntProp(%1, Prop_Data, "m_iPendingTeamNum")


public OnPluginStart()
{
	CreateConVar("ultjb_weapon_selection_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_select_weapon_time = CreateConVar("ultjb_select_weapon_time", "15", "The number of seconds a player has to select their weapon.", _, true, 1.0);
	
	g_aWeaponTeams = CreateArray(WeaponTeam);
	PopulateWeaponTeamArray();
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_weapon_selection");
	
	CreateNative("UltJB_Weapons_DisplaySelectionMenu", _UltJB_Weapons_DisplaySelectionMenu);
	CreateNative("UltJB_Weapons_CancelWeaponSelection", _UltJB_Weapons_CancelWeaponSelection);
	CreateNative("UltJB_Weapons_GetEntNameFromWeaponID", _UltJB_Weapons_GetEntNameFromWeaponID);
	CreateNative("UltJB_Weapons_GetItemDefIndexFromWeaponID", _UltJB_Weapons_GetItemDefIndexFromWeaponID);
	CreateNative("UltJB_Weapons_GetWeaponsDefaultTeam", _UltJB_Weapons_GetWeaponsDefaultTeam);
	CreateNative("UltJB_Weapons_GivePlayerWeapon", _UltJB_Weapons_GivePlayerWeapon);
	CreateNative("UltJB_Weapons_IsWeaponFromLR", _UltJB_Weapons_IsWeaponFromLR);
	CreateNative("UltJB_Weapons_IsGettingItem", _UltJB_Weapons_IsGettingItem);
	CreateNative("UltJB_Weapons_GivePlayerItem", _UltJB_Weapons_GivePlayerItem);
	
	return APLRes_Success;
}

public _UltJB_Weapons_GivePlayerItem(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return -1;
	}
	
	decl String:szClassName[ITEM_MAX_ENTITY_NAME_LENGTH];
	GetNativeString(2, szClassName, sizeof(szClassName));
	
	return GivePlayerItemCustom(GetNativeCell(1), szClassName);
}

public _UltJB_Weapons_IsGettingItem(Handle:hPlugin, iNumParams)
{
	return g_bIsGettingItem[GetNativeCell(1)];
}

public _UltJB_Weapons_IsWeaponFromLR(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iWeapon = GetNativeCell(1);
	if(IsWeaponFromLR(iWeapon))
		return true;
	
	return false;
}

GivePlayerItemCustom(iClient, const String:szClassName[])
{
	g_bIsGettingItem[iClient] = true;
	new iEnt = GivePlayerItem(iClient, szClassName);
	
	/*
	* 	Sometimes GivePlayerItem() will call EquipPlayerWeapon() directly.
	* 	Other times which seems to be directly after stripping weapons or player spawn EquipPlayerWeapon() won't get called.
	* 	Call EquipPlayerWeapon() here if it wasn't called during GivePlayerItem(). Determine that by checking the entities owner.
	*/
	if(iEnt != -1 && GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == -1)
		EquipPlayerWeapon(iClient, iEnt);
	
	g_bIsGettingItem[iClient] = false;
	
	return iEnt;
}

public _UltJB_Weapons_GivePlayerWeapon(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return -1;
	}
	
	new iWeaponID = GetNativeCell(2);
	decl String:szClassName[WEAPON_MAX_ENTITY_NAME_LENGTH];
	if(!UltJB_Weapons_GetEntNameFromWeaponID(iWeaponID, szClassName, sizeof(szClassName)))
		return -1;
	
	new iClient = GetNativeCell(1);
	new iClientTeam = GetClientTeam(iClient);
	
	new iDefaultWeaponTeam = UltJB_Weapons_GetWeaponsDefaultTeam(szClassName);
	if(iDefaultWeaponTeam != WEAPON_TEAM_ANY)
		SetEntProp(iClient, Prop_Send, "m_iTeamNum", iDefaultWeaponTeam);
	
	new iWeapon = GivePlayerItemCustom(iClient, szClassName);
	SetEntProp(iClient, Prop_Send, "m_iTeamNum", iClientTeam);
	
	if(iWeapon == -1)
		return -1;
	
	if(UltJB_LR_HasStartedLastRequest(iClient))
		SetWeaponAsFromLR(iWeapon);
	
	// Setting the item def index might be getting the servers banned?
	/*
	new iItemDefinitionIndex = UltJB_Weapons_GetItemDefIndexFromWeaponID(iWeaponID);
	if(iItemDefinitionIndex)
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iItemDefinitionIndex);
	*/
	
	/*
	* 	WARNING: 	Calling EquipPlayerWeapon() any point in the round can crash the server during round restart.
	* 				Seems to only happen with the knife during testing.
	* 
	* 				We don't need to call EquipPlayerWeapon again regardless since GivePlayerItem will try to equip it as long as WeaponCanUse returns true.
	*/
	//if(GetNativeCell(3))
	//	EquipPlayerWeapon(iClient, iWeapon);
	
	return iWeapon;
}

public _UltJB_Weapons_GetWeaponsDefaultTeam(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return WEAPON_TEAM_ANY;
	}
	
	decl String:szClassName[WEAPON_MAX_ENTITY_NAME_LENGTH];
	GetNativeString(1, szClassName, sizeof(szClassName));
	
	new iIndex = FindStringInArray(g_aWeaponTeams, szClassName);
	if(iIndex == -1)
		return WEAPON_TEAM_ANY;
	
	decl eWeaponTeam[WeaponTeam];
	GetArrayArray(g_aWeaponTeams, iIndex, eWeaponTeam);
	
	return eWeaponTeam[WEAPON_TEAM];
}

public _UltJB_Weapons_GetItemDefIndexFromWeaponID(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	switch(GetNativeCell(1))
	{
		case CSWeapon_CZ75A: return ITEMDEF_CZ75A;
		case CSWeapon_M4A1_SILENCER: return ITEMDEF_M4A1_SILENCER;
		case CSWeapon_USP_SILENCER: return ITEMDEF_USP_SILENCER;
		case CSWeapon_HKP2000: return ITEMDEF_HKP2000;
	}
	
	return 0;
}

public _UltJB_Weapons_GetEntNameFromWeaponID(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iWeaponID = GetNativeCell(1);
	
	// Note: Remember to remove these special checks when sourcemod implements their own values.
	new iCellsWritten;
	decl String:szEntityName[WEAPON_MAX_ENTITY_NAME_LENGTH];
	switch(iWeaponID)
	{
		case CSWeapon_CZ75A:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_cz75a");
		}
		case CSWeapon_M4A1_SILENCER:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_m4a1_silencer");
		}
		case CSWeapon_USP_SILENCER:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_usp_silencer");
		}
		case CSWeapon_KNIFE_T:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_knife_t");
		}
		case CSWeapon_KNIFE_GG:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_knifegg");
		}
		case CSWeapon_HEALTHSHOT:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_healthshot");
		}
		case CSWeapon_TAGRENADE:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_tagrenade");
		}
		case CSWeapon_REVOLVER:
		{
			iCellsWritten = strcopy(szEntityName, sizeof(szEntityName), "weapon_revolver");
		}
		default:
		{
			//CS_WeaponIDToAlias(CSWeaponID:iWeaponID, szEntityName, sizeof(szEntityName));
			TempWeaponIDToAlias(CSWeaponID:iWeaponID, szEntityName, sizeof(szEntityName)); // TODO: Delete when CS_WeaponIDToAlias() is fixed.
			iCellsWritten = Format(szEntityName, sizeof(szEntityName), "weapon_%s", szEntityName);
		}
	}
	
	SetNativeString(2, szEntityName, GetNativeCell(3));
	return iCellsWritten;
}

/*
* 	Remove this function when CS_WeaponIDToAlias() is fixed in SourceMod.
*/
new const String:g_szWeaponIDToAlias[][] =
{
	"none",
	"p228",
	"glock",
	"scout",
	"hegrenade",
	"xm1014",
	"c4",
	"mac10",
	"aug",
	"smokegrenade",
	"elite",
	"fiveseven", // fn57 in other games but CS:GO
	"ump45",
	"sg550",
	"galil",
	"famas",
	"usp",
	"awp",
	"mp5",
	"m249",
	"m3",
	"m4a1",
	"tmp",
	"g3sg1",
	"flashbang",
	"deagle",
	"sg552",
	"ak47",
	"knife",
	"p90",
	"shield",
	"vest",
	"vesthelm",
	"nvg",
	"galilar",
	"bizon",
	"mag7",
	"negev",
	"sawedoff",
	"tec9",
	"taser",
	"hkp2000",
	"mp7",
	"mp9",
	"nova",
	"p250",
	"scar17",
	"scar20",
	"sg556",
	"ssg08",
	"knifegg",
	"molotov",
	"decoy",
	"incgrenade",
	"defuser"
};

TempWeaponIDToAlias(CSWeaponID:iWeaponID, String:szEntityName[], iLen)
{
	if(_:iWeaponID < 0 || _:iWeaponID >= sizeof(g_szWeaponIDToAlias))
		return strcopy(szEntityName, iLen, "");
	
	return strcopy(szEntityName, iLen, g_szWeaponIDToAlias[iWeaponID]);
}

public _UltJB_Weapons_CancelWeaponSelection(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	if(!iClient)
		return false;
	
	StopTimer_WeaponSelection(iClient);
	
	if(g_hMenu_WeaponSelection[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_WeaponSelection[iClient]);
	
	return true;
}

public _UltJB_Weapons_DisplaySelectionMenu(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 4)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	if(!iClient)
		return false;
	
	new Function:success_callback = GetNativeCell(2);
	if(success_callback == INVALID_FUNCTION)
		return false;
	
	new Function:failed_callback = GetNativeCell(3);
	if(failed_callback == INVALID_FUNCTION)
		return false;
	
	GetNativeArray(4, g_iWeaponSelectionFlags[iClient], sizeof(g_iWeaponSelectionFlags[]));
	
	if(g_hFwd_OnWeaponSelectedSuccess[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hFwd_OnWeaponSelectedSuccess[iClient]);
		g_hFwd_OnWeaponSelectedSuccess[iClient] = INVALID_HANDLE;
	}
	
	if(g_hFwd_OnWeaponSelectedFailed[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hFwd_OnWeaponSelectedFailed[iClient]);
		g_hFwd_OnWeaponSelectedFailed[iClient] = INVALID_HANDLE;
	}
	
	g_hFwd_OnWeaponSelectedSuccess[iClient] = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Array);
	AddToForward(g_hFwd_OnWeaponSelectedSuccess[iClient], hPlugin, success_callback);
	
	g_hFwd_OnWeaponSelectedFailed[iClient] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
	AddToForward(g_hFwd_OnWeaponSelectedFailed[iClient], hPlugin, failed_callback);
	
	g_hMenu_WeaponSelection[iClient] = DisplayMenu_CategorySelection(iClient);
	if(g_hMenu_WeaponSelection[iClient] == INVALID_HANDLE)
	{
		Forward_OnWeaponSelectedFailed(iClient);
		return false;
	}
	
	StopTimer_WeaponSelection(iClient);
	g_hTimer_WeaponSelection[iClient] = CreateTimer(GetConVarFloat(cvar_select_weapon_time), Timer_WeaponSelection, GetClientSerial(iClient));
	
	return true;
}

public Action:Timer_WeaponSelection(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
	{
		InvalidateHandleArrayIndex(hTimer, g_hTimer_WeaponSelection, sizeof(g_hTimer_WeaponSelection));
		return;
	}
	
	g_hTimer_WeaponSelection[iClient] = INVALID_HANDLE;
	
	if(g_hMenu_WeaponSelection[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_WeaponSelection[iClient]);
	
	PrintToChat(iClient, "[SM] Selecting a random weapon.");
	SelectRandomWeapon(iClient);
}

StopTimer_WeaponSelection(iClient)
{
	if(g_hTimer_WeaponSelection[iClient] == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hTimer_WeaponSelection[iClient]);
	g_hTimer_WeaponSelection[iClient] = INVALID_HANDLE;
}

SelectRandomWeapon(iClient)
{
	new iNumAllowed;
	decl iAllowedWeaponIDs[128];
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_KNIFE] != WPN_FLAGS_DISABLE_KNIVES)
	{
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_KNIFE] & WPN_FLAGS_DISABLE_KNIFE_KNIFE))
		{
			switch(GetRandomInt(0, 1))
			{
				case 0: iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_KNIFE;
				case 1: iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_KNIFE_T;
			}
		}
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_KNIFE] & WPN_FLAGS_DISABLE_KNIFE_TASER))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_TASER;
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] != WPN_FLAGS_DISABLE_PISTOLS)
	{
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_GLOCK))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_GLOCK;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_HPK2000))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_HKP2000;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_USP_SILENCER))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_USP_SILENCER;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_ELITE))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_ELITE;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_P250))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_P250;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_CZ75A))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_CZ75A;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_FIVESEVEN))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_FIVESEVEN;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_TEC9))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_TEC9;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_DEAGLE))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_DEAGLE;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] & WPN_FLAGS_DISABLE_PISTOL_REVOLVER))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_REVOLVER;
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] != WPN_FLAGS_DISABLE_HEAVYS)
	{
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] & WPN_FLAGS_DISABLE_HEAVY_NOVA))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_NOVA;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] & WPN_FLAGS_DISABLE_HEAVY_XM1014))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_XM1014;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] & WPN_FLAGS_DISABLE_HEAVY_SAWEDOFF))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_SAWEDOFF;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] & WPN_FLAGS_DISABLE_HEAVY_MAG7))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_MAG7;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] & WPN_FLAGS_DISABLE_HEAVY_M249))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_M249;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] & WPN_FLAGS_DISABLE_HEAVY_NEGEV))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_NEGEV;
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] != WPN_FLAGS_DISABLE_SMGS)
	{
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] & WPN_FLAGS_DISABLE_SMG_MAC10))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_MAC10;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] & WPN_FLAGS_DISABLE_SMG_MP7))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_MP7;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] & WPN_FLAGS_DISABLE_SMG_MP9))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_MP9;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] & WPN_FLAGS_DISABLE_SMG_UMP45))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_UMP45;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] & WPN_FLAGS_DISABLE_SMG_P90))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_P90;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] & WPN_FLAGS_DISABLE_SMG_BIZON))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_BIZON;
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] != WPN_FLAGS_DISABLE_RIFLES)
	{
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_GALILAR))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_GALILAR;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_FAMAS))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_FAMAS;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_AK47))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_AK47;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_M4A1))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_M4A1;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_M4A1_SILENCER))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_M4A1_SILENCER;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_SSG08))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_SSG08;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_SG556))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_SG556;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_AUG))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_AUG;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_AWP))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_AWP;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_G3SG1))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_G3SG1;
		
		if(!(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] & WPN_FLAGS_DISABLE_RIFLE_SCAR20))
			iAllowedWeaponIDs[iNumAllowed++] = _:CSWeapon_SCAR20;
	}
	
	if(!iNumAllowed)
	{
		PrintToChat(iClient, "[SM] There was an error selecting a random weapon.");
		Forward_OnWeaponSelectedFailed(iClient);
		return;
	}
	
	SelectWeapon(iClient, iAllowedWeaponIDs[GetRandomInt(0, iNumAllowed-1)]);
}

SelectWeapon(iClient, iWeaponID)
{
	Forward_OnWeaponSelectedSuccess(iClient, iWeaponID);
}

Handle:DisplayMenu_CategorySelection(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_CategorySelection);
	
	SetMenuTitle(hMenu, "Select your weapon");
	SetMenuExitButton(hMenu, false);
	
	decl String:szInfo[12];
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_KNIFE] != WPN_FLAGS_DISABLE_KNIVES)
	{
		IntToString(WPN_CAT_KNIFE, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "Knife/Taser");
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_PISTOLS] != WPN_FLAGS_DISABLE_PISTOLS)
	{
		IntToString(WPN_CAT_PISTOLS, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "Pistols");
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_HEAVY] != WPN_FLAGS_DISABLE_HEAVYS)
	{
		IntToString(WPN_CAT_HEAVY, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "Heavy");
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_SMGS] != WPN_FLAGS_DISABLE_SMGS)
	{
		IntToString(WPN_CAT_SMGS, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "SMGs");
	}
	
	if(g_iWeaponSelectionFlags[iClient][WPN_CAT_RIFLES] != WPN_FLAGS_DISABLE_RIFLES)
	{
		IntToString(WPN_CAT_RIFLES, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "Rifles");
	}
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no weapon categories to select.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

public MenuHandle_CategorySelection(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_WeaponSelection, sizeof(g_hMenu_WeaponSelection));
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	g_hMenu_WeaponSelection[iParam1] = DisplayMenu_WeaponSelection(iParam1, StringToInt(szInfo));
	if(g_hMenu_WeaponSelection[iParam1] == INVALID_HANDLE)
	{
		g_hMenu_WeaponSelection[iParam1] = DisplayMenu_CategorySelection(iParam1);
		if(g_hMenu_WeaponSelection[iParam1] == INVALID_HANDLE)
		{
			StopTimer_WeaponSelection(iParam1);
			Forward_OnWeaponSelectedFailed(iParam1);
		}
	}
}

Handle:DisplayMenu_WeaponSelection(iClient, iCategory)
{
	new Handle:hMenu = CreateMenu(MenuHandle_WeaponSelection);
	
	SetMenuTitle(hMenu, "Select your weapon");
	SetMenuExitButton(hMenu, false);
	SetMenuExitBackButton(hMenu, true);
	
	decl String:szInfo[12];
	
	switch(iCategory)
	{
		case WPN_CAT_KNIFE:
		{
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_KNIFE_KNIFE))
			{
				switch(GetRandomInt(0, 1))
				{
					case 0: IntToString(_:CSWeapon_KNIFE, szInfo, sizeof(szInfo));
					case 1: IntToString(_:CSWeapon_KNIFE_T, szInfo, sizeof(szInfo));
				}
				
				AddMenuItem(hMenu, szInfo, "Knife");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_KNIFE_TASER))
			{
				IntToString(_:CSWeapon_TASER, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Taser");
			}
		}
		case WPN_CAT_PISTOLS:
		{
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_GLOCK))
			{
				IntToString(_:CSWeapon_GLOCK, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Glock");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_HPK2000))
			{
				IntToString(_:CSWeapon_HKP2000, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "P2000");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_USP_SILENCER))
			{
				IntToString(_:CSWeapon_USP_SILENCER, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "USP-S");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_ELITE))
			{
				IntToString(_:CSWeapon_ELITE, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Dual Berettas");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_P250))
			{
				IntToString(_:CSWeapon_P250, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "P250");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_CZ75A))
			{
				IntToString(_:CSWeapon_CZ75A, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "CZ75-Auto");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_FIVESEVEN))
			{
				IntToString(_:CSWeapon_FIVESEVEN, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Five-Seven");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_TEC9))
			{
				IntToString(_:CSWeapon_TEC9, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Tec-9");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_DEAGLE))
			{
				IntToString(_:CSWeapon_DEAGLE, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Desert Eagle");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_PISTOL_REVOLVER))
			{
				IntToString(_:CSWeapon_REVOLVER, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "R8 Revolver");
			}
		}
		case WPN_CAT_HEAVY:
		{
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_HEAVY_NOVA))
			{
				IntToString(_:CSWeapon_NOVA, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Nova");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_HEAVY_XM1014))
			{
				IntToString(_:CSWeapon_XM1014, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "XM1014");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_HEAVY_SAWEDOFF))
			{
				IntToString(_:CSWeapon_SAWEDOFF, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Sawed-Off");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_HEAVY_MAG7))
			{
				IntToString(_:CSWeapon_MAG7, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "MAG-7");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_HEAVY_M249))
			{
				IntToString(_:CSWeapon_M249, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "M249");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_HEAVY_NEGEV))
			{
				IntToString(_:CSWeapon_NEGEV, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Negev");
			}
		}
		case WPN_CAT_SMGS:
		{
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_SMG_MAC10))
			{
				IntToString(_:CSWeapon_MAC10, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "MAC-10");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_SMG_MP7))
			{
				IntToString(_:CSWeapon_MP7, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "MP7");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_SMG_MP9))
			{
				IntToString(_:CSWeapon_MP9, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "MP9");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_SMG_UMP45))
			{
				IntToString(_:CSWeapon_UMP45, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "UMP-45");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_SMG_P90))
			{
				IntToString(_:CSWeapon_P90, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "P90");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_SMG_BIZON))
			{
				IntToString(_:CSWeapon_BIZON, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "PP-Bizon");
			}
		}
		case WPN_CAT_RIFLES:
		{
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_GALILAR))
			{
				IntToString(_:CSWeapon_GALILAR, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "Galil AR");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_FAMAS))
			{
				IntToString(_:CSWeapon_FAMAS, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "FAMAS");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_AK47))
			{
				IntToString(_:CSWeapon_AK47, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "AK-47");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_M4A1))
			{
				IntToString(_:CSWeapon_M4A1, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "M4A4");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_M4A1_SILENCER))
			{
				IntToString(_:CSWeapon_M4A1_SILENCER, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "M4A1-S");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_SSG08))
			{
				IntToString(_:CSWeapon_SSG08, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "SSG 08");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_SG556))
			{
				IntToString(_:CSWeapon_SG556, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "SG 553");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_AUG))
			{
				IntToString(_:CSWeapon_AUG, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "AUG");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_AWP))
			{
				IntToString(_:CSWeapon_AWP, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "AWP");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_G3SG1))
			{
				IntToString(_:CSWeapon_G3SG1, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "G3SG1");
			}
			
			if(!(g_iWeaponSelectionFlags[iClient][iCategory] & WPN_FLAGS_DISABLE_RIFLE_SCAR20))
			{
				IntToString(_:CSWeapon_SCAR20, szInfo, sizeof(szInfo));
				AddMenuItem(hMenu, szInfo, "SCAR-20");
			}
		}
	}
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no weapons to select.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

public MenuHandle_WeaponSelection(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_WeaponSelection, sizeof(g_hMenu_WeaponSelection));
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		g_hMenu_WeaponSelection[iParam1] = DisplayMenu_CategorySelection(iParam1);
		if(g_hMenu_WeaponSelection[iParam1] == INVALID_HANDLE)
		{
			StopTimer_WeaponSelection(iParam1);
			Forward_OnWeaponSelectedFailed(iParam1);
		}
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	StopTimer_WeaponSelection(iParam1);
	SelectWeapon(iParam1, StringToInt(szInfo));
}

Forward_OnWeaponSelectedSuccess(iClient, iWeaponID)
{
	if(g_hFwd_OnWeaponSelectedSuccess[iClient] == INVALID_HANDLE)
		return;
	
	Call_StartForward(g_hFwd_OnWeaponSelectedSuccess[iClient]);
	Call_PushCell(iClient);
	Call_PushCell(iWeaponID);
	Call_PushArray(g_iWeaponSelectionFlags[iClient], sizeof(g_iWeaponSelectionFlags[]));
	if(Call_Finish() != SP_ERROR_NONE)
		LogError("Error calling weapon selection success.");
}

Forward_OnWeaponSelectedFailed(iClient)
{
	if(g_hFwd_OnWeaponSelectedFailed[iClient] == INVALID_HANDLE)
		return;
	
	Call_StartForward(g_hFwd_OnWeaponSelectedFailed[iClient]);
	Call_PushCell(iClient);
	Call_PushArray(g_iWeaponSelectionFlags[iClient], sizeof(g_iWeaponSelectionFlags[]));
	if(Call_Finish() != SP_ERROR_NONE)
		LogError("Error calling weapon selection failed.");
}

InvalidateHandleArrayIndex(const Handle:hHandleToSearchFor, Handle:hHandleArray[], iNumElements)
{
	for(new i=0; i<iNumElements; i++)
	{
		if(hHandleArray[i] != hHandleToSearchFor)
			continue;
		
		hHandleArray[i] = INVALID_HANDLE;
		return;
	}
}

PopulateWeaponTeamArray()
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
	decl eWeaponTeam[WeaponTeam];
	strcopy(eWeaponTeam[WEAPON_ENT_NAME], WEAPON_MAX_ENTITY_NAME_LENGTH, szWeaponEntName);
	eWeaponTeam[WEAPON_TEAM] = iWeaponTeam;
	
	PushArrayArray(g_aWeaponTeams, eWeaponTeam);
}