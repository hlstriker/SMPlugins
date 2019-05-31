#include <sourcemod>
#include <sdktools_functions>
#include <sdktools_stringtables>
#include "../Includes/ultjb_last_request"
#include "../Includes/ultjb_days"
#include "../Includes/ultjb_weapon_selection"
#include "../Includes/ultjb_effects"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] Warday: Capture the Flag";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "Warday: Capture the Flag.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define DAY_NAME	"Capture the Flag"
new const DayType:DAY_TYPE = DAY_TYPE_WARDAY;

new g_iFlagEntRef;

#define MODEL_FLAG	"models/swoobles/ultimate_jailbreak/flag/flag.mdl"

new const FSOLID_NOT_SOLID = 0x0004;
new const FSOLID_TRIGGER = 0x0008;


public OnPluginStart()
{
	CreateConVar("warday_classic_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	RegConsoleCmd("sm_test", OnTest);
}

public OnMapStart()
{
	AddFileToDownloadsTable(MODEL_FLAG);
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/flag/flag.dx90.vtx");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/flag/flag.phy");
	AddFileToDownloadsTable("models/swoobles/ultimate_jailbreak/flag/flag.vvd");
	
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_fx_yellow.vmt");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_glow.vtf");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_glow_normal.vtf");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_yellow.vmt");
	AddFileToDownloadsTable("materials/swoobles/ultimate_jailbreak/flag/flag_yellow.vtf");
	
	PrecacheModel(MODEL_FLAG);
}

public UltJB_Day_OnRegisterReady()
{
	new iDayID = UltJB_Day_RegisterDay(DAY_NAME, DAY_TYPE, DAY_FLAG_STRIP_GUARDS_WEAPONS | DAY_FLAG_STRIP_PRISONERS_WEAPONS | DAY_FLAG_ALLOW_WEAPON_PICKUPS | DAY_FLAG_ALLOW_WEAPON_DROPS, OnDayStart, OnDayEnd, OnFreezeEnd);
	UltJB_Day_SetFreezeTime(iDayID, 1); // TODO: Set this to the wardens attack/defend selection menu time.
}

public OnDayStart(iClient)
{
	// Show the attack/defend selection menu.
}

public OnDayEnd(iClient)
{
	//
}

public OnFreezeEnd()
{
	for(new iClient=1; iClient<=MaxClients; iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		PrepareClient(iClient);
	}
}

public UltJB_Day_OnSpawnPost(iClient)
{
	if(!UltJB_Day_GetCurrentDayID())
		return;
	
	if(UltJB_Day_GetFreezeTimeRemaining())
		return;
	
	PrepareClient(iClient);
}

PrepareClient(iClient)
{
	switch(GetClientTeam(iClient))
	{
		case TEAM_GUARDS:
		{
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE);
		}
		case TEAM_PRISONERS:
		{
			UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_KNIFE_T);
		}
	}
	
	new iWeapon = UltJB_Weapons_GivePlayerWeapon(iClient, _:CSWeapon_M4A1);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	// Give health based on team's player count.
	// -->
	
	
}

public Action:OnTest(iClient, iArgsNum)
{
	SpawnFlag(iClient);
}

SpawnFlag(iClient)
{
	new iEnt = GetFlagEntity();
	if(iEnt < 1)
		return;
	
	SetEntityModel(iEnt, MODEL_FLAG);
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2); // SOLID_BBOX
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER);
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", Float:{-16.0, -16.0, -0.0});
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", Float:{16.0, 16.0, 70.0});
	
	SetEntProp(iEnt, Prop_Send, "m_nSequence", 1);
	SetEntPropFloat(iEnt, Prop_Send, "m_flPlaybackRate", 1.0);
	
	decl Float:fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
}

GetFlagEntity()
{
	new iEnt = EntRefToEntIndex(g_iFlagEntRef);
	if(iEnt > 0)
		return iEnt;
	
	iEnt = CreateEntityByName("prop_dynamic_override");
	if(iEnt < 1)
		return -1;
	
	g_iFlagEntRef = EntIndexToEntRef(iEnt);
	
	return iEnt;
}