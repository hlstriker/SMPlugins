#include <sourcemod>
#include "Includes/ultjb_cell_doors"

#undef REQUIRE_PLUGIN
#include "../../Libraries/EntityHooker/entity_hooker"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Cell Doors";
new const String:PLUGIN_VERSION[] = "1.2";

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
	RegAdminCmd("sm_cdo", OnCellDoorsOpen, ADMFLAG_ROOT, "Forces the cell doors to open.");
	
	HookEvent("round_start", EventRoundStart_Post, EventHookMode_PostNoCopy);
}

#if defined _entity_hooker_included
public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_JAILBREAK_CELL_DOORS, "Cell Doors");
	
	EntityHooker_RegisterAdditional(EH_TYPE_JAILBREAK_CELL_DOORS,
		"func_door", "func_door_rotating", "prop_door_rotating", "func_breakable", "func_movelinear", "func_tracktrain", "func_wall_toggle", "func_brush");
	
	EntityHooker_RegisterProperty(EH_TYPE_JAILBREAK_CELL_DOORS, Prop_Send, PropField_String, "m_iName");
	EntityHooker_RegisterProperty(EH_TYPE_JAILBREAK_CELL_DOORS, Prop_Data, PropField_String, "m_target");
	EntityHooker_RegisterProperty(EH_TYPE_JAILBREAK_CELL_DOORS, Prop_Data, PropField_String, "m_iParent");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_JAILBREAK_CELL_DOORS)
		return;
	
	UltJB_CellDoors_AddEntityAsDoor(iEnt);
}

public EntityHooker_OnEntityUnhooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_JAILBREAK_CELL_DOORS)
		return;
	
	UltJB_CellDoors_RemoveEntityFromBeingDoor(iEnt);
}
#endif

public Action:OnCellDoorsOpen(iClient, iArgNum)
{
	if(!UltJB_CellDoors_ForceOpen())
	{
		ReplyToCommand(iClient, "[SM] There are no cell doors to open.");
		return Plugin_Handled;
	}
	
	PrintToChatAll("Admin %N forced the cell doors open.", iClient);
	LogAction(iClient, -1, "\"%L\" forced open cell doors", iClient);
	
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