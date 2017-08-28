#include <sourcemod>
#include <hls_color_chat>
#include "../Includes/ultjb_warden"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Command Roll";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to roll a random number.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fNextRollTime[MAXPLAYERS+1];
new const Float:ROLL_WAIT_TIME = 1.0;


public OnPluginStart()
{
	CreateConVar("ultjb_command_roll_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	RegConsoleCmd("sm_roll", OnRoll);
}

public Action:OnRoll(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(UltJB_Warden_GetWarden() != iClient)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}Error: {olive}You must be the warden to roll.");
		return Plugin_Handled;
	}
	
	new Float:fCurTime = GetEngineTime();
	if(fCurTime < g_fNextRollTime[iClient])
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}Error: {olive}You must wait a second to roll again.");
		return Plugin_Handled;
	}
	
	g_fNextRollTime[iClient] = fCurTime + ROLL_WAIT_TIME;
	
	decl iMax;
	if(iArgCount)
	{
		decl String:szNumber[11];
		GetCmdArg(1, szNumber, sizeof(szNumber));
		iMax = StringToInt(szNumber);
		
		if(iMax < 1)
			iMax = 1;
	}
	else
	{
		iMax = 100;
	}
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}rolled a {lightred}%i {olive}out of {lightred}%i{olive}.", iClient, GetRandomInt(1, iMax), iMax);
	return Plugin_Handled;
}