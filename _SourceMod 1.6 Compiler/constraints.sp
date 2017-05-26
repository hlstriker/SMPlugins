#include <sourcemod>
#include <sdktools>

#include <vphysics>

public OnPluginStart() {
	RegAdminCmd("sm_weld", Command_Weld, ADMFLAG_CHEATS, "");
	RegAdminCmd("sm_rope", Command_Rope, ADMFLAG_CHEATS, "");
	RegAdminCmd("sm_wheel", Command_Wheel, ADMFLAG_CHEATS, "");
	RegAdminCmd("sm_thruster", Command_Thruster, ADMFLAG_CHEATS, "");
	RegAdminCmd("sm_thrust", Command_ThrusterPush, ADMFLAG_CHEATS, "");
}

public Action:Command_Weld(client, args)
{
	static tempEntIndex = 0;
	
	if (!tempEntIndex)
	{
		new entity = GetClientAimTarget(client, false);
		if (IsValidEntity(entity) && Phys_IsPhysicsObject(entity))
		{
			tempEntIndex = entity;
			ReplyToCommand(client, "[VPhys] Set reference entity to %d", tempEntIndex);
		} else {
			ReplyToCommand(client, "[VPhys] Target entity invalid, try again.");
		}
	} else {
		new entity = GetClientAimTarget(client, false);
		if (IsValidEntity(entity) && Phys_IsPhysicsObject(entity))
		{
			Phys_CreateFixedConstraint(tempEntIndex, entity, INVALID_HANDLE);
			ReplyToCommand(client, "[VPhys] Welded entities %d and %d, reset reference entity.", tempEntIndex, entity);
		} else {
			ReplyToCommand(client, "[VPhys] Target entity invalid, reset reference entity.");
		}
		tempEntIndex = 0;
	}
	
	return Plugin_Handled;
}

public Action:Command_Rope(client, args)
{
	static tempEntIndex = 0;
	static Float:tempEntHitPos[3];
	
	new Float:eyePos[3];
	new Float:eyeAng[3];
	
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	new Handle:trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SHOT, RayType_Infinite, TraceEntityFilterOnlyVPhysics);
	
	if (!tempEntIndex)
	{
		if(TR_DidHit(trace) && TR_GetEntityIndex(trace))
		{
			new Float:tempEntHitPosWorld[3];
			TR_GetEndPosition(tempEntHitPosWorld, trace);
			
			tempEntIndex = TR_GetEntityIndex(trace);
			Phys_WorldToLocal(tempEntIndex, tempEntHitPos, tempEntHitPosWorld);
			
			ReplyToCommand(client, "[VPhys] Set reference entity to %d", tempEntIndex);
		} else {
			ReplyToCommand(client, "[VPhys] Target entity invalid, try again.");
			return Plugin_Handled;
		}
	} else {
		if(TR_DidHit(trace) && TR_GetEntityIndex(trace))
		{
			new entIndex = TR_GetEntityIndex(trace);
			new Float:hitPosWorld[3];
			TR_GetEndPosition(hitPosWorld, trace);
			new Float:hitPos[3];
			Phys_WorldToLocal(entIndex, hitPos, hitPosWorld);
			
			new Float:tempEntHitPosWorld[3];
			Phys_LocalToWorld(tempEntIndex, tempEntHitPosWorld, tempEntHitPos);
			
			new Float:distVec[3];
			MakeVectorFromPoints(tempEntHitPosWorld, hitPosWorld, distVec);
			
			Phys_CreateLengthConstraint(tempEntIndex, entIndex, INVALID_HANDLE, tempEntHitPos, hitPos, GetVectorLength(distVec));
			ReplyToCommand(client, "[VPhys] Roped entities %d and %d, reset reference entity.", tempEntIndex, entIndex);
		} else {
			ReplyToCommand(client, "[VPhys] Target entity invalid, reset reference entity.");
		}
		
		tempEntIndex = 0;
	}
	
	CloseHandle(trace);
	
	return Plugin_Handled;
}

public Action:Command_Wheel(client, args)
{
	new Float:eyePos[3];
	new Float:eyeAng[3];
	
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	new Handle:trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SHOT, RayType_Infinite, TraceEntityFilterOnlyVPhysics);
	
	if(TR_DidHit(trace) && TR_GetEntityIndex(trace))
	{
		new entIndex = TR_GetEntityIndex(trace);
		new Float:hitPos[3];
		new Float:hitNormal[3];
		TR_GetEndPosition(hitPos, trace);
		TR_GetPlaneNormal(trace, hitNormal);
		
		new wheelIndex = CreateEntityByName("prop_physics_multiplayer");
		
		DispatchKeyValue(wheelIndex, "model", "models/props_vehicles/tire001c_car.mdl");
		DispatchKeyValue(wheelIndex, "spawnflags", "256");
		DispatchKeyValueFloat(wheelIndex, "physdamagescale", 0.0);
		DispatchKeyValueFloat(wheelIndex, "ExplodeDamage", 0.0);
		DispatchKeyValueFloat(wheelIndex, "ExplodeRadius", 0.0);
		
		DispatchSpawn(wheelIndex);
		ActivateEntity(wheelIndex);
		
		SetEntityModel(wheelIndex, "models/props_vehicles/tire001c_car.mdl");
		
		new Float:surfaceAng[3];
		GetVectorAngles(hitNormal, surfaceAng)
		
		new Float:wheelCenter[3]; // Should be calculating the width of the model for this.
		new Float:vecToAdd[3];
		vecToAdd[0] = hitNormal[0];
		vecToAdd[1] = hitNormal[1];
		vecToAdd[2] = hitNormal[2];
		ScaleVector(vecToAdd, 5.0);
		AddVectors(hitPos, vecToAdd, wheelCenter);
		
		TeleportEntity(wheelIndex, wheelCenter, surfaceAng, NULL_VECTOR);
		
		Phys_CreateHingeConstraint(entIndex, wheelIndex, INVALID_HANDLE, hitPos, hitNormal);
		ReplyToCommand(client, "[VPhys] Added wheel (index %d) to entity %d", wheelIndex, entIndex);
	} else {
		ReplyToCommand(client, "[VPhys] Target entity invalid.");
	}
	
	CloseHandle(trace);
	
	return Plugin_Handled;
}

new thrusterIndex = 0;

public Action:Command_ThrusterPush(client, args)
{
	new Float:angles[3];
	GetEntPropVector(thrusterIndex, Prop_Send, "m_angRotation", angles);

	new Float:thrustVec[3];
	GetAngleVectors(angles, thrustVec, NULL_VECTOR, NULL_VECTOR);
	
	ScaleVector(thrustVec, 15000.0);

	Phys_ApplyForceCenter(thrusterIndex, thrustVec);
	return Plugin_Handled;
}

public Action:Command_Thruster(client, args)
{
	new Float:eyePos[3];
	new Float:eyeAng[3];
	
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	new Handle:trace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_SHOT, RayType_Infinite, TraceEntityFilterOnlyVPhysics);
	
	if(TR_DidHit(trace) && TR_GetEntityIndex(trace))
	{
		new entIndex = TR_GetEntityIndex(trace);
		new Float:hitPos[3];
		new Float:hitNormal[3];
		TR_GetEndPosition(hitPos, trace);
		TR_GetPlaneNormal(trace, hitNormal);
		
		thrusterIndex = CreateEntityByName("prop_physics");
		
		DispatchKeyValue(thrusterIndex, "model", "models/props_junk/garbage_metalcan001a.mdl");
		DispatchKeyValue(thrusterIndex, "spawnflags", "1542");
		DispatchKeyValueFloat(thrusterIndex, "physdamagescale", 0.0);
		DispatchKeyValue(thrusterIndex, "disableshadows", "1");
		DispatchKeyValueFloat(thrusterIndex, "ExplodeDamage", 0.0);
		DispatchKeyValueFloat(thrusterIndex, "ExplodeRadius", 0.0);
		DispatchKeyValue(thrusterIndex, "nodamageforces", "1");
		DispatchKeyValue(thrusterIndex, "solid", "0");
		
		DispatchSpawn(thrusterIndex);
		ActivateEntity(thrusterIndex);
		
		SetEntityModel(thrusterIndex, "models/props_junk/garbage_metalcan001a.mdl");
		
		new Float:surfaceAng[3];
		GetVectorAngles(hitNormal, surfaceAng)
		
		TeleportEntity(thrusterIndex, hitPos, surfaceAng, NULL_VECTOR);
		
		Phys_CreateFixedConstraint(entIndex, thrusterIndex, INVALID_HANDLE);
		ReplyToCommand(client, "[VPhys] Added thruster (index %d) to entity %d", thrusterIndex, entIndex);
	} else {
		ReplyToCommand(client, "[VPhys] Target entity invalid.");
	}
	
	CloseHandle(trace);
	
	return Plugin_Handled;
}

public bool:TraceEntityFilterOnlyVPhysics(entity, contentsMask)
{
    return ((entity > MaxClients) && Phys_IsPhysicsObject(entity));
}