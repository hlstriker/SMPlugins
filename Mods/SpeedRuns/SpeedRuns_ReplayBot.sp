#include <sdktools>
#include "../../Libraries/DatabaseCore/database_core"
#include "../../Libraries/DatabaseMaps/database_maps"
#include "../../Libraries/Replays/replays"
#include "Includes/speed_runs"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Replay Bot";
new const String:PLUGIN_VERSION[] = "0.0.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "The speed run replay bot plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

public OnAllPluginsLoaded()
{
	cvar_database_servers_configname = FindConVar("sm_database_servers_configname");
}

public DB_OnStartConnectionSetup()
{
	if(cvar_database_servers_configname != INVALID_HANDLE)
		GetConVarString(cvar_database_servers_configname, g_szDatabaseConfigName, sizeof(g_szDatabaseConfigName));
}

new g_iBot = 0;

public OnPluginStart()
{
	CreateConVar("speed_runs_replay_bot_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	/* HookEvent("player_connect", Event_PlayerConnect_Pre, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerConnect_Pre, EventHookMode_Pre); */
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_Post);
}

new String:g_szForcedCvars[][][] =
{
	{ "bot_stop", "1" },
	{ "bot_zombie", "1" },
	{ "bot_quota_mode", "normal" },
	{ "mp_limitteams", "0" },
	{ "bot_join_after_player", "0" },
	{ "bot_chatter", "off" },
	
	{ "bot_controllable", "0" },
	{ "bot_flipout", "1" },
	{ "mp_autoteambalance", "0" }
};

public OnConfigsExecuted()
{
	for(new i = 0; i < sizeof(g_szForcedCvars); i++)
	{
		new Handle:hCvar = FindConVar(g_szForcedCvars[i][0]);

		if(hCvar == INVALID_HANDLE)
			continue;
		
		SetConVarString(hCvar, g_szForcedCvars[i][1]);
	}
	
	new Handle:hBotQuota = FindConVar("bot_quota");
	SetConVarInt(hBotQuota, 1);
	
	HookConVarChange(hBotQuota, OnBotQuotaChanged);
	
	
	// Create the bot on a timer to prevent it from spawning in invalid spots.
	/* CreateTimer(1.0, Timer_CreateBot, _, TIMER_FLAG_NO_MAPCHANGE); */
}

public OnBotQuotaChanged(Handle:hConvar, String:szOldValue[], String:szNewValue[])
{
	SetConVarInt(hConvar, 1);
}

public OnTeamBalanceChanged(Handle:hConvar, String:szOldValue[], String:szNewValue[])
{
	SetConVarInt(hConvar, 0);
}

public Action:Timer_CreateBot(Handle:hTimer)
{
	/* ServerCommand("bot_add");
	PrintToServer(">>>>>>>>>>> adding a bot"); */
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("speed_runs_replay_bot");
	
	CreateNative("SpeedRunsReplayBot_PlayRecord", _SpeedRunsReplayBot_PlayRecord);
	CreateNative("SpeedRunsReplayBot_IsClientReplayBot", _SpeedRunsReplayBot_IsClientReplayBot);
	
	return APLRes_Success;
}

public _SpeedRunsReplayBot_PlayRecord(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRunsReplayBot_PlayRecord");
		return -1;
	}
	
	return PlayRecord(GetNativeCell(1));
}

public _SpeedRunsReplayBot_IsClientReplayBot(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters SpeedRunsReplayBot_IsClientReplayBot");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	
	if (!(1 <= iClient <= MaxClients))
		return false;
		
	/* PrintToServer("%i %i", iClient, g_iBot); */
		
	return iClient == g_iBot;
}

PlayRecord(iRecordID)
{
	if (!g_iBot)
	{
		PrintToServer("the bot is not loaded yet");
		return 0;
	}
	
	SetClientInfo(g_iBot, "name", "Loading Replay...");
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetRecord, DBPrio_Low, _, "\
	SELECT \
	r1.replay_id, \
	r1.map_id, \
	r1.style_bits, \
	(SELECT u.user_name FROM gs_username_stats u \
			 WHERE u.user_id = r1.user_id \
			 ORDER BY u.last_utime DESC \
			 LIMIT 1) as name \
\
	FROM plugin_sr_records r1 \
\
	WHERE \
	record_id = %i",
		 iRecordID);
		 
	PrintToServer("trying to play record from id %i", iRecordID);
		 
	return g_iBot;
}

public Query_GetRecord(Handle:hDatabase, Handle:hQuery, any:data)
{
	PrintToServer("query came back");
	if (!g_iBot)
	{
		PrintToServer("no bot");
		return;
	}
		
	
	if(hQuery == INVALID_HANDLE)
	{
		PrintToServer("bad query");
		return;
	}

	if (!SQL_FetchRow(hQuery))
	{
		SetClientInfo(g_iBot, "name", "Error Loading Replay");
		return;
	}
	
	new iMapID = SQL_FetchInt(hQuery, 1);
	if (iMapID != DBMaps_GetMapID())
	{
		PrintToServer("bad mapid");
		return;
	}
	
	new iReplayID = SQL_FetchInt(hQuery, 0);
	if (!iReplayID)
	{
			SetClientInfo(g_iBot, "name", "No replay found");
			return;
	}
		
	decl String:szRecordHolderName[255];
	SQL_FetchString(hQuery, 3, szRecordHolderName, sizeof(szRecordHolderName));
	SetClientInfo(g_iBot, "name", szRecordHolderName);
	
	Replays_LoadReplayToClient(g_iBot, iReplayID);
}

public OnClientPutInServer(iClient)
{
	if (!IsFakeClient(iClient))
		return;
	
	if (g_iBot == 0)
		g_iBot = iClient;
}

public OnClientDisconnect_Post(iClient)
{
	if (iClient == g_iBot)
		g_iBot = 0;
}

public Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if (g_iBot)
		return;
	
	/* PrintToServer("round started");
	ServerCommand("bot_add"); */
}
