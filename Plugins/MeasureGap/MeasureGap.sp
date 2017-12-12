#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Measure Gap";
new const String:PLUGIN_VERSION[] = "1.3";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Measures the distance between 2 points via a menu",
	version = PLUGIN_VERSION,
	url = ""
}

// Everything that blocks player movement
#define	MASK_PLAYERSOLID		(CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_PLAYERCLIP|CONTENTS_WINDOW|CONTENTS_MONSTER|CONTENTS_GRATE)

enum
{
	LOCATION_1 = 0,
	LOCATION_2,
	NUM_LOCATIONS
};

// Player measure locations
new Float:g_fMeasureLocation[MAXPLAYERS + 1][NUM_LOCATIONS][3];

// Player measure normals
new Float:g_fMeasureNormal[MAXPLAYERS + 1][NUM_LOCATIONS][3];

// Player measure distances
new Float:g_fMeasureDelta[MAXPLAYERS + 1][3];

// Player snap to grid option
new bool:g_bSnapToGrid[MAXPLAYERS + 1];

// Player snap increment index
new g_iSnapIncrementIndex[MAXPLAYERS + 1];

new g_Sprite;

new g_iMeasureColor[] = {0, 255, 255, 255};         // Color of the actual measurement beam   {R, G, B, A} 0-255
new g_iFirstPointerColor[] = {182, 255, 0, 255};    // Color of the first pointer beam
new g_iSecondPointerColor[] = {0, 255, 127, 255};   // Color of the second pointer beam

new Float:g_fSnapIncrements[] = {4.0, 8.0, 16.0, 32.0, 64.0};  // The array of snap to grid options

enum
{
	MENUSELECT_LOCATION_1 = 1,
	MENUSELECT_LOCATION_2,
	MENUSELECT_MEASURE,
	MENUSELECT_SNAP_TO_GRID,
	MENUSELECT_SNAP_INCREMENT
};


public OnPluginStart()
{
	RegConsoleCmd("sm_measure", OnMeasure, "Opens the Measure Gap menu");
	RegConsoleCmd("sm_gap", OnMeasure, "Opens the Measure Gap menu");
}

public OnMapStart()
{
	g_Sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public Action:OnMeasure(iClient, iArgs)
{
	DisplayMenu_Gap(iClient);
	return Plugin_Handled;
}

DisplayMenu_Gap(iClient)
{
	new Handle:hMenu = CreateMenu(MenuHandle_Gap);
	SetMenuTitle(hMenu, "Measure Gap");
	
	decl String:szInfo[4], String:szBuffer[30];
	IntToString(MENUSELECT_LOCATION_1, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Location 1");
	
	IntToString(MENUSELECT_LOCATION_2, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Location 2");
	
	IntToString(MENUSELECT_MEASURE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Measure");
	
	FormatEx(szBuffer, sizeof(szBuffer), "Snap to grid: %s", g_bSnapToGrid[iClient] ? "Yes" : "No");
	IntToString(MENUSELECT_SNAP_TO_GRID, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "Snap increment: %.0f", g_fSnapIncrements[g_iSnapIncrementIndex[iClient]]);
	IntToString(MENUSELECT_SNAP_INCREMENT, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, szBuffer);
	
	FormatEx(szBuffer, sizeof(szBuffer), "Horizontal: %.2f", g_fMeasureDelta[iClient][0]);
	AddMenuItem(hMenu, "", szBuffer, ITEMDRAW_DISABLED);
	
	FormatEx(szBuffer, sizeof(szBuffer), "    Vertical: %.2f", g_fMeasureDelta[iClient][1]);
	AddMenuItem(hMenu, "", szBuffer, ITEMDRAW_DISABLED);
	
	FormatEx(szBuffer, sizeof(szBuffer), "        Total: %.2f", g_fMeasureDelta[iClient][2]);
	AddMenuItem(hMenu, "", szBuffer, ITEMDRAW_DISABLED);
	
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, iClient, 0);
}

public MenuHandle_Gap(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	new iClient = iParam1;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	switch(StringToInt(szInfo))
	{
		case MENUSELECT_LOCATION_1:		GetLocation(iClient, LOCATION_1, g_iFirstPointerColor);
		case MENUSELECT_LOCATION_2:		GetLocation(iClient, LOCATION_2, g_iSecondPointerColor);
		case MENUSELECT_MEASURE:		PlayerMeasure(iClient);
		case MENUSELECT_SNAP_TO_GRID:	g_bSnapToGrid[iClient] = !g_bSnapToGrid[iClient];
		
		case MENUSELECT_SNAP_INCREMENT:
		{
			new iNewIndex = g_iSnapIncrementIndex[iClient] + 1;
			if(iNewIndex >= sizeof(g_fSnapIncrements))
				iNewIndex = 0;
			
			g_iSnapIncrementIndex[iClient] = iNewIndex;
		}
	}
	
	DisplayMenu_Gap(iClient);
}

GetLocation(iClient, iLocationNum, const iColor[4])
{
	decl Float:fEyePos[3], Float:fEyeAngles[3], Float:fEndPos[3], Float:fTraceNormal[3];
	GetClientEyePosition(iClient, fEyePos);
	GetClientEyeAngles(iClient, fEyeAngles);
	TR_TraceRayFilter(fEyePos, fEyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_DontHitPlayers);
	TR_GetEndPosition(fEndPos);
	TR_GetPlaneNormal(INVALID_HANDLE, fTraceNormal);
	
	g_fMeasureNormal[iClient][iLocationNum] = fTraceNormal;
	g_fMeasureLocation[iClient][iLocationNum] = fEndPos;
	
	decl Float:fPointerStartPos[3];
	new Float:fPointerOffset[] = {0.0, 0.0, -10.0};
	AddVectors(fEyePos, fPointerOffset, fPointerStartPos);  // Offset the pointer beam so that it doesnt come right out of the player's eyes.
	AddVectors(fEndPos, fTraceNormal, fEndPos);             // Offset the end point to be slightly out from the surface, ensures the beam will draw.
	TE_SetupBeamPoints(fPointerStartPos, fEndPos, g_Sprite, 0, 0, 0, 0.5, 0.25, 0.25, 10, 0.0, iColor, 0);
	TE_SendToClient(iClient);
	
}

PlayerMeasure(iClient)
{
	decl Float:fFirstLocation[3], Float:fSecondLocation[3], Float:fDeltaLocation[3];
	
	fFirstLocation = g_fMeasureLocation[iClient][LOCATION_1];
	fSecondLocation = g_fMeasureLocation[iClient][LOCATION_2];
	
	if(g_bSnapToGrid[iClient])
	{
		new Float:fSnapIncrement = g_fSnapIncrements[g_iSnapIncrementIndex[iClient]];
		fFirstLocation[0] = RoundFloat(fFirstLocation[0] / fSnapIncrement) * fSnapIncrement;
		fFirstLocation[1] = RoundFloat(fFirstLocation[1] / fSnapIncrement) * fSnapIncrement;
		fFirstLocation[2] = RoundFloat(fFirstLocation[2] / fSnapIncrement) * fSnapIncrement;
		
		fSecondLocation[0] = RoundFloat(fSecondLocation[0] / fSnapIncrement) * fSnapIncrement;
		fSecondLocation[1] = RoundFloat(fSecondLocation[1] / fSnapIncrement) * fSnapIncrement;
		fSecondLocation[2] = RoundFloat(fSecondLocation[2] / fSnapIncrement) * fSnapIncrement;
	}
	
	SubtractVectors(fSecondLocation, fFirstLocation, fDeltaLocation);
	
	decl Float:fHorizontalDelta[3];
	fHorizontalDelta[0] = fDeltaLocation[0];
	fHorizontalDelta[1] = fDeltaLocation[1];
	fHorizontalDelta[2] = 0.0;
	
	g_fMeasureDelta[iClient][0] = GetVectorLength(fHorizontalDelta, false);
	g_fMeasureDelta[iClient][1] = fDeltaLocation[2];
	g_fMeasureDelta[iClient][2] = GetVectorLength(fDeltaLocation, false);
	
	AddVectors(fFirstLocation, g_fMeasureNormal[iClient][0], fFirstLocation);    // Offset the beam end positions to be slightly out from the surface,
	AddVectors(fSecondLocation, g_fMeasureNormal[iClient][1], fSecondLocation);  // prevents the beam from being drawn directly on the surface and being hidden sometimes.
	
	TE_SetupBeamPoints(fFirstLocation, fSecondLocation, g_Sprite, 0, 0, 0, 10.0, 1.0, 1.0, 10, 0.0, g_iMeasureColor, 0);
	TE_SendToClient(iClient);
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}
