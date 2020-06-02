#include <sourcemod>
#include <sdktools_functions>
#include <cstrike>

#undef REQUIRE_PLUGIN
//#include "../Swoobles 5.0/Plugins/StoreItems/Equipment/item_equipment"
#include "../../Plugins/DonatorItems/PlayerModels/donatoritem_player_models"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Player models for skill servers";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Uses old player models to fix the landing view bob.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:PLAYER_MODELS_T[][] =
{
	"models/player/tm_professional.mdl"
};

new const String:PLAYER_MODELS_CT[][] =
{
	"models/player/ctm_gign.mdl"
};

new bool:g_bLibLoaded_ItemPlayerModels;
new bool:g_bLibLoaded_ItemEquipment;
new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("player_models_skill_servers_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ItemPlayerModels = LibraryExists("donatoritem_player_models");
	g_bLibLoaded_ItemEquipment = LibraryExists("item_equipment");
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "donatoritem_player_models"))
	{
		g_bLibLoaded_ItemPlayerModels = true;
	}
	else if(StrEqual(szName, "item_equipment"))
	{
		g_bLibLoaded_ItemEquipment = true;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "donatoritem_player_models"))
	{
		g_bLibLoaded_ItemPlayerModels = false;
	}
	else if(StrEqual(szName, "item_equipment"))
	{
		g_bLibLoaded_ItemEquipment = false;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = false;
	}
}

public OnMapStart()
{
	for(new i=0; i<sizeof(PLAYER_MODELS_T); i++)
		PrecacheModel(PLAYER_MODELS_T[i]);
	
	for(new i=0; i<sizeof(PLAYER_MODELS_CT); i++)
		PrecacheModel(PLAYER_MODELS_CT[i]);
}

public MSManager_OnSpawnPost(iClient)
{
	SpawnPost(iClient);
}

SpawnPost(iClient)
{
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	if(g_bLibLoaded_ItemPlayerModels)
	{
		#if defined _donatoritem_player_models_included
		if(DItemPlayerModels_HasUsableModelActivated(iClient))
			return;
		#endif
	}
	
	switch(GetClientTeam(iClient))
	{
		case CS_TEAM_T:
		{
			new iIndex = GetRandomInt(0, sizeof(PLAYER_MODELS_T)-1);
			MSManager_SetPlayerModel(iClient, PLAYER_MODELS_T[iIndex]);
		}
		case CS_TEAM_CT:
		{
			new iIndex = GetRandomInt(0, sizeof(PLAYER_MODELS_CT)-1);
			MSManager_SetPlayerModel(iClient, PLAYER_MODELS_CT[iIndex]);
		}
	}
	
	if(g_bLibLoaded_ItemEquipment)
	{
		#if defined _item_equipment_included
		ItemEquipment_RecalculateClientsEquipment(iClient);
		#endif
	}
}
