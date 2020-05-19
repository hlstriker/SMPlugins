#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <emitsoundany>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_player_models"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Horror Movie";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Horror Movie.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME		"Horror Movie"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new g_iCustomFogControllerPrisonersRef;
new g_iCustomFogControllerGuardsRef;
new g_iOriginalFogControllerRef[MAXPLAYERS+1];

new bool:g_bHasSavedFogSettings[MAXPLAYERS+1];

new g_iSavedSkyboxFog_Enable[MAXPLAYERS+1];
new g_iSavedSkyboxFog_Blend[MAXPLAYERS+1];
new g_iSavedSkyboxFog_ColorPrimary[MAXPLAYERS+1];
new Float:g_fSavedSkyboxFog_Start[MAXPLAYERS+1];
new Float:g_fSavedSkyboxFog_End[MAXPLAYERS+1];
new Float:g_fSavedSkyboxFog_MaxDensity[MAXPLAYERS+1];

new const g_iFogColor[] = {25, 25, 25, 255};
#define FOG_DIST_MIN_GUARDS		0.0
#define FOG_DIST_MAX_GUARDS		120.0

#define FOG_DIST_MIN_PRISONERS	0.0
#define FOG_DIST_MAX_PRISONERS	0.0
#define FOG_DENSITY_PRISONERS	0.97

#define BUFF_TEAM_TIME	45.0

#define GUARD_FOG_DENSITY_START	1.0
#define GUARD_FOG_DENSITY_DECREMENT	0.00025
new Float:g_fGuardFogDensity;

#define FFA_SPEED					0.8
#define GUARD_SPEED					1.0
#define PRISONER_SPEED_START		0.5
#define PRISONER_SPEED_INCREMENT	0.07
new Float:g_fPrisonerSpeed;

#define PRISONER_GRAVITY	0.6

#define MIN_SPEED_FOR_MOVE_SOUND	10.0
#define MOVE_SOUND_MIN_DELAY				1.7
#define MOVE_SOUND_MAX_ADDITIONAL_DELAY		0.9
new const String:SZ_SOUND_MOVING[] = "sound/swoobles/ultimate_jailbreak/cowbell.mp3";

new Handle:g_hTimer_BuffTeams;

new bool:g_bIsFFA;

new Handle:cvar_footsteps;
new bool:g_bOriginalFootsteps;


public OnPluginStart()
{
	CreateConVar("warday_horror_movie_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_footsteps = FindConVar("sv_footsteps");
}

public OnMapStart()
{
	AddFileToDownloadsTable(SZ_SOUND_MOVING);
	PrecacheSoundAny(SZ_SOUND_MOVING[6]);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_DISABLE_GUARDS_RADAR | DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_KILL_WORLD_WEAPONS, OnDayStart, OnDayEnd, OnFreezeEnd);
	UltJB_Day_AllowFreeForAll(iDayID, true);
}

public OnClientPutInServer(iClient)
{
	g_bHasSavedFogSettings[iClient] = false;
}

public OnDayStart(iClient)
{
	if(cvar_footsteps != INVALID_HANDLE)
	{
		g_bOriginalFootsteps = GetConVarBool(cvar_footsteps);
		SetConVarBool(cvar_footsteps, false, true, false);
	}
	
	g_bIsFFA = UltJB_Day_IsFreeForAll();
	
	g_fPrisonerSpeed = PRISONER_SPEED_START;
	g_fGuardFogDensity = GUARD_FOG_DENSITY_START;
}

CreateCustomFogControllerEnt(const Float:fDistMin, const Float:fDistMax, const Float:fDensity)
{
	new iEnt = CreateEntityByName("env_fog_controller");
	if(iEnt < 1)
		return -1;
	
	DispatchSpawn(iEnt);
	
	new iColorCombined = (g_iFogColor[3] << 24) | (g_iFogColor[2] << 16) | (g_iFogColor[1] << 8) | g_iFogColor[0];
	SetEntProp(iEnt, Prop_Send, "m_fog.enable", 1);
	SetEntProp(iEnt, Prop_Send, "m_fog.blend", 0);
	SetEntProp(iEnt, Prop_Send, "m_fog.colorPrimary", iColorCombined);
	SetEntPropFloat(iEnt, Prop_Send, "m_fog.start", fDistMin);
	SetEntPropFloat(iEnt, Prop_Send, "m_fog.end", fDistMax);
	SetEntPropFloat(iEnt, Prop_Send, "m_fog.maxdensity", fDensity);
	
	return iEnt;
}

SetCustomFogControllerOnClients(iCustomFogControllerGuards, iCustomFogControllerPrisoners)
{
	decl iOriginalFogController, iColorCombined;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		g_bHasSavedFogSettings[iClient] = true;
		
		iOriginalFogController = GetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl");
		if(iOriginalFogController > 0)
			g_iOriginalFogControllerRef[iClient] = EntIndexToEntRef(iOriginalFogController);
		else
			g_iOriginalFogControllerRef[iClient] = INVALID_ENT_REFERENCE;
		
		g_iSavedSkyboxFog_Enable[iClient] = GetEntProp(iClient, Prop_Send, "m_skybox3d.fog.enable");
		g_iSavedSkyboxFog_Blend[iClient] = GetEntProp(iClient, Prop_Send, "m_skybox3d.fog.blend");
		g_iSavedSkyboxFog_ColorPrimary[iClient] = GetEntProp(iClient, Prop_Send, "m_skybox3d.fog.colorPrimary");
		g_fSavedSkyboxFog_Start[iClient] = GetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start");
		g_fSavedSkyboxFog_End[iClient] = GetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end");
		g_fSavedSkyboxFog_MaxDensity[iClient] = GetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity");
		
		// NOTE: This won't actually modify the skybox fog. We need to access the sky_camera fog settings but those have no send props.
		// It only modifies the entities in the horizon of the skybox.
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.enable", 1);
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.blend", 0);
		
		iColorCombined = (g_iFogColor[3] << 24) | (g_iFogColor[2] << 16) | (g_iFogColor[1] << 8) | g_iFogColor[0];
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.colorPrimary", iColorCombined);
		
		if(g_bIsFFA)
		{
			// We need to change guards to be a prisoner model since we will use their completely white skin that we can render it the fog color.
			UltJB_PlayerModels_ApplyPrisonerModel(iClient);
			
			// Set everyone to be the same color as the fog.
			SetEntityRenderColor(iClient, g_iFogColor[0], g_iFogColor[1], g_iFogColor[2], g_iFogColor[3]);
			SetEntProp(iClient, Prop_Send, "m_nSkin", 1);
			
			// Use the guards fog controller for FFA.
			SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", iCustomFogControllerGuards);
			SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start", FOG_DIST_MIN_GUARDS);
			SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end", FOG_DIST_MAX_GUARDS);
			SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity", g_fGuardFogDensity);
			
			SetEntityGravity(iClient, PRISONER_GRAVITY);
		}
		else
		{
			switch(GetClientTeam(iClient))
			{
				case TEAM_GUARDS:
				{
					SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", iCustomFogControllerGuards);
					SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start", FOG_DIST_MIN_GUARDS);
					SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end", FOG_DIST_MAX_GUARDS);
					SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity", g_fGuardFogDensity);
				}
				case TEAM_PRISONERS:
				{
					SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", iCustomFogControllerPrisoners);
					SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start", FOG_DIST_MIN_PRISONERS);
					SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end", FOG_DIST_MAX_PRISONERS);
					SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity", FOG_DENSITY_PRISONERS);
					
					// Set prisoners to be the same color as the fog.
					SetEntityRenderColor(iClient, g_iFogColor[0], g_iFogColor[1], g_iFogColor[2], g_iFogColor[3]);
					SetEntProp(iClient, Prop_Send, "m_nSkin", 1);
					
					SetEntityGravity(iClient, PRISONER_GRAVITY);
				}
			}
		}
	}
}

SetCustomFogControllerDensity(iCustomController, Float:fDensity)
{
	SetEntPropFloat(iCustomController, Prop_Send, "m_fog.maxdensity", fDensity);
	
	decl iCurrentFogController;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!g_bHasSavedFogSettings[iClient])
			continue;
		
		iCurrentFogController = GetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl");
		if(iCurrentFogController != iCustomController)
			continue;
		
		SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity", fDensity);
	}
}

RemoveCustomFogControllers()
{
	decl iOriginalController;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!g_bHasSavedFogSettings[iClient])
			continue;
		
		iOriginalController = EntRefToEntIndex(g_iOriginalFogControllerRef[iClient]);
		SetEntPropEnt(iClient, Prop_Send, "m_PlayerFog.m_hCtrl", (iOriginalController > 0) ? iOriginalController : -1);
		
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.enable", g_iSavedSkyboxFog_Enable[iClient]);
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.blend", g_iSavedSkyboxFog_Blend[iClient]);
		SetEntProp(iClient, Prop_Send, "m_skybox3d.fog.colorPrimary", g_iSavedSkyboxFog_ColorPrimary[iClient]);
		SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.start", g_fSavedSkyboxFog_Start[iClient]);
		SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.end", g_fSavedSkyboxFog_End[iClient]);
		SetEntPropFloat(iClient, Prop_Send, "m_skybox3d.fog.maxdensity", g_fSavedSkyboxFog_MaxDensity[iClient]);
	}
	
	new iCustomController = EntRefToEntIndex(g_iCustomFogControllerPrisonersRef);
	if(iCustomController && iCustomController != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iCustomController, "KillHierarchy");
	
	iCustomController = EntRefToEntIndex(g_iCustomFogControllerGuardsRef);
	if(iCustomController && iCustomController != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iCustomController, "KillHierarchy");
}

public OnFreezeEnd()
{
	new iCustomFogControllerGuards = CreateCustomFogControllerEnt(FOG_DIST_MIN_GUARDS, FOG_DIST_MAX_GUARDS, g_fGuardFogDensity);
	if(iCustomFogControllerGuards != -1)
		g_iCustomFogControllerGuardsRef = EntIndexToEntRef(iCustomFogControllerGuards);
	
	new iCustomFogControllerPrisoners = CreateCustomFogControllerEnt(FOG_DIST_MIN_PRISONERS, FOG_DIST_MAX_PRISONERS, FOG_DENSITY_PRISONERS);
	if(iCustomFogControllerPrisoners != -1)
		g_iCustomFogControllerPrisonersRef = EntIndexToEntRef(iCustomFogControllerPrisoners);
	
	SetCustomFogControllerOnClients(iCustomFogControllerGuards, iCustomFogControllerPrisoners);
	
	decl iWeapon;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(g_bIsFFA)
		{
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
			iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_SAWEDOFF);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
			
			SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", FFA_SPEED);
			
			SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
		}
		else
		{
			switch(GetClientTeam(iClient))
			{
				case TEAM_GUARDS:
				{
					UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
					iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_SAWEDOFF);
					SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
					
					SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", GUARD_SPEED);
				}
				case TEAM_PRISONERS:
				{
					iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
					SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
					
					SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", g_fPrisonerSpeed);
					
					SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
				}
			}
		}
	}
	
	StartTimer_BuffTeams();
}

SetPrisonersSpeed(Float:fSpeed)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		switch(GetClientTeam(iClient))
		{
			case TEAM_PRISONERS:
			{
				SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", fSpeed);
			}
		}
	}
}

public OnDayEnd(iClient)
{
	StopTimer_BuffTeams();
	RemoveCustomFogControllers();
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		SDKUnhook(iPlayer, SDKHook_PostThinkPost, OnPostThinkPost);
	}
	
	if(cvar_footsteps != INVALID_HANDLE)
		SetConVarBool(cvar_footsteps, g_bOriginalFootsteps, true, false);
}

public OnPostThinkPost(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	static Float:fVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	
	new Float:fSpeed = GetVectorLength(fVelocity);
	if(fSpeed < MIN_SPEED_FOR_MOVE_SOUND)
		return;
	
	static Float:fNextMoveSound[MAXPLAYERS+1], Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < fNextMoveSound[iClient])
		return;
	
	if(fSpeed > 170.0)
		fSpeed = 170.0;
	
	new Float:fAdditionalDelay = MOVE_SOUND_MAX_ADDITIONAL_DELAY - RemapRangeValueFloat(fSpeed, MIN_SPEED_FOR_MOVE_SOUND, 170.0, 0.0, MOVE_SOUND_MAX_ADDITIONAL_DELAY);
	fNextMoveSound[iClient] = fCurTime + MOVE_SOUND_MIN_DELAY + fAdditionalDelay;
	
	new iPitch = RoundFloat(RemapRangeValueFloat(fSpeed, MIN_SPEED_FOR_MOVE_SOUND, 170.0, 85.0, 100.0));
	
	// Emit sound at lower volume to self.
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		if(iPlayer == iClient)
			EmitSoundToClientAny(iPlayer, SZ_SOUND_MOVING[6], iClient, SNDCHAN_ITEM, 65, _, 0.11, iPitch);
		else
			EmitSoundToClientAny(iPlayer, SZ_SOUND_MOVING[6], iClient, SNDCHAN_ITEM, 60, _, _, iPitch);
	}
}

stock RemapRangeValue(iValue, iRange1Min, iRange1Max, iRange2Min, iRange2Max)
{
	return (iRange2Min + (iValue - iRange1Min) * (iRange2Max - iRange2Min) / (iRange1Max - iRange1Min));
}

stock Float:RemapRangeValueFloat(Float:fValue, Float:fRange1Min, Float:fRange1Max, Float:fRange2Min, Float:fRange2Max)
{
	return (fRange2Min + (fValue - fRange1Min) * (fRange2Max - fRange2Min) / (fRange1Max - fRange1Min));
}

StartTimer_BuffTeams()
{
	StopTimer_BuffTeams();
	g_hTimer_BuffTeams = CreateTimer(BUFF_TEAM_TIME, Timer_BuffTeams, _, TIMER_REPEAT);
}

StopTimer_BuffTeams()
{
	if(g_hTimer_BuffTeams == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_BuffTeams);
	g_hTimer_BuffTeams = INVALID_HANDLE;
}

public Action:Timer_BuffTeams(Handle:hTimer)
{
	// Remove some of the guards fog.
	g_fGuardFogDensity -= GUARD_FOG_DENSITY_DECREMENT;
	if(g_fGuardFogDensity < 0.1)
		g_fGuardFogDensity = 0.1;
	
	new iCustomController = EntRefToEntIndex(g_iCustomFogControllerGuardsRef);
	if(iCustomController && iCustomController != INVALID_ENT_REFERENCE)
		SetCustomFogControllerDensity(iCustomController, g_fGuardFogDensity);
	
	if(g_bIsFFA)
	{
		PrintHintTextToAll("<font color='#257edd'>Everyones vision improved.</font>");
	}
	else
	{
		// Increase the prisoners speed.
		g_fPrisonerSpeed += PRISONER_SPEED_INCREMENT;
		SetPrisonersSpeed(g_fPrisonerSpeed);
		
		PrintHintTextToAll("<font color='#ddaf25'>Prisoners speed increased.</font>\n<font color='#257edd'>Guards vision improved.</font>");
	}
	
	return Plugin_Continue;
}