#if defined _block_maker_included
 #endinput
#endif
#define _block_maker_included


public SharedPlugin:__pl_block_maker = 
{
	name = "block_maker",
	file = "API_BlockMaker.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define INVALID_BLOCK_ID			-1
#define MAX_BLOCK_TYPE_NAME_LEN		24
#define MAX_BLOCK_DATA_STRING_LEN	256


stock GetEntityBlockID(iEnt)
{
	if(1 <= iEnt <= MaxClients)
		return 0;
	
	return GetEntProp(iEnt, Prop_Data, "m_iPendingTeamNum");
}

stock SetEntityBlockID(iEnt, iBlockID)
{
	SetEntProp(iEnt, Prop_Data, "m_iPendingTeamNum", iBlockID);
}


functag public Action:Callback_OnTouch(block_ent, other_ent);
functag public Action:Callback_OnStartTouch(block_ent, other_ent);
functag public Action:Callback_OnEndTouch(block_ent, other_ent);
functag public Callback_OnTypeAssigned(block_ent, block_id);
functag public Callback_OnTypeUnassigned(block_ent, block_id);
functag public Callback_OnEditData(client, block_id);


forward BlockMaker_OnRegisterReady();
forward BlockMaker_OnBlocksLoaded();
forward BlockMaker_OnTypeAssigned(block_ent, block_id, block_type_id);
forward BlockMaker_OnTypeUnassigned(block_ent, block_id, block_type_id);
forward BlockMaker_OnBlockCreated(block_id);
forward BlockMaker_OnBlockRemoved_Pre(block_id, block_type_id);
forward BlockMaker_OnBlockRemoved_Post(block_id, block_type_id);
forward BlockMaker_OnDataChanged(block_id, block_type_id);


native BlockMaker_RegisterBlockType(const String:block_type_name[], const String:block_model[], Callback_OnTouch:touch_callback=INVALID_FUNCTION, Callback_OnStartTouch:start_touch_callback=INVALID_FUNCTION, Callback_OnEndTouch:end_touch_callback=INVALID_FUNCTION, Callback_OnTypeAssigned:type_assigned_callback=INVALID_FUNCTION, Callback_OnTypeUnassigned:type_unassigned_callback=INVALID_FUNCTION, Callback_OnEditData:edit_data_callback=INVALID_FUNCTION);
native bool:BlockMaker_SetSounds(block_type_id, const String:sound_start_touch[]="", const String:sound_touch[]="");
native bool:BlockMaker_AllowAsRandom(block_type_id, bool:allow=true);

native bool:BlockMaker_GetBlocksByType(block_type_id, Handle:block_ids_array);
native BlockMaker_GetBlockEntFromID(block_id);
native BlockMaker_GetBlockTypeID(block_id);
native bool:BlockMaker_GetBlockTypeNameFromID(block_type_id, bool:to_lower=true, String:type_name[], maxlength);
native BlockMaker_GetBlockTypeIDFromName(const String:type_name[]);

native bool:BlockMaker_GetDataString(block_id, String:data_string[], maxlength);
native bool:BlockMaker_SetDataString(block_id, const String:data_string[]);

native BlockMaker_FinishedEditingBlockData(client);
native BlockMaker_RestartEditingBlockData(client, block_id);
native BlockMaker_DisplayMenu_EditBlock(client, block_id);


#if !defined REQUIRE_PLUGIN
public __pl_block_maker_SetNTVOptional()
{
	MarkNativeAsOptional("BlockMaker_RegisterBlockType");
	MarkNativeAsOptional("BlockMaker_SetSounds");
	MarkNativeAsOptional("BlockMaker_AllowAsRandom");
	MarkNativeAsOptional("BlockMaker_GetBlocksByType");
	MarkNativeAsOptional("BlockMaker_GetBlockEntFromID");
	MarkNativeAsOptional("BlockMaker_GetBlockTypeID");
	MarkNativeAsOptional("BlockMaker_GetBlockTypeNameFromID");
	MarkNativeAsOptional("BlockMaker_GetBlockTypeIDFromName");
	MarkNativeAsOptional("BlockMaker_GetDataString");
	MarkNativeAsOptional("BlockMaker_SetDataString");
	MarkNativeAsOptional("BlockMaker_FinishedEditingBlockData");
	MarkNativeAsOptional("BlockMaker_RestartEditingBlockData");
	MarkNativeAsOptional("BlockMaker_DisplayMenu_EditBlock");
}
#endif