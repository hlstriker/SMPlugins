#include <sourcemod>
#include <sdkhooks>
#include <hls_color_chat>

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "No Scope Rounds";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Allows a chance for the round to be noscope only.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define RESTRICT_SOUND	"buttons/button11.wav"

new Handle:cvar_noscope_chance;
new bool:g_bNoScopeActivated;

new bool:g_bBlockScoping[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("no_scope_rounds_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_noscope_chance = CreateConVar("noscope_chance", "0.0", "The chance for noscope to be activated 1-100. 0 disables plugin.", _, true, 0.0, true, 100.0);
	
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	DeactivateNoScope();
}

public Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	DeactivateNoScope();
	TryActivateNoScope();
}

TryActivateNoScope()
{
	new iChance = GetConVarInt(cvar_noscope_chance);
	if(!iChance)
		return;
	
	if(iChance < GetRandomInt(1, 100))
		return;
	
	ActivateNoScope();
}

ActivateNoScope()
{
	if(g_bNoScopeActivated)
		return;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SetupClientHooks(iClient);
	}
	
	g_bNoScopeActivated = true;
	
	PrintHintTextToAll("<font color='#c41919'>No-scope round activated!</font>");
	CPrintToChatAll("{lightgreen}-- {lightred}No-scope round activated!");
}

public OnClientPutInServer(iClient)
{
	if(g_bNoScopeActivated)
		SetupClientHooks(iClient);
}

SetupClientHooks(iClient)
{
	SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

DeactivateNoScope()
{
	if(!g_bNoScopeActivated)
		return;
	
	g_bNoScopeActivated = false;
	
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient))
			continue;
		
		SDKUnhook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
		SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
		g_bBlockScoping[iClient] = false;
	}
}

public OnWeaponSwitchPost(iClient, iWeapon)
{
	g_bBlockScoping[iClient] = IsScopeWeapon(iWeapon);
}

bool:IsScopeWeapon(iWeapon)
{
	static String:szClassName[14];
	if(!GetEntityClassname(iWeapon, szClassName, sizeof(szClassName)))
		return false;
	
	if(StrEqual(szClassName[7], "scar20")
	|| StrEqual(szClassName[7], "g3sg1")
	|| StrEqual(szClassName[7], "awp")
	|| StrEqual(szClassName[7], "ssg08")
	|| StrEqual(szClassName[7], "aug")
	|| StrEqual(szClassName[7], "sg556"))
	{
		return true;
	}
	
	return false;
}

public OnPreThinkPost(iClient)
{
	if(!g_bBlockScoping[iClient])
		return;
	
	static iWeapon;
	iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	
	if(iWeapon < 1)
		return;
	
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", Float:0x7f7fffff);
	
	if(GetClientButtons(iClient) & IN_ATTACK2)
		TryPlayRestrictSound(iClient);
}

TryPlayRestrictSound(iClient)
{
	static Float:fNextSound[MAXPLAYERS+1];
	if(GetEngineTime() < fNextSound[iClient])
		return;
	
	fNextSound[iClient] = GetEngineTime() + 0.75;
	
	ClientCommand(iClient, "play %s", RESTRICT_SOUND);
}