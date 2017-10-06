#include <sourcemod>
#include <sdkhooks>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <sdktools_stringtables>
#include <sdktools_trace>
#include <sdktools_engine>
#include <sdktools_functions>
#include <hls_color_chat>
#include <emitsoundany>
#include "Includes/ultjb_warden"
#include "Includes/ultjb_last_request"
#include "Includes/ultjb_logger"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ParticleManager/particle_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warden Menu";
new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "The warden menu plugin for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const String:SZ_BEAM_MATERIAL[] = "materials/sprites/laserbeam.vmt";
new const String:SZ_BEAM_MATERIAL_NOWALL[] = "materials/swoobles/ultimate_jailbreak/wall_beam.vmt";
new g_iBeamIndex;
new g_iBeamNoWallIndex;

new const String:g_szRingNames[][] =
{
	"Green",
	"Red",
	"Yellow",
	"Blue"
};

new g_iRingColors[][] =
{
	{0, 255, 0, 255},
	{255, 0, 0, 255},
	{255, 255, 0, 255},
	{0, 255, 255, 255}
};

enum
{
	MENUINFO_TYPE_HEALING_AREA,
	MENUINFO_TYPE_RINGS,
	MENUINFO_TYPE_CLIENTCOLORS
};

enum
{
	MENUINFO_MANAGERING_SET_POSITION,
	MENUINFO_MANAGERING_SIZE_INCREASE,
	MENUINFO_MANAGERING_SIZE_DECREASE,
	MENUINFO_MANAGERING_REMOVE
};

enum
{
	MENUINFO_CLIENTCOLOR_SETRING,
	MENUINFO_CLIENTCOLOR_REMOVERING,
	MENUINFO_CLIENTCOLOR_REMOVEALL
};

new bool:g_bRingSet[sizeof(g_iRingColors)];
new Float:g_fRingOrigin[sizeof(g_iRingColors)][3];
new Float:g_fRingSize[sizeof(g_iRingColors)];
new Float:g_fRingCustomRadius[sizeof(g_iRingColors)];

#define RING_SIZE_MIN		1.0
#define RING_SIZE_MAX		5.0
#define RING_RADIUS			50.0
#define RING_UPDATE_TIME	0.3

new Float:g_fNextRingUpdate;
new g_iWardenCount;

#define HEALING_RADIUS				33.0
#define HEALING_AREA_UPDATE_TIME	0.5
#define HEALTH_INCREASE_AMOUNT		5
new Float:g_fNextHealUpdate;

new const String:PARTICLE_FILE_PATH[] = "particles/swoobles/jailbreak_v1.pcf";
#if defined _particle_manager_included
new const String:PEFFECT_HEALING_AREA[] = "healing_area";
#endif

new const String:SOUND_HEALING_AREA[] = "sound/ambient/atmosphere/underground_hall_loop1.wav";
//new const String:SOUND_HEALING_AREA[] = "sound/ambient/machines/courtyard_mach_loop.wav";

new const String:SOUND_HEAL_PLAYER[] = "sound/items/medshot4.wav";

new bool:g_bHealingAreaSet;
new Float:g_fHealingAreaOrigin[3];

new g_iHealingEntRef;

new const String:HEALING_MATERIAL_FILES[][] =
{
	"materials/swoobles/particles/ring_wave_10_water_add.vmt",
	"materials/swoobles/particles/flare_002.vmt",
	"materials/swoobles/particles/flare_002.vmt",
	"materials/swoobles/particles/heal_cross_1.vmt",
	
	"materials/swoobles/particles/ring_wave_10_water.vtf",
	"materials/swoobles/particles/flare_002.vtf",
	"materials/swoobles/particles/flare_002.vtf",
	"materials/swoobles/particles/heal_cross_1.vtf"
};

new bool:g_bLibLoaded_ParticleManager;


public OnPluginStart()
{
	CreateConVar("ultjb_wardenmenu_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
	
	RegConsoleCmd("sm_wm", OnWardenMenu, "Opens the warden's menu.");
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ParticleManager = LibraryExists("particle_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = false;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("ultjb_wardenmenu");
	CreateNative("UltJB_WardenMenu_CreateRing", _UltJB_WardenMenu_CreateRing);
	
	return APLRes_Success;
}

public _UltJB_WardenMenu_CreateRing(Handle:hPlugin, iNumParams)
{
	decl Float:fOrigin[3];
	GetNativeArray(3, fOrigin, sizeof(fOrigin));
	SetRingPosition(GetNativeCell(1), GetNativeCell(2), fOrigin, true, GetNativeCell(4));
}

public OnMapStart()
{
	RemoveAllRings(0);
	g_iWardenCount = 0;
	
	AddFileToDownloadsTable(SZ_BEAM_MATERIAL);
	g_iBeamIndex = PrecacheModel(SZ_BEAM_MATERIAL);
	
	AddFileToDownloadsTable(SZ_BEAM_MATERIAL_NOWALL);
	g_iBeamNoWallIndex = PrecacheModel(SZ_BEAM_MATERIAL_NOWALL);
	
	AddFileToDownloadsTable(PARTICLE_FILE_PATH);
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_HEALING_AREA);
		#endif
	}
	
	AddFileToDownloadsTable(SOUND_HEALING_AREA);
	PrecacheSoundAny(SOUND_HEALING_AREA[6]);
	
	AddFileToDownloadsTable(SOUND_HEAL_PLAYER);
	PrecacheSoundAny(SOUND_HEAL_PLAYER[6]);
	
	for(new i=0; i<sizeof(HEALING_MATERIAL_FILES); i++)
		AddFileToDownloadsTable(HEALING_MATERIAL_FILES[i]);
}

public Event_CSPreRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	RemoveHealingArea();
	RemoveAllRings(0);
	g_iWardenCount = 0;
}

public UltJB_Warden_OnSelected(iClient)
{
	g_iWardenCount++;
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Type {lightred}!wm {olive} to open the warden's menu.");
	
	//if(g_iWardenCount == 1)
		//DisplayMenu_WardenMenu(iClient);
}

public UltJB_Warden_OnRemoved(iClient)
{
	RemoveHealingArea();
}

public Action:OnWardenMenu(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_WardenMenu(iClient);
	
	return Plugin_Handled;
}

DisplayMenu_WardenMenu(iClient, iStartItem=0)
{
	if(UltJB_Warden_GetWarden() != iClient)
	{
		DisplayMustBeWardenMessage(iClient);
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_WardenMenu);
	
	decl String:szInfo[4];
	SetMenuTitle(hMenu, "Warden Menu");
	
	IntToString(_:MENUINFO_TYPE_HEALING_AREA, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, g_bHealingAreaSet ? "Remove healing area" : "Create healing area");
	
	IntToString(_:MENUINFO_TYPE_RINGS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Open rings menu");
	
	IntToString(_:MENUINFO_TYPE_CLIENTCOLORS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Set client colors");
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Could not display menu: warden menu.");
		return;
	}
}

public MenuHandle_WardenMenu(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(UltJB_Warden_GetWarden() != iParam1)
	{
		DisplayMustBeWardenMessage(iParam1);
		return;
	}
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENUINFO_TYPE_HEALING_AREA:
		{
			if(g_bHealingAreaSet)
			{
				RemoveHealingArea();
				CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {olive}Healing area removed.");
			}
			else
			{
				SetPosition(iParam1, MENUINFO_TYPE_HEALING_AREA);
			}
			
			DisplayMenu_WardenMenu(iParam1, GetMenuSelectionPosition());
		}
		case MENUINFO_TYPE_RINGS:
		{
			DisplayMenu_RingMenu(iParam1);
		}
		case MENUINFO_TYPE_CLIENTCOLORS:
		{
			DisplayMenu_ClientColorMenu(iParam1);
		}
		default:
		{
			DisplayMenu_WardenMenu(iParam1, GetMenuSelectionPosition());
		}
	}
}

DisplayMenu_RingMenu(iClient, iStartItem=0)
{
	if(UltJB_Warden_GetWarden() != iClient)
	{
		DisplayMustBeWardenMessage(iClient);
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_RingMenu);
	SetMenuTitle(hMenu, "Rings Menu");
	
	AddMenuItem(hMenu, "-1", "Remove all rings");
	
	decl String:szInfo[4], String:szBuffer[32];
	for(new i=0; i<sizeof(g_szRingNames); i++)
	{
		FormatEx(szBuffer, sizeof(szBuffer), "Manage ring: %s", g_szRingNames[i]);
		IntToString(i, szInfo, sizeof(szInfo));
		AddMenuItem(hMenu, szInfo, szBuffer);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Could not display menu: ring menu.");
		return;
	}
}

public MenuHandle_RingMenu(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		DisplayMenu_WardenMenu(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(UltJB_Warden_GetWarden() != iParam1)
	{
		DisplayMustBeWardenMessage(iParam1);
		return;
	}
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iInfo = StringToInt(szInfo);
	if(iInfo == -1)
	{
		RemoveAllRings(iParam1);
		DisplayMenu_RingMenu(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	DisplayMenu_ManageRing(iParam1, iInfo);
}

DisplayMenu_ManageRing(iClient, iRingIndex, iStartItem=0)
{
	if(UltJB_Warden_GetWarden() != iClient)
	{
		DisplayMustBeWardenMessage(iClient);
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_ManageRing);
	
	decl String:szTitle[32], String:szInfo[12];
	Format(szTitle, sizeof(szTitle), "Manage Ring: %s", g_szRingNames[iRingIndex]);
	SetMenuTitle(hMenu, szTitle);
	
	FormatEx(szInfo, sizeof(szInfo), "%i/%i", iRingIndex, MENUINFO_MANAGERING_SET_POSITION);
	AddMenuItem(hMenu, szInfo, "Set position");
	
	FormatEx(szInfo, sizeof(szInfo), "%i/%i", iRingIndex, MENUINFO_MANAGERING_SIZE_INCREASE);
	AddMenuItem(hMenu, szInfo, "Increase size", (g_bRingSet[iRingIndex] && g_fRingSize[iRingIndex] != RING_SIZE_MAX) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	FormatEx(szInfo, sizeof(szInfo), "%i/%i", iRingIndex, MENUINFO_MANAGERING_SIZE_DECREASE);
	AddMenuItem(hMenu, szInfo, "Decrease size", (g_bRingSet[iRingIndex] && g_fRingSize[iRingIndex] != RING_SIZE_MIN) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	AddMenuItem(hMenu, "", "", ITEMDRAW_SPACER);
	
	FormatEx(szInfo, sizeof(szInfo), "%i/%i", iRingIndex, MENUINFO_MANAGERING_REMOVE);
	AddMenuItem(hMenu, szInfo, "Remove ring", g_bRingSet[iRingIndex] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Could not display menu: manage ring.");
		return;
	}
}

public MenuHandle_ManageRing(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		DisplayMenu_RingMenu(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(UltJB_Warden_GetWarden() != iParam1)
	{
		DisplayMustBeWardenMessage(iParam1);
		return;
	}
	
	decl String:szInfo[12], String:szBuffers[2][12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new iNumExplodes = ExplodeString(szInfo, "/", szBuffers, sizeof(szBuffers), sizeof(szBuffers[]));
	if(iNumExplodes != 2)
	{
		CPrintToChat(iParam1, "{green}[{lightred}SM{green}] {red}Something went wrong.");
		return;
	}
	
	new iRingIndex = StringToInt(szBuffers[0]);
	new iMenuInfo = StringToInt(szBuffers[1]);
	
	switch(iMenuInfo)
	{
		case MENUINFO_MANAGERING_SET_POSITION: SetPosition(iParam1, MENUINFO_TYPE_RINGS, iRingIndex);
		case MENUINFO_MANAGERING_SIZE_INCREASE: IncreaseSize(iRingIndex);
		case MENUINFO_MANAGERING_SIZE_DECREASE: DecreaseSize(iRingIndex);
		case MENUINFO_MANAGERING_REMOVE: RemoveRing(iParam1, iRingIndex);
	}
	
	DisplayMenu_ManageRing(iParam1, iRingIndex, GetMenuSelectionPosition());
}

DisplayMenu_ClientColorMenu(iClient, iStartItem=0)
{
	if(UltJB_Warden_GetWarden() != iClient)
	{
		DisplayMustBeWardenMessage(iClient);
		return;
	}
	
	decl String:szInfo[4];
	
	new Handle:hMenu = CreateMenu(MenuHandle_ClientColorMenu);
	SetMenuTitle(hMenu, "Client Color Menu");
	
	IntToString(_:MENUINFO_CLIENTCOLOR_SETRING, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Set client ring color");
	
	IntToString(_:MENUINFO_CLIENTCOLOR_REMOVERING, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Remove client ring color");
	
	IntToString(_:MENUINFO_CLIENTCOLOR_REMOVEALL, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Remove all client colors");
	
	SetMenuExitBackButton(hMenu, true);
	
	if(!DisplayMenuAtItem(hMenu, iClient, iStartItem, 0))
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}Could not display menu: client color menu.");
		return;
	}
}

public MenuHandle_ClientColorMenu(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 != MenuCancel_ExitBack)
			return;
		
		DisplayMenu_WardenMenu(iParam1);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(UltJB_Warden_GetWarden() != iParam1)
	{
		DisplayMustBeWardenMessage(iParam1);
		return;
	}
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENUINFO_CLIENTCOLOR_SETRING:
		{
			SetClientsColor(false, _, true, true);
			DisplayMenu_ClientColorMenu(iParam1, GetMenuSelectionPosition());
		}
		case MENUINFO_CLIENTCOLOR_REMOVERING:
		{
			SetClientsColor(true, _, true, false);
			DisplayMenu_ClientColorMenu(iParam1, GetMenuSelectionPosition());
		}
		case MENUINFO_CLIENTCOLOR_REMOVEALL:
		{
			SetClientsColor(true, _, false, false);
			DisplayMenu_ClientColorMenu(iParam1, GetMenuSelectionPosition());
		}
		default:
		{
			DisplayMenu_WardenMenu(iParam1);
		}
	}
}

DisplayMustBeWardenMessage(iClient)
{
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}You must be warden to use this menu.");
}

SetPosition(iClient, iType, iRingIndex=0)
{
	decl Float:fEyePos[3], Float:fVector[3];
	GetClientEyePosition(iClient, fEyePos);
	GetClientEyeAngles(iClient, fVector);
	
	TR_TraceRayFilter(fEyePos, fVector, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_DontHitPlayers);
	
	TR_GetEndPosition(fVector);
	CreateSetPositionEffect(iClient, fVector);
	
	decl Float:fNormal[3];
	TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
	
	if(fNormal[2] < 0.85)
	{
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {red}You must place this on a flat surface.");
		return;
	}
	
	switch(iType)
	{
		case MENUINFO_TYPE_HEALING_AREA:
		{
			InitHealingArea(fVector);
			CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}Healing area created.");
		}
		case MENUINFO_TYPE_RINGS:
		{
			SetRingPosition(iClient, iRingIndex, fVector);
		}
	}
}

SetRingPosition(iClient, iRingIndex, const Float:fOrigin[3], bool:bUseCustomRadius=false, Float:fCustomRadius=0.0)
{
	if(bUseCustomRadius)
	{
		g_fRingCustomRadius[iRingIndex] = fCustomRadius;
		
		if(g_fRingCustomRadius[iRingIndex] > (RING_RADIUS * RING_SIZE_MAX))
		{
			g_fRingSize[iRingIndex] = RING_SIZE_MAX;
			g_fRingCustomRadius[iRingIndex] = 0.0;
		}
		else if(g_fRingCustomRadius[iRingIndex] < (RING_RADIUS * RING_SIZE_MIN))
		{
			g_fRingSize[iRingIndex] = RING_SIZE_MIN;
			g_fRingCustomRadius[iRingIndex] = 0.0;
		}
	}
	
	g_fRingOrigin[iRingIndex][0] = fOrigin[0];
	g_fRingOrigin[iRingIndex][1] = fOrigin[1];
	g_fRingOrigin[iRingIndex][2] = fOrigin[2];
	
	g_bRingSet[iRingIndex] = true;
	g_fNextRingUpdate = 0.0;
	
	CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}%s ring's position set.", g_szRingNames[iRingIndex]);
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}

CreateSetPositionEffect(iClient, const Float:fOrigin[3])
{
	TE_SetupBeamRingPoint(fOrigin, 35.0, 2.0, g_iBeamNoWallIndex, 0, 1, 1, 0.25, 2.0, 0.0, {0, 255, 255, 255}, 20, 0);
	TE_SendToClient(iClient);
}

IncreaseSize(iRingIndex)
{
	if(g_fRingSize[iRingIndex] >= RING_SIZE_MAX)
		return;
	
	g_fRingSize[iRingIndex]++;
	g_fRingCustomRadius[iRingIndex] = 0.0;
	g_fNextRingUpdate = 0.0;
}

DecreaseSize(iRingIndex)
{
	if(g_fRingSize[iRingIndex] <= RING_SIZE_MIN)
		return;
	
	g_fRingSize[iRingIndex]--;
	g_fRingCustomRadius[iRingIndex] = 0.0;
	g_fNextRingUpdate = 0.0;
}

RemoveRing(iClient, iRingIndex)
{
	if(g_bRingSet[iRingIndex] && iClient && IsClientInGame(iClient))
		CPrintToChat(iClient, "{green}[{lightred}SM{green}] {olive}%s ring removed.", g_szRingNames[iRingIndex]);
	
	g_bRingSet[iRingIndex] = false;
	g_fRingSize[iRingIndex] = (RING_SIZE_MAX - RING_SIZE_MIN) / 2.0;
}

RemoveAllRings(iClient)
{
	for(new i=0; i<sizeof(g_bRingSet); i++)
		RemoveRing(iClient, i);
}

public OnGameFrame()
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime >= g_fNextRingUpdate)
	{
		g_fNextRingUpdate = fCurTime + RING_UPDATE_TIME;
		
		static i;
		for(i=0; i<sizeof(g_szRingNames); i++)
		{
			if(g_bRingSet[i])
				DisplayRing(i);
		}
	}
	
	if(fCurTime >= g_fNextHealUpdate)
	{
		g_fNextHealUpdate = fCurTime + HEALING_AREA_UPDATE_TIME;
		
		if(g_bHealingAreaSet)
			UpdateHealingArea();
	}
}

DisplayRing(iRingIndex)
{
	static Float:fDiameter, Float:fOrigin[3];
	
	if(g_fRingCustomRadius[iRingIndex] == 0.0)
		fDiameter = RING_RADIUS * g_fRingSize[iRingIndex] * 2.0;
	else
		fDiameter = g_fRingCustomRadius[iRingIndex] * 2.0;
	
	fOrigin[0] = g_fRingOrigin[iRingIndex][0];
	fOrigin[1] = g_fRingOrigin[iRingIndex][1];
	fOrigin[2] = g_fRingOrigin[iRingIndex][2] + 10.0;
	
	TE_SetupBeamRingPoint(fOrigin, fDiameter - 1.0, fDiameter, g_iBeamIndex, 0, 0, 5, RING_UPDATE_TIME + 0.1, 5.0, 0.0, g_iRingColors[iRingIndex], 10, 0);
	TE_SendToAll();
}

UpdateHealingArea()
{
	DisplayHealingArea();
	
	new iEnt = GetHealingEnt();
	if(iEnt < 1)
		return;
	
	// Play the healing client sound once at the healing ents origin if a player is inside the radius.
	decl Float:fClientOrigin[3];
	new bool:bPlayedHealingSound;
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		if(!IsPlayerAlive(iClient))
			continue;
		
		if(GetClientTeam(iClient) != TEAM_PRISONERS)
			continue;
		
		GetClientAbsOrigin(iClient, fClientOrigin);
		if(GetVectorDistance(fClientOrigin, g_fHealingAreaOrigin) > HEALING_RADIUS)
			continue;
		
		if(!HealClient(iClient))
			continue;
		
		if(!bPlayedHealingSound)
		{
			PlayHealingClientSound();
			bPlayedHealingSound = true;
		}
	}
}

DisplayHealingArea()
{
	decl Float:fColor[3];
	fColor[0] = 255.0;
	fColor[1] = GetRandomFloat(65.0, 160.0);
	fColor[2] = fColor[1];
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		PM_CreateEntityEffectCustomOrigin(0, PEFFECT_HEALING_AREA, g_fHealingAreaOrigin, Float:{0.0, 0.0, 0.0}, fColor);
		#endif
	}
}

InitHealingArea(const Float:fOrigin[3])
{
	g_fHealingAreaOrigin[0] = fOrigin[0];
	g_fHealingAreaOrigin[1] = fOrigin[1];
	g_fHealingAreaOrigin[2] = fOrigin[2] + 5.0;
	
	g_fNextHealUpdate = 0.0;
	g_bHealingAreaSet = true;
	
	new iEnt = GetHealingEnt();
	if(iEnt)
	{
		TeleportEntity(iEnt, g_fHealingAreaOrigin, NULL_VECTOR, NULL_VECTOR);
		PlayHealingAreaSound(iEnt);
	}
}

RemoveHealingArea()
{
	new iEnt = GetHealingEnt();
	if(iEnt)
		PlayHealingAreaSound(iEnt, false);
	
	g_bHealingAreaSet = false;
}

GetHealingEnt()
{
	new iEnt = EntRefToEntIndex(g_iHealingEntRef);
	if(iEnt > 0 && iEnt != INVALID_ENT_REFERENCE)
		return iEnt;
	
	iEnt = CreateEntityByName("info_target");
	if(iEnt < 1 || !IsValidEntity(iEnt))
		return 0;
	
	SetEdictFlags(iEnt, FL_EDICT_FULL | FL_EDICT_ALWAYS);
	g_iHealingEntRef = EntIndexToEntRef(iEnt);
	
	return iEnt;
}

bool:HealClient(iClient)
{
	new iOrigHealth = GetEntProp(iClient, Prop_Data, "m_iHealth");
	if(iOrigHealth >= 100)
		return false;
	
	new iHealth = iOrigHealth + HEALTH_INCREASE_AMOUNT;
	
	if(iHealth > 100)
		iHealth = 100;
	
	UltJB_LR_SetClientsHealth(iClient, iHealth);
	
	new String:szMessage[512];
	Format(szMessage, sizeof(szMessage), "Warden healed %N for %d.", iClient, iHealth - iOrigHealth);
	UltJB_Logger_LogEvent(szMessage, iClient, 0, LOGTYPE_ATTACK);
	
	return true;
}

PlayHealingAreaSound(iEnt, bool:bStart=true)
{
	decl iFlags;
	if(bStart)
		iFlags = SND_NOFLAGS;
	else
		iFlags = SND_STOP | SND_STOPLOOPING;
	
	EmitSoundToAllAny(SOUND_HEALING_AREA[6], iEnt, SNDCHAN_BODY, SNDLEVEL_NORMAL, iFlags);
}

PlayHealingClientSound()
{
	EmitAmbientSoundAny(SOUND_HEAL_PLAYER[6], g_fHealingAreaOrigin, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6, 130);
}

SetClientsColor(bool:bRemoveColor, const iColor[4]={255, 255, 255, 255}, bool:bInRingsOnly=false, bool:bUseRingColor=true)
{
    decl iRingIndex, iNewColor[4];
    for(new iClient=1; iClient<=MaxClients; iClient++)
    {
        if(!IsClientInGame(iClient))
            continue;
        
        if(!IsPlayerAlive(iClient))
            continue;
        
        if(GetClientTeam(iClient) != TEAM_PRISONERS)
            continue;
        
        iNewColor[0] = iColor[0];
        iNewColor[1] = iColor[1];
        iNewColor[2] = iColor[2];
        iNewColor[3] = iColor[3];
        
        if(bInRingsOnly)
        {
            iRingIndex = GetClientsRingIndex(iClient);
            if(iRingIndex == -1)
                continue;
            
            if(bUseRingColor)
                iNewColor = g_iRingColors[iRingIndex];
        }
        
        if(bRemoveColor)
		{
			SetEntityRenderColor(iClient, 255, 255, 255, 255);
			SetEntProp(iClient, Prop_Send, "m_nSkin", 0);
		}
        else
		{
			SetEntityRenderColor(iClient, iNewColor[0], iNewColor[1], iNewColor[2], iNewColor[3]);
			SetEntProp(iClient, Prop_Send, "m_nSkin", 1);
		}
    }
}

GetClientsRingIndex(iClient)
{
    decl Float:fClientOrigin[3], Float:fRadius;
    for(new i=0; i<sizeof(g_bRingSet); i++)
    {
        if(!g_bRingSet[i])
            continue;
        
        if(g_fRingCustomRadius[i] == 0.0)
            fRadius = RING_RADIUS * g_fRingSize[i];
        else
            fRadius = g_fRingCustomRadius[i];
        
        GetClientAbsOrigin(iClient, fClientOrigin);
        
        if(GetVectorDistance(fClientOrigin, g_fRingOrigin[i]) <= fRadius)
            return i;
    }
    
    return -1;
}