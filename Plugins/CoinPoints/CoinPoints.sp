#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_stringtables>
#include <emitsoundany>
//#include "../../../Swoobles 4.0/Libraries/FileDownloader/file_downloader"
#include "../../Plugins/UserPoints/user_points"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Coin Points";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Throws coins other players can pickup for points.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define COLLISION_GROUP_DEBRIS	1
#define SOLID_NONE				0
#define SOLID_BBOX				2
#define USE_SPECIFIED_BOUNDS	3
#define MOVECOLLIDE_FLY_BOUNCE	1

#define PICKUP_DELAY	1.5
#define REMOVE_DELAY	30.0

new const Float:g_fCoinMins[3] = {-10.0, -10.0, -0.0};
new const Float:g_fCoinMaxs[3] = {10.0, 10.0, 20.0};

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;
new const FSOLID_USE_TRIGGER_BOUNDS = 0x0080;

new const String:SOUND_COIN[] = "sound/swoobles/misc/coin_v1.mp3";

new const String:SOUND_SNOB_FILES[][] =
{
	"sound/swoobles/misc/snob.mp3",
	"sound/swoobles/misc/snob2.mp3"
};

new const String:MODEL_COIN[] = "models/swoobles/misc/coin/swoobles_coin_v2.mdl";

new const String:MODEL_COIN_FILES[][] =
{
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_copper_v2.vmt",
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_copper.vtf",
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_gold_v2.vmt",
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_gold.vtf",
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_platinum_v2.vmt",
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_platinum.vtf",
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_silver_v2.vmt",
	"materials/swoobles/misc/coin/swoobles_coin_diffuse_silver.vtf",
	"materials/swoobles/misc/coin/swoobles_coin_normal_v2.vtf",
	"materials/swoobles/misc/coin/swoobles_coin_shine.vtf",
	
	"models/swoobles/misc/coin/swoobles_coin_v2.dx80.vtx",
	"models/swoobles/misc/coin/swoobles_coin_v2.dx90.vtx",
	"models/swoobles/misc/coin/swoobles_coin_v2.sw.vtx",
	"models/swoobles/misc/coin/swoobles_coin_v2.vvd"
};

new Handle:g_aCoinRefs;
new Handle:g_hTimer;

new bool:g_bPluginEnabled;

enum
{
	COIN_COPPER = 0,
	COIN_SILVER,
	COIN_GOLD,
	COIN_PLATINUM,
	NUM_COIN_TYPES
};

new const Float:g_fCoinScale[] =
{
	0.8,
	0.9,
	1.2,
	1.8
};

new const g_iCoinWorth[] =
{
	1,
	7,
	18,
	57
};


public OnPluginStart()
{
	CreateConVar("coin_points_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aCoinRefs = CreateArray();
	
	RegAdminCmd("sm_coins", Command_Coins, ADMFLAG_ROOT, "sm_coins <total worth> - Throws coins.");
}

public OnMapEnd()
{
	g_bPluginEnabled = false;
	
	if(g_hTimer != INVALID_HANDLE)
	{
		KillTimer(g_hTimer);
		g_hTimer = INVALID_HANDLE;
	}
}

public OnMapStart()
{
	if(DoesFileNeedDownloaded())
	{
		g_bPluginEnabled = false;
		return;
	}
	
	g_bPluginEnabled = true;
	
	PrecacheModel(MODEL_COIN, true);
	AddFileToDownloadsTable(MODEL_COIN);
	
	for(new i=0; i<sizeof(MODEL_COIN_FILES); i++)
		AddFileToDownloadsTable(MODEL_COIN_FILES[i]);
	
	for(new i=0; i<sizeof(SOUND_SNOB_FILES); i++)
	{
		AddFileToDownloadsTable(SOUND_SNOB_FILES[i]);
		PrecacheSoundAny(SOUND_SNOB_FILES[i][6]);
	}
	
	AddFileToDownloadsTable(SOUND_COIN);
	PrecacheSoundAny(SOUND_COIN[6]);
}

bool:DoesFileNeedDownloaded()
{
	new bool:bNeedsDownloaded;
	
	if(!FileExists(MODEL_COIN, false))
	{
		bNeedsDownloaded = true;
		DownloadFile(MODEL_COIN);
	}
	
	for(new i=0; i<sizeof(MODEL_COIN_FILES); i++)
	{
		if(!FileExists(MODEL_COIN_FILES[i], false))
		{
			bNeedsDownloaded = true;
			DownloadFile(MODEL_COIN_FILES[i]);
		}
	}
	
	for(new i=0; i<sizeof(SOUND_SNOB_FILES); i++)
	{
		if(!FileExists(SOUND_SNOB_FILES[i], false))
		{
			bNeedsDownloaded = true;
			DownloadFile(SOUND_SNOB_FILES[i]);
		}
	}
	
	if(!FileExists(SOUND_COIN, false))
	{
		bNeedsDownloaded = true;
		DownloadFile(SOUND_COIN);
	}
	
	return bNeedsDownloaded;
}

DownloadFile(const String:szPath[])
{
	decl String:szURL[512];
	FormatEx(szURL, sizeof(szURL), "http://storefiles.swoobles.com/%s", szPath);
	//FileDownloader_DownloadFile(szURL, szPath); // TODO: Add back
	
	decl String:szFilePathBz2[PLATFORM_MAX_PATH];
	StrCat(szURL, sizeof(szURL), ".bz2");
	FormatEx(szFilePathBz2, sizeof(szFilePathBz2), "%s.bz2", szPath);
	//FileDownloader_DownloadFile(szURL, szFilePathBz2); // TODO: Add back
}

public Action:Command_Coins(iClient, iArgs)
{
	if(!g_bPluginEnabled)
		return Plugin_Handled;
	
	decl iTotalWorth;
	new iNumCoins[NUM_COIN_TYPES], iTotalCoins;
	
	if(iArgs < 1)
	{
		iTotalWorth = 10;
	}
	else
	{
		decl String:szWorth[5];
		GetCmdArg(1, szWorth, sizeof(szWorth));
		iTotalWorth = StringToInt(szWorth);
		
		if(iTotalWorth > 200)
			iTotalWorth = 200;
		
		if(iTotalWorth < 0)
			iTotalWorth = 0;
	}
	
	new i;
	if(iTotalWorth > 0)
	{
		decl iWorthRemaining, iCoinType;
		while(i < iTotalWorth)
		{
			iWorthRemaining = iTotalWorth - i;
			
			if(iWorthRemaining >= g_iCoinWorth[COIN_PLATINUM])
			{
				iCoinType = COIN_PLATINUM;
			}
			else if(iWorthRemaining >= g_iCoinWorth[COIN_GOLD])
			{
				iCoinType = COIN_GOLD;
			}
			else if(iWorthRemaining >= g_iCoinWorth[COIN_SILVER])
			{
				iCoinType = COIN_SILVER;
			}
			else
			{
				iCoinType = COIN_COPPER;
			}
			
			iNumCoins[iCoinType]++;
			i += g_iCoinWorth[iCoinType];
			
			iTotalCoins++;
		}
	}
	else
	{
		for(i=0; i<10; i++)
		{
			iNumCoins[GetRandomInt(0, NUM_COIN_TYPES-1)]++;
			iTotalCoins++;
		}
	}
	
	PlaySound_Snob(iClient);
	
	decl Float:fOrigin[3], Float:fVelocity[3], Float:fAngles[3], Float:fEyeAngles[3], iCoin;
	GetClientEyeAngles(iClient, fEyeAngles);
	GetClientAbsOrigin(iClient, fOrigin);
	fOrigin[2] += 32.0;
	
	for(new iCoinType=0; iCoinType<sizeof(iNumCoins); iCoinType++)
	{
		for(i=0; i<iNumCoins[iCoinType]; i++)
		{
			iCoin = CreateCoin(iClient);
			if(iCoin < 1)
				continue;
			
			ScaleEntity(iCoin, 0, g_fCoinScale[iCoinType]);
			SetEntProp(iCoin, Prop_Send, "m_nSkin", iCoinType);
			
			PushArrayCell(g_aCoinRefs, EntIndexToEntRef(iCoin));
			
			fVelocity[0] = fEyeAngles[0] + GetRandomFloat(-40.0, -20.0);
			fVelocity[1] = fEyeAngles[1] + GetRandomFloat(-20.0, 20.0);
			fVelocity[2] = fEyeAngles[2];
			
			GetAngleVectors(fVelocity, fVelocity, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(fVelocity, GetRandomFloat(350.0, 450.0));
			
			fAngles[0] = 0.0;
			fAngles[1] = GetRandomFloat(-179.0, 179.0);
			fAngles[2] = 0.0;
			
			if(iTotalWorth > 0)
				SetCoinWorth(iCoin, g_iCoinWorth[iCoinType]);
			else
				SetCoinWorth(iCoin, 0);
			
			TeleportEntity(iCoin, fOrigin, fAngles, fVelocity);
		}
	}
	
	if(g_hTimer == INVALID_HANDLE)
		g_hTimer = CreateTimer(3.0, Timer_CleanUp, _, TIMER_REPEAT);
	
	ReplyToCommand(iClient, "[SM] Threw %i coin%s worth a total of %i.", iTotalCoins, (iTotalCoins == 1) ? "" : "s", iTotalWorth);
	CPrintToChat(iClient, "{olive}Threw {lightred}%i {olive}coin%s worth a total of {lightred}%i{olive}.", iTotalCoins, (iTotalCoins == 1) ? "" : "s", iTotalWorth);
	
	return Plugin_Handled;
}

ScaleEntity(iEnt, iScaleType=0, Float:fScale=1.0)
{
	SetEntProp(iEnt, Prop_Send, "m_ScaleType", iScaleType);
	SetEntPropFloat(iEnt, Prop_Send, "m_flModelScale", fScale);
}

public Action:Timer_CleanUp(Handle:hTimer)
{
	decl iCoin, bool:bRemove;
	new Float:fCurTime = GetGameTime();
	
	for(new i=0; i<GetArraySize(g_aCoinRefs); i++)
	{
		bRemove = false;
		iCoin = EntRefToEntIndex(GetArrayCell(g_aCoinRefs, i));
		
		if(iCoin < 1 || (GetSpawnedTime(iCoin) + REMOVE_DELAY) < fCurTime)
		{
			bRemove = true;
			RemoveFromArray(g_aCoinRefs, i);
			i--;
		}
		
		if(iCoin > 0 && bRemove)
		{
			// TODO: Add to fade out array instead of removing?
			RemoveCoin(iCoin);
		}
	}
	
	return Plugin_Continue;
}

CreateCoin(iClient)
{
	new iEnt = CreateEntityByName("smokegrenade_projectile");
	if(iEnt < 1 || !IsValidEntity(iEnt))
		return 0;
	
	InitCoin(iClient, iEnt);
	return iEnt;
}

InitCoin(iClient, iEnt)
{
	DispatchSpawn(iEnt);
	
	SetEntityModel(iEnt, MODEL_COIN); // WARNING: Make sure we set the model *before* setting the mins/maxs.
	
	SetEntityGravity(iEnt, 0.7);
	SetEntPropFloat(iEnt, Prop_Data, "m_flElasticity", 3.0);
	
	SetEntityMoveType(iEnt, MOVETYPE_FLYGRAVITY);
	SetEntProp(iEnt, Prop_Send, "movecollide", MOVECOLLIDE_FLY_BOUNCE);
	SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
	SetEntProp(iEnt, Prop_Data, "m_nSolidType", SOLID_BBOX);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER | FSOLID_USE_TRIGGER_BOUNDS);
	SetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity", iClient);
	
	/*
	SetEntProp(iEnt, Prop_Data, "m_nSurroundType", USE_SPECIFIED_BOUNDS);
	SetEntPropFloat(iEnt, Prop_Data, "m_flRadius", 0.0);
	SetEntProp(iEnt, Prop_Data, "m_triggerBloat", 0);
	*/
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", g_fCoinMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", g_fCoinMaxs);
	
	/*
	SetEntPropVector(iEnt, Prop_Send, "m_vecSpecifiedSurroundingMins", g_fCoinMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecSpecifiedSurroundingMaxs", g_fCoinMaxs);
	
	SetEntPropVector(iEnt, Prop_Data, "m_vecSurroundingMins", g_fCoinMins);
	SetEntPropVector(iEnt, Prop_Data, "m_vecSurroundingMaxs", g_fCoinMaxs);
	*/
	
	SetSpawnedTime(iEnt);
	
	SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost);
}

SetCoinWorth(iCoin, iWorth)
{
	SetEntProp(iCoin, Prop_Send, "m_iPendingTeamNum", iWorth);
}

GetCoinWorth(iCoin)
{
	return GetEntProp(iCoin, Prop_Send, "m_iPendingTeamNum");
}

SetSpawnedTime(iCoin)
{
	SetEntPropFloat(iCoin, Prop_Send, "m_DmgRadius", GetGameTime());
}

Float:GetSpawnedTime(iCoin)
{
	return GetEntPropFloat(iCoin, Prop_Send, "m_DmgRadius");
}

OnCoinBounce(iCoin)
{
	new iBounces = GetEntProp(iCoin, Prop_Send, "m_nBounces");
	iBounces++;
	
	if(iBounces > 5)
		return;
	
	if(iBounces == 5)
		SetEntPropFloat(iCoin, Prop_Data, "m_flElasticity", 0.0);
	
	SetEntProp(iCoin, Prop_Send, "m_nBounces", iBounces);
	PlaySound_CoinBounce(iCoin);
}

PlaySound_CoinBounce(iCoin)
{
	EmitSoundToAllAny(SOUND_COIN[6], iCoin, 17, 55);
}

PlaySound_Snob(iClient)
{
	EmitSoundToAllAny(SOUND_SNOB_FILES[GetRandomInt(0, sizeof(SOUND_SNOB_FILES)-1)][6], iClient, 17, 80);
}

public OnStartTouchPost(iCoin, iOther)
{
	if(1 <= iOther <= MaxClients)
	{
		ClientPickupCoin(iOther, iCoin);
		return;
	}
	
	OnCoinBounce(iCoin);
}

ClientPickupCoin(iClient, iCoin)
{
	/*
	new iOwner = GetEntPropEnt(iCoin, Prop_Send, "m_hOwnerEntity");
	if(iOwner == iClient)
		return;
	*/
	
	if(GetSpawnedTime(iCoin) + PICKUP_DELAY > GetGameTime())
		return;
	
	PlaySound_CoinBounce(iCoin);
	new iNumPoints = GetCoinWorth(iCoin);
	
	RemoveCoin(iCoin);
	
	CPrintToChat(iClient, "{yellow}Coin {olive}gave you {yellow}%i {olive}points.", iNumPoints);
	
	UserPoints_GivePoints(iClient, iNumPoints);
}

RemoveCoin(iCoin)
{
	SetEntProp(iCoin, Prop_Data, "m_nSolidType", SOLID_NONE);
	AcceptEntityInput(iCoin, "KillHierarchy");
}