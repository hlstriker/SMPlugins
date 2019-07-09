#include <sourcemod>
#include <sdkhooks>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_variant_t>
#undef REQUIRE_PLUGIN
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_player_models"
#include "../Includes/ultjb_last_guard"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Admin Xray Vision";
new const String:PLUGIN_VERSION[] = "1.4";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "The X-ray command for Ultimate Jailbreak.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define EF_BONEMERGE				(1<<0)
#define EF_NOSHADOW					(1<<4)
#define EF_NORECEIVESHADOW			(1<<6)
#define EF_BONEMERGE_FASTCULL		(1<<7)
#define EF_PARENT_ANIMATES			(1<<9)

new bool:g_bEventHooked_PlayerSpawn;
new bool:g_bEventHooked_PlayerDeath;
new bool:g_bEventHooked_PlayerTeam;

new g_iXrayModelRefs[MAXPLAYERS+1];
new bool:g_bXrayEnabled[MAXPLAYERS+1];
new g_iNumUsingXray;

new Handle:cvar_sv_force_transmit_players;
new bool:g_bOriginalForceTransmitValue;


public OnPluginStart()
{
	CreateConVar("ultjb_command_xray_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegAdminCmd("sm_xray", OnXray, ADMFLAG_BAN, "sm_xray - Allows the client to see everyones outline through walls.");
	
	cvar_sv_force_transmit_players = FindConVar("sv_force_transmit_players");
}

public Action:OnXray(iClient, iArgs)
{
	static Float:fLastUsedCommand[MAXPLAYERS+1];
	if((fLastUsedCommand[iClient] + 3.0) > GetEngineTime())
	{
		ReplyToCommand(iClient, "[SM] Please wait a few seconds before toggling xray again.");
		return Plugin_Handled;
	}
	
	fLastUsedCommand[iClient] = GetEngineTime();
	
	if(g_bXrayEnabled[iClient])
	{
		DisableXray(iClient);
		LogAction(iClient, -1, "\"%L\" toggled X-ray off", iClient);
		ReplyToCommand(iClient, "[SM] X-ray disabled.");
	}
	else
	{
		EnableXray(iClient);
		LogAction(iClient, -1, "\"%L\" toggled X-ray on", iClient);
		ReplyToCommand(iClient, "[SM] X-ray enabled.");
	}
	
	return Plugin_Handled;
}

public OnClientDisconnect(iClient)
{
	DisableXray(iClient);
}

EnableXray(iClient)
{
	if(g_bXrayEnabled[iClient])
		return;
	
	g_bXrayEnabled[iClient] = true;
	g_iNumUsingXray++;
	
	if(g_iNumUsingXray == 1)
	{
		CreateAllXrayModels();
		HookEvents();
		
		if(cvar_sv_force_transmit_players != INVALID_HANDLE)
		{
			g_bOriginalForceTransmitValue = GetConVarBool(cvar_sv_force_transmit_players);
			SetConVarBool(cvar_sv_force_transmit_players, true);
		}
	}
}

DisableXray(iClient)
{
	if(!g_bXrayEnabled[iClient])
		return;
	
	g_bXrayEnabled[iClient] = false;
	g_iNumUsingXray--;
	
	if(!g_iNumUsingXray)
	{
		RemoveAllXrayModels();
		UnhookEvents();
		
		if(cvar_sv_force_transmit_players != INVALID_HANDLE)
			SetConVarBool(cvar_sv_force_transmit_players, g_bOriginalForceTransmitValue);
	}
	else
	{
		// Recreate all xray models when someone disables xray and there are still people with xray enabled.
		// This is because the person that disabled xray will still see the glow through walls until the entity is removed.
		// However, if multiple people disable xray on the same tick (such as map ending) we only want to recreate once.
		static iLastRecreateTick;
		if(iLastRecreateTick != GetGameTickCount())
		{
			RemoveAllXrayModels();
			CreateAllXrayModels();
			iLastRecreateTick = GetGameTickCount();
		}
	}
}

HookEvents()
{
	g_bEventHooked_PlayerSpawn = HookEventEx("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
	g_bEventHooked_PlayerDeath = HookEventEx("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
	g_bEventHooked_PlayerTeam = HookEventEx("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
}

UnhookEvents()
{
	if(g_bEventHooked_PlayerSpawn)
	{
		UnhookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
		g_bEventHooked_PlayerSpawn = false;
	}
	
	if(g_bEventHooked_PlayerDeath)
	{
		UnhookEvent("player_death", Event_PlayerDeath_Post, EventHookMode_Post);
		g_bEventHooked_PlayerDeath = false;
	}
	
	if(g_bEventHooked_PlayerTeam)
	{
		UnhookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
		g_bEventHooked_PlayerTeam = false;
	}
}

RemoveAllXrayModels()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		RemoveXrayModel(iClient);
}

RemoveXrayModel(iClient)
{
	new iEnt = EntRefToEntIndex(g_iXrayModelRefs[iClient]);
	if(iEnt < 1)
		return;
	
	AcceptEntityInput(iEnt, "Kill");
	g_iXrayModelRefs[iClient] = INVALID_ENT_REFERENCE;
}

CreateAllXrayModels()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
		CreateXrayModel(iClient);
}

CreateXrayModel(iClient)
{
	RemoveXrayModel(iClient);
	
	if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	new iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1)
		return;
	
	g_iXrayModelRefs[iClient] = EntIndexToEntRef(iEnt);
	
	ReapplyXrayModel(iClient);
	
	SetEntProp(iEnt, Prop_Send, "m_fEffects", EF_BONEMERGE | EF_BONEMERGE_FASTCULL | EF_PARENT_ANIMATES | EF_NOSHADOW | EF_NORECEIVESHADOW);
	SetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity", iClient);
	
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetParent", iClient, iEnt);
	
	SetEntityRenderColor(iEnt, 255, 255, 255, 1);
	SetEntityRenderMode(iEnt, RENDER_TRANSALPHA);
	ReapplyGlow(iClient);
	
	SDKHook(iEnt, SDKHook_SetTransmit, OnTransmit_Glow);
}

ReapplyXrayModel(iClient)
{
	new iEnt = EntRefToEntIndex(g_iXrayModelRefs[iClient]);
	if(iEnt < 1)
		return;
	
	decl String:szModel[PLATFORM_MAX_PATH];
	GetClientModel(iClient, szModel, sizeof(szModel));
	SetEntityModel(iEnt, szModel);
}

ReapplyGlow(iClient)
{
	new iEnt = EntRefToEntIndex(g_iXrayModelRefs[iClient]);
	if(iEnt < 1)
		return;
	
	decl iRed, iGreen, iBlue;
	switch(GetClientTeam(iClient))
	{
		case TEAM_PRISONERS:
		{
			iRed = 255;
			iGreen = 0;
			iBlue = 0;
		}
		case TEAM_GUARDS:
		{
			iRed = 0;
			iGreen = 0;
			iBlue = 255;
		}
		default:
		{
			iRed = 0;
			iGreen = 255;
			iBlue = 0;
		}
	}
	
	SetEntProp(iEnt, Prop_Send, "m_bShouldGlow", 1);
	SetEntProp(iEnt, Prop_Send, "m_clrGlow", (iRed | (iGreen << 8) | (iBlue << 16) | (255 << 24)));
	SetEntPropFloat(iEnt, Prop_Send, "m_flGlowMaxDist", 10000000.0);
}

public Event_PlayerSpawn_Post(Handle:hEvent, String:szName[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(1 <= iClient <= MaxClients)
		CreateXrayModel(iClient);
}

public Event_PlayerDeath_Post(Handle:hEvent, String:szName[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(1 <= iClient <= MaxClients)
		RemoveXrayModel(iClient);
}

public Event_PlayerTeam_Post(Handle:hEvent, String:szName[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(1 <= iClient <= MaxClients)
		ReapplyGlow(iClient);
}

public UltJB_Warden_OnSelected(iClient)
{
	ReapplyXrayModel(iClient);
}

public UltJB_Warden_OnRemoved(iClient)
{
	ReapplyXrayModel(iClient);
}

public UltJB_PlayerModels_OnApplied(iClient)
{
	ReapplyXrayModel(iClient);
}

public UltJB_LastGuard_OnActivated_Post(iClient)
{
	ReapplyXrayModel(iClient);
}

public Action:OnTransmit_Glow(iXrayModel, iClient)
{
	if(!g_bXrayEnabled[iClient])
		return Plugin_Handled;
	
	if(IsPlayerAlive(iClient))
		return Plugin_Handled;
	
	if(GetEntPropEnt(iXrayModel, Prop_Send, "m_hOwnerEntity") == iClient)
		return Plugin_Handled;
	
	return Plugin_Continue;
}
