#include <sourcemod>
#include <basecomm>
#include <regex>
#include "../SquelchManager/squelch_manager"
#include "player_chat"

#undef REQUIRE_PLUGIN
#include "../../Plugins/DonatorItems/Titles/donatoritem_titles"
#include "../../Plugins/DonatorItems/ColoredChat/donatoritem_colored_chat"
#include "../../Mods/UltimateJailbreak/Includes/ultjb_warden"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Player Chat";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage players chat.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SOURCEMOD_CORE_CONFIG[] = "configs/core.cfg";

new String:g_szSilentChatTrigger[12];
new bool:g_bHasSilentChatTrigger;
new bool:g_bSilentFailSuppress;

enum
{
	MODE_SPECALL = 0,	// Used "say" while in spec.
	MODE_SPECTEAM,		// Used "say_team" while in spec.
	
	MODE_ALL,			// Used "say" while alive.
	MODE_TEAM2ALIVE,	// Used "say_team" while alive on T.
	MODE_TEAM3ALIVE,	// Used "say_team" while alive on CT.
	
	MODE_ALLDEAD,		// Used "say" while dead.
	MODE_TEAM2DEAD,		// Used "say_team" while dead on T.
	MODE_TEAM3DEAD,		// Used "say_team" while dead on CT.
	
	NUM_CHAT_MODES,
	MODE_NONE
};

enum
{
	TEAM_NONE = 0,
	TEAM_SPEC,
	TEAM_2,
	TEAM_3,
	
	NUM_TEAMS
};

#if !defined _donatoritem_titles_included
#define MAX_TITLE_LENGTH	16
#endif

#define MAX_MESSAGE_LENGTH	256
#define TEAM_NAME_LENGTH	20
new String:g_szTeamNames[NUM_TEAMS][TEAM_NAME_LENGTH];

new Handle:cvar_disable_message_display;
new Handle:cvar_sv_deadtalk;
new Handle:cvar_sm_flood_time;
new Handle:cvar_sm_chat_mode;
new Float:g_fLastMessageSent[MAXPLAYERS+1];

new Handle:g_hFwd_OnMessage;

new bool:g_bHasCustomTitle[MAXPLAYERS+1];
new String:g_szCustomTitle[MAXPLAYERS+1][MAX_TITLE_LENGTH+1];

new bool:g_bLibLoaded_UltJBWarden;
new bool:g_bLibLoaded_ItemTitles;
new bool:g_bLibLoaded_ItemColoredChat;


public OnPluginStart()
{
	CreateConVar("api_player_chat_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	if(!LoadGameVariables())
	{
		SetFailState("Game not supported.");
		return;
	}
	
	cvar_disable_message_display = CreateConVar("playerchat_disable_message_display", "0", "Should message display be disabled?", _, true, 0.0, true, 1.0);
	
	cvar_sm_flood_time = FindConVar("sm_flood_time");
	if(cvar_sm_flood_time == INVALID_HANDLE)
		cvar_sm_flood_time = CreateConVar("sm_flood_time", "0.75", "Amount of time allowed between chat messages");
	
	cvar_sv_deadtalk = FindConVar("sv_deadtalk");
	if(cvar_sv_deadtalk == INVALID_HANDLE)
		cvar_sv_deadtalk = CreateConVar("sv_deadtalk", "1", "Dead players can type to the living");
	
	cvar_sm_chat_mode = FindConVar("sm_chat_mode");
	if(cvar_sm_chat_mode == INVALID_HANDLE)
		cvar_sm_chat_mode = CreateConVar("sm_chat_mode", "1", "Specifies whether or not non-admins can send messages to admins using say_team @<message>. Valid values are 0 (Disabled) or 1 (Enabled)", _, true, 0.0, true, 1.0);
	
	g_hFwd_OnMessage = CreateGlobalForward("PlayerChat_OnMessage", ET_Event, Param_Cell, Param_Cell, Param_String);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_UltJBWarden = LibraryExists("ultjb_warden");
	g_bLibLoaded_ItemTitles = LibraryExists("donatoritem_titles");
	g_bLibLoaded_ItemColoredChat = LibraryExists("donatoritem_colored_chat");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "ultjb_warden"))
	{
		g_bLibLoaded_UltJBWarden = true;
	}
	else if(StrEqual(szName, "donatoritem_titles"))
	{
		g_bLibLoaded_ItemTitles = true;
	}
	else if(StrEqual(szName, "donatoritem_colored_chat"))
	{
		g_bLibLoaded_ItemColoredChat = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "ultjb_warden"))
	{
		g_bLibLoaded_UltJBWarden = false;
	}
	else if(StrEqual(szName, "donatoritem_titles"))
	{
		g_bLibLoaded_ItemTitles = false;
	}
	else if(StrEqual(szName, "donatoritem_colored_chat"))
	{
		g_bLibLoaded_ItemColoredChat = false;
	}
}

bool:LoadGameVariables()
{
	decl String:szGameDir[8];
	GetGameFolderName(szGameDir, sizeof(szGameDir));
	
	if(StrEqual(szGameDir, "cstrike") || StrEqual(szGameDir, "csgo"))
	{
		g_szTeamNames[TEAM_SPEC] = "(Spectator)";
		g_szTeamNames[TEAM_2] = "(Terrorist)";
		g_szTeamNames[TEAM_3] = "(Counter-Terrorist)";
		
		return true;
	}
	
	return false;
}

public OnConfigsExecuted()
{
	decl String:szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), SOURCEMOD_CORE_CONFIG);
	
	new Handle:fp = OpenFile(szBuffer, "r");
	if(fp == INVALID_HANDLE)
		SetFailState("Could not open configs/core.cfg file.");
	
	new Handle:hRegSilentChatTrigger = CompileRegex(".*?\"SilentChatTrigger\".*?\"(.*?)\"", PCRE_CASELESS);
	new Handle:hRegSilentFailSuppress = CompileRegex(".*?\"SilentFailSuppress\".*?\"(.*?)\"", PCRE_CASELESS);
	
	while(!IsEndOfFile(fp))
	{
		ReadFileLine(fp, szBuffer, sizeof(szBuffer));
		
		if(MatchRegex(hRegSilentChatTrigger, szBuffer) > 1)
		{
			GetRegexSubString(hRegSilentChatTrigger, 1, g_szSilentChatTrigger, sizeof(g_szSilentChatTrigger));
			
			if(g_szSilentChatTrigger[0])
				g_bHasSilentChatTrigger = true;
			else
				g_bHasSilentChatTrigger = false;
			
			continue;
		}
		
		if(MatchRegex(hRegSilentFailSuppress, szBuffer) > 1)
		{
			GetRegexSubString(hRegSilentFailSuppress, 1, szBuffer, sizeof(szBuffer));
			
			if(StrEqual(szBuffer, "yes", false))
				g_bSilentFailSuppress = true;
			else
				g_bSilentFailSuppress = false;
			
			continue;
		}
	}
	
	CloseHandle(hRegSilentChatTrigger);
	CloseHandle(hRegSilentFailSuppress);
	CloseHandle(fp);
}

public OnClientPutInServer(iClient)
{
	g_fLastMessageSent[iClient] = 0.0;
}

public Action:OnClientSayCommand(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!iClient)
		return Plugin_Continue;
	
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	static Float:fCurTime;
	fCurTime = GetGameTime();
	
	if((g_fLastMessageSent[iClient] + GetConVarFloat(cvar_sm_flood_time)) > fCurTime)
		return Plugin_Handled;
	
	g_fLastMessageSent[iClient] = fCurTime;
	
	if(BaseComm_IsClientGagged(iClient))
		return Plugin_Continue;
	
	if(!strlen(szArgs))
		return Plugin_Handled;
	
	static ChatType:iChatType;
	if(strlen(szCommand) == 3)
		iChatType = CHAT_TYPE_ALL;
	else
		iChatType = CHAT_TYPE_TEAM;
	
	if(!TrySendMessage(iClient, iChatType, szArgs))
		return Plugin_Continue;
	
	return Plugin_Handled;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("player_chat");
	
	CreateNative("PlayerChat_SetCustomTitle", _PlayerChat_SetCustomTitle);
	CreateNative("PlayerChat_ClearCustomTitle", _PlayerChat_ClearCustomTitle);
	
	return APLRes_Success;
}

public _PlayerChat_SetCustomTitle(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters _PlayerChat_SetCustomTitle().");
		return;
	}
	
	new iClient = GetNativeCell(1);
	
	GetNativeString(2, g_szCustomTitle[iClient], sizeof(g_szCustomTitle[]));
	g_bHasCustomTitle[iClient] = true;
}

public _PlayerChat_ClearCustomTitle(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters _PlayerChat_ClearCustomTitle().");
		return;
	}
	
	g_bHasCustomTitle[GetNativeCell(1)] = false;
}

bool:TrySendMessage(iSender, ChatType:iSendType, const String:szArgs[])
{
	// Check the @ before trimming.
	new bool:bFirstIsAt = (szArgs[0] == '@');
	
	static String:szMessage[MAX_MESSAGE_LENGTH];
	strcopy(szMessage, sizeof(szMessage), szArgs);
	
	TrimString(szMessage);
	if(!strlen(szMessage))
		return true;
	
	new Action:iReturn;
	Call_StartForward(g_hFwd_OnMessage);
	Call_PushCell(iSender);
	Call_PushCell(iSendType);
	Call_PushString(szMessage);
	Call_Finish(iReturn);
	
	if(iReturn != Plugin_Continue)
		return true;
	
	if(GetConVarBool(cvar_disable_message_display))
		return true;
	
	if(bFirstIsAt)
	{
		if(iSendType == CHAT_TYPE_ALL)
		{
			if(CheckCommandAccess(iSender, "sm_say", ADMFLAG_CHAT))
				return true;
		}
		else if(iSendType == CHAT_TYPE_TEAM)
		{
			if(GetConVarBool(cvar_sm_chat_mode) || CheckCommandAccess(iSender, "sm_chat", ADMFLAG_CHAT))
				return true;
		}
	}
	
	if(g_bHasSilentChatTrigger)
	{
		new bool:bIsSilentTrigger = true;
		for(new i=0; i<strlen(g_szSilentChatTrigger); i++)
		{
			if(g_szSilentChatTrigger[i] == szMessage[i])
				continue;
			
			bIsSilentTrigger = false;
			break;
		}
		
		if(IsChatTrigger() && bIsSilentTrigger)
			return false;
		
		if(g_bSilentFailSuppress && bIsSilentTrigger)
			return false;
	}
	
	new iChatMode = GetChatMode(iSender, iSendType);
	if(iChatMode == MODE_NONE)
		return false;
	
	new bool:bSenderIsJailbreakWarden;
	
	if(g_bLibLoaded_UltJBWarden)
	{
		#if defined _ultjb_warden_included
		if(iSender == UltJB_Warden_GetWarden())
			bSenderIsJailbreakWarden = true;
		#endif
	}
	
	// Get clients to send message to based on the chat mode.
	static iClients[MAXPLAYERS];
	new iNumClients;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!ShouldSendToClient(iClient, iChatMode))
			continue;
		
		if(SquelchManager_IsClientGaggingTarget(iClient, iSender))
		{
			// Continue as long as the sender isn't the warden. Warden should bypass any !sg
			if(!bSenderIsJailbreakWarden)
				continue;
		}
		
		iClients[iNumClients++] = iClient;
	}
	
	StripIllegalBytes(szMessage);
	FormatMessage(iSender, iChatMode, szMessage);
	
	SendMessage(iSender, szMessage, iClients, iNumClients);
	SendMessageToConsoles(szMessage, iClients, iNumClients);
	
	return true;
}

FormatMessage(iSender, iChatMode, String:szMessage[MAX_MESSAGE_LENGTH])
{
	static String:szSenderName[32];
	GetClientName(iSender, szSenderName, sizeof(szSenderName));
	
	new String:szPrefixOne[7], String:szPrefixTwo[TEAM_NAME_LENGTH], bool:bHasPrefix;
	switch(iChatMode)
	{
		case MODE_SPECALL:
		{
			szPrefixOne = "*SPEC*";
			bHasPrefix = true;
		}
		
		case MODE_SPECTEAM:
		{
			szPrefixTwo = g_szTeamNames[TEAM_SPEC];
			bHasPrefix = true;
		}
		
		case MODE_TEAM2ALIVE:
		{
			szPrefixTwo = g_szTeamNames[TEAM_2];
			bHasPrefix = true;
		}
		
		case MODE_TEAM3ALIVE:
		{
			szPrefixTwo = g_szTeamNames[TEAM_3];
			bHasPrefix = true;
		}
		
		case MODE_ALLDEAD:
		{
			szPrefixOne = "*DEAD*";
			bHasPrefix = true;
		}
		
		case MODE_TEAM2DEAD:
		{
			szPrefixOne = "*DEAD*";
			szPrefixTwo = g_szTeamNames[TEAM_2];
			bHasPrefix = true;
		}
		
		case MODE_TEAM3DEAD:
		{
			szPrefixOne = "*DEAD*";
			szPrefixTwo = g_szTeamNames[TEAM_3];
			bHasPrefix = true;
		}
	}
	
	static String:szTitle[MAX_TITLE_LENGTH+1], bool:bHasTitle, String:szTitleBracket1[4], String:szTitleBracket2[3];
	
	if(g_bHasCustomTitle[iSender])
	{
		strcopy(szTitle, sizeof(szTitle), g_szCustomTitle[iSender]);
		bHasTitle = true;
		
		szTitleBracket1 = "\x01[\x0E";
		szTitleBracket2 = "\x01]";
	}
	else
	{
		if(g_bLibLoaded_ItemTitles)
		{
			#if defined _donatoritem_titles_included
			bHasTitle = DItemTitles_GetTitle(iSender, szTitle, sizeof(szTitle));
			#else
			bHasTitle = false;
			#endif
		}
		else
		{
			bHasTitle = false;
		}
		
		szTitleBracket1 = "\x02[\x04";
		szTitleBracket2 = "\x02]";
	}
	
	decl iColorChatByte;
	
	if(g_bLibLoaded_ItemColoredChat)
	{
		#if defined _donatoritem_colored_chat_included
		iColorChatByte = DItemColoredChat_GetColorByte(iSender);
		#else
		iColorChatByte = 0;
		#endif
	}
	else
	{
		iColorChatByte = 0;
	}
	
	if(!iColorChatByte)
		iColorChatByte = 0x01;
	
	Format(szMessage, sizeof(szMessage), " %s%s%s%s%s%s%s\x03%s : %c%s", szPrefixOne, szPrefixTwo, (bHasPrefix ? " " : ""), (bHasTitle ? szTitleBracket1 : ""), (bHasTitle ? szTitle : ""), (bHasTitle ? szTitleBracket2 : ""), (bHasTitle ? " " : ""), szSenderName, iColorChatByte, szMessage);
}

GetChatMode(iSender, ChatType:iSendType)
{
	if(IsPlayerAlive(iSender))
	{
		// Check alive modes.
		if(iSendType == CHAT_TYPE_ALL)
			return MODE_ALL;
		
		switch(GetClientTeam(iSender))
		{
			case 2: return MODE_TEAM2ALIVE;
			case 3: return MODE_TEAM3ALIVE;
		}
	}
	else
	{
		// Check dead modes.
		switch(GetClientTeam(iSender))
		{
			case 1:
			{
				if(iSendType == CHAT_TYPE_ALL)
					return MODE_SPECALL;
				
				return MODE_SPECTEAM;
			}
			case 2:
			{
				if(iSendType == CHAT_TYPE_ALL)
					return MODE_ALLDEAD;
				
				return MODE_TEAM2DEAD;
			}
			case 3:
			{
				if(iSendType == CHAT_TYPE_ALL)
					return MODE_ALLDEAD;
				
				return MODE_TEAM3DEAD;
			}
		}
	}
	
	return MODE_NONE;
}

bool:ShouldSendToClient(iClient, iChatMode)
{
	if(!IsClientInGame(iClient))
		return false;
	
	if(IsClientSourceTV(iClient))
		return true;
	
	if(IsFakeClient(iClient))
		return false;
	
	switch(iChatMode)
	{
		// Send to everyone that's dead. Also send to the living if dead talk is enabled.
		case MODE_SPECALL:
			if(GetConVarBool(cvar_sv_deadtalk) || !IsPlayerAlive(iClient))
				return true;
		
		// Send to everyone in spec or unassigned.
		case MODE_SPECTEAM:
			if(GetClientTeam(iClient) < 2)
				return true;
		
		// Send to everyone.
		case MODE_ALL:
			return true;
		
		// Send to everyone that's on team 2.
		case MODE_TEAM2ALIVE:
			if(GetClientTeam(iClient) == 2)
				return true;
		
		// Send to everyone that's on team 3.
		case MODE_TEAM3ALIVE:
			if(GetClientTeam(iClient) == 3)
				return true;
		
		// Send to everyone that's dead. Also send to the living if dead talk is enabled.
		case MODE_ALLDEAD:
			if(GetConVarBool(cvar_sv_deadtalk) || !IsPlayerAlive(iClient))
				return true;
		
		// Send to everyone that's dead on team 2.
		case MODE_TEAM2DEAD:
		{
			if(GetClientTeam(iClient) == 2)
			{
				if(!IsPlayerAlive(iClient))
					return true;
				
				// Also send to alive if dead talk is enabled.
				if(GetConVarBool(cvar_sv_deadtalk))
					return true;
			}
		}
		
		// Send to everyone that's dead on team 3.
		case MODE_TEAM3DEAD:
		{
			if(GetClientTeam(iClient) == 3)
			{
				if(!IsPlayerAlive(iClient))
					return true;
				
				// Also send to alive if dead talk is enabled.
				if(GetConVarBool(cvar_sv_deadtalk))
					return true;
			}
		}
	}
	
	return false;
}

StripIllegalBytes(String:szMessage[])
{
	for(new i=0; i<strlen(szMessage); i++)
	{
		if(szMessage[i] == '\x01'
		|| szMessage[i] == '\x02'
		|| szMessage[i] == '\x03'
		|| szMessage[i] == '\x04'
		|| szMessage[i] == '\x05'
		|| szMessage[i] == '\x06'
		|| szMessage[i] == '\x07'
		|| szMessage[i] == '\x08'
		|| szMessage[i] == '\x09'
		|| szMessage[i] == '\x0A'
		|| szMessage[i] == '\x0B'
		|| szMessage[i] == '\x0C'
		|| szMessage[i] == '\x0D'
		|| szMessage[i] == '\x0E'
		|| szMessage[i] == '\x0F'
		|| szMessage[i] == '\n')
		{
			szMessage[i] = ' ';
		}
	}
}

SendMessage(iSender, const String:szMessage[], iClients[], iNumClients)
{
	new Handle:hBuffer = StartMessage("SayText", iClients, iNumClients, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	if(hBuffer == INVALID_HANDLE)
		return;
	
	PbSetInt(hBuffer, "ent_idx", iSender);
	PbSetBool(hBuffer, "chat", true);
	PbSetString(hBuffer, "text", szMessage);
	
	EndMessage();
}

SendMessageToConsoles(String:szMessage[], iClients[], iNumClients)
{
	StripIllegalBytes(szMessage);
	PrintToServer(szMessage);
	
	for(new i=0; i<iNumClients; i++)
		PrintToConsole(iClients[i], szMessage);
}