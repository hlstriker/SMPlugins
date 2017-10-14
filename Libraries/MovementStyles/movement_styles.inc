#if defined _movement_styles_included
 #endinput
#endif
#define _movement_styles_included


public SharedPlugin:__pl_movement_styles = 
{
	name = "movement_styles",
	file = "API_MovementStyles.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#define MAX_STYLE_NAME_LENGTH	32


// WARNING: Never change the order of the STYLE_ID and STYLE_BIT definitions!
enum
{
	STYLE_ID_NONE = 0,
	STYLE_ID_AUTO_BHOP,
	STYLE_ID_PRO_TIMER,
	STYLE_ID_NO_SPEED_CAP,
	STYLE_ID_LOW_GRAVITY,
	STYLE_ID_FORWARD_ONLY,
	STYLE_ID_STRAFE_ONLY,
	STYLE_ID_BACKWARD_ONLY,
	STYLE_ID_SIDEWAYS_BHOP_ONLY,
	STYLE_ID_HALF_SIDEWAYS_BHOP_ONLY,
	STYLE_ID_NO_LAND_CAP,
};

#define STYLE_BIT_NONE						0
#define STYLE_BIT_AUTO_BHOP					(1<<0)
#define STYLE_BIT_PRO_TIMER					(1<<1)
#define STYLE_BIT_NO_SPEED_CAP				(1<<2)
#define STYLE_BIT_LOW_GRAVITY				(1<<3)
#define STYLE_BIT_FORWARD_ONLY				(1<<4)
#define STYLE_BIT_STRAFE_ONLY				(1<<5)
#define STYLE_BIT_BACKWARD_ONLY				(1<<6)
#define STYLE_BIT_SIDEWAYS_BHOP_ONLY		(1<<7)
#define STYLE_BIT_HALF_SIDEWAYS_BHOP_ONLY	(1<<8)
#define STYLE_BIT_NO_LAND_CAP				(1<<9)


functag public Callback_OnActivated(client);
functag public Callback_OnDeactivated(client);


forward MovementStyles_OnRegisterReady();
forward MovementStyles_OnBitsChanged(client, old_bits, &new_bits);
forward MovementStyles_OnBitsChanged_Post(client, old_bits, new_bits);
forward Action:MovementStyles_OnMenuBitChanged(client, bit_being_toggled, bool:toggled_on_or_off, &bits_to_force_menu_visual_only); // bits_to_force_menu_visual_only is to be used in combination with new_bits from MovementStyles_OnBitsChanged()


native bool:MovementStyles_RegisterStyle(style_id, style_bit, const String:style_type_name[], Callback_OnActivated:activated_callback=INVALID_FUNCTION, Callback_OnDeactivated:deactivated_callback=INVALID_FUNCTION, order=0);
native MovementStyles_GetTotalStylesRegistered();

native MovementStyles_GetStyleBits(client);
native bool:MovementStyles_GetStyleNames(client, Handle:names_array);

native MovementStyles_SetDefaultBits(bits); // Safe to call this in MovementStyles_OnRegisterReady().
