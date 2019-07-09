#include <sdktools_trace>
#include <sdktools_tempents>
#include <sdktools_tempents_stocks>

#define TRACE_UPDATE_TICKS 1
#define TRACE_MAX_TICKS 200

new g_Sprite;

new g_iNextUpdate[MAXPLAYERS + 1];

new Handle:cvar_gravity;

public OnPluginStart()
{
	cvar_gravity = FindConVar("sv_gravity");
}

public OnMapStart()
{
	g_Sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public OnClientConnected(iClient)
{
    g_iNextUpdate[iClient] = 0;
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
    if (iTickCount < g_iNextUpdate[iClient])
        return;
    
    g_iNextUpdate[iClient] = iTickCount + TRACE_UPDATE_TICKS;

    new Float:fGravity = GetConVarFloat(cvar_gravity) * GetEntityGravity(iClient);

    decl Float:fStart[3], Float:fOrigin[3], Float:fStep[3];
    //GetClientEyePosition(iClient, fEyePos);
    GetClientAbsOrigin(iClient, fOrigin);
    GetClientAbsOrigin(iClient, fStart);
    GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fStep);

    decl Float:fMins[3];
    fMins[0] = -16.0;
    fMins[1] = -16.0;
    fMins[2] = 0.0;
    decl Float:fMaxs[3];
    fMaxs[0] = 16.0;
    fMaxs[1] = 16.0;
    fMaxs[2] = 72.0
        
    decl Float:fEnd[3];
    ScaleVector(fStep, GetTickInterval());

    new i = 0;
    while (i < TRACE_MAX_TICKS)
    {
        i++
        AddVectors(fOrigin, fStep, fEnd);
        TR_TraceHullFilter(fOrigin, fEnd, fMins, fMaxs, MASK_PLAYERSOLID, TraceFilter_DontHitPlayers);
        if (TR_DidHit())
            break;
        fOrigin[0] = fEnd[0];
        fOrigin[1] = fEnd[1];
        fOrigin[2] = fEnd[2];
        fStep[2] -= fGravity * GetTickInterval() * GetTickInterval();
    }
	
    TR_GetEndPosition(fEnd, INVALID_HANDLE);

    decl iColor[4];

    decl Float:fNormal[3];
    TR_GetPlaneNormal(INVALID_HANDLE, fNormal);

    if (fNormal[2] >= 0.70710678118)
        iColor = {0, 255, 0, 255}
    else
        iColor = {255, 255, 255, 255}

    new Float:fDrawTime = 0.06; //float(TRACE_UPDATE_TICKS) * GetTickInterval();

    //TE_SetupBeamPoints(fStart, fEnd, g_Sprite, 0, 0, 0, fDrawTime, 2.0, 2.0, 10, 0.0, {255, 255, 255, 255}, 0);

    decl Float:fPoint1[3], Float:fPoint2[3];

    AddVectors(fEnd, Float:{-16.0, -16.0, 0.0}, fPoint1);
    AddVectors(fEnd, Float:{-16.0, 16.0, 0.0}, fPoint2);
    TE_SetupBeamPoints(fPoint1, fPoint2, g_Sprite, 0, 0, 0, fDrawTime, 2.0, 2.0, 10, 0.0, iColor, 0);
    TE_SendToClient(iClient);

    AddVectors(fEnd, Float:{-16.0, -16.0, 0.0}, fPoint1);
    AddVectors(fEnd, Float:{16.0, -16.0, 0.0}, fPoint2);
    TE_SetupBeamPoints(fPoint1, fPoint2, g_Sprite, 0, 0, 0, fDrawTime, 2.0, 2.0, 10, 0.0, iColor, 0);
    TE_SendToClient(iClient);

    AddVectors(fEnd, Float:{16.0, 16.0, 0.0}, fPoint1);
    AddVectors(fEnd, Float:{-16.0, 16.0, 0.0}, fPoint2);
    TE_SetupBeamPoints(fPoint1, fPoint2, g_Sprite, 0, 0, 0, fDrawTime, 2.0, 2.0, 10, 0.0, iColor, 0);
    TE_SendToClient(iClient);

    AddVectors(fEnd, Float:{16.0, 16.0, 0.0}, fPoint1);
    AddVectors(fEnd, Float:{16.0, -16.0, 0.0}, fPoint2);
    TE_SetupBeamPoints(fPoint1, fPoint2, g_Sprite, 0, 0, 0, fDrawTime, 2.0, 2.0, 10, 0.0, iColor, 0);
    TE_SendToClient(iClient);

    //PrintToChat(iClient, "%f %f %f", fEnd[0], fEnd[1], fEnd[2]);
}

public bool:TraceFilter_DontHitPlayers(iEnt, iMask, any:iData)
{
	if(1 <= iEnt <= MaxClients)
		return false;
	
	return true;
}