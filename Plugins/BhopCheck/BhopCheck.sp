#include <sourcemod>
#include <hls_color_chat>
#include <sourcetvmanager>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Bhop Check";
new const String:PLUGIN_VERSION[] = "1.0";

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

new g_iBhopsMax;

enum _:Bhop
{
	Bhop_Inputs,
	Bhop_LateTicks,
	Float:Bhop_Speed
}

enum _:Total
{
	Total_Inputs,
	Total_Perfs,
	Total_Late,
	Float:Total_Speed
}

new Handle:g_hBhopData[MAXPLAYERS + 1];
new g_eBhopTotal[MAXPLAYERS + 1][Total];

new g_iInputTicks[MAXPLAYERS + 1];
new g_iInputsSinceJump[MAXPLAYERS + 1];
new g_iGroundTicks[MAXPLAYERS + 1];

new Float:g_fLastWarnTime[MAXPLAYERS + 1];


public OnClientConnected(iClient)
{
	g_hBhopData[iClient] = CreateArray(Bhop, 0);
	new eEmptyTotals[Total];
	g_eBhopTotal[iClient] = eEmptyTotals;
	g_fLastWarnTime[iClient] = 0.0;
}

public OnClientDisconnected(iClient)
	CloseHandle(g_hBhopData[iClient]);


public OnPluginStart()
{
	LoadTranslations("common.phrases");
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
	RegConsoleCmd("sm_bhopcheck", Command_BhopCheck);
	RegConsoleCmd("sm_bhc", Command_BhopCheck);
	
	cvar_warn_inputs = CreateConVar("bhc_warn_inputs", "19.0", "Min avg. inputs to warn admins", _, true, 15.0, true, 23.0);
	cvar_warn_perfs = CreateConVar("bhc_warn_perfs", "0.8", "Min avg. perfs to warn admins", _, true, 0.6, true, 1.0);
	cvar_warn_cooldown = CreateConVar("bhc_warn_cooldown", "30.0", "Min time to wait before warning about the same player", _, true, 0.0, false, 0.0);
	cvar_bhops_max = CreateConVar("bhc_max_bhops", "40", "Max bhops to track per player", _, true, 20.0, true, 100.0);
}

public OnMapStart()
	g_iBhopsMax = GetConVarInt(cvar_bhops_max);


public Action:Command_BhopCheck(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_bhopcheck <#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	PrintToChat(iClient, "Bhop Stats for %N printed to console", iTarget);
	
	PrintToConsole(iClient, "   ------BhopCheck------");
	PrintToConsole(iClient, "   %N", iTarget);
	
	decl String:szMapName[PLATFORM_MAX_PATH];
	GetCurrentMap(szMapName, sizeof(szMapName));
	
	PrintToConsole(iClient, "   %s - %i", szMapName, SourceTV_GetRecordingTick());
	new Handle:hBhopArray = g_hBhopData[iTarget];
	new iBhops = GetArraySize(hBhopArray);
	if (!iBhops)
	{
		PrintToConsole(iClient, "   No Scroll Bhops So Far");
		return Plugin_Handled;
	}
	PrintToConsole(iClient, "   Inputs | Late | Speed");
	PrintToConsole(iClient, "   ---------------------");
	
	for (new i=0; i<iBhops; i++)
	{
		decl eBhop[Bhop];
		GetArrayArray(hBhopArray, i, eBhop);
		
		decl String:szInputs[3];
		Format(szInputs, 3, "%i ", eBhop[Bhop_Inputs]);
		
		PrintToConsole(iClient, "      %s  |  %i   | %.1f", szInputs, eBhop[Bhop_LateTicks], eBhop[Bhop_Speed]);
	}
	PrintToConsole(iClient, "   ---------------------");
	PrintToConsole(iClient, "          Averages");
	PrintToConsole(iClient, "   ---------------------");
	decl String:szInputs[6], String: szLate[6];
	Format(szInputs, 6, "%.2f      ", float(g_eBhopTotal[iClient][Total_Inputs]) / float(iBhops));
	Format(szLate, 6, "%.2f       ", float(g_eBhopTotal[iClient][Total_Late]) / float(iBhops));
	PrintToConsole(iClient, "    %s | %s | %.1f", szInputs, szLate, g_eBhopTotal[iClient][Total_Speed] / iBhops);
	PrintToConsole(iClient, "   ---------------------");
	PrintToConsole(iClient, "        Perfect Jumps");
	PrintToConsole(iClient, "           %.2f%", (float(g_eBhopTotal[iClient][Total_Perfs]) / iBhops) * 100.0);
	
	return Plugin_Handled;
}


public Action:Event_PlayerJump(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (g_iGroundTicks[iClient] > 15	//Not a bhop
		|| g_iInputTicks[iClient] > 1)	//Not a scroll jump
	{
		g_iInputsSinceJump[iClient] = 0;
		return Plugin_Continue;
	}
	decl eBhop[Bhop], Float:fVel[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fVel);
	fVel[2] = 0.0;
	
	eBhop[Bhop_Inputs] 		= g_iInputsSinceJump[iClient];
	eBhop[Bhop_LateTicks] 	= g_iGroundTicks[iClient] - 1;
	if (eBhop[Bhop_LateTicks] < 0)
		eBhop[Bhop_LateTicks] = 0;
	eBhop[Bhop_Speed] 		= GetVectorLength(fVel, false);
	
	g_eBhopTotal[iClient][Total_Inputs] += g_iInputsSinceJump[iClient];
	g_eBhopTotal[iClient][Total_Late] 	+= g_iGroundTicks[iClient] - 1;
	g_eBhopTotal[iClient][Total_Speed] 	+= GetVectorLength(fVel, false);
	if (eBhop[Bhop_LateTicks] == 0)
		g_eBhopTotal[iClient][Total_Perfs]++;
	
	
	new Handle:hBhopArray = g_hBhopData[iClient];
	new iBhops = GetArraySize(hBhopArray);
	if (iBhops)
	{
		ShiftArrayUp(hBhopArray, 0);
		SetArrayArray(hBhopArray, 0, eBhop);
		iBhops = GetArraySize(hBhopArray);
		
		if (iBhops > g_iBhopsMax)
		{
			decl eDroppedBhop[Bhop];
			GetArrayArray(hBhopArray, g_iBhopsMax, eDroppedBhop);
			
			g_eBhopTotal[iClient][Total_Inputs] -= eDroppedBhop[Bhop_Inputs];
			g_eBhopTotal[iClient][Total_Late] -= eDroppedBhop[Bhop_LateTicks];
			g_eBhopTotal[iClient][Total_Speed] -= eDroppedBhop[Bhop_Speed];
			
			if (eDroppedBhop[Bhop_LateTicks] == 0)
				g_eBhopTotal[iClient][Total_Perfs]--;
				
			ResizeArray(hBhopArray, g_iBhopsMax);
		}
	}
	else
		PushArrayArray(hBhopArray, eBhop);
	
	
	g_iInputsSinceJump[iClient] = 0;
	
	AutoCheck(iClient);
	
	return Plugin_Continue;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if(GetEntityFlags(iClient) & FL_ONGROUND)
	{
		g_iGroundTicks[iClient]++;
		if (g_iGroundTicks[iClient] > 15)
			g_iInputsSinceJump[iClient] = 0;		
	}
	else
		g_iGroundTicks[iClient] = 0;
	
	if(iButtons & IN_JUMP)
		g_iInputTicks[iClient]++;
	else if(g_iInputTicks[iClient] > 0)
	{
		g_iInputsSinceJump[iClient]++;
		g_iInputTicks[iClient] = 0;
	}
}

AutoCheck(iClient)
{
	new iBhops = GetArraySize(g_hBhopData[iClient]);
	if (iBhops < 15)
		return;
	
	if (GetEngineTime() - g_fLastWarnTime[iClient] < GetConVarFloat(cvar_warn_cooldown))
		return;
	
	new Float:fAvgInputs 	= float(g_eBhopTotal[iClient][Total_Inputs]) / iBhops;
	new Float:fPerfsPercent = float(g_eBhopTotal[iClient][Total_Perfs]) / iBhops;
	
	if (fAvgInputs >= GetConVarFloat(cvar_warn_inputs) ||
		fPerfsPercent >= GetConVarFloat(cvar_warn_perfs))
	{
		
		g_fLastWarnTime[iClient] = GetEngineTime();
		new Float:fAvgLate 		= float(g_eBhopTotal[iClient][Total_Late]) / iBhops;
		new Float:fAvgSpeed 	= g_eBhopTotal[iClient][Total_Speed] / iBhops;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && (GetUserFlagBits(i) & ADMFLAG_BAN))
			{
				CPrintToChat(i, "{lightgreen}[BHC]{lightred}: %N, {blue}Averages:", iClient);
				CPrintToChat(i, "{white}{ Inputs: %.2f, Late: %.2f, Speed: %.2f, Perfs: %.1f%% }",
										fAvgInputs, fAvgLate, fAvgSpeed, fPerfsPercent * 100.0);
			}	
		}
		
	}
}
