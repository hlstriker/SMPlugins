#include <sourcemod>
#include <sdktools_entinput>
#include "../../../Libraries/EntityHooker/entity_hooker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Remove entities";
new const String:PLUGIN_VERSION[] = "1.18";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows certain entities to be removed.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("remove_entities_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_REMOVE_ENTITIES, "Remove entities");
	
	EntityHooker_RegisterAdditional(EH_TYPE_REMOVE_ENTITIES,
		"ambient_generic");
	
	EntityHooker_RegisterAdditional(EH_TYPE_REMOVE_ENTITIES,
		"env_explosion", "env_fire", "env_laser", "env_spark", "env_soundscape", "env_soundscape_proxy", "env_soundscape_triggerable");
	
	EntityHooker_RegisterAdditional(EH_TYPE_REMOVE_ENTITIES,
		"func_breakable", "func_brush", "func_button", "func_door", "func_door_rotating", "func_movelinear", "func_occluder", "func_physbox",
		"func_physbox_multiplayer", "func_rot_button", "func_rotating", "func_tanktrain", "func_tracktrain", "func_wall_toggle", "func_water_analog");
	
	EntityHooker_RegisterAdditional(EH_TYPE_REMOVE_ENTITIES,
		"logic_auto", "logic_timer");
	
	EntityHooker_RegisterAdditional(EH_TYPE_REMOVE_ENTITIES,
		"prop_door_rotating", "prop_dynamic", "prop_dynamic_override", "prop_physics", "prop_physics_multiplayer");
	
	EntityHooker_RegisterAdditional(EH_TYPE_REMOVE_ENTITIES,
		"trigger_hurt", "trigger_multiple", "trigger_once", "trigger_push", "trigger_soundscape", "trigger_teleport");
	
	EntityHooker_RegisterProperty(EH_TYPE_REMOVE_ENTITIES, Prop_Send, PropField_String, "m_iName");
	EntityHooker_RegisterProperty(EH_TYPE_REMOVE_ENTITIES, Prop_Data, PropField_String, "m_target");
	EntityHooker_RegisterProperty(EH_TYPE_REMOVE_ENTITIES, Prop_Data, PropField_String, "m_iParent");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_REMOVE_ENTITIES)
		return;
	
	AcceptEntityInput(iEnt, "KillHierarchy");
}