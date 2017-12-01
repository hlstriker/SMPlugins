#include <sourcemod>
#include <hls_color_chat>
#include "../Includes/ultjb_warden"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Countdown Timer";
new const String:PLUGIN_VERSION[] = "1.0";

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


public OnPluginStart()
{
	CreateConVar("ultjb_command_timer_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	RegConsoleCmd("sm_timer", OnTimer, "[Usage] sm_timer <seconds> - Starts a countdown timer");
	
	HookEvent("round_end", Event_RoundEnd);
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

StartTimer_Countdown()
{
	g_iTimerCountdown = 0;
	ShowCountdown();
	
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
	
	PrintHintTextToAll("<font color='#6FC41A'>Countdown Complete!</font>");
	
	return Plugin_Stop;
}