#include <sourcemod>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Libraries/ClientCookies/client_cookies"
#include "Includes/speed_runs"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Experience";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed run experience plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define HIGHEST_TIER_COMPLETION_EXP 200
new g_iClientTotalExperience[MAXPLAYERS+1];
new g_iClientCachedLevel[MAXPLAYERS+1];
new g_iClientCachedExpInCurrentLevel[MAXPLAYERS+1];
new g_iClientCachedExpForNextLevel[MAXPLAYERS+1];

#define MAX_AUTHID_LEN 32
new Handle:g_aCompletedStages;
enum _:CompletedStages
{
	String:Completed_AuthID[MAX_AUTHID_LEN],
	Handle:Completed_StageNumbers,
	Completed_StyleBits
};

new g_iTotalStages;

// TODO: Get a level up sound effect.
// TODO: Make a level up particle effect.

new Handle:g_hFwd_OnExperienceGiven;
new Handle:g_hFwd_OnLevelUp;

new Handle:cvar_sr_group_name;
new ClientCookieType:g_iCookieTypeToUseForExp;


public OnPluginStart()
{
	CreateConVar("speed_runs_experience_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if((cvar_sr_group_name = FindConVar("speedruns_group_name")) == INVALID_HANDLE)
		cvar_sr_group_name = CreateConVar("speedruns_group_name", "", "The group name to use for this server (applied on map change)");
	
	g_aCompletedStages = CreateArray(CompletedStages);
	
	g_hFwd_OnExperienceGiven = CreateGlobalForward("SpeedRunsExp_OnExperienceGiven", ET_Ignore, Param_Cell, Param_Cell);
	g_hFwd_OnLevelUp = CreateGlobalForward("SpeedRunsExp_OnLevelUp", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("speed_runs_experience");
	
	CreateNative("SpeedRunsExp_GetClientLevel", _SpeedRunsExp_GetClientLevel);
	CreateNative("SpeedRunsExp_GetClientExpInCurrentLevel", _SpeedRunsExp_GetClientExpInCurrentLevel);
	CreateNative("SpeedRunsExp_GetClientExpForNextLevel", _SpeedRunsExp_GetClientExpForNextLevel);
	
	return APLRes_Success;
}

public _SpeedRunsExp_GetClientLevel(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRunsExp_GetClientLevel");
		return 0;
	}
	
	return g_iClientCachedLevel[GetNativeCell(1)];
}

public _SpeedRunsExp_GetClientExpInCurrentLevel(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRunsExp_GetClientExpInCurrentLevel");
		return 0;
	}
	
	return g_iClientCachedExpInCurrentLevel[GetNativeCell(1)];
}

public _SpeedRunsExp_GetClientExpForNextLevel(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRunsExp_GetClientExpForNextLevel");
		return 0;
	}
	
	return g_iClientCachedExpForNextLevel[GetNativeCell(1)];
}

public OnMapStart()
{
	g_iTotalStages = 0;
	
	// We only clear the completed stages on map start since we don't want players reconnecting on a single map to get more EXP.
	decl eCompletedStages[CompletedStages];
	for(new i=0; i<GetArraySize(g_aCompletedStages); i++)
	{
		GetArrayArray(g_aCompletedStages, i, eCompletedStages);
		
		if(eCompletedStages[Completed_StageNumbers] != INVALID_HANDLE)
			CloseHandle(eCompletedStages[Completed_StageNumbers]);
	}
	
	ClearArray(g_aCompletedStages);
	
	// Get the cookie type to use for exp.
	decl String:szGroupName[32];
	GetConVarString(cvar_sr_group_name, szGroupName, sizeof(szGroupName));
	
	if(StrEqual(szGroupName, "surf", false))
	{
		g_iCookieTypeToUseForExp = CC_TYPE_SPEEDRUNS_EXPERIENCE_SURF;
	}
	else if(StrEqual(szGroupName, "bhop", false))
	{
		g_iCookieTypeToUseForExp = CC_TYPE_SPEEDRUNS_EXPERIENCE_BHOP;
	}
	else if(StrEqual(szGroupName, "course", false))
	{
		g_iCookieTypeToUseForExp = CC_TYPE_SPEEDRUNS_EXPERIENCE_COURSE;
	}
	else if(StrEqual(szGroupName, "kz", false))
	{
		g_iCookieTypeToUseForExp = CC_TYPE_SPEEDRUNS_EXPERIENCE_KZ;
	}
	else if(StrEqual(szGroupName, "rocket", false))
	{
		g_iCookieTypeToUseForExp = CC_TYPE_SPEEDRUNS_EXPERIENCE_ROCKET;
	}
	else
	{
		g_iCookieTypeToUseForExp = ClientCookieType:-1;
	}
}

public OnClientConnected(iClient)
{
	g_iClientTotalExperience[iClient] = 0;
	CacheClientExperience(iClient);
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, g_iCookieTypeToUseForExp))
	{
		g_iClientTotalExperience[iClient] += ClientCookies_GetCookie(iClient, g_iCookieTypeToUseForExp);
		CacheClientExperience(iClient);
	}
	
	// Instantly set experience here incase they already had some before cookies were loaded.
	// We set here because we didn't set it before cookies were loaded since that could result in data loss.
	// Consider setting the EXP variable when its 0 and the client disconnects before cookies are loaded.
	ClientCookies_SetCookie(iClient, g_iCookieTypeToUseForExp, g_iClientTotalExperience[iClient]);
}

public SpeedRuns_OnStageCompleted_Pre(iClient, iStageNumber, iStyleBits, Float:fTimeTaken)
{
	HandleStageCompletion(iClient, iStageNumber, iStyleBits);
}

HandleStageCompletion(iClient, iStageNumber, iStyleBits)
{
	new iIndex = GetCompletedStagesIndex(iClient, iStyleBits);
	if(iIndex == -1)
		return;
	
	decl eCompletedStages[CompletedStages];
	GetArrayArray(g_aCompletedStages, iIndex, eCompletedStages);
	
	if(eCompletedStages[Completed_StageNumbers] == INVALID_HANDLE)
		return;
	
	new bool:bMapAlreadyCompleted;
	for(new i=0; i<GetArraySize(eCompletedStages[Completed_StageNumbers]); i++)
	{
		if(GetArrayCell(eCompletedStages[Completed_StageNumbers], i) != iStageNumber)
			continue;
		
		// We don't return if the map record was already completed since we give half exp for every completion after the first.
		if(iStageNumber == 0)
		{
			bMapAlreadyCompleted = true;
			break;
		}
		
		// Return if the stage was already completed.
		return;
	}
	
	decl iReturn;
	if(iStageNumber)
		iReturn = GiveStageCompletionExperience(iClient);
	else
		iReturn = GiveMapCompletionExperience(iClient, bMapAlreadyCompleted);
	
	if(iReturn && !bMapAlreadyCompleted)
		PushArrayCell(eCompletedStages[Completed_StageNumbers], iStageNumber);
}

GetCompletedStagesIndex(iClient, iStyleBits)
{
	decl String:szAuthID[MAX_AUTHID_LEN];
	if(!GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID)))
		return -1;
	
	decl eCompletedStages[CompletedStages];
	for(new i=0; i<GetArraySize(g_aCompletedStages); i++)
	{
		GetArrayArray(g_aCompletedStages, i, eCompletedStages);
		
		if(eCompletedStages[Completed_StyleBits] != iStyleBits)
			continue;
		
		if(!StrEqual(szAuthID, eCompletedStages[Completed_AuthID]))
			continue;
		
		return i;
	}
	
	strcopy(eCompletedStages[Completed_AuthID], MAX_AUTHID_LEN, szAuthID);
	eCompletedStages[Completed_StageNumbers] = CreateArray();
	eCompletedStages[Completed_StyleBits] = iStyleBits;
	
	return PushArrayArray(g_aCompletedStages, eCompletedStages);
}

bool:GiveStageCompletionExperience(iClient)
{
	new iData = GetTotalStages();
	if(!iData)
		return false;
	
	iData = GetMapCompletionExperience() / iData;
	if(!iData)
		return false;
	
	return GiveExperience(iClient, iData);
}

bool:GiveMapCompletionExperience(iClient, bool:bMapAlreadyCompleted)
{
	new iExp = GetMapCompletionExperience();
	
	// If the map was already completed we only give half exp.
	if(bMapAlreadyCompleted)
		iExp = RoundFloat(iExp / 2.0);
	
	if(!iExp)
		return false;
	
	return GiveExperience(iClient, iExp);
}

GetMapCompletionExperience()
{
	new Float:fPercent = float(SpeedRuns_GetMapTier()) / SpeedRuns_GetMapTierMax();
	return RoundFloat(HIGHEST_TIER_COMPLETION_EXP * fPercent);
}

GetTotalStages()
{
	if(g_iTotalStages)
		return g_iTotalStages;
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	
	g_iTotalStages = GetArraySize(hZoneIDs);
	CloseHandle(hZoneIDs);
	
	return g_iTotalStages;
}

public ZoneManager_OnTypeAssigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TIMER_START && iZoneType != ZONE_TYPE_TIMER_END_START)
		return;
	
	g_iTotalStages = 0;
	GetTotalStages();
}

public ZoneManager_OnTypeUnassigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TIMER_START && iZoneType != ZONE_TYPE_TIMER_END_START)
		return;
	
	g_iTotalStages = 0;
	GetTotalStages();
}

bool:GiveExperience(iClient, iAmount)
{
	if(_:g_iCookieTypeToUseForExp == -1)
		return false;
	
	if(iAmount < 1)
		return false;
	
	new iOldLevel = g_iClientCachedLevel[iClient];
	
	g_iClientTotalExperience[iClient] += iAmount;
	CacheClientExperience(iClient);
	
	decl result;
	Call_StartForward(g_hFwd_OnExperienceGiven);
	Call_PushCell(iClient);
	Call_PushCell(iAmount);
	Call_Finish(result);
	
	if(iOldLevel != g_iClientCachedLevel[iClient])
	{
		Call_StartForward(g_hFwd_OnLevelUp);
		Call_PushCell(iClient);
		Call_PushCell(iOldLevel);
		Call_PushCell(g_iClientCachedLevel[iClient]);
		Call_Finish(result);
	}
	
	// Make sure we only set the cookie here if they are loaded so there isn't data loss.
	if(ClientCookies_HaveCookiesLoaded(iClient))
		ClientCookies_SetCookie(iClient, g_iCookieTypeToUseForExp, g_iClientTotalExperience[iClient]);
	
	return true;
}

CacheClientExperience(iClient)
{
	g_iClientCachedLevel[iClient] = GetLevelFromExperience(g_iClientTotalExperience[iClient]);
	g_iClientCachedExpInCurrentLevel[iClient] = GetClientsExperienceInCurrentLevel(iClient);
	g_iClientCachedExpForNextLevel[iClient] = GetExperienceForNextLevel(g_iClientCachedLevel[iClient]);
}

GetClientsExperienceInCurrentLevel(iClient)
{
	decl iTotalExpForNextLevel;
	new iLevel = GetLevelFromExperience(g_iClientTotalExperience[iClient], iTotalExpForNextLevel);
	return (GetExperienceForNextLevel(iLevel) - (iTotalExpForNextLevel - g_iClientTotalExperience[iClient]));
}

GetExperienceForNextLevel(iLevel)
{
	new iNextLevelExp = 30;
	
	for(new i=0; i<iLevel; i++)
	{
		if((i + 1) == iLevel)
			return iNextLevelExp;
		
		iNextLevelExp = RoundToCeil(iNextLevelExp + (iNextLevelExp * 0.05) + 5.0);
	}
	
	return 99999999;
}

GetLevelFromExperience(iExperience, &iTotalExp=0)
{
	new iNextLevelExp = 30;
	new iLevel = 1;
	
	iTotalExp = iNextLevelExp;
	
	decl i;
	for(i=0; i<9999; i++)
	{
		if(iExperience < iTotalExp)
			return iLevel;
		
		iNextLevelExp = RoundToCeil(iNextLevelExp + (iNextLevelExp * 0.05) + 5.0);
		iTotalExp += iNextLevelExp;
		
		iLevel++;
	}
	
	return i;
}