#if defined _item_equipment_included
 #endinput
#endif
#define _item_equipment_included


public SharedPlugin:__pl_item_equipment = 
{
	name = "item_equipment",
	file = "Item_Equipment.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


enum EquipmentType
{
	EquipmentType_Head,
	EquipmentType_Face,
	EquipmentType_Torso
};


forward ItemEquipment_OnEquipped(client, equipment_ent);


native bool:ItemEquipment_GetEntities(client, equipment_entities[EquipmentType]);



#if !defined REQUIRE_PLUGIN
public __pl_item_equipment_SetNTVOptional()
{
	MarkNativeAsOptional("ItemEquipment_GetEntities");
}
#endif