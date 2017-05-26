#include <sourcemod>
#include <sdktools_functions>
#include "../../../Libraries/EntityHooker/entity_hooker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Lock state";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Locks entities in a specific state.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAMAGE_NO	0

#define SF_DOOR_SILENT	4096


public OnPluginStart()
{
	CreateConVar("lock_state_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_LOCK_STATE, "Lock state", "func_breakable", "func_door");
	
	EntityHooker_RegisterProperty(EH_TYPE_LOCK_STATE, Prop_Send, PropField_String, "m_iName");
	EntityHooker_RegisterProperty(EH_TYPE_LOCK_STATE, Prop_Data, PropField_String, "m_target");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_LOCK_STATE)
		return;
	
	decl String:szClassName[15];
	if(!GetEntityClassname(iEnt, szClassName, sizeof(szClassName)))
		return;
	
	// Change the entities name so nothing can target it.
	DispatchKeyValue(iEnt, "targetname", "swoobles_locked_state");
	
	if(StrEqual(szClassName, "func_door"))
	{
		LockState_FuncDoor(iEnt);
	}
	else if(StrEqual(szClassName, "func_breakable"))
	{
		LockState_FuncBreakable(iEnt);
	}
}

LockState_FuncDoor(iEnt)
{
	SetEntProp(iEnt, Prop_Data, "m_spawnflags", GetEntProp(iEnt, Prop_Data, "m_spawnflags") | SF_DOOR_SILENT); // Disable locked sound.
	SetEntProp(iEnt, Prop_Data, "m_bLocked", 1);
}

LockState_FuncBreakable(iEnt)
{
	SetEntProp(iEnt, Prop_Data, "m_takedamage", DAMAGE_NO);
}