#include <sourcemod>

#pragma semicolon 1

enum _:Bhop
{
	Bhop_Inputs,
	Bhop_LateTicks,
	Float:Bhop_Speed
}

new Handle:g_hBhopData[MAXPLAYERS + 1];

new g_iInputTicks[MAXPLAYERS + 1];
new g_iInputsSinceJump[MAXPLAYERS + 1];
new g_iGroundTicks[MAXPLAYERS + 1];


public OnClientConnected(iClient)
	g_hBhopData[iClient] = CreateArray(Bhop, 0);

public OnClientDisconnected(iClient)
	CloseHandle(g_hBhopData[iClient]);


public OnPluginStart()
{
	LoadTranslations("common.phrases");
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
	RegConsoleCmd("sm_bhopcheck", Command_BhopCheck);
}


public Action:Command_BhopCheck(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_bhopcheck <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, true, false);
	if(iTarget == -1)
		return Plugin_Handled;
	
	PrintToChat(iClient, "Bhop Stats for %N printed to console", iTarget);
	
	PrintToConsole(iClient, "   ---------------------");
	PrintToConsole(iClient, "   BhopCheck: %N", iTarget);
	new Handle:hBhopArray = g_hBhopData[iTarget];
	new iBhops = GetArraySize(hBhopArray);
	if (!iBhops)
	{
		PrintToConsole(iClient, "   No Scroll Bhops So Far");
		return Plugin_Handled;
	}
	PrintToConsole(iClient, "   Inputs | Late | Speed");
	PrintToConsole(iClient, "   ---------------------");
	
	new iInputs, iLate, Float:fSpeed, iPerfs;
	for (new i=0; i<iBhops; i++)
	{
		decl eBhop[Bhop];
		GetArrayArray(hBhopArray, i, eBhop);
		
		iInputs += eBhop[Bhop_Inputs];
		fSpeed += eBhop[Bhop_Speed];
		iLate += eBhop[Bhop_LateTicks];
		
		if (eBhop[Bhop_LateTicks] == 1)
			iPerfs++;
		
		decl String:szInputs[3];
		Format(szInputs, 3, "%i ", eBhop[Bhop_Inputs]);
		
		PrintToConsole(iClient, "      %s  |  %i   | %.1f", szInputs, eBhop[Bhop_LateTicks], eBhop[Bhop_Speed]);
	}
	PrintToConsole(iClient, "   ---------------------");
	PrintToConsole(iClient, "          Averages");
	PrintToConsole(iClient, "   ---------------------");
	decl String:szInputs[6];
	Format(szInputs, 6, "%.2f      ", float(iInputs) / iBhops);
	PrintToConsole(iClient, "    %s | %.2f | %.1f", szInputs, float(iLate) / iBhops, fSpeed / iBhops);
	PrintToConsole(iClient, "   ---------------------");
	PrintToConsole(iClient, "        Perfect Jumps");
	PrintToConsole(iClient, "           %.2f%", 100.0 * (float(iPerfs) / iBhops));
	
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
	eBhop[Bhop_Inputs] = g_iInputsSinceJump[iClient];
	eBhop[Bhop_LateTicks] = g_iGroundTicks[iClient] - 1;
	fVel[2] = 0.0;
	eBhop[Bhop_Speed] = GetVectorLength(fVel, false);
	
	
	new Handle:hBhopArray = g_hBhopData[iClient];
	new iBhops = GetArraySize(hBhopArray);
	if (iBhops)
	{
		ShiftArrayUp(hBhopArray, 0);
		SetArrayArray(hBhopArray, 0, eBhop);
		if (iBhops > 20)
			ResizeArray(hBhopArray, 20);
	}
	else
		PushArrayArray(hBhopArray, eBhop);
	
	
	g_iInputsSinceJump[iClient] = 0;
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
