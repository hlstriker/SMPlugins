#include <sourcemod>
#include <sdkhooks>
#include "../../Libraries/MovementStyles/movement_styles"

#pragma semicolon 1

new const String:PLUGIN_NAME[] = "Style: Third Person";
new const String:PLUGIN_VERSION[] = "1.2";

public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "hlstriker",
	description = PLUGIN_NAME,
	version = PLUGIN_VERSION,
	url = "www.swoobles.com"
}

#define THIS_STYLE_BIT			STYLE_BIT_THIRDPERSON
#define THIS_STYLE_NAME			"Thirdperson"
#define THIS_STYLE_NAME_AUTO	"Thirdperson + Auto Bhop"
#define THIS_STYLE_ORDER		100

new Handle:cvar_add_autobhop;
new Handle:cvar_force_autobhop;

new Handle:cvar_sv_allow_thirdperson;

#define QUERY_CHECK_INTERVAL 0.3
new Float:g_fNextQueryCheck[MAXPLAYERS+1];

new bool:g_bActivated[MAXPLAYERS+1];


public OnPluginStart()
{
	CreateConVar("style_thirdperson_ver", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	
	cvar_add_autobhop = CreateConVar("style_thirdperson_add_autobhop", "0", "Add an additional auto-bhop style for this style too.", _, true, 0.0, true, 1.0);
	cvar_force_autobhop = CreateConVar("style_thirdperson_force_autobhop", "0", "Force auto-bhop on this style.", _, true, 0.0, true, 1.0);
	
	if((cvar_sv_allow_thirdperson = FindConVar("sv_allow_thirdperson")) == INVALID_HANDLE)
		SetFailState("Could not find cvar sv_allow_thirdperson");
	
	SetConVarInt(cvar_sv_allow_thirdperson, 1);
	HookConVarChange(cvar_sv_allow_thirdperson, OnConVarChanged);
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[])
{
	if(hConVar == cvar_sv_allow_thirdperson)
		SetConVarInt(hConVar, 1);
}

public MovementStyles_OnRegisterReady()
{
	MovementStyles_RegisterStyle(THIS_STYLE_BIT, THIS_STYLE_NAME, OnActivated, OnDeactivated, THIS_STYLE_ORDER, GetConVarBool(cvar_force_autobhop) ? THIS_STYLE_NAME_AUTO : "");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_thirdperson");
	MovementStyles_RegisterStyleCommand(THIS_STYLE_BIT, "sm_3p");
}

public MovementStyles_OnRegisterMultiReady()
{
	if(GetConVarBool(cvar_add_autobhop) && !GetConVarBool(cvar_force_autobhop))
		MovementStyles_RegisterMultiStyle(THIS_STYLE_BIT | STYLE_BIT_AUTO_BHOP, THIS_STYLE_NAME_AUTO, THIS_STYLE_ORDER + 1);
}

public MovementStyles_OnBitsChanged(iClient, iOldBits, &iNewBits)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(iNewBits != THIS_STYLE_BIT)
		return;
	
	iNewBits = TryForceAutoBhopBits(iNewBits);
}

public Action:MovementStyles_OnMenuBitsChanged(iClient, iBitsBeingToggled, bool:bBeingToggledOn, &iExtraBitsToForceOn)
{
	// Do not compare using bitwise operators. The bit should be an exact equal.
	if(!bBeingToggledOn || iBitsBeingToggled != THIS_STYLE_BIT)
		return;
	
	iExtraBitsToForceOn = TryForceAutoBhopBits(iExtraBitsToForceOn);
}

TryForceAutoBhopBits(iBits)
{
	if(!GetConVarBool(cvar_force_autobhop))
		return iBits;
	
	return (iBits | STYLE_BIT_AUTO_BHOP);
}

public OnClientConnected(iClient)
{
	g_bActivated[iClient] = false;
}

public OnActivated(iClient)
{
	g_bActivated[iClient] = true;
	
	SetThirdPerson(iClient);
	SDKHook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

public OnDeactivated(iClient)
{
	g_bActivated[iClient] = false;
	
	SetFirstPerson(iClient);
	SDKUnhook(iClient, SDKHook_PreThinkPost, OnPreThinkPost);
}

SetThirdPerson(iClient)
{
	if(IsPlayerAlive(iClient))
		ClientCommand(iClient, "thirdperson;cam_idealdist 150;cam_idealyaw 0");
	else
		SetFirstPerson(iClient);
}

SetFirstPerson(iClient)
{
	ClientCommand(iClient, "firstperson");
}

public OnPreThinkPost(iClient)
{
	static Float:fCurTime;
	fCurTime = GetEngineTime();
	
	if(fCurTime < g_fNextQueryCheck[iClient])
		return;
	
	g_fNextQueryCheck[iClient] = fCurTime + QUERY_CHECK_INTERVAL;
	
	QueryClientConVar(iClient, "cam_command", OnQueryFinished);
}

public OnQueryFinished(QueryCookie:cookie, iClient, ConVarQueryResult:result, const String:szConvarName[], const String:szConvarValue[], any:hPack)
{
	if(!g_bActivated[iClient])
		return;
	
	if(StringToInt(szConvarValue) == 1)
		return;
	
	SetThirdPerson(iClient);
}