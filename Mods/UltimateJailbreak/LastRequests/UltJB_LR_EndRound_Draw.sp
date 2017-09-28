#include <sourcemod>
#include <sdktools_functions>
#include <cstrike>
#include <hls_color_chat>
#include "../Includes/ultjb_last_request"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "[UltJB] LR: End Round - Draw";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "yota_ninja",
	description = "Last Request: End Round - Draw",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define LR_NAME			"Draw"
#define LR_CATEGORY		"End Round"
#define LR_DESCRIPTION	"This ends the round in a draw"



public OnPluginStart()
{
	CreateConVar("lr_endround_draw_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
}

public UltJB_LR_OnRegisterReady()
{
	new iLastRequestID = UltJB_LR_RegisterLastRequest(LR_NAME, LR_FLAG_LAST_PRISONER_ONLY_CAN_USE, OnLastRequestStart);
	UltJB_LR_SetLastRequestData(iLastRequestID, LR_CATEGORY, LR_DESCRIPTION);
}

public OnLastRequestStart(iClient)
{
	CS_TerminateRound(3.0, CSRoundEnd_Draw);
	CPrintToChatAll("{olive}[{lightred}SM{olive}] {lightred}%N {olive}has chosen to end the round in a {red}%s{olive}!", iClient, LR_NAME);
	
	for(new iPlayer=1; iPlayer<=MaxClients; iPlayer++)
	{
		if(!IsClientInGame(iPlayer))
			continue;
		
		SetEntProp(iPlayer, Prop_Data, "m_takedamage", 0);
	}
}