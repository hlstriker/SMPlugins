#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_settings"

#undef REQUIRE_PLUGIN
//#include "../Swoobles 5.0/Plugins/StoreItems/Equipment/item_equipment"
#include "../../Plugins/DonatorItems/PlayerModels/donatoritem_player_models"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Player Models";
new const String:PLUGIN_VERSION[] = "1.14";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The player models plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:PLAYER_MODEL_CT[] = "models/player/custom_player/legacy/ctm_swat.mdl";

/*new const String:PLAYER_MODEL_CT_FILES[][] =
{
	"models/player/custom_player/swoobles/guard/guard.dx90.vtx",
	"models/player/custom_player/swoobles/guard/guard.phy",
	"models/player/custom_player/swoobles/guard/guard.vvd"
};*/


new const String:PLAYER_MODELS_T[][] =
{
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.mdl"
};

new const String:PLAYER_MODEL_T_FILES[][] =
{
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.dx90.vtx",
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.phy",
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.vvd",
	
	"materials/swoobles/player/prisoners/male_white_hair/charles01_body01_au_d.vmt",
	"materials/swoobles/player/prisoners/male_white_hair/charles01_body01_au_d.vtf",
	"materials/swoobles/player/prisoners/male_white_hair/charles01_body01_au_normal.vtf",
	"materials/swoobles/player/prisoners/male_white_hair/charles01_head01_au_d.vmt",
	"materials/swoobles/player/prisoners/male_white_hair/charles01_head01_au_d.vtf",
	"materials/swoobles/player/prisoners/male_white_hair/charles01_head01_au_normal.vtf",
	"materials/swoobles/player/prisoners/male_white_hair/hair01_au_d.vmt",
	"materials/swoobles/player/prisoners/male_white_hair/hair01_au_d.vtf",
	"materials/swoobles/player/prisoners/male_white_hair/hair01_au_normal.vtf",
	"materials/swoobles/player/prisoners/male_white_hair/hair02_au_d.vmt",
	
	"materials/swoobles/player/prisoners/shared/prisoner1_body.vmt",
	"materials/swoobles/player/prisoners/shared/prisoner1_body.vtf",
	"materials/swoobles/player/prisoners/shared/prisoner1_body_white.vmt",
	"materials/swoobles/player/prisoners/shared/prisoner1_body_white.vtf",
	"materials/swoobles/player/prisoners/shared/prisoner1_body_normal.vtf"
};

new bool:g_bLibLoaded_ItemPlayerModels;
new bool:g_bLibLoaded_ItemEquipment;
new bool:g_bLibLoaded_ModelSkinManager;

new Handle:g_hFwd_OnApplied;


public OnPluginStart()
{
	CreateConVar("ultjb_player_models_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnApplied = CreateGlobalForward("UltJB_PlayerModels_OnApplied", ET_Ignore, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_player_models");
	return APLRes_Success;
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
	for(new i=0; i<sizeof(PLAYER_MODEL_T_FILES); i++)
		AddFileToDownloadsTable(PLAYER_MODEL_T_FILES[i]);
	
	//for(new i=0; i<sizeof(PLAYER_MODEL_CT_FILES); i++)
	//	AddFileToDownloadsTable(PLAYER_MODEL_CT_FILES[i]);
	
	for(new i=0; i<sizeof(PLAYER_MODELS_T); i++)
	{
		AddFileToDownloadsTable(PLAYER_MODELS_T[i]);
		PrecacheModel(PLAYER_MODELS_T[i]);
	}
	
	//AddFileToDownloadsTable(PLAYER_MODEL_CT);
	PrecacheModel(PLAYER_MODEL_CT);
}

public UltJB_Settings_OnSpawnPost(iClient)
{
	if(g_bLibLoaded_ItemPlayerModels)
	{
		#if defined _donatoritem_player_models_included
		if(DItemPlayerModels_HasUsableModelActivated(iClient))
			return;
		#endif
	}
	
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS:
		{
			new iIndex = GetRandomInt(0, sizeof(PLAYER_MODELS_T)-1);
			
			if(g_bLibLoaded_ModelSkinManager)
			{
				#if defined _model_skin_manager_included
				MSManager_SetPlayerModel(iClient, PLAYER_MODELS_T[iIndex]);
				#else
				SetEntityModel(iClient, PLAYER_MODELS_T[iIndex]);
				#endif
			}
			else
			{
				SetEntityModel(iClient, PLAYER_MODELS_T[iIndex]);
			}
		}
		case TEAM_GUARDS:
		{
			if(g_bLibLoaded_ModelSkinManager)
			{
				#if defined _model_skin_manager_included
				MSManager_SetPlayerModel(iClient, PLAYER_MODEL_CT);
				#else
				SetEntityModel(iClient, PLAYER_MODEL_CT);
				#endif
			}
			else
			{
				SetEntityModel(iClient, PLAYER_MODEL_CT);
			}
		}
	}
	
	SetEntProp(iClient, Prop_Send, "m_nSkin", 0);
	
	if(g_bLibLoaded_ItemEquipment)
	{
		#if defined _item_equipment_included
		ItemEquipment_RecalculateClientsEquipment(iClient);
		#endif
	}
	
	Forward_OnApplied(iClient);
}

Forward_OnApplied(iClient)
{
	new result;
	Call_StartForward(g_hFwd_OnApplied);
	Call_PushCell(iClient);
	Call_Finish(result);
}