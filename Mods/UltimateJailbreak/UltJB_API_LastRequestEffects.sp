#include <sourcemod>
#include <hls_color_chat>
#include "Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Last Request Effects";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The LR effects plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

const MAX_EFFECTS = 128;
const INVALID_EFFECT_INDEX = -1;

new Handle:g_aEffects;
new g_iEffectIDToIndex[MAX_EFFECTS+1];
enum _:Effect
{
	Effect_ID,
	String:Effect_Name[EFFECT_MAX_NAME_LENGTH],
	Handle:Effect_ForwardStart,
	Handle:Effect_ForwardStop,
	Float:Effect_DefaultData
};

new Handle:g_hFwd_OnRegisterReady;
new Handle:g_hFwd_OnRegisterComplete;
new Handle:g_hFwd_OnEffectSelectedSuccess[MAXPLAYERS+1];
new Handle:g_hFwd_OnEffectSelectedFailed[MAXPLAYERS+1];

new Handle:g_hMenu_EffectSelection[MAXPLAYERS+1];
new Handle:g_hTimer_EffectSelection[MAXPLAYERS+1];

new bool:g_bIsInEffect[MAXPLAYERS+1][MAX_EFFECTS+1];

new Handle:cvar_select_effect_time;


public OnPluginStart()
{
	CreateConVar("ultjb_lr_effects_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_select_effect_time = CreateConVar("ultjb_select_effect_time", "15", "The number of seconds a player has to select their effect.", _, true, 1.0);
	
	g_aEffects = CreateArray(Effect);
	g_hFwd_OnRegisterReady = CreateGlobalForward("UltJB_Effects_OnRegisterReady", ET_Ignore);
	g_hFwd_OnRegisterComplete = CreateGlobalForward("UltJB_Effects_OnRegisterComplete", ET_Ignore);
}

public OnClientDisconnect(iClient)
{
	decl eEffect[Effect];
	
	for(new i=0; i<GetArraySize(g_aEffects); i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		UltJB_Effects_StopEffect(iClient, eEffect[Effect_ID]);
	}
}

public OnMapStart()
{
	decl i;
	for(i=0; i<sizeof(g_iEffectIDToIndex); i++)
		g_iEffectIDToIndex[i] = INVALID_EFFECT_INDEX;
	
	decl eEffect[Effect];
	for(i=0; i<GetArraySize(g_aEffects); i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		
		if(eEffect[Effect_ForwardStart] != INVALID_HANDLE)
			CloseHandle(eEffect[Effect_ForwardStart]);
		
		if(eEffect[Effect_ForwardStop] != INVALID_HANDLE)
			CloseHandle(eEffect[Effect_ForwardStop]);
	}
	
	ClearArray(g_aEffects);
	
	Call_StartForward(g_hFwd_OnRegisterReady);
	Call_Finish();
	
	SortEffectsByName();
	
	Call_StartForward(g_hFwd_OnRegisterComplete);
	Call_Finish();
}

SortEffectsByName()
{
	new iArraySize = GetArraySize(g_aEffects);
	decl String:szName[EFFECT_MAX_NAME_LENGTH], eEffect[Effect], j, iIndex; //iID;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		strcopy(szName, sizeof(szName), eEffect[Effect_Name]);
		iIndex = 0;
		//iID = eEffect[Effect_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aEffects, j, eEffect);
			if(strcmp(szName, eEffect[Effect_Name], false) < 0)
				continue;
			
			iIndex = j;
			strcopy(szName, sizeof(szName), eEffect[Effect_Name]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aEffects, i, iIndex);
	}
	
	for(new i=0; i<iArraySize;i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		g_iEffectIDToIndex[eEffect[Effect_ID]] = i;
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_lr_effects");
	
	CreateNative("UltJB_Effects_StartEffect", _UltJB_Effects_StartEffect);
	CreateNative("UltJB_Effects_StopEffect", _UltJB_Effects_StopEffect);
	CreateNative("UltJB_Effects_RegisterEffect", _UltJB_Effects_RegisterEffect);
	CreateNative("UltJB_Effects_CancelEffectSelection", _UltJB_Effects_CancelEffectSelection);
	CreateNative("UltJB_Effects_DisplaySelectionMenu", _UltJB_Effects_DisplaySelectionMenu);
	CreateNative("UltJB_Effects_GetEffectID", _UltJB_Effects_GetEffectID);
	CreateNative("UltJB_Effects_GetEffectDefaultData", _UltJB_Effects_GetEffectDefaultData);
	
	return APLRes_Success;
}

public _UltJB_Effects_GetEffectDefaultData(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return _:0.0;
	}
	
	new iEffectID = GetNativeCell(1);
	if(g_iEffectIDToIndex[iEffectID] == INVALID_EFFECT_INDEX)
		return _:0.0;
	
	decl eEffect[Effect];
	GetArrayArray(g_aEffects, g_iEffectIDToIndex[iEffectID], eEffect);
	
	return _:eEffect[Effect_DefaultData];
}

public _UltJB_Effects_GetEffectID(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iLength;
	if(GetNativeStringLength(1, iLength) != SP_ERROR_NONE)
		return 0;
	
	iLength++;
	decl String:szName[iLength];
	GetNativeString(1, szName, iLength);
	
	decl eEffect[Effect];
	for(new i=0; i<GetArraySize(g_aEffects); i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		
		if(StrEqual(szName, eEffect[Effect_Name], false))
			return eEffect[Effect_ID];
	}
	
	return 0;
}

public _UltJB_Effects_StartEffect(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 2 || iNumParams > 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	if(!iClient)
		return false;
	
	new any:data;
	if(iNumParams >= 3)
		data = GetNativeCell(3);
	
	if(!StartEffect(iClient, GetNativeCell(2), data))
		return false;
	
	return true;
}

bool:StartEffect(iClient, iEffectID, any:data)
{
	if(iEffectID < 1)
	{
		LogError("Effect with ID %i trying to start.", iEffectID);
		return false;
	}
	
	if(g_bIsInEffect[iClient][iEffectID])
	{
		PrintToChat(iClient, "[SM] You are already in this effect.");
		return false;
	}
	
	if(g_iEffectIDToIndex[iEffectID] == INVALID_EFFECT_INDEX)
		return false;
	
	decl eEffect[Effect];
	GetArrayArray(g_aEffects, g_iEffectIDToIndex[iEffectID], eEffect);
	
	Call_StartForward(eEffect[Effect_ForwardStart]);
	Call_PushCell(iClient);
	Call_PushCell(data);
	
	if(Call_Finish() != SP_ERROR_NONE)
	{
		PrintToChat(iClient, "[SM] There was an error starting effect %s.", eEffect[Effect_Name]);
		return false;
	}
	
	g_bIsInEffect[iClient][iEffectID] = true;
	
	return true;
}

public _UltJB_Effects_StopEffect(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	if(!iClient)
		return false;
	
	if(!StopEffect(iClient, GetNativeCell(2)))
		return false;
	
	return true;
}

bool:StopEffect(iClient, iEffectID)
{
	if(iEffectID < 1)
	{
		LogError("Effect with ID %i trying to stop.", iEffectID);
		return false;
	}
	
	if(!g_bIsInEffect[iClient][iEffectID])
	{
		if(IsClientInGame(iClient))
			PrintToChat(iClient, "[SM] You are not in this effect.");
		
		return false;
	}
	
	if(g_iEffectIDToIndex[iEffectID] == INVALID_EFFECT_INDEX)
		return false;
	
	decl eEffect[Effect];
	GetArrayArray(g_aEffects, g_iEffectIDToIndex[iEffectID], eEffect);
	
	Call_StartForward(eEffect[Effect_ForwardStop]);
	Call_PushCell(iClient);
	
	if(Call_Finish() != SP_ERROR_NONE)
	{
		if(IsClientInGame(iClient))
			PrintToChat(iClient, "[SM] There was an error stopping effect %s.", eEffect[Effect_Name]);
		
		return false;
	}
	
	g_bIsInEffect[iClient][iEffectID] = false;
	
	return true;
}

public _UltJB_Effects_RegisterEffect(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 4)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iLength;
	if(GetNativeStringLength(1, iLength) != SP_ERROR_NONE)
		return 0;
	
	iLength++;
	decl String:szName[iLength];
	GetNativeString(1, szName, iLength);
	
	decl eEffect[Effect];
	new iArraySize = GetArraySize(g_aEffects);
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		
		if(StrEqual(szName, eEffect[Effect_Name], false))
		{
			LogError("Last request effect [%s] is already registered.", szName);
			return 0;
		}
	}
	
	if(iArraySize >= MAX_EFFECTS)
	{
		LogError("Cannot add [%s]. Please increase MAX_EFFECTS and recompile.", szName);
		return 0;
	}
	
	eEffect[Effect_ID] = iArraySize + 1;
	strcopy(eEffect[Effect_Name], EFFECT_MAX_NAME_LENGTH, szName);
	
	new Function:callback = GetNativeCell(2);
	if(callback != INVALID_FUNCTION)
	{
		eEffect[Effect_ForwardStart] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
		AddToForward(eEffect[Effect_ForwardStart], hPlugin, callback);
	}
	else
	{
		eEffect[Effect_ForwardStart] = INVALID_HANDLE;
	}
	
	callback = GetNativeCell(3);
	if(callback != INVALID_FUNCTION)
	{
		eEffect[Effect_ForwardStop] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(eEffect[Effect_ForwardStop], hPlugin, callback);
	}
	else
	{
		eEffect[Effect_ForwardStop] = INVALID_HANDLE;
	}
	
	eEffect[Effect_DefaultData] = GetNativeCell(4);
	
	g_iEffectIDToIndex[eEffect[Effect_ID]] = PushArrayArray(g_aEffects, eEffect);
	
	return eEffect[Effect_ID];
}

public _UltJB_Effects_DisplaySelectionMenu(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
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
	
	if(g_hFwd_OnEffectSelectedSuccess[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hFwd_OnEffectSelectedSuccess[iClient]);
		g_hFwd_OnEffectSelectedSuccess[iClient] = INVALID_HANDLE;
	}
	
	if(g_hFwd_OnEffectSelectedFailed[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hFwd_OnEffectSelectedFailed[iClient]);
		g_hFwd_OnEffectSelectedFailed[iClient] = INVALID_HANDLE;
	}
	
	g_hFwd_OnEffectSelectedSuccess[iClient] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
	AddToForward(g_hFwd_OnEffectSelectedSuccess[iClient], hPlugin, success_callback);
	
	g_hFwd_OnEffectSelectedFailed[iClient] = CreateForward(ET_Ignore, Param_Cell);
	AddToForward(g_hFwd_OnEffectSelectedFailed[iClient], hPlugin, failed_callback);
	
	g_hMenu_EffectSelection[iClient] = DisplayMenu_EffectSelection(iClient);
	if(g_hMenu_EffectSelection[iClient] == INVALID_HANDLE)
	{
		Forward_OnEffectSelectedFailed(iClient);
		return false;
	}
	
	StopTimer_EffectSelection(iClient);
	g_hTimer_EffectSelection[iClient] = CreateTimer(GetConVarFloat(cvar_select_effect_time), Timer_EffectSelection, GetClientSerial(iClient));
	
	return true;
}

public _UltJB_Effects_CancelEffectSelection(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	if(!iClient)
		return false;
	
	StopTimer_EffectSelection(iClient);
	
	if(g_hMenu_EffectSelection[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_EffectSelection[iClient]);
	
	return true;
}

public Action:Timer_EffectSelection(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
	{
		InvalidateHandleArrayIndex(hTimer, g_hTimer_EffectSelection, sizeof(g_hTimer_EffectSelection));
		return;
	}
	
	g_hTimer_EffectSelection[iClient] = INVALID_HANDLE;
	
	if(g_hMenu_EffectSelection[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_EffectSelection[iClient]);
	
	PrintToChat(iClient, "[SM] Selecting a random effect.");
	SelectRandomEffect(iClient);
}

StopTimer_EffectSelection(iClient)
{
	if(g_hTimer_EffectSelection[iClient] == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hTimer_EffectSelection[iClient]);
	g_hTimer_EffectSelection[iClient] = INVALID_HANDLE;
}

Forward_OnEffectSelectedSuccess(iClient, iEffectID)
{
	if(g_hFwd_OnEffectSelectedSuccess[iClient] == INVALID_HANDLE)
		return;
	
	Call_StartForward(g_hFwd_OnEffectSelectedSuccess[iClient]);
	Call_PushCell(iClient);
	Call_PushCell(iEffectID);
	if(Call_Finish() != SP_ERROR_NONE)
		LogError("Error calling effect selection success.");
}

Forward_OnEffectSelectedFailed(iClient)
{
	if(g_hFwd_OnEffectSelectedFailed[iClient] == INVALID_HANDLE)
		return;
	
	Call_StartForward(g_hFwd_OnEffectSelectedFailed[iClient]);
	Call_PushCell(iClient);
	if(Call_Finish() != SP_ERROR_NONE)
		LogError("Error calling effect selection failed.");
}

Handle:DisplayMenu_EffectSelection(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EffectSelection);
	
	SetMenuTitle(hMenu, "Select an effect");
	SetMenuExitButton(hMenu, false);
	
	AddMenuItem(hMenu, "0", "No effect");
	
	decl String:szInfo[4], eEffect[Effect];
	for(new i=0; i<GetArraySize(g_aEffects); i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		
		IntToString(eEffect[Effect_ID], szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, eEffect[Effect_Name]);
	}
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There are no effects to select.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

public MenuHandle_EffectSelection(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_EffectSelection, sizeof(g_hMenu_EffectSelection));
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	StopTimer_EffectSelection(iParam1);
	SelectEffect(iParam1, StringToInt(szInfo));
}

SelectEffect(iClient, iEffectID)
{
	decl eEffect[Effect];
	GetArrayArray(g_aEffects, g_iEffectIDToIndex[iEffectID], eEffect);
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}selected effect: {purple}%s{olive}.", iClient, eEffect[Effect_Name]);
	
	Forward_OnEffectSelectedSuccess(iClient, iEffectID);
}

SelectRandomEffect(iClient)
{
	new iNumEffects;
	decl iEffects[MAX_EFFECTS];
	
	decl eEffect[Effect];
	for(new i=0; i<GetArraySize(g_aEffects); i++)
	{
		GetArrayArray(g_aEffects, i, eEffect);
		iEffects[iNumEffects++] = eEffect[Effect_ID];
	}
	
	if(!iNumEffects)
	{
		PrintToChat(iClient, "[SM] There was an error selecting a random effect.");
		Forward_OnEffectSelectedFailed(iClient);
		return;
	}
	
	SelectEffect(iClient, iEffects[GetRandomInt(0, iNumEffects-1)]);
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