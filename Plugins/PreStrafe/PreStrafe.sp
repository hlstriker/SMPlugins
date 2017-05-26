/*
* Most of the code was taken directly or rewritten from the KZTimer plugin to maintain a standard:
* https://github.com/1NutWunDeR/KZTimerOffical/blob/0fc829a3b17903f9304c6760fd5c3be65c68c2eb/addons/sourcemod/scripting/kztimer/hooks.sp
*/

// NOTE: Prestrafe interferes with the no landing cap.
// NOTE: Servers sv_accelerate should be about 6.5

#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "PreStrafe";
new const String:PLUGIN_VERSION[] = "1.6";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Prestrafing.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

// Note: The goal is to get 250 max speed.
#define VELMOD_DEFAULT_WPN260			0.9615384638
#define VELMOD_DEFAULT_WPN250			1.0
#define VELMOD_DEFAULT_WPN240			1.04166669
#define VELMOD_DEFAULT_WPN230			1.0869564415
#define VELMOD_DEFAULT_WPN220			1.136363567
#define VELMOD_DEFAULT_WPN215			1.162790715695
#define VELMOD_DEFAULT_WPN195			1.314925014973

// Note: The goal is to get 276 max speed.
#define VELMOD_MAX_WPN260				1.0615384
#define VELMOD_MAX_WPN250				1.104
#define VELMOD_MAX_WPN240				1.15
#define VELMOD_MAX_WPN230				1.2
#define VELMOD_MAX_WPN220				1.2545454
// TODO: -->
#define VELMOD_MAX_WPN215				1.0
#define VELMOD_MAX_WPN195				1.0

// Note: The goal is to get 260 max speed.
#define VELMOD_NEEDED_FOR_TURBO_WPN260	1.0
#define VELMOD_NEEDED_FOR_TURBO_WPN250	1.04
#define VELMOD_NEEDED_FOR_TURBO_WPN240	1.08333333
#define VELMOD_NEEDED_FOR_TURBO_WPN230	1.130434692
#define VELMOD_NEEDED_FOR_TURBO_WPN220	1.181818069
// TODO: -->
#define VELMOD_NEEDED_FOR_TURBO_WPN215	5.0
#define VELMOD_NEEDED_FOR_TURBO_WPN195	5.0

enum LookDirection
{
	LOOK_DIR_NONE = 0,
	LOOK_DIR_RIGHT,
	LOOK_DIR_LEFT
};

enum MoveDirection
{
	MOVE_DIR_FORWARD = 0,
	MOVE_DIR_BACKWARD,
	MOVE_DIR_RIGHT,
	MOVE_DIR_LEFT
};

#define TICKRATE_64		64
#define TICKRATE_102	102
#define TICKRATE_128	128

new g_iServerTickrate;

new Handle:cvar_default_modifiers_only;

//#define DEBUG_PRESTRAFE
#if defined DEBUG_PRESTRAFE
new Handle:cvar_prestrafe_test_modifier;
#endif

public OnPluginStart()
{
	CreateConVar("prestrafe_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_default_modifiers_only = CreateConVar("prestrafe_default_modifiers_only", "0", "0: Use prestrafing -- 1: Use default modifiers which only allows 250 speed on any weapon.", _, true, 0.0, true, 1.0);
	
	new Float:fTickrate = 1.0 / GetTickInterval();
	if(fTickrate > 65.0)
	{
		if(fTickrate < 103.0)
			g_iServerTickrate = TICKRATE_102;
		else
			g_iServerTickrate = TICKRATE_128;
	}
	else
	{
		g_iServerTickrate = TICKRATE_64;
	}
	
#if defined DEBUG_PRESTRAFE
	cvar_prestrafe_test_modifier = CreateConVar("prestrafe_test_modifier", "1.0");
#endif
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon, &iSubType, &iCmdNum, &iTickCount, &iSeed, iMouse[2])
{
	PreStrafe(iClient, fAngles, iButtons);
}

LookDirection:GetLookDirection(iClient, const Float:fAngles[3])
{
	static Float:fOldAngles[MAXPLAYERS+1][3];
	GetClientEyeAngles(iClient, fOldAngles[iClient]);
	
	if(fAngles[1] == fOldAngles[iClient][1])
	{
		return LOOK_DIR_NONE;
	}
	else if(fAngles[1] > fOldAngles[iClient][1] && fAngles[1] > 0.0 && fOldAngles[iClient][1] > 0.0)
	{
		return LOOK_DIR_LEFT;
	}
	else if(fAngles[1] > fOldAngles[iClient][1] && fAngles[1] < 0.0 && fOldAngles[iClient][1] < 0.0)
	{
		return LOOK_DIR_LEFT;
	}
	else if(fAngles[1] < fOldAngles[iClient][1] && fAngles[1] > 0.0 && fOldAngles[iClient][1] > 0.0)
	{
		return LOOK_DIR_RIGHT;
	}
	else if(fAngles[1] < fOldAngles[iClient][1] && fAngles[1] < 0.0 && fOldAngles[iClient][1] < 0.0)
	{
		return LOOK_DIR_RIGHT;
	}
	else if((fOldAngles[iClient][1] > 135.0 && fOldAngles[iClient][1] > 0.0 && fAngles[1] < -135.0)
	|| (fOldAngles[iClient][1] > -45.0 && fOldAngles[iClient][1] < 0.0 && fAngles[1] < 45.0))
	{
		return LOOK_DIR_LEFT;
	}
	else if((fOldAngles[iClient][1] < 45.0 && fOldAngles[iClient][1] > 0.0 && fAngles[1] > -45.0)
	|| (fOldAngles[iClient][1] < -135.0 && fOldAngles[iClient][1] < 0.0 && fAngles[1] > 135.0))
	{
		return LOOK_DIR_RIGHT;
	}
	
	return LOOK_DIR_NONE;
}

bool:GetCurrentWeaponModifierData(iClient, &Float:fDefaultModifier, &Float:fMaxModifier, &Float:fNeededForTurbo)
{
	static iWeapon;
	iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iWeapon == -1)
	{
		fDefaultModifier = VELMOD_DEFAULT_WPN260;
		fMaxModifier = VELMOD_MAX_WPN260;
		fNeededForTurbo = VELMOD_NEEDED_FOR_TURBO_WPN260;
		return true;
	}
	
	static String:szClassName[48];
	GetEntityClassname(iWeapon, szClassName, sizeof(szClassName));
	
	//PrintToServer("[%s] - %i", szClassName[7], iWeapon);
	
	static iSavedChar;
	iSavedChar = szClassName[12];
	szClassName[12] = 0x00;
	
	if(StrEqual(szClassName[7], "knife")
	|| StrEqual(szClassName[7], "c4"))
	{
		fDefaultModifier = VELMOD_DEFAULT_WPN250;
		fMaxModifier = VELMOD_MAX_WPN250;
		fNeededForTurbo = VELMOD_NEEDED_FOR_TURBO_WPN250;
		return true;
	}
	
	szClassName[12] = iSavedChar;
	
	if(StrEqual(szClassName[7], "hkp2000")
	|| StrEqual(szClassName[7], "glock")
	|| StrEqual(szClassName[7], "elite")
	|| StrEqual(szClassName[7], "tec9")
	|| StrEqual(szClassName[7], "p250")
	|| StrEqual(szClassName[7], "fiveseven"))
	{
		fDefaultModifier = VELMOD_DEFAULT_WPN240;
		fMaxModifier = VELMOD_MAX_WPN240;
		fNeededForTurbo = VELMOD_NEEDED_FOR_TURBO_WPN240;
		return true;
	}
	
	// Handle the deagle and revolver since they both use the weapon_deagle classname.
	if(StrEqual(szClassName[7], "deagle"))
	{
		switch(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))
		{
			// Deagle
			case 1:
			{
				fDefaultModifier = VELMOD_DEFAULT_WPN230;
				fMaxModifier = VELMOD_MAX_WPN230;
				fNeededForTurbo = VELMOD_NEEDED_FOR_TURBO_WPN230;
				return true;
			}
			
			// Revolver
			case 64:
			{
				fDefaultModifier = VELMOD_DEFAULT_WPN220;
				fMaxModifier = VELMOD_MAX_WPN220;
				fNeededForTurbo = VELMOD_NEEDED_FOR_TURBO_WPN220;
				return true;
			}
		}
	}
	
	return false;
}

Float:GetClientMovingDirection(iClient)
{
	new Float:fVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fVelocity);
	
	new Float:fEyeAngles[3];
	GetClientEyeAngles(iClient, fEyeAngles);
	
	if(fEyeAngles[0] > 70.0)
	{
		fEyeAngles[0] = 70.0;
	}
	else if(fEyeAngles[0] < -70.0)
	{
		fEyeAngles[0] = -70.0;
	}
	
	new Float:fViewDirection[3];
	GetAngleVectors(fEyeAngles, fViewDirection, NULL_VECTOR, NULL_VECTOR);
	
	NormalizeVector(fVelocity, fVelocity);
	NormalizeVector(fViewDirection, fViewDirection);
	
	return GetVectorDotProduct(fVelocity, fViewDirection);
}

#if defined DEBUG_PRESTRAFE
SetPrestrafeTestingModifier(iClient)
{
	SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", GetConVarFloat(cvar_prestrafe_test_modifier));
	
	static Float:fVelocity[3], Float:fSpeed;
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	fVelocity[2] = 0.0;
	fSpeed = GetVectorLength(fVelocity);
	
	PrintHintText(iClient, "Speed: %f", fSpeed);
	
	static iWeapon;
	iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iWeapon != -1)
	{
		static String:szClassName[48];
		GetEntityClassname(iWeapon, szClassName, sizeof(szClassName));
		PrintToServer("[%s] - %i", szClassName[7], GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"));
	}
}
#endif

PreStrafe(iClient, const Float:fAngles[3], const iButtons)
{
	if(!IsPlayerAlive(iClient))
		return;
	
#if defined DEBUG_PRESTRAFE
	SetPrestrafeTestingModifier(iClient);
	return;
#endif
	
	static Float:fDefaultModifier, Float:fMaxModifier, Float:fNeededForTurbo, Float:fOldVelocityModifier[MAXPLAYERS+1];
	if(!GetCurrentWeaponModifierData(iClient, fDefaultModifier, fMaxModifier, fNeededForTurbo))
	{
		// Could not find any modifier data for their current weapon. Set the modifier back to normal.
		SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", 1.0);
		fOldVelocityModifier[iClient] = 1.0;
		return;
	}
	
	if(GetConVarBool(cvar_default_modifiers_only))
	{
		SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", fDefaultModifier);
		fOldVelocityModifier[iClient] = fDefaultModifier;
		return;
	}
	
	if(!(GetEntityFlags(iClient) & FL_ONGROUND))
	{
		SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", fDefaultModifier);
		fOldVelocityModifier[iClient] = fDefaultModifier;
		return;
	}
	
	static LookDirection:lookDir, Float:fVelocityModifierLastChanged[MAXPLAYERS+1];
	lookDir = GetLookDirection(iClient, fAngles);
	
	// Use the default modifier if the player isn't turning their mouse.
	if(lookDir == LOOK_DIR_NONE)
	{
		if(GetEngineTime() - fVelocityModifierLastChanged[iClient] > 0.2)
		{
			SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", fDefaultModifier);
			fOldVelocityModifier[iClient] = fDefaultModifier;
			//fVelocityModifierLastChanged[iClient] = GetEngineTime();
		}
		else
		{
			// Set to the previously set modifier. If the modifer is less than 1.0 the game tries to increment by 0.6250 automatically each time it processes a command.
			SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", fOldVelocityModifier[iClient]);
		}
		
		return;
	}
	
	static iPreStrafeFrameCounter[MAXPLAYERS+1];
	static Float:fVelocity[3], Float:fSpeed;
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	fVelocity[2] = 0.0;
	fSpeed = GetVectorLength(fVelocity);
	
	// Use the default modifier if the player isn't going fast enough or isn't strafing.
	if(fSpeed < 249.0 || !((iButtons & IN_MOVERIGHT) || (iButtons & IN_MOVELEFT)))
	{
		SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", fDefaultModifier);
		fOldVelocityModifier[iClient] = fDefaultModifier;
		iPreStrafeFrameCounter[iClient] = 0;
		return;
	}
	
	// Get the speed increment and decrement values based on the servers tickrate.
	static Float:fSpeedIncrement, Float:fSpeedDecrement, iMaxFrameCount;
	switch(g_iServerTickrate)
	{
		case TICKRATE_64:
		{
			iMaxFrameCount = 45;
			fSpeedIncrement = 0.0015;
			fSpeedDecrement = 0.0045;
		}
		case TICKRATE_102:
		{
			iMaxFrameCount = 60;
			fSpeedIncrement = 0.0011;
			fSpeedDecrement = 0.0045;
		}
		case TICKRATE_128:
		{
			iMaxFrameCount = 75;
			fSpeedIncrement = 0.0009;
			fSpeedDecrement = 0.0045;
		}
		default:
		{
			SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", 1.0);
			fOldVelocityModifier[iClient] = 1.0;
			return;
		}
	}
	
	//new Float:fVelocityModifier = GetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier");
	new Float:fVelocityModifier = fOldVelocityModifier[iClient];
	
	if(fVelocityModifier > fNeededForTurbo)
		fSpeedIncrement = 0.001;
	
	static bool:bForward;
	if(GetClientMovingDirection(iClient) > 0.0)
		bForward = true;
	else
		bForward = false;
	
	if (((iButtons & IN_MOVERIGHT && (lookDir == LOOK_DIR_RIGHT) || (lookDir == LOOK_DIR_LEFT) && !bForward))
	|| ((iButtons & IN_MOVELEFT && (lookDir == LOOK_DIR_LEFT) || (lookDir == LOOK_DIR_RIGHT) && !bForward)))
	{
		iPreStrafeFrameCounter[iClient]++;
		
		if(iPreStrafeFrameCounter[iClient] < iMaxFrameCount)
		{	
			// Increase speed.
			fVelocityModifier += fSpeedIncrement;
			
			if(fVelocityModifier > fMaxModifier)
			{
				if(fVelocityModifier > fMaxModifier + 0.007)
					fVelocityModifier = fMaxModifier - 0.001;
				else
					fVelocityModifier -= 0.007;
			}
			
			fVelocityModifier += fSpeedIncrement;
		}
		else
		{
			// Decrease speed.
			fVelocityModifier -= fSpeedDecrement;
			iPreStrafeFrameCounter[iClient] -= 2;
			
			if(fVelocityModifier < fDefaultModifier)
			{
				iPreStrafeFrameCounter[iClient] = 0;
				fVelocityModifier = fDefaultModifier;
			}
		}
	}
	else
	{
		fVelocityModifier -= 0.04;
		
		if(fVelocityModifier < fDefaultModifier)
			fVelocityModifier = fDefaultModifier;
	}
	
	SetEntPropFloat(iClient, Prop_Send, "m_flVelocityModifier", fVelocityModifier);
	fVelocityModifierLastChanged[iClient] = GetEngineTime();
	fOldVelocityModifier[iClient] = fVelocityModifier;
}