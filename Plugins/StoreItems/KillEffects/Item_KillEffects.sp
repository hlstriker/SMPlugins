#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_entinput>
#include "../../../Libraries/Store/store"
#include "../../../Libraries/ParticleManager/particle_manager"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Kill Effects";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to have kill effects.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

// WARNING: Never change the order of this enum, if adding more then put them at the end of the list.
enum
{
	KILL_EFFECT_TYPE_PARTICLE = 1,
	KILL_EFFECT_TYPE_PARTICLE_FOLLOW_RAGDOLL,
	KILL_EFFECT_TYPE_FIRE,
	KILL_EFFECT_TYPE_FORCE
};

new Handle:g_aItems;


public OnPluginStart()
{
	CreateConVar("store_item_kill_effects_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aItems = CreateArray();
	HookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
}

public OnMapStart()
{
	ClearArray(g_aItems);
}

public Store_OnItemsReady()
{
	decl iFoundItemID, String:szEffect[MAX_STORE_DATA_STRING_LEN+1];
	
	new iIndex = -1;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_KILL_EFFECTS, iFoundItemID)) != -1)
	{
		if(!Store_GetItemsDataString(iFoundItemID, 2, szEffect, sizeof(szEffect)))
			continue;
		
		PushArrayCell(g_aItems, iFoundItemID);
		PM_PrecacheParticleEffect(_, szEffect);
	}
}

public Event_PlayerDeath_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if(!(1 <= iAttacker <= MaxClients))
		return;
	
	if(IsFakeClient(iAttacker))
		return;
	
	new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	new iRagDoll = GetEntPropEnt(iVictim, Prop_Send, "m_hRagdoll");
	
	if(iRagDoll < 1)
		return;
	
	new iItemID = GetRandomItemID(iAttacker);
	if(iItemID < 1)
		return;
	
	static String:szEffectType[6];
	if(!Store_GetItemsDataString(iItemID, 1, szEffectType, sizeof(szEffectType)))
		return;
	
	new iEffectType = StringToInt(szEffectType);
	if(iEffectType < 1)
		return;
	
	switch(iEffectType)
	{
		case KILL_EFFECT_TYPE_PARTICLE:
		{
			if(KillEffect_Particle(iVictim, iItemID))
				AcceptEntityInput(iRagDoll, "Kill");
		}
		case KILL_EFFECT_TYPE_PARTICLE_FOLLOW_RAGDOLL:
		{
			if(DoesOwnEffect(iAttacker, KILL_EFFECT_TYPE_FORCE))
				KillEffect_Force(iRagDoll);
			
			KillEffect_Particle(iVictim, iItemID, iRagDoll);
		}
		case KILL_EFFECT_TYPE_FIRE:
		{
			KillEffect_Fire(iRagDoll);
			if(DoesOwnEffect(iAttacker, KILL_EFFECT_TYPE_FORCE))
				KillEffect_Force(iRagDoll);
		}
		case KILL_EFFECT_TYPE_FORCE:
		{
			KillEffect_Force(iRagDoll);
			
			new bool:bOwnsFire = bool:DoesOwnEffect(iAttacker, KILL_EFFECT_TYPE_FIRE);
			new iOwnsParticleEffect = DoesOwnEffect(iAttacker, KILL_EFFECT_TYPE_PARTICLE_FOLLOW_RAGDOLL);
			
			if(bOwnsFire && iOwnsParticleEffect)
			{
				if(GetRandomInt(0, 1))
					KillEffect_Fire(iRagDoll);
				else
					KillEffect_Particle(iVictim, iOwnsParticleEffect, iRagDoll);
			}
			else if(bOwnsFire)
			{
				KillEffect_Fire(iRagDoll);
			}
			else if(iOwnsParticleEffect)
			{
				KillEffect_Particle(iVictim, iOwnsParticleEffect, iRagDoll);
			}
		}
	}
}

bool:KillEffect_Particle(iClient, iItemID, iRagDoll=0)
{
	static String:szEffect[MAX_STORE_DATA_STRING_LEN+1];
	if(!Store_GetItemsDataString(iItemID, 2, szEffect, sizeof(szEffect)))
		return false;
	
	new iNumClients;
	static iClients[MAXPLAYERS];
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		iClients[iNumClients++] = iPlayer;
	}
	
	if(iRagDoll)
	{
		PM_CreateEntityEffectFollow(iRagDoll, szEffect, _, _, iClients, iNumClients);
	}
	else
	{
		static String:szControlPoint[MAX_STORE_DATA_STRING_LEN+1];
		if(!Store_GetItemsDataString(iItemID, 3, szControlPoint, sizeof(szControlPoint)))
			return false;
		
		static String:szExplode[3][14];
		new iNumExplodes = ExplodeString(szControlPoint, " ", szExplode, sizeof(szExplode), sizeof(szExplode[]));
		
		decl Float:fControlPoint[3];
		if(iNumExplodes != 3)
		{
			fControlPoint[0] = 0.0;
			fControlPoint[1] = 0.0;
			fControlPoint[2] = 0.0;
		}
		else
		{
			fControlPoint[0] = StringToFloat(szExplode[0]);
			fControlPoint[1] = StringToFloat(szExplode[1]);
			fControlPoint[2] = StringToFloat(szExplode[2]);
			
			if(fControlPoint[0] == -1.0 && fControlPoint[1] == -1.0 && fControlPoint[2] == -1.0)
			{
				// Randomize 0-255.
				fControlPoint[0] = GetRandomFloat(1.0, 255.0);
				fControlPoint[1] = GetRandomFloat(1.0, 255.0);
				fControlPoint[2] = GetRandomFloat(1.0, 255.0);
			}
		}
		
		decl Float:fOrigin[3], Float:fMaxs[3];
		GetClientAbsOrigin(iClient, fOrigin);
		GetClientMaxs(iClient, fMaxs);
		fOrigin[2] += (fMaxs[2] - (fMaxs[2] / 3.0));
		
		PM_CreateEntityEffectCustomOrigin(0, szEffect, fOrigin, Float:{0.0, 0.0, 0.0}, fControlPoint, _, iClients, iNumClients);
	}
	
	return true;
}

KillEffect_Fire(iRagDoll)
{
	IgniteEntity(iRagDoll, 1.1);
}

KillEffect_Force(iRagDoll)
{
	decl Float:fVector[3];
	GetEntPropVector(iRagDoll, Prop_Send, "m_vecRagdollVelocity", fVector);
	fVector[0] *= 40.0;
	fVector[1] *= 40.0;
	fVector[2] *= 85.0;
	SetEntPropVector(iRagDoll, Prop_Send, "m_vecRagdollVelocity", fVector);
	
	GetEntPropVector(iRagDoll, Prop_Send, "m_vecForce", fVector);
	fVector[0] *= 40.0;
	fVector[1] *= 40.0;
	fVector[2] *= 85.0;
	SetEntPropVector(iRagDoll, Prop_Send, "m_vecForce", fVector);
}

DoesOwnEffect(iClient, iEffectType)
{
	static String:szEffectType[6], iItemID;
	
	new Handle:hOwned = CreateArray();
	for(new i=0; i<GetArraySize(g_aItems); i++)
	{
		iItemID = GetArrayCell(g_aItems, i);
		if(!Store_CanClientUseItem(iClient, iItemID))
			continue;
		
		if(!Store_GetItemsDataString(iItemID, 1, szEffectType, sizeof(szEffectType)))
			continue;
		
		if(StringToInt(szEffectType) != iEffectType)
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