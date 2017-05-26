#include <sourcemod>
#include <sdkhooks>
#include <sdktools_entinput>
#include <sdktools_entoutput>
#include "../../../Libraries/EntityHooker/entity_hooker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Auto use";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Automatically presses +use on hooked entities.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}


public OnPluginStart()
{
	CreateConVar("auto_use_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_AUTO_USE, "Auto use", "func_button", "func_rot_button", "func_rotating", "func_door", "func_door_rotating", "prop_door_rotating", "trigger_once", "trigger_multiple");
	
	EntityHooker_RegisterProperty(EH_TYPE_AUTO_USE, Prop_Send, PropField_String, "m_iName");
	EntityHooker_RegisterProperty(EH_TYPE_AUTO_USE, Prop_Data, PropField_String, "m_target");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_AUTO_USE)
		return;
	
	decl String:szClassName[8];
	if(!GetEntityClassname(iEnt, szClassName, sizeof(szClassName)))
		return;
	
	szClassName[7] = 0x00;
	if(StrEqual(szClassName, "trigger"))
		UseTrigger(iEnt);
	else
		UseButtonAndDoor(iEnt);
}

UseTrigger(iEnt)
{
	FireEntityOutput(iEnt, "OnStartTouch");
	FireEntityOutput(iEnt, "OnTouching");
	FireEntityOutput(iEnt, "OnTrigger");
	FireEntityOutput(iEnt, "OnEndTouch");
	FireEntityOutput(iEnt, "OnEndTouchAll");
}

UseButtonAndDoor(iEnt)
{
	AcceptEntityInput(iEnt, "Use");
	SDKHooks_TakeDamage(iEnt, 0, 0, 0.0);
}