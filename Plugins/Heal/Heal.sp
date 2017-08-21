#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Heal";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianRonin",
	description = "Heals a player to full",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart() {
	RegAdminCmd("sm_heal", Command_Heal, ADMFLAG_ROOT, "sm_heal <#steamid|#userid|name> - Heals a player to 100 health.");
}

public Action:Command_Heal(iClient, iArgs) {
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_heal <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, false, false);
	
	if(iTarget == -1)
		return Plugin_Handled;
	
	if(GetClientHealth(iTarget) != 100) {
		SetEntityHealth(iTarget, 100);
		PrintToChat(iClient, "[SM] You have healed %N to full health.", iTarget);
		PrintToChat(iTarget, "[SM] You have been healed to full health by %N", iClient);
	} else {
		PrintToChat(iClient, "[SM] %N is already at full health.", iTarget);
	}
	
	return Plugin_Handled;
}