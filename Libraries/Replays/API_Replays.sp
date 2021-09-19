#include "replays"
#include "../DatabaseCore/database_core"
#include <sdktools_functions>
#include <sdktools_trace>
#include <sdkhooks>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Replays";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Replays API.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aReplay[MAXPLAYERS + 1];
new ReplayMode:g_iMode[MAXPLAYERS + 1];
new g_iTick[MAXPLAYERS + 1];
new g_iBreakpoint[MAXPLAYERS + 1];

new Float:g_fMoveVelocity[MAXPLAYERS + 1][3];

/* new Handle:g_hFwd_OnTick; */
new Handle:g_hFwd_OnTickLoad_Pre;

enum _:Frame
{
	Float:Frame_Velocity[3],
	Float:Frame_Angles[3],
	Float:Frame_Origin[3],
	Frame_Buttons,
	Frame_Flags,
	MoveType:Frame_MoveType,
	Float:Frame_Duck,
};

#define BETA_FORMAT "beta1"

public OnPluginStart()
{
	/* g_hFwd_OnTick = CreateGlobalForward("Replays_OnTick", ET_Ignore, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_Array); */
	g_hFwd_OnTickLoad_Pre = CreateGlobalForward("Replays_OnLoadTick_Pre", ET_Ignore, Param_Cell, Param_Cell);
}

public OnClientConnected(iClient)
{
	g_aReplay[iClient] = CreateArray(Frame);
	g_iMode[iClient] = REPLAY_RECORD;
	g_iBreakpoint[iClient] = -1;
	g_iTick[iClient] = -1;
}

public OnClientDisconnect(iClient)
{
	CloseHandle(g_aReplay[iClient]);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPre);
	SDKHook(iClient, SDKHook_VPhysicsUpdatePost, phys);
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public phys(iClient)
{
	PrintToServer("phys %i", iClient);
}

public OnPreThinkPre(iClient)
{
	/* PrintToServer("PreThinkPost %i %i", iClient, GetGameTickCount()); */
	/* if (g_iMode[iClient] != REPLAY_PLAYBACK)
		return;
	
	new Handle:aReplay = g_aReplay[iClient];
	new iFrames = GetArraySize(aReplay);
	
	if (!(0 <= g_iTick[iClient] < iFrames))
		return;
		
	decl Float:fVel[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVel);
	SubtractVectors(g_fMoveVelocity[iClient], fVel, fVel);
	PrintToServer("pre think vel diff %f %f %f", fVel[0], fVel[1], fVel[2]);
	
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, g_fMoveVelocity[iClient]); */
}

public OnPostThinkPost(iClient)
{
	/* PrintToServer("PostThinkPost %i %i", iClient, GetGameTickCount()); */
	if (g_iMode[iClient] != REPLAY_PLAYBACK)
		return;
	
	new Handle:aReplay = g_aReplay[iClient];
	new iFrames = GetArraySize(aReplay);
	
	if (!(0 <= g_iTick[iClient] < iFrames))
		return;
		
	decl eFrame[Frame];
	GetArrayArray(aReplay, g_iTick[iClient], eFrame);
	
	decl Float:fPos[3], Float:fLoadPos[3];
	fLoadPos[0] = eFrame[Frame_Origin][0];
	fLoadPos[1] = eFrame[Frame_Origin][1];
	fLoadPos[2] = eFrame[Frame_Origin][2];
	GetClientAbsOrigin(iClient, fPos);
	SubtractVectors(fLoadPos, fPos, fPos);
	new Float:fError = GetVectorLength(fPos);
	
	if (fError < 5.0) // The playback velocity put the client in basically the right place
		return;
	
	// Correct the position
	TeleportEntity(iClient, fLoadPos, NULL_VECTOR, NULL_VECTOR);
	PrintToServer("client teleported. corrected");
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	if (!(1 <= iVictim <= MaxClients))
		return Plugin_Continue;
	
	if(g_iMode[iVictim] == REPLAY_RECORD)
		return Plugin_Continue;
	
	fDamage = 0.0;
	return Plugin_Changed;
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	/* PrintToServer("RunCmd %i %i", iClient, GetGameTickCount()); */
	if (!IsPlayerAlive(iClient))
		return Plugin_Continue;

	new Handle:aReplay = g_aReplay[iClient];
	
	if (GetArraySize(aReplay) == 0)
	{
		// TODO: Should we really auto forward the client to the record as default?
		// Or instead have a special mode for invalid state
		g_iMode[iClient] = REPLAY_RECORD;
		return Plugin_Continue;
	}
	

	if (g_iMode[iClient] == REPLAY_RECORD)
	{
		return Plugin_Continue;
	}
	else if (g_iMode[iClient] == REPLAY_REWIND)
	{
		if (g_iTick[iClient] > 0)
			g_iTick[iClient]--;
		else
			g_iMode[iClient] = REPLAY_FREEZE;
	}
	else if (g_iMode[iClient] == REPLAY_PLAYBACK)
	{
		if (g_iTick[iClient] < GetArraySize(g_aReplay[iClient])-1)
			g_iTick[iClient]++;
		else // We're at the end of the playback
			g_iMode[iClient] = REPLAY_FREEZE;
	}
	
	if (g_iTick[iClient] >= 0 && g_iTick[iClient] == g_iBreakpoint[iClient])
	{
		g_iMode[iClient] = REPLAY_FREEZE;
	}
	
	decl eFrame[Frame];
	GetArrayArray(aReplay, g_iTick[iClient], eFrame);

	decl Float:fLoadOrigin[3], Float:fLoadAngles[3], Float:fLoadVelocity[3];

	fLoadOrigin[0] = eFrame[Frame_Origin][0];
	fLoadOrigin[1] = eFrame[Frame_Origin][1];
	fLoadOrigin[2] = eFrame[Frame_Origin][2];

	fLoadAngles[0] = eFrame[Frame_Angles][0];
	fLoadAngles[1] = eFrame[Frame_Angles][1];
	fLoadAngles[2] = eFrame[Frame_Angles][2];

	fLoadVelocity[0] = eFrame[Frame_Velocity][0];
	fLoadVelocity[1] = eFrame[Frame_Velocity][1];
	fLoadVelocity[2] = eFrame[Frame_Velocity][2];
	g_fMoveVelocity[iClient][0] = fLoadVelocity[0];
	g_fMoveVelocity[iClient][1] = fLoadVelocity[1];
	g_fMoveVelocity[iClient][2] = fLoadVelocity[2];

	Call_StartForward(g_hFwd_OnTickLoad_Pre);
	Call_PushCell(iClient);
	Call_PushCell(g_iTick[iClient]);
	Call_Finish();
	
	fAngles[0] = fLoadAngles[0];
	fAngles[1] = fLoadAngles[1];
	fAngles[2] = fLoadAngles[2];

	/* SetEntityMoveType(iClient, MOVETYPE_NOCLIP); */
	SetEntityMoveType(iClient, eFrame[Frame_MoveType]);

	if (g_iTick[iClient] == 0)
	{
		TeleportEntity(iClient, fLoadOrigin, fLoadAngles, fLoadVelocity);
	}
	else
	{
		decl Float:fPos[3], Float:fVel[3];
		GetClientAbsOrigin(iClient, fPos);
		
		decl Float:fMins[3], Float:fMaxs[3];
		GetEntPropVector(iClient, Prop_Data, "m_vecMins", fMins);
		GetEntPropVector(iClient, Prop_Data, "m_vecMaxs", fMaxs);
		
		// Give a little margin as we don't care if the player is sliding against something
		AddVectors(fMins, Float:{1.0, 1.0, 1.0}, fMins);
		AddVectors(fMaxs, Float:{-1.0, -1.0, -1.0}, fMaxs);
		
		// Test if there is anything blocking the path from where the client is now
		// to where we want them to go this tick
		TR_TraceHullFilter(fPos, fLoadOrigin, fMins, fMaxs, MASK_PLAYERSOLID, TraceFilter_DontHitPlayers);
		if (TR_DidHit())
		{
			// Teleport the client directly to the right place
			TeleportEntity(iClient, fLoadOrigin, fLoadAngles, Float:{0.0, 0.0, 0.0});
			PrintToServer("THERE IS SOMETHING BLOCKING WHERE THE PLAYBACK IS GOING");
		}
		else
		{
			// Make a velocity to send the client to where they should go
			MakeVectorFromPoints(fPos, fLoadOrigin, fVel);
			ScaleVector(fVel, 1.0/GetTickInterval());
			TeleportEntity(iClient, NULL_VECTOR, fLoadAngles, fVel);
		}
		
		/* PrintToServer("%f %f %f  --- %f %f %f", fMins[0], fMins[1], fMins[2], fMaxs[0], fMaxs[1], fMaxs[2]); */
		
	}
	
	
	iButtons = eFrame[Frame_Buttons] & (IN_DUCK | IN_ATTACK | IN_ATTACK2);

	return Plugin_Changed;
}

public Action:OnPlayerRunCmdPost(iClient, iButtons, iImpulse, const Float:fVelocity[3], const Float:fAngles[3], iWeapon, iSubType, iCmdNum, iTickCount, iSeed, const iMouse[2])
{
	/* PrintToServer("RunCmdPost %i %i", iClient, GetGameTickCount()); */
	if (g_iMode[iClient] != REPLAY_RECORD)
	{
		return Plugin_Continue;
	}
	
	if (!IsFakeClient(iClient))
	{
		/* new Float:f1 = GetEntPropFloat(iClient, Prop_Data, "m_flDuckSpeed");
		new Float:f2 = GetEntPropFloat(iClient, Prop_Data, "m_flDuckAmount");
		PrintToServer("duckspeed: %f, speed:%f", f1, f2); */
		/* PrintToServer("%08X", -1); */
	}
	
	new Handle:aReplay = g_aReplay[iClient];
	new iFrames = GetArraySize(aReplay);
	
	g_iTick[iClient]++;

	/* decl Action:result;
	Call_StartForward(g_hFwd_OnTick);
	Call_PushCell(iClient);
	Call_PushCellRef(iButtons);
	Call_PushCellRef(iImpulse);
	Call_PushArrayEx(fVelocity, sizeof(fVelocity), SM_PARAM_COPYBACK);
	Call_PushArrayEx(fAngles, sizeof(fAngles), SM_PARAM_COPYBACK);
	Call_PushCellRef(iWeapon);
	Call_PushCellRef(iSubType);
	Call_PushCellRef(iCmdNum);
	Call_PushCellRef(iTickCount);
	Call_PushCellRef(iSeed);
	Call_PushArray(iMouse, sizeof(iMouse));
	Call_Finish(result); */


	if (iFrames > g_iTick[iClient])
		ResizeArray(aReplay, g_iTick[iClient]);

	decl eFrame[Frame];

	decl Float:fPos[3], Float:fAng[3], Float:fVel[3];
	GetClientAbsOrigin(iClient, fPos);
	GetClientEyeAngles(iClient, fAng);
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVel);
	
	/* if (g_iTick[iClient]-1 >= 0) // can we look back a tick?
	{
			decl ePrevFrame[Frame];
			GetArrayArray(aReplay, g_iTick[iClient]-1, ePrevFrame);
			decl Float:fScaledVel[3];
			fScaledVel[0] = fVel[0]; fScaledVel[1] = fVel[1]; fScaledVel[2] = fVel[2];
			ScaleVector(fScaledVel, GetTickInterval());
			decl Float:fPrevPos[3];
			fPrevPos[0] = ePrevFrame[Frame_Origin][0]; fPrevPos[1] = ePrevFrame[Frame_Origin][1]; fPrevPos[2] = ePrevFrame[Frame_Origin][2];
			AddVectors(fPrevPos, fScaledVel, fPrevPos);
			SubtractVectors(fPrevPos, fPos, fPrevPos);
			new Float:fDiff = GetVectorLength(fPrevPos);
			if (fDiff > 1.0)
				PrintToServer("pos diff %f", fDiff);
			PrintToServer("pos diff %f %f %f", fPrevPos[0], fPrevPos[1], fPrevPos[2]);
	} */

	eFrame[Frame_Velocity][0] = fVel[0];
	eFrame[Frame_Velocity][1] = fVel[1];
	eFrame[Frame_Velocity][2] = fVel[2];

	eFrame[Frame_Origin][0] = fPos[0];
	eFrame[Frame_Origin][1] = fPos[1];
	eFrame[Frame_Origin][2] = fPos[2];

	/* eFrame[Frame_Angles][0] = fAng[0];
	eFrame[Frame_Angles][1] = fAng[1];
	eFrame[Frame_Angles][2] = fAng[2]; */
	eFrame[Frame_Angles][0] = fAngles[0];
	eFrame[Frame_Angles][1] = fAngles[1];
	eFrame[Frame_Angles][2] = fAngles[2];

	eFrame[Frame_Buttons] = iButtons;

	eFrame[Frame_MoveType] = GetEntityMoveType(iClient);
	
	/* PrintToServer("mt %i", eFrame[Frame_MoveType]); */

	PushArrayArray(g_aReplay[iClient], eFrame);
	return Plugin_Continue;
}
	


public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("replays");
	CreateNative("Replays_GetTick", _Replays_GetTick);
	CreateNative("Replays_GetMode", _Replays_GetMode);
	CreateNative("Replays_SetMode", _Replays_SetMode);
	CreateNative("Replays_SetBreakpoint", _Replays_SetBreakpoint);

	CreateNative("Replays_GetAverageSpeed", _Replays_GetAverageSpeed);
	
	CreateNative("Replays_SaveReplay", _Replays_SaveReplay);
	CreateNative("Replays_LoadReplayToClient", _Replays_LoadReplayToClient);

	return APLRes_Success;
}

public _Replays_GetTick(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);

	return g_iTick[iClient];
}

public _Replays_GetMode(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);

	return _:g_iMode[iClient];
}

public _Replays_SetMode(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new ReplayMode:iMode = GetNativeCell(2);

	g_iMode[iClient] = iMode;
}

public _Replays_SetBreakpoint(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new iTick = GetNativeCell(2);

	if(iTick == -1)
		iTick = g_iTick[iClient];

	g_iBreakpoint[iClient] = iTick;
}

public _Replays_GetAverageSpeed(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	new iTick = GetNativeCell(2);
	new iEndTick = GetNativeCell(3);
	new bool:bExcludeVertical = GetNativeCell(4);

	new Float:fTotalSpeed = 0.0;
	decl eFrame[Frame];
	new i = 0;

	for (; iTick < iEndTick; iTick++)
	{
		i++;
		GetArrayArray(g_aReplay[iClient], iTick, eFrame);
		new Float:fSpeed = eFrame[Frame_Velocity][0]*eFrame[Frame_Velocity][0] + eFrame[Frame_Velocity][1]*eFrame[Frame_Velocity][1];
		if (!bExcludeVertical)
			fSpeed += eFrame[Frame_Velocity][2]*eFrame[Frame_Velocity][2];
		fTotalSpeed += SquareRoot(fSpeed);
	}
	return _:(fTotalSpeed / float(i));
}

public _Replays_SaveReplay(Handle:hPlugin, iNumParams)
{
	if (iNumParams != 4)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	return SaveReplay(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4));
}

public _Replays_LoadReplayToClient(Handle:hPlugin, iNumParams)
{
	if (iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	LoadReplayToClient(GetNativeCell(1), GetNativeCell(2));
}
 
// --SQL--
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

public DBServers_OnServerIDReady(iServerID, iGameID)
{
	if (!Query_CreateReplaysTable())
		return;
}

bool:Query_CreateReplaysTable()
{
	static bool:bTableCreated = false;
	if(bTableCreated)
		return true;

	new Handle:hQuery = DB_Query(g_szDatabaseConfigName, "\n\
	CREATE TABLE IF NOT EXISTS plugin_replays \n\
	(\n\
		replay_id         INT UNSIGNED          NOT NULL   AUTO_INCREMENT,\n\
		replay_format     VARCHAR(255)          NOT NULL,\n\
		tickrate          FLOAT(11,6)           NOT NULL,\n\
		utime_created     INT                   NOT NULL,\n\
		utime_deleted     INT                   NOT NULL,\n\
		replay_data       LONGBLOB              NOT NULL,\n\
		PRIMARY KEY ( replay_id )\n\
	) ENGINE = INNODB");

	if(hQuery == INVALID_HANDLE)
	{
		LogError("There was an error creating the plugin_replays sql table.");
		return false;
	}

	DB_CloseQueryHandle(hQuery);
	bTableCreated = true;

	return true;
}

#define LARGE_BUFFER_SIZE 16777216
// 134217728 = 2^27, or 128 megabytes.
// If a replay uses 28 bytes per tick (x + y + z + pitch + yaw + buttons + movetype) * 32bit
// this uses approximately 1 megabyte every 5 minutes of replay.
// Hex encoding will use double the size of the raw data as each byte is encoded
// to a hex pair of 2 bytes.
new String:g_szLargeBuffer[LARGE_BUFFER_SIZE];


bool:SaveReplay(iClient, iStartTick, iEndTick, Handle:hTransaction)
{
	if (g_aReplay[iClient] == INVALID_HANDLE)
		return false;
		
	if (hTransaction == INVALID_HANDLE)
	{
		LogError("Invalid Transaction");
		return false;
	}
		
	if (iEndTick < iStartTick)
	{
		LogError("End Tick < Start Tick");
		return false;
	}
	
	new Handle:aReplay = g_aReplay[iClient];
	new iFrames = GetArraySize(aReplay);
	
	if ((iStartTick < 0) || (iEndTick >= iFrames))
	{
		LogError("Save replay start and end ticks out of bounds: start=%i end=%i total_frames=%i", iStartTick, iEndTick, iFrames);
		return false;
	}
	
	new iLen = FormatEx(g_szLargeBuffer, sizeof(g_szLargeBuffer),
		"INSERT INTO plugin_replays (replay_format, replay_data) VALUES ('%s', UNHEX('",
		BETA_FORMAT
	);
	
	decl eFrame[Frame];
	for (new i = iStartTick; i < iEndTick; i++)
	{
		GetArrayArray(aReplay, i, eFrame);
		iLen += EncodeFrameHex_Beta(eFrame, g_szLargeBuffer[iLen], sizeof(g_szLargeBuffer)-iLen);
	}
	
	if (FormatEx(g_szLargeBuffer[iLen], sizeof(g_szLargeBuffer)-iLen, "'))") < 3)
	{
		LogError("Encoded replay too long to fit in buffer of size %i", LARGE_BUFFER_SIZE);
		return false;
	}
	
	SQL_AddQuery(hTransaction, g_szLargeBuffer);
	return true;
}

LoadReplayToClient(iClient, iReplayID)
{
	if (!IsClientInGame(iClient))
		return;
		
	if (!iReplayID)
	{
		LogError("Tried to load replay of id 0");
		return;
	}
	
	DB_TQuery(g_szDatabaseConfigName, Query_GetReplay, DBPrio_High, GetClientSerial(iClient),
	"SELECT replay_format, HEX(replay_data) FROM plugin_replays WHERE replay_id = %i", iReplayID);
}

public Query_GetReplay(Handle:hDatabase, Handle:hQuery, any:iClientSerial)
{
	// TODO: this should check if the map has changed since the query was sent
	if (hQuery == INVALID_HANDLE)
	{
		PrintToServer("get replay query failed");
		return;
	}

	if (!SQL_FetchRow(hQuery))
		return;
	
	new iClient = GetClientFromSerial(iClientSerial);
	if(!iClient)
		return;
		
	decl String:szReplayFormat[255];
	SQL_FetchString(hQuery, 0, szReplayFormat, sizeof(szReplayFormat));
	
	SQL_FetchString(hQuery, 1, g_szLargeBuffer, sizeof(g_szLargeBuffer));
	
	PrintToServer("replay encoded length is this: %i", strlen(g_szLargeBuffer));
	
	if (!StrEqual(szReplayFormat, BETA_FORMAT, true))
	{
		LogError("Tried to load replay with invalid format: '%s'", szReplayFormat);
		return;
	}
	
	new Handle:aReplay = g_aReplay[iClient];
	
	ResizeArray(aReplay, 0);
	
	new iOffset = 0;
	decl iAdd;
	decl eFrame[Frame];
	
	for (;;)
	{
			iAdd = DecodeFrameHex_Beta(eFrame, g_szLargeBuffer[iOffset]);
			if (!iAdd)
				break;

			iOffset += iAdd;
			PushArrayArray(aReplay, eFrame);
	}
	
	new iFrames = GetArraySize(aReplay);
	
	if (!iFrames)
	{
		// TODO: What to do when the fetched replay has 0 frames? We already cleared the client replay array
		g_iTick[iClient] = -1;
	}
	else
	{
		g_iTick[iClient] = -1;
		g_iMode[iClient] = REPLAY_PLAYBACK;
	}
	
}

// Encode/Decode

EncodeFrameHex_Beta(eFrame[Frame], String:szBuffer[], iBufferLen)
{
	return FormatEx(szBuffer, iBufferLen,
		"%08X%08X%08X%08X%08X%08X%08X%08X%08X%08X%08X",
		_:eFrame[Frame_Origin][0],
		_:eFrame[Frame_Origin][1],
		_:eFrame[Frame_Origin][2],
		_:eFrame[Frame_Angles][0],
		_:eFrame[Frame_Angles][1],
		_:eFrame[Frame_Velocity][0],
		_:eFrame[Frame_Velocity][1],
		_:eFrame[Frame_Velocity][2],
		eFrame[Frame_Buttons],
		eFrame[Frame_MoveType],
		eFrame[Frame_Flags]
		);
}

// 10*4*2
#define FRAME_SIZE_BETA 80
DecodeFrameHex_Beta(eFrame[Frame], String:szBuffer[])
{
	for (new i = 0; i < FRAME_SIZE_BETA; i++)
	{
		if (szBuffer[i] == '\0')
		{
			if (i != 0)
				LogError("Incomplete frame in replay of format "...BETA_FORMAT);
			return 0;
		}
	}
	
	new iField = 0;
	// 32 bit cells, 4 bytes, 8 hex chars + null terminator.
	decl String:szHexCell[9];
	
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Origin][0] = Float:StringToInt(szHexCell, 16);
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Origin][1] = Float:StringToInt(szHexCell, 16);
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Origin][2] = Float:StringToInt(szHexCell, 16);
	
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Angles][0] = Float:StringToInt(szHexCell, 16);
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Angles][1] = Float:StringToInt(szHexCell, 16);
	
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Velocity][0] = Float:StringToInt(szHexCell, 16);
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Velocity][1] = Float:StringToInt(szHexCell, 16);
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Velocity][2] = Float:StringToInt(szHexCell, 16);
	
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Buttons] = StringToInt(szHexCell, 16);
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_MoveType] = MoveType:StringToInt(szHexCell, 16);
	
	strcopy(szHexCell, sizeof(szHexCell), szBuffer[8*iField++]);
	eFrame[Frame_Flags] = StringToInt(szHexCell, 16);
	
	// Should be same as FRAME_SIZE_BETA
	return iField*8;
}
