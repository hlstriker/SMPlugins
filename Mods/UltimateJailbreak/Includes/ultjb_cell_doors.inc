#if defined _ultjb_cell_doors_included
 #endinput
#endif
#define _ultjb_cell_doors_included


public SharedPlugin:__pl_ultjb_cell_doors = 
{
	name = "ultjb_cell_doors",
	file = "UltJB_API_CellDoors.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};



/**
 * Forces the cell doors opened.
 *
 * @return				True if there are cell doors, false otherwise.
 */
native bool:UltJB_CellDoors_ForceOpen();

/**
 * Checks to see if the cell doors have been opened.
 *
 * @return				True if they have been opened, false otherwise.
 */
native bool:UltJB_CellDoors_HaveOpened();

/**
 * Checks to see if any cell doors are set.
 *
 * @return				True if cell doors exist, false otherwise.
 */
native bool:UltJB_CellDoors_DoExist();

/**
 * Adds an entity as a cell door.
 *
 * @param entity		The entity index to add as a cell door.
 * @noreturn
 */
native bool:UltJB_CellDoors_AddEntityAsDoor(entity);

/**
 * Removes an entity from being a cell door.
 *
 * @param entity		The entity index to remove from being a cell door.
 * @noreturn
 */
native bool:UltJB_CellDoors_RemoveEntityFromBeingDoor(entity);



/**
 * Called after the cell doors have been initialized on round start.
 *
 * @noreturn
 */
forward UltJB_CellDoors_OnRoundStartReady();

/**
 * Called when the cell doors have been opened.
 *
 * @noreturn
 */
forward UltJB_CellDoors_OnOpened();
