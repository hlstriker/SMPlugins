#include <sourcemod>
#include <sdktools_engine>
#include <sdktools_tempents>
#include <sdktools_trace>
#include <sdktools_stringtables>
#include "../../../Libraries/Store/store"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Bullet Tracers";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have bullet tracers.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fNextTracerTime[MAXPLAYERS+1];
const Float:TRACER_DELAY = 0.02;

new Handle:g_aItems;

new const String:SZ_DEFAULT_DESIGN[] = "materials/sprites/laserbeam.vmt";
new g_iDefaultDesignPrecacheID;

new const String:SZ_WEAPON_MODEL_ELITE[] = "models/weapons/v_pist_elite.mdl";
new g_iWeaponModelIndex_Elite;

const WEAPON_ELITE_LEFT_SEQUENCE = 2;
const WEAPON_ELITE_LEFT_MASK = 0x4000;

const WEAPON_ELITE_RIGHT_SEQUENCE = 4;
const WEAPON_ELITE_RIGHT_MASK = 0x3000;

#define SPECMODE_FIRSTPERSON	4


public OnPluginStart()
{
	CreateConVar("store_item_bullet_tracers_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aItems = CreateArray();
	HookEvent("bullet_impact", Event_BulletImpact_Post, EventHookMode_Post);
}

public OnMapStart()
{
	ClearArray(g_aItems);
	
	AddFileToDownloadsTable(SZ_DEFAULT_DESIGN);
	g_iDefaultDesignPrecacheID = PrecacheModel(SZ_DEFAULT_DESIGN);
	
	g_iWeaponModelIndex_Elite = PrecacheModel(SZ_WEAPON_MODEL_ELITE);
}

public Store_OnItemsReady()
{
	new iIndex = -1;
	decl iFoundItemID;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_BULLET_TRACER, iFoundItemID)) != -1)
	{
		PushArrayCell(g_aItems, iFoundItemID);
	}
}

public Event_BulletImpact_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	static iClient;
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsFakeClient(iClient))
		return;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextTracerTime[iClient])
		return;
	
	new iItemID = GetRandomItemID(iClient);
	if(iItemID < 1)
		return;
	
	static String:szColor[MAX_STORE_DATA_STRING_LEN];
	if(!Store_GetItemsDataString(iItemID, 1, szColor, sizeof(szColor)))
		return;
	
	static String:szExplode[4][4];
	ExplodeString(szColor, " ", szExplode, sizeof(szExplode), sizeof(szExplode[]));
	
	static iColor[4];
	iColor[0] = StringToInt(szExplode[0]);
	iColor[1] = StringToInt(szExplode[1]);
	iColor[2] = StringToInt(szExplode[2]);
	iColor[3] = GetRandomInt(85, 150);
	
	new iPrecacheID = Store_GetItemsMainFilePrecacheID(iItemID);
	if(!iPrecacheID)
		iPrecacheID = g_iDefaultDesignPrecacheID;
	
	static Float:fBulletOrigin[3];
	fBulletOrigin[0] = GetEventFloat(hEvent, "x");
	fBulletOrigin[1] = GetEventFloat(hEvent, "y");
	fBulletOrigin[2] = GetEventFloat(hEvent, "z");
	
	static Float:fEyePos[3];
	GetClientEyePosition(iClient, fEyePos);
	TR_TraceRayFilter(fEyePos, fBulletOrigin, MASK_ALL, RayType_EndPoint, TraceFilter_DontHitSelf, iClient);
	
	if(TR_GetEntityIndex() > 0)
		TR_GetEndPosition(fBulletOrigin);
	
	CreateTracer(iClient, fBulletOrigin, iPrecacheID, iColor);
	g_fNextTracerTime[iClient] = fCurTime + TRACER_DELAY;
}

CreateTracer(iClient, const Float:fBulletOrigin[3], iPrecacheID, iColor[4])
{
	static iOwnerFlags;
	iOwnerFlags = Store_GetClientSettings(iClient, STOREITEM_TYPE_BULLET_TRACER);
	
	static iWeapon, iViewModelMask;
	iViewModelMask = 0;
	iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	
	if(iWeapon > 0 && !(iOwnerFlags & ITYPE_FLAG_SELF_DISABLED))
	{
		if(GetEntProp(iWeapon, Prop_Send, "m_nModelIndex") == g_iWeaponModelIndex_Elite)
		{
			switch(GetEntProp(iWeapon, Prop_Data, "m_nSequence"))
			{
				case WEAPON_ELITE_LEFT_SEQUENCE: iViewModelMask = WEAPON_ELITE_LEFT_MASK;
				case WEAPON_ELITE_RIGHT_SEQUENCE: iViewModelMask = WEAPON_ELITE_RIGHT_MASK;
				default: iViewModelMask = 0x1000;
			}
		}
		else
			iViewModelMask = 0x1000;
		
		TE_SetupBeamEntPoint(iWeapon | iViewModelMask, _, _, fBulletOrigin, iPrecacheID, _, 1, 1, 0.056, 0.4, 0.01, 0, 0.0, iColor, 0);
		TE_SendToClient(iClient);
	}
	
	static iActiveWeapon;
	iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iActiveWeapon > 0)
		iWeapon = GetEntPropEnt(iActiveWeapon, Prop_Send, "m_hWeaponWorldModel");
	else
		iWeapon = 0;
	
	if(iWeapon < 1)
		iWeapon = iActiveWeapon;
	
	if(iWeapon < 1)
		return;
	
	static iWorldModelMask;
	if(GetEntProp(iWeapon, Prop_Send, "m_nModelIndex") == g_iWeaponModelIndex_Elite)
	{
		switch(GetEntProp(iWeapon, Prop_Data, "m_nSequence"))
		{
			case WEAPON_ELITE_LEFT_SEQUENCE: iWorldModelMask = WEAPON_ELITE_LEFT_MASK;
			case WEAPON_ELITE_RIGHT_SEQUENCE: iWorldModelMask = WEAPON_ELITE_RIGHT_MASK;
			default: iWorldModelMask = 0x5000;
		}
	}
	else
		iWorldModelMask = 0x5000;
	
	static iOriginalWeapon;
	iOriginalWeapon = iWeapon;
	
	static iPlayerFlags, iClientTeam;
	iClientTeam = GetClientTeam(iClient);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(iClient == iPlayer || !IsClientInGame(iPlayer) || IsFakeClient(iPlayer))
			continue;
		
		iPlayerFlags = Store_GetClientSettings(iPlayer, STOREITEM_TYPE_BULLET_TRACER);
		
		if(iClientTeam == GetClientTeam(iPlayer))
		{
			if(iPlayerFlags & ITYPE_FLAG_MY_TEAM_DISABLED)
				continue;
			
			if(iOwnerFlags & ITYPE_FLAG_MY_ITEM_MY_TEAM_DISABLED)
				continue;
		}
		else
		{
			if(iPlayerFlags & ITYPE_FLAG_OTHER_TEAM_DISABLED)
				continue;
			
			if(iOwnerFlags & ITYPE_FLAG_MY_ITEM_OTHER_TEAM_DISABLED)
				continue;
		}
		
		if(GetEntProp(iPlayer, Prop_Send, "m_iObserverMode") == SPECMODE_FIRSTPERSON
		&& iClient == GetEntPropEnt(iPlayer, Prop_Send, "m_hObserverTarget")
		&& (iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel")) > 0)
		{
			iWeapon |= iViewModelMask;
		}
		else
		{
			iWeapon = iOriginalWeapon | iWorldModelMask;
		}
		
		TE_SetupBeamEntPoint(iWeapon, _, _, fBulletOrigin, iPrecacheID, _, 1, 1, 0.056, 0.4, 0.01, 0, 0.0, iColor, 0);
		TE_SendToClient(iPlayer);
	}
}

TE_SetupBeamEntPoint(iStartEnt=0, iEndEnt=0, const Float:fStartPoint[3]=NULL_VECTOR, const Float:fEndPoint[3]=NULL_VECTOR, iModelIndex, iHaloIndex=0, iStartFrame, iFramerate, Float:fLife, Float:fWidth, Float:fEndWidth, iFadeLength, Float:fAmplitude, iColor[4], iSpeed)
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
	TE_WriteVector("m_vecStartPoint", fStartPoint);
	TE_WriteVector("m_vecEndPoint", fEndPoint);
}

public bool:TraceFilter_DontHitSelf(iEnt, iContentsMask, any:iClient)
{
	if(iEnt == iClient)
		return false;
	
	return true;
}

GetRandomItemID(iClient)
{
	decl iItemID;
	new Handle:hOwned = CreateArray();
	for(new i=0; i<GetArraySize(g_aItems); i++)
	{
		iItemID = GetArrayCell(g_aItems, i);
		if(!Store_CanClientUseItem(iClient, iItemID))
			continue;
		
		PushArrayCell(hOwned, iItemID);
	}
	
	if(GetArraySize(hOwned) < 1)
	{
		CloseHandle(hOwned);
		return 0;
	}
	
	iItemID = GetArrayCell(hOwned, GetRandomInt(0, GetArraySize(hOwned)-1));
	CloseHandle(hOwned);
	
	return iItemID;
}