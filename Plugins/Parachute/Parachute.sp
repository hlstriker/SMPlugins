#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Parachute";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Give players parachutes.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_hCall_EquipParachutePlayer;
new Handle:g_hCall_RemoveParachutePlayer;
new Handle:g_hCall_CanEquipParachute;


public OnPluginStart()
{
	CreateConVar("parachute_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	LoadTranslations("common.phrases");
	
	new Handle:hGameConf = LoadGameConfigFile("parachute.games");
	if(hGameConf == INVALID_HANDLE)
		SetFailState("Could not load gamedata file: parachute.games");
	
	// CanEquipParachute
	StartPrepSDKCall(SDKCall_Entity);
	if(PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CanEquipParachute"))
	{
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		g_hCall_CanEquipParachute = EndPrepSDKCall();
	}
	else
	{
		LogError("Could not find signature for: CanEquipParachute");
	}
	
	// EquipParachutePlayer
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "EquipParachutePlayer"))
	{
		g_hCall_EquipParachutePlayer = EndPrepSDKCall();
	}
	else
	{
		LogError("Could not find signature for: EquipParachutePlayer");
	}
	
	// RemoveParachutePlayer
	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RemoveParachutePlayer"))
	{
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		g_hCall_RemoveParachutePlayer = EndPrepSDKCall();
	}
	else
	{
		LogError("Could not find signature for: RemoveParachutePlayer");
	}
	
	CloseHandle(hGameConf);
	
	RegAdminCmd("sm_giveparachute", Command_GiveParachute, ADMFLAG_BAN, "sm_giveparachute <#steamid|#userid|name> - Gives a player a parachute.");
	RegAdminCmd("sm_removeparachute", Command_RemoveParachute, ADMFLAG_BAN, "sm_removeparachute <#steamid|#userid|name> - Removes a player's parachute.");
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("parachute");
	CreateNative("Parachute_GiveParachute", _Parachute_GiveParachute);
	CreateNative("Parachute_RemoveParachute", _Parachute_RemoveParachute);
	CreateNative("Parachute_HasParachute", _Parachute_HasParachute);
	
	return APLRes_Success;
}

public _Parachute_GiveParachute(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	return GiveParachute(GetNativeCell(1));
}

public _Parachute_RemoveParachute(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	return RemoveParachute(GetNativeCell(1));
}

public _Parachute_HasParachute(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return false;
	}
	
	return HasParachute(GetNativeCell(1));
}

bool:GiveParachute(iClient)
{
	if(HasParachute(iClient))
		return false;
	
	if(g_hCall_EquipParachutePlayer != INVALID_HANDLE)
		SDKCall(g_hCall_EquipParachutePlayer, iClient);
	
	return true;
}

bool:RemoveParachute(iClient)
{
	if(!HasParachute(iClient))
		return false;
	
	if(g_hCall_RemoveParachutePlayer != INVALID_HANDLE)
		SDKCall(g_hCall_RemoveParachutePlayer, iClient);
	
	return true;
}

bool:HasParachute(iClient)
{
	if(g_hCall_CanEquipParachute == INVALID_HANDLE)
		return false;
	
	return (!SDKCall(g_hCall_CanEquipParachute, 0, iClient, false));
}

public Action:Command_GiveParachute(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_giveparachute <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	decl String:szTargetName[MAX_TARGET_LENGTH];
	decl iTargetList[MAXPLAYERS], iTargetCount, bool:tn_is_ml;
	
	new iFlags = COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS;
	if((iTargetCount = ProcessTargetString(szTarget, iClient, iTargetList, MAXPLAYERS, iFlags, szTargetName, sizeof(szTargetName), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	decl iTarget;
	for(new i=0; i<iTargetCount; i++)
	{
		iTarget = iTargetList[i];
		
		if(!GiveParachute(iClient))
			continue;
		
		LogAction(iClient, iTarget, "\"%L\" gave parachute to \"%L\"", iClient, iTarget);
		PrintToChat(iTarget, "[SM] %N gave you a parachute.", iClient);
	}
	
	return Plugin_Handled;
}

public Action:Command_RemoveParachute(iClient, iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_removeparachute <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	decl String:szTargetName[MAX_TARGET_LENGTH];
	decl iTargetList[MAXPLAYERS], iTargetCount, bool:tn_is_ml;
	
	new iFlags = COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS;
	if((iTargetCount = ProcessTargetString(szTarget, iClient, iTargetList, MAXPLAYERS, iFlags, szTargetName, sizeof(szTargetName), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	decl iTarget;
	for(new i=0; i<iTargetCount; i++)
	{
		iTarget = iTargetList[i];
		
		if(!RemoveParachute(iClient))
			continue;
		
		LogAction(iClient, iTarget, "\"%L\" removed parachute from \"%L\"", iClient, iTarget);
		PrintToChat(iTarget, "[SM] %N removed your parachute.", iClient);
	}
	
	return Plugin_Handled;
}