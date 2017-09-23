#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block saved message";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Blocks the player saved by messages.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	HookUserMessage(GetUserMessageId("TextMsg"), MsgTextMsg, true);
}

public Action:MsgTextMsg(UserMsg:msg_id, Handle:hBuffer, const iPlayers[], iPlayersNum, bool:bReliable, bool:bInit)
{
	if(!bReliable || !iPlayersNum)
		return Plugin_Continue;
	
	decl String:szMessage[28];
	PbReadString(hBuffer, "params", szMessage, sizeof(szMessage), 0);
	
	if(StrEqual(szMessage, "#Chat_SavePlayer_Saved"))
		return Plugin_Handled;
	
	if(StrEqual(szMessage, "#Chat_SavePlayer_Savior"))
		return Plugin_Handled;
	
	if(StrEqual(szMessage, "#Chat_SavePlayer_Spectator"))
		return Plugin_Handled;
		
	if(StrEqual(szMessage, "#Item_Traded"))
		return Plugin_Handled;
	
	return Plugin_Continue;
}