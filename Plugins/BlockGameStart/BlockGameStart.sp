#include <sourcemod>
#include <cstrike>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block game start";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Blocks the game start OnTerminateRound reason.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public Action:CS_OnTerminateRound(&Float:fDelay, &CSRoundEndReason:reason)
{
	if(reason == CSRoundEnd_GameStart)
		return Plugin_Handled;
	
	return Plugin_Continue;
}