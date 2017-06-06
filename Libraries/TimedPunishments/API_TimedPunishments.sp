#include <sourcemod>
#include "../DatabaseCore/database_core"
#include "../DatabaseUsers/database_users"
#include "../DatabaseUserSessions/database_user_sessions"
#include "../DatabaseMapSessions/database_map_sessions"
#include "../DemoSessions/demo_sessions"
#include "../WebPageViewer/web_page_viewer"
#include "timed_punishments"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Timed Punishments";
new const String:PLUGIN_VERSION[] = "2.10";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to handle timed punishments.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_database_servers_configname;
new String:g_szDatabaseConfigName[64];

new Handle:g_aTimedPunishments;
enum _:TimedPunishment
{
	PUNISHMENT_CLIENT,
	TimedPunishmentType:PUNISHMENT_TYPE,
	bool:PUNISHMENT_IS_PERM,
	Float:PUNISHMENT_LOAD_TIME,
	Float:PUNISHMENT_EXPIRES,
	String:PUNISHMENT_REASON[MAX_REASON_LENGTH]
};

new g_iClientPunishmentMap[MAXPLAYERS+1][NUM_TP_TYPES];

new Handle:g_hFwd_OnAllPunishmentsLoaded;
new Handle:g_hFwd_OnPunishmentLoaded;
new Handle:g_hFwd_OnPunishmentExpired;


public OnPluginStart()
{
	CreateConVar("api_timed_punishments_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aTimedPunishments = CreateArray(TimedPunishment);
	g_hFwd_OnAllPunishmentsLoaded = CreateGlobalForward("TimedPunishment_OnAllPunishmentsLoaded", ET_Ignore, Param_Cell);
	g_hFwd_OnPunishmentLoaded = CreateGlobalForward("TimedPunishment_OnPunishmentLoaded", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_hFwd_OnPunishmentExpired = CreateGlobalForward("TimedPunishment_OnPunishmentExpired", ET_Ignore, Param_Cell, Param_Cell);
	
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_check_tp", Command_CheckTimedPunishment, ADMFLAG_BAN, "sm_check_tp <#steamid|#userid|name> - Loads the players timed punishment page.");
}

public Action:Command_CheckTimedPunishment(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_check_tp <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	new iUserID = DBUsers_GetUserID(iTarget);
	if(iUserID < 1)
	{
		ReplyToCommand(iClient, "[SM] Please wait until this client is fully loaded from the database.");
		return Plugin_Handled;
	}
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Loading timed punishments page...");
	
	static String:szURL[255];
	FormatEx(szURL, sizeof(szURL), "http://swoobles.com/1-timed-punishments-database/%i-null", iUserID);
	WebPageViewer_OpenPage(iClient, szURL);
	
	return Plugin_Handled;
}

public OnMapStart()
{
	ClearArray(g_aTimedPunishments);
	CreateTimer(5.0, Timer_CheckExpiredPunishments, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_CheckExpiredPunishments(Handle:hTimer)
{
	new Float:fCurTime = GetGameTime();
	
	decl ePunishment[TimedPunishment];
	for(new i=0; i<GetArraySize(g_aTimedPunishments); i++)
	{
		GetArrayArray(g_aTimedPunishments, i, ePunishment);
		
		if(ePunishment[PUNISHMENT_IS_PERM])
			continue;
		
		if(ePunishment[PUNISHMENT_EXPIRES] > fCurTime)
			continue;
		
		Call_StartForward(g_hFwd_OnPunishmentExpired);
		Call_PushCell(ePunishment[PUNISHMENT_CLIENT]);
		Call_PushCell(ePunishment[PUNISHMENT_TYPE]);
		Call_Finish();
		
		RemovePunishment(ePunishment[PUNISHMENT_CLIENT], ePunishment[PUNISHMENT_TYPE]);
		i--;
	}
}

RemovePunishment(iClient, TimedPunishmentType:punishment_type)
{
	if(g_iClientPunishmentMap[iClient][punishment_type] == -1)
		return;
	
	new iIndexRemoved = g_iClientPunishmentMap[iClient][punishment_type];
	RemoveFromArray(g_aTimedPunishments, g_iClientPunishmentMap[iClient][punishment_type]);
	g_iClientPunishmentMap[iClient][punishment_type] = -1;
	
	// Decrease all array map indexes by 1 that are greater than the index we just removed.
	decl i;
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		for(i=0; i<sizeof(g_iClientPunishmentMap[]); i++)
		{
			if(g_iClientPunishmentMap[iPlayer][i] == -1)
				continue;
			
			if(g_iClientPunishmentMap[iPlayer][i] <= iIndexRemoved)
				continue;
			
			g_iClientPunishmentMap[iPlayer][i]--;
		}
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("timed_punishments");
	
	CreateNative("TimedPunishment_AddPunishment", _TimedPunishment_AddPunishment);
	CreateNative("TimedPunishment_RemovePunishment", _TimedPunishment_RemovePunishment);
	CreateNative("TimedPunishment_GetSecondsLeft", _TimedPunishment_GetSecondsLeft);
	CreateNative("TimedPunishment_GetReason", _TimedPunishment_GetReason);
	
	return APLRes_Success;
}

public _TimedPunishment_GetReason(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 4)
		return false;
	
	new iClient = GetNativeCell(1);
	new TimedPunishmentType:iPunishmentType = GetNativeCell(2);
	
	if(g_iClientPunishmentMap[iClient][iPunishmentType] == -1)
		return false;
	
	decl ePunishment[TimedPunishment];
	GetArrayArray(g_aTimedPunishments, g_iClientPunishmentMap[iClient][iPunishmentType], ePunishment);
	
	SetNativeString(3, ePunishment[PUNISHMENT_REASON], GetNativeCell(4));
	return true;
}

public _TimedPunishment_GetSecondsLeft(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
		return -1;
	
	new iClient = GetNativeCell(1);
	new TimedPunishmentType:iPunishmentType = GetNativeCell(2);
	
	if(g_iClientPunishmentMap[iClient][iPunishmentType] == -1)
		return -1;
	
	decl ePunishment[TimedPunishment];
	GetArrayArray(g_aTimedPunishments, g_iClientPunishmentMap[iClient][iPunishmentType], ePunishment);
	
	if(ePunishment[PUNISHMENT_IS_PERM])
		return 0;
	
	new iSecondsLeft = RoundFloat(ePunishment[PUNISHMENT_EXPIRES] - GetGameTime());
	if(iSecondsLeft < 1)
		return -1;
	
	return iSecondsLeft;
}

public _TimedPunishment_RemovePunishment(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
		return false;
	
	new iAdmin = GetNativeCell(1);
	new iAdminUserID = DBUsers_GetUserID(iAdmin);
	new TimedPunishmentType:iPunishmentType = GetNativeCell(3);
	
	decl String:szAuthID[33];
	GetNativeString(2, szAuthID, sizeof(szAuthID));
	if(szAuthID[0] == '#')
		Format(szAuthID, sizeof(szAuthID), "%s", szAuthID[1]);
	
	decl String:szSafeAuthID[33], iClient;
	for(iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!GetClientAuthString(iClient, szSafeAuthID, sizeof(szSafeAuthID)))
			continue;
		
		if(StrEqual(szAuthID[8], szSafeAuthID[8]))
			break;
	}
	
	if(strlen(szAuthID) > 9)
		strcopy(szSafeAuthID, sizeof(szSafeAuthID), szAuthID[8]);
	else
		strcopy(szSafeAuthID, sizeof(szSafeAuthID), szAuthID);
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szSafeAuthID, szSafeAuthID, sizeof(szSafeAuthID)))
		return false;
	
	/*
	* // TODO: Should probably implement adding/removing punishments by IP at some point.
	if(is_lifting_by_ip)
	{
		// Lift by IP.
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
			UPDATE gs_user_timed_punishment SET tp_lifted=1, tp_lifted_user_id=%i, tp_utime_lifted=UNIX_TIMESTAMP() \
			WHERE user_ip='%s' AND tp_type=%i AND tp_lifted=0 AND (tp_is_perm=1 OR UNIX_TIMESTAMP() < utime_expires)", iAdminUserID, szSafeIP, iPunishmentType);
	}
	else
	*/
	{
		// Lift by steam id.
		DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
			UPDATE gs_user_timed_punishment SET tp_lifted=1, tp_lifted_user_id=%i, tp_utime_lifted=UNIX_TIMESTAMP() \
			WHERE steam_id='%s' AND tp_type=%i AND tp_lifted=0 AND (tp_is_perm=1 OR UNIX_TIMESTAMP() < utime_expires)", iAdminUserID, szSafeAuthID, iPunishmentType);
	}
	
	// Remove punishment if client was found in the server.
	if(iClient <= MaxClients)
		RemovePunishment(iClient, iPunishmentType);
	
	return true;
}

public _TimedPunishment_AddPunishment(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 6)
		return false;
	
	new iAdmin = GetNativeCell(1);
	
	new iClient = GetNativeCell(2);
	new iClientUserID = DBUsers_GetUserID(iClient);
	
	new TimedPunishmentType:iPunishmentType = GetNativeCell(3);
	new iPunishmentTime = GetNativeCell(4);
	
	decl String:szAuthID[33], String:szUserName[MAX_NAME_LENGTH+1], String:szIP[16];
	if(!iClientUserID)
	{
		GetNativeString(6, szAuthID, sizeof(szAuthID));
		StripQuotes(szAuthID);
		TrimString(szAuthID);
		
		if(szAuthID[0] == '#')
			Format(szAuthID, sizeof(szAuthID), "%s", szAuthID[1]);
		
		if(strlen(szAuthID) < 11)
			return false;
		
		if(StrContains(szAuthID, "STEAM_", false) == -1)
			return false;
		
		strcopy(szAuthID, sizeof(szAuthID), szAuthID[8]);
		szUserName[0] = '\x0';
		szIP[0] = '\x0';
	}
	else
	{
		DBUsers_GetFormattedAuthID(iClient, szAuthID, sizeof(szAuthID));
		GetClientName(iClient, szUserName, sizeof(szUserName));
		GetClientIP(iClient, szIP, sizeof(szIP));
	}
	
	decl String:szReason[MAX_REASON_LENGTH+1];
	GetNativeString(5, szReason, sizeof(szReason));
	StripQuotes(szReason);
	TrimString(szReason);
	
	AddPunishmentToDatabase(iClientUserID, _:iPunishmentType, iAdmin, iPunishmentTime, szAuthID, szIP, szReason, szUserName);
	
	if(iClientUserID)
	{
		new Float:fCurTime = GetGameTime();
		AddPunishment(iClient, iPunishmentType, fCurTime, fCurTime + float(iPunishmentTime), bool:(iPunishmentTime ? false : true), szReason);
	}
	
	return true;
}

AddPunishmentToDatabase(iClientUserID, iPunishmentType, iAdminClient, iPunishmentTime, const String:szAuthID[], const String:szIP[], const String:szReason[], const String:szUserName[])
{
	decl String:szSafeAuthID[33], String:szSafeIP[31], String:szSafeReason[511], String:szSafeUserName[MAX_NAME_LENGTH*2+1];
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szAuthID, szSafeAuthID, sizeof(szSafeAuthID)))
		return;
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szIP, szSafeIP, sizeof(szSafeIP)))
		return;
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szReason, szSafeReason, sizeof(szSafeReason)))
		return;
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szUserName, szSafeUserName, sizeof(szSafeUserName)))
		return;
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		INSERT INTO gs_user_timed_punishment\
		(tp_type, map_sess_id, admin_id, user_id, steam_id, user_ip, user_name, utime_start, utime_expires, demo_sess_id, demo_tick, reason, tp_is_perm)\
		VALUES (%i, %i, %i, %i, '%s', '%s', '%s', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + %i, %i, %i, '%s', %i)",
		iPunishmentType, DBMapSessions_GetSessionID(), DBUsers_GetUserID(iAdminClient), iClientUserID, szSafeAuthID, szSafeIP, szSafeUserName, iPunishmentTime, DemoSessions_GetID(), DemoSessions_GetCurrentTick(), szSafeReason, (iPunishmentTime ? 0 : 1));
	
	// Make sure we turn off any whitelists for this SteamID.
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		UPDATE IGNORE gs_user_timed_punishment \
		SET tp_is_whitelisted=0 \
		WHERE steam_id='%s' AND tp_lifted=0 AND (tp_is_perm=1 OR UNIX_TIMESTAMP() < utime_expires) AND tp_type=%i",
		szSafeAuthID, iPunishmentType);
}

AutoAddPunishmentToDatabase(iClient, iPunishmentType, iPunishmentExpires, bool:bIsPunishmentPerm, const String:szAuthID[], const String:szIP[], const String:szReason[], iOriginalPunishmentID)
{
	decl String:szSafeAuthID[33], String:szSafeIP[31], String:szSafeReason[511], String:szSafeUserName[MAX_NAME_LENGTH*2+1];
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szAuthID, szSafeAuthID, sizeof(szSafeAuthID)))
		return;
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szIP, szSafeIP, sizeof(szSafeIP)))
		return;
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szReason, szSafeReason, sizeof(szSafeReason)))
		return;
	
	GetClientName(iClient, szSafeUserName, sizeof(szSafeUserName));
	if(!DB_EscapeString(g_szDatabaseConfigName, szSafeUserName, szSafeUserName, sizeof(szSafeUserName)))
		return;
	
	DB_TQuery(g_szDatabaseConfigName, _, DBPrio_Low, _, "\
		INSERT INTO gs_user_timed_punishment \
		(tp_type, tp_original_id, user_id, steam_id, user_ip, utime_start, utime_expires, reason, tp_is_perm, user_name) \
		VALUES (%i, %i, %i, '%s', '%s', UNIX_TIMESTAMP(), %i, '%s', %i, '%s')",
		iPunishmentType, iOriginalPunishmentID, DBUsers_GetUserID(iClient), szSafeAuthID, szSafeIP, iPunishmentExpires, szSafeReason, bIsPunishmentPerm, szSafeUserName);
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
	Query_CreateUserTimedPunishmentTable();
}

bool:Query_CreateUserTimedPunishmentTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;
	
	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\
	CREATE TABLE IF NOT EXISTS gs_user_timed_punishment\
	(\
		tp_id				INT UNSIGNED		NOT NULL	AUTO_INCREMENT,\
		tp_original_id		INT UNSIGNED		NOT NULL,\
		tp_type				TINYINT UNSIGNED	NOT NULL,\
		map_sess_id			INT UNSIGNED		NOT NULL,\
		admin_id			INT UNSIGNED		NOT NULL,\
		user_id				INT UNSIGNED		NOT NULL,\
		steam_id			VARCHAR( 16 )		NOT NULL,\
		user_ip				VARCHAR( 15 )		NOT NULL,\
		user_name			VARCHAR( 32 )		NOT NULL,\
		utime_start			INT					NOT NULL,\
		utime_expires		INT					NOT NULL,\
		demo_sess_id		INT UNSIGNED		NOT NULL,\
		demo_tick			INT UNSIGNED		NOT NULL,\
		reason				VARCHAR( 255 )		NOT NULL,\
		tp_is_perm			BIT( 1 )			NOT NULL,\
		tp_lifted			BIT( 1 )			NOT NULL,\
		tp_lifted_user_id	INT UNSIGNED		NOT NULL,\
		tp_utime_lifted		INT					NOT NULL,\
		tp_is_whitelisted	BIT( 1 )			NOT NULL,\
		PRIMARY KEY ( tp_id ),\
		INDEX ( steam_id, user_ip, tp_lifted, tp_is_perm, utime_expires ),\
		INDEX ( user_ip, tp_type, tp_lifted, tp_is_perm, utime_expires ),\
		INDEX ( steam_id, tp_type, tp_lifted, tp_is_perm, utime_expires ),\
		INDEX ( tp_type, utime_start )\
	)\
	CHARACTER SET utf8 COLLATE utf8_unicode_ci ENGINE INNODB");
	
	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the gs_user_timed_punishment sql table.");
		return false;
	}
	
	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;
	
	return true;
}

public OnClientConnected(iClient)
{
	for(new i=0; i<sizeof(g_iClientPunishmentMap[]); i++)
		g_iClientPunishmentMap[iClient][i] = -1;
}

public OnClientDisconnect(iClient)
{
	for(new i=0; i<sizeof(g_iClientPunishmentMap[]); i++)
	{
		if(g_iClientPunishmentMap[iClient][i] == -1)
			continue;
		
		RemovePunishment(iClient, TimedPunishmentType:i);
	}
}

public DBUsers_OnUserIDReady(iClient, iUserID)
{
	decl String:szSafeAuthID[33], String:szSafeIP[31];
	DBUsers_GetFormattedAuthID(iClient, szSafeAuthID, sizeof(szSafeAuthID));
	GetClientIP(iClient, szSafeIP, sizeof(szSafeIP));
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szSafeAuthID, szSafeAuthID, sizeof(szSafeAuthID)))
		return;
	
	if(!DB_EscapeString(g_szDatabaseConfigName, szSafeIP, szSafeIP, sizeof(szSafeIP)))
		return;
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetPunishments, DBPrio_Low, GetClientSerial(iClient), "\
		SELECT tp_type, UNIX_TIMESTAMP() as cur_time, utime_expires, CAST(tp_is_perm AS SIGNED), reason, steam_id, user_ip, tp_original_id, tp_id, CAST(tp_is_whitelisted AS SIGNED) \
		FROM gs_user_timed_punishment \
		WHERE ((steam_id='%s' OR user_ip='%s') AND tp_lifted=0 AND (tp_is_perm=1 OR UNIX_TIMESTAMP() < utime_expires)) OR (steam_id='%s' AND tp_is_whitelisted=1) \
		ORDER BY tp_is_perm DESC, utime_expires DESC, tp_id ASC",
		szSafeAuthID, szSafeIP, szSafeAuthID);
}

public Query_GetPunishments(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	if(hQuery == INVALID_HANDLE)
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
	
	if(!SQL_GetRowCount(hQuery))
	{
		Forward_OnAllPunishmentsLoaded(iClient);
		return;
	}
	
	// First check to see if we need to punish this ID/IP combination.
	decl String:szAuthID[33], String:szIP[16], String:szAuthIDPunished[17], String:szIPPunished[16];
	GetClientAuthString(iClient, szAuthID, sizeof(szAuthID));
	GetClientIP(iClient, szIP, sizeof(szIP));
	
	decl iType;
	new bool:bAlreadyPunished[NUM_TP_TYPES];
	new bool:bIsWhitelisted[NUM_TP_TYPES];
	while(SQL_FetchRow(hQuery))
	{
		iType = SQL_FetchInt(hQuery, 0);
		if(iType < 0 || iType >= _:NUM_TP_TYPES)
			continue;
		
		if(SQL_FetchInt(hQuery, 9))
			bIsWhitelisted[iType] = true;
		
		if(bAlreadyPunished[iType])
			continue;
		
		SQL_FetchString(hQuery, 5, szAuthIDPunished, sizeof(szAuthIDPunished));
		SQL_FetchString(hQuery, 6, szIPPunished, sizeof(szIPPunished));
		
		if(StrEqual(szAuthID[8], szAuthIDPunished) && StrEqual(szIP, szIPPunished))
			bAlreadyPunished[iType] = true;
	}
	
	SQL_Rewind(hQuery);
	
	new Float:fCurTime = GetGameTime();
	new bool:bAlreadyCheckedType[NUM_TP_TYPES];
	decl String:szReason[256], iPunishmentExpires, iCurUnixTime, Float:fPunishmentExpires, bool:bIsPunishmentPerm, iOriginalPunishmentID;
	while(SQL_FetchRow(hQuery))
	{
		iType = SQL_FetchInt(hQuery, 0);
		if(iType < 0 || iType >= _:NUM_TP_TYPES)
			continue;
		
		// Continue if this type is whitelisted.
		if(bIsWhitelisted[iType])
			continue;
		
		if(bAlreadyCheckedType[iType])
			continue;
		
		bAlreadyCheckedType[iType] = true;
		
		SQL_FetchString(hQuery, 4, szReason, sizeof(szReason));
		
		iPunishmentExpires = SQL_FetchInt(hQuery, 2);
		bIsPunishmentPerm = SQL_FetchInt(hQuery, 3) ? true : false;
		
		if(!bAlreadyPunished[iType])
		{
			iOriginalPunishmentID = SQL_FetchInt(hQuery, 7);
			if(!iOriginalPunishmentID)
				iOriginalPunishmentID = SQL_FetchInt(hQuery, 8);
			
			AutoAddPunishmentToDatabase(iClient, iType, iPunishmentExpires, bIsPunishmentPerm, szAuthID[8], szIP, szReason, iOriginalPunishmentID);
		}
		
		// Go ahead and add the punishment.
		iCurUnixTime = SQL_FetchInt(hQuery, 1);
		fPunishmentExpires = fCurTime + float(iPunishmentExpires - iCurUnixTime);
		AddPunishment(iClient, TimedPunishmentType:iType, fCurTime, fPunishmentExpires, bIsPunishmentPerm, szReason);
		
		Call_StartForward(g_hFwd_OnPunishmentLoaded);
		Call_PushCell(iClient);
		Call_PushCell(iType);
		Call_PushCell(bIsPunishmentPerm);
		Call_PushCell(iCurUnixTime);
		Call_PushCell(iPunishmentExpires);
		Call_PushString(szReason);
		Call_Finish();
	}
	
	Forward_OnAllPunishmentsLoaded(iClient);
}

Forward_OnAllPunishmentsLoaded(iClient)
{
	Call_StartForward(g_hFwd_OnAllPunishmentsLoaded);
	Call_PushCell(iClient);
	Call_Finish();
}

AddPunishment(iClient, TimedPunishmentType:punishment_type, Float:fCurTime, Float:fPunishmentExpires, bool:bIsPerm, String:szReason[])
{
	// Return if the old punishment is longer and remove the old punishment if it's shorter.
	decl ePunishment[TimedPunishment];
	if(g_iClientPunishmentMap[iClient][punishment_type] != -1)
	{
		GetArrayArray(g_aTimedPunishments, g_iClientPunishmentMap[iClient][punishment_type], ePunishment);
		if(ePunishment[PUNISHMENT_IS_PERM])
			return;
		
		if(ePunishment[PUNISHMENT_EXPIRES] >= fPunishmentExpires && !bIsPerm)
			return;
		
		RemovePunishment(iClient, punishment_type);
	}
	
	ePunishment[PUNISHMENT_CLIENT] = iClient;
	ePunishment[PUNISHMENT_TYPE] = punishment_type;
	ePunishment[PUNISHMENT_LOAD_TIME] = fCurTime;
	ePunishment[PUNISHMENT_EXPIRES] = fPunishmentExpires;
	ePunishment[PUNISHMENT_IS_PERM] = bIsPerm;
	strcopy(ePunishment[PUNISHMENT_REASON], MAX_REASON_LENGTH, szReason);
	
	g_iClientPunishmentMap[iClient][punishment_type] = PushArrayArray(g_aTimedPunishments, ePunishment);
}