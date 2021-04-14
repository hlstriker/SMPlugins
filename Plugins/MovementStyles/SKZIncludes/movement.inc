/*
	MovementAPI Function Stock Library
	Website: https://github.com/danzayau/MovementAPI
*/

#if defined _movement_included_
  #endinput
#endif
#define _movement_included_

#include <sdktools>



// =====[ STOCKS ]=====

/**
 * Calculates the horizontal distance between two vectors.
 *
 * @param vec1			First vector.
 * @param vec2			Second vector.
 * @return				Vector horizontal distance.
 */
stock Float:GetVectorHorizontalDistance(const Float:vec1[3], const Float:vec2[3])
{
	return SquareRoot(Pow(vec2[0] - vec1[0], 2.0) + Pow(vec2[1] - vec1[1], 2.0));
}

/**
 * Calculates a vector's horizontal length.
 *
 * @param vec			Vector.
 * @return				Vector horizontal length (magnitude).
 */
stock Float:GetVectorHorizontalLength(const Float:vec[3])
{
	return SquareRoot(Pow(vec[0], 2.0) + Pow(vec[1], 2.0));
}

/**
 * Scales a vector to a certain horizontal length.
 *
 * @param vec			Vector.
 * @param length		New horizontal length.
 */
stock SetVectorHorizontalLength(Float:vec[3], Float:length)
{
	new Float:newVec[3];
	newVec = vec;
	newVec[2] = 0.0;
	NormalizeVector(newVec, newVec);
	ScaleVector(newVec, length);
	newVec[2] = vec[2];
	vec = newVec;
}

/**
 * Gets a player's currently pressed buttons.
 *
 * @param client		Client index.
 * @return				Bitsum of buttons.
 */
stock Movement_GetButtons(client)
{
	return GetClientButtons(client);
}

/**
 * Gets a player's origin.
 *
 * @param client		Client index.
 * @param result		Resultant vector.
 */
stock Movement_GetOrigin(client, Float:result[3])
{
	GetClientAbsOrigin(client, result);
}

/**
 * Gets a player's origin.
 * If the player is on the ground, a trace hull is used to find the
 * exact height of the ground the player is standing on. This is thus
 * more accurate than Movement_GetOrigin when player is on ground.
 *
 * @param client		Client index.
 * @param result		Resultant vector.
 */
stock Movement_GetOriginEx(client, Float:result[3])
{
	if (!Movement_GetOnGround(client))
	{
		GetClientAbsOrigin(client, result);
		return;
	}
	
	// Get the coordinate of the solid beneath the player's origin
	// More accurate than GetClientAbsOrigin when on ground
	new Float:startPosition[3], endPosition[3];
	GetClientAbsOrigin(client, startPosition);
	endPosition = startPosition;
	endPosition[2] = startPosition[2] - 2.0; // Should be less than 2.0 units away
	Handle trace = TR_TraceHullFilterEx(
		startPosition, 
		endPosition, 
		view_as<float>( { -16.0, -16.0, 0.0 } ),  // Players are 32 x 32 x 72
		view_as<float>( { 16.0, 16.0, 72.0 } ), 
		MASK_PLAYERSOLID, 
		TraceEntityFilterPlayers, 
		client);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(result, trace);
		result[2] = result[2] - 0.03125; // Get rid of the offset (CS:GO quirk?)
	}
	else
	{
		result = startPosition; // Fallback to GetClientAbsOrigin
	}
	delete trace;
}

public bool:TraceEntityFilterPlayers(entity, contentsMask)
{
	return entity > MaxClients;
}

/**
 * Sets a player's origin by teleporting them.
 *
 * @param client		Client index.
 * @param origin		New origin.
 */
stock Movement_SetOrigin(client, const Float:origin[3])
{
	TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
}

/**
 * Gets a player's velocity.
 *
 * @param client		Client index.
 * @param result		Resultant vector.
 */
stock Movement_GetVelocity(client, Float:result[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", result);
}

/**
 * Sets a player's velocity by teleporting them.
 *
 * @param client		Client index.
 * @param velocity		New velocity.
 */
stock Movement_SetVelocity(client, const Float:velocity[3])
{
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
}

/**
 * Gets a player's horizontal speed.
 *
 * @param client		Client index.
 * @return				Player's horizontal speed.
 */
stock Float:Movement_GetSpeed(client)
{
	new Float:velocity[3];
	Movement_GetVelocity(client, velocity);
	return GetVectorHorizontalLength(velocity);
}

/**
 * Sets a player's horizontal speed.
 *
 * @param client		Client index.
 * @param value			New horizontal speed.
 * @param applyBaseVel	Whether to apply base velocity as well.
 */
stock Movement_SetSpeed(client, Float:value, bool:applyBaseVel = false)
{
	new Float:velocity[3];
	Movement_GetVelocity(client, velocity);
	SetVectorHorizontalLength(velocity, value);
	if (applyBaseVel)
	{
		new Float:baseVelocity[3];
		Movement_GetBaseVelocity(client, baseVelocity);
		AddVectors(velocity, baseVelocity, velocity);
	}
	Movement_SetVelocity(client, velocity);
}

/**
 * Gets a player's vertical velocity.
 *
 * @param client		Client index.
 * @return				Player's vertical velocity.
 */
stock Float:Movement_GetVerticalVelocity(client)
{
	new Float:velocity[3];
	Movement_GetVelocity(client, velocity);
	return velocity[2];
}

/**
 * Sets a player's vertical velocity.
 *
 * @param client		Client index.
 * @param value			New vertical velocity.
 */
stock Movement_SetVerticalVelocity(client, Float:value)
{
	new Float:velocity[3];
	Movement_GetVelocity(client, velocity);
	velocity[2] = value;
	Movement_SetVelocity(client, velocity);
}

/**
 * Gets a player's base velocity.
 *
 * @param client		Client index.
 * @param result		Resultant vector.
 */
stock Movement_GetBaseVelocity(client, Float:result[3])
{
	GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", result);
}

/**
 * Sets a player's base velocity.
 *
 * @param client		Client index.
 * @param baseVelocity	New base velocity.
 */
stock Movement_SetBaseVelocity(client, const Float:baseVelocity[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", baseVelocity);
}

/**
 * Gets a player's eye angles.
 *
 * @param client		Client index.
 * @param result		Resultant vector.
 */
stock Movement_GetEyeAngles(client, Float:result[3])
{
	GetClientEyeAngles(client, result);
}

/**
 * Sets a player's eye angles by teleporting them.
 *
 * @param client		Client index.
 * @param eyeAngles		New eye angles.
 */
stock Movement_SetEyeAngles(client, const Float:eyeAngles[3])
{
	TeleportEntity(client, NULL_VECTOR, eyeAngles, NULL_VECTOR);
}

/**
 * Gets whether a player is on the ground.
 *
 * @param client		Client index.
 * @return				Whether player is on the ground.
 */
stock bool:Movement_GetOnGround(client)
{
	return bool:(GetEntityFlags(client) & FL_ONGROUND);
}

/**
 * Gets whether a player is ducking or ducked.
 *
 * @param client		Client index.
 * @return				Whether player is ducking or ducked.
 */
stock bool:Movement_GetDucking(client)
{
	return GetEntProp(client, Prop_Send, "m_bDucked") || GetEntProp(client, Prop_Send, "m_bDucking");
}

/**
 * Gets a player's "m_flDuckSpeed" value.
 *
 * @param client			Client index.
 * @return					Value of "m_flDuckSpeed".
 */
stock Float:Movement_GetDuckSpeed(client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flDuckSpeed");
}

/**
 * Sets a player's "m_flDuckSpeed" value.
 *
 * @param client			Client index.
 * @param value				New "m_flDuckSpeed" value.
 */
stock Movement_SetDuckSpeed(client, Float:value)
{
	SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", value);
}

/**
 * Gets a player's "m_flVelocityModifier" value.
 *
 * @param client		Client index.
 * @return				Value of "m_flVelocityModifier".
 */
stock Float:Movement_GetVelocityModifier(client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flVelocityModifier");
}

/**
 * Sets a player's "m_flVelocityModifier" value.
 *
 * @param client		Client index.
 * @param value			New "m_flVelocityModifier" value.
 */
stock Movement_SetVelocityModifier(client, Float:value)
{
	SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", value);
}

/**
 * Gets a player's gravity scale factor.
 *
 * @param client			Client index.
 * @return					Gravity scale factor.
 */
stock Float:Movement_GetGravity(client)
{
	return GetEntityGravity(client);
}

/**
 * Sets a player's gravity scale factor.
 *
 * @param client			Client index.
 * @param value				Desired gravity scale factor.
 */
stock Movement_SetGravity(client, Float:value)
{
	SetEntityGravity(client, value);
}

/**
 * Gets a player's movetype.
 *
 * @param client		Client index.
 * @return				Player's movetype.
 */
stock MoveType:Movement_GetMovetype(client)
{
	return GetEntityMoveType(client);
}

/**
 * Sets a player's movetype.
 *
 * @param client		Client index.
 * @param movetype 		New movetype.
 */
stock Movement_SetMovetype(client, MoveType:movetype)
{
	SetEntityMoveType(client, movetype);
}

/**
 * Gets whether a player is on a ladder.
 *
 * @param client		Client index.
 * @return				Whether player is on a ladder.
 */
stock bool:Movement_GetOnLadder(client)
{
	return GetEntityMoveType(client) == MOVETYPE_LADDER;
}

/**
 * Gets whether a player is noclipping.
 *
 * @param client		Client index.
 * @return				Whether player is noclipping.
 */
stock bool:Movement_GetNoclipping(client)
{
	return GetEntityMoveType(client) == MOVETYPE_NOCLIP;
}



// =====[ METHODMAP ]=====
/*
methodmap MovementPlayer {
	
	public MovementPlayer(client) {
		return view_as<MovementPlayer>(client);
	}
	
	property ID {
		public get() {
			return view_as<int>(this);
		}
	}
	
	property Buttons {
		public get() {
			return Movement_GetButtons(this.ID);
		}
	}
	
	public GetOrigin(Float:result[3]) {
		Movement_GetOrigin(this.ID, result);
	}
	
	public SetOrigin(const Float:origin[3]) {
		Movement_SetOrigin(this.ID, origin);
	}
	
	public GetVelocity(Float:result[3]) {
		Movement_GetVelocity(this.ID, result);
	}
	
	public SetVelocity(const Float:velocity[3]) {
		Movement_SetVelocity(this.ID, velocity);
	}
	
	property Float:Speed {
		public get() {
			return Movement_GetSpeed(this.ID);
		}
		public set(Float:value) {
			Movement_SetSpeed(this.ID, value);
		}
	}
	
	property Float:VerticalVelocity {
		public get() {
			return Movement_GetVerticalVelocity(this.ID);
		}
		public set(Float:value) {
			Movement_SetVerticalVelocity(this.ID, value);
		}
	}
	
	public GetBaseVelocity(Float:result[3]) {
		Movement_GetBaseVelocity(this.ID, result);
	}
	
	public SetBaseVelocity(const Float:baseVelocity[3]) {
		Movement_SetBaseVelocity(this.ID, baseVelocity);
	}
	
	public GetEyeAngles(Float:result[3]) {
		Movement_GetEyeAngles(this.ID, result);
	}
	
	public SetEyeAngles(const Float:eyeAngles[3]) {
		Movement_SetEyeAngles(this.ID, eyeAngles);
	}
	
	property bool:OnGround {
		public get() {
			return Movement_GetOnGround(this.ID);
		}
	}
	
	property bool:Ducking {
		public get() {
			return Movement_GetDucking(this.ID);
		}
	}
	
	property Float:DuckSpeed {
		public get() {
			return Movement_GetDuckSpeed(this.ID);
		}
		public set(Float:value) {
			Movement_SetDuckSpeed(this.ID, value);
		}
	}
	
	property Float:VelocityModifier {
		public get() {
			return Movement_GetVelocityModifier(this.ID);
		}
		public set(Float:value) {
			Movement_SetVelocityModifier(this.ID, value);
		}
	}
	
	property Float:Gravity {
		public get() {
			return Movement_GetGravity(this.ID);
		}
		public set(Float:value) {
			Movement_SetGravity(this.ID, value);
		}
	}
	
	property MoveType Movetype {
		public get() {
			return Movement_GetMovetype(this.ID);
		}
		public set(MoveType movetype) {
			Movement_SetMovetype(this.ID, movetype);
		}
	}
	
	property bool:OnLadder {
		public get() {
			return Movement_GetOnLadder(this.ID);
		}
	}
	
	property bool:Noclipping {
		public get() {
			return Movement_GetNoclipping(this.ID);
		}
	}
}
*/
