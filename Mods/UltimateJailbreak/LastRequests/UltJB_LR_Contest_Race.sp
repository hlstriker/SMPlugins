#include <sourcemod>
#include <sdkhooks>
#include <sdktools_engine>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: Contest - Race";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Contest - Race.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Race"
#define LR_CATEGORY		"Contest"
#define LR_DESCRIPTION	""

new g_iEffectSelectedID[MAXPLAYERS+1];
new bool:g_bWasOpponentSelected[MAXPLAYERS+1];
new Handle:g_hMenu_StartEndPlacement[MAXPLAYERS+1];

enum
{
	RACE_ID_START = 1,
	RACE_ID_END,
	NUM_RACE_IDS
};

new Float:g_fStartOrigin[MAXPLAYERS+1][3];
new g_iRaceEndRef[MAXPLAYERS+1];

new bool:g_bIsPositionCreated[MAXPLAYERS+1][NUM_RACE_IDS];

new const String:SZ_MODEL_FINISH_LINE[] = "models/swoobles/ultimate_jailbreak/finish_line/finish_line.mdl";

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;

new Handle:g_hContestTimer[MAXPLAYERS+1];
new g_iTimerCountdown[MAXPLAYERS+1];
new Handle:cvar_countdown;

new bool:g_bHasRaceStarted[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("lr_contest_race_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_countdown = CreateConVar("lr_race_contest_countdown", "5", "The number of seconds to countdown before starting the contest.", _, true, 1.0);
}

public OnMapStart()
{
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/finish_line/finish_line.dx90.vtx");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/finish_line/finish_line.mdl");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/finish_line/finish_line.phy");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/finish_line/finish_line.vvd");
	
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/finish_line/checkers.vmt");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/finish_line/checkers.vtf");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/finish_line/poles.vmt");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/finish_line/poles.vtf");
	
	PrecacheModel(SZ_MODEL_FINISH_LINE);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT | LR_FLAG_ALLOW_WEAPON_PICKUPS, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	for(new i=0; i<sizeof(g_bIsPositionCreated[]); i++)
		g_bIsPositionCreated[iClient][i] = false;
	
	UltJB_LR_DisplayOpponentSelection(iClient, OnOpponentSelectedSuccess);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	if(!g_bWasOpponentSelected[iClient])
		return;
	
	g_bWasOpponentSelected[iClient] = false;
	
	if(g_hContestTimer[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hContestTimer[iClient]);
		g_hContestTimer[iClient] = INVALID_HANDLE;
	}
	
	if(g_hMenu_StartEndPlacement[iClient] != INVALID_HANDLE)
		CancelMenu(g_hMenu_StartEndPlacement[iClient]);
	
	LastRequestEndCleanup(iClient, g_iEffectSelectedID[iClient]);
	LastRequestEndCleanup(iOpponent, g_iEffectSelectedID[iClient]);
	
	RemoveEndEntity(iClient);
}

public OnOpponentSelectedSuccess(iClient, iOpponent)
{
	g_bWasOpponentSelected[iClient] = true;
	
	g_bHasRaceStarted[iClient] = false;
	g_bHasRaceStarted[iOpponent] = false;
	
	UltJB_Effects_DisplaySelectionMenu(iClient, OnEffectSelected_Success, OnEffectSelected_Failed);
}

public OnEffectSelected_Success(iClient, iEffectID)
{
	g_iEffectSelectedID[iClient] = iEffectID;
	DisplaySetupMenu(iClient);
}

public OnEffectSelected_Failed(iClient)
{
	g_iEffectSelectedID[iClient] = 0;
	DisplaySetupMenu(iClient);
}

DisplaySetupMenu(iClient)
{
	UltJB_LR_StartSlayTimer(iClient, 15, LR_SLAYTIMER_FLAG_PRISONER);
	
	g_hMenu_StartEndPlacement[iClient] = DisplayMenu_StartEndPlacement(iClient);
	if(g_hMenu_StartEndPlacement[iClient] != INVALID_HANDLE)
		return;
	
	UltJB_LR_EndLastRequest(iClient);
}

Handle:DisplayMenu_StartEndPlacement(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_StartEndPlacement);
	
	decl String:szInfo[2];
	if(!g_bIsPositionCreated[iClient][RACE_ID_START])
	{
		SetMenuTitle(hMenu, "Select where you would like to start the race.");
		
		IntToString(RACE_ID_START, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "Create start position");
	}
	else
	{
		SetMenuTitle(hMenu, "Select where you would like to end the race.");
		
		IntToString(RACE_ID_END, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, "Create end position");
	}
	
	SetMenuExitButton(hMenu, false);
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There was a problem creating the start/end menu.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

public MenuHandle_StartEndPlacement(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		InvalidateHandleArrayIndex(hMenu, g_hMenu_StartEndPlacement, sizeof(g_hMenu_StartEndPlacement));
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case RACE_ID_START:
		{
			if(CreateStart(iParam1))
			{
				g_bIsPositionCreated[iParam1][RACE_ID_START] = true;
				UltJB_LR_StartSlayTimer(iParam1, 25, LR_SLAYTIMER_FLAG_PRISONER);
			}
		}
		case RACE_ID_END:
		{
			if(CreateEnd(iParam1))
				g_bIsPositionCreated[iParam1][RACE_ID_END] = true;
		}
	}
	
	if(!g_bIsPositionCreated[iParam1][RACE_ID_START] || !g_bIsPositionCreated[iParam1][RACE_ID_END])
		g_hMenu_StartEndPlacement[iParam1] = DisplayMenu_StartEndPlacement(iParam1);
}

bool:CreateStart(iClient)
{
	if(!CheckPlacementCriteria(iClient))
		return false;
	
	GetClientAbsOrigin(iClient, g_fStartOrigin[iClient]);
	
	decl Float:fAngles[3];
	GetClientAbsAngles(iClient, fAngles);
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	TeleportEntity(iOpponent, g_fStartOrigin[iClient], fAngles, NULL_VECTOR);
	PrintToChat(iOpponent, "[SM] Carefully watch where your opponent goes.");
	
	return true;
}

bool:CreateEnd(iClient)
{
	if(!CheckPlacementCriteria(iClient))
		return false;
	
	if(!CheckEndDistance(iClient))
		return false;
	
	if(!CreateFinishLine(iClient))
	{
		PrintToChat(iClient, "[SM] There was an error creating the end entity.");
		return false;
	}
	
	UltJB_LR_StopSlayTimer(iClient);
	StartCountdown(iClient);
	
	return true;
}

#define MIN_DISTANCE_FROM_START	200.0

bool:CheckEndDistance(iClient)
{
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	
	new Float:fDistance = GetVectorDistance(fOrigin, g_fStartOrigin[iClient]);
	if(fDistance < MIN_DISTANCE_FROM_START)
	{
		PrintToChat(iClient, "[SM] Move at least %i more units away from the start.", RoundFloat(MIN_DISTANCE_FROM_START - fDistance));
		return false;
	}
	
	return true;
}

bool:CheckPlacementCriteria(iClient)
{
	if((GetEntityFlags(iClient) & FL_DUCKING) || (GetClientButtons(iClient) & IN_DUCK))
	{
		PrintToChat(iClient, "[SM] Cannot place while ducking.");
		return false;
	}
	
	if(GetEntProp(iClient, Prop_Send, "m_hGroundEntity") == -1)
	{
		PrintToChat(iClient, "[SM] You must be on the ground.");
		return false;
	}
	
	return true;
}

bool:CreateFinishLine(iClient)
{
	new iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1 || !IsValidEntity(iEnt))
		return false;
	
	SetEntityModel(iEnt, SZ_MODEL_FINISH_LINE);
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2); // SOLID_BBOX
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER);
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", Float:{-20.0, -20.0, -0.0});
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", Float:{20.0, 20.0, 80.0});
	
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost);
	
	SetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity", iClient);
	g_iRaceEndRef[iClient] = EntIndexToEntRef(iEnt);
	
	return true;
}

public OnStartTouchPost(iEnt, iOther)
{
	if(!IsPlayer(iOther) || !IsPlayerAlive(iOther))
		return;
	
	// Return if the player has noclip.
	if(GetEntityMoveType(iOther) == MOVETYPE_NOCLIP)
		return;
	
	if(!g_bHasRaceStarted[iOther])
		return;
	
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iOther);
	new iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
	
	if(iOwner != iOther && iOwner != iOpponent)
		return;
	
	SDKHooks_TakeDamage(iOpponent, iOther, iOther, 99999.0);
	SDKUnhook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost);
}

StartCountdown(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	
	SetEntityMoveType(iClient, MOVETYPE_NONE);
	SetEntityMoveType(iOpponent, MOVETYPE_NONE);
	
	TeleportEntity(iClient, g_fStartOrigin[iClient], NULL_VECTOR, NULL_VECTOR);
	TeleportEntity(iOpponent, g_fStartOrigin[iClient], NULL_VECTOR, NULL_VECTOR);
	
	g_iTimerCountdown[iClient] = 0;
	g_hContestTimer[iClient] = CreateTimer(1.0, Timer_Countdown, iClient, TIMER_REPEAT);
	
	PrintToChat(iClient, "[SM] The race will start in %i seconds.", GetConVarInt(cvar_countdown));
	PrintToChat(iOpponent, "[SM] The race will start in %i seconds.", GetConVarInt(cvar_countdown));
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StartEffect(iClient, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
		UltJB_Effects_StartEffect(iOpponent, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
	}
}

public Action:Timer_Countdown(Handle:hTimer, any:iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(!iOpponent)
	{
		g_hContestTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_iTimerCountdown[iClient]++;
	
	if(g_iTimerCountdown[iClient] == GetConVarInt(cvar_countdown))
	{
		PrintToChat(iClient, "[SM] The race has started!");
		PrintToChat(iOpponent, "[SM] The race has started!");
		
		StartRace(iClient, iOpponent);
		
		UltJB_LR_StartSlayTimer(iClient, 45);
		
		g_hContestTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	PrintToChat(iClient, "[SM] %i..", GetConVarInt(cvar_countdown) - g_iTimerCountdown[iClient]);
	PrintToChat(iOpponent, "[SM] %i..", GetConVarInt(cvar_countdown) - g_iTimerCountdown[iClient]);
	
	return Plugin_Continue;
}

StartRace(iClient, iOpponent)
{
	decl Float:fOrigin[3], Float:fAngles[3];
	GetClientAbsOrigin(iClient, fOrigin);
	GetClientAbsAngles(iClient, fAngles);
	TeleportEntity(iClient, fOrigin, fAngles, Float:{0.0, 0.0, 0.0});
	
	GetClientAbsOrigin(iOpponent, fOrigin);
	GetClientAbsAngles(iOpponent, fAngles);
	TeleportEntity(iOpponent, fOrigin, fAngles, Float:{0.0, 0.0, 0.0});
	
	SetEntityMoveType(iClient, MOVETYPE_WALK);
	SetEntityMoveType(iOpponent, MOVETYPE_WALK);
	
	g_bHasRaceStarted[iClient] = true;
	g_bHasRaceStarted[iOpponent] = true;
}

LastRequestEndCleanup(iClient, iEffectID)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
	{
		UltJB_LR_RestoreClientsWeapons(iClient);
		SetEntityMoveType(iClient, MOVETYPE_WALK);
	}
	
	if(iEffectID)
		UltJB_Effects_StopEffect(iClient, iEffectID);
}

RemoveEndEntity(iClient)
{
	new iEnt = EntRefToEntIndex(g_iRaceEndRef[iClient]);
	if(iEnt < 1 || iEnt == INVALID_ENT_REFERENCE)
		return;
	
	AcceptEntityInput(iEnt, "Kill");
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
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