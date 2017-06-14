#include <sourcemod>

new const String:PLUGIN_NAME[] = "Map Armour Config";
new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "FrostJacked",
	description = "A plugin to manage armour on a map-by-map basis.",
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

new Handle:g_aArmourMaps;

new Handle:cvar_mp_free_armor;

public OnPluginStart()
{
	CreateConVar("map_armour_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_mp_free_armor = FindConVar("mp_free_armor");

	g_aArmourMaps = CreateArray(PLATFORM_MAX_PATH);
	LoadArmourConfig();
	
	RegAdminCmd("sm_armour", Command_Armour, ADMFLAG_ROOT, "sm_armour - Enables armour on the current map.");
	RegAdminCmd("sm_noarmour", Command_NoArmour, ADMFLAG_ROOT, "sm_noarmour - Disables armour on the current map.");

}

public OnMapStart()
{
	new String:szBuffer[PLATFORM_MAX_PATH];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	
	new iMatch = FindStringInArray(g_aArmourMaps, szBuffer);
	
	SetConVarInt(cvar_mp_free_armor, (iMatch == -1) ? 0 : 1);
}

public Action:Command_Armour(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
	
	if(GetConVarInt(cvar_mp_free_armor) == 1)
	{
		PrintToChat(iClient, "[SM] Armour already allowed on this map.");
		return Plugin_Handled;
	}

	new String:szBuffer[PLATFORM_MAX_PATH];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	
	SetConVarInt(cvar_mp_free_armor, 1);
	PushArrayString(g_aArmourMaps, szBuffer);
	SaveArmourConfig();
	SetPlayerArmour();
	
	return Plugin_Handled;
}

public Action:Command_NoArmour(iClient, iArgNum)
{
	if(!iClient)
		return Plugin_Handled;
		
	if(GetConVarInt(cvar_mp_free_armor) == 0)
	{
		PrintToChat(iClient, "[SM] Armour already disabled on this map.");
		return Plugin_Handled;
	}

	new String:szBuffer[PLATFORM_MAX_PATH];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	
	SetConVarInt(cvar_mp_free_armor, 0);
	RemoveFromArray(g_aArmourMaps, FindStringInArray(g_aArmourMaps, szBuffer));
	SaveArmourConfig();
	SetPlayerArmour();
	
	return Plugin_Handled;
}

SaveArmourConfig()
{
	decl String:szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/map_armour.txt");
	
	new Handle:fp = OpenFile(szPath, "w");
	if(fp == INVALID_HANDLE)
	{
		PrintToChatAll("[SM] Error creating save file.");
		return;
	}
	
	new String:szBuffer[PLATFORM_MAX_PATH];
	
	for(new i=0;i<GetArraySize(g_aArmourMaps); i++)
	{	
		GetArrayString(g_aArmourMaps, i, szBuffer, sizeof(szBuffer));
		WriteFileLine(fp, szBuffer);
	}
	
	CloseHandle(fp);
	
	PrintToChatAll("[SM] Armour configs have been saved.");
}

LoadArmourConfig()
{	
	decl String:szBuffer[PLATFORM_MAX_PATH];
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/map_armour.txt");
	
	new Handle:fp = OpenFile(szBuffer, "r");
	if(fp == INVALID_HANDLE)
		return;
	
	ClearArray(g_aArmourMaps);
	
	while(!IsEndOfFile(fp))
	{
		if(!ReadFileLine(fp, szBuffer, sizeof(szBuffer)))
			continue;
		
		TrimString(szBuffer);
		
		if(strlen(szBuffer) < 1)
			continue;
			
		PushArrayString(g_aArmourMaps, szBuffer);
	}
	
	CloseHandle(fp);
	
	GetLowercaseMapName(szBuffer, sizeof(szBuffer));
	new iMatch = FindStringInArray(g_aArmourMaps, szBuffer);
	
	SetConVarInt(cvar_mp_free_armor, (iMatch == -1) ? 0 : 1);
}

GetLowercaseMapName(String:szMapName[], iMaxLength)
{
	GetCurrentMap(szMapName, iMaxLength);
	StringToLower(szMapName);
}

StringToLower(String:szString[])
{
	for(new i=0; i<strlen(szString); i++)
		szString[i] = CharToLower(szString[i]);
}

SetPlayerArmour()
{
	new bool:bVar = GetConVarBool(cvar_mp_free_armor);
	
	for(new iClient=1;iClient<=MaxClients;iClient++)
	{
		if(!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
			continue;
		
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", bVar ? 100 : 0);
		SetEntProp(iClient, Prop_Send, "m_bHasHelmet", bVar ? 1 : 0);
	}
}