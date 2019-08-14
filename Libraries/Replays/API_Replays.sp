#include "replays"
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Replays";
new const String:PLUGIN_VERSION[] = "1.1";

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

new Handle:g_hFwd_OnTick;
new Handle:g_hFwd_OnTickLoad_Pre;

enum _:Frame
{
	Float:Frame_Velocity[3],
	Float:Frame_Angles[3],
	Float:Frame_Origin[3],
	MoveType:Frame_MoveType
};

public OnPluginStart()
{
	g_hFwd_OnTick = CreateGlobalForward("Replays_OnTick", ET_Ignore, Param_Cell, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_Array);
	g_hFwd_OnTickLoad_Pre = CreateGlobalForward("Replays_OnLoadTick_Pre", ET_Ignore, Param_Cell, Param_Cell);
}

public OnClientConnected(iClient)
{
	g_aReplay[iClient] = CreateArray(Frame);
	g_iMode[iClient] = REPLAY_RECORD;
	g_iBreakpoint[iClient] = 0;
	g_iTick[iClient] = -1;
}

public OnClientDisconnect(iClient)
{
	CloseHandle(g_aReplay[iClient]);
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if (!IsPlayerAlive(iClient))
		return Plugin_Continue;

	new Handle:aReplay = g_aReplay[iClient];
	new iFrames = GetArraySize(aReplay);

	if (g_iMode[iClient] == REPLAY_RECORD)
	{
		g_iTick[iClient]++;

		decl Action:result;
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
		Call_Finish(result);


		if (iFrames > g_iTick[iClient])
			ResizeArray(aReplay, g_iTick[iClient]);

		decl eFrame[Frame];

		decl Float:fPos[3], Float:fAng[3], Float:fVel[3];
		GetClientAbsOrigin(iClient, fPos);
		GetClientEyeAngles(iClient, fAng);
		GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVel);

		eFrame[Frame_Velocity][0] = fVel[0];
		eFrame[Frame_Velocity][1] = fVel[1];
		eFrame[Frame_Velocity][2] = fVel[2];

		eFrame[Frame_Origin][0] = fPos[0];
		eFrame[Frame_Origin][1] = fPos[1];
		eFrame[Frame_Origin][2] = fPos[2];

		eFrame[Frame_Angles][0] = fAng[0];
		eFrame[Frame_Angles][1] = fAng[1];
		eFrame[Frame_Angles][2] = fAng[2];

		eFrame[Frame_MoveType] = GetEntityMoveType(iClient);

		PushArrayArray(g_aReplay[iClient], eFrame);
		return result;
	}
	decl eFrame[Frame];
	if (g_iMode[iClient] == REPLAY_REWIND)
	{
		if (g_iTick[iClient] == g_iBreakpoint[iClient])
			g_iMode[iClient] = REPLAY_FREEZE;
		else
			g_iTick[iClient]--;
	}
	GetArrayArray(g_aReplay[iClient], g_iTick[iClient], eFrame);

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

	Call_StartForward(g_hFwd_OnTickLoad_Pre);
	Call_PushCell(iClient);
	Call_PushCell(g_iTick[iClient]);
	Call_Finish();

	SetEntityMoveType(iClient, eFrame[Frame_MoveType]);

	TeleportEntity(iClient, fLoadOrigin, fLoadAngles, fLoadVelocity);

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
