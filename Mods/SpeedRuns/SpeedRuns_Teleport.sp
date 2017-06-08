#include <sourcemod>
#include <sdkhooks>
#include <sdktools_trace>
#include <sdktools_functions>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <sdktools_entinput>
#include <cstrike>
#include "../../Libraries/ZoneManager/zone_manager"
#include "../../Libraries/MovementStyles/movement_styles"
#include "Includes/speed_runs"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../Plugins/AllowMorePlayers/allow_more_players"
#include "../../Plugins/CourseAutoRespawn/course_auto_respawn"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Speed Runs: Teleport";
new const String:PLUGIN_VERSION[] = "1.22";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The speed run teleport plugin.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const Float:HULL_STANDING_MINS_CSGO[] = {-16.0, -16.0, 0.0};
new const Float:HULL_STANDING_MAXS_CSGO[] = {16.0, 16.0, 72.0};

new g_iCurrentStage[MAXPLAYERS+1];

#define BLOCK_STAGE_START_DELAY	0.2
new Float:g_fBlockStageStartDelay[MAXPLAYERS+1];

new bool:g_bCanUseTeleport[MAXPLAYERS+1];
new g_iSpawnTick[MAXPLAYERS+1];

new Float:g_fTeleportOrigin[MAX_STAGES+1][3];
new bool:g_bHasTeleportOrigin[MAX_STAGES+1];

// Variables for displaying beams to info_teleport_destination
new bool:g_bShowTeleportDestinations[MAXPLAYERS+1];

#define BEAM_UPDATE_DELAY	0.5
new Float:g_fNextBeamUpdate[MAXPLAYERS+1];

new g_iBeamIndex;
new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";

new Handle:g_hFwd_OnRestart;
new Handle:g_hFwd_OnSendToSpawn;
new Handle:g_hFwd_OnTeleport_Pre;
new Handle:g_hFwd_OnTeleport_Post;

new Handle:cvar_restart_is_respawn;
new Handle:cvar_allow_respawn_only;

new Handle:cvar_mp_free_armor;

new bool:g_bLibLoaded_AllowMorePlayers;
new bool:g_bLibLoaded_CourseAutoRespawn;
new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	CreateConVar("speed_runs_teleport_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_restart_is_respawn = CreateConVar("speedruns_teleport_restart_is_respawn", "0", "0: Default behavior -- 1: Restart will act like respawn.", _, true, 0.0, true, 1.0);
	cvar_allow_respawn_only = CreateConVar("speedruns_teleport_allow_respawn_only", "0", "0: Default behavior -- 1: Only the spawn command is allowed.", _, true, 0.0, true, 1.0);
	
	cvar_mp_free_armor = FindConVar("mp_free_armor");
	
	RegConsoleCmd("sm_s", OnStage);
	RegConsoleCmd("sm_stage", OnStage);
	
	RegConsoleCmd("sm_b", OnBonus);
	RegConsoleCmd("sm_bonus", OnBonus);
	
	RegConsoleCmd("sm_prev", OnBack);
	RegConsoleCmd("sm_back", OnBack);
	RegConsoleCmd("sm_goback", OnBack);
	RegConsoleCmd("sm_gb", OnBack);
	
	RegConsoleCmd("sm_next", OnNext);
	RegConsoleCmd("sm_gonext", OnNext);
	RegConsoleCmd("sm_gn", OnNext);
	
	RegConsoleCmd("sm_restart", OnRestart);
	RegConsoleCmd("sm_r", OnRestart);
	
	RegConsoleCmd("sm_spawn", OnSpawn);
	
	RegConsoleCmd("sm_teleport", OnTeleport);
	RegConsoleCmd("sm_tele", OnTeleport);
	RegConsoleCmd("sm_t", OnTeleport);
	
	//RegConsoleCmd("sm_goto", OnGoto);
	
	RegAdminCmd("sm_reloadteleports", Command_ReloadTeleports, ADMFLAG_ROOT, "sm_reloadteleports - Reloads the teleports for each stage.");
	RegAdminCmd("sm_showteledests", Command_ShowTeleportDestinations, ADMFLAG_ROOT, "sm_showteledests - Shows the teleport destinations.");
	RegAdminCmd("sm_showtargetname", Command_ShowTargetName, ADMFLAG_ROOT, "sm_showtargetname - Shows your current targetname.");
	
	g_hFwd_OnRestart = CreateGlobalForward("SpeedRunsTeleport_OnRestart", ET_Ignore, Param_Cell);
	g_hFwd_OnSendToSpawn = CreateGlobalForward("SpeedRunsTeleport_OnSendToSpawn", ET_Ignore, Param_Cell);
	
	g_hFwd_OnTeleport_Pre = CreateGlobalForward("SpeedRunsTeleport_OnTeleport_Pre", ET_Hook, Param_Cell, Param_Cell);
	g_hFwd_OnTeleport_Post = CreateGlobalForward("SpeedRunsTeleport_OnTeleport_Post", ET_Ignore, Param_Cell, Param_Cell);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_AllowMorePlayers = LibraryExists("allow_more_players");
	g_bLibLoaded_CourseAutoRespawn = LibraryExists("course_auto_respawn");
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "allow_more_players"))
	{
		g_bLibLoaded_AllowMorePlayers = true;
	}
	else if(StrEqual(szName, "course_auto_respawn"))
	{
		g_bLibLoaded_CourseAutoRespawn = true;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "allow_more_players"))
	{
		g_bLibLoaded_AllowMorePlayers = false;
	}
	else if(StrEqual(szName, "course_auto_respawn"))
	{
		g_bLibLoaded_CourseAutoRespawn = false;
	}
	else if(StrEqual(szName, "model_skin_manager"))
	{
		g_bLibLoaded_ModelSkinManager = false;
	}
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("speed_runs_teleport");
	CreateNative("SpeedRunsTeleport_TeleportToStage", _SpeedRunsTeleport_TeleportToStage);
	CreateNative("SpeedRunsTeleport_IsAllowedToTeleport", _SpeedRunsTeleport_IsAllowedToTeleport);
	
	return APLRes_Success;
}

public _SpeedRunsTeleport_IsAllowedToTeleport(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
		SetFailState("Invalid number of parameters SpeedRunsTeleport_IsAllowedToTeleport");
	
	return IsAllowedToTeleport(GetNativeCell(1));
}

bool:IsAllowedToTeleport(iClient)
{
	if(GetGameTickCount() == g_iSpawnTick[iClient])
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Cannot teleport yet.");
		return false;
	}
	
	if(GetEntProp(iClient, Prop_Send, "m_hGroundEntity") == -1)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}You must be on the ground to teleport.");
		return false;
	}
	
	return true;
}

public _SpeedRunsTeleport_TeleportToStage(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
		SetFailState("Invalid number of parameters SpeedRunsTeleport_TeleportToStage");
	
	TeleportToStage(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));
}

Forward_OnRestart(iClient)
{
	decl result;
	Call_StartForward(g_hFwd_OnRestart);
	Call_PushCell(iClient);
	Call_Finish(result);
}

Forward_OnSendToSpawn(iClient)
{
	decl result;
	Call_StartForward(g_hFwd_OnSendToSpawn);
	Call_PushCell(iClient);
	Call_Finish(result);
}

bool:Forward_OnTeleport(iClient, iStageNumber, bool:bIsPre)
{
	decl Action:result;
	Call_StartForward(bIsPre ? g_hFwd_OnTeleport_Pre : g_hFwd_OnTeleport_Post);
	Call_PushCell(iClient);
	Call_PushCell(iStageNumber);
	Call_Finish(result);
	
	if(bIsPre && result >= Plugin_Handled)
		return false;
	
	return true;
}

public OnMapStart()
{
	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL);
}

public OnClientPutInServer(iClient)
{
	g_iCurrentStage[iClient] = 0;
	g_fBlockStageStartDelay[iClient] = 0.0;
	
	g_bShowTeleportDestinations[iClient] = false;
	SDKHook(iClient, SDKHook_Spawn, OnSpawnPre);
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPre(iClient)
{
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	g_iSpawnTick[iClient] = GetGameTickCount();
}

public OnSpawnPost(iClient)
{
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	g_bCanUseTeleport[iClient] = true;
}

public Action:SpeedRuns_OnStageStarted_Pre(iClient, iStageNumber, iStyleBits)
{
	if(g_fBlockStageStartDelay[iClient] >= GetGameTime())
		return Plugin_Stop;
	
	g_iCurrentStage[iClient] = iStageNumber;
	
	return Plugin_Continue;
}

public SpeedRuns_OnStageStarted_Post(iClient, iStageNumber, iStyleBits)
{
	g_bCanUseTeleport[iClient] = true;
}

public SpeedRuns_OnStageCompleted_Pre(iClient, iStageNumber, iStyleBits, Float:fTimeTaken)
{
	new iFinalEndStageNumber = GetFinalEndStageNumber();
	
	if(iStageNumber <= iFinalEndStageNumber)
	{
		// Regular stages.
		g_iCurrentStage[iClient] = iStageNumber + 1;
	}
	else
	{
		// Bonus stages (teleport back to the same stage they just beat).
		g_iCurrentStage[iClient] = iStageNumber;
	}
	
	// Stop client from teleporting until they hit the next start unless this is the final end or the end of a bonus.
	if(SpeedRuns_IsInTotalRun(iClient) && iStageNumber && iStageNumber < iFinalEndStageNumber)
		g_bCanUseTeleport[iClient] = false;
}

GetFinalEndStageNumber()
{
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END);
	SortEndZonesByStageNumber(hZoneIDs);
	
	decl iZoneID;
	for(new i=GetArraySize(hZoneIDs)-1; i>=0; i--)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		
		// Continue if it's not the final end.
		if(!ZoneManager_GetDataInt(iZoneID, 2))
			continue;
		
		CloseHandle(hZoneIDs);
		return ZoneManager_GetDataInt(iZoneID, 1);
	}
	
	CloseHandle(hZoneIDs);
	
	return 0;
}

public Action:OnTeleport(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_allow_respawn_only))
		return Plugin_Handled;
	
	if(!g_bCanUseTeleport[iClient])
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Start the next stage before using teleport.");
		return Plugin_Handled;
	}
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	SortStartZonesByStageNumber(hZoneIDs);
	
	new iArraySize = GetArraySize(hZoneIDs);
	if(!iArraySize)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no stages.");
		CloseHandle(hZoneIDs);
		return Plugin_Handled;
	}
	
	decl iFirstStageNum, iZoneID;
	iZoneID = GetArrayCell(hZoneIDs, 0);
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default:
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
			CloseHandle(hZoneIDs);
			return Plugin_Handled;
		}
	}
	
	new iCurrentStage = g_iCurrentStage[iClient];
	if(!iCurrentStage)
		iCurrentStage = iFirstStageNum;
	
	TeleportToStage(iClient, iCurrentStage, false);
	CloseHandle(hZoneIDs);
	
	return Plugin_Handled;
}

public Action:OnSpawn(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	SendClientToSpawn(iClient);
	
	return Plugin_Handled;
}

SendClientToSpawn(iClient)
{
	new iTeam = GetClientTeam(iClient);
	if(iTeam < CS_TEAM_T)
		FakeClientCommand(iClient, "jointeam %i", (GetTeamClientCount(2) < GetTeamClientCount(3)) ? 2 : 3);
	
	if(SpeedRuns_GetServerGroupType() == GROUP_TYPE_COURSE)
	{
		#if defined _course_auto_respawn_included
		if(g_bLibLoaded_CourseAutoRespawn && !CourseAutoRespawn_IsAutoRespawnOn())
		{
			CPrintToChat(iClient, "{lightgreen}-- {red}Cannot use this command when the respawn bot is dead.");
			return;
		}
		#else
		// Suppress warning.
		if(g_bLibLoaded_CourseAutoRespawn)
		{
		}
		
		return;
		#endif
	}
	
	new bool:bRealRespawned;
	if(!IsPlayerAlive(iClient))
	{
		CS_RespawnPlayer(iClient);
		bRealRespawned = true;
	}
	
	// Make sure we try to cancel the players run after trying to real respawn them.
	SpeedRuns_CancelRun(iClient);
	
	if(bRealRespawned)
		return;
	
	decl Float:fOrigin[3], Float:fAngles[3];
	
	if(g_bLibLoaded_AllowMorePlayers)
	{
		#if defined _allow_more_players_included
		new iCreatedSpawnCount = AllowMorePlayers_GetCreatedSpawnCount();
		if(iCreatedSpawnCount && iTeam == AllowMorePlayers_GetCreatedSpawnTeam())
		{
			new iSpawnIndex = GetRandomInt(0, iCreatedSpawnCount-1);
			
			if(AllowMorePlayers_GetCreatedSpawnData(iSpawnIndex, fOrigin, fAngles))
			{
				TeleportToSpawn(iClient, fOrigin, fAngles);
				return;
			}
		}
		#endif
	}
	
	new String:szClassName[32];
	switch(iTeam)
	{
		case CS_TEAM_T: szClassName = "info_player_terrorist";
		case CS_TEAM_CT: szClassName = "info_player_counterterrorist";
		default: return;
	}
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, szClassName)) != -1)
		break;
	
	if(iEnt == -1)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Could not find your teams spawn points.");
		return;
	}
	
	GetEntPropVector(iEnt, Prop_Data, "m_vecAbsOrigin", fOrigin);
	GetEntPropVector(iEnt, Prop_Data, "m_angAbsRotation", fAngles);
	TeleportToSpawn(iClient, fOrigin, fAngles);
}

TeleportToSpawn(iClient, const Float:fOrigin[3], const Float:fAngles[3])
{
	TeleportEntity(iClient, fOrigin, fAngles, Float:{0.0, 0.0, 0.0});
	
	SetEntityHealth(iClient, 100);
	
	if(GetConVarBool(cvar_mp_free_armor))
	{
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", 100);
		SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 1);
	}
	
	Forward_OnSendToSpawn(iClient);
}

public Action:OnRestart(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_restart_is_respawn))
	{
		SendClientToSpawn(iClient);
		return Plugin_Handled;
	}
	
	if(GetConVarBool(cvar_allow_respawn_only))
		return Plugin_Handled;
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	SortStartZonesByStageNumber(hZoneIDs);
	
	new iArraySize = GetArraySize(hZoneIDs);
	if(!iArraySize)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no stages.");
		CloseHandle(hZoneIDs);
		return Plugin_Handled;
	}
	
	decl iFirstStageNum, iZoneID;
	iZoneID = GetArrayCell(hZoneIDs, 0);
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default:
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
			CloseHandle(hZoneIDs);
			return Plugin_Handled;
		}
	}
	
	CloseHandle(hZoneIDs);
	
	if(TeleportToStage(iClient, iFirstStageNum))
		Forward_OnRestart(iClient);
	
	return Plugin_Handled;
}

public Action:OnBack(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_allow_respawn_only))
		return Plugin_Handled;
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	SortStartZonesByStageNumber(hZoneIDs);
	
	new iArraySize = GetArraySize(hZoneIDs);
	if(!iArraySize)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no stages.");
		CloseHandle(hZoneIDs);
		return Plugin_Handled;
	}
	
	decl iFirstStageNum, iLastStageNum, iStageNum, iZoneID;
	iZoneID = GetArrayCell(hZoneIDs, 0);
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default:
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
			CloseHandle(hZoneIDs);
			return Plugin_Handled;
		}
	}
	
	iZoneID = GetArrayCell(hZoneIDs, iArraySize-1);
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iLastStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iLastStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default:
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
			CloseHandle(hZoneIDs);
			return Plugin_Handled;
		}
	}
	
	// Teleport to the last stage number if we are at the first stage number already.
	new iCurrentStage = g_iCurrentStage[iClient];
	if(!iCurrentStage)
		iCurrentStage = iFirstStageNum;
	
	if(iCurrentStage <= iFirstStageNum)
	{
		CloseHandle(hZoneIDs);
		TeleportToStage(iClient, iLastStageNum);
		return Plugin_Handled;
	}
	
	new iLowest = iFirstStageNum;
	for(new i=0; i<iArraySize; i++)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default:
			{
				CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
				CloseHandle(hZoneIDs);
				return Plugin_Handled;
			}
		}
		
		if(iStageNum < iCurrentStage)
		{
			iLowest = iStageNum;
			continue;
		}
		
		TeleportToStage(iClient, iLowest, false);
		break;
	}
	
	CloseHandle(hZoneIDs);
	
	return Plugin_Handled;
}

public Action:OnNext(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_allow_respawn_only))
		return Plugin_Handled;
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	SortStartZonesByStageNumber(hZoneIDs);
	
	new iArraySize = GetArraySize(hZoneIDs);
	if(!iArraySize)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no stages.");
		CloseHandle(hZoneIDs);
		return Plugin_Handled;
	}
	
	decl iFirstStageNum, iLastStageNum, iStageNum, iZoneID;
	iZoneID = GetArrayCell(hZoneIDs, 0);
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iFirstStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default:
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
			CloseHandle(hZoneIDs);
			return Plugin_Handled;
		}
	}
	
	iZoneID = GetArrayCell(hZoneIDs, iArraySize-1);
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iLastStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iLastStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default:
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
			CloseHandle(hZoneIDs);
			return Plugin_Handled;
		}
	}
	
	// Teleport to the first stage number if we are at the last stage number already.
	new iCurrentStage = g_iCurrentStage[iClient];
	if(!iCurrentStage)
		iCurrentStage = iFirstStageNum;
	
	if(iCurrentStage >= iLastStageNum)
	{
		CloseHandle(hZoneIDs);
		TeleportToStage(iClient, iFirstStageNum);
		return Plugin_Handled;
	}
	
	new iHighest = iLastStageNum;
	for(new i=iArraySize-1; i>=0; i--)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default:
			{
				CPrintToChat(iClient, "{lightgreen}-- {olive}There was an error.");
				CloseHandle(hZoneIDs);
				return Plugin_Handled;
			}
		}
		
		if(iStageNum > iCurrentStage)
		{
			iHighest = iStageNum;
			continue;
		}
		
		TeleportToStage(iClient, iHighest);
		break;
	}
	
	CloseHandle(hZoneIDs);
	
	return Plugin_Handled;
}

public Action:OnBonus(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_allow_respawn_only))
		return Plugin_Handled;
	
	if(!iArgCount)
	{
		DisplayMenu_BonusSelect(iClient);
		return Plugin_Handled;
	}
	
	decl String:szBonusNum[11];
	GetCmdArg(1, szBonusNum, sizeof(szBonusNum));
	new iBonusNum = StringToInt(szBonusNum);
	
	if(iBonusNum < 1)
	{
		DisplayMenu_BonusSelect(iClient);
		return Plugin_Handled;
	}
	
	new iStageNum = GetBonusStageNumber(iBonusNum);
	if(!iStageNum)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Bonus {lightred}%i {olive}doesn't exist.", iBonusNum);
		return Plugin_Handled;
	}
	
	TeleportToStage(iClient, iStageNum);
	
	return Plugin_Handled;
}

GetBonusStageNumber(iBonusNum)
{
	new iFinalEndStageNum = GetFinalEndStageNumber();
	if(!iFinalEndStageNum)
		return 0;
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	SortStartZonesByStageNumber(hZoneIDs);
	
	new bool:bAtBonusStages, iStageNumber, iBonusCount;
	
	decl iZoneID, iTempStageNum;
	for(new i=0; i<GetArraySize(hZoneIDs); i++)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iTempStageNum = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iTempStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default: continue;
		}
		
		if(iTempStageNum == iFinalEndStageNum)
		{
			bAtBonusStages = true;
			continue;
		}
		
		if(!bAtBonusStages)
			continue;
		
		iBonusCount++;
		if(iBonusCount != iBonusNum)
			continue;
		
		iStageNumber = iTempStageNum;
		break;
	}
	
	CloseHandle(hZoneIDs);
	
	return iStageNumber;
}

DisplayMenu_BonusSelect(iClient)
{
	new iFinalEndStageNum = GetFinalEndStageNumber();
	if(!iFinalEndStageNum)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no bonuses to select.");
		return;
	}
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	SortStartZonesByStageNumber(hZoneIDs);
	
	new Handle:hMenu = CreateMenu(MenuHandle_BonusSelect);
	SetMenuTitle(hMenu, "Bonus Select");
	
	new bool:bAtBonusStages;
	decl iZoneID, iStageNum, String:szStageName[MAX_ZONE_DATA_STRING_LENGTH], String:szInfo[12];
	for(new i=0; i<GetArraySize(hZoneIDs); i++)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default: continue;
		}
		
		if(iStageNum == iFinalEndStageNum)
		{
			bAtBonusStages = true;
			continue;
		}
		
		if(!bAtBonusStages)
			continue;
		
		if(!ZoneManager_GetDataString(iZoneID, 1, szStageName, sizeof(szStageName)) || !szStageName[0])
			FormatEx(szStageName, sizeof(szStageName), "Stage %i", iStageNum);
		
		IntToString(iZoneID, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szStageName);
	}
	
	CloseHandle(hZoneIDs);
	
	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no bonuses to select.");
}

public MenuHandle_BonusSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iZoneID = StringToInt(szInfo);
	
	decl iStageNum;
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default: return;
	}
	
	TeleportToStage(iParam1, iStageNum);
}

public Action:OnStage(iClient, iArgCount)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarBool(cvar_allow_respawn_only))
		return Plugin_Handled;
	
	if(!iArgCount)
	{
		DisplayMenu_StageSelect(iClient);
		return Plugin_Handled;
	}
	
	decl String:szStageNum[11];
	GetCmdArg(1, szStageNum, sizeof(szStageNum));
	new iStageNum = StringToInt(szStageNum);
	
	if(iStageNum < 1)
	{
		DisplayMenu_StageSelect(iClient);
		return Plugin_Handled;
	}
	
	new iFinalStageNum = GetFinalEndStageNumber();
	if(!iFinalStageNum)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}You cannot teleport until the final end zone is created.");
		return Plugin_Handled;
	}
	
	if(iStageNum > iFinalStageNum)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Stage {lightred}%i {olive}doesn't exist. Try {lightred}!bonus{olive}.", iStageNum);
		return Plugin_Handled;
	}
	
	TeleportToStage(iClient, iStageNum);
	
	return Plugin_Handled;
}

DisplayMenu_StageSelect(iClient)
{
	new iFinalEndStageNum = GetFinalEndStageNumber();
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	SortStartZonesByStageNumber(hZoneIDs);
	
	new Handle:hMenu = CreateMenu(MenuHandle_StageSelect);
	SetMenuTitle(hMenu, "Stage Select");
	
	decl iZoneID, iStageNum, String:szStageName[MAX_ZONE_DATA_STRING_LENGTH], String:szInfo[12];
	for(new i=0; i<GetArraySize(hZoneIDs); i++)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default: continue;
		}
		
		if(iFinalEndStageNum && iStageNum > iFinalEndStageNum)
			break;
		
		if(!ZoneManager_GetDataString(iZoneID, 1, szStageName, sizeof(szStageName)) || !szStageName[0])
			FormatEx(szStageName, sizeof(szStageName), "Stage %i", iStageNum);
		
		IntToString(iZoneID, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szStageName);
	}
	
	CloseHandle(hZoneIDs);
	
	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{lightgreen}-- {olive}There are no stages to select.");
}

SortStartZonesByStageNumber(Handle:hZoneIDs)
{
	new iArraySize = GetArraySize(hZoneIDs);
	
	decl iZoneID, iStageNum1, iStageNum2, iIndex, j, iLeast;
	for(new i=0; i<iArraySize; i++)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iStageNum1 = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iStageNum1 = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default: continue;
		}
		
		iIndex = 0;
		iLeast = iStageNum1;
		for(j=i+1; j<iArraySize; j++)
		{
			iZoneID = GetArrayCell(hZoneIDs, j);
			
			switch(ZoneManager_GetZoneType(iZoneID))
			{
				case ZONE_TYPE_TIMER_START: iStageNum2 = ZoneManager_GetDataInt(iZoneID, 1);
				case ZONE_TYPE_TIMER_END_START: iStageNum2 = ZoneManager_GetDataInt(iZoneID, 1) + 1;
				default: continue;
			}
			
			if(iStageNum2 > iLeast)
				continue;
			
			iIndex = j;
			iLeast = iStageNum2;
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(hZoneIDs, i, iIndex);
	}
}

SortEndZonesByStageNumber(Handle:hZoneIDs)
{
	new iArraySize = GetArraySize(hZoneIDs);
	
	decl iZoneID, iStageNum1, iStageNum2, iIndex, j, iLeast;
	for(new i=0; i<iArraySize; i++)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_END: iStageNum1 = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iStageNum1 = ZoneManager_GetDataInt(iZoneID, 1);
			default: continue;
		}
		
		iIndex = 0;
		iLeast = iStageNum1;
		for(j=i+1; j<iArraySize; j++)
		{
			iZoneID = GetArrayCell(hZoneIDs, j);
			
			switch(ZoneManager_GetZoneType(iZoneID))
			{
				case ZONE_TYPE_TIMER_END: iStageNum2 = ZoneManager_GetDataInt(iZoneID, 1);
				case ZONE_TYPE_TIMER_END_START: iStageNum2 = ZoneManager_GetDataInt(iZoneID, 1);
				default: continue;
			}
			
			if(iStageNum2 > iLeast)
				continue;
			
			iIndex = j;
			iLeast = iStageNum2;
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(hZoneIDs, i, iIndex);
	}
}

public MenuHandle_StageSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iZoneID = StringToInt(szInfo);
	
	decl iStageNum;
	switch(ZoneManager_GetZoneType(iZoneID))
	{
		case ZONE_TYPE_TIMER_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1);
		case ZONE_TYPE_TIMER_END_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
		default: return;
	}
	
	TeleportToStage(iParam1, iStageNum);
}

bool:TeleportToStage(iClient, iStageNum, bool:bCancelRun=true)
{
	if(!bCancelRun && MovementStyles_GetStyleBits(iClient) & STYLE_BIT_PRO_TIMER)
	{
		CPrintToChat(iClient, "{lightgreen}-- {red}Cannot use teleports in a Pro Timer run.");
		return false;
	}
	
	if(!IsAllowedToTeleport(iClient))
		return false;
	
	new iZoneID = FindZoneByStageNumber(iStageNum);
	if(!iZoneID)
	{
		CPrintToChat(iClient, "{lightgreen}-- {olive}Stage {lightred}%i {olive}doesn't exist.", iStageNum);
		return false;
	}
	
	decl Float:fOrigin[3];
	
	if(g_bHasTeleportOrigin[iStageNum])
	{
		fOrigin[0] = g_fTeleportOrigin[iStageNum][0];
		fOrigin[1] = g_fTeleportOrigin[iStageNum][1];
		fOrigin[2] = g_fTeleportOrigin[iStageNum][2];
	}
	else
	{
		if(!ZoneManager_GetZoneOrigin(iZoneID, fOrigin) || !FindTeleportOrigin(iZoneID, fOrigin))
		{
			CPrintToChat(iClient, "{lightgreen}-- {olive}Could not find a valid teleport location.");
			return false;
		}
	}
	
	if(!Forward_OnTeleport(iClient, iStageNum, true))
		return false;
	
	g_fBlockStageStartDelay[iClient] = GetGameTime() + BLOCK_STAGE_START_DELAY;
	
	if(bCancelRun)
		SpeedRuns_CancelRun(iClient);
	
	// Change clients target name to whatever this stage has its filter set to if needed.
	decl String:szFilter[MAX_ZONE_DATA_STRING_LENGTH];
	new bool:bGotFilter = ZoneManager_GetDataString(iZoneID, 3, szFilter, sizeof(szFilter));
	if(bGotFilter && szFilter[0])
		SetEntPropString(iClient, Prop_Data, "m_iName", szFilter);
	else
		SetEntPropString(iClient, Prop_Data, "m_iName", "");
	
	decl String:szBuffer[MAX_ZONE_DATA_STRING_LENGTH];
	if(!ZoneManager_GetDataString(iZoneID, 1, szBuffer, sizeof(szBuffer)) || !szBuffer[0])
		FormatEx(szBuffer, sizeof(szBuffer), "Stage %i", iStageNum);
	
	decl Float:fAngles[3];
	ZoneManager_GetZoneAngles(iZoneID, fAngles);
	TeleportEntity(iClient, fOrigin, fAngles, Float:{0.0, 0.0, 0.0});
	g_iCurrentStage[iClient] = iStageNum;
	g_bCanUseTeleport[iClient] = true;
	
	// Set the targetname to the filter after teleporting as well.
	if(bGotFilter && szFilter[0])
		SetEntPropString(iClient, Prop_Data, "m_iName", szFilter);
	else
		SetEntPropString(iClient, Prop_Data, "m_iName", "");
	
	CPrintToChat(iClient, "{lightgreen}-- {olive}Teleporting to {lightred}%s{olive}.", szBuffer);
	
	Forward_OnTeleport(iClient, iStageNum, false);
	
	return true;
}

bool:FindTeleportOrigin(iZoneID, Float:fOrigin[3])
{
	decl Float:fMins[3], Float:fMaxs[3], Float:fStartOrigin[3];
	ZoneManager_GetZoneMins(iZoneID, fMins);
	ZoneManager_GetZoneMaxs(iZoneID, fMaxs);
	
	// First try to see if we can teleport to the center of the zone.
	fStartOrigin[0] = fOrigin[0] + ((fMins[0] + fMaxs[0]) * 0.5);
	fStartOrigin[1] = fOrigin[1] + ((fMins[1] + fMaxs[1]) * 0.5);
	fStartOrigin[2] = fOrigin[2] + ((fMins[2] + fMaxs[2]) * 0.5);
	
	// Move the origin down either the player maxs or the zones half size (whichever is the smallest move).
	if(FloatAbs(((fMins[2] + fMaxs[2]) * 0.5)) > FloatAbs(HULL_STANDING_MAXS_CSGO[2]))
	{
		fStartOrigin[2] -= FloatAbs(HULL_STANDING_MAXS_CSGO[2]);
		fStartOrigin[2] += 1.0;
	}
	else
	{
		fStartOrigin[2] -= FloatAbs(((fMins[2] + fMaxs[2]) * 0.5));
		fStartOrigin[2] += 1.0;
	}
	
	if(CanTeleportToOrigin(fStartOrigin))
	{
		fOrigin[0] = fStartOrigin[0];
		fOrigin[1] = fStartOrigin[1];
		fOrigin[2] = fStartOrigin[2];
		return true;
	}
	
	// Could not teleport to the center so try to find an open spot in the zone.
	decl iNumChecksOnAxi[3];
	iNumChecksOnAxi[0] = RoundToCeil((FloatAbs(fMins[0]) + FloatAbs(fMaxs[0])) / (FloatAbs(HULL_STANDING_MINS_CSGO[0]) + FloatAbs(HULL_STANDING_MAXS_CSGO[0])));
	iNumChecksOnAxi[1] = RoundToCeil((FloatAbs(fMins[1]) + FloatAbs(fMaxs[1])) / (FloatAbs(HULL_STANDING_MINS_CSGO[1]) + FloatAbs(HULL_STANDING_MAXS_CSGO[1])));
	iNumChecksOnAxi[2] = RoundToCeil((FloatAbs(fMins[2]) + FloatAbs(fMaxs[2])) / (FloatAbs(HULL_STANDING_MINS_CSGO[2]) + FloatAbs(HULL_STANDING_MAXS_CSGO[2])));
	
	// Set the start origin to the zones origin.
	fStartOrigin[0] = fOrigin[0];
	fStartOrigin[1] = fOrigin[1];
	fStartOrigin[2] = fOrigin[2];
	
	// Loop starting at the bottom back left.
	decl j, k;
	fOrigin[2] = fStartOrigin[2] + fMins[2] - HULL_STANDING_MINS_CSGO[2];
	
	for(new i=0; i<iNumChecksOnAxi[2]; i++)
	{
		fOrigin[1] = fStartOrigin[1] + fMins[1] - HULL_STANDING_MINS_CSGO[1];
		
		for(j=0; j<iNumChecksOnAxi[1]; j++)
		{
			fOrigin[0] = fStartOrigin[0] + fMins[0] - HULL_STANDING_MINS_CSGO[0];
			
			for(k=0; k<iNumChecksOnAxi[0]; k++)
			{
				if(CanTeleportToOrigin(fOrigin))
					return true;
				
				fOrigin[0] = fOrigin[0] + (FloatAbs(HULL_STANDING_MINS_CSGO[0]) + FloatAbs(HULL_STANDING_MAXS_CSGO[0]));
			}
			
			fOrigin[1] = fOrigin[1] + (FloatAbs(HULL_STANDING_MINS_CSGO[1]) + FloatAbs(HULL_STANDING_MAXS_CSGO[1]));
		}
		
		fOrigin[2] = fOrigin[2] + (FloatAbs(HULL_STANDING_MINS_CSGO[2]) + FloatAbs(HULL_STANDING_MAXS_CSGO[2]));
	}
	
	return false;
}

bool:CanTeleportToOrigin(Float:fOrigin[3])
{
	TR_TraceHullFilter(fOrigin, fOrigin, HULL_STANDING_MINS_CSGO, HULL_STANDING_MAXS_CSGO, MASK_PLAYERSOLID, TraceFilter_DontHitPlayers);
	if(TR_DidHit())
		return false;
	
	return true;
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}

FindZoneByStageNumber(iStageNum)
{
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	
	decl iZoneID, iTempStageNum;
	for(new i=0; i<GetArraySize(hZoneIDs); i++)
	{
		iZoneID =  GetArrayCell(hZoneIDs, i);
		
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iTempStageNum = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iTempStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default: continue;
		}
		
		if(iStageNum != iTempStageNum)
			continue;
		
		CloseHandle(hZoneIDs);
		return iZoneID;
	}
	
	CloseHandle(hZoneIDs);
	return 0;
}

public Action:Command_ShowTargetName(iClient, iArgs)
{
	if(!iClient)
		return Plugin_Handled;
	
	decl String:szName[128];
	GetEntPropString(iClient, Prop_Data, "m_iName", szName, sizeof(szName));
	
	ReplyToCommand(iClient, "Targetname = [%s]", szName);
	
	return Plugin_Handled;
}


public Action:Command_ReloadTeleports(iClient, iArgs)
{
	FindAllStageTeleportOrigins();
	ReplyToCommand(iClient, "Teleports have been reloaded.");
	return Plugin_Handled;
}

public Action:Command_ShowTeleportDestinations(iClient, iArgs)
{
	if(!iClient)
		return Plugin_Handled;
	
	g_bShowTeleportDestinations[iClient] = !g_bShowTeleportDestinations[iClient];
	
	if(g_bShowTeleportDestinations[iClient])
	{
		ReplyToCommand(iClient, "Type the command again to stop showing teleport destinations.");
		SDKHook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	}
	else
	{
		ReplyToCommand(iClient, "Type the command again to start showing teleport destinations.");
		SDKUnhook(iClient, SDKHook_PostThinkPost, OnPostThinkPost);
	}
	
	decl String:szBuffer[256];
	GetEntPropString(iClient, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
	
	return Plugin_Handled;
}

public ZoneManager_OnZonesLoaded()
{
	FindAllStageTeleportOrigins();
}

FindAllStageTeleportOrigins()
{
	decl i;
	for(i=0; i<sizeof(g_bHasTeleportOrigin); i++)
		g_bHasTeleportOrigin[i] = false;
	
	new Handle:hZoneIDs = CreateArray();
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(hZoneIDs, ZONE_TYPE_TIMER_END_START);
	
	decl iZoneID, iStageNum, iEnt, String:szCustomZoneDest[MAX_ZONE_DATA_STRING_LENGTH], String:szName[64], iIntersectingEnt, String:szExplode[3][16], iNumExplodes;
	for(i=0; i<GetArraySize(hZoneIDs); i++)
	{
		iZoneID = GetArrayCell(hZoneIDs, i);
		
		switch(ZoneManager_GetZoneType(iZoneID))
		{
			case ZONE_TYPE_TIMER_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1);
			case ZONE_TYPE_TIMER_END_START: iStageNum = ZoneManager_GetDataInt(iZoneID, 1) + 1;
			default: continue;
		}
		
		// See if a custom teleport origin was set.
		ZoneManager_GetDataString(iZoneID, 4, szCustomZoneDest, sizeof(szCustomZoneDest));
		if(szCustomZoneDest[0])
		{
			iNumExplodes = ExplodeString(szCustomZoneDest, "/", szExplode, sizeof(szExplode), sizeof(szExplode[]));
			if(iNumExplodes == 3)
			{
				g_fTeleportOrigin[iStageNum][0] = StringToFloat(szExplode[0]);
				g_fTeleportOrigin[iStageNum][1] = StringToFloat(szExplode[1]);
				g_fTeleportOrigin[iStageNum][2] = StringToFloat(szExplode[2]);
				g_bHasTeleportOrigin[iStageNum] = true;
			}
		}
		
		if(g_bHasTeleportOrigin[iStageNum])
			continue;
		
		iIntersectingEnt = 0; // The intersecting ent just means to use a info_player_destination if it's within a zone if no other checks pass.
		ZoneManager_GetDataString(iZoneID, 2, szCustomZoneDest, sizeof(szCustomZoneDest));
		
		iEnt = -1;
		while((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
		{
			GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
			
			if(szCustomZoneDest[0] && StrEqual(szCustomZoneDest, szName, false))
			{
				GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", g_fTeleportOrigin[iStageNum]);
				g_bHasTeleportOrigin[iStageNum] = true;
				break;
			}
			
			if(!IsIntersecting(iEnt, iZoneID))
				continue;
			
			iIntersectingEnt = iEnt;
		}
		
		if(g_bHasTeleportOrigin[iStageNum])
			continue;
		
		iEnt = -1;
		while((iEnt = FindEntityByClassname(iEnt, "info_target")) != -1)
		{
			GetEntPropString(iEnt, Prop_Data, "m_iName", szName, sizeof(szName));
			
			if(szCustomZoneDest[0] && StrEqual(szCustomZoneDest, szName, false))
			{
				GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", g_fTeleportOrigin[iStageNum]);
				g_bHasTeleportOrigin[iStageNum] = true;
				break;
			}
		}
		
		if(g_bHasTeleportOrigin[iStageNum])
			continue;
		
		if(iIntersectingEnt)
		{
			GetEntPropVector(iIntersectingEnt, Prop_Data, "m_vecOrigin", g_fTeleportOrigin[iStageNum]);
			g_bHasTeleportOrigin[iStageNum] = true;
		}
	}
	
	CloseHandle(hZoneIDs);
}

bool:IsIntersecting(iEnt, iZoneID)
{
	decl Float:fEntOrigin[3], Float:fEntMins[3], Float:fEntMaxs[3];
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fEntOrigin);
	GetEntPropVector(iEnt, Prop_Data, "m_vecMins", fEntMins);
	GetEntPropVector(iEnt, Prop_Data, "m_vecMaxs", fEntMaxs);
	
	AddVectors(fEntOrigin, fEntMins, fEntMins);
	AddVectors(fEntOrigin, fEntMaxs, fEntMaxs);
	
	decl Float:fZoneOrigin[3], Float:fZoneMins[3], Float:fZoneMaxs[3];
	ZoneManager_GetZoneOrigin(iZoneID, fZoneOrigin);
	ZoneManager_GetZoneMins(iZoneID, fZoneMins);
	ZoneManager_GetZoneMaxs(iZoneID, fZoneMaxs);
	
	AddVectors(fZoneOrigin, fZoneMins, fZoneMins);
	AddVectors(fZoneOrigin, fZoneMaxs, fZoneMaxs);
	
	if(fZoneMins[0] > fEntMaxs[0]
	|| fZoneMins[1] > fEntMaxs[1]
	|| fZoneMins[2] > fEntMaxs[2]
	
	|| fZoneMaxs[0] < fEntMins[0]
	|| fZoneMaxs[1] < fEntMins[1]
	|| fZoneMaxs[2] < fEntMins[2])
	{
		return false;
	}
	
	return true;
}

public OnPostThinkPost(iClient)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextBeamUpdate[iClient])
		return;
	
	g_fNextBeamUpdate[iClient] = fCurTime + BEAM_UPDATE_DELAY;
	
	static iEnt, String:szName[64], Float:fOrigin[3], Float:fClientOrigin[3], iClosestEnt, Float:fClosestDist, Float:fDist;
	
	GetClientAbsOrigin(iClient, fClientOrigin);
	iClosestEnt = 0;
	fClosestDist = 999999999.0;
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
		
		fDist = GetVectorDistance(fClientOrigin, fOrigin);
		if(fDist >= fClosestDist)
			continue;
		
		iClosestEnt = iEnt;
		fClosestDist = fDist;
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_target")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
		
		fDist = GetVectorDistance(fClientOrigin, fOrigin);
		if(fDist >= fClosestDist)
			continue;
		
		iClosestEnt = iEnt;
		fClosestDist = fDist;
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
		if(iEnt == iClosestEnt)
			TE_SetupBeamEntPoint(0, iClient, g_iBeamIndex, 0, 1, 1, BEAM_UPDATE_DELAY + 0.1, 0.5, 1.5, 0, 0.0, {0, 255, 0, 255}, 20, fOrigin);
		else
			TE_SetupBeamEntPoint(0, iClient, g_iBeamIndex, 0, 1, 1, BEAM_UPDATE_DELAY + 0.1, 0.2, 0.5, 0, 0.0, {255, 0, 0, 190}, 20, fOrigin);
		
		TE_SendToClient(iClient);
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_target")) != -1)
	{
		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fOrigin);
		if(iEnt == iClosestEnt)
			TE_SetupBeamEntPoint(0, iClient, g_iBeamIndex, 0, 1, 1, BEAM_UPDATE_DELAY + 0.1, 0.5, 1.5, 0, 0.0, {0, 255, 0, 255}, 20, fOrigin);
		else
			TE_SetupBeamEntPoint(0, iClient, g_iBeamIndex, 0, 1, 1, BEAM_UPDATE_DELAY + 0.1, 0.2, 0.5, 0, 0.0, {255, 0, 0, 190}, 20, fOrigin);
		
		TE_SendToClient(iClient);
	}
	
	if(iClosestEnt)
	{
		static String:szClassName[32];
		GetEntityClassname(iClosestEnt, szClassName, sizeof(szClassName));
		GetEntPropString(iClosestEnt, Prop_Data, "m_iName", szName, sizeof(szName));
		PrintToConsole(iClient, "Closest is: %s -- %s", szClassName, szName);
		
		GetEntPropVector(iClosestEnt, Prop_Data, "m_vecOrigin", fOrigin);
		TE_SetupBeamRingPoint(fOrigin, 2.0, 80.0, g_iBeamIndex, 0, 1, 1, BEAM_UPDATE_DELAY + 0.1, 5.0, 0.0, {255, 255, 0, 255}, 20, 0);
		TE_SendToClient(iClient);
	}
}

TE_SetupBeamEntPoint(iStartEnt, iEndEnt, iModelIndex, iHaloIndex, iStartFrame, iFramerate, Float:fLife, Float:fWidth, Float:fEndWidth, iFadeLength, Float:fAmplitude, iColor[4], iSpeed, const Float:fStartVec[3]={0.0, 0.0, 0.0}, const Float:fEndVec[3]={0.0, 0.0, 0.0})
{
	TE_Start("BeamEntPoint");
	TE_WriteNum("m_nModelIndex", iModelIndex);
	TE_WriteNum("m_nHaloIndex", iHaloIndex);
	TE_WriteNum("m_nStartFrame", iStartFrame);
	TE_WriteNum("m_nFrameRate", iFramerate);
	TE_WriteFloat("m_fLife", fLife);
	TE_WriteFloat("m_fWidth", fWidth);
	TE_WriteFloat("m_fEndWidth", fEndWidth);
	TE_WriteNum("m_nFadeLength", iFadeLength);
	TE_WriteFloat("m_fAmplitude", fAmplitude);
	TE_WriteNum("m_nSpeed", iSpeed);
	TE_WriteNum("r", iColor[0]);
	TE_WriteNum("g", iColor[1]);
	TE_WriteNum("b", iColor[2]);
	TE_WriteNum("a", iColor[3]);
	TE_WriteNum("m_nFlags", 0);
	TE_WriteNum("m_nStartEntity", iStartEnt);
	TE_WriteNum("m_nEndEntity", iEndEnt);
	TE_WriteVector("m_vecStartPoint", fStartVec);
	TE_WriteVector("m_vecEndPoint", fEndVec);
}