#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entoutput>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_logger"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Logger";
new const String:PLUGIN_VERSION[] = "1.7";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The logger plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fNextDamageMessage[MAXPLAYERS+1];

new bool:g_bIsAdmin[MAXPLAYERS+1];

new Handle:g_hPlayerLogs[MAXPLAYERS+1];
new Handle:g_hLogTypes[MAXPLAYERS+1];

new g_iRoundStartTime;
new g_iHurtsTouched[MAXPLAYERS+1];
new g_iPlayerHealth[MAXPLAYERS+1];

new String:g_szLastHitVent[64];

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("ultjb_logger_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegAdminCmd("sm_log", OnLogUse, ADMFLAG_BAN, "sm_log <player> <num> - List the actions relating to <player> in the past <num> seconds.");
	RegAdminCmd("sm_logs", OnLogUse, ADMFLAG_BAN, "sm_log <player> <num> - List the actions relating to <player> in the past <num> seconds.");
	
	for(new i=0;i<=MaxClients;i++)
	{
		g_hPlayerLogs[i] = CreateArray(512);
		g_hLogTypes[i] = CreateArray(1);
	}
	
	HookEvent("player_hurt", EventPlayerHurt_Post, EventHookMode_Post);
	HookEvent("player_death", EventPlayerDeath_Post, EventHookMode_Post);
	HookEvent("round_start", EventRoundStart_Post, EventHookMode_PostNoCopy);
	
	SetupConVars();
	
	HookEntityOutput("func_button", "OnIn", OnButtonIn);
	HookEntityOutput("func_rot_button", "OnIn", OnButtonIn);
	HookEntityOutput("trigger_teleport", "OnEndTouch", OnTeleportEndTouch);
	HookEntityOutput("trigger_hurt", "OnStartTouch", OnHurtEnter);
	HookEntityOutput("trigger_hurt", "OnEndTouch", OnHurtLeave);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
}

SetupConVars()
{
	new Handle:hConvar = FindConVar("sv_damage_print_enable");
	if(hConvar == INVALID_HANDLE)
		return;
	
	HookConVarChange(hConvar, OnConVarChanged);
	SetConVarBool(hConvar, false);
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[])
{
	SetConVarBool(hConvar, false);
}

public OnMapStart()
{
	FindEntitiesToHook();
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	SDKHook(iClient, SDKHook_WeaponDropPost, OnWeaponDropPost);
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponPickupPost);
}

public Action:OnWeaponDropPost(iClient, iWeapon)
{
	if(iWeapon <= 0)
		return;
	new String:szMessage[512];
	new String:szName[64];
	GetEdictClassname(iWeapon, szName, sizeof(szName));
	Format(szMessage, sizeof(szMessage), "%N dropped %s.", iClient, szName);
	LogEvent(szMessage, iClient, 0, LOGTYPE_ITEM, false);
}

public Action:OnWeaponPickupPost(iClient, iWeapon)
{
	new String:szMessage[512];
	new String:szName[64];
	GetEdictClassname(iWeapon, szName, sizeof(szName));
	Format(szMessage, sizeof(szMessage), "%N picked up %s.", iClient, szName);
	LogEvent(szMessage, iClient, 0, LOGTYPE_ITEM, false);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_logger");
	
	CreateNative("UltJB_Logger_LogEvent", _UltJB_Logger_LogEvent);
	
	return APLRes_Success;
}

public _UltJB_Logger_LogEvent(Handle:hPlugin, iNumParams)
{
	if(iNumParams < 4 || iNumParams > 5)
	{
		LogError("Invalid number of parameters.");
		return 0;
	}
	
	new iLength;
	if(GetNativeStringLength(1, iLength) != SP_ERROR_NONE)
		return 0;
	
	iLength++;
	decl String:szMessage[iLength];
	GetNativeString(1, szMessage, iLength);
	
	new iPrimary = GetNativeCell(2);
	new iSecondary = GetNativeCell(3);
	new iLogType = GetNativeCell(4);
	new bool:bLogGlobal = true;
	
	if(iNumParams == 5)
		bLogGlobal = GetNativeCell(5);
		
	LogEvent(szMessage, iPrimary, iSecondary, iLogType, bLogGlobal);
	
	return 0;
}

public EventRoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	FindEntitiesToHook();
	
	ClearLogs();
	g_iRoundStartTime = GetTime();
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		PrintToConsole(iClient, "\n---------------------\n+ NEW ROUND STARTED +\n---------------------\n");
	}
}

FindEntitiesToHook()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_breakable")) != -1)
	{
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamage);
		HookSingleEntityOutput(iEnt, "OnBreak", OnVentBreak, true);
	}
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_button")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamageButton);
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "func_rot_button")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamageButton);
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "momentary_rot_button")) != -1)
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamageButton);
}

public OnButtonIn(const String:szOutput[], iVictim, iAttacker, Float:fDelay)
{
	if(!(1 <= iAttacker <= MaxClients))
	{
		if(iAttacker < 0)
			return;
		
		iAttacker = GetEntPropEnt(iAttacker, Prop_Data, "m_hOwnerEntity");
		if(!(1 <= iAttacker <= MaxClients))
			return;
	}
	
	static String:szClientName[MAX_NAME_LENGTH];
	GetClientName(iAttacker, szClientName, sizeof(szClientName));
	
	
	static String:szName[64];
	GetEntPropString(iVictim, Prop_Data, "m_iName", szName, sizeof(szName));
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "   +++   Button pressed by: %s - (%s)", szClientName, szName);
	
	LogEvent(szMessage, iAttacker, 0, LOGTYPE_USE);
	
	if(GetClientTeam(iAttacker) == TEAM_GUARDS)
	{
		for(new iClient=1; iClient<=MaxClients; iClient++)
		{	
				if(!IsClientInGame(iClient))
					continue;
				
				if(!g_bIsAdmin[iClient] && !IsClientSourceTV(iClient))
					continue;
				
				PrintToConsole(iClient, szMessage);
		}
	}
}

public OnSpawnPost(iClient)
{	
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage),  "%N was respawned.", iClient);
	
	LogEvent(szMessage, iClient, 0, LOGTYPE_ANY);
}

public Action:OnTakeDamageButton(iVictim, &iAttacker, &iInflictor, &Float:fdamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3])
{
	if(!(1 <= iAttacker <= MaxClients))
	{
		if(iAttacker < 0)
			return Plugin_Continue;
		
		iAttacker = GetEntPropEnt(iAttacker, Prop_Data, "m_hOwnerEntity");
		if(!(1 <= iAttacker <= MaxClients))
			return Plugin_Continue;
	}
	
	static String:szClientName[MAX_NAME_LENGTH];
	GetClientName(iAttacker, szClientName, sizeof(szClientName));
	
	
	static String:szName[64];
	GetEntPropString(iVictim, Prop_Data, "m_iName", szName, sizeof(szName));
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "Button damaged by: %s - (%s)", szClientName, szName);
	
	LogEvent(szMessage, iAttacker, 0, LOGTYPE_USE);
	
	if(GetClientTeam(iAttacker) == TEAM_GUARDS)
	{
		for(new iClient=1; iClient<=MaxClients; iClient++)
		{	
				if(!IsClientInGame(iClient))
					continue;
				
				if(!g_bIsAdmin[iClient] && !IsClientSourceTV(iClient))
					continue;
				
				PrintToConsole(iClient, "   +++   %s", szMessage);
		}
	}
	
	return Plugin_Continue;
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fdamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3])
{
	static iOwner;
	if(1 <= iAttacker <= MaxClients)
	{
		if(iAttacker == iInflictor)
			iOwner = iAttacker;
		else
			iOwner = GetEntPropEnt(iInflictor, Prop_Data, "m_hOwnerEntity");
	}
	else
	{
		iOwner = GetEntPropEnt(iAttacker, Prop_Data, "m_hOwnerEntity");
	}
	
	if(!(1 <= iOwner <= MaxClients))
		return;
	
	if(g_fNextDamageMessage[iOwner] > GetEngineTime())
		return;
	
	g_fNextDamageMessage[iOwner] = GetEngineTime() + 0.04;
	
	new iEnt;
	if(iWeapon != -1)
	{
		iEnt = iWeapon;
	}
	else
	{
		if(!(1 <= iInflictor <= MaxClients))
			iEnt = iInflictor;
		else if(!(1 <= iAttacker <= MaxClients))
			iEnt = iAttacker;
	}
	
	decl String:szWeapon[32];
	if(iEnt)
		GetEntityClassname(iEnt, szWeapon, sizeof(szWeapon));
	else
		strcopy(szWeapon, sizeof(szWeapon), "unknown weapon");
	
	static String:szName[64];
	GetEntPropString(iVictim, Prop_Data, "m_iName", szName, sizeof(szName));
	
	strcopy(g_szLastHitVent, sizeof(g_szLastHitVent), szName);
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "Vent damaged by: %N using %s - (%s)", iOwner, szWeapon, szName);
	
	LogEvent(szMessage, iOwner, 0, LOGTYPE_BREAK, false);
	
	if(GetClientTeam(iOwner) != TEAM_GUARDS)
		return;
		
	PrintHintText(iOwner, "You damaged a vent. This is against the rules unless it is LR or Last Guard.");
	
	for(new iClient=1; iClient<=MaxClients; iClient++) 
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!g_bIsAdmin[iClient] && !IsClientSourceTV(iClient))
			continue;
		
		PrintToConsole(iClient, "   +++   %s", szMessage);
	}
}

public OnVentBreak(String:szOutput[], iCaller, iActivator, Float:fDelay)
{
	if(!(1 <= iActivator <= MaxClients))
		return;

	new String:szMessage[512];
	new String:szName[64];
	strcopy(szName, sizeof(szName), g_szLastHitVent);
	
	Format(szMessage, sizeof(szMessage), "%N broke a vent (%s).", iActivator, szName, g_szLastHitVent);
	
	LogEvent(szMessage, iActivator, 0, LOGTYPE_BREAK);
}

public OnClientConnected(iClient)
{
	g_bIsAdmin[iClient] = false;
}

public OnClientPostAdminCheck(iClient)
{
	if(CheckCommandAccess(iClient, "sm_say", ADMFLAG_CHAT, false))
		g_bIsAdmin[iClient] = true;
}

public EventPlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsPlayer(iVictim))
		return;
	
	decl String:szWeaponNameString[32], String:szVictimName[MAX_NAME_LENGTH+8], String:szAttackerName[MAX_NAME_LENGTH+8];
	
	if(iAttacker == iVictim)
	{
		GetClientName(iVictim, szAttackerName, sizeof(szAttackerName));
		Format(szAttackerName, sizeof(szAttackerName), "(%s) %s", (GetClientTeam(iVictim) == TEAM_GUARDS) ? "CT" : "T", szAttackerName);
		
		strcopy(szVictimName, sizeof(szVictimName), "themself");
		strcopy(szWeaponNameString, sizeof(szWeaponNameString), "From suicide");
	}
	else if(!IsPlayer(iAttacker))
	{
		GetClientName(iVictim, szAttackerName, sizeof(szAttackerName));
		Format(szAttackerName, sizeof(szAttackerName), "(%s) %s", (GetClientTeam(iVictim) == TEAM_GUARDS) ? "CT" : "T", szAttackerName);
		
		strcopy(szVictimName, sizeof(szVictimName), "themself");
		strcopy(szWeaponNameString, sizeof(szWeaponNameString), "From world damage");
	}
	else
	{
		GetClientName(iAttacker, szAttackerName, sizeof(szAttackerName));
		Format(szAttackerName, sizeof(szAttackerName), "(%s) %s", (GetClientTeam(iAttacker) == TEAM_GUARDS) ? "CT" : "T", szAttackerName);
		
		GetClientName(iVictim, szVictimName, sizeof(szVictimName));
		Format(szVictimName, sizeof(szVictimName), "(%s) %s", (GetClientTeam(iVictim) == TEAM_GUARDS) ? "CT" : "T", szVictimName);
		
		GetEventString(hEvent, "weapon", szWeaponNameString, sizeof(szWeaponNameString));
		Format(szWeaponNameString, sizeof(szWeaponNameString), "With weapon %s", szWeaponNameString);
	}
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "   ---   \"%s\" killed \"%s\"  --  %s.", szAttackerName, szVictimName, szWeaponNameString);
	
	LogEvent(szMessage, iAttacker, iVictim, LOGTYPE_ATTACK);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		PrintToConsole(iClient, szMessage);
	}
}

public EventPlayerHurt_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	new iDamageHealth = GetEventInt(hEvent, "dmg_health");
	new iDamageArmor = GetEventInt(hEvent, "dmg_armor");
	
	if(iAttacker == iVictim)
	{
		new String:szMessage[512];
		Format(szMessage, sizeof(szMessage), "%N damaged themself for %i Health and %i Armor.", iAttacker, iDamageHealth, iDamageArmor);
	
		LogEvent(szMessage, iAttacker, 0, LOGTYPE_ATTACK);
		return;
	}
	
	if(iAttacker == 0)
	{
		new String:szMessage[512];
		Format(szMessage, sizeof(szMessage), "%N took %d (+%d) world damage.", iVictim, iDamageHealth, iDamageArmor);
	
		LogEvent(szMessage, iVictim, 0, LOGTYPE_ATTACK);
		return;
	}
	
	if(!IsPlayer(iAttacker) || !IsPlayer(iVictim))
		return;
		
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "   ---   %N damaged %N for %i Health and %i Armor.", iAttacker, iVictim, iDamageHealth, iDamageArmor);
	
	LogEvent(szMessage, iAttacker, iVictim, LOGTYPE_ATTACK);
	
	if(GetClientTeam(iAttacker) == TEAM_PRISONERS)
		return;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		PrintToConsole(iClient, szMessage);
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}

public Action:OnLogUse(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	new iLines, iLog;
	
	if(iArgCount < 1)
	{
		iLines = 0;
		iLog = 0;
	}
	else
	{
		new String:szTarget[256];
		GetCmdArg(1, szTarget, sizeof(szTarget));
	
		new iTarget = FindTarget(iClient, szTarget, false, false);
		if(iTarget == -1)
		{
			iLines = StringToInt(szTarget);
			if(iLines <= 0)
				return Plugin_Handled;
		}
		else
		{
			iLog = iTarget;
		}
		
		if(iArgCount > 1)
		{
			new String:szLines[16];
			GetCmdArg(2, szLines, sizeof(szLines));
			
			iLines = StringToInt(szLines);
		}
		else
		{
			iLines = 0;
		}
	}
	
	if(GetClientTeam(iClient) == TEAM_GUARDS && IsPlayerAlive(iClient) && (iLog == 0 || IsPlayerAlive(iLog)))
	{
		ReplyToCommand(iClient, "[SM] You cannot check logs of living players while you are a living CT.");
		return Plugin_Handled;
	}
	
	if(iLog == 0)
		ReplyToCommand(iClient, "[SM] Printing logs to console.");
	else
		ReplyToCommand(iClient, "[SM] Printing logs for %N to console.", iLog);
		
	PrintToConsole(iClient, " ");
	
	PrintLogLines(iClient, iLog, iLines, LOGTYPE_ANY);
	
	return Plugin_Handled;
}

PrintLogLines(iClient, iLog, iLines, iType)
{
	new iLen = GetArraySize(g_hPlayerLogs[iLog]);
	new iStart, iCount;
	
	if(iLines > 0)
		iStart = iLen - iLines;

	if(iStart < 1)
		iStart = 1;
	
	new String:szLine[512];
	new iLinetype;
	new String:szLinetype[1];
	
	for(new i=iStart-1;i<iLen;i++)
	{
		GetArrayString(g_hPlayerLogs[iLog], i, szLine, sizeof(szLine));
		GetArrayString(g_hLogTypes[iLog], i, szLinetype, sizeof(szLinetype));
		iLinetype = StringToInt(szLinetype);
		
		if(iType == LOGTYPE_ANY || (iType == iLinetype))
		{	
			PrintToConsole(iClient, szLine);
			
			iCount++;
			if(iCount >= 40) 
			{	
				new Handle:hPack = CreateDataPack();
				WritePackCell(hPack, iClient);
				WritePackCell(hPack, iLog);
				WritePackCell(hPack, (iLen - iStart - 40));
				WritePackCell(hPack, iType);
				CreateTimer(0.0, Timer_FinishPrintingLogs, hPack);
				break;
			}
		}
	}
}
public Action:Timer_FinishPrintingLogs(Handle:hTimer, any:hPack)
{
	ResetPack(hPack, false);
	new iClient = ReadPackCell(hPack);
	new iLog = ReadPackCell(hPack);
	new iLines = ReadPackCell(hPack);
	new iType = ReadPackCell(hPack);
	
	CloseHandle(hPack);
	
	PrintLogLines(iClient, iLog, iLines, iType);
}

ClearLogs()
{
	for(new iClient=1;iClient<=MaxClients;iClient++)
	{
		if(IsClientInGame(iClient) && IsClientSourceTV(iClient))
		{
			new iLen = GetArraySize(g_hPlayerLogs[0]);
			new String:szLine[512];
			for(new iLine=0;iLine<iLen;iLine++)
			{
				GetArrayString(g_hPlayerLogs[0], iLine, szLine, sizeof(szLine));
				PrintToConsole(iClient, szLine);
			}
		}
	}
	for(new i=0;i<=MaxClients;i++)
	{
		ClearArray(g_hLogTypes[i]);
		ClearArray(g_hPlayerLogs[i]);
	}
}

LogEvent(String:szMessage[], iClient, iSecondary, iType, bool:bLogGlobal=true)
{
	new iTime = GetTime() - g_iRoundStartTime;
	new iMin = ((iTime / 60) % 60);
	new iSec = (iTime % 60);
	new String:szFormatted[512];
	
	Format(szFormatted, sizeof(szFormatted), "[%02i:%02i] %s", iMin, iSec, szMessage);
	
	new String:szType[1];
	IntToString(iType, szType, sizeof(szType));
	
	if(iClient > 0)
	{
		PushArrayString(g_hPlayerLogs[iClient], szFormatted);
		PushArrayString(g_hLogTypes[iClient], szType);
	}
	
	if(iSecondary > 0 && iSecondary != iClient)
	{
		PushArrayString(g_hPlayerLogs[iSecondary], szFormatted);
		PushArrayString(g_hLogTypes[iSecondary], szType);
	}
	
	if(bLogGlobal)
	{
		PushArrayString(g_hPlayerLogs[0], szFormatted);
		PushArrayString(g_hLogTypes[0], szType);
	}
	
	if(iClient == 0 && iSecondary == 0 && !bLogGlobal)
	{
		NotifyAdminsLogFailure(szFormatted);
	}
}

NotifyAdminsLogFailure(String:szMessage[])
{
	for(new iClient=1;iClient<=MaxClients;iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(CheckCommandAccess(iClient, "sm_logwarn", ADMFLAG_UNBAN))
		{
			PrintToConsole(iClient, "[SM] WARNING: Not sure where to log following message:");
			PrintToConsole(iClient, szMessage);
		}
	}
}

public OnTeleportEndTouch(const String:szOutput[], iCaller, iActivator, Float:fDelay)
{
	if(!(1 <= iActivator <= MaxClients))
		return;

	static String:szName[64];
	GetEntPropString(iCaller, Prop_Data, "m_iName", szName, sizeof(szName));
	
	static String:szDest[64];
	GetEntPropString(iCaller, Prop_Data, "m_target", szDest, sizeof(szDest));
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "%N used teleport (%s) to %s", iActivator, szName, szDest);
	
	LogEvent(szMessage, iActivator, 0, LOGTYPE_USE, false);
}

public OnHurtEnter(const String:szOutput[], iVictim, iAttacker, Float:fDelay)
{
	if(!(0 < iAttacker <= MaxClients))
		return;
	
	g_iPlayerHealth[iAttacker] = GetClientHealth(iAttacker);
	
	if(g_iHurtsTouched[iAttacker] == 0)
		SDKHook(iAttacker, SDKHook_PostThinkPost, Hook_PostThinkHealCheck);
	
	g_iHurtsTouched[iAttacker]++;
}

public OnHurtLeave(const String:szOutput[], iVictim, iAttacker, Float:fDelay)
{
	if(!(0 < iAttacker <= MaxClients))
		return;
	
	g_iHurtsTouched[iAttacker]--;
	
	if(g_iHurtsTouched[iAttacker] == 0)
		SDKUnhook(iAttacker, SDKHook_PostThinkPost, Hook_PostThinkHealCheck);
}

public Action:Hook_PostThinkHealCheck(iClient)
{
	new iHealth = GetClientHealth(iClient);
	
	if(g_iPlayerHealth[iClient] < iHealth)
	{
		new String:szMessage[512];
		Format(szMessage, sizeof(szMessage), "%N healed for %d.", iClient, iHealth - g_iPlayerHealth[iClient]);
		LogEvent(szMessage, iClient, 0, LOGTYPE_ATTACK, false);
	}
	
	g_iPlayerHealth[iClient] = iHealth;
}
