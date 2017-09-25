#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block spam messages";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Blocks many of the spam messages.",
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
	
	static String:szMessage[64], iTemp;
	PbReadString(hBuffer, "params", szMessage, sizeof(szMessage), 0);
	
	if(StrEqual(szMessage, "#Item_Traded"))
		return Plugin_Handled;
	
	// #Chat_SavePlayer_Saved, #Chat_SavePlayer_Savior, #Chat_SavePlayer_Spectator
	iTemp = szMessage[16];
	szMessage[16] = '\x00';
	
	if(StrEqual(szMessage, "#Chat_SavePlayer"))
		return Plugin_Handled;
	
	szMessage[16] = iTemp;
	
	// #Player_Cash_Award_ExplainSuicide_YouGotCash, #Player_Cash_Award_ExplainSuicide_TeammateGotCash, #Player_Cash_Award_ExplainSuicide_TeammateGotCash, #Player_Cash_Award_ExplainSuicide_Spectators
	iTemp = szMessage[33];
	szMessage[33] = '\x00';
	
	if(StrEqual(szMessage, "#Player_Cash_Award_ExplainSuicide"))
		return Plugin_Handled;
	
	szMessage[33] = iTemp;
	
	return Plugin_Continue;
}