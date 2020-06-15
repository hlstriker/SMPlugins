#include <sourcemod>
#include <sdktools_functions>
#include "../../../Libraries/EntityHooker/entity_hooker"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Fix Teleport Angles";
new const String:PLUGIN_VERSION[] = "2.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Fixes the angles of teleport destinations.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_hTrie_DefaultValues;


public OnPluginStart()
{
	CreateConVar("fix_teleport_angles_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hTrie_DefaultValues = CreateTrie();
}

public EntityHooker_OnRegisterReady()
{
	EntityHooker_Register(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, "Don't fix teleport angles");
	
	EntityHooker_RegisterAdditional(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, "trigger_teleport");
	
	EntityHooker_RegisterProperty(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, Prop_Send, PropField_String, "m_iName");
	EntityHooker_RegisterProperty(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, Prop_Data, PropField_String, "m_target");
	EntityHooker_RegisterProperty(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, Prop_Data, PropField_String, "m_iParent");
	EntityHooker_RegisterProperty(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, Prop_Data, PropField_String, "m_iLandmark");
	EntityHooker_RegisterProperty(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, Prop_Data, PropField_Integer, "m_bUseLandmarkAngles");
}

public OnMapStart()
{
	ClearTrie(g_hTrie_DefaultValues);
}

public EntityHooker_OnInitialHooksPre()
{
	ClearTrie(g_hTrie_DefaultValues);
	
	// Get the default m_bUseLandmarkAngles values.
	decl String:szEntRef[13];
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_teleport")) != -1)
	{
		IntToString(EntIndexToEntRef(iEnt), szEntRef, sizeof(szEntRef));
		SetTrieValue(g_hTrie_DefaultValues, szEntRef, GetEntProp(iEnt, Prop_Data, "m_bUseLandmarkAngles"), true);
	}
}

public EntityHooker_OnInitialHooksReady()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_teleport")) != -1)
	{
		if(!EntityHooker_IsEntityHooked(EH_TYPE_DONT_FIX_TELEPORT_ANGLES, iEnt))
			PatchEntity(iEnt);
	}
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_DONT_FIX_TELEPORT_ANGLES)
		return;
	
	UnpatchEntity(iEnt);
}

public EntityHooker_OnEntityUnhooked(iHookType, iEnt)
{
	if(iHookType != EH_TYPE_DONT_FIX_TELEPORT_ANGLES)
		return;
	
	PatchEntity(iEnt);
}

PatchEntity(iEnt)
{
	decl String:szLandmark[256];
	GetEntPropString(iEnt, Prop_Data, "m_iLandmark", szLandmark, sizeof(szLandmark));
	
	// Return if the landmark string isn't blank (that means it's a seamless teleport and we don't want to set the angles.)
	if(szLandmark[0])
		return;
	
	SetEntProp(iEnt, Prop_Data, "m_bUseLandmarkAngles", 1);
}

UnpatchEntity(iEnt)
{
	decl iDefaultValue, String:szEntRef[13];
	IntToString(EntIndexToEntRef(iEnt), szEntRef, sizeof(szEntRef));
	if(!GetTrieValue(g_hTrie_DefaultValues, szEntRef, iDefaultValue))
		return;
	
	SetEntProp(iEnt, Prop_Data, "m_bUseLandmarkAngles", iDefaultValue);
}