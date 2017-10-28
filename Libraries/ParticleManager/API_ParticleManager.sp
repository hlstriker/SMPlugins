#include <sourcemod>
#include <sdktools_stringtables>
#include <sdktools_tempents>
#include <sdktools_functions>
#include <sdkhooks>
#include "particle_manager"

#undef REQUIRE_PLUGIN
#include "../FileDownloader/file_downloader"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Particle Manager";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to manage particle systems.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

// sv_force_transmit_players 1

#define PARTICLE_DISPATCH_FROM_ENTITY		(1<<0)
#define PARTICLE_DISPATCH_RESET_PARTICLES	(1<<1)

enum ParticleAttachment_CSGO
{
	PATTACH_ABSORIGIN = 0,		// Create at absorigin, but don't follow
	PATTACH_ABSORIGIN_FOLLOW,	// Create at absorigin, and update to follow the entity
	PATTACH_CUSTOMORIGIN,		// Create at a custom origin, but don't follow
	PATTACH_UNKNOWN1,			// Seems to be the same as PATTACH_ABSORIGIN
	PATTACH_POINT,				// Create on attachment point, but don't follow
	PATTACH_POINT_FOLLOW		// Create on attachment point, and update to follow the entity
};

new bool:g_bCanUseParticleEffects;
new bool:g_bIsDownloadingParticleFile;
new bool:g_bIsDownloadingParticleFile_Bz2;
new const String:MANAGER_FILE_PATH[] = "particles/particle_manager/pm_plugin_v2.pcf";
new const String:MANAGER_STOP_EFFECT[] = "particle_manager_stop";

new g_iFakeWorldEntRef;

new bool:g_bHasEffect[MAXPLAYERS+1];

#define EFS_CLEAN_DELAY	1.5

enum _:EdictFlagState
{
	EFS_EntityRef,
	EFS_OriginalFlags,
	EFS_OriginalFlagsPost,
	Float:EFS_SetTime
};

new Handle:g_aEdictFlagStates;


public OnPluginStart()
{
	CreateConVar("api_particle_manager_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("cs_pre_restart", Event_CSPreRestart_Post, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	g_aEdictFlagStates = CreateArray(EdictFlagState);
	CreateTimer(1.0, Timer_CheckCleanEFS, _, TIMER_REPEAT);
}

public Event_CSPreRestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		g_bHasEffect[iClient] = false;
}

public Event_PlayerDeath(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!g_bHasEffect[iClient])
		return;
	
	StopEntityEffects(iClient);
	g_bHasEffect[iClient] = false;
}

CreateFakeWorldEntity()
{
	if(g_iFakeWorldEntRef && EntRefToEntIndex(g_iFakeWorldEntRef) > 0)
		return;
	
	new iEnt = CreateEntityByName("info_target");
	if(iEnt < 1)
		return;
	
	SetEdictFlags(iEnt, FL_EDICT_ALWAYS); // We must always transmit this entity.
	g_iFakeWorldEntRef = EntIndexToEntRef(iEnt);
}

GetFakeWorldEntity()
{
	return EntRefToEntIndex(g_iFakeWorldEntRef);
}

public Event_RoundStart(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	CreateFakeWorldEntity();
}

public OnMapStart()
{
	CreateFakeWorldEntity();
	
	PrecacheEffect("ParticleEffect");
	PrecacheEffect("ParticleEffectStop");
	
	if(!IsParticleFileDownloading())
	{
		AddFileToDownloadsTable(MANAGER_FILE_PATH);
		PrecacheParticleEffect(MANAGER_FILE_PATH, MANAGER_STOP_EFFECT);
		g_bCanUseParticleEffects = true;
	}
	else
	{
		g_bCanUseParticleEffects = false;
	}
}

bool:IsParticleFileDownloading()
{
	#if !defined _file_downloader_included
	
	// Suppress warnings if the file downloader isn't included.
	if(g_bIsDownloadingParticleFile || g_bIsDownloadingParticleFile_Bz2)
	{
		//
	}
	
	return false;
	
	#else
	
	if(g_bIsDownloadingParticleFile || g_bIsDownloadingParticleFile_Bz2)
		return true;
	
	if(FileExists(MANAGER_FILE_PATH, true))
		return false;
	
	g_bIsDownloadingParticleFile = true;
	g_bIsDownloadingParticleFile_Bz2 = true;
	
	LogMessage("Starting download: %s", MANAGER_FILE_PATH);
	
	decl String:szURL[512];
	FormatEx(szURL, sizeof(szURL), "http://swoobles.com/plugin_files/%s", MANAGER_FILE_PATH);
	FileDownloader_DownloadFile(szURL, MANAGER_FILE_PATH, OnDownloadSuccess, OnDownloadFailed);
	
	decl String:szFilePathBz2[PLATFORM_MAX_PATH];
	StrCat(szURL, sizeof(szURL), ".bz2");
	FormatEx(szFilePathBz2, sizeof(szFilePathBz2), "%s.bz2", MANAGER_FILE_PATH);
	FileDownloader_DownloadFile(szURL, szFilePathBz2, OnDownloadSuccess_Bz2, OnDownloadFailed_Bz2);
	
	return true;
	
	#endif
}

public OnDownloadSuccess(const String:szFilePath[], any:data)
{
	LogMessage("Successfully downloaded: %s", szFilePath);
	g_bIsDownloadingParticleFile = false;
}

public OnDownloadFailed(const String:szFilePath[], any:data)
{
	LogError("Failed to downloaded: %s", szFilePath);
	g_bIsDownloadingParticleFile = false;
}

public OnDownloadSuccess_Bz2(const String:szFilePath[], any:data)
{
	LogMessage("Successfully downloaded: %s", szFilePath);
	g_bIsDownloadingParticleFile_Bz2 = false;
}

public OnDownloadFailed_Bz2(const String:szFilePath[], any:data)
{
	LogError("Failed to downloaded: %s", szFilePath);
	g_bIsDownloadingParticleFile_Bz2 = false;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("particle_manager");
	
	CreateNative("PM_PrecacheParticleEffect", _PM_PrecacheParticleEffect);
	CreateNative("PM_CreateEntityEffect", _PM_CreateEntityEffect);
	CreateNative("PM_CreateEntityEffectFollow", _PM_CreateEntityEffectFollow);
	CreateNative("PM_CreateEntityEffectCustomOrigin", _PM_CreateEntityEffectCustomOrigin);
	CreateNative("PM_CreateWorldEffect", _PM_CreateWorldEffect);
	CreateNative("PM_StopEntityEffects", _PM_StopEntityEffects);
	
	return APLRes_Success;
}

public _PM_PrecacheParticleEffect(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 2)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iLengthFilePath;
	if(GetNativeStringLength(1, iLengthFilePath) != SP_ERROR_NONE)
		return;
	
	new iLengthEffect;
	if(GetNativeStringLength(2, iLengthEffect) != SP_ERROR_NONE)
		return;
	
	iLengthFilePath++;
	decl String:szParticleFilePath[iLengthFilePath];
	GetNativeString(1, szParticleFilePath, iLengthFilePath);
	
	iLengthEffect++;
	decl String:szParticleEffect[iLengthEffect];
	GetNativeString(2, szParticleEffect, iLengthEffect);
	
	PrecacheParticleEffect(szParticleFilePath, szParticleEffect);
}

public _PM_CreateEntityEffect(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 6)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iLength;
	if(GetNativeStringLength(2, iLength) != SP_ERROR_NONE)
		return;
	
	iLength++;
	decl String:szParticleEffect[iLength];
	GetNativeString(2, szParticleEffect, iLength);
	
	new iNumClients = GetNativeCell(6);
	decl iClients[iNumClients];
	GetNativeArray(5, iClients, iNumClients);
	
	CreateEntityEffect(GetNativeCell(1), szParticleEffect, GetNativeCell(3), GetNativeCell(4), iClients, iNumClients);
}

public _PM_CreateEntityEffectFollow(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 6)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iLength;
	if(GetNativeStringLength(2, iLength) != SP_ERROR_NONE)
		return;
	
	iLength++;
	decl String:szParticleEffect[iLength];
	GetNativeString(2, szParticleEffect, iLength);
	
	new iNumClients = GetNativeCell(6);
	decl iClients[iNumClients];
	GetNativeArray(5, iClients, iNumClients);
	
	CreateEntityEffectFollow(GetNativeCell(1), szParticleEffect, GetNativeCell(3), GetNativeCell(4), iClients, iNumClients);
}

public _PM_CreateEntityEffectCustomOrigin(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 8)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iLength;
	if(GetNativeStringLength(2, iLength) != SP_ERROR_NONE)
		return;
	
	iLength++;
	decl String:szParticleEffect[iLength];
	GetNativeString(2, szParticleEffect, iLength);
	
	decl Float:fOrigin[3], Float:fAngles[3], Float:fControlPointOneOrigin[3];
	GetNativeArray(3, fOrigin, sizeof(fOrigin));
	GetNativeArray(4, fAngles, sizeof(fAngles));
	GetNativeArray(5, fControlPointOneOrigin, sizeof(fControlPointOneOrigin));
	
	new iNumClients = GetNativeCell(8);
	decl iClients[iNumClients];
	GetNativeArray(7, iClients, iNumClients);
	
	CreateEntityEffectCustomOrigin(GetNativeCell(1), szParticleEffect, fOrigin, fAngles, fControlPointOneOrigin, GetNativeCell(6), iClients, iNumClients);
}

public _PM_CreateWorldEffect(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 4)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	new iLength;
	if(GetNativeStringLength(1, iLength) != SP_ERROR_NONE)
		return;
	
	iLength++;
	decl String:szParticleEffect[iLength];
	GetNativeString(1, szParticleEffect, iLength);
	
	decl Float:fOrigin[3], Float:fAngles[3], Float:fControlPointOneOrigin[3];
	GetNativeArray(2, fOrigin, sizeof(fOrigin));
	GetNativeArray(3, fAngles, sizeof(fAngles));
	GetNativeArray(4, fControlPointOneOrigin, sizeof(fControlPointOneOrigin));
	
	CreateWorldEffect(szParticleEffect, fOrigin, fAngles, fControlPointOneOrigin);
}

public _PM_StopEntityEffects(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return;
	}
	
	StopEntityEffects(GetNativeCell(1));
}

PrecacheEffect(const String:szEffect[])
{
	static iTable = INVALID_STRING_TABLE;
	
	if(iTable == INVALID_STRING_TABLE)
		iTable = FindStringTable("EffectDispatch");
	
	new bool:bSave = LockStringTables(false);
	AddToStringTable(iTable, szEffect);
	LockStringTables(bSave);
}

PrecacheParticleEffect(const String:szParticleFilePath[], const String:szParticleEffect[])
{
	PrecacheGeneric(szParticleFilePath, true);
	
	static iTable = INVALID_STRING_TABLE;
	
	if(iTable == INVALID_STRING_TABLE)
		iTable = FindStringTable("ParticleEffectNames");
	
	new bool:bSave = LockStringTables(false);
	AddToStringTable(iTable, szParticleEffect);
	LockStringTables(bSave);
}

GetParticleEffectIndex(const String:szParticleEffect[])
{
	static iTable = INVALID_STRING_TABLE;
	
	if(iTable == INVALID_STRING_TABLE)
		iTable = FindStringTable("ParticleEffectNames");
	
	new iIndex = FindStringIndex(iTable, szParticleEffect);
	if(iIndex != INVALID_STRING_INDEX)
		return iIndex;
	
	return 0;
}

GetEffectIndex(const String:szEffect[])
{
	static iTable = INVALID_STRING_TABLE;
	
	if(iTable == INVALID_STRING_TABLE)
		iTable = FindStringTable("EffectDispatch");
	
	new iIndex = FindStringIndex(iTable, szEffect);
	if(iIndex != INVALID_STRING_INDEX)
		return iIndex;
	
	return 0;
}

CreateEntityEffect(iEntToUse, const String:szParticleEffect[], iAttachmentPoint, bool:bStopPriorEffects, iClients[], iNumClients)
{
	if(!g_bCanUseParticleEffects)
		return;
	
	// It's not safe to use the world entity because clients will crash on map change if a particle was created on the world ent.
	// Try to use a fake entity we created.
	new iEnt = iEntToUse;
	if(!iEnt)
	{
		iEnt = GetFakeWorldEntity();
		
		if(iEnt < 1)
			return;
	}
	
	CheckForTransmitAlways(iEnt);
	
	TE_Start("EffectDispatch");
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	
	TE_WriteNum("entindex", iEnt);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(szParticleEffect));
	TE_WriteNum("m_fFlags", PARTICLE_DISPATCH_FROM_ENTITY | (bStopPriorEffects ? PARTICLE_DISPATCH_RESET_PARTICLES : 0));
	
	if(iAttachmentPoint > 0)
	{
		TE_WriteNum("m_nDamageType", _:PATTACH_POINT);
		TE_WriteNum("m_nAttachmentIndex", iAttachmentPoint);
	}
	else
	{
		TE_WriteNum("m_nDamageType", _:PATTACH_ABSORIGIN);
	}
	
	if(iNumClients)
		TE_Send(iClients, iNumClients);
	else
		TE_SendToAll();
	
	CheckForClientEffect(iEnt);
}

CreateEntityEffectFollow(iEntToUse, const String:szParticleEffect[], iAttachmentPoint, bool:bStopPriorEffects, iClients[], iNumClients)
{
	if(!g_bCanUseParticleEffects)
		return;
	
	// It's not safe to use the world entity because clients will crash on map change if a particle was created on the world ent.
	// Try to use a fake entity we created.
	new iEnt = iEntToUse;
	if(!iEnt)
	{
		iEnt = GetFakeWorldEntity();
		
		if(iEnt < 1)
			return;
	}
	
	CheckForTransmitAlways(iEnt);
	
	TE_Start("EffectDispatch");
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	
	TE_WriteNum("entindex", iEnt);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(szParticleEffect));
	TE_WriteNum("m_fFlags", PARTICLE_DISPATCH_FROM_ENTITY | (bStopPriorEffects ? PARTICLE_DISPATCH_RESET_PARTICLES : 0));
	
	if(iAttachmentPoint > 0)
	{
		TE_WriteNum("m_nDamageType", _:PATTACH_POINT_FOLLOW);
		TE_WriteNum("m_nAttachmentIndex", iAttachmentPoint);
	}
	else
	{
		TE_WriteNum("m_nDamageType", _:PATTACH_ABSORIGIN_FOLLOW);
	}
	
	if(iNumClients)
		TE_Send(iClients, iNumClients);
	else
		TE_SendToAll();
	
	CheckForClientEffect(iEnt);
}

CreateEntityEffectCustomOrigin(iEntToUse, const String:szParticleEffect[], const Float:fOrigin[3], const Float:fAngles[3], const Float:fControlPointOneOrigin[3], bool:bStopPriorEffects, iClients[], iNumClients)
{
	if(!g_bCanUseParticleEffects)
		return;
	
	// It's not safe to use the world entity because clients will crash on map change if a particle was created on the world ent.
	// Try to use a fake entity we created.
	new iEnt = iEntToUse;
	if(!iEnt)
	{
		iEnt = GetFakeWorldEntity();
		
		if(iEnt < 1)
			return;
	}
	
	CheckForTransmitAlways(iEnt);
	
	TE_Start("EffectDispatch");
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	
	TE_WriteNum("entindex", iEnt);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(szParticleEffect));
	TE_WriteNum("m_fFlags", PARTICLE_DISPATCH_FROM_ENTITY | (bStopPriorEffects ? PARTICLE_DISPATCH_RESET_PARTICLES : 0));
	
	TE_WriteNum("m_nDamageType", _:PATTACH_CUSTOMORIGIN);
	
	TE_WriteFloatArray("m_vOrigin.x", fOrigin, sizeof(fOrigin));
	TE_WriteFloatArray("m_vStart.x", fControlPointOneOrigin, sizeof(fControlPointOneOrigin));
	TE_WriteVector("m_vAngles", fAngles);
	
	if(iNumClients)
		TE_Send(iClients, iNumClients);
	else
		TE_SendToAll();
	
	CheckForClientEffect(iEnt);
}

CheckForTransmitAlways(iEnt)
{
	// Don't change players transmit state.
	//if(1 <= iEnt <= MaxClients)
	//	return;
	
	decl eEdictFlagState[EdictFlagState];
	new iFlags = GetEdictFlags(iEnt);
	new iEntRef = EntIndexToEntRef(iEnt);
	
	new iFlagsPost = iFlags;
	iFlagsPost &= ~FL_EDICT_DONTSEND;
	iFlagsPost &= ~FL_EDICT_PVSCHECK;
	iFlagsPost |= FL_EDICT_ALWAYS;
	
	new iIndex = FindValueInArray(g_aEdictFlagStates, iEntRef);
	if(iIndex != -1)
	{
		GetArrayArray(g_aEdictFlagStates, iIndex, eEdictFlagState);
		eEdictFlagState[EFS_SetTime] = GetGameTime();
		
		if(iFlags != eEdictFlagState[EFS_OriginalFlagsPost])
		{
			eEdictFlagState[EFS_OriginalFlags] = iFlags;
			eEdictFlagState[EFS_OriginalFlagsPost] = iFlags;
		}
		
		SetArrayArray(g_aEdictFlagStates, iIndex, eEdictFlagState);
	}
	else
	{
		eEdictFlagState[EFS_EntityRef] = iEntRef;
		eEdictFlagState[EFS_OriginalFlags] = iFlags;
		eEdictFlagState[EFS_OriginalFlagsPost] = iFlagsPost;
		eEdictFlagState[EFS_SetTime] = GetGameTime();
		PushArrayArray(g_aEdictFlagStates, eEdictFlagState);
	}
	
	SetEdictFlags(iEnt, iFlags);
}

public Action:Timer_CheckCleanEFS(Handle:hTimer)
{
	static iArraySize, i, Float:fCurTime, eEdictFlagState[EdictFlagState], iEnt;
	iArraySize = GetArraySize(g_aEdictFlagStates);
	
	if(!iArraySize)
		return;
	
	fCurTime = GetGameTime();
	
	for(i=0; i<iArraySize; i++)
	{
		GetArrayArray(g_aEdictFlagStates, i, eEdictFlagState);
		if(eEdictFlagState[EFS_SetTime] < (fCurTime + EFS_CLEAN_DELAY))
			continue;
		
		iEnt = EntRefToEntIndex(eEdictFlagState[EFS_EntityRef]);
		if(iEnt != INVALID_ENT_REFERENCE)
		{
			// Only update if the flags are still exactly what we set it too.
			if(GetEdictFlags(iEnt) == eEdictFlagState[EFS_OriginalFlagsPost])
				SetEdictFlags(iEnt, eEdictFlagState[EFS_OriginalFlags]);
		}
		
		RemoveFromArray(g_aEdictFlagStates, i);
		iArraySize--;
		i--;
	}
}

CheckForClientEffect(iEnt)
{
	if(!(1 <= iEnt <= MaxClients))
		return;
	
	g_bHasEffect[iEnt] = true;
}

CreateWorldEffect(const String:szParticleEffect[], const Float:fOrigin[3], const Float:fAngles[3], const Float:fControlPointOneOrigin[3])
{
	if(!g_bCanUseParticleEffects)
		return;
	
	TE_Start("EffectDispatch");
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(szParticleEffect));
	
	TE_WriteFloatArray("m_vOrigin.x", fOrigin, sizeof(fOrigin));
	TE_WriteFloatArray("m_vStart.x", fControlPointOneOrigin, sizeof(fControlPointOneOrigin));
	TE_WriteVector("m_vAngles", fAngles);
	
	TE_SendToAll();
}

StopEntityEffects(iEntToUse)
{
	if(!g_bCanUseParticleEffects)
		return;
	
	// It's not safe to use the world entity because clients will crash on map change if a particle was created on the world ent.
	// Try to use a fake entity we created.
	new iEnt = iEntToUse;
	if(!iEnt)
	{
		iEnt = GetFakeWorldEntity();
		
		if(iEnt < 1)
			return;
	}
	
	CheckForTransmitAlways(iEnt);
	
	/*
	// Note: Some reason this isn't stopping every particle effect on an entity.
	// It sems to leave the first effect applied if there were multiple applied.
	TE_Start("EffectDispatch");
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffectStop"));
	TE_WriteNum("entindex", iEnt);
	TE_SendToAll();
	*/
	
	// Instead simply send a particle system that has no properties applied within it.
	// Make sure it has the PARTICLE_DISPATCH_RESET_PARTICLES flag applied as this is what emulates the stopping.
	TE_Start("EffectDispatch");
	TE_WriteNum("m_iEffectName", GetEffectIndex("ParticleEffect"));
	
	TE_WriteNum("entindex", iEnt);
	TE_WriteNum("m_nHitBox", GetParticleEffectIndex(MANAGER_STOP_EFFECT));
	TE_WriteNum("m_fFlags", PARTICLE_DISPATCH_FROM_ENTITY | PARTICLE_DISPATCH_RESET_PARTICLES);
	
	TE_SendToAll();
}