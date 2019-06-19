#include <sourcemod>
#include <sdkhooks>
#include <sdktools_sound>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include <sdktools_entinput>
#include <sdktools_variant_t>
#include <hls_color_chat>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_effects"
#include "../Includes/ultjb_settings"
#include "../../../Libraries/ZoneManager/zone_manager"
#include "../../../Plugins/ZoneTypes/Includes/zonetype_teleport"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Capture the Flag";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Capture the Flag.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Capture the Flag"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new g_iThisDayID;

new g_iFlagEntRef;
new g_iFlagCarriedEntRef;
new g_iCapturePointEntRef;

new const String:SOUND_PICKUP[]		= "sound/music/kill_01.wav";
new const String:SOUND_DROP[]		= "sound/music/deathcam_gg_01.wav";
new const String:SOUND_RETURN[]		= "sound/player/orch_hit_csharp_short.wav";
new const String:SOUND_CAPTURE[]	= "sound/music/point_captured_ct.wav";

#define MODEL_FLAG			"models/swoobles/ultimate_jailbreak/flag/flag.mdl"
#define MODEL_CAPTURE_POINT	"models/swoobles/ultimate_jailbreak/capture_point/block.mdl"

#define EF_NODRAW	32

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;

#define CLIENT_NOT_CARRIED	-1
#define PICKUP_DELAY_AFTER_DROPPING				0.4
#define PICKUP_DELAY_AFTER_DROPPING_PER_CLIENT	1.0
#define RETURN_DELAY_AFTER_DROPPING				0.75
#define AUTO_RETURN_DELAY_AFTER_DROPPING		15.0

new Float:g_fFlagDroppedTime;
new Float:g_fFlagDroppedTimePerClient[MAXPLAYERS+1];

new const Float:g_fFlagMins[3] = {-12.0, -12.0, -0.0};
new const Float:g_fFlagMaxs[3] = {12.0, 12.0, 40.0};

#define CAPTURE_POINT_SCALE	1.2

new bool:g_bHasStartedCTF;
new bool:g_bFlagAtSpawn;

new g_iTeleportZoneID_Attack;
new g_iTeleportZoneID_Defend;

#define SIDE_SELECTION_TIME	10
new Handle:g_hMenu_Selection;
new Handle:g_hTimer_Selection;

new Handle:g_hTimer_Logic;

new g_iDefendingTeam;

enum
{
	SIDE_NONE = 0,
	SIDE_RANDOM,
	SIDE_ATTACK,
	SIDE_DEFEND
};

#define SOLID_BBOX		2
#define SOLID_VPHYSICS	6
#define COLLISION_GROUP_DEBRIS_TRIGGER	2

#define RESPAWN_DELAY_ATTACKERS	2.5
#define RESPAWN_DELAY_DEFENDERS	3.0

#define HEALTH_PER_CLIENT_TEAM_DIFFERENCE	50

new bool:g_bEventHooked_PlayerDeath;

new g_iInitialDayFlags = DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_STRIP_PRISONERS_WEAPONS;

new Handle:cvar_mp_roundtime;
new Handle:cvar_mp_respawn_immunitytime;

new Float:g_fRoundTime;
new Float:g_fRoundTimeStarted;

#define RESPAWN_IMMUNITY_TIME	1.0
new Float:g_fOriginalRespawnImmunityTime;


public OnPluginStart()
{
	CreateConVar("warday_ctf_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	
	AddCommandListener(OnWeaponDrop, "drop");
	
	cvar_mp_roundtime = FindConVar("mp_roundtime");
	cvar_mp_respawn_immunitytime = FindConVar("mp_respawn_immunitytime");
}

public OnMapStart()
{
	// Flag
	AddFileToDownloadsTable(MODEL_FLAG);
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/flag/flag.dx90.vtx");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/flag/flag.phy");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/flag/flag.vvd");
	
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_fx_yellow.vmt");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_glow.vtf");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_glow_normal.vtf");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_yellow.vmt");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_yellow.vtf");
	
	PrecacheModel(MODEL_FLAG);
	
	// Capture point
	AddFileToDownloadsTable(MODEL_CAPTURE_POINT);
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/capture_point/block.dx90.vtx");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/capture_point/block.phy");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/capture_point/block.vvd");
	
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/capture_point/block.vmt");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/capture_point/block.vtf");
	
	PrecacheModel(MODEL_CAPTURE_POINT);
	
	// Sounds
	PrecacheSound(SOUND_PICKUP[6]);
	PrecacheSound(SOUND_DROP[6]);
	PrecacheSound(SOUND_RETURN[6]);
	PrecacheSound(SOUND_CAPTURE[6]);
	
	// Other
	RoundPreStart();
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	g_fRoundTimeStarted = GetEngineTime();
	if(cvar_mp_roundtime != INVALID_HANDLE)
		g_fRoundTime = GetConVarFloat(cvar_mp_roundtime) * 60.0 + 3.0;
	else
		g_fRoundTime = 300.0;
	
	if(g_iThisDayID)
		UltJB_Day_SetEnabled(g_iThisDayID, (g_iTeleportZoneID_Attack && g_iTeleportZoneID_Defend));
}

public Action:Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RoundPreStart();
}

RoundPreStart()
{
	g_iTeleportZoneID_Attack = 0;
	g_iTeleportZoneID_Defend = 0;
}

public UltJB_Day_OnRegisterReady()
{
	g_iThisDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, g_iInitialDayFlags, OnDayStart, OnDayEnd);
	UltJB_Day_SetFreezeTime(g_iThisDayID, SIDE_SELECTION_TIME);
}

public OnMapEnd()
{
	g_iThisDayID = 0;
}

public OnDayStart(iClient)
{
	if(cvar_mp_respawn_immunitytime != INVALID_HANDLE)
	{
		g_fOriginalRespawnImmunityTime = GetConVarFloat(cvar_mp_respawn_immunitytime);
		SetConVarFloat(cvar_mp_respawn_immunitytime, RESPAWN_IMMUNITY_TIME, true, false);
	}
	
	g_iDefendingTeam = 0;
	g_bHasStartedCTF = false;
	
	g_hMenu_Selection = DisplayMenu_Selection(iClient);
	if(g_hMenu_Selection != INVALID_HANDLE)
	{
		StartTimer_Selection(iClient, float(SIDE_SELECTION_TIME));
	}
	else
	{
		SelectRandomSide(iClient);
	}
}

public OnDayEnd(iClient)
{
	if(cvar_mp_respawn_immunitytime != INVALID_HANDLE)
		SetConVarFloat(cvar_mp_respawn_immunitytime, g_fOriginalRespawnImmunityTime, true, false);
	
	g_bHasStartedCTF = false;
	
	StopTimer_Selection();
	StopTimer_Logic();
	
	if(g_bEventHooked_PlayerDeath)
	{
		UnhookEvent("player_death", EventPlayerDeath_Pre, EventHookMode_Pre);
		g_bEventHooked_PlayerDeath = false;
	}
	
	UltJB_Settings_StopAutoRespawning();
}

public EventPlayerDeath_Pre(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!iClient)
		return;
	
	if(GetFlagCarrier() != iClient)
		return;
	
	SetFlagCarrier(CLIENT_NOT_CARRIED, true);
}

Handle:DisplayMenu_Selection(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Selection);
	
	SetMenuTitle(hMenu, "Select your teams side");
	SetMenuExitButton(hMenu, false);
	
	decl String:szInfo[2];
	IntToString(SIDE_ATTACK, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Attack");
	
	IntToString(SIDE_DEFEND, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Defend");
	
	IntToString(SIDE_RANDOM, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Choose for me");
	
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] There is nothing to select.");
		return INVALID_HANDLE;
	}
	
	return hMenu;
}

public MenuHandle_Selection(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		g_hMenu_Selection = INVALID_HANDLE;
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iSide = StringToInt(szInfo);
	
	if(iSide == SIDE_RANDOM)
	{
		SelectRandomSide(iParam1);
		return;
	}
	
	SelectSide(iParam1, iSide);
}

StartTimer_Selection(iClient, Float:fTime)
{
	StopTimer_Selection();
	g_hTimer_Selection = CreateTimer(fTime, Timer_Selection, GetClientSerial(iClient));
}

StopTimer_Selection()
{
	if(g_hTimer_Selection == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Selection);
	g_hTimer_Selection = INVALID_HANDLE;
}

public Action:Timer_Selection(Handle:hTimer, any:iClientSerial)
{
	g_hTimer_Selection = INVALID_HANDLE;
	
	if(g_hMenu_Selection != INVALID_HANDLE)
		CancelMenu(g_hMenu_Selection);
	
	SelectRandomSide(GetClientFromSerial(iClientSerial));
	StartGame();
}

SelectRandomSide(iClient)
{
	// Return if the team was already selected.
	if(g_iDefendingTeam)
		return;
	
	if(iClient)
		PrintToChat(iClient, "[SM] Selecting a random side.");
	
	SelectSide(iClient, GetRandomInt(SIDE_ATTACK, SIDE_DEFEND));
}

SelectSide(iClient, iSide)
{
	// Return if the team was already selected.
	if(g_iDefendingTeam)
		return;
	
	if(!iClient)
	{
		g_iDefendingTeam = GetRandomInt(TEAM_PRISONERS, TEAM_GUARDS);
		return;
	}
	
	new iTeam = GetClientTeam(iClient);
	if(iTeam < TEAM_PRISONERS)
	{
		g_iDefendingTeam = GetRandomInt(TEAM_PRISONERS, TEAM_GUARDS);
		return;
	}
	
	if(iSide == SIDE_DEFEND)
	{
		g_iDefendingTeam = iTeam;
	}
	else
	{
		switch(iTeam)
		{
			case TEAM_PRISONERS:	g_iDefendingTeam = TEAM_GUARDS;
			case TEAM_GUARDS:		g_iDefendingTeam = TEAM_PRISONERS;
			default:
			{
				g_iDefendingTeam = GetRandomInt(TEAM_PRISONERS, TEAM_GUARDS);
			}
		}
	}
}

StartGame()
{
	if(!SpawnFlag() || !SpawnCapturePoint())
	{
		// TODO: Force end day.
		return;
	}
	
	if(!g_bEventHooked_PlayerDeath)
		g_bEventHooked_PlayerDeath = HookEventEx("player_death", EventPlayerDeath_Pre, EventHookMode_Pre);
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		PrepareClient(iClient);
	}
	
	g_bHasStartedCTF =  true;
	
	// Infinite ammo for defenders might be too op?
	//UltJB_Day_SetFlags(g_iThisDayID, g_iInitialDayFlags | ((g_iDefendingTeam == TEAM_GUARDS) ? DAY_FLAG_GIVE_GUARDS_INFINITE_AMMO : DAY_FLAG_GIVE_PRISONERS_INFINITE_AMMO));
	
	UltJB_Settings_SetNextRoundEndReason(true, (g_iDefendingTeam == TEAM_GUARDS) ? CSRoundEnd_CTWin : CSRoundEnd_TerroristWin);
	UltJB_Settings_BlockTerminateRound(true);
	UltJB_Settings_StartAutoRespawning(true);
	UltJB_Settings_SetAutoRespawnDelay(RESPAWN_DELAY_DEFENDERS, (g_iDefendingTeam == TEAM_GUARDS) ? ART_GUARDS : ART_PRISONERS);
	UltJB_Settings_SetAutoRespawnDelay(RESPAWN_DELAY_ATTACKERS, (g_iDefendingTeam == TEAM_GUARDS) ? ART_PRISONERS : ART_GUARDS);
	
	StartTimer_Logic();
}

bool:SpawnFlag()
{
	new iFlag = GetFlagEntity();
	if(iFlag < 1)
		return false;
	
	SetFlagsOwnerTeam(g_iDefendingTeam);
	ReturnFlagToSpawn();
	
	return true;
}

bool:ReturnFlagToSpawn()
{
	new iFlag = GetFlagEntity();
	if(iFlag < 1)
		return false;
	
	SetFlagCarrier();
	
	if(!ZoneTypeTeleport_TryToTeleport(g_iTeleportZoneID_Defend, iFlag))
		return false;
	
	// Flip the flag so it's facing the right direction.
	decl Float:fAngles[3];
	GetEntPropVector(iFlag, Prop_Data, "m_angAbsRotation", fAngles);
	fAngles[1] += 180.0;
	TeleportEntity(iFlag, NULL_VECTOR, fAngles, NULL_VECTOR);
	
	g_bFlagAtSpawn = true;
	
	return true;
}

bool:SpawnCapturePoint()
{
	new iEnt = GetCapturePointEntity();
	if(iEnt < 1)
		return false;
	
	return true;
}

public UltJB_Day_OnSpawnPost(iClient)
{
	if(!g_bHasStartedCTF)
		return;
	
	PrepareClient(iClient);
}

PrepareClient(iClient)
{
	switch(GetClientTeam(iClient))
	{
		case TEAM_GUARDS:		UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		case TEAM_PRISONERS:
		{
			if(UltJB_LR_HasStartedLastRequest(iClient) && (UltJB_LR_GetLastRequestFlags(iClient) & LR_FLAG_FREEDAY))
				return;
			
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
		}
	}
	
	decl iWeapon;
	switch(GetClientSide(iClient))
	{
		case SIDE_ATTACK:
		{
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_GLOCK);
			
			switch(GetRandomInt(1, 6))
			{
				case 1: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_MP5NAVY);
				case 2: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_UMP45);
				case 3: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_BIZON);
				case 4: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_P90);
				case 5: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_MP9);
				case 6: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_MAC10);
				default: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AWP);
			}
			
			ZoneTypeTeleport_TryToTeleport(g_iTeleportZoneID_Attack, iClient);
			
			CPrintToChat(iClient, "{olive}You are {lightred}attacking{olive}. Go get the {lightred}flag{olive}!");
		}
		case SIDE_DEFEND:
		{
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_DEAGLE);
			
			switch(GetRandomInt(1, 2))
			{
				case 1: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_M4A1);
				case 2: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AK47);
				default: iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AWP);
			}
			
			ZoneTypeTeleport_TryToTeleport(g_iTeleportZoneID_Defend, iClient);
			
			CPrintToChat(iClient, "{olive}You are {lightred}defending{olive}. Guard your {lightred}flag{olive}!");
		}
		default:
		{
			iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_AWP);
		}
	}
	
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	SetEntProp(iClient, Prop_Send, "m_ArmorValue", 100);
	SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 1);
	
	SetClientSpawnHealth(iClient);
}

SetClientSpawnHealth(iClient)
{
	new iNumGuards, iNumPrisoners;
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		switch(GetClientTeam(iPlayer))
		{
			case TEAM_GUARDS: iNumGuards++;
			case TEAM_PRISONERS:
			{
				if(UltJB_LR_HasStartedLastRequest(iPlayer) && (UltJB_LR_GetLastRequestFlags(iPlayer) & LR_FLAG_FREEDAY))
					continue;
				
				iNumPrisoners++;
			}
		}
	}
	
	new iHealth = 100;
	new iTeam = GetClientTeam(iClient);
	
	if(iNumPrisoners > iNumGuards)
	{
		if(iTeam == TEAM_GUARDS)
			iHealth += (iNumPrisoners - iNumGuards) * HEALTH_PER_CLIENT_TEAM_DIFFERENCE;
	}
	else
	{
		if(iTeam == TEAM_PRISONERS)
			iHealth += (iNumGuards - iNumPrisoners) * HEALTH_PER_CLIENT_TEAM_DIFFERENCE;
	}
	
	SetEntityHealth(iClient, iHealth);
	SetEntProp(iClient, Prop_Data, "m_iMaxHealth", iHealth);
}

GetClientSide(iClient)
{
	new iTeam = GetClientTeam(iClient);
	if(iTeam < TEAM_PRISONERS)
		return SIDE_NONE;
	
	if(iTeam == g_iDefendingTeam)
		return SIDE_DEFEND;
	
	return SIDE_ATTACK;
}

GetCapturePointEntity()
{
	new iEnt = EntRefToEntIndex(g_iCapturePointEntRef);
	if(iEnt > 0)
		return iEnt;
	
	iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1)
		return -1;
	
	g_iCapturePointEntRef = EntIndexToEntRef(iEnt);
	InitCapturePointEntity(iEnt);
	
	return iEnt;
}

InitCapturePointEntity(iEnt)
{
	SetEntityModel(iEnt, MODEL_CAPTURE_POINT);
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_VPHYSICS);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER);
	
	SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	
	ScaleEntity(iEnt, 1, CAPTURE_POINT_SCALE);
	
	SetCapturePointToLocation(iEnt);
	
	SDKHook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost_CapturePoint);
}

bool:SetCapturePointToLocation(iEnt)
{
	decl Float:fOrigin[3];
	if(!ZoneManager_GetZoneOrigin(g_iTeleportZoneID_Attack, fOrigin))
		return false;
	
	decl Float:fZoneMins[3];
	if(!ZoneManager_GetZoneMins(g_iTeleportZoneID_Attack, fZoneMins))
		return false;
	
	decl Float:fZoneMaxs[3];
	if(!ZoneManager_GetZoneMaxs(g_iTeleportZoneID_Attack, fZoneMaxs))
		return false;
	
	decl Float:fZoneAngles[3];
	if(!ZoneManager_GetZoneAngles(g_iTeleportZoneID_Attack, fZoneAngles))
		return false;
	
	decl Float:fCaptureMins[3], Float:fCaptureMaxs[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fCaptureMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fCaptureMaxs);
	
	// Get center of zone.
	fOrigin[0] = fOrigin[0] + ((fZoneMins[0] + fZoneMaxs[0]) * 0.5);
	fOrigin[1] = fOrigin[1] + ((fZoneMins[1] + fZoneMaxs[1]) * 0.5);
	
	// Put the capture point at the bottom of the zone and 70% into the ground.
	fOrigin[2] = (fOrigin[2] + fZoneMins[2]) - ((fCaptureMaxs[2] - fCaptureMins[2]) * 0.7);
	
	// Fix angles.
	fZoneAngles[0] = 0.0;
	fZoneAngles[1] = 90.0;
	fZoneAngles[2] = 0.0;
	
	TeleportEntity(iEnt, fOrigin, fZoneAngles, Float:{0.0, 0.0, 0.0});
	
	return true;
}

ScaleEntity(iEnt, iScaleType=0, Float:fScale=1.0)
{
	SetEntProp(iEnt, Prop_Send, "m_ScaleType", iScaleType);
	SetEntPropFloat(iEnt, Prop_Send, "m_flModelScale", fScale);
}

public OnStartTouchPost_CapturePoint(iEnt, iOther)
{
	if(!IsPlayer(iOther) || !IsPlayerAlive(iOther))
		return;
	
	TryCaptureFlag(iOther);
}

TryCaptureFlag(iClient)
{
	if(!g_bHasStartedCTF)
		return;
	
	if(GetFlagCarrier() != iClient)
		return;
	
	EndGame();
	
	CS_SetClientContributionScore(iClient, CS_GetClientContributionScore(iClient) + 1000);
	EmitSoundToAll(SOUND_CAPTURE[6], _, _, SNDLEVEL_NONE, _, 0.9);
	ShowCapturedHintText(iClient);
}

EndGame(bool:bFromTimeExpired=false)
{
	g_bHasStartedCTF = false;
	
	decl iWinningTeam;
	if(bFromTimeExpired)
	{
		// From time running out.
		iWinningTeam = (g_iDefendingTeam == TEAM_GUARDS) ? TEAM_GUARDS : TEAM_PRISONERS;
	}
	else
	{
		// From flag capture.
		iWinningTeam = (g_iDefendingTeam == TEAM_GUARDS) ? TEAM_PRISONERS : TEAM_GUARDS;
	}
	
	new CSRoundEndReason:endReason = (iWinningTeam == TEAM_GUARDS) ? CSRoundEnd_CTWin : CSRoundEnd_TerroristWin;
	
	UltJB_Settings_SetNextRoundEndReason(true, endReason);
	CS_TerminateRound(5.0, endReason);
	UltJB_Settings_BlockTerminateRound(false);
	
	new iEnt = GetCapturePointEntity();
	if(iEnt)
		SDKUnhook(iEnt, SDKHook_StartTouchPost, OnStartTouchPost_CapturePoint);
	
	iEnt = GetFlagEntity();
	if(iEnt > 0)
	{
		SDKUnhook(iEnt, SDKHook_TouchPost, OnTouchPost_Flag);
		SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_NODRAW);
	}
	
	iEnt = GetFlagCarriedEntity();
	if(iEnt)
		SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_NODRAW);
	
	new iNewScore = CS_GetTeamScore(iWinningTeam) + 1;
	SetTeamScore(iWinningTeam, iNewScore);
	CS_SetTeamScore(iWinningTeam, iNewScore);
	
	StopTimer_Logic();
}

GetFlagEntity()
{
	new iFlag = EntRefToEntIndex(g_iFlagEntRef);
	if(iFlag > 0)
		return iFlag;
	
	iFlag = CreateEntityByName("breachcharge_projectile");
	if(iFlag < 1)
		return -1;
	
	g_iFlagEntRef = EntIndexToEntRef(iFlag);
	InitFlagEntity(iFlag);
	
	return iFlag;
}

InitFlagEntity(iFlag)
{
	DispatchSpawn(iFlag);
	ActivateEntity(iFlag);
	
	SetEntityModel(iFlag, MODEL_FLAG);
	SetEntityMoveType(iFlag, MOVETYPE_FLYGRAVITY);
	SetEntProp(iFlag, Prop_Send, "m_fEffects", 0);
	
	InitFlagSharedProperties(iFlag);
	SetEntProp(iFlag, Prop_Send, "m_bShouldExplode", 0);
	
	SDKHook(iFlag, SDKHook_TouchPost, OnTouchPost_Flag);
}

GetFlagCarriedEntity()
{
	new iFlag = EntRefToEntIndex(g_iFlagCarriedEntRef);
	if(iFlag > 0)
		return iFlag;
	
	iFlag = CreateEntityByName("prop_dynamic_override");
	if(iFlag < 1)
		return -1;
	
	g_iFlagCarriedEntRef = EntIndexToEntRef(iFlag);
	InitFlagCarriedEntity(iFlag);
	
	return iFlag;
}

InitFlagCarriedEntity(iFlag)
{
	SetEntityModel(iFlag, MODEL_FLAG);
	DispatchSpawn(iFlag);
	SetEntityMoveType(iFlag, MOVETYPE_NONE);
	SetEntProp(iFlag, Prop_Send, "m_fEffects", EF_NODRAW);
	
	InitFlagSharedProperties(iFlag);
}

InitFlagSharedProperties(iFlag)
{
	SetEntProp(iFlag, Prop_Send, "m_nSolidType", SOLID_BBOX);
	SetEntProp(iFlag, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER);
	
	SetEntProp(iFlag, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
	
	SetEntPropVector(iFlag, Prop_Send, "m_vecMins", g_fFlagMins);
	SetEntPropVector(iFlag, Prop_Send, "m_vecMaxs", g_fFlagMaxs);
	
	SetEntProp(iFlag, Prop_Send, "m_nSequence", 2);
	SetEntProp(iFlag, Prop_Send, "m_bClientSideAnimation", 1);
	SetEntPropFloat(iFlag, Prop_Send, "m_flPlaybackRate", 1.0);
}

public OnTouchPost_Flag(iEnt, iOther)
{
	if(!IsPlayer(iOther) || !IsPlayerAlive(iOther))
		return;
	
	if(UltJB_LR_HasStartedLastRequest(iOther) && (UltJB_LR_GetLastRequestFlags(iOther) & LR_FLAG_FREEDAY))
		return;
	
	if(CanReturnFlag(iOther))
	{
		ReturnFlagToSpawn();
		ShowReturnHintText(iOther);
		EmitSoundToAll(SOUND_RETURN[6], _, _, SNDLEVEL_NONE, _, 1.0);
		return;
	}
	
	if(CanPickupFlag(iOther))
	{
		SetFlagCarrier(iOther);
		return;
	}
}

bool:IsPlayer(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return true;
	
	return false;
}

GetFlagsOwnerTeam()
{
	static iFlag;
	iFlag = GetFlagEntity();
	if(iFlag < 1)
		return 0;
	
	return GetEntProp(iFlag, Prop_Data, "m_iTeamNum");
}

SetFlagsOwnerTeam(iTeam)
{
	new iFlag = GetFlagEntity();
	if(iFlag < 1)
		return;
	
	SetEntProp(iFlag, Prop_Data, "m_iTeamNum", iTeam);
}

bool:CanPickupFlag(iClient)
{
	if(!g_bHasStartedCTF)
		return false;
	
	if(GetFlagCarrier() > 0)
		return false;
	
	static iTeam;
	iTeam = GetClientTeam(iClient);
	if(iTeam < TEAM_PRISONERS)
		return false;
	
	if(iTeam == GetFlagsOwnerTeam())
		return false;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < (g_fFlagDroppedTime + PICKUP_DELAY_AFTER_DROPPING))
		return false;
	
	if(fCurTime < (g_fFlagDroppedTimePerClient[iClient] + PICKUP_DELAY_AFTER_DROPPING_PER_CLIENT))
		return false;
	
	return true;
}

bool:CanReturnFlag(iClient)
{
	if(!g_bHasStartedCTF)
		return false;
	
	if(g_bFlagAtSpawn)
		return false;
	
	if(GetFlagCarrier() > 0)
		return false;
	
	static iTeam;
	iTeam = GetClientTeam(iClient);
	if(iTeam != GetFlagsOwnerTeam())
		return false;
	
	if(GetEngineTime() < (g_fFlagDroppedTime + RETURN_DELAY_AFTER_DROPPING))
		return false;
	
	return true;
}

GetFlagCarrier()
{
	new iFlag = GetFlagEntity();
	if(iFlag < 1)
		return CLIENT_NOT_CARRIED;
	
	return GetEntPropEnt(iFlag, Prop_Send, "m_hOwnerEntity");
}

SetFlagCarrier(iClient=CLIENT_NOT_CARRIED, bool:bDropFromDeath=false)
{
	new iFlag = GetFlagEntity();
	if(iFlag < 1)
		return;
	
	new iFlagCarried = GetFlagCarriedEntity();
	if(iFlagCarried < 1)
		return;
	
	new iPrevCarrier = GetEntPropEnt(iFlag, Prop_Send, "m_hOwnerEntity");
	SetEntPropEnt(iFlag, Prop_Send, "m_hOwnerEntity", iClient);
	
	AcceptEntityInput(iFlagCarried, "ClearParent");
	
	if(iClient > 0)
	{
		SetEntProp(iFlag, Prop_Send, "m_fEffects", EF_NODRAW);
		SetEntProp(iFlagCarried, Prop_Send, "m_fEffects", 0);
		
		decl Float:fOrigin[3];
		GetClientAbsOrigin(iClient, fOrigin);
		fOrigin[2] += 32.0;
		
		decl Float:fAngles[3];
		GetClientAbsAngles(iClient, fAngles);
		fAngles[0] = 0.0;
		
		TeleportEntity(iFlagCarried, fOrigin, fAngles, NULL_VECTOR);
		
		SetVariantString("!activator");
		AcceptEntityInput(iFlagCarried, "SetParent", iClient);
		
		SetVariantString("defusekit");
		AcceptEntityInput(iFlagCarried, "SetParentAttachment", iClient);
		
		EmitSoundToAll(SOUND_PICKUP[6], _, _, SNDLEVEL_NONE, _, 0.85);
		
		g_bFlagAtSpawn = false;
	}
	else if(iPrevCarrier > 0)
	{
		// Drop flag.
		SetEntProp(iFlag, Prop_Send, "m_fEffects", 0);
		SetEntProp(iFlagCarried, Prop_Send, "m_fEffects", EF_NODRAW);
		
		decl Float:fOrigin[3], Float:fMins[3], Float:fMaxs[3];
		GetClientAbsOrigin(iPrevCarrier, fOrigin);
		GetEntPropVector(iPrevCarrier, Prop_Send, "m_vecMins", fMins);
		GetEntPropVector(iPrevCarrier, Prop_Send, "m_vecMaxs", fMaxs);	
		fOrigin[0] = fOrigin[0] + ((fMins[0] + fMaxs[0]) * 0.2);
		fOrigin[1] = fOrigin[1] + ((fMins[1] + fMaxs[1]) * 0.2);
		fOrigin[2] = fOrigin[2] + ((fMins[2] + fMaxs[2]) * 0.2);
		
		decl Float:fEyeAngles[3];
		GetClientEyeAngles(iPrevCarrier, fEyeAngles);
		if(fEyeAngles[0] > -45.0)
			fEyeAngles[0] = -45.0;
		
		decl Float:fForward[3];
		
		if(bDropFromDeath)
		{
			fForward[0] = 0.0;
			fForward[1] = 0.0;
			fForward[2] = 100.0;
		}
		else
		{
			decl Float:fRight[3], Float:fUp[3];
			GetAngleVectors(fEyeAngles, fForward, fRight, fUp);
			fForward[0] = fForward[0] * 325.0;
			fForward[1] = fForward[1] * 325.0;
			fForward[2] = fForward[2] * 325.0;
		}
		
		fEyeAngles[0] = 0.0;
		fEyeAngles[1] += bDropFromDeath ? 0.0 : 180.0;
		fEyeAngles[2] = 0.0;
		TeleportEntity(iFlag, fOrigin, fEyeAngles, fForward);
		
		g_fFlagDroppedTime = GetEngineTime();
		g_fFlagDroppedTimePerClient[iPrevCarrier] = g_fFlagDroppedTime;
		
		EmitSoundToAll(SOUND_DROP[6], _, _, SNDLEVEL_NONE, _, 0.85);
	}
}

public Action:OnWeaponDrop(iClient, const String:szCommand[], iArgCount)
{
	if(!IsClientInGame(iClient))
		return Plugin_Continue;
	
	if(!g_bHasStartedCTF)
		return Plugin_Continue;
	
	if(iClient == GetFlagCarrier())
	{
		SetFlagCarrier();
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public OnClientDisconnect(iClient)
{
	if(!g_bHasStartedCTF)
		return;
	
	if(iClient == GetFlagCarrier())
		SetFlagCarrier(CLIENT_NOT_CARRIED, true);
}

public ZoneManager_OnTypeAssigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TELEPORT_DESTINATION)
		return;
	
	decl String:szBuffer[12];
	if(!ZoneManager_GetDataString(iZoneID, 1, szBuffer, sizeof(szBuffer)))
		return;
	
	if(StrEqual(szBuffer, "ctf_capture"))
	{
		g_iTeleportZoneID_Attack = iZoneID;
	}
	else if(StrEqual(szBuffer, "ctf_flag"))
	{
		g_iTeleportZoneID_Defend = iZoneID;
	}
}

public ZoneManager_OnTypeUnassigned(iEnt, iZoneID, iZoneType)
{
	if(iZoneType != ZONE_TYPE_TELEPORT_DESTINATION)
		return;
	
	if(iZoneID == g_iTeleportZoneID_Attack)
	{
		g_iTeleportZoneID_Attack = 0;
	}
	else if(iZoneID == g_iTeleportZoneID_Defend)
	{
		g_iTeleportZoneID_Defend = 0;
	}
}

public ZoneManager_OnZoneRemoved_Pre(iZoneID)
{
	if(iZoneID == g_iTeleportZoneID_Attack)
	{
		g_iTeleportZoneID_Attack = 0;
	}
	else if(iZoneID == g_iTeleportZoneID_Defend)
	{
		g_iTeleportZoneID_Defend = 0;
	}
}

StartTimer_Logic()
{
	StopTimer_Logic();
	g_hTimer_Logic = CreateTimer(0.1, Timer_Logic, _, TIMER_REPEAT);
}

StopTimer_Logic()
{
	if(g_hTimer_Logic == INVALID_HANDLE)
		return;
	
	KillTimer(g_hTimer_Logic);
	g_hTimer_Logic = INVALID_HANDLE;
}

public Action:Timer_Logic(Handle:hTimer)
{
	if(!g_bHasStartedCTF)
	{
		g_hTimer_Logic = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	// End the game if the round time elapsed.
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if((fCurTime - g_fRoundTimeStarted) > g_fRoundTime)
	{
		g_hTimer_Logic = INVALID_HANDLE;
		EndGame(true);
		ShowTimeExpiredHintText();
		
		return Plugin_Stop;
	}
	
	if(g_bFlagAtSpawn)
		return Plugin_Continue;
	
	static iCarrier;
	iCarrier = GetFlagCarrier();
	
	if(iCarrier > 0)
	{
		// Show whos carrying the flag.
		ShowCarriedHintText(iCarrier);
		return Plugin_Continue;
	}
	
	// Check if the flag should auto-return.
	static iTimeBeforeAutoReturn;
	iTimeBeforeAutoReturn = RoundToCeil((g_fFlagDroppedTime + AUTO_RETURN_DELAY_AFTER_DROPPING) - fCurTime);
	
	if(iTimeBeforeAutoReturn < 1)
	{
		ReturnFlagToSpawn();
		ShowReturnHintText();
		EmitSoundToAll(SOUND_RETURN[6], _, _, SNDLEVEL_NONE, _, 1.0);
		return Plugin_Continue;
	}
	
	// Show flag respawn time.
	PrintHintTextToAll("<font color='#DE2626'>Flag dropped!</font>\n<font color='#6FC41A'>Returning in <font color='#DE2626'>%d</font> seconds.</font>", iTimeBeforeAutoReturn);
	
	return Plugin_Continue;
}

ShowTimeExpiredHintText()
{
	static String:szColor[7], String:szTeam[10];
	strcopy(szColor, sizeof(szColor), (g_iDefendingTeam == TEAM_GUARDS) ? "257edd" : "ddaf25");
	strcopy(szTeam, sizeof(szTeam), (g_iDefendingTeam == TEAM_GUARDS) ? "guards" : "prisoners");
	
	PrintHintTextToAll("<font color='#6FC41A'>Flag defended.</font>\n<font color='#%s'>The %s win!</font>", szColor, szTeam);
}

ShowReturnHintText(const iReturner=0)
{
	if(iReturner)
	{
		static String:szColor[7];
		strcopy(szColor, sizeof(szColor), (GetClientTeam(iReturner) == TEAM_GUARDS) ? "257edd" : "ddaf25");
		
		PrintHintTextToAll("<font color='#DE2626'>Flag returned by</font>\n<font color='#%s'>%N</font>", szColor, iReturner);
	}
	else
	{
		PrintHintTextToAll("<font color='#DE2626'>Flag returned!</font>");
	}
}

ShowCarriedHintText(const iCarrier)
{
	static String:szColor[7];
	strcopy(szColor, sizeof(szColor), (GetClientTeam(iCarrier) == TEAM_GUARDS) ? "257edd" : "ddaf25");
	
	PrintHintTextToAll("<font color='#6FC41A'>Flag carried by</font>\n<font color='#%s'>%N</font>", szColor, iCarrier);
}

ShowCapturedHintText(const iCapturer)
{
	decl String:szColor[7];
	strcopy(szColor, sizeof(szColor), (GetClientTeam(iCapturer) == TEAM_GUARDS) ? "257edd" : "ddaf25");
	
	PrintHintTextToAll("<font color='#%s'>%N</font>\n<font color='#6FC41A'>captured the flag!</font>", szColor, iCapturer);
}