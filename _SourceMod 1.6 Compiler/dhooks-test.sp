#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <dhooks>

// int CBaseCombatCharacter::BloodColor(void)
new Handle:hBloodColor;

// bool CBaseCombatCharacter::Weapon_CanUse(CBaseCombatWeapon *)
new Handle:hHookCanUse;

// Vector CBasePlayer::GetPlayerMaxs()
new Handle:hGetMaxs;

// string_t CBaseEntity::GetModelName(void)
new Handle:hGetModelName;

// bool CGameRules::CanHaveAmmo(CBaseCombatCharacter *, int)
new Handle:hCanHaveAmmo;

// void CBaseEntity::SetModel(char  const*)
new Handle:hSetModel;

//float CCSPlayer::GetPlayerMaxSpeed()
new Handle:hGetSpeed;

//void CDirector::OnGameplayStart()
new Handle:hGameplayStart;

//int CCSPlayer::OnTakeDamage(CTakeDamageInfo const&)
new Handle:hTakeDamage;

enum GameType
{
	GameUnknown,
	GameCstrike,
	GameL4D2
};
new GameType:gametype = GameUnknown;

public OnPluginStart()
{
	new Handle:temp = LoadGameConfigFile("dhooks-test.games");
	if(temp == INVALID_HANDLE)
		SetFailState("Why you no has gamedata?");
	
	new String:game[64];
	GetGameFolderName(game, sizeof(game));
	new offset;
	
	if(strcmp(game, "cstrike") == 0)
	{
		gametype = GameCstrike;
		offset = GameConfGetOffset(temp, "BloodColor");
		hBloodColor = DHookCreate(offset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, BloodColorPost);
	
		offset = GameConfGetOffset(temp, "GetModelName");
		hGetModelName = DHookCreate(offset, HookType_Entity, ReturnType_String, ThisPointer_CBaseEntity, GetModelName);
	
		offset = GameConfGetOffset(temp, "GetMaxs");
		hGetMaxs = DHookCreate(offset, HookType_Entity, ReturnType_Vector, ThisPointer_Ignore, GetMaxsPost);
	
		offset = GameConfGetOffset(temp, "CanUse");
		hHookCanUse = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, CanUsePost);
		DHookAddParam(hHookCanUse, HookParamType_CBaseEntity);
	
		offset = GameConfGetOffset(temp, "CanHaveAmmo");
		hCanHaveAmmo = DHookCreate(offset, HookType_GameRules, ReturnType_Bool, ThisPointer_Ignore, CanHaveAmmoPost);
		DHookAddParam(hCanHaveAmmo, HookParamType_CBaseEntity);
		DHookAddParam(hCanHaveAmmo, HookParamType_Int);
	
		offset = GameConfGetOffset(temp, "SetModel");
		hSetModel = DHookCreate(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, SetModel);
		DHookAddParam(hSetModel, HookParamType_CharPtr);
	
		offset = GameConfGetOffset(temp, "GetMaxPlayerSpeed");
		hGetSpeed = DHookCreate(offset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, GetMaxPlayerSpeedPost);
		
		offset = GameConfGetOffset(temp, "OnTakeDamage");
		hTakeDamage = DHookCreate(offset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnTakeDamage);
		DHookAddParam(hTakeDamage, HookParamType_ObjectPtr);
	}
	else if(strcmp(game, "left4dead2") == 0)
	{
		gametype = GameL4D2;
		new Address:addr = GameConfGetAddress(temp, "CDirector");
		offset = GameConfGetOffset(temp, "OnGameplayStart");
		hGameplayStart = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, OnGameplayStart);
		DHookRaw(hGameplayStart, true, addr, RemovalCB);
	}
	DHookAddEntityListener(ListenType_Created, EntityCreated);
	DHookAddEntityListener(ListenType_Deleted, EntityDeleted);
	CloseHandle(temp);
	
}
public OnMapStart()
{
	if(gametype == GameCstrike)
	{
		//Hook Gamerules function in map start
		DHookGamerules(hCanHaveAmmo, true, RemovalCB);
	}
}
public OnClientPutInServer(client)
{
	if(gametype == GameCstrike)
	{
		DHookEntity(hBloodColor, true, client, RemovalCB);
		DHookEntity(hHookCanUse, true, client, RemovalCB);
		DHookEntity(hGetMaxs, true, client, RemovalCB);
		DHookEntity(hGetModelName, true, client, RemovalCB);
		DHookEntity(hSetModel, false, client, RemovalCB);
		DHookEntity(hGetSpeed, true, client, RemovalCB);
		
		//Dont add removal callback for this one
		DHookEntity(hTakeDamage, false, client);
	}

}
public EntityCreated(entity, const String:classname[])
{
	PrintToServer("Entity %i has been created it is %s", entity, classname);
}
public EntityDeleted(entity)
{
	PrintToServer("Entity %i has been deleted", entity);
}
//int CCSPlayer::OnTakeDamage(CTakeDamageInfo const&)
public MRESReturn:OnTakeDamage(this, Handle:hReturn, Handle:hParams)
{
	PrintToServer("DHooksHacks = Victim %i, Attacker %i, Inflictor %i, Damage %f", this, DHookGetParamObjectPtrVar(hParams, 1, 40, ObjectValueType_Ehandle), DHookGetParamObjectPtrVar(hParams, 1, 36, ObjectValueType_Ehandle), DHookGetParamObjectPtrVar(hParams, 1, 48, ObjectValueType_Float));
	
	if(this <= MaxClients && this > 0 && !IsFakeClient(this))
	{
		DHookSetParamObjectPtrVar(hParams, 1, 48, ObjectValueType_Float, 0.0);
		PrintToChat(this, "Pimping your hp");
	}
}
//void CDirector::OnGameplayStart()
public MRESReturn:OnGameplayStart()
{
	PrintToServer("Gameplay starting!");
	return MRES_Ignored;
}
// void CBaseEntity::SetModel(char  const*)
public MRESReturn:SetModel(this, Handle:hParams)
{
	//Change all bot skins to phoenix one
	if(IsFakeClient(this))
	{
		DHookSetParamString(hParams, 1, "models/player/t_phoenix.mdl");
		return MRES_ChangedHandled;
	}
	return MRES_Ignored;
}
//float CCSPlayer::GetPlayerMaxSpeed()
public MRESReturn:GetMaxPlayerSpeedPost(this, Handle:hReturn)
{
	if(IsFakeClient(this))
		return MRES_Ignored;
	
	//Change return max speed for non bots.
	DHookSetReturn(hReturn, 1000.0);
	return MRES_Override;
}
// bool CGameRules::CanHaveAmmo(CBaseCombatCharacter *, int)
public MRESReturn:CanHaveAmmoPost(Handle:hReturn, Handle:hParams)
{
	PrintToServer("Can has ammo? %s %i", DHookGetReturn(hReturn)?"true":"false", DHookGetParam(hParams, 2));
	return MRES_Ignored;
}
// string_t CBaseEntity::GetModelName(void)
public MRESReturn:GetModelName(this, Handle:hReturn)
{
	if(IsFakeClient(this))
	{
		new String:returnval[128];
		DHookGetReturnString(hReturn, returnval, sizeof(returnval));
		PrintToServer("It is a bot, Model should be: models/player/t_phoenix.mdl It is %s", returnval);
	}
	return MRES_Ignored;
	
}
// Vector CBasePlayer::GetPlayerMaxs()
public MRESReturn:GetMaxsPost(Handle:hReturn)
{
	new Float:vec[3];
	DHookGetReturnVector(hReturn, vec);
	PrintToServer("Get maxes %.1f, %.1f, %.1f", vec[0], vec[1], vec[2]);
	return MRES_Ignored;
}
// bool CBaseCombatCharacter::Weapon_CanUse(CBaseCombatWeapon *)
public MRESReturn:CanUsePost(this, Handle:hReturn, Handle:hParams)
{
	//Deny bots everything
	if(IsFakeClient(this))
	{
		DHookSetReturn(hReturn, false);
		return MRES_Override;
	}
	return MRES_Ignored;
}
// int CBaseCombatCharacter::BloodColor(void)
public MRESReturn:BloodColorPost(this, Handle:hReturn)
{
	//Change the bots blood color to goldish yellow
	if(IsFakeClient(this))
	{
		DHookSetReturn(hReturn, 2);
		return MRES_Override;
	}
	return MRES_Ignored;
}
public RemovalCB(hookid)
{
	PrintToServer("Removed hook %i", hookid);
}