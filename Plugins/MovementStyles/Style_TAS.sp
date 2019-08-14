#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"
#include "../../Libraries/Replays/replays"
#include "../../Mods/SpeedRuns/Includes/speed_runs"
#include "../AutoBhop/auto_bhop"
#include "../AutoStrafe/auto_strafe"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: TAS";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = PLUGIN_NAME,
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_TAS
#define THIS_STYLE_NAME			"TAS"
#define THIS_STYLE_NAME_AUTO	"TAS"
#define THIS_STYLE_ORDER		1

new bool:g_bActivated[MAXPLAYERS+1];

new bool:g_bAllowMouse[MAXPLAYERS + 1];
new bool:g_bMouseControl[MAXPLAYERS + 1];


enum
{
	MENUSELECT_PAUSE = 1,
	MENUSELECT_RESUME,
	MENUSELECT_REWIND,
	MENUSELECT_AUTO_STRAFE,
	MENUSELECT_ALLOW_MOUSE
};

public OnPluginStart()
{
	CreateConVar("style_tas_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);

	RegConsoleCmd("sm_tas", OnTAS);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, "");
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
	g_bMouseControl[iClient] = false;
	AutoBhop_SetEnabled(iClient, true);
	AutoStrafe_SetEnabled(iClient, true);

	CPrintToChat(iClient, "{blue}[TAS] {default} Type !tas to open the menu");
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
	Replays_SetMode(iClient, REPLAY_RECORD);
	AutoBhop_SetEnabled(iClient, false);
	AutoStrafe_SetEnabled(iClient, false);
}

public SpeedRuns_OnStageStarted_Post(iClient, iStageNumber, iStyleBits)
{
	if (iStageNumber != 0)
		return;
}

public Action:OnTAS(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;

	if (g_bActivated[iClient])
	{
		DisplayMenu_TAS(iClient);
	}
	else
	{
		CPrintToChat(iClient, "{blue}[TAS] {default} Turn on the TAS style to use the menu");
	}

	return Plugin_Continue;
}

DisplayMenu_TAS(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_TAS);
	SetMenuTitle(hMenu, "Tool Assisted Speedrun");

	decl String:szInfo[4];
	IntToString(MENUSELECT_PAUSE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Pause");

	IntToString(MENUSELECT_RESUME, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Resume");

	IntToString(MENUSELECT_REWIND, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Rewind");

	IntToString(MENUSELECT_ALLOW_MOUSE, szInfo, sizeof(szInfo));
	if (g_bAllowMouse[iClient])
		AddMenuItem(hMenu, szInfo, "[*] - Mouse Control");
	else
		AddMenuItem(hMenu, szInfo, "[ ] - Mouse Control");

	IntToString(MENUSELECT_AUTO_STRAFE, szInfo, sizeof(szInfo));
	if (AutoStrafe_IsEnabled(iClient))
		AddMenuItem(hMenu, szInfo, "[*] Auto Strafe");
	else
		AddMenuItem(hMenu, szInfo, "[ ] Auto Strafe");


	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, iClient, 0);
}

public MenuHandle_TAS(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	new iClient = iParam1;
	if(!(1 <= iClient <= MaxClients))
		return;

	if (!g_bActivated[iClient])
	{
		CloseHandle(hMenu);
		return;
	}

	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}

	if(action != MenuAction_Select)
		return;


	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));

	switch(StringToInt(szInfo))
	{
		case MENUSELECT_PAUSE:		Replays_SetMode(iClient, REPLAY_FREEZE);
		case MENUSELECT_RESUME:	 Replays_SetMode(iClient, REPLAY_RECORD);
		case MENUSELECT_REWIND:		Replays_SetMode(iClient, REPLAY_REWIND);
		case MENUSELECT_ALLOW_MOUSE:	g_bAllowMouse[iClient] = !g_bAllowMouse[iClient];
		case MENUSELECT_AUTO_STRAFE:	AutoStrafe_SetEnabled(iClient, !AutoStrafe_IsEnabled(iClient));
	}

	DisplayMenu_TAS(iClient);
}


public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	if (g_bAllowMouse[iClient])
	{
		if (iButtons & IN_ATTACK)
		{
			Replays_SetMode(iClient, REPLAY_REWIND);
			g_bMouseControl[iClient] = true;
		}
		else if (iButtons & IN_ATTACK2)
		{
			Replays_SetMode(iClient, REPLAY_FREEZE);
			g_bMouseControl[iClient] = true;
		}
		else if (g_bMouseControl[iClient])
		{
			Replays_SetMode(iClient, REPLAY_RECORD);
			g_bMouseControl[iClient] = false;
		}
	}

}
