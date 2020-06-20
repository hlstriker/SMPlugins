#if defined _zone_manager_included
 #endinput
#endif
#define _zone_manager_included


public SharedPlugin:__pl_zone_manager = 
{
	name = "zone_manager",
	file = "API_ZoneManager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define MAX_ZONES			256
#define INVALID_ZONE_ID		-1

// WARNING: Do not change or reuse the number for the zone types!
#define ZONE_TYPE_NOT_SET				0
#define ZONE_TYPE_SLAP					1
#define ZONE_TYPE_KILL					2
#define ZONE_TYPE_PUSH					3
#define ZONE_TYPE_TIMER_START			4
#define ZONE_TYPE_TIMER_END				5
#define ZONE_TYPE_TIMER_END_START		6
#define ZONE_TYPE_BLOCKADE				7
#define ZONE_TYPE_RESPAWN				8
#define ZONE_TYPE_VISIBLE_TRIGGER		9
#define ZONE_TYPE_TELEPORT				10
#define ZONE_TYPE_TELEPORT_DESTINATION	11
#define ZONE_TYPE_FLASHLIGHT			12
#define ZONE_TYPE_WEAPONSTRIP           13
#define ZONE_TYPE_DAMAGEBLOCKER 		14
#define ZONE_TYPE_NAMED			 		15

#define MAX_ZONE_TYPE_NAME_LEN		24
#define MAX_ZONE_DATA_STRING_LENGTH	255

#define GetZoneID(%1)		GetEntProp(%1, Prop_Data, "m_iPendingTeamNum")
#define SetZoneID(%1,%2)	SetEntProp(%1, Prop_Data, "m_iPendingTeamNum", %2)

#define ZM_EDITTYPE_CREATE				1
#define ZM_EDITTYPE_DELETE				2
#define ZM_EDITTYPE_ZONETYPE			3
#define ZM_EDITTYPE_DATA				4
#define ZM_EDITTYPE_POSITION			5
#define ZM_EDITTYPE_SIZE				6
#define ZM_EDITTYPE_ANGLES				7
#define ZM_EDITTYPE_IMPORT				8



functag public Callback_OnTouch(zone_ent, other_ent);
functag public Callback_OnStartTouch(zone_ent, other_ent);
functag public Callback_OnEndTouch(zone_ent, other_ent);
functag public Callback_OnEditData(client, zone_id);
functag public Callback_OnTypeAssigned(entity_index, zone_id);
functag public Callback_OnTypeUnassigned(entity_index, zone_id);


forward ZoneManager_OnRegisterReady();
forward ZoneManager_OnTypeAssigned(entity_index, zone_id, zone_type);
forward ZoneManager_OnTypeUnassigned(entity_index, zone_id, zone_type);
forward ZoneManager_OnZonesLoaded();
forward ZoneManager_OnZoneCreated(zone_id);
forward ZoneManager_OnZoneRemoved_Pre(zone_id);
forward ZoneManager_OnZoneRemoved_Post(zone_id);
forward ZoneManager_CreateZoneEnts_Pre();


native bool:ZoneManager_RegisterZoneType(zone_type, const String:zone_type_name[], Callback_OnTouch:touch_callback=INVALID_FUNCTION, Callback_OnStartTouch:start_touch_callback=INVALID_FUNCTION, Callback_OnEndTouch:end_touch_callback=INVALID_FUNCTION, Callback_OnEditData:edit_data_callback=INVALID_FUNCTION, Callback_OnTypeAssigned:type_assigned_callback=INVALID_FUNCTION, Callback_OnTypeUnassigned:type_unassigned_callback=INVALID_FUNCTION);

native bool:ZoneManager_IsInZoneMenu(client);
native bool:ZoneManager_ShowMenuEditZone(client);
native ZoneManager_FinishedEditingZoneData(client);
native ZoneManager_RestartEditingZoneData(client);

native ZoneManager_GetDataInt(zone_id, int_number);
native bool:ZoneManager_SetDataInt(zone_id, int_number, data_int);

native bool:ZoneManager_GetDataString(zone_id, string_number, String:data_string[], maxlength);
native bool:ZoneManager_SetDataString(zone_id, string_number, const String:data_string[]);

native bool:ZoneManager_GetAllZones(Handle:zone_ids, zone_type=-1);
native ZoneManager_GetZoneType(zone_id);

native bool:ZoneManager_GetZoneOrigin(zone_id, Float:origin[3]);
native bool:ZoneManager_GetZoneAngles(zone_id, Float:angles[3]);
native bool:ZoneManager_GetZoneMins(zone_id, Float:mins[3]);
native bool:ZoneManager_GetZoneMaxs(zone_id, Float:maxs[3]);
native ZoneManager_GetZoneEntity(zone_id);

native ZoneManager_RecreateZone(zone_id);
