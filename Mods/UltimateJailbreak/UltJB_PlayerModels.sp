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

new const String:PLUGIN_NAME[] = "Ultimate Jailbreak: Player Models";
new const String:PLUGIN_VERSION[] = "1.13";

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
	"models/player/custom_player/swoobles/prisoners/male_black_big/male_black_big.mdl",
	"models/player/custom_player/swoobles/prisoners/female_asian/female_asian.mdl",
	"models/player/custom_player/swoobles/prisoners/male_white_hair/male_white_hair.mdl"
};

new const String:PLAYER_MODEL_T_FILES[][] =
{
	"models/player/custom_player/swoobles/prisoners/female_asian/female_asian.dx90.vtx",
	"models/player/custom_player/swoobles/prisoners/female_asian/female_asian.phy",
	"models/player/custom_player/swoobles/prisoners/female_asian/female_asian.vvd",
	
	"models/player/custom_player/swoobles/prisoners/male_black_big/male_black_big.dx90.vtx",
	"models/player/custom_player/swoobles/prisoners/male_black_big/male_black_big.phy",
	"models/player/custom_player/swoobles/prisoners/male_black_big/male_black_big.vvd",
	
	"models/player/custom_player/swoobles/prisoners/male_white_hair/male_white_hair.dx90.vtx",
	"models/player/custom_player/swoobles/prisoners/male_white_hair/male_white_hair.phy",
	"models/player/custom_player/swoobles/prisoners/male_white_hair/male_white_hair.vvd",
	
	"materials/swoobles/player/prisoners/female_asian/denise_head01_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/denise_head01_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/denise_head01_normal.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_brow_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_brow_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_eye_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_eye_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_eye_normal.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_face_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_face_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_face_normal.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_hair1_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_hair1_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_hair1_d_tr.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_hair1_normal.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_hair2_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_hair2_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_hair2_d_tr.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_hair2_normal.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_lashes_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_lashes_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_mouth_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_mouth_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/lara_sh_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/lara_sh_d.vtf",
	"materials/swoobles/player/prisoners/female_asian/shirt_d.vmt",
	"materials/swoobles/player/prisoners/female_asian/shirt_d.vtf",
	
	"materials/swoobles/player/prisoners/male_black_big/eye_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/eye_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d_frozen.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d_frozen.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_normal.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_head_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_head_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_head_normal.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d_frozen.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d_frozen.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_normal.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoners_torso_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoners_torso_d.vtf",
	
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
	
	"materials/swoobles/player/prisoners/shared/brown_eye_normal.vtf",
	"materials/swoobles/player/prisoners/shared/brown_eye01_an_d.vmt",
	"materials/swoobles/player/prisoners/shared/brown_eye01_an_d.vtf",
	"materials/swoobles/player/prisoners/shared/prisoner1_body.vmt",
	"materials/swoobles/player/prisoners/shared/prisoner1_body.vtf",
	"materials/swoobles/player/prisoners/shared/prisoner1_body_frozen.vmt",
	"materials/swoobles/player/prisoners/shared/prisoner1_body_frozen.vtf",
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
			// Chance the player will get the big black prisoner model. Give them a bit of extra health!
			if(GetRandomInt(1, 50) == 1)
			{
				if(g_bLibLoaded_ModelSkinManager)
				{
					#if defined _model_skin_manager_included
					MSManager_SetPlayerModel(iClient, PLAYER_MODELS_T[0]);
					#else
					SetEntityModel(iClient, PLAYER_MODELS_T[0]);
					#endif
				}
				else
				{
					SetEntityModel(iClient, PLAYER_MODELS_T[0]);
				}
				
				UltJB_LR_SetClientsHealth(iClient, GetEntProp(iClient, Prop_Data, "m_iHealth") + 25);
			}
			else
			{
				new iIndex = GetRandomInt(1, sizeof(PLAYER_MODELS_T)-1);
				
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