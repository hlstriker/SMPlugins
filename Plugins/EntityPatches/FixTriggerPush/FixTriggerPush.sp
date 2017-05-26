#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>

#undef REQUIRE_PLUGIN
#include "../../../Libraries/EntityHooker/entity_hooker"
#include "../../../Mods/SpeedRuns/Includes/speed_runs"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Fix Trigger Push";
new const String:PLUGIN_VERSION[] = "2.14";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Fixes the trigger_push entity.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define WAIT_TIME_AFTER_END_TOUCH	10.0

#define ENTITY_LIMIT	4096
new Float:g_fNextTriggerTouch[MAXPLAYERS+1][ENTITY_LIMIT+1];
new bool:g_bIsCooldownDisabled[ENTITY_LIMIT+1];
new bool:g_bIsEmulationDisabled[ENTITY_LIMIT+1];

new Float:g_fStartTouchTime[MAXPLAYERS+1][ENTITY_LIMIT+1];

new Handle:g_aCooldownRefs[MAXPLAYERS+1];
new g_iStageFailedTick[MAXPLAYERS+1];

new Float:g_fBaseVelocity[MAXPLAYERS+1][3];

new Handle:cvar_trigger_push_enable_cooldowns;
new Handle:cvar_trigger_push_emulate_first_ms;

#if defined _entity_hooker_included
new bool:g_bLibLoaded_EntityHooker;
#endif


public OnPluginStart()
{
	CreateConVar("fix_trigger_push_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_trigger_push_enable_cooldowns = CreateConVar("sv_trigger_push_enable_cooldowns", "1", "1: Enabled -- 0: Disabled", _, true, 0.0, true, 1.0);
	
	// Set to 0 to fix some minigame maps that use the trigger_push to give weapons. Any emulation causes the weapons to be created unlimited times.
	cvar_trigger_push_emulate_first_ms = CreateConVar("sv_trigger_push_emulate_first_ms", "1", "1: Yes -- 0: No", _, true, 0.0, true, 1.0);
	
	for(new iClient=1; iClient<sizeof(g_aCooldownRefs); iClient++)
		g_aCooldownRefs[iClient] = CreateArray();
	
	HookEvent("round_start", Event_RoundStart_Post, EventHookMode_PostNoCopy);
}

#if defined _entity_hooker_included
public OnAllPluginsLoaded()
{
	g_bLibLoaded_EntityHooker = LibraryExists("entity_hooker");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "entity_hooker"))
	{
		g_bLibLoaded_EntityHooker = true;
	}
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "entity_hooker"))
	{
		g_bLibLoaded_EntityHooker = false;
	}
}
#endif

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("fix_trigger_push");
	CreateNative("TriggerPush_ResetCooldowns", _TriggerPush_ResetCooldowns);
	
	return APLRes_Success;
}

public _TriggerPush_ResetCooldowns(Handle:hPlugin, iNumParams)
{
	ResetCooldowns(GetNativeCell(1));
}

ResetCooldowns(iClient)
{
	decl iEnt;
	new iArraySize = GetArraySize(g_aCooldownRefs[iClient]);
	for(new i=0; i<iArraySize; i++)
	{
		iEnt = EntRefToEntIndex(GetArrayCell(g_aCooldownRefs[iClient], i));
		if(iEnt < 1)
			continue;
		
		g_fNextTriggerTouch[iClient][iEnt] = 0.0;
	}
	
	ClearArray(g_aCooldownRefs[iClient]);
}

public OnMapStart()
{
	FindEntitiesToHook();
}

public Action:Event_RoundStart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		ResetCooldowns(iClient);
	
	FindEntitiesToHook();
}

FindEntitiesToHook()
{
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "trigger_push")) != -1)
	{
		#if defined _entity_hooker_included
		if(g_bLibLoaded_EntityHooker)
		{
			if(EntityHooker_IsEntityHooked(EH_TYPE_TRIGGER_PUSH_NO_COOLDOWN, iEnt))
			{
				g_bIsCooldownDisabled[iEnt] = true;
			}
			else
			{
				g_bIsCooldownDisabled[iEnt] = false;
			}
			
			if(EntityHooker_IsEntityHooked(EH_TYPE_TRIGGER_PUSH_NO_EMULATION, iEnt))
			{
				g_bIsEmulationDisabled[iEnt] = true;
			}
			else
			{
				g_bIsEmulationDisabled[iEnt] = false;
			}
		}
		else
		{
			g_bIsCooldownDisabled[iEnt] = false;
			g_bIsEmulationDisabled[iEnt] = false;
		}
		#else
		g_bIsCooldownDisabled[iEnt] = false;
		g_bIsEmulationDisabled[iEnt] = false;
		#endif
		
		// Hook OnTouch no matter what since we need to fix the CS:GO trigger_push issue.
		SDKHook(iEnt, SDKHook_Touch, OnTouch);
		SDKHook(iEnt, SDKHook_StartTouch, OnStartTouch);
		SDKHook(iEnt, SDKHook_EndTouchPost, OnEndTouchPost);
	}
}

#if defined _entity_hooker_included
public EntityHooker_OnRegisterReady()
{
	if(GetConVarBool(cvar_trigger_push_enable_cooldowns))
	{
		EntityHooker_Register(EH_TYPE_TRIGGER_PUSH_NO_COOLDOWN, "trigger_push disable cooldowns", "trigger_push");
		EntityHooker_RegisterProperty(EH_TYPE_TRIGGER_PUSH_NO_COOLDOWN, Prop_Data, PropField_Float, "m_flSpeed");
	}
	
	EntityHooker_Register(EH_TYPE_TRIGGER_PUSH_NO_EMULATION, "trigger_push disable emulation", "trigger_push");
	EntityHooker_RegisterProperty(EH_TYPE_TRIGGER_PUSH_NO_EMULATION, Prop_Data, PropField_Float, "m_flSpeed");
}

public EntityHooker_OnEntityHooked(iHookType, iEnt)
{
	if(iHookType == EH_TYPE_TRIGGER_PUSH_NO_COOLDOWN)
	{
		g_bIsCooldownDisabled[iEnt] = true;
	}
	else if(iHookType == EH_TYPE_TRIGGER_PUSH_NO_EMULATION)
	{
		g_bIsEmulationDisabled[iEnt] = true;
	}
}

public EntityHooker_OnEntityUnhooked(iHookType, iEnt)
{
	if(iHookType == EH_TYPE_TRIGGER_PUSH_NO_COOLDOWN)
	{
		g_bIsCooldownDisabled[iEnt] = false;
	}
	else if(iHookType == EH_TYPE_TRIGGER_PUSH_NO_EMULATION)
	{
		g_bIsEmulationDisabled[iEnt] = false;
	}
}
#endif

public OnClientDisconnect_Post(iClient)
{
	g_iStageFailedTick[iClient] = 0;
}

#if defined _speed_runs_included
public SpeedRuns_OnStageFailed(iClient, iOldStage, iNewStage)
{
	g_iStageFailedTick[iClient] = GetGameTickCount();
}
#endif

AngleMatrixPosition(const Float:fAngles[3], const Float:fPosition[3], Float:fMatrix3x4[3][4])
{
	AngleMatrix(fAngles, fMatrix3x4);
	MatrixSetColumn(fPosition, 3, fMatrix3x4);
}

MatrixSetColumn(const Float:fIn[3], iColumn, Float:fMatrix3x4[3][4])
{
	fMatrix3x4[0][iColumn] = fIn[0];
	fMatrix3x4[1][iColumn] = fIn[1];
	fMatrix3x4[2][iColumn] = fIn[2];
}

AngleMatrix(const Float:fAngles[3], Float:fMatrix3x4[3][4])
{
	static Float:sr, Float:sp, Float:sy, Float:cr, Float:cp, Float:cy;
	SinCos(DegToRad(fAngles[0]), sp, cp);
	SinCos(DegToRad(fAngles[1]), sy, cy);
	SinCos(DegToRad(fAngles[2]), sr, cr);
	
	fMatrix3x4[0][0] = cp*cy;
	fMatrix3x4[1][0] = cp*sy;
	fMatrix3x4[2][0] = -sp;
	
	static Float:crcy, Float:crsy, Float:srcy, Float:srsy;
	crcy = cr*cy;
	crsy = cr*sy;
	srcy = sr*cy;
	srsy = sr*sy;
	fMatrix3x4[0][1] = sp*srcy-crsy;
	fMatrix3x4[1][1] = sp*srsy+crcy;
	fMatrix3x4[2][1] = sr*cp;
	
	fMatrix3x4[0][2] = (sp*crcy+srsy);
	fMatrix3x4[1][2] = (sp*crsy-srcy);
	fMatrix3x4[2][2] = cr*cp;
	
	fMatrix3x4[0][3] = 0.0;
	fMatrix3x4[1][3] = 0.0;
	fMatrix3x4[2][3] = 0.0;
}

SinCos(const Float:fRadians, &Float:fSine, &Float:fCosine)
{
	fSine = Sine(fRadians);
	fCosine = Cosine(fRadians);
}

EntityToWorldTransform(iEnt, Float:fRgflCoordinateFrame[3][4])
{
	static Float:fAngles[3], Float:fOrigin[3];
	GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
	
	AngleMatrixPosition(fAngles, fOrigin, fRgflCoordinateFrame);
	
	// TODO: Concatenate with our parent's transform.
	//CBaseEntity *pMoveParent = GetMoveParent();
	//if ( !pMoveParent )
	//	return;
	//matrix3x4_t tmpMatrix, scratchSpace;
	//ConcatTransforms( GetParentToWorldTransform( scratchSpace ), m_rgflCoordinateFrame, tmpMatrix );
	//MatrixCopy( tmpMatrix, m_rgflCoordinateFrame );
}

Float:DotProduct(const Float:v1[3], const Float:v2[4])
{
	return v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2];
}

VectorRotate(const Float:fIn[3], const Float:fMatrix3x4[3][4], Float:fOut[3])
{
	fOut[0] = DotProduct(fIn, fMatrix3x4[0]);
	fOut[1] = DotProduct(fIn, fMatrix3x4[1]);
	fOut[2] = DotProduct(fIn, fMatrix3x4[2]);
}

public Action:OnTouch(iEnt, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Continue;
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(!GetConVarBool(cvar_trigger_push_enable_cooldowns))
	{
		// Note: Always emulate the first miliseconds of touching no matter what to get the player in the air if needed.
		if(!g_bIsEmulationDisabled[iEnt] || (g_fStartTouchTime[iOther][iEnt] + 0.1 > fCurTime && GetConVarBool(cvar_trigger_push_emulate_first_ms)))
		{
			EmulatePush(iOther, iEnt);
			return Plugin_Handled;
		}
		
		return Plugin_Continue;
	}
	
	#if defined _entity_hooker_included
	if(g_bLibLoaded_EntityHooker)
	{
		if(!g_bIsCooldownDisabled[iEnt] && g_fNextTriggerTouch[iOther][iEnt] > fCurTime)
		{
			g_fNextTriggerTouch[iOther][iEnt] = fCurTime + 60.0; // Don't let the player touch the trigger again until their endtouch cooldown expires (or a minute passes).
			return Plugin_Handled;
		}
	}
	#endif
	
	// Note: Always emulate the first miliseconds of touching no matter what to get the player in the air if needed.
	if(!g_bIsEmulationDisabled[iEnt] || (g_fStartTouchTime[iOther][iEnt] + 0.1 > fCurTime && GetConVarBool(cvar_trigger_push_emulate_first_ms)))
	{
		EmulatePush(iOther, iEnt);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:OnStartTouch(iEnt, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Continue;
	
	g_fStartTouchTime[iOther][iEnt] = GetEngineTime();
	
	if(!GetConVarBool(cvar_trigger_push_enable_cooldowns))
		return Plugin_Continue;
	
	if(!g_bIsCooldownDisabled[iEnt])
	{
		static Float:fCurTime;
		fCurTime = GetEngineTime();
		
		if(g_fNextTriggerTouch[iOther][iEnt] > fCurTime)
		{
			g_fNextTriggerTouch[iOther][iEnt] = fCurTime + 60.0; // Don't let the player touch the trigger again until their endtouch cooldown expires (or a minute passes).
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public OnEndTouchPost(iEnt, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return;
	
	if(!GetConVarBool(cvar_trigger_push_enable_cooldowns))
		return;
	
	if(!g_bIsCooldownDisabled[iEnt])
	{
		// Don't allow a player to add any trigger_pushes to the cooldown array on the same frame they failed a stage.
		// This is because a start zone's OnStartTouch can be called before this push's OnEndTouchPost if the player teleports into the start zone while still in a push.
		// This would effectively readd that push's cooldown right after it was reset from failing the stage.
		if(g_iStageFailedTick[iOther] == GetGameTickCount())
			return;
		
		g_fNextTriggerTouch[iOther][iEnt] = GetEngineTime() + WAIT_TIME_AFTER_END_TOUCH;
		
		new iEntRef = EntIndexToEntRef(iEnt);
		if(FindValueInArray(g_aCooldownRefs[iOther], iEntRef) == -1)
			PushArrayCell(g_aCooldownRefs[iOther], iEntRef);
	}
}

EmulatePush(iClient, iPush)
{
	if(GetEntityMoveType(iClient) == MOVETYPE_NOCLIP)
		return;
	
	if(GetEntPropEnt(iClient, Prop_Data, "m_hMoveParent") != -1)
		return;
	
	if(!PassesTriggerFilters(iClient, iPush))
		return;
	
	static Float:fPushDir[3];
	GetEntPropVector(iPush, Prop_Data, "m_vecPushDir", fPushDir);
	
	static Float:fRgflCoordinateFrame[3][4], Float:fAbsDir[3];
	EntityToWorldTransform(iPush, fRgflCoordinateFrame);
	VectorRotate(fPushDir, fRgflCoordinateFrame, fAbsDir);
	
	new Float:fSpeed = GetEntPropFloat(iPush, Prop_Data, "m_flSpeed");
	ScaleVector(fAbsDir, fSpeed);
	
	new iFlags = GetEntityFlags(iClient);
	
	//PrintToServer("Emulating - %s", (iFlags & FL_ONGROUND) ? "ON GROUND" : "OFF GROUND");
	
	//if(FloatAbs(fAbsDir[0]) < 0.01 && FloatAbs(fAbsDir[1]) < 0.01 && (iFlags & FL_ONGROUND) && !(GetClientButtons(iClient) & IN_JUMP))
	//	return;
	
	// NOTE: Comment this block out if we want the behavior where the player has to jump to start being pushed (has side effects on maps like iceskate mg_galaxy).
	if(fAbsDir[2] > 0.0 && (iFlags & FL_ONGROUND))
	{
		SetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity", -1);
		iFlags &= ~FL_ONGROUND;
		
		// WARNING: The following code was getting players stuck in ceilings, plus it doesn't seem to be needed.
		decl Float:fOrigin[3];
		GetClientAbsOrigin(iClient, fOrigin);
		fOrigin[2] += 2.0;
		TeleportEntity(iClient, fOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	
	// Set vertical velocity using m_vecVelocity.
	static Float:fVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	
	fVelocity[2] += (fAbsDir[2] * GetTickInterval());
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fVelocity);
	
	// Set horizontal velocity using m_vecBaseVelocity.
	fAbsDir[2] = 0.0;
	
	// m_vecBaseVelocity always seems to return 0 even if there is basevelocity set.
	// Because of this we need to use a custom variable to store the basevelocity incase the player is inside multiple pushes at once.
	// We can determine when our basevelocity variable needs reset since the game will clear the FL_BASEVELOCITY flag for us after it's applied.
	if(!(iFlags & FL_BASEVELOCITY))
	{
		g_fBaseVelocity[iClient][0] = 0.0;
		g_fBaseVelocity[iClient][1] = 0.0;
		g_fBaseVelocity[iClient][2] = 0.0;
	}
	
	AddVectors(fAbsDir, g_fBaseVelocity[iClient], g_fBaseVelocity[iClient]);
	
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", g_fBaseVelocity[iClient]);
	SetEntityFlags(iClient, iFlags | FL_BASEVELOCITY);
}

#define SF_TRIGGER_ALLOW_CLIENTS				1
#define SF_TRIGGER_ALLOW_NPCS					2
#define SF_TRIGGER_ALLOW_PUSHABLES				4
#define SF_TRIGGER_ALLOW_PHYSICS				8
#define SF_TRIGGER_ONLY_CLIENTS_IN_VEHICLES		32
#define SF_TRIGGER_ALLOW_ALL					64
#define SF_TRIGGER_ONLY_CLIENTS_OUT_OF_VEHICLES	512
#define SF_TRIGGER_DISALLOW_BOTS				4096

bool:PassesTriggerFilters(iCheckEnt, iTrigger)
{
	static iSpawnFlags, iFlags;
	iSpawnFlags = GetEntProp(iTrigger, Prop_Data, "m_spawnflags");
	iFlags = GetEntityFlags(iCheckEnt);
	
	if((iSpawnFlags & SF_TRIGGER_ALLOW_ALL)
	|| ((iSpawnFlags & SF_TRIGGER_ALLOW_CLIENTS) && (iFlags & FL_CLIENT))
	|| ((iSpawnFlags & SF_TRIGGER_ALLOW_NPCS) && (iFlags & FL_NPC))
	|| ((iSpawnFlags & SF_TRIGGER_ALLOW_PHYSICS) && GetEntityMoveType(iCheckEnt) == MOVETYPE_VPHYSICS))
	{
		if(iFlags & FL_NPC)
		{
			// TODO: NPC checks.
			// -->
		}
		
		if(1 <= iCheckEnt <= MaxClients)
		{
			if(!IsPlayerAlive(iCheckEnt))
				return false;
			
			if((iSpawnFlags & SF_TRIGGER_ONLY_CLIENTS_IN_VEHICLES) && !IsInAVehicle(iCheckEnt))
				return false;
			
			if((iSpawnFlags & SF_TRIGGER_ONLY_CLIENTS_OUT_OF_VEHICLES) && IsInAVehicle(iCheckEnt))
				return false;
			
			if((iSpawnFlags & SF_TRIGGER_DISALLOW_BOTS) && IsFakeClient(iCheckEnt))
				return false;
		}
		
		return PassesFilters(iCheckEnt, iTrigger);
	}
	
	if(iSpawnFlags & SF_TRIGGER_ALLOW_PUSHABLES)
	{
		static String:szClassName[14];
		GetEntityClassname(iCheckEnt, szClassName, sizeof(szClassName));
		if(StrEqual(szClassName, "func_pushable"))
			return PassesFilters(iCheckEnt, iTrigger);
	}
	
	return false;
}

bool:IsInAVehicle(iClient)
{
	return (GetEntPropEnt(iClient, Prop_Data, "m_hVehicle") != -1);
}

bool:PassesFilters(iCheckEnt, iTrigger)
{
	static String:szFilterEntsTargetName[64];
	GetEntPropString(iTrigger, Prop_Data, "m_iFilterName", szFilterEntsTargetName, sizeof(szFilterEntsTargetName));
	
	if(StrEqual(szFilterEntsTargetName, ""))
		return true;
	
	if(!PassesFilterByTeam(iCheckEnt, szFilterEntsTargetName))
		return false;
	
	if(!PassesFilterByName(iCheckEnt, szFilterEntsTargetName))
		return false;
	
	if(!PassesFilterByClass(iCheckEnt, szFilterEntsTargetName))
		return false;
	
	return true;
}

bool:PassesFilterByTeam(iCheckEnt, const String:szFilterEntsTargetName[])
{
	new iFilterEnt = -1;
	static String:szBuffer[64];
	while((iFilterEnt = FindEntityByClassname(iFilterEnt, "filter_activator_team")) != -1)
	{
		GetEntPropString(iFilterEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		
		if(StrEqual(szBuffer, szFilterEntsTargetName))
			break;
	}
	
	if(iFilterEnt == -1)
		return true;
	
	new iCheckEntTeamNum = GetEntProp(iCheckEnt, Prop_Send, "m_iTeamNum");
	new iFilterTeamNum = GetEntProp(iFilterEnt, Prop_Data, "m_iFilterTeam");
	
	if(GetEntProp(iFilterEnt, Prop_Data, "m_bNegated"))
		return (iCheckEntTeamNum != iFilterTeamNum);
	
	return (iCheckEntTeamNum == iFilterTeamNum);
}

bool:PassesFilterByName(iCheckEnt, const String:szFilterEntsTargetName[])
{
	new iFilterEnt = -1;
	static String:szBuffer[64];
	while((iFilterEnt = FindEntityByClassname(iFilterEnt, "filter_activator_name")) != -1)
	{
		GetEntPropString(iFilterEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		
		if(StrEqual(szBuffer, szFilterEntsTargetName))
			break;
	}
	
	if(iFilterEnt == -1)
		return true;
	
	GetEntPropString(iFilterEnt, Prop_Data, "m_iFilterName", szBuffer, sizeof(szBuffer));
	
	// Special check for !player since m_iName on a player won't return "!player" as the name.
	if(StrEqual(szBuffer, "!player"))
		return (1 <= iCheckEnt <= MaxClients);
	
	static String:szCheckEntTargetName[64];
	GetEntPropString(iCheckEnt, Prop_Data, "m_iName", szCheckEntTargetName, sizeof(szCheckEntTargetName));
	
	if(GetEntProp(iFilterEnt, Prop_Data, "m_bNegated"))
		return (!StrEqual(szBuffer, szCheckEntTargetName));
	
	return StrEqual(szBuffer, szCheckEntTargetName);
}

bool:PassesFilterByClass(iCheckEnt, const String:szFilterEntsTargetName[])
{
	new iFilterEnt = -1;
	static String:szBuffer[64];
	while((iFilterEnt = FindEntityByClassname(iFilterEnt, "filter_activator_class")) != -1)
	{
		GetEntPropString(iFilterEnt, Prop_Data, "m_iName", szBuffer, sizeof(szBuffer));
		
		if(StrEqual(szBuffer, szFilterEntsTargetName))
			break;
	}
	
	if(iFilterEnt == -1)
		return true;
	
	GetEntPropString(iFilterEnt, Prop_Data, "m_iFilterClass", szBuffer, sizeof(szBuffer));
	
	static String:szCheckEntClassName[64];
	GetEntPropString(iCheckEnt, Prop_Data, "m_iClassname", szCheckEntClassName, sizeof(szCheckEntClassName));
	
	if(GetEntProp(iFilterEnt, Prop_Data, "m_bNegated"))
		return (!StrEqual(szBuffer, szCheckEntClassName));
	
	return StrEqual(szBuffer, szCheckEntClassName);
}