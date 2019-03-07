#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <regex>
#include <sdktools_voice>
#include "../DatabaseCore/database_core"
#include "../DatabaseServers/database_servers"
#include "../DatabaseUsers/database_users"
#include "../WebPageViewer/web_page_viewer"
#include "../Admins/admins"
#include "squelch_manager"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Squelch Manager";
new const String:PLUGIN_VERSION[] = "1.12";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage users squelches.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define SQUELCH_FLAG_MUTE	(1<<0)
#define SQUELCH_FLAG_GAG	(1<<1)

enum SquelchType
{
	SQUELCH_TYPE_MUTE = 0,
	SQUELCH_TYPE_GAG
};

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:g_hOnVoiceTransmit;
new g_iHookedVoiceTransmit[MAXPLAYERS+1];

new bool:g_bHasWhoSquelchedThisUser[MAXPLAYERS+1];
new bool:g_bHasWhoThisUserSquelched[MAXPLAYERS+1];
new Handle:g_hTrie_UserIDToClientSerial[MAXPLAYERS+1];

new g_iSquelchFlags[MAXPLAYERS+1][MAXPLAYERS+1]; // [Client][Target]

new Handle:g_hTextArray;
new Handle:g_hVoiceArray;

#define SQUELCH_SET_DELAY	0.7
new Float:g_fLastSquelchSet[MAXPLAYERS+1];

#define VOICE_END_DELAY		0.3
new bool:g_bIsUsingVoice[MAXPLAYERS+1];
new Float:g_fVoiceEndTime[MAXPLAYERS+1];

new Handle:g_hFwd_OnClientStartSpeaking;
new Handle:g_hFwd_OnClientStopSpeaking;
new Handle:g_hFwd_OnClientSpeaking;

#define VOICE_SPAM_DELAY				10.0
#define VOICE_SPAM_HINT_DELAY_CLIENT	30.0
#define VOICE_SPAM_HINT_DELAY_TARGET	60.0
new Float:g_fVoiceStartTime[MAXPLAYERS+1];
new Float:g_fNextSpamHintTimeClient[MAXPLAYERS+1];
new Float:g_fNextSpamHintTimeTarget[MAXPLAYERS+1];

new bool:g_bIsInMenu[MAXPLAYERS+1];
new Handle:g_aMenuQueue[MAXPLAYERS+1];
enum _:MenuQueue
{
	SquelchType:MenuQueue_SquelchType,
	MenuQueue_TargetSerial,
	bool:MenuQueue_WasPreSquelched,	// Used to mute a player before the menu appears.
	MenuQueue_AdminSerial,			// Set if this was from an admin vote.
	String:MenuQueue_AdminName[MAX_NAME_LENGTH]
};

#define MENU_QUEUE_DISPLAY_DELAY	0.5
new Float:g_fNextMenuDisplayTime[MAXPLAYERS+1];

new Handle:g_aRoundEndSquelches;
enum _:RoundEndSquelch
{
	RoundEndSquelch_ClientSerial,
	RoundEndSquelch_TargetSerial,
	SquelchType:RoundEndSquelch_SquelchType
};

new g_bTimeMenu_TargetSerial[MAXPLAYERS+1];
new bool:g_bTimeMenu_WasPreSquelched[MAXPLAYERS+1];

new Handle:g_hVoteMutedSteamIDs;

#define FFADE_IN	0x0001
#define FFADE_OUT	0x0002
#define FFADE_PURGE	0x0010
#define SCREENFADE_FRACBITS		9
new UserMsg:g_msgFade;

#define VOTED_TIMEOUT_SECONDS	15
new g_iVotedTimeoutSeconds[MAXPLAYERS+1];
new Handle:g_hTimer_VotedTimeout[MAXPLAYERS+1];

new Handle:cvar_squelchmanager_show_vote_warning;
new Handle:cvar_squelchmanager_limit_duration_to_map;


public OnPluginStart()
{
	CreateConVar("api_squelch_manager_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	new Handle:hGameConf = LoadGameConfigFile("voicehook.csgo");
	if(hGameConf == INVALID_HANDLE)
		SetFailState("Could not load gamedata voicehook.csgo");
	
	new iOffset = GameConfGetOffset(hGameConf, "OnVoiceTransmit");
	CloseHandle(hGameConf);
	
	if(iOffset == -1)
		SetFailState("Could not get offset for OnVoiceTransmit");
	
	g_hOnVoiceTransmit = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, OnVoiceTransmit);
	
	for(new iClient=1; iClient<=MAXPLAYERS; iClient++)
	{
		g_hTrie_UserIDToClientSerial[iClient] = CreateTrie();
		g_aMenuQueue[iClient] = CreateArray(MenuQueue);
	}
	
	g_aRoundEndSquelches = CreateArray(RoundEndSquelch);
	
	g_hTextArray = CreateArray();
	g_hVoiceArray = CreateArray();
	
	g_hVoteMutedSteamIDs = CreateArray(48);
	
	cvar_squelchmanager_show_vote_warning = CreateConVar("squelchmanager_show_vote_warning", "1", "Whether or not to show the votesm warning to the target.", _, true, 0.0, true, 1.0);
	cvar_squelchmanager_limit_duration_to_map = CreateConVar("squelchmanager_limit_duration_to_map", "1", "Whether or not to limit the duration to a single map.", _, true, 0.0, true, 1.0);
	
	g_hFwd_OnClientStartSpeaking = CreateGlobalForward("SquelchManager_OnClientStartSpeaking", ET_Ignore, Param_Cell);
	g_hFwd_OnClientStopSpeaking = CreateGlobalForward("SquelchManager_OnClientStopSpeaking", ET_Ignore, Param_Cell);
	g_hFwd_OnClientSpeaking = CreateGlobalForward("SquelchManager_OnClientSpeaking", ET_Ignore, Param_Cell);
	
	g_msgFade = GetUserMessageId("Fade");
	
	RegConsoleCmd("sm_sg", OnGag, "Allows you to gag specific players.");
	RegConsoleCmd("sm_sm", OnMute, "Allows you to mute specific players.");
	RegConsoleCmd("sm_ms", OnMuteSpeaking, "Mutes all current speaking players that have been speaking for at least X seconds.");
	
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_votesm", Command_VoteSetMute, ADMFLAG_BAN, "sm_votesm <#steamid|#userid|name> - Opens a vote menu for all players to mute said target.");
	//RegAdminCmd("sm_votesg", Command_VoteSetGag, ADMFLAG_BAN, "sm_votesg <#steamid|#userid|name> - Opens a vote menu for all players to gag said target.");
	
	HookEvent("round_end", Event_RoundEnd_Post, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	ClearArray(g_hVoteMutedSteamIDs);
}

AddToVoteMutedArray(iClient)
{
	decl String:szAuthID[48];
	if(!GetClientAuthId(iClient, AuthId_Steam2, szAuthID, sizeof(szAuthID), false))
		return;
	
	if(FindStringInArray(g_hVoteMutedSteamIDs, szAuthID) != -1)
		return;
	
	PushArrayString(g_hVoteMutedSteamIDs, szAuthID);
}

MuteAllInVotedArray(iClient)
{
	decl String:szAuthID[48], iTarget, j;
	for(new i=0; i<GetArraySize(g_hVoteMutedSteamIDs); i++)
	{
		GetArrayString(g_hVoteMutedSteamIDs, i, szAuthID, sizeof(szAuthID));
		
		iTarget = FindClientByAuthID(szAuthID);
		if(!iTarget)
			continue;
		
		if(iClient == iTarget)
		{
			// This client is in the array so we need mute them for everyone else on the server.
			for(j=1; j<=MaxClients; j++)
			{
				if(!IsClientInGame(j) && !IsFakeClient(j))
					SetClientSquelchingTarget(j, iClient, SQUELCH_TYPE_MUTE, TIME_TO_SQUELCH_MAP_END, false);
			}
			
			continue;
		}
		
		SetClientSquelchingTarget(iClient, iTarget, SQUELCH_TYPE_MUTE, TIME_TO_SQUELCH_MAP_END, false);
	}
}

FindClientByAuthID(const String:szAuthID[])
{
	decl String:szClientsAuthID[48];
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!GetClientAuthId(iClient, AuthId_Steam2, szClientsAuthID, sizeof(szClientsAuthID), false))
			continue;
		
		if(StrEqual(szAuthID, szClientsAuthID))
			return iClient;
	}
	
	return 0;
}

public Action:Command_VoteSetMute(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_votesm <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, true);
	if(iTarget == -1)
		return Plugin_Handled;
	
	AddToVoteMutedArray(iTarget);
	OpenSquelchedWebPage(iTarget);
	
	LogAction(iClient, iTarget, "\"%L\" vote sm \"%L\"", iClient, iTarget);
	PrintToChatAll("[SM] %N issued a vote mute against %N.", iClient, iTarget);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(iPlayer == iTarget)
			continue;
		
		if(!IsClientInGame(iPlayer) || IsFakeClient(iPlayer))
			continue;
		
		if(iPlayer == iClient)
		{
			// Automatically squelch the target for this admin for the remainder of the map.
			SetClientMutingTarget(iClient, iTarget, TIME_TO_SQUELCH_MAP_END);
			PrintToChat(iClient, "[SM] %N was automatically muted for you.", iTarget);
			continue;
		}
		if(IsClientMutingTarget(iPlayer, iTarget))
		{
			PrintToChat(iPlayer, "[SM] You already have %N muted.", iTarget);
			continue;
		}
		
		if(SetListeningStateFromSquelchFlags(iPlayer, iTarget, SQUELCH_FLAG_MUTE, true))
			AddToMenuQueue(iPlayer, iTarget, SQUELCH_TYPE_MUTE, true, iClient);
		else
			AddToMenuQueue(iPlayer, iTarget, SQUELCH_TYPE_MUTE, false, iClient);
	}
	
	return Plugin_Handled;
}

public Event_RoundEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	decl eRoundEndSquelch[RoundEndSquelch], iClient, iTarget;
	
	for(new i=0; i<GetArraySize(g_aRoundEndSquelches); i++)
	{
		GetArrayArray(g_aRoundEndSquelches, i, eRoundEndSquelch);
		RemoveFromArray(g_aRoundEndSquelches, i);
		i--;
		
		iClient = GetClientFromSerial(eRoundEndSquelch[RoundEndSquelch_ClientSerial]);
		if(!iClient)
			continue;
		
		iTarget = GetClientFromSerial(eRoundEndSquelch[RoundEndSquelch_TargetSerial]);
		if(!iTarget)
			continue;
		
		switch(eRoundEndSquelch[RoundEndSquelch_SquelchType])
		{
			case SQUELCH_TYPE_GAG: SetClientGaggingTarget(iClient, iTarget, 0, false);
			case SQUELCH_TYPE_MUTE: SetClientMutingTarget(iClient, iTarget, 0, false);
		}
	}
}

RemoveClientSquelchTypeFromRoundEnd(iClient, SquelchType:iSquelchType)
{
	new iClientSerial = GetClientSerial(iClient);
	new iArraySize = GetArraySize(g_aRoundEndSquelches);
	
	decl eRoundEndSquelch[RoundEndSquelch];
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aRoundEndSquelches, i, eRoundEndSquelch);
		
		if(iClientSerial != eRoundEndSquelch[RoundEndSquelch_ClientSerial])
			continue;
		
		if(iSquelchType != eRoundEndSquelch[RoundEndSquelch_SquelchType])
			continue;
		
		RemoveFromArray(g_aRoundEndSquelches, i);
		break;
	}
}

public Action:OnMuteSpeaking(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgNum < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_ms <seconds (how many seconds someone has to stay speaking for this to work)>");
		return Plugin_Handled;
	}
	
	if(!AreFlagsLoaded(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Try soon, your squelch data is still loading.");
		return Plugin_Handled;
	}
	
	if(!CheckSpammingCommand(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Please do not spam this command.");
		return Plugin_Handled;
	}
	
	decl String:szSeconds[12];
	GetCmdArg(1, szSeconds, sizeof(szSeconds));
	new iSeconds = StringToInt(szSeconds);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Muting speaking players who have spoke for %i seconds.", iSeconds);
	
	MuteSpeaking(iClient, float(iSeconds));
	
	return Plugin_Handled;
}

MuteSpeaking(iClient, Float:fSeconds)
{
	new Float:fCurTime = GetEngineTime();
	
	if(fSeconds < 1.0)
		fSeconds = 0.5;
	
	for(new iTarget=1; iTarget<=MaxClients; iTarget++)
	{
		if(iClient == iTarget)
			continue;
		
		if(!IsClientInGame(iTarget) || IsFakeClient(iTarget))
			continue;
		
		if(!g_bIsUsingVoice[iTarget])
			continue;
		
		if((fCurTime - g_fVoiceStartTime[iTarget]) < fSeconds)
			continue;
		
		if(IsClientMutingTarget(iClient, iTarget))
			continue;
		
		if(SetListeningStateFromSquelchFlags(iClient, iTarget, SQUELCH_FLAG_MUTE, true))
			AddToMenuQueue(iClient, iTarget, SQUELCH_TYPE_MUTE, true);
		else
			AddToMenuQueue(iClient, iTarget, SQUELCH_TYPE_MUTE, false);
	}
}

AddToMenuQueue(iClient, iTarget, SquelchType:iSquelchType, bool:bWasPreSquelched=false, iAdminIndex=0)
{
	if(!AreFlagsLoaded(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Try soon, your squelch data is still loading.");
		return;
	}
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%N {olive}is now in the squelch queue.", iTarget);
	
	new iTargetSerial = GetClientSerial(iTarget);
	
	// Is this client already in the time menu for this target?
	if(g_bTimeMenu_TargetSerial[iClient] == iTargetSerial)
		return;
	
	new iArraySize = GetArraySize(g_aMenuQueue[iClient]);
	
	decl eMenuQueue[MenuQueue], i;
	for(i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aMenuQueue[iClient], i, eMenuQueue);
		
		if(eMenuQueue[MenuQueue_SquelchType] == iSquelchType && eMenuQueue[MenuQueue_TargetSerial] == iTargetSerial)
			break;
	}
	
	if(i >= iArraySize)
	{
		eMenuQueue[MenuQueue_SquelchType] = iSquelchType;
		eMenuQueue[MenuQueue_TargetSerial] = iTargetSerial;
		eMenuQueue[MenuQueue_WasPreSquelched] = bWasPreSquelched;
		
		if(iAdminIndex > 0)
		{
			eMenuQueue[MenuQueue_AdminSerial] = GetClientSerial(iAdminIndex);
			GetClientName(iAdminIndex, eMenuQueue[MenuQueue_AdminName], MAX_NAME_LENGTH);
		}
		else
		{
			eMenuQueue[MenuQueue_AdminSerial] = 0;
			strcopy(eMenuQueue[MenuQueue_AdminName], MAX_NAME_LENGTH, "");
		}
		
		PushArrayArray(g_aMenuQueue[iClient], eMenuQueue);
	}
	
	TryDisplayMenuFromQueue(iClient);
}

TryDisplayMenuFromQueue(iClient)
{
	static iArraySize;
	iArraySize = GetArraySize(g_aMenuQueue[iClient]);
	if(!iArraySize)
		return;
	
	if(g_bIsInMenu[iClient])
		return;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextMenuDisplayTime[iClient])
		return;
	
	g_fNextMenuDisplayTime[iClient] = fCurTime + MENU_QUEUE_DISPLAY_DELAY;
	
	decl eMenuQueue[MenuQueue], iTarget;
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aMenuQueue[iClient], i, eMenuQueue);
		RemoveFromArray(g_aMenuQueue[iClient], i);
		i--;
		
		iTarget = GetClientFromSerial(eMenuQueue[MenuQueue_TargetSerial]);
		if(!iTarget)
			continue;
		
		DisplayMenu_Time(iClient, iTarget, eMenuQueue[MenuQueue_SquelchType], eMenuQueue[MenuQueue_WasPreSquelched], eMenuQueue[MenuQueue_AdminSerial], eMenuQueue[MenuQueue_AdminName]);
		break;
	}
}

public Action:OnGag(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!AreFlagsLoaded(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Try soon, your squelch data is still loading.");
		return Plugin_Handled;
	}
	
	if(iArgNum != 1)
	{
		DisplayMenu_Gag(iClient);
		return Plugin_Handled;
	}
	
	if(!CheckSpammingCommand(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Please do not spam this command.");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(iClient == iTarget)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}You cannot use this command on yourself.");
		return Plugin_Handled;
	}
	
	if(IsClientGaggingTarget(iClient, iTarget))
	{
		SetClientGaggingTarget(iClient, iTarget, TIME_TO_SQUELCH_REMOVE);
	}
	else
	{
		DisplayMenu_Time(iClient, iTarget, SQUELCH_TYPE_GAG);
	}
	
	return Plugin_Handled;
}

public Action:OnMute(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(!AreFlagsLoaded(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Try soon, your squelch data is still loading.");
		return Plugin_Handled;
	}
	
	if(iArgNum != 1)
	{
		DisplayMenu_Mute(iClient);
		return Plugin_Handled;
	}
	
	if(!CheckSpammingCommand(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Please do not spam this command.");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(iClient == iTarget)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}You cannot use this command on yourself.");
		return Plugin_Handled;
	}
	
	if(IsClientMutingTarget(iClient, iTarget))
	{
		SetClientMutingTarget(iClient, iTarget, TIME_TO_SQUELCH_REMOVE);
	}
	else
	{
		DisplayMenu_Time(iClient, iTarget, SQUELCH_TYPE_MUTE);
	}
	
	return Plugin_Handled;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("squelch_manager");
	CreateNative("SquelchManager_IsClientSpeaking", _SquelchManager_IsClientSpeaking);
	CreateNative("SquelchManager_IsClientMutingTarget", _SquelchManager_IsClientMutingTarget);
	CreateNative("SquelchManager_IsClientGaggingTarget", _SquelchManager_IsClientGaggingTarget);
	
	CreateNative("SquelchManager_SetClientMutingTarget", _SquelchManager_SetClientMutingTarget);
	CreateNative("SquelchManager_SetClientGaggingTarget", _SquelchManager_SetClientGaggingTarget);
	CreateNative("SquelchManager_ReapplyListeningState", _SquelchManager_ReapplyListeningState);
	
	return APLRes_Success;
}

public _SquelchManager_IsClientSpeaking(Handle:hPlugin, iNumParams)
{
	return g_bIsUsingVoice[GetNativeCell(1)];
}

public _SquelchManager_SetClientMutingTarget(Handle:hPlugin, iNumParams)
{
	return SetClientMutingTarget(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public _SquelchManager_SetClientGaggingTarget(Handle:hPlugin, iNumParams)
{
	return SetClientGaggingTarget(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

public _SquelchManager_ReapplyListeningState(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new iTarget = GetNativeCell(2);
	SetListeningStateFromSquelchFlags(iClient, iTarget, g_iSquelchFlags[iClient][iTarget], GetNativeCell(3));
}

bool:SetClientMutingTarget(iClient, iTarget, iSeconds, bool:bUpdateInDatabase=true)
{
	new bool:bReturn = SetClientSquelchingTarget(iClient, iTarget, SQUELCH_TYPE_MUTE, iSeconds, bUpdateInDatabase);
	
	if(bReturn)
	{
		if(iSeconds != 0)
		{
			decl String:szTime[72];
			GetTimeStringFromSeconds(iSeconds, szTime, sizeof(szTime));
			
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%N {olive}is now muted for {lightred}%s{olive}.", iTarget, szTime);
		}
		else
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%N {olive}is now unmuted.", iTarget);
	}
	else
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Error muting/unmuting %N", iTarget);
	}
	
	return bReturn;
}

bool:SetClientGaggingTarget(iClient, iTarget, iSeconds, bool:bUpdateInDatabase=true)
{
	new bool:bReturn = SetClientSquelchingTarget(iClient, iTarget, SQUELCH_TYPE_GAG, iSeconds, bUpdateInDatabase);
	
	if(bReturn)
	{
		if(iSeconds != 0)
		{
			decl String:szTime[72];
			GetTimeStringFromSeconds(iSeconds, szTime, sizeof(szTime));
			
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%N {olive}is now gagged for {lightred}%s{olive}.", iTarget, szTime);
		}
		else
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%N {olive}is now ungagged.", iTarget);
	}
	else
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}%N's squelch data is still loading", iTarget);
	}
	
	return bReturn;
}

GetTimeStringFromSeconds(iSeconds, String:szTime[], iMaxLength)
{
	if(iSeconds == TIME_TO_SQUELCH_ROUND_END)
		strcopy(szTime, iMaxLength, "the round");
	else if(iSeconds == TIME_TO_SQUELCH_MAP_END)
		strcopy(szTime, iMaxLength, "the map");
	else
	{
		new iMonth = (iSeconds / 2592000) % 12;
		iSeconds -= (iMonth * 2592000);
		
		new iWeek = (iSeconds / 604800) % 30;
		iSeconds -= (iWeek * 604800);
		
		new iDay = (iSeconds / 86400) % 7;
		iSeconds -= (iDay * 86400);
		
		new iHour = (iSeconds / 3600) % 24;
		iSeconds -= (iHour * 3600);
		
		new iMinute = (iSeconds / 60) % 60;
		iSeconds -= (iMinute * 60);
		
		new iSecondCount = iSeconds % 60;
		
		new iLen;
		
		if(iMonth)
		{
			if(iLen)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, ", ");
			
			iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "%i month", iMonth);
			
			if(iMonth > 1)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "s");
		}
		
		if(iWeek)
		{
			if(iLen)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, ", ");
			
			iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "%i week", iWeek);
			
			if(iWeek > 1)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "s");
		}
		
		if(iDay)
		{
			if(iLen)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, ", ");
			
			iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "%i day", iDay);
			
			if(iDay > 1)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "s");
		}
		
		if(iHour)
		{
			if(iLen)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, ", ");
			
			iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "%i hour", iHour);
			
			if(iHour > 1)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "s");
		}
		
		if(iMinute)
		{
			if(iLen)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, ", ");
			
			iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "%i minute", iMinute);
			
			if(iMinute > 1)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "s");
		}
		
		if(iSecondCount)
		{
			if(iLen)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, ", ");
			
			iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "%i second", iSecondCount);
			
			if(iSecondCount > 1)
				iLen += FormatEx(szTime[iLen], iMaxLength-iLen, "s");
		}
	}
}

public _SquelchManager_IsClientMutingTarget(Handle:hPlugin, iNumParams)
{
	return IsClientMutingTarget(GetNativeCell(1), GetNativeCell(2));
}

public _SquelchManager_IsClientGaggingTarget(Handle:hPlugin, iNumParams)
{
	return IsClientGaggingTarget(GetNativeCell(1), GetNativeCell(2));
}

bool:IsClientMutingTarget(iClient, iTarget)
{
	return IsClientSquelchingTarget(iClient, iTarget, SQUELCH_FLAG_MUTE);
}

bool:IsClientGaggingTarget(iClient, iTarget)
{
	return IsClientSquelchingTarget(iClient, iTarget, SQUELCH_FLAG_GAG);
}

bool:IsClientSquelchingTarget(iClient, iTarget, iBitFlagsToCheck)
{
	if(!AreFlagsLoaded(iClient))
		return false;
	
	if(iBitFlagsToCheck & g_iSquelchFlags[iClient][iTarget])
		return true;
	
	return false;
}

bool:SetClientSquelchingTarget(iClient, iTarget, SquelchType:iSquelchType, iSeconds, bool:bUpdateInDatabase)
{
	if(!AreFlagsLoaded(iClient))
		return false;
	
	if(iSeconds != 0)
	{
		switch(iSquelchType)
		{
			case SQUELCH_TYPE_GAG: g_iSquelchFlags[iClient][iTarget] |= SQUELCH_FLAG_GAG;
			case SQUELCH_TYPE_MUTE: g_iSquelchFlags[iClient][iTarget] |= SQUELCH_FLAG_MUTE;
		}
	}
	else
	{
		switch(iSquelchType)
		{
			case SQUELCH_TYPE_GAG: g_iSquelchFlags[iClient][iTarget] &= ~SQUELCH_FLAG_GAG;
			case SQUELCH_TYPE_MUTE: g_iSquelchFlags[iClient][iTarget] &= ~SQUELCH_FLAG_MUTE;
		}
	}
	
	SetListeningStateFromSquelchFlags(iClient, iTarget, g_iSquelchFlags[iClient][iTarget]);
	
	// If iSeconds is less than 0 that means the squelch should be removed on round or map end.
	if(!GetConVarBool(cvar_squelchmanager_limit_duration_to_map) && iSeconds >= 0 && bUpdateInDatabase)
		InsertSquelchType(iClient, iTarget, iSquelchType, iSeconds);
	
	return true;
}

bool:InsertSquelchType(iClient, iTarget, SquelchType:iSquelchType, iSeconds)
{
	new iClientUserID = DBUsers_GetUserID(iClient);
	if(iClientUserID < 1)
		return false;
	
	new iTargetUserID = DBUsers_GetUserID(iTarget);
	if(iTargetUserID < 1)
		return false;
	
	if(iSeconds)
	{
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Normal, _, "\
			INSERT INTO gs_user_squelches (user_id, target_user_id, squelch_type, expires) VALUES (%i, %i, %i, UNIX_TIMESTAMP() + %i) ON DUPLICATE KEY UPDATE expires=UNIX_TIMESTAMP() + %i",
			iClientUserID, iTargetUserID, iSquelchType, iSeconds, iSeconds);
	}
	else
	{
		// We need to clear this type. Set expired to 0.
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Normal, _, "\
			INSERT INTO gs_user_squelches (user_id, target_user_id, squelch_type, expires) VALUES (%i, %i, %i, 0) ON DUPLICATE KEY UPDATE expires=0",
			iClientUserID, iTargetUserID, iSquelchType);
	}
	
	return true;
}

bool:AreFlagsLoaded(iClient)
{
	if(g_bHasWhoSquelchedThisUser[iClient] && g_bHasWhoThisUserSquelched[iClient])
		return true;
	
	return false;
}

public OnClientConnected(iClient)
{
	g_iHookedVoiceTransmit[iClient] = -1;
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	g_iHookedVoiceTransmit[iClient] = DHookEntity(g_hOnVoiceTransmit, true, iClient);
	
	SDKHook(iClient, SDKHook_PreThink, OnPreThink);
}

public MRESReturn:OnVoiceTransmit(iClient, Handle:hReturn)
{
	if(!g_bIsUsingVoice[iClient])
		Forward_OnClientStartSpeaking(iClient);
	
	Forward_OnClientSpeaking(iClient);
}

public OnPreThink(iClient)
{
	TryDisplayMenuFromQueue(iClient);
	
	if(!g_bIsUsingVoice[iClient])
		return;
	
	if(g_fVoiceEndTime[iClient] > GetEngineTime())
		return;
	
	Forward_OnClientStopSpeaking(iClient);
}

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_UserSquelches())
		SetFailState("There was an error creating the gs_user_squelches sql table.");
}

bool:Query_CreateTable_UserSquelches()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_user_squelches\
	(\
		user_id			INT UNSIGNED		NOT NULL,\
		target_user_id	INT UNSIGNED		NOT NULL,\
		squelch_type	TINYINT UNSIGNED	NOT NULL,\
		expires			INT UNSIGNED		NOT NULL,\
		PRIMARY KEY ( user_id, target_user_id, squelch_type ),\
		INDEX ( target_user_id, user_id, expires ),\
		INDEX ( user_id, target_user_id, expires )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
		return false;
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnClientDisconnect(iClient)
{
	Forward_OnClientStopSpeaking(iClient);
	ClearArray(g_aMenuQueue[iClient]);
	
	if(g_iHookedVoiceTransmit[iClient] != -1)
	{
		DHookRemoveHookID(g_iHookedVoiceTransmit[iClient]);
		g_iHookedVoiceTransmit[iClient] = -1;
	}
	
	for(new i=1; i<=MaxClients; i++)
	{
		g_iSquelchFlags[iClient][i] = 0;
		
		if(!IsClientInGame(i))
			continue;
		
		SetListenOverride(iClient, i, Listen_Default);
		SetListenOverride(i, iClient, Listen_Default);
	}
}

public OnClientDisconnect_Post(iClient)
{
	g_bHasWhoSquelchedThisUser[iClient] = false;
	g_bHasWhoThisUserSquelched[iClient] = false;
	
	RemoveClientFromArray(iClient, g_hTextArray);
	RemoveClientFromArray(iClient, g_hVoiceArray);
	
	g_fNextSpamHintTimeTarget[iClient] = 0.0;
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	ClearTrie(g_hTrie_UserIDToClientSerial[iClient]);
	
	static String:szInQuery[1024], iLen, iPlayerUserID, String:szUserID[16];
	iLen = 0;
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		iPlayerUserID = DBUsers_GetUserID(iPlayer);
		if(iPlayerUserID < 1 || iPlayerUserID == iUserID)
			continue;
		
		if(iLen)
			iLen += FormatEx(szInQuery[iLen], sizeof(szInQuery)-iLen, ",%i", iPlayerUserID);
		else
			iLen += FormatEx(szInQuery[iLen], sizeof(szInQuery)-iLen, "%i", iPlayerUserID);
		
		IntToString(iPlayerUserID, szUserID, sizeof(szUserID));
		SetTrieValue(g_hTrie_UserIDToClientSerial[iClient], szUserID, GetClientSerial(iPlayer));
	}
	
	if(!iLen || GetConVarBool(cvar_squelchmanager_limit_duration_to_map))
	{
		g_bHasWhoSquelchedThisUser[iClient] = true;
		g_bHasWhoThisUserSquelched[iClient] = true;
		CheckOnFlagsLoaded(iClient);
		
		return;
	}
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetWhoSquelchedThisUser, DBPrio_Normal, GetClientSerial(iClient), "\
		SELECT user_id, squelch_type FROM gs_user_squelches WHERE target_user_id = %i AND user_id IN (%s) AND expires > UNIX_TIMESTAMP()", iUserID, szInQuery);
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetWhoThisUserSquelched, DBPrio_Normal, GetClientSerial(iClient), "\
		SELECT target_user_id, squelch_type FROM gs_user_squelches WHERE user_id = %i AND target_user_id IN (%s) AND expires > UNIX_TIMESTAMP()", iUserID, szInQuery);
}

public Query_GetWhoSquelchedThisUser(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_bHasWhoSquelchedThisUser[iClient] = true;
	CheckOnFlagsLoaded(iClient);
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	decl iUserID, iSquelchType, iPlayer, String:szUserID[16], i;
	while(SQL_FetchRow(hQuery))
	{
		iUserID = SQL_FetchInt(hQuery, 0);
		IntToString(iUserID, szUserID, sizeof(szUserID));
		
		if(!GetTrieValue(g_hTrie_UserIDToClientSerial[iClient], szUserID, iPlayer))
			continue;
		
		iPlayer = GetClientFromSerial(iPlayer);
		if(!iPlayer)
		{
			// This clients serial is no longer valid. We still need to check to see if they are still in the game from a reconnect.
			for(i=1; i<=MaxClients; i++)
			{
				if(i == iClient)
					continue;
				
				if(!IsClientInGame(i))
					continue;
				
				if(iUserID != DBUsers_GetUserID(i))
					continue;
				
				iPlayer = i;
				break;
			}
		}
		
		if(!iPlayer)
			continue;
		
		iSquelchType = SQL_FetchInt(hQuery, 1);
		
		switch(iSquelchType)
		{
			case SQUELCH_TYPE_MUTE: g_iSquelchFlags[iPlayer][iClient] |= SQUELCH_FLAG_MUTE;
			case SQUELCH_TYPE_GAG: g_iSquelchFlags[iPlayer][iClient] |= SQUELCH_FLAG_GAG;
		}
		
		SetListeningStateFromSquelchFlags(iPlayer, iClient, g_iSquelchFlags[iPlayer][iClient]);
	}
}

public Query_GetWhoThisUserSquelched(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	g_bHasWhoThisUserSquelched[iClient] = true;
	CheckOnFlagsLoaded(iClient);
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	decl iUserID, iSquelchType, iPlayer, String:szUserID[16], i;
	while(SQL_FetchRow(hQuery))
	{
		iUserID = SQL_FetchInt(hQuery, 0);
		IntToString(iUserID, szUserID, sizeof(szUserID));
		
		if(!GetTrieValue(g_hTrie_UserIDToClientSerial[iClient], szUserID, iPlayer))
			continue;
		
		iPlayer = GetClientFromSerial(iPlayer);
		if(!iPlayer)
		{
			// This clients serial is no longer valid. We still need to check to see if they are still in the game from a reconnect.
			for(i=1; i<=MaxClients; i++)
			{
				if(i == iClient)
					continue;
				
				if(!IsClientInGame(i))
					continue;
				
				if(iUserID != DBUsers_GetUserID(i))
					continue;
				
				iPlayer = i;
				break;
			}
		}
		
		if(!iPlayer)
			continue;
		
		iSquelchType = SQL_FetchInt(hQuery, 1);
		
		switch(iSquelchType)
		{
			case SQUELCH_TYPE_MUTE: g_iSquelchFlags[iClient][iPlayer] |= SQUELCH_FLAG_MUTE;
			case SQUELCH_TYPE_GAG: g_iSquelchFlags[iClient][iPlayer] |= SQUELCH_FLAG_GAG;
		}
		
		SetListeningStateFromSquelchFlags(iClient, iPlayer, g_iSquelchFlags[iClient][iPlayer]);
	}
}

CheckOnFlagsLoaded(iClient)
{
	if(g_bHasWhoSquelchedThisUser[iClient] && g_bHasWhoThisUserSquelched[iClient])
		OnFlagsLoaded(iClient);
}

OnFlagsLoaded(iClient)
{
	MuteAllInVotedArray(iClient);
}

bool:SetListeningStateFromSquelchFlags(iClient, iTarget, iClientSquelchFlags, bool:bShouldReturnIfListenYes=true)
{
	if(bShouldReturnIfListenYes && GetListenOverride(iClient, iTarget) == Listen_Yes)
		return false;
	
	if(iClientSquelchFlags & SQUELCH_FLAG_MUTE)
		SetListenOverride(iClient, iTarget, Listen_No);
	else
		SetListenOverride(iClient, iTarget, Listen_Default);
	
	return true;
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!iClient)
		return;
	
	UpdateClientInArray(iClient, g_hTextArray);
}

UpdateClientInArray(iClient, Handle:hArray)
{
	RemoveClientFromArray(iClient, hArray);
	PushArrayCell(hArray, iClient);
}

RemoveClientFromArray(iClient, Handle:hArray)
{
	new iIndex = FindValueInArray(hArray, iClient);
	if(iIndex != -1)
		RemoveFromArray(hArray, iIndex);
}

DisplayMenu_Gag(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Gag);
	SetMenuTitle(hMenu, "Set Gag - Gag Specific Players\nThis menu is ordered by who typed most recently.");
	
	decl String:szName[MAX_NAME_LENGTH], String:szInfo[16], iTarget;
	for(new i=GetArraySize(g_hTextArray)-1; i>=0; i--)
	{
		iTarget = GetArrayCell(g_hTextArray, i);
		
		if(iTarget == iClient)
		{
			FormatEx(szName, sizeof(szName), "[YOU] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
		else if(AreFlagsLoaded(iTarget))
		{
			FormatEx(szName, sizeof(szName), "%s %N", IsClientGaggingTarget(iClient, iTarget) ? "[GAGGED]" : "", iTarget);
			FormatEx(szInfo, sizeof(szInfo), "%i", GetClientSerial(iTarget));
			AddMenuItem(hMenu, szInfo, szName);
		}
		else
		{
			FormatEx(szName, sizeof(szName), "[PENDING] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
	}
	
	for(iTarget=1; iTarget<=MaxClients; iTarget++)
	{
		if(!IsClientInGame(iTarget) || IsFakeClient(iTarget))
			continue;
		
		if(FindValueInArray(g_hTextArray, iTarget) != -1)
			continue;
		
		if(iTarget == iClient)
		{
			FormatEx(szName, sizeof(szName), "[YOU] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
		else if(AreFlagsLoaded(iTarget))
		{
			FormatEx(szName, sizeof(szName), "%s %N", IsClientGaggingTarget(iClient, iTarget) ? "[GAGGED]" : "", iTarget);
			FormatEx(szInfo, sizeof(szInfo), "%i", GetClientSerial(iTarget));
			AddMenuItem(hMenu, szInfo, szName);
		}
		else
		{
			FormatEx(szName, sizeof(szName), "[PENDING] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
	}
	
	g_bIsInMenu[iClient] = true;
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
}

public MenuHandle_Gag(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_fNextMenuDisplayTime[iParam1] = GetEngineTime() + MENU_QUEUE_DISPLAY_DELAY;
		g_bIsInMenu[iParam1] = false;
		
		if(IsClientInGame(iParam1))
			DisplaySpamHintMessage(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[16];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iTarget = GetClientFromSerial(StringToInt(szInfo));
	
	if(!iTarget)
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {red}Selected player is no longer in server.");
		DisplayMenu_Gag(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	if(!CheckSpammingCommand(iParam1))
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {red}Please do not spam this menu.");
		DisplayMenu_Gag(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	if(IsClientGaggingTarget(iParam1, iTarget))
	{
		SetClientGaggingTarget(iParam1, iTarget, TIME_TO_SQUELCH_REMOVE);
		DisplayMenu_Gag(iParam1, GetMenuSelectionPosition());
	}
	else
	{
		DisplayMenu_Time(iParam1, iTarget, SQUELCH_TYPE_GAG);
	}
}

DisplayMenu_Mute(iClient, iStartItem=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Mute);
	SetMenuTitle(hMenu, "Set Mute - Mute Specific Players\nThis menu is ordered by who started speaking most recently.");
	
	decl String:szName[MAX_NAME_LENGTH], String:szInfo[16], iTarget;
	for(new i=GetArraySize(g_hVoiceArray)-1; i>=0; i--)
	{
		iTarget = GetArrayCell(g_hVoiceArray, i);
		
		if(iTarget == iClient)
		{
			FormatEx(szName, sizeof(szName), "[YOU] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
		else if(AreFlagsLoaded(iTarget))
		{
			FormatEx(szName, sizeof(szName), "%s %N", IsClientMutingTarget(iClient, iTarget) ? "[MUTED]" : "", iTarget);
			FormatEx(szInfo, sizeof(szInfo), "%i", GetClientSerial(iTarget));
			AddMenuItem(hMenu, szInfo, szName);
		}
		else
		{
			FormatEx(szName, sizeof(szName), "[PENDING] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
	}
	
	for(iTarget=1; iTarget<=MaxClients; iTarget++)
	{
		if(!IsClientInGame(iTarget) || IsFakeClient(iTarget))
			continue;
		
		if(FindValueInArray(g_hVoiceArray, iTarget) != -1)
			continue;
		
		if(iTarget == iClient)
		{
			FormatEx(szName, sizeof(szName), "[YOU] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
		else if(AreFlagsLoaded(iTarget))
		{
			FormatEx(szName, sizeof(szName), "%s %N", IsClientMutingTarget(iClient, iTarget) ? "[MUTED]" : "", iTarget);
			FormatEx(szInfo, sizeof(szInfo), "%i", GetClientSerial(iTarget));
			AddMenuItem(hMenu, szInfo, szName);
		}
		else
		{
			FormatEx(szName, sizeof(szName), "[PENDING] %N", iTarget);
			AddMenuItem(hMenu, "0", szName, ITEMDRAW_DISABLED);
		}
	}
	
	g_bIsInMenu[iClient] = true;
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		return;
	}
}

public MenuHandle_Mute(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_fNextMenuDisplayTime[iParam1] = GetEngineTime() + MENU_QUEUE_DISPLAY_DELAY;
		g_bIsInMenu[iParam1] = false;
		
		if(IsClientInGame(iParam1))
			DisplaySpamHintMessage(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[16];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iTarget = GetClientFromSerial(StringToInt(szInfo));
	
	if(!iTarget)
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {red}Selected player is no longer in server.");
		DisplayMenu_Mute(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	if(!CheckSpammingCommand(iParam1))
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {red}Please do not spam this menu.");
		DisplayMenu_Mute(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	if(IsClientMutingTarget(iParam1, iTarget))
	{
		SetClientMutingTarget(iParam1, iTarget, TIME_TO_SQUELCH_REMOVE);
		DisplayMenu_Mute(iParam1, GetMenuSelectionPosition());
	}
	else
	{
		DisplayMenu_Time(iParam1, iTarget, SQUELCH_TYPE_MUTE);
	}
}

bool:CheckSpammingCommand(iClient)
{
	new Float:fCurTime = GetEngineTime();
	if(g_fLastSquelchSet[iClient] + SQUELCH_SET_DELAY > fCurTime)
		return false;
	
	g_fLastSquelchSet[iClient] = fCurTime;
	
	return true;
}

Forward_OnClientStartSpeaking(iClient)
{
	g_bIsUsingVoice[iClient] = true;
	g_fVoiceStartTime[iClient] = GetEngineTime();
	g_fNextSpamHintTimeClient[iClient] = 0.0;
	
	decl result;
	Call_StartForward(g_hFwd_OnClientStartSpeaking);
	Call_PushCell(iClient);
	Call_Finish(result);
	
	UpdateClientInArray(iClient, g_hVoiceArray);
}

Forward_OnClientStopSpeaking(iClient)
{
	g_bIsUsingVoice[iClient] = false;
	
	decl result;
	Call_StartForward(g_hFwd_OnClientStopSpeaking);
	Call_PushCell(iClient);
	Call_Finish(result);
}

Forward_OnClientSpeaking(iClient)
{
	g_fVoiceEndTime[iClient] = GetEngineTime() + VOICE_END_DELAY;
	
	decl result;
	Call_StartForward(g_hFwd_OnClientSpeaking);
	Call_PushCell(iClient);
	Call_Finish(result);
	
	CheckForVoiceSpam(iClient);
}

CheckForVoiceSpam(iClient)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(g_fVoiceStartTime[iClient] + VOICE_SPAM_DELAY > fCurTime)
		return;
	
	if(g_fNextSpamHintTimeClient[iClient] > fCurTime)
		return;
	
	g_fNextSpamHintTimeClient[iClient] = fCurTime + VOICE_SPAM_HINT_DELAY_CLIENT;
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer) || IsFakeClient(iPlayer))
			continue;
		
		if(IsClientMutingTarget(iPlayer, iClient))
			continue;
		
		if(g_fNextSpamHintTimeTarget[iPlayer] > fCurTime)
			continue;
		
		g_fNextSpamHintTimeTarget[iPlayer] = fCurTime + VOICE_SPAM_HINT_DELAY_TARGET;
		DisplaySpamHintMessage(iPlayer);
	}
}

DisplaySpamHintMessage(iClient)
{
	static Float:fNextHintMessage[MAXPLAYERS+1];
	
	if(fNextHintMessage[iClient] > GetEngineTime())
		return;
	
	fNextHintMessage[iClient] = GetEngineTime() + VOICE_SPAM_HINT_DELAY_CLIENT;
	
	CPrintToChat(iClient, "{lightgreen}- {olive}Is someone {lightred}spamming {olive}or {lightred}bothering you{olive}?");
	CPrintToChat(iClient, "{lightgreen}- {olive}Type {lightred}!sm {olive}to {lightred}mute (voice) {olive}and {lightred}!sg {olive}to {lightred}gag (text){olive} them.");
	CPrintToChat(iClient, "{lightgreen}- {olive}You can also use {lightred}!ms {olive}to {lightred}mute everyone speaking {olive}.");
}

DisplayMenu_Time(iClient, iTarget, SquelchType:iSquelchType, bool:bWasPreSquelched=false, iAdminSerial=0, const String:szAdminName[]="")
{
	new iLen;
	decl String:szTitle[255];
	
	switch(iSquelchType)
	{
		case SQUELCH_TYPE_GAG: iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "Gag length for: %N", iTarget);
		case SQUELCH_TYPE_MUTE: iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "Mute length for: %N", iTarget);
		default: return;
	}
	
	if(iAdminSerial)
	{
		new iAdmin = GetClientFromSerial(iAdminSerial);
		
		decl String:szName[MAX_NAME_LENGTH];
		if(iAdmin)
			GetClientName(iAdmin, szName, sizeof(szName));
		else
			strcopy(szName, sizeof(szName), szAdminName);
		
		iLen += FormatEx(szTitle[iLen], sizeof(szTitle)-iLen, "\n \nThe admin %s\nthinks this player is spamming.\n \nSelect a length to mute %N\nor simply exit the menu if you disagree.", szName, iTarget);
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_Time);
	SetMenuTitle(hMenu, szTitle);
	
	new iTargetSerial = GetClientSerial(iTarget);
	
	AddMenuItem(hMenu, "0", "Exit Menu (no squelch)");
	
	decl String:szInfo[32];
	FormatEx(szInfo, sizeof(szInfo), "%i/%i/%i", iSquelchType, iTargetSerial, TIME_TO_SQUELCH_ROUND_END);
	AddMenuItem(hMenu, szInfo, "Round End");
	
	FormatEx(szInfo, sizeof(szInfo), "%i/%i/%i", iSquelchType, iTargetSerial, TIME_TO_SQUELCH_MAP_END);
	AddMenuItem(hMenu, szInfo, "Map End");
	
	// Only allow squelching longer than the map duration if the cvar allows it, and the client is not an admin.
	if(!GetConVarBool(cvar_squelchmanager_limit_duration_to_map) && Admins_GetLevel(iClient) == AdminLevel_None)
	{
		FormatEx(szInfo, sizeof(szInfo), "%i/%i/%i", iSquelchType, iTargetSerial, 3600);
		AddMenuItem(hMenu, szInfo, "1 Hour");
		
		FormatEx(szInfo, sizeof(szInfo), "%i/%i/%i", iSquelchType, iTargetSerial, 86400);
		AddMenuItem(hMenu, szInfo, "1 Day");
		
		FormatEx(szInfo, sizeof(szInfo), "%i/%i/%i", iSquelchType, iTargetSerial, 604800);
		AddMenuItem(hMenu, szInfo, "1 Week");
		
		FormatEx(szInfo, sizeof(szInfo), "%i/%i/%i", iSquelchType, iTargetSerial, 2592000);
		AddMenuItem(hMenu, szInfo, "1 Month");
	}
	
	g_bTimeMenu_TargetSerial[iClient] = GetClientSerial(iTarget);
	g_bTimeMenu_WasPreSquelched[iClient] = bWasPreSquelched;
	
	g_bIsInMenu[iClient] = true;
	
	SetMenuExitBackButton(hMenu, false);
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		ResetPresquelchIfNeeded(iClient);
		return;
	}
}

ResetPresquelchIfNeeded(iClient)
{
	if(g_bTimeMenu_WasPreSquelched[iClient] && AreFlagsLoaded(iClient))
	{
		new iTarget = GetClientFromSerial(g_bTimeMenu_TargetSerial[iClient]);
		if(iTarget)
			SetListeningStateFromSquelchFlags(iClient, iTarget, g_iSquelchFlags[iClient][iTarget]);
	}
}

public MenuHandle_Time(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_fNextMenuDisplayTime[iParam1] = GetEngineTime() + MENU_QUEUE_DISPLAY_DELAY;
		g_bIsInMenu[iParam1] = false;
		g_bTimeMenu_TargetSerial[iParam1] = 0;
		
		if(IsClientInGame(iParam1))
		{
			ResetPresquelchIfNeeded(iParam1);
			DisplaySpamHintMessage(iParam1);
		}
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	g_fNextMenuDisplayTime[iParam1] = GetEngineTime() + MENU_QUEUE_DISPLAY_DELAY;
	g_bIsInMenu[iParam1] = false;
	
	decl String:szInfo[32];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	if(StrEqual(szInfo, "0"))
	{
		ResetPresquelchIfNeeded(iParam1);
		DisplaySpamHintMessage(iParam1);
		g_bTimeMenu_TargetSerial[iParam1] = 0;
		return;
	}
	
	g_bTimeMenu_TargetSerial[iParam1] = 0;
	
	decl String:szBuffer[3][12];
	new iNumExplodes = ExplodeString(szInfo, "/", szBuffer, sizeof(szBuffer), sizeof(szBuffer[]));
	
	if(iNumExplodes != 3)
	{
		PrintToChat(iParam1, "[SM] Something went wrong.");
		return;
	}
	
	new iTarget = GetClientFromSerial(StringToInt(szBuffer[1]));
	
	if(!iTarget)
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {red}Selected player is no longer in server.");
		return;
	}
	
	new SquelchType:iSquelchType = SquelchType:StringToInt(szBuffer[0]);
	new iSeconds = StringToInt(szBuffer[2]);
	
	if(iSeconds == TIME_TO_SQUELCH_REMOVE)
	{
		RemoveClientSquelchTypeFromRoundEnd(iParam1, iSquelchType);
	}
	else if(iSeconds == TIME_TO_SQUELCH_ROUND_END)
	{
		decl eRoundEndSquelch[RoundEndSquelch];
		eRoundEndSquelch[RoundEndSquelch_ClientSerial] = GetClientSerial(iParam1);
		eRoundEndSquelch[RoundEndSquelch_TargetSerial] = GetClientSerial(iTarget);
		eRoundEndSquelch[RoundEndSquelch_SquelchType] = iSquelchType;
		PushArrayArray(g_aRoundEndSquelches, eRoundEndSquelch);
	}
	
	switch(iSquelchType)
	{
		case SQUELCH_TYPE_GAG:
		{
			SetClientGaggingTarget(iParam1, iTarget, iSeconds);
			DisplayMenu_Gag(iParam1);
		}
		case SQUELCH_TYPE_MUTE:
		{
			SetClientMutingTarget(iParam1, iTarget, iSeconds);
			DisplayMenu_Mute(iParam1);
		}
	}
}

OpenSquelchedWebPage(iClient)
{
	if(!GetConVarBool(cvar_squelchmanager_show_vote_warning))
		return;
	
	// Don't open multiple webpages too quickly.
	if(!CheckSpammingCommand(iClient))
		return;
	
	decl iClients[1];
	iClients[0] = iClient;
	FadeScreen(iClients, 1, 5, VOTED_TIMEOUT_SECONDS, {0, 0, 0, 255}, FFADE_IN | FFADE_PURGE);
	
	WebPageViewer_OpenPage(iClient, "http://swoobles.com/page/votesm");
	
	StartTimer_VotedTimeout(iClient);
}

StartTimer_VotedTimeout(iClient)
{
	StopTimer_VotedTimeout(iClient);
	
	g_iVotedTimeoutSeconds[iClient] = 0;
	Timer_VotedTimeout(INVALID_HANDLE, GetClientSerial(iClient));
	g_hTimer_VotedTimeout[iClient] = CreateTimer(1.0, Timer_VotedTimeout, GetClientSerial(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

StopTimer_VotedTimeout(iClient)
{
	if(g_hTimer_VotedTimeout[iClient] == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_VotedTimeout[iClient]);
	g_hTimer_VotedTimeout[iClient] = INVALID_HANDLE;
}

public Action:Timer_VotedTimeout(Handle:hTimer, any:iClientSerial)
{
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
	{
		g_hTimer_VotedTimeout[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if(hTimer != INVALID_HANDLE)
		g_iVotedTimeoutSeconds[iClient]++;
	
	if(g_iVotedTimeoutSeconds[iClient] >= VOTED_TIMEOUT_SECONDS)
	{
		PrintHintText(iClient, "<font color='#DE2626'>Please try to be less annoying.</font>\n<font color='#6FC41A'>You will end up making friends!</font>");
		g_hTimer_VotedTimeout[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	PrintHintText(iClient, "<font color='#26D2DE'>You were vote muted.</font>\n<font color='#6FC41A'>Timeout remaining:</font> <font color='#DE2626'>%i</font>", VOTED_TIMEOUT_SECONDS - g_iVotedTimeoutSeconds[iClient]);
	return Plugin_Continue;
}

FadeScreen(iClients[], iNumClients, iDurationSeconds, iHoldSeconds, iColor[4], iFlags)
{
	new Handle:hMessage = StartMessageEx(g_msgFade, iClients, iNumClients);
	
	if(GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(hMessage, "duration", (1<<SCREENFADE_FRACBITS) * iDurationSeconds);
		PbSetInt(hMessage, "hold_time", (1<<SCREENFADE_FRACBITS) * iHoldSeconds);
		PbSetInt(hMessage, "flags", iFlags);
		PbSetColor(hMessage, "clr", iColor);
	}
	else
	{
		BfWriteShort(hMessage, (1<<SCREENFADE_FRACBITS) * iDurationSeconds);
		BfWriteShort(hMessage, (1<<SCREENFADE_FRACBITS) * iHoldSeconds);
		BfWriteShort(hMessage, iFlags);
		BfWriteByte(hMessage, iColor[0]);
		BfWriteByte(hMessage, iColor[1]);
		BfWriteByte(hMessage, iColor[2]);
		BfWriteByte(hMessage, iColor[3]);
	}
	
	EndMessage();
}