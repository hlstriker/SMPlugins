#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = "Radio Spam Block",
	author = "hlstriker",
	description = "Blocks radio command spam",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fNextRadioCommand[MAXPLAYERS+1];
const RADIO_COMMAND_DELAY = 5;

public OnPluginStart()
{
	CreateConVar("hls_radiospam_version", PLUGIN_VERSION, "Radio Spam Block Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	AddCommandListener(Command_Radio, "coverme");
	AddCommandListener(Command_Radio, "takepoint");
	AddCommandListener(Command_Radio, "holdpos");
	AddCommandListener(Command_Radio, "regroup");
	AddCommandListener(Command_Radio, "followme");
	AddCommandListener(Command_Radio, "takingfire");
	AddCommandListener(Command_Radio, "go");
	AddCommandListener(Command_Radio, "fallback");
	AddCommandListener(Command_Radio, "sticktog");
	AddCommandListener(Command_Radio, "getinpos");
	AddCommandListener(Command_Radio, "stormfront");
	AddCommandListener(Command_Radio, "report");
	AddCommandListener(Command_Radio, "roger");
	AddCommandListener(Command_Radio, "enemyspot");
	AddCommandListener(Command_Radio, "needbackup");
	AddCommandListener(Command_Radio, "sectorclear");
	AddCommandListener(Command_Radio, "inposition");
	AddCommandListener(Command_Radio, "reportingin");
	AddCommandListener(Command_Radio, "getout");
	AddCommandListener(Command_Radio, "negative");
	AddCommandListener(Command_Radio, "enemydown");
	AddCommandListener(Command_Radio, "cheer");
	AddCommandListener(Command_Radio, "compliment");
	AddCommandListener(Command_Radio, "thanks");
}

public OnClientDisconnect(iClient)
{
	g_fNextRadioCommand[iClient] = 0.0;
}

public Action:Command_Radio(iClient, const String:szCommand[], iArgCount)
{
	if(!IsClientInGame(iClient))
		return Plugin_Handled;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(g_fNextRadioCommand[iClient] > fCurTime)
	{
		PrintToChat(iClient, "[SM] Wait %.02f seconds to play another radio command.", g_fNextRadioCommand[iClient] - fCurTime);
		return Plugin_Handled;
	}
	
	g_fNextRadioCommand[iClient] = fCurTime + RADIO_COMMAND_DELAY;
	
	return Plugin_Continue;
}