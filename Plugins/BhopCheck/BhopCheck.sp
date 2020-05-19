#include <sourcemod>
#include <hls_color_chat>
#include <sourcetvmanager>

#include "../../Libraries/ClientCookies/client_cookies"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Bhop Check";
new const String:PLUGIN_VERSION[] = "2.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "HymnsForDisco",
	description = "Bhop Check Plugin",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:cvar_warn_inputs;
new Handle:cvar_warn_perfs;
new Handle:cvar_warn_cooldown;
new Handle:cvar_bhops_max;
new Handle:cvar_allow_perf_sounds;

new const String:szPerfSound[] = "physics/wood/wood_solid_impact_hard1.wav";

new g_iBhopsMax;
new Float:g_fMinWarnCooldown;
new Float:g_fWarnPerfs;
new Float:g_fWarnInputsPerTick;

enum _:BhopLog
{
	Bhop_Inputs,
	Bhop_AirTicks,
	Bhop_GroundTicks,
	Bhop_InputTicks,
	Bhop_DemoTick,
	Float:Bhop_InputsPerTick,
	Float:Bhop_Speed
}

enum _:Jump
{
	Jump_AirTicks,
	Jump_Inputs,
	Jump_GroundTicks
}

enum _:Total
{
	Total_Inputs,
	Total_AirTicks,
	Total_GroundTicks,
	Float:Total_Speed,
	Total_Perfs
}

enum _:Avg
{
	Float:Avg_Inputs,
	Float:Avg_InputsPerTick,
	Float:Avg_GroundTicks,
	Float:Avg_Speed,
	Float:Avg_Perfs
}

new Handle:g_hBhops[MAXPLAYERS + 1];
new g_eJump[MAXPLAYERS + 1][Jump];
new g_eTotals[MAXPLAYERS + 1][Total];
new g_eAvg[MAXPLAYERS + 1][Avg];

new g_bInJump[MAXPLAYERS + 1];

new g_iInputTicks[MAXPLAYERS + 1];

new Float:g_fLastWarnTime[MAXPLAYERS + 1];

new bool:g_bPerfSound[MAXPLAYERS + 1];

StartJump(iClient)
{
	if (g_bInJump[iClient])
		PushBhopToLog(iClient);
	
	g_bInJump[iClient] = true;

	new eStartJumpData[Jump];

	g_eJump[iClient] = eStartJumpData;
}

AbortJump(iClient)
{

	g_bInJump[iClient] = false;
	
	new eEmptyJumpData[Jump];
	g_eJump[iClient] = eEmptyJumpData;

}

PushBhopToLog(iClient)
{
	new eBhop[BhopLog];
	eBhop[Bhop_Inputs] = g_eJump[iClient][Jump_Inputs];
	eBhop[Bhop_AirTicks] = g_eJump[iClient][Jump_AirTicks];
	eBhop[Bhop_GroundTicks] = g_eJump[iClient][Jump_GroundTicks];
	eBhop[Bhop_InputTicks] = g_iInputTicks[iClient];
	eBhop[Bhop_DemoTick] = SourceTV_GetRecordingTick();

	if (GetConVarBool(cvar_allow_perf_sounds) && g_bPerfSound[iClient] && eBhop[Bhop_GroundTicks] == 1 && eBhop[Bhop_InputTicks] == 1)
	{
		ClientCommand(iClient, "play %s", szPerfSound);
	}

	if (eBhop[Bhop_AirTicks])
		eBhop[Bhop_InputsPerTick] = float(eBhop[Bhop_Inputs]) / float(eBhop[Bhop_AirTicks]);
	else
		eBhop[Bhop_InputsPerTick] = 0.0;
	
	decl Float:fVel[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fVel);
	fVel[2] = 0.0;
	eBhop[Bhop_Speed] = GetVectorLength(fVel);

	g_eTotals[iClient][Total_Inputs] += eBhop[Bhop_Inputs];
	g_eTotals[iClient][Total_AirTicks] += eBhop[Bhop_AirTicks];
	g_eTotals[iClient][Total_GroundTicks] += eBhop[Bhop_GroundTicks];
	g_eTotals[iClient][Total_Speed] += eBhop[Bhop_Speed];
	if (eBhop[Bhop_GroundTicks] <= 1)
		g_eTotals[iClient][Total_Perfs]++;

	new iBhops = GetArraySize(g_hBhops[iClient]);
	if (iBhops)
	{
		ShiftArrayUp(g_hBhops[iClient], 0);
		if (iBhops >= g_iBhopsMax)
		{
			decl eDroppedBhop[BhopLog];
			GetArrayArray(g_hBhops[iClient], g_iBhopsMax, eDroppedBhop);

			g_eTotals[iClient][Total_Inputs] -= eDroppedBhop[Bhop_Inputs];
			g_eTotals[iClient][Total_AirTicks] -= eDroppedBhop[Bhop_AirTicks];
			g_eTotals[iClient][Total_GroundTicks] -= eDroppedBhop[Bhop_GroundTicks];
			g_eTotals[iClient][Total_Speed] -= eDroppedBhop[Bhop_Speed];
			if (eDroppedBhop[Bhop_GroundTicks] <= 1)
				g_eTotals[iClient][Total_Perfs]--;

			ResizeArray(g_hBhops[iClient], g_iBhopsMax);
		}
		SetArrayArray(g_hBhops[iClient], 0, eBhop);
	}
	else
		PushArrayArray(g_hBhops[iClient], eBhop);

	CalculateAverages(iClient);
}

CalculateAverages(iClient)
{
	new Float:fBhops = float(GetArraySize(g_hBhops[iClient]));

	g_eAvg[iClient][Avg_Inputs] = float(g_eTotals[iClient][Total_Inputs]) / fBhops;
	g_eAvg[iClient][Avg_InputsPerTick] = float(g_eTotals[iClient][Total_Inputs]) / float(g_eTotals[iClient][Total_AirTicks]);
	g_eAvg[iClient][Avg_GroundTicks] = float(g_eTotals[iClient][Total_GroundTicks]) / fBhops;
	g_eAvg[iClient][Avg_Speed] = g_eTotals[iClient][Total_Speed] / fBhops;
	g_eAvg[iClient][Avg_Perfs] = float(g_eTotals[iClient][Total_Perfs]) / fBhops;

	CheckClient(iClient);
}

CheckClient(iClient)
{
	//if (g_fLastWarnTime[iClient] && (GetClientTime(iClient) - g_fLastWarnTime[iClient]) >= )
		return;
}

PrepareClient(iClient)
{
	g_fLastWarnTime[iClient] = 0.0;
	g_hBhops[iClient] = CreateArray(BhopLog, 0);
	AbortJump(iClient);
	
	new eEmptyTotals[Total];
	g_eTotals[iClient] = eEmptyTotals;
}

public OnClientConnected(iClient)
	PrepareClient(iClient);

public OnClientDisconnected(iClient)
	CloseHandle(g_hBhops[iClient]);


public OnPluginStart()
{
	LoadTranslations("common.phrases");
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
	AddCommandListener(OnSay, "say");
	AddCommandListener(OnSay, "say_team");
	RegConsoleCmd("sm_bhopcheck", Command_BhopCheck);
	RegConsoleCmd("sm_bhc", Command_BhopCheck);
	//RegAdminCmd("sm_bhce", Command_BhopCheckExtended, ADMFLAG_SLAY);
	RegConsoleCmd("sm_bhce", Command_BhopCheckExtended);
	RegConsoleCmd("sm_perfsound", Command_PerfSounds);
	
	cvar_warn_inputs = CreateConVar("bhc_warn_inputs", "0.45", "Min avg. inputs per tick to warn admins", _, true, 0.25, true, 0.45);
	cvar_warn_perfs = CreateConVar("bhc_warn_perfs", "0.8", "Min avg. perfs to warn admins", _, true, 0.6, true, 1.0);
	cvar_warn_cooldown = CreateConVar("bhc_warn_cooldown", "30.0", "Min time to wait before warning about the same player", _, true, 0.0, false, 0.0);
	cvar_bhops_max = CreateConVar("bhc_max_bhops", "20", "Max bhops to track per player", _, true, 20.0, true, 100.0);
	cvar_allow_perf_sounds = CreateConVar("bhc_allow_perf_sounds", "0", "Allow players to turn of sounds for perfect jumps", _, true, 0.0, true, 1.0);

	g_iBhopsMax = GetConVarInt(cvar_bhops_max);
	g_fMinWarnCooldown = GetConVarFloat(cvar_warn_cooldown);
	g_fWarnInputsPerTick = GetConVarFloat(cvar_warn_inputs);
	g_fWarnPerfs = GetConVarFloat(cvar_warn_perfs);

	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			PrepareClient(i);
}

public OnMapStart()
{
	g_iBhopsMax = GetConVarInt(cvar_bhops_max);
	g_fMinWarnCooldown = GetConVarFloat(cvar_warn_cooldown);
	g_fWarnInputsPerTick = GetConVarFloat(cvar_warn_inputs);
	g_fWarnPerfs = GetConVarFloat(cvar_warn_perfs);
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	g_bPerfSound[iClient] = bool:ClientCookies_GetCookie(iClient, CC_TYPE_BHC_PERF_SOUNDS);
}

public Action:OnSay(iClient, const String:szCommand[], iArgCount)
{
	decl String:szMessage[128];
	GetCmdArgString(szMessage, sizeof(szMessage));
	StripQuotes(szMessage);
	if (StrContains(szMessage, "!bhc", false) == 0 ||
		StrContains(szMessage, "/bhc", false) == 0)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}


public Action:Command_BhopCheck(iClient, iArgs)
{
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		ReplyToCommand(iClient, "[SM] Bhopcheck is a console only command.  Please use sm_bhc in console to see Bhopcheck stats.");
		return Plugin_Handled;
	}

	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_bhc <#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;

	PrintBhopCheck(iClient, iTarget, false);

	return Plugin_Handled;
}

public Action:Command_BhopCheckExtended(iClient, iArgs)
{
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		ReplyToCommand(iClient, "[SM] Bhopcheck is a console only command.  Please use sm_bhce in console to see extended Bhopcheck stats.");
		return Plugin_Handled;
	}

	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_bhce <#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	PrintBhopCheck(iClient, iTarget, true);

	return Plugin_Handled;
}


PrintBhopCheck(iClient, iTarget, bool:bExtended)
{
	decl  String:szAuthID[24];
	GetClientAuthId(iTarget, AuthId_Steam2, szAuthID, sizeof(szAuthID), false);

	decl String:szMapName[PLATFORM_MAX_PATH];
	GetCurrentMap(szMapName, sizeof(szMapName));

	new iBhops = GetArraySize(g_hBhops[iTarget]);

	PrintToConsole(iClient, "\n\t\tBhopCheck %s", PLUGIN_VERSION);
	PrintToConsole(iClient, "\tName: %N\n\tSteam ID: %s\n\tMap: %s",
							iTarget,
							szAuthID,
							szMapName
							);

	decl String:szTime[32];
	FormatTime(szTime, sizeof(szTime), "\t%Y-%m-%d-%H:%M:%S", GetTime());
	PrintToConsole(iClient, szTime);

	if (!iBhops)
	{
		PrintToConsole(iClient, "\n\tNo bhops logged for this player");
		return;
	}
	if (bExtended){ // Extended Log

		PrintToConsole(iClient, "\t----------------- Bhop Log Extended -----------------");
		PrintToConsole(iClient, "\tInputs\tAir\tI/T\tGround\tSpeed\tTick\tHeld");
		PrintToConsole(iClient, "\t-----------------------------------------------------");
		for (new i = 0; i < iBhops; i++)
		{
			decl eBhop[BhopLog];
			GetArrayArray(g_hBhops[iTarget], i, eBhop);

			PrintToConsole(iClient, "\t%i\t%i\t%s%.2f\t%s%i\t%.1f\t%i\t%s%i",
			eBhop[Bhop_Inputs],
			eBhop[Bhop_AirTicks],
			(eBhop[Bhop_InputsPerTick] >= g_fWarnInputsPerTick) ? "*" : " ",
			eBhop[Bhop_InputsPerTick],
			(eBhop[Bhop_GroundTicks] <= 1) ? "# " : "  ",
			eBhop[Bhop_GroundTicks],
			eBhop[Bhop_Speed],
			eBhop[Bhop_DemoTick],
			(eBhop[Bhop_InputTicks] <= 2) ? "N " : "A ",
			eBhop[Bhop_InputTicks]);
		}
	}
	else{ // Regular Log
		PrintToConsole(iClient, "\t------------- Bhop Log -------------");
		PrintToConsole(iClient, "\tInputs\tI/T\tGround\tSpeed\tType");
		PrintToConsole(iClient, "\t------------------------------------");
		for (new i = 0; i < iBhops; i++)
		{
			decl eBhop[BhopLog];
			GetArrayArray(g_hBhops[iTarget], i, eBhop);

			PrintToConsole(iClient, "\t%i\t%.2f\t%s%i\t%.1f\t%s",
			eBhop[Bhop_Inputs],
			eBhop[Bhop_InputsPerTick],
			(eBhop[Bhop_GroundTicks] <= 1) ? "# " : "  ",
			eBhop[Bhop_GroundTicks],
			eBhop[Bhop_Speed],
			(eBhop[Bhop_InputTicks] <= 2) ? "Normal " : "Auto ");
		}
	}



	PrintToConsole(iClient, "\n\t----\t----\tAvg\t----\t----");
	PrintToConsole(iClient, "\tInputs\tI/T\tGround\tSpeed\tPerfs");
	PrintToConsole(iClient, "\t%.1f\t%.2f\t%.1f\t%.1f\t%.0f%%",
		g_eAvg[iTarget][Avg_Inputs],
		g_eAvg[iTarget][Avg_InputsPerTick],
		g_eAvg[iTarget][Avg_GroundTicks],
		g_eAvg[iTarget][Avg_Speed],
		g_eAvg[iTarget][Avg_Perfs] * 100.0
	);
}


public Action:Event_PlayerJump(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	StartJump(iClient);

	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(IsFakeClient(iClient))
		return Plugin_Continue;
	
	if(iButtons & IN_JUMP)
		g_iInputTicks[iClient]++;
	else
		g_iInputTicks[iClient] = 0;
	
	if (g_bInJump[iClient])
	{
		if (!IsPlayerAlive(iClient))
		{
			AbortJump(iClient);
			return Plugin_Continue;
		}

		if (GetEntityMoveType(iClient) & (MOVETYPE_NOCLIP | MOVETYPE_LADDER))
		{
			AbortJump(iClient);
			return Plugin_Continue;
		}
		
		if(GetEntityFlags(iClient) & FL_ONGROUND)
		{
			if (g_eJump[iClient][Jump_GroundTicks]++ > 20)
			{
				AbortJump(iClient);
				return Plugin_Continue;
			}
		}	
		else
		{
			if (g_eJump[iClient][Jump_GroundTicks])
			{
				AbortJump(iClient);
				return Plugin_Continue;
			}

			g_eJump[iClient][Jump_AirTicks]++;
			g_eJump[iClient][Jump_GroundTicks] = 0;
		}

		if (g_iInputTicks[iClient] == 1)
			g_eJump[iClient][Jump_Inputs]++;
	}

	return Plugin_Continue;
}


public Action:Command_PerfSounds(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;

	if (!GetConVarBool(cvar_allow_perf_sounds))
	{
		PrintToChat(iClient, "[SM] Server does not allow perf sounds");
		return Plugin_Handled;
	}
	
	g_bPerfSound[iClient] = !g_bPerfSound[iClient];
	
	if(g_bPerfSound[iClient])
		PrintToChat(iClient, "[SM] You will now hear sounds on perfect jumps. Type !perfsound to toggle");
	else
		PrintToChat(iClient, "[SM] You will no longer hear sounds on perfect jumps. Type !perfsound to toggle");
	
	ClientCookies_SetCookie(iClient, CC_TYPE_BHC_PERF_SOUNDS, g_bPerfSound[iClient]);
	
	return Plugin_Handled;
}