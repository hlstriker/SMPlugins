#include <sourcemod>
#include <cstrike>
#include "../ClientSettings/client_settings"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Client Times";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to handle clients times in the server.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fConnectTime[MAXPLAYERS+1];

new g_iOldButtons[MAXPLAYERS+1];
new Float:g_fNextAwayCheck[MAXPLAYERS+1];
new Float:g_fLastValidAction[MAXPLAYERS+1];

new const NUM_ACTIONS_REQ_PER_MIN = 1; // NOTE: Just set this to 1 for now so the first time the client presses a key it marks them as back.
new Float:g_fNextActionMinuteUpdate[MAXPLAYERS+1];
new g_iNumActionsPerMinCount[MAXPLAYERS+1];

new Handle:g_hClanTagTimes[MAXPLAYERS+1];
new String:g_szCurrentClanTag[MAXPLAYERS+1][MAX_CLAN_TAG_LENGTH+1];
new Float:g_fClanTagStartTime[MAXPLAYERS+1];
new Handle:g_hFwd_OnClanTagTimeUpdated;

enum _:HookedPlugins
{
	HookedPluginSeconds,
	Handle:HookedPluginHandle,
	bool:HookedPluginIsClientAway[MAXPLAYERS+1],
	Float:HookedPluginAwayStartTime[MAXPLAYERS+1],
	Float:HookedPluginAwayTotalTime[MAXPLAYERS+1],
	Handle:HookedPluginForwardAway,
	Handle:HookedPluginForwardBack
};

new Handle:g_aHookedPlugins;


public OnPluginStart()
{
	CreateConVar("api_client_times_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnClanTagTimeUpdated = CreateGlobalForward("ClientTimes_OnClanTagTimeUpdated", ET_Ignore, Param_Cell, Param_String, Param_Float);
	
	g_aHookedPlugins = CreateArray(HookedPlugins);
	HookEvent("player_team", EventPlayerTeam_Post, EventHookMode_Post);
}

public EventPlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// When players join a team we need to force it as a valid command so they are marked as back if needed.
	CheckValidAction(GetClientOfUserId(GetEventInt(hEvent, "userid")), true);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("client_times");
	
	CreateNative("ClientTimes_SetTimeBeforeMarkedAsAway", _ClientTimes_SetTimeBeforeMarkedAsAway);
	
	CreateNative("ClientTimes_GetTimeInServer", _ClientTimes_GetTimeInServer);
	CreateNative("ClientTimes_GetTimePlayed", _ClientTimes_GetTimePlayed);
	CreateNative("ClientTimes_GetTimeAway", _ClientTimes_GetTimeAway);
	CreateNative("ClientTimes_GetClanTagTime", _ClientTimes_GetClanTagTime);
	
	return APLRes_Success;
}

public _ClientTimes_GetTimeAway(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iClient = GetNativeCell(1);
	ForceUpdateClientsAwayTime(iClient, hPlugin);
	
	decl eHookedPlugin[HookedPlugins];
	for(new i=0; i<GetArraySize(g_aHookedPlugins); i++)
	{
		GetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		if(eHookedPlugin[HookedPluginHandle] != hPlugin)
			continue;
		
		return RoundFloat(eHookedPlugin[HookedPluginAwayTotalTime][iClient]);
	}
	
	return 0;
}

public _ClientTimes_GetTimePlayed(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iClient = GetNativeCell(1);
	ForceUpdateClientsAwayTime(iClient, hPlugin);
	
	decl eHookedPlugin[HookedPlugins];
	for(new i=0; i<GetArraySize(g_aHookedPlugins); i++)
	{
		GetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		if(eHookedPlugin[HookedPluginHandle] != hPlugin)
			continue;
		
		return RoundFloat(GetGameTime() - g_fConnectTime[iClient] - eHookedPlugin[HookedPluginAwayTotalTime][iClient]);
	}
	
	return 0;
}

public _ClientTimes_GetTimeInServer(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	return RoundFloat(GetGameTime() - g_fConnectTime[GetNativeCell(1)]);
}

public _ClientTimes_GetClanTagTime(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iLength;
	if(GetNativeStringLength(2, iLength) != SP_ERROR_NONE)
		return 0;
	
	iLength++;
	decl String:szClanTag[iLength];
	GetNativeString(2, szClanTag, iLength);
	
	return GetClanTagTime(GetNativeCell(1), szClanTag);
}

RemoveAllUnusedPlugins(const Handle:hCallingPlugin)
{
	new Handle:hLoadedPlugins = CreateArray();
	
	decl Handle:hPlugin;
	new Handle:hIterator = GetPluginIterator();
	while(MorePlugins(hIterator))
	{
		hPlugin = ReadPlugin(hIterator);
		
		// We want to remove the calling plugin as well so we can reinsert it.
		if(hPlugin != hCallingPlugin)
			PushArrayCell(hLoadedPlugins, hPlugin);
	}
	
	CloseHandle(hIterator);
	
	// Remove the unused plugins.
	decl eHookedPlugin[HookedPlugins];
	new iArraySize = GetArraySize(g_aHookedPlugins);
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		
		if(FindValueInArray(hLoadedPlugins, eHookedPlugin[HookedPluginHandle]) != -1)
			continue;
		
		// Remove this plugin.
		if(eHookedPlugin[HookedPluginForwardAway] != INVALID_HANDLE)
			CloseHandle(eHookedPlugin[HookedPluginForwardAway]);
		
		if(eHookedPlugin[HookedPluginForwardBack] != INVALID_HANDLE)
			CloseHandle(eHookedPlugin[HookedPluginForwardBack]);
		
		RemoveFromArray(g_aHookedPlugins, i);
		iArraySize = GetArraySize(g_aHookedPlugins);
		i--;
	}
	
	CloseHandle(hLoadedPlugins);
}

public _ClientTimes_SetTimeBeforeMarkedAsAway(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	RemoveAllUnusedPlugins(hPlugin);
	
	new eHookedPlugin[HookedPlugins];
	eHookedPlugin[HookedPluginSeconds] = GetNativeCell(1);
	eHookedPlugin[HookedPluginHandle] = hPlugin;
	
	new Function:away_callback = GetNativeCell(2);
	if(away_callback != INVALID_FUNCTION)
	{
		eHookedPlugin[HookedPluginForwardAway] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(eHookedPlugin[HookedPluginForwardAway], hPlugin, away_callback);
	}
	
	new Function:back_callback = GetNativeCell(3);
	if(back_callback != INVALID_FUNCTION)
	{
		eHookedPlugin[HookedPluginForwardBack] = CreateForward(ET_Ignore, Param_Cell);
		AddToForward(eHookedPlugin[HookedPluginForwardBack], hPlugin, back_callback);
	}
	
	PushArrayArray(g_aHookedPlugins, eHookedPlugin);
	
	return true;
}

public OnClientConnected(iClient)
{
	new Float:fCurTime = GetGameTime();
	
	g_fConnectTime[iClient] = fCurTime;
	g_fLastValidAction[iClient] = fCurTime;
	
	g_fNextActionMinuteUpdate[iClient] = 0.0;
	g_iNumActionsPerMinCount[iClient] = 0;
	
	g_fClanTagStartTime[iClient] = fCurTime;
	g_hClanTagTimes[iClient] = CreateTrie();
	
	g_fNextAwayCheck[iClient] = 0.0;
	
	ResetClientsAwayData(iClient, fCurTime);
}

public OnClientDisconnect_Post(iClient)
{
	g_iOldButtons[iClient] = 0;
	
	if(g_hClanTagTimes[iClient] != INVALID_HANDLE)
	{
		CloseHandle(g_hClanTagTimes[iClient]);
		g_hClanTagTimes[iClient] = INVALID_HANDLE;
	}
	
	strcopy(g_szCurrentClanTag[iClient], sizeof(g_szCurrentClanTag[]), "");
}

public Action:ClientSettings_OnRealClanTagChange(iClient, const String:szOldTag[], const String:szNewTag[], bool:bHasFakeTag)
{
	if(!bHasFakeTag)
		ClanTagChanged(iClient, szOldTag, szNewTag);
}

public ClientSettings_OnFakeClanTagChange(iClient, const String:szOldTag[], const String:szNewTag[])
{
	ClanTagChanged(iClient, szOldTag, szNewTag);
}

ClanTagChanged(iClient, const String:szOldTag[], const String:szNewTag[])
{
	UpdateLastUsedClanTagTime(iClient, szOldTag);
	strcopy(g_szCurrentClanTag[iClient], sizeof(g_szCurrentClanTag[]), szNewTag);
}

GetClanTagTime(iClient, const String:szClanTag[])
{
	if(g_hClanTagTimes[iClient] == INVALID_HANDLE)
		return 0;
	
	if(StrEqual(szClanTag, g_szCurrentClanTag[iClient]))
		UpdateLastUsedClanTagTime(iClient, szClanTag);
	
	decl Float:fTimeTagUsed;
	if(!GetTrieValue(g_hClanTagTimes[iClient], szClanTag, fTimeTagUsed))
		return 0;
	
	return RoundFloat(fTimeTagUsed);
}

UpdateLastUsedClanTagTime(iClient, const String:szClanTag[])
{
	if(g_hClanTagTimes[iClient] == INVALID_HANDLE)
		return;
	
	decl Float:fTimeTagUsed;
	if(!GetTrieValue(g_hClanTagTimes[iClient], szClanTag, fTimeTagUsed))
		fTimeTagUsed = 0.0;
	
	fTimeTagUsed += (GetGameTime() - g_fClanTagStartTime[iClient]);
	SetTrieValue(g_hClanTagTimes[iClient], szClanTag, fTimeTagUsed);
	
	g_fClanTagStartTime[iClient] = GetGameTime();
	
	// OnClanTagTimeUpdated forward.
	Call_StartForward(g_hFwd_OnClanTagTimeUpdated);
	Call_PushCell(iClient);
	Call_PushString(szClanTag);
	Call_PushFloat(fTimeTagUsed);
	Call_Finish();
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!iClient)
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	if(GetClientTeam(iClient) <= CS_TEAM_SPECTATOR)
		return;
	
	CheckValidAction(iClient);
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(g_iOldButtons[iClient] == iButtons || GetClientTeam(iClient) <= CS_TEAM_SPECTATOR)
	{
		UpdateClientAsAwayIfNeeded(iClient);
		return;
	}
	
	g_iOldButtons[iClient] = iButtons;
	CheckValidAction(iClient);
}

UpdateClientAsAwayIfNeeded(iClient)
{
	static Float:fCurTime;
	fCurTime = GetGameTime();
	if(fCurTime < g_fNextAwayCheck[iClient])
		return;
	
	g_fNextAwayCheck[iClient] = fCurTime + 1.0;
	
	decl eHookedPlugin[HookedPlugins];
	for(new i=0; i<GetArraySize(g_aHookedPlugins); i++)
	{
		GetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		
		if(eHookedPlugin[HookedPluginIsClientAway][iClient])
			continue;
		
		if((g_fLastValidAction[iClient] + eHookedPlugin[HookedPluginSeconds]) > fCurTime)
			continue;
		
		eHookedPlugin[HookedPluginAwayTotalTime][iClient] += (fCurTime - g_fLastValidAction[iClient]);
		eHookedPlugin[HookedPluginAwayStartTime][iClient] = fCurTime;
		eHookedPlugin[HookedPluginIsClientAway][iClient] = true;
		SetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		
		if(eHookedPlugin[HookedPluginForwardAway] != INVALID_HANDLE)
		{
			Call_StartForward(eHookedPlugin[HookedPluginForwardAway]);
			Call_PushCell(iClient);
			Call_Finish();
		}
	}
}

CheckValidAction(iClient, bool:bForceValid=false)
{
	static Float:fCurTime;
	fCurTime = GetGameTime();
	
	if(fCurTime > g_fNextActionMinuteUpdate[iClient])
	{
		g_fNextActionMinuteUpdate[iClient] = fCurTime + 60;
		g_iNumActionsPerMinCount[iClient] = 0;
	}
	
	g_iNumActionsPerMinCount[iClient]++;
	if(!bForceValid && g_iNumActionsPerMinCount[iClient] < NUM_ACTIONS_REQ_PER_MIN)
		return;
	
	UpdateClientAsBackIfNeeded(iClient, fCurTime);
	g_fLastValidAction[iClient] = fCurTime;
}

UpdateClientAsBackIfNeeded(iClient, const Float:fCurTime)
{
	decl eHookedPlugin[HookedPlugins];
	for(new i=0; i<GetArraySize(g_aHookedPlugins); i++)
	{
		GetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		if(!eHookedPlugin[HookedPluginIsClientAway][iClient])
			continue;
		
		eHookedPlugin[HookedPluginIsClientAway][iClient] = false;
		eHookedPlugin[HookedPluginAwayTotalTime][iClient] += (fCurTime - eHookedPlugin[HookedPluginAwayStartTime][iClient]);
		SetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		
		if(eHookedPlugin[HookedPluginForwardBack] != INVALID_HANDLE)
		{
			Call_StartForward(eHookedPlugin[HookedPluginForwardBack]);
			Call_PushCell(iClient);
			Call_Finish();
		}
	}
}

ResetClientsAwayData(iClient, Float:fCurTime)
{
	decl eHookedPlugin[HookedPlugins];
	for(new i=0; i<GetArraySize(g_aHookedPlugins); i++)
	{
		GetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		eHookedPlugin[HookedPluginIsClientAway][iClient] = true;
		eHookedPlugin[HookedPluginAwayTotalTime][iClient] = 0.0;
		eHookedPlugin[HookedPluginAwayStartTime][iClient] = fCurTime;
		SetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
	}
}

ForceUpdateClientsAwayTime(iClient, Handle:hPlugin)
{
	new Float:fCurTime = GetGameTime();
	
	decl eHookedPlugin[HookedPlugins];
	for(new i=0; i<GetArraySize(g_aHookedPlugins); i++)
	{
		GetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		
		if(!eHookedPlugin[HookedPluginIsClientAway][iClient])
			continue;
		
		if(eHookedPlugin[HookedPluginHandle] != hPlugin)
			continue;
		
		eHookedPlugin[HookedPluginAwayTotalTime][iClient] += (fCurTime - eHookedPlugin[HookedPluginAwayStartTime][iClient]);
		eHookedPlugin[HookedPluginAwayStartTime][iClient] = fCurTime;
		SetArrayArray(g_aHookedPlugins, i, eHookedPlugin);
		
		return;
	}
}