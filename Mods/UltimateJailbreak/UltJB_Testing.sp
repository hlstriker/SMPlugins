#include <sourcemod>
#include <cstrike>
#include <sdktools_functions>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <sdkhooks>
#include <sdktools_engine>
#include "Includes/ultjb_weapon_selection"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Ultimate Jailbreak: Testing";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The testing plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:MODEL_FINISH_LINE[] = "models/swoobles/ultimate_jailbreak/finish_line/finish_line.mdl";
new const String:SZ_DEFAULT_BEAM[] = "materials/sprites/laserbeam.vmt";

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;

new g_iDefaultBeamIndex;


public OnPluginStart()
{
	CreateConVar("ultjb_testing_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_test", OnTesting, "If this command exists warn an admin!");
}

public OnClientPutInServer(iClient)
{
	//SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public OnPreThinkPost(iClient)
{
	PrintToServer("%f", GetEntPropFloat(iClient, Prop_Data, "m_fLastPlayerTalkTime"));
}

public Action:OnTesting(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	/*
	new iEnt = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if(iEnt > 0)
	{
		decl String:szClassName[128];
		GetEntityClassname(iEnt, szClassName, sizeof(szClassName));
		PrintToServer("Entity name = [%s] - [%i]", szClassName, GetEntProp(iEnt, Prop_Send, "m_iItemDefinitionIndex"));
	}
	
	new iFlags[NUM_WPN_CATS];
	UltJB_Weapons_DisplaySelectionMenu(iClient, OnSuccess, OnFailed, iFlags);
	*/
	
	//CreateFinishLine(iClient);
	
	decl Float:fMins[3], Float:fMaxs[3];
	GetClientMins(iClient, fMins);
	GetClientMaxs(iClient, fMaxs);
	
	PrintToServer("[%f - %f - %f] - [%f - %f - %f]", fMins[0], fMins[1], fMins[2], fMaxs[0], fMaxs[1], fMaxs[2]);
	
	return Plugin_Handled;
}

public OnMapStart()
{
	PrecacheModel(MODEL_FINISH_LINE);
	g_iDefaultBeamIndex = PrecacheModel(SZ_DEFAULT_BEAM);
}

public OnSuccess(iClient, iWeaponID, const iFlags[NUM_WPN_CATS])
{
	UltJB_Weapons_GivePlayerWeapon(iClient, iWeaponID);
}

public OnFailed(iClient, const iFlags[NUM_WPN_CATS])
{
	PrintToChat(iClient, "Failed");
}

bool:CreateFinishLine(iClient)
{
	new iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1 || !IsValidEntity(iEnt))
		return false;
	
	SetEntityModel(iEnt, MODEL_FINISH_LINE);
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2); // SOLID_BBOX
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID|FSOLID_TRIGGER);
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", Float:{-20.0, -20.0, -0.0});
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", Float:{20.0, 20.0, 80.0});
	
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	ShowEntityBoundingBox(iEnt);
	
	return true;
}

ShowEntityBoundingBox(iEnt/*, iClients[], iNumClients*/)
{
	/*
	* 	Shows the bounding box dimensions to specified clients.
	*/
	
	decl Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	
	new Float:fVertices[8][3], i;
	
	// Add the entities origin to all the vertices.
	for(i=0; i<8; i++)
	{
		fVertices[i][0] += fOrigin[0];
		fVertices[i][1] += fOrigin[1];
		fVertices[i][2] += fOrigin[2];
	}
	
	// Set the vertices origins.
	fVertices[0][2] += fMins[2];
	fVertices[1][2] += fMins[2];
	fVertices[2][2] += fMins[2];
	fVertices[3][2] += fMins[2];
	
	fVertices[4][2] += fMaxs[2];
	fVertices[5][2] += fMaxs[2];
	fVertices[6][2] += fMaxs[2];
	fVertices[7][2] += fMaxs[2];
	
	fVertices[0][0] += fMins[0];
	fVertices[0][1] += fMins[1];
	fVertices[1][0] += fMins[0];
	fVertices[1][1] += fMaxs[1];
	fVertices[2][0] += fMaxs[0];
	fVertices[2][1] += fMaxs[1];
	fVertices[3][0] += fMaxs[0];
	fVertices[3][1] += fMins[1];
	
	fVertices[4][0] += fMins[0];
	fVertices[4][1] += fMins[1];
	fVertices[5][0] += fMins[0];
	fVertices[5][1] += fMaxs[1];
	fVertices[6][0] += fMaxs[0];
	fVertices[6][1] += fMaxs[1];
	fVertices[7][0] += fMaxs[0];
	fVertices[7][1] += fMins[1];
	
	// Draw the horizontal beams.
	for(i=0; i<4; i++)
	{
		if(i != 3)
			TE_SetupBeamPoints(fVertices[i], fVertices[i+1], g_iDefaultBeamIndex, 0, 1, 0, 22.0, 1.0, 1.0, 0, 0.0, {255, 0, 0, 255}, 0);
		else
			TE_SetupBeamPoints(fVertices[i], fVertices[0], g_iDefaultBeamIndex, 0, 1, 0, 22.0, 1.0, 1.0, 0, 0.0, {255, 0, 0, 255}, 0);
		
		TE_SendToAll();
	}
	
	for(i=4; i<8; i++)
	{
		if(i != 7)
			TE_SetupBeamPoints(fVertices[i], fVertices[i+1], g_iDefaultBeamIndex, 0, 1, 0, 22.0, 1.0, 1.0, 0, 0.0, {255, 0, 0, 255}, 0);
		else
			TE_SetupBeamPoints(fVertices[i], fVertices[4], g_iDefaultBeamIndex, 0, 1, 0, 22.0, 1.0, 1.0, 0, 0.0, {255, 0, 0, 255}, 0);
		
		TE_SendToAll();
	}
	
	// Draw the vertical beams.
	for(i=0; i<4; i++)
	{
		TE_SetupBeamPoints(fVertices[i], fVertices[i+4], g_iDefaultBeamIndex, 0, 1, 0, 22.0, 1.0, 1.0, 0, 0.0, {255, 0, 0, 255}, 0);
		TE_SendToAll();
	}
}