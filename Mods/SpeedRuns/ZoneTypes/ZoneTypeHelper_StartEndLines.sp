#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>
#include <sdktools_stringtables>
#include "../../../Libraries/ZoneManager/zone_manager"
#include "zonetype_helper_startendlines"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Zone Type Helper: Start End Lines";
new const String:PLUGIN_VERSION[] = "1.5";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A zone type helper for the start and end lines.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DISTANCE_NOT_SET				-1.0
#define DEFAULT_LINE_PERCENT			-1
#define DEFAULT_LINE_HEIGHT				5
#define DEFAULT_LINE_HEIGHT_START_END	40

#define DATA_INT_STAGE_NUMBER	1
#define DATA_INT_IS_FINAL_END	2

new Handle:g_hZoneIDs;
new g_iNumZoneIDs;

new g_iZoneIndexCounter[MAXPLAYERS+1];
new g_iShowingZoneIndex[MAXPLAYERS+1][LineType];

new const Float:DISPLAY_LINE_DELAY = 0.25;
new Float:g_fNextDisplayLineTime[MAXPLAYERS+1][LineType];

new g_iZoneStyles[MAX_ZONES+1][LineType];
new g_iZoneFaceTypes[MAX_ZONES+1][LineType];
new Float:g_fZoneLinePercentNormalized[MAX_ZONES+1][LineType];
new g_iZoneType[MAX_ZONES+1];

new g_iBeamIndex_Start;
new g_iBeamIndex_End;
new const String:SZ_BEAM_MATERIAL_START[] = "materials/swoobles/speed_runs/start.vmt";
new const String:SZ_BEAM_MATERIAL_END[] = "materials/swoobles/speed_runs/end.vmt";
new const String:SZ_BEAM_MATERIAL_START_VTF[] = "materials/swoobles/speed_runs/start.vtf";
new const String:SZ_BEAM_MATERIAL_END_VTF[] = "materials/swoobles/speed_runs/end.vtf";

new const BEAM_COLOR_START[] = {0, 255, 0, 255};
new const BEAM_COLOR_END[] = {255, 0, 0, 255};
new const BEAM_COLOR_EDIT[] = {255, 128, 0, 255};

new const Float:BEAM_WIDTH = 5.0;
new const BEAM_SPEED = 10; // Anything lower than 10 seems to bug out.

new g_iEditingZoneID[MAXPLAYERS+1];
new LineType:g_iEditingLineType[MAXPLAYERS+1];
new MenuInfoLine:g_iEditingLine[MAXPLAYERS+1];
new FaceType:g_iOriginalFaceType[MAXPLAYERS+1];
new FaceType:g_iLookingAtFaceType[MAXPLAYERS+1];

new Handle:g_hForwardLineMenuBack[MAXPLAYERS+1];

enum MenuInfoLine
{
	MENU_LINE_NONE = 0,
	MENU_LINE_STYLE,
	MENU_LINE_POSITION,
	MENU_LINE_FACE
};


public OnPluginStart()
{
	CreateConVar("zone_type_helper_start_end_lines_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hZoneIDs = CreateArray();
}

public OnMapStart()
{
	g_iNumZoneIDs = 0;
	
	AddFileToDownloadsTable(SZ_BEAM_MATERIAL_START);
	AddFileToDownloadsTable(SZ_BEAM_MATERIAL_START_VTF);
	g_iBeamIndex_Start = PrecacheModel(SZ_BEAM_MATERIAL_START, true);
	
	AddFileToDownloadsTable(SZ_BEAM_MATERIAL_END);
	AddFileToDownloadsTable(SZ_BEAM_MATERIAL_END_VTF);
	g_iBeamIndex_End = PrecacheModel(SZ_BEAM_MATERIAL_END, true);
}

public ZoneManager_OnTypeAssigned(iEnt, iZoneID, iZoneType)
{
	ReloadZoneIDs();
}

public ZoneManager_OnZoneRemoved_Post(iZoneID)
{
	ReloadZoneIDs();
}

ReloadZoneIDs()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		g_iShowingZoneIndex[iClient][LINE_TYPE_START] = INVALID_ZONE_ID;
		g_iShowingZoneIndex[iClient][LINE_TYPE_END] = INVALID_ZONE_ID;
	}
	
	ClearArray(g_hZoneIDs);
	ZoneManager_GetAllZones(g_hZoneIDs, ZONE_TYPE_TIMER_START);
	ZoneManager_GetAllZones(g_hZoneIDs, ZONE_TYPE_TIMER_END_START);
	ZoneManager_GetAllZones(g_hZoneIDs, ZONE_TYPE_TIMER_END);
	g_iNumZoneIDs = GetArraySize(g_hZoneIDs);
	
	decl iZoneID;
	for(new i=0; i<g_iNumZoneIDs; i++)
	{
		iZoneID = GetArrayCell(g_hZoneIDs, i);
		g_iZoneType[iZoneID] = ZoneManager_GetZoneType(iZoneID);
		
		g_iZoneStyles[iZoneID][LINE_TYPE_START] = GetStyle(iZoneID, LINE_TYPE_START);
		g_iZoneStyles[iZoneID][LINE_TYPE_END] = GetStyle(iZoneID, LINE_TYPE_END);
		
		g_iZoneFaceTypes[iZoneID][LINE_TYPE_START] = GetFaceType(iZoneID, LINE_TYPE_START);
		g_iZoneFaceTypes[iZoneID][LINE_TYPE_END] = GetFaceType(iZoneID, LINE_TYPE_END);
		
		g_fZoneLinePercentNormalized[iZoneID][LINE_TYPE_START] = _:(float(GetLinePercent(iZoneID, LINE_TYPE_START)) / 100.0);
		g_fZoneLinePercentNormalized[iZoneID][LINE_TYPE_END] = _:(float(GetLinePercent(iZoneID, LINE_TYPE_END)) / 100.0);
	}
}

public OnClientPutInServer(iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	g_iShowingZoneIndex[iClient][LINE_TYPE_START] = INVALID_ZONE_ID;
	g_iShowingZoneIndex[iClient][LINE_TYPE_END] = INVALID_ZONE_ID;
	
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public OnPreThinkPost(iClient)
{
	if(!g_iNumZoneIDs)
		return;
	
	g_iZoneIndexCounter[iClient]++;
	if(g_iZoneIndexCounter[iClient] >= g_iNumZoneIDs)
		g_iZoneIndexCounter[iClient] = 0;
	
	static iZoneID;
	iZoneID = GetArrayCell(g_hZoneIDs, g_iZoneIndexCounter[iClient]);
	
	if(g_iEditingLine[iClient] == MENU_LINE_FACE)
	{
		SetFaceOfLookingDirection(iClient);
	}
	else
	{
		static Float:fZoneOrigin[3];
		if(ZoneManager_GetZoneOrigin(iZoneID, fZoneOrigin))
		{
			static Float:fClientOrigin[3];
			GetClientAbsOrigin(iClient, fClientOrigin);
			
			static Float:fDistance;
			fDistance = GetVectorDistance(fClientOrigin, fZoneOrigin);
			
			IsThisNewShowLine(iClient, iZoneID, g_iZoneIndexCounter[iClient], LINE_TYPE_START, fDistance, fClientOrigin);
			IsThisNewShowLine(iClient, iZoneID, g_iZoneIndexCounter[iClient], LINE_TYPE_END, fDistance, fClientOrigin);
		}
	}
	
	static bool:bShowLineType[MAXPLAYERS+1];
	if(bShowLineType[iClient])
		ShowLine(iClient, LINE_TYPE_START);
	else
		ShowLine(iClient, LINE_TYPE_END);
	
	bShowLineType[iClient] = !bShowLineType[iClient];
}

IsThisNewShowLine(iClient, iZoneID, iZoneIndex, LineType:iLineType, Float:fDistance, const Float:fClientOrigin[3])
{
	// If the style is not enabled we skip over this line so it's not ever added to the show list.
	if(g_iZoneStyles[iZoneID][iLineType] == _:STYLE_TYPE_NOT_ENABLED)
		return;
	
	if(g_iShowingZoneIndex[iClient][iLineType] == iZoneIndex)
		return;
	
	// Compare this zones distance to the current show zone distance.
	if(g_iShowingZoneIndex[iClient][iLineType] != INVALID_ZONE_ID)
	{
		static iShowZoneID, Float:fShowZoneOrigin[3], Float:fShowZoneDistance;
		iShowZoneID = GetArrayCell(g_hZoneIDs, g_iShowingZoneIndex[iClient][iLineType]);
		
		if(ZoneManager_GetZoneOrigin(iShowZoneID, fShowZoneOrigin))
		{
			fShowZoneDistance = GetVectorDistance(fClientOrigin, fShowZoneOrigin);
			
			// Return if we are still closer to the zone we are currently showing.
			if(fShowZoneDistance < fDistance)
				return;
		}
	}
	
	g_fNextDisplayLineTime[iClient][iLineType] = 0.0;
	g_iShowingZoneIndex[iClient][iLineType] = iZoneIndex;
}

ShowLine(iClient, LineType:iLineType)
{
	if(g_iShowingZoneIndex[iClient][iLineType] == INVALID_ZONE_ID)
		return;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	if(fCurTime < g_fNextDisplayLineTime[iClient][iLineType])
		return;
	
	g_fNextDisplayLineTime[iClient][iLineType] = fCurTime + DISPLAY_LINE_DELAY;
	
	static iZoneID;
	iZoneID = GetArrayCell(g_hZoneIDs, g_iShowingZoneIndex[iClient][iLineType]);
	
	if((g_iZoneType[iZoneID] == ZONE_TYPE_TIMER_START && iLineType == LINE_TYPE_END)
	|| (g_iZoneType[iZoneID] == ZONE_TYPE_TIMER_END && iLineType == LINE_TYPE_START))
	{
		return;
	}
	
	switch(g_iZoneStyles[iZoneID][iLineType])
	{
		case STYLE_TYPE_LINE: ShowLine_Line(iClient, iZoneID, LineType:iLineType);
	}
}

FaceType:GetFaceTypeFromViewAngles(LineType:iLineType, const Float:fViewAngles[3])
{
	if(fViewAngles[0] <= -50.0)
	{
		if(iLineType == LINE_TYPE_START)
			return FACE_TYPE_TOP;
		else
			return FACE_TYPE_BOTTOM;
	}
	else if(fViewAngles[0] >= 50.0)
	{
		if(iLineType == LINE_TYPE_START)
			return FACE_TYPE_BOTTOM;
		else
			return FACE_TYPE_TOP;
	}
	else if(fViewAngles[1] >= -45.0 && fViewAngles[1] <= 45.0)
	{
		if(iLineType == LINE_TYPE_START)
			return FACE_TYPE_FORWARD;
		else
			return FACE_TYPE_BACK;
	}
	else if(fViewAngles[1] >= 135.0 || fViewAngles[1] <= -135.0)
	{
		if(iLineType == LINE_TYPE_START)
			return FACE_TYPE_BACK;
		else
			return FACE_TYPE_FORWARD;
	}
	else if(fViewAngles[1] >= 45.0 && fViewAngles[1] <= 135.0)
	{
		if(iLineType == LINE_TYPE_START)
			return FACE_TYPE_LEFT;
		else
			return FACE_TYPE_RIGHT;
	}
	else if(fViewAngles[1] >= -135.0 && fViewAngles[1] <= -45.0)
	{
		if(iLineType == LINE_TYPE_START)
			return FACE_TYPE_RIGHT;
		else
			return FACE_TYPE_LEFT;
	}
	
	return FACE_TYPE_AUTOMATIC;
}

ShowLine_Line(iClient, iZoneID, LineType:iLineType)
{
	static FaceType:iFaceType;
	
	if(g_iZoneFaceTypes[iZoneID][iLineType] == _:FACE_TYPE_AUTOMATIC)
	{
		static Float:fZoneAngles[3];
		ZoneManager_GetZoneAngles(iZoneID, fZoneAngles);
		
		iFaceType = GetFaceTypeFromViewAngles(iLineType, fZoneAngles);
		if(iFaceType == FACE_TYPE_AUTOMATIC)
			return;
	}
	else
	{
		iFaceType = FaceType:g_iZoneFaceTypes[iZoneID][iLineType];
	}
	
	static Float:fZoneOrigin[3], Float:fMins[3], Float:fMaxs[3];
	if(!ZoneManager_GetZoneOrigin(iZoneID, fZoneOrigin))
		return;
	
	if(!ZoneManager_GetZoneMins(iZoneID, fMins))
		return;
	
	if(!ZoneManager_GetZoneMaxs(iZoneID, fMaxs))
		return;
	
	static Float:fPoint1[3], Float:fPoint2[3], Float:fLineHeight[3], iDefaultLineHeight;
	
	switch(g_iZoneType[iZoneID])
	{
		/*
		case ZONE_TYPE_TIMER_START:
		{
			if(ZoneManager_GetDataInt(iZoneID, DATA_INT_STAGE_NUMBER) == 1)
				iDefaultLineHeight = DEFAULT_LINE_HEIGHT_START_END;
			else
				iDefaultLineHeight = DEFAULT_LINE_HEIGHT;
		}
		*/
		case ZONE_TYPE_TIMER_END:
		{
			if(ZoneManager_GetDataInt(iZoneID, DATA_INT_IS_FINAL_END) == 1)
				iDefaultLineHeight = DEFAULT_LINE_HEIGHT_START_END;
			else
				iDefaultLineHeight = DEFAULT_LINE_HEIGHT;
		}
		default:
		{
			iDefaultLineHeight = DEFAULT_LINE_HEIGHT;
		}
	}
	
	fLineHeight[0] = fMins[0] + ((fMaxs[0] - fMins[0]) * g_fZoneLinePercentNormalized[iZoneID][iLineType]);
	fLineHeight[1] = fMins[1] + ((fMaxs[1] - fMins[1]) * g_fZoneLinePercentNormalized[iZoneID][iLineType]);
	fLineHeight[2] = fMins[2] + ((fMaxs[2] - fMins[2]) * g_fZoneLinePercentNormalized[iZoneID][iLineType]);
	
	if(g_fZoneLinePercentNormalized[iZoneID][iLineType] < 0.0)
	{
		fLineHeight[0] = ((fMaxs[0] - fMins[0]) <= iDefaultLineHeight) ? fMins[0] : fMins[0] + iDefaultLineHeight;
		fLineHeight[1] = ((fMaxs[1] - fMins[1]) <= iDefaultLineHeight) ? fMins[1] : fMins[1] + iDefaultLineHeight;
		fLineHeight[2] = ((fMaxs[2] - fMins[2]) <= iDefaultLineHeight) ? fMins[2] : fMins[2] + iDefaultLineHeight;
	}
	
	switch(iFaceType)
	{
		case FACE_TYPE_FORWARD:
		{
			// Right point.
			fPoint1[0] = fZoneOrigin[0] + fMaxs[0];
			fPoint1[1] = fZoneOrigin[1] + fMaxs[1];
			fPoint1[2] = fZoneOrigin[2] + fLineHeight[2];
			
			// Left point.
			fPoint2[0] = fZoneOrigin[0] + fMaxs[0];
			fPoint2[1] = fZoneOrigin[1] + fMins[1];
			fPoint2[2] = fZoneOrigin[2] + fLineHeight[2];
		}
		case FACE_TYPE_BACK:
		{
			// Right point.
			fPoint1[0] = fZoneOrigin[0] + fMins[0];
			fPoint1[1] = fZoneOrigin[1] + fMaxs[1];
			fPoint1[2] = fZoneOrigin[2] + fLineHeight[2];
			
			// Left point.
			fPoint2[0] = fZoneOrigin[0] + fMins[0];
			fPoint2[1] = fZoneOrigin[1] + fMins[1];
			fPoint2[2] = fZoneOrigin[2] + fLineHeight[2];
		}
		case FACE_TYPE_RIGHT:
		{
			// Right point.
			fPoint1[0] = fZoneOrigin[0] + fMaxs[0];
			fPoint1[1] = fZoneOrigin[1] + fMins[1];
			fPoint1[2] = fZoneOrigin[2] + fLineHeight[2];
			
			// Left point.
			fPoint2[0] = fZoneOrigin[0] + fMins[0];
			fPoint2[1] = fZoneOrigin[1] + fMins[1];
			fPoint2[2] = fZoneOrigin[2] + fLineHeight[2];
		}
		case FACE_TYPE_LEFT:
		{
			// Right point.
			fPoint1[0] = fZoneOrigin[0] + fMaxs[0];
			fPoint1[1] = fZoneOrigin[1] + fMaxs[1];
			fPoint1[2] = fZoneOrigin[2] + fLineHeight[2];
			
			// Left point.
			fPoint2[0] = fZoneOrigin[0] + fMins[0];
			fPoint2[1] = fZoneOrigin[1] + fMaxs[1];
			fPoint2[2] = fZoneOrigin[2] + fLineHeight[2];
		}
		case FACE_TYPE_TOP:
		{
			// Right point.
			fPoint1[0] = fZoneOrigin[0] + fMaxs[0];
			fPoint1[1] = fZoneOrigin[1] + fLineHeight[1];
			fPoint1[2] = fZoneOrigin[2] + fMaxs[2];
			
			// Left point.
			fPoint2[0] = fZoneOrigin[0] + fMins[0];
			fPoint2[1] = fZoneOrigin[1] + fLineHeight[1];
			fPoint2[2] = fZoneOrigin[2] + fMaxs[2];
		}
		case FACE_TYPE_BOTTOM:
		{
			// Right point.
			fPoint1[0] = fZoneOrigin[0] + fMaxs[0];
			fPoint1[1] = fZoneOrigin[1] + fLineHeight[1];
			fPoint1[2] = fZoneOrigin[2] + fMins[2];
			
			// Left point.
			fPoint2[0] = fZoneOrigin[0] + fMins[0];
			fPoint2[1] = fZoneOrigin[1] + fLineHeight[1];
			fPoint2[2] = fZoneOrigin[2] + fMins[2];
		}
		default:
		{
			return;
		}
	}
	
	static iColor[4], iBeamIndex;
	if(iLineType == LINE_TYPE_START)
	{
		iBeamIndex = g_iBeamIndex_Start;
		iColor = BEAM_COLOR_START;
	}
	else
	{
		iBeamIndex = g_iBeamIndex_End;
		iColor = BEAM_COLOR_END;
	}
	
	if(ZoneManager_IsInZoneMenu(iClient))
		iColor = BEAM_COLOR_EDIT;
	
	TE_SetupBeamPoints(fPoint1, fPoint2, iBeamIndex, 0, 0, 0, DISPLAY_LINE_DELAY+0.1, BEAM_WIDTH, BEAM_WIDTH, 0, 0.0, iColor, BEAM_SPEED);
	TE_SendToClient(iClient);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("zonetype_helper_startendlines");
	CreateNative("StartEndLines_DisplayLineMenu", _StartEndLines_DisplayLineMenu);
	CreateNative("StartEndLines_SetStyle", _StartEndLines_SetStyle);
	
	return APLRes_Success;
}

public _StartEndLines_DisplayLineMenu(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 4)
	{
		LogError("Invalid number of parameters StartEndLines_DisplayLineMenu()");
		return false;
	}
	
	new iClient = GetNativeCell(1);
	new iZoneID = GetNativeCell(2);
	new LineType:iLineType = LineType:GetNativeCell(3);
	new Function:callback = GetNativeCell(4);
	
	if(callback == INVALID_FUNCTION)
		return false;
	
	if(g_hForwardLineMenuBack[iClient] != INVALID_HANDLE)
		CloseHandle(g_hForwardLineMenuBack[iClient]);
	
	g_hForwardLineMenuBack[iClient] = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
	AddToForward(g_hForwardLineMenuBack[iClient], hPlugin, callback);
	
	DisplayMenu_EditLine(iClient, iZoneID, iLineType);
	
	return true;
}

Forward_LineMenuBack(iClient, iZoneID)
{
	if(g_hForwardLineMenuBack[iClient] == INVALID_HANDLE)
		return;
	
	decl result;
	Call_StartForward(g_hForwardLineMenuBack[iClient]);
	Call_PushCell(iClient);
	Call_PushCell(iZoneID);
	Call_Finish(result);
}

public _StartEndLines_SetStyle(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters StartEndLines_SetStyle()");
		return;
	}
	
	SetStyle(GetNativeCell(1), LineType:GetNativeCell(2), StyleType:GetNativeCell(3));
}

SetStyle(iZoneID, LineType:iLineType, StyleType:iStyleNew)
{
	decl StyleType:iStyle, FaceType:iFace, iPercent, Float:fPoint1[3], Float:fPoint2[3];
	if(!GetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2))
		SetDefaultLineValues(iStyle, iFace, iPercent, fPoint1, fPoint2);
	
	iStyle = iStyleNew;
	g_iZoneStyles[iZoneID][iLineType] = _:iStyle;
	
	SetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2);
}

GetStyle(iZoneID, LineType:iLineType)
{
	decl StyleType:iStyle, FaceType:iFace, iPercent, Float:fPoint1[3], Float:fPoint2[3];
	if(!GetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2))
	{
		new iZoneType = ZoneManager_GetZoneType(iZoneID);
		
		if(iZoneType == ZONE_TYPE_TIMER_END)
		{
			if(iLineType == LINE_TYPE_END)
				return _:STYLE_TYPE_LINE;
		}
		else
		{
			if(iLineType == LINE_TYPE_START)
				return _:STYLE_TYPE_LINE;
		}
		
		return _:STYLE_TYPE_NOT_ENABLED;
	}
	
	return _:iStyle;
}

public _StartEndLines_SetFaceType(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters StartEndLines_SetFaceType()");
		return;
	}
	
	SetFaceType(GetNativeCell(1), LineType:GetNativeCell(2), FaceType:GetNativeCell(3));
}

SetFaceType(iZoneID, LineType:iLineType, FaceType:iFaceTypeNew)
{
	decl StyleType:iStyle, FaceType:iFace, iPercent, Float:fPoint1[3], Float:fPoint2[3];
	if(!GetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2))
		SetDefaultLineValues(iStyle, iFace, iPercent, fPoint1, fPoint2);
	
	iFace = iFaceTypeNew;
	g_iZoneFaceTypes[iZoneID][iLineType] = _:iFace;
	
	SetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2);
}

GetFaceType(iZoneID, LineType:iLineType)
{
	decl StyleType:iStyle, FaceType:iFace, iPercent, Float:fPoint1[3], Float:fPoint2[3];
	if(!GetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2))
		return _:FACE_TYPE_AUTOMATIC;
	
	return _:iFace;
}

public _StartEndLines_SetLinePercent(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 3)
	{
		LogError("Invalid number of parameters StartEndLines_SetLinePercent()");
		return;
	}
	
	SetLinePercent(GetNativeCell(1), LineType:GetNativeCell(2), GetNativeCell(3));
}

SetLinePercent(iZoneID, LineType:iLineType, iPercentNew)
{
	decl StyleType:iStyle, FaceType:iFace, iPercent, Float:fPoint1[3], Float:fPoint2[3];
	if(!GetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2))
		SetDefaultLineValues(iStyle, iFace, iPercent, fPoint1, fPoint2);
	
	iPercent = iPercentNew;
	g_fZoneLinePercentNormalized[iZoneID][iLineType] = float(iPercent) / 100.0;
	
	SetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2);
}

GetLinePercent(iZoneID, LineType:iLineType)
{
	decl StyleType:iStyle, FaceType:iFace, iPercent, Float:fPoint1[3], Float:fPoint2[3];
	if(!GetValuesForLineType(iZoneID, iLineType, iStyle, iFace, iPercent, fPoint1, fPoint2))
		return DEFAULT_LINE_PERCENT;
	
	return iPercent;
}

SetDefaultLineValues(&StyleType:iStyleType, &FaceType:iFaceType, &iLinePercent, Float:fPoint1[3], Float:fPoint2[3])
{
	iStyleType = STYLE_TYPE_NOT_ENABLED;
	iFaceType = FACE_TYPE_AUTOMATIC;
	iLinePercent = DEFAULT_LINE_PERCENT;
	fPoint1 = Float:{0.0, 0.0, 0.0};
	fPoint2 = Float:{0.0, 0.0, 0.0};
}

SetValuesForLineType(iZoneID, LineType:iLineType, StyleType:iStyleType, FaceType:iFaceType, iLinePercent, Float:fPoint1[3], Float:fPoint2[3])
{
	// First get the other linetype's variables.
	decl LineType:iOtherLineType, StyleType:iOtherStyle, FaceType:iOtherFace, iOtherPercent, Float:fOtherPoint1[3], Float:fOtherPoint2[3];
	
	if(iLineType == LINE_TYPE_START)
		iOtherLineType = LINE_TYPE_END;
	else
		iOtherLineType = LINE_TYPE_START;
	
	if(!GetValuesForLineType(iZoneID, iOtherLineType, iOtherStyle, iOtherFace, iOtherPercent, fOtherPoint1, fOtherPoint2))
		SetDefaultLineValues(iOtherStyle, iOtherFace, iOtherPercent, fOtherPoint1, fOtherPoint2);
	
	// Format the string.
	decl String:szString[MAX_ZONE_DATA_STRING_LENGTH];
	FormatEx(szString, sizeof(szString), "%i:%i:%i:%i:%f,%f,%f:%f,%f,%f/%i:%i:%i:%i:%f,%f,%f:%f,%f,%f",
		iLineType, iStyleType, iFaceType, iLinePercent, fPoint1[0], fPoint1[1], fPoint1[2], fPoint2[0], fPoint2[1], fPoint2[2],
		iOtherLineType, iOtherStyle, iOtherFace, iOtherPercent, fOtherPoint1[0], fOtherPoint1[1], fOtherPoint1[2], fOtherPoint2[0], fOtherPoint2[1], fOtherPoint2[2]);
	
	ZoneManager_SetDataString(iZoneID, DATA_STRING_LINE_DATA, szString);
}

bool:GetValuesForLineType(iZoneID, LineType:iLineType, &StyleType:iStyleType, &FaceType:iFaceType, &iLinePercent, Float:fPoint1[3], Float:fPoint2[3])
{
	decl String:szString[MAX_ZONE_DATA_STRING_LENGTH];
	if(!ZoneManager_GetDataString(iZoneID, DATA_STRING_LINE_DATA, szString, sizeof(szString)))
		return false;
	
	decl String:szLineTypes[2][256], iLineTypeNum, String:szArgs[6][64], iArgNum;
	
	iLineTypeNum = ExplodeString(szString, "/", szLineTypes, sizeof(szLineTypes), sizeof(szLineTypes[]), false);
	for(new i=0; i<iLineTypeNum; i++)
	{
		iArgNum = ExplodeString(szLineTypes[i], ":", szArgs, sizeof(szArgs), sizeof(szArgs[]), false);
		if(iArgNum != 6)
			continue;
		
		if(iLineType != LineType:StringToInt(szArgs[0]))
			continue;
		
		decl String:szPoint[3][14], iPointCount;
		
		// Get the first point.
		iPointCount = ExplodeString(szArgs[4], ",", szPoint, sizeof(szPoint), sizeof(szPoint[]), false);
		if(iPointCount != 3)
			return false;
		
		fPoint1[0] = StringToFloat(szPoint[0]);
		fPoint1[1] = StringToFloat(szPoint[1]);
		fPoint1[2] = StringToFloat(szPoint[2]);
		
		// Get the second point.
		iPointCount = ExplodeString(szArgs[5], ",", szPoint, sizeof(szPoint), sizeof(szPoint[]), false);
		if(iPointCount != 3)
			return false;
		
		fPoint2[0] = StringToFloat(szPoint[0]);
		fPoint2[1] = StringToFloat(szPoint[1]);
		fPoint2[2] = StringToFloat(szPoint[2]);
		
		// Get the rest of the values.
		iStyleType = StyleType:StringToInt(szArgs[1]);
		iFaceType = FaceType:StringToInt(szArgs[2]);
		iLinePercent = StringToInt(szArgs[3]);
		
		return true;
	}
	
	return false;
}

DisplayMenu_EditLine(iClient, iZoneID, LineType:iLineType)
{
	decl String:szTitle[1024];
	FormatEx(szTitle, sizeof(szTitle), "Edit %s Line", (iLineType == LINE_TYPE_START) ? "Start" : "End");
	
	if(g_iZoneStyles[iZoneID][iLineType] == _:STYLE_TYPE_LINE
	|| g_iZoneStyles[iZoneID][iLineType] == _:STYLE_TYPE_X)
	{
		Format(szTitle, sizeof(szTitle), "%s\n \nPercent: %i\n \nChange the lines position by\nentering a number 0-100 in chat.\n \n", szTitle, RoundFloat(g_fZoneLinePercentNormalized[iZoneID][iLineType] * 100.0));
	}
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditLine);
	SetMenuTitle(hMenu, szTitle);
	
	decl String:szInfo[4];
	IntToString(_:MENU_LINE_STYLE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Set line style.");
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		Forward_LineMenuBack(iClient, iZoneID);
		return;
	}
	
	g_iEditingLineType[iClient] = iLineType;
	g_iEditingZoneID[iClient] = iZoneID;
	g_iEditingLine[iClient] = MENU_LINE_POSITION;
	ZoneManager_RestartEditingZoneData(iClient);
}

public MenuHandle_EditLine(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		g_iEditingLine[iParam1] = MENU_LINE_NONE;
		
		new iZoneID = g_iEditingZoneID[iParam1];
		g_iEditingZoneID[iParam1] = 0;
		ZoneManager_FinishedEditingZoneData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			Forward_LineMenuBack(iParam1, iZoneID);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new MenuInfoLine:iType = MenuInfoLine:StringToInt(szInfo);
	
	if(iType == MENU_LINE_STYLE)
	{
		g_iEditingLine[iParam1] = MENU_LINE_NONE;
		DisplayMenu_EditStyle(iParam1, g_iEditingZoneID[iParam1]);
		return;
	}
	
	g_iEditingLine[iParam1] = iType;
	DisplayMenu_EditLine(iParam1, g_iEditingZoneID[iParam1], g_iEditingLineType[iParam1]);
}

DisplayMenu_EditStyle(iClient, iZoneID)
{
	new Handle:hMenu = CreateMenu(MenuHandle_EditStyle);
	SetMenuTitle(hMenu, "Edit Line Style");
	
	decl String:szInfo[4];
	IntToString(_:STYLE_TYPE_NOT_ENABLED, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Don't show a line");
	
	IntToString(_:STYLE_TYPE_LINE, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Line");
	
	IntToString(_:STYLE_TYPE_LINE_BETWEEN_POINTS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "Line between points", ITEMDRAW_DISABLED);
	
	IntToString(_:STYLE_TYPE_X, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "X", ITEMDRAW_DISABLED);
	
	IntToString(_:STYLE_TYPE_X_BETWEEN_POINTS, szInfo, sizeof(szInfo));
	AddMenuItem(hMenu, szInfo, "X between points", ITEMDRAW_DISABLED);
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		DisplayMenu_EditLine(iClient, iZoneID, g_iEditingLineType[iClient]);
		return;
	}
	
	g_iEditingZoneID[iClient] = iZoneID;
	ZoneManager_RestartEditingZoneData(iClient);
}

public MenuHandle_EditStyle(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		new iZoneID = g_iEditingZoneID[iParam1];
		g_iEditingZoneID[iParam1] = 0;
		ZoneManager_FinishedEditingZoneData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditLine(iParam1, iZoneID, g_iEditingLineType[iParam1]);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	new StyleType:iStyleType = StyleType:StringToInt(szInfo);
	StartEndLines_SetStyle(g_iEditingZoneID[iParam1], g_iEditingLineType[iParam1], iStyleType);
	
	switch(iStyleType)
	{
		case STYLE_TYPE_LINE: DisplayMenu_EditFace(iParam1, g_iEditingZoneID[iParam1]);
		default: DisplayMenu_EditLine(iParam1, g_iEditingZoneID[iParam1], g_iEditingLineType[iParam1]);
	}
}

DisplayMenu_EditFace(iClient, iZoneID)
{
	g_iOriginalFaceType[iClient] = FaceType:GetFaceType(iZoneID, g_iEditingLineType[iClient]);
	g_iLookingAtFaceType[iClient] = FACE_TYPE_AUTOMATIC;
	
	new Handle:hMenu = CreateMenu(MenuHandle_EditFace);
	SetMenuTitle(hMenu, "Edit Line Face\n \nLook in a specific direction.\nThe line will appear on the face of the direction you are looking.");
	
	AddMenuItem(hMenu, "1", "Put line here");
	AddMenuItem(hMenu, "0", "Cancel");
	
	SetMenuExitBackButton(hMenu, true);
	if(!DisplayMenu(hMenu, iClient, 0))
	{
		PrintToChat(iClient, "[SM] Error displaying menu.");
		DisplayMenu_EditStyle(iClient, iZoneID);
		return;
	}
	
	g_iEditingZoneID[iClient] = iZoneID;
	ZoneManager_RestartEditingZoneData(iClient);
	
	g_iEditingLine[iClient] = MENU_LINE_FACE;
}

public MenuHandle_EditFace(Handle:hMenu, MenuAction:action, iParam1, iParam2)
{
	if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
		return;
	}
	
	if(action == MenuAction_Cancel)
	{
		SetFaceType(g_iEditingZoneID[iParam1], g_iEditingLineType[iParam1], g_iOriginalFaceType[iParam1]);
		
		new iZoneID = g_iEditingZoneID[iParam1];
		g_iEditingZoneID[iParam1] = 0;
		g_iEditingLine[iParam1] = MENU_LINE_NONE;
		ZoneManager_FinishedEditingZoneData(iParam1);
		
		if(iParam2 == MenuCancel_ExitBack)
			DisplayMenu_EditStyle(iParam1, iZoneID);
		
		return;
	}
	
	if(action != MenuAction_Select)
		return;
	
	decl String:szInfo[4];
	GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));
	
	g_iEditingLine[iParam1] = MENU_LINE_NONE;
	
	if(!StringToInt(szInfo))
		SetFaceType(g_iEditingZoneID[iParam1], g_iEditingLineType[iParam1], g_iOriginalFaceType[iParam1]);
	
	DisplayMenu_EditLine(iParam1, g_iEditingZoneID[iParam1], g_iEditingLineType[iParam1]);
}

SetFaceOfLookingDirection(iClient)
{
	static iZoneID;
	iZoneID = g_iEditingZoneID[iClient];
	
	if(!iZoneID)
		return;
	
	static Float:fEyeAngles[3];
	GetClientEyeAngles(iClient, fEyeAngles);
	
	static FaceType:iFaceType;
	iFaceType = GetFaceTypeFromViewAngles(LINE_TYPE_START, fEyeAngles);
	if(iFaceType == FACE_TYPE_AUTOMATIC)
		return;
	
	SetFaceType(iZoneID, g_iEditingLineType[iClient], iFaceType);
	
	for(new i=0; i<g_iNumZoneIDs; i++)
	{
		if(GetArrayCell(g_hZoneIDs, i) != iZoneID)
			continue;
		
		g_iShowingZoneIndex[iClient][g_iEditingLineType[iClient]] = i;
		
		if(g_iLookingAtFaceType[iClient] != iFaceType)
		{
			g_fNextDisplayLineTime[iClient][g_iEditingLineType[iClient]] = 0.0;
			g_iLookingAtFaceType[iClient] = iFaceType;
		}
	}
}

public OnClientSayCommand_Post(iClient, const String:szCommand[], const String:szArgs[])
{
	if(!g_iEditingZoneID[iClient])
		return;
	
	if(g_iEditingLine[iClient] != MENU_LINE_POSITION)
		return;
	
	
	if(g_iZoneStyles[g_iEditingZoneID[iClient]][g_iEditingLineType[iClient]] != _:STYLE_TYPE_LINE
	&& g_iZoneStyles[g_iEditingZoneID[iClient]][g_iEditingLineType[iClient]] != _:STYLE_TYPE_X)
	{
		return;
	}
	
	new iInt = StringToInt(szArgs);
	if(iInt < -1 || iInt > 100)
	{
		PrintToChat(iClient, "[SM] Invalid percent.");
		return;
	}
	
	SetLinePercent(g_iEditingZoneID[iClient], g_iEditingLineType[iClient], iInt);
	PrintToChat(iClient, "[SM] Set percent to: %i.", iInt);
	
	DisplayMenu_EditLine(iClient, g_iEditingZoneID[iClient], g_iEditingLineType[iClient]);
	
	g_fNextDisplayLineTime[iClient][g_iEditingLineType[iClient]] = 0.0;
}