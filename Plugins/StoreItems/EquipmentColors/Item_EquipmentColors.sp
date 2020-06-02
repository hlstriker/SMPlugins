#include <sourcemod>
#include "../Equipment/item_equipment"
#include "../../../Libraries/Store/store"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Store Item: Equipment Colors";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to add colors to their equipment.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aItems;


public OnPluginStart()
{
	CreateConVar("store_item_equipment_colors_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_aItems = CreateArray();
}

public OnMapStart()
{
	ClearArray(g_aItems);
}

public Store_OnItemsReady()
{
	new iIndex = -1;
	decl iFoundItemID;
	while((iIndex = Store_FindItemByType(iIndex, STOREITEM_TYPE_EQUIPMENT_COLORS, iFoundItemID)) != -1)
	{
		PushArrayCell(g_aItems, iFoundItemID);
	}
}

public ItemEquipment_OnEquipped(iClient, iEquipment)
{
	new iItemID = GetRandomItemID(iClient);
	if(iItemID < 1)
		return;
	
	SetEquipmentColor(iEquipment, iItemID);
}

SetEquipmentColor(iEnt, iItemID)
{
	static String:szColor[MAX_STORE_DATA_STRING_LEN];
	if(!Store_GetItemsDataString(iItemID, 1, szColor, sizeof(szColor)))
		return;
	
	static String:szExplode[4][4];
	ExplodeString(szColor, " ", szExplode, sizeof(szExplode), sizeof(szExplode[]));
	
	static iColor[4];
	iColor[0] = StringToInt(szExplode[0]);
	iColor[1] = StringToInt(szExplode[1]);
	iColor[2] = StringToInt(szExplode[2]);
	iColor[3] = GetRandomInt(230, 255);
	
	SetEntityRenderColor(iEnt, iColor[0], iColor[1], iColor[2], iColor[3]);
	SetEntityRenderMode(iEnt, RENDER_TRANSCOLOR);
	SetEntityRenderFx(iEnt, RENDERFX_NONE);
}

stock SetDefaultColor(iEnt)
{
	SetEntityRenderColor(iEnt, 255, 255, 255, 255);
	SetEntityRenderMode(iEnt, RENDER_NORMAL);
	SetEntityRenderFx(iEnt, RENDERFX_NONE);
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