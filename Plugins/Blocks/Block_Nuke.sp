#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <emitsoundany>
#include "../../Libraries/BlockMaker/block_maker"

#undef REQUIRE_PLUGIN
#include "../../Libraries/ParticleManager/particle_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Block: Nuke";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "A block type.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define BLOCK_NAME			"Nuke"
new const String:SOUND_START_TOUCH[] = "sound/weapons/c4/c4_explode1.wav";

new String:g_szBlockFiles[][] =
{
	"models/swoobles/blocks/nuke/block.mdl",
	"models/swoobles/blocks/nuke/block.dx90.vtx",
	"models/swoobles/blocks/nuke/block.phy",
	"models/swoobles/blocks/nuke/block.vvd",
	
	"materials/swoobles/blocks/nuke/block.vtf",
	"materials/swoobles/blocks/nuke/block.vmt"
};

new const String:PARTICLE_FILE_PATH[] = "particles/explosions_fx.pcf";
#if defined _particle_manager_included
new const String:PEFFECT_EXPLOSION[] = "explosion_c4_500";
#endif

new bool:g_bLibLoaded_ParticleManager;


public OnPluginStart()
{
	CreateConVar("block_nuke_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ParticleManager = LibraryExists("particle_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "particle_manager"))
		g_bLibLoaded_ParticleManager = false;
}

public OnMapStart()
{
	for(new i=0; i<sizeof(g_szBlockFiles); i++)
		AddFileToDownloadsTable(g_szBlockFiles[i]);
	
	PrecacheModel(g_szBlockFiles[0], true);
	
	AddFileToDownloadsTable(PARTICLE_FILE_PATH);
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		PM_PrecacheParticleEffect(PARTICLE_FILE_PATH, PEFFECT_EXPLOSION);
		#endif
	}
}

public BlockMaker_OnRegisterReady()
{
	new iType = BlockMaker_RegisterBlockType(BLOCK_NAME, g_szBlockFiles[0], _, OnStartTouch);
	BlockMaker_SetSounds(iType, SOUND_START_TOUCH);
}

public Action:OnStartTouch(iBlock, iOther)
{
	if(!(1 <= iOther <= MaxClients))
		return Plugin_Continue;
	
	decl Float:fOrigin[3];
	new iClientTeam = GetClientTeam(iOther);
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer) || !IsPlayerAlive(iPlayer))
			continue;
		
		if(GetClientTeam(iPlayer) == iClientTeam)
			continue;
		
		SDKHooks_TakeDamage(iPlayer, iOther, iOther, 9999999.0);
		
		if(g_bLibLoaded_ParticleManager)
		{
			#if defined _particle_manager_included
			GetClientAbsOrigin(iPlayer, fOrigin);
			PM_CreateEntityEffectCustomOrigin(0, PEFFECT_EXPLOSION, fOrigin, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
			#endif
		}
	}
	
	EmitSoundToAllAny(SOUND_START_TOUCH[6], iBlock, _, SNDLEVEL_NONE);
	PrintHintTextToAll("<font color='#c41919'>A nuke was activated by:</font>\n<font color='#6FC41A'>%N</font>", iOther);
	
	if(g_bLibLoaded_ParticleManager)
	{
		#if defined _particle_manager_included
		GetEntPropVector(iBlock, Prop_Data, "m_vecOrigin", fOrigin);
		PM_CreateEntityEffectCustomOrigin(0, PEFFECT_EXPLOSION, fOrigin, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});
		#endif
	}
	
	AcceptEntityInput(iBlock, "KillHierarchy");
	
	return Plugin_Handled;
}