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
#define STYLE_BIT_THIRDPERSON				(1<<10)
#define STYLE_BIT_ROCKET_JUMP				(1<<11)
#define STYLE_BIT_PARKOUR					(1<<12)
#define STYLE_BIT_AUTO_STRAFE				(1<<13)
#define STYLE_BIT_TAS						(1<<14)
#define STYLE_BIT_HIGH_FOV					(1<<15)
#define STYLE_BIT_BACKWARDS					(1<<16)
#define STYLE_BIT_ONE_STRAFE_ONLY			(1<<17)
#define STYLE_BIT_LOW_FOV					(1<<18)
#define STYLE_BIT_STOCK_CAP					(1<<19)
#define STYLE_BIT_BUMP_MINES				(1<<20)
#define STYLE_BIT_SIMPLE_KZ				  (1<<21)
#define STYLE_BIT_VANILLA				  (1<<22)


functag public Callback_OnActivated(client);
functag public Callback_OnDeactivated(client);


forward MovementStyles_OnRegisterReady();
forward MovementStyles_OnRegisterMultiReady();
forward MovementStyles_OnBitsChanged(client, old_bits, &new_bits);
forward MovementStyles_OnBitsChanged_Post(client, old_bits, new_bits);
forward Action:MovementStyles_OnMenuBitsChanged(client, bits_being_toggled, bool:toggled_on_or_off, &extra_bits_to_force_on);
forward MovementStyles_OnSpawnPostForwardsSent(client);


native bool:MovementStyles_RegisterStyle(style_bit, const String:style_name[], Callback_OnActivated:activated_callback=INVALID_FUNCTION, Callback_OnDeactivated:deactivated_callback=INVALID_FUNCTION, order=0, const String:custom_menu_name[]="");
native bool:MovementStyles_RegisterMultiStyle(style_bits, const String:style_name[], order=0);
native MovementStyles_RegisterStyleCommand(style_bit, const String:command[]);
native MovementStyles_GetTotalStylesRegistered();

native MovementStyles_GetStyleBits(client);
native MovementStyles_SetStyleBitsRespawn(client, style_bits);
native bool:MovementStyles_GetStyleNames(client, Handle:names_array);
native bool:MovementStyles_GetStyleNamesFromBits(bits, Handle:names_array);

native MovementStyles_SetDefaultBits(bits); // Safe to call this in MovementStyles_OnRegisterReady().



#if !defined REQUIRE_PLUGIN
public __pl_movement_styles_SetNTVOptional()
{
	MarkNativeAsOptional("MovementStyles_RegisterStyle");
	MarkNativeAsOptional("MovementStyles_RegisterMultiStyle");
	MarkNativeAsOptional("MovementStyles_GetTotalStylesRegistered");
	MarkNativeAsOptional("MovementStyles_GetStyleBits");
  MarkNativeAsOptional("MovementStyles_SetStyleBitsRespawn");
  MarkNativeAsOptional("MovementStyles_GetStyleNames");
  MarkNativeAsOptional("MovementStyles_GetStyleNamesFromBits");
	MarkNativeAsOptional("MovementStyles_SetDefaultBits");
}
#endif
