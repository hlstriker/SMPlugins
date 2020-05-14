#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_settings"

#undef REQUIRE_PLUGIN
//#include "../Swoobles 5.0/Plugins/StoreItems/Equipment/item_equipment"
#include "../../Plugins/DonatorItems/PlayerModels/donatoritem_player_models"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#include "../../Libraries/DatabaseUserStats/database_user_stats"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Player Models";
new const String:PLUGIN_VERSION[] = "1.19";

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
	"models/player/custom_player/swoobles/prisoners/male_black_big_new/male_black_big_new.mdl",
	"models/player/custom_player/swoobles/prisoners/female_asian_new/female_asian_new.mdl",
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.mdl"
};

new const String:PLAYER_MODEL_T_FILES[][] =
{
	"models/player/custom_player/swoobles/prisoners/male_black_big_new/male_black_big_new.dx90.vtx",
	"models/player/custom_player/swoobles/prisoners/male_black_big_new/male_black_big_new.phy",
	"models/player/custom_player/swoobles/prisoners/male_black_big_new/male_black_big_new.vvd",
	
	"models/player/custom_player/swoobles/prisoners/female_asian_new/female_asian_new.dx90.vtx",
	"models/player/custom_player/swoobles/prisoners/female_asian_new/female_asian_new.phy",
	"models/player/custom_player/swoobles/prisoners/female_asian_new/female_asian_new.vvd",
	
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.dx90.vtx",
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.phy",
	"models/player/custom_player/swoobles/prisoners/male_white_hair_new/male_white_hair_new.vvd",
	
	"materials/swoobles/player/prisoners/male_black_big/eye_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/eye_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d_white.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_d_white.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_bottom_normal.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_head_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_head_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_head_normal.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d_white.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_d_white.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoner_lt_top_normal.vtf",
	"materials/swoobles/player/prisoners/male_black_big/prisoners_torso_d.vmt",
	"materials/swoobles/player/prisoners/male_black_big/prisoners_torso_d.vtf",
	
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
	"materials/swoobles/player/prisoners/shared/prisoner1_body_white.vmt",
	"materials/swoobles/player/prisoners/shared/prisoner1_body_white.vtf",
	"materials/swoobles/player/prisoners/shared/prisoner1_body_normal.vtf"
};

new bool:g_bLibLoaded_ItemPlayerModels;
new bool:g_bLibLoaded_ItemEquipment;
new bool:g_bLibLoaded_ModelSkinManager;
new bool:g_bLibLoaded_DatabaseUserStats;

new Handle:g_hFwd_OnApplied;

#define NUM_HELP_MODELS	2
new Handle:cvar_help1_seconds;
new Handle:cvar_help2_seconds;
new Handle:cvar_help1_bonushealth;
new Handle:cvar_help2_bonushealth;


public OnPluginStart()
{
	CreateConVar("ultjb_player_models_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	// 15 hours default
	cvar_help1_seconds = CreateConVar("ultjb_playermodels_help1_seconds", "54000", "The number of seconds to use help model 1.", _, true, 0.0);
	
	// 30 hours default
	cvar_help2_seconds = CreateConVar("ultjb_playermodels_help2_seconds", "108000", "The number of seconds to use help model 2.", _, true, 0.0);
	
	cvar_help1_bonushealth = CreateConVar("ultjb_playermodels_help1_bonushealth", "30", "The amount of bonus health to give to help model 1.", _, true, 0.0);
	cvar_help2_bonushealth = CreateConVar("ultjb_playermodels_help2_bonushealth", "15", "The amount of bonus health to give to help model 2.", _, true, 0.0);
	
	g_hFwd_OnApplied = CreateGlobalForward("UltJB_PlayerModels_OnApplied", ET_Ignore, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_player_models");
	CreateNative("UltJB_PlayerModels_ApplyGuardModel", _UltJB_PlayerModels_ApplyGuardModel);
	CreateNative("UltJB_PlayerModels_ApplyPrisonerModel", _UltJB_PlayerModels_ApplyPrisonerModel);
	
	return APLRes_Success;
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ItemPlayerModels = LibraryExists("donatoritem_player_models");
	g_bLibLoaded_ItemEquipment = LibraryExists("item_equipment");
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
	g_bLibLoaded_DatabaseUserStats = LibraryExists("database_user_stats");
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
	else if(StrEqual(szName, "database_user_stats"))
	{
		g_bLibLoaded_DatabaseUserStats = true;
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
	else if(StrEqual(szName, "database_user_stats"))
	{
		g_bLibLoaded_DatabaseUserStats = false;
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

public _UltJB_PlayerModels_ApplyGuardModel(Handle:hPlugin, iNumParams)
{
	return ApplyGuardModel(GetNativeCell(1));
}

public _UltJB_PlayerModels_ApplyPrisonerModel(Handle:hPlugin, iNumParams)
{
	new iClient = GetNativeCell(1);
	return ApplyPrisonerModel(iClient, GetHelpModelIndex(iClient));
}

public UltJB_Settings_OnSpawnPost(iClient)
{
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS:
		{
			new iHelpModelIndex = GetHelpModelIndex(iClient);
			
			if(iHelpModelIndex != -1)
				UltJB_LR_SetClientsHealth(iClient, GetEntProp(iClient, Prop_Data, "m_iHealth") + GetHelpModelBonusHealth(iHelpModelIndex));
			
			if(g_bLibLoaded_ItemPlayerModels)
			{
				#if defined _donatoritem_player_models_included
				if(DItemPlayerModels_HasUsableModelActivated(iClient))
					return;
				#endif
			}
			
			ApplyPrisonerModel(iClient, iHelpModelIndex);
		}
		case TEAM_GUARDS:
		{
			if(g_bLibLoaded_ItemPlayerModels)
			{
				#if defined _donatoritem_player_models_included
				if(DItemPlayerModels_HasUsableModelActivated(iClient))
					return;
				#endif
			}
			
			ApplyGuardModel(iClient);
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

ApplyPrisonerModel(iClient, iHelpModelIndex=-1)
{
	decl iIndex;
	if(iHelpModelIndex != -1)
	{
		iIndex = iHelpModelIndex;
	}
	else
	{
		iIndex = GetRandomInt(NUM_HELP_MODELS, sizeof(PLAYER_MODELS_T)-1);
	}
	
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
	
	return true;
}

ApplyGuardModel(iClient)
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
	
	return true;
}

Forward_OnApplied(iClient)
{
	new result;
	Call_StartForward(g_hFwd_OnApplied);
	Call_PushCell(iClient);
	Call_Finish(result);
}

GetHelpModelIndex(iClient)
{
	if(!g_bLibLoaded_DatabaseUserStats)
		return -1;
	
	#if defined _database_user_stats_included
	if(!DBUserStats_HasServerStatsLoaded(iClient))
		return -1;
	
	new iSecondsPlayed = DBUserStats_GetServerTimePlayed(iClient);
	
	if(GetConVarInt(cvar_help1_seconds) > 0 && iSecondsPlayed < GetConVarInt(cvar_help1_seconds))
		return 0;
	
	if(GetConVarInt(cvar_help2_seconds) > 0 && iSecondsPlayed < GetConVarInt(cvar_help2_seconds))
		return 1;
	#endif
	
	return -1;
}

GetHelpModelBonusHealth(iIndex)
{
	switch(iIndex)
	{
		case 0:	return GetConVarInt(cvar_help1_bonushealth);
		case 1:	return GetConVarInt(cvar_help2_bonushealth);
	}
	
	return 0;
}