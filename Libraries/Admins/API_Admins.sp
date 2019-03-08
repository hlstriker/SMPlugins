#include <sourcemod>
#include <sdkhooks>
#include "admins"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "API: Admins";
new const String:PLUGIN_VERSION[] = "1.1";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = "An API to handle admins.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new AdminLevel:g_iAdminLevel[MAXPLAYERS+1];

new Handle:g_hFwd_OnLoaded;


public OnPluginStart()
{
	CreateConVar("api_admins_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	g_hFwd_OnLoaded = CreateGlobalForward("Admins_OnLoaded", ET_Ignore, Param_Cell, Param_Cell);
}

public APLRes:AskPluginLoad2(Handle:hMyself, bool:bLate, String:szError[], iErrLen)
{
	RegPluginLibrary("admins");
	
	CreateNative("Admins_GetLevel", _Admins_GetLevel);

	return APLRes_Success;
}

public _Admins_GetLevel(Handle:hPlugin, iNumParams)
{
	if(iNumParams != 1)
	{
		LogError("Invalid number of parameters.");
		return _:AdminLevel_None;
	}
	
	return _:g_iAdminLevel[GetNativeCell(1)];
}

public OnClientConnected(iClient)
{
	g_iAdminLevel[iClient] = AdminLevel_NotLoaded;
}

public OnClientPostAdminCheck(iClient)
{
	g_iAdminLevel[iClient] = GetAdminsLevel(iClient);
	Forward_OnLoaded(iClient);
}

Forward_OnLoaded(iClient)
{
	Call_StartForward(g_hFwd_OnLoaded);
	Call_PushCell(iClient);
	Call_PushCell(_:g_iAdminLevel[iClient]);
	Call_Finish();
}

AdminLevel:GetAdminsLevel(iClient)
{
	new AdminId:iAdminID = GetUserAdmin(iClient);
	if(iAdminID == INVALID_ADMIN_ID)
		return AdminLevel_None;
	
	new iGroupCount = GetAdminGroupCount(iAdminID);
	if(!iGroupCount)
		return AdminLevel_None;
	
	new AdminLevel:iHighestLevel = AdminLevel_None;
	
	static String:szGroupName[32], AdminLevel:iLevel;
	for(new i=0; i<iGroupCount; i++)
	{
		if(GetAdminGroup(iAdminID, i, szGroupName, sizeof(szGroupName)) == INVALID_GROUP_ID)
			continue;
		
		if(StrEqual(szGroupName, "Junior"))
		{
			iLevel = AdminLevel_Junior;
		}
		else if(StrEqual(szGroupName, "Senior"))
		{
			iLevel = AdminLevel_Senior;
		}
		else if(StrEqual(szGroupName, "Reputable"))
		{
			iLevel = AdminLevel_Reputable;
		}
		else if(StrEqual(szGroupName, "Lead"))
		{
			iLevel = AdminLevel_Lead;
		}
		else
		{
			continue;
		}
		
		if(iLevel > iHighestLevel)
			iHighestLevel = iLevel;
	}
	
	return iHighestLevel;
}