#include <sourcemod>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Plugins/UserPoints/user_points"
#include "Includes/speed_runs"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Points";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed run points plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define HIGHEST_TIER_COMPLETION_POINTS	600.0

#define MAX_AUTHID_LEN	32
new Handle:g_aCompletedStages;
enum _:CompletedStages
{
	String:Completed_AuthID[MAX_AUTHID_LEN],
	Handle:Completed_StageNumbers
};

new g_iTotalStages;


public OnPluginStart()
{
	CreateConVar("speed_runs_points_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aCompletedStages = CreateArray(CompletedStages);
}

public OnMapStart()
{
	g_iTotalStages = 0;
	
	// We only clear the completed stages on map start since we don't want players reconnecting on a single map to get more points.
	decl eCompletedStages[CompletedStages];
	for(new i=0; i<GetArraySize(g_aCompletedStages); i++)
	{
		GetArrayArray(g_aCompletedStages, i, eCompletedStages);
		
		if(eCompletedStages[Completed_StageNumbers] != INVALID_HANDLE)
			CloseHandle(eCompletedStages[Completed_StageNumbers]);
	}
	
	ClearArray(g_aCompletedStages);
}

public SpeedRuns_OnStageCompleted_Pre(iClient, iStageNumber, iStyleBits, Float:fTimeTaken)
{
	HandleStageCompletion(iClient, iStageNumber);
}

HandleStageCompletion(iClient, iStageNumber)
{
	// Don't give points for beating the map, only give for individual stages.
	if(iStageNumber == 0)
		return;
	
	new iIndex = GetCompletedStagesIndex(iClient);
	if(iIndex == -1)
		return;
	
	decl eCompletedStages[CompletedStages];
	GetArrayArray(g_aCompletedStages, iIndex, eCompletedStages);
	
	if(eCompletedStages[Completed_StageNumbers] == INVALID_HANDLE)
		return;
	
	// Return if the stage was already completed.
	if(FindValueInArray(eCompletedStages[Completed_StageNumbers], iStageNumber) != -1)
		return;
	
	if(GiveStageCompletionPoints(iClient))
		PushArrayCell(eCompletedStages[Completed_StageNumbers], iStageNumber);
}

GetCompletedStagesIndex(iClient)
{
	decl String:szAuthID[MAX_AUTHID_LEN];
	if(!GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID)))
		return -1;
	
	decl eCompletedStages[CompletedStages];
	for(new i=0; i<GetArraySize(g_aCompletedStages); i++)
	{
		GetArrayArray(g_aCompletedStages, i, eCompletedStages);
		
		if(!StrEqual(szAuthID, eCompletedStages[Completed_AuthID]))
			continue;
		
		return i;
	}
	
	strcopy(eCompletedStages[Completed_AuthID], MAX_AUTHID_LEN, szAuthID);
	eCompletedStages[Completed_StageNumbers] = CreateArray();
	
	return PushArrayArray(g_aCompletedStages, eCompletedStages);
}

bool:GiveStageCompletionPoints(iClient)
{
	new iData = GetTotalStages();
	if(!iData)
		return false;
	
	iData = RoundFloat(GetMapCompletionPoints() / float(iData));
	if(!iData)
		return false;
	
	return GivePoints(iClient, iData);
}

Float:GetMapCompletionPoints()
{
	new Float:fPercent = float(SpeedRuns_GetMapTier()) / float(SpeedRuns_GetMapTierMax());
	return (HIGHEST_TIER_COMPLETION_POINTS * fPercent);
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

bool:GivePoints(iClient, iAmount)
{
	if(iAmount < 1)
		return false;
	
	UserPoints_GivePoints(iClient, iAmount);
	CPrintToChat(iClient, "{lightgreen}-- {olive}Awarded {lightred}%d {olive}store points for beating a stage.", iAmount);
	
	return true;
}