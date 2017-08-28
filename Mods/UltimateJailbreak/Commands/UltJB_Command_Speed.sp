#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB]  Command Speed";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("ultjb_command_speed_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_speed", Command_Speed, ADMFLAG_KICK, "sm_speed <#steamid|#userid|name> <0.0 to 10.0> - Sets a players speed.");
}

public Action:Command_Speed(iClient, iArgs)
{
	if(iArgs < 2)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_speed <#steamid|#userid|name> <0.0 to 10.0>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(2, szTarget, sizeof(szTarget));
	
	new Float:fValue = StringToFloat(szTarget);
	if(fValue < 0.0 || fValue > 10.0)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_speed <#steamid|#userid|name> <0.0 to 10.0>");
		return Plugin_Handled;
	}
	
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	decl String:szTargetName[MAX_TARGET_LENGTH];
	decl iTargetList[MAXPLAYERS], iTargetCount, bool:tn_is_ml;
	
	new iFlags = COMMAND_FILTER_ALIVE;
	if((iTargetCount = ProcessTargetString(szTarget, iClient, iTargetList, MAXPLAYERS, iFlags, szTargetName, sizeof(szTargetName), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	decl iTarget;
	for(new i=0; i<iTargetCount; i++)
	{
		iTarget = iTargetList[i];
		
		SetSpeed(iTarget, fValue);
		PrintToChatAll("%N's speed has been set to %.02f by %N.", iTarget, fValue, iClient);
		LogAction(iClient, iTarget, "\"%L\" set speed \"%L\" (speed \"%.02f\")", iClient, iTarget, fValue);
	}
	
	return Plugin_Handled;
}

SetSpeed(iClient, Float:fValue)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flLaggedMovementValue", fValue);
}