#include <sourcemod>
#include <sdkhooks>
#include "../../../Libraries/EntityHooker/entity_hooker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Fix CS:GO trigger_gravity";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Fix CS:GO trigger_gravity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fGravity[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("fix_csgo_trigger_gravity_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_CSGO_TO_CSS_GRAVITY_FIX, "trigger_gravity cs:go -> cs:s", "trigger_gravity");
	EntityHooker_RegisterProperty(EH_TYPE_CSGO_TO_CSS_GRAVITY_FIX, Prop_Data, PropField_Float, "m_flGravity");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_CSGO_TO_CSS_GRAVITY_FIX)
		return;
	
	SDKHook(iEnt, SDKHook_EndTouch, OnEndTouch);
	SDKHook(iEnt, SDKHook_EndTouchPost, OnEndTouchPost);
}

public EntityHooker_OnEntityUnhooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_CSGO_TO_CSS_GRAVITY_FIX)
		return;
	
	SDKUnhook(iEnt, SDKHook_EndTouch, OnEndTouch);
	SDKUnhook(iEnt, SDKHook_EndTouchPost, OnEndTouchPost);
}

public OnEndTouch(iEnt, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	g_fGravity[iOther] = GetEntityGravity(iOther);
}

public OnEndTouchPost(iEnt, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	SetEntityGravity(iOther, g_fGravity[iOther]);
}