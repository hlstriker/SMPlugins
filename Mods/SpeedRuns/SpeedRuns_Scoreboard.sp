#pragma semicolon 1
 
#include <sourcemod>
#include <cstrike>
 
#include "Includes/speed_runs"
 
#define PLUGIN_VERSION   "1.0"
 
new Handle:g_hTimer_Scoreboard[MAXPLAYERS + 1];

new bool:g_bSpeedRuns;
 
public Plugin:myinfo = {
    name = "SpeedRuns Scoreboard",
    author = "Scoutkllr and Hymns For Disco",
    version = PLUGIN_VERSION,
    description = "Adds timer info to player scoreboard.",
    url = "swoobles.com"
};
 
public OnAllPluginsLoaded()
{
    g_bSpeedRuns = LibraryExists("speed_runs");
   
    if (!g_bSpeedRuns)
        SetFailState("SpeedRuns_Core is required to run this plugin!");
}

public OnClientConnected(iClient)
	StartTimer_Scoreboard(iClient);

public OnClientDisconnect(iClient)
	StopTimer_Scoreboard(iClient);


StopTimer_Scoreboard(iClient)
{
	if(g_hTimer_Scoreboard[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Scoreboard[iClient]);
	g_hTimer_Scoreboard[iClient] = INVALID_HANDLE;
}

StartTimer_Scoreboard(iClient)
{
	StopTimer_Scoreboard(iClient);
	g_hTimer_Scoreboard[iClient] = CreateTimer(1.0, Timer_Scoreboard, GetClientSerial(iClient), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

SetKills(iClient, iKills)
    SetEntProp(iClient, Prop_Data, "m_iFrags", iKills);
 
SetAssists(iClient, iAssists)
    SetEntData(iClient, FindDataMapInfo(iClient, "m_iFrags") + 4, iAssists);
 
SetDeaths(iClient, iDeaths)
    SetEntProp(iClient, Prop_Data, "m_iDeaths", iDeaths);

public Action:Timer_Scoreboard(Handle:hTimer, any:iClientSerial)
{
    new iClient = GetClientFromSerial(iClientSerial);

    if (!iClient || !IsClientInGame(iClient))
        return;

    new iStage = SpeedRuns_GetCurrentStage(iClient);
    SetAssists(iClient, iStage);

    if (IsPlayerAlive(iClient))
    {
        SetKills(iClient, RoundToNearest(SpeedRuns_GetTotalRunTime(iClient)));
        if (iStage > 1)
            SetDeaths(iClient, RoundToNearest(SpeedRuns_GetStageRunTime(iClient)));
        else
            SetDeaths(iClient, 0);
    }
    else  // If player is dead, don't show their run times.
    {
        SetKills(iClient, 0);
        SetDeaths(iClient, 0);
    }
}

public SpeedRuns_OnStageCompleted_Post(iClient, iStageNum, iStyleBits, Float:fTimeTaken)
    if (iStageNum == 0) // Stage 0 is total map run
        CS_SetMVPCount(iClient, CS_GetMVPCount(iClient) + 1);
