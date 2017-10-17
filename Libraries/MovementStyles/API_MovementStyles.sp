#include <sourcemod>
#include <sdkhooks>
#include "../ClientCookies/client_cookies"
#include "movement_styles"

#undef REQUIRE_PLUGIN
#include "../../Mods/SpeedRuns/Includes/speed_runs_teleport"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Movement Styles";
new const String:PLUGIN_VERSION[] = "1.9";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage movement styles.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define INVALID_STYLE_ID		-1
#define MAX_STYLES				31

new g_iRegisteredBitMask;
new g_iDefaultBits;

new g_iStyleIDToIndex[MAX_STYLES+1] = {INVALID_STYLE_ID, ...};
new Handle:g_aStyles;
enum _:Style
{
	Style_ID,
	Style_Bit,
	String:Style_Name[MAX_STYLE_NAME_LENGTH],
	Handle:Style_ForwardActivated,
	Handle:Style_ForwardDeactivated,
	Style_Order
};

new Handle:g_hFwd_OnRegisterReady;
new Handle:g_hFwd_OnBitsChanged;
new Handle:g_hFwd_OnBitsChangedPost;
new Handle:g_hFwd_OnMenuBitChanged;

new g_iStyleBits[MAXPLAYERS+1];
new g_iStyleBitsRespawn[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("api_movement_styles_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aStyles = CreateArray(Style);
	g_hFwd_OnRegisterReady = CreateGlobalForward("MovementStyles_OnRegisterReady", ET_Ignore);
	g_hFwd_OnBitsChanged = CreateGlobalForward("MovementStyles_OnBitsChanged", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_hFwd_OnBitsChangedPost = CreateGlobalForward("MovementStyles_OnBitsChanged_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnMenuBitChanged = CreateGlobalForward("MovementStyles_OnMenuBitChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	
	RegConsoleCmd("sm_style", OnStylesSelect, "Opens the styles selection menu.");
	RegConsoleCmd("sm_styles", OnStylesSelect, "Opens the styles selection menu.");
	RegConsoleCmd("sm_mode", OnStylesSelect, "Opens the styles selection menu.");
}

public OnClientPutInServer(iClient)
{
	g_iStyleBits[iClient] = 0;
	g_iStyleBitsRespawn[iClient] = VerifyBitMask(g_iDefaultBits);
	
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	// Make sure we verify the mask so we only load bits that are a valid registered styles.
	if(ClientCookies_HasCookie(iClient, CC_TYPE_MOVEMENT_STYLE_BITS))
	{
		g_iStyleBitsRespawn[iClient] = VerifyBitMask(ClientCookies_GetCookie(iClient, CC_TYPE_MOVEMENT_STYLE_BITS));
		
#if !defined ALLOW_STYLE_COMBINATIONS
		// If we don't allow multiple style combinations we need to make sure the style bits being loaded doesn't contain multiple bits.
		new bool:bFoundAlready;
		for(new i=0; i<32; i++)
		{
			if(!(g_iStyleBitsRespawn[iClient] & (1<<i)))
				continue;
			
			if(!bFoundAlready)
			{
				bFoundAlready = true;
				continue;
			}
			
			// There are more than 1 bits set. Just set the style bits to 0.
			g_iStyleBitsRespawn[iClient] = 0;
			break;
		}
#endif
	}
	else
	{
		g_iStyleBitsRespawn[iClient] = VerifyBitMask(g_iDefaultBits);
	}
}

VerifyBitMask(iMaskToVerify)
{
	return (iMaskToVerify & g_iRegisteredBitMask);
}

public SpeedRunsTeleport_OnRestart(iClient)
{
	OnSpawnPost(iClient);
}

public SpeedRunsTeleport_OnSendToSpawn(iClient)
{
	OnSpawnPost(iClient);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	decl result;
	Call_StartForward(g_hFwd_OnBitsChanged);
	Call_PushCell(iClient);
	Call_PushCell(g_iStyleBits[iClient]);
	Call_PushCellRef(g_iStyleBitsRespawn[iClient]);
	Call_Finish(result);
	
	Call_StartForward(g_hFwd_OnBitsChangedPost);
	Call_PushCell(iClient);
	Call_PushCell(g_iStyleBits[iClient]);
	Call_PushCell(g_iStyleBitsRespawn[iClient]);
	Call_Finish(result);
	
	if(g_iStyleBits[iClient] == g_iStyleBitsRespawn[iClient])
		return;
	
	// Verify since the respawn bits could have changed since it's passed by ref.
	g_iStyleBitsRespawn[iClient] = VerifyBitMask(g_iStyleBitsRespawn[iClient]);
	
	decl eStyle[Style];
	for(new i=0; i<GetArraySize(g_aStyles); i++)
	{
		GetArrayArray(g_aStyles, i, eStyle);
		
		if(eStyle[Style_ID] == STYLE_ID_NONE)
			continue;
		
		if((g_iStyleBits[iClient] & eStyle[Style_Bit]) && !(g_iStyleBitsRespawn[iClient] & eStyle[Style_Bit]))
		{
			Forward_ActivatedDeactivated(iClient, eStyle[Style_ForwardDeactivated]);
		}
		else if(!(g_iStyleBits[iClient] & eStyle[Style_Bit]) && (g_iStyleBitsRespawn[iClient] & eStyle[Style_Bit]))
		{
			Forward_ActivatedDeactivated(iClient, eStyle[Style_ForwardActivated]);
		}
	}
	
	g_iStyleBits[iClient] = g_iStyleBitsRespawn[iClient];
}

Forward_ActivatedDeactivated(iClient, Handle:hForward)
{
	if(hForward == INVALID_HANDLE)
		return;
	
	decl result;
	Call_StartForward(hForward);
	Call_PushCell(iClient);
	Call_Finish(result);
}

public OnMapStart()
{
	g_iRegisteredBitMask = 0;
	
	decl eStyle[Style];
	for(new i=0; i<GetArraySize(g_aStyles); i++)
	{
		GetArrayArray(g_aStyles, i, eStyle);
		
		if(eStyle[Style_ForwardActivated] != INVALID_HANDLE)
			CloseHandle(eStyle[Style_ForwardActivated]);
		
		if(eStyle[Style_ForwardDeactivated] != INVALID_HANDLE)
			CloseHandle(eStyle[Style_ForwardDeactivated]);
	}
	
	ClearArray(g_aStyles);
	CreateStyleNone();
	
	g_iDefaultBits = 0;
	
	new result;
	Call_StartForward(g_hFwd_OnRegisterReady);
	Call_Finish(result);
	
	SortStyles();
}

SortStyles()
{
	new iArraySize = GetArraySize(g_aStyles);
	decl iOrder, eStyle[Style], j, iIndex, iID;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aStyles, i, eStyle);
		iOrder = eStyle[Style_Order];
		iIndex = 0;
		iID = eStyle[Style_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aStyles, j, eStyle);
			
			if(iOrder < eStyle[Style_Order])
				continue;
			
			iIndex = j;
			iOrder = eStyle[Style_Order];
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aStyles, i, iIndex);
		
		// We must swap the IDtoIndex too.
		g_iStyleIDToIndex[eStyle[Style_ID]] = i;
		g_iStyleIDToIndex[iID] = iIndex;
	}
}

CreateStyleNone()
{
	decl eStyle[Style];
	eStyle[Style_ID] = STYLE_ID_NONE;
	eStyle[Style_Bit] = STYLE_BIT_NONE;
	strcopy(eStyle[Style_Name], MAX_STYLE_NAME_LENGTH, "None");
	eStyle[Style_ForwardActivated] = INVALID_HANDLE;
	eStyle[Style_ForwardDeactivated] = INVALID_HANDLE;
	eStyle[Style_Order] = -1;
	
	g_iStyleIDToIndex[STYLE_ID_NONE] = PushArrayArray(g_aStyles, eStyle);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("movement_styles");
	CreateNative("MovementStyles_RegisterStyle", _MovementStyles_RegisterStyle);
	CreateNative("MovementStyles_GetStyleBits", _MovementStyles_GetStyleBits);
	CreateNative("MovementStyles_GetStyleNames", _MovementStyles_GetStyleNames);
	CreateNative("MovementStyles_GetTotalStylesRegistered", _MovementStyles_GetTotalStylesRegistered);
	CreateNative("MovementStyles_SetDefaultBits", _MovementStyles_SetDefaultBits);
	
	return APLRes_Success;
}

public _MovementStyles_SetDefaultBits(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters for MovementStyles_SetDefaultBits()");
		return;
	}
	
	g_iDefaultBits = GetNativeCell(1);
}

public _MovementStyles_GetTotalStylesRegistered(Handle:hPlugin, iNumParams)
{
	return GetArraySize(g_aStyles);
}

public _MovementStyles_GetStyleBits(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters for MovementStyles_GetStyleBits()");
		return VerifyBitMask(g_iDefaultBits);
	}
	
	new iClient = GetNativeCell(1);
	if(!(1 <= iClient <= MaxClients))
		return VerifyBitMask(g_iDefaultBits);
	
	return g_iStyleBits[iClient];
}

public _MovementStyles_GetStyleNames(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters for MovementStyles_GetStyleNames()");
		return false;
	}
	
	new Handle:hStyleNames = GetNativeCell(2);
	if(hStyleNames == INVALID_HANDLE)
		return false;
	
	new iClient = GetNativeCell(1);
	
	decl eStyle[Style];
	for(new i=0; i<GetArraySize(g_aStyles); i++)
	{
		GetArrayArray(g_aStyles, i, eStyle);
		
		if(eStyle[Style_ID] == STYLE_ID_NONE)
			continue;
		
		if(!(g_iStyleBits[iClient] & eStyle[Style_Bit]))
			continue;
		
		PushArrayString(hStyleNames, eStyle[Style_Name]);
	}
	
	if(!GetArraySize(hStyleNames))
		return false;
	
	return true;
}

public _MovementStyles_RegisterStyle(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 5 || iNumParams > 6)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iStyleID = GetNativeCell(1);
	
	decl eStyle[Style];
	for(new i=0; i<GetArraySize(g_aStyles); i++)
	{
		GetArrayArray(g_aStyles, i, eStyle);
		if(eStyle[Style_ID] != iStyleID)
			continue;
		
		RemoveFromArray(g_aStyles, i);
		break;
	}
	
	eStyle[Style_ID] = iStyleID;
	eStyle[Style_Bit] = GetNativeCell(2);
	g_iRegisteredBitMask |= eStyle[Style_Bit];
	
	if(iNumParams >= 6)
	{
		eStyle[Style_Order] = GetNativeCell(6);
		
		if(eStyle[Style_Order] < 0)
			eStyle[Style_Order] = 0;
	}
	else
		eStyle[Style_Order] = 0;
	
	decl String:szStyleName[MAX_STYLE_NAME_LENGTH];
	GetNativeString(3, szStyleName, sizeof(szStyleName));
	strcopy(eStyle[Style_Name], MAX_STYLE_NAME_LENGTH, szStyleName);
	
	// Activated callback.
	new Function:callback = GetNativeCell(4);
	if(callback != INVALID_FUNCTION)
	{
		eStyle[Style_ForwardActivated] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(eStyle[Style_ForwardActivated], hPlugin, callback);
	}
	else
	{
		eStyle[Style_ForwardActivated] = INVALID_HANDLE;
	}
	
	// Deactivated callback.
	callback = GetNativeCell(5);
	if(callback != INVALID_FUNCTION)
	{
		eStyle[Style_ForwardDeactivated] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(eStyle[Style_ForwardDeactivated], hPlugin, callback);
	}
	else
	{
		eStyle[Style_ForwardDeactivated] = INVALID_HANDLE;
	}
	
	g_iStyleIDToIndex[iStyleID] = PushArrayArray(g_aStyles, eStyle);
	
	return true;
}

public Action:OnStylesSelect(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetArraySize(g_aStyles) <= 1)
	{
		PrintToChat(iClient, "[SM] There are no styles to select.");
		return Plugin_Handled;
	}
	
	DisplayMenu_StylesSelect(iClient);
	return Plugin_Handled;
}

DisplayMenu_StylesSelect(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_StylesSelect);
	SetMenuTitle(hMenu, "Select your styles");
	
	decl eStyle[Style], String:szInfo[4], String:szBuffer[MAX_STYLE_NAME_LENGTH+24];
	for(new i=0; i<GetArraySize(g_aStyles); i++)
	{
		GetArrayArray(g_aStyles, i, eStyle);
		
		if(eStyle[Style_ID] == STYLE_ID_NONE)
		{
			strcopy(szBuffer, sizeof(szBuffer), "Disable All");
		}
		else
		{
			Format(szBuffer, sizeof(szBuffer), "%s %s%s", eStyle[Style_Name], (g_iStyleBitsRespawn[iClient] & eStyle[Style_Bit]) ? "[ON]" : "[OFF]", ((g_iStyleBits[iClient] & eStyle[Style_Bit]) != (g_iStyleBitsRespawn[iClient] & eStyle[Style_Bit])) ? " *Respawn*" : "");
		}
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
		PrintToChat(iClient, "[SM] There are no styles to select.");
}

public MenuHandle_StylesSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl eStyle[Style], String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	GetArrayArray(g_aStyles, StringToInt(szInfo), eStyle);
	
	ToggleStyleBit(iParam1, eStyle[Style_Bit]);
	
	PrintToChat(iParam1, "[SM] Styles will update when you respawn.");
	DisplayMenu_StylesSelect(iParam1, GetMenuSelectionPosition());
}

ToggleStyleBit(iClient, iBit)
{
	new result, iExtraBitsToForceOn;
	Call_StartForward(g_hFwd_OnMenuBitChanged);
	Call_PushCell(iClient);
	Call_PushCell(iBit);
	Call_PushCell((iBit && (g_iStyleBitsRespawn[iClient] & iBit)) ? false : true);
	Call_PushCellRef(iExtraBitsToForceOn);
	Call_Finish(result);
	
	if(result > _:Plugin_Continue)
		return;
	
	iExtraBitsToForceOn = VerifyBitMask(iExtraBitsToForceOn);
	
	if(!iBit)
	{
		g_iStyleBitsRespawn[iClient] = 0;
		ClientCookies_SetCookie(iClient, CC_TYPE_MOVEMENT_STYLE_BITS, g_iStyleBitsRespawn[iClient]);
		
		// Don't set the menu visual only bits in the cookie.
		g_iStyleBitsRespawn[iClient] |= iExtraBitsToForceOn;
		
		return;
	}
	
#if defined ALLOW_STYLE_COMBINATIONS
	g_iStyleBitsRespawn[iClient] ^= iBit; // This allows multiple styles to be selected at once.
#else
	// This allows only 1 style to be selected at once.
	if(g_iStyleBitsRespawn[iClient] & iBit)
		g_iStyleBitsRespawn[iClient] = 0;
	else
		g_iStyleBitsRespawn[iClient] = iBit;
#endif
	
	ClientCookies_SetCookie(iClient, CC_TYPE_MOVEMENT_STYLE_BITS, g_iStyleBitsRespawn[iClient]);
	
	// Don't set the menu visual only bits in the cookie.
	g_iStyleBitsRespawn[iClient] |= iExtraBitsToForceOn;
}