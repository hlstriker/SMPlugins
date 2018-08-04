#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <cstrike>
#include "../../Libraries/ClientCookies/client_cookies"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Knives";
new const String:PLUGIN_VERSION[] = "2.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to use the CS:GO knives.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:g_szKnifeNames[][] =
{
	"Default",
	"T Default",
	"CT Default",
	"Golden",
	"Falchion",
	"Bayonet",
	"M9 Bayonet",
	"Gut",
	"Flip",
	"Karambit",
	"Huntsman",
	"Butterfly",
	"Shadow Daggers",
	"Bowie",
	"Ursus",
	"Navaja",
	"Stiletto",
	"Talon"
};

new const g_iItemDefinitionIndexes[] =
{
	0,
	59,		// T Default
	42,		// CT Default
	41,		// Golden
	512,	// Falchion
	500,	// Bayonet
	508,	// M9 Bayonet
	506,	// Gut
	505,	// Flip
	507,	// Karambit
	509,	// Huntsman (tactical)
	515,	// Butterfly
	516,	// Shadow Daggers (push)
	514,	// Bowie
	519,	// Ursus
	520,	// Navaja
	522,	// Stiletto
	523 	// Talon
};

new const String:g_szKnifeEnts[][] =
{
	"",
	"weapon_knife_t",
	"weapon_knife",
	"weapon_knifegg",
	"weapon_knife_falchion",
	"weapon_bayonet",
	"weapon_knife_m9_bayonet",
	"weapon_knife_gut",
	"weapon_knife_flip",
	"weapon_knife_karambit",
	"weapon_knife_tactical",
	"weapon_knife_butterfly",
	"weapon_knife_push",
	"weapon_knife_survival_bowie",
	"weapon_knife_ursus",
	"weapon_knife_gypsy_jackknife",
	"weapon_knife_stiletto",
	"weapon_knife_widowmaker"
};

new const String:g_szWorldModels[][] =
{
	"",
	"models/weapons/w_knife_default_t.mdl",
	"models/weapons/w_knife_default_ct.mdl",
	"models/weapons/w_knife_gg.mdl",
	"models/weapons/w_knife_falchion_advanced.mdl",
	"models/weapons/w_knife_bayonet.mdl",
	"models/weapons/w_knife_m9_bay.mdl",
	"models/weapons/w_knife_gut.mdl",
	"models/weapons/w_knife_flip.mdl",
	"models/weapons/w_knife_karam.mdl",
	"models/weapons/w_knife_tactical.mdl",
	"models/weapons/w_knife_butterfly.mdl",
	"models/weapons/w_knife_push.mdl",
	"models/weapons/w_knife_survival_bowie.mdl",
	"models/weapons/w_knife_ursus.mdl",
	"models/weapons/w_knife_gypsy_jackknife.mdl",
	"models/weapons/w_knife_stiletto.mdl",
	"models/weapons/w_knife_widowmaker.mdl"
};

new g_iModelIndex_WorldModels[sizeof(g_szWorldModels)];

new g_iKnifeIndex[MAXPLAYERS+1];
new Handle:g_hForwardMenuBack[MAXPLAYERS+1];
new Handle:g_hForwardMenuSelect[MAXPLAYERS+1];

new bool:g_bLibLoaded_SkillServerWeapons;


public OnPluginStart()
{
	CreateConVar("knives_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_knife", OnKnifeSelect, "Opens the knife selection menu.");
	RegConsoleCmd("sm_knives", OnKnifeSelect, "Opens the knife selection menu.");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_SkillServerWeapons = LibraryExists("skill_server_weapons");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "skill_server_weapons"))
	{
		g_bLibLoaded_SkillServerWeapons = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "skill_server_weapons"))
	{
		g_bLibLoaded_SkillServerWeapons = false;
	}
}

public OnMapStart()
{
	for(new i=1; i<sizeof(g_szWorldModels); i++)
		g_iModelIndex_WorldModels[i] = PrecacheModel(g_szWorldModels[i], true);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("unsafe_knives");
	CreateNative("Knives_OpenKnifeMenu", _Knives_OpenKnifeMenu);
	CreateNative("Knives_GetUsedKnifeClassname", _Knives_GetUsedKnifeClassname);
	
	return APLRes_Success;
}

public _Knives_OpenKnifeMenu(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	TryCloseForwards(iClient);
	
	new Function:callback = GetNativeCell(2);
	if(callback != INVALID_FUNCTION)
	{
		g_hForwardMenuSelect[iClient] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(g_hForwardMenuSelect[iClient], hPlugin, callback);
	}
	
	callback = GetNativeCell(3);
	if(callback != INVALID_FUNCTION)
	{
		g_hForwardMenuBack[iClient] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(g_hForwardMenuBack[iClient], hPlugin, callback);
	}
	
	DisplayMenu_KnifeSelect(iClient);
}

TryCloseForwards(iClient)
{
	if(g_hForwardMenuBack[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hForwardMenuBack[iClient]);
		g_hForwardMenuBack[iClient] = INVALID_HANDLE;
	}
	
	if(g_hForwardMenuSelect[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hForwardMenuSelect[iClient]);
		g_hForwardMenuSelect[iClient] = INVALID_HANDLE;
	}
}

public _Knives_GetUsedKnifeClassname(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	if(!g_iKnifeIndex[iClient] || g_iKnifeIndex[iClient] >= sizeof(g_szKnifeEnts))
		return false;
	
	SetNativeString(2, g_szKnifeEnts[g_iKnifeIndex[iClient]], GetNativeCell(3));
	return true;
}

public OnClientDisconnect_Post(iClient)
{
	TryCloseForwards(iClient);
}

public OnClientPutInServer(iClient)
{
	PlayerHooks(iClient);
}

public Action:OnKnifeSelect(iClient, iArgNum)
{
	if(g_bLibLoaded_SkillServerWeapons)
		return Plugin_Handled;
	
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_KnifeSelect(iClient);
	return Plugin_Handled;
}

DisplayMenu_KnifeSelect(iClient, iStartItem=0)
{
	if(!ClientCookies_HaveCookiesLoaded(iClient))
	{
		CPrintToChat(iClient, "{red}Unavailable, try again in a few seconds.");
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_KnifeSelect);
	SetMenuTitle(hMenu, "Knife Select");
	
	decl String:szInfo[4];
	for(new i=0; i<sizeof(g_szKnifeNames); i++)
	{
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, g_szKnifeNames[i]);
	}
	
	if(g_hForwardMenuBack[iClient] != INVALID_HANDLE)
		SetMenuExitBackButton(hMenu, true);
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		CPrintToChat(iClient, "{red}There are no knives to select.");
}

public MenuHandle_KnifeSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		if(g_hForwardMenuBack[iParam1] == INVALID_HANDLE)
		{
			TryCloseForwards(iParam1);
			return;
		}
		
		Call_StartForward(g_hForwardMenuBack[iParam1]);
		Call_PushCell(iParam1);
		Call_Finish();
		
		TryCloseForwards(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iKnifeIndex = StringToInt(szInfo);
	
	if(iKnifeIndex == g_iKnifeIndex[iParam1])
	{
		if(g_hForwardMenuSelect[iParam1] == INVALID_HANDLE)
			CPrintToChat(iParam1, "{olive}You will continue using the {yellow}%s {olive}knife.", g_szKnifeNames[iKnifeIndex]);
	}
	else
	{
		g_iKnifeIndex[iParam1] = iKnifeIndex;
		ClientCookies_SetCookie(iParam1, CC_TYPE_SPOOFED_KNIVES, iKnifeIndex);
		
		if(g_hForwardMenuSelect[iParam1] == INVALID_HANDLE)
			CPrintToChat(iParam1, "{olive}Giving the {yellow}%s {olive}knife next time you spawn.", g_szKnifeNames[iKnifeIndex]);
	}
	
	if(g_hForwardMenuSelect[iParam1] != INVALID_HANDLE)
	{
		Call_StartForward(g_hForwardMenuSelect[iParam1]);
		Call_PushCell(iParam1);
		Call_Finish();
		
		TryCloseForwards(iParam1);
		return;
	}
	
	TryCloseForwards(iParam1);
	DisplayMenu_KnifeSelect(iParam1, GetMenuSelectionPosition());
}

PlayerHooks(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	g_iKnifeIndex[iClient] = GetRandomKnifeIndex();
	SDKHook(iClient, SDKHook_WeaponEquip, OnWeaponEquip);
}

public OnWeaponEquip(iClient, iWeapon)
{
	if(!g_iKnifeIndex[iClient])
		return;
	
	if(iWeapon < 1 || !IsValidEntity(iWeapon))
		return;
	
	static String:szClassName[13];
	if(!GetEntityClassname(iWeapon, szClassName, sizeof(szClassName)))
		return;
	
	if(strlen(szClassName) < 12)
		return;
	
	szClassName[12] = '\x00';
	if(!StrEqual(szClassName[7], "knife") && !StrEqual(szClassName[7], "bayon"))
		return;
	
	new iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
	if(iWorldModel > 0)
	{
		SetEntProp(iWorldModel, Prop_Send, "m_nModelIndex", g_iModelIndex_WorldModels[g_iKnifeIndex[iClient]]);
		SetEntPropString(iWorldModel, Prop_Data, "m_ModelName", g_szWorldModels[g_iKnifeIndex[iClient]]);
	}
	
	SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", g_iItemDefinitionIndexes[g_iKnifeIndex[iClient]]);
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SPOOFED_KNIVES))
		g_iKnifeIndex[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_SPOOFED_KNIVES);
	else
		g_iKnifeIndex[iClient] = GetRandomKnifeIndex();
}

GetRandomKnifeIndex()
{
	return GetRandomInt(4, sizeof(g_szKnifeNames)-1);
}