#include <sourcemod>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Magic target filter";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Filters magic targeting for admin commands.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define COMMAND_TEXT_LEN 45
#define MAX_COMMANDS_IN_CONFIG_FILE 512

new String:g_szCommandsAllowed[MAX_COMMANDS_IN_CONFIG_FILE][COMMAND_TEXT_LEN+1];
new g_iNumCommandsAllowed;

new const String:g_szMagicTargetsToFilter[][] =
{
	// General
	"@all",
	"@bots",
	"@humans",
	"@alive",
	"@dead",
	"@!me",
	
	// Counter-Strike
	"@ct",
	"@cts",
	"@t",
	"@ts",
	
	// Team Fortress 2
	"@red",
	"@blue"
};


public OnPluginStart()
{
	CreateConVar("magic_target_filter_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	AddCommandListener(GlobalCommandListener, "");
}

public Action:GlobalCommandListener(iClient, const String:szCommand[], iArgCount)
{
	// If the server is issuing the command allow it.
	if(!iClient)
		return Plugin_Continue;
	
	// Use -1 as the flag (flag is used if admin command isn't found). Since the global listener listens for non-admin commands as well, this will filter those commands out.
	if(!CheckCommandAccess(iClient, szCommand, -1))
		return Plugin_Continue;
	
	// There are no args (which means no magic target) so allow it.
	if(iArgCount < 1)
		return Plugin_Continue;
	
	// Allow if this command is in the allowed array.
	static i;
	for(i=0; i<g_iNumCommandsAllowed; i++)
	{
		if(StrEqual(szCommand, g_szCommandsAllowed[i]))
			return Plugin_Continue;
	}
	
	// Check to see if the first arg is a blocked magic target.
	static String:szArgString[12], String:szFirstArg[12];
	GetCmdArgString(szArgString, sizeof(szArgString));
	
	if(SplitString(szArgString, " ", szFirstArg, sizeof(szFirstArg)) == -1)
		strcopy(szFirstArg, sizeof(szFirstArg), szArgString);
	
	for(i=0; i<sizeof(g_szMagicTargetsToFilter); i++)
	{
		// Note: Magic targets themselves are case sensitive as lowercase in SourceMod itself, so don't check sensitivity variations in StrEqual().
		if(StrEqual(szFirstArg, g_szMagicTargetsToFilter[i]))
		{
			ReplyToCommand(iClient, "[SM] You cannot use the \"%s\" magic target for \"%s\".", g_szMagicTargetsToFilter[i], szCommand);
			return Plugin_Stop;
		}
	}
	
	// The first arg wasn't a blocked magic target so allow.
	return Plugin_Continue;
}

public OnMapStart()
{
	g_iNumCommandsAllowed = 0;
	LoadAllowedCommands();
}

bool:LoadAllowedCommands()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/swoobles/magic_target_commands_allowed.txt");
	
	new Handle:hFile = OpenFile(szBuffer, "r");
	if(hFile == INVALID_HANDLE)
		return false;
	
	while(!IsEndOfFile(hFile))
	{
		if(!ReadFileLine(hFile, szBuffer, sizeof(szBuffer)))
			continue;
		
		TrimString(szBuffer);
		
		if(strlen(szBuffer) < 3)
			continue;
		
		if((szBuffer[0] == '/' && szBuffer[1] == '/') || szBuffer[0] == '#')
			continue;
		
		if(g_iNumCommandsAllowed >= MAX_COMMANDS_IN_CONFIG_FILE)
		{
			LogError("The allowed array is full. If you want to add more commands please recompile the plugin.");
			break;
		}
		
		strcopy(g_szCommandsAllowed[g_iNumCommandsAllowed], sizeof(g_szCommandsAllowed[]), szBuffer);
		g_iNumCommandsAllowed++;
	}
	
	CloseHandle(hFile);
	return true;
}