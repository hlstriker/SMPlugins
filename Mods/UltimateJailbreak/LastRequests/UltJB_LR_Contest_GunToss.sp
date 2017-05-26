#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <cstrike>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_lr_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "LR: Contest - Gun Toss";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Last Request: Contest - Gun Toss.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Gun Toss"
#define LR_CATEGORY		"Contest"
#define LR_DESCRIPTION	""

new bool:g_bWasOpponentSelected[MAXPLAYERS+1];
new g_iEffectSelectedID[MAXPLAYERS+1];

#define MAX_TOSS_TIME 10.0
new Float:g_fForceEndTime[MAXPLAYERS+1];

#define SetOldOrigin(%1,%2)		SetEntPropVector(%1, Prop_Data, "m_vecAbsVelocity", %2)
#define GetOldOrigin(%1,%2)		GetEntPropVector(%1, Prop_Data, "m_vecAbsVelocity", %2)

#define MOVEMENT_UPDATE_TIME 0.2
new Float:g_fNextMovementUpdate[MAXPLAYERS+1];

#define BEAM_UPDATE_TIME 0.5
new Float:g_fNextBeamUpdate[MAXPLAYERS+1];

new const g_iColorT[4] = {255, 85, 0, 255};
new const g_iColorCT[4] = {0, 0, 255, 255};

new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";
new g_iBeamIndex;

enum
{
	POSITION_START = 0,
	POSITION_END,
	NUM_POSITIONS
};

new Float:g_fPositionOrigin[NUM_POSITIONS][MAXPLAYERS+1][3];
new bool:g_bHasPositionSet[NUM_POSITIONS][MAXPLAYERS+1];

#define SLAY_TIMER_TIME 45
new Float:g_fSlayTimerStartTime[MAXPLAYERS+1];

new g_iWeaponEntRef[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("lr_contest_gun_toss_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_DONT_ALLOW_DAMAGING_OPPONENT | LR_FLAG_ALLOW_WEAPON_DROPS, OnLastRequestStart, OnLastRequestEnd);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	UltJB_LR_DisplayOpponentSelection(iClient, OnOpponentSelectedSuccess);
}

public OnLastRequestEnd(iClient, iOpponent)
{
	if(!g_bWasOpponentSelected[iClient])
		return;
	
	g_bWasOpponentSelected[iClient] = false;
	
	LastRequestEndCleanup(iClient, g_iEffectSelectedID[iClient]);
	LastRequestEndCleanup(iOpponent, g_iEffectSelectedID[iClient]);
}

public OnOpponentSelectedSuccess(iClient, iOpponent)
{
	g_bWasOpponentSelected[iClient] = true;
	
	UltJB_LR_StripClientsWeapons(iClient, true);
	UltJB_LR_StripClientsWeapons(iOpponent, true);
	
	UltJB_Effects_DisplaySelectionMenu(iClient, OnEffectSelected_Success, OnEffectSelected_Failed);
}

public OnEffectSelected_Success(iClient, iEffectID)
{
	g_iEffectSelectedID[iClient] = iEffectID;
	PrepareClients(iClient);
}

public OnEffectSelected_Failed(iClient)
{
	PrintToChat(iClient, "[SM] Proceeding without an effect.");
	
	g_iEffectSelectedID[iClient] = 0;
	PrepareClients(iClient);
}

PrepareClients(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	
	UltJB_LR_StartSlayTimer(iClient, SLAY_TIMER_TIME);
	g_fSlayTimerStartTime[iClient] = GetGameTime();
	g_fSlayTimerStartTime[iOpponent] = GetGameTime();
	
	if(g_iEffectSelectedID[iClient])
	{
		UltJB_Effects_StartEffect(iClient, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
		UltJB_Effects_StartEffect(iOpponent, g_iEffectSelectedID[iClient], UltJB_Effects_GetEffectDefaultData(g_iEffectSelectedID[iClient]));
	}
	
	PrepareClient(iClient);
	PrepareClient(iOpponent);
}

PrepareClient(iClient)
{
	g_iWeaponEntRef[iClient] = INVALID_ENT_REFERENCE;
	
	for(new i=0; i<NUM_POSITIONS; i++)
		g_bHasPositionSet[i][iClient] = false;
	
	SDKHook(iClient, SDKHook_WeaponDropPost, OnWeaponDropPost);
	
	new iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_DEAGLE);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
}

LastRequestEndCleanup(iClient, iEffectID)
{
	if(!iClient || !IsClientInGame(iClient))
		return;
	
	if(IsPlayerAlive(iClient))
		UltJB_LR_RestoreClientsWeapons(iClient);
	
	if(iEffectID)
		UltJB_Effects_StopEffect(iClient, iEffectID);
	
	SDKUnhook(iClient, SDKHook_WeaponDropPost, OnWeaponDropPost);
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public OnWeaponDropPost(iClient, iWeapon)
{
	g_iWeaponEntRef[iClient] = EntIndexToEntRef(iWeapon);
	g_fForceEndTime[iClient] = GetEngineTime() + MAX_TOSS_TIME;
	
	SetStartPosition(iClient);
	
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

SetStartPosition(iClient)
{
	GetClientAbsOrigin(iClient, g_fPositionOrigin[POSITION_START][iClient]);
	g_bHasPositionSet[POSITION_START][iClient] = true;
	
	DrawBeam(iClient, POSITION_START);
}

SetEndPosition(iClient, iWeapon)
{
	GetEntPropVector(iWeapon, Prop_Data, "m_vecOrigin", g_fPositionOrigin[POSITION_END][iClient]);
	g_bHasPositionSet[POSITION_END][iClient] = true;
	
	DrawBeam(iClient, POSITION_END);
	
	CheckForWinner(iClient);
}

public OnPreThinkPost(iClient)
{
	CheckWeaponMovement(iClient);
	TryDrawBeams(iClient);
}

CheckWeaponMovement(iClient)
{
	if(g_bHasPositionSet[POSITION_END][iClient])
		return;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextMovementUpdate[iClient])
		return;
	
	g_fNextMovementUpdate[iClient] = fCurTime + MOVEMENT_UPDATE_TIME;
	
	static iWeapon;
	iWeapon = EntRefToEntIndex(g_iWeaponEntRef[iClient]);
	if(iWeapon < 1 || iWeapon == INVALID_ENT_REFERENCE)
	{
		UltJB_LR_EndLastRequest(iClient);
		return;
	}
	
	if(fCurTime >= g_fForceEndTime[iClient])
	{
		SetEndPosition(iClient, iWeapon);
		return;
	}
	
	static Float:fNewOrigin[3], Float:fOldOrigin[3];
	GetEntPropVector(iWeapon, Prop_Data, "m_vecOrigin", fNewOrigin);
	GetOldOrigin(iWeapon, fOldOrigin);
	
	if(fNewOrigin[0] != fOldOrigin[0]
	|| fNewOrigin[1] != fOldOrigin[1]
	|| fNewOrigin[2] != fOldOrigin[2])
	{
		SetOldOrigin(iWeapon, fNewOrigin);
		return;
	}
	
	SetEndPosition(iClient, iWeapon);
}

TryDrawBeams(iClient)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextBeamUpdate[iClient])
		return;
	
	g_fNextBeamUpdate[iClient] = fCurTime + BEAM_UPDATE_TIME;
	
	if(g_bHasPositionSet[POSITION_START][iClient])
		DrawBeam(iClient, POSITION_START);
	
	if(g_bHasPositionSet[POSITION_END][iClient])
		DrawBeam(iClient, POSITION_END);
}

DrawBeam(iClient, iPosition)
{
	static Float:fEndOrigin[3];
	AddVectors(g_fPositionOrigin[iPosition][iClient], Float:{0.0, 0.0, 50.0}, fEndOrigin);
	
	static iColor[4];
	switch(GetClientTeam(iClient))
	{
		case CS_TEAM_T: iColor = g_iColorT;
		case CS_TEAM_CT: iColor = g_iColorCT;
	}
	
	TE_SetupBeamPoints(g_fPositionOrigin[iPosition][iClient], fEndOrigin, g_iBeamIndex, 0, 1, 1, BEAM_UPDATE_TIME + 0.1, 0.1, 6.0, 0, 0.0, iColor, 20);
	TE_SendToAll();
}

CheckForWinner(iClient)
{
	new iOpponent = UltJB_LR_GetLastRequestOpponent(iClient);
	if(!g_bHasPositionSet[POSITION_END][iOpponent])
	{
		new iNewTime = RoundToCeil(GetGameTime() - g_fSlayTimerStartTime[iClient]);
		UltJB_LR_StartSlayTimer(iClient, iNewTime, (GetClientTeam(iClient) == TEAM_GUARDS) ? LR_SLAYTIMER_FLAG_PRISONER : LR_SLAYTIMER_FLAG_GUARD);
		return;
	}
	
	new Float:fDistanceClient = GetVectorDistance(g_fPositionOrigin[POSITION_START][iClient], g_fPositionOrigin[POSITION_END][iClient]);
	new Float:fDistanceOpponent = GetVectorDistance(g_fPositionOrigin[POSITION_START][iOpponent], g_fPositionOrigin[POSITION_END][iOpponent]);
	
	decl iWinner, iLoser, Float:fDistanceWinner, Float:fDistanceLoser;
	if(fDistanceClient > fDistanceOpponent)
	{
		iWinner = iClient;
		iLoser = iOpponent;
		
		fDistanceWinner = fDistanceClient;
		fDistanceLoser = fDistanceOpponent;
	}
	else
	{
		iWinner = iOpponent;
		iLoser = iClient;
		
		fDistanceWinner = fDistanceOpponent;
		fDistanceLoser = fDistanceClient;
	}
	
	new iWeapon = UltJB_Weapons_GivePlayerWeapon(iWinner, _:CSWeapon_DEAGLE);
	SetEntPropEnt(iWinner, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	SDKHooks_TakeDamage(iLoser, iWinner, iWinner, 99999.0);
	
	PrintToChat(iWinner, "[SM] You won with a toss of %.01f units (vs %.01f).", fDistanceWinner, fDistanceLoser);
	PrintToChat(iLoser, "[SM] You lost with a toss of %.01f units (vs %.01f).", fDistanceLoser, fDistanceWinner);
}