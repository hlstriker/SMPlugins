#include <sourcemod>
#include "Includes/ultjb_cell_doors"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Ultimate Jailbreak: Cell Doors";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The cell doors plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_hOpenTimer;
new Handle:cvar_cell_door_open_time;


public OnPluginStart()
{
	CreateConVar("ultjb_cell_doors_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_cell_door_open_time = CreateConVar("ultjb_cell_door_open_time", "60", "How long to wait before the cell doors automatically open.", _, true, 1.0);
	
	RegAdminCmd("sm_celldoors_open", OnCellDoorsOpen, ADMFLAG_ROOT, "Forces the cell doors to open.");
	
	HookEvent("round_start", EventRoundStart_Post, EventHookMode_PostNoCopy);
}

public Action:OnCellDoorsOpen(iClient, iArgNum)
{
	if(!UltJB_CellDoors_ForceOpen())
	{
		ReplyToCommand(iClient, "[SM] There are no cell doors to open.");
		return Plugin_Handled;
	}
	
	PrintToChatAll("Admin %N forced the cell doors open.", iClient);
	return Plugin_Handled;
}

public EventRoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(g_hOpenTimer != INVALID_HANDLE)
		CloseHandle(g_hOpenTimer);
	
	g_hOpenTimer = CreateTimer(GetConVarFloat(cvar_cell_door_open_time), Timer_OpenCellDoors);
}

public Action:Timer_OpenCellDoors(Handle:hTimer)
{
	g_hOpenTimer = INVALID_HANDLE;
	
	UltJB_CellDoors_ForceOpen();
}