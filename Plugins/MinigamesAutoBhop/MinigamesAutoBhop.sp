#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entoutput>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Plugins/ZoneTypes/Includes/zonetype_named"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Minigames Auto Bhop";
new const String:PLUGIN_VERSION[] = "2.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Enables auto bhop on the bhop levels.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_VALUE_LENGTH 256

new bool:g_bMapHasTeleport;
new String:g_szTeleportName[MAX_VALUE_LENGTH];

new bool:g_bShowTeleportNames[MAXPLAYERS+1];
new bool:g_bAutoJumpActivated[MAXPLAYERS+1];

new g_iForceAutoJumpTeamNum;

new Handle:cvar_autobunnyhopping;


public OnPluginStart()
{
	CreateConVar("minigames_auto_bhop_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEntityOutput("trigger_teleport", "OnStartTouch", OnTeleportTrigger);
	
	HookEvent("cs_match_end_restart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	
	RegAdminCmd("sm_showteleportnames", OnTeleportNames, ADMFLAG_ROOT, "Shows the name of the teleports you take.");
	RegAdminCmd("sm_setbhopname", OnSetBhopName, ADMFLAG_ROOT, "Sets the name of the bunny hop levels teleport name.");
	RegAdminCmd("sm_setbhopteam", OnSetBhopTeam, ADMFLAG_ROOT, "Sets the team that should have auto bhop forced on them. Use -1 for all teams.");
	
	cvar_autobunnyhopping = FindConVar("sv_autobunnyhopping");
	SetConVarFlags(cvar_autobunnyhopping, GetConVarFlags(cvar_autobunnyhopping) & ~FCVAR_REPLICATED);
}

public Action:Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(IsClientInGame(iClient) && !IsFakeClient(iClient))
			DeactivateAutoBhop(iClient);
	}
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(!g_iForceAutoJumpTeamNum)
		return;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(g_iForceAutoJumpTeamNum == -1 || GetClientTeam(iClient) == g_iForceAutoJumpTeamNum)
			ActivateAutoBhop(iClient);
	}
}

public OnClientDisconnect(iClient)
{
	g_bShowTeleportNames[iClient] = false;
	g_bAutoJumpActivated[iClient] = false;
}

public Action:OnSetBhopName(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgNum != 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_setbhopname \"bhop teleport or destination name\"");
		return Plugin_Handled;
	}
	
	decl String:szName[MAX_VALUE_LENGTH];
	GetCmdArg(1, szName, sizeof(szName));
	TrimString(szName);
	
	if(strlen(szName) < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_setbhopname \"bhop teleport or destination name\"");
		return Plugin_Handled;
	}
	
	SetTriggerName(iClient, szName);
	
	return Plugin_Handled;
}

public Action:OnSetBhopTeam(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(iArgNum != 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_setbhopteam \"team number to force auto bhop on\"");
		return Plugin_Handled;
	}
	
	decl String:szTeamNum[3];
	GetCmdArg(1, szTeamNum, sizeof(szTeamNum));
	TrimString(szTeamNum);
	
	SetForceAutoJumpTeamNum(iClient, StringToInt(szTeamNum));
	
	return Plugin_Handled;
}

public Action:OnTeleportNames(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	g_bShowTeleportNames[iClient] = !g_bShowTeleportNames[iClient];
	
	ReplyToCommand(iClient, "[SM] You will %s see teleports & destination names.", g_bShowTeleportNames[iClient] ? "now" : "no longer");
	
	return Plugin_Handled;
}

public OnTeleportTrigger(const String:szOutput[], iCaller, iActivator, Float:fDelay)
{
	if(!(1 <= iActivator <= MaxClients))
		return;
	
	static String:szName[MAX_VALUE_LENGTH], String:szTarget[MAX_VALUE_LENGTH];
	GetEntPropString(iCaller, Prop_Data, "m_iName", szName, sizeof(szName));
	GetEntPropString(iCaller, Prop_Data, "m_target", szTarget, sizeof(szTarget));
	
	if(g_bShowTeleportNames[iActivator])
	{
		PrintToChat(iActivator, "Teleport:[%s] - Destination:[%s]", szName, szTarget);
	}
	
	if(!g_bMapHasTeleport)
		return;
	
	if(g_bAutoJumpActivated[iActivator])
		return;
	
	if(StrContains(szName, g_szTeleportName) == -1 && StrContains(szTarget, g_szTeleportName) == -1)
		return;
	
	ActivateAutoBhop(iActivator);
}

public ZoneTypeNamed_OnStartTouch(iZoneEnt, iTouchedEnt)
{
	if(!(1 <= iTouchedEnt <= MaxClients))
		return;
	
	if(!IsPlayerAlive(iTouchedEnt))
		return;
	
	static iZoneID;
	iZoneID = GetZoneID(iZoneEnt);
	
	static String:szString[7];
	if(!ZoneManager_GetDataString(iZoneID, 1, szString, sizeof(szString)))
		return;
	
	if(!StrEqual(szString, "mgbhop"))
		return;
	
	ActivateAutoBhop(iTouchedEnt);
}

public OnMapStart()
{
	g_iForceAutoJumpTeamNum = GetForceAutoJumpTeamNum();
	g_bMapHasTeleport = GetTriggerName();
}

GetForceAutoJumpTeamNum()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/bhop_force_teams.txt");
	
	new Handle:kv = CreateKeyValues("BhopTeamNum");
	if(!FileToKeyValues(kv, szBuffer))
	{
		CloseHandle(kv);
		return 0;
	}
	
	decl String:szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	new iTeamNum = KvGetNum(kv, szMapName);
	CloseHandle(kv);
	
	return iTeamNum;
}

bool:SetForceAutoJumpTeamNum(iClient, iTeamNum)
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/bhop_force_teams.txt");
	
	new Handle:kv = CreateKeyValues("BhopTeamNum");
	if(!FileToKeyValues(kv, szBuffer))
	{
		CloseHandle(kv);
		ReplyToCommand(iClient, "[SM] Unable to read in file.");
		return false;
	}
	
	decl String:szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	KvSetNum(kv, szMapName, iTeamNum);
	
	if(!KeyValuesToFile(kv, szBuffer))
	{
		CloseHandle(kv);
		ReplyToCommand(iClient, "[SM] Unable to write value to file.");
		return false;
	}
	
	CloseHandle(kv);
	
	g_iForceAutoJumpTeamNum = iTeamNum;
	
	ReplyToCommand(iClient, "[SM] Successfully added \"%i\" as the forced bhop team.", iTeamNum);
	
	return true;
}

bool:GetTriggerName()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/bhop_triggers.txt");
	
	new Handle:kv = CreateKeyValues("BhopTriggerNames");
	if(!FileToKeyValues(kv, szBuffer))
	{
		CloseHandle(kv);
		return false;
	}
	
	decl String:szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	KvGetString(kv, szMapName, g_szTeleportName, sizeof(g_szTeleportName));
	CloseHandle(kv);
	
	if(StrEqual(g_szTeleportName, ""))
		return false;
	
	return true;
}

bool:SetTriggerName(iClient, const String:szName[])
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/bhop_triggers.txt");
	
	new Handle:kv = CreateKeyValues("BhopTriggerNames");
	if(!FileToKeyValues(kv, szBuffer))
	{
		CloseHandle(kv);
		ReplyToCommand(iClient, "[SM] Unable to read in file.");
		return false;
	}
	
	decl String:szMapName[64];
	GetCurrentMap(szMapName, sizeof(szMapName));
	KvSetString(kv, szMapName, szName);
	
	if(!KeyValuesToFile(kv, szBuffer))
	{
		CloseHandle(kv);
		ReplyToCommand(iClient, "[SM] Unable to write value to file.");
		return false;
	}
	
	CloseHandle(kv);
	
	strcopy(g_szTeleportName, sizeof(g_szTeleportName), szName);
	g_bMapHasTeleport = true;
	
	ReplyToCommand(iClient, "[SM] Successfully added \"%s\" as the bhop level.", szName);
	
	return true;
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	if(g_bAutoJumpActivated[iClient])
		SendConVarValue(iClient, cvar_autobunnyhopping, "1");
	else
		SendConVarValue(iClient, cvar_autobunnyhopping, "0");
	
	SDKHook(iClient, SDKHook_PreThink, OnPreThink);
}

ActivateAutoBhop(iClient)
{
	if(g_bAutoJumpActivated[iClient])
		return;
	
	g_bAutoJumpActivated[iClient] = true;
	SendConVarValue(iClient, cvar_autobunnyhopping, "1");
	
	PrintHintText(iClient, "<font size='28' color='#FF0000'>Auto-jump activated!</font>\n<font size='28' color='#00FF00'>Hold the jump key.</font>");
}

DeactivateAutoBhop(iClient)
{
	g_bAutoJumpActivated[iClient] = false;
	SendConVarValue(iClient, cvar_autobunnyhopping, "0");
}

public Action:OnPreThink(iClient)
{
	if(!g_bAutoJumpActivated[iClient])
	{
		SetConVarBool(cvar_autobunnyhopping, false);
		return Plugin_Continue;
	}
	
	SetConVarBool(cvar_autobunnyhopping, true);
	//TryCapSpeed(iClient, 430.0);
	
	return Plugin_Continue;
}

TryCapSpeed(iClient, Float:fHardCap)
{
	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return;
	
	if(fHardCap <= 0.0)
	{
		TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
		return;
	}
	
	static Float:fVelocity[3], Float:fVerticalVelocity, Float:fSpeed;
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	fVerticalVelocity = fVelocity[2];
	fVelocity[2] = 0.0;
	
	fSpeed = GetVectorLength(fVelocity);
	
	static Float:fSoftCap;
	fSoftCap = fHardCap * 0.8; // The softcap is 80% of the hard cap.
	
	if(fSpeed <= fSoftCap || fSoftCap < 250.0)
		return;
	
	static Float:fPercent[2];
	fPercent[0] = fVelocity[0] / fSpeed;
	fPercent[1] = fVelocity[1] / fSpeed;
	
	// Apply the softcap. Go X% slower than the difference between the current speed and soft cap. Clamp at the soft cap.
	static Float:fReduceSpeed;
	fReduceSpeed = ((fSpeed - fSoftCap) * 0.009);
	fVelocity[0] -= (fReduceSpeed * fPercent[0]);
	fVelocity[1] -= (fReduceSpeed * fPercent[1]);
	
	// Apply the hardcap if needed.
	if(GetVectorLength(fVelocity) > fHardCap)
	{
		fVelocity[0] = fHardCap * fPercent[0];
		fVelocity[1] = fHardCap * fPercent[1];
	}
	
	fVelocity[2] = fVerticalVelocity; // Don't cap vertical velocity.
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fVelocity);
}