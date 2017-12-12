#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Bhop Cap";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Adds a speed cap to bunny hopping.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define MAX_RUN_SPEED	260.0

new Handle:cvar_bhop_hard_cap_speed;
new Handle:cvar_bhop_soft_cap_percent;
new Handle:cvar_bhop_soft_cap_reducer_percent;

#define CAP_TIME	0.1
new Float:g_fUncapTime[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("bhop_cap_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_bhop_hard_cap_speed = CreateConVar("bhop_hard_cap_speed", "500.0", "The hard cap to apply to jumping.");
	cvar_bhop_soft_cap_percent = CreateConVar("bhop_soft_cap_percent", "0.7", "The percent of the hard cap to use as the soft cap.");
	cvar_bhop_soft_cap_reducer_percent = CreateConVar("bhop_soft_cap_reducer_percent", "0.04", "The percent to reduce the difference between the current speed and soft cap.");
	
	HookEvent("player_jump", Event_PlayerJump_Post, EventHookMode_Post);
}

public Action:Event_PlayerJump_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!(1 <= iClient <= MaxClients))
		return;
	
	if(!IsClientInGame(iClient))
		return;
	
	g_fUncapTime[iClient] = GetEngineTime() + CAP_TIME;
	TryCapSpeed(iClient);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_PreThink, OnPreThink);
}

public OnPreThink(iClient)
{
	if(!IsPlayerAlive(iClient))
		return;
	
	TryCapSpeed(iClient);
}

TryCapSpeed(iClient)
{
	if(g_fUncapTime[iClient] < GetEngineTime())
		return;
	
	static Float:fHardCap;
	fHardCap = GetConVarFloat(cvar_bhop_hard_cap_speed);
	
	if(fHardCap <= 0.0)
	{
		TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
		return;
	}
	
	static Float:fVelocity[3], Float:fVerticalVelocity, Float:fSpeed;
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	fVerticalVelocity = fVelocity[2];
	fVelocity[2] = 0.0;
	
	fSpeed = GetVectorLength(fVelocity);
	
	static Float:fSoftCap;
	fSoftCap = fHardCap * GetConVarFloat(cvar_bhop_soft_cap_percent);
	
	if(fSoftCap < MAX_RUN_SPEED)
		fSoftCap = MAX_RUN_SPEED;
	
	if(fSpeed <= fSoftCap)
		return;
	
	static Float:fPercent[2];
	fPercent[0] = fVelocity[0] / fSpeed;
	fPercent[1] = fVelocity[1] / fSpeed;
	
	// Apply the softcap. Go X% slower than the difference between the current speed and soft cap. Clamp at the soft cap.
	static Float:fReduceSpeed;
	fReduceSpeed = ((fSpeed - fSoftCap) * GetConVarFloat(cvar_bhop_soft_cap_reducer_percent));
	fVelocity[0] -= (fReduceSpeed * fPercent[0]);
	fVelocity[1] -= (fReduceSpeed * fPercent[1]);
	
	// Apply the hardcap if needed.
	if(GetVectorLength(fVelocity) > fHardCap)
	{
		fVelocity[0] = fHardCap * fPercent[0];
		fVelocity[1] = fHardCap * fPercent[1];
	}
	
	fVelocity[2] = fVerticalVelocity; // Don't cap vertical velocity.
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, fVelocity);
}