#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <sdktools_trace>

#undef REQUIRE_PLUGIN
#include "../../Libraries/ModelSkinManager/model_skin_manager"
#define REQUIRE_PLUGIN

#pragma semicolon 1

new const String:PLUGIN_VERSION[] = "1.8";

public Plugin:myinfo =
{
	name = "Allow More Players",
	author = "hlstriker",
	description = "Allows more players to join teams.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define TEAM_NONE				0
#define TEAM_SPECTATE			1
#define TEAM_TERRORIST			2
#define TEAM_COUNTER_TERRORIST	3

new g_iSpawnCount[TEAM_COUNTER_TERRORIST+1];

const JOIN_TEAM_DELAY = 2;
new Float:g_fNextJointeamTime[MAXPLAYERS+1];

new Handle:cvar_block_join_team;
new Handle:cvar_block_join_team_max_players;
new Handle:cvar_force_even_teams;
new Handle:cvar_force_even_teams_create_spawns;

new const String:g_szRestrictedSound[] = "buttons/button11.wav";

new const Float:HULL_STANDING_MINS_CSGO[] = {-16.0, -16.0, 0.0};
new const Float:HULL_STANDING_MAXS_CSGO[] = {16.0, 16.0, 72.0};

#define MAX_SPAWNS	128
new Float:g_fCreatedSpawnOrigins[MAX_SPAWNS][3];
new Float:g_fCreatedSpawnAngles[MAX_SPAWNS][3];
new g_iCreatedSpawnCount;
new g_iCreatedSpawnTeam;

new bool:g_bLibLoaded_ModelSkinManager;


public OnPluginStart()
{
	AddCommandListener(OnJoinTeam, "jointeam");
	
	HookEvent("round_prestart", Event_RoundPrestart_Post, EventHookMode_PostNoCopy);
	
	cvar_block_join_team = CreateConVar("sv_block_join_team", "0", "0: Don't block joining any team -- 1-X: Team to block joining.", _, true, 0.0);
	cvar_block_join_team_max_players = CreateConVar("sv_block_join_team_max_players", "0", "The maximum players that can be on the team before sv_block_join_team kicks in.", _, true, 0.0);
	cvar_force_even_teams = CreateConVar("sv_force_even_teams", "0", "0: Don't force. -- 1: Force.", _, true, 0.0, true, 1.0);
	cvar_force_even_teams_create_spawns = CreateConVar("sv_force_even_teams_create_spawns", "0", "Will create spawn points for a team that doesn't exist if sv_force_even_teams is on.", _, true, 0.0, true, 1.0);
}

public OnAllPluginsLoaded()
{
	g_bLibLoaded_ModelSkinManager = LibraryExists("model_skin_manager");
}

public OnLibraryAdded(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = true;
}

public OnLibraryRemoved(const String:szName[])
{
	if(StrEqual(szName, "model_skin_manager"))
		g_bLibLoaded_ModelSkinManager = false;
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("allow_more_players");
	CreateNative("AllowMorePlayers_GetCreatedSpawnCount", _AllowMorePlayers_GetCreatedSpawnCount);
	CreateNative("AllowMorePlayers_GetCreatedSpawnTeam", _AllowMorePlayers_GetCreatedSpawnTeam);
	CreateNative("AllowMorePlayers_GetCreatedSpawnData", _AllowMorePlayers_GetCreatedSpawnData);
	
	return APLRes_Success;
}

public _AllowMorePlayers_GetCreatedSpawnCount(Handle:hPlugin, iNumParams)
{
	return g_iCreatedSpawnCount;
}

public _AllowMorePlayers_GetCreatedSpawnTeam(Handle:hPlugin, iNumParams)
{
	return g_iCreatedSpawnTeam;
}

public _AllowMorePlayers_GetCreatedSpawnData(Handle:hPlugin, iNumParams)
{
	new iSpawnIndex = GetNativeCell(1);
	if(iSpawnIndex >= g_iCreatedSpawnCount)
		return false;
	
	SetNativeArray(2, g_fCreatedSpawnOrigins[iSpawnIndex], sizeof(g_fCreatedSpawnOrigins[]));
	SetNativeArray(3, g_fCreatedSpawnAngles[iSpawnIndex], sizeof(g_fCreatedSpawnAngles[]));
	
	return true;
}

public OnConfigsExecuted()
{
	g_iCreatedSpawnCount = 0;
	g_iCreatedSpawnTeam = 0;
	
	GetSpawnCounts();
	CheckCreateSpawn();
}

public Event_RoundPrestart_Post(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	GetSpawnCounts();
	CheckCreateSpawn();
}

public CheckCreateSpawn()
{
	if(!GetConVarBool(cvar_force_even_teams) || !GetConVarBool(cvar_force_even_teams_create_spawns))
		return;
	
	if(g_iSpawnCount[TEAM_TERRORIST] > 0 && g_iSpawnCount[TEAM_COUNTER_TERRORIST] > 0)
		return;
	
	if(!g_iSpawnCount[TEAM_TERRORIST])
		CreateSpawnsForTeam(TEAM_TERRORIST);
	
	if(!g_iSpawnCount[TEAM_COUNTER_TERRORIST])
		CreateSpawnsForTeam(TEAM_COUNTER_TERRORIST);
}

GetSpawnCounts()
{
	g_iSpawnCount[TEAM_TERRORIST] = 0;
	g_iSpawnCount[TEAM_COUNTER_TERRORIST] = 0;
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_terrorist")) != -1)
	{
		g_iSpawnCount[TEAM_TERRORIST]++;
	}
	
	iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "info_player_counterterrorist")) != -1)
	{
		g_iSpawnCount[TEAM_COUNTER_TERRORIST]++;
	}
}

CreateSpawnsForTeam(iTeam)
{
	g_iCreatedSpawnCount = 0;
	g_iCreatedSpawnTeam = iTeam;
	
	new String:szClassNameToFind[29], String:szClassNameToMake[29];
	if(iTeam == TEAM_TERRORIST)
	{
		szClassNameToMake = "info_player_terrorist";
		szClassNameToFind = "info_player_counterterrorist";
	}
	else
	{
		szClassNameToMake = "info_player_counterterrorist";
		szClassNameToFind = "info_player_terrorist";
	}
	
	decl Float:fOrigin[3], Float:fAngles[3];
	
	new iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, szClassNameToFind)) != -1)
	{
		if(!GetEntProp(iEnt, Prop_Data, "m_bEnabled"))
			continue;
		
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
		
		TR_TraceHull(fOrigin, fOrigin, HULL_STANDING_MINS_CSGO, HULL_STANDING_MAXS_CSGO, MASK_PLAYERSOLID);
		
		if(TR_DidHit())
			continue;
		
		g_fCreatedSpawnOrigins[g_iCreatedSpawnCount] = fOrigin;
		g_fCreatedSpawnAngles[g_iCreatedSpawnCount] = fAngles;
		g_iCreatedSpawnCount++;
		
		g_iSpawnCount[iTeam]++;
		
		if(g_iCreatedSpawnCount == MAX_SPAWNS)
			break;
	}
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
}

public OnSpawnPost(iClient)
{
	if(IsClientObserver(iClient) || !IsPlayerAlive(iClient))
		return;
	
	if(g_bLibLoaded_ModelSkinManager)
	{
		#if defined _model_skin_manager_included
		if(MSManager_IsBeingForceRespawned(iClient))
			return;
		#endif
	}
	
	if(!g_iCreatedSpawnCount)
		return;
	
	new iTeam = GetClientTeam(iClient);
	if(iTeam < TEAM_TERRORIST || iTeam != g_iCreatedSpawnTeam)
		return;
	
	new iIndex = GetRandomInt(0, g_iCreatedSpawnCount-1);
	TeleportEntity(iClient, g_fCreatedSpawnOrigins[iIndex], g_fCreatedSpawnAngles[iIndex], NULL_VECTOR);
}

public Action:OnJoinTeam(iClient, const String:szCommand[], iArgCount)
{
	// Block team switch if not enough time has passed.
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(g_fNextJointeamTime[iClient] > fCurTime)
	{
		ClientCommand(iClient, "play %s", g_szRestrictedSound);
		return Plugin_Handled;
	}
	
	g_fNextJointeamTime[iClient] = fCurTime + JOIN_TEAM_DELAY;
	
	decl String:szTeam[2];
	GetCmdArg(1, szTeam, sizeof(szTeam));
	new iTeam = StringToInt(szTeam);
	
	// The client is trying to auto-assign. Choose a random team.
	if(iTeam == TEAM_NONE)
		iTeam = GetRandomInt(2, 3);
	
	// Check to see if the server is blocking the client from joining the team.
	if(GetConVarInt(cvar_block_join_team))
	{
		if(iTeam == GetConVarInt(cvar_block_join_team) && GetTeamClientCount(iTeam) >= GetConVarInt(cvar_block_join_team_max_players))
		{
			// Spectate is being blocked.
			if(iTeam == TEAM_SPECTATE)
			{
				ClientCommand(iClient, "play %s", g_szRestrictedSound);
				return Plugin_Handled;
			}
			
			// The team they are trying to join is being blocked. Put them on the other team.
			if(iTeam == TEAM_TERRORIST)
				iTeam = TEAM_COUNTER_TERRORIST;
			else
				iTeam = TEAM_TERRORIST;
		}
	}
	
	// Let the client always join spectators.
	if(iTeam == TEAM_SPECTATE)
	{
		ChangeClientTeam(iClient, iTeam);
		return Plugin_Handled;
	}
	
	// Force even teams without caring about the number of spawn points on those teams as long as each team has at least 1 spawn point.
	if(GetConVarBool(cvar_force_even_teams) && g_iSpawnCount[TEAM_TERRORIST] && g_iSpawnCount[TEAM_COUNTER_TERRORIST])
	{
		new iNumT = GetTeamClientCount(TEAM_TERRORIST);
		new iNumCT = GetTeamClientCount(TEAM_COUNTER_TERRORIST);
		
		// Let the first player to join a team go on the team they selected.
		if(!iNumT && !iNumCT)
		{
			ChangeClientTeam(iClient, iTeam);
			return Plugin_Handled;
		}
		
		if(iNumT <= iNumCT)
			ChangeClientTeam(iClient, TEAM_TERRORIST);
		else
			ChangeClientTeam(iClient, TEAM_COUNTER_TERRORIST);
		
		return Plugin_Handled;
	}
	
	// Force the client on the team they are trying to join if the spawn count is even.
	if(g_iSpawnCount[TEAM_TERRORIST] == g_iSpawnCount[TEAM_COUNTER_TERRORIST])
	{
		ChangeClientTeam(iClient, iTeam);
		return Plugin_Handled;
	}
	
	// Check if the client is trying to join the team with the fewest spawns.
	new iTryForceToTeamNum;
	switch(iTeam)
	{
		case TEAM_TERRORIST:
		{
			// Are there less T than CT spawns?
			if(g_iSpawnCount[TEAM_TERRORIST] < g_iSpawnCount[TEAM_COUNTER_TERRORIST])
			{
				// Put the client on T if the team isn't full. Otherwise put on CT.
				if(GetTeamClientCount(TEAM_TERRORIST) < g_iSpawnCount[TEAM_TERRORIST])
					iTryForceToTeamNum = TEAM_TERRORIST;
				else
					iTryForceToTeamNum = TEAM_COUNTER_TERRORIST;
			}
		}
		case TEAM_COUNTER_TERRORIST:
		{
			// Are there less CT than T spawns?
			if(g_iSpawnCount[TEAM_COUNTER_TERRORIST] < g_iSpawnCount[TEAM_TERRORIST])
			{
				// Put the client on CT if the team isn't full. Otherwise put on T.
				if(GetTeamClientCount(TEAM_COUNTER_TERRORIST) < g_iSpawnCount[TEAM_COUNTER_TERRORIST])
					iTryForceToTeamNum = TEAM_COUNTER_TERRORIST;
				else
					iTryForceToTeamNum = TEAM_TERRORIST;
			}
		}
	}
	
	if(iTryForceToTeamNum)
	{
		if(GetConVarInt(cvar_block_join_team))
		{
			if(iTryForceToTeamNum == GetConVarInt(cvar_block_join_team) && GetTeamClientCount(iTryForceToTeamNum) >= GetConVarInt(cvar_block_join_team_max_players))
			{
				// The team we are trying to force the client to is blocked. Force them to the opposite team instead as long as that team has spawn points.
				if(iTryForceToTeamNum == TEAM_TERRORIST)
				{
					if(g_iSpawnCount[TEAM_COUNTER_TERRORIST])
					{
						ChangeClientTeam(iClient, TEAM_COUNTER_TERRORIST);
						return Plugin_Handled;
					}
				}
				else
				{
					if(g_iSpawnCount[TEAM_TERRORIST])
					{
						ChangeClientTeam(iClient, TEAM_TERRORIST);
						return Plugin_Handled;
					}
				}
			}
		}
		
		ChangeClientTeam(iClient, iTryForceToTeamNum);
		return Plugin_Handled;
	}
	
	// The player is trying to join the team with the most spawns. It's safe to force them on that team.
	ChangeClientTeam(iClient, iTeam);
	
	return Plugin_Handled;
}