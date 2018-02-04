#include <sourcemod>
#include <sdktools_sound>
#include <emitsoundany>
#include "../../../Libraries/Store/store"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Grenade Sounds";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to add custom sounds to their grenades.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new const GRENADE_SOUND_ITEM_TYPES[] =
{
	STOREITEM_TYPE_GRENADESOUND_BOUNCE,
	STOREITEM_TYPE_GRENADESOUND_EXPLODE
};

enum GrenadeSoundType
{
	GrenadeSoundType_Bounce,
	GrenadeSoundType_Explode
};

new Handle:g_aItems[GrenadeSoundType];


public OnPluginStart()
{
	CreateConVar("store_item_grenade_sounds_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	for(new i=0; i<sizeof(g_aItems); i++)
		g_aItems[i] = CreateArray();
	
	AddNormalSoundHook(OnNormalSound);
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_aItems); i++)
		ClearArray(g_aItems[i]);
}

public Store_OnItemsReady()
{
	decl iIndex, iFoundItemID;
	for(new i=0; i<sizeof(g_aItems); i++)
	{
		iIndex = -1;
		while((iIndex = Store_FindItemByType(iIndex, GRENADE_SOUND_ITEM_TYPES[i], iFoundItemID)) != -1)
		{
			PushArrayCell(g_aItems[i], iFoundItemID);
		}
	}
}

bool:IsGrenadeSound_Bounce(const String:szSample[], iChannel, iLevel, iPitch)
{
	if(iLevel != 75)
		return false;
	
	if(iChannel != 0 && iChannel != 3 && iChannel != 6)
		return false;
	
	if(iPitch < 95 || iPitch > 100)
		return false;
	
	if(!StrEqual(szSample, "~)weapons/hegrenade/he_bounce-1.wav")
	&& !StrEqual(szSample, ")weapons/flashbang/grenade_hit1.wav")
	&& !StrEqual(szSample, "~)weapons/smokegrenade/grenade_hit1.wav")
	&& !StrEqual(szSample, ")weapons/incgrenade/inc_grenade_bounce-1.wav")
	&& !StrEqual(szSample, "physics/glass/glass_bottle_impact_hard1.wav")
	&& !StrEqual(szSample, "physics/glass/glass_bottle_impact_hard2.wav")
	&& !StrEqual(szSample, "physics/glass/glass_bottle_impact_hard3.wav"))
		return false;
	
	return true;
}

bool:IsGrenadeSound_Explode(const String:szSample[], iChannel, iLevel, iPitch)
{
	if(iChannel != 6)
		return false;
	
	if(iPitch != 100)
		return false;
	
	if(iLevel != 140 && iLevel != 85)
		return false;
	
	if(!StrEqual(szSample, "~)weapons/hegrenade/explode3.wav")
	&& !StrEqual(szSample, "~)weapons/hegrenade/explode4.wav")
	&& !StrEqual(szSample, "~)weapons/hegrenade/explode5.wav")
	&& !StrEqual(szSample, ")weapons/flashbang/flashbang_explode1.wav")
	&& !StrEqual(szSample, ")weapons/flashbang/flashbang_explode2.wav")
	&& !StrEqual(szSample, "~)weapons/smokegrenade/smoke_emit.wav"))
		return false;
	
	return true;
}

public Action:OnNormalSound(iClients[64], &iNumClients, String:szSample[PLATFORM_MAX_PATH], &iEntity, &iChannel, &Float:fVolume, &iLevel, &iPitch, &iFlags)
{
	if(!IsValidEntity(iEntity))
		return Plugin_Continue;
	
	new iItemID;
	static String:szSoundPath[PLATFORM_MAX_PATH], iOwner;
	
	if(IsGrenadeSound_Bounce(szSample, iChannel, iLevel, iPitch))
	{
		iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		if(!(1 <= iOwner <= MaxClients))
			return Plugin_Continue;
		
		iItemID = GetRandomGrenadeSoundID(iOwner, _:GrenadeSoundType_Bounce);
		
		// Let players hear the bounce sound a bit further away.
		if(iItemID > 0)
			iLevel += 25;
	}
	
	if(iItemID < 1 && IsGrenadeSound_Explode(szSample, iChannel, iLevel, iPitch))
	{
		iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		if(!(1 <= iOwner <= MaxClients))
			return Plugin_Continue;
		
		iItemID = GetRandomGrenadeSoundID(iOwner, _:GrenadeSoundType_Explode);
	}
	
	if(iItemID < 1)
		return Plugin_Continue;
	
	if(!Store_GetItemsMainFilePath(iItemID, szSoundPath, sizeof(szSoundPath)))
		return Plugin_Continue;
	
	EmitSoundAny(iClients, iNumClients, szSoundPath[6], iEntity, SNDCHAN_BODY, iLevel);
	
	return Plugin_Handled;
}

GetRandomGrenadeSoundID(iClient, iIndex)
{
	decl iItemID;
	new Handle:hOwned = CreateArray();
	for(new i=0; i<GetArraySize(g_aItems[iIndex]); i++)
	{
		iItemID = GetArrayCell(g_aItems[iIndex], i);
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