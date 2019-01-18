#include <sourcemod>
#include "../../Libraries/ClientCookies/client_cookies"
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#include <hls_color_chat>

#undef REQUIRE_PLUGIN
#include "../../RandomIncludes/kztimer"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Gloves";
new const String:PLUGIN_VERSION[] = "1.3";

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

new g_iStartIndex_Type;
new g_iStartIndex_Paint;

new g_iGloveIndex_Type[MAXPLAYERS+1];
new g_iGloveIndex_Paint[MAXPLAYERS+1];

new Handle:g_hFwd_OnApply;

new bool:g_bLibLoaded_KZTimer;


public OnPluginStart()
{
	CreateConVar("gloves_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnApply = CreateGlobalForward("Gloves_OnApply", ET_Hook, Param_Cell);
	
	RegConsoleCmd("sm_glove", OnGlovesSelect, "Opens the glove selection menu.");
	RegConsoleCmd("sm_gloves", OnGlovesSelect, "Opens the glove selection menu.");
	
	BuildArray_Types();
	BuildArray_Paints();
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("unsafe_gloves");
	return APLRes_Success;
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_KZTimer = LibraryExists("KZTimer");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "KZTimer"))
	{
		g_bLibLoaded_KZTimer = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "KZTimer"))
	{
		g_bLibLoaded_KZTimer = false;
	}
}

BuildArray_Types()
{
	if(g_aTypes == INVALID_HANDLE)
		g_aTypes = CreateArray(Type);
	else
		ClearArray(g_aTypes);
	
	AddType("Default", 0);
	AddType("Random", 0);
	
	// NOTE: Add new types to end of list.
	g_iStartIndex_Type = GetArraySize(g_aTypes);
	AddType("Bloodhound Gloves", 5027);
	AddType("Sport Gloves", 5030);
	AddType("Driver Gloves", 5031);
	AddType("Hand Wraps", 5032);
	AddType("Moto Gloves", 5033);
	AddType("Specialist Gloves", 5034);
	AddType("Hydra Gloves", 5035);
	
	SortTypeArrayByName(g_aTypes, g_iStartIndex_Type);
}

BuildArray_Paints()
{
	if(g_aPaints == INVALID_HANDLE)
		g_aPaints = CreateArray(Type);
	else
		ClearArray(g_aPaints);
	
	AddPaint("Random", 0);
	
	// NOTE: Add new paints to end of list.
	g_iStartIndex_Paint = GetArraySize(g_aPaints);
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
	AddPaint("King Snake", 10041);
	AddPaint("Imperial Plaid", 10042);
	AddPaint("Overtake", 10043);
	AddPaint("Racing Green", 10044);
	AddPaint("Amphibious", 10045);
	AddPaint("Bronze Morph", 10046);
	AddPaint("Omega", 10047);
	AddPaint("Vice", 10048);
	AddPaint("POW!", 10049);
	AddPaint("Turtle", 10050);
	AddPaint("Transport", 10051);
	AddPaint("Polygon", 10052);
	AddPaint("Cobalt Skulls", 10053);
	AddPaint("Overprint", 10054);
	AddPaint("Duct Tape", 10055);
	AddPaint("Arboreal", 10056);
	AddPaint("Emerald", 10057);
	AddPaint("Mangrove", 10058);
	AddPaint("Rattler", 10059);
	AddPaint("Case Hardened", 10060);
	AddPaint("Crimson Web", 10061);
	AddPaint("Buckshot", 10062);
	AddPaint("Fade", 10063);
	AddPaint("Mogul", 10064);
	
	SortTypeArrayByName(g_aPaints, g_iStartIndex_Paint);
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

SortTypeArrayByName(Handle:hArray, iStartIndex)
{
	new iArraySize = GetArraySize(hArray);
	decl String:szName[MAX_TYPE_PAINT_NAME_LEN], eType[Type], j, iIndex;
	
	for(new i=iStartIndex; i<iArraySize; i++)
	{
		GetArrayArray(hArray, i, eType);
		strcopy(szName, sizeof(szName), eType[TYPE_NAME]);
		iIndex = 0;
		
		for(j=i+1; j<iArraySize; j++)
		{
			GetArrayArray(hArray, j, eType);
			if(strcmp(szName, eType[TYPE_NAME], false) < 0)
				continue;
			
			iIndex = j;
			strcopy(szName, sizeof(szName), eType[TYPE_NAME]);
		}
		
		if(!iIndex)
			continue;
		
		SwapArrayItems(hArray, i, iIndex);
	}
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
		
		if(g_iGloveIndex_Type[iClient] > 0 && g_iGloveIndex_Type[iClient] < g_iStartIndex_Type)
			g_iGloveIndex_Type[iClient] = -1;
	}
	
	if(ClientCookies_HasCookie(iClient, CC_TYPE_SPOOFED_SKINS_GLOVES_PAINT))
	{
		g_iGloveIndex_Paint[iClient] = ClientCookies_GetCookie(iClient, CC_TYPE_SPOOFED_SKINS_GLOVES_PAINT);
		
		if(g_iGloveIndex_Paint[iClient] != -1 && g_iGloveIndex_Paint[iClient] < g_iStartIndex_Paint)
			g_iGloveIndex_Paint[iClient] = -1;
	}
}

public MSManager_OnSpawnPost_Post(iClient)
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

CloseKZTimerMenu(iClient)
{
	if(g_bLibLoaded_KZTimer)
	{
		#if defined _KZTimer_included
		KZTimer_StopUpdatingOfClimbersMenu(iClient);
		#endif
	}
}

DisplayMenu_CategorySelect(iClient)
{
	CloseKZTimerMenu(iClient);
	
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
	CloseKZTimerMenu(iClient);
	
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
	CloseKZTimerMenu(iClient);
	
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
	
	if(fCurTime < fLastUse[iClient] + 0.5)
	{
		CPrintToChat(iClient, "{red}Please wait a second before using the menu again.");
		return false;
	}
	
	fLastUse[iClient] = fCurTime;
	
	return true;
}

bool:Forward_OnApply(iClient)
{
	decl Action:result;
	Call_StartForward(g_hFwd_OnApply);
	Call_PushCell(iClient);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		return false;
	
	return true;
}

bool:ApplyGloves(iClient, bool:bShowMessage=true)
{
	if(!Forward_OnApply(iClient))
	{
		if(bShowMessage)
			CPrintToChat(iClient, "{red}Could not apply gloves right now.");
		
		return false;
	}
	
	new iTypeIndex = g_iGloveIndex_Type[iClient];
	new iPaintIndex = g_iGloveIndex_Paint[iClient];
	
	if(iTypeIndex < g_iStartIndex_Type)
	{
		new iArraySize = GetArraySize(g_aTypes);
		if(iArraySize <= g_iStartIndex_Type)
		{
			if(bShowMessage)
				CPrintToChat(iClient, "{red}Error: There are no glove types.");
			
			LogError("There are no glove types.");
			return false;
		}
		
		iTypeIndex = GetRandomInt(g_iStartIndex_Type, iArraySize-1);
	}
	
	if(iPaintIndex < g_iStartIndex_Paint)
	{
		new iArraySize = GetArraySize(g_aPaints);
		if(iArraySize <= g_iStartIndex_Paint)
		{
			if(bShowMessage)
				CPrintToChat(iClient, "{red}Error: There are no glove paints.");
			
			LogError("There are no glove paints.");
			return false;
		}
		
		iPaintIndex = GetRandomInt(g_iStartIndex_Paint, iArraySize-1);
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