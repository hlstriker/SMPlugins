#include <sourcemod>
#include "../../Libraries/ClientCookies/client_cookies"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Gloves";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows players to select gloves.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_TYPE_PAINT_NAME_LEN	64

enum
{
	CATEGORY_TYPE,
	CATEGORY_PAINT
};

new Handle:g_aTypes;
new Handle:g_aPaints;
enum _:Type
{
	TYPE_INDEX,
	String:TYPE_NAME[MAX_TYPE_PAINT_NAME_LEN]
};

new g_iGloveIndex_Type[MAXPLAYERS+1];
new g_iGloveIndex_Paint[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("gloves_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_gloves", OnGlovesSelect, "Opens the glove selection menu.");
	
	g_aTypes = CreateArray(Type);
	BuildArray_Types();
	
	g_aPaints = CreateArray(Type);
	BuildArray_Paints();
}

#define TYPE_START_INDEX 2
BuildArray_Types()
{
	AddType("Default", 0);
	AddType("Random", 0);
	
	// NOTE: Add new types to end of list.
	AddType("Bloodhound Gloves", 5027);
	AddType("Sport Gloves", 5030);
	AddType("Driver Gloves", 5031);
	AddType("Hand Wraps", 5032);
	AddType("Moto Gloves", 5033);
	AddType("Specialist Gloves", 5034);
}

#define PAINT_START_INDEX 1
BuildArray_Paints()
{
	AddPaint("Random", 0);
	
	// NOTE: Add new paints to end of list.
	AddPaint("Charred", 10006);
	AddPaint("Snakebite", 10007);
	AddPaint("Bronzed", 10008);
	AddPaint("Guerrilla", 10039);
	AddPaint("Superconductor", 10018);
	AddPaint("Arid", 10019);
	AddPaint("Pandora's Box", 10037);
	AddPaint("Hedge Maze", 10038);
	AddPaint("Lunar Weave", 10013);
	AddPaint("Convoy", 10015);
	AddPaint("Crimson Weave", 10016);
	AddPaint("Diamondback", 10040);
	AddPaint("Leather", 10009);
	AddPaint("Spruce DDPAT", 10010);
	AddPaint("Slaughter", 10021);
	AddPaint("Badlands", 10036);
	AddPaint("Eclipse", 10024);
	AddPaint("Spearmint", 10026);
	AddPaint("Boom!", 10027);
	AddPaint("Cool Mint", 10028);
	AddPaint("Forest DDPAT", 10030);
	AddPaint("Crimson Kimono", 10033);
	AddPaint("Emerald Web", 10034);
	AddPaint("Foundation", 10035);
}

AddType(const String:szName[], iIndex)
{
	decl eType[Type];
	eType[TYPE_INDEX] = iIndex;
	strcopy(eType[TYPE_NAME], MAX_TYPE_PAINT_NAME_LEN, szName);
	
	PushArrayArray(g_aTypes, eType);
}

AddPaint(const String:szName[], iIndex)
{
	decl ePaint[Type];
	ePaint[TYPE_INDEX] = iIndex;
	strcopy(ePaint[TYPE_NAME], MAX_TYPE_PAINT_NAME_LEN, szName);
	
	PushArrayArray(g_aPaints, ePaint);
}

public OnClientConnected(iClient)
{
	g_iGloveIndex_Type[iClient] = -1;
	g_iGloveIndex_Paint[iClient] = -1;
}

public ClientCookies_OnCookiesLoaded(iClient)
{
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SPOOFED_SKINS_GLOVES_TYPE))
	{
		g_iGloveIndex_Type[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_SPOOFED_SKINS_GLOVES_TYPE);
		
		if(g_iGloveIndex_Type[iClient] > 0 && g_iGloveIndex_Type[iClient] < TYPE_START_INDEX)
			g_iGloveIndex_Type[iClient] = -1;
	}
	
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SPOOFED_SKINS_GLOVES_PAINT))
	{
		g_iGloveIndex_Paint[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_SPOOFED_SKINS_GLOVES_PAINT);
		
		if(g_iGloveIndex_Paint[iClient] != -1 && g_iGloveIndex_Paint[iClient] < PAINT_START_INDEX)
			g_iGloveIndex_Paint[iClient] = -1;
	}
}

public MSManager_OnSpawnPost(iClient)
{
	if(!g_iGloveIndex_Type[iClient])
		return;
	
	ApplyGloves(iClient, false);
}

public Action:OnGlovesSelect(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	DisplayMenu_CategorySelect(iClient);
	return Plugin_Handled;
}

DisplayMenu_CategorySelect(iClient)
{
	if(!ClientCookies_HaveCookiesLoaded(iClient))
	{
		CPrintToChat(iClient, "{red}Unavailable, try again in a few seconds.");
		return;
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_CategorySelect);
	SetMenuTitle(hMenu, "Select a category");
	
	decl String:szInfo[2];
	IntToString(CATEGORY_TYPE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Glove Type");
	
	IntToString(CATEGORY_PAINT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Glove Skin");
	
	if(!DisplayMenu(hMenu, iClient, 0))
		CPrintToChat(iClient, "{red}There are no categories.");
}

public MenuHandle_CategorySelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[2];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case CATEGORY_TYPE: DisplayMenu_TypeSelect(iParam1);
		case CATEGORY_PAINT: DisplayMenu_PaintSelect(iParam1);
	}
}

DisplayMenu_TypeSelect(iClient, iStartPos=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_TypeSelect);
	SetMenuTitle(hMenu, "Select a glove type");
	
	new iArraySize = GetArraySize(g_aTypes);
	
	decl String:szInfo[12], eType[Type];
	for(new i=0; i<iArraySize; i++)
	{
		if(!GetArrayArray(g_aTypes, i, eType))
			continue;
		
		FormatEx(szInfo, sizeof(szInfo), "%i", i);
		AddMenuItem(hMenu, szInfo, eType[TYPE_NAME]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartPos, 0))
	{
		CPrintToChat(iClient, "{red}There is nothing in this category.");
		DisplayMenu_CategorySelect(iClient);
		return;
	}
}

public MenuHandle_TypeSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_CategorySelect(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!CheckMenuSpam(iParam1))
	{
		DisplayMenu_TypeSelect(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iIndex = StringToInt(szInfo);
	
	// Is random index?
	if(iIndex == 1)
		iIndex = -1;
	
	if(iIndex == 0)
	{
		g_iGloveIndex_Type[iParam1] = 0;
		
		if(!MSManager_HasWearableGloves(iParam1))
		{
			CPrintToChat(iParam1, "{olive}You are already using default gloves.");
		}
		else
		{
			CPrintToChat(iParam1, "{lightred}You will use default gloves next time you spawn.");
		}
	}
	else
	{
		g_iGloveIndex_Type[iParam1] = iIndex;
		
		if(MSManager_HasWearableGloves(iParam1))
		{
			ApplyGloves(iParam1);
		}
		else
		{
			CPrintToChat(iParam1, "{lightred}Your gloves will be applied next time you spawn.");
		}
	}
	
	ClientCookies_SetCookie(iParam1, CC_TYPE_SPOOFED_SKINS_GLOVES_TYPE, g_iGloveIndex_Type[iParam1]);
	DisplayMenu_TypeSelect(iParam1, GetMenuSelectionPosition());
}

DisplayMenu_PaintSelect(iClient, iStartPos=0)
{
	new Handle:hMenu = CreateMenu(MenuHandle_PaintSelect);
	SetMenuTitle(hMenu, "Select a glove skin");
	
	new iArraySize = GetArraySize(g_aPaints);
	
	decl String:szInfo[12], eType[Type];
	for(new i=0; i<iArraySize; i++)
	{
		if(!GetArrayArray(g_aPaints, i, eType))
			continue;
		
		FormatEx(szInfo, sizeof(szInfo), "%i", i);
		AddMenuItem(hMenu, szInfo, eType[TYPE_NAME]);
	}
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenuAtItem(hMenu, iClient, iStartPos, 0))
	{
		CPrintToChat(iClient, "{red}There is nothing in this category.");
		DisplayMenu_CategorySelect(iClient);
		return;
	}
}

public MenuHandle_PaintSelect(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_CategorySelect(iParam1);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	if(!CheckMenuSpam(iParam1))
	{
		DisplayMenu_PaintSelect(iParam1, GetMenuSelectionPosition());
		return;
	}
	
	decl String:szInfo[12];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	new iIndex = StringToInt(szInfo);
	
	// Is random index?
	if(iIndex == 0)
		iIndex = -1;
	
	g_iGloveIndex_Paint[iParam1] = iIndex;
	
	if(MSManager_HasWearableGloves(iParam1))
	{
		ApplyGloves(iParam1);
	}
	else
	{
		g_iGloveIndex_Type[iParam1] = -1;
		CPrintToChat(iParam1, "{lightred}Your gloves will be applied next time you spawn.");
	}
	
	ClientCookies_SetCookie(iParam1, CC_TYPE_SPOOFED_SKINS_GLOVES_PAINT, g_iGloveIndex_Paint[iParam1]);
	DisplayMenu_PaintSelect(iParam1, GetMenuSelectionPosition());
}

bool:CheckMenuSpam(iClient)
{
	static Float:fLastUse[MAXPLAYERS+1], Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < fLastUse[iClient] + 2.0)
	{
		CPrintToChat(iClient, "{red}Please wait a few seconds before using the menu again.");
		return false;
	}
	
	fLastUse[iClient] = fCurTime;
	
	return true;
}

bool:ApplyGloves(iClient, bool:bShowMessage=true)
{
	new iTypeIndex = g_iGloveIndex_Type[iClient];
	new iPaintIndex = g_iGloveIndex_Paint[iClient];
	
	if(iTypeIndex < TYPE_START_INDEX)
	{
		new iArraySize = GetArraySize(g_aTypes);
		if(iArraySize <= TYPE_START_INDEX)
		{
			if(bShowMessage)
				CPrintToChat(iClient, "{red}Error: There are no glove types.");
			
			LogError("There are no glove types.");
			return false;
		}
		
		iTypeIndex = GetRandomInt(TYPE_START_INDEX, iArraySize-1);
	}
	
	if(iPaintIndex < PAINT_START_INDEX)
	{
		new iArraySize = GetArraySize(g_aPaints);
		if(iArraySize <= PAINT_START_INDEX)
		{
			if(bShowMessage)
				CPrintToChat(iClient, "{red}Error: There are no glove paints.");
			
			LogError("There are no glove paints.");
			return false;
		}
		
		iPaintIndex = GetRandomInt(PAINT_START_INDEX, iArraySize-1);
	}
	
	decl eType[Type], ePaint[Type];
	GetArrayArray(g_aTypes, iTypeIndex, eType);
	GetArrayArray(g_aPaints, iPaintIndex, ePaint);
	
	MSManager_DeleteWearableItem(iClient, WEARABLE_INDEX_GLOVES);
	if(!MSManager_CreateWearableItem(iClient, WEARABLE_INDEX_GLOVES, eType[TYPE_INDEX], ePaint[TYPE_INDEX]))
	{
		if(bShowMessage)
			CPrintToChat(iClient, "{red}Your gloves will be applied next time you spawn.");
		
		return false;
	}
	
	if(bShowMessage)
		CPrintToChat(iClient, "{olive}Using gloves: {yellow}%s - %s", eType[TYPE_NAME], ePaint[TYPE_NAME]);
	
	return true;
}