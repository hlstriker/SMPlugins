/*
** Delete the following plugins if you use this plugin:
** rockthevote.smx, mapchooser.smx, nominations.smx,
** basetriggers.smx, nextmap.smx, randomcycle.smx
*/

#include <sourcemod>
#include <cstrike>
#include <emitsoundany>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/DatabaseServers/database_servers"
#include "map_voting"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../ForceMapEnd/force_map_end"
#include "../AFKManager/afk_manager"
#include "../../RandomIncludes/kztimer"
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma dynamic 500000

new const String:PLUGIN_NAME[] = "Map Voting";
new const String:PLUGIN_VERSION[] = "1.26";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A better map voting system.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_mp_timelimit;
new Handle:cvar_mp_endmatch_votenextleveltime;
new Handle:cvar_sm_vote_progress_hintbox;
new Handle:cvar_mp_roundtime;
new Handle:cvar_mp_roundtime_defuse;
new Handle:cvar_mp_roundtime_hostage;
new Handle:cvar_mp_roundtime_deployment;

new bool:g_bOriginalHintBoxValue;

new g_iTimeToChooseIndex;
new const String:SZ_SOUND_TIME_TO_CHOOSE[][] =
{
	"sound/swoobles/map_vote/choose1.mp3",
	"sound/swoobles/map_vote/choose2.mp3"
};

new const String:SZ_SOUND_COUNTDOWN[][] =
{
	"sound/swoobles/map_vote/one.mp3",
	"sound/swoobles/map_vote/two.mp3",
	"sound/swoobles/map_vote/three.mp3"
};

#define MAX_MAP_CAT_NAME_LENGTH		65
#define MAX_MAP_CAT_TAG_LENGTH		9
#define MAX_MAP_NAME_LENGTH			65

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new g_iCategoryIDToIndex[65536];
new Handle:g_aCategories;
enum _:Category
{
	Category_ID,
	String:Category_Name[MAX_MAP_CAT_NAME_LENGTH],
	String:Category_Tag[MAX_MAP_CAT_TAG_LENGTH],
	Category_PlayedMin,
	Category_PlayedMax,
	Handle:Category_MapIndexes
};

new Handle:g_aMaps;
enum _:Map
{
	String:Map_Name[MAX_MAP_NAME_LENGTH],
	String:Map_NameFormatted[MAX_MAP_NAME_LENGTH],
	Map_PlayersMin,
	Map_PlayersMax,
	Map_CategoryID,
	Float:Map_MapTime,
	Float:Map_RoundTime,
	bool:Map_Disabled
};

new Handle:g_aTrie_MapQuickIndex; // Map name as key, map array index as value.

new g_iUniqueMapCounter;

#define INVALID_NOMINATION_INDEX	-1
new g_iClientNominationsIndex[MAXPLAYERS+1];
new Handle:g_aNominations;
new Handle:g_aRockTheVotePlayers;

new Handle:cvar_sm_rtv_changetime;
new Handle:cvar_sm_rtv_initialdelay;
new Handle:cvar_sm_rtv_interval;
new Handle:cvar_sm_rtv_minplayers;
new Handle:cvar_sm_rtv_needed;
new Handle:cvar_sm_rtv_postvoteaction;
new Handle:cvar_sm_rtv_roundend_forcetime;

new Handle:cvar_sm_extendmap_timestep;
new Handle:cvar_sm_mapvote_endvote;
new Handle:cvar_sm_mapvote_exclude;
new Handle:cvar_sm_mapvote_extend;
new Handle:cvar_sm_mapvote_include;
new Handle:cvar_sm_mapvote_start;
new Handle:cvar_sm_mapvote_voteduration;

new Handle:cvar_sm_mapvote_playedmax_type;

new Handle:cvar_mapvoting_log_nextmap;

new bool:g_bIsVoteInProgress;
new Float:g_fLastMapVote;

new g_iCountDownTimer;
new Handle:g_hMenu_MapVote;
new Handle:g_hTimer_EndOfMapVote;
new Handle:g_hTimer_MapVote;

new bool:g_bWasNextMapSelected;
new String:g_szNextMapSelected[MAX_MAP_NAME_LENGTH];

new g_iNumTimesExtended;

new Handle:g_aRecentlyPlayedMaps;

enum StartedByType
{
	STARTED_BY_RTV = 1,
	STARTED_BY_MAPVOTE
};

new StartedByType:g_iStartedByType;

new g_iNumPlayersVoted;
new g_bHasClientVotedFromMenu[MAXPLAYERS+1];

new g_iNumVoteSelections;
new g_iClientsVoteIndex[MAXPLAYERS+1];

new g_iVoteMapTally[11];
new g_iVoteMapIndexes[11];
new String:g_szVoteMapNames[11][MAX_MAP_NAME_LENGTH];

#define MAP_INDEX_DONT_CARE	-1
#define MAP_INDEX_EXTEND	-2

new g_iFrameNum;
new g_iFrameRevote[MAXPLAYERS+1];
new g_iFrameCancel[MAXPLAYERS+1];

#define NEXTMAP_AUTO_PRINT_DELAY	5.0
new Float:g_fLastNextMapAutoPrint[MAXPLAYERS+1];

new g_iLastPlayedCategoryID = -1;
new g_iSameCategoryPlayedInRow;
new Handle:g_aTrie_CategoryPlayedCount;

new Float:g_fNextEligiblePlayerCountCheck;
new g_iEligiblePlayerCount;

new Handle:g_hFwd_OnCategoriesLoaded;
new Handle:g_hFwd_OnMapsLoaded;
new Handle:g_hFwd_OnVoteRocked;

new g_iMapChangeTime;

new bool:g_bLibLoaded_ForceMapEnd;
new bool:g_bLibLoaded_AFKManager;
new bool:g_bLibLoaded_KZTimer;


public OnPluginStart()
{
	CreateConVar("map_voting_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnCategoriesLoaded = CreateGlobalForward("MapVoting_OnCategoriesLoaded", ET_Ignore);
	g_hFwd_OnMapsLoaded = CreateGlobalForward("MapVoting_OnMapsLoaded", ET_Ignore);
	g_hFwd_OnVoteRocked = CreateGlobalForward("MapVoting_OnVoteRocked", ET_Ignore, Param_Cell);
	
	g_aCategories = CreateArray(Category);
	g_aMaps = CreateArray(Map);
	g_aNominations = CreateArray(MAX_MAP_NAME_LENGTH);
	g_aRecentlyPlayedMaps = CreateArray(MAX_MAP_NAME_LENGTH);
	g_aRockTheVotePlayers = CreateArray();
	
	g_aTrie_MapQuickIndex = CreateTrie();
	g_aTrie_CategoryPlayedCount = CreateTrie();
	
	HookEvent("cs_intermission", Event_Intermission_Post, EventHookMode_PostNoCopy);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	RegConsoleCmd("sm_nominate", OnNominate);
	RegConsoleCmd("sm_nom", OnNominate);
	RegConsoleCmd("sm_nextmap", OnNextMap);
	RegConsoleCmd("sm_timeleft", OnTimeLeft);
	RegConsoleCmd("sm_revote", OnRevote);
	RegConsoleCmd("sm_rtv", OnRockTheVote);
	RegConsoleCmd("sm_rockthevote", OnRockTheVote);
	
	RegAdminCmd("sm_setnextmap", OnSetNextMap, ADMFLAG_CHANGEMAP, "sm_setnextmap <mapname> - Sets what the next map will be.");
	
	// cvars for rtv.cfg
	if((cvar_sm_rtv_changetime = FindConVar("sm_rtv_changetime")) == INVALID_HANDLE)
		cvar_sm_rtv_changetime = CreateConVar("sm_rtv_changetime", "0", "When to change the map after a succesful RTV: 0 - Instant, 1 - RoundEnd, 2 - MapEnd");
	
	if((cvar_sm_rtv_initialdelay = FindConVar("sm_rtv_initialdelay")) == INVALID_HANDLE)
		cvar_sm_rtv_initialdelay = CreateConVar("sm_rtv_initialdelay", "30", "Time (in seconds) before first RTV can be held");
	
	if((cvar_sm_rtv_interval = FindConVar("sm_rtv_interval")) == INVALID_HANDLE)
		cvar_sm_rtv_interval = CreateConVar("sm_rtv_interval", "240", "Time (in seconds) after a failed RTV before another can be held");
	
	if((cvar_sm_rtv_minplayers = FindConVar("sm_rtv_minplayers")) == INVALID_HANDLE)
		cvar_sm_rtv_minplayers = CreateConVar("sm_rtv_minplayers", "0", "Number of players required before RTV will be enabled.");
	
	if((cvar_sm_rtv_needed = FindConVar("sm_rtv_needed")) == INVALID_HANDLE)
		cvar_sm_rtv_needed = CreateConVar("sm_rtv_needed", "0.60", "Percentage of players needed to rockthevote (Def 60%)");
	
	if((cvar_sm_rtv_postvoteaction = FindConVar("sm_rtv_postvoteaction")) == INVALID_HANDLE)
		cvar_sm_rtv_postvoteaction = CreateConVar("sm_rtv_postvoteaction", "0", "What to do with RTV's after a mapvote has completed. 0 - Allow, success = instant change, 1 - Deny");
	
	if((cvar_sm_rtv_roundend_forcetime = FindConVar("sm_rtv_roundend_forcetime")) == INVALID_HANDLE)
		cvar_sm_rtv_roundend_forcetime = CreateConVar("sm_rtv_roundend_forcetime", "0", "Only for sm_rtv_changetime 1: The number of seconds before the round will force end after a map vote passes. Set to 0 to disable.");
	
	AutoExecConfig(false, "rtv", "sourcemod");
	
	// cvars for mapchooser.cfg
	if((cvar_sm_extendmap_timestep = FindConVar("sm_extendmap_timestep")) == INVALID_HANDLE)
		cvar_sm_extendmap_timestep = CreateConVar("sm_extendmap_timestep", "15", "Specifies how many more minutes each extension makes");
	
	if((cvar_sm_mapvote_endvote = FindConVar("sm_mapvote_endvote")) == INVALID_HANDLE)
		cvar_sm_mapvote_endvote = CreateConVar("sm_mapvote_endvote", "1", "Specifies if there should be an end of map vote");
	
	if((cvar_sm_mapvote_exclude = FindConVar("sm_mapvote_exclude")) == INVALID_HANDLE)
		cvar_sm_mapvote_exclude = CreateConVar("sm_mapvote_exclude", "5", "Specifies how many past maps to exclude from the vote.");
	
	if((cvar_sm_mapvote_extend = FindConVar("sm_mapvote_extend")) == INVALID_HANDLE)
		cvar_sm_mapvote_extend = CreateConVar("sm_mapvote_extend", "0", "Number of extensions allowed each map.");
	
	if((cvar_sm_mapvote_include = FindConVar("sm_mapvote_include")) == INVALID_HANDLE)
		cvar_sm_mapvote_include = CreateConVar("sm_mapvote_include", "7", "Specifies how many maps to include in the vote.", _, true, 2.0, true, 7.0);
	
	if((cvar_sm_mapvote_start = FindConVar("sm_mapvote_start")) == INVALID_HANDLE)
		cvar_sm_mapvote_start = CreateConVar("sm_mapvote_start", "3.0", "Specifies when to start the vote based on time remaining (in minutes).");
	
	if((cvar_sm_mapvote_voteduration = FindConVar("sm_mapvote_voteduration")) == INVALID_HANDLE)
		cvar_sm_mapvote_voteduration = CreateConVar("sm_mapvote_voteduration", "20", "Specifies how long the mapvote should be available for (in seconds).");
	
	if((cvar_sm_mapvote_playedmax_type = FindConVar("sm_mapvote_playedmax_type")) == INVALID_HANDLE)
		cvar_sm_mapvote_playedmax_type = CreateConVar("sm_mapvote_playedmax_type", "1", "0: How many times a category can be played in a row before another category is forced. 1: How many times a category can be played in a cycle before the cycle is reset.", _, true, 0.0, true, 1.0);
	
	AutoExecConfig(false, "mapchooser", "sourcemod");
	
	// Custom cvars
	cvar_mapvoting_log_nextmap = CreateConVar("mapvoting_log_nextmap", "0", "Should the nextmap be logged?", _, true, 0.0, true, 1.0);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("map_voting");
	CreateNative("MapVoting_GetMapList", _MapVoting_GetMapList);
	CreateNative("MapVoting_AddCategory", _MapVoting_AddCategory);
	CreateNative("MapVoting_SwitchMapsCategory", _MapVoting_SwitchMapsCategory);
	CreateNative("MapVoting_RemoveUnusedCategories", _MapVoting_RemoveUnusedCategories);
	CreateNative("MapVoting_RemoveMap", _MapVoting_RemoveMap);
	
	return APLRes_Success;
}

public _MapVoting_RemoveMap(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters MapVoting_RemoveMap");
		return false;
	}
	
	decl String:szMapName[MAX_MAP_NAME_LENGTH];
	GetNativeString(1, szMapName, sizeof(szMapName));
	
	decl iMapIndex;
	if(!GetTrieValue(g_aTrie_MapQuickIndex, szMapName, iMapIndex))
		return false;
	
	// Don't actually remove the map from the g_aMaps array. Just disable it so we don't have to reindex everything.
	decl eMap[Map];
	GetArrayArray(g_aMaps, iMapIndex, eMap);
	eMap[Map_Disabled] = true;
	SetArrayArray(g_aMaps, iMapIndex, eMap);
	
	decl eCategory[Category];
	GetArrayArray(g_aCategories, g_iCategoryIDToIndex[eMap[Map_CategoryID]], eCategory);
	
	new iIndex = FindValueInArray(eCategory[Category_MapIndexes], iMapIndex);
	if(iIndex != -1)
		RemoveFromArray(eCategory[Category_MapIndexes], iIndex);
	
	return true;
}

public _MapVoting_RemoveUnusedCategories(Handle:hPlugin, iNumParams)
{
	RemoveUnusedCategories();
}

public _MapVoting_GetMapList(Handle:hPlugin, iNumParams)
{
	new Handle:aList = GetNativeCell(1);
	if(aList == INVALID_HANDLE)
		return false;
	
	new bool:bFormatNames = false;
	if(iNumParams > 1)
		bFormatNames = bool:GetNativeCell(2);
	
	new iArraySize = GetArraySize(g_aMaps);
	
	decl eMap[Map];
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aMaps, i, eMap);
		
		if(bFormatNames)
			PushArrayString(aList, eMap[Map_NameFormatted]);
		else
			PushArrayString(aList, eMap[Map_Name]);
	}
	
	return true;
}

public _MapVoting_AddCategory(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 4)
	{
		LogError("Invalid number of parameters MapVoting_AddCategory");
		return -1;
	}
	
	new iCatID = FindFreeCategoryIndex();
	if(iCatID == -1)
		return -1;
	
	decl String:szCatName[MAX_MAP_CAT_NAME_LENGTH], String:szCatTag[MAX_MAP_CAT_TAG_LENGTH];
	GetNativeString(1, szCatName, sizeof(szCatName));
	GetNativeString(2, szCatTag, sizeof(szCatTag));
	
	if(!AddCategory(iCatID, szCatName, szCatTag, GetNativeCell(3), GetNativeCell(4)))
		return -1;
	
	return iCatID;
}

public _MapVoting_SwitchMapsCategory(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters MapVoting_SwitchMapsCategory");
		return false;
	}
	
	decl String:szMapName[MAX_MAP_NAME_LENGTH];
	GetNativeString(1, szMapName, sizeof(szMapName));
	
	decl iMapIndex;
	if(!GetTrieValue(g_aTrie_MapQuickIndex, szMapName, iMapIndex))
		return false;
	
	// Add map to new category.
	decl eMap[Map], eCategory[Category], iOldCategoryID;
	GetArrayArray(g_aMaps, iMapIndex, eMap);
	iOldCategoryID = eMap[Map_CategoryID];
	eMap[Map_CategoryID] = GetNativeCell(2);
	SetArrayArray(g_aMaps, iMapIndex, eMap);
	
	GetArrayArray(g_aCategories, g_iCategoryIDToIndex[eMap[Map_CategoryID]], eCategory);
	PushArrayCell(eCategory[Category_MapIndexes], iMapIndex);
	
	// Remove map from old category.
	GetArrayArray(g_aCategories, g_iCategoryIDToIndex[iOldCategoryID], eCategory);
	new iIndex = FindValueInArray(eCategory[Category_MapIndexes], iMapIndex);
	if(iIndex != -1)
		RemoveFromArray(eCategory[Category_MapIndexes], iIndex);
	
	return true;
}

public OnMapTimeLeftChanged()
{
	SetupTimeleftTimer();
}

StartTimer_EndOfMapVote(Float:fInterval)
{
	StopTimer_EndOfMapVote();
	g_hTimer_EndOfMapVote = CreateTimer(fInterval, Timer_EndOfMapVote);
}

StopTimer_EndOfMapVote()
{
	if(g_hTimer_EndOfMapVote == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_EndOfMapVote);
	g_hTimer_EndOfMapVote = INVALID_HANDLE;
}

public Action:Timer_EndOfMapVote(Handle:hTimer)
{
	g_hTimer_EndOfMapVote = INVALID_HANDLE;
	
	if(g_bIsVoteInProgress)
		return;
	
	MapVoteStartTimer(STARTED_BY_MAPVOTE);
}

SetupTimeleftTimer()
{
	if(g_bWasNextMapSelected || !GetConVarBool(cvar_sm_mapvote_endvote))
		return;
	
	new iTime;
	if(GetMapTimeLeft(iTime) && iTime > 0)
	{
		new Float:fTime = float(iTime);
		new Float:fStartTime = GetConVarFloat(cvar_sm_mapvote_start) * 60.0;
		
		if(fTime - fStartTime < 0.0 && !g_bIsVoteInProgress)
		{
			MapVoteStartTimer(STARTED_BY_MAPVOTE);
		}
		else
		{
			StartTimer_EndOfMapVote(fTime - fStartTime);
		}		
	}
}

ClearNominations()
{
	for(new i=0; i<sizeof(g_iClientNominationsIndex); i++)
		g_iClientNominationsIndex[i] = INVALID_NOMINATION_INDEX;
	
	ClearArray(g_aNominations);
}

bool:IsMapNominated(iClient, const String:szMapName[])
{
	if(g_iClientNominationsIndex[iClient] == INVALID_NOMINATION_INDEX)
		return false;
	
	decl String:szMap[MAX_MAP_NAME_LENGTH];
	GetArrayString(g_aNominations, g_iClientNominationsIndex[iClient], szMap, sizeof(szMap));
	
	return StrEqual(szMap, szMapName);
}

public Action:OnRockTheVote(iClient, iArgNum)
{
	RockTheVote(iClient);
	return Plugin_Handled;
}

public Action:OnNominate(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgNum != 1)
	{
		DisplayMenu_NominateCategorySelect(iClient);
		return Plugin_Handled;
	}
	
	decl String:szMapName[MAX_MAP_NAME_LENGTH];
	GetCmdArg(1, szMapName, sizeof(szMapName));
	StringToLower(szMapName, sizeof(szMapName));
	
	decl iMapIndex;
	if(!GetTrieValue(g_aTrie_MapQuickIndex, szMapName, iMapIndex))
	{
		new iDisplayIndex = FindMatchingMapName(szMapName);
		if(iDisplayIndex == -1)
		{
			DisplayMenu_NominateCategorySelect(iClient);
			return Plugin_Handled;
		}
		
		DisplayMenu_NominateMapSelectAll(iClient, iDisplayIndex);
		return Plugin_Handled;
	}
	
	NominateMap(iClient, iMapIndex);
	
	return Plugin_Handled;
}

public Action:OnSetNextMap(iClient, iArgNum)
{
	if(iArgNum < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_setnextmap <mapname>");
		return Plugin_Handled;
	}
	
	decl String:szMapName[MAX_MAP_NAME_LENGTH];
	GetCmdArg(1, szMapName, sizeof(szMapName));
	StringToLower(szMapName, sizeof(szMapName));
	
	decl iMapIndex;
	if(!GetTrieValue(g_aTrie_MapQuickIndex, szMapName, iMapIndex))
	{
		ReplyToCommand(iClient, "[SM] Error: Map \"%s\" not found.", szMapName);
		return Plugin_Handled;
	}
	
	SetNextLevel(szMapName);
	ReplyToCommand(iClient, "[SM] Set next map to \"%s\".", szMapName);
	
	return Plugin_Handled;
}

public OnGameFrame()
{
	g_iFrameNum++;
}

public Action:OnRevote(iClient, iArgNum)
{
	if(g_hMenu_MapVote == INVALID_HANDLE)
		return Plugin_Handled;
	
	g_iFrameRevote[iClient] = g_iFrameNum;
	
	if(g_iFrameCancel[iClient] == g_iFrameRevote[iClient])
	{
		// Menu cancel was first. It added to "I don't care".
		// We need to keep "I don't care", BUT we need to set this player as hasn't voted from menu.
		MarkAsHasntVotedFromMenu(iClient);
	}
	
	return Plugin_Handled;
}

public Action:OnTimeLeft(iClient, iArgNum)
{
	DisplayTimeLeft(iClient);
	return Plugin_Handled;
}

DisplayTimeLeft(iClient)
{
	decl iSecondsLeft;
	if(!GetMapTimeLeft(iSecondsLeft))
	{
		ReplyToCommand(iClient, "Unknown time left.");
		return;
	}
	
	if(iSecondsLeft <= 0)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}There is no time limit.");
		return;
	}
	
	decl String:szTime[18];
	new Float:fSeconds = float(iSecondsLeft);
	
	if(fSeconds >= 3600.0)
	{
		FormatEx(szTime, sizeof(szTime), "%.01f hours", fSeconds / 3600.0);
	}
	else if(fSeconds >= 60.0)
	{
		FormatEx(szTime, sizeof(szTime), "%.01f minutes", fSeconds / 60.0);
	}
	else
	{
		FormatEx(szTime, sizeof(szTime), "%i seconds", iSecondsLeft);
	}
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Time remaining: {lightred}%s{olive}.", szTime);
}

public Action:OnNextMap(iClient, iArgNum)
{
	DisplayNextMapText(iClient);
	return Plugin_Handled;
}

public Action:OnClientSayCommand(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!iClient)
		return;
	
	static iMapIndex;
	if(GetTrieValue(g_aTrie_MapQuickIndex, szArgs, iMapIndex))
	{
		NominateMap(iClient, iMapIndex);
		return;
	}
	
	if(StrEqual(szArgs, "nom") || StrEqual(szArgs, "nominate"))
	{
		DisplayMenu_NominateCategorySelect(iClient);
		return;
	}
	
	if(StrEqual(szArgs, "rtv") || StrEqual(szArgs, "rockthevote"))
	{
		RockTheVote(iClient);
		return;
	}
	
	if(StrEqual(szArgs, "nextmap"))
	{
		DisplayNextMapText(iClient);
		return;
	}
	
	if(StrEqual(szArgs, "timeleft"))
	{
		DisplayTimeLeft(iClient);
		return;
	}
}

DisplayNextMapText(iClient, bool:bIsBeingAutoPrinted=false)
{
	if(bIsBeingAutoPrinted)
	{
		if(g_fLastNextMapAutoPrint[iClient] + NEXTMAP_AUTO_PRINT_DELAY > GetEngineTime())
			return;
		
		g_fLastNextMapAutoPrint[iClient] = GetEngineTime();
	}
	
	if(g_bWasNextMapSelected)
	{
		if(iClient)
		{
			decl String:szMapNameFormatted[MAX_MAP_NAME_LENGTH];
			strcopy(szMapNameFormatted, sizeof(szMapNameFormatted), g_szNextMapSelected);
			DBMaps_GetMapNameFormatted(szMapNameFormatted, sizeof(szMapNameFormatted));
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}The next map will be {lightred}%s{olive}.", szMapNameFormatted);
		}
		else
		{
			ReplyToCommand(iClient, g_szNextMapSelected);
		}
	}
	else
	{
		if(iClient)
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}The next map will be selected {lightred}after voting{olive}.");
		else
			ReplyToCommand(iClient, "Pending vote");
	}
}

RockTheVote(iClient)
{
	if(!iClient)
		return;
	
	if(g_bWasNextMapSelected)
	{
		if(GetConVarBool(cvar_sm_rtv_postvoteaction))
		{
			DisplayNextMapText(iClient);
		}
		else
		{
			switch(g_iMapChangeTime)
			{
				case CHANGETIME_NOT_SET:
				{
					if(AddToRockTheVotePlayers(iClient))
						HandleRockTheVoteChanging();
				}
				case CHANGETIME_INSTANTLY:
				{
					DisplayNextMapText(iClient);
				}
				case CHANGETIME_ROUND_END:
				{
					DisplayNextMapText(iClient);
				}
				case CHANGETIME_MAP_END:
				{
					DisplayNextMapText(iClient);
				}
				default:
				{
					DisplayNextMapText(iClient);
				}
			}
		}
		
		return;
	}
	
	if(g_bIsVoteInProgress)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You can't rock the vote while a vote is in progress.");
		return;
	}
	
	if(GetGameTime() < GetConVarFloat(cvar_sm_rtv_initialdelay))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You must wait {lightred}%i {olive}more seconds.", RoundFloat(GetConVarFloat(cvar_sm_rtv_initialdelay) - GetGameTime()));
		return;
	}
	
	if(g_fLastMapVote > 0.0 && GetEngineTime() < (g_fLastMapVote + GetConVarFloat(cvar_sm_rtv_interval)))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You must wait {lightred}%i {olive}more seconds.", RoundFloat((g_fLastMapVote + GetConVarFloat(cvar_sm_rtv_interval)) - GetEngineTime()));
		return;
	}
	
	if(AddToRockTheVotePlayers(iClient))
		MapVoteStartTimer(STARTED_BY_RTV);
}

bool:AddToRockTheVotePlayers(iClient)
{
	new bool:bHasRockedAlready;
	if(FindValueInArray(g_aRockTheVotePlayers, iClient) == -1)
		PushArrayCell(g_aRockTheVotePlayers, iClient);
	else
		bHasRockedAlready = true;
	
	decl iPlayerCount, iPlayersNeeded;
	new bool:bRet = CheckHasEnoughPlayersRockedTheVote(iPlayerCount, iPlayersNeeded);
	
	if(bHasRockedAlready)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You already rocked the vote {yellow}[{green}%i{yellow}/{green}%i{yellow}]{olive}.", iPlayerCount, iPlayersNeeded);
	}
	else
	{
		CPrintToChatAll("{green}[{lightred}SM{green}] {yellow}%N {olive}has rocked the vote {yellow}[{green}%i{yellow}/{green}%i{yellow}]{olive}.", iClient, iPlayerCount, iPlayersNeeded);
	}
	
	return bRet;
}

CheckIneligibleClientsVoteNowEligible(iClient)
{
	new iIndex = FindValueInArray(g_aRockTheVotePlayers, iClient);
	if(iIndex == -1)
		return;
	
	if(!CheckHasEnoughPlayersRockedTheVote())
		return;
	
	if(g_bWasNextMapSelected)
	{
		if(!GetConVarBool(cvar_sm_rtv_postvoteaction))
		{
			switch(g_iMapChangeTime)
			{
				case CHANGETIME_NOT_SET: HandleRockTheVoteChanging();
			}
		}
		
		return;
	}
	
	MapVoteStartTimer(STARTED_BY_RTV);
}

public AFKManager_OnBack(iClient)
{
	CheckIneligibleClientsVoteNowEligible(iClient);
}

public Event_PlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(GetEventInt(hEvent, "oldteam") != CS_TEAM_SPECTATOR)
		return;
	
	CheckIneligibleClientsVoteNowEligible(iClient);
}

bool:CheckHasEnoughPlayersRockedTheVote(&iPlayerCount=0, &iPlayersNeeded=0)
{
	new iNumOnTeams;
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer) || IsFakeClient(iPlayer))
			continue;
		
		if(!IsValidPlayerForRTV(iPlayer))
			continue;
		
		iNumOnTeams++;
	}
	
	new iPlayersNeededForPercent = RoundToCeil(iNumOnTeams * GetConVarFloat(cvar_sm_rtv_needed));
	new iPlayersNeededForMin = GetConVarInt(cvar_sm_rtv_minplayers);
	
	iPlayersNeeded = (iPlayersNeededForPercent > iPlayersNeededForMin) ? iPlayersNeededForPercent : iPlayersNeededForMin;
	iPlayerCount = GetNonAfkPlayerCountInRTVArray();
	
	if(iPlayerCount < iPlayersNeeded)
		return false;
	
	return true;
}

GetNonAfkPlayerCountInRTVArray()
{
	new iNumPlayers;
	
	decl iClient;
	new iArraySize = GetArraySize(g_aRockTheVotePlayers);
	for(new i=0; i<iArraySize; i++)
	{
		iClient = GetArrayCell(g_aRockTheVotePlayers, i);
		
		if(!IsValidPlayerForRTV(iClient))
			continue;
		
		iNumPlayers++;
	}
	
	return iNumPlayers;
}

bool:IsValidPlayerForRTV(iClient)
{
	static iTeam;
	iTeam = GetClientTeam(iClient);
	if(iTeam < CS_TEAM_SPECTATOR)
		return false;
	
	if(g_bLibLoaded_AFKManager)
	{
		#if defined _afk_manager_included
		if(AFKManager_IsAway(iClient))
			return false;
		#else
		if(iTeam == CS_TEAM_SPECTATOR)
			return false;
		#endif
	}
	else
	{
		if(iTeam == CS_TEAM_SPECTATOR)
			return false;
	}
	
	return true;
}

MapVoteStartTimer(StartedByType:iStartedByType)
{
	StopTimer_EndOfMapVote();
	
	g_iStartedByType = iStartedByType;
	
	g_bIsVoteInProgress = true;
	ClearArray(g_aRockTheVotePlayers);
	
	g_iCountDownTimer = 5;
	Timer_CountDown(INVALID_HANDLE);
	CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_CountDown(Handle:hTimer)
{
	if(hTimer != INVALID_HANDLE)
		g_iCountDownTimer--;
	
	if(g_iCountDownTimer > 0)
	{
		PrintHintTextToAll("<font color='#6FC41A'>Map vote in <font color='#DE2626'>%i</font> second%s.</font>\n<font size='16' color='#999999'>Press 1 when the menu appears if you\ndon't care which map is selected next.</font>", g_iCountDownTimer, (g_iCountDownTimer == 1) ? "" : "s");
		
		if(g_iCountDownTimer <= sizeof(SZ_SOUND_COUNTDOWN))
			EmitAmbientSoundAny(SZ_SOUND_COUNTDOWN[g_iCountDownTimer-1][6], Float:{0.0, 0.0, 0.0}, SOUND_FROM_WORLD, SNDLEVEL_NONE);
		
		return Plugin_Continue;
	}
	
	MapVoteStart();
	
	return Plugin_Stop;
}

StopTimer_MapVote()
{
	if(g_hTimer_MapVote == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_MapVote);
	g_hTimer_MapVote = INVALID_HANDLE;
}

MapVoteStart()
{
	if(!DisplayMenu_MapVote())
		return;
	
	g_bOriginalHintBoxValue = GetConVarBool(cvar_sm_vote_progress_hintbox);
	SetConVarBool(cvar_sm_vote_progress_hintbox, false);
	
	EmitAmbientSoundAny(SZ_SOUND_TIME_TO_CHOOSE[g_iTimeToChooseIndex][6], Float:{0.0, 0.0, 0.0}, SOUND_FROM_WORLD, SNDLEVEL_NONE);
	
	StopTimer_MapVote();
	
	g_iCountDownTimer = GetConVarInt(cvar_sm_mapvote_voteduration);
	Timer_MapVote(INVALID_HANDLE);
	g_hTimer_MapVote = CreateTimer(1.0, Timer_MapVote, _, TIMER_REPEAT);
}

MapVoteEnd()
{
	ClearNominations();
	g_fLastMapVote = GetEngineTime();
	g_bIsVoteInProgress = false;
	
	if(g_hMenu_MapVote != INVALID_HANDLE)
		CancelMenu(g_hMenu_MapVote);
	
	if(cvar_sm_vote_progress_hintbox != INVALID_HANDLE)
		SetConVarBool(cvar_sm_vote_progress_hintbox, g_bOriginalHintBoxValue);
}

OrderVoteIndexes(iVoteIndexes[], iNumIndexes)
{
	decl i, j, k, bool:bContinue;
	
	for(i=0; i<iNumIndexes; i++)
		iVoteIndexes[i] = -1;
	
	for(i=0; i<iNumIndexes; i++)
	{
		for(j=0; j<g_iNumVoteSelections; j++)
		{
			// Continue if mostvoteindex has been set AND the new tally is less than the current tally.
			if(iVoteIndexes[i] != -1 && g_iVoteMapTally[j] <= g_iVoteMapTally[iVoteIndexes[i]])
				continue;
			
			// Continue if this index is the same as any index before it.
			bContinue = false;
			for(k=i-1; k>=0; k--)
			{
				if(iVoteIndexes[k] != j)
					continue;
				
				bContinue = true;
				break;
			}
			
			if(bContinue)
				continue;
			
			iVoteIndexes[i] = j;
		}
	}
}

DisplayVoteTallyHintText()
{
	decl iMostVoteIndexes[3];
	OrderVoteIndexes(iMostVoteIndexes, sizeof(iMostVoteIndexes));
	
	new iNumAllowedToVote;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientAllowedToVote(iClient))
			iNumAllowedToVote++;
	}
	
	decl String:szBuffer[255];
	new iLen;
	
	iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "<font size='16'>");
	iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "<font color='#6FC41A'>Vote results [%i/%i] (<font color='#DE2626'>%i</font>)</font>", g_iNumPlayersVoted, iNumAllowedToVote, g_iCountDownTimer);
	
	for(new i=0; i<sizeof(iMostVoteIndexes); i++)
	{
		if(iMostVoteIndexes[i] == -1)
			continue;
		
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "\n[%i] %.20s", g_iVoteMapTally[iMostVoteIndexes[i]], g_szVoteMapNames[iMostVoteIndexes[i]]);
	}
	
	iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "</font>");
	
	PrintHintTextToAll(szBuffer);
}

GetWinningMapIndex()
{
	decl iMostVoteIndexes[3];
	OrderVoteIndexes(iMostVoteIndexes, sizeof(iMostVoteIndexes));
	
	new iNumTies;
	for(new i=1; i<sizeof(iMostVoteIndexes); i++)
	{
		if(iMostVoteIndexes[i] == -1)
			break;
		
		if(iMostVoteIndexes[i] == iMostVoteIndexes[i-1])
			iNumTies++;
	}
	
	decl iIndex;
	if(iNumTies)
	{
		new iNumAllowed;
		decl iIndexes[iNumTies];
		for(new i=0; i<=iNumTies; i++)
		{
			if(g_iVoteMapIndexes[iMostVoteIndexes[i]] == MAP_INDEX_DONT_CARE)
				continue;
			
			iIndexes[iNumAllowed++] = iMostVoteIndexes[i];
		}
		
		iIndex = iIndexes[GetRandomInt(0, iNumAllowed-1)];
	}
	else
	{
		if(g_iVoteMapIndexes[iMostVoteIndexes[0]] == MAP_INDEX_DONT_CARE)
			iIndex = iMostVoteIndexes[1];
		else
			iIndex = iMostVoteIndexes[0];
	}
	
	return g_iVoteMapIndexes[iIndex];
}

public Action:Timer_MapVote(Handle:hTimer)
{
	if(hTimer != INVALID_HANDLE)
		g_iCountDownTimer--;
	
	if(g_iCountDownTimer > 0)
	{
		DisplayVoteTallyHintText();
		return Plugin_Continue;
	}
	
	g_hTimer_MapVote = INVALID_HANDLE; // Set this before calling MapVoteEnd.
	
	ClearArray(g_aRockTheVotePlayers);
	
	// Tally up the votes.
	new iWinningMapIndex = GetWinningMapIndex();
	
	if(iWinningMapIndex == MAP_INDEX_EXTEND)
	{
		new Float:fExtendByMinutes = GetConVarFloat(cvar_sm_extendmap_timestep) * 60.0;
		new iExtendBySeconds = RoundFloat(fExtendByMinutes);
		ExtendMapTimeLimit(iExtendBySeconds);
		
		g_iNumTimesExtended++;
		
		PrintHintTextToAll("<font color='#26D2DE'>The current map will be extended.</font>\n<font color='#999999'>There are %i extensions left.</font>", GetConVarInt(cvar_sm_mapvote_extend) - g_iNumTimesExtended);
	}
	else
	{
		decl eMap[Map];
		GetArrayArray(g_aMaps, iWinningMapIndex, eMap);
		
		SetNextLevel(eMap[Map_Name]);
		
		for(new iClient=1; iClient<=MaxClients; iClient++)
		{
			if(IsClientInGame(iClient))
				DisplayNextMapText(iClient, true);
		}
		
		PrintHintTextToAll("<font color='#6FC41A'>The next map will be:</font>\n<font color='#DE2626'>%s</font>", eMap[Map_NameFormatted]);
	}
	
	MapVoteEnd();
	
	if(iWinningMapIndex != MAP_INDEX_EXTEND && g_iStartedByType == STARTED_BY_RTV)
	{
		HandleRockTheVoteChanging();
	}
	
	return Plugin_Stop;
}

HandleRockTheVoteChanging()
{
	switch(GetConVarInt(cvar_sm_rtv_changetime))
	{
		case CHANGETIME_INSTANTLY:
		{
			// Change instantly.
			g_iMapChangeTime = CHANGETIME_INSTANTLY;
			SetConVarInt(cvar_mp_timelimit, 0);
			//ExtendMapTimeLimit(1); // Don't do this here.  // Extend by a second so sourcemod knows the timelimit changed.
			CS_TerminateRound(0.1, CSRoundEnd_Draw);
		}
		case CHANGETIME_ROUND_END:
		{
			// Change at end of round.
			g_iMapChangeTime = CHANGETIME_ROUND_END;
			
			if(g_bLibLoaded_ForceMapEnd)
			{
				#if defined _force_map_end_included
				ForceMapEnd_SetCurrentRoundAsLast();
				
				if(GetConVarInt(cvar_sm_rtv_roundend_forcetime) > 0)
					ForceMapEnd_ForceChangeInSeconds(GetConVarInt(cvar_sm_rtv_roundend_forcetime));
				
				#else
				
				// Suppress warning.
				if(GetConVarInt(cvar_sm_rtv_roundend_forcetime))
				{
					//
				}
				
				SetConVarInt(cvar_mp_timelimit, 0);
				ExtendMapTimeLimit(1); // Extend by a second so sourcemod knows the timelimit changed.
				#endif
			}
			else
			{
				SetConVarInt(cvar_mp_timelimit, 0);
				ExtendMapTimeLimit(1); // Extend by a second so sourcemod knows the timelimit changed.
			}
		}
		case CHANGETIME_MAP_END:
		{
			// Change on map end.
			// Do nothing here.
			g_iMapChangeTime = CHANGETIME_MAP_END;
		}
	}
	
	Forward_OnVoteRocked(g_iMapChangeTime);
}

Forward_OnVoteRocked(iMapChangeTimeType)
{
	new result;
	Call_StartForward(g_hFwd_OnVoteRocked);
	Call_PushCell(iMapChangeTimeType);
	Call_Finish(result);
}

SetNextLevel(const String:szMapName[])
{
	StopTimer_MapVote();
	StopTimer_EndOfMapVote();
	
	g_bWasNextMapSelected = true;
	strcopy(g_szNextMapSelected, sizeof(g_szNextMapSelected), szMapName);
	SetNextMap(szMapName);
	
	if(GetConVarBool(cvar_mapvoting_log_nextmap))
	{
		decl String:szPath[PLATFORM_MAX_PATH], String:szCurMap[MAX_MAP_NAME_LENGTH];
		GetCurrentMap(szCurMap, sizeof(szCurMap));
		BuildPath(Path_SM, szPath, sizeof(szPath), "logs/map_voting.txt");
		LogToFile(szPath, "[Current: %s] - [Next: %s]", szCurMap, g_szNextMapSelected);
	}
}

GetEligiblePlayerCount()
{
	if(g_fNextEligiblePlayerCountCheck > GetEngineTime())
		return g_iEligiblePlayerCount;
	
	g_fNextEligiblePlayerCountCheck = GetEngineTime() + 3.0;
	g_iEligiblePlayerCount = 0;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || IsClientSourceTV(iClient))
			continue;
		
		g_iEligiblePlayerCount++;
	}
	
	return g_iEligiblePlayerCount;
}

GetMapsPlayerRequirementNeeds(const eMap[Map])
{
	new iPlayerCount = GetEligiblePlayerCount();
	
	// Players need to join.
	if(eMap[Map_PlayersMin] > 0)
	{
		if(iPlayerCount < eMap[Map_PlayersMin])
			return (eMap[Map_PlayersMin] - iPlayerCount);
	}
	
	// Players need to leave.
	if(eMap[Map_PlayersMax] > 0)
	{
		if(iPlayerCount > eMap[Map_PlayersMax])
			return (eMap[Map_PlayersMax] - iPlayerCount);
	}
	
	return 0;
}

CloseKZTimerMenuAll()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			CloseKZTimerMenu(iClient);
	}
}

CloseKZTimerMenu(iClient)
{
	if(g_bLibLoaded_KZTimer)
	{
		#if defined _KZTimer_included
		KZTimer_StopUpdatingOfClimbersMenu(iClient);
		#endif
	}
}

bool:DisplayMenu_MapVote()
{
	CloseKZTimerMenuAll();
	
	if(g_hMenu_MapVote != INVALID_HANDLE)
		return false;
	
	// Check for player count requirements of the nominated maps.
	decl String:szBuffer[255], i, j, iMapIndex, eMap[Map], String:szCurrentMap[MAX_MAP_NAME_LENGTH];
	for(i=GetArraySize(g_aNominations)-1; i>=0; i--)
	{
		GetArrayString(g_aNominations, i, szBuffer, sizeof(szBuffer));
		
		if(!GetTrieValue(g_aTrie_MapQuickIndex, szBuffer, iMapIndex))
			continue;
		
		GetArrayArray(g_aMaps, iMapIndex, eMap);
		
		if(eMap[Map_Disabled])
			continue;
		
		if(GetMapsPlayerRequirementNeeds(eMap) == 0)
			continue;
		
		RemoveFromArray(g_aNominations, i);
		
		CPrintToChatAll("{green}[{lightred}SM{green}] {red}%s no longer meets the player requirements.", szBuffer);
	}
	
	// Remove duplicates since multiple players can nominate the same map.
	for(i=GetArraySize(g_aNominations)-1; i>0; i--)
	{
		GetArrayString(g_aNominations, i, szCurrentMap, sizeof(szCurrentMap));
		
		for(j=i-1; j>=0; j--)
		{
			GetArrayString(g_aNominations, j, szBuffer, sizeof(szBuffer));
			
			if(!StrEqual(szCurrentMap, szBuffer))
				continue;
			
			RemoveFromArray(g_aNominations, j);
			i--;
		}
	}
	
	// If we still need more maps we should just add random maps to the nomination list.
	new iNumMapsNeeded = GetConVarInt(cvar_sm_mapvote_include) - GetArraySize(g_aNominations);
	if(iNumMapsNeeded > 0)
	{
		DBMaps_GetCurrentMapNameFormatted(szCurrentMap, sizeof(szCurrentMap));
		
		new Handle:aAllowedMaps = CreateArray(MAX_MAP_NAME_LENGTH);
		
		for(i=0; i<GetArraySize(g_aMaps); i++)
		{
			GetArrayArray(g_aMaps, i, eMap);
			
			if(eMap[Map_Disabled])
				continue;
			
			if(StrEqual(szCurrentMap, eMap[Map_NameFormatted]))
				continue;
			
			if(WasMapRecentlyPlayed(eMap[Map_NameFormatted]))
				continue;
			
			if(FindStringInArray(g_aNominations, eMap[Map_NameFormatted]) != -1)
				continue;
			
			if(!CanCategoryBePlayed(eMap[Map_CategoryID]))
				continue;
			
			if(GetMapsPlayerRequirementNeeds(eMap) != 0)
				continue;
			
			if(strncmp(eMap[Map_NameFormatted], "dr_", 3, false) == 0)
				continue;
			
			if(strncmp(eMap[Map_NameFormatted], "deathrun_", 8, false) == 0)
				continue;
				
			PushArrayString(aAllowedMaps, eMap[Map_NameFormatted]);
		}
		
		decl iNum;
		for(i=0; i<iNumMapsNeeded; i++)
		{
			iNum = GetArraySize(aAllowedMaps);
			if(!iNum)
				break;
			
			iNum = GetRandomInt(0, iNum-1);
			GetArrayString(aAllowedMaps, iNum, szBuffer, sizeof(szBuffer));
			PushArrayString(g_aNominations, szBuffer);
			
			RemoveFromArray(aAllowedMaps, iNum);
		}
		
		CloseHandle(aAllowedMaps);
	}
	
	if(!GetArraySize(g_aNominations))
	{
		CPrintToChatAll("{green}[{lightred}SM{green}] {red}There are no maps to select for the map vote.");
		return false;
	}
	
	decl String:szInfo[12];
	g_iNumVoteSelections = 0;
	g_iNumPlayersVoted = 0;
	
	// Create the menu.
	g_hMenu_MapVote = CreateMenu(MenuHandle_MapVote);
	SetMenuTitle(g_hMenu_MapVote, "Choose the nextmap");
	
	IntToString(g_iNumVoteSelections, szInfo, sizeof(szInfo));
	AddMenuItem(g_hMenu_MapVote, szInfo, "I don't care.");
	g_iVoteMapIndexes[g_iNumVoteSelections] = MAP_INDEX_DONT_CARE;
	g_iVoteMapTally[g_iNumVoteSelections] = 0;
	strcopy(g_szVoteMapNames[g_iNumVoteSelections], sizeof(g_szVoteMapNames[]), "Don't care.");
	g_iNumVoteSelections++;
	
	// Make sure this loop is run after setting the "Don't care" variables.
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		g_iClientsVoteIndex[iClient] = -1;
		g_bHasClientVotedFromMenu[iClient] = false;
		
		if(IsClientAllowedToVote(iClient))
			AddClientsVote(iClient, 0, false); // Set to "I don't care" by default.
	}
	
	i = 0;
	decl eCategory[Category], iLen;
	while(i < GetArraySize(g_aNominations) && i < GetConVarInt(cvar_sm_mapvote_include))
	{
		GetArrayString(g_aNominations, i, szBuffer, sizeof(szBuffer));
		i++;
		
		if(!GetTrieValue(g_aTrie_MapQuickIndex, szBuffer, iMapIndex))
			continue;
		
		GetArrayArray(g_aMaps, iMapIndex, eMap);
		
		if(g_iCategoryIDToIndex[eMap[Map_CategoryID]] == -1)
			continue;
		
		GetArrayArray(g_aCategories, g_iCategoryIDToIndex[eMap[Map_CategoryID]], eCategory);
		
		iLen = 0;
		if(!StrEqual(eCategory[Category_Tag], ""))
			iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "[%s] ", eCategory[Category_Tag]);
		
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, eMap[Map_NameFormatted]);
		
		IntToString(g_iNumVoteSelections, szInfo, sizeof(szInfo));
		AddMenuItem(g_hMenu_MapVote, szInfo, szBuffer);
		g_iVoteMapIndexes[g_iNumVoteSelections] = iMapIndex;
		g_iVoteMapTally[g_iNumVoteSelections] = 0;
		strcopy(g_szVoteMapNames[g_iNumVoteSelections], sizeof(g_szVoteMapNames[]), eMap[Map_NameFormatted]);
		g_iNumVoteSelections++;
	}
	
	while(i < 7)
	{
		AddMenuItem(g_hMenu_MapVote, "-99999", "", ITEMDRAW_SPACER);
		i++;
	}
	
	if(g_iNumTimesExtended < GetConVarInt(cvar_sm_mapvote_extend))
	{
		IntToString(g_iNumVoteSelections, szInfo, sizeof(szInfo));
		AddMenuItem(g_hMenu_MapVote, szInfo, "Extend current map.");
		g_iVoteMapIndexes[g_iNumVoteSelections] = MAP_INDEX_EXTEND;
		g_iVoteMapTally[g_iNumVoteSelections] = 0;
		strcopy(g_szVoteMapNames[g_iNumVoteSelections], sizeof(g_szVoteMapNames[]), "Extend map.");
		g_iNumVoteSelections++;
	}
	
	SetMenuExitBackButton(g_hMenu_MapVote, false);
	SetMenuPagination(g_hMenu_MapVote, MENU_NO_PAGINATION);
	SetMenuExitButton(g_hMenu_MapVote, false);
	
	/*
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!DisplayMenu(g_hMenu_MapVote, iClient, 0))
		{
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Error displaying vote menu for you.");
			continue;
		}
	}
	*/
	
	VoteMenuToAll(g_hMenu_MapVote, 0);
	
	return true;
}

bool:IsClientAllowedToVote(iClient)
{
	if(!IsClientInGame(iClient) || IsFakeClient(iClient))
		return false;
	
	new iTeam = GetClientTeam(iClient);
	if(iTeam < 1 || iTeam > 3)
		return false;
	
	return true;
}

MarkAsHasntVotedFromMenu(iClient)
{
	if(g_bHasClientVotedFromMenu[iClient])
	{
		g_iNumPlayersVoted--;
		g_bHasClientVotedFromMenu[iClient] = false;
	}
}

AddClientsVote(iClient, iVoteIndex, bool:bMarkAsVotedFromMenu=true)
{
	RemoveClientsVote(iClient);
	g_iClientsVoteIndex[iClient] = iVoteIndex;
	
	g_iVoteMapTally[iVoteIndex]++;
	
	if(bMarkAsVotedFromMenu)
	{
		g_iNumPlayersVoted++;
		g_bHasClientVotedFromMenu[iClient] = true;
	}
}

RemoveClientsVote(iClient)
{
	if(g_iClientsVoteIndex[iClient] == -1)
		return;
	
	g_iVoteMapTally[g_iClientsVoteIndex[iClient]]--;
	g_iClientsVoteIndex[iClient] = -1;
	
	MarkAsHasntVotedFromMenu(iClient);
}

public MenuHandle_MapVote(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		g_hMenu_MapVote = INVALID_HANDLE;
		
		// Force end the map voting since everyone voted and the menu force ended itself.
		if(g_hTimer_MapVote != INVALID_HANDLE)
		{
			StopTimer_MapVote(); // Call this before directly calling Timer_MapVote().
			
			g_iCountDownTimer = 0;
			Timer_MapVote(INVALID_HANDLE);
		}
		
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_iFrameCancel[iParam1] = g_iFrameNum;
		AddClientsVote(iParam1, 0);
		
		if(g_iFrameCancel[iParam1] == g_iFrameRevote[iParam1])
		{
			// sm_revote was first.
			// Since we know this cancel is coming from a revote we need to mark this client as hasn't voted from menu since we just added to "I don't care".
			MarkAsHasntVotedFromMenu(iParam1);
		}
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	AddClientsVote(iParam1, StringToInt(szInfo));
}

RemoveClientFromRockTheVoteArray(iClient)
{
	new iIndex = FindValueInArray(g_aRockTheVotePlayers, iClient);
	if(iIndex == -1)
		return;
	
	RemoveFromArray(g_aRockTheVotePlayers, iIndex);
}

public OnClientDisconnect_Post(iClient)
{
	RemoveClientFromRockTheVoteArray(iClient);
	RemoveClientsVote(iClient);
	RemoveClientsNomination(iClient, false);
}

public OnMapEnd()
{
	StopTimer_MapVote();
	StopTimer_EndOfMapVote();
	
	MapVoteEnd();
	ClearArray(g_aRockTheVotePlayers);
}

bool:CanCategoryBePlayed(iCategoryID)
{
	if(g_iCategoryIDToIndex[iCategoryID] == -1)
		return true;
	
	decl eCategory[Category];
	GetArrayArray(g_aCategories, g_iCategoryIDToIndex[iCategoryID], eCategory);
	
	if(eCategory[Category_PlayedMax] > 0)
	{
		decl iPlayedCount;
		switch(GetConVarBool(cvar_sm_mapvote_playedmax_type))
		{
			case false: iPlayedCount = g_iSameCategoryPlayedInRow;
			case true: iPlayedCount =  GetCategoriesPlayedCountForCycle(eCategory[Category_ID]);
			default: iPlayedCount = 0;
		}
		
		if(iPlayedCount >= eCategory[Category_PlayedMax])
			return false;
	}
	
	return true;
}

NominateMap(iClient, iMapIndex)
{
	if(g_bWasNextMapSelected)
	{
		DisplayNextMapText(iClient);
		return;
	}
	
	decl eMap[Map];
	GetArrayArray(g_aMaps, iMapIndex, eMap);
	
	if(eMap[Map_Disabled])
		return;
	
	decl String:szCurrentMap[MAX_MAP_NAME_LENGTH];
	DBMaps_GetCurrentMapNameFormatted(szCurrentMap, sizeof(szCurrentMap));
	
	if(StrEqual(szCurrentMap, eMap[Map_NameFormatted]))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%s {olive}is the current map.", eMap[Map_NameFormatted]);
		return;
	}
	
	if(WasMapRecentlyPlayed(eMap[Map_NameFormatted]))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%s {olive}was recently played.", eMap[Map_NameFormatted]);
		return;
	}
	
	if(IsMapNominated(iClient, eMap[Map_NameFormatted]))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}%s {olive}is already nominated by you.", eMap[Map_NameFormatted]);
		return;
	}
	
	if(!CanCategoryBePlayed(eMap[Map_CategoryID]))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}You must play a map from another category first.");
		return;
	}
	
	new iPlayersNeeded = GetMapsPlayerRequirementNeeds(eMap);
	if(iPlayersNeeded != 0)
	{
		if(iPlayersNeeded > 0)
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}There are not enough players in the server to play this map. Need a minimum of %i players in the server.", eMap[Map_PlayersMin]);
		else
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}There are too many players in the server to play this map. Need a maximum of %i players in the server.", eMap[Map_PlayersMax]);
		
		return;
	}
	
	RemoveClientsNomination(iClient, true);
	g_iClientNominationsIndex[iClient] = PushArrayString(g_aNominations, eMap[Map_NameFormatted]);
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You have nominated {lightred}%s{olive}.", eMap[Map_NameFormatted]);
}

RemoveClientsNomination(iClient, bool:bShowMessage)
{
	if(g_iClientNominationsIndex[iClient] == INVALID_NOMINATION_INDEX)
		return;
	
	decl String:szMap[MAX_MAP_NAME_LENGTH];
	GetArrayString(g_aNominations, g_iClientNominationsIndex[iClient], szMap, sizeof(szMap));
	RemoveFromArray(g_aNominations, g_iClientNominationsIndex[iClient]);
	g_iClientNominationsIndex[iClient] = INVALID_NOMINATION_INDEX;
	
	if(bShowMessage)
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Removed old nomination of {lightred}%s{olive}.", szMap);
}

DisplayMenu_NominateCategorySelect(iClient)
{
	CloseKZTimerMenu(iClient);
	
	/*
	if(g_bWasNextMapSelected)
	{
		DisplayNextMapText(iClient);
		return;
	}
	*/
	
	if(GetArraySize(g_aCategories) == 1)
	{
		DisplayMenu_NominateMapSelect(iClient, 0);
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_NominateCategorySelect);
	SetMenuTitle(hMenu, "Select Map Category");
	
	new iTotalMaps;
	decl eCategory[Category], String:szInfo[12], String:szBuffer[64], iNumMaps;
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		
		iNumMaps = GetArraySize(eCategory[Category_MapIndexes]);
		iTotalMaps += iNumMaps;
		
		if(!iNumMaps)
			continue;
		
		IntToString(i, szInfo, sizeof(szInfo));
		FormatEx(szBuffer, sizeof(szBuffer), "%s (%i map%s)", eCategory[Category_Name], iNumMaps, (iNumMaps == 1) ? "" : "s");
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	FormatEx(szBuffer, sizeof(szBuffer), "All maps (%i map%s)", iTotalMaps, (iTotalMaps == 1) ? "" : "s");
	AddMenuItem(hMenu, "-1", szBuffer);
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Could not display menu: nominate category select.");
		return;
	}
}

public MenuHandle_NominateCategorySelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iCategoryIndex = StringToInt(szInfo);
	
	if(iCategoryIndex == -1)
	{
		DisplayMenu_NominateMapSelectAll(iParam1);
		return;
	}
	
	DisplayMenu_NominateMapSelect(iParam1, iCategoryIndex);
}

DisplayMenu_NominateMapSelectAll(iClient, iStartIndex=0)
{
	CloseKZTimerMenu(iClient);
	
	new Handle:hMenu = CreateMenu(MenuHandle_NominateMapSelect);
	SetMenuTitle(hMenu, "All maps");
	
	decl String:szCurrentMap[MAX_MAP_NAME_LENGTH];
	DBMaps_GetCurrentMapNameFormatted(szCurrentMap, sizeof(szCurrentMap));
	
	decl eMap[Map], eCategory[Category], String:szInfo[12], String:szBuffer[256], iLen, bool:bDisabled;
	for(new i=0; i<GetArraySize(g_aMaps); i++)
	{
		GetArrayArray(g_aMaps, i, eMap);
		
		if(eMap[Map_Disabled])
			continue;
		
		iLen = 0;
		GetArrayArray(g_aCategories, g_iCategoryIDToIndex[eMap[Map_CategoryID]], eCategory);
		
		if(!StrEqual(eCategory[Category_Tag], ""))
			iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "[%s] ", eCategory[Category_Tag]);
		
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, eMap[Map_NameFormatted]);
		
		bDisabled = TryAppendMapsDisabledStatus(iClient, szCurrentMap, eMap[Map_NameFormatted], szBuffer, iLen, sizeof(szBuffer));
		
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer, bDisabled ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	if(GetArraySize(g_aCategories) != 1)
		SetMenuExitBackButton(hMenu, true);
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartIndex, 0))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Could not display menu: nominate map select all.");
		return;
	}
}

bool:TryAppendMapsDisabledStatus(iClient, const String:szCurrentMap[], const String:szMapName[], String:szBuffer[], &iLen, const iMaxLen)
{
	// Current map.
	if(StrEqual(szCurrentMap, szMapName))
	{
		iLen += FormatEx(szBuffer[iLen], iMaxLen-iLen, " *current map*");
		return true;
	}
	
	// Recently played.
	if(WasMapRecentlyPlayed(szMapName))
	{
		iLen += FormatEx(szBuffer[iLen], iMaxLen-iLen, " *recently played*");
		return true;
	}
	
	// Already nominated.
	if(IsMapNominated(iClient, szMapName))
	{
		iLen += FormatEx(szBuffer[iLen], iMaxLen-iLen, " *nominated*");
		return true;
	}
	
	return false;
}

DisplayMenu_NominateMapSelect(iClient, iCategoryIndex)
{
	CloseKZTimerMenu(iClient);
	
	decl eCategory[Category];
	GetArrayArray(g_aCategories, iCategoryIndex, eCategory);
	
	decl String:szBuffer[256];
	new iLen = FormatEx(szBuffer, sizeof(szBuffer), "%s ", eCategory[Category_Name]);
	
	if(!StrEqual(eCategory[Category_Tag], ""))
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "(%s)", eCategory[Category_Tag]);
	
	new bool:bCategoryDisabled;
	
	if(!CanCategoryBePlayed(eCategory[Category_ID]))
	{
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "\nYou must play maps from another category\nbefore you can play a map from this category again.");
		bCategoryDisabled = true;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_NominateMapSelect);
	SetMenuTitle(hMenu, szBuffer);
	
	decl String:szCurrentMap[MAX_MAP_NAME_LENGTH];
	DBMaps_GetCurrentMapNameFormatted(szCurrentMap, sizeof(szCurrentMap));
	
	new Handle:aNeedPlayersMapIndexes = CreateArray();
	
	decl eMap[Map], String:szInfo[12], iMapIndex, bool:bDisabled;
	for(new i=0; i<GetArraySize(eCategory[Category_MapIndexes]); i++)
	{
		iLen = 0;
		
		iMapIndex = GetArrayCell(eCategory[Category_MapIndexes], i);
		GetArrayArray(g_aMaps, iMapIndex, eMap);
		
		if(eMap[Map_Disabled])
			continue;
		
		//if(!StrEqual(eCategory[Category_Tag], ""))
		//	iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, "[%s] ", eCategory[Category_Tag]);
		
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, eMap[Map_NameFormatted]);
		
		bDisabled = TryAppendMapsDisabledStatus(iClient, szCurrentMap, eMap[Map_NameFormatted], szBuffer, iLen, sizeof(szBuffer));
		
		if(!bDisabled && GetMapsPlayerRequirementNeeds(eMap) != 0)
		{
			PushArrayCell(aNeedPlayersMapIndexes, iMapIndex);
			continue;
		}
		
		IntToString(iMapIndex, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer, (bCategoryDisabled || bDisabled) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	decl iPlayersNeeded;
	for(new i=0; i<GetArraySize(aNeedPlayersMapIndexes); i++)
	{
		iMapIndex = GetArrayCell(aNeedPlayersMapIndexes, i);
		GetArrayArray(g_aMaps, iMapIndex, eMap);
		
		iLen = 0;
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, eMap[Map_NameFormatted]);
		
		iPlayersNeeded = GetMapsPlayerRequirementNeeds(eMap);
		iLen += FormatEx(szBuffer[iLen], sizeof(szBuffer)-iLen, " *need %i players*", iPlayersNeeded);
		
		IntToString(iMapIndex, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer, ITEMDRAW_DISABLED);
	}
	
	CloseHandle(aNeedPlayersMapIndexes);
	
	if(GetArraySize(g_aCategories) != 1)
		SetMenuExitBackButton(hMenu, true);
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Could not display menu: nominate map select.");
		return;
	}
}

public MenuHandle_NominateMapSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
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
		
		DisplayMenu_NominateCategorySelect(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	NominateMap(iParam1, StringToInt(szInfo));
}

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
	g_bLibLoaded_ForceMapEnd = LibraryExists("force_map_end");
	g_bLibLoaded_AFKManager = LibraryExists("afk_manager");
	g_bLibLoaded_KZTimer = LibraryExists("KZTimer");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "force_map_end"))
	{
		g_bLibLoaded_ForceMapEnd = true;
	}
	else if(StrEqual(szName, "afk_manager"))
	{
		g_bLibLoaded_AFKManager = true;
	}
	else if(StrEqual(szName, "KZTimer"))
	{
		g_bLibLoaded_KZTimer = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "force_map_end"))
	{
		g_bLibLoaded_ForceMapEnd = false;
	}
	else if(StrEqual(szName, "afk_manager"))
	{
		g_bLibLoaded_AFKManager = false;
	}
	else if(StrEqual(szName, "KZTimer"))
	{
		g_bLibLoaded_KZTimer = false;
	}
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if(!Query_CreateTable_MapVoteCategories())
		return;
	
	if(!Query_CreateTable_MapVoteMaps())
		return;
	
	SelectCategories();
}

bool:Query_CreateTable_MapVoteCategories()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_mapvote_categories\
	(\
		cat_id		SMALLINT UNSIGNED	NOT NULL	AUTO_INCREMENT,\
		server_id	SMALLINT UNSIGNED	NOT NULL,\
		cat_name	VARCHAR( 64 )		NOT NULL,\
		cat_tag		VARCHAR( 8 )		NOT NULL,\
		played_min	TINYINT UNSIGNED	NOT NULL,\
		played_max	TINYINT UNSIGNED	NOT NULL,\
		PRIMARY KEY ( cat_id ),\
		INDEX ( server_id )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		SetFailState("Could not create table: plugin_mapvote_categories");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

bool:Query_CreateTable_MapVoteMaps()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS plugin_mapvote_maps\
	(\
		cat_id		SMALLINT UNSIGNED	NOT NULL,\
		map_name	VARCHAR( 64 )		NOT NULL,\
		players_min	TINYINT UNSIGNED	NOT NULL,\
		players_max	TINYINT UNSIGNED	NOT NULL,\
		map_time	FLOAT(11,6)			NOT NULL,\
		round_time	FLOAT(11,6)			NOT NULL,\
		PRIMARY KEY ( cat_id, map_name )\
	) ENGINE = INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		SetFailState("Could not create table: plugin_mapvote_maps");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

SelectCategories()
{
	DB_TQuery(g_szDatabaseConfigName, Query_GetCategories, DBPrio_Low, g_iUniqueMapCounter, "SELECT cat_id, cat_name, cat_tag, played_min, played_max FROM plugin_mapvote_categories WHERE server_id=%i OR server_id=%i ORDER BY cat_name ASC", DBServers_GetServerParentID(), DBServers_GetServerID());
}

public Query_GetCategories(Handle:hDatabase, Handle:hQuery, any:iMapCount)
{
	if(iMapCount != g_iUniqueMapCounter)
		return;
	
	if(hQuery == INVALID_HANDLE)
		return;
	
	decl eCategory[Category];
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		if(eCategory[Category_MapIndexes] != INVALID_HANDLE)
			CloseHandle(eCategory[Category_MapIndexes]);
	}
	
	ClearArray(g_aCategories);
	AddCategory(0, "Other", "", 0, 0);
	
	if(!SQL_GetRowCount(hQuery))
	{
		OnCategoriesLoaded();
		return;
	}
	
	decl String:szCatName[MAX_MAP_CAT_NAME_LENGTH], String:szCatTag[MAX_MAP_CAT_TAG_LENGTH];
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 1, szCatName, sizeof(szCatName));
		SQL_FetchString(hQuery, 2, szCatTag, sizeof(szCatTag));
		
		AddCategory(SQL_FetchInt(hQuery, 0), szCatName, szCatTag, SQL_FetchInt(hQuery, 3), SQL_FetchInt(hQuery, 4));
	}
	
	SwapArrayItems(g_aCategories, 0, GetArraySize(g_aCategories)-1); // Make sure "Other" is at the end.
	OnCategoriesLoaded();
}

bool:AddCategory(iCatID, const String:szCatName[], const String:szCatTag[], iPlayedMin, iPlayedMax)
{
	decl eCategory[Category];
	new iArraySize = GetArraySize(g_aCategories);
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		
		if(StrEqual(eCategory[Category_Name], szCatName))
			return false;
	}
	
	eCategory[Category_ID] = iCatID;
	strcopy(eCategory[Category_Name], MAX_MAP_CAT_NAME_LENGTH, szCatName);
	strcopy(eCategory[Category_Tag], MAX_MAP_CAT_TAG_LENGTH, szCatTag);
	eCategory[Category_PlayedMin] = iPlayedMin;
	eCategory[Category_PlayedMax] = iPlayedMax;
	eCategory[Category_MapIndexes] = CreateArray();
	
	g_iCategoryIDToIndex[iCatID] = PushArrayArray(g_aCategories, eCategory);
	
	return true;
}

FindFreeCategoryIndex()
{
	// Note: Other plugins should only be calling this function *after* we load the default categories.
	for(new i=0; i<sizeof(g_iCategoryIDToIndex); i++)
	{
		if(g_iCategoryIDToIndex[i] == -1)
			return i;
	}
	
	return -1;
}

OnCategoriesLoaded()
{
	Forward_OnCategoriesLoaded();
	SelectMaps();
}

Forward_OnCategoriesLoaded()
{
	decl Action:result;
	Call_StartForward(g_hFwd_OnCategoriesLoaded);
	Call_Finish(result);
}

SelectMaps()
{
	new iLen, iArraySize = GetArraySize(g_aCategories);
	decl String:szCategoryIDs[65535*6], eCategory[Category];
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		
		if(eCategory[Category_ID] == 0)
			continue;
		
		iLen += FormatEx(szCategoryIDs[iLen], sizeof(szCategoryIDs)-iLen, "%i,", eCategory[Category_ID]);
	}
	
	if(iLen)
	{
		// Remove the last comma.
		szCategoryIDs[iLen-1] = '\x0';
	}
	else
	{
		// So the query doesn't fail just set it to 0 so nothing will be selected regardless.
		iLen += FormatEx(szCategoryIDs[iLen], sizeof(szCategoryIDs)-iLen, "0");
	}
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetMaps, DBPrio_Low, g_iUniqueMapCounter, "SELECT cat_id, map_name, players_min, players_max, map_time, round_time FROM plugin_mapvote_maps WHERE cat_id IN (%s) ORDER BY map_name ASC", szCategoryIDs);
}

public Query_GetMaps(Handle:hDatabase, Handle:hQuery, any:iMapCount)
{
	if(iMapCount != g_iUniqueMapCounter)
		return;
	
	if(hQuery == INVALID_HANDLE)
	{
		OnMapsLoaded();
		return;
	}
	
	ClearArray(g_aMaps);
	ClearTrie(g_aTrie_MapQuickIndex);
	
	if(!SQL_GetRowCount(hQuery))
	{
		OnMapsLoaded();
		return;
	}
	
	decl String:szMapName[MAX_MAP_NAME_LENGTH];
	while(SQL_FetchRow(hQuery))
	{
		SQL_FetchString(hQuery, 1, szMapName, sizeof(szMapName));
		
		AddMap(SQL_FetchInt(hQuery, 0), szMapName, SQL_FetchInt(hQuery, 2), SQL_FetchInt(hQuery, 3), SQL_FetchFloat(hQuery, 4), SQL_FetchFloat(hQuery, 5));
	}
	
	SortMapsByName();
	OnMapsLoaded();
}

SortMapsByName()
{
	new iArraySize = GetArraySize(g_aMaps);
	decl String:szName[MAX_MAP_NAME_LENGTH], eMap[Map], j, iIndex;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aMaps, i, eMap);
		strcopy(szName, sizeof(szName), eMap[Map_NameFormatted]);
		iIndex = 0;
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aMaps, j, eMap);
			if(strcmp(szName, eMap[Map_NameFormatted], false) < 0)
				continue;
			
			iIndex = j;
			strcopy(szName, sizeof(szName), eMap[Map_NameFormatted]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aMaps, i, iIndex);
		
		// We must reset the name to index map too.
		GetArrayArray(g_aMaps, i, eMap);
		SetTrieValue(g_aTrie_MapQuickIndex, eMap[Map_NameFormatted], i, true);
		
		GetArrayArray(g_aMaps, iIndex, eMap);
		SetTrieValue(g_aTrie_MapQuickIndex, eMap[Map_NameFormatted], iIndex, true);
	}
}

AddMap(iCatID, const String:szMapName[], iPlayersMin, iPlayersMax, Float:fMapTime, Float:fRoundTime)
{
	decl String:szMapNameLower[MAX_MAP_NAME_LENGTH], String:szMapNameLowerFormatted[MAX_MAP_NAME_LENGTH];
	strcopy(szMapNameLower, sizeof(szMapNameLower), szMapName);
	StringToLower(szMapNameLower, strlen(szMapNameLower));
	
	strcopy(szMapNameLowerFormatted, sizeof(szMapNameLowerFormatted), szMapNameLower);
	DBMaps_GetMapNameFormatted(szMapNameLowerFormatted, sizeof(szMapNameLowerFormatted));
	
	// Make sure the map actually exists on the server before adding it.
	decl String:szMapPath[MAX_MAP_NAME_LENGTH+10];
	FormatEx(szMapPath, sizeof(szMapPath), "maps/%s.bsp", szMapNameLower);
	if(!FileExists(szMapPath, true))
		return;
	
	// If the map is already in another category we need to remove it before adding it again.
	decl eMap[Map], eCategory[Category], iMapIndex, iCatMapIndex;
	
	new iNumMaps = GetArraySize(g_aMaps);
	for(iMapIndex=0; iMapIndex<iNumMaps; iMapIndex++)
	{
		GetArrayArray(g_aMaps, iMapIndex, eMap);
		if(!StrEqual(szMapNameLowerFormatted, eMap[Map_NameFormatted]))
			continue;
		
		GetArrayArray(g_aCategories, g_iCategoryIDToIndex[eMap[Map_CategoryID]], eCategory);
		
		iCatMapIndex = FindValueInArray(eCategory[Category_MapIndexes], iMapIndex);
		if(iCatMapIndex != -1)
			RemoveFromArray(eCategory[Category_MapIndexes], iCatMapIndex);
		
		break;
	}
	
	strcopy(eMap[Map_Name], MAX_MAP_NAME_LENGTH, szMapNameLower);
	strcopy(eMap[Map_NameFormatted], MAX_MAP_NAME_LENGTH, szMapNameLowerFormatted);
	
	eMap[Map_PlayersMin] = iPlayersMin;
	eMap[Map_PlayersMax] = iPlayersMax;
	eMap[Map_CategoryID] = iCatID;
	
	eMap[Map_MapTime] = fMapTime;
	eMap[Map_RoundTime] = fRoundTime;
	
	eMap[Map_Disabled] = false;
	
	if(iMapIndex >= iNumMaps)
		iMapIndex = PushArrayArray(g_aMaps, eMap);
	else
		SetArrayArray(g_aMaps, iMapIndex, eMap);
	
	SetTrieValue(g_aTrie_MapQuickIndex, szMapNameLowerFormatted, iMapIndex, true);
}

StringToLower(String:szString[], iLength)
{
	for(new i=0; i<iLength; i++)
		szString[i] = CharToLower(szString[i]);
}

OnMapsLoaded()
{
	AddMapsToCorrectCategories();
	Forward_OnMapsLoaded();
	
	AddCurrentMapsCategoryToPlayedCount(); // Must be when maps are selected since we need to know the current maps category ID.
	SetCurrentMapsTimeConvars();
}

SetCurrentMapsTimeConvars()
{
	decl String:szMapName[MAX_MAP_NAME_LENGTH];
	DBMaps_GetCurrentMapNameFormatted(szMapName, sizeof(szMapName));
	
	decl iMapIndex;
	if(!GetTrieValue(g_aTrie_MapQuickIndex, szMapName, iMapIndex))
		return;
	
	decl eMap[Map];
	GetArrayArray(g_aMaps, iMapIndex, eMap);
	
	if(eMap[Map_MapTime] > 0.0)
	{
		SetConVarFloat(cvar_mp_timelimit, eMap[Map_MapTime]);
		ExtendMapTimeLimit(1); // Extend by a second so sourcemod knows the timelimit changed.
	}
	
	if(eMap[Map_RoundTime] > 0.0)
	{
		SetConVarInt(cvar_mp_roundtime_defuse, 0);
		SetConVarInt(cvar_mp_roundtime_hostage, 0);
		SetConVarInt(cvar_mp_roundtime_deployment, 0);
		
		SetConVarFloat(cvar_mp_roundtime, eMap[Map_RoundTime]);
	}
}

Forward_OnMapsLoaded()
{
	decl Action:result;
	Call_StartForward(g_hFwd_OnMapsLoaded);
	Call_Finish(result);
}

AddMapsToCorrectCategories()
{
	decl eMap[Map], eCategory[Category], j;
	new iCategoryArraySize = GetArraySize(g_aCategories);
	
	// First clear each categories map indexes.
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		if(eCategory[Category_MapIndexes] != INVALID_HANDLE)
			ClearArray(eCategory[Category_MapIndexes]);
	}
	
	// Now add maps to the correct categories.
	for(new i=0; i<GetArraySize(g_aMaps); i++)
	{
		GetArrayArray(g_aMaps, i, eMap);
		
		for(j=0; j<iCategoryArraySize; j++)
		{
			GetArrayArray(g_aCategories, j, eCategory);
			
			if(eMap[Map_CategoryID] != eCategory[Category_ID])
				continue;
			
			AddMapToCategory(i, j);
			break;
		}
		
		if(j >= iCategoryArraySize)
		{
			// Could not find the category for this map. Add it to "Other".
			AddMapToCategory(i, iCategoryArraySize-1);
		}
	}
	
	// Remove the categories that don't have any maps.
	RemoveUnusedCategories();
}

RemoveUnusedCategories()
{
	decl eCategory[Category];
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		
		if(eCategory[Category_MapIndexes] == INVALID_HANDLE || !GetArraySize(eCategory[Category_MapIndexes]))
		{
			RemoveFromArray(g_aCategories, i);
			g_iCategoryIDToIndex[eCategory[Category_ID]] = -1;
			i--;
		}
	}
	
	RebuildCategoryIDToIndexMap(); // Must rebuild since we possibly removed a category from the array.
	SortCategoriesByName(); // Must call this here too since it can also modify the fast index map.
}

RebuildCategoryIDToIndexMap()
{
	decl eCategory[Category];
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		g_iCategoryIDToIndex[eCategory[Category_ID]] = i;
	}
}

SortCategoriesByName()
{
	new iArraySize = GetArraySize(g_aCategories);
	decl String:szName[MAX_MAP_CAT_NAME_LENGTH], eCategory[Category], j, iIndex, iID, iID2;
	
	for(new i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		strcopy(szName, sizeof(szName), eCategory[Category_Name]);
		iIndex = 0;
		iID = eCategory[Category_ID];
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(g_aCategories, j, eCategory);
			if(strcmp(szName, eCategory[Category_Name], false) < 0)
				continue;
			
			iIndex = j;
			iID2 = eCategory[Category_ID];
			strcopy(szName, sizeof(szName), eCategory[Category_Name]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(g_aCategories, i, iIndex);
		
		// We must swap the IDtoIndex too.
		g_iCategoryIDToIndex[iID] = iIndex;
		g_iCategoryIDToIndex[iID2] = i;
	}
}

AddMapToCategory(iMapIndex, iCategoryIndex)
{
	decl eCategory[Category];
	GetArrayArray(g_aCategories, iCategoryIndex, eCategory);
	PushArrayCell(eCategory[Category_MapIndexes], iMapIndex);
}

bool:WasMapRecentlyPlayed(const String:szMapName[])
{
	if(FindStringInArray(g_aRecentlyPlayedMaps, szMapName) == -1)
		return false;
	
	return true;
}

BuildRecentlyPlayedArray()
{
	ClearArray(g_aRecentlyPlayedMaps);
	
	new iMapHistorySize = GetMapHistorySize();
	if(iMapHistorySize > GetConVarInt(cvar_sm_mapvote_exclude))
		iMapHistorySize = GetConVarInt(cvar_sm_mapvote_exclude);
	
	decl String:szMapName[MAX_MAP_NAME_LENGTH], String:szReason[1], iTime;
	for(new i=0; i<iMapHistorySize; i++)
	{
		GetMapHistory(i, szMapName, sizeof(szMapName), szReason, sizeof(szReason), iTime);
		StringToLower(szMapName, sizeof(szMapName));
		DBMaps_GetMapNameFormatted(szMapName, sizeof(szMapName));
		PushArrayString(g_aRecentlyPlayedMaps, szMapName);
	}
}

public OnMapStart()
{
	g_iUniqueMapCounter++;
	
	for(new i=0; i<sizeof(g_iCategoryIDToIndex); i++)
		g_iCategoryIDToIndex[i] = -1;
	
	PrecacheTimeToChoose();
	PrecacheCountdown();
	
	g_iNumTimesExtended = 0;
	g_bWasNextMapSelected = false;
	g_fLastMapVote = 0.0;
	g_iMapChangeTime = CHANGETIME_NOT_SET;
	ClearNominations();
}

PrecacheCountdown()
{
	for(new i=0; i<sizeof(SZ_SOUND_COUNTDOWN); i++)
	{
		AddFileToDownloadsTable(SZ_SOUND_COUNTDOWN[i]);
		PrecacheSoundAny(SZ_SOUND_COUNTDOWN[i][6]);
	}
}

PrecacheTimeToChoose()
{
	g_iTimeToChooseIndex++;
	if(g_iTimeToChooseIndex >= sizeof(SZ_SOUND_TIME_TO_CHOOSE))
		g_iTimeToChooseIndex = 0;
	
	AddFileToDownloadsTable(SZ_SOUND_TIME_TO_CHOOSE[g_iTimeToChooseIndex]);
	PrecacheSoundAny(SZ_SOUND_TIME_TO_CHOOSE[g_iTimeToChooseIndex][6]);
}

public OnConfigsExecuted()
{
	cvar_mp_timelimit = FindConVar("mp_timelimit");
	cvar_mp_endmatch_votenextleveltime = FindConVar("mp_endmatch_votenextleveltime");
	cvar_sm_vote_progress_hintbox = FindConVar("sm_vote_progress_hintbox");
	
	cvar_mp_roundtime = FindConVar("mp_roundtime");
	cvar_mp_roundtime_defuse = FindConVar("mp_roundtime_defuse");
	cvar_mp_roundtime_hostage = FindConVar("mp_roundtime_hostage");
	cvar_mp_roundtime_deployment = FindConVar("mp_roundtime_deployment");
	
	BuildRecentlyPlayedArray();
	SetupTimeleftTimer();
	
	RemoveNotifyFlag("sm_nextmap");
	RemoveNotifyFlag("mp_timelimit");
	RemoveNotifyFlag("sm_vote_progress_hintbox");
}

RemoveNotifyFlag(const String:szCvarName[])
{
	new Handle:hCvar = FindConVar(szCvarName);
	if(hCvar == INVALID_HANDLE)
		return;
	
	new iCvarFlags = GetConVarFlags(hCvar);
	iCvarFlags &= ~FCVAR_NOTIFY;
	SetConVarFlags(hCvar, iCvarFlags);
}

SetRandomNextmap()
{
	if(!GetArraySize(g_aMaps))
		return;
	
	decl String:szCurrentMap[MAX_MAP_NAME_LENGTH];
	DBMaps_GetCurrentMapNameFormatted(szCurrentMap, sizeof(szCurrentMap));
	
	decl eMap[Map];
	new Handle:aMapIndexes = CreateArray();
	for(new i=0; i<GetArraySize(g_aMaps); i++)
	{
		GetArrayArray(g_aMaps, i, eMap);
		
		if(eMap[Map_Disabled])
			continue;
		
		if(StrEqual(szCurrentMap, eMap[Map_NameFormatted]))
			continue;
		
		if(WasMapRecentlyPlayed(eMap[Map_NameFormatted]))
			continue;
		
		if(!CanCategoryBePlayed(eMap[Map_CategoryID]))
			continue;
		
		if(GetMapsPlayerRequirementNeeds(eMap) != 0)
			continue;
		
		PushArrayCell(aMapIndexes, i);
	}
	
	decl iIndex;
	if(!GetArraySize(aMapIndexes))
	{
		iIndex = GetRandomInt(0, GetArraySize(g_aMaps)-1);
	}
	else
	{
		iIndex = GetRandomInt(0, GetArraySize(aMapIndexes)-1);
		iIndex = GetArrayCell(aMapIndexes, iIndex);
	}
	
	GetArrayArray(g_aMaps, iIndex, eMap);
	CloseHandle(aMapIndexes);
	
	SetNextLevel(eMap[Map_Name]);
}

public Event_Intermission_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	// Make sure a next map is set if somehow one didn't get set yet.
	if(!g_bWasNextMapSelected)
		SetRandomNextmap();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
			DisplayNextMapText(iClient, true);
	}
	
	new Float:fIntermissionTotalTime = GetConVarFloat(cvar_mp_endmatch_votenextleveltime);
	
	// Clamp the minimum votenextleveltime to 11 since that's what it seems to be in CS:GO.
	if(fIntermissionTotalTime < 11.0)
		fIntermissionTotalTime = 11.0;
	
	fIntermissionTotalTime += 2.0; // Add the time it takes from intermission starting to the time the next map countdown begins.
	
	CreateTimer(fIntermissionTotalTime, Timer_EndMap, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_EndMap(Handle:hTimer)
{
	if(g_bWasNextMapSelected)
	{
		// TODO: Remove this clientcommand loop when csgo devs decide to actually fix their shit. Client's will crash a lot of times without it.
		{
			for(new iClient=1; iClient<=MaxClients; iClient++)
			{
				if(!IsClientInGame(iClient) || IsFakeClient(iClient))
					continue;
				
				ClientCommand(iClient, "retry");
			}
			
			RequestFrame(OnNextFrame_EndMap);
		}
		
		//ForceChangeLevel(g_szNextMapSelected, "End map");
	}
	
	return Plugin_Stop;
}

public OnNextFrame_EndMap(any:hPack)
{
	if(g_bWasNextMapSelected)
		ForceChangeLevel(g_szNextMapSelected, "End map");
}

GetCurrentMapsCategoryID()
{
	decl String:szMapName[MAX_MAP_NAME_LENGTH];
	DBMaps_GetCurrentMapNameFormatted(szMapName, sizeof(szMapName));
	
	decl iMapIndex;
	if(!GetTrieValue(g_aTrie_MapQuickIndex, szMapName, iMapIndex))
		return -1;
	
	decl eMap[Map];
	GetArrayArray(g_aMaps, iMapIndex, eMap);
	
	return eMap[Map_CategoryID];
}

AddCurrentMapsCategoryToPlayedCount()
{
	new iCurrentCatID = GetCurrentMapsCategoryID();
	if(iCurrentCatID == -1)
		return;
	
	// Increment this categories played count.
	decl String:szKey[16];
	IntToString(iCurrentCatID, szKey, sizeof(szKey));
	
	new iTimesPlayed;
	GetTrieValue(g_aTrie_CategoryPlayedCount, szKey, iTimesPlayed);
	
	iTimesPlayed++;
	SetTrieValue(g_aTrie_CategoryPlayedCount, szKey, iTimesPlayed, true);
	
	// Try to clear the categories played count if needed.
	if(TryClearCategoryPlayedCount(iCurrentCatID))
	{
		// Since the categories were cleared we need to set this categories played count to 1.
		SetTrieValue(g_aTrie_CategoryPlayedCount, szKey, 1, true);
	}
	
	g_iLastPlayedCategoryID = iCurrentCatID;
}

bool:TryClearCategoryPlayedCount(iCurrentCatID)
{
	if(iCurrentCatID == g_iLastPlayedCategoryID)
		g_iSameCategoryPlayedInRow++;
	else
		g_iSameCategoryPlayedInRow = 1;
	
	decl eCategory[Category];
	for(new i=0; i<GetArraySize(g_aCategories); i++)
	{
		GetArrayArray(g_aCategories, i, eCategory);
		
		if(eCategory[Category_PlayedMin] > 0)
		{
			if(GetCategoriesPlayedCountForCycle(eCategory[Category_ID]) < eCategory[Category_PlayedMin])
				return false;
		}
	}
	
	ClearTrie(g_aTrie_CategoryPlayedCount);
	return true;
}

GetCategoriesPlayedCountForCycle(iCategoryID)
{
	decl String:szKey[16];
	IntToString(iCategoryID, szKey, sizeof(szKey));
	
	new iTimesPlayed;
	GetTrieValue(g_aTrie_CategoryPlayedCount, szKey, iTimesPlayed);
	
	return iTimesPlayed;
}

FindMatchingMapName(const String:szMapName[MAX_MAP_NAME_LENGTH])
{
	new iDisplayIndex = 0; // The index at which the map will appear in the menu
	decl eMap[Map];
	for (new i=0; i<GetArraySize(g_aMaps); i++)
	{
		GetArrayArray(g_aMaps, i, eMap);
		if(eMap[Map_Disabled])
			continue;
		
		if(StrContains(eMap[Map_NameFormatted], szMapName, false) != -1)
		{
			decl iMapIndex;
			if(GetTrieValue(g_aTrie_MapQuickIndex, eMap[Map_NameFormatted], iMapIndex))
				return iDisplayIndex;
			
			return -1;
		}
		
		iDisplayIndex++;
	}
	
	return -1;
}
