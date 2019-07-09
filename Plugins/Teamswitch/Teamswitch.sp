// TeamSwitch

// Allows admins to switch people in the opposite team
// This can either be done immediately, or on player death,
// or - if available in the mod - on round end.
// The plugin configures itself for the different mods automatically,
// so there is no $mod Edition neccessary.

// Changes:
// 1.3:
//      * teamswitch_spec command
// 1.2:
//      * Bugfix: Wrong player ID got listed in the menu, so the wrong people were switched
// 1.1:
//      * Menu was re-displayed at the wrong item index

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#undef REQUIRE_EXTENSIONS
#include <cstrike>
#define REQUIRE_EXTENSIONS


// Team indices
#define TEAM_1    2
#define TEAM_2    3
#define TEAM_SPEC 1


#define TEAMSWITCH_VERSION    "1.4"
#define TEAMSWITCH_ADMINFLAG  ADMFLAG_KICK
#define TEAMSWITCH_ARRAY_SIZE 64


public Plugin:myinfo = {
	name = "TeamSwitch",
	author = "MistaGee",
	description = "switch people to the other team now, at round end, on death",
	version = TEAMSWITCH_VERSION,
	url = "http://www.sourcemod.net/"
	};

new	bool:onRoundEndPossible	= false,
	bool:cstrikeExtAvail	= false,
	String:teamName1[5],
	String:teamName2[5],
	bool:switchOnRoundEnd[TEAMSWITCH_ARRAY_SIZE],
	bool:switchOnDeath[TEAMSWITCH_ARRAY_SIZE];
	
	
enum TeamSwitchEvent{
	TeamSwitchEvent_Immediately	= 0,
	TeamSwitchEvent_OnDeath		= 1,
	TeamSwitchEvent_OnRoundEnd	= 2,
	TeamSwitchEvent_ToSpec		= 3
	};

public OnPluginStart(){
	CreateConVar( "teamswitch_version",	TEAMSWITCH_VERSION, "TeamSwitch version", FCVAR_NOTIFY );
	
	RegAdminCmd( "sm_teamswitch",			Command_SwitchImmed,	TEAMSWITCH_ADMINFLAG );
	RegAdminCmd( "sm_teamswitch_death",	Command_SwitchDeath,	TEAMSWITCH_ADMINFLAG );
	RegAdminCmd( "sm_teamswitch_roundend",	Command_SwitchRend,		TEAMSWITCH_ADMINFLAG );
	RegAdminCmd( "sm_ts",					Command_SwitchImmed,	TEAMSWITCH_ADMINFLAG );
	RegAdminCmd( "sm_tsd",					Command_SwitchDeath,	TEAMSWITCH_ADMINFLAG );
	RegAdminCmd( "sm_tsr",					Command_SwitchRend,		TEAMSWITCH_ADMINFLAG );
	
	HookEvent(   "player_death",	Event_PlayerDeath	);
	
	// Hook game specific round end events - if none found, round end is not shown in menu
	decl String:theFolder[40];
	GetGameFolderName( theFolder, sizeof(theFolder) );
	
	PrintToServer( "[TS] Hooking round end events for game: %s", theFolder );
	
	if( StrEqual( theFolder, "dod" ) ){
		HookEvent( "dod_round_win",		Event_RoundEnd, EventHookMode_PostNoCopy );
		onRoundEndPossible = true;
		}
	else if( StrEqual( theFolder, "tf" ) ){
		HookEvent( "teamplay_round_win",	Event_RoundEnd, EventHookMode_PostNoCopy );
		HookEvent( "teamplay_round_stalemate",	Event_RoundEnd, EventHookMode_PostNoCopy );
		onRoundEndPossible = true;
		}
	else if( StrEqual( theFolder, "cstrike" ) || StrEqual( theFolder, "csgo" ) ){
		HookEvent( "round_end",			Event_RoundEnd, EventHookMode_PostNoCopy );
		onRoundEndPossible = true;
		}
	
	
	
	// Check for cstrike extension - if available, CS_SwitchTeam is used
	cstrikeExtAvail = ( GetExtensionFileStatus( "game.cstrike.ext" ) == 1 );
	
	LoadTranslations( "common.phrases" );
	}

public OnMapStart(){
	GetTeamName( 2, teamName1, sizeof(teamName1) );
	GetTeamName( 3, teamName2, sizeof(teamName2) );
	
	PrintToServer(
		"[TS] Team Names: %s %s - OnRoundEnd available: %s",
		teamName1, teamName2,
		( onRoundEndPossible ? "yes" : "no" )
		);
	}

public Action:Command_SwitchImmed( client, args ){
	
	new targetTeam;
	decl String:teamArg[10];
	
	if (args == 2)
	{
		GetCmdArg( 2, teamArg, sizeof(teamArg));
		if (!strcmp(teamArg, "t", false))
		{
			targetTeam = 2;
		}
		else if (!strcmp(teamArg, "ct", false))
		{
			targetTeam = 3;
		}
		else if (!strcmp(teamArg, "s", false) || !strcmp(teamArg, "sp", false) || !strcmp(teamArg, "spec", false))
		{
			targetTeam = 1;
		}
		else
		{
			ReplyToCommand( client, "[SM] Invalid team provided.");
			return Plugin_Handled;
		}
		
	}
	else if (args == 1)
	{
		targetTeam = 0;
	}
	else
	{
		ReplyToCommand( client, "[SM] Usage: teamswitch <name> <team> - Switch player to another team" );
		return Plugin_Handled;
	}
	
	// Try to find a target player
	decl String:targetArg[50];
	GetCmdArg( 1, targetArg, sizeof(targetArg) );
	
	decl String:target_name[50];
	
	new target = FindTarget( client, targetArg );
	
	if( target != -1){
		GetClientName( target, target_name, sizeof(target_name) );
		if (targetTeam != 0 && GetClientTeam(target) == targetTeam)
		{
			ReplyToCommand(client, "[SM] %s is already on that team.", target_name);
			return Plugin_Handled;
		}
		PerformSwitch( target , targetTeam);
		if (targetTeam != 0)
			PrintToChatAll( "[SM] Admin teamswitched %s to team %s.", target_name, teamArg );
		else
			PrintToChatAll( "[SM] Admin teamswitched %s.", target_name);
		
		LogAction(client, target, "\"%L\" used teamswitch for \"%L\"", client, target);
	}
	
	return Plugin_Handled;
	}

public Action:Command_SwitchDeath( client, args ){
	if( args != 1 ){
		ReplyToCommand( client, "[SM] Usage: teamswitch_death <name> - Switch player to opposite team when they die" );
		return Plugin_Handled;
		}
	
	// Try to find a target player
	decl String:targetArg[50];
	GetCmdArg( 1, targetArg, sizeof(targetArg) );
	
	decl String:target_name[50];
	new target = FindTarget( client, targetArg );
	if( target != -1 ){
		switchOnDeath[target] = !switchOnDeath[target];
		GetClientName( target, target_name, sizeof(target_name) );
		PrintToChatAll(
			"[SM] %s will %s be switched to opposite team on their death.",
			target_name, ( switchOnDeath[target] ? "" : "not" )
			);
		
		LogAction(client, target, "\"%L\" used teamswitch on death for \"%L\"", client, target);
		}
	
	return Plugin_Handled;
	}

public Action:Command_SwitchRend( client, args ){
	if( args != 1 ){
		ReplyToCommand( client, "[SM] Usage: teamswitch_roundend <name> - Switch player to opposite team when the round ends" );
		return Plugin_Handled;
		}
	
	if( !onRoundEndPossible ){
		ReplyToCommand( client, "[SM] Switching on round end is not possible in this mod." );
		return Plugin_Handled;
		}
	
	// Try to find a target player
	decl String:targetArg[50];
	GetCmdArg( 1, targetArg, sizeof(targetArg) );
	
	new target = FindTarget( client, targetArg );
	
	if( target != -1 ){
		decl String:target_name[50];
		switchOnRoundEnd[target] = !switchOnRoundEnd[target];
		GetClientName( target, target_name, sizeof(target_name) );
		PrintToChatAll(
			"[SM] %s will %s be switched to opposite team on round end.",
			target_name, ( switchOnRoundEnd[target] ? "" : "not" )
			);
		
		LogAction(client, target, "\"%L\" used teamswitch on round end for \"%L\"", client, target);
		}
	
	return Plugin_Handled;
	}

public Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ){
	new victim   = GetClientOfUserId( GetEventInt( event, "userid" ) );
	
	if( switchOnDeath[victim] ){
		PerformTimedSwitch( victim );
		switchOnDeath[victim] = false;
		}
	}

public Event_RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ){
	if( !onRoundEndPossible )
		return;
	
	for( new i = 0; i < TEAMSWITCH_ARRAY_SIZE; i++ ){
		if( switchOnRoundEnd[i] ){
			PerformTimedSwitch(i);
			switchOnRoundEnd[i] = false;
			}
		}
	}
	
void:PerformTimedSwitch( client ){
    CreateTimer( 0.5, Timer_TeamSwitch, client );
    }
	
public Action:Timer_TeamSwitch( Handle:timer, any:client ){
    if( IsClientInGame( client ) )
        PerformSwitch( client );
    return Plugin_Stop;
    }

void:PerformSwitch( client, targTeam = 0 ){
    new cTeam  = GetClientTeam( client ),
        toTeam = ( targTeam != 0 ? targTeam : TEAM_1 + TEAM_2 - cTeam );
   
    if( cstrikeExtAvail && !(toTeam == 1) )
        CS_SwitchTeam(    client, toTeam );
    else    ChangeClientTeam( client, toTeam );
   
    decl String:plName[40];
    GetClientName( client, plName, sizeof(plName) );
    PrintToChatAll( "[SM] %s has been switched by an admin.", plName);
    }