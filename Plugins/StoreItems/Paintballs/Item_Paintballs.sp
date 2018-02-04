#include <sourcemod>
#include <sdktools_engine>
#include <sdktools_tempents>
#include <sdktools_trace>
#include "../../../Libraries/Store/store"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Paintballs";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to shoot paintballs.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Float:g_fNextPaintTime_Entity[MAXPLAYERS+1];
new Float:g_fNextPaintTime_World[MAXPLAYERS+1];
const Float:PAINT_DELAY = 0.02;

new Handle:g_aItems;

new Handle:g_hFwd_OnShootPaintball;


public OnPluginStart()
{
	CreateConVar("store_item_paintballs_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnShootPaintball = CreateGlobalForward("ItemPaintballs_OnShootPaintball", ET_Hook, Param_Cell);
	
	g_aItems = CreateArray();
	HookEvent("bullet_impact", Event_BulletImpact_Post, EventHookMode_Post);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("item_paintballs");
	return APLRes_Success;
}

public OnMapStart()
{
	ClearArray(g_aItems);
}

public Store_OnItemsReady()
{
	new iIndex = -1;
	decl iFoundItemID;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_PAINTBALL, iFoundItemID)) != -1)
	{
		PushArrayCell(g_aItems, iFoundItemID);
	}
}

bool:Forward_OnShootPaintball(iClient)
{
	new Action:result;
	Call_StartForward(g_hFwd_OnShootPaintball);
	Call_PushCell(iClient);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return false;
	
	return true;
}

public Event_BulletImpact_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	static iClient;
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsFakeClient(iClient))
		return;
	
	new iItemID = GetRandomItemID(iClient);
	if(iItemID < 1)
		return;
	
	new iPrecacheID = Store_GetItemsMainFilePrecacheID(iItemID);
	if(!iPrecacheID)
		return;
	
	if(!Forward_OnShootPaintball(iClient))
		return;
	
	static Float:fBulletOrigin[3];
	fBulletOrigin[0] = GetEventFloat(hEvent, "x");
	fBulletOrigin[1] = GetEventFloat(hEvent, "y");
	fBulletOrigin[2] = GetEventFloat(hEvent, "z");
	
	static Float:fEyePos[3];
	GetClientEyePosition(iClient, fEyePos);
	TR_TraceRayFilter(fEyePos, fBulletOrigin, MASK_ALL, RayType_EndPoint, TraceFilter_DontHitSelf, iClient);
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	// Draw paintball on entity.
	new iHit = TR_GetEntityIndex();
	if(iHit > 0 && fCurTime >= g_fNextPaintTime_Entity[iClient])
	{
		TR_GetEndPosition(fBulletOrigin);
		
		TE_Start("Entity Decal");
		TE_WriteVector("m_vecOrigin", fBulletOrigin);
		TE_WriteVector("m_vecStart", fEyePos);
		TE_WriteNum("m_nEntity", iHit);
		TE_WriteNum("m_nHitbox", TR_GetHitGroup());
		TE_WriteNum("m_nIndex", iPrecacheID);
		
		// Only send non-player entity hits to owner because the Entity Decal uses a lot of bandwidth.
		if(1 <= iHit <= MaxClients)
			TE_SendToAll();
		else
			TE_SendToClient(iClient);
		
		g_fNextPaintTime_Entity[iClient] = fCurTime + PAINT_DELAY;
		return;
	}
	
	// Draw paintball on world.
	if(iHit < 1 && fCurTime >= g_fNextPaintTime_World[iClient] && fCurTime >= g_fNextPaintTime_Entity[iClient])
	{
		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin", fBulletOrigin);
		TE_WriteNum("m_nIndex", iPrecacheID);
		TE_SendToAll();
		
		g_fNextPaintTime_World[iClient] = fCurTime + PAINT_DELAY;
	}
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