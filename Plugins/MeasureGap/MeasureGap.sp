#include <sdktools>

new const String:PLUGIN_NAME[] = "Measure Gap";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "Hymns For Disco",
	description = "Measures the distance between 2 points via a menu",
	version = PLUGIN_VERSION,
	url = ""
}





#define	MASK_PLAYERSOLID		(CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_PLAYERCLIP|CONTENTS_WINDOW|CONTENTS_MONSTER|CONTENTS_GRATE) 	/**< everything that blocks player movement */

new Float:g_fMeasureLocation[MAXPLAYERS + 1][2][3];
//Player measure locations

new Float:g_fMeasureDelta[MAXPLAYERS + 1][3];
//Player measure distances

new bool:g_bSnapToGrid[MAXPLAYERS + 1];
//Player snap to grid option

new g_iSnapIncrementIndex[MAXPLAYERS + 1];
//Player snap increment index

new g_Sprite;

new g_iColor[] = {0, 255, 255, 255};

new Float:g_fSnapIncrements[] = {4.0, 8.0, 16.0, 32.0, 64.0};

public OnPluginStart()
{
	RegConsoleCmd("sm_measure", OnMeasure, "Opens the Measure Gap menu");
	RegConsoleCmd("sm_gap", OnMeasure, "Opens the Measure Gap menu");
}

public OnMapStart()
{
	g_Sprite = PrecacheModel("materials/sprites/laser.vmt");
}
 
public MenuHandler1(Handle:menu, MenuAction:action, param1, param2)
{
	new iClient = param1;
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{	
		switch(param2)
		{
			case 0:
			{
				new Float:fEyePos[3], Float:fEyeAngles[3], Float:fEndPos[3];
				GetClientEyePosition(iClient, fEyePos);
				GetClientEyeAngles(iClient, fEyeAngles);
				TR_TraceRayFilter(fEyePos, fEyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_DontHitPlayers);
				TR_GetEndPosition(fEndPos);
				
				g_fMeasureLocation[iClient][0] = fEndPos;
				
				DisplayGapMenu(iClient);
			}
			case 1:
			{
				decl Float:fEyePos[3], Float:fEyeAngles[3], Float:fEndPos[3];
				GetClientEyePosition(iClient, fEyePos);
				GetClientEyeAngles(iClient, fEyeAngles);
				TR_TraceRayFilter(fEyePos, fEyeAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_DontHitPlayers);
				TR_GetEndPosition(fEndPos);
				
				g_fMeasureLocation[iClient][1] = fEndPos;
				
				DisplayGapMenu(iClient);
			}
			case 2:
			{
				PlayerMeasure(iClient);
				DisplayGapMenu(iClient);
			}
			case 3:
			{
				g_bSnapToGrid[iClient] = !g_bSnapToGrid[iClient];
				DisplayGapMenu(iClient);
			}
			case 4:
			{
				new iNewIndex = g_iSnapIncrementIndex[iClient] + 1;
				if (iNewIndex >= sizeof(g_fSnapIncrements))
				{
					iNewIndex = 0;
				}
				
				g_iSnapIncrementIndex[iClient] = iNewIndex;
				
				DisplayGapMenu(iClient);
			}
		}
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

PlayerMeasure(iClient)
{
	new Float:fFirstLocation[3], Float:fSecondLocation[3], Float:fDeltaLocation[3];
	
	fFirstLocation = g_fMeasureLocation[iClient][0];
	fSecondLocation = g_fMeasureLocation[iClient][1];
	
	if (g_bSnapToGrid[iClient])
	{
		new Float:fSnapIncrement = g_fSnapIncrements[g_iSnapIncrementIndex[iClient]];
		fFirstLocation[0] = RoundFloat(fFirstLocation[0] / fSnapIncrement)*fSnapIncrement;
		fFirstLocation[1] = RoundFloat(fFirstLocation[1] / fSnapIncrement)*fSnapIncrement;
		fFirstLocation[2] = RoundFloat(fFirstLocation[2] / fSnapIncrement)*fSnapIncrement;
		
		fSecondLocation[0] = RoundFloat(fSecondLocation[0] / fSnapIncrement)*fSnapIncrement;
		fSecondLocation[1] = RoundFloat(fSecondLocation[1] / fSnapIncrement)*fSnapIncrement;
		fSecondLocation[2] = RoundFloat(fSecondLocation[2] / fSnapIncrement)*fSnapIncrement;
	}
	
	SubtractVectors(fSecondLocation, fFirstLocation, fDeltaLocation);
	
	new Float:fHorizontalDelta[3]
	fHorizontalDelta[0] = fDeltaLocation[0];
	fHorizontalDelta[1] = fDeltaLocation[1];
	fHorizontalDelta[2] = 0.0;
	
	g_fMeasureDelta[iClient][0] = GetVectorLength(fHorizontalDelta, false);
	g_fMeasureDelta[iClient][1] = fDeltaLocation[2];
	g_fMeasureDelta[iClient][2] = GetVectorLength(fDeltaLocation, false);
	
	TE_SetupBeamPoints(fFirstLocation, fSecondLocation, g_Sprite, 0, 0, 0, 10.0, 5.0, 5.0, 10, 0.0, g_iColor, 0);
	TE_SendToClient(iClient);
}

DisplayGapMenu(iClient)
{
	new Handle:menu = CreateMenu(MenuHandler1);
	SetMenuTitle(menu, "Measure Gap");
	AddMenuItem(menu, "loc1", "Location 1");
	AddMenuItem(menu, "loc2", "Location 2");
	AddMenuItem(menu, "measure", "Measure");
	
	new String:snapStr[20] = "Snap to Grid: ";
	StrCat(snapStr, sizeof(snapStr), g_bSnapToGrid[iClient] ? "Yes" : "No");
	AddMenuItem(menu, "snap", snapStr);
	
	new String:snapIncStr[30] = "";
	Format(snapIncStr, sizeof(snapIncStr), "Snap Increment: %.0f", g_fSnapIncrements[g_iSnapIncrementIndex[iClient]]);
	AddMenuItem(menu, "snap_inc", snapIncStr);
	
	new String:hStr[30] = "";
	Format(hStr, sizeof(hStr), "Horizontal: %f", g_fMeasureDelta[iClient][0]);
	new String:vStr[30] = "";
	Format(vStr, sizeof(vStr), "Vertical: %f", g_fMeasureDelta[iClient][1]);
	new String:tStr[30] = "";
	Format(tStr, sizeof(tStr), "Total: %f", g_fMeasureDelta[iClient][2]);
	
	AddMenuItem(menu, "h", hStr, ITEMDRAW_DISABLED);
	AddMenuItem(menu, "v", vStr, ITEMDRAW_DISABLED);
	AddMenuItem(menu, "total", tStr, ITEMDRAW_DISABLED);
	AddMenuItem(menu, "exit", "Exit");
	
	SetMenuPagination(menu, MENU_NO_PAGINATION);
	DisplayMenu(menu, iClient, 0);
}
 
public Action:OnMeasure(client, args)
{
	DisplayGapMenu(client);
	return Plugin_Handled;
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}
