#include <sourcemod>
#include <sdkhooks>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <sdktools_engine>
#include <sdktools_functions>
#include <sdktools_trace>
#include <sdktools_stringtables>
#include <emitsoundany>
#include <hls_color_chat>
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_last_guard"
#include "Includes/ultjb_days"
#include "Includes/ultjb_wardenmenu"

#undef REQUIRE_PLUGIN
//#include "../Swoobles 5.0/Plugins/StoreItems/Equipment/item_equipment"
#include "../../Libraries/ClientSettings/client_settings"
#include "../../Libraries/PlayerChat/player_chat"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warden";
new const String:PLUGIN_VERSION[] = "1.36";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The warden plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aQueuePrimary;
new Handle:g_aQueueSecondary;

new Handle:cvar_warden_select_time;
new Handle:cvar_warden_select_time_initial;
new Handle:g_hTimer_SelectWarden;
new g_iTimerCountdown;
new g_iTimerCountdownMax;

new g_iWardenSerial;
new g_iLastWardenSerial;
new g_iClientWardenCount[MAXPLAYERS+1];

new const String:PLAYER_MODEL_WARDEN[] = "models/player/custom_player/legacy/ctm_heavy.mdl";
new String:g_szPlayerOriginalModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];

new const String:WARDENDEATH_SOUND[] = "sound/music/revenge.wav";

new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";
new const String:SZ_BEAM_MATERIAL_NOWALL[] = "materials/swoobles/ultimate_jailbreak/wall_beam.vmt";
new g_iBeamIndex;
new g_iBeamIndex_NoWall;
new g_iBeamColor_Pointer[4] = {240, 50, 15, 255};
new g_iBeamColor_Line[4] = {255, 0, 136, 255};

new Handle:g_hTimer_DrawBeamLine;
new const Float:BEAM_LINE_DELAY = 0.3;

new const Float:POINTER_BUTTON_EXPIRE_TIME = 0.5;
new Float:g_fPointerNextButtonExpireTime;
new Float:g_fPointerNextBeamExpireTime;
new Float:g_fPointerNextStartExpireTime;

#define EF_NODRAW 32
new const String:SZ_MODEL_END_ENT[] = "models/error.mdl";
new g_iBeamEndEntRef;

new Handle:g_hFwd_OnSelected;
new Handle:g_hFwd_OnRemoved;

#if !defined MAX_CLAN_TAG_LENGTH
#define MAX_CLAN_TAG_LENGTH	22
#endif

new bool:g_bHasOriginalFakeClanTag[MAXPLAYERS+1];
new String:g_szOriginalFakeClanTag[MAXPLAYERS+1][MAX_CLAN_TAG_LENGTH];
new bool:g_bHasGuardClanTag[MAXPLAYERS+1];
new bool:g_bGivingGuardClanTag[MAXPLAYERS+1];

new const String:SZ_PAINTBALLS_VMT[][] =
{
	"materials/swoobles/ultimate_jailbreak/paintballs/splat_blue.vmt",
	"materials/swoobles/ultimate_jailbreak/paintballs/splat_green.vmt",
	"materials/swoobles/ultimate_jailbreak/paintballs/splat_pink.vmt"
};

new const String:SZ_PAINTBALLS_VTF[][] =
{
	"materials/swoobles/ultimate_jailbreak/paintballs/splat_blue.vtf",
	"materials/swoobles/ultimate_jailbreak/paintballs/splat_green.vtf",
	"materials/swoobles/ultimate_jailbreak/paintballs/splat_pink.vtf"
};

new Handle:g_aPaintballIndexes;
new Float:g_fNextPaintBallTime;
const Float:PAINT_DELAY = 0.02;

new Float:g_fBulletOrigins_Saved[2][3];
new Float:g_fBulletOriginsPulled_Saved[2][3];
new Float:g_fBulletOrigins_Line[2][3];

new Float:g_fNextBulletOriginSave;

new iBeamCreationCount_Line;
new Float:g_fBeamCreationExpireTime_Line;

new iBeamCreationCount_Ring;
new Float:g_fBeamCreationExpireTime_Ring;

new g_iRoundWardenCount;

new bool:g_bLibLoaded_ItemEquipment;
new bool:g_bLibLoaded_ClientSettings;
new bool:g_bLibLoaded_PlayerChat;
new bool:g_bLibLoaded_ModelSkinManager;

new bool:g_bRoundStarted;


public OnPluginStart()
{
	CreateConVar("ultjb_warden_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_warden_select_time = CreateConVar("ultjb_warden_select_time", "3", "The number of seconds before selecting a new warden.", _, true, 1.0);
	cvar_warden_select_time_initial = CreateConVar("ultjb_warden_select_time_initial", "10", "The number of seconds before selecting the initial warden.", _, true, 1.0);
	
	g_aQueuePrimary = CreateArray();
	g_aQueueSecondary = CreateArray();
	g_aPaintballIndexes = CreateArray();
	
	g_hFwd_OnSelected = CreateGlobalForward("UltJB_Warden_OnSelected", ET_Ignore, Param_Cell);
	g_hFwd_OnRemoved = CreateGlobalForward("UltJB_Warden_OnRemoved", ET_Ignore, Param_Cell);
	
	HookEvent("player_team", EventPlayerTeam_Post, EventHookMode_Post);
	HookEvent("round_freeze_end", EventRoundFreezeEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventRoundEnd_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", EventPlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("bullet_impact", EventBulletImpact_Post, EventHookMode_Post);
	
	LoadTranslations("common.phrases");
	
	RegConsoleCmd("sm_w", OnWardenQueue, "Adds you to the warden queue.");
	RegConsoleCmd("sm_warden", OnWardenQueue, "Adds you to the warden queue.");
	RegConsoleCmd("sm_uw", OnUnwarden, "Allows the warden to unwarden themselves.");
	RegConsoleCmd("sm_wwho", OnWardenWho, "Displays the current warden.");
	
	RegAdminCmd("sm_rw", Command_RemoveWarden, ADMFLAG_KICK, "sm_rw - Removes the current warden.");
	RegAdminCmd("sm_sw", Command_SetWarden, ADMFLAG_ROOT, "Sets the current warden.");
	RegAdminCmd("sm_setw", Command_SetWarden, ADMFLAG_ROOT, "Sets the current warden.");
	RegAdminCmd("sm_setwarden", Command_SetWarden, ADMFLAG_ROOT, "Sets the current warden.");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ClientSettings = LibraryExists("client_settings");
	g_bLibLoaded_PlayerChat = LibraryExists("player_chat");
	g_bLibLoaded_ItemEquipment = LibraryExists("item_equipment");
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "client_settings"))
	{
		g_bLibLoaded_ClientSettings = true;
	}
	else if(StrEqual(szName, "player_chat"))
	{
		g_bLibLoaded_PlayerChat = true;
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
	if(StrEqual(szName, "client_settings"))
	{
		g_bLibLoaded_ClientSettings = false;
	}
	else if(StrEqual(szName, "player_chat"))
	{
		g_bLibLoaded_PlayerChat = false;
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

public Action:OnUnwarden(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	new iWarden = GetClientFromSerial(g_iWardenSerial);
	if(iClient != iWarden)
		return Plugin_Handled;
	
	CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}removed themself from warden.", iClient);
	
	if(!TryRemoveClientFromWarden(iClient))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Error removing yourself from warden.");
		PrintToConsole(iClient, "[SM] Error removing yourself from warden.");
	}
	
	return Plugin_Handled;
}

public Action:Command_RemoveWarden(iClient, iArgs)
{
	new iWarden = GetClientFromSerial(g_iWardenSerial);
	if(!iWarden)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}There is no warden to remove.");
		PrintToConsole(iClient, "[SM] There is no warden to remove.");
		return Plugin_Handled;
	}
	
	if(!TryRemoveClientFromWarden(iWarden))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Error removing the warden.");
		PrintToConsole(iClient, "[SM] Error removing the warden.");
		return Plugin_Handled;
	}
	
	PrintToChatAll("[SM] %N has been removed from warden.", iWarden);
	
	return Plugin_Handled;
}

public Action:Command_SetWarden(iClient, iArgs)
{	
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_setwarden <#steamid|#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:szTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, szTarget, sizeof(szTarget));
	
	new iTarget = FindTarget(iClient, szTarget, false, false);
	if(iTarget < 1)
		return Plugin_Handled;
	
	if(!IsClientInGame(iTarget) || !IsPlayerAlive(iTarget))
	{
		ReplyToCommand(iClient, "[SM] Target must be alive to set warden.");
		return Plugin_Handled;
	}
	
	if(GetClientTeam(iTarget) != TEAM_GUARDS)
	{
		ReplyToCommand(iClient, "[SM] Target must be a guard to set warden.");
		return Plugin_Handled;
	}
	
	new iWarden = GetClientFromSerial(g_iWardenSerial);
	if(iWarden)
	{
		if(iTarget == iWarden)
		{
			ReplyToCommand(iClient, "[SM] Target is already warden.");
			return Plugin_Handled;
		}
		
		if(!TryRemoveClientFromWarden(iWarden))
		{
			ReplyToCommand(iClient, "[SM] Error removing the warden.");
			return Plugin_Handled;
		}
	}
	
	SetWarden(iTarget);
	CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}set as warden by {blue}%N{olive}.", iTarget, iClient);
	StopWardenTimer();
	return Plugin_Handled;
}

public Action:OnWardenWho(iClient, iArgs)
{
	if(!iClient || !IsClientInGame(iClient))
		return Plugin_Handled;
	
	new iWarden = GetClientFromSerial(g_iWardenSerial);
	
	if(iWarden)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}The current warden is: {lightred}%N{olive}.", iWarden);
		PrintToConsole(iClient, "[SM] The current warden is: %N.", iWarden);
	}
	else
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}There is no warden.");
		PrintToConsole(iClient, "[SM] There is no warden.");
	}

	return Plugin_Handled;

}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_warden");
	
	CreateNative("UltJB_Warden_GetWarden", _UltJB_Warden_GetWarden);
	CreateNative("UltJB_Warden_GetClientWardenCount", _UltJB_Warden_GetClientWardenCount);
	
	return APLRes_Success;
}

public _UltJB_Warden_GetWarden(Handle:hPlugin, iNumParams)
{
	return GetClientFromSerial(g_iWardenSerial);
}

public _UltJB_Warden_GetClientWardenCount(Handle:hPlugin, iNumParams)
{
	return g_iClientWardenCount[GetNativeCell(1)];
}

public OnMapStart()
{
	AddFileToDownloadsTable(SZ_BEAM_MATERIAL_NOWALL);
	
	AddFileToDownloadsTable(WARDENDEATH_SOUND);
	PrecacheSoundAny(WARDENDEATH_SOUND[6]);

	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL, true);
	g_iBeamIndex_NoWall = PrecacheModel(SZ_BEAM_MATERIAL_NOWALL, true);
	PrecacheModel(SZ_MODEL_END_ENT, true);
	PrecacheModel(PLAYER_MODEL_WARDEN, true);
	
	ClearArray(g_aPaintballIndexes);
	
	decl iIndex;
	for(new i=0; i<sizeof(SZ_PAINTBALLS_VMT); i++)
	{
		iIndex = PrecacheDecal(SZ_PAINTBALLS_VMT[i][10], true);
		PushArrayCell(g_aPaintballIndexes, iIndex);
		
		AddFileToDownloadsTable(SZ_PAINTBALLS_VMT[i]);
	}
	
	for(new i=0; i<sizeof(SZ_PAINTBALLS_VTF); i++)
		AddFileToDownloadsTable(SZ_PAINTBALLS_VTF[i]);
}

public OnClientPutInServer(iClient)
{
	g_iClientWardenCount[iClient] = 0;
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnPreThinkPost(iClient)
{
	static iOldButtons, iButtons, Float:fCurTime;
	iButtons = GetClientButtons(iClient);
	iOldButtons = GetEntProp(iClient, Prop_Data, "m_nOldButtons");
	fCurTime = GetEngineTime();
	
	// Update the beam pointer end position if needed.
	if(fCurTime < (g_fPointerNextButtonExpireTime + 0.2))
		UpdatePointerEndPosition(iClient);
	
	// Pointer.
	if(iButtons & IN_USE)
		CheckBeamCreation_Pointer(iClient, iOldButtons, fCurTime);
	
	// Rings or line.
	if((iButtons & IN_DUCK) && !(iOldButtons & IN_DUCK))
	{
		CheckBeamCreation_Rings(iClient, fCurTime);
	}
	else if((iButtons & IN_SPEED) && !(iOldButtons & IN_SPEED))
	{
		CheckBeamCreation_Line(fCurTime);
	}
}

CheckBeamCreation_Rings(const &iClient, const &Float:fCurTime)
{
	if(fCurTime > g_fBeamCreationExpireTime_Ring)
		iBeamCreationCount_Ring = 0;
	
	g_fBeamCreationExpireTime_Ring = fCurTime + POINTER_BUTTON_EXPIRE_TIME;
	
	iBeamCreationCount_Ring++;
	
	if(iBeamCreationCount_Ring != 3)
		return;
	
	new Float:fRadius = GetVectorDistance(g_fBulletOrigins_Saved[0], g_fBulletOrigins_Saved[1]) / 2.0;
	
	decl Float:fVector[3];
	SubtractVectors(g_fBulletOrigins_Saved[1], g_fBulletOrigins_Saved[0], fVector);
	GetVectorAngles(fVector, fVector);
	GetAngleVectors(fVector, fVector, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVector, fRadius);
	
	decl Float:fOrigin[3];
	AddVectors(g_fBulletOrigins_Saved[0], fVector, fOrigin);
	
	UltJB_WardenMenu_CreateRing(iClient, 0, fOrigin, fRadius);
}

CheckBeamCreation_Line(const &Float:fCurTime)
{
	if(fCurTime > g_fBeamCreationExpireTime_Line)
		iBeamCreationCount_Line = 0;
	
	g_fBeamCreationExpireTime_Line = fCurTime + POINTER_BUTTON_EXPIRE_TIME;
	
	iBeamCreationCount_Line++;
	
	if(iBeamCreationCount_Line != 3)
		return;
	
	SetBulletOriginsForLine();
	
	Timer_DrawBeamLine(INVALID_HANDLE);
	StartTimer_DrawBeamLine();
}

StartTimer_DrawBeamLine()
{
	StopTimer_DrawBeamLine();
	g_hTimer_DrawBeamLine = CreateTimer(BEAM_LINE_DELAY, Timer_DrawBeamLine, _, TIMER_REPEAT);
}

StopTimer_DrawBeamLine()
{
	if(g_hTimer_DrawBeamLine == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hTimer_DrawBeamLine);
	g_hTimer_DrawBeamLine = INVALID_HANDLE;
}

public Action:Timer_DrawBeamLine(Handle:hTimer)
{
	TE_SetupBeamPoints(g_fBulletOrigins_Line[0], g_fBulletOrigins_Line[1], g_iBeamIndex, 0, 1, 1, BEAM_LINE_DELAY + 0.1, 5.0, 5.0, 0, 0.0, g_iBeamColor_Line, 10);
	TE_SendToAll();
}

CheckBeamCreation_Pointer(const &iClient, const &iOldButtons, const &Float:fCurTime)
{
	// Check to see if we need to initiate the pointer.
	if(fCurTime > g_fPointerNextButtonExpireTime)
	{
		if(iOldButtons & IN_USE)
			return;
		
		if(fCurTime > g_fPointerNextStartExpireTime)
		{
			g_fPointerNextStartExpireTime = fCurTime + POINTER_BUTTON_EXPIRE_TIME;
			return;
		}
		
		UpdatePointerEndPosition(iClient);
		UpdatePointerBeamEffect(iClient);
		
		g_fPointerNextBeamExpireTime = fCurTime + POINTER_BUTTON_EXPIRE_TIME;
		g_fPointerNextButtonExpireTime = fCurTime + POINTER_BUTTON_EXPIRE_TIME;
		return;
	}
	
	// Check to see if we need to create the ring effect.
	if(!(iOldButtons & IN_USE))
		CreatePointerRingEffect();
	
	// Check to see if we need to reapply the beam effect.
	if(fCurTime > g_fPointerNextBeamExpireTime)
	{
		UpdatePointerBeamEffect(iClient);
		g_fPointerNextBeamExpireTime = fCurTime + POINTER_BUTTON_EXPIRE_TIME;
	}
	
	g_fPointerNextButtonExpireTime = fCurTime + POINTER_BUTTON_EXPIRE_TIME;
}

CreatePointerRingEffect()
{
	new iEndEnt = GetBeamEndEnt();
	if(!iEndEnt)
		return;
	
	decl Float:fOrigin[3];
	GetEntPropVector(iEndEnt, Prop_Data, "m_vecOrigin", fOrigin);
	
	TE_SetupBeamRingPoint(fOrigin, 2.0, 80.0, g_iBeamIndex_NoWall, 0, 1, 1, 0.3, 3.0, 0.0, g_iBeamColor_Pointer, 20, 0);
	TE_SendToAll(); // TODO: Would sending to each specific player fix the PVS checking?
}

UpdatePointerEndPosition(iClient)
{
	new iEndEnt = GetBeamEndEnt();
	if(!iEndEnt)
		return;
	
	decl Float:fEyePos[3], Float:fVector[3];
	GetClientEyePosition(iClient, fEyePos);
	GetClientEyeAngles(iClient, fVector);
	
	TR_TraceRayFilter(fEyePos, fVector, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_DontHitPlayers);
	TR_GetEndPosition(fVector);
	
	TeleportEntity(iEndEnt, fVector, NULL_VECTOR, NULL_VECTOR);
}

UpdatePointerBeamEffect(iClient)
{
	new iEndEnt = GetBeamEndEnt();
	if(!iEndEnt)
		return;
	
	new iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if(iWeapon > 0)
	{
		TE_SetupBeamEnts(iEndEnt, iWeapon | 0x1000, g_iBeamIndex_NoWall, 0, 1, 1, POINTER_BUTTON_EXPIRE_TIME + 0.1, 0.4, 1.0, 0, 0.0, g_iBeamColor_Pointer, 20);
		TE_SendToClient(iClient);
	}
	
	static iActiveWeapon;
	iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	// Why did CS:GO add m_hWeaponWorldModel ?!
	// Note that the Item_WeaponColors plugin is forcing to use m_hActiveWeapon instead of m_hWeaponWorldModel.
	if(iActiveWeapon > 0)
		iWeapon = GetEntPropEnt(iActiveWeapon, Prop_Send, "m_hWeaponWorldModel");
	else
		iWeapon = 0;
	
	if(iWeapon < 1)
		iWeapon = iActiveWeapon;
	
	if(iWeapon > 0)
	{
		static String:szClassName[20], iTemp, bool:bUseHandAttachment;
		GetEntityClassname(iActiveWeapon, szClassName, sizeof(szClassName));
		bUseHandAttachment = false;
		
		iTemp = szClassName[7];
		szClassName[19] = 0x00;
		
		szClassName[7] = 0x00;
		if(StrEqual(szClassName, "weapon_"))
		{
			szClassName[7] = iTemp;
			if(StrEqual(szClassName[7], "hegrenade")
			|| StrEqual(szClassName[7], "smokegrenade")
			|| StrEqual(szClassName[7], "incgrenade")
			|| StrEqual(szClassName[7], "decoy")
			|| StrEqual(szClassName[7], "molotov")
			|| StrEqual(szClassName[7], "tagrenade")
			|| StrEqual(szClassName[7], "flashbang"))
				bUseHandAttachment = true;
			
			szClassName[12] = 0x00;
			if(StrEqual(szClassName[7], "knife")
			|| StrEqual(szClassName[7], "healt"))
				bUseHandAttachment = true;
		}
		
		for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
		{
			if(iClient == iPlayer || !IsClientInGame(iPlayer))
				continue;
			
			if(bUseHandAttachment)
				TE_SetupBeamEnts(iEndEnt, iClient | 0x2000, g_iBeamIndex_NoWall, 0, 1, 1, POINTER_BUTTON_EXPIRE_TIME + 0.1, 0.4, 1.0, 0, 0.0, g_iBeamColor_Pointer, 20);
			else
				TE_SetupBeamEnts(iEndEnt, iWeapon | 0x5000, g_iBeamIndex_NoWall, 0, 1, 1, POINTER_BUTTON_EXPIRE_TIME + 0.1, 0.4, 1.0, 0, 0.0, g_iBeamColor_Pointer, 20);
			
			TE_SendToClient(iPlayer);
		}
	}
}

TE_SetupBeamEnts(iStartEnt, iEndEnt, iModelIndex, iHaloIndex, iStartFrame, iFramerate, Float:fLife, Float:fWidth, Float:fEndWidth, iFadeLength, Float:fAmplitude, iColor[4], iSpeed)
{
	TE_Start("BeamEnts");
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
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}

public bool:TraceFilter_OnlyHitWorld(iEnt, iMask, any:iData)
{
	if(iEnt == 0)
		return true;
	
	return false;
}

GetBeamEndEnt()
{
	new iEnt = EntRefToEntIndex(g_iBeamEndEntRef);
	if(iEnt == 0 || iEnt == INVALID_ENT_REFERENCE)
		return CreateBeamEndEnt();
	
	return iEnt;
}

CreateBeamEndEnt()
{
	new iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1)
		return 0;
	
	SetEntityModel(iEnt, SZ_MODEL_END_ENT);
	SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_NODRAW);
	
	g_iBeamEndEntRef = EntIndexToEntRef(iEnt);
	return iEnt;
}

public EventRoundEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RoundEndCleanup();
}

public OnMapEnd()
{
	RoundEndCleanup();
}

RoundEndCleanup()
{
	new iWarden = GetClientFromSerial(g_iWardenSerial);
	if(iWarden)
		RemoveWarden(iWarden);
	
	StopWardenTimer();
	StopTimer_DrawBeamLine();
	g_bRoundStarted = false;
}

StopWardenTimer()
{
	if(g_hTimer_SelectWarden == INVALID_HANDLE)
		return;
	
	CloseHandle(g_hTimer_SelectWarden);
	g_hTimer_SelectWarden = INVALID_HANDLE;
}

public EventRoundFreezeEnd_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	if(GetNumAliveGuards() < 1)
		return;
	
	g_iRoundWardenCount = 0;
	StartWardenTimer(true);
	g_bRoundStarted = true;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Type {lightred}!w {olive}if you would like to have priority.");
	}
}

GetNumAliveGuards()
{
	new iNumAlive;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		iNumAlive++;
	}
	
	return iNumAlive;
}

StartWardenTimer(bool:bIsInitial=false)
{
	StopWardenTimer();
	
	// Return if timer's already started
	if(g_hTimer_SelectWarden != INVALID_HANDLE)
		return;
	
	// Don't start the warden timer if LR started.
	if(UltJB_LR_CanLastRequest())
		return;
	
	// Don't start the warden timer if last guard is activated.
	if(UltJB_LastGuard_GetLastGuard())
		return;
	
	// Don't start the warden timer if a day is activated.
	if(UltJB_Day_IsInProgress())
		return;
	
	g_iTimerCountdown = 0;
	g_iTimerCountdownMax = bIsInitial ? GetConVarInt(cvar_warden_select_time_initial) : GetConVarInt(cvar_warden_select_time);
	ShowWardenCountdown();
	
	g_hTimer_SelectWarden = CreateTimer(1.0, Timer_SelectWarden, _, TIMER_REPEAT);
	CPrintToChatAll("{green}[{lightred}SM{green}] {olive}A warden will be selected in {lightred}%i {olive}seconds.", g_iTimerCountdownMax);
}

ShowWardenCountdown()
{
	PrintHintTextToNeeded("<font color='#6FC41A'>Selecting warden in:</font>\n<font color='#DE2626'>%i</font> <font color='#6FC41A'>seconds.</font>", g_iTimerCountdownMax - g_iTimerCountdown);
}

PrintHintTextToNeeded(const String:szFormat[], any:...)
{
	decl String:szBuffer[256];
	VFormat(szBuffer, sizeof(szBuffer), szFormat, 2);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(UltJB_LR_HasStartedLastRequest(iClient))
			continue;
		
		PrintHintText(iClient, szBuffer);
	}
}

public Action:Timer_SelectWarden(Handle:hTimer)
{
	if(UltJB_LastGuard_GetLastGuard())
	{
		g_hTimer_SelectWarden = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_iTimerCountdown++;
	if(g_iTimerCountdown < g_iTimerCountdownMax)
	{
		ShowWardenCountdown();
		return Plugin_Continue;
	}
	
	g_hTimer_SelectWarden = INVALID_HANDLE;
	
	new iWarden;
	
	if(!g_iRoundWardenCount)
		iWarden = GetPrimaryWarden();
	
	if(!iWarden)
		iWarden = GetSecondaryWarden();
	
	if(!iWarden)
	{
		PrintHintTextToNeeded("<font color='#6FC41A'>A warden could</font> <font color='#DE2626'>not</font> <font color='#6FC41A'>be found.</font>");
		CPrintToChatAll("{green}[{lightred}SM{green}] {olive}A warden could not be found.");
		
		// TODO: Automatically go into a freeday.
		// -->
		
		return Plugin_Stop;
	}
	
	PrintHintTextToNeeded("<font color='#DE2626'>%N</font>\n<font color='#6FC41A'>has been selected as warden.</font>", iWarden);
	CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}has been selected as warden.", iWarden);
	SetWarden(iWarden);
	
	return Plugin_Stop;
}

SetWarden(iClient)
{
	GetEntPropString(iClient, Prop_Data, "m_ModelName", g_szPlayerOriginalModel[iClient], sizeof(g_szPlayerOriginalModel[]));
	
	g_iWardenSerial = GetClientSerial(iClient);
	g_iLastWardenSerial = g_iWardenSerial;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		MSManager_SetPlayerModel(iClient, PLAYER_MODEL_WARDEN);
		#else
		SetEntityModel(iClient, PLAYER_MODEL_WARDEN);
		#endif
	}
	else
	{
		SetEntityModel(iClient, PLAYER_MODEL_WARDEN);
	}
	
	if(g_bLibLoaded_ItemEquipment)
	{
		#if defined _item_equipment_included
		ItemEquipment_RecalculateClientsEquipment(iClient);
		#endif
	}
	
	// TODO: Show messages to warden about using the pointer.
	// cl_use_opens_buy_menu check
	
	g_iClientWardenCount[iClient]++;
	g_iRoundWardenCount++;
	
	new result;
	Call_StartForward(g_hFwd_OnSelected);
	Call_PushCell(iClient);
	Call_Finish(result);
	
	GiveGuardClanTag(iClient);
	
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public Action:OnWardenQueue(iClient, iArgNum)
{
	if(!iClient || !IsClientInGame(iClient))
		return Plugin_Handled;
	
	new iWarden = GetClientFromSerial(g_iWardenSerial);
	
	if(GetClientTeam(iClient) != TEAM_GUARDS)
	{
		if(iWarden)
		{
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}The current warden is: {lightred}%N{olive}.", iWarden);
			PrintToConsole(iClient, "[SM] The current warden is: %N.", iWarden);
		}
		else
		{
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}There is no warden.");
			PrintToConsole(iClient, "[SM] There is no warden.");
		}
		
		return Plugin_Handled;
	}
	
	if(iWarden)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}The current warden is: {lightred}%N{olive}.", iWarden);
		PrintToConsole(iClient, "[SM] The current warden is: %N.", iWarden);
	}
	
	if(!AddPlayerToQueue(iClient, g_aQueuePrimary))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You are already in the warden queue.");
		PrintToConsole(iClient, "[SM] You are already in the warden queue.");
		return Plugin_Handled;
	}
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}You have been added to the warden queue. This queue is only used for the first warden of each round.");
	PrintToConsole(iClient, "[SM] You have been added to the warden queue. This queue is only used for the first warden of each round.");
	
	return Plugin_Handled;
}

public EventPlayerTeam_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	switch(GetEventInt(hEvent, "team"))
	{
		case TEAM_GUARDS:
		{
			AddPlayerToQueue(iClient, g_aQueueSecondary);
			GiveGuardClanTag(iClient);
		}
		case TEAM_PRISONERS:
		{
			RemovePlayerFromQueue(iClient, g_aQueuePrimary);
			AddPlayerToQueue(iClient, g_aQueueSecondary);
			
			RemoveGuardClanTag(iClient);
			
			TryRemoveClientFromWarden(iClient);
		}
		default:
		{
			RemovePlayerFromQueue(iClient, g_aQueuePrimary);
			RemoveGuardClanTag(iClient);
			
			TryRemoveClientFromWarden(iClient);
		}
	}
}

GiveGuardClanTag(iClient)
{
	if(!g_bLibLoaded_ClientSettings || !g_bLibLoaded_PlayerChat)
		return;
	
	if(!g_bHasGuardClanTag[iClient])
	{
		#if defined _client_settings_included
		if(ClientSettings_HasFakeClanTag(iClient))
		{
			ClientSettings_GetFakeClanTag(iClient, g_szOriginalFakeClanTag[iClient], sizeof(g_szOriginalFakeClanTag[]));
			g_bHasOriginalFakeClanTag[iClient] = true;
		}
		else
		{
			strcopy(g_szOriginalFakeClanTag[iClient], sizeof(g_szOriginalFakeClanTag[]), "");
			g_bHasOriginalFakeClanTag[iClient] = false;
		}
		#endif
	}
	
	g_bGivingGuardClanTag[iClient] = true;
	
	new iWarden = GetClientFromSerial(g_iWardenSerial);
	if(iClient == iWarden)
	{
		#if defined _client_settings_included
		ClientSettings_SetFakeClanTag(iClient, "Warden");
		#endif
		
		#if defined _player_chat_included
		PlayerChat_SetCustomTitle(iClient, "Warden");
		#endif
	}
	else
	{
		#if defined _client_settings_included
		ClientSettings_SetFakeClanTag(iClient, "");
		#endif
		
		#if defined _player_chat_included
		PlayerChat_ClearCustomTitle(iClient);
		#endif
	}
	
	g_bGivingGuardClanTag[iClient] = false;
	g_bHasGuardClanTag[iClient] = true;
}

RemoveGuardClanTag(iClient)
{
	if(!g_bLibLoaded_ClientSettings || !g_bLibLoaded_PlayerChat)
		return;
	
	if(!g_bHasGuardClanTag[iClient])
		return;
	
	g_bHasGuardClanTag[iClient] = false;
	
	if(g_bHasOriginalFakeClanTag[iClient])
	{
		#if defined _client_settings_included
		ClientSettings_SetFakeClanTag(iClient, g_szOriginalFakeClanTag[iClient]);
		#endif
	}
	else
	{
		#if defined _client_settings_included
		ClientSettings_ClearFakeClanTag(iClient);
		#endif
	}
	
	#if defined _player_chat_included
	PlayerChat_ClearCustomTitle(iClient);
	#endif
}

public ClientSettings_OnFakeClanTagChange(iClient, const String:szOldTag[], const String:szNewTag[])
{
	if(!g_bHasGuardClanTag[iClient])
		return;
	
	if(g_bGivingGuardClanTag[iClient])
		return;
	
	strcopy(g_szOriginalFakeClanTag[iClient], sizeof(g_szOriginalFakeClanTag[]), szNewTag);
	g_bHasOriginalFakeClanTag[iClient] = true;
}

public OnClientDisconnect_Post(iClient)
{
	RemovePlayerFromQueue(iClient, g_aQueuePrimary);
	RemovePlayerFromQueue(iClient, g_aQueueSecondary);
}

public OnClientDisconnect(iClient)
{
	TryRemoveClientFromWarden(iClient);
}

public EventPlayerDeath_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iClient && iClient == GetClientFromSerial(g_iWardenSerial))
	{
		CPrintToChatAll("{green}[{lightred}SM{green}] {olive}The warden has died!");
		EmitSoundToAllAny(WARDENDEATH_SOUND[6], _, _, SNDLEVEL_NONE);
	}
	
	TryRemoveClientFromWarden(iClient);
}

public UltJB_LastGuard_OnActivated_Pre(iClient)
{
	StopWardenTimer();
	TryRemoveClientFromWarden(GetClientFromSerial(g_iWardenSerial));
}

public UltJB_LR_OnLastRequestInitialized(iClient)
{
	StopWardenTimer();
	TryRemoveClientFromWarden(GetClientFromSerial(g_iWardenSerial));
}

public UltJB_Day_OnStart(iClient, DayType:iDayType)
{
	StopWardenTimer();
	TryRemoveClientFromWarden(GetClientFromSerial(g_iWardenSerial));
}

bool:TryRemoveClientFromWarden(iClient)
{
	if(!iClient || iClient != GetClientFromSerial(g_iWardenSerial))
		return false;
	
	RemoveWarden(iClient);
	StartWardenTimer();
	
	if(IsPlayerAlive(iClient))
	{
		if(g_bLibLoaded_ModelSkinManager)
		{
			#if defined _model_skin_manager_included
			MSManager_SetPlayerModel(iClient, g_szPlayerOriginalModel[iClient]);
			#else
			SetEntityModel(iClient, g_szPlayerOriginalModel[iClient]);
			#endif
		}
		else
		{
			SetEntityModel(iClient, g_szPlayerOriginalModel[iClient]);
		}
		
		if(g_bLibLoaded_ItemEquipment)
		{
			#if defined _item_equipment_included
			ItemEquipment_RecalculateClientsEquipment(iClient);
			#endif
		}
	}
	
	return true;
}

RemoveWarden(iWarden)
{
	g_iWardenSerial = 0;
	
	GiveGuardClanTag(iWarden);
	SDKUnhook(iWarden, SDKHook_PreThinkPost, OnPreThinkPost);
	
	new result;
	Call_StartForward(g_hFwd_OnRemoved);
	Call_PushCell(iWarden);
	Call_Finish(result);
}

RemovePlayerFromQueue(iClient, Handle:hQueue)
{
	new iIndex = FindValueInArray(hQueue, iClient);
	if(iIndex == -1)
		return;
	
	RemoveFromArray(hQueue, iIndex);
}

bool:AddPlayerToQueue(iClient, Handle:hQueue)
{
	if(FindValueInArray(hQueue, iClient) != -1)
		return false;
	
	PushArrayCell(hQueue, iClient);
	return true;
}

GetPrimaryWarden()
{
	new iArraySize = GetArraySize(g_aQueuePrimary);
	if(!iArraySize)
		return 0;
	
	decl iClient, iIndex;
	for(iIndex=0; iIndex<iArraySize; iIndex++)
	{
		iClient = GetArrayCell(g_aQueuePrimary, iIndex);
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		break;
	}
	
	if(iIndex >= iArraySize)
		return 0;
	
	// Remove the found warden from the queue.
	RemovePlayerFromQueue(iClient, g_aQueuePrimary);
	
	return iClient;
}

GetSecondaryWarden()
{
	new iArraySize = GetArraySize(g_aQueueSecondary);
	if(!iArraySize)
		return 0;
	
	decl iClient, iIndex;
	for(iIndex=0; iIndex<iArraySize; iIndex++)
	{
		iClient = GetArrayCell(g_aQueueSecondary, iIndex);
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_GUARDS)
			continue;
		
		break;
	}
	
	if(iIndex >= iArraySize)
		return 0;
	
	// Move the found warden to the end of the queue.
	RemovePlayerFromQueue(iClient, g_aQueueSecondary);
	AddPlayerToQueue(iClient, g_aQueueSecondary);
	
	return iClient;
}

public EventBulletImpact_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	static iClient;
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(g_iWardenSerial != GetClientSerial(iClient))
		return;
	
	static Float:fBulletOrigin[3];
	fBulletOrigin[0] = GetEventFloat(hEvent, "x");
	fBulletOrigin[1] = GetEventFloat(hEvent, "y");
	fBulletOrigin[2] = GetEventFloat(hEvent, "z");
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime > g_fNextBulletOriginSave)
	{
		// Use g_fNextBulletOriginSave to prevent penetration recursion.
		SaveBulletOrigin(iClient, fBulletOrigin);
		g_fNextBulletOriginSave = fCurTime + 0.03;
	}
	
	if(fCurTime < g_fNextPaintBallTime)
		return;
	
	new iArraySize = GetArraySize(g_aPaintballIndexes);
	if(!iArraySize)
		return;
	
	new iPrecacheID = GetArrayCell(g_aPaintballIndexes, GetRandomInt(0, iArraySize-1));
	if(!iPrecacheID)
		return;
	
	static Float:fEyePos[3];
	GetClientEyePosition(iClient, fEyePos);
	TR_TraceRayFilter(fEyePos, fBulletOrigin, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_OnlyHitWorld);
	
	// Draw paintball on world only.
	new iHit = TR_GetEntityIndex();
	if(iHit > 0)
		return;
	
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", fBulletOrigin);
	TE_WriteNum("m_nIndex", iPrecacheID);
	TE_SendToAll();
	
	g_fNextPaintBallTime = fCurTime + PAINT_DELAY;
}

SaveBulletOrigin(iClient, const Float:fBulletOrigin[3])
{
	// Put the previous origins in the second array index.
	g_fBulletOrigins_Saved[1][0] = g_fBulletOrigins_Saved[0][0];
	g_fBulletOrigins_Saved[1][1] = g_fBulletOrigins_Saved[0][1];
	g_fBulletOrigins_Saved[1][2] = g_fBulletOrigins_Saved[0][2];
	
	g_fBulletOriginsPulled_Saved[1][0] = g_fBulletOriginsPulled_Saved[0][0];
	g_fBulletOriginsPulled_Saved[1][1] = g_fBulletOriginsPulled_Saved[0][1];
	g_fBulletOriginsPulled_Saved[1][2] = g_fBulletOriginsPulled_Saved[0][2];
	
	// Get the pulled back version.
	decl Float:fEyeAngles[3];
	GetClientEyeAngles(iClient, fEyeAngles);
	
	decl Float:fVector[3];
	GetClientEyePosition(iClient, fVector);
	
	TR_TraceRayFilter(fVector, fEyeAngles, MASK_SHOT, RayType_Infinite, TraceFilter_DontHitPlayers);
	
	TR_GetPlaneNormal(INVALID_HANDLE, fVector);
	ScaleVector(fVector, 10.0);
	AddVectors(fBulletOrigin, fVector, fVector);
	
	// Save the new origins.
	g_fBulletOrigins_Saved[0][0] = fBulletOrigin[0];
	g_fBulletOrigins_Saved[0][1] = fBulletOrigin[1];
	g_fBulletOrigins_Saved[0][2] = fBulletOrigin[2];
	
	g_fBulletOriginsPulled_Saved[0][0] = fVector[0];
	g_fBulletOriginsPulled_Saved[0][1] = fVector[1];
	g_fBulletOriginsPulled_Saved[0][2] = fVector[2];
}

SetBulletOriginsForLine()
{
	g_fBulletOrigins_Line[0][0] = g_fBulletOriginsPulled_Saved[0][0];
	g_fBulletOrigins_Line[0][1] = g_fBulletOriginsPulled_Saved[0][1];
	g_fBulletOrigins_Line[0][2] = g_fBulletOriginsPulled_Saved[0][2];
	
	g_fBulletOrigins_Line[1][0] = g_fBulletOriginsPulled_Saved[1][0];
	g_fBulletOrigins_Line[1][1] = g_fBulletOriginsPulled_Saved[1][1];
	g_fBulletOrigins_Line[1][2] = g_fBulletOriginsPulled_Saved[1][2];
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	if(!g_bRoundStarted)
		return;
		
	if(GetNumAliveGuards() < 1)
		return;
		
	if(GetClientFromSerial(g_iWardenSerial))
		return;
		
	if(g_hTimer_SelectWarden != INVALID_HANDLE)
		return;
	
	new iWarden = GetClientFromSerial(g_iLastWardenSerial);
	if(iWarden && GetClientTeam(iWarden) == TEAM_GUARDS && IsPlayerAlive(iWarden))
	{
		CPrintToChatAll("{green}[{lightred}SM{green}] {lightred}%N {olive}is now warden.", iWarden);
		SetWarden(iWarden);
	}
	else
		StartWardenTimer();
}