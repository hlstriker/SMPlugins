#include <sourcemod>
#include <hls_color_chat>
#include <sdktools_stringtables>
#include <emitsoundany>
#include "../Includes/ultjb_warden"
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Countdown Timer";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "RussianLightning",
	description = "Allows warden to display a countdown timer.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new g_iCountdown;
new g_iTimerCountdown;
new Handle:g_hTimer_Countdown;

new const String:SOUND_TIMER_COMPLETE[] = "sound/buttons/weapon_cant_buy.wav";


public OnPluginStart()
{
	CreateConVar("ultjb_command_timer_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	RegConsoleCmd("sm_timer", OnTimer, "[Usage] sm_timer <seconds> - Starts a countdown timer");
	RegConsoleCmd("sm_stoptimer", OnStopTimer, "[Usage] sm_stoptimer - Stops the countdown timer.");
	
	HookEvent("round_end", Event_RoundEnd);
}

public OnMapStart()
{
	AddFileToDownloadsTable(SOUND_TIMER_COMPLETE);
	PrecacheSoundAny(SOUND_TIMER_COMPLETE[6]);
}

public Action:Event_RoundEnd(Handle:event,const String:name[],bool:dontBroadcast)
{
	StopTimer_Countdown();
	return Plugin_Handled;
}

public Action:OnTimer(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(UltJB_Warden_GetWarden() != iClient)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}Error: {olive}You must be the warden to use the timer.");
		return Plugin_Handled;
	}
	
	if(UltJB_Day_IsInProgress())
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}Error: {olive}You cannot use the timer if a day is in progress.");
		return Plugin_Handled;
	}
	
	if(iArgCount)
	{
		decl String:szNumber[11];
		GetCmdArg(1, szNumber, sizeof(szNumber));
		g_iCountdown = StringToInt(szNumber);
		
		if(g_iCountdown <= 0)
		{
			ReplyToCommand(iClient, "[SM] Please enter a valid number greater than 0.");
			return Plugin_Handled;
		}
		
		if(g_iCountdown < 10 && g_iCountdown > 0)
			g_iCountdown = 10;
			
		if(g_iCountdown > 180)
			g_iCountdown = 180;
			
		StartTimer_Countdown();
	}
	else
	{
		ReplyToCommand(iClient, "[SM] Please enter a time.");
	}
	
	return Plugin_Handled;
}

public Action:OnStopTimer(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(UltJB_Warden_GetWarden() != iClient)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {lightred}Error: {olive}You must be the warden to stop the timer.");
		return Plugin_Handled;
	}
	
	if(g_hTimer_Countdown != INVALID_HANDLE)
	{
		StopTimer_Countdown();
		CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}The timer has been stopped.");
	}
	else
	{
		ReplyToCommand(iClient, "[SM] There is no timer running.");
	}
	
	return Plugin_Handled;
}

StartTimer_Countdown()
{
	g_iTimerCountdown = 0;
	ShowCountdown();
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}The timer has started for {lightred}%i {olive}seconds.", g_iCountdown - g_iTimerCountdown);
	
	StopTimer_Countdown();
	g_hTimer_Countdown = CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT);
}

StopTimer_Countdown()
{
	if(g_hTimer_Countdown == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Countdown);
	g_hTimer_Countdown = INVALID_HANDLE;
}

ShowCountdown()
{
	PrintHintTextToAll("<font color='#6FC41A'>Countdown Timer:</font>\n<font color='#DE2626'>%i</font> <font color='#6FC41A'>seconds.</font>", g_iCountdown - g_iTimerCountdown);
}

public Action:Timer_Countdown(Handle:hTimer)
{
	g_iTimerCountdown++;
	
	if(UltJB_LR_CanLastRequest())
	{
		g_hTimer_Countdown = INVALID_HANDLE;
		PrintHintTextToAll("<font color='#DE2626'>Countdown Stopped due to LR!</font>");
		return Plugin_Stop;
	}
	
	if(UltJB_Day_IsInProgress())
	{
		g_hTimer_Countdown = INVALID_HANDLE;
		PrintHintTextToAll("<font color='#DE2626'>Countdown Stopped due to a day starting!</font>");
		return Plugin_Stop;
	}
	
	if(((g_iCountdown - g_iTimerCountdown) % 10) == 0)
	{
		CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}There are {olive}%i {lightred}seconds left on the countdown.", g_iCountdown - g_iTimerCountdown);
	}
	
	if(g_iTimerCountdown < g_iCountdown)
	{
		ShowCountdown();
		return Plugin_Continue;
	}
	
	g_hTimer_Countdown = INVALID_HANDLE;
	
	EmitSoundToAllAny(SOUND_TIMER_COMPLETE[6], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS);
	
	PrintHintTextToAll("<font color='#6FC41A'>Countdown Complete!</font>");
	
	return Plugin_Stop;
}