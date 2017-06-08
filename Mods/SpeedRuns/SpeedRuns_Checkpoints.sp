#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include "Includes/speed_runs"
#include "Includes/speed_runs_teleport"
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Libraries/ClientCookies/client_cookies"
#include "../../Libraries/ZoneManager/zone_manager"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Checkpoints";
new const String:PLUGIN_VERSION[] = "2.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed run checkpoint plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define STAGE_ZERO_TYPE_OUT_OF_RUN		false
#define STAGE_ZERO_TYPE_BETWEEN_STAGES	true

new g_iCheckpointsSaved[MAXPLAYERS+1][MAX_STAGES+1];
new g_iCheckpointsUsed[MAXPLAYERS+1][MAX_STAGES+1];

new Handle:g_aStageCheckpoints[MAXPLAYERS+1][MAX_STAGES+1];
enum _:Checkpoint
{
	CP_StageNumber,
	bool:CP_StageZeroType,
	bool:CP_SetCurrentTotal,
	bool:CP_SetCurrentStage,
	
	String:CP_TargetName[MAX_ZONE_DATA_STRING_LENGTH],
	Float:CP_Origin[3],
	Float:CP_Angles[3],
	Float:CP_Velocity[3],
	Float:CP_BaseVelocity[3],
	Float:CP_FallVelocity,
	Float:CP_VelocityModifier,
	bool:CP_Ducked,
	bool:CP_Ducking,
	Float:CP_DuckAmount,
	Float:CP_DuckSpeed,
	Float:CP_VecViewOffset2,
	Float:CP_VecMaxs[3],
	MoveType:CP_MoveType,
	CP_Flags
};

enum
{
	CP_MENU_SAVE_POSITION = 1,
	CP_MENU_LOAD_LAST_SAVED,
	CP_MENU_LOAD_PREVIOUS,
	CP_MENU_LOAD_NEXT,
	CP_MENU_UNDO_LOADS,
	CP_MENU_LOAD_SPECIFIC,
	CP_MENU_MAINTAIN_ANGLES,
	CP_MENU_MAINTAIN_VELOCITY
};

enum CancelRunType
{
	CANCEL_RUN_NONE	= 0,
	CANCEL_RUN_OLD_TOTAL,
	CANCEL_RUN_OLD_STAGE,
	CANCEL_RUN_DIFF_STAGE,
	CANCEL_RUN_BETWEEN_STAGE,
	CANCEL_RUN_OUT_OF_RUN,
	CANCEL_RUN_CP_NOT_USABLE,
	CANCEL_RUN_VELOCITY_NOT_USABLE
};

new g_iLastSavedArrayIndex[MAXPLAYERS+1] = -1;
new g_iLastSavedStageNumber[MAXPLAYERS+1] = -1;

new g_iLastVisitedArrayIndex[MAXPLAYERS+1] = -1;
new g_iLastVisitedStageNumber[MAXPLAYERS+1] = -1;

#define BLOCK_STAGE_START_DELAY	0.2
new Float:g_fBlockStageStartDelay[MAXPLAYERS+1];

new bool:g_bCanUndoLoads[MAXPLAYERS+1];
new Float:g_fBeforeLoadOrigin[MAXPLAYERS+1][3];
new Float:g_fBeforeLoadAngles[MAXPLAYERS+1][3];

new g_iCheckpointBits[MAXPLAYERS+1];
#define CP_BITS_NONE			0
#define CP_BITS_USE_ANGLES		(1<<0)
#define CP_BITS_USE_VELOCITY	(1<<1)
#define CP_BITS_USE_ALL			CP_BITS_USE_ANGLES | CP_BITS_USE_VELOCITY

enum CancelChoice
{
	CANCEL_CHOICE_WARN_EVERYTIME = 1,
	CANCEL_CHOICE_NOWARN_MINUTES,
	CANCEL_CHOICE_NOWARN_MAP_DURATION
};

#define NOWARN_WAIT_TIME	300

new CancelChoice:g_iCancelChoice[MAXPLAYERS+1];
new Float:g_fCancelChoiceTimeStart[MAXPLAYERS+1];

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("speed_runs_checkpoint_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_save", OnSave);
	RegConsoleCmd("sm_cp", OnSave);
	RegConsoleCmd("sm_checkpoint", OnSave);
	
	RegConsoleCmd("sm_load", OnLoad);
	RegConsoleCmd("sm_gocp", OnLoad);
	RegConsoleCmd("sm_gocheck", OnLoad);
	
	RegConsoleCmd("sm_nextcp", OnNext);
	
	RegConsoleCmd("sm_prevcp", OnPrev);
	RegConsoleCmd("sm_stuck", OnPrev);
	RegConsoleCmd("sm_unstuck", OnPrev);
	
	RegConsoleCmd("sm_undo", OnUndo);
	
	RegConsoleCmd("sm_menu", OnCheckpointMenu);
	RegConsoleCmd("sm_cpmenu", OnCheckpointMenu);
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

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("speed_runs_checkpoints");
	
	CreateNative("SpeedRunsCheckpoints_GetCountSaved", _SpeedRunsCheckpoints_GetCountSaved);
	CreateNative("SpeedRunsCheckpoints_GetCountUsed", _SpeedRunsCheckpoints_GetCountUsed);
	
	CreateNative("SpeedRunsCheckpoints_AreUsableDuringSpeedRun", _SpeedRunsCheckpoints_AreUsableDuringSpeedRun);
	
	return APLRes_Success;
}

public _SpeedRunsCheckpoints_AreUsableDuringSpeedRun(Handle:hPlugin, iNumParams)
{
	return AreUsableDuringSpeedRun();
}

public _SpeedRunsCheckpoints_GetCountSaved(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters SpeedRunsCheckpoints_GetCount");
		return -2;
	}
	
	return g_iCheckpointsSaved[GetNativeCell(1)][GetNativeCell(2)];
}

public _SpeedRunsCheckpoints_GetCountUsed(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters SpeedRunsCheckpoints_GetCount");
		return -2;
	}
	
	return g_iCheckpointsUsed[GetNativeCell(1)][GetNativeCell(2)];
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	g_iCancelChoice[iClient] = CANCEL_CHOICE_WARN_EVERYTIME;
	
	if(AreUsableDuringSpeedRun())
		g_iCheckpointBits[iClient] = CP_BITS_USE_ANGLES;
	else
		g_iCheckpointBits[iClient] = CP_BITS_USE_ALL;
}

// Don't load the clients checkpoint bits. It's better to just have g_iCheckpointBits reset every client reconnect.
/*
public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SPEEDRUNS_CHECKPOINT_BITS))
	{
		g_iCheckpointBits[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_SPEEDRUNS_CHECKPOINT_BITS);
	}
	else
	{
		if(AreUsableDuringSpeedRun())
			g_iCheckpointBits[iClient] = CP_BITS_USE_ANGLES;
		else
			g_iCheckpointBits[iClient] = CP_BITS_USE_ALL;
	}
}
*/

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	if(AreUsableDuringSpeedRun())
		DisplayMenu_Checkpoint(iClient);
}

public OnClientConnected(iClient)
{
	g_fBlockStageStartDelay[iClient] = 0.0;
	
	ClearLastSaved(iClient);
	ClearLastVisited(iClient);
}

public OnClientDisconnect_Post(iClient)
{
	ClearCheckpoints(iClient);
	g_bCanUndoLoads[iClient] = false;
}

ClearCheckpoints(iClient)
{
	for(new i=0; i<sizeof(g_aStageCheckpoints[]); i++)
	{
		if(g_aStageCheckpoints[iClient][i] == INVALID_HANDLE)
			continue;
		
		CloseHandle(g_aStageCheckpoints[iClient][i]);
		g_aStageCheckpoints[iClient][i] = INVALID_HANDLE;
	}
	
	ClearLastSaved(iClient);
	ClearLastVisited(iClient);
}

ClearLastSaved(iClient)
{
	g_iLastSavedArrayIndex[iClient] = -1;
	g_iLastSavedStageNumber[iClient] = -1;
}

ClearLastVisited(iClient)
{
	g_iLastVisitedArrayIndex[iClient] = -1;
	g_iLastVisitedStageNumber[iClient] = -1;
}

public Action:SpeedRuns_OnStageStarted_Pre(iClient, iStageNumber, iStyleBits)
{
	if(g_fBlockStageStartDelay[iClient] >= GetGameTime())
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public SpeedRuns_OnStageStarted_Post(iClient, iStageNumber, iStyleBits)
{
	g_bCanUndoLoads[iClient] = false;
	
	if(iStageNumber == 1)
	{
		UncurrentTotalCheckpoints(iClient);
		
		g_iCheckpointsSaved[iClient][0] = 0;
		g_iCheckpointsUsed[iClient][0] = 0;
		
		g_iCheckpointsSaved[iClient][iStageNumber] = 0;
		g_iCheckpointsUsed[iClient][iStageNumber] = 0;
	}
	else
	{
		UncurrentStageCheckpoints(iClient, iStageNumber);
		
		g_iCheckpointsSaved[iClient][iStageNumber] = 0;
		g_iCheckpointsUsed[iClient][iStageNumber] = 0;
	}
}

UncurrentStageCheckpoints(iClient, iStageNumber)
{
	if(g_aStageCheckpoints[iClient][iStageNumber] == INVALID_HANDLE)
		return;
	
	decl eCheckpoint[Checkpoint];
	for(new i=0; i<GetArraySize(g_aStageCheckpoints[iClient][iStageNumber]); i++)
	{
		GetArrayArray(g_aStageCheckpoints[iClient][iStageNumber], i, eCheckpoint);
		eCheckpoint[CP_SetCurrentStage] = false;
		SetArrayArray(g_aStageCheckpoints[iClient][iStageNumber], i, eCheckpoint);
	}
}

UncurrentTotalCheckpoints(iClient)
{
	decl j, eCheckpoint[Checkpoint];
	for(new i=0; i<sizeof(g_aStageCheckpoints[]); i++)
	{
		if(g_aStageCheckpoints[iClient][i] == INVALID_HANDLE)
			continue;
		
		for(j=0; j<GetArraySize(g_aStageCheckpoints[iClient][i]); j++)
		{
			GetArrayArray(g_aStageCheckpoints[iClient][i], j, eCheckpoint);
			eCheckpoint[CP_SetCurrentStage] = false;
			eCheckpoint[CP_SetCurrentTotal] = false;
			SetArrayArray(g_aStageCheckpoints[iClient][i], j, eCheckpoint);
		}
	}
}

public Action:OnSave(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	SavePosition(iClient);
	return Plugin_Handled;
}

public Action:OnLoad(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	LoadLastSavedOrUsed(iClient);
	return Plugin_Handled;
}

public Action:OnPrev(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	LoadPrevious(iClient);
	return Plugin_Handled;
}

public Action:OnNext(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	LoadNext(iClient);
	return Plugin_Handled;
}

public Action:OnUndo(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	UndoLoads(iClient);
	return Plugin_Handled;
}

public Action:OnCheckpointMenu(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_Checkpoint(iClient);
	return Plugin_Handled;
}

DisplayMenu_Checkpoint(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Checkpoint);
	SetMenuTitle(hMenu, "Checkpoint Menu");
	
	decl String:szInfo[4];
	
	IntToString(CP_MENU_SAVE_POSITION, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Save position");
	
	IntToString(CP_MENU_LOAD_LAST_SAVED, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Load last saved/used", (g_iLastSavedArrayIndex[iClient] == -1 && g_iLastVisitedArrayIndex[iClient] == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	IntToString(CP_MENU_LOAD_PREVIOUS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Load previous", (g_iLastVisitedArrayIndex[iClient] < 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	IntToString(CP_MENU_LOAD_NEXT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Load next", (g_iLastVisitedArrayIndex[iClient] == -1 || g_iLastVisitedArrayIndex[iClient] >= GetArraySize(g_aStageCheckpoints[iClient][g_iLastVisitedStageNumber[iClient]]) - 1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	IntToString(CP_MENU_UNDO_LOADS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Undo last load", g_bCanUndoLoads[iClient] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	IntToString(CP_MENU_LOAD_SPECIFIC, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Load specific");
	
	IntToString(CP_MENU_MAINTAIN_ANGLES, szInfo, sizeof(szInfo));
	if(g_iCheckpointBits[iClient] & CP_BITS_USE_ANGLES)
		AddMenuItem(hMenu, szInfo, "[*] Maintain angles");
	else
		AddMenuItem(hMenu, szInfo, "[  ] Maintain angles");
	
	IntToString(CP_MENU_MAINTAIN_VELOCITY, szInfo, sizeof(szInfo));
	if(g_iCheckpointBits[iClient] & CP_BITS_USE_VELOCITY)
		AddMenuItem(hMenu, szInfo, "[*] Maintain velocity");
	else
		AddMenuItem(hMenu, szInfo, "[  ] Maintain velocity");
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	DisplayMenuAtItem(hMenu, iClient, iStartItem, 0);
}

public MenuHandle_Checkpoint(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iValue = StringToInt(szInfo);
	
	switch(iValue)
	{
		case CP_MENU_SAVE_POSITION:
		{
			SavePosition(iParam1);
			DisplayMenu_Checkpoint(iParam1, GetMenuSelectionPosition());
		}
		case CP_MENU_LOAD_LAST_SAVED:
		{
			if(LoadLastSavedOrUsed(iParam1))
				DisplayMenu_Checkpoint(iParam1, GetMenuSelectionPosition());
		}
		case CP_MENU_LOAD_PREVIOUS:
		{
			if(LoadPrevious(iParam1))
				DisplayMenu_Checkpoint(iParam1, GetMenuSelectionPosition());
		}
		case CP_MENU_LOAD_NEXT:
		{
			if(LoadNext(iParam1))
				DisplayMenu_Checkpoint(iParam1, GetMenuSelectionPosition());
		}
		case CP_MENU_UNDO_LOADS:
		{
			UndoLoads(iParam1);
			DisplayMenu_Checkpoint(iParam1, GetMenuSelectionPosition());
		}
		case CP_MENU_LOAD_SPECIFIC:
		{
			DisplayMenu_LoadSpecific(iParam1);
		}
		case CP_MENU_MAINTAIN_ANGLES:
		{
			g_iCheckpointBits[iParam1] ^= CP_BITS_USE_ANGLES;
			ClientCookies_SetCookie(iParam1, CC_TYPE_SPEEDRUNS_CHECKPOINT_BITS, g_iCheckpointBits[iParam1]);
			DisplayMenu_Checkpoint(iParam1);
		}
		case CP_MENU_MAINTAIN_VELOCITY:
		{
			g_iCheckpointBits[iParam1] ^= CP_BITS_USE_VELOCITY;
			ClientCookies_SetCookie(iParam1, CC_TYPE_SPEEDRUNS_CHECKPOINT_BITS, g_iCheckpointBits[iParam1]);
			DisplayMenu_Checkpoint(iParam1);
		}
	}
}

UndoLoads(iClient)
{
	if(!g_bCanUndoLoads[iClient])
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Cannot undo loads after starting a new run.");
		return;
	}
	
	if(!SpeedRunsTeleport_IsAllowedToTeleport(iClient))
		return;
	
	g_fBlockStageStartDelay[iClient] = GetGameTime() + BLOCK_STAGE_START_DELAY;
	TeleportEntity(iClient, g_fBeforeLoadOrigin[iClient], g_fBeforeLoadAngles[iClient], Float:{0.0, 0.0, 0.0});
	
	CPrintToChat(iClient, "{lightgreen}-- {olive}Returning to position before using load.");
	
	g_bCanUndoLoads[iClient] = false;
}

bool:AreUsableDuringSpeedRun()
{
	if(SpeedRuns_GetServerGroupType() == GROUP_TYPE_KZ || SpeedRuns_GetServerGroupType() == GROUP_TYPE_ROCKET)
		return true;
	
	return false;
}

SavePosition(iClient)
{
	if(!IsPlayerAlive(iClient))
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}You must be alive to do this.");
		return;
	}
	
	if(MovementStyles_GetStyleBits(iClient) & STYLE_BIT_PRO_TIMER)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Cannot use checkpoints in a Pro Timer run.");
		return;
	}
	
	/*
	if((GetEntityFlags(iClient) & FL_DUCKING) || (GetClientButtons(iClient) & IN_DUCK))
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}You must be standing to do this.");
		return;
	}
	*/
	
	decl iCurrentStage;
	
	// If checkpoints are usable during a speed run make sure the player is standing on the ground before saving.
	if(AreUsableDuringSpeedRun())
	{
		if(GetEntProp(iClient, Prop_Send, "m_hGroundEntity") == -1)
		{
			CPrintToChat(iClient, "{lightgreen}-- {red}You must be on the ground to do this.");
			return;
		}
		
		iCurrentStage = SpeedRuns_GetCurrentStage(iClient);
	}
	else
	{
		iCurrentStage = 0;
	}
	
	if(g_aStageCheckpoints[iClient][iCurrentStage] == INVALID_HANDLE)
		g_aStageCheckpoints[iClient][iCurrentStage] = CreateArray(Checkpoint);
	
	decl eCheckpoint[Checkpoint], Float:fVector[3];
	
	eCheckpoint[CP_StageNumber] = iCurrentStage;
	
	GetEntPropString(iClient, Prop_Data, "m_iName", eCheckpoint[CP_TargetName], MAX_ZONE_DATA_STRING_LENGTH);
	
	GetClientAbsOrigin(iClient, fVector);
	eCheckpoint[CP_Origin][0] = fVector[0];
	eCheckpoint[CP_Origin][1] = fVector[1];
	eCheckpoint[CP_Origin][2] = fVector[2];
	
	GetClientEyeAngles(iClient, fVector);
	eCheckpoint[CP_Angles][0] = fVector[0];
	eCheckpoint[CP_Angles][1] = fVector[1];
	eCheckpoint[CP_Angles][2] = fVector[2];
	
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fVector);
	eCheckpoint[CP_Velocity][0] = fVector[0];
	eCheckpoint[CP_Velocity][1] = fVector[1];
	eCheckpoint[CP_Velocity][2] = fVector[2];
	
	GetEntPropVector(iClient, Prop_Send, "m_vecBaseVelocity", fVector);
	eCheckpoint[CP_BaseVelocity][0] = fVector[0];
	eCheckpoint[CP_BaseVelocity][1] = fVector[1];
	eCheckpoint[CP_BaseVelocity][2] = fVector[2];
	
	eCheckpoint[CP_FallVelocity] = GetEntPropFloat(iClient, Prop_Send, "m_flFallVelocity");
	eCheckpoint[CP_VelocityModifier] = GetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier");
	
	eCheckpoint[CP_Ducked] = bool:GetEntProp(iClient, Prop_Send, "m_bDucked");
	eCheckpoint[CP_Ducking] = bool:GetEntProp(iClient, Prop_Send, "m_bDucking");
	eCheckpoint[CP_DuckAmount] = GetEntPropFloat(iClient, Prop_Send, "m_flDuckAmount");
	eCheckpoint[CP_DuckSpeed] = GetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed");
	
	eCheckpoint[CP_VecViewOffset2] = GetEntPropFloat(iClient, Prop_Send, "m_vecViewOffset[2]");
	
	GetEntPropVector(iClient, Prop_Send, "m_vecMaxs", fVector);
	eCheckpoint[CP_VecMaxs][0] = fVector[0];
	eCheckpoint[CP_VecMaxs][1] = fVector[1];
	eCheckpoint[CP_VecMaxs][2] = fVector[2];
	
	eCheckpoint[CP_MoveType] = GetEntityMoveType(iClient);
	eCheckpoint[CP_Flags] = GetEntityFlags(iClient);
	
	eCheckpoint[CP_SetCurrentStage] = iCurrentStage ? true : false;
	eCheckpoint[CP_SetCurrentTotal] = SpeedRuns_IsInTotalRun(iClient);
	eCheckpoint[CP_StageZeroType] = eCheckpoint[CP_SetCurrentTotal] ? STAGE_ZERO_TYPE_BETWEEN_STAGES : STAGE_ZERO_TYPE_OUT_OF_RUN;
	
	g_iLastSavedArrayIndex[iClient] = PushArrayArray(g_aStageCheckpoints[iClient][iCurrentStage], eCheckpoint);
	g_iLastSavedStageNumber[iClient] = iCurrentStage;
	
	g_iLastVisitedArrayIndex[iClient] = g_iLastSavedArrayIndex[iClient];
	g_iLastVisitedStageNumber[iClient] = g_iLastSavedStageNumber[iClient];
	
	if(!AreUsableDuringSpeedRun())
	{
		CPrintToChat(iClient, "{lightgreen}-- {yellow}Global {olive}checkpoint {yellow}#%i {olive}created.", GetArraySize(g_aStageCheckpoints[iClient][iCurrentStage]));
	}
	else if(iCurrentStage)
	{
		CPrintToChat(iClient, "{lightgreen}-- {yellow}Stage %i {olive}checkpoint {yellow}#%i {olive}created.", iCurrentStage, GetArraySize(g_aStageCheckpoints[iClient][iCurrentStage]));
	}
	else
	{
		if(eCheckpoint[CP_StageZeroType] == STAGE_ZERO_TYPE_BETWEEN_STAGES)
			CPrintToChat(iClient, "{lightgreen}-- {yellow}Global (between stages) {olive}checkpoint {yellow}#%i {olive}created.", GetArraySize(g_aStageCheckpoints[iClient][iCurrentStage]));
		else
			CPrintToChat(iClient, "{lightgreen}-- {yellow}Global (out of run) {olive}checkpoint {yellow}#%i {olive}created.", GetArraySize(g_aStageCheckpoints[iClient][iCurrentStage]));
	}
	
	g_iCheckpointsSaved[iClient][0]++;
	g_iCheckpointsSaved[iClient][iCurrentStage]++;
}

bool:LoadLastSavedOrUsed(iClient)
{
	if(g_iLastVisitedArrayIndex[iClient] == -1)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}You don't have a last saved/used checkpoint.");
		return true;
	}
	
	return LoadCheckpoint(iClient, g_iLastVisitedStageNumber[iClient], g_iLastVisitedArrayIndex[iClient]);
}

bool:LoadPrevious(iClient)
{
	if(g_iLastVisitedArrayIndex[iClient] == -1)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}There are no previous checkpoints.");
		return true;
	}
	
	if(g_iLastVisitedArrayIndex[iClient] == 0)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Already at your first Stage %i checkpoint.", g_iLastVisitedStageNumber[iClient]);
		return true;
	}
	
	return LoadCheckpoint(iClient, g_iLastVisitedStageNumber[iClient], g_iLastVisitedArrayIndex[iClient] - 1);
}

bool:LoadNext(iClient)
{
	if(g_iLastVisitedArrayIndex[iClient] == -1)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}There are no next checkpoints.");
		return true;
	}
	
	if(g_iLastVisitedArrayIndex[iClient] >= GetArraySize(g_aStageCheckpoints[iClient][g_iLastVisitedStageNumber[iClient]]) - 1)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Already at your last Stage %i checkpoint.", g_iLastVisitedStageNumber[iClient]);
		return true;
	}
	
	return LoadCheckpoint(iClient, g_iLastVisitedStageNumber[iClient], g_iLastVisitedArrayIndex[iClient] + 1);
}

bool:LoadCheckpoint(iClient, iStageNumber, iArrayIndex)
{
	if(!SpeedRunsTeleport_IsAllowedToTeleport(iClient))
		return false;
	
	new CancelRunType:iCancelType = CANCEL_RUN_NONE;
	new iCurrentStage = SpeedRuns_GetCurrentStage(iClient);
	
	decl eCheckpoint[Checkpoint];
	GetArrayArray(g_aStageCheckpoints[iClient][iStageNumber], iArrayIndex, eCheckpoint);
	
	new bool:bIsInTotalRun = SpeedRuns_IsInTotalRun(iClient);
	
	if(bIsInTotalRun || iCurrentStage > 0)
	{
		if(!AreUsableDuringSpeedRun())
		{
			if(iCancelType == CANCEL_RUN_NONE)
				iCancelType = CANCEL_RUN_CP_NOT_USABLE;
		}
		else if(g_iCheckpointBits[iClient] & CP_BITS_USE_VELOCITY)
		{
			if(iCancelType == CANCEL_RUN_NONE)
				iCancelType = CANCEL_RUN_VELOCITY_NOT_USABLE;
		}
	}
	
	if(bIsInTotalRun)
	{
		if(iStageNumber == 0 && eCheckpoint[CP_StageZeroType] == STAGE_ZERO_TYPE_OUT_OF_RUN)
		{
			// They are trying to teleport to an out of run checkpoint.
			// Ask the player if they want to cancel their total run before going to the checkpoint.
			if(iCancelType == CANCEL_RUN_NONE)
				iCancelType = CANCEL_RUN_OUT_OF_RUN;
		}
		else if(!eCheckpoint[CP_SetCurrentTotal])
		{
			// They are trying to teleport to a previous total runs checkpoint.
			// Ask the player if they want to cancel their total run before going to the checkpoint.
			if(iCancelType == CANCEL_RUN_NONE)
				iCancelType = CANCEL_RUN_OLD_TOTAL;
		}
	}
	
	if(iCurrentStage > 0)
	{
		if(iStageNumber == 0)
		{
			if(eCheckpoint[CP_StageZeroType] == STAGE_ZERO_TYPE_OUT_OF_RUN)
			{
				// They are trying to teleport to an out of run checkpoint.
				// Ask the player if they want to cancel their total run before going to the checkpoint.
				if(iCancelType == CANCEL_RUN_NONE)
					iCancelType = CANCEL_RUN_OUT_OF_RUN;
			}
			else
			{
				// They are trying to teleport to a between stages checkpoint.
				// Ask the player if they want to cancel their total run before going to the checkpoint.
				if(iCancelType == CANCEL_RUN_NONE)
					iCancelType = CANCEL_RUN_BETWEEN_STAGE;
			}
		}
		else if(iCurrentStage == iStageNumber && !eCheckpoint[CP_SetCurrentStage])
		{
			// They are trying to teleport to the same stage but to a previous runs checkpoint.
			// Ask the player if they want to cancel their stage run before going to the checkpoint.
			if(iCancelType == CANCEL_RUN_NONE)
				iCancelType = CANCEL_RUN_OLD_STAGE;
		}
		else if(iCurrentStage != iStageNumber)
		{
			// They are trying to teleport to a different stage.
			// Ask the player if they want to cancel their stage run before going to the checkpoint.
			if(iCancelType == CANCEL_RUN_NONE)
				iCancelType = CANCEL_RUN_DIFF_STAGE;
		}
	}
	
	if(iCancelType != CANCEL_RUN_NONE)
	{
		if(g_iCancelChoice[iClient] == CANCEL_CHOICE_NOWARN_MAP_DURATION
		|| (g_iCancelChoice[iClient] == CANCEL_CHOICE_NOWARN_MINUTES && g_fCancelChoiceTimeStart[iClient] + NOWARN_WAIT_TIME > GetEngineTime()))
		{
			// Cancel the players run but also load their checkpoint.
			CancelRunFromCancelType(iClient, iCancelType, iStageNumber, iArrayIndex);
			TeleportToCheckpoint(iClient, iStageNumber, iArrayIndex);
			return true;
		}
		
		DisplayMenu_CancelRun(iClient, iCancelType, iStageNumber, iArrayIndex);
		return false;
	}
	
	// It's safe to load the checkpoint without canceling their run.
	TeleportToCheckpoint(iClient, iStageNumber, iArrayIndex);
	return true;
}

TeleportToCheckpoint(iClient, iStageNumber, iArrayIndex)
{
	if(MovementStyles_GetStyleBits(iClient) & STYLE_BIT_PRO_TIMER)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Cannot use checkpoints in a Pro Timer run.");
		return;
	}
	
	g_bCanUndoLoads[iClient] = true;
	GetClientAbsOrigin(iClient, g_fBeforeLoadOrigin[iClient]);
	GetClientEyeAngles(iClient, g_fBeforeLoadAngles[iClient]);
	
	decl eCheckpoint[Checkpoint];
	GetArrayArray(g_aStageCheckpoints[iClient][iStageNumber], iArrayIndex, eCheckpoint);
	
	new bool:bUseNullVelocity, bool:bUseNullAngles;
	decl Float:fOrigin[3], Float:fAngles[3], Float:fVelocity[3];
	
	if(g_iCheckpointBits[iClient] & CP_BITS_USE_VELOCITY)
	{
		fVelocity[0] = eCheckpoint[CP_BaseVelocity][0];
		fVelocity[1] = eCheckpoint[CP_BaseVelocity][1];
		fVelocity[2] = eCheckpoint[CP_BaseVelocity][2];
		SetEntPropVector(iClient, Prop_Send, "m_vecBaseVelocity", fVelocity);
		
		SetEntPropFloat(iClient, Prop_Send, "m_flFallVelocity", eCheckpoint[CP_FallVelocity]);
		SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", eCheckpoint[CP_VelocityModifier]);
		
		fVelocity[0] = eCheckpoint[CP_Velocity][0];
		fVelocity[1] = eCheckpoint[CP_Velocity][1];
		fVelocity[2] = eCheckpoint[CP_Velocity][2];
	}
	else
	{
		// When checkpoints are usable within a speed run we want the players velocity to be zeroed out when using one.
		if(AreUsableDuringSpeedRun())
		{
			fVelocity[0] = 0.0;
			fVelocity[1] = 0.0;
			fVelocity[2] = 0.0;
		}
		else
		{
			bUseNullVelocity = true;
		}
	}
	
	if(g_iCheckpointBits[iClient] & CP_BITS_USE_ANGLES)
	{
		fAngles[0] = eCheckpoint[CP_Angles][0];
		fAngles[1] = eCheckpoint[CP_Angles][1];
		fAngles[2] = eCheckpoint[CP_Angles][2];
	}
	else
	{
		bUseNullAngles = true;
	}
	
	fOrigin[0] = eCheckpoint[CP_Origin][0];
	fOrigin[1] = eCheckpoint[CP_Origin][1];
	fOrigin[2] = eCheckpoint[CP_Origin][2];
	
	SetEntProp(iClient, Prop_Send, "m_bDucked", eCheckpoint[CP_Ducked]);
	SetEntProp(iClient, Prop_Send, "m_bDucking", eCheckpoint[CP_Ducking]);
	SetEntPropFloat(iClient, Prop_Send, "m_flDuckAmount", eCheckpoint[CP_DuckAmount]);
	SetEntPropFloat(iClient, Prop_Send, "m_flDuckSpeed", eCheckpoint[CP_DuckSpeed]);
	
	SetEntPropFloat(iClient, Prop_Send, "m_vecViewOffset[2]", eCheckpoint[CP_VecViewOffset2]);
	
	decl Float:fVecMaxs[3];
	fVecMaxs[0] = eCheckpoint[CP_VecMaxs][0];
	fVecMaxs[1] = eCheckpoint[CP_VecMaxs][1];
	fVecMaxs[2] = eCheckpoint[CP_VecMaxs][2];
	SetEntPropVector(iClient, Prop_Send, "m_vecMaxs", fVecMaxs);
	
	SetEntityMoveType(iClient, eCheckpoint[CP_MoveType]);
	SetEntityFlags(iClient, eCheckpoint[CP_Flags]);
	
	SetEntPropString(iClient, Prop_Data, "m_iName", eCheckpoint[CP_TargetName]); // Set the clients targetname before teleporting.
	
	g_fBlockStageStartDelay[iClient] = GetGameTime() + BLOCK_STAGE_START_DELAY;
	TeleportEntity(iClient, fOrigin, bUseNullAngles ? NULL_VECTOR : fAngles, bUseNullVelocity ? NULL_VECTOR : fVelocity);
	
	SetEntPropString(iClient, Prop_Data, "m_iName", eCheckpoint[CP_TargetName]); // Set the clients targetname after teleporting as well.
	
	if(!AreUsableDuringSpeedRun())
	{
		CPrintToChat(iClient, "{lightgreen}-- {yellow}Global {olive}checkpoint {yellow}#%i {olive}loaded.", iArrayIndex+1);
	}
	else if(eCheckpoint[CP_StageNumber])
	{
		CPrintToChat(iClient, "{lightgreen}-- {yellow}Stage %i {olive}checkpoint {yellow}#%i {olive}loaded.", eCheckpoint[CP_StageNumber], iArrayIndex+1);
	}
	else
	{
		if(eCheckpoint[CP_StageZeroType] == STAGE_ZERO_TYPE_BETWEEN_STAGES)
			CPrintToChat(iClient, "{lightgreen}-- {yellow}Global (between stages) {olive}checkpoint {yellow}#%i {olive}loaded.", iArrayIndex+1);
		else
			CPrintToChat(iClient, "{lightgreen}-- {yellow}Global (out of run) {olive}checkpoint {yellow}#%i {olive}loaded.", iArrayIndex+1);
	}
	
	g_iCheckpointsUsed[iClient][0]++;
	
	if(eCheckpoint[CP_StageNumber] > 0)
		g_iCheckpointsUsed[iClient][eCheckpoint[CP_StageNumber]]++;
	
	g_iLastVisitedArrayIndex[iClient] = iArrayIndex;
	g_iLastVisitedStageNumber[iClient] = iStageNumber;
}

DisplayMenu_CancelRun(iClient, CancelRunType:iCancelType, iStageNumber, iArrayIndex)
{
	new Handle:hMenu = CreateMenu(MenuHandle_CancelRun);
	
	switch(iCancelType)
	{
		case CANCEL_RUN_OLD_TOTAL: SetMenuTitle(hMenu, "This is an old run's checkpoint.\nUsing it will cancel your TOTAL run.");
		case CANCEL_RUN_OLD_STAGE: SetMenuTitle(hMenu, "This is an old run's checkpoint.\nUsing it will cancel your STAGE run.");
		case CANCEL_RUN_DIFF_STAGE: SetMenuTitle(hMenu, "This is a different stage's checkpoint.\nUsing it will cancel your STAGE run.");
		case CANCEL_RUN_BETWEEN_STAGE: SetMenuTitle(hMenu, "This is a between stages checkpoint.\nUsing it will cancel your STAGE run.");
		case CANCEL_RUN_OUT_OF_RUN: SetMenuTitle(hMenu, "This is an out of run checkpoint.\nUsing it will cancel your TOTAL run.");
		case CANCEL_RUN_CP_NOT_USABLE: SetMenuTitle(hMenu, "Using a checkpoint will cancel your speedrun.");
		case CANCEL_RUN_VELOCITY_NOT_USABLE: SetMenuTitle(hMenu, "Using a checkpoint will cancel your speedrun.\nThis is because you have \"Maintain velocity\" checked in !cpmenu.");
	}
	
	AddMenuItem(hMenu, "0", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "0", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "0", "", ITEMDRAW_SPACER);
	AddMenuItem(hMenu, "0", "Don't cancel run!");
	AddMenuItem(hMenu, "0", "", ITEMDRAW_SPACER);
	
	decl String:szInfo[48];
	FormatEx(szInfo, sizeof(szInfo), "%i|%i|%i|%i", iCancelType, iStageNumber, iArrayIndex, CANCEL_CHOICE_WARN_EVERYTIME);
	AddMenuItem(hMenu, szInfo, "Use the checkpoint.");
	
	AddMenuItem(hMenu, "0", "", ITEMDRAW_SPACER);
	
	FormatEx(szInfo, sizeof(szInfo), "%i|%i|%i|%i", iCancelType, iStageNumber, iArrayIndex, CANCEL_CHOICE_NOWARN_MINUTES);
	AddMenuItem(hMenu, szInfo, "Use the checkpoint. Don't warn again for 5 min.");
	
	FormatEx(szInfo, sizeof(szInfo), "%i|%i|%i|%i", iCancelType, iStageNumber, iArrayIndex, CANCEL_CHOICE_NOWARN_MAP_DURATION);
	AddMenuItem(hMenu, szInfo, "Use the checkpoint. Don't warn again for map.");
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, false);
	DisplayMenu(hMenu, iClient, 0);
}

public MenuHandle_CancelRun(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[48], String:szExplode[4][12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iNumStrings = ExplodeString(szInfo, "|", szExplode, sizeof(szExplode), sizeof(szExplode[]));
	if(iNumStrings < 4 || StrEqual(szInfo, "0"))
	{
		DisplayMenu_Checkpoint(iParam1);
		return;
	}
	
	new CancelRunType:iCancelType = CancelRunType:StringToInt(szExplode[0]);
	new iStageNumber = StringToInt(szExplode[1]);
	new iArrayIndex = StringToInt(szExplode[2]);
	g_iCancelChoice[iParam1] = CancelChoice:StringToInt(szExplode[3]);
	
	g_fCancelChoiceTimeStart[iParam1] = GetEngineTime();
	
	CancelRunFromCancelType(iParam1, iCancelType, iStageNumber, iArrayIndex);
	TeleportToCheckpoint(iParam1, iStageNumber, iArrayIndex);
	
	switch(g_iCancelChoice[iParam1])
	{
		case CANCEL_CHOICE_NOWARN_MINUTES: CPrintToChat(iParam1, "{lightred}Warning: {lightgreen}Cancellation confirmations will no longer be shown for 5 minutes. Don't load a checkpoint on accident!");
		case CANCEL_CHOICE_NOWARN_MAP_DURATION: CPrintToChat(iParam1, "{lightred}Warning: {lightgreen}Cancellation confirmations will no longer be shown for the map. Don't load a checkpoint on accident!");
	}
	
	DisplayMenu_Checkpoint(iParam1);
}

CancelRunFromCancelType(iClient, CancelRunType:iCancelType, iStageNumber, iArrayIndex)
{
	if(iCancelType == CANCEL_RUN_OLD_STAGE || iCancelType == CANCEL_RUN_DIFF_STAGE || iCancelType == CANCEL_RUN_BETWEEN_STAGE)
	{
		// If we are canceling the stage only we need to make sure they didn't delay this menu to cheat with it.
		decl eCheckpoint[Checkpoint];
		GetArrayArray(g_aStageCheckpoints[iClient][iStageNumber], iArrayIndex, eCheckpoint);
		
		if(!eCheckpoint[CP_SetCurrentTotal])
		{
			// This checkpoint was from an old total run. Cancel the entire run.
			SpeedRuns_CancelRun(iClient);
		}
		else
		{
			// It's safe to just cancel the stage only.
			SpeedRuns_CancelRun(iClient, true);
		}
	}
	else
	{
		SpeedRuns_CancelRun(iClient);
	}
}

DisplayMenu_LoadSpecific(iClient)
{
	if(!AreUsableDuringSpeedRun())
	{
		DisplayMenu_LoadSpecificStage(iClient, 0);
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_LoadSpecific);
	
	SetMenuTitle(hMenu, "Select a stage");
	
	decl String:szInfo[4], String:szBuffer[32];
	for(new i=0; i<sizeof(g_aStageCheckpoints[]); i++)
	{
		if(g_aStageCheckpoints[iClient][i] == INVALID_HANDLE || !GetArraySize(g_aStageCheckpoints[iClient][i]))
			continue;
		
		if(i > 0)
			FormatEx(szBuffer, sizeof(szBuffer), "Stage %i", i);
		else
			FormatEx(szBuffer, sizeof(szBuffer), "Global");
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		DisplayMenu_Checkpoint(iClient);
		CPrintToChat(iClient, "{lightgreen}-- {red}You have no checkpoints to load.");
	}
}

public MenuHandle_LoadSpecific(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
		
		DisplayMenu_Checkpoint(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	DisplayMenu_LoadSpecificStage(iParam1, StringToInt(szInfo));
}

DisplayMenu_LoadSpecificStage(iClient, iStageNumber)
{
	if(g_aStageCheckpoints[iClient][iStageNumber] == INVALID_HANDLE)
	{
		DisplayMenu_Checkpoint(iClient);
		CPrintToChat(iClient, "{lightgreen}-- {red}No checkpoints to load.");
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_LoadSpecificStage);
	
	SetMenuTitle(hMenu, "Load specific checkpoint");
	
	decl String:szInfo[16], String:szBuffer[32], eCheckpoint[Checkpoint];
	for(new i=GetArraySize(g_aStageCheckpoints[iClient][iStageNumber])-1; i>=0; i--)
	{
		GetArrayArray(g_aStageCheckpoints[iClient][iStageNumber], i, eCheckpoint);
		
		if(iStageNumber)
		{
			if(eCheckpoint[CP_SetCurrentStage])
				FormatEx(szBuffer, sizeof(szBuffer), "CP #%i", i+1);
			else
				FormatEx(szBuffer, sizeof(szBuffer), "CP #%i (old)", i+1);
		}
		else
		{
			if(!AreUsableDuringSpeedRun())
				FormatEx(szBuffer, sizeof(szBuffer), "CP #%i", i+1);
			else if(eCheckpoint[CP_StageZeroType] == STAGE_ZERO_TYPE_BETWEEN_STAGES)
				FormatEx(szBuffer, sizeof(szBuffer), "CP #%i (between stages)", i+1);
			else
				FormatEx(szBuffer, sizeof(szBuffer), "CP #%i (out of run)", i+1);
		}
		
		FormatEx(szInfo, sizeof(szInfo), "%i|%i", iStageNumber, i);
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		DisplayMenu_LoadSpecific(iClient);
		CPrintToChat(iClient, "{lightgreen}-- {red}You have no Stage %i checkpoints to load.", iStageNumber);
	}
}

public MenuHandle_LoadSpecificStage(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
		
		if(AreUsableDuringSpeedRun())
			DisplayMenu_LoadSpecific(iParam1);
		else
			DisplayMenu_Checkpoint(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[16], String:szExplode[2][12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iNumStrings = ExplodeString(szInfo, "|", szExplode, sizeof(szExplode), sizeof(szExplode[]));
	if(iNumStrings < 2)
	{
		DisplayMenu_Checkpoint(iParam1);
		return;
	}
	
	new iStageNumber = StringToInt(szExplode[0]);
	new iArrayIndex = StringToInt(szExplode[1]);
	
	if(LoadCheckpoint(iParam1, iStageNumber, iArrayIndex))
		DisplayMenu_Checkpoint(iParam1);
}

public SpeedRunsTeleport_OnTeleport_Post(iClient, iStageNumber)
{
	new iCurrentStage = SpeedRuns_GetCurrentStage(iClient);
	if(iCurrentStage > 0)
		g_iCheckpointsUsed[iClient][iCurrentStage]++;
	
	g_iCheckpointsUsed[iClient][0]++;
	
	if(AreUsableDuringSpeedRun())
		CPrintToChat(iClient, "{lightgreen}-- {yellow}Note: {olive}Using teleports counts as using a checkpoint.");
}