#include <sourcemod>
#include <sdkhooks>
#include <sdktools_sound>
#include <emitsoundany>
#include <sdktools_stringtables>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Jetpacks";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Lets users fly around with jetpacks",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define IN_JUMP_FAKE	(1 << 31)

new const Float:JETPACK_BURST_RATE = 0.05;
new const Float:JETPACK_BURST_MAX_SPEED = 200.0;
new const Float:JETPACK_TIME_WAIT_AFTER_JUMP = 0.2;
new const Float:JETPACK_FALL_RECOVERY_PERCENT = 0.3; // Default 30%. Increase the percent to recover faster.

new const Float:JETPACK_ACTIVE_TIME = 4.0;
new const Float:JETPACK_COOLDOWN_TIME = 8.0;

new Float:g_fNextActiveEnd[MAXPLAYERS+1];
new Float:g_fNextCooldownEnd[MAXPLAYERS+1];
new bool:g_bHasCooldownReset[MAXPLAYERS+1];

new Float:g_fNextBurst[MAXPLAYERS+1];
new bool:g_bUsingJetpack[MAXPLAYERS+1];

new const String:JETPACK_SOUND[] = "sound/swoobles/jetpack/jetpack_v1.mp3";


public OnPluginStart()
{
	CreateConVar("hls_jetpack_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnMapStart()
{
	AddFileToDownloadsTable(JETPACK_SOUND);
	PrecacheSoundAny(JETPACK_SOUND[6]);
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVel[3], Float:fAngles[3], &iWeapon)
{
	if(!IsPlayerAlive(iClient))
		return CheckCancelJetpack(iClient);
	
	if((!(iButtons & IN_JUMP) && !(iButtons & IN_JUMP_FAKE)) || !(iButtons & IN_DUCK))
		return CheckCancelJetpack(iClient);
	
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(GetEntPropEnt(iClient, Prop_Send, "m_hGroundEntity") != -1)
	{
		g_fNextBurst[iClient] = fCurTime + JETPACK_TIME_WAIT_AFTER_JUMP;
		return CheckCancelJetpack(iClient);
	}
	
	// Calling GetClientButtons() in the OnPlayerRunCmd() function will return the clients old button mask.
	static iOldButtons;
	iOldButtons = GetClientButtons(iClient);
	if((!(iOldButtons & IN_JUMP) && !(iOldButtons & IN_JUMP_FAKE)) || !(iOldButtons & IN_DUCK))
		return CheckCancelJetpack(iClient);
	
	if(g_fNextActiveEnd[iClient] <= fCurTime)
	{
		CheckCancelJetpack(iClient);
		
		if(g_fNextCooldownEnd[iClient] > fCurTime)
			return Plugin_Continue;
		
		g_bHasCooldownReset[iClient] = true;
	}
	
	if(g_fNextBurst[iClient] > fCurTime)
		return Plugin_Continue;
	
	JetpackBurst(iClient);
	JetpackSound(iClient);
	
	if(g_bHasCooldownReset[iClient])
	{
		g_bHasCooldownReset[iClient] = false;
		g_fNextActiveEnd[iClient] = fCurTime + JETPACK_ACTIVE_TIME;
		g_fNextCooldownEnd[iClient] = fCurTime + JETPACK_COOLDOWN_TIME;
	}
	
	g_bUsingJetpack[iClient] = true;
	g_fNextBurst[iClient] = fCurTime + JETPACK_BURST_RATE;
	
	return Plugin_Continue;
}

JetpackBurst(iClient)
{
	static Float:fVelocity[3], Float:fBaseVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	GetEntPropVector(iClient, Prop_Send, "m_vecBaseVelocity", fBaseVelocity);
	
	// Check if the players current velocity is below the minimum burst speed.
	if(fVelocity[2] < 0)
	{
		// Start the base velocity at a percent of their current velocity.
		fBaseVelocity[2] = (fVelocity[2] / 2) + FloatAbs(fVelocity[2] * JETPACK_FALL_RECOVERY_PERCENT);
	}
	else
	{
		// Negate the players velocity.
		fBaseVelocity[2] = (fVelocity[2] * -1);
	}
	
	fBaseVelocity[2] += JETPACK_BURST_MAX_SPEED;
	SetEntPropVector(iClient, Prop_Send, "m_vecBaseVelocity", fBaseVelocity);
}

JetpackSound(iClient)
{
	if(!g_bUsingJetpack[iClient])
		EmitSoundToAllAny(JETPACK_SOUND[6], iClient, SNDCHAN_BODY, SNDLEVEL_SCREAMING, SND_NOFLAGS);
}

Action:CheckCancelJetpack(iClient)
{
	if(!g_bUsingJetpack[iClient])
		return Plugin_Continue;
	
	EmitSoundToAllAny(JETPACK_SOUND[6], iClient, SNDCHAN_BODY, SNDLEVEL_SCREAMING, SND_STOP | SND_STOPLOOPING);
	g_bUsingJetpack[iClient] = false;
	
	return Plugin_Continue;
}